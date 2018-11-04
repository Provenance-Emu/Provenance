/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* endian.h:
**  Copyright (C) 2006-2017 Mednafen Team
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

#ifndef __MDFN_ENDIAN_H
#define __MDFN_ENDIAN_H

void Endian_A16_Swap(void *src, uint32 nelements);
void Endian_A32_Swap(void *src, uint32 nelements);
void Endian_A64_Swap(void *src, uint32 nelements);

void Endian_A16_NE_LE(void *src, uint32 nelements);
void Endian_A32_NE_LE(void *src, uint32 nelements);
void Endian_A64_NE_LE(void *src, uint32 nelements);

void Endian_A16_NE_BE(void *src, uint32 nelements);
void Endian_A32_NE_BE(void *src, uint32 nelements);
void Endian_A64_NE_BE(void *src, uint32 nelements);

void Endian_V_NE_LE(void* p, size_t len);
void Endian_V_NE_BE(void* p, size_t len);

//
//
//

static INLINE uint32 BitsExtract(const uint8* ptr, const size_t bit_offset, const size_t bit_count)
{
 uint32 ret = 0;

 for(size_t x = 0; x < bit_count; x++)
 {
  size_t co = bit_offset + x;
  bool b = (ptr[co >> 3] >> (co & 7)) & 1;

  ret |= (uint64)b << x;
 }

 return ret;
}

static INLINE void BitsIntract(uint8* ptr, const size_t bit_offset, const size_t bit_count, uint32 value)
{
 for(size_t x = 0; x < bit_count; x++)
 {
  size_t co = bit_offset + x;
  bool b = (value >> x) & 1;
  uint8 tmp = ptr[co >> 3];

  tmp &= ~(1 << (co & 7));
  tmp |= b << (co & 7);

  ptr[co >> 3] = tmp;
 }
}

/*
 Regarding safety of calling MDFN_*sb<true> on dynamically-allocated memory with new uint8[], see C++ standard 3.7.3.1(i.e. it should be
 safe provided the offsets into the memory are aligned/multiples of the MDFN_*sb access type).  malloc()'d and calloc()'d
 memory should be safe as well.

 Statically-allocated arrays/memory should be unioned with a big POD type or C++11 "alignas"'d.  (May need to audit code to ensure
 this is being done).
*/

static INLINE uint16 MDFN_bswap16(uint16 v)
{
#if defined(_MSC_VER)
 return _byteswap_ushort(v);
#else
 return (v << 8) | (v >> 8);
#endif
}

static INLINE uint32 MDFN_bswap32(uint32 v)
{
#if defined(_MSC_VER)
 return _byteswap_ulong(v);
#else
 return (v << 24) | ((v & 0xFF00) << 8) | ((v >> 8) & 0xFF00) | (v >> 24);
#endif
}

static INLINE uint64 MDFN_bswap64(uint64 v)
{
#if defined(_MSC_VER)
 return _byteswap_uint64(v);
#else
 return (v << 56) | (v >> 56) | ((v & 0xFF00) << 40) | ((v >> 40) & 0xFF00) | ((uint64)MDFN_bswap32(v >> 16) << 16);
#endif
}

//
// X endian.
//
template<int isbigendian, typename T, bool aligned>
static INLINE T MDFN_deXsb(const void* ptr)
{
 T tmp;

 memcpy(&tmp, MDFN_ASSUME_ALIGNED(ptr, (aligned ? alignof(T) : 1)), sizeof(T));

 if(isbigendian != -1 && isbigendian != (int)MDFN_IS_BIGENDIAN)
 {
  static_assert(sizeof(T) == 1 || sizeof(T) == 2 || sizeof(T) == 4 || sizeof(T) == 8, "Gummy penguins.");

  if(sizeof(T) == 8)
   return MDFN_bswap64(tmp);
  else if(sizeof(T) == 4)
   return MDFN_bswap32(tmp);
  else if(sizeof(T) == 2)
   return MDFN_bswap16(tmp);
 }

 return tmp;
}

//
// Native endian.
//
template<typename T, bool aligned = false>
static INLINE T MDFN_densb(const void* ptr)
{
 return MDFN_deXsb<-1, T, aligned>(ptr);
}

