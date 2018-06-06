/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* GZFileStream.cpp:
**  Copyright (C) 2014-2016 Mednafen Team
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

#include <mednafen/mednafen.h>
#include "GZFileStream.h"

#include <trio/trio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

#include <zlib.h>

GZFileStream::GZFileStream(const std::string& path, const MODE mode, const int level) : OpenedMode(mode)
{
 char zmode[16];
 int open_flags;
 int tmpfd;
 auto perm_mode = S_IRUSR | S_IWUSR;

 path_save = path;

 #if defined(S_IRGRP)
 perm_mode |= S_IRGRP;
 #endif

 #if defined(S_IROTH) 
 perm_mode |= S_IROTH;
 #endif

 if(mode == MODE::READ)
 {
  open_flags = O_RDONLY;
  trio_snprintf(zmode, sizeof(zmode), "rb");
 }
 else if(mode == MODE::WRITE)
 {
  open_flags = O_WRONLY | O_CREAT | O_TRUNC;
  
  if(level >= 0)
   trio_snprintf(zmode, sizeof(zmode), "wb%u", level);
  else
   trio_snprintf(zmode, sizeof(zmode), "wbT");
 }
 else
  abort();

 #ifdef O_BINARY
  open_flags |= O_BINARY;
 #elif defined(_O_BINARY)
  open_flags |= _O_BINARY;
 #endif

 #ifdef WIN32
 {
  bool invalid_utf8;
  std::u16string u16path = UTF8_to_UTF16(path, &invalid_utf8, true);

  if(invalid_utf8)
   throw MDFN_Error(EINVAL, _("Error opening file \"%s\": %s"), path_save.c_str(), _("Invalid UTF-8 in path."));

  tmpfd = ::_wopen((const wchar_t*)u16path.c_str(), open_flags, perm_mode);
 }
 #else
 tmpfd = ::open(path.c_str(), open_flags, perm_mode);
 #endif

 if(tmpfd == -1)
 {
  ErrnoHolder ene(errno);

  throw MDFN_Error(ene.Errno(), _("Error opening file \"%s\": %s"), path_save.c_str(), ene.StrError());
 }

 // Clear errno to 0 so can we detect internal zlib errors.
 errno = 0;
 gzp = gzdopen(tmpfd, zmode);

 if(!gzp)
 {
  ErrnoHolder ene(errno);

  ::close(tmpfd);

  throw MDFN_Error(ene.Errno(), _("Error opening file \"%s\": %s"), path_save.c_str(), (ene.Errno() == 0) ? _("zlib error") : ene.StrError());
 }
}

GZFileStream::~GZFileStream()
{
 try
 {
  close();
 }
 catch(std::exception &e)
 {
  MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
 }
}

void GZFileStream::close(void)
{
 if(gzp != NULL)
 {
  gzFile tmp = gzp;

  gzp = NULL;

  if(gzclose(tmp) != Z_OK)
  {
   throw MDFN_Error(0, _("Error closing opened file \"%s\"."), path_save.c_str());
  }
 }
}

uint64 GZFileStream::read(void *data, uint64 count, bool error_on_eof)
{
 const auto read_count = gzread(gzp, data, count);

 if(read_count == -1)
 {
  int errnum;
  const char* errstring;

  errstring = gzerror(gzp, &errnum);
  throw MDFN_Error(0, _("Error reading from opened file \"%s\": %s"), path_save.c_str(), errstring);
 }

 const uint64 read_count_u64 = (std::make_unsigned<decltype(read_count)>::type)read_count;

 if(read_count_u64 != count && error_on_eof)
  throw MDFN_Error(0, _("Error reading from opened file \"%s\": %s"), path_save.c_str(), _("Unexpected EOF"));

 return(read_count_u64);
}

int GZFileStream::get_line(std::string &str)
{
 int c;

 str.clear();

 while((c = gzgetc(gzp)) >= 0)
 {
  if(c == '\r' || c == '\n' || c == 0)
   return(c);

  str.push_back(c);
 }

 if(c == -1 && !gzeof(gzp))
 {
  int errnum;
  const char* errstring;

  errstring = gzerror(gzp, &errnum);
  throw MDFN_Error(0, _("Error reading from opened file \"%s\": %s"), path_save.c_str(), errstring);
 }

 return(str.length() ? 256 : -1);
}

void GZFileStream::flush(void)
{
 int errnum;

 errnum = gzflush(gzp, Z_FINISH);
 if(errnum != Z_OK)
 {
  //ErrnoHolder ene(errno);
  const char* errstring;

  errstring = gzerror(gzp, &errnum);
  throw MDFN_Error(0, _("Error flushing to opened file \"%s\": %s"), path_save.c_str(), errstring);
 }
}

void GZFileStream::write(const void *data, uint64 count)
{
 const auto write_count = gzwrite(gzp, data, count);
 const uint64 write_count_u64 = (std::make_unsigned<decltype(write_count)>::type)write_count;

 if(write_count_u64 != count)
 {
  //ErrnoHolder ene(errno);
  int errnum;
  const char* errstring;

  errstring = gzerror(gzp, &errnum);
  throw MDFN_Error(0, _("Error writing to opened file \"%s\": %s"), path_save.c_str(), errstring);
 }
}

void GZFileStream::truncate(uint64 length)
{
 throw MDFN_Error(ErrnoHolder(ENOSYS));
}

void GZFileStream::seek(int64 offset, int whence)
{
 // TODO: Throw error if offset is beyond the range that can be represented by the gz*() offset type.
 if(gzseek(gzp, offset, whence) == -1)
 {
  //ErrnoHolder ene(errno);
  int errnum;
  const char* errstring;

  errstring = gzerror(gzp, &errnum);

  throw MDFN_Error(0, _("Error seeking in opened file \"%s\": %s"), path_save.c_str(), errstring);
 }
}

uint64 GZFileStream::size(void)
{
 const uint64 p = tell();

 if(OpenedMode == MODE::WRITE)
  return(p);
 else
 {
  uint64 s = 0;
  int c;

  rewind();

  while((c = get_char()) >= 0)
   s++;
  
  seek(p, SEEK_SET);

  return s;
 }
}

uint64 GZFileStream::tell(void)
{
 auto gofs = gztell(gzp);

 if(gofs == -1)
 {
  //ErrnoHolder ene(errno);
  int errnum;
  const char* errstring;

  errstring = gzerror(gzp, &errnum);

  throw MDFN_Error(0, _("Error getting position in opened file \"%s\": %s"), path_save.c_str(), errstring);
 }

 return (std::make_unsigned<decltype(gofs)>::type)gofs;
}


uint64 GZFileStream::attributes(void)
{
 uint64 ret = ATTRIBUTE_SEEKABLE | ATTRIBUTE_SLOW_SEEK | ATTRIBUTE_SLOW_SIZE;

 switch(OpenedMode)
 {
  case MODE::READ:
        ret |= ATTRIBUTE_READABLE;
        break;

  case MODE::WRITE:
        ret |= ATTRIBUTE_WRITEABLE;
        break;
 }

 return ret;
}
