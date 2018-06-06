/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* FileStream.h:
**  Copyright (C) 2010-2016 Mednafen Team
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

#ifndef __MDFN_FILESTREAM_H
#define __MDFN_FILESTREAM_H

#include "Stream.h"

class FileStream : public Stream
{
 public:

 // Convenience function so we don't need so many try { } catch { } for ENOENT
 static INLINE FileStream* open(const std::string& path, const int mode, const int do_lock = false)
 {
  try
  {
   return new FileStream(path, mode, do_lock);
  }
  catch(MDFN_Error& e)
  {
   if(e.GetErrno() == ENOENT)
    return nullptr;

   throw;
  }
 }

 enum
 {
  MODE_READ = 0,

  MODE_READ_WRITE,	// Will create file if it doesn't already exist.  Will not truncate existing file.
			// Any necessary synchronization when switching between read and write operations is handled internally in
			// FileStream.

  MODE_WRITE,
  MODE_WRITE_SAFE,	// Will throw an exception instead of overwriting an existing file.
  MODE_WRITE_INPLACE,	// Like MODE_WRITE, but won't truncate the file if it already exists.
 };

 FileStream(const std::string& path, const int mode, const int do_lock = false);
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

  if(MDFN_UNLIKELY(prev_was_write == 1))
   seek(0, SEEK_CUR);

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

 bool locked;
 int prev_was_write;	// -1 for no state, 0 for last op was read, 1 for last op was write(used for MODE_READ_WRITE)

 //
 void lock(bool nb);
 void unlock(void);
};



#endif
