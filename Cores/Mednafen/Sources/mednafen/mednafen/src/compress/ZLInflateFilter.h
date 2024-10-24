/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* ZLInflateFilter.h:
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

#ifndef __MDFN_COMPRESS_ZLINFLATEFILTER_H
#define __MDFN_COMPRESS_ZLINFLATEFILTER_H

#include <mednafen/Stream.h>
#include "DecompressFilter.h"

#include <zlib.h>

namespace Mednafen
{

class ZLInflateFilter : public DecompressFilter
{
 public:

 enum class FORMAT
 {
  RAW = 0,	// Raw inflate
  ZLIB = 1,	// zlib format
  GZIP = 2,	// gzip format
  AUTO_ZGZ = 3	// zlib or gzip, autodetect
 };

 ZLInflateFilter(janky_ptr<Stream> source_stream, const std::string& vfcontext, FORMAT df, uint64 csize, uint64 ucs = (uint64)-1, uint64 ucrc32 = (uint64)-1);
 virtual ~ZLInflateFilter() override;

 virtual uint64 read_decompress(void* data, uint64 count) override;
 virtual void reset_decompress(void) override;
 virtual void close_decompress(void) override;

 private:

 z_stream zs;
 uint8 buf[8192];
};

/*
class GZIPReadFilter : public ZLInflateFilter
{
 public:
 INLINE GZIPReadFilter(Stream* source_stream) : ZLInflateFilter(source_stream, "", FORMAT::GZIP, (uint64)-1);

}
*/

}
#endif
