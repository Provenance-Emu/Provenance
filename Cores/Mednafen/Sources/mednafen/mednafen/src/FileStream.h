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
#include "VirtualFS.h"

namespace Mednafen
{

class FileStream : public Stream
{
 public:

 // Convenience function so we don't need so many try { } catch { } for ENOENT
 static INLINE FileStream* open(const std::string& path, const uint32 mode, const int do_lock = false, const uint32 buffer_size = 4096)
 {
  try
  {
   return new FileStream(path, mode, do_lock, buffer_size);
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
  MODE_READ = VirtualFS::MODE_READ,

  MODE_READ_WRITE = VirtualFS::MODE_READ_WRITE,

  MODE_WRITE = VirtualFS::MODE_WRITE,
  MODE_WRITE_SAFE = VirtualFS::MODE_WRITE_SAFE,	// Will throw an exception instead of overwriting an existing file.
  MODE_WRITE_INPLACE = VirtualFS::MODE_WRITE_INPLACE,	// Like MODE_WRITE, but won't truncate the file if it already exists.
 };

 FileStream(const std::string& path, const uint32 mode, const int do_lock = false, const uint32 buffer_size = 4096);
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
  unsigned char ret;

  if(buf_read_offs < buf_read_avail)
  {
   ret = buf[buf_read_offs++];
   pos++;
  }
  else if(!read(&ret, 1, false))
   return -1;

  return ret;
 }

 void set_buffer_size(uint32 new_size);

 private:
 FileStream & operator=(const FileStream &);    // Assignment operator
 FileStream(const FileStream &);		// Copy constructor
 //FileStream(FileStream &);                // Copy constructor

 void lock(bool nb);
 void unlock(void);

 uint64 read_ub(void* data, uint64 count);
 uint64 write_ub(const void* data, uint64 count);
 void write_buffered_data(void);

 int fd;
 uint64 pos;

 std::unique_ptr<uint8[]> buf;
 uint32 buf_size;
 uint32 buf_write_offs;
 uint32 buf_read_offs;
 uint32 buf_read_avail;

 bool need_real_seek;

 uint64 locked;

 void* mapping;
 uint64 mapping_size;

 const uint32 OpenedMode;
 const std::string path_save;
};

}
#endif
