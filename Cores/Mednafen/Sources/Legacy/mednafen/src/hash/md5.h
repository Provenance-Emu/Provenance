/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* md5.h:
**  Copyright (C) 2018 Mednafen Team
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

#ifndef __MDFN_MD5_H
#define __MDFN_MD5_H

namespace Mednafen
{

typedef std::array<uint8, 16> md5_digest;

class md5_hasher
{
 public:

 md5_hasher();

 void reset(void);

 void process(const void* data, size_t len);

 INLINE void process_cstr(const char* s)
 {
  return process(s, strlen(s));
 }

 template<typename T>
 INLINE void process_scalar(const T v)
 {
  if(std::is_same<T, bool>::value)
  {
   uint8 tmp = v;

   process(&tmp, 1);
  }
  else
  {
   alignas(T) uint8 tmp[sizeof(T)];

   MDFN_enlsb<T, true>(&tmp[0], v);

   process(tmp, sizeof(tmp));
  }
 }

 md5_digest digest(void) const;

 private:

 void process_block(const uint8* data);

 uint8 buf[64];
 size_t buf_count;

 uint64 bytes_processed;

 uint32 state[4];
};

//
// Backwards-compatibility shim class, remove eventually:
//
class md5_context : private md5_hasher
{
 public:

 INLINE void starts(void)
 {
  finished = false;
  reset();
 }

 INLINE void finish(uint8* d)
 {
  assert(!finished);
  finished = true;
  //
  md5_digest ds = digest();

  memcpy(d, &ds[0], 16);
 }

 INLINE void update(const uint8* data, size_t len)
 {
  assert(!finished);
  //
  process(data, len);
 }

 INLINE void update_u32_as_lsb(uint32 v)
 {
  assert(!finished);
  //
  process_scalar<uint32>(v);
 }

 INLINE void update_string(const char* s)
 {
  assert(!finished);
  //
  process_cstr(s);
 }

 static INLINE std::string asciistr(const uint8* d, bool broken_order)
 {
  assert(!broken_order);
  //
  std::string ret((size_t)16 * 2, 0);

  for(size_t i = 0; i < 16; i++)
  {
   static const char hexlut[16 + 1] = "0123456789abcdef";
   const uint8 v = d[i];

   ret[i * 2 + 0] = hexlut[v >> 4];
   ret[i * 2 + 1] = hexlut[v & 0xF];
  }

  return ret;
 }

 private:
 bool finished = true;
};

void md5_test(void);

static INLINE md5_digest md5(const void* data, uint64 len)
{
 md5_hasher h;

 h.process(data, len);

 return h.digest();
}

static INLINE constexpr uint8 md5_cton(char c)
{
 return ((c >= 'A' && c <= 'F') ? c - 'A' + 0xa : ((c >= 'a' && c <= 'f') ? c - 'a' + 0xa : c - '0'));
}

static INLINE constexpr uint8 md5_cton2(char c, char d)
{
 return (md5_cton(c) << 4) | (md5_cton(d) << 0);
}

static INLINE constexpr md5_digest operator "" _md5(const char *s, std::size_t sz)
{
 //static_assert(sz == 33, "Malformed MD5 string.");
 return /*(sz == 33 ? (void)0 : abort()),*/ md5_digest({{ md5_cton2(s[0], s[1]), md5_cton2(s[2], s[3]), md5_cton2(s[4], s[5]), md5_cton2(s[6], s[7]),
		      md5_cton2(s[8], s[9]), md5_cton2(s[10], s[11]), md5_cton2(s[12], s[13]), md5_cton2(s[14], s[15]),
		      md5_cton2(s[16], s[17]), md5_cton2(s[18], s[19]), md5_cton2(s[20], s[21]), md5_cton2(s[22], s[23]),
		      md5_cton2(s[24], s[25]), md5_cton2(s[26], s[27]), md5_cton2(s[28], s[29]), md5_cton2(s[30], s[31])
		    }});
}

}
#endif
