/*
 * minimum data types for MIPS and the Ultra64 RCP
 *
 * No copyright is intended on this file. :)
 *
 * To work with features of the RCP hardware, we need at the very least:
 *     1.  a 64-bit type or a type which can encompass 64-bit operations
 *     2.  signed and unsigned 32-or-more-bit types (s32, u32)
 *     3.  signed and unsigned 16-or-more-bit types (s16, u16)
 *     4.  signed and unsigned 8-or-more-bit types (s8, u8)
 *
 * This tends to coincide with the regulations of <stdint.h> and even most of
 * what is guaranteed by simple preprocessor logic and the C89 standard, so
 * the deduction of RCP hardware types will have the following priority:
 *     1.  compiler implementation of the <stdint.h> extension
 *     2.  64-bit ABI detection by the preprocessor with help from <limits.h>
 *     3.  preprocessor derivation of literal integer interpretation
 *     4.  the presumption of C89 conformance for 8-, 16-, and 32-bit types
 *         and the presumption of `long long` support for 64-bit types
 */

/*
 * Rather than call it "n64_types.h" or "my_stdint.h", the idea is that this
 * header should be maintainable to any independent implementation's needs,
 * especially in the event that one decides that type requirements should be
 * mandated by the user and not permanently merged into the C specifications.
 *
 * Custom, collision-free type definitions are also useful in that they can
 * be tested for cross-ABI portability by changing a custom type like `u32`
 * from `unsigned long` to `unsigned short` or vice-versa.
 */
#ifndef _MY_TYPES_H_
#define _MY_TYPES_H_

/*
 * This is the only method we really need to care about for defining types.
 *
 * All concerns of absolute plausibility are addressed with minimum-width
 * types; we do not require fixed-width types or any C99 dependency.
 */
#include <limits.h>

/*
 * Until proven otherwise, there are no standard integer types.
 */
#undef HAVE_STANDARD_INTEGER_TYPES

/*
 * an optional facility which could be used as an external alternative to
 * deducing minimum-width types (if the compiler agrees to rely on this level
 * of the language specifications to have it)
 *
 * Because no standard system is required to have any exact-width type, the
 * C99 enforcement of <stdint.h> is more of an early initiative (as in,
 * "better early than late" or "better early than never at all") rather than
 * a fully portable resource available or even possible all of the time.
 */
#if defined(__STDC_VERSION__) && (__STDC_VERSION__ >= 199901L)
#include <stdint.h>
#endif

/*
 * Even with -std=c89 or -ansi, modern GCC will tend to supply <stdint.h>.
 * That isn't needed--here--for LP64 ABI, however, so why assume it exists?
 */
#if defined(__GNUC__) && !defined(__LP64__)
#include <stdint.h>
#endif

/*
 * With or without external or internal support for <stdint.h>, we need to
 * confirm the level of support for RCP data types on the Nintendo 64.
 *
 * We only need minimum-width data types, not exact-width types.
 * Systems on which there is no 16- or 32-bit type, for example, can easily
 * be accounted for by the code itself using optimizable AND bit-masks.
 */
#if defined(INT8_MIN) && defined(INT8_MAX)
#define HAVE_INT8_EXACT
#endif
#if defined(INT_FAST8_MIN) && defined(INT_FAST8_MAX)
#define HAVE_INT8_FAST
#endif
#if defined(INT_LEAST8_MIN) && defined(INT_LEAST8_MAX)
#define HAVE_INT8_MINIMUM
#endif
#if defined(INT16_MIN) && defined(INT16_MAX)
#define HAVE_INT16_EXACT
#endif
#if defined(INT_FAST16_MIN) && defined(INT_FAST16_MAX)
#define HAVE_INT16_FAST
#endif
#if defined(INT_LEAST16_MIN) && defined(INT_LEAST16_MAX)
#define HAVE_INT16_MINIMUM
#endif
#if defined(INT32_MIN) && defined(INT32_MAX)
#define HAVE_INT32_EXACT
#endif
#if defined(INT_FAST32_MIN) && defined(INT_FAST32_MAX)
#define HAVE_INT32_FAST
#endif
#if defined(INT_LEAST32_MIN) && defined(INT_LEAST32_MAX)
#define HAVE_INT32_MINIMUM
#endif
#if defined(INT64_MIN) && defined(INT64_MAX)
#define HAVE_INT64_EXACT
#endif
#if defined(INT_FAST64_MIN) && defined(INT_FAST64_MAX)
#define HAVE_INT64_FAST
#endif
#if defined(INT_LEAST64_MIN) && defined(INT_LEAST64_MAX)
#define HAVE_INT64_MINIMUM
#endif

