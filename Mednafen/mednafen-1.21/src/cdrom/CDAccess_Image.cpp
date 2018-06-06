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

/*
 Notes and TODO:

	POSTGAP in CUE sheets may not be handled properly, should the directive automatically increment the index number?

	INDEX nn where 02 <= nn <= 99 is not supported in CUE sheets.

	TOC reading code is extremely barebones, leaving out support for more esoteric features.

	A PREGAP statement in the first track definition in a CUE sheet may not work properly(depends on what is proper);
	it will be added onto the implicit default 00:02:00 of pregap.
*/

#include <mednafen/mednafen.h>

#include <sys/types.h>

#include <trio/trio.h>

#include <mednafen/general.h>
#include <mednafen/string/string.h>
#include <mednafen/FileStream.h>
#include <mednafen/MemoryStream.h>

#include "CDAccess.h"
#include "CDAccess_Image.h"

#include "CDAFReader.h"

#include <map>

using namespace CDUtility;

enum
{
 CDRF_SUBM_NONE = 0,
 CDRF_SUBM_RW = 1,
 CDRF_SUBM_RW_RAW = 2
};

// Disk-image(rip) track/sector formats
enum
{
 DI_FORMAT_AUDIO       = 0x00,
 DI_FORMAT_MODE1       = 0x01,
 DI_FORMAT_MODE1_RAW   = 0x02,
 DI_FORMAT_MODE2       = 0x03,
 DI_FORMAT_MODE2_FORM1 = 0x04,
 DI_FORMAT_MODE2_FORM2 = 0x05,
 DI_FORMAT_MODE2_RAW   = 0x06,
 DI_FORMAT_CDI_RAW     = 0x07,
 _DI_FORMAT_COUNT
};

static const int32 DI_Size_Table[8] =
{
 2352, // Audio
 2048, // MODE1
 2352, // MODE1 RAW
 2336, // MODE2
 2048, // MODE2 Form 1
 2324, // Mode 2 Form 2
 2352, // MODE2 RAW
 2352, // CD-I RAW
};

static const char *DI_CDRDAO_Strings[8] = 
{
 "AUDIO",
 "MODE1",
 "MODE1_RAW",
 "MODE2",
 "MODE2_FORM1",
 "MODE2_FORM2",
 "MODE2_RAW",
 "CDI_RAW"
};

static const char *DI_CUE_Strings[8] = 
{
 "AUDIO",
 "MODE1/2048",
 "MODE1/2352",
 "MODE2/2336",	// FIXME: A guess
 "MODE2/2048",	// FIXME: A guess
 "MODE2/2324",	// FIXME: A guess
 "MODE2/2352",	// FIXME: A guess
 "CDI/2352",
};

// Should return an offset to the start of the next argument(past any whitespace), or if there isn't a next argument,
// it'll return the length of the src string.
static size_t UnQuotify(const std::string &src, size_t source_offset, std::string &dest, bool parse_quotes = true)
{
 const size_t source_len = src.length();
 bool in_quote = 0;
 bool already_normal = 0;

 dest.clear();

 while(source_offset < source_len)
 {
  if(src[source_offset] == ' ' || src[source_offset] == '\t')
  {
   if(!in_quote)
   {
    if(already_normal)	// Trailing whitespace(IE we're done with this argument)
     break;
    else		// Leading whitespace, ignore it.
    {
     source_offset++;
     continue;
    }
   }
  }

  if(src[source_offset] == '"' && parse_quotes)
  {
   if(in_quote)
   {
    source_offset++;
// Not sure which behavior is most useful(or correct :b).
#if 0
    in_quote = false;
    already_normal = true;
#else
    break;
#endif
   }
   else
    in_quote = 1;
  }
  else
  {
   dest.push_back(src[source_offset]);
   already_normal = 1;
  }
  source_offset++;
 }

 while(source_offset < source_len)
 {
  if(src[source_offset] != ' ' && src[source_offset] != '\t')
   break;

  source_offset++;
 }

 return source_offset;
}

uint32 CDAccess_Image::GetSectorCount(CDRFILE_TRACK_INFO *track)
{
 const int div = DI_Size_Table[track->DIFormat] + (track->SubchannelMode ? 96 : 0);
 int64 size;

 size = track->AReader ? track->AReader->FrameCount() * 4 : track->fp->size();
 size -= track->FileOffset;

 if(size < 0)
  throw MDFN_Error(0, _("Track offset into file exceeds the amount of data available!"));

 // Might need to update/fix TOC loading path before enabling this check.
 //if(size % div)
 // throw MDFN_Error(0, _("Garbage at end of referenced file?"));

 return size / div;
}

