#ifndef __MDFN_TYPES
#define __MDFN_TYPES

#include <inttypes.h>

typedef int8_t int8;
typedef int16_t int16;
typedef int32_t int32;
typedef int64_t int64;

typedef uint8_t uint8;
typedef uint16_t uint16;
typedef uint32_t uint32;
typedef uint64_t uint64;


#ifdef __GNUC__

  #define INLINE inline __attribute__((always_inline))
  #define NO_INLINE __attribute__((noinline))

  #if defined(__386__) || defined(__i386__) || defined(__i386) || defined(_M_IX86) || defined(_M_I386)
    #define MDFN_FASTCALL __attribute__((fastcall))
  #else
    #define MDFN_FASTCALL
  #endif

  #define MDFN_FORMATSTR(a,b,c) __attribute__ ((format (a, b, c)));
  #define MDFN_WARN_UNUSED_RESULT __attribute__ ((warn_unused_result))

#else
  #warning "Not compiling with GCC(or compatible)"
  #define INLINE inline
  #define NO_INLINE

  #define MDFN_FASTCALL

  #define MDFN_FORMATSTR(a,b,c)

  #define MDFN_WARN_UNUSED_RESULT

#endif

#endif
