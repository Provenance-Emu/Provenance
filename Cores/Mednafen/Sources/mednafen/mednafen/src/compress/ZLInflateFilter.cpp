/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* ZLInflateFilter.cpp:
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

#include <mednafen/mednafen.h>
#include "ZLInflateFilter.h"

namespace Mednafen
{

ZLInflateFilter::ZLInflateFilter(janky_ptr<Stream> source_stream, const std::string& vfc, FORMAT df, uint64 csize, uint64 ucs, uint64 ucrc32) 
	: DecompressFilter(std::move(source_stream), vfc, csize, ucs, ucrc32)
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

void ZLInflateFilter::reset_decompress(void)
{
 zs.avail_in = 0;
 //
 int irc = inflateReset(&zs);

 if(MDFN_UNLIKELY(irc < 0))
  throw MDFN_Error(0, _("Error seeking in %s: inflateReset() failed: %d"), vfcontext.c_str(), irc);
}


uint64 ZLInflateFilter::read_decompress(void* data, uint64 count)
{
 bool stream_end = false;

 zs.next_out = (Bytef*)data;

 while((uint64)(zs.next_out - (Bytef*)data) < count)
 {
  zs.avail_out = std::min<uint64>(((uInt)(uint64)-1) >> 1, count - (zs.next_out - (Bytef*)data));
  //printf("%016llx %08x --- %016llx\n", (unsigned long long)count, zs.avail_out, (unsigned long long)(((uInt)(uint64)-1) >> 1));

  if(!zs.avail_in)
  {
   zs.next_in = buf;
   zs.avail_in = read_source(buf, sizeof(buf));
  }

  if(stream_end)
  {
   if(zs.avail_in)
   {
    //printf("inflateReset: %u\n", (unsigned)zs.avail_in);

    int reset_irc = inflateReset(&zs);

    //printf("inflateResetPost: %u\n", (unsigned)zs.avail_in);

    if(MDFN_UNLIKELY(reset_irc < 0))
     throw MDFN_Error(0, _("Error reading from %s: inflateReset() failed: %d"), vfcontext.c_str(), reset_irc);

    stream_end = false;
   }
   else
    break;
  }

  const bool no_more_input = !zs.avail_in;
  int irc;

  zs.total_out = 0;
  //printf("inflate: stream_end=%d, zs.avail_in=%d\n", stream_end, zs.avail_in);
  irc = inflate(&zs, no_more_input ? Z_SYNC_FLUSH : Z_NO_FLUSH);
  //printf(" return: %d\n", irc);
  if(MDFN_UNLIKELY(irc < 0))
  {
   if(irc == Z_DATA_ERROR)
    throw MDFN_Error(0, _("Error reading from %s: %s"), vfcontext.c_str(), zs.msg);
   else if(irc == Z_MEM_ERROR)
    throw MDFN_Error(0, _("Error reading from %s: %s"), vfcontext.c_str(), _("insufficient memory"));
   else
    throw MDFN_Error(0, _("Error reading from %s: zlib error %d"), vfcontext.c_str(), irc);
  }

  if(no_more_input)
  {
   //if(irc != Z_STREAM_END)
   // throw MDFN_Error(0, _("Ran out of data for inflate(), but not at
   break;
  }
  else if(irc == Z_STREAM_END)
   stream_end = true;
 }

 uint64 ret = zs.next_out - (Bytef*)data;
 assert(ret <= count);

 return ret;
}

void ZLInflateFilter::close_decompress(void)
{
 inflateEnd(&zs);
 memset(&zs, 0, sizeof(zs));
}

}