void CDAccess_Image::ParseTOCFileLineInfo(CDRFILE_TRACK_INFO *track, const int tracknum, const std::string &filename, const char *binoffset, const char *msfoffset, const char *length, bool image_memcache, std::map<std::string, Stream*> &toc_streamcache)
{
 long offset = 0; // In bytes!
 long tmp_long;
 int m, s, f;
 uint32 sector_mult;
 long sectors;
 std::map<std::string, Stream*>::iterator ribbit;

 ribbit = toc_streamcache.find(filename);

 if(ribbit != toc_streamcache.end())
 {
  track->FirstFileInstance = 0;

  track->fp = ribbit->second;
 }
 else
 {
  std::string efn;

  track->FirstFileInstance = 1;

  efn = MDFN_EvalFIP(base_dir, filename);

  if(image_memcache)
   track->fp = new MemoryStream(new FileStream(efn, FileStream::MODE_READ));
  else
   track->fp = new FileStream(efn, FileStream::MODE_READ);

  toc_streamcache[filename] = track->fp;
 }

 if(filename.length() >= 4 && !MDFN_strazicmp(filename.c_str() + filename.length() - 4, ".wav"))
 {
  track->AReader = CDAFR_Open(track->fp);

  if(!track->AReader)
   throw MDFN_Error(0, "TODO ERROR");
 }

 sector_mult = DI_Size_Table[track->DIFormat];

 if(track->SubchannelMode)
  sector_mult += 96;

 if(binoffset && trio_sscanf(binoffset, "%ld", &tmp_long) == 1)
 {
  offset += tmp_long;
 }

 if(msfoffset && trio_sscanf(msfoffset, "%d:%d:%d", &m, &s, &f) == 3)
 {
  offset += ((m * 60 + s) * 75 + f) * sector_mult;
 }

 track->FileOffset = offset; // Make sure this is set before calling GetSectorCount()!
 sectors = GetSectorCount(track);
 //printf("Track: %d, offset: %ld, %ld\n", tracknum, offset, sectors);

 if(length)
 {
  tmp_long = sectors;

  if(trio_sscanf(length, "%d:%d:%d", &m, &s, &f) == 3)
   tmp_long = (m * 60 + s) * 75 + f;
  else if(track->DIFormat == DI_FORMAT_AUDIO)
  {
   char *endptr = NULL;

   tmp_long = strtol(length, &endptr, 10);

   // Error?
   if(endptr == length)
   {
    tmp_long = sectors;
   }
   else
    tmp_long /= 588;

  }

  if(tmp_long > sectors)
  {
   throw MDFN_Error(0, _("Length specified in TOC file for track %d is too large by %ld sectors!\n"), tracknum, (long)(tmp_long - sectors));
  }
  sectors = tmp_long;
 }

 track->sectors = sectors;
}

static void MDFN_strtoupper(std::string &str)
{
 const size_t len = str.length();

 for(size_t x = 0; x < len; x++)
 {
  if(str[x] >= 'a' && str[x] <= 'z')
  {
   str[x] = str[x] - 'a' + 'A';
  }
 }
}

#if 0
std::string MDFN_toupper(const std::string &str)
{
 const size_t len = str.length();
 std::string new_str;

 new_str.reserve(len);

 for(size_t x = 0; x < len; x++)
 {
  int c = str[x];

  if(c >= 'a' && c <= 'z')
   c = c - 'a' + 'A';

  new_str.push_back(c);
 }
}
#endif

void CDAccess_Image::LoadSBI(const std::string& sbi_path)
{
 MDFN_printf(_("Loading SBI file \"%s\"...\n"), sbi_path.c_str());
 {
  MDFN_AutoIndent aind(1);

  try
  {
   FileStream sbis(sbi_path, FileStream::MODE_READ);
   uint8 header[4];
   uint8 ed[4 + 10];
   uint8 tmpq[12];

   sbis.read(header, 4);

   if(memcmp(header, "SBI\0", 4))
    throw MDFN_Error(0, _("Not recognized a valid SBI file."));

   while(sbis.read(ed, sizeof(ed), false) == sizeof(ed))
   {
    if(!BCD_is_valid(ed[0]) || !BCD_is_valid(ed[1]) || !BCD_is_valid(ed[2]))
     throw MDFN_Error(0, _("Bad BCD MSF offset in SBI file: %02x:%02x:%02x"), ed[0], ed[1], ed[2]);

    if(ed[3] != 0x01)
     throw MDFN_Error(0, _("Unrecognized boogly oogly in SBI file: %02x"), ed[3]);

    memcpy(tmpq, &ed[4], 10);

    //
    subq_generate_checksum(tmpq);
    tmpq[10] ^= 0xFF;
    tmpq[11] ^= 0xFF;
    //

    //printf("%02x:%02x:%02x --- ", ed[0], ed[1], ed[2]);
    //for(unsigned i = 0; i < 12; i++)
    // printf("%02x ", tmpq[i]);
    //printf("\n");

    uint32 aba = AMSF_to_ABA(BCD_to_U8(ed[0]), BCD_to_U8(ed[1]), BCD_to_U8(ed[2]));

    memcpy(SubQReplaceMap[aba].data(), tmpq, 12);
   }
   MDFN_printf(_("Loaded Q subchannel replacements for %zu sectors.\n"), SubQReplaceMap.size());
  }
  catch(MDFN_Error &e)
  {
   if(e.GetErrno() != ENOENT)
    throw;
   else
    MDFN_printf(_("Error: %s\n"), e.what());
  }
  catch(std::exception &e)
  {
   throw;
  }
 }
}

static void StringToMSF(const char* str, unsigned* m, unsigned* s, unsigned* f)
{
 if(trio_sscanf(str, "%u:%u:%u", m, s, f) != 3)
  throw MDFN_Error(0, _("M:S:F time \"%s\" is malformed."), str);

 if(*m > 99 || *s > 59 || *f > 74)
  throw MDFN_Error(0, _("M:S:F time \"%s\" contains component(s) out of range."), str);
}

