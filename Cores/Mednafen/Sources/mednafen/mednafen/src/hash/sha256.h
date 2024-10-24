/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* sha256.h:
**  Copyright (C) 2014-2017 Mednafen Team
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

#ifndef __MDFN_SHA256_H
#define __MDFN_SHA256_H

namespace Mednafen
{

typedef std::array<uint8, 32> sha256_digest;
class sha256_hasher
{
 public:

 sha256_hasher();

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

 sha256_digest digest(void) const;

 private:

 void process_block(const uint8* data);
 std::array<uint32, 8> h;

 uint8 buf[64];
 size_t buf_count;

 uint64 bytes_processed;
};

void sha256_test(void);

static INLINE sha256_digest sha256(const void* data, uint64 len)
{
 sha256_hasher h;

 h.process(data, len);

 return h.digest();
}


static INLINE constexpr uint8 sha256_cton(char c)
{
 return ((c >= 'A' && c <= 'F') ? c - 'A' + 0xa : ((c >= 'a' && c <= 'f') ? c - 'a' + 0xa : c - '0'));
}

static INLINE constexpr uint8 sha256_cton2(char c, char d)
{
 return (sha256_cton(c) << 4) | (sha256_cton(d) << 0);
}

static INLINE constexpr sha256_digest operator "" _sha256(const char *s, std::size_t sz)
{
 //static_assert(sz == 65, "Malformed SHA-256 string.");
 return /*(sz == 65 ? (void)0 : abort()),*/ sha256_digest({{ sha256_cton2(s[0], s[1]), sha256_cton2(s[2], s[3]), sha256_cton2(s[4], s[5]), sha256_cton2(s[6], s[7]),
		      sha256_cton2(s[8], s[9]), sha256_cton2(s[10], s[11]), sha256_cton2(s[12], s[13]), sha256_cton2(s[14], s[15]),
		      sha256_cton2(s[16], s[17]), sha256_cton2(s[18], s[19]), sha256_cton2(s[20], s[21]), sha256_cton2(s[22], s[23]),
		      sha256_cton2(s[24], s[25]), sha256_cton2(s[26], s[27]), sha256_cton2(s[28], s[29]), sha256_cton2(s[30], s[31]),
		      sha256_cton2(s[32], s[33]), sha256_cton2(s[34], s[35]), sha256_cton2(s[36], s[37]), sha256_cton2(s[38], s[39]),
		      sha256_cton2(s[40], s[41]), sha256_cton2(s[42], s[43]), sha256_cton2(s[44], s[45]), sha256_cton2(s[46], s[47]),
		      sha256_cton2(s[48], s[49]), sha256_cton2(s[50], s[51]), sha256_cton2(s[52], s[53]), sha256_cton2(s[54], s[55]),
		      sha256_cton2(s[56], s[57]), sha256_cton2(s[58], s[59]), sha256_cton2(s[60], s[61]), sha256_cton2(s[62], s[63]), }
		    });
}

}
#endif
