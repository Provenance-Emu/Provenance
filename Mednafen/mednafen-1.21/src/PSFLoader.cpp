/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* PSFLoader.cpp:
**  Copyright (C) 2011-2016 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

/*
 TODO: Time string parsing convenience functions.
*/

#include "mednafen.h"
#include <mednafen/FileStream.h>
#include <mednafen/compress/ZLInflateFilter.h>
#include "PSFLoader.h"
#include "general.h"
#include <mednafen/string/string.h>

#include <trio/trio.h>
#include <iconv.h>

#include <zlib.h>

PSFTags::PSFTags()
{


}

PSFTags::~PSFTags()
{

}

void PSFTags::AddTag(char *tag_line)
{
 char *eq;

 // Transform 0x01-0x1F -> 0x20
 for(unsigned int i = 0; i < strlen(tag_line); i++)
  if((unsigned char)tag_line[i] < 0x20)
   tag_line[i] = 0x20;

 eq = strchr(tag_line, '=');

 if(eq)
 {
  *eq = 0;

  MDFN_trim(tag_line);
  MDFN_trim(eq + 1);
  MDFN_strazlower(tag_line);

  if(TagExists(tag_line))
   tags[tag_line] = tags[std::string(tag_line)] + std::string(1, '\n') + std::string(eq + 1);
  else
   tags[tag_line] = std::string(eq + 1);
 }
}

void PSFTags::LoadTags(Stream* fp)
{
 uint64 size = fp->size() - fp->tell();
 std::vector<char> tags_heap;
 char *data;
 char *spos;
 //const char *detected_charset = DetectCharset(data_in, size);

 tags_heap.resize(size + 1);
 tags_heap[size] = 0;

 fp->read(&tags_heap[0], size);

 data = &tags_heap[0];
 spos = data;

 while(size)
 {
  if(*data == 0x0A || *data == 0x00)
  {
   *data = 0;

   if(data - spos)
   {
    if(*(data - 1) == 0xD)	// handle \r
     *(data - 1) = 0;

    AddTag(spos);
   }

   spos = data + 1;	// Skip \n for next tag
  }

  size--;
  data++;
 }

 //
 // Check if utf8 tag exists and is set to a non-zero value, and if so, return.
 //
 if(TagExists("utf8"))
 {
  std::string tmp = GetTag("utf8");

  if(atoi(tmp.c_str()) != 0)
  {
   //puts("utf8");
   return;
  }
 }

 bool probably_ascii = true;

 for(auto& t : tags)
  for(auto& c : t.second)
   if(c & 0x80)
    probably_ascii = false;

 if(probably_ascii)
  return;

 //
 // Detect possible SJIS encoding, and convert tags.
 //
 {
  bool possibly_sjis = true;
  iconv_t sjis_utf8_cd;

  sjis_utf8_cd = iconv_open("UTF-8", "SJIS");
  if(sjis_utf8_cd == (iconv_t)-1)
   throw MDFN_Error(errno, "iconv_open() failed.");

  try
  {
   for(unsigned commit = 0; commit < 2 && possibly_sjis; commit++)
   {
    for(auto& t : tags)
    {
     std::string tmp;

     tmp.resize(t.second.size() * 7);
     size_t in_len = t.second.size();
     size_t out_len = tmp.size();
     char* in_ptr = (char *)&t.second[0];
     char* out_ptr = &tmp[0];

     if(iconv(sjis_utf8_cd, (ICONV_CONST char **)&in_ptr, &in_len, &out_ptr, &out_len) == (size_t)-1)
     {
      possibly_sjis = false;
      break;
     }
     else if(commit)
     {
      tmp.resize(out_ptr - &tmp[0]);
      t.second = tmp;
     }
    }
   }
  }
  catch(...)
  {
   iconv_close(sjis_utf8_cd);
   throw;
  }
  iconv_close(sjis_utf8_cd);

  if(possibly_sjis)
   return;
 }
}

int64 PSFTags::GetTagI(const char *name)
{
 std::map<std::string, std::string>::iterator it;

 it = tags.find(name);
 if(it != tags.end())
 {
  long long ret = 0;
  std::string &tmp = tags[name];

  trio_sscanf(tmp.c_str(), "%lld", &ret);

  return(ret);
 }
 return(0);	// INT64_MIN
}