void CDAccess_Image::ImageOpen(const std::string& path, bool image_memcache)
{
 MemoryStream fp(new FileStream(path, FileStream::MODE_READ));
 static const unsigned max_args = 4;
 std::string linebuf;
 std::string cmdbuf, args[max_args];
 bool IsTOC = false;
 int32 active_track = -1;
 int32 AutoTrackInc = 1; // For TOC
 CDRFILE_TRACK_INFO TmpTrack;
 std::string file_base, file_ext;
 std::map<std::string, Stream*> toc_streamcache;

 disc_type = DISC_TYPE_CDDA_OR_M1;
 memset(&TmpTrack, 0, sizeof(TmpTrack));

 MDFN_GetFilePathComponents(path, &base_dir, &file_base, &file_ext);

 if(!MDFN_strazicmp(file_ext.c_str(), ".toc"))
 {
  MDFN_printf(_("TOC file detected.\n"));
  IsTOC = true;
 }

 if(!IsTOC && !fp.read_utf8_bom())
 {
  fp.mswin_utf8_convert_kludge();
 }

 // Assign opposite maximum values so our tests will work!
 FirstTrack = 99;
 LastTrack = 0;

 linebuf.reserve(1024);
 while(fp.get_line(linebuf) >= 0)
 {
   unsigned argcount = 0;

   if(IsTOC)
   {
    // Handle TOC format comments
    size_t ss_loc = linebuf.find("//");

    if(ss_loc != std::string::npos)
     linebuf.resize(ss_loc);
   }

   // Call trim AFTER we handle TOC-style comments, so we'll be sure to remove trailing whitespace in lines like: MONKEY  // BABIES
   MDFN_trim(linebuf);

   if(linebuf.length() == 0)	// Skip blank lines.
    continue;

   // Grab command and arguments.
   {
    size_t offs = 0;

    offs = UnQuotify(linebuf, offs, cmdbuf, false);
    for(argcount = 0; argcount < max_args && offs < linebuf.length(); argcount++)
     offs = UnQuotify(linebuf, offs, args[argcount]);

    // Make sure unused arguments are cleared out so we don't have inter-line leaks!
    for(unsigned x = argcount; x < max_args; x++)
     args[x].clear();

    MDFN_strtoupper(cmdbuf);
   }

   //printf("%s\n", cmdbuf.c_str()); //: %s %s %s %s\n", cmdbuf.c_str(), args[0].c_str(), args[1].c_str(), args[2].c_str(), args[3].c_str());

   if(IsTOC)
   {
    if(cmdbuf == "TRACK")
    {
     if(active_track >= 0)
     {
      memcpy(&Tracks[active_track], &TmpTrack, sizeof(TmpTrack));
      memset(&TmpTrack, 0, sizeof(TmpTrack));
      active_track = -1;
     }

     for(int32 i = 2; i < 100; i++)
      TmpTrack.index[i] = -1;
 
     if(AutoTrackInc > 99)
     {
      throw(MDFN_Error(0, _("Invalid track number: %d"), AutoTrackInc));
     }

     active_track = AutoTrackInc++;
     if(active_track < FirstTrack)
      FirstTrack = active_track;
     if(active_track > LastTrack)
      LastTrack = active_track;

     int format_lookup;
     for(format_lookup = 0; format_lookup < _DI_FORMAT_COUNT; format_lookup++)
     {
      if(!MDFN_strazicmp(args[0].c_str(), DI_CDRDAO_Strings[format_lookup]))
      {
       TmpTrack.DIFormat = format_lookup;
       break;
      }
     }

     if(format_lookup == _DI_FORMAT_COUNT)
     {
      throw(MDFN_Error(0, _("Invalid track format: %s"), args[0].c_str()));
     }

     if(TmpTrack.DIFormat == DI_FORMAT_AUDIO)
      TmpTrack.RawAudioMSBFirst = true; // Silly cdrdao...

     if(!MDFN_strazicmp(args[1].c_str(), "RW"))
     {
      TmpTrack.SubchannelMode = CDRF_SUBM_RW;
      throw(MDFN_Error(0, _("\"RW\" format subchannel data not supported, only \"RW_RAW\" is!")));
     }
     else if(!MDFN_strazicmp(args[1].c_str(), "RW_RAW"))
      TmpTrack.SubchannelMode = CDRF_SUBM_RW_RAW;

    } // end to TRACK
    else if(cmdbuf == "SILENCE")
    {
     //throw MDFN_Error(0, _("Unsupported directive: %s"), cmdbuf.c_str());
    }
    else if(cmdbuf == "ZERO")
    {
     //throw MDFN_Error(0, _("Unsupported directive: %s"), cmdbuf.c_str());
    }
    else if(cmdbuf == "FIFO")
    {
     throw MDFN_Error(0, _("Unsupported directive: %s"), cmdbuf.c_str());
    }
    else if(cmdbuf == "FILE" || cmdbuf == "AUDIOFILE")
    {
     const char *binoffset = NULL;
     const char *msfoffset = NULL;
     const char *length = NULL;

     if(args[1].c_str()[0] == '#')
     {
      binoffset = args[1].c_str() + 1;
      msfoffset = args[2].c_str();
      length = args[3].c_str();
     }
     else
     {
      msfoffset = args[1].c_str();
      length = args[2].c_str();
     }
     //printf("%s, %s, %s, %s\n", args[0].c_str(), binoffset, msfoffset, length);
     ParseTOCFileLineInfo(&TmpTrack, active_track, args[0], binoffset, msfoffset, length, image_memcache, toc_streamcache);
    }
    else if(cmdbuf == "DATAFILE")
    {
     const char *binoffset = NULL;
     const char *length = NULL;
  
     if(args[1].c_str()[0] == '#') 
     {
      binoffset = args[1].c_str() + 1;
      length = args[2].c_str();
     }
     else
      length = args[1].c_str();

     ParseTOCFileLineInfo(&TmpTrack, active_track, args[0], binoffset, NULL, length, image_memcache, toc_streamcache);
    }
    else if(cmdbuf == "INDEX")
    {
     // FIXME
     throw MDFN_Error(0, _("Unsupported directive: %s"), cmdbuf.c_str());
    }
    else if(cmdbuf == "PREGAP")
    {
     if(active_track < 0)
     {
      throw(MDFN_Error(0, _("Command %s is outside of a TRACK definition!\n"), cmdbuf.c_str()));
     }

     unsigned int m,s,f;

     StringToMSF(args[0].c_str(), &m, &s, &f);

     TmpTrack.pregap = (m * 60 + s) * 75 + f;
    } // end to PREGAP
    else if(cmdbuf == "START")
    {
     if(active_track < 0)
     {
      throw(MDFN_Error(0, _("Command %s is outside of a TRACK definition!\n"), cmdbuf.c_str()));
     }

     unsigned int m,s,f;

     StringToMSF(args[0].c_str(), &m, &s, &f);

     TmpTrack.pregap = (m * 60 + s) * 75 + f;
    }
    else if(cmdbuf == "TWO_CHANNEL_AUDIO")
    {
     TmpTrack.subq_control &= ~SUBQ_CTRLF_4CH;
    }
    else if(cmdbuf == "FOUR_CHANNEL_AUDIO")
    {
     TmpTrack.subq_control |= SUBQ_CTRLF_4CH;
    }
    else if(cmdbuf == "NO")
    {
     MDFN_strtoupper(args[0]);

     if(args[0] == "COPY")
     {
      TmpTrack.subq_control &= ~SUBQ_CTRLF_DCP; 
     }
     else if(args[0] == "PRE_EMPHASIS")
     {
      TmpTrack.subq_control &= ~SUBQ_CTRLF_PRE;
     }
     else
     {
      throw MDFN_Error(0, _("Unsupported argument to \"NO\" directive: %s"), args[0].c_str());
     }
    }
    else if(cmdbuf == "COPY")
    {
     TmpTrack.subq_control |= SUBQ_CTRLF_DCP;
    } 
    else if(cmdbuf == "PRE_EMPHASIS")
    {
     TmpTrack.subq_control |= SUBQ_CTRLF_PRE;
    }
    // TODO: Confirm that these are taken from the TOC of the disc, and not synthesized by cdrdao.
    else if(cmdbuf == "CD_DA")
     disc_type = DISC_TYPE_CDDA_OR_M1;
    else if(cmdbuf == "CD_ROM")
     disc_type = DISC_TYPE_CDDA_OR_M1;
    else if(cmdbuf == "CD_ROM_XA")
     disc_type = DISC_TYPE_CD_XA;
    else
    {
     //throw MDFN_Error(0, _("Unsupported directive: %s"), cmdbuf.c_str());
    }
    // TODO: CATALOG

   } /*********** END TOC HANDLING ************/
   else // now for CUE sheet handling
   {
    if(cmdbuf == "FILE")
    {
     if(active_track >= 0)
     {
      memcpy(&Tracks[active_track], &TmpTrack, sizeof(TmpTrack));
      memset(&TmpTrack, 0, sizeof(TmpTrack));
      active_track = -1;
     }

     std::string efn = MDFN_EvalFIP(base_dir, args[0]);
     TmpTrack.fp = new FileStream(efn, FileStream::MODE_READ);
     TmpTrack.FirstFileInstance = 1;

     if(image_memcache)
      TmpTrack.fp = new MemoryStream(TmpTrack.fp);

     if(!MDFN_strazicmp(args[1].c_str(), "BINARY"))
     {
      //TmpTrack.Format = TRACK_FORMAT_DATA;
      //struct stat stat_buf;
      //fstat(fileno(TmpTrack.fp), &stat_buf);
      //TmpTrack.sectors = stat_buf.st_size; // / 2048;
     }
     else if(!MDFN_strazicmp(args[1].c_str(), "OGG") || !MDFN_strazicmp(args[1].c_str(), "VORBIS") || !MDFN_strazicmp(args[1].c_str(), "WAVE") || !MDFN_strazicmp(args[1].c_str(), "WAV") || !MDFN_strazicmp(args[1].c_str(), "PCM")
	|| !MDFN_strazicmp(args[1].c_str(), "MPC") || !MDFN_strazicmp(args[1].c_str(), "MP+"))
     {
      TmpTrack.AReader = CDAFR_Open(TmpTrack.fp);
      if(!TmpTrack.AReader)
      {
       throw(MDFN_Error(0, _("Unsupported audio track file format: %s\n"), args[0].c_str()));
      }
     }
     else
     {
      throw(MDFN_Error(0, _("Unsupported track format: %s\n"), args[1].c_str()));
     }
    }
    else if(cmdbuf == "TRACK")
    {
     if(active_track >= 0)
     {
      memcpy(&Tracks[active_track], &TmpTrack, sizeof(TmpTrack));
      TmpTrack.FirstFileInstance = 0;
      TmpTrack.pregap = 0;
      TmpTrack.pregap_dv = 0;
      TmpTrack.postgap = 0;
      TmpTrack.index[0] = -1;
      TmpTrack.index[1] = 0;
     }

     for(int32 i = 2; i < 100; i++)
      TmpTrack.index[i] = -1;

     active_track = atoi(args[0].c_str());

     if(active_track < 1 || active_track > 99)
     {
      throw(MDFN_Error(0, _("Invalid track number: %d\n"), active_track));
     }

     if(active_track < FirstTrack)
      FirstTrack = active_track;
     if(active_track > LastTrack)
      LastTrack = active_track;

     int format_lookup;
     for(format_lookup = 0; format_lookup < _DI_FORMAT_COUNT; format_lookup++)
     {
      if(!MDFN_strazicmp(args[1].c_str(), DI_CUE_Strings[format_lookup]))
      {
       TmpTrack.DIFormat = format_lookup;
       break;
      }
     }

     if(format_lookup == _DI_FORMAT_COUNT)
     {
      throw(MDFN_Error(0, _("Invalid track format: %s\n"), args[1].c_str()));
     }
    }
    else if(cmdbuf == "INDEX")
    {
     if(active_track >= 0)
     {
      unsigned wi;
      unsigned int m,s,f;

      StringToMSF(args[1].c_str(), &m, &s, &f);

      if(trio_sscanf(args[0].c_str(), "%u", &wi) == 1 && wi < 100)
       TmpTrack.index[wi] = (m * 60 + s) * 75 + f;
      else
       throw MDFN_Error(0, _("Malformed \"INDEX\" directive: %s\n"), cmdbuf.c_str());
     }
    }
    else if(cmdbuf == "PREGAP")
    {
     if(active_track >= 0)
     {
      unsigned int m,s,f;

      StringToMSF(args[0].c_str(), &m, &s, &f);

      TmpTrack.pregap = (m * 60 + s) * 75 + f;
     }
    }
    else if(cmdbuf == "POSTGAP")
    {
     if(active_track >= 0)
     {
      unsigned int m,s,f;

      StringToMSF(args[0].c_str(), &m, &s, &f);

      TmpTrack.postgap = (m * 60 + s) * 75 + f;
     }
    }
    else if(cmdbuf == "REM")
    {

    }
    else if(cmdbuf == "FLAGS")
    {
     TmpTrack.subq_control &= ~(SUBQ_CTRLF_PRE | SUBQ_CTRLF_DCP | SUBQ_CTRLF_4CH);
     for(unsigned i = 0; i < argcount; i++)
     {
      if(args[i] == "DCP")
      {
       TmpTrack.subq_control |= SUBQ_CTRLF_DCP;
      }
      else if(args[i] == "4CH")
      {
       TmpTrack.subq_control |= SUBQ_CTRLF_4CH;
      }
      else if(args[i] == "PRE")
      {
       TmpTrack.subq_control |= SUBQ_CTRLF_PRE;
      }
      else if(args[i] == "SCMS")
      {
	// Not implemented, likely pointless.  PROBABLY indicates that the copy bit of the subchannel Q control field is supposed to
	// alternate between 1 and 0 at 9.375 Hz(four 1, four 0, four 1, four 0, etc.).
      }
      else
      {
       throw MDFN_Error(0, _("Unknown CUE sheet \"FLAGS\" directive flag \"%s\".\n"), args[i].c_str());
      }
     }
    }
    else if(cmdbuf == "CDTEXTFILE" || cmdbuf == "CATALOG" || cmdbuf == "ISRC" ||
	    cmdbuf == "TITLE" || cmdbuf == "PERFORMER" || cmdbuf == "SONGWRITER")
    {
     MDFN_printf(_("Unsupported CUE sheet directive: \"%s\".\n"), cmdbuf.c_str());	// FIXME, generic logger passed by pointer to constructor
    }
    else
    {
     throw MDFN_Error(0, _("Unknown CUE sheet directive \"%s\".\n"), cmdbuf.c_str());
    }
   } // end of CUE sheet handling
 } // end of fgets() loop

 if(active_track >= 0)
  memcpy(&Tracks[active_track], &TmpTrack, sizeof(TmpTrack));

 if(FirstTrack > LastTrack)
 {
  throw(MDFN_Error(0, _("No tracks found!\n")));
 }

 FirstTrack = FirstTrack;
 NumTracks = 1 + LastTrack - FirstTrack;

 int32 RunningLBA = 0;
 int32 LastIndex = 0;
 long FileOffset = 0;

 RunningLBA -= 150;
 Tracks[FirstTrack].pregap += 150;

 for(int x = FirstTrack; x < (FirstTrack + NumTracks); x++)
 {
  if(!Tracks[x].fp && !Tracks[x].AReader)
   throw MDFN_Error(0, _("Missing track %u."), x);

  if(Tracks[x].DIFormat == DI_FORMAT_AUDIO)
   Tracks[x].subq_control &= ~SUBQ_CTRLF_DATA;
  else
   Tracks[x].subq_control |= SUBQ_CTRLF_DATA;

  if(!IsTOC)	// TOC-format disc_type calculation is handled differently.
  {
   if(disc_type != DISC_TYPE_CD_I)
   {
    switch(Tracks[x].DIFormat)
    {
     default: break;

     case DI_FORMAT_MODE2:
     case DI_FORMAT_MODE2_FORM1:
     case DI_FORMAT_MODE2_FORM2:
     case DI_FORMAT_MODE2_RAW:
	disc_type = DISC_TYPE_CD_XA;	
	break;

     case DI_FORMAT_CDI_RAW:
	disc_type = DISC_TYPE_CD_I;
	break;
    }
   }
  }

  if(IsTOC)
  {
   RunningLBA += Tracks[x].pregap;
   Tracks[x].LBA = RunningLBA;
   RunningLBA += Tracks[x].sectors;
   RunningLBA += Tracks[x].postgap;
  }
  else // else handle CUE sheet...
  {
   if(Tracks[x].FirstFileInstance) 
   {
    LastIndex = 0;
    FileOffset = 0;
   }

   RunningLBA += Tracks[x].pregap;

   Tracks[x].pregap_dv = 0;

   if(Tracks[x].index[0] != -1)
    Tracks[x].pregap_dv = Tracks[x].index[1] - Tracks[x].index[0];

   FileOffset += Tracks[x].pregap_dv * DI_Size_Table[Tracks[x].DIFormat];

   RunningLBA += Tracks[x].pregap_dv;

   Tracks[x].LBA = RunningLBA;

   // Make sure FileOffset this is set before the call to GetSectorCount()
   Tracks[x].FileOffset = FileOffset;

   if((x + 1) >= (FirstTrack + NumTracks) || Tracks[x+1].FirstFileInstance)
    Tracks[x].sectors = GetSectorCount(&Tracks[x]);
   else
   { 
    // Calculate the sector count if we have multiple tracks per one binary image file.
    if(Tracks[x + 1].index[0] == -1)
     Tracks[x].sectors = Tracks[x + 1].index[1] - Tracks[x].index[1];
    else
     Tracks[x].sectors = Tracks[x + 1].index[0] - Tracks[x].index[1];	//Tracks[x + 1].index - Tracks[x].index;
   }

   //printf("Poo: %d %d\n", x, Tracks[x].sectors);
   RunningLBA += Tracks[x].sectors;
   RunningLBA += Tracks[x].postgap;

   //printf("%d, %ld %d %d %d %d\n", x, FileOffset, Tracks[x].index, Tracks[x].pregap, Tracks[x].sectors, Tracks[x].LBA);

   FileOffset += Tracks[x].sectors * DI_Size_Table[Tracks[x].DIFormat];
  } // end to cue sheet handling
 } // end to track loop

 total_sectors = RunningLBA;

 //
 // Adjust indexes for MakeSubPQ()
 //
 for(int x = FirstTrack; x < (FirstTrack + NumTracks); x++)
 {
  const int32 base = Tracks[x].index[1];

  for(int32 i = 0; i < 100; i++)
  {
   if(i == 0 || Tracks[x].index[i] == -1)
    Tracks[x].index[i] = INT32_MAX;
   else
    Tracks[x].index[i] = Tracks[x].LBA + (Tracks[x].index[i] - base);

   assert(Tracks[x].index[i] >= 0);
  }
 }

 //
 // Load SBI file, if present
 //
 if(!IsTOC)
 {
  char sbi_ext[4] = { 's', 'b', 'i', 0 };

  if(file_ext.length() == 4 && file_ext[0] == '.')
  {
   for(unsigned i = 0; i < 3; i++)
   {
    if(file_ext[1 + i] >= 'A' && file_ext[1 + i] <= 'Z')
     sbi_ext[i] += 'A' - 'a';
   }
  }

  LoadSBI(MDFN_EvalFIP(base_dir, file_base + std::string(".") + std::string(sbi_ext), true).c_str());
 }

 GenerateTOC();
}