#if defined(HAVE_INT8_EXACT)\
 || defined(HAVE_INT8_FAST) \
 || defined(HAVE_INT8_MINIMUM)
#define HAVE_INT8
#endif
#if defined(HAVE_INT16_EXACT)\
 || defined(HAVE_INT16_FAST) \
 || defined(HAVE_INT16_MINIMUM)
#define HAVE_INT16
#endif
#if defined(HAVE_INT32_EXACT)\
 || defined(HAVE_INT32_FAST) \
 || defined(HAVE_INT32_MINIMUM)
#define HAVE_INT32
#endif
#if defined(HAVE_INT64_EXACT)\
 || defined(HAVE_INT64_FAST) \
 || defined(HAVE_INT64_MINIMUM)
#define HAVE_INT64
#endif

/*
 * This determines whether or not it is possible to use the evolution of the
 * C standards for compiler advice on how to define the types or whether we
 * will instead rely on preprocessor logic and ABI detection or C89 rules to
 * define each of the types.
 */
#if defined(HAVE_INT8) \
 && defined(HAVE_INT16)\
 && defined(HAVE_INT32)\
 && defined(HAVE_INT64)
#define HAVE_STANDARD_INTEGER_TYPES
#endif

/*
 * Since the Microsoft Windows API frequently uses `long` instead of `int` to
 * guarantee 32-bit DWORD types, they were forced to propose a "LLP64" ABI.
 */
#if defined(_MSC_VER)
#define MICROSOFT_ABI
#endif

#if defined(HAVE_INT8_EXACT)
typedef int8_t                  s8;
typedef uint8_t                 u8;
typedef s8                      i8;
#elif defined(HAVE_INT8_FAST)
typedef int_fast8_t             s8;
typedef uint_fast8_t            u8;
typedef s8                      i8;
#elif defined(HAVE_INT8_MINIMUM)
typedef int_least8_t            s8;
typedef uint_least8_t           u8;
typedef s8                      i8;
#elif defined(MICROSOFT_ABI)
typedef signed __int8           s8;
typedef unsigned __int8         u8;
typedef __int8                  i8;

#elif (SCHAR_MIN < -127 && SCHAR_MAX >= +127)
typedef signed char             s8;
typedef unsigned char           u8;
typedef char                    i8;
#else
#error Non-ANSI-conformant `char` size.
#endif

#if defined(HAVE_INT16_EXACT)
typedef int16_t                 s16;
typedef uint16_t                u16;
#elif defined(HAVE_INT16_FAST)
typedef int_fast16_t            s16;
typedef uint_fast16_t           u16;
#elif defined(HAVE_INT16_MINIMUM)
typedef int_least16_t           s16;
typedef uint_least16_t          u16;
#elif defined(MICROSOFT_ABI)
typedef signed __int16          s16;
typedef unsigned __int16        u16;

#elif (SCHAR_MIN < -32767 && SCHAR_MAX >= +32767)
typedef signed char             s16;
typedef unsigned char           u16;
#else
typedef signed short            s16;
typedef unsigned short          u16;
#endif

#if defined(HAVE_INT32_EXACT)
typedef int32_t                 s32;
typedef uint32_t                u32;
#elif defined(HAVE_INT32_FAST)
typedef int_fast32_t            s32;
typedef uint_fast32_t           u32;
#elif defined(HAVE_INT32_MINIMUM)
typedef int_least32_t           s32;
typedef uint_least32_t          u32;
#elif defined(MICROSOFT_ABI)
typedef signed __int32          s32;
typedef unsigned __int32        u32;

#elif (SCHAR_MIN < -2147483647L && SCHAR_MAX >= +2147483647L)
typedef signed char             s32;
typedef unsigned char           u32;
#elif (SHRT_MIN < -2147483647L && SHRT_MAX >= +2147483647L)
typedef signed short            s32;
typedef unsigned short          u32;
#elif (INT_MIN < -2147483647L && INT_MAX >= +2147483647L)
typedef signed int              s32;
typedef unsigned int            u32;
#else
typedef signed long             s32;
typedef unsigned long           u32;
#endif

