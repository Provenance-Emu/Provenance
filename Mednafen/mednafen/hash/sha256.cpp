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

#include <mednafen/mednafen.h>
#include <mednafen/endian.h>

#include "sha256.h"

#include <stdio.h>
#include <string.h>

static const uint32 K[64] =
{
 0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
 0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
};

template<unsigned n>
static INLINE uint32 rotr(const uint32 val)
{
 return (val >> n) | (val << (32 - n));
}

static INLINE uint32 ch(const uint32 x, const uint32 y, const uint32 z)
{
 return (x & y) ^ ((~x) & z);
}

static INLINE uint32 maj(const uint32 x, const uint32 y, const uint32 z)
{
 return (x & y) ^ (x & z) ^ (y & z);
}

static INLINE uint32 bs0(const uint32 x)
{
 return rotr<2>(x) ^ rotr<13>(x) ^ rotr<22>(x);
}

static INLINE uint32 bs1(const uint32 x)
{
 return rotr<6>(x) ^ rotr<11>(x) ^ rotr<25>(x);
}

static INLINE uint32 ls0(const uint32 x)
{
 return rotr<7>(x) ^ rotr<18>(x) ^ (x >> 3);
}

static INLINE uint32 ls1(const uint32 x)
{
 return rotr<17>(x) ^ rotr<19>(x) ^ (x >> 10);
}

static INLINE void block(std::array<uint32, 8> &h, void* blk_data)
{
 alignas(16) uint32 w[64];
 alignas(16) auto v = h;

 for(unsigned t = 0; t < 16; t++)
  w[t] = MDFN_de32msb((uint8*)blk_data + (t << 2));

 for(unsigned t = 16; t < 64; t++)
  w[t] = ls1(w[t - 2]) + w[t - 7] + ls0(w[t - 15]) + w[t - 16];

 for(unsigned t = 0; t < 64; t++)
 {
  uint32 T1 = v[7] + bs1(v[4]) + ch(v[4], v[5], v[6]) + K[t] + w[t];
  uint32 T2 = bs0(v[0]) + maj(v[0], v[1], v[2]);

  v[7] = v[6];
  v[6] = v[5];
  v[5] = v[4];
  v[4] = v[3] + T1;
  v[3] = v[2];
  v[2] = v[1];
  v[1] = v[0];
  v[0] = T1 + T2;
 }

 for(unsigned i = 0; i < h.size(); i++)
  h[i] += v[i];
}

sha256_digest sha256(const void* data, const uint64 len)
{
 sha256_digest ret;
 alignas(16) std::array<uint32, 8> h({{ 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 }});
 uint8* p = (uint8*)data;
 uint64 dc = len;

 while(MDFN_LIKELY(dc >= 64))
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

 for(unsigned i = 0; i < 8; i++)
  MDFN_en32msb(&ret[i * 4], h[i]);

 //printf("%08x %08x %08x %08x %08x %08x %08x %08x\n", h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7]);

 return ret;
}

//sha256_digest goomba = "dccac470d07efd7f989c1f9a5045bc2cfe446622dbb50d4ad7f53996e574cd29"_sha256;
#include <assert.h>
void sha256_test(void)
{
 char tv[256];

 for(unsigned i = 0; i < 256; i++)
  tv[i] = i * 3;

#if 0
 void *bmt = malloc(1024 * 1024 * 512);

 memset(bmt, 0, 1024 * 1024 * 512);

 uint32 st = MDFND_GetTime();

 sha256(bmt, 1024 * 1024 * 512);
 printf("%f\n", (double)1024 * 1024 * 512 * 1000 / (MDFND_GetTime() - st) / 1000 / 1000);

 abort();
#endif

 static const sha256_digest expected[6] =
 {
  "16f868c5d6f278b54eacc307c56c0cd6ece81bb3784a531f0d6d75d4200c6fe6"_sha256,
  "4ccac470d07efd7f989c1f9a5045bc2cfe446622dbb50d4ad7f53996e574cd29"_sha256,
  "a9d56e4e0d999c82ac86ce58b6b711e95e40eaddceb3bbc2ee0dc213236d7056"_sha256,
  "ab14676d2f0ce3b7cec24dfcab775b124f2c95dd42bea4fe6a7c7158f4c1788e"_sha256,
  "1a0e0ecf84382961a85aa8629e98aefcfeffdcf0fd74a6dd49d55d9706477ab2"_sha256,
  "fd833d1be324b92272bc7c17a0ee9cad152cae24c622082f912e4552afe6bdbd"_sha256
 };

 assert(sha256(tv, 55) == expected[0]);
 assert(sha256(tv, 56) == expected[1]);
 assert(sha256(tv, 57) == expected[2]);
 assert(sha256(tv, 63) == expected[3]);
 assert(sha256(tv, 64) == expected[4]);
 assert(sha256(tv, 65) == expected[5]);

}

