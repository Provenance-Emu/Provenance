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

#include <mednafen/types.h>
#include "Stream.h"

#include <stdlib.h>
#include <trio/trio.h>

Stream::Stream()
{

}

Stream::~Stream()
{

}

uint64 Stream::read_discard(uint64 count)
{
 uint8 buf[1024];
 uint64 tmp;
 uint64 ret = 0;

 do
 {
  tmp = read(buf, std::min<uint64>(count, sizeof(buf)), false);
  count -= tmp;
  ret += tmp;
 } while(tmp == sizeof(buf));

 return ret;
}

uint64 Stream::alloc_and_read(void** data_out, uint64 size_limit)
{
 uint8 *data_buffer = NULL;
 uint64 data_buffer_size = 0;
 uint64 data_buffer_alloced = 0;

 try
 {
  if(attributes() & ATTRIBUTE_SLOW_SIZE)
  {
   uint64 rti;

   data_buffer_size = 0;
   data_buffer_alloced = 65536;

   if(!(data_buffer = (uint8*)realloc(data_buffer, data_buffer_alloced)))
    throw MDFN_Error(ErrnoHolder(errno));

   while((rti = read(data_buffer + data_buffer_size, data_buffer_alloced - data_buffer_size, false)) > 0)
   {
    uint8* new_data_buffer;

    data_buffer_size += rti;

    if(data_buffer_size == data_buffer_alloced)
    {
     data_buffer_alloced <<= 1;

     if(data_buffer_alloced > size_limit)	// So we can test against our size limit without going far far over it in temporary memory allocations.
      data_buffer_alloced = size_limit + 1;

     if(data_buffer_size > size_limit)
      throw MDFN_Error(0, _("Size limit of %llu bytes would be exceeded."), (unsigned long long)size_limit);

     if(!(new_data_buffer = (uint8 *)realloc(data_buffer, data_buffer_alloced)))
      throw MDFN_Error(ErrnoHolder(errno));
     data_buffer = new_data_buffer;
    }
    else	// EOS
     break;
   }

   if(data_buffer_alloced > data_buffer_size)
   {
    uint8 *new_data_buffer;
  
    new_data_buffer = (uint8*)realloc(data_buffer, data_buffer_size);

    if(new_data_buffer != NULL)
    {
     data_buffer = new_data_buffer;
     data_buffer_alloced = data_buffer_size;
    }
   }
  }
  else
  {
   data_buffer_size = size();
   data_buffer_alloced = data_buffer_size;

   if(data_buffer_size > size_limit)
    throw MDFN_Error(0, _("Size limit of %llu bytes would be exceeded."), (unsigned long long)size_limit);

   if(data_buffer_alloced > SIZE_MAX)
    throw MDFN_Error(ErrnoHolder(ENOMEM));

   if(!(data_buffer = (uint8*)realloc(data_buffer, data_buffer_alloced)))
    throw MDFN_Error(ErrnoHolder(errno));

   read(data_buffer, data_buffer_size);
  }
 }
 catch(...)
 {
  if(data_buffer)
  {
   free(data_buffer);
   data_buffer = NULL;
  }
  throw;
 }

 *data_out = data_buffer;
 return data_buffer_size;
}

uint8* Stream::map(void) noexcept
{
 return(NULL);
}

uint64 Stream::map_size(void) noexcept
{
 return 0;
}

void Stream::unmap(void) noexcept
{

}

void Stream::put_line(const std::string& str)
{
 char l = '\n';

 write(&str[0], str.size());
 write(&l, sizeof(l));
}


void Stream::print_format(const char *format, ...)
{
 char *str = NULL;
 int rc;

 va_list ap;

 va_start(ap, format);

 rc = trio_vasprintf(&str, format, ap);

 va_end(ap);

 if(rc < 0)
  throw MDFN_Error(0, "Error in trio_vasprintf()");
 else
 {
  try	// Bleck
  {
   write(str, rc);
  }
  catch(...)
  {
   free(str);
   throw;
  }
  free(str);
 }
}

int Stream::get_line(std::string &str)
{
 uint8 c;

 str.clear();	// or str.resize(0)??

 while(read(&c, sizeof(c), false) > 0)
 {
  if(c == '\r' || c == '\n' || c == 0)
   return(c);

  str.push_back(c);
 }

 return(str.length() ? 256 : -1);
}

