/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* MemoryStream.cpp:
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

#include "MemoryStream.h"

#ifdef WIN32
// For mswin_utf8_convert_kludge()
#include <mednafen/string/string.h>
#include <windows.h>
#endif

/*
 TODO:	Copy and assignment constructor fixes.
	
	Proper negative position behavior?
*/

MemoryStream::MemoryStream() : data_buffer(NULL), data_buffer_size(0), data_buffer_alloced(0), position(0)
{
 data_buffer_size = 0;
 data_buffer_alloced = 64;
 if(!(data_buffer = (uint8*)realloc(data_buffer, data_buffer_alloced)))
  throw MDFN_Error(ErrnoHolder(ENOMEM));
}

MemoryStream::MemoryStream(uint64 alloc_hint, int alloc_hint_is_size) : data_buffer(NULL), data_buffer_size(0), data_buffer_alloced(0), position(0)
{
 if(alloc_hint_is_size != 0)
 {
  data_buffer_size = alloc_hint;
  data_buffer_alloced = alloc_hint;

  if(alloc_hint > SIZE_MAX)
   throw MDFN_Error(ErrnoHolder(ENOMEM));
 }
 else
 {
  data_buffer_size = 0;
  data_buffer_alloced = (alloc_hint > SIZE_MAX) ? SIZE_MAX : alloc_hint;
 }

 data_buffer_alloced = std::max<uint64>(data_buffer_alloced, 1);

 if(!(data_buffer = (uint8*)realloc(data_buffer, data_buffer_alloced)))
  throw MDFN_Error(ErrnoHolder(ENOMEM));

 if(alloc_hint_is_size > 0)
  memset(data_buffer, 0, data_buffer_size);
}

MemoryStream::MemoryStream(Stream *stream, uint64 size_limit) : data_buffer(NULL), data_buffer_size(0), data_buffer_alloced(0), position(0)
{
 try
 {
  if((position = stream->tell()) != 0)
   stream->seek(0, SEEK_SET);

  void* tp;
  data_buffer_size = data_buffer_alloced = stream->alloc_and_read(&tp, size_limit);
  data_buffer = (uint8*)tp;
  stream->close();
 }
 catch(...)
 {
  if(data_buffer)
  {
   free(data_buffer);
   data_buffer = NULL;
  }

  delete stream;
  throw;
 }
 delete stream;
}

MemoryStream::MemoryStream(const MemoryStream &zs)
{
 data_buffer_size = zs.data_buffer_size;
 data_buffer_alloced = zs.data_buffer_alloced;
 if(!(data_buffer = (uint8*)malloc(data_buffer_alloced)))
  throw MDFN_Error(ErrnoHolder(ENOMEM));

 memcpy(data_buffer, zs.data_buffer, data_buffer_size);

 position = zs.position;
}

#if 0
MemoryStream & MemoryStream::operator=(const MemoryStream &zs)
{
 if(this != &zs)
 {
  if(data_buffer)
  {
   free(data_buffer);
   data_buffer = NULL;
  }

  data_buffer_size = zs.data_buffer_size;
  data_buffer_alloced = zs.data_buffer_alloced;

  if(!(data_buffer = (uint8*)malloc(data_buffer_alloced)))
   throw MDFN_Error(ENOMEM);

  memcpy(data_buffer, zs.data_buffer, data_buffer_size);

  position = zs.position;
 }
 return(*this);
}
#endif

MemoryStream::~MemoryStream()
{
 close();
}

uint64 MemoryStream::attributes(void)
{
 return (ATTRIBUTE_READABLE | ATTRIBUTE_WRITEABLE | ATTRIBUTE_SEEKABLE);
}


uint8 *MemoryStream::map(void) noexcept
{
 return data_buffer;
}

uint64 MemoryStream::map_size(void) noexcept
{
 return data_buffer_size;
}

void MemoryStream::unmap(void) noexcept
{

}


