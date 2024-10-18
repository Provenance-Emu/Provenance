/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* ZstdDecompressFilter.cpp:
**  Copyright (C) 2021 Mednafen Team
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
#include "ZstdDecompressFilter.h"

namespace Mednafen
{

ZstdDecompressFilter::ZstdDecompressFilter(janky_ptr<Stream> source_stream, const std::string& vfc, uint64 csize, uint64 ucs, uint64 ucrc32) 
	: DecompressFilter(std::move(source_stream), vfc, csize, ucs, ucrc32)
{
 if(!(zs = ZSTD_createDStream()))
  throw MDFN_Error(0, _("%s failed."), "ZSTD_createDStream()");

 reset_decompress();
}

void ZstdDecompressFilter::reset_decompress(void)
{
 const size_t res = ZSTD_initDStream(zs);
 if(ZSTD_isError(res))
  throw MDFN_Error(0, _("%s failed: %s"), "ZSTD_initDStream()", ZSTD_getErrorName(res));

 memset(&ib, 0, sizeof(ib));
 ib.src = buf;
 ib.pos = 0;
 ib.size = 0;
}

ZstdDecompressFilter::~ZstdDecompressFilter()
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

uint64 ZstdDecompressFilter::read_decompress(void* data, uint64 count)
{
 //printf("ZstdDecompressFilter::read() %llu --- %llu %llu %llu --- %016llx %016llx\n", (unsigned long long)count, (unsigned long long)ss->tell(), (unsigned long long)ss_startpos, (unsigned long long)position, (unsigned long long)this, (unsigned long long)ss);
 //
 //
 ZSTD_outBuffer ob;

 memset(&ob, 0, sizeof(ob));

 ob.dst = data;
 ob.size = count;
 ob.pos = 0;

 if(ob.size)
 {
  do
  {
   if(ib.pos == ib.size)
   {
    ib.pos = 0;
    ib.size = 0;
    //
    ib.size = read_source(buf, sizeof(buf));
   }
   //
   const size_t res = ZSTD_decompressStream(zs, &ob, &ib);
   if(ZSTD_isError(res))
    throw MDFN_Error(0, _("Error reading from %s: %s failed: %s"), vfcontext.c_str(), "ZSTD_decompressStream()", ZSTD_getErrorName(res));
  } while(ob.pos != ob.size && ib.size);
 }

 return ob.pos;
}

void ZstdDecompressFilter::close_decompress(void)
{
 ZSTD_freeDStream(zs);
 zs = nullptr;
 memset(&ib, 0, sizeof(ib));
}

}