void CDAccess_Image::Cleanup(void)
{
 for(int32 track = 0; track < 100; track++)
 {
  CDRFILE_TRACK_INFO *this_track = &Tracks[track];

  if(this_track->FirstFileInstance)
  {
   if(Tracks[track].AReader)
   {
    delete Tracks[track].AReader;
    Tracks[track].AReader = NULL;
   }

   if(this_track->fp)
   {
    delete this_track->fp;
    this_track->fp = NULL;
   }
  }
 }
}

CDAccess_Image::CDAccess_Image(const std::string& path, bool image_memcache) : NumTracks(0), FirstTrack(0), LastTrack(0), total_sectors(0)
{
 memset(Tracks, 0, sizeof(Tracks));

 try
 {
  ImageOpen(path, image_memcache);
 }
 catch(...)
 {
  Cleanup();
  throw;
 }
}

CDAccess_Image::~CDAccess_Image()
{
 Cleanup();
}

void CDAccess_Image::Read_Raw_Sector(uint8 *buf, int32 lba)
{
  uint8 SimuQ[0xC];
  int32 track;
  CDRFILE_TRACK_INFO *ct;

  //
  // Leadout synthesis
  //
  if(lba >= total_sectors)
  {
   uint8 data_synth_mode = (disc_type == DISC_TYPE_CD_XA ? 0x02 : 0x01);

   switch(Tracks[LastTrack].DIFormat)
   {
    case DI_FORMAT_AUDIO:
		break;

    case DI_FORMAT_MODE1_RAW:
    case DI_FORMAT_MODE1:
		data_synth_mode = 0x01;
		break;

    case DI_FORMAT_MODE2_RAW:
    case DI_FORMAT_MODE2_FORM1:
    case DI_FORMAT_MODE2_FORM2:
    case DI_FORMAT_MODE2:
    case DI_FORMAT_CDI_RAW:
		data_synth_mode = 0x02;
		break;
   }

   synth_leadout_sector_lba(data_synth_mode, toc, lba, buf);
   return;
  }
  //
  //
  //

  memset(buf + 2352, 0, 96);
  track = MakeSubPQ(lba, buf + 2352);
  subq_deinterleave(buf + 2352, SimuQ);

  ct = &Tracks[track];

  //
  // Handle pregap and postgap reading
  //
  if(lba < (ct->LBA - ct->pregap_dv) || lba >= (ct->LBA + ct->sectors))
  {
   int32 pg_offset = lba - ct->LBA;
   CDRFILE_TRACK_INFO* et = ct;

   if(pg_offset < -150)
   {
    if((Tracks[track].subq_control & SUBQ_CTRLF_DATA) && (FirstTrack < track) && !(Tracks[track - 1].subq_control & SUBQ_CTRLF_DATA))
     et = &Tracks[track - 1];
   }

   memset(buf, 0, 2352);
   switch(et->DIFormat)
   {
    case DI_FORMAT_AUDIO:
		break;

    case DI_FORMAT_MODE1_RAW:
    case DI_FORMAT_MODE1:
		encode_mode1_sector(lba + 150, buf);
		break;

    case DI_FORMAT_MODE2_RAW:
    case DI_FORMAT_MODE2_FORM1:
    case DI_FORMAT_MODE2_FORM2:
    case DI_FORMAT_MODE2:
    case DI_FORMAT_CDI_RAW:
	 	buf[12 +  6] = 0x20;
		buf[12 + 10] = 0x20;
		encode_mode2_form2_sector(lba + 150, buf);
		// TODO: Zero out optional(?) checksum bytes?
		break;
   }
   //printf("Pre/post-gap read, LBA=%d(LBA-track_start_LBA=%d)\n", lba, lba - ct->LBA);
  }
  else
  {
   if(ct->AReader)
   {
    int16 AudioBuf[588 * 2];
    uint64 frames_read = ct->AReader->Read((ct->FileOffset / 4) + (lba - ct->LBA) * 588, AudioBuf, 588);

    ct->LastSamplePos += frames_read;

    if(frames_read > 588)	// This shouldn't happen.
    {
     printf("Error: frames_read out of range: %llu\n", (unsigned long long)frames_read);
     frames_read = 0;
    }

    if(frames_read < 588)
     memset((uint8 *)AudioBuf + frames_read * 2 * sizeof(int16), 0, (588 - frames_read) * 2 * sizeof(int16));

    for(int i = 0; i < 588 * 2; i++)
     MDFN_en16lsb(buf + i * 2, AudioBuf[i]);
   }
   else	// Binary, woo.
   {
    long SeekPos = ct->FileOffset;
    long LBARelPos = lba - ct->LBA;

    SeekPos += LBARelPos * DI_Size_Table[ct->DIFormat];

    if(ct->SubchannelMode)
     SeekPos += 96 * (lba - ct->LBA);

    ct->fp->seek(SeekPos, SEEK_SET);

    switch(ct->DIFormat)
    {
	case DI_FORMAT_AUDIO:
		ct->fp->read(buf, 2352);

		if(ct->RawAudioMSBFirst)
		 Endian_A16_Swap(buf, 588 * 2);
		break;

	case DI_FORMAT_MODE1:
		ct->fp->read(buf + 12 + 3 + 1, 2048);
		encode_mode1_sector(lba + 150, buf);
		break;

	case DI_FORMAT_MODE1_RAW:
	case DI_FORMAT_MODE2_RAW:
	case DI_FORMAT_CDI_RAW:
		ct->fp->read(buf, 2352);
		break;

	case DI_FORMAT_MODE2:
		ct->fp->read(buf + 16, 2336);
		encode_mode2_sector(lba + 150, buf);
		break;


	// FIXME: M2F1, M2F2, does sub-header come before or after user data(standards say before, but I wonder
	// about cdrdao...).
	case DI_FORMAT_MODE2_FORM1:
		ct->fp->read(buf + 24, 2048);
		//encode_mode2_form1_sector(lba + 150, buf);
		break;

	case DI_FORMAT_MODE2_FORM2:
		ct->fp->read(buf + 24, 2324);
		//encode_mode2_form2_sector(lba + 150, buf);
		break;

    }

    if(ct->SubchannelMode)
     ct->fp->read(buf + 2352, 96);
   }
  } // end if audible part of audio track read.
}