INLINE void MemoryStream::grow_if_necessary(uint64 new_required_size, uint64 hole_end)
{
 if(new_required_size > data_buffer_size)
 {
  const uint64 old_data_buffer_size = data_buffer_size;

  if(new_required_size > data_buffer_alloced)
  {
   uint64 new_required_alloced = round_up_pow2(new_required_size);
   uint8 *new_data_buffer;

   // first condition will happen at new_required_size > (1ULL << 63) due to round_up_pow2() "wrapping".
   // second condition can occur when running on a 32-bit system.
   if(new_required_alloced < new_required_size || new_required_alloced > SIZE_MAX)
    new_required_alloced = SIZE_MAX;

   // If constrained alloc size isn't enough, throw an out-of-memory/address-space type error.
   if(new_required_alloced < new_required_size)
    throw MDFN_Error(ErrnoHolder(ENOMEM));

   if(!(new_data_buffer = (uint8*)realloc(data_buffer, new_required_alloced)))
    throw MDFN_Error(ErrnoHolder(ENOMEM));

   //
   // Assign all in one go after the realloc() so we don't leave our object in an inconsistent state if the realloc() fails.
   //
   data_buffer = new_data_buffer;
   data_buffer_size = new_required_size;
   data_buffer_alloced = new_required_alloced;
  }
  else
   data_buffer_size = new_required_size;

  if(hole_end > old_data_buffer_size)
   memset(data_buffer + old_data_buffer_size, 0, hole_end - old_data_buffer_size);
 }
}

void MemoryStream::shrink_to_fit(void) noexcept
{
 if(data_buffer_alloced > data_buffer_size)
 {
  uint8 *new_data_buffer;
  const uint64 new_data_buffer_alloced = std::max<uint64>(data_buffer_size, 1);

  new_data_buffer = (uint8*)realloc(data_buffer, new_data_buffer_alloced);

  if(new_data_buffer != NULL)
  {
   data_buffer = new_data_buffer;
   data_buffer_alloced = new_data_buffer_alloced;
  }
 }
}

uint64 MemoryStream::read(void *data, uint64 count, bool error_on_eos)
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

void MemoryStream::write(const void *data, uint64 count)
{
 uint64 nrs = position + count;

 if(nrs < position)
  throw MDFN_Error(ErrnoHolder(EFBIG));

 grow_if_necessary(nrs, position);

 memmove(&data_buffer[position], data, count);
 position += count;
}

//
// Don't add code to reduce the amount of memory allocated(when possible) without providing a 
// per-stream setting to disable that behavior.
//
void MemoryStream::truncate(uint64 length)
{
 grow_if_necessary(length, length);

 data_buffer_size = length;
}

void MemoryStream::seek(int64 offset, int whence)
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

uint64 MemoryStream::tell(void)
{
 return position;
}

uint64 MemoryStream::size(void)
{
 return data_buffer_size;
}

void MemoryStream::flush(void)
{

}

void MemoryStream::close(void)
{
 if(data_buffer)
 {
  free(data_buffer);
  data_buffer = NULL;
 }

 data_buffer_size = 0;
 data_buffer_alloced = 0;
 position = 0;
}


int MemoryStream::get_line(std::string &str)
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


void MemoryStream::mswin_utf8_convert_kludge(void)
{
#ifdef WIN32
 if(!UTF8_validate(map_size(), (char*)map(), true) && map_size() <= INT_MAX)
 {
  int req;

  if((req = MultiByteToWideChar(CP_ACP, 0, (char*)map(), map_size(), NULL, 0)) > 0)
  {
   std::unique_ptr<char16_t[]> ws(new char16_t[req]);

   if(MultiByteToWideChar(CP_ACP, 0, (char*)map(), map_size(), (wchar_t*)ws.get(), req) == req)
   {
    size_t fpnr = 0;

    if(UTF16_to_UTF8(ws.get(), req, (char*)map(), &fpnr, true))
    {
     truncate(fpnr);
     UTF16_to_UTF8(ws.get(), req, (char*)map(), &fpnr, true);
    }
   }
  }
 }
#endif
}
