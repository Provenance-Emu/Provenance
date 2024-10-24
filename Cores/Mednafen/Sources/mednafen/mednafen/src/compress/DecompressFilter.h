/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* DecompressFilter.h:
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

#ifndef __MDFN_COMPRESS_DECOMPRESSFILTER_H
#define __MDFN_COMPRESS_DECOMPRESSFILTER_H

#include <mednafen/Stream.h>

namespace Mednafen
{

class DecompressFilter : public Stream
{
 public:

 template<typename T>
 struct janky_ptr
 {
  INLINE janky_ptr(T* p) : eff(p) { }
  INLINE janky_ptr(std::unique_ptr<T> p) : eff(p.get()), up(std::move(p)) { }
  INLINE void reset(void) { eff = nullptr; up.reset(); }
  INLINE T* operator->() { return eff; }

  private:
  T* eff;
  std::unique_ptr<T> up;
 };


 DecompressFilter(janky_ptr<Stream> source_stream, const std::string& vfcontext, uint64 csize, uint64 ucs = (uint64)-1, uint64 ucrc32 = (uint64)-1);
 virtual ~DecompressFilter() override;
 virtual uint64 read(void *data, uint64 count, bool error_on_eos = true) override;
 virtual void write(const void *data, uint64 count) override;
 virtual void seek(int64 offset, int whence) override;
 virtual uint64 tell(void) override;
 virtual uint64 size(void) override;
 virtual void close(void) override;
 virtual uint64 attributes(void) override;
 virtual void truncate(uint64 length) override;
 virtual void flush(void) override;

 virtual void require_fast_seekable(void) override;

 virtual uint64 read_decompress(void* data, uint64 count) = 0;
 virtual void reset_decompress(void) = 0;
 virtual void close_decompress(void) = 0;

 protected:

 uint64 read_wrap(void* data, uint64 count);

 INLINE uint64 read_source(void* data, uint64 count)
 {
  const uint64 ret = ss->read(data, std::min<uint64>(count, ss_boundpos - ss_pos), false);

  ss_pos += ret;

  return ret;
 }

 private:
 janky_ptr<Stream> ss;
 const uint64 ss_startpos;
 const uint64 ss_boundpos;
 uint64 ss_pos;

 uint64 position;
 uint64 target_position;
 uint64 uc_size;

 uint32 running_crc32;
 const uint64 expected_crc32;

 protected:
 std::string vfcontext;
};

}
#endif