//
// Little endian.
//
template<typename T, bool aligned = false>
static INLINE T MDFN_delsb(const void* ptr)
{
 return MDFN_deXsb<0, T, aligned>(ptr);
}

template<bool aligned = false>
static INLINE uint16 MDFN_de16lsb(const void* ptr)
{
 return MDFN_delsb<uint16, aligned>(ptr);
}

static INLINE uint32 MDFN_de24lsb(const void* ptr)
{
 const uint8* ptr_u8 = (const uint8*)ptr;

 return (ptr_u8[0] << 0) | (ptr_u8[1] << 8) | (ptr_u8[2] << 16);
}

template<bool aligned = false>
static INLINE uint32 MDFN_de32lsb(const void* ptr)
{
 return MDFN_delsb<uint32, aligned>(ptr);
}

template<bool aligned = false>
static INLINE uint64 MDFN_de64lsb(const void* ptr)
{
 return MDFN_delsb<uint64, aligned>(ptr);
}

//
// Big endian.
//
template<typename T, bool aligned = false>
static INLINE T MDFN_demsb(const void* ptr)
{
 return MDFN_deXsb<1, T, aligned>(ptr);
}

template<bool aligned = false>
static INLINE uint16 MDFN_de16msb(const void* ptr)
{
 return MDFN_demsb<uint16, aligned>(ptr);
}

static INLINE uint32 MDFN_de24msb(const void* ptr)
{
 const uint8* ptr_u8 = (const uint8*)ptr;

 return (ptr_u8[0] << 16) | (ptr_u8[1] << 8) | (ptr_u8[2] << 0);
}

template<bool aligned = false>
static INLINE uint32 MDFN_de32msb(const void* ptr)
{
 return MDFN_demsb<uint32, aligned>(ptr);
}

template<bool aligned = false>
static INLINE uint64 MDFN_de64msb(const void* ptr)
{
 return MDFN_demsb<uint64, aligned>(ptr);
}

//
//
//
//
//
//
//
//

//
// X endian.
//
template<int isbigendian, typename T, bool aligned>
static INLINE void MDFN_enXsb(void* ptr, T value)
{
 T tmp = value;

 if(isbigendian != -1 && isbigendian != (int)MDFN_IS_BIGENDIAN)
 {
  static_assert(sizeof(T) == 1 || sizeof(T) == 2 || sizeof(T) == 4 || sizeof(T) == 8, "Gummy penguins.");

  if(sizeof(T) == 8)
   tmp = MDFN_bswap64(value);
  else if(sizeof(T) == 4)
   tmp = MDFN_bswap32(value);
  else if(sizeof(T) == 2)
   tmp = MDFN_bswap16(value);
 }

 memcpy(MDFN_ASSUME_ALIGNED(ptr, (aligned ? alignof(T) : 1)), &tmp, sizeof(T));
}

//
// Native endian.
//
template<typename T, bool aligned = false>
static INLINE void MDFN_ennsb(void* ptr, T value)
{
 MDFN_enXsb<-1, T, aligned>(ptr, value);
}

//
// Little endian.
//
template<typename T, bool aligned = false>
static INLINE void MDFN_enlsb(void* ptr, T value)
{
 MDFN_enXsb<0, T, aligned>(ptr, value);
}

template<bool aligned = false>
static INLINE void MDFN_en16lsb(void* ptr, uint16 value)
{
 MDFN_enlsb<uint16, aligned>(ptr, value);
}

static INLINE void MDFN_en24lsb(void* ptr, uint32 value)
{
 uint8* ptr_u8 = (uint8*)ptr;

 ptr_u8[0] = value >> 0;
 ptr_u8[1] = value >> 8;
 ptr_u8[2] = value >> 16;
}

template<bool aligned = false>
static INLINE void MDFN_en32lsb(void* ptr, uint32 value)
{
 MDFN_enlsb<uint32, aligned>(ptr, value);
}

template<bool aligned = false>
static INLINE void MDFN_en64lsb(void* ptr, uint64 value)
{
 MDFN_enlsb<uint64, aligned>(ptr, value);
}


//
// Big endian.
//
template<typename T, bool aligned = false>
static INLINE void MDFN_enmsb(void* ptr, T value)
{
 MDFN_enXsb<1, T, aligned>(ptr, value);
}

