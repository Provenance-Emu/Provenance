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

// TODO: Seek testing and fixes, ensure will work for >2GB streams(see zs.total_out, zs.avail_out usage) on 32-bit platforms

#include <mednafen/types.h>
#include "ZLInflateFilter.h"
#include <mednafen/mednafen.h>

ZLInflateFilter::ZLInflateFilter(Stream *source_stream, FORMAT df, uint64 csize, uint64 ucs) 
	: ss(source_stream), ss_startpos(source_stream->tell()), ss_boundpos(ss_startpos + csize), uc_size(ucs)
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
  throw MDFN_Error(0, _("zlib error: %d"), irc);

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
  MDFND_PrintError(e.what());
 }
}

uint64 ZLInflateFilter::read(void *data, uint64 count, bool error_on_eos)
{
 zs.next_out = (Bytef*)data;
 zs.avail_out = count;

 while((uint64)(zs.next_out - (Bytef*)data) < count)
 {
  if(!zs.avail_in)
  {
   uint64 rc = ss->read(buf, std::min<uint64>(sizeof(buf), ss_boundpos - ss->tell()), false);
   zs.next_in = buf;
   zs.avail_in = rc;
  }

  bool no_more_input = !zs.avail_in;
  int irc;

  zs.total_out = 0;
  irc = inflate(&zs, no_more_input ? Z_SYNC_FLUSH : Z_NO_FLUSH);
  if(MDFN_UNLIKELY(irc < 0))
   throw MDFN_Error(0, _("zlib error %d"), irc);
  position += zs.total_out;

  if(no_more_input)
  {
   //if(irc != Z_STREAM_END)
   // throw MDFN_Error(0, _("Ran out of data for inflate(), but not at

   break;
  }
 }

 uint64 ret = zs.next_out - (Bytef*)data;
 assert(ret <= count);

 if(MDFN_UNLIKELY(ret < count && error_on_eos))
 {
  throw MDFN_Error(0, _("Unexpected EOF"));
 }

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
	 throw MDFN_Error(EINVAL, _("Attempted to seek relative to end-of-file in deflate-compressed stream of indeterminate uncompressed size."));
	else
	 new_position = uc_size + offset;
        break;
 }

 if(MDFN_UNLIKELY((int64)new_position < 0 || new_position > uc_size))
  throw MDFN_Error(EINVAL, _("Attempted to seek to out-of-bounds position %llu in deflate-compressed stream."), (unsigned long long)new_position);

 if(new_position < position)
 {
  int irc = inflateReset(&zs);

  if(MDFN_UNLIKELY(irc < 0))
   throw MDFN_Error(0, _("zlib error %d"), irc);

  ss->seek(ss_startpos, SEEK_SET);
  position = 0;
 }

 while(position < new_position)
 {
  uint8 dummy[4096];
  uint64 toread = std::min<uint64>(new_position - position, sizeof(dummy));

  if(MDFN_UNLIKELY(read(dummy, toread, false) != toread))
   throw MDFN_Error(EINVAL, _("Ran out of data while seeking to position %llu in deflate-compressed stream."), (unsigned long long)new_position);
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

