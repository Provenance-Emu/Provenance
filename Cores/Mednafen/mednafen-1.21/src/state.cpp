/* Mednafen - Multi-system Emulator
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "mednafen.h"

#include <map>

#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <mednafen/Time.h>

#include <trio/trio.h>
#include "driver.h"
#include "general.h"
#include "state.h"
#include "movie.h"
#include "netplay.h"
#include "video.h"
#include "video/resize.h"

#include "MemoryStream.h"
#include "compress/GZFileStream.h"

struct StateSectionMapEntry
{
 uint64 pos;
 uint32 size;
 bool used;
};

struct StateMem
{
 StateMem(Stream*s, bool svbe_ = false) : st(s), svbe(svbe_) { };
 ~StateMem();

 Stream* st = nullptr;
 bool svbe = false;	// State variable data is stored big-endian(for normal-path state loading only).

 std::map<std::string, StateSectionMapEntry> secmap; // For loads

 std::exception_ptr deferred_error;
 void ThrowDeferred(void);
};

static void MakeSectionMap(StateMem* sm, const uint64 sss_bound)
{
 Stream* const st = sm->st;
 char sname_tmp[32 + 1];

 while(st->tell() < sss_bound)
 {
  StateSectionMapEntry sme;

  st->read(sname_tmp, 32);
  sname_tmp[32] = 0;

  sme.size = st->get_LE<uint32>();
  sme.pos = st->tell();
  sme.used = false;
  st->seek(sme.size, SEEK_CUR);
  //
  std::string name_ss = sname_tmp;

  if(sm->secmap.count(name_ss))
   throw MDFN_Error(0, _("Duplicate section \"%s\" in save state!"), name_ss.c_str());
  else
   sm->secmap[name_ss] = sme;
 }
}


static void SubWrite(Stream *st, const SFORMAT *sf)
{
 while(sf->size || sf->name)	// Size can sometimes be zero, so also check for the text name.  These two should both be zero only at the end of a struct.
 {
  if(!sf->size || !sf->data)
  {
   sf++;
   continue;
  }

  if(sf->size == ~0U)		/* Link to another struct.	*/
  {
   SubWrite(st, (const SFORMAT *)sf->data);

   sf++;
   continue;
  }

  int32 bytesize = sf->size;
  uintptr_t p = (uintptr_t)sf->data;
  uint32 repcount = sf->repcount;
  const size_t repstride = sf->repstride; 
  char nameo[1 + 255];
  const int slen = strlen(sf->name);

  if(slen > 255)
   throw MDFN_Error(0, _("State variable name \"%s\" is too long."), sf->name);

  memcpy(&nameo[1], sf->name, slen);
  nameo[0] = slen;

  st->write(nameo, 1 + nameo[0]);
  st->put_LE<uint32>(bytesize * (repcount + 1));

  do
  {
   // Special case for the evil bool type, to convert bool to 1-byte elements.
   if(!sf->type)
   {
    for(int32 bool_monster = 0; bool_monster < bytesize; bool_monster++)
    {
     uint8 tmp_bool = ((bool *)p)[bool_monster];
     //printf("Bool write: %.31s\n", sf->name);
     st->write(&tmp_bool, 1);
    }
   }
   else
   {
    st->write((void*)p, bytesize);
   }
  } while(p += repstride, repcount--);

  sf++; 
 }
}

struct compare_cstr
{
 bool operator()(const char *s1, const char *s2) const
 {
  return(strcmp(s1, s2) < 0);
 }
};

typedef std::map<const char *, const SFORMAT *, compare_cstr> SFMap_t;

static void MakeSFMap(const SFORMAT *sf, SFMap_t &sfmap)
{
 while(sf->size || sf->name) // Size can sometimes be zero, so also check for the text name.  These two should both be zero only at the end of a struct.
 {
  if(!sf->size || !sf->data)
  {
   sf++;
   continue;
  }

  if(sf->size == ~0U)            /* Link to another SFORMAT structure. */
   MakeSFMap((const SFORMAT *)sf->data, sfmap);
  else
  {
   assert(sf->name);

   if(sfmap.find(sf->name) != sfmap.end())
    printf("Duplicate save state variable in internal emulator structures(CLUB THE PROGRAMMERS WITH BREADSTICKS): %s\n", sf->name);

   sfmap[sf->name] = sf;
  }

  sf++;
 }
}

