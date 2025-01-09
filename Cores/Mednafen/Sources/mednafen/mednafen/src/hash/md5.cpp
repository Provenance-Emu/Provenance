/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* md5.cpp:
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

#include <mednafen/types.h>
#include "md5.h"

namespace Mednafen
{

/*
 for(int i = 0; i < 64; i++)
 {
  printf(" 0x%08x,", (unsigned)floor(fabs(((1ULL << 32) * sin(1 + i)))));
  if((i & 0x7) == 0x7)
   printf("\n");
 }
*/
static const uint32 sine_table[0x40] =
{
 0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee, 0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
 0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be, 0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
 0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa, 0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
 0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed, 0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
 0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c, 0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
 0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05, 0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
 0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039, 0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
 0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1, 0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391
};

typedef std::array<uint8, 16> md5_digest;

md5_hasher::md5_hasher()
{
 reset();
}

void md5_hasher::reset(void)
{
 buf_count = 0;
 bytes_processed = 0;

 state[0] = 0x67452301;
 state[1] = 0xEFCDAB89;
 state[2] = 0x98BADCFE;
 state[3] = 0x10325476;
}

static uint32 rotl32(unsigned amount, uint32 v)
{
 return (v << amount) | (v >> (32 - amount));
}

static uint32 op0(uint32 x, uint32 y, uint32 z)
{
 return (x & y) | (~x & z);
}

static uint32 op1(uint32 x, uint32 y, uint32 z)
{
 return (x & z) | (y & ~z);
}

static uint32 op2(uint32 x, uint32 y, uint32 z)
{
 return x ^ y ^ z;
}

static uint32 op3(uint32 x, uint32 y, uint32 z)
{
 return y ^ (x | ~z);
}

NO_INLINE void md5_hasher::process_block(const uint8* data)
{
 uint32 ns[4] = { state[0], state[1], state[2], state[3] };
 uint32 d32[16];

 for(size_t i = 0; i < 0x10; i++)
 {
  d32[i] = MDFN_de32lsb(&data[i << 2]);
  //printf("%08x\n", d32[i]);
 }

 static const unsigned rot_tab[/*round*/4][/*sub*/4] =
 {
  { 7, 12, 17, 22 },
  { 5,  9, 14, 20 },
  { 4, 11, 16, 23 },
  { 6, 10, 15, 21 },
 };

 static const struct
 {
  unsigned base;
  unsigned inc;
 } d32_index_tab[4] =
 {
  { 0, 1 },
  { 1, 5 },
  { 5, 3 },
  { 0, 7 },
 };

 static uint32 (*const optab[4])(uint32, uint32, uint32) = { op0, op1, op2, op3 };

 #define SUBE(round, group, sub)						\
 {										\
	uint32& n0 = ns[(0 - sub) & 3];						\
	uint32& n1 = ns[(1 - sub) & 3];						\
	uint32& n2 = ns[(2 - sub) & 3];						\
	uint32& n3 = ns[(3 - sub) & 3];						\
	const uint32 r = rot_tab[round][sub];					\
	const uint32 d = d32[(d32_base + d32_inc * ((group << 2) + sub)) & 0xF];\
	const uint32 s = sine_table[(round << 4) + (group << 2) + sub];		\
										\
	n0 = n1 + rotl32(r, n0 + optab[round](n1, n2, n3) + d + s);		\
 }

 #define GROUPE(round, group)	\
 {				\
  SUBE(round, group, 0)		\
  SUBE(round, group, 1)		\
  SUBE(round, group, 2)		\
  SUBE(round, group, 3)		\
 }

 #define ROUNDE(round)						\
 {								\
	const size_t d32_base = d32_index_tab[round].base;	\
	const size_t d32_inc = d32_index_tab[round].inc;	\
	GROUPE(round, 0)					\
	GROUPE(round, 1)					\
	GROUPE(round, 2)					\
	GROUPE(round, 3)					\
 }

 ROUNDE(0)
 ROUNDE(1)
 ROUNDE(2)
 ROUNDE(3)

 #undef ROUNDE
 #undef GROUPE
 #undef SUBE

 //
 state[0] += ns[0];
 state[1] += ns[1];
 state[2] += ns[2];
 state[3] += ns[3];
}

void md5_hasher::process(const void* data, size_t len)
{
 uint8* d8 = (uint8*)data;

 bytes_processed += len;

 while(len)
 {
  if(buf_count || len < 0x40)
  {
   const size_t copy_len = std::min<size_t>(0x40 - buf_count, len);

   memcpy(&buf[buf_count], d8, copy_len);
   len -= copy_len;
   d8 += copy_len;
   buf_count += copy_len;
   if(buf_count == 0x40)
   {
    process_block(buf);
    buf_count = 0;
   }
  }
  else
  {
   process_block(d8);
   d8 += 0x40;
   len -= 0x40;
  }
 }
}

md5_digest md5_hasher::digest(void) const
{
 const size_t padding_len = 0x40 - ((bytes_processed + 8) & 0x3F);
 uint8 footer[0x40 + 8] = { 0x80 };
 md5_hasher tmp = *this;
 md5_digest ret;

 //printf("%u %zu\n", (unsigned)bytes_processed, padding_len);

 MDFN_en64lsb(&footer[padding_len], 8 * bytes_processed);
 tmp.process(footer, padding_len + 8);

 assert(tmp.buf_count == 0);

 for(unsigned i = 0; i < 4; i++)
  MDFN_en32lsb(&ret[i << 2], tmp.state[i]);

 return ret;
}

//#include <mednafen/Time.h>
void md5_test(void)
{
#if 0
 unsigned char buf[256];

 srand(1);
 for(unsigned i = 0; i < 256; i++)
  buf[i] = rand() >> 8;

 for(unsigned len = 0; len <= 256; len++)
 {
  for(unsigned sub_len = 1; sub_len < len; sub_len++)
  {
   md5_hasher h1;
   md5_hasher h2;

   h1.process(buf, len);

   for(unsigned offs = 0; offs < len; offs += sub_len)
   {
    h2.process(buf + offs, std::min<unsigned>(len - offs, sub_len));
    h2.digest();
   }

   assert(h1.digest() == h2.digest());
  }
 }
#endif
#if 0
 {
  static char bigbuf[1024 * 1024] = { 0 };
  uint64 st = Time::MonoUS();
  md5_hasher h;

  h.process(bigbuf, sizeof(bigbuf));
  printf("%llu %d\n", (unsigned long long)(Time::MonoUS() - st), h.digest()[0]);
 }
#endif

 unsigned char tv[256];

 for(unsigned i = 0; i < 256; i++)
  tv[i] = i * 3;

 static const md5_digest expected[8] =
 {
  "d41d8cd98f00b204e9800998ecf8427e"_md5,
  "93b885adfe0da089cdf634904fd59f71"_md5,
  "aca1b6056cce96c00c6fc48ed9dddcd3"_md5,
  "12b2736751b6bf8c10667bb1ed4ccfc1"_md5,
  "1882e526935174fe916407dfb77c402d"_md5,
  "4be29edac5cd4e4b15f57d53da8b87e0"_md5,
  "a0d9e4f17da49cec85f710a9b9c68772"_md5,
  "8e51f9a1666715700fba3f5ba5f2857b"_md5
 };

 assert(md5(tv,  0) == expected[0]);
 assert(md5(tv,  1) == expected[1]);
 assert(md5(tv, 55) == expected[2]);
 assert(md5(tv, 56) == expected[3]);
 assert(md5(tv, 57) == expected[4]);
 assert(md5(tv, 63) == expected[5]);
 assert(md5(tv, 64) == expected[6]);
 assert(md5(tv, 65) == expected[7]);
}

}
