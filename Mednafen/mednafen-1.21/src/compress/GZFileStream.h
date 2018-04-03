/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* GZFileStream.h:
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

#ifndef __MDFN_GZFILESTREAM_H
#define __MDFN_GZFILESTREAM_H

#include <mednafen/Stream.h>

#include <zlib.h>

class GZFileStream : public Stream
{
 public:

 enum class MODE
 {
  READ = 0,
  WRITE = 1,
 };

 //
 // Pass negative value for level for raw(non-gzip) file access with MODE::WRITE.
 //
 GZFileStream(const std::string& path, const MODE mode, const int level = 6);
 virtual ~GZFileStream() override;

 virtual uint64 attributes(void) override;

 virtual uint64 read(void *data, uint64 count, bool error_on_eos = true) override;
 virtual void write(const void *data, uint64 count) override;
 virtual void truncate(uint64 length) override;
 virtual void seek(int64 offset, int whence) override;
 virtual uint64 tell(void) override;
 virtual uint64 size(void) override;
 virtual void close(void) override;
 virtual void flush(void) override;
 INLINE int get_char(void)
 {
  int c;

  c = gzgetc(gzp);

  if(MDFN_UNLIKELY(c == -1 && !gzeof(gzp)))
  {
   int errnum;
   const char* errstring;

   errstring = gzerror(gzp, &errnum);
   throw MDFN_Error(0, _("Error reading from opened file \"%s\": %s"), path_save.c_str(), errstring);
  }
  return(c);
 }

 virtual int get_line(std::string &str) override;

 private:

 GZFileStream & operator=(const GZFileStream &);    // Assignment operator
 GZFileStream(const GZFileStream &);              // Copy constructor

 gzFile gzp;
 const MODE OpenedMode;
 std::string path_save;
};



#endif