static void ReadStateChunk(Stream *st, const SFORMAT *sf, uint32 size, const bool svbe, const bool fuzz)
{
 SFMap_t sfmap;
 SFMap_t sfmap_found;	// Used for identifying variables that are missing in the save state.

 MakeSFMap(sf, sfmap);

 uint64 temp = st->tell();
 while(st->tell() < (temp + size))
 {
  uint32 recorded_size;	// In bytes
  uint8 toa[1 + 256];	// Don't change to char unless cast toa[0] to unsigned to smem_read() and other places.

  st->read(toa, 1);
  st->read(toa + 1, toa[0]);

  toa[1 + toa[0]] = 0;

  recorded_size = st->get_LE<uint32>();

  SFMap_t::iterator sfmit;

  sfmit = sfmap.find((char *)toa + 1);

  if(sfmit != sfmap.end())
  {
   const SFORMAT *tmp = sfmit->second;

   if(recorded_size != tmp->size * (1 + tmp->repcount))
   {
    // Don't error out(throw), but still printf-log it.
    printf("Variable in save state wrong size: %s.  Need: %u, got: %u\n", toa + 1, tmp->size * (1 + tmp->repcount), recorded_size);
    st->seek(recorded_size, SEEK_CUR);
   }
   else
   {
    const auto type = tmp->type;
    const uint32 expected_size = tmp->size;	// In bytes
    uintptr_t p = (uintptr_t)tmp->data;
    uint32 repcount = tmp->repcount;
    const size_t repstride = tmp->repstride; 

    sfmap_found[tmp->name] = tmp;

    do
    {
     st->read((void*)p, expected_size);
#if 0
     if(MDFN_UNLIKELY(fuzz))
     {
      static uint64 lcg[2] = { 0xDEADBEEFCAFEBABEULL, 0x0123456789ABCDEFULL };

      for(unsigned i = 0; i < expected_size; i++)
      {
       ((uint8*)tmp->data)[i] = (lcg[0] ^ lcg[1]) >> 28;
       lcg[0] = (19073486328125ULL * lcg[0]) + 1;
       lcg[1] = (6364136223846793005ULL * lcg[1]) + 1442695040888963407ULL;
      }
     }
#endif
     if(!type)
     {
      // Converting downwards is necessary for the case of sizeof(bool) > 1
      for(int32 bool_monster = expected_size - 1; bool_monster >= 0; bool_monster--)
      {
       ((bool *)p)[bool_monster] = ((uint8 *)p)[bool_monster];
      }
     }
     else if(svbe != MDFN_IS_BIGENDIAN)
     {
      switch(type)
      {
       case 2: Endian_A16_Swap((void*)p, expected_size / sizeof(uint16)); break;
       case 4: Endian_A32_Swap((void*)p, expected_size / sizeof(uint32)); break;
       case 8: Endian_A64_Swap((void*)p, expected_size / sizeof(uint64)); break;
      }
     }
    } while(p += repstride, repcount--);
   }
  }
  else
  {
   printf("Unknown variable in save state: %s\n", toa + 1);
   st->seek(recorded_size, SEEK_CUR);
  }
 } // while(...)

 for(SFMap_t::const_iterator it = sfmap.begin(); it != sfmap.end(); it++)
 {
  if(sfmap_found.find(it->second->name) == sfmap_found.end())
  {
   printf("Variable of bytesize %u missing from save state: %s\n", it->second->size * (1 + it->second->repcount), it->second->name);
  }
 }
}

//
// Fast raw chunk reader/writer.
//
template<bool load>
static void FastRWChunk(Stream *st, const SFORMAT *sf)
{
 while(sf->size || sf->name)	// Size can sometimes be zero, so also check for the text name.  These two should both be zero only at the end of a struct.
 {
  if(!sf->size || !sf->data)
  {
   sf++;
   continue;
  }

  if(sf->size == ~0U)		/* Link to another struct.	*/
  {
   FastRWChunk<load>(st, (const SFORMAT *)sf->data);

   sf++;
   continue;
  }

  int32 bytesize = sf->size;
  uintptr_t p = (uintptr_t)sf->data;
  uint32 repcount = sf->repcount;
  const size_t repstride = sf->repstride; 

  // If we're only saving the raw data, and we come across a bool type, we save it as it is in memory, rather than converting it to
  // 1-byte.  In the SFORMAT structure, the size member for bool entries is the number of bool elements, not the total in-memory size,
  // so we adjust it here.
  if(!sf->type)
   bytesize *= sizeof(bool);
  
  //
  // Align large variables(e.g. RAM) to a 16-byte boundary for potentially faster memory copying, before we read/write it.
  //
  if(bytesize >= 65536)
   st->seek((st->tell() + 15) &~ 15, SEEK_SET);

  do
  {
   if(load)
    st->read((void*)p, bytesize);
   else
    st->write((void*)p, bytesize);
  } while(p += repstride, repcount--);
  sf++; 
 }
}

