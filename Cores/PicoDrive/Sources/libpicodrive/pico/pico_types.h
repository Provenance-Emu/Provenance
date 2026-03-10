#ifndef PICO_TYPES
#define PICO_TYPES

#include <stdint.h>

#ifndef __TAMTYPES_H__
#ifndef UTYPES_DEFINED
typedef uint8_t        u8;
typedef int8_t         s8;
typedef uint16_t       u16;
typedef int16_t        s16;
typedef uint32_t       u32;
typedef int32_t        s32;
typedef uint64_t       u64;
typedef int64_t        s64;
#endif
#endif

typedef uintptr_t      uptr; /* unsigned pointer-sized int */

typedef unsigned int   uint; /* printf casts */
typedef unsigned long  ulong;
#endif
