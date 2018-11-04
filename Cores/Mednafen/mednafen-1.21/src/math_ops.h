/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* math_ops.h:
**  Copyright (C) 2007-2016 Mednafen Team
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

/*
** Some ideas from:
**  blargg
**  http://graphics.stanford.edu/~seander/bithacks.html
*/

#ifndef __MDFN_MATH_OPS_H
#define __MDFN_MATH_OPS_H

#if defined(_MSC_VER)
 #include <intrin.h>
#endif

static INLINE unsigned MDFN_lzcount16_0UD(uint16 v)
{
 #if defined(__GNUC__) || defined(__clang__) || defined(__ICC) || defined(__INTEL_COMPILER)
 return 15 ^ 31 ^ __builtin_clz(v);
 #elif defined(_MSC_VER)
 unsigned long idx;

 _BitScanReverse(&idx, v);

 return 15 ^ idx;
 #else
 unsigned ret = 0;
 unsigned tmp;

 tmp = !(v & 0xFF00) << 3; v <<= tmp; ret += tmp;
 tmp = !(v & 0xF000) << 2; v <<= tmp; ret += tmp;
 tmp = !(v & 0xC000) << 1; v <<= tmp; ret += tmp;
 tmp = !(v & 0x8000) << 0;            ret += tmp;

 return(ret);
 #endif
}

static INLINE unsigned MDFN_lzcount32_0UD(uint32 v)
{
 #if defined(__GNUC__) || defined(__clang__) || defined(__ICC) || defined(__INTEL_COMPILER)
 return __builtin_clz(v);
 #elif defined(_MSC_VER)
 unsigned long idx;

 _BitScanReverse(&idx, v);

 return 31 ^ idx;
 #else
 unsigned ret = 0;
 unsigned tmp;

 tmp = !(v & 0xFFFF0000) << 4; v <<= tmp; ret += tmp;
 tmp = !(v & 0xFF000000) << 3; v <<= tmp; ret += tmp;
 tmp = !(v & 0xF0000000) << 2; v <<= tmp; ret += tmp;
 tmp = !(v & 0xC0000000) << 1; v <<= tmp; ret += tmp;
 tmp = !(v & 0x80000000) << 0;            ret += tmp;

 return(ret);
 #endif
}

static INLINE unsigned MDFN_lzcount64_0UD(uint64 v)
{
 #if defined(__GNUC__) || defined(__clang__) || defined(__ICC) || defined(__INTEL_COMPILER)
 return __builtin_clzll(v);
 #elif defined(_MSC_VER)
  #if defined(_WIN64)
   unsigned long idx;
   _BitScanReverse64(&idx, v);
   return 63 ^ idx;
  #else
   unsigned long idx0;
   unsigned long idx1;

   _BitScanReverse(&idx1, v >> 0);
   idx1 -= 32;
   if(!_BitScanReverse(&idx0, v >> 32))
    idx0 = idx1;

   idx0 += 32;

   return 63 ^ idx0;
  #endif
 #else
 unsigned ret = 0;
 unsigned tmp;

 tmp = !(v & 0xFFFFFFFF00000000ULL) << 5; v <<= tmp; ret += tmp;
 tmp = !(v & 0xFFFF000000000000ULL) << 4; v <<= tmp; ret += tmp;
 tmp = !(v & 0xFF00000000000000ULL) << 3; v <<= tmp; ret += tmp;
 tmp = !(v & 0xF000000000000000ULL) << 2; v <<= tmp; ret += tmp;
 tmp = !(v & 0xC000000000000000ULL) << 1; v <<= tmp; ret += tmp;
 tmp = !(v & 0x8000000000000000ULL) << 0;            ret += tmp;

 return(ret);
 #endif
}

static INLINE unsigned MDFN_tzcount16_0UD(uint16 v)
{
 #if defined(__GNUC__) || defined(__clang__) || defined(__ICC) || defined(__INTEL_COMPILER)
 return __builtin_ctz(v);
 #elif defined(_MSC_VER)
 unsigned long idx;

 _BitScanForward(&idx, v);

 return idx;
 #else
 unsigned ret = 0;
 unsigned tmp;

 tmp = !( (uint8)v)  << 3; v >>= tmp; ret += tmp;
 tmp = !(v & 0x000F) << 2; v >>= tmp; ret += tmp;
 tmp = !(v & 0x0003) << 1; v >>= tmp; ret += tmp;
 tmp = !(v & 0x0001) << 0;            ret += tmp;

 return ret;
 #endif
}

static INLINE unsigned MDFN_tzcount32_0UD(uint32 v)
{
 #if defined(__GNUC__) || defined(__clang__) || defined(__ICC) || defined(__INTEL_COMPILER)
 return __builtin_ctz(v);
 #elif defined(_MSC_VER)
 unsigned long idx;

 _BitScanForward(&idx, v);

 return idx;
 #else
 unsigned ret = 0;
 unsigned tmp;

 tmp = !((uint16)v)  << 4; v >>= tmp; ret += tmp;
 tmp = !( (uint8)v)  << 3; v >>= tmp; ret += tmp;
 tmp = !(v & 0x000F) << 2; v >>= tmp; ret += tmp;
 tmp = !(v & 0x0003) << 1; v >>= tmp; ret += tmp;
 tmp = !(v & 0x0001) << 0;            ret += tmp;

 return ret;
 #endif
}