//
// When updating this function make sure to adhere to the guarantees in state.h.
//
bool MDFNSS_StateAction(StateMem *sm, const unsigned load, const bool data_only, const SFORMAT *sf, const char *sname, const bool optional) noexcept
{
 //printf("Section: %s %zu\n", sname, strlen(sname));

 if(MDFN_UNLIKELY(sm->deferred_error))
 {
  return(load ? false : true);
 }

 try
 {
  Stream* st = sm->st;

  if(MDFN_LIKELY(data_only))	// Not particularly likely, but it's more important to optimize for this code path...
  {
   static const uint8 SSFastCanary[8] = { 0x42, 0xA3, 0x10, 0x87, 0xBC, 0x6D, 0xF2, 0x79 };
   char sname_canary[32 + 8];

   if(load)
   {
    st->read(sname_canary, 32 + 8);

    if(strncmp(sname_canary, sname, 32))
     throw MDFN_Error(0, _("Section name mismatch in state loading fast path."));

    if(memcmp(sname_canary + 32, SSFastCanary, 8))
     throw MDFN_Error(0, _("Section canary is a zombie AAAAAAAAAAGH!"));

    FastRWChunk<true>(st, sf);
   }
   else
   {
    memset(sname_canary, 0, sizeof(sname_canary));
    strncpy(sname_canary, sname, 32);
    memcpy(sname_canary + 32, SSFastCanary, 8);
    st->write(sname_canary, 32 + 8);

    FastRWChunk<false>(st, sf);
   }
  }
  else
  {
   if(load)
   {
    auto msme = sm->secmap.find(sname);

    if(msme == sm->secmap.end())
    {
     if(optional)
     {
      printf("Missing optional section: %.32s\n", sname);

      return false;
     }
     else
      throw MDFN_Error(0, _("Section missing: %.32s"), sname);
    }
    else
    {
     msme->second.used = true;
     st->seek(msme->second.pos, SEEK_SET);
     ReadStateChunk(st, sf, msme->second.size, sm->svbe, (bool)(load & 0x80000000));
    }
   }
   else
   {
    int64 data_start_pos;
    int64 end_pos;
    uint8 sname_tmp[32];

    memset(sname_tmp, 0, sizeof(sname_tmp));
    strncpy((char *)sname_tmp, sname, 32);

    if(strlen(sname) > 32)
     printf("Warning: section name is too long: %s\n", sname);

    st->write(sname_tmp, 32);

    st->put_LE<uint32>(0);                // We'll come back and write this later.

    data_start_pos = st->tell();
    SubWrite(st, sf);
    end_pos = st->tell();

    st->seek(data_start_pos - 4, SEEK_SET);
    st->put_LE<uint32>(end_pos - data_start_pos);
    st->seek(end_pos, SEEK_SET);
   }
  }
 }
 catch(...)
 {
  sm->deferred_error = std::current_exception();
  return(load ? false : true);
 }
 return(true);
}

StateMem::~StateMem(void)
{

}

void StateMem::ThrowDeferred(void)
{
 if(deferred_error)
 {
  std::exception_ptr te = deferred_error;
  deferred_error = nullptr;
  std::rethrow_exception(te);
 }
}