template<bool aligned = false>
static INLINE void MDFN_en16msb(void* ptr, uint16 value)
{
 MDFN_enmsb<uint16, aligned>(ptr, value);
}

static INLINE void MDFN_en24msb(void* ptr, uint32 value)
{
 uint8* ptr_u8 = (uint8*)ptr;

 ptr_u8[0] = value >> 16;
 ptr_u8[1] = value >> 8;
 ptr_u8[2] = value >> 0;
}

template<bool aligned = false>
static INLINE void MDFN_en32msb(void* ptr, uint32 value)
{
 MDFN_enmsb<uint32, aligned>(ptr, value);
}

template<bool aligned = false>
static INLINE void MDFN_en64msb(void* ptr, uint64 value)
{
 MDFN_enmsb<uint64, aligned>(ptr, value);
}


//
//
//
//
//
//

template<typename T, typename X>
static INLINE uintptr_t neX_ptr_be(uintptr_t const base, const size_t byte_offset)
{
#ifdef MSB_FIRST
 return base + (byte_offset &~ (sizeof(T) - 1));
#else
 return base + (((byte_offset &~ (sizeof(T) - 1)) ^ (sizeof(X) - std::min<size_t>(sizeof(X), sizeof(T)))));
#endif
}

template<typename T, typename X>
static INLINE uintptr_t neX_ptr_le(uintptr_t const base, const size_t byte_offset)
{
#ifdef LSB_FIRST
 return base + (byte_offset &~ (sizeof(T) - 1));
#else
 return base + (((byte_offset &~ (sizeof(T) - 1)) ^ (sizeof(X) - std::min<size_t>(sizeof(X), sizeof(T)))));
#endif
}

template<typename T, typename BT>
static INLINE void ne16_wbo_be(BT base, const size_t byte_offset, const T value)
{
 static_assert(sizeof(T) == 1 || sizeof(T) == 2 || sizeof(T) == 4, "Unsupported type size");
 static_assert(std::is_same<BT, uintptr_t>::value || std::is_convertible<BT, uint16*>::value, "Wrong base type");

 uintptr_t const ptr = neX_ptr_be<T, uint16>((uintptr_t)base, byte_offset);

 if(sizeof(T) == 4)
 {
  uint16* const ptr16 = (uint16*)ptr;

  ptr16[0] = value >> 16;
  ptr16[1] = value;
 }
 else
  *(T*)ptr = value;
}

template<typename T, typename BT>
static INLINE T ne16_rbo_be(BT base, const size_t byte_offset)
{
 static_assert(sizeof(T) == 1 || sizeof(T) == 2 || sizeof(T) == 4, "Unsupported type size");
 static_assert(std::is_same<BT, uintptr_t>::value || std::is_convertible<BT, const uint16*>::value, "Wrong base type");

 uintptr_t const ptr = neX_ptr_be<T, uint16>((uintptr_t)base, byte_offset);

 if(sizeof(T) == 4)
 {
  uint16* const ptr16 = (uint16*)ptr;
  T tmp;

  tmp  = ptr16[0] << 16;
  tmp |= ptr16[1];

  return tmp;
 }
 else
  return *(T*)ptr;
}

template<typename T, bool IsWrite, typename BT>
static INLINE void ne16_rwbo_be(BT base, const size_t byte_offset, T* value)
{
 if(IsWrite)
  ne16_wbo_be<T>(base, byte_offset, *value);
 else
  *value = ne16_rbo_be<T>(base, byte_offset);
}

//
//
//

template<typename T, typename BT>
static INLINE void ne16_wbo_le(BT base, const size_t byte_offset, const T value)
{
 static_assert(sizeof(T) == 1 || sizeof(T) == 2 || sizeof(T) == 4, "Unsupported type size");
 static_assert(std::is_same<BT, uintptr_t>::value || std::is_convertible<BT, uint16*>::value, "Wrong base type");

 uintptr_t const ptr = neX_ptr_le<T, uint16>((uintptr_t)base, byte_offset);

 if(sizeof(T) == 4)
 {
  uint16* const ptr16 = (uint16*)ptr;

  ptr16[0] = value;
  ptr16[1] = value >> 16;
 }
 else
  *(T*)ptr = value;
}

