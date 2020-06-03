/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* ExtMemStream.cpp:
**  Copyright (C) 2012-2018 Mednafen Team
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

#include "ExtMemStream.h"

namespace Mednafen
{

/*
 TODO:	Proper negative position behavior?
*/

ExtMemStream::ExtMemStream(void* p, uint64 s) : data_buffer((uint8*)p), data_buffer_size(s), ro(false), position(0)
{

}

ExtMemStream::ExtMemStream(const void* p, uint64 s) : data_buffer((uint8*)p), data_buffer_size(s), ro(true), position(0)
{

}

ExtMemStream::~ExtMemStream()
{
 close();
}

uint64 ExtMemStream::attributes(void)
{
 return (ATTRIBUTE_READABLE | ATTRIBUTE_WRITEABLE | ATTRIBUTE_SEEKABLE | ATTRIBUTE_INMEM_FAST);
}


uint8 *ExtMemStream::map(void) noexcept
{
 return data_buffer;
}

uint64 ExtMemStream::map_size(void) noexcept
{
 return data_buffer_size;
}

void ExtMemStream::unmap(void) noexcept
{

}


INLINE void ExtMemStream::grow_if_necessary(uint64 new_required_size, uint64 hole_end)
{
 if(new_required_size > data_buffer_size)
  throw MDFN_Error(0, _("Attempt to grow fixed size ExtMemStream."));
}

uint64 ExtMemStream::read(void *data, uint64 count, bool error_on_eos)
{
 //printf("%llu %llu %llu\n", position, count, data_buffer_size);

 if(count > data_buffer_size)
 {
  if(error_on_eos)
   throw MDFN_Error(0, _("Unexpected EOF"));

  count = data_buffer_size;
 }

 if(position > (data_buffer_size - count))
 {
  if(error_on_eos)
   throw MDFN_Error(0, _("Unexpected EOF"));

  if(data_buffer_size > position)
   count = data_buffer_size - position;
  else
   count = 0;
 }

 memmove(data, &data_buffer[position], count);
 position += count;

 return count;
}

void ExtMemStream::write(const void *data, uint64 count)
{
 uint64 nrs = position + count;

 if(ro)
  throw MDFN_Error(EINVAL, _("Write attempted to read-only ExtMemStream."));

 if(nrs < position)
  throw MDFN_Error(ErrnoHolder(EFBIG));

 grow_if_necessary(nrs, position);

 memmove(&data_buffer[position], data, count);
 position += count;
}

void ExtMemStream::truncate(uint64 length)
{
 grow_if_necessary(length, length);

 data_buffer_size = length;
}

void ExtMemStream::seek(int64 offset, int whence)
{
 uint64 new_position;

 switch(whence)
 {
  default:
	throw MDFN_Error(ErrnoHolder(EINVAL));
	break;

  case SEEK_SET:
	new_position = offset;
	break;

  case SEEK_CUR:
	new_position = position + offset;
	break;

  case SEEK_END:
	new_position = data_buffer_size + offset;
	break;
 }

 if(new_position < 0)
  throw MDFN_Error(ErrnoHolder(EINVAL));

 position = new_position;
}

uint64 ExtMemStream::tell(void)
{
 return position;
}

uint64 ExtMemStream::size(void)
{
 return data_buffer_size;
}

void ExtMemStream::flush(void)
{

}

void ExtMemStream::close(void)
{
 data_buffer = nullptr;
 data_buffer_size = 0;
 position = 0;
}


int ExtMemStream::get_line(std::string &str)
{
 str.clear();	// or str.resize(0)??

 while((uint64)position < data_buffer_size)
 {
  uint8 c = data_buffer[position++];

  if(c == '\r' || c == '\n' || c == 0)
   return(c);

  str.push_back(c);	// Should be faster than str.append(1, c)
 }

 return(str.length() ? 256 : -1);
}

}