static INLINE unsigned MDFN_tzcount64_0UD(uint64 v)
{
 #if defined(__GNUC__) || defined(__clang__) || defined(__ICC) || defined(__INTEL_COMPILER)
 return __builtin_ctzll(v);
 #elif defined(_MSC_VER)
  #if defined(_WIN64)
   unsigned long idx;
   _BitScanForward64(&idx, v);
   return idx;
  #else
   unsigned long idx0, idx1;

   _BitScanForward(&idx1, v >> 32);
   idx1 += 32;
   if(!_BitScanForward(&idx0, v))
    idx0 = idx1;

   return idx0;
  #endif
 #else
 unsigned ret = 0;
 unsigned tmp;

 tmp = !((uint32)v)  << 5; v >>= tmp; ret += tmp;
 tmp = !((uint16)v)  << 4; v >>= tmp; ret += tmp;
 tmp = !( (uint8)v)  << 3; v >>= tmp; ret += tmp;
 tmp = !(v & 0x000F) << 2; v >>= tmp; ret += tmp;
 tmp = !(v & 0x0003) << 1; v >>= tmp; ret += tmp;
 tmp = !(v & 0x0001) << 0;            ret += tmp;

 return ret;
 #endif
}

//
// Result is defined for all possible inputs(including 0).
//
static INLINE unsigned MDFN_lzcount16(uint16 v) { return !v ? 16 : MDFN_lzcount16_0UD(v); }
static INLINE unsigned MDFN_lzcount32(uint32 v) { return !v ? 32 : MDFN_lzcount32_0UD(v); }
static INLINE unsigned MDFN_lzcount64(uint64 v) { return !v ? 64 : MDFN_lzcount64_0UD(v); }

static INLINE unsigned MDFN_tzcount16(uint16 v) { return !v ? 16 : MDFN_tzcount16_0UD(v); }
static INLINE unsigned MDFN_tzcount32(uint32 v) { return !v ? 32 : MDFN_tzcount32_0UD(v); }
static INLINE unsigned MDFN_tzcount64(uint64 v) { return !v ? 64 : MDFN_tzcount64_0UD(v); }

static INLINE unsigned MDFN_log2(uint32 v) { return 31 ^ MDFN_lzcount32_0UD(v | 1); }
static INLINE unsigned MDFN_log2(uint64 v) { return 63 ^ MDFN_lzcount64_0UD(v | 1); }

static INLINE unsigned MDFN_log2(int32 v) { return MDFN_log2((uint32)v); }
static INLINE unsigned MDFN_log2(int64 v) { return MDFN_log2((uint64)v); }

// Rounds up to the nearest power of 2(treats input as unsigned to a degree, but be aware of integer promotion rules).
// Returns 0 on overflow.
static INLINE uint64 round_up_pow2(uint32 v) { uint64 tmp = (uint64)1 << MDFN_log2(v); return tmp << (tmp < v); }
static INLINE uint64 round_up_pow2(uint64 v) { uint64 tmp = (uint64)1 << MDFN_log2(v); return tmp << (tmp < v); }

static INLINE uint64 round_up_pow2(int32 v) { return round_up_pow2((uint32)v); }
static INLINE uint64 round_up_pow2(int64 v) { return round_up_pow2((uint64)v); }

// Rounds to the nearest power of 2(treats input as unsigned to a degree, but be aware of integer promotion rules).
static INLINE uint64 round_nearest_pow2(uint32 v, bool round_half_up = true) { uint64 tmp = (uint64)1 << MDFN_log2(v); return tmp << (v && (((v - tmp) << 1) >= (tmp + !round_half_up))); }
static INLINE uint64 round_nearest_pow2(uint64 v, bool round_half_up = true) { uint64 tmp = (uint64)1 << MDFN_log2(v); return tmp << (v && (((v - tmp) << 1) >= (tmp + !round_half_up))); }

static INLINE uint64 round_nearest_pow2(int32 v, bool round_half_up = true) { return round_nearest_pow2((uint32)v, round_half_up); }
static INLINE uint64 round_nearest_pow2(int64 v, bool round_half_up = true) { return round_nearest_pow2((uint64)v, round_half_up); }

// Some compilers' optimizers and some platforms might fubar the generated code from these macros,
// so some tests are run in...tests.cpp
#define sign_8_to_s16(_value) ((int16)(int8)(_value))
#define sign_9_to_s16(_value)  (((int16)((unsigned int)(_value) << 7)) >> 7)
#define sign_10_to_s16(_value)  (((int16)((uint32)(_value) << 6)) >> 6)
#define sign_11_to_s16(_value)  (((int16)((uint32)(_value) << 5)) >> 5)
#define sign_12_to_s16(_value)  (((int16)((uint32)(_value) << 4)) >> 4)
#define sign_13_to_s16(_value)  (((int16)((uint32)(_value) << 3)) >> 3)
#define sign_14_to_s16(_value)  (((int16)((uint32)(_value) << 2)) >> 2)
#define sign_15_to_s16(_value)  (((int16)((uint32)(_value) << 1)) >> 1)

// This obviously won't convert higher-than-32 bit numbers to signed 32-bit ;)
// Also, this shouldn't be used for 8-bit and 16-bit signed numbers, since you can
// convert those faster with typecasts...
#define sign_x_to_s32(_bits, _value) (((int32)((uint32)(_value) << (32 - _bits))) >> (32 - _bits))

static INLINE int32 clamp_to_u8(int32 i)
{
 if(i & 0xFFFFFF00)
  i = (((~i) >> 30) & 0xFF);

 return(i);
}

static INLINE int32 clamp_to_u16(int32 i)
{
 if(i & 0xFFFF0000)
  i = (((~i) >> 31) & 0xFFFF);

 return(i);
}

template<typename T, typename U, typename V> static INLINE void clamp(T *val, U minimum, V maximum)
{
 if(*val < minimum)
 {
  //printf("Warning: clamping to minimum(%d)\n", (int)minimum);
  *val = minimum;
 }
 if(*val > maximum)
 {
  //printf("Warning: clamping to maximum(%d)\n", (int)maximum);
  *val = maximum;
 }
}

#endif
