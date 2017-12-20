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

#ifndef __MDFN_FILESTREAM_H
#define __MDFN_FILESTREAM_H

#include "Stream.h"

#include <stdio.h>
#include <string>

class FileStream : public Stream
{
 public:

 enum
 {
  MODE_READ = 0,
  MODE_WRITE,
  MODE_WRITE_SAFE,	// Will throw an exception instead of overwriting an existing file.
  MODE_WRITE_INPLACE,	// Like MODE_WRITE, but won't truncate the file if it already exists.
 };

 FileStream(const std::string& path, const int mode);
 virtual ~FileStream() override;

 virtual uint64 attributes(void) override;

 virtual uint8 *map(void) noexcept override;
 virtual uint64 map_size(void) noexcept override;
 virtual void unmap(void) noexcept override;

 virtual uint64 read(void *data, uint64 count, bool error_on_eos = true) override;
 virtual void write(const void *data, uint64 count) override;
 virtual void truncate(uint64 length) override;
 virtual void seek(int64 offset, int whence) override;
 virtual uint64 tell(void) override;
 virtual uint64 size(void) override;
 virtual void flush(void) override;
 virtual void close(void) override;

 virtual int get_line(std::string &str) override;

 INLINE int get_char(void)
 {
  int ret;

  errno = 0;
  ret = fgetc(fp);

  if(MDFN_UNLIKELY(errno != 0))
  {
   ErrnoHolder ene(errno);
   throw(MDFN_Error(ene.Errno(), _("Error reading from opened file \"%s\": %s"), path_save.c_str(), ene.StrError()));
  }
  return(ret);
 }

 private:
 FileStream & operator=(const FileStream &);    // Assignment operator
 FileStream(const FileStream &);		// Copy constructor
 //FileStream(FileStream &);                // Copy constructor

 FILE *fp;
 std::string path_save;
 const int OpenedMode;

 void* mapping;
 uint64 mapping_size;
};



#endif