#if defined(HAVE_INT64_EXACT)
typedef int64_t                 s64;
typedef uint64_t                u64;
#elif defined(HAVE_INT64_FAST)
typedef int_fast64_t            s64;
typedef uint_fast64_t           u64;
#elif defined(HAVE_INT64_MINIMUM)
typedef int_least64_t           s64;
typedef uint_least64_t          u64;
#elif defined(MICROSOFT_ABI)
typedef signed __int64          s64;
typedef unsigned __int64        u64;

#elif defined(__LP64__) && (0x00000000FFFFFFFFUL < ~0UL)
typedef long long             s64;
typedef unsigned long long           u64;
#elif (LONG_MIN < -9223372036854775807L && LONG_MAX >= +9223372036854775807L)
typedef signed long             s64;
typedef unsigned long           u64;
#else
typedef signed long long        s64;
typedef unsigned long long      u64;
#endif

/*
 * Although most types are signed by default, using `int' instead of `signed
 * int' and `i32' instead of `s32' can be preferable to denote cases where
 * the signedness of something operated on is irrelevant to the algorithm.
 */
typedef s16                     i16;
typedef s32                     i32;
typedef s64                     i64;

/*
 * If <stdint.h> was unavailable or not included (should be included before
 * "my_types.h" if it is ever to be included), then perhaps this is the
 * right opportunity to try defining the <stdint.h> types ourselves.
 *
 * Due to sole popularity, code can sometimes be easier to read when saying
 * things like "int8_t" instead of "i8", just because more people are more
 * likely to understand the <stdint.h> type names in generic C code.  To be
 * as neutral as possible, people will have every right to sometimes prefer
 * saying "uint32_t" instead of "u32" for the sake of modern standards.
 *
 * The below macro just means whether or not we had access to <stdint.h>
 * material to deduce any of our 8-, 16-, 32-, or 64-bit type definitions.
 */
#ifndef HAVE_STANDARD_INTEGER_TYPES
typedef s8      int8_t;
typedef u8      uint8_t;
typedef s16     int16_t;
typedef u16     uint16_t;
typedef s32     int32_t;
typedef u32     uint32_t;
typedef s64     int64_t;
typedef u64     uint64_t;
#define HAVE_STANDARD_INTEGER_TYPES
#endif

/*
 * MIPS-native types are `float' for f32, `double' for f64.
 * These type requirements are based on the MIPS manuals on the FPU.
 */
#include <float.h>

#if (FLT_MANT_DIG >= 24) && (FLT_MAX_EXP > 127)
typedef float                   f32;
#elif (DBL_MANT_DIG >= 24) && (DBL_MAX_EXP > 127)
typedef double                  f32;
#elif (LDBL_MANT_DIG >= 24) && (LDBL_MAX_EXP > 127)
typedef long double             f32;
#else
typedef struct {
#if (UINT_MAX >= (0x00000001UL << 23) - 1UL)
    unsigned f:  23; /* mantissa fraction */
#else
    unsigned long f;
#endif
    unsigned e:   8; /* biased exponent, from -126 to +127 for generic values */
    unsigned s:   1; /* mantissa sign bit */
} f32;
#endif

#if (DBL_MANT_DIG >= 53) && (DBL_MAX_EXP > 1023)
typedef double                  f64;
#elif (LDBL_MANT_DIG >= 53) && (LDBL_MAX_EXP > 1023)
typedef long double             f64;
#else
typedef struct {
    uint64_t f/*:  52*/;
    unsigned e:  11;
    unsigned s:   1;
} f64;
#endif

/*
 * Pointer types, serving as the memory reference address to the actual type.
 * I thought this was useful to have due to the various reasons for declaring
 * or using variable pointers in various styles and complex scenarios.
 *     ex) i32* pointer;
 *     ex) i32 * pointer;
 *     ex) i32 *a, *b, *c;
 *     neutral:  `pi32 pointer;' or `pi32 a, b, c;'
 */
typedef i8*                     pi8;
typedef i16*                    pi16;
typedef i32*                    pi32;
typedef i64*                    pi64;

typedef s8*                     ps8;
typedef s16*                    ps16;
typedef s32*                    ps32;
typedef s64*                    ps64;

typedef u8*                     pu8;
typedef u16*                    pu16;
typedef u32*                    pu32;
typedef u64*                    pu64;