bool CDAccess_Image::Fast_Read_Raw_PW_TSRE(uint8* pwbuf, int32 lba) const noexcept
{
 int32 track;

 if(lba >= total_sectors)
 {
  subpw_synth_leadout_lba(toc, lba, pwbuf);
  return(true);
 }

 memset(pwbuf, 0, 96);
 try
 {
  track = MakeSubPQ(lba, pwbuf);
 }
 catch(...)
 {
  return(false);
 }

 //
 // If TOC+BIN has embedded subchannel data, we can't fast-read(synthesize) it...
 //
 if(Tracks[track].SubchannelMode && lba >= (Tracks[track].LBA - Tracks[track].pregap_dv) && (lba < Tracks[track].LBA + Tracks[track].sectors))
  return(false);

 return(true);
}

//
// Note: this function makes use of the current contents(as in |=) in SubPWBuf.
//
int32 CDAccess_Image::MakeSubPQ(int32 lba, uint8 *SubPWBuf) const
{
 uint8 buf[0xC];
 int32 track;
 uint32 lba_relative;
 uint32 ma, sa, fa;
 uint32 m, s, f;
 uint8 pause_or = 0x00;
 bool track_found = false;

 for(track = FirstTrack; track < (FirstTrack + NumTracks); track++)
 {
  if(lba >= (Tracks[track].LBA - Tracks[track].pregap_dv - Tracks[track].pregap) && lba < (Tracks[track].LBA + Tracks[track].sectors + Tracks[track].postgap))
  {
   track_found = true;
   break;
  }
 }

 if(!track_found)
  throw(MDFN_Error(0, _("Could not find track for sector %u!"), lba));

 if(lba < Tracks[track].LBA)
  lba_relative = Tracks[track].LBA - 1 - lba;
 else
  lba_relative = lba - Tracks[track].LBA;

 f = (lba_relative % 75);
 s = ((lba_relative / 75) % 60);
 m = (lba_relative / 75 / 60);

 fa = (lba + 150) % 75;
 sa = ((lba + 150) / 75) % 60;
 ma = ((lba + 150) / 75 / 60);

 uint8 adr = 0x1; // Q channel data encodes position
 uint8 control = Tracks[track].subq_control;

 // Handle pause(D7 of interleaved subchannel byte) bit, should be set to 1 when in pregap or postgap.
 if((lba < Tracks[track].LBA) || (lba >= Tracks[track].LBA + Tracks[track].sectors))
 {
  //printf("pause_or = 0x80 --- %d\n", lba);
  pause_or = 0x80;
 }

 // Handle pregap between audio->data track
 {
  int32 pg_offset = (int32)lba - Tracks[track].LBA;

  // If we're more than 2 seconds(150 sectors) from the real "start" of the track/INDEX 01, and the track is a data track,
  // and the preceding track is an audio track, encode it as audio(by taking the SubQ control field from the preceding track).
  //
  // TODO: Look into how we're supposed to handle subq control field in the four combinations of track types(data/audio).
  //
  if(pg_offset < -150)
  {
   if((Tracks[track].subq_control & SUBQ_CTRLF_DATA) && (FirstTrack < track) && !(Tracks[track - 1].subq_control & SUBQ_CTRLF_DATA))
   {
    //printf("Pregap part 1 audio->data: lba=%d track_lba=%d\n", lba, Tracks[track].LBA);
    control = Tracks[track - 1].subq_control;
   }
  }
 }


 memset(buf, 0, 0xC);
 buf[0] = (adr << 0) | (control << 4);
 buf[1] = U8_to_BCD(track);

 // Index
 //if(lba < Tracks[track].LBA) // Index is 00 in pregap
 // buf[2] = U8_to_BCD(0x00);
 //else
 // buf[2] = U8_to_BCD(0x01);
 {
  int index = 0;

  for(int32 i = 0; i < 100; i++)
  {
   if(lba >= Tracks[track].index[i])
    index = i;
  }
  buf[2] = U8_to_BCD(index);
 }

 // Track relative MSF address
 buf[3] = U8_to_BCD(m);
 buf[4] = U8_to_BCD(s);
 buf[5] = U8_to_BCD(f);

 buf[6] = 0; // Zerroooo

 // Absolute MSF address
 buf[7] = U8_to_BCD(ma);
 buf[8] = U8_to_BCD(sa);
 buf[9] = U8_to_BCD(fa);

 subq_generate_checksum(buf);

 if(!SubQReplaceMap.empty())
 {
  //printf("%d\n", lba);
  auto it = SubQReplaceMap.find(LBA_to_ABA(lba));

  if(it != SubQReplaceMap.end())
  {
   //printf("Replace: %d\n", lba);
   memcpy(buf, it->second.data(), 12);
  }
 }

 for(int i = 0; i < 96; i++)
  SubPWBuf[i] |= (((buf[i >> 3] >> (7 - (i & 0x7))) & 1) ? 0x40 : 0x00) | pause_or;

 return track;
}

void CDAccess_Image::Read_TOC(TOC *rtoc)
{
 *rtoc = toc;
}

void CDAccess_Image::GenerateTOC(void)
{
 toc.Clear();

 toc.first_track = FirstTrack;
 toc.last_track = FirstTrack + NumTracks - 1;
 toc.disc_type = disc_type;

 for(int i = FirstTrack; i < FirstTrack + NumTracks; i++)
 {
  if(Tracks[i].DIFormat == DI_FORMAT_CDI_RAW)
  {
   toc.first_track = std::min<int>(99, i + 1);
   toc.last_track = std::max<int>(toc.first_track, toc.last_track);
  }

  toc.tracks[i].lba = Tracks[i].LBA;
  toc.tracks[i].adr = ADR_CURPOS;
  toc.tracks[i].control = Tracks[i].subq_control;
  toc.tracks[i].valid = true;
 }

 toc.tracks[100].lba = total_sectors;
 toc.tracks[100].adr = ADR_CURPOS;
 toc.tracks[100].control = Tracks[FirstTrack + NumTracks - 1].subq_control;
 toc.tracks[100].valid = true;
}


