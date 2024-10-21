/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* ZstdDecompressFilter.h:
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

#ifndef __MDFN_COMPRESS_ZSTDDECOMPRESSFILTER_H
#define __MDFN_COMPRESS_ZSTDDECOMPRESSFILTER_H

#include "DecompressFilter.h"

#include <zstd/zstd.h>

namespace Mednafen
{

class ZstdDecompressFilter : public DecompressFilter
{
 public:

 ZstdDecompressFilter(janky_ptr<Stream> source_stream, const std::string& vfcontext, uint64 csize, uint64 ucs = (uint64)-1, uint64 ucrc32 = (uint64)-1);
 virtual ~ZstdDecompressFilter() override;

 virtual uint64 read_decompress(void* data, uint64 count) override;
 virtual void reset_decompress(void) override;
 virtual void close_decompress(void) override;

 private:
 ZSTD_DStream* zs;
 ZSTD_inBuffer ib;

 uint8 buf[8192];
};

}
#endif
