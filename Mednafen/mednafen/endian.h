#ifndef __MDFN_ENDIAN_H
#define __MDFN_ENDIAN_H

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

void Endian_A16_Swap(void *src, uint32 nelements);
void Endian_A32_Swap(void *src, uint32 nelements);
void Endian_A64_Swap(void *src, uint32 nelements);

void Endian_A16_NE_LE(void *src, uint32 nelements);
void Endian_A32_NE_LE(void *src, uint32 nelements);
void Endian_A64_NE_LE(void *src, uint32 nelements);

void Endian_A16_NE_BE(void *src, uint32 nelements);
void Endian_A32_NE_BE(void *src, uint32 nelements);
void Endian_A64_NE_BE(void *src, uint32 nelements);

void Endian_V_NE_LE(void *src, uint32 bytesize);
void Endian_V_NE_BE(void *src, uint32 bytesize);

static INLINE uint16 MDFN_bswap16(uint16 v)
{
 return (v << 8) | (v >> 8);
}

static INLINE uint32 MDFN_bswap32(uint32 v)
{
 return (v << 24) | ((v & 0xFF00) << 8) | ((v >> 8) & 0xFF00) | (v >> 24);
}

static INLINE uint64 MDFN_bswap64(uint64 v)
{
 return (v << 56) | (v >> 56) | ((v & 0xFF00) << 40) | ((v >> 40) & 0xFF00) | ((uint64)MDFN_bswap32(v >> 16) << 16);
}

#ifdef LSB_FIRST
 #define MDFN_ENDIANH_IS_BIGENDIAN 0
#else
 #define MDFN_ENDIANH_IS_BIGENDIAN 1
#endif

//
// X endian.
//
template<int isbigendian, typename T, bool aligned>
static INLINE T MDFN_deXsb(const void* ptr)
{
 T tmp;

 memcpy(&tmp, MDFN_ASSUME_ALIGNED(ptr, (aligned ? sizeof(T) : 1)), sizeof(T));

 if(isbigendian != -1 && isbigendian != MDFN_ENDIANH_IS_BIGENDIAN)
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
 const uint8* morp = (const uint8*)ptr;
 return(morp[0]|(morp[1]<<8)|(morp[2]<<16));
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
 const uint8* morp = (const uint8*)ptr;
 return((morp[2]<<0)|(morp[1]<<8)|(morp[0]<<16));
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

 if(isbigendian != -1 && isbigendian != MDFN_ENDIANH_IS_BIGENDIAN)
 {
  static_assert(sizeof(T) == 1 || sizeof(T) == 2 || sizeof(T) == 4 || sizeof(T) == 8, "Gummy penguins.");

  if(sizeof(T) == 8)
   tmp = MDFN_bswap64(value);
  else if(sizeof(T) == 4)
   tmp = MDFN_bswap32(value);
  else if(sizeof(T) == 2)
   tmp = MDFN_bswap16(value);
 }

 memcpy(MDFN_ASSUME_ALIGNED(ptr, (aligned ? sizeof(T) : 1)), &tmp, sizeof(T));
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
 uint8* morp = (uint8*)ptr;

 morp[0] = value;
 morp[1] = value >> 8;
 morp[2] = value >> 16;
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
 uint8* morp = (uint8*)ptr;

 morp[0] = value;
 morp[1] = value >> 8;
 morp[2] = value >> 16;
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

#endif
