/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* sha1.cpp:
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

#include <mednafen/mednafen.h>
#include "sha1.h"

template<unsigned n>
static INLINE uint32 rotl(uint32 val)
{
 return (val << n) | (val >> (32 - n));
}

template<unsigned bt>
static INLINE uint32 f(uint32 x, uint32 y, uint32 z)
{
 switch(bt)
 {
  case 0:
	return (x & y) ^ ((~x) & z);

  case 1:
	return x ^ y ^ z;

  case 2:
	return (x & y) ^ (x & z) ^ (y & z);

  case 3:
	return x ^ y ^ z;
 }
}

template<unsigned bt>
static INLINE void block_sub(uint32 v[5], uint32 w[80])
{
 static const uint32 K[4] = { 0x5a827999, 0x6ed9eba1, 0x8f1bbcdc, 0xca62c1d6 };
 uint32* bw = &w[bt * 20];
 const uint32 Kt = K[bt];

 for(unsigned st = 0; st < 20; st++)
 {
  uint32 T = rotl<5>(v[0]) + f<bt>(v[1], v[2], v[3]) + v[4] + Kt + bw[st];

  v[4] = v[3];
  v[3] = v[2];
  v[2] = rotl<30>(v[1]);
  v[1] = v[0];
  v[0] = T;
 }
}

static INLINE void block(uint32 h[5], void* blk_data)
{
 alignas(16) uint32 w[80];
 uint32 v[5];

 for(unsigned t = 0; t < 16; t++)
  w[t] = MDFN_de32msb((uint8*)blk_data + (t << 2));

 for(unsigned t = 16; t < 80; t++)
  w[t] = rotl<1>(w[t - 3] ^ w[t - 8] ^ w[t - 14] ^ w[t - 16]);

 memcpy(v, h, sizeof(v));

 block_sub<0>(v, w);
 block_sub<1>(v, w);
 block_sub<2>(v, w);
 block_sub<3>(v, w);

 for(unsigned i = 0; i < 5; i++)
  h[i] += v[i];
}

sha1_digest sha1(const void* data, const uint64 len)
{
 sha1_digest ret;
 uint32 h[5] = { 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476, 0xc3d2e1f0 };
 uint8* p = (uint8*)data;
 uint64 dc = len;

 while(dc >= 64)
 {
  block(h, p);

  p += 64;
  dc -= 64;
 }

 {
  alignas(16) uint8 tmp[128];

  memcpy(tmp, p, dc);
  memset(tmp + dc, 0, 128 - dc);
  tmp[dc] |= 0x80;

  dc = ((dc + 8) &~ 63) + 56;

  MDFN_en64msb<true>(&tmp[dc], len * 8);

  block(h, tmp);
  if(dc >= 64)
   block(h, tmp + 64);
 }

 for(unsigned i = 0; i < 5; i++)
  MDFN_en32msb(&ret[i * 4], h[i]);

 //printf("%08x %08x %08x %08x %08x\n", h[0], h[1], h[2], h[3], h[4]);

 return ret;
}

void sha1_test(void)
{
 char tv[256];

 for(unsigned i = 0; i < 256; i++)
  tv[i] = i * 3;

 static const sha1_digest expected[6] =
 {
  "e119a863bce69ad1b6ca1a51e94994531d122088"_sha1,
  "fd62c272e1f0f24b92a0ec8360519cd64d6ab986"_sha1,
  "010b0113d06cffb80f2beb657ef39682e5e7de79"_sha1,
  "adf8998c4791fc378fa6d8b23666934522546778"_sha1,
  "787680a25bf74f34c22b2c37d7d5bae2feceb20c"_sha1,
  "079b9ef0684bd9a600b9a23caa4297d064ce076e"_sha1
 };

 assert(sha1(tv, 55) == expected[0]);
 assert(sha1(tv, 56) == expected[1]);
 assert(sha1(tv, 57) == expected[2]);
 assert(sha1(tv, 63) == expected[3]);
 assert(sha1(tv, 64) == expected[4]);
 assert(sha1(tv, 65) == expected[5]);
}