void MDFNSS_SaveSM(Stream *st, bool data_only, const MDFN_Surface *surface, const MDFN_Rect *DisplayRect, const int32 *LineWidths)
{
	if(!MDFNGameInfo->StateAction)
	{
	 throw MDFN_Error(0, _("Module \"%s\" doesn't support save states."), MDFNGameInfo->shortname);
	}

	StateMem sm(st);

	if(data_only)
	{
	 MDFN_StateAction(&sm, 0, true);
	 sm.ThrowDeferred();
	}
	else
	{
	 static const char *header_magic = "MDFNSVST";
	 int64 start_pos;
         uint8 header[32];
	 int neowidth = 0, neoheight = 0;

	 memset(header, 0, sizeof(header));

	 if(surface && DisplayRect && LineWidths)
	 {
	  bool is_multires = false;

	  // We'll want to use the nominal width if the source rectangle is > 25% off on either axis, or the source image has
	  // multiple horizontal resolutions.
	  neowidth = MDFNGameInfo->nominal_width;
	  neoheight = MDFNGameInfo->nominal_height;

	  if(LineWidths[0] != ~0)
 	  {
	   int32 first_w = LineWidths[DisplayRect->y];

	   for(int y = 0; y < DisplayRect->h; y++)
	   {
	    if(LineWidths[DisplayRect->y + y] != first_w)
	    {
	     //puts("Multires!");
	     is_multires = true;
	    }
	   }
	  }

	  if(!is_multires)
	  {
	   if(((double)DisplayRect->w / MDFNGameInfo->nominal_width) > 0.75  && ((double)DisplayRect->w / MDFNGameInfo->nominal_width) < 1.25)
	    neowidth = DisplayRect->w;

           if(((double)DisplayRect->h / MDFNGameInfo->nominal_height) > 0.75  && ((double)DisplayRect->h / MDFNGameInfo->nominal_height) < 1.25)
	    neoheight = DisplayRect->h;
	  }
	 }

	 memcpy(header, header_magic, 8);

	 MDFN_en64lsb(header + 8, Time::EpochTime());

	 MDFN_en32lsb(header + 16, MEDNAFEN_VERSION_NUMERIC);
	 MDFN_en32lsb(header + 24, neowidth);
	 MDFN_en32lsb(header + 28, neoheight);

	 start_pos = st->tell();
	 st->write(header, 32);

	 if(surface && DisplayRect && LineWidths)
	 {
	  //
	  // TODO: Make work with 8bpp and 16bpp.
	  //
	  MDFN_Surface dest_surface(NULL, neowidth, neoheight, neowidth, surface->format);
	  MDFN_Rect dest_rect;

	  dest_rect.x = 0;
	  dest_rect.y = 0;
	  dest_rect.w = neowidth;
	  dest_rect.h = neoheight;

	  MDFN_ResizeSurface(surface, DisplayRect, LineWidths, &dest_surface, &dest_rect);

	  {
	   uint32* previewbuffer = dest_surface.pixels;
	   uint8* previewbuffer8 = (uint8*)previewbuffer;

	   for(int32 a = 0; a < neowidth * neoheight; a++)
	   {
	    int nr, ng, nb;

	    surface->DecodeColor(previewbuffer[a], nr, ng, nb);

	    previewbuffer8[0] = nr;
	    previewbuffer8[1] = ng;
	    previewbuffer8[2] = nb;

	    previewbuffer8 += 3;
	   }
	  }

          st->write((uint8*)dest_surface.pixels, 3 * neowidth * neoheight);
	 }

	 MDFN_StateAction(&sm, 0, data_only);
	 sm.ThrowDeferred();

	 {
	  int64 end_pos = st->tell();
	  uint32 pv = (end_pos - start_pos) & 0x7FFFFFFF;

	  #ifdef MSB_FIRST
	  pv |= 0x80000000;
	  #endif

	  st->seek(start_pos + 16 + 4, SEEK_SET);
	  st->put_LE<uint32>(pv);
	  st->seek(end_pos, SEEK_SET);		// Seek to just beyond end of save state before returning.
	 }
	}
}