bool PSFTags::TagExists(const char *name)
{
 if(tags.find(name) != tags.end())
  return(true);

 return(false);
}


std::string PSFTags::GetTag(const char *name)
{
 std::map<std::string, std::string>::iterator it;

 it = tags.find(name);

 if(it != tags.end())
  return(it->second);

 return("");
}

void PSFTags::EraseTag(const char *name)
{
 std::map<std::string, std::string>::iterator it;

 it = tags.find(name);
 if(it != tags.end())
  tags.erase(it);
}

PSFLoader::PSFLoader()
{


}

PSFLoader::~PSFLoader()
{


}

bool PSFLoader::TestMagic(uint8 version, Stream* fp)
{
 uint8 buf[3 + 1 + 4 + 4 + 4];
 uint64 rc;

 rc = fp->read(buf, sizeof(buf), false);
 fp->rewind();

 if(rc != sizeof(buf))
  return(false);

 if(memcmp(buf, "PSF", 3))
  return(false);

 if(buf[3] != version)
  return(false);

 return(true);
}

PSFTags PSFLoader::LoadInternal(uint8 version, uint32 max_exe_size, Stream *fp, uint32 level, bool force_ignore_pcsp)
{
 uint32 reserved_size, compressed_size, compressed_crc32;
 bool _lib_present = false;
 PSFTags tags;
 uint8 raw_header[16];

 fp->read(raw_header, 16);

 if(memcmp(raw_header, "PSF", 3) || raw_header[3] != version)
  throw(MDFN_Error(0, _("Not a PSF(version=0x%02x) file!"), version));

 reserved_size = MDFN_de32lsb(&raw_header[4]);
 compressed_size = MDFN_de32lsb(&raw_header[8]);
 compressed_crc32 = MDFN_de32lsb(&raw_header[12]);

 (void)compressed_crc32;

 //
 // Load tags.
 //
 {
  uint8 theader[5];

  fp->seek(16 + reserved_size + compressed_size);

  if(fp->read(theader, 5, false) == 5 && !memcmp(theader, "[TAG]", 5))
   tags.LoadTags(fp);
 }

 //
 // Handle minipsf simple _lib
 //
 if(level < 15)
 {
  if(tags.TagExists("_lib"))
  {
   std::string tp = tags.GetTag("_lib");

   MDFN_CheckFIROPSafe(tp);
   //
   //
   //
   FileStream subfile(MDFN_MakeFName(MDFNMKF_AUX, 0, tp.c_str()).c_str(), FileStream::MODE_READ);

   LoadInternal(version, max_exe_size, &subfile, level + 1);

   _lib_present = true;
  }
 }

 //
 // Handle reserved section.
 //
 {
  fp->seek(16);
  HandleReserved(fp, reserved_size);
 }

 //
 // Handle compressed EXE section
 //
 {
  fp->seek(16 + reserved_size);
  ZLInflateFilter ifs(fp, "<Compressed EXE section of PSF>", ZLInflateFilter::FORMAT::ZLIB, compressed_size);
  HandleEXE(&ifs, force_ignore_pcsp | _lib_present);
 }

 //
 // handle libN
 //
 if(level < 15)
 {
  for(unsigned int n = 2; n <= INT_MAX; n++)
  {
   char tmpbuf[32];

   trio_snprintf(tmpbuf, 32, "_lib%d", (int)n);

   if(tags.TagExists(tmpbuf))
   {
    FileStream subfile(MDFN_MakeFName(MDFNMKF_AUX, 0, tags.GetTag(tmpbuf).c_str()).c_str(), FileStream::MODE_READ);

    LoadInternal(version, max_exe_size, &subfile, level + 1, true);
   }
   else
    break;   
  }
 }

 return(tags);
}

PSFTags PSFLoader::Load(uint8 version, uint32 max_exe_size, Stream* fp)
{
 return(LoadInternal(version, max_exe_size, fp, 0, false));
}

void PSFLoader::HandleReserved(Stream* fp, uint32 len)
{
 fp->seek(len, SEEK_CUR);
}

void PSFLoader::HandleEXE(Stream* fp, bool ignore_pcsp)
{

}