template<typename T, typename BT>
static INLINE T ne16_rbo_le(BT base, const size_t byte_offset)
{
 static_assert(sizeof(T) == 1 || sizeof(T) == 2 || sizeof(T) == 4, "Unsupported type size");
 static_assert(std::is_same<BT, uintptr_t>::value || std::is_convertible<BT, const uint16*>::value, "Wrong base type");

 uintptr_t const ptr = neX_ptr_le<T, uint16>((uintptr_t)base, byte_offset);

 if(sizeof(T) == 4)
 {
  uint16* const ptr16 = (uint16*)ptr;
  T tmp;

  tmp  = ptr16[0];
  tmp |= ptr16[1] << 16;

  return tmp;
 }
 else
  return *(T*)ptr;
}


template<typename T, bool IsWrite, typename BT>
static INLINE void ne16_rwbo_le(BT base, const size_t byte_offset, T* value)
{
 if(IsWrite)
  ne16_wbo_le<T>(base, byte_offset, *value);
 else
  *value = ne16_rbo_le<T>(base, byte_offset);
}

//
//
//
template<typename T, typename BT>
static INLINE void ne64_wbo_be(BT base, const size_t byte_offset, const T value)
{
 static_assert(sizeof(T) == 1 || sizeof(T) == 2 || sizeof(T) == 4 || sizeof(T) == 8, "Unsupported type size");
 static_assert(std::is_same<BT, uintptr_t>::value || std::is_convertible<BT, uint64*>::value, "Wrong base type");

 uintptr_t const ptr = neX_ptr_be<T, uint64>((uintptr_t)base, byte_offset);

 memcpy(MDFN_ASSUME_ALIGNED((void*)ptr, alignof(T)), &value, sizeof(T));
}

template<typename T, typename BT>
static INLINE T ne64_rbo_be(BT base, const size_t byte_offset)
{
 static_assert(sizeof(T) == 1 || sizeof(T) == 2 || sizeof(T) == 4 || sizeof(T) == 8, "Unsupported type size");
 static_assert(std::is_same<BT, uintptr_t>::value || std::is_convertible<BT, const uint64*>::value, "Wrong base type");

 uintptr_t const ptr = neX_ptr_be<T, uint64>((uintptr_t)base, byte_offset);
 T ret;

 memcpy(&ret, MDFN_ASSUME_ALIGNED((void*)ptr, alignof(T)), sizeof(T));

 return ret;
}

template<typename T, bool IsWrite, typename BT>
static INLINE void ne64_rwbo_be(BT base, const size_t byte_offset, T* value)
{
 if(IsWrite)
  ne64_wbo_be<T>(base, byte_offset, *value);
 else
  *value = ne64_rbo_be<T>(base, byte_offset);
}
//
//
//
template<typename T, typename BT>
static INLINE void ne64_wbo_le(BT base, const size_t byte_offset, const T value)
{
 static_assert(sizeof(T) == 1 || sizeof(T) == 2 || sizeof(T) == 4 || sizeof(T) == 8, "Unsupported type size");
 static_assert(std::is_same<BT, uintptr_t>::value || std::is_convertible<BT, uint64*>::value, "Wrong base type");

 uintptr_t const ptr = neX_ptr_le<T, uint64>((uintptr_t)base, byte_offset);

 memcpy(MDFN_ASSUME_ALIGNED((void*)ptr, alignof(T)), &value, sizeof(T));
}

template<typename T, typename BT>
static INLINE T ne64_rbo_le(BT base, const size_t byte_offset)
{
 static_assert(sizeof(T) == 1 || sizeof(T) == 2 || sizeof(T) == 4 || sizeof(T) == 8, "Unsupported type size");
 static_assert(std::is_same<BT, uintptr_t>::value || std::is_convertible<BT, const uint64*>::value, "Wrong base type");

 uintptr_t const ptr = neX_ptr_le<T, uint64>((uintptr_t)base, byte_offset);
 T ret;

 memcpy(&ret, MDFN_ASSUME_ALIGNED((void*)ptr, alignof(T)), sizeof(T));

 return ret;
}

template<typename T, bool IsWrite, typename BT>
static INLINE void ne64_rwbo_le(BT base, const size_t byte_offset, T* value)
{
 if(IsWrite)
  ne64_wbo_le<T>(base, byte_offset, *value);
 else
  *value = ne64_rbo_le<T>(base, byte_offset);
}


#endif
