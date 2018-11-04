/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* ZLInflateFilter.cpp:
**  Copyright (C) 2014-2018 Mednafen Team
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

// TODO: Seek testing and fixes, ensure will work for >2GB streams(see zs.total_out, zs.avail_out usage) on 32-bit platforms

#include <mednafen/types.h>
#include "ZLInflateFilter.h"
#include <mednafen/mednafen.h>

ZLInflateFilter::ZLInflateFilter(Stream *source_stream, const std::string& vfp, FORMAT df, uint64 csize, uint64 ucs, uint64 ucrc32) 
	: ss(source_stream), ss_startpos(source_stream->tell()), ss_boundpos(ss_startpos + csize), ss_pos(ss_startpos), uc_size(ucs), running_crc32(0), expected_crc32(ucrc32), vfpath(vfp)
{
 int irc;
 int iiwbits;

 switch(df)
 {
  default:
	abort();
	break;

  case FORMAT::RAW:
	iiwbits = 0 - 15;
	break;

  case FORMAT::ZLIB:
	iiwbits = 0 + 15;
	break;

  case FORMAT::GZIP:
	iiwbits = 16 + 15;
	break;

  case FORMAT::AUTO_ZGZ:
	iiwbits = 32 + 15;
	break;
 }

 memset(&zs, 0, sizeof(zs));
 irc = inflateInit2(&zs, iiwbits);

 if(MDFN_UNLIKELY(irc < 0))
  throw MDFN_Error(0, _("zlib inflateInit2() failed: %d"), irc);

 position = 0;
}

ZLInflateFilter::~ZLInflateFilter()
{
 try
 {
  close();
 }
 catch(std::exception &e)
 {
  MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
 }
}

uint64 ZLInflateFilter::read(void *data, uint64 count, bool error_on_eos)
{
 const uint64 count_limited = std::min<uint64>(uc_size - position, count);

 zs.next_out = (Bytef*)data;
 zs.avail_out = count_limited;

 while((uint64)(zs.next_out - (Bytef*)data) < count_limited)
 {
  if(!zs.avail_in)
  {
   if(ss->tell() != ss_pos)
    ss->seek(ss_pos, SEEK_SET);

   uint64 rc = ss->read(buf, std::min<uint64>(sizeof(buf), ss_boundpos - ss_pos), false);
   ss_pos += rc;
   zs.next_in = buf;
   zs.avail_in = rc;
  }

  bool no_more_input = !zs.avail_in;
  int irc;

  zs.total_out = 0;
  irc = inflate(&zs, no_more_input ? Z_SYNC_FLUSH : Z_NO_FLUSH);
  if(MDFN_UNLIKELY(irc < 0))
  {
   if(irc == Z_DATA_ERROR)
    throw MDFN_Error(0, _("Error reading from virtual file \"%s\": %s"), vfpath.c_str(), zs.msg);
   else if(irc == Z_MEM_ERROR)
    throw MDFN_Error(0, _("Error reading from virtual file \"%s\": %s"), vfpath.c_str(), _("insufficient memory"));
   else
    throw MDFN_Error(0, _("Error reading from virtual file \"%s\": zlib error %d"), vfpath.c_str(), irc);
  }
  position += zs.total_out;

  if(no_more_input)
  {
   //if(irc != Z_STREAM_END)
   // throw MDFN_Error(0, _("Ran out of data for inflate(), but not at

   break;
  }
 }

 uint64 ret = zs.next_out - (Bytef*)data;
 assert(ret <= count_limited);
 assert(position <= uc_size);

 if(expected_crc32 != ~(uint64)0)
 {
  // Obviously won't work right if we're read()'ing into weirdly-mapped memory. ;)
  running_crc32 = crc32/*_z*/(running_crc32, (Bytef*)data, ret);

  if(position == uc_size)
  {
   if(running_crc32 != expected_crc32)
    throw MDFN_Error(0, _("Error reading from virtual file \"%s\": %s"), vfpath.c_str(), _("decompressed data fails CRC32 check"));
  }
 }

 if(MDFN_UNLIKELY(ret < count && error_on_eos))
  throw MDFN_Error(0, _("Error reading from virtual file \"%s\": %s"), vfpath.c_str(), _("Unexpected EOF"));

 return ret;
}

void ZLInflateFilter::write(const void *data, uint64 count)
{
 throw MDFN_Error(ErrnoHolder(EINVAL));
}

void ZLInflateFilter::seek(int64 offset, int whence)
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
	if(MDFN_UNLIKELY(uc_size == ~(uint64)0))
         throw MDFN_Error(EINVAL, _("Error seeking in virtual file \"%s\": %s"), vfpath.c_str(), _("Attempted to seek relative to end-of-file in deflate-compressed stream of indeterminate uncompressed size."));
	else
	 new_position = uc_size + offset;
        break;
 }

 if(MDFN_UNLIKELY((int64)new_position < 0 || new_position > uc_size))
  throw MDFN_Error(EINVAL, _("Error seeking in virtual file \"%s\": Attempted to seek to out-of-bounds position %llu in deflate-compressed stream."), vfpath.c_str(), (unsigned long long)new_position);

 if(new_position < position)
 {
  int irc = inflateReset(&zs);

  if(MDFN_UNLIKELY(irc < 0))
   throw MDFN_Error(0, _("Error seeking in virtual file \"%s\": inflateReset() failed: %d"), vfpath.c_str(), irc);

  ss->seek(ss_startpos, SEEK_SET);
  ss_pos = ss_startpos;
  position = 0;
  running_crc32 = 0;
 }

 while(position < new_position)
 {
  uint8 dummy[4096];
  uint64 toread = std::min<uint64>(new_position - position, sizeof(dummy));

  if(MDFN_UNLIKELY(read(dummy, toread, false) != toread))
   throw MDFN_Error(EINVAL, _("Error seeking in virtual file \"%s\": Ran out of data while seeking to position %llu in deflate-compressed stream."), vfpath.c_str(), (unsigned long long)new_position);
 }
}

uint64 ZLInflateFilter::tell(void)
{
 return position;
}

uint64 ZLInflateFilter::size(void)
{
 if(uc_size == ~(uint64)0)
  throw MDFN_Error(ErrnoHolder(EINVAL));
 else
  return uc_size;
}

void ZLInflateFilter::close(void)
{
 inflateEnd(&zs);
 memset(&zs, 0, sizeof(zs));
}

uint64 ZLInflateFilter::attributes(void)
{
 uint64 ret = ss->attributes() & (ATTRIBUTE_READABLE | ATTRIBUTE_SEEKABLE);

 if(ret & ATTRIBUTE_SEEKABLE)
  ret |= ATTRIBUTE_SLOW_SEEK;

 if(uc_size == ~(uint64)0)
  ret |= ATTRIBUTE_SLOW_SIZE;

 return ret;
}

void ZLInflateFilter::truncate(uint64 length)
{
 throw MDFN_Error(ErrnoHolder(EINVAL));
}

void ZLInflateFilter::flush(void)
{
 throw MDFN_Error(ErrnoHolder(EINVAL));  
}