void MDFNSS_LoadSM(Stream *st, bool data_only)
{
	if(!MDFNGameInfo->StateAction)
	{
	 throw MDFN_Error(0, _("Module \"%s\" doesn't support save states."), MDFNGameInfo->shortname);
	}

	if(MDFN_LIKELY(data_only))
	{
	 StateMem sm(st);
	 MDFN_StateAction(&sm, MEDNAFEN_VERSION_NUMERIC, true);
	 sm.ThrowDeferred();
	}
	else
	{
         uint8 header[32];
	 uint32 width, height, preview_len;
  	 uint32 stateversion;
	 uint32 total_len;
	 int64 start_pos;
	 bool svbe;

	 start_pos = st->tell();
         st->read(header, 32);

         if(memcmp(header, "MEDNAFENSVESTATE", 16) && memcmp(header, "MDFNSVST", 8))
	  throw MDFN_Error(0, _("Missing/Wrong save state header ID."));

	 stateversion = MDFN_de32lsb(header + 16);
	 total_len = MDFN_de32lsb(header + 20) & 0x7FFFFFFF;
         svbe = MDFN_de32lsb(header + 20) & 0x80000000;
         width = MDFN_de32lsb(header + 24);
         height = MDFN_de32lsb(header + 28);
	 preview_len = width * height * 3;

	 if((int)stateversion < 0x900)	// Ensuring that (int)stateversion is > 0 is the most important part.
	  throw MDFN_Error(0, _("Invalid/Unsupported version in save state header."));

	 st->seek(preview_len, SEEK_CUR);				// Skip preview

	 {
	  StateMem sm(st, svbe);

	  MakeSectionMap(&sm, start_pos + total_len);

	  MDFN_StateAction(&sm, stateversion, false);			// Load state data.

	  for(auto msme : sm.secmap)
	  {
	   if(!msme.second.used)
	    printf("Warning: Unused section \"%s\".\n", msme.first.c_str());
	  }

	  sm.ThrowDeferred();
	 }
	 st->seek(start_pos + total_len, SEEK_SET);			// Seek to just beyond end of save state before returning.
	}
}

//
//
//
static int SaveStateStatus[10];
static int CurrentState = 0;
static int RecentlySavedState = -1;

void MDFNSS_CheckStates(void)
{
	time_t last_time = 0;

        if(!MDFNGameInfo->StateAction) 
         return;


	for(int ssel = 0; ssel < 10; ssel++)
        {
	 struct stat stat_buf;

	 SaveStateStatus[ssel] = false;
	 //printf("%s\n", MDFN_MakeFName(MDFNMKF_STATE, ssel, 0).c_str());
	 if(MDFN_stat(MDFN_MakeFName(MDFNMKF_STATE, ssel, 0).c_str(), &stat_buf) == 0)
	 {
	  SaveStateStatus[ssel] = true;
	  if(stat_buf.st_mtime > last_time)
	  {
	   RecentlySavedState = ssel;
	   last_time = stat_buf.st_mtime;
 	  }
	 }
        }

	CurrentState = 0;
	MDFND_SetStateStatus(NULL);
}

void MDFNSS_GetStateInfo(const std::string& path, StateStatusStruct* status)
{
 uint32 StateShowPBWidth;
 uint32 StateShowPBHeight;
 uint8 *previewbuffer = NULL;

 try
 {
  GZFileStream fp(path, GZFileStream::MODE::READ);
  uint8 header[32];

  fp.read(header, 32);

  uint32 width = MDFN_de32lsb(header + 24);
  uint32 height = MDFN_de32lsb(header + 28);

  if(width > 1024)
   width = 1024;

  if(height > 1024)
   height = 1024;

  previewbuffer = new uint8[3 * width * height];
  fp.read(previewbuffer, 3 * width * height);

  StateShowPBWidth = width;
  StateShowPBHeight = height;
 }
 catch(std::exception &e)
 {
  if(previewbuffer != NULL)
  {
   delete[] previewbuffer;
   previewbuffer = NULL;
  }

  StateShowPBWidth = MDFNGameInfo->nominal_width;
  StateShowPBHeight = MDFNGameInfo->nominal_height;
 }

 status->gfx = previewbuffer;
 status->w = StateShowPBWidth;
 status->h = StateShowPBHeight;
}

