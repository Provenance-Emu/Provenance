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

#include <mednafen/mednafen.h>
#include "GZFileStream.h"

#include <trio/trio.h>
#include <stdarg.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>

#include <zlib.h>

GZFileStream::GZFileStream(const std::string& path, const MODE mode, const int level) : OpenedMode(mode)
{
 path_save = path;

 // Clear errno to 0 so can we detect internal zlib errors.
 errno = 0;
 if(mode == MODE::READ)
  gzp = gzopen(path.c_str(), "rb");
 else if(mode == MODE::WRITE)
 {
  char tmp[16];

  if(level >= 0)
   trio_snprintf(tmp, sizeof(tmp), "wb%u", level);
  else
   trio_snprintf(tmp, sizeof(tmp), "wbT");

  gzp = gzopen(path.c_str(), tmp);
 }
 else
  abort();

 if(!gzp)
 {
  ErrnoHolder ene(errno);

  throw(MDFN_Error(ene.Errno(), _("Error opening file \"%s\": %s"), path_save.c_str(), (ene.Errno() == 0) ? _("zlib error") : ene.StrError()));
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
  MDFND_PrintError(e.what());
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
