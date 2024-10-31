/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* crc.cpp:
**  Copyright (C) 2018-2021 Mednafen Team
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
#include "crc.h"

namespace Mednafen
{

#if 0
uint16 crc16_ccitt(const void* data, const size_t len)
{
 static const uint16 tab[16] = { 0x0000, 0x1021, 0x2042, 0x3063, 0x4084, 0x50a5, 0x60c6, 0x70e7, 0x8108, 0x9129, 0xa14a, 0xb16b, 0xc18c, 0xd1ad, 0xe1ce, 0xf1ef };
 uint8* p = (uint8*)data;
 uint16 r = 0;

#if 0
 for(unsigned i = 0; i < 16; i++)
 {
  r = i << 12;
  for(unsigned b = 4; b; b--)
   r = (r << 1) ^ (((int16)r >> 15) & 0x1021);
  printf("0x%04x, ", r);
 }
 exit(0);
#endif

 for(size_t i = 0; MDFN_LIKELY(i < len); i++)
 {
  r ^= p[i] << 8;
  r = (r << 4) ^ tab[r >> 12];
  r = (r << 4) ^ tab[r >> 12];
  //r = (r << 4) ^ ((r >> 12) * 0x1021);
  //r = (r << 4) ^ ((r >> 12) * 0x1021);
 }

 return r;
}
#endif

#define MDFN_REVBITSH_1(v) ((((v) & 0xAAAAAAAA) >>  1) | (((v) <<  1) & 0xAAAAAAAA))
#define MDFN_REVBITSH_2(v) (((MDFN_REVBITSH_1(v) & 0xCCCCCCCC) >>  2) | ((MDFN_REVBITSH_1(v) <<  2) & 0xCCCCCCCC))
#define MDFN_REVBITSH_4(v) (((MDFN_REVBITSH_2(v) & 0xF0F0F0F0) >>  4) | ((MDFN_REVBITSH_2(v) <<  4) & 0xF0F0F0F0))
#define MDFN_REVBITSH_8(v) (((MDFN_REVBITSH_4(v) & 0xFF00FF00) >>  8) | ((MDFN_REVBITSH_4(v) <<  8) & 0xFF00FF00))
#define MDFN_REVBITSH_16(v) (((MDFN_REVBITSH_8(v) & 0xFFFF0000) >> 16) | ((MDFN_REVBITSH_8(v) << 16) & 0xFFFF0000))
#define MDFN_REVBITSH_32(v) (((uint64)MDFN_REVBITSH_16(v) >> 32) | ((uint64)MDFN_REVBITSH_16(v) << 32))

static INLINE constexpr uint64 MDFN_revbits64(uint64 v)
{
/*
 (v = (((v & 0xAAAAAAAA) >>  1) | ((v <<  1) & 0xAAAAAAAA))),
 (v = (((v & 0xCCCCCCCC) >>  2) | ((v <<  2) & 0xCCCCCCCC))),
 (v = (((v & 0xF0F0F0F0) >>  4) | ((v <<  4) & 0xF0F0F0F0))),
 (v = (((v & 0xFF00FF00) >>  8) | ((v <<  8) & 0xFF00FF00))),
 (v = (((v & 0xFFFF0000) >> 16) | ((v << 16) & 0xFFFF0000))),
 v;
*/
 return MDFN_REVBITSH_32(v);
}

template<typename T, unsigned N, T polynomial, bool data_lsbit_first>
static INLINE constexpr T CRCN_GTEH_L_(T v)
{
 return (((v) >> 1) ^ ((((v) & 1) ? ~0 : 0) & (T)(MDFN_revbits64(polynomial) >> (64 - N)) ));
}

template<typename T, unsigned N, T polynomial, bool data_lsbit_first>
static INLINE constexpr T CRCN_GTEH_M_(T v)
{
 return (((v) << 1) ^ (((((v) >> (sizeof(T) * 8 - 1)) & 1) ? ~0 : 0) & polynomial ));
}

#define CRCN_GTEH(v) (data_lsbit_first ? CRCN_GTEH_L_<T, N, polynomial, data_lsbit_first>(v) : CRCN_GTEH_M_<T, N, polynomial, data_lsbit_first>(v))

template<typename T, unsigned N, T polynomial, bool data_lsbit_first>
static INLINE constexpr T CRCN_GTE4_(T v)
{
 return ((T)CRCN_GTEH(CRCN_GTEH(CRCN_GTEH(CRCN_GTEH((T)(v) << (data_lsbit_first ? 0 : (sizeof(T) * 8 - 4)) )))));
}

template<typename T, unsigned N, T polynomial, bool data_lsbit_first>
static INLINE constexpr T CRCN_GTE8_(T v)
{
 return ((T)CRCN_GTEH(CRCN_GTEH(CRCN_GTEH(CRCN_GTEH(CRCN_GTEH(CRCN_GTEH(CRCN_GTEH(CRCN_GTEH((T)(v) << (data_lsbit_first ? 0 : (sizeof(T) * 8 - 8)) )))))))));
}

#define CRCN_GTE4(v) CRCN_GTE4_<T, N, polynomial, data_lsbit_first>(v)
#define CRCN_GTE8(v) CRCN_GTE8_<T, N, polynomial, data_lsbit_first>(v)
#define CRCN_GTEX16(o) CRCN_GTE8((o) + 0x00), CRCN_GTE8((o) + 0x01), CRCN_GTE8((o) + 0x02), CRCN_GTE8((o) + 0x03), CRCN_GTE8((o) + 0x04), CRCN_GTE8((o) + 0x05), CRCN_GTE8((o) + 0x06), CRCN_GTE8((o) + 0x07), CRCN_GTE8((o) + 0x08), CRCN_GTE8((o) + 0x09), CRCN_GTE8((o) + 0x0A), CRCN_GTE8((o) + 0x0B), CRCN_GTE8((o) + 0x0C), CRCN_GTE8((o) + 0x0D), CRCN_GTE8((o) + 0x0E), CRCN_GTE8((o) + 0x0F)

template<typename T, unsigned N, T polynomial, bool data_lsbit_first>
static INLINE T crcN(T r, const void* data, const size_t len)
{
 const uint8* p = (const uint8*)data;

 static const T tab256[256] =
 {
  CRCN_GTEX16(0x00), CRCN_GTEX16(0x10), CRCN_GTEX16(0x20), CRCN_GTEX16(0x30), CRCN_GTEX16(0x40), CRCN_GTEX16(0x50), CRCN_GTEX16(0x60), CRCN_GTEX16(0x70),
  CRCN_GTEX16(0x80), CRCN_GTEX16(0x90), CRCN_GTEX16(0xA0), CRCN_GTEX16(0xB0), CRCN_GTEX16(0xC0), CRCN_GTEX16(0xD0), CRCN_GTEX16(0xE0), CRCN_GTEX16(0xF0),
 };

 static const T tab16[16] =
 {
  CRCN_GTE4(0x0), CRCN_GTE4(0x1), CRCN_GTE4(0x2), CRCN_GTE4(0x3), CRCN_GTE4(0x4), CRCN_GTE4(0x5), CRCN_GTE4(0x6), CRCN_GTE4(0x7),
  CRCN_GTE4(0x8), CRCN_GTE4(0x9), CRCN_GTE4(0xA), CRCN_GTE4(0xB), CRCN_GTE4(0xC), CRCN_GTE4(0xD), CRCN_GTE4(0xE), CRCN_GTE4(0xF),
 };

 if(data_lsbit_first)
 {
  for(size_t i = 0; MDFN_LIKELY(i < len); i++)
  {
   r ^= p[i];

   if(N >= 24)
    r = (r >> 8) ^ tab256[(uint8)r];
   else
   {
    r = (r >> 4) ^ tab16[r & 0xF];
    r = (r >> 4) ^ tab16[r & 0xF];
   }
  }
 }
 else
 {
  for(size_t i = 0; MDFN_LIKELY(i < len); i++)
  {
   r ^= (T)p[i] << (sizeof(T) * 8 - 8);

   if(N >= 24)
    r = (r << 8) ^ tab256[r >> (sizeof(T) * 8 - 8)];
   else
   {
    r = (r << 4) ^ tab16[r >> (sizeof(T) * 8 - 4)];
    r = (r << 4) ^ tab16[r >> (sizeof(T) * 8 - 4)];
   }
  }

  r >>= sizeof(T) * 8 - N;
 }

 return r;
}

uint16 crc16_ccitt(const uint16 initial, const void* data, const size_t len)
{
 return crcN<uint16, 16, 0x1021, false>(initial, data, len);
}

uint32 crc32_cdrom_edc(const void* data, const size_t len)
{
 return crcN<uint32, 32, 0x8001801B, true>(0, data, len);
}

uint32 crc32_zip(const uint32 initial, const void* data, const size_t len)
{
 return ~crcN<uint32, 32, 0x04C11DB7, true>(~initial, data, len);
}

void crc_test(void)
{
 unsigned char tv[256];

 for(unsigned i = 0; i < 256; i++)
  tv[i] = i ^ 0xA5;

 assert(crc16_ccitt(0, tv,   0) == 0x0000);
 assert(crc16_ccitt(0, tv,   1) == 0xE54F);
 assert(crc16_ccitt(0, tv, 256) == 0x9C87);

 assert(crc32_cdrom_edc(tv,   0) == 0x00000000);
 assert(crc32_cdrom_edc(tv,   1) == 0x58D0A500);
 assert(crc32_cdrom_edc(tv, 256) == 0xA194A58B);

 assert(crc32_zip(0xDEADBEEF, tv,   0) == 0xDEADBEEF);
 assert(crc32_zip(0x12345678, tv,   1) == 0x2A7275B2);
 assert(crc32_zip(0xA555555A, tv, 256) == 0xBF3981FE);
}
}