void MDFNI_SelectState(int w) noexcept
{
 if(!MDFNGameInfo->StateAction) 
  return;

 if(w == -1) 
 {  
  MDFND_SetStateStatus(NULL);
  return; 
 }

 MDFNI_SelectMovie(-1);

 try
 {
  if(w == 666 + 1)
   CurrentState = (CurrentState + 1) % 10;
  else if(w == 666 - 1)
  {
   CurrentState--;

   if(CurrentState < 0 || CurrentState > 9)
    CurrentState = 9;
  }
  else
   CurrentState = w;

  std::unique_ptr<StateStatusStruct> status(new StateStatusStruct());

  memset(status.get(), 0, sizeof(StateStatusStruct));
 
  memcpy(status->status, SaveStateStatus, 10 * sizeof(int));

  status->current = CurrentState;
  status->recently_saved = RecentlySavedState;

  MDFNSS_GetStateInfo(MDFN_MakeFName(MDFNMKF_STATE, CurrentState, NULL), status.get());
  MDFND_SetStateStatus(status.release());
 }
 catch(std::exception& e)
 {
  MDFN_Notify(MDFN_NOTICE_WARNING, "%s", e.what());
  MDFND_SetStateStatus(NULL);
 }
}  

bool MDFNI_SaveState(const char *fname, const char *suffix, const MDFN_Surface *surface, const MDFN_Rect *DisplayRect, const int32 *LineWidths) noexcept
{
 bool ret = true;

 try
 {
  if(MDFNnetplay && (MDFNGameInfo->SaveStateAltersState == true))
  {
   throw MDFN_Error(0, _("Module %s is not compatible with manual state saving during netplay."), MDFNGameInfo->shortname);
  }

  //
  //
  {
   MemoryStream st(65536);

   MDFNSS_SaveSM(&st, false, surface, DisplayRect, LineWidths);

   //
   //
   //
   GZFileStream gp(fname ? std::string(fname) : MDFN_MakeFName(MDFNMKF_STATE,CurrentState,suffix),
			GZFileStream::MODE::WRITE, MDFN_GetSettingI("filesys.state_comp_level"));

   gp.write(st.map(), st.size());
   gp.close();
  }

  MDFND_SetStateStatus(NULL);

  if(!fname && !suffix)
  {
   SaveStateStatus[CurrentState] = true;
   RecentlySavedState = CurrentState;
   MDFN_Notify(MDFN_NOTICE_STATUS, _("State %d saved."), CurrentState);
  }
 }
 catch(std::exception &e)
 {
  if(!fname && !suffix)
   MDFN_Notify(MDFN_NOTICE_ERROR, _("State %d save error: %s"), CurrentState, e.what());
  else
   MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());

  if(MDFNnetplay)
   MDFND_NetplayText(e.what(), false);

  ret = false;
 }

 return(ret);
}

bool MDFNI_LoadState(const char *fname, const char *suffix) noexcept
{
 bool ret = true;

 try
 {
  /* For network play and movies, be load the state locally, and then save the state to a temporary buffer,
     and send or record that.  This ensures that if an older state is loaded that is missing some
     information expected in newer save states, desynchronization won't occur(at least not
     from this ;)).
  */

  {
   GZFileStream st(fname ? std::string(fname) : MDFN_MakeFName(MDFNMKF_STATE,CurrentState,suffix), GZFileStream::MODE::READ);
   uint8 header[32];
   uint32 st_len;

   st.read(header, 32);

   st_len = MDFN_de32lsb(header + 16 + 4) & 0x7FFFFFFF;

   if(st_len < 32)
    throw MDFN_Error(0, _("Save state header length field is bad."));

   MemoryStream sm(st_len, -1);

   memcpy(sm.map(), header, 32);
   st.read(sm.map() + 32, st_len - 32);

   MDFNSS_LoadSM(&sm, false);
  }

  if(MDFNnetplay)
  {
   NetplaySendState();
  }

  if(MDFNMOV_IsRecording())
   MDFNMOV_RecordState();

  MDFND_SetStateStatus(NULL);

  if(!fname && !suffix)
  {
   SaveStateStatus[CurrentState] = true;
   MDFN_Notify(MDFN_NOTICE_STATUS, _("State %d loaded."), CurrentState);
  }
 }
 catch(std::exception &e)
 {
  MDFN_Error* me = dynamic_cast<MDFN_Error*>(&e);

  if(!fname && !suffix)
   MDFN_Notify(MDFN_NOTICE_ERROR, _("State %d load error: %s"), CurrentState, e.what());
  else
  {
   // FIXME: Autosave kludgery, refactor interfaces in the future to make cleaner.
   if(suffix && me && me->GetErrno() == ENOENT)
    return true;

   MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
  }

  if(MDFNnetplay)
   MDFND_NetplayText(e.what(), false);

  ret = false;
 }

 return(ret);
}