typedef f32*                    pf32;
typedef f64*                    pf64;
typedef void*                   p_void;
typedef void(*p_func)(void);

/*
 * helper macros with exporting functions for shared objects or dynamically
 * loaded libraries
 */
#if defined(M64P_PLUGIN_API)
#define M64P_PLUGIN_PROTOTYPES 1
#include "m64p_common.h"
#include "m64p_config.h"
#include "m64p_plugin.h"
#include "m64p_types.h"
#include "osal_dynamiclib.h"
#else
#if defined(_WIN32)
#define EXPORT      __declspec(dllexport)
#define CALL        __cdecl
#else
#define EXPORT      __attribute__((visibility("default")))
#define CALL
#endif
#endif

/*
 * Commonly, Ultra64 will refer to these common symbols.
 * They seem to be fairly widely used outside of just <windows.h>.
 */
#if !defined(TRUE) && !defined(FALSE)
#define FALSE       0
#define TRUE        1
#endif

/*
 * Optimizing compilers aren't necessarily perfect compilers, but they do
 * have that extra chance of supporting explicit [anti-]inline instructions.
 */
#ifdef _MSC_VER
#define INLINE      __inline
#define NOINLINE    __declspec(noinline)
#define ALIGNED     _declspec(align(16))
#elif defined(__GNUC__)
#define INLINE      inline
#define NOINLINE    __attribute__((noinline))
#define ALIGNED     __attribute__((aligned(16)))
#else
#define INLINE
#define NOINLINE
#define ALIGNED
#endif

/*
 * aliasing helpers
 * Strictly put, this may be unspecified behavior, but it's nice to have!
 */
typedef union {
    u8 B[2];
    s8 SB[2];

    i16 W;
    u16 UW;
    s16 SW; /* Here, again, explicitly writing "signed" may help clarity. */
} word_16;
typedef union {
    u8 B[4];
    s8 SB[4];

    i16 H[2];
    u16 UH[2];
    s16 SH[2];

    i32 W;
    u32 UW;
    s32 SW;
} word_32;
typedef union {
    u8 B[8];
    s8 SB[8];

    i16 Q[4];
    u16 UQ[4];
    s16 SQ[4];

    i32 H[2];
    u32 UH[2];
    s32 SH[2];

    i64 W;
    u64 UW;
    s64 SW;
} word_64;

/*
 * helper macros for indexing memory in the above unions
 * EEP!  Currently concentrates mostly on 32-bit endianness.
 */
#ifndef ENDIAN_M
#if defined(__BIG_ENDIAN__)
#define ENDIAN_M    ( 0U)
#else
#define ENDIAN_M    (~0U)
#endif
#endif

#define ENDIAN_SWAP_BYTE    (ENDIAN_M & 7U & 3U)
#define ENDIAN_SWAP_HALF    (ENDIAN_M & 6U & 2U)
#define ENDIAN_SWAP_BIMI    (ENDIAN_M & 5U & 1U)
#define ENDIAN_SWAP_WORD    (ENDIAN_M & 4U & 0U)

#define BES(address)    ((address) ^ ENDIAN_SWAP_BYTE)
#define HES(address)    ((address) ^ ENDIAN_SWAP_HALF)
#define MES(address)    ((address) ^ ENDIAN_SWAP_BIMI)
#define WES(address)    ((address) ^ ENDIAN_SWAP_WORD)

/*
 * extra types of encoding for the well-known MIPS RISC architecture
 * Possibly implement other machine types in future versions of this header.
 */
typedef struct {
    unsigned opcode   :   6;
    unsigned rs       :   5;
    unsigned rt       :   5;
    unsigned rd       :   5;
    unsigned sa       :   5;
    unsigned function :   6;
} MIPS_type_R;
typedef struct {
    unsigned opcode   :   6;
    unsigned rs       :   5;
    unsigned rt       :   5;
    unsigned immediate:  16;
} MIPS_type_I;

#if (UINT_MAX >= (0x00000001UL << 26) - 1UL)
typedef struct {
    unsigned opcode   :   6;
    unsigned target   :  26;
} MIPS_type_J;
#else
typedef struct {
    unsigned opcode   :   6;
    unsigned long target; /* If `int' can't store 26 bits, `long' can. */
} MIPS_type_J;
#endif

#endif
