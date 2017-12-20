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
 Notes:
	For performance reasons(like in the state rewinding code), we should try to make sure map()
	returns a pointer that is aligned to at least what malloc()/realloc() provides.
	(And maybe forcefully align it to at least 16 bytes in the future)
*/

#ifndef __MDFN_MEMORYSTREAM_H
#define __MDFN_MEMORYSTREAM_H

#include "Stream.h"

class MemoryStream : public Stream
{
 public:

 MemoryStream();
 MemoryStream(uint64 alloc_hint, int alloc_hint_is_size = false);	// Pass -1 instead of 1 for alloc_hint_is_size to skip initialization of the memory.
 MemoryStream(Stream *stream, uint64 size_limit = ~(uint64)0);
				// Will create a MemoryStream equivalent of the contents of "stream", and then "delete stream".
				// Will only work if stream->tell() == 0, or if "stream" is seekable.
				// stream will be deleted even if this constructor throws.
				//
				// Will throw an exception if the initial size() of the MemoryStream would be greater than size_limit(useful for when passing
				// in GZFileStream streams).

 MemoryStream(const MemoryStream &zs);
 MemoryStream & operator=(const MemoryStream &zs);

 virtual ~MemoryStream() override;

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

 void shrink_to_fit(void) noexcept;	// Minimizes alloced memory.

 private:
 uint8 *data_buffer;
 uint64 data_buffer_size;
 uint64 data_buffer_alloced;

 uint64 position;

 void grow_if_necessary(uint64 new_required_size, uint64 hole_end);
};
#endif
