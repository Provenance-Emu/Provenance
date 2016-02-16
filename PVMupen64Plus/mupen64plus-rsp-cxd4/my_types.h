/******************************************************************************\
* Project:  Standard Integer Type Definitions                                  *
* Authors:  Iconoclast                                                         *
* Release:  2014.12.15                                                         *
* License:  CC0 Public Domain Dedication                                       *
*                                                                              *
* To the extent possible under law, the author(s) have dedicated all copyright *
* and related and neighboring rights to this software to the public domain     *
* worldwide. This software is distributed without any warranty.                *
*                                                                              *
* You should have received a copy of the CC0 Public Domain Dedication along    *
* with this software.                                                          *
* If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.             *
\******************************************************************************/

#ifndef _MY_TYPES_H_
#define _MY_TYPES_H_

typedef char                    i8;
typedef signed char             s8;
typedef unsigned char           u8;

/*
 * Use three procedures for standard integer type definitions from C.
 *     1.  If compiling with MSVC, use Microsoft's LLP64 fixed-size types.
 *         If it's not a Microsoft compiler, it isn't using the LLP64 model.
 *     2.  If C99 or later support is found, attempt to #include <stdint.h>
 *         and to use possible C99 type definitions.  The above method for
 *         MSFT compilers has the pro of not raising subtle C89 warnings.
 *     3.  If C99 support was not found, hope for a LP64 model and the best.
 *         Even C89 regulates that short >= 16b; int >= 16b; long >= 32b.
 */
#ifdef _MSC_VER

typedef signed __int16          s16;
typedef unsigned __int16        u16;

typedef signed __int32          s32;
typedef unsigned __int32        u32;

typedef signed __int64          s64;
typedef unsigned __int64        u64;

#elif (__STDC_VERSION__ >= 199901L) | !defined(__STDC_VERSION__)

#include <stdint.h>

typedef uint16_t                u16;
typedef uint32_t                u32;
typedef uint64_t                u64;

typedef int16_t                 s16;
typedef int32_t                 s32;
typedef int64_t                 s64;

#else

typedef signed short            s16;
typedef unsigned short          u16;

typedef signed int              s32;
typedef unsigned int            u32;

typedef signed long             s64;
typedef unsigned long           u64;

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
 * Single- and double-precision floating-point data types have a little less
 * room for maintenance across different CPU processors, as the C standard
 * just provides `float' and `[long] double'.
 */
typedef float                   f32;
typedef double                  f64;

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

    i16 F[4];
    u16 UF[4];
    s16 SF[4];

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
#if defined(__BIG_ENDIAN__) | (__BYTE_ORDER != __LITTLE_ENDIAN)
#define ENDIAN_M    ( 0)
#else
#define ENDIAN_M    (~0)
#endif
#endif

#define ENDIAN_SWAP_BYTE    (ENDIAN_M & 0x7 & 3)
#define ENDIAN_SWAP_HALF    (ENDIAN_M & 0x6 & 2)
#define ENDIAN_SWAP_BIMI    (ENDIAN_M & 0x5 & 1)
#define ENDIAN_SWAP_WORD    (ENDIAN_M & 0x4 & 0)

#define BES(address)    ((address) ^ ENDIAN_SWAP_BYTE)
#define HES(address)    ((address) ^ ENDIAN_SWAP_HALF)
#define MES(address)    ((address) ^ ENDIAN_SWAP_BIMI)
#define WES(address)    ((address) ^ ENDIAN_SWAP_WORD)

/*
 * extra types of encoding for the well-known MIPS RISC architecture
 * Possibly implement other machine types in future versions of this header.
 */
typedef struct {
    unsigned opcode:  6;
    unsigned rs:  5;
    unsigned rt:  5;
    unsigned rd:  5;
    unsigned sa:  5;
    unsigned function:  6;
} MIPS_type_R;
typedef struct {
    unsigned opcode:  6;
    unsigned rs:  5;
    unsigned rt:  5;
    unsigned imm:  16;
} MIPS_type_I;

/*
 * Maybe worth including, maybe not.
 * It's sketchy since bit-fields pertain to `int' type, of which the size is
 * not necessarily going to be even 4 bytes.  On C compilers for MIPS itself,
 * almost certainly, but is this really important to have?
 */
#if 0
typedef struct {
    unsigned opcode:  6;
    unsigned target:  26;
} MIPS_type_J;
#endif

#endif
