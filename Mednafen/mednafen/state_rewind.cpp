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
#include "state.h"
#include "movie.h"
#include "state_rewind.h"

#include <mednafen/MemoryStream.h>
#include <mednafen/quicklz/quicklz.h>

#if QLZ_COMPRESSION_LEVEL != 0
 #error "State rewinding code untested with QLZ_COMPRESSION_LEVEL != 0"
#endif

#include <algorithm>
#include <vector>
#include <memory>

struct StateMemPacket
{
	std::unique_ptr<MemoryStream> data;
	uint32 uncompressed_len = 0;	// Only non-zero when data is compressed.
};

static bool Active = false;
static bool Enabled = false;
static uint32 SRW_AllocHint;
static std::vector<StateMemPacket> bcs;
static size_t bcs_pos;

static union
{
 char compress[QLZ_SCRATCH_COMPRESS];
 char decompress[QLZ_SCRATCH_DECOMPRESS];
} qlz_scratch;

void MDFNSRW_Begin(void) noexcept
{
 if(!Enabled)
  return;

 if(!Active)
 {
  try
  {
   bcs.resize(std::max<size_t>(3, MDFN_GetSettingUI("srwframes")));
   bcs_pos = 0;
   memset(&qlz_scratch, 0, sizeof(qlz_scratch));
   SRW_AllocHint = 8192;
   Active = true;
  }
  catch(std::exception &e)
  {
   bcs.clear();

   MDFN_DispMessage("State rewinding error.");
   MDFND_PrintError(e.what());
  }
 }
}

void MDFNSRW_End(void) noexcept
{
 if(Active)
 {
  bcs.clear();

  Active = false;
 }
}

bool MDFNSRW_IsRunning(void) noexcept
{
 return(Active);
}

static INLINE void DoXORFilter(MemoryStream* prev, MemoryStream* cur) noexcept
{
 MDFN_FastMemXOR(prev->map(), cur->map(), std::min(prev->size(), cur->size()));
}

static INLINE void DoDecompress(StateMemPacket* dp)
{
 std::unique_ptr<MemoryStream> tmp_buf(new MemoryStream(dp->uncompressed_len, -1));

 qlz_decompress((char*)dp->data->map(), tmp_buf->map(), qlz_scratch.decompress);

 //
 //
 //

 delete dp->data.release();
 dp->data = std::move(tmp_buf);
 dp->uncompressed_len = 0;
}

static INLINE void DoCompress(StateMemPacket* dp)
{
 const uint32 uncompressed_len = dp->data->size();
 const uint32 max_compressed_len = (uncompressed_len + 400);
 std::unique_ptr<MemoryStream> tmp_buf(new MemoryStream(max_compressed_len, -1));
 uint32 dst_len;

 dst_len = qlz_compress(dp->data->map(), (char*)tmp_buf->map(), uncompressed_len, qlz_scratch.compress);
 tmp_buf->truncate(dst_len);
 tmp_buf->shrink_to_fit();

 //
 //
 //

 delete dp->data.release();
 dp->data = std::move(tmp_buf);
 dp->uncompressed_len = uncompressed_len;
}

//
//
//
static bool DoRewind(void)
{
 bool ret = false;

  //
  // If there's a save state to load, load it.
  //
  {
   StateMemPacket* smp = &bcs[(bcs_pos + bcs.size() - 1) % bcs.size()];

   if(smp->data)
   {
    assert(smp->uncompressed_len == 0);

    smp->data->rewind();
    MDFNSS_LoadSM(smp->data.get(), true);

    ret = true;
   }
  }

  //
  // If more than one save state is available, then decompress the save state that comes before the one we just loaded,
  // and THEN destroy the save state data we just loaded.
  //
  {
   StateMemPacket* smp = &bcs[(bcs_pos + bcs.size() - 1) % bcs.size()];
   StateMemPacket* smp_nr = &bcs[(bcs_pos + bcs.size() - 2) % bcs.size()];

   if(smp_nr->data)
   {
#if 1
    if(smp_nr->uncompressed_len != 0) 
    {
     DoDecompress(smp_nr);
     DoXORFilter(smp_nr->data.get(), smp->data.get());
    }
#endif
    //
    //
    //
    *smp = std::move(StateMemPacket());
    bcs_pos = (bcs_pos + bcs.size() - 1) % bcs.size();
   }
  }

 return(ret);
}

//
//
//
static void DoRecord(void)
{
  //
  // Save current save state and push it onto the list.
  //
  {
   StateMemPacket smp;
   smp.data.reset(new MemoryStream(SRW_AllocHint));
   MDFNSS_SaveSM(smp.data.get(), true);

   if(smp.data->size() > SRW_AllocHint)
    SRW_AllocHint = smp.data->size();

   bcs[bcs_pos] = std::move(smp);
   bcs_pos = (bcs_pos + 1) % bcs.size();
  }

  //
  // Compress previous save states that need compression(AFTER we push the current state onto the list, for exception-safety).
  //
#if 1
  {
   for(size_t i = 0; i < bcs.size() - 1; i++)
   {
    StateMemPacket* smp = &bcs[(bcs_pos + bcs.size() - (1 + i)) % bcs.size()];
    StateMemPacket* smp_nr = &bcs[(bcs_pos + bcs.size() - (2 + i)) % bcs.size()];

    //printf("%u\n", smp_nr->uncompressed_len);
    if(smp_nr->data && smp_nr->uncompressed_len == 0)
    {
     DoXORFilter(smp_nr->data.get(), smp->data.get());
     try { DoCompress(smp_nr); } catch(...) { DoXORFilter(smp_nr->data.get(), smp->data.get()); }
    }
    else
     break;
   }
  }
#endif
}

bool MDFNSRW_Frame(bool rewind) noexcept
{
 if(!Active)
  return(false);

 try
 {
  if(rewind)
  {
   return DoRewind();
  }
  else
  {
   DoRecord();
   return(false);
  }
 }
 catch(std::exception &e)
 {
  MDFNSRW_End();
  MDFND_PrintError(e.what());
  MDFN_DispMessage(_("State rewinding error."));
  return(false);
 }
}

bool MDFNI_EnableStateRewind(bool enable)
{
 Enabled = enable;

 if(Enabled)
  MDFNSRW_Begin();
 else
  MDFNSRW_End();

 return(Active);
}

