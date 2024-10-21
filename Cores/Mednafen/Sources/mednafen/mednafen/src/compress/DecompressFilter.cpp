/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* DecompressFilter.cpp:
**  Copyright (C) 2014-2021 Mednafen Team
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

// TODO: Seek testing.

#include <mednafen/mednafen.h>
#include "DecompressFilter.h"

#include <zlib.h>

namespace Mednafen
{

DecompressFilter::DecompressFilter(janky_ptr<Stream> source_stream, const std::string& vfc, uint64 csize, uint64 ucs, uint64 ucrc32) 
	: ss(std::move(source_stream)), ss_startpos(source_stream->tell()), ss_boundpos(ss_startpos + csize), ss_pos(ss_startpos), uc_size(ucs), running_crc32(0), expected_crc32(ucrc32), vfcontext(vfc)
{
 position = 0;
 target_position = 0;
}

DecompressFilter::~DecompressFilter()
{

}

void DecompressFilter::require_fast_seekable(void)
{
 throw MDFN_Error(0, _("Unable to perform fast seeks on %s."), vfcontext.c_str());
}

uint64 DecompressFilter::read_wrap(void* data, uint64 count)
{
 const uint64 ret = read_decompress(data, std::min<uint64>(uc_size - position, count));

 position += ret;

 assert(position <= uc_size);

 if(expected_crc32 != (uint64)-1)
 {
  // Obviously won't work right if we're read()'ing into weirdly-mapped memory. ;)
  for(uint64 i = 0, zlmax = ((uInt)(uint64)-1) >> 1; i != ret; i += std::min<uint64>(zlmax, ret - i))
   running_crc32 = crc32(running_crc32, (Bytef*)data + i, std::min<uint64>(zlmax, ret - i));

  if(position == uc_size)
  {
   if(running_crc32 != expected_crc32)
    throw MDFN_Error(0, _("Error reading from %s: %s"), vfcontext.c_str(), _("decompressed data fails CRC32 check"));
  }
 }

 return ret;
}

uint64 DecompressFilter::read(void *data, uint64 count, bool error_on_eos)
{
 uint64 ret = 0;

 if(!count)
  return ret;

 try
 {
  if(target_position < position)
  {
   //puts("REWIND");
   ss_pos = ss_startpos;
   position = 0;
   running_crc32 = 0;
   //
   reset_decompress();
  }

  if(ss->tell() != ss_pos)
   ss->seek(ss_pos, SEEK_SET);

  while(position < target_position)
  {
   //puts("Seek forward");
   uint8 dummy[4096];
   const uint64 toread = std::min<uint64>(target_position - position, sizeof(dummy));
   const uint64 dr = read_wrap(dummy, toread);

   if(MDFN_UNLIKELY(dr != toread))
    throw MDFN_Error(EINVAL, _("Error seeking in %s: Ran out of data while seeking to position %llu in compressed stream."), vfcontext.c_str(), (unsigned long long)target_position);
  }
  //
  //
  ret = read_wrap(data, count);

  target_position += ret;
  assert(position == target_position);
 }
 catch(...)
 {
  position = (uint64)-1;

  throw;
 }
 //
 //
 if(MDFN_UNLIKELY(ret < count && error_on_eos))
  throw MDFN_Error(0, _("Error reading from %s: %s"), vfcontext.c_str(), _("Unexpected EOF"));

 return ret;
}

void DecompressFilter::write(const void *data, uint64 count)
{
 throw MDFN_Error(ErrnoHolder(EINVAL));
}

void DecompressFilter::seek(int64 offset, int whence)
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
        new_position = target_position + offset;
        break;

   case SEEK_END:
	new_position = size() + offset;
        break;
 }

 if(MDFN_UNLIKELY((int64)new_position < 0))
  throw MDFN_Error(EINVAL, _("Error seeking in %s: Attempted to seek to out-of-bounds position %llu in compressed stream."), vfcontext.c_str(), (unsigned long long)new_position);

 target_position = new_position;
}

uint64 DecompressFilter::tell(void)
{
 return target_position;
}

uint64 DecompressFilter::size(void)
{
 if(uc_size == (uint64)-1)
 {
  uint8 dummy[4096];

  while(read_wrap(dummy, sizeof(dummy)) == sizeof(dummy))
  {
   //
  }

  uc_size = position;
 }

 return uc_size;
}

void DecompressFilter::close(void)
{
 close_decompress();

 ss.reset();
}

uint64 DecompressFilter::attributes(void)
{
 uint64 ret = ss->attributes() & (ATTRIBUTE_READABLE | ATTRIBUTE_SEEKABLE);

 if(ret & ATTRIBUTE_SEEKABLE)
  ret |= ATTRIBUTE_SLOW_SEEK;

 if(uc_size == (uint64)-1)
  ret |= ATTRIBUTE_SLOW_SIZE;

 return ret;
}

void DecompressFilter::truncate(uint64 length)
{
 throw MDFN_Error(EINVAL, _("Error truncating %s: %s"), vfcontext.c_str(), _("DecompressFilter::truncate() not implemented"));
}

void DecompressFilter::flush(void)
{
 throw MDFN_Error(EINVAL, _("Error flushing %s: %s"), vfcontext.c_str(), _("DecompressFilter::flush() not implemented"));
}

}
