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

#ifndef __MDFN_ZLINFLATEFILTER_H
#define __MDFN_ZLINFLATEFILTER_H

#include <mednafen/Stream.h>

#include <zlib.h>

class ZLInflateFilter : public Stream
{
 public:

 enum class FORMAT
 {
  RAW = 0,	// Raw inflate
  ZLIB = 1,	// zlib format
  GZIP = 2,	// gzip format
  AUTO_ZGZ = 3	// zlib or gzip, autodetect
 };

 ZLInflateFilter(Stream *source_stream, FORMAT df, uint64 csize, uint64 ucs = ~(uint64)0);
 virtual ~ZLInflateFilter() override;
 virtual uint64 read(void *data, uint64 count, bool error_on_eos = true) override;
 virtual void write(const void *data, uint64 count) override;
 virtual void seek(int64 offset, int whence) override;
 virtual uint64 tell(void) override;
 virtual uint64 size(void) override;
 virtual void close(void) override;
 virtual uint64 attributes(void) override;
 virtual void truncate(uint64 length) override;
 virtual void flush(void) override;

 private:

 Stream* ss;
 const uint64 ss_startpos;
 const uint64 ss_boundpos;

 z_stream zs;
 uint8 buf[8192];

 uint64 position;
 const uint64 uc_size;
};

#endif
