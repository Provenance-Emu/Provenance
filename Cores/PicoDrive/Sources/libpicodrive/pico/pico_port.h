#ifndef PICO_PORT_INCLUDED
#define PICO_PORT_INCLUDED

// provide size_t, uintptr_t
#include <stdlib.h>
#if !(defined(_MSC_VER) && _MSC_VER < 1800)
#include <stdint.h>
#endif
#include "pico_types.h"

#ifdef USE_LIBRETRO_VFS
#include "file_stream_transforms.h"
#endif

#if defined(__GNUC__) && defined(__i386__)
#define REGPARM(x) __attribute__((regparm(x)))
#else
#define REGPARM(x)
#endif

#ifdef __GNUC__
#define NOINLINE    __attribute__((noinline))
#define ALIGNED(n)  __attribute__((aligned(n)))
#define unlikely(x) __builtin_expect((x), 0)
#define likely(x)   __builtin_expect(!!(x), 1)
#else
#define NOINLINE
#define ALIGNED(n)
#define unlikely(x) (x)
#define likely(x) (x)
#endif

#ifdef _MSC_VER
#define snprintf _snprintf
#define strcasecmp _stricmp
#define strncasecmp _strnicmp
#define strdup _strdup
#endif


// There's no standard way to determine endianess at compile time. Try using
// some well known non-standard macros for detection.
#if defined __BYTE_ORDER__
#define	CPU_IS_LE	__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
#elif defined __BYTE_ORDER
#define	CPU_IS_LE	__BYTE_ORDER == __LITTLE_ENDIAN
#elif defined __BIG_ENDIAN__ || defined _M_PPC // Windows on PPC was big endian
#define	CPU_IS_LE	0
#elif defined __LITTLE_ENDIAN__ || defined _WIN32 // all other Windows is LE
#define	CPU_IS_LE	1
#else
#warning "can't detect byte order, assume little endian"
#define	CPU_IS_LE	1
#endif
// NB mixed endian integer platforms are not supported.

#if CPU_IS_LE
// address/offset operations
#define MEM_BE2(a)	((a)^1)		// addr/offs of u8 in u16, or u16 in u32
#define MEM_BE4(a)	((a)^3)		// addr/offs of u8 in u32
#define MEM_LE2(a)	(a)
#define MEM_LE4(a)	(a)
// swapping
#define CPU_BE2(v)	((u32)((u64)(v)<<16)|((u32)(v)>>16))
#define CPU_BE4(v)	(((u32)(v)>>24)|(((v)>>8)&0x00ff00)| \
			(((v)<<8)&0xff0000)|(u32)((v)<<24))
#define CPU_LE2(v)	(v)		// swap of 2*u16 in u32
#define CPU_LE4(v)	(v)		// swap of 4*u8  in u32
#else
// address/offset operations
#define MEM_BE2(a)	(a)
#define MEM_BE4(a)	(a)
#define MEM_LE2(a)	((a)^1)
#define MEM_LE4(a)	((a)^3)
// swapping
#define CPU_BE2(v)	(v)
#define CPU_BE4(v)	(v)
#define CPU_LE2(v)	((u32)((u64)(v)<<16)|((u32)(v)>>16))
#define CPU_LE4(v)	(((u32)(v)>>24)|(((v)>>8)&0x00ff00)| \
			(((v)<<8)&0xff0000)|(u32)((v)<<24))
#endif

#endif // PICO_PORT_INCLUDED
