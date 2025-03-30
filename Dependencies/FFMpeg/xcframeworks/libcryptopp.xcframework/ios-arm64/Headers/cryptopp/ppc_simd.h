// ppc_simd.h - written and placed in public domain by Jeffrey Walton

/// \file ppc_simd.h
/// \brief Support functions for PowerPC and vector operations
/// \details This header provides an agnostic interface into Clang, GCC
///  and IBM XL C/C++ compilers modulo their different built-in functions
///  for accessing vector instructions.
/// \details The abstractions are necessary to support back to GCC 4.8 and
///  XLC 11 and 12. GCC 4.8 and 4.9 are still popular, and they are the
///  default compiler for GCC112, GCC119 and others on the compile farm.
///  Older IBM XL C/C++ compilers also have the need due to lack of
///  <tt>vec_xl</tt> and <tt>vec_xst</tt> support on some platforms. Modern
///  compilers provide best support and don't need many of the hacks
///  below.
/// \details The library is tested with the following PowerPC machines and
///  compilers. GCC110, GCC111, GCC112, GCC119 and GCC135 are provided by
///  the <A HREF="https://cfarm.tetaneutral.net/">GCC Compile Farm</A>
///  - PowerMac G5, OSX 10.5, POWER4, Apple GCC 4.0
///  - PowerMac G5, OSX 10.5, POWER4, Macports GCC 5.0
///  - GCC110, Linux, POWER7, GCC 4.8.5
///  - GCC110, Linux, POWER7, XLC 12.01
///  - GCC111, AIX, POWER7, GCC 4.8.1
///  - GCC111, AIX, POWER7, XLC 12.01
///  - GCC112, Linux, POWER8, GCC 4.8.5
///  - GCC112, Linux, POWER8, XLC 13.01
///  - GCC112, Linux, POWER8, Clang 7.0
///  - GCC119, AIX, POWER8, GCC 7.2.0
///  - GCC119, AIX, POWER8, XLC 13.01
///  - GCC135, Linux, POWER9, GCC 7.0
/// \details 12 machines are used for testing because the three compilers form
///  five or six profiles. The profiles are listed below.
///  - GCC (Linux GCC, Macports GCC, etc. Consistent across machines)
///  - XLC 13.0 and earlier (all IBM components)
///  - XLC 13.1 and later on Linux (LLVM front-end, no compatibility macros)
///  - XLC 13.1 and later on Linux (LLVM front-end, -qxlcompatmacros option)
///  - early LLVM Clang (traditional Clang compiler)
///  - late LLVM Clang (traditional Clang compiler)
/// \details The LLVM front-end makes it tricky to write portable code because
///  LLVM pretends to be other compilers but cannot consume other compiler's
///  builtins. When using XLC with -qxlcompatmacros the compiler pretends to
///  be GCC, Clang and XLC all at once but it can only consume it's variety
///  of builtins.
/// \details At Crypto++ 8.0 the various <tt>Vector{FuncName}</tt> were
///  renamed to <tt>Vec{FuncName}</tt>. For example, <tt>VectorAnd</tt> was
///  changed to <tt>VecAnd</tt>. The name change helped consolidate two
///  slightly different implementations.
/// \details At Crypto++ 8.3 the library added select 64-bit functions for
///  32-bit Altivec. For example, <tt>VecAdd64</tt> and <tt>VecSub64</tt>
///  take 32-bit vectors and adds or subtracts them as if there were vectors
///  with two 64-bit elements. The functions dramtically improve performance
///  for some algorithms on some platforms, like SIMON128 and SPECK128 on
///  Power6 and earlier. For example, SPECK128 improved from 70 cpb to
///  10 cpb on an old PowerMac. Use the functions like shown below.
///  <pre>
///    \#if defined(_ARCH_PWR8)
///    \#  define speck128_t uint64x2_p
///    \#else
///    \#  define speck128_t uint32x4_p
///    \#endif
///
///    speck128_t rk, x1, x2, y1, y2;
///    rk = (speck128_t)VecLoadAligned(ptr);
///    x1 = VecRotateRight64<8>(x1);
///    x1 = VecAdd64(x1, y1);
///    ...</pre>
/// \since Crypto++ 6.0, LLVM Clang compiler support since Crypto++ 8.0

// Use __ALTIVEC__, _ARCH_PWR7, __VSX__, and _ARCH_PWR8 when detecting
// actual availaibility of the feature for the source file being compiled.
// The preprocessor macros depend on compiler options like -maltivec; and
// not compiler versions.

// For GCC see https://gcc.gnu.org/onlinedocs/gcc/Basic-PowerPC-Built-in-Functions.html
// For XLC see the Compiler Reference manual. For Clang you have to experiment.
// Clang does not document the compiler options, does not reject options it does
// not understand, and pretends to be other compilers even though it cannot
// process the builtins and intrinsics. Clang will waste hours of your time.

// DO NOT USE this pattern in VecLoad and VecStore. We have to use the
// code paths guarded by preprocessor macros because XLC 12 generates
// bad code in some places. To verify the bad code generation test on
// GCC111 with XLC 12.01 installed. XLC 13.01 on GCC112 and GCC119 are OK.
//
//   inline uint32x4_p VecLoad(const byte src[16])
//   {
//   #if defined(__VSX__) || defined(_ARCH_PWR8)
//       return (uint32x4_p) *(uint8x16_p*)((byte*)src);
//   #else
//       return VecLoad_ALTIVEC(src);
//   #endif
//   }

// We should be able to perform the load using inline asm on Power7 with
// VSX or Power8. The inline asm will avoid C undefined behavior due to
// casting from byte* to word32*. We are safe because our byte* are
// 16-byte aligned for Altivec. Below is the big endian load. Little
// endian would need to follow with xxpermdi for the reversal.
//
//   __asm__ ("lxvw4x %x0, %1, %2" : "=wa"(v) : "r"(0), "r"(src) : );

// GCC and XLC use integer math for the address (D-form or byte-offset
// in the ISA manual). LLVM uses pointer math for the address (DS-form
// or indexed in the ISA manual). To keep them consistent we calculate
// the address from the offset and pass to a load or store function
// using a 0 offset.

#ifndef CRYPTOPP_PPC_CRYPTO_H
#define CRYPTOPP_PPC_CRYPTO_H

#include "config.h"
#include "misc.h"

#if defined(__ALTIVEC__)
# include <altivec.h>
# undef vector
# undef pixel
# undef bool
#endif

// XL C++ on AIX does not define VSX and does not
// provide an option to set it. We have to set it
// for the code below. This define must stay in
// sync with the define in test_ppc_power7.cpp.
#ifndef CRYPTOPP_DISABLE_POWER7
# if defined(_AIX) && defined(_ARCH_PWR7) && defined(__xlC__)
#  define __VSX__ 1
# endif
#endif

// XL C++ on AIX does not define CRYPTO and does not
// provide an option to set it. We have to set it
// for the code below. This define must stay in
// sync with the define in test_ppc_power8.cpp
#ifndef CRYPTOPP_DISABLE_POWER8
# if defined(_AIX) && defined(_ARCH_PWR8) && defined(__xlC__)
#  define __CRYPTO__ 1
# endif
#endif

/// \brief Cast array to vector pointer
/// \details CONST_V8_CAST casts a const array to a vector
///  pointer for a byte array. The Power ABI says source arrays
///  are non-const, so this define removes the const. XLC++ will
///  fail the compile if the source array is const.
#define CONST_V8_CAST(x)  ((unsigned char*)(x))
/// \brief Cast array to vector pointer
/// \details CONST_V32_CAST casts a const array to a vector
///  pointer for a word array. The Power ABI says source arrays
///  are non-const, so this define removes the const. XLC++ will
///  fail the compile if the source array is const.
#define CONST_V32_CAST(x) ((unsigned int*)(x))
/// \brief Cast array to vector pointer
/// \details CONST_V64_CAST casts a const array to a vector
///  pointer for a double word array. The Power ABI says source arrays
///  are non-const, so this define removes the const. XLC++ will
///  fail the compile if the source array is const.
#define CONST_V64_CAST(x) ((unsigned long long*)(x))
/// \brief Cast array to vector pointer
/// \details NCONST_V8_CAST casts an array to a vector
///  pointer for a byte array. The Power ABI says source arrays
///  are non-const, so this define removes the const. XLC++ will
///  fail the compile if the source array is const.
#define NCONST_V8_CAST(x)  ((unsigned char*)(x))
/// \brief Cast array to vector pointer
/// \details NCONST_V32_CAST casts an array to a vector
///  pointer for a word array. The Power ABI says source arrays
///  are non-const, so this define removes the const. XLC++ will
///  fail the compile if the source array is const.
#define NCONST_V32_CAST(x) ((unsigned int*)(x))
/// \brief Cast array to vector pointer
/// \details NCONST_V64_CAST casts an array to a vector
///  pointer for a double word array. The Power ABI says source arrays
///  are non-const, so this define removes the const. XLC++ will
///  fail the compile if the source array is const.
#define NCONST_V64_CAST(x) ((unsigned long long*)(x))

// VecLoad_ALTIVEC and VecStore_ALTIVEC are
// too noisy on modern compilers
#if CRYPTOPP_GCC_DIAGNOSTIC_AVAILABLE
# pragma GCC diagnostic push
# pragma GCC diagnostic ignored "-Wdeprecated"
#endif

NAMESPACE_BEGIN(CryptoPP)

#if defined(__ALTIVEC__) || defined(CRYPTOPP_DOXYGEN_PROCESSING)

/// \brief Vector of 8-bit elements
/// \par Wraps
///  __vector unsigned char
/// \since Crypto++ 6.0
typedef __vector unsigned char   uint8x16_p;
/// \brief Vector of 16-bit elements
/// \par Wraps
///  __vector unsigned short
/// \since Crypto++ 6.0
typedef __vector unsigned short  uint16x8_p;
/// \brief Vector of 32-bit elements
/// \par Wraps
///  __vector unsigned int
/// \since Crypto++ 6.0
typedef __vector unsigned int    uint32x4_p;

#if defined(__VSX__) || defined(_ARCH_PWR8) || defined(CRYPTOPP_DOXYGEN_PROCESSING)
/// \brief Vector of 64-bit elements
/// \details uint64x2_p is available on POWER7 with VSX and above. Most
///  supporting functions, like 64-bit <tt>vec_add</tt> (<tt>vaddudm</tt>)
///  and <tt>vec_sub</tt> (<tt>vsubudm</tt>), did not arrive until POWER8.
/// \par Wraps
///  __vector unsigned long long
/// \since Crypto++ 6.0
typedef __vector unsigned long long uint64x2_p;
#endif  // VSX or ARCH_PWR8

/// \brief The 0 vector
/// \return a 32-bit vector of 0's
/// \since Crypto++ 8.0
inline uint32x4_p VecZero()
{
    const uint32x4_p v = {0,0,0,0};
    return v;
}

/// \brief The 1 vector
/// \return a 32-bit vector of 1's
/// \since Crypto++ 8.0
inline uint32x4_p VecOne()
{
    const uint32x4_p v = {1,1,1,1};
    return v;
}

/// \brief Reverse bytes in a vector
/// \tparam T vector type
/// \param data the vector
/// \return vector
/// \details VecReverse() reverses the bytes in a vector
/// \par Wraps
///  vec_perm
/// \since Crypto++ 6.0
template <class T>
inline T VecReverse(const T data)
{
#if defined(CRYPTOPP_BIG_ENDIAN)
    const uint8x16_p mask = {15,14,13,12, 11,10,9,8, 7,6,5,4, 3,2,1,0};
    return (T)vec_perm(data, data, mask);
#else
    const uint8x16_p mask = {0,1,2,3, 4,5,6,7, 8,9,10,11, 12,13,14,15};
    return (T)vec_perm(data, data, mask);
#endif
}

/// \brief Reverse bytes in a vector
/// \tparam T vector type
/// \param data the vector
/// \return vector
/// \details VecReverseLE() reverses the bytes in a vector on
///  little-endian systems.
/// \par Wraps
///  vec_perm
/// \since Crypto++ 6.0
template <class T>
inline T VecReverseLE(const T data)
{
#if defined(CRYPTOPP_LITTLE_ENDIAN)
    const uint8x16_p mask = {15,14,13,12, 11,10,9,8, 7,6,5,4, 3,2,1,0};
    return (T)vec_perm(data, data, mask);
#else
    return data;
#endif
}

/// \brief Reverse bytes in a vector
/// \tparam T vector type
/// \param data the vector
/// \return vector
/// \details VecReverseBE() reverses the bytes in a vector on
///  big-endian systems.
/// \par Wraps
///  vec_perm
/// \since Crypto++ 6.0
template <class T>
inline T VecReverseBE(const T data)
{
#if defined(CRYPTOPP_BIG_ENDIAN)
    const uint8x16_p mask = {15,14,13,12, 11,10,9,8, 7,6,5,4, 3,2,1,0};
    return (T)vec_perm(data, data, mask);
#else
    return data;
#endif
}

/// \name LOAD OPERATIONS
//@{

/// \brief Loads a vector from a byte array
/// \param src the byte array
/// \details Loads a vector in native endian format from a byte array.
/// \details VecLoad_ALTIVEC() uses <tt>vec_ld</tt> if the effective address
///  of <tt>src</tt> is aligned. If unaligned it uses <tt>vec_lvsl</tt>,
///  <tt>vec_ld</tt>, <tt>vec_perm</tt> and <tt>src</tt>. The fixups using
///  <tt>vec_lvsl</tt> and <tt>vec_perm</tt> are relatively expensive so
///  you should provide aligned memory addresses.
/// \par Wraps
///  vec_ld, vec_lvsl, vec_perm
/// \sa VecLoad, VecLoadAligned
/// \since Crypto++ 6.0
inline uint32x4_p VecLoad_ALTIVEC(const byte src[16])
{
    // Avoid IsAlignedOn for convenience.
    const uintptr_t addr = reinterpret_cast<uintptr_t>(src);
    if (addr % 16 == 0)
    {
        return (uint32x4_p)vec_ld(0, CONST_V8_CAST(addr));
    }
    else
    {
        // http://www.nxp.com/docs/en/reference-manual/ALTIVECPEM.pdf
        const uint8x16_p perm = vec_lvsl(0, CONST_V8_CAST(addr));
        const uint8x16_p low = vec_ld(0, CONST_V8_CAST(addr));
        const uint8x16_p high = vec_ld(15, CONST_V8_CAST(addr));
        return (uint32x4_p)vec_perm(low, high, perm);
    }
}

/// \brief Loads a vector from a byte array
/// \param src the byte array
/// \param off offset into the src byte array
/// \details Loads a vector in native endian format from a byte array.
/// \details VecLoad_ALTIVEC() uses <tt>vec_ld</tt> if the effective address
///  of <tt>src</tt> is aligned. If unaligned it uses <tt>vec_lvsl</tt>,
///  <tt>vec_ld</tt>, <tt>vec_perm</tt> and <tt>src</tt>.
/// \details The fixups using <tt>vec_lvsl</tt> and <tt>vec_perm</tt> are
///  relatively expensive so you should provide aligned memory addresses.
/// \par Wraps
///  vec_ld, vec_lvsl, vec_perm
/// \sa VecLoad, VecLoadAligned
/// \since Crypto++ 6.0
inline uint32x4_p VecLoad_ALTIVEC(int off, const byte src[16])
{
    // Avoid IsAlignedOn for convenience.
    const uintptr_t addr = reinterpret_cast<uintptr_t>(src)+off;
    if (addr % 16 == 0)
    {
        return (uint32x4_p)vec_ld(0, CONST_V8_CAST(addr));
    }
    else
    {
        // http://www.nxp.com/docs/en/reference-manual/ALTIVECPEM.pdf
        const uint8x16_p perm = vec_lvsl(0, CONST_V8_CAST(addr));
        const uint8x16_p low = vec_ld(0, CONST_V8_CAST(addr));
        const uint8x16_p high = vec_ld(15, CONST_V8_CAST(addr));
        return (uint32x4_p)vec_perm(low, high, perm);
    }
}

/// \brief Loads a vector from a byte array
/// \param src the byte array
/// \details VecLoad() loads a vector from a byte array.
/// \details VecLoad() uses POWER9's <tt>vec_xl</tt> if available.
///  The instruction does not require aligned effective memory addresses.
///  VecLoad_ALTIVEC() is used if POWER9 is not available.
///  VecLoad_ALTIVEC() can be relatively expensive if extra instructions
///  are required to fix up unaligned memory addresses.
/// \par Wraps
///  vec_xl on POWER9 and above, Altivec load on POWER8 and below
/// \sa VecLoad_ALTIVEC, VecLoadAligned
/// \since Crypto++ 6.0
inline uint32x4_p VecLoad(const byte src[16])
{
    // Power7/ISA 2.06 provides vec_xl, but only for 32-bit and 64-bit
    // word pointers. The ISA lacks loads for short* and char*.
    // Power9/ISA 3.0 provides vec_xl for all datatypes.

    const uintptr_t addr = reinterpret_cast<uintptr_t>(src);
    CRYPTOPP_ASSERT(addr % GetAlignmentOf<byte>() == 0);
    CRYPTOPP_UNUSED(addr);

#if defined(_ARCH_PWR9)
    return (uint32x4_p)vec_xl(0, CONST_V8_CAST(src));
#else
    return (uint32x4_p)VecLoad_ALTIVEC(CONST_V8_CAST(addr));
#endif
}

/// \brief Loads a vector from a byte array
/// \param src the byte array
/// \param off offset into the src byte array
/// \details VecLoad() loads a vector from a byte array.
/// \details VecLoad() uses POWER9's <tt>vec_xl</tt> if available.
///  The instruction does not require aligned effective memory addresses.
///  VecLoad_ALTIVEC() is used if POWER9 is not available.
///  VecLoad_ALTIVEC() can be relatively expensive if extra instructions
///  are required to fix up unaligned memory addresses.
/// \par Wraps
///  vec_xl on POWER9 and above, Altivec load on POWER8 and below
/// \sa VecLoad_ALTIVEC, VecLoadAligned
/// \since Crypto++ 6.0
inline uint32x4_p VecLoad(int off, const byte src[16])
{
    // Power7/ISA 2.06 provides vec_xl, but only for 32-bit and 64-bit
    // word pointers. The ISA lacks loads for short* and char*.
    // Power9/ISA 3.0 provides vec_xl for all datatypes.

    const uintptr_t addr = reinterpret_cast<uintptr_t>(src)+off;
    CRYPTOPP_ASSERT(addr % GetAlignmentOf<byte>() == 0);
    CRYPTOPP_UNUSED(addr);

#if defined(_ARCH_PWR9)
    return (uint32x4_p)vec_xl(off, CONST_V8_CAST(src));
#else
    return (uint32x4_p)VecLoad_ALTIVEC(CONST_V8_CAST(addr));
#endif
}

/// \brief Loads a vector from a word array
/// \param src the word array
/// \details VecLoad() loads a vector from a word array.
/// \details VecLoad() uses POWER7's and VSX's <tt>vec_xl</tt> if available.
///  The instruction does not require aligned effective memory addresses.
///  VecLoad_ALTIVEC() is used if POWER7 is not available.
///  VecLoad_ALTIVEC() can be relatively expensive if extra instructions
///  are required to fix up unaligned memory addresses.
/// \par Wraps
///  vec_xl on VSX or POWER8 and above, Altivec load on POWER7 and below
/// \sa VecLoad_ALTIVEC, VecLoadAligned
/// \since Crypto++ 8.0
inline uint32x4_p VecLoad(const word32 src[4])
{
    // Power7/ISA 2.06 provides vec_xl, but only for 32-bit and 64-bit
    // word pointers. The ISA lacks loads for short* and char*.
    // Power9/ISA 3.0 provides vec_xl for all datatypes.

    const uintptr_t addr = reinterpret_cast<uintptr_t>(src);
    CRYPTOPP_ASSERT(addr % GetAlignmentOf<word32>() == 0);
    CRYPTOPP_UNUSED(addr);

#if defined(_ARCH_PWR9)
    return (uint32x4_p)vec_xl(0, CONST_V8_CAST(src));
#elif defined(__VSX__) || defined(_ARCH_PWR8)
    return (uint32x4_p)vec_xl(0, CONST_V32_CAST(addr));
#else
    return (uint32x4_p)VecLoad_ALTIVEC(CONST_V8_CAST(addr));
#endif
}

/// \brief Loads a vector from a word array
/// \param src the word array
/// \param off offset into the word array
/// \details VecLoad() loads a vector from a word array.
/// \details VecLoad() uses POWER7's and VSX's <tt>vec_xl</tt> if available.
///  The instruction does not require aligned effective memory addresses.
///  VecLoad_ALTIVEC() is used if POWER7 is not available.
///  VecLoad_ALTIVEC() can be relatively expensive if extra instructions
///  are required to fix up unaligned memory addresses.
/// \par Wraps
///  vec_xl on VSX or POWER8 and above, Altivec load on POWER7 and below
/// \sa VecLoad_ALTIVEC, VecLoadAligned
/// \since Crypto++ 8.0
inline uint32x4_p VecLoad(int off, const word32 src[4])
{
    // Power7/ISA 2.06 provides vec_xl, but only for 32-bit and 64-bit
    // word pointers. The ISA lacks loads for short* and char*.
    // Power9/ISA 3.0 provides vec_xl for all datatypes.

    const uintptr_t addr = reinterpret_cast<uintptr_t>(src)+off;
    CRYPTOPP_ASSERT(addr % GetAlignmentOf<word32>() == 0);
    CRYPTOPP_UNUSED(addr);

#if defined(_ARCH_PWR9)
    return (uint32x4_p)vec_xl(off, CONST_V8_CAST(src));
#elif defined(__VSX__) || defined(_ARCH_PWR8)
    return (uint32x4_p)vec_xl(0, CONST_V32_CAST(addr));
#else
    return (uint32x4_p)VecLoad_ALTIVEC(CONST_V8_CAST(addr));
#endif
}

#if defined(__VSX__) || defined(_ARCH_PWR8) || defined(CRYPTOPP_DOXYGEN_PROCESSING)

/// \brief Loads a vector from a double word array
/// \param src the double word array
/// \details VecLoad() loads a vector from a double word array.
/// \details VecLoad() uses POWER7's and VSX's <tt>vec_xl</tt> if available.
///  The instruction does not require aligned effective memory addresses.
///  VecLoad_ALTIVEC() is used if POWER7 and VSX are not available.
///  VecLoad_ALTIVEC() can be relatively expensive if extra instructions
///  are required to fix up unaligned memory addresses.
/// \details VecLoad() with 64-bit elements is available on POWER7 and above.
/// \par Wraps
///  vec_xl on VSX or POWER8 and above, Altivec load on POWER7 and below
/// \sa VecLoad_ALTIVEC, VecLoadAligned
/// \since Crypto++ 8.0
inline uint64x2_p VecLoad(const word64 src[2])
{
    // Power7/ISA 2.06 provides vec_xl, but only for 32-bit and 64-bit
    // word pointers. The ISA lacks loads for short* and char*.
    // Power9/ISA 3.0 provides vec_xl for all datatypes.

    const uintptr_t addr = reinterpret_cast<uintptr_t>(src);
    CRYPTOPP_ASSERT(addr % GetAlignmentOf<word64>() == 0);
    CRYPTOPP_UNUSED(addr);

#if defined(_ARCH_PWR9)
    return (uint64x2_p)vec_xl(0, CONST_V8_CAST(src));
#elif defined(__VSX__) || defined(_ARCH_PWR8)
    // The 32-bit cast is not a typo. Compiler workaround.
    return (uint64x2_p)vec_xl(0, CONST_V32_CAST(addr));
#else
    return (uint64x2_p)VecLoad_ALTIVEC(CONST_V8_CAST(addr));
#endif
}

/// \brief Loads a vector from a double word array
/// \param src the double word array
/// \param off offset into the double word array
/// \details VecLoad() loads a vector from a double word array.
/// \details VecLoad() uses POWER7's and VSX's <tt>vec_xl</tt> if available.
///  The instruction does not require aligned effective memory addresses.
///  VecLoad_ALTIVEC() is used if POWER7 and VSX are not available.
///  VecLoad_ALTIVEC() can be relatively expensive if extra instructions
///  are required to fix up unaligned memory addresses.
/// \details VecLoad() with 64-bit elements is available on POWER8 and above.
/// \par Wraps
///  vec_xl on VSX or POWER8 and above, Altivec load on POWER7 and below
/// \sa VecLoad_ALTIVEC, VecLoadAligned
/// \since Crypto++ 8.0
inline uint64x2_p VecLoad(int off, const word64 src[2])
{
    // Power7/ISA 2.06 provides vec_xl, but only for 32-bit and 64-bit
    // word pointers. The ISA lacks loads for short* and char*.
    // Power9/ISA 3.0 provides vec_xl for all datatypes.

    const uintptr_t addr = reinterpret_cast<uintptr_t>(src)+off;
    CRYPTOPP_ASSERT(addr % GetAlignmentOf<word64>() == 0);
    CRYPTOPP_UNUSED(addr);

#if defined(_ARCH_PWR9)
    return (uint64x2_p)vec_xl(off, CONST_V8_CAST(src));
#elif defined(__VSX__) || defined(_ARCH_PWR8)
    // The 32-bit cast is not a typo. Compiler workaround.
    return (uint64x2_p)vec_xl(0, CONST_V32_CAST(addr));
#else
    return (uint64x2_p)VecLoad_ALTIVEC(CONST_V8_CAST(addr));
#endif
}

#endif  // VSX or ARCH_PWR8

/// \brief Loads a vector from an aligned byte array
/// \param src the byte array
/// \details VecLoadAligned() loads a vector from an aligned byte array.
/// \details VecLoadAligned() uses POWER9's <tt>vec_xl</tt> if available.
///  <tt>vec_ld</tt> is used if POWER9 is not available. The effective
///  address of <tt>src</tt> must be 16-byte aligned for Altivec.
/// \par Wraps
///  vec_xl on POWER9, vec_ld on POWER8 and below
/// \sa VecLoad_ALTIVEC, VecLoad
/// \since Crypto++ 8.0
inline uint32x4_p VecLoadAligned(const byte src[16])
{
    // Power7/ISA 2.06 provides vec_xl, but only for 32-bit and 64-bit
    // word pointers. The ISA lacks loads for short* and char*.
    // Power9/ISA 3.0 provides vec_xl for all datatypes.

    const uintptr_t addr = reinterpret_cast<uintptr_t>(src);
    CRYPTOPP_ASSERT(addr % 16 == 0);
    CRYPTOPP_UNUSED(addr);

#if defined(_ARCH_PWR9)
    return (uint32x4_p)vec_xl(0, CONST_V8_CAST(src));
#else
    return (uint32x4_p)vec_ld(0, CONST_V8_CAST(src));
#endif
}

/// \brief Loads a vector from an aligned byte array
/// \param src the byte array
/// \param off offset into the src byte array
/// \details VecLoadAligned() loads a vector from an aligned byte array.
/// \details VecLoadAligned() uses POWER9's <tt>vec_xl</tt> if available.
///  <tt>vec_ld</tt> is used if POWER9 is not available. The effective
///  address of <tt>src</tt> must be 16-byte aligned for Altivec.
/// \par Wraps
///  vec_xl on POWER9, vec_ld on POWER8 and below
/// \sa VecLoad_ALTIVEC, VecLoad
/// \since Crypto++ 8.0
inline uint32x4_p VecLoadAligned(int off, const byte src[16])
{
    // Power7/ISA 2.06 provides vec_xl, but only for 32-bit and 64-bit
    // word pointers. The ISA lacks loads for short* and char*.
    // Power9/ISA 3.0 provides vec_xl for all datatypes.

    const uintptr_t addr = reinterpret_cast<uintptr_t>(src)+off;
    CRYPTOPP_ASSERT(addr % 16 == 0);
    CRYPTOPP_UNUSED(addr);

#if defined(_ARCH_PWR9)
    return (uint32x4_p)vec_xl(off, CONST_V8_CAST(src));
#else
    return (uint32x4_p)vec_ld(off, CONST_V8_CAST(src));
#endif
}

/// \brief Loads a vector from an aligned word array
/// \param src the word array
/// \details VecLoadAligned() loads a vector from an aligned word array.
/// \details VecLoadAligned() uses POWER7's and VSX's <tt>vec_xl</tt> if
///  available. <tt>vec_ld</tt> is used if POWER7 or VSX are not available.
///  The effective address of <tt>src</tt> must be 16-byte aligned for Altivec.
/// \par Wraps
///  vec_xl on VSX or POWER8 and above, vec_ld on POWER7 and below
/// \sa VecLoad_ALTIVEC, VecLoad
/// \since Crypto++ 8.0
inline uint32x4_p VecLoadAligned(const word32 src[4])
{
    // Power7/ISA 2.06 provides vec_xl, but only for 32-bit and 64-bit
    // word pointers. The ISA lacks loads for short* and char*.
    // Power9/ISA 3.0 provides vec_xl for all datatypes.

    const uintptr_t addr = reinterpret_cast<uintptr_t>(src);
    CRYPTOPP_ASSERT(addr % 16 == 0);
    CRYPTOPP_UNUSED(addr);

#if defined(_ARCH_PWR9)
    return (uint32x4_p)vec_xl(0, CONST_V8_CAST(src));
#elif defined(__VSX__) || defined(_ARCH_PWR8)
    return (uint32x4_p)vec_xl(0, CONST_V32_CAST(src));
#else
    return (uint32x4_p)vec_ld(0, CONST_V8_CAST(src));
#endif
}

/// \brief Loads a vector from an aligned word array
/// \param src the word array
/// \param off offset into the src word array
/// \details VecLoadAligned() loads a vector from an aligned word array.
/// \details VecLoadAligned() uses POWER7's and VSX's <tt>vec_xl</tt> if
///  available. <tt>vec_ld</tt> is used if POWER7 or VSX are not available.
///  The effective address of <tt>src</tt> must be 16-byte aligned for Altivec.
/// \par Wraps
///  vec_xl on VSX or POWER8 and above, vec_ld on POWER7 and below
/// \sa VecLoad_ALTIVEC, VecLoad
/// \since Crypto++ 8.0
inline uint32x4_p VecLoadAligned(int off, const word32 src[4])
{
    // Power7/ISA 2.06 provides vec_xl, but only for 32-bit and 64-bit
    // word pointers. The ISA lacks loads for short* and char*.
    // Power9/ISA 3.0 provides vec_xl for all datatypes.

    const uintptr_t addr = reinterpret_cast<uintptr_t>(src)+off;
    CRYPTOPP_ASSERT(addr % 16 == 0);
    CRYPTOPP_UNUSED(addr);

#if defined(_ARCH_PWR9)
    return (uint32x4_p)vec_xl(off, CONST_V8_CAST(src));
#elif defined(__VSX__) || defined(_ARCH_PWR8)
    return (uint32x4_p)vec_xl(0, CONST_V32_CAST(addr));
#else
    return (uint32x4_p)vec_ld(off, CONST_V8_CAST(src));
#endif
}

#if defined(__VSX__) || defined(_ARCH_PWR8) || defined(CRYPTOPP_DOXYGEN_PROCESSING)

/// \brief Loads a vector from an aligned double word array
/// \param src the double word array
/// \details VecLoadAligned() loads a vector from an aligned double word array.
/// \details VecLoadAligned() uses POWER7's and VSX's <tt>vec_xl</tt> if
///  available. <tt>vec_ld</tt> is used if POWER7 or VSX are not available.
///  The effective address of <tt>src</tt> must be 16-byte aligned for Altivec.
/// \par Wraps
///  vec_xl on VSX or POWER8 and above, vec_ld on POWER7 and below
/// \sa VecLoad_ALTIVEC, VecLoad
/// \since Crypto++ 8.0
inline uint64x2_p VecLoadAligned(const word64 src[4])
{
    // Power7/ISA 2.06 provides vec_xl, but only for 32-bit and 64-bit
    // word pointers. The ISA lacks loads for short* and char*.
    // Power9/ISA 3.0 provides vec_xl for all datatypes.

    const uintptr_t addr = reinterpret_cast<uintptr_t>(src);
    CRYPTOPP_ASSERT(addr % 16 == 0);
    CRYPTOPP_UNUSED(addr);

#if defined(_ARCH_PWR9)
    return (uint64x2_p)vec_xl(0, CONST_V8_CAST(src));
#elif defined(__VSX__) || defined(_ARCH_PWR8)
    // The 32-bit cast is not a typo. Compiler workaround.
    return (uint64x2_p)vec_xl(0, CONST_V32_CAST(src));
#else
    return (uint64x2_p)vec_ld(0, CONST_V8_CAST(src));
#endif
}

/// \brief Loads a vector from an aligned double word array
/// \param src the double word array
/// \param off offset into the src double word array
/// \details VecLoadAligned() loads a vector from an aligned double word array.
/// \details VecLoadAligned() uses POWER7's and VSX's <tt>vec_xl</tt> if
///  available. <tt>vec_ld</tt> is used if POWER7 or VSX are not available.
///  The effective address of <tt>src</tt> must be 16-byte aligned for Altivec.
/// \par Wraps
///  vec_xl on VSX or POWER8 and above, vec_ld on POWER7 and below
/// \sa VecLoad_ALTIVEC, VecLoad
/// \since Crypto++ 8.0
inline uint64x2_p VecLoadAligned(int off, const word64 src[4])
{
    // Power7/ISA 2.06 provides vec_xl, but only for 32-bit and 64-bit
    // word pointers. The ISA lacks loads for short* and char*.
    // Power9/ISA 3.0 provides vec_xl for all datatypes.

    const uintptr_t addr = reinterpret_cast<uintptr_t>(src)+off;
    CRYPTOPP_ASSERT(addr % 16 == 0);
    CRYPTOPP_UNUSED(addr);

#if defined(_ARCH_PWR9)
    return (uint64x2_p)vec_xl(off, CONST_V8_CAST(src));
#elif defined(__VSX__) || defined(_ARCH_PWR8)
    // The 32-bit cast is not a typo. Compiler workaround.
    return (uint64x2_p)vec_xl(0, CONST_V32_CAST(addr));
#else
    return (uint64x2_p)vec_ld(off, CONST_V8_CAST(src));
#endif
}

#endif

/// \brief Loads a vector from a byte array
/// \param src the byte array
/// \details VecLoadBE() loads a vector from a byte array. VecLoadBE
///  will reverse all bytes in the array on a little endian system.
/// \details VecLoadBE() uses POWER7's and VSX's <tt>vec_xl</tt> if available.
///  The instruction does not require aligned effective memory addresses.
///  VecLoad_ALTIVEC() is used if POWER7 or VSX are not available.
///  VecLoad_ALTIVEC() can be relatively expensive if extra instructions
///  are required to fix up unaligned memory addresses.
/// \par Wraps
///  vec_xl on POWER8, Altivec load on POWER7 and below
/// \sa VecLoad_ALTIVEC, VecLoad, VecLoadAligned
/// \since Crypto++ 6.0
inline uint32x4_p VecLoadBE(const byte src[16])
{
    // Power7/ISA 2.06 provides vec_xl, but only for 32-bit and 64-bit
    // word pointers. The ISA lacks loads for short* and char*.
    // Power9/ISA 3.0 provides vec_xl for all datatypes.

    const uintptr_t addr = reinterpret_cast<uintptr_t>(src);
    // CRYPTOPP_ASSERT(addr % GetAlignmentOf<byte>() == 0);
    CRYPTOPP_UNUSED(addr);

#if defined(_ARCH_PWR9)
    CRYPTOPP_ASSERT(addr % GetAlignmentOf<byte>() == 0);
    return (uint32x4_p)vec_xl_be(0, CONST_V8_CAST(src));
#elif defined(CRYPTOPP_BIG_ENDIAN)
    return (uint32x4_p)VecLoad_ALTIVEC(0, CONST_V8_CAST(src));
#else
    return (uint32x4_p)VecReverseLE(VecLoad_ALTIVEC(CONST_V8_CAST(src)));
#endif
}

/// \brief Loads a vector from a byte array
/// \param src the byte array
/// \param off offset into the src byte array
/// \details VecLoadBE() loads a vector from a byte array. VecLoadBE
///  will reverse all bytes in the array on a little endian system.
/// \details VecLoadBE() uses POWER7's and VSX's <tt>vec_xl</tt> if available.
///  The instruction does not require aligned effective memory addresses.
///  VecLoad_ALTIVEC() is used if POWER7 is not available.
///  VecLoad_ALTIVEC() can be relatively expensive if extra instructions
///  are required to fix up unaligned memory addresses.
/// \par Wraps
///  vec_xl on POWER8, Altivec load on POWER7 and below
/// \sa VecLoad_ALTIVEC, VecLoad, VecLoadAligned
/// \since Crypto++ 6.0
inline uint32x4_p VecLoadBE(int off, const byte src[16])
{
    // Power7/ISA 2.06 provides vec_xl, but only for 32-bit and 64-bit
    // word pointers. The ISA lacks loads for short* and char*.
    // Power9/ISA 3.0 provides vec_xl for all datatypes.

    const uintptr_t addr = reinterpret_cast<uintptr_t>(src)+off;
    // CRYPTOPP_ASSERT(addr % GetAlignmentOf<byte>() == 0);
    CRYPTOPP_UNUSED(addr);

#if defined(_ARCH_PWR9)
    CRYPTOPP_ASSERT(addr % GetAlignmentOf<byte>() == 0);
    return (uint32x4_p)vec_xl_be(off, CONST_V8_CAST(src));
#elif defined(CRYPTOPP_BIG_ENDIAN)
    return (uint32x4_p)VecLoad_ALTIVEC(CONST_V8_CAST(addr));
#else
    return (uint32x4_p)VecReverseLE(VecLoad_ALTIVEC(CONST_V8_CAST(addr)));
#endif
}

//@}

/// \name STORE OPERATIONS
//@{

/// \brief Stores a vector to a byte array
/// \tparam T vector type
/// \param data the vector
/// \param dest the byte array
/// \details VecStore_ALTIVEC() stores a vector to a byte array.
/// \details VecStore_ALTIVEC() uses <tt>vec_st</tt> if the effective address
///  of <tt>dest</tt> is aligned, and uses <tt>vec_ste</tt> otherwise.
///  <tt>vec_ste</tt> is relatively expensive so you should provide aligned
///  memory addresses.
/// \details VecStore_ALTIVEC() is used when POWER7 or above
///  and unaligned loads is not available.
/// \par Wraps
///  vec_st, vec_ste, vec_lvsr, vec_perm
/// \sa VecStore, VecStoreAligned
/// \since Crypto++ 8.0
template<class T>
inline void VecStore_ALTIVEC(const T data, byte dest[16])
{
    // Avoid IsAlignedOn for convenience.
    uintptr_t addr = reinterpret_cast<uintptr_t>(dest);
    if (addr % 16 == 0)
    {
        vec_st((uint8x16_p)data, 0, NCONST_V8_CAST(addr));
    }
    else
    {
        // http://www.nxp.com/docs/en/reference-manual/ALTIVECPEM.pdf
        uint8x16_p perm = (uint8x16_p)vec_perm(data, data, vec_lvsr(0, NCONST_V8_CAST(addr)));
        vec_ste((uint8x16_p) perm,  0, (unsigned char*) NCONST_V8_CAST(addr));
        vec_ste((uint16x8_p) perm,  1, (unsigned short*)NCONST_V8_CAST(addr));
        vec_ste((uint32x4_p) perm,  3, (unsigned int*)  NCONST_V8_CAST(addr));
        vec_ste((uint32x4_p) perm,  4, (unsigned int*)  NCONST_V8_CAST(addr));
        vec_ste((uint32x4_p) perm,  8, (unsigned int*)  NCONST_V8_CAST(addr));
        vec_ste((uint32x4_p) perm, 12, (unsigned int*)  NCONST_V8_CAST(addr));
        vec_ste((uint16x8_p) perm, 14, (unsigned short*)NCONST_V8_CAST(addr));
        vec_ste((uint8x16_p) perm, 15, (unsigned char*) NCONST_V8_CAST(addr));
    }
}

/// \brief Stores a vector to a byte array
/// \tparam T vector type
/// \param data the vector
/// \param off offset into the dest byte array
/// \param dest the byte array
/// \details VecStore_ALTIVEC() stores a vector to a byte array.
/// \details VecStore_ALTIVEC() uses <tt>vec_st</tt> if the effective address
///  of <tt>dest</tt> is aligned, and uses <tt>vec_ste</tt> otherwise.
///  <tt>vec_ste</tt> is relatively expensive so you should provide aligned
///  memory addresses.
/// \details VecStore_ALTIVEC() is used when POWER7 or above
///  and unaligned loads is not available.
/// \par Wraps
///  vec_st, vec_ste, vec_lvsr, vec_perm
/// \sa VecStore, VecStoreAligned
/// \since Crypto++ 8.0
template<class T>
inline void VecStore_ALTIVEC(const T data, int off, byte dest[16])
{
    // Avoid IsAlignedOn for convenience.
    uintptr_t addr = reinterpret_cast<uintptr_t>(dest)+off;
    if (addr % 16 == 0)
    {
        vec_st((uint8x16_p)data, 0, NCONST_V8_CAST(addr));
    }
    else
    {
        // http://www.nxp.com/docs/en/reference-manual/ALTIVECPEM.pdf
        uint8x16_p perm = (uint8x16_p)vec_perm(data, data, vec_lvsr(0, NCONST_V8_CAST(addr)));
        vec_ste((uint8x16_p) perm,  0, (unsigned char*) NCONST_V8_CAST(addr));
        vec_ste((uint16x8_p) perm,  1, (unsigned short*)NCONST_V8_CAST(addr));
        vec_ste((uint32x4_p) perm,  3, (unsigned int*)  NCONST_V8_CAST(addr));
        vec_ste((uint32x4_p) perm,  4, (unsigned int*)  NCONST_V8_CAST(addr));
        vec_ste((uint32x4_p) perm,  8, (unsigned int*)  NCONST_V8_CAST(addr));
        vec_ste((uint32x4_p) perm, 12, (unsigned int*)  NCONST_V8_CAST(addr));
        vec_ste((uint16x8_p) perm, 14, (unsigned short*)NCONST_V8_CAST(addr));
        vec_ste((uint8x16_p) perm, 15, (unsigned char*) NCONST_V8_CAST(addr));
    }
}

/// \brief Stores a vector to a byte array
/// \tparam T vector type
/// \param data the vector
/// \param dest the byte array
/// \details VecStore() stores a vector to a byte array.
/// \details VecStore() uses POWER9's <tt>vec_xst</tt> if available.
///  The instruction does not require aligned effective memory addresses.
///  VecStore_ALTIVEC() is used if POWER9 is not available.
///  VecStore_ALTIVEC() can be relatively expensive if extra instructions
///  are required to fix up unaligned memory addresses.
/// \par Wraps
///  vec_xst on POWER9 and above, Altivec store on POWER8 and below
/// \sa VecStore_ALTIVEC, VecStoreAligned
/// \since Crypto++ 6.0
template<class T>
inline void VecStore(const T data, byte dest[16])
{
    // Power7/ISA 2.06 provides vec_xl, but only for 32-bit and 64-bit
    // word pointers. The ISA lacks loads for short* and char*.
    // Power9/ISA 3.0 provides vec_xl for all datatypes.

    const uintptr_t addr = reinterpret_cast<uintptr_t>(dest);
    CRYPTOPP_ASSERT(addr % GetAlignmentOf<byte>() == 0);
    CRYPTOPP_UNUSED(addr);

#if defined(_ARCH_PWR9)
    vec_xst((uint8x16_p)data, 0, NCONST_V8_CAST(dest));
#else
    VecStore_ALTIVEC((uint8x16_p)data, NCONST_V8_CAST(dest));
#endif
}

/// \brief Stores a vector to a byte array
/// \tparam T vector type
/// \param data the vector
/// \param off offset into the dest byte array
/// \param dest the byte array
/// \details VecStore() stores a vector to a byte array.
/// \details VecStore() uses POWER9's <tt>vec_xst</tt> if available.
///  The instruction does not require aligned effective memory addresses.
///  VecStore_ALTIVEC() is used if POWER9 is not available.
///  VecStore_ALTIVEC() can be relatively expensive if extra instructions
///  are required to fix up unaligned memory addresses.
/// \par Wraps
///  vec_xst on POWER9 and above, Altivec store on POWER8 and below
/// \sa VecStore_ALTIVEC, VecStoreAligned
/// \since Crypto++ 6.0
template<class T>
inline void VecStore(const T data, int off, byte dest[16])
{
    // Power7/ISA 2.06 provides vec_xl, but only for 32-bit and 64-bit
    // word pointers. The ISA lacks loads for short* and char*.
    // Power9/ISA 3.0 provides vec_xl for all datatypes.

    const uintptr_t addr = reinterpret_cast<uintptr_t>(dest)+off;
    CRYPTOPP_ASSERT(addr % GetAlignmentOf<byte>() == 0);
    CRYPTOPP_UNUSED(addr);

#if defined(_ARCH_PWR9)
    vec_xst((uint8x16_p)data, off, NCONST_V8_CAST(dest));
#else
    VecStore_ALTIVEC((uint8x16_p)data, NCONST_V8_CAST(addr));
#endif
}

/// \brief Stores a vector to a word array
/// \tparam T vector type
/// \param data the vector
/// \param dest the word array
/// \details VecStore() stores a vector to a word array.
/// \details VecStore() uses POWER7's and VSX's <tt>vec_xst</tt> if available.
///  The instruction does not require aligned effective memory addresses.
///  VecStore_ALTIVEC() is used if POWER7 or VSX are not available.
///  VecStore_ALTIVEC() can be relatively expensive if extra instructions
///  are required to fix up unaligned memory addresses.
/// \par Wraps
///  vec_xst on VSX or POWER8 and above, Altivec store on POWER7 and below
/// \sa VecStore_ALTIVEC, VecStoreAligned
/// \since Crypto++ 8.0
template<class T>
inline void VecStore(const T data, word32 dest[4])
{
    // Power7/ISA 2.06 provides vec_xst, but only for 32-bit and 64-bit
    // word pointers. The ISA lacks stores for short* and char*.
    // Power9/ISA 3.0 provides vec_xst for all datatypes.

    const uintptr_t addr = reinterpret_cast<uintptr_t>(dest);
    CRYPTOPP_ASSERT(addr % GetAlignmentOf<word32>() == 0);
    CRYPTOPP_UNUSED(addr);

#if defined(_ARCH_PWR9)
    vec_xst((uint8x16_p)data, 0, NCONST_V8_CAST(dest));
#elif defined(__VSX__) || defined(_ARCH_PWR8)
    vec_xst((uint32x4_p)data, 0, NCONST_V32_CAST(addr));
#else
    VecStore_ALTIVEC((uint8x16_p)data, NCONST_V8_CAST(addr));
#endif
}

/// \brief Stores a vector to a word array
/// \tparam T vector type
/// \param data the vector
/// \param off offset into the dest word array
/// \param dest the word array
/// \details VecStore() stores a vector to a word array.
/// \details VecStore() uses POWER7's and VSX's <tt>vec_xst</tt> if available.
///  The instruction does not require aligned effective memory addresses.
///  VecStore_ALTIVEC() is used if POWER7 or VSX are not available.
///  VecStore_ALTIVEC() can be relatively expensive if extra instructions
///  are required to fix up unaligned memory addresses.
/// \par Wraps
///  vec_xst on VSX or POWER8 and above, Altivec store on POWER7 and below
/// \sa VecStore_ALTIVEC, VecStoreAligned
/// \since Crypto++ 8.0
template<class T>
inline void VecStore(const T data, int off, word32 dest[4])
{
    // Power7/ISA 2.06 provides vec_xst, but only for 32-bit and 64-bit
    // word pointers. The ISA lacks stores for short* and char*.
    // Power9/ISA 3.0 provides vec_xst for all datatypes.

    const uintptr_t addr = reinterpret_cast<uintptr_t>(dest)+off;
    CRYPTOPP_ASSERT(addr % GetAlignmentOf<word32>() == 0);
    CRYPTOPP_UNUSED(addr);

#if defined(_ARCH_PWR9)
    vec_xst((uint8x16_p)data, off, NCONST_V8_CAST(dest));
#elif defined(__VSX__) || defined(_ARCH_PWR8)
    vec_xst((uint32x4_p)data, 0, NCONST_V32_CAST(addr));
#else
    VecStore_ALTIVEC((uint8x16_p)data, NCONST_V8_CAST(addr));
#endif
}

/// \brief Stores a vector to a word array
/// \tparam T vector type
/// \param data the vector
/// \param dest the word array
/// \details VecStore() stores a vector to a word array.
/// \details VecStore() uses POWER7's and VSX's <tt>vec_xst</tt> if available.
///  The instruction does not require aligned effective memory addresses.
///  VecStore_ALTIVEC() is used if POWER7 or VSX are not available.
///  VecStore_ALTIVEC() can be relatively expensive if extra instructions
///  are required to fix up unaligned memory addresses.
/// \details VecStore() with 64-bit elements is available on POWER8 and above.
/// \par Wraps
///  vec_xst on VSX or POWER8 and above, Altivec store on POWER7 and below
/// \sa VecStore_ALTIVEC, VecStoreAligned
/// \since Crypto++ 8.0
template<class T>
inline void VecStore(const T data, word64 dest[2])
{
    // Power7/ISA 2.06 provides vec_xst, but only for 32-bit and 64-bit
    // word pointers. The ISA lacks stores for short* and char*.
    // Power9/ISA 3.0 provides vec_xst for all datatypes.

    const uintptr_t addr = reinterpret_cast<uintptr_t>(dest);
    CRYPTOPP_ASSERT(addr % GetAlignmentOf<word64>() == 0);
    CRYPTOPP_UNUSED(addr);

#if defined(_ARCH_PWR9)
    vec_xst((uint8x16_p)data, 0, NCONST_V8_CAST(dest));
#elif defined(__VSX__) || defined(_ARCH_PWR8)
    // 32-bit cast is not a typo. Compiler workaround.
    vec_xst((uint32x4_p)data, 0, NCONST_V32_CAST(addr));
#else
    VecStore_ALTIVEC((uint8x16_p)data, NCONST_V8_CAST(addr));
#endif
}

/// \brief Stores a vector to a word array
/// \tparam T vector type
/// \param data the vector
/// \param off offset into the dest word array
/// \param dest the word array
/// \details VecStore() stores a vector to a word array.
/// \details VecStore() uses POWER7's and VSX's <tt>vec_xst</tt> if available.
///  The instruction does not require aligned effective memory addresses.
///  VecStore_ALTIVEC() is used if POWER7 or VSX are not available.
///  VecStore_ALTIVEC() can be relatively expensive if extra instructions
///  are required to fix up unaligned memory addresses.
/// \details VecStore() with 64-bit elements is available on POWER8 and above.
/// \par Wraps
///  vec_xst on VSX or POWER8 and above, Altivec store on POWER7 and below
/// \sa VecStore_ALTIVEC, VecStoreAligned
/// \since Crypto++ 8.0
template<class T>
inline void VecStore(const T data, int off, word64 dest[2])
{
    // Power7/ISA 2.06 provides vec_xst, but only for 32-bit and 64-bit
    // word pointers. The ISA lacks stores for short* and char*.
    // Power9/ISA 3.0 provides vec_xst for all datatypes.

    const uintptr_t addr = reinterpret_cast<uintptr_t>(dest)+off;
    CRYPTOPP_ASSERT(addr % GetAlignmentOf<word64>() == 0);
    CRYPTOPP_UNUSED(addr);

#if defined(_ARCH_PWR9)
    vec_xst((uint8x16_p)data, off, NCONST_V8_CAST(dest));
#elif defined(__VSX__) || defined(_ARCH_PWR8)
    // 32-bit cast is not a typo. Compiler workaround.
    vec_xst((uint32x4_p)data, 0, NCONST_V32_CAST(addr));
#else
    VecStore_ALTIVEC((uint8x16_p)data, NCONST_V8_CAST(addr));
#endif
}

/// \brief Stores a vector to a byte array
/// \tparam T vector type
/// \param data the vector
/// \param dest the byte array
/// \details VecStoreAligned() stores a vector from an aligned byte array.
/// \details VecStoreAligned() uses POWER9's <tt>vec_xl</tt> if available.
///  <tt>vec_st</tt> is used if POWER9 is not available. The effective
///  address of <tt>dest</tt> must be 16-byte aligned for Altivec.
/// \par Wraps
///  vec_xst on POWER9 or above, vec_st on POWER8 and below
/// \sa VecStore_ALTIVEC, VecStore
/// \since Crypto++ 8.0
template<class T>
inline void VecStoreAligned(const T data, byte dest[16])
{
    // Power7/ISA 2.06 provides vec_xl, but only for 32-bit and 64-bit
    // word pointers. The ISA lacks loads for short* and char*.
    // Power9/ISA 3.0 provides vec_xl for all datatypes.

    const uintptr_t addr = reinterpret_cast<uintptr_t>(dest);
    CRYPTOPP_ASSERT(addr % GetAlignmentOf<byte>() == 0);
    CRYPTOPP_UNUSED(addr);

#if defined(_ARCH_PWR9)
    vec_xst((uint8x16_p)data, 0, NCONST_V8_CAST(dest));
#else
    vec_st((uint8x16_p)data, 0, NCONST_V8_CAST(addr));
#endif
}

/// \brief Stores a vector to a byte array
/// \tparam T vector type
/// \param data the vector
/// \param off offset into the dest byte array
/// \param dest the byte array
/// \details VecStoreAligned() stores a vector from an aligned byte array.
/// \details VecStoreAligned() uses POWER9's <tt>vec_xl</tt> if available.
///  <tt>vec_st</tt> is used if POWER9 is not available. The effective
///  address of <tt>dest</tt> must be 16-byte aligned for Altivec.
/// \par Wraps
///  vec_xst on POWER9 or above, vec_st on POWER8 and below
/// \sa VecStore_ALTIVEC, VecStore
/// \since Crypto++ 8.0
template<class T>
inline void VecStoreAligned(const T data, int off, byte dest[16])
{
    // Power7/ISA 2.06 provides vec_xl, but only for 32-bit and 64-bit
    // word pointers. The ISA lacks loads for short* and char*.
    // Power9/ISA 3.0 provides vec_xl for all datatypes.

    const uintptr_t addr = reinterpret_cast<uintptr_t>(dest)+off;
    CRYPTOPP_ASSERT(addr % GetAlignmentOf<byte>() == 0);
    CRYPTOPP_UNUSED(addr);

#if defined(_ARCH_PWR9)
    vec_xst((uint8x16_p)data, off, NCONST_V8_CAST(dest));
#else
    vec_st((uint8x16_p)data, 0, NCONST_V8_CAST(addr));
#endif
}

/// \brief Stores a vector to a word array
/// \tparam T vector type
/// \param data the vector
/// \param dest the word array
/// \details VecStoreAligned() stores a vector from an aligned word array.
/// \details VecStoreAligned() uses POWER9's <tt>vec_xl</tt> if available.
///  POWER7 <tt>vec_xst</tt> is used if POWER9 is not available. <tt>vec_st</tt>
///  is used if POWER7 is not available. The effective address of <tt>dest</tt>
///  must be 16-byte aligned for Altivec.
/// \par Wraps
///  vec_xst on VSX or POWER8 and above, vec_st on POWER7 and below
/// \sa VecStore_ALTIVEC, VecStore
/// \since Crypto++ 8.0
template<class T>
inline void VecStoreAligned(const T data, word32 dest[4])
{
    // Power7/ISA 2.06 provides vec_xst, but only for 32-bit and 64-bit
    // word pointers. The ISA lacks stores for short* and char*.
    // Power9/ISA 3.0 provides vec_xst for all datatypes.

    const uintptr_t addr = reinterpret_cast<uintptr_t>(dest);
    CRYPTOPP_ASSERT(addr % GetAlignmentOf<word32>() == 0);
    CRYPTOPP_UNUSED(addr);

#if defined(_ARCH_PWR9)
    vec_xst((uint8x16_p)data, 0, NCONST_V8_CAST(dest));
#elif defined(__VSX__) || defined(_ARCH_PWR8)
    vec_xst((uint32x4_p)data, 0, NCONST_V32_CAST(addr));
#else
    vec_st((uint8x16_p)data, 0, NCONST_V8_CAST(addr));
#endif
}

/// \brief Stores a vector to a word array
/// \tparam T vector type
/// \param data the vector
/// \param off offset into the dest word array
/// \param dest the word array
/// \details VecStoreAligned() stores a vector from an aligned word array.
/// \details VecStoreAligned() uses POWER9's <tt>vec_xl</tt> if available.
///  POWER7 <tt>vec_xst</tt> is used if POWER9 is not available. <tt>vec_st</tt>
///  is used if POWER7 is not available. The effective address of <tt>dest</tt>
///  must be 16-byte aligned for Altivec.
/// \par Wraps
///  vec_xst on VSX or POWER8 and above, vec_st on POWER7 and below
/// \sa VecStore_ALTIVEC, VecStore
/// \since Crypto++ 8.0
template<class T>
inline void VecStoreAligned(const T data, int off, word32 dest[4])
{
    // Power7/ISA 2.06 provides vec_xst, but only for 32-bit and 64-bit
    // word pointers. The ISA lacks stores for short* and char*.
    // Power9/ISA 3.0 provides vec_xst for all datatypes.

    const uintptr_t addr = reinterpret_cast<uintptr_t>(dest)+off;
    CRYPTOPP_ASSERT(addr % GetAlignmentOf<word32>() == 0);
    CRYPTOPP_UNUSED(addr);

#if defined(_ARCH_PWR9)
    vec_xst((uint8x16_p)data, off, NCONST_V8_CAST(dest));
#elif defined(__VSX__) || defined(_ARCH_PWR8)
    vec_xst((uint32x4_p)data, 0, NCONST_V32_CAST(addr));
#else
    vec_st((uint8x16_p)data, 0, NCONST_V8_CAST(addr));
#endif
}

/// \brief Stores a vector to a byte array
/// \tparam T vector type
/// \param data the vector
/// \param dest the byte array
/// \details VecStoreBE() stores a vector to a byte array. VecStoreBE
///  will reverse all bytes in the array on a little endian system.
/// \details VecStoreBE() uses POWER7's and VSX's <tt>vec_xst</tt> if available.
///  The instruction does not require aligned effective memory addresses.
///  VecStore_ALTIVEC() is used if POWER7 is not available.
///  VecStore_ALTIVEC() can be relatively expensive if extra instructions
///  are required to fix up unaligned memory addresses.
/// \par Wraps
///  vec_xst on VSX or POWER8 and above, vec_st on POWER7 and below
/// \sa VecStore_ALTIVEC, VecStoreAligned
/// \since Crypto++ 6.0
template <class T>
inline void VecStoreBE(const T data, byte dest[16])
{
    // Power7/ISA 2.06 provides vec_xst, but only for 32-bit and 64-bit
    // word pointers. The ISA lacks stores for short* and char*.
    // Power9/ISA 3.0 provides vec_xst for all datatypes.

    const uintptr_t addr = reinterpret_cast<uintptr_t>(dest);
    CRYPTOPP_ASSERT(addr % GetAlignmentOf<byte>() == 0);
    CRYPTOPP_UNUSED(addr);

#if defined(_ARCH_PWR9)
    vec_xst_be((uint8x16_p)data, 0, NCONST_V8_CAST(dest));
#elif defined(CRYPTOPP_BIG_ENDIAN)
    VecStore((uint8x16_p)data, NCONST_V8_CAST(addr));
#else
    VecStore((uint8x16_p)VecReverseLE(data), NCONST_V8_CAST(addr));
#endif
}

/// \brief Stores a vector to a byte array
/// \tparam T vector type
/// \param data the vector
/// \param off offset into the dest byte array
/// \param dest the byte array
/// \details VecStoreBE() stores a vector to a byte array. VecStoreBE
///  will reverse all bytes in the array on a little endian system.
/// \details VecStoreBE() uses POWER7's and VSX's <tt>vec_xst</tt> if available.
///  The instruction does not require aligned effective memory addresses.
///  VecStore_ALTIVEC() is used if POWER7 is not available.
///  VecStore_ALTIVEC() can be relatively expensive if extra instructions
///  are required to fix up unaligned memory addresses.
/// \par Wraps
///  vec_xst on VSX or POWER8 and above, vec_st on POWER7 and below
/// \sa VecStore_ALTIVEC, VecStoreAligned
/// \since Crypto++ 6.0
template <class T>
inline void VecStoreBE(const T data, int off, byte dest[16])
{
    // Power7/ISA 2.06 provides vec_xst, but only for 32-bit and 64-bit
    // word pointers. The ISA lacks stores for short* and char*.
    // Power9/ISA 3.0 provides vec_xst for all datatypes.

    const uintptr_t addr = reinterpret_cast<uintptr_t>(dest)+off;
    CRYPTOPP_ASSERT(addr % GetAlignmentOf<byte>() == 0);
    CRYPTOPP_UNUSED(addr);

#if defined(_ARCH_PWR9)
    vec_xst_be((uint8x16_p)data, off, NCONST_V8_CAST(dest));
#elif defined(CRYPTOPP_BIG_ENDIAN)
    VecStore((uint8x16_p)data, NCONST_V8_CAST(addr));
#else
    VecStore((uint8x16_p)VecReverseLE(data), NCONST_V8_CAST(addr));
#endif
}

/// \brief Stores a vector to a word array
/// \tparam T vector type
/// \param data the vector
/// \param dest the word array
/// \details VecStoreBE() stores a vector to a word array. VecStoreBE
///  will reverse all bytes in the array on a little endian system.
/// \details VecStoreBE() uses POWER7's and VSX's <tt>vec_xst</tt> if available.
///  The instruction does not require aligned effective memory addresses.
///  VecStore_ALTIVEC() is used if POWER7 is not available.
///  VecStore_ALTIVEC() can be relatively expensive if extra instructions
///  are required to fix up unaligned memory addresses.
/// \par Wraps
///  vec_xst on VSX or POWER8 and above, vec_st on POWER7 and below
/// \sa VecStore_ALTIVEC, VecStoreAligned
/// \since Crypto++ 8.0
template <class T>
inline void VecStoreBE(const T data, word32 dest[4])
{
    // Power7/ISA 2.06 provides vec_xst, but only for 32-bit and 64-bit
    // word pointers. The ISA lacks stores for short* and char*.
    // Power9/ISA 3.0 provides vec_xst for all datatypes.

    const uintptr_t addr = reinterpret_cast<uintptr_t>(dest);
    CRYPTOPP_ASSERT(addr % GetAlignmentOf<word32>() == 0);
    CRYPTOPP_UNUSED(addr);

#if defined(_ARCH_PWR9)
    vec_xst_be((uint8x16_p)data, 0, NCONST_V8_CAST(dest));
#elif defined(CRYPTOPP_BIG_ENDIAN)
    VecStore((uint32x4_p)data, NCONST_V32_CAST(addr));
#else
    VecStore((uint32x4_p)VecReverseLE(data), NCONST_V32_CAST(addr));
#endif
}

/// \brief Stores a vector to a word array
/// \tparam T vector type
/// \param data the vector
/// \param off offset into the dest word array
/// \param dest the word array
/// \details VecStoreBE() stores a vector to a word array. VecStoreBE
///  will reverse all words in the array on a little endian system.
/// \details VecStoreBE() uses POWER7's and VSX's <tt>vec_xst</tt> if available.
///  The instruction does not require aligned effective memory addresses.
///  VecStore_ALTIVEC() is used if POWER7 is not available.
///  VecStore_ALTIVEC() can be relatively expensive if extra instructions
///  are required to fix up unaligned memory addresses.
/// \par Wraps
///  vec_xst on VSX or POWER8 and above, vec_st on POWER7 and below
/// \sa VecStore_ALTIVEC, VecStoreAligned
/// \since Crypto++ 8.0
template <class T>
inline void VecStoreBE(const T data, int off, word32 dest[4])
{
    // Power7/ISA 2.06 provides vec_xst, but only for 32-bit and 64-bit
    // word pointers. The ISA lacks stores for short* and char*.
    // Power9/ISA 3.0 provides vec_xst for all datatypes.

    const uintptr_t addr = reinterpret_cast<uintptr_t>(dest)+off;
    CRYPTOPP_ASSERT(addr % GetAlignmentOf<word32>() == 0);
    CRYPTOPP_UNUSED(addr);

#if defined(_ARCH_PWR9)
    vec_xst_be((uint8x16_p)data, off, NCONST_V8_CAST(dest));
#elif defined(CRYPTOPP_BIG_ENDIAN)
    VecStore((uint32x4_p)data, NCONST_V32_CAST(addr));
#else
    VecStore((uint32x4_p)VecReverseLE(data), NCONST_V32_CAST(addr));
#endif
}

//@}

/// \name LOGICAL OPERATIONS
//@{

/// \brief AND two vectors
/// \tparam T1 vector type
/// \tparam T2 vector type
/// \param vec1 the first vector
/// \param vec2 the second vector
/// \return vector
/// \details VecAnd() performs <tt>vec1 & vec2</tt>.
///  vec2 is cast to the same type as vec1. The return vector
///  is the same type as vec1.
/// \par Wraps
///  vec_and
/// \sa VecAnd64
/// \since Crypto++ 6.0
template <class T1, class T2>
inline T1 VecAnd(const T1 vec1, const T2 vec2)
{
    return (T1)vec_and(vec1, (T1)vec2);
}

/// \brief OR two vectors
/// \tparam T1 vector type
/// \tparam T2 vector type
/// \param vec1 the first vector
/// \param vec2 the second vector
/// \return vector
/// \details VecOr() performs <tt>vec1 | vec2</tt>.
///  vec2 is cast to the same type as vec1. The return vector
///  is the same type as vec1.
/// \par Wraps
///  vec_or
/// \sa VecOr64
/// \since Crypto++ 6.0
template <class T1, class T2>
inline T1 VecOr(const T1 vec1, const T2 vec2)
{
    return (T1)vec_or(vec1, (T1)vec2);
}

/// \brief XOR two vectors
/// \tparam T1 vector type
/// \tparam T2 vector type
/// \param vec1 the first vector
/// \param vec2 the second vector
/// \return vector
/// \details VecXor() performs <tt>vec1 ^ vec2</tt>.
///  vec2 is cast to the same type as vec1. The return vector
///  is the same type as vec1.
/// \par Wraps
///  vec_xor
/// \sa VecXor64
/// \since Crypto++ 6.0
template <class T1, class T2>
inline T1 VecXor(const T1 vec1, const T2 vec2)
{
    return (T1)vec_xor(vec1, (T1)vec2);
}

//@}

/// \name ARITHMETIC OPERATIONS
//@{

/// \brief Add two vectors
/// \tparam T1 vector type
/// \tparam T2 vector type
/// \param vec1 the first vector
/// \param vec2 the second vector
/// \return vector
/// \details VecAdd() performs <tt>vec1 + vec2</tt>.
///  vec2 is cast to the same type as vec1. The return vector
///  is the same type as vec1.
/// \par Wraps
///  vec_add
/// \sa VecAdd64
/// \since Crypto++ 6.0
template <class T1, class T2>
inline T1 VecAdd(const T1 vec1, const T2 vec2)
{
    return (T1)vec_add(vec1, (T1)vec2);
}

/// \brief Subtract two vectors
/// \tparam T1 vector type
/// \tparam T2 vector type
/// \param vec1 the first vector
/// \param vec2 the second vector
/// \details VecSub() performs <tt>vec1 - vec2</tt>.
///  vec2 is cast to the same type as vec1. The return vector
///  is the same type as vec1.
/// \par Wraps
///  vec_sub
/// \sa VecSub64
/// \since Crypto++ 6.0
template <class T1, class T2>
inline T1 VecSub(const T1 vec1, const T2 vec2)
{
    return (T1)vec_sub(vec1, (T1)vec2);
}

//@}

/// \name PERMUTE OPERATIONS
//@{

/// \brief Permutes a vector
/// \tparam T1 vector type
/// \tparam T2 vector type
/// \param vec the vector
/// \param mask vector mask
/// \return vector
/// \details VecPermute() creates a new vector from vec according to mask.
///  mask is an uint8x16_p vector. The return vector is the same type as vec.
/// \par Wraps
///  vec_perm
/// \since Crypto++ 6.0
template <class T1, class T2>
inline T1 VecPermute(const T1 vec, const T2 mask)
{
    return (T1)vec_perm(vec, vec, (uint8x16_p)mask);
}

/// \brief Permutes two vectors
/// \tparam T1 vector type
/// \tparam T2 vector type
/// \param vec1 the first vector
/// \param vec2 the second vector
/// \param mask vector mask
/// \return vector
/// \details VecPermute() creates a new vector from vec1 and vec2 according to mask.
///  mask is an uint8x16_p vector. The return vector is the same type as vec.
/// \par Wraps
///  vec_perm
/// \since Crypto++ 6.0
template <class T1, class T2>
inline T1 VecPermute(const T1 vec1, const T1 vec2, const T2 mask)
{
    return (T1)vec_perm(vec1, (T1)vec2, (uint8x16_p)mask);
}

//@}

/// \name SHIFT AND ROTATE OPERATIONS
//@{

/// \brief Shift a vector left
/// \tparam C shift byte count
/// \tparam T vector type
/// \param vec the vector
/// \return vector
/// \details VecShiftLeftOctet() returns a new vector after shifting the
///  concatenation of the zero vector and the source vector by the specified
///  number of bytes. The return vector is the same type as vec.
/// \details On big endian machines VecShiftLeftOctet() is <tt>vec_sld(a, z,
///  c)</tt>. On little endian machines VecShiftLeftOctet() is translated to
///  <tt>vec_sld(z, a, 16-c)</tt>. You should always call the function as
///  if on a big endian machine as shown below.
/// <pre>
///   uint8x16_p x = VecLoad(ptr);
///   uint8x16_p y = VecShiftLeftOctet<12>(x);
/// </pre>
/// \par Wraps
///  vec_sld
/// \sa <A HREF="https://stackoverflow.com/q/46341923/608639">Is vec_sld
///  endian sensitive?</A> on Stack Overflow
/// \since Crypto++ 6.0
template <unsigned int C, class T>
inline T VecShiftLeftOctet(const T vec)
{
    const T zero = {0};
    if (C >= 16)
    {
        // Out of range
        return zero;
    }
    else if (C == 0)
    {
        // Noop
        return vec;
    }
    else
    {
#if defined(CRYPTOPP_BIG_ENDIAN)
    enum { R=C&0xf };
    return (T)vec_sld((uint8x16_p)vec, (uint8x16_p)zero, R);
#else
    enum { R=(16-C)&0xf };  // Linux xlC 13.1 workaround in Debug builds
    return (T)vec_sld((uint8x16_p)zero, (uint8x16_p)vec, R);
#endif
    }
}

/// \brief Shift a vector right
/// \tparam C shift byte count
/// \tparam T vector type
/// \param vec the vector
/// \return vector
/// \details VecShiftRightOctet() returns a new vector after shifting the
///  concatenation of the zero vector and the source vector by the specified
///  number of bytes. The return vector is the same type as vec.
/// \details On big endian machines VecShiftRightOctet() is <tt>vec_sld(a, z,
///  c)</tt>. On little endian machines VecShiftRightOctet() is translated to
///  <tt>vec_sld(z, a, 16-c)</tt>. You should always call the function as
///  if on a big endian machine as shown below.
/// <pre>
///   uint8x16_p x = VecLoad(ptr);
///   uint8x16_p y = VecShiftRightOctet<12>(y);
/// </pre>
/// \par Wraps
///  vec_sld
/// \sa <A HREF="https://stackoverflow.com/q/46341923/608639">Is vec_sld
///  endian sensitive?</A> on Stack Overflow
/// \since Crypto++ 6.0
template <unsigned int C, class T>
inline T VecShiftRightOctet(const T vec)
{
    const T zero = {0};
    if (C >= 16)
    {
        // Out of range
        return zero;
    }
    else if (C == 0)
    {
        // Noop
        return vec;
    }
    else
    {
#if defined(CRYPTOPP_BIG_ENDIAN)
    enum { R=(16-C)&0xf };  // Linux xlC 13.1 workaround in Debug builds
    return (T)vec_sld((uint8x16_p)zero, (uint8x16_p)vec, R);
#else
    enum { R=C&0xf };
    return (T)vec_sld((uint8x16_p)vec, (uint8x16_p)zero, R);
#endif
    }
}

/// \brief Rotate a vector left
/// \tparam C shift byte count
/// \tparam T vector type
/// \param vec the vector
/// \return vector
/// \details VecRotateLeftOctet() returns a new vector after rotating the
///  concatenation of the source vector with itself by the specified
///  number of bytes. The return vector is the same type as vec.
/// \par Wraps
///  vec_sld
/// \sa <A HREF="https://stackoverflow.com/q/46341923/608639">Is vec_sld
///  endian sensitive?</A> on Stack Overflow
/// \since Crypto++ 6.0
template <unsigned int C, class T>
inline T VecRotateLeftOctet(const T vec)
{
#if defined(CRYPTOPP_BIG_ENDIAN)
    enum { R = C&0xf };
    return (T)vec_sld((uint8x16_p)vec, (uint8x16_p)vec, R);
#else
    enum { R=(16-C)&0xf };  // Linux xlC 13.1 workaround in Debug builds
    return (T)vec_sld((uint8x16_p)vec, (uint8x16_p)vec, R);
#endif
}

/// \brief Rotate a vector right
/// \tparam C shift byte count
/// \tparam T vector type
/// \param vec the vector
/// \return vector
/// \details VecRotateRightOctet() returns a new vector after rotating the
///  concatenation of the source vector with itself by the specified
///  number of bytes. The return vector is the same type as vec.
/// \par Wraps
///  vec_sld
/// \sa <A HREF="https://stackoverflow.com/q/46341923/608639">Is vec_sld
///  endian sensitive?</A> on Stack Overflow
/// \since Crypto++ 6.0
template <unsigned int C, class T>
inline T VecRotateRightOctet(const T vec)
{
#if defined(CRYPTOPP_BIG_ENDIAN)
    enum { R=(16-C)&0xf };  // Linux xlC 13.1 workaround in Debug builds
    return (T)vec_sld((uint8x16_p)vec, (uint8x16_p)vec, R);
#else
    enum { R = C&0xf };
    return (T)vec_sld((uint8x16_p)vec, (uint8x16_p)vec, R);
#endif
}

/// \brief Rotate a vector left
/// \tparam C rotate bit count
/// \param vec the vector
/// \return vector
/// \details VecRotateLeft() rotates each element in a vector by
///  bit count. The return vector is the same type as vec.
/// \par Wraps
///  vec_rl
/// \since Crypto++ 7.0
template<unsigned int C>
inline uint32x4_p VecRotateLeft(const uint32x4_p vec)
{
    const uint32x4_p m = {C, C, C, C};
    return vec_rl(vec, m);
}

/// \brief Rotate a vector right
/// \tparam C rotate bit count
/// \param vec the vector
/// \return vector
/// \details VecRotateRight() rotates each element in a vector
///  by bit count. The return vector is the same type as vec.
/// \par Wraps
///  vec_rl
/// \since Crypto++ 7.0
template<unsigned int C>
inline uint32x4_p VecRotateRight(const uint32x4_p vec)
{
    const uint32x4_p m = {32-C, 32-C, 32-C, 32-C};
    return vec_rl(vec, m);
}

/// \brief Shift a vector left
/// \tparam C shift bit count
/// \param vec the vector
/// \return vector
/// \details VecShiftLeft() rotates each element in a vector
///  by bit count. The return vector is the same type as vec.
/// \par Wraps
///  vec_sl
/// \since Crypto++ 8.1
template<unsigned int C>
inline uint32x4_p VecShiftLeft(const uint32x4_p vec)
{
    const uint32x4_p m = {C, C, C, C};
    return vec_sl(vec, m);
}

/// \brief Shift a vector right
/// \tparam C shift bit count
/// \param vec the vector
/// \return vector
/// \details VecShiftRight() rotates each element in a vector
///  by bit count. The return vector is the same type as vec.
/// \par Wraps
///  vec_rl
/// \since Crypto++ 8.1
template<unsigned int C>
inline uint32x4_p VecShiftRight(const uint32x4_p vec)
{
    const uint32x4_p m = {C, C, C, C};
    return vec_sr(vec, m);
}

// 64-bit elements available at POWER7 with VSX, but vec_rl and vec_sl require POWER8
#if defined(_ARCH_PWR8) || defined(CRYPTOPP_DOXYGEN_PROCESSING)

/// \brief Rotate a vector left
/// \tparam C rotate bit count
/// \param vec the vector
/// \return vector
/// \details VecRotateLeft() rotates each element in a vector
///  by bit count. The return vector is the same type as vec.
/// \details VecRotateLeft() with 64-bit elements is available on
///  POWER8 and above.
/// \par Wraps
///  vec_rl
/// \since Crypto++ 8.0
template<unsigned int C>
inline uint64x2_p VecRotateLeft(const uint64x2_p vec)
{
    const uint64x2_p m = {C, C};
    return vec_rl(vec, m);
}

/// \brief Shift a vector left
/// \tparam C shift bit count
/// \param vec the vector
/// \return vector
/// \details VecShiftLeft() rotates each element in a vector
///  by bit count. The return vector is the same type as vec.
/// \details VecShiftLeft() with 64-bit elements is available on
///  POWER8 and above.
/// \par Wraps
///  vec_sl
/// \since Crypto++ 8.1
template<unsigned int C>
inline uint64x2_p VecShiftLeft(const uint64x2_p vec)
{
    const uint64x2_p m = {C, C};
    return vec_sl(vec, m);
}

/// \brief Rotate a vector right
/// \tparam C rotate bit count
/// \param vec the vector
/// \return vector
/// \details VecRotateRight() rotates each element in a vector
///  by bit count. The return vector is the same type as vec.
/// \details VecRotateRight() with 64-bit elements is available on
///  POWER8 and above.
/// \par Wraps
///  vec_rl
/// \since Crypto++ 8.0
template<unsigned int C>
inline uint64x2_p VecRotateRight(const uint64x2_p vec)
{
    const uint64x2_p m = {64-C, 64-C};
    return vec_rl(vec, m);
}

/// \brief Shift a vector right
/// \tparam C shift bit count
/// \param vec the vector
/// \return vector
/// \details VecShiftRight() rotates each element in a vector
///  by bit count. The return vector is the same type as vec.
/// \details VecShiftRight() with 64-bit elements is available on
///  POWER8 and above.
/// \par Wraps
///  vec_sr
/// \since Crypto++ 8.1
template<unsigned int C>
inline uint64x2_p VecShiftRight(const uint64x2_p vec)
{
    const uint64x2_p m = {C, C};
    return vec_sr(vec, m);
}

#endif  // ARCH_PWR8

//@}

/// \name OTHER OPERATIONS
//@{

/// \brief Merge two vectors
/// \tparam T vector type
/// \param vec1 the first vector
/// \param vec2 the second vector
/// \return vector
/// \par Wraps
///  vec_mergel
/// \since Crypto++ 8.1
template <class T>
inline T VecMergeLow(const T vec1, const T vec2)
{
    return vec_mergel(vec1, vec2);
}

/// \brief Merge two vectors
/// \tparam T vector type
/// \param vec1 the first vector
/// \param vec2 the second vector
/// \return vector
/// \par Wraps
///  vec_mergeh
/// \since Crypto++ 8.1
template <class T>
inline T VecMergeHigh(const T vec1, const T vec2)
{
    return vec_mergeh(vec1, vec2);
}

/// \brief Broadcast 32-bit word to a vector
/// \param val the 32-bit value
/// \return vector
/// \par Wraps
///  vec_splats
/// \since Crypto++ 8.3
inline uint32x4_p VecSplatWord(word32 val)
{
    // Fix spurious GCC warning???
    CRYPTOPP_UNUSED(val);

    // Apple Altivec and XL C++ do not offer vec_splats.
    // GCC offers vec_splats back to -mcpu=power4.
#if defined(_ARCH_PWR4) && defined(__GNUC__)
    return vec_splats(val);
#else
    //const word32 x[4] = {val,val,val,val};
    //return VecLoad(x);
    const word32 x[4] = {val};
    return vec_splat(VecLoad(x),0);
#endif
}

/// \brief Broadcast 32-bit element to a vector
/// \tparam the element number
/// \param val the 32-bit value
/// \return vector
/// \par Wraps
///  vec_splat
/// \since Crypto++ 8.3
template <unsigned int N>
inline uint32x4_p VecSplatElement(const uint32x4_p val)
{
    return vec_splat(val, N);
}

#if defined(__VSX__) || defined(_ARCH_PWR8) || defined(CRYPTOPP_DOXYGEN_PROCESSING)
/// \brief Broadcast 64-bit double word to a vector
/// \param val the 64-bit value
/// \return vector
/// \par Wraps
///  vec_splats
/// \since Crypto++ 8.3
inline uint64x2_p VecSplatWord(word64 val)
{
    // The PPC64 ABI says so.
    return vec_splats((unsigned long long)val);
}

/// \brief Broadcast 64-bit element to a vector
/// \tparam the element number
/// \param val the 64-bit value
/// \return vector
/// \par Wraps
///  vec_splat
/// \since Crypto++ 8.3
template <unsigned int N>
inline uint64x2_p VecSplatElement(const uint64x2_p val)
{
#if defined(__VSX__) || defined(_ARCH_PWR8)
    return vec_splat(val, N);
#else
    enum {E=N&1};
    if (E == 0)
    {
        const uint8x16_p m = {0,1,2,3, 4,5,6,7, 0,1,2,3, 4,5,6,7};
        return vec_perm(val, val, m);
    }
    else // (E == 1)
    {
        const uint8x16_p m = {8,9,10,11, 12,13,14,15, 8,9,10,11, 12,13,14,15};
        return vec_perm(val, val, m);
    }
#endif
}
#endif

/// \brief Extract a dword from a vector
/// \tparam T vector type
/// \param val the vector
/// \return vector created from low dword
/// \details VecGetLow() extracts the low dword from a vector. The low dword
///  is composed of the least significant bits and occupies bytes 8 through 15
///  when viewed as a big endian array. The return vector is the same type as
///  the original vector and padded with 0's in the most significant bit positions.
/// \par Wraps
///  vec_sld
/// \since Crypto++ 7.0
template <class T>
inline T VecGetLow(const T val)
{
#if defined(CRYPTOPP_BIG_ENDIAN) && (defined(__VSX__) || defined(_ARCH_PWR8))
    const T zero = {0};
    return (T)VecMergeLow((uint64x2_p)zero, (uint64x2_p)val);
#else
    return VecShiftRightOctet<8>(VecShiftLeftOctet<8>(val));
#endif
}

/// \brief Extract a dword from a vector
/// \tparam T vector type
/// \param val the vector
/// \return vector created from high dword
/// \details VecGetHigh() extracts the high dword from a vector. The high dword
///  is composed of the most significant bits and occupies bytes 0 through 7
///  when viewed as a big endian array. The return vector is the same type as
///  the original vector and padded with 0's in the most significant bit positions.
/// \par Wraps
///  vec_sld
/// \since Crypto++ 7.0
template <class T>
inline T VecGetHigh(const T val)
{
#if defined(CRYPTOPP_BIG_ENDIAN) && (defined(__VSX__) || defined(_ARCH_PWR8))
    const T zero = {0};
    return (T)VecMergeHigh((uint64x2_p)zero, (uint64x2_p)val);
#else
    return VecShiftRightOctet<8>(val);
#endif
}

/// \brief Exchange high and low double words
/// \tparam T vector type
/// \param vec the vector
/// \return vector
/// \par Wraps
///  vec_sld
/// \since Crypto++ 7.0
template <class T>
inline T VecSwapWords(const T vec)
{
    return (T)vec_sld((uint8x16_p)vec, (uint8x16_p)vec, 8);
}

//@}

/// \name COMPARISON
//@{

/// \brief Compare two vectors
/// \tparam T1 vector type
/// \tparam T2 vector type
/// \param vec1 the first vector
/// \param vec2 the second vector
/// \return true if vec1 equals vec2, false otherwise
/// \details VecEqual() performs a bitwise compare. The vector element types do
///  not matter.
/// \par Wraps
///  vec_all_eq
/// \since Crypto++ 8.0
template <class T1, class T2>
inline bool VecEqual(const T1 vec1, const T2 vec2)
{
    return 1 == vec_all_eq((uint32x4_p)vec1, (uint32x4_p)vec2);
}

/// \brief Compare two vectors
/// \tparam T1 vector type
/// \tparam T2 vector type
/// \param vec1 the first vector
/// \param vec2 the second vector
/// \return true if vec1 does not equal vec2, false otherwise
/// \details VecNotEqual() performs a bitwise compare. The vector element types do
///  not matter.
/// \par Wraps
///  vec_all_eq
/// \since Crypto++ 8.0
template <class T1, class T2>
inline bool VecNotEqual(const T1 vec1, const T2 vec2)
{
    return 0 == vec_all_eq((uint32x4_p)vec1, (uint32x4_p)vec2);
}

//@}

////////////////// 32-bit Altivec /////////////////

/// \name 32-BIT ALTIVEC
//@{

/// \brief Add two vectors as if uint64x2_p
/// \param vec1 the first vector
/// \param vec2 the second vector
/// \return vector
/// \details VecAdd64() performs <tt>vec1 + vec2</tt>. VecAdd64() performs as
///  if adding two uint64x2_p vectors. On POWER7 and below VecAdd64() manages
///  the carries from the elements.
/// \par Wraps
///  vec_add for POWER8, vec_addc, vec_perm, vec_add for Altivec
/// \since Crypto++ 8.3
inline uint32x4_p VecAdd64(const uint32x4_p& vec1, const uint32x4_p& vec2)
{
    // 64-bit elements available at POWER7 with VSX, but addudm requires POWER8
#if defined(_ARCH_PWR8) && !defined(CRYPTOPP_DEBUG)
    return (uint32x4_p)vec_add((uint64x2_p)vec1, (uint64x2_p)vec2);
#else
    // The carry mask selects carrys for elements 1 and 3 and sets
    // remaining elements to 0. The results is then shifted so the
    // carried values are added to elements 0 and 2.
#if defined(CRYPTOPP_BIG_ENDIAN)
    const uint32x4_p zero = {0, 0, 0, 0};
    const uint32x4_p mask = {0, 1, 0, 1};
#else
    const uint32x4_p zero = {0, 0, 0, 0};
    const uint32x4_p mask = {1, 0, 1, 0};
#endif

    uint32x4_p cy = vec_addc(vec1, vec2);
    uint32x4_p res = vec_add(vec1, vec2);
    cy = vec_and(mask, cy);
    cy = vec_sld (cy, zero, 4);
    return vec_add(res, cy);
#endif
}

#if defined(_ARCH_PWR8) || defined(CRYPTOPP_DOXYGEN_PROCESSING)
/// \brief Add two vectors as if uint64x2_p
/// \param vec1 the first vector
/// \param vec2 the second vector
/// \return vector
/// \details VecAdd64() performs <tt>vec1 + vec2</tt>. VecAdd64() performs as
///  if adding two uint64x2_p vectors. On POWER7 and below VecAdd64() manages
///  the carries from the elements.
/// \par Wraps
///  vec_add for POWER8
/// \since Crypto++ 8.3
inline uint64x2_p VecAdd64(const uint64x2_p& vec1, const uint64x2_p& vec2)
{
    // 64-bit elements available at POWER7 with VSX, but addudm requires POWER8
    const uint64x2_p res = vec_add(vec1, vec2);

#if defined(CRYPTOPP_DEBUG)
    // Test 32-bit add in debug builds while we are here.
    const uint32x4_p x = (uint32x4_p)vec1;
    const uint32x4_p y = (uint32x4_p)vec2;
    const uint32x4_p r = VecAdd64(x, y);

    CRYPTOPP_ASSERT(vec_all_eq((uint32x4_p)res, r) == 1);
#endif

    return res;
}
#endif

/// \brief Subtract two vectors as if uint64x2_p
/// \param vec1 the first vector
/// \param vec2 the second vector
/// \details VecSub64() performs <tt>vec1 - vec2</tt>. VecSub64() performs as
///  if subtracting two uint64x2_p vectors. On POWER7 and below VecSub64()
///  manages the borrows from the elements.
/// \par Wraps
///  vec_sub for POWER8, vec_subc, vec_andc, vec_perm, vec_sub for Altivec
/// \since Crypto++ 8.3
inline uint32x4_p VecSub64(const uint32x4_p& vec1, const uint32x4_p& vec2)
{
#if defined(_ARCH_PWR8) && !defined(CRYPTOPP_DEBUG)
    // 64-bit elements available at POWER7 with VSX, but subudm requires POWER8
    return (uint32x4_p)vec_sub((uint64x2_p)vec1, (uint64x2_p)vec2);
#else
    // The borrow mask selects borrows for elements 1 and 3 and sets
    // remaining elements to 0. The results is then shifted so the
    // borrowed values are subtracted from elements 0 and 2.
#if defined(CRYPTOPP_BIG_ENDIAN)
    const uint32x4_p zero = {0, 0, 0, 0};
    const uint32x4_p mask = {0, 1, 0, 1};
#else
    const uint32x4_p zero = {0, 0, 0, 0};
    const uint32x4_p mask = {1, 0, 1, 0};
#endif

    // subc sets the complement of borrow, so we have to
    // un-complement it using andc.
    uint32x4_p bw = vec_subc(vec1, vec2);
    uint32x4_p res = vec_sub(vec1, vec2);
    bw = vec_andc(mask, bw);
    bw = vec_sld (bw, zero, 4);
    return vec_sub(res, bw);
#endif
}

#if defined(_ARCH_PWR8) || defined(CRYPTOPP_DOXYGEN_PROCESSING)
/// \brief Subtract two vectors as if uint64x2_p
/// \param vec1 the first vector
/// \param vec2 the second vector
/// \details VecSub64() performs <tt>vec1 - vec2</tt>. VecSub64() performs as
///  if subtracting two uint64x2_p vectors. On POWER7 and below VecSub64()
///  manages the borrows from the elements.
/// \par Wraps
///  vec_sub for POWER8
/// \since Crypto++ 8.3
inline uint64x2_p VecSub64(const uint64x2_p& vec1, const uint64x2_p& vec2)
{
    // 64-bit elements available at POWER7 with VSX, but subudm requires POWER8
    const uint64x2_p res = vec_sub(vec1, vec2);

#if defined(CRYPTOPP_DEBUG)
    // Test 32-bit sub in debug builds while we are here.
    const uint32x4_p x = (uint32x4_p)vec1;
    const uint32x4_p y = (uint32x4_p)vec2;
    const uint32x4_p r = VecSub64(x, y);

    CRYPTOPP_ASSERT(vec_all_eq((uint32x4_p)res, r) == 1);
#endif

    return res;
}
#endif

/// \brief Rotate a vector left as if uint64x2_p
/// \tparam C rotate bit count
/// \param vec the vector
/// \return vector
/// \details VecRotateLeft() rotates each element in a vector by bit count.
///  vec is rotated as if uint64x2_p.
/// \par Wraps
///  vec_rl
/// \since Crypto++ 8.3
template<unsigned int C>
inline uint32x4_p VecRotateLeft64(const uint32x4_p vec)
{
#if defined(_ARCH_PWR8) && !defined(CRYPTOPP_DEBUG)
    // 64-bit elements available at POWER7 with VSX, but vec_rl and vec_sl require POWER8
    return (uint32x4_p)VecRotateLeft<C>((uint64x2_p)vec);
#else
    // C=0, 32, or 64 needs special handling. That is S32 and S64 below.
    enum {S64=C&63, S32=C&31, BR=(S64>=32)};

    // Get the low bits, shift them to high bits
    uint32x4_p t1 = VecShiftLeft<S32>(vec);
    // Get the high bits, shift them to low bits
    uint32x4_p t2 = VecShiftRight<32-S32>(vec);

    if (S64 == 0)
    {
        const uint8x16_p m = {0,1,2,3, 4,5,6,7, 8,9,10,11, 12,13,14,15};
        return VecPermute(vec, m);
    }
    else if (S64 == 32)
    {
        const uint8x16_p m = {4,5,6,7, 0,1,2,3, 12,13,14,15, 8,9,10,11};
        return VecPermute(vec, m);
    }
    else if (BR)  // Big rotate amount?
    {
        const uint8x16_p m = {4,5,6,7, 0,1,2,3, 12,13,14,15, 8,9,10,11};
        t1 = VecPermute(t1, m);
    }
    else
    {
        const uint8x16_p m = {4,5,6,7, 0,1,2,3, 12,13,14,15, 8,9,10,11};
        t2 = VecPermute(t2, m);
    }

    return vec_or(t1, t2);
#endif
}

/// \brief Rotate a vector left as if uint64x2_p
/// \param vec the vector
/// \return vector
/// \details VecRotateLeft<8>() rotates each element in a vector
///  by 8-bits. vec is rotated as if uint64x2_p. This specialization
///  is used by algorithms like Speck128.
/// \par Wraps
///  vec_rl
/// \since Crypto++ 8.3
template<>
inline uint32x4_p VecRotateLeft64<8>(const uint32x4_p vec)
{
#if (CRYPTOPP_BIG_ENDIAN)
    const uint8x16_p m = { 1,2,3,4, 5,6,7,0, 9,10,11,12, 13,14,15,8 };
    return VecPermute(vec, m);
#else
    const uint8x16_p m = { 7,0,1,2, 3,4,5,6, 15,8,9,10, 11,12,13,14 };
    return VecPermute(vec, m);
#endif
}

#if defined(_ARCH_PWR8) || defined(CRYPTOPP_DOXYGEN_PROCESSING)
/// \brief Rotate a vector left as if uint64x2_p
/// \tparam C rotate bit count
/// \param vec the vector
/// \return vector
/// \details VecRotateLeft64() rotates each element in a vector by
///  bit count. vec is rotated as if uint64x2_p.
/// \par Wraps
///  vec_rl
/// \since Crypto++ 8.3
template<unsigned int C>
inline uint64x2_p VecRotateLeft64(const uint64x2_p vec)
{
    // 64-bit elements available at POWER7 with VSX, but vec_rl and vec_sl require POWER8
    const uint64x2_p res = VecRotateLeft<C>(vec);

#if defined(CRYPTOPP_DEBUG)
    // Test 32-bit rotate in debug builds while we are here.
    const uint32x4_p x = (uint32x4_p)vec;
    const uint32x4_p r = VecRotateLeft64<C>(x);

    CRYPTOPP_ASSERT(vec_all_eq((uint32x4_p)res, r) == 1);
#endif

    return res;
}
#endif

/// \brief Rotate a vector right as if uint64x2_p
/// \tparam C rotate bit count
/// \param vec the vector
/// \return vector
/// \details VecRotateRight64() rotates each element in a vector by
///  bit count. vec is rotated as if uint64x2_p.
/// \par Wraps
///  vec_rl
/// \since Crypto++ 8.3
template<unsigned int C>
inline uint32x4_p VecRotateRight64(const uint32x4_p vec)
{
#if defined(_ARCH_PWR8) && !defined(CRYPTOPP_DEBUG)
    // 64-bit elements available at POWER7 with VSX, but vec_rl and vec_sl require POWER8
    return (uint32x4_p)VecRotateRight<C>((uint64x2_p)vec);
#else
    // C=0, 32, or 64 needs special handling. That is S32 and S64 below.
    enum {S64=C&63, S32=C&31, BR=(S64>=32)};

    // Get the low bits, shift them to high bits
    uint32x4_p t1 = VecShiftRight<S32>(vec);
    // Get the high bits, shift them to low bits
    uint32x4_p t2 = VecShiftLeft<32-S32>(vec);

    if (S64 == 0)
    {
        const uint8x16_p m = {0,1,2,3, 4,5,6,7, 8,9,10,11, 12,13,14,15};
        return VecPermute(vec, m);
    }
    else if (S64 == 32)
    {
        const uint8x16_p m = {4,5,6,7, 0,1,2,3, 12,13,14,15, 8,9,10,11};
        return VecPermute(vec, m);
    }
    else if (BR)  // Big rotate amount?
    {
        const uint8x16_p m = {4,5,6,7, 0,1,2,3, 12,13,14,15, 8,9,10,11};
        t1 = VecPermute(t1, m);
    }
    else
    {
        const uint8x16_p m = {4,5,6,7, 0,1,2,3, 12,13,14,15, 8,9,10,11};
        t2 = VecPermute(t2, m);
    }

    return vec_or(t1, t2);
#endif
}

/// \brief Rotate a vector right as if uint64x2_p
/// \param vec the vector
/// \return vector
/// \details VecRotateRight64<8>() rotates each element in a vector
///  by 8-bits. vec is rotated as if uint64x2_p. This specialization
///  is used by algorithms like Speck128.
/// \details vec is rotated as if uint64x2_p.
/// \par Wraps
///  vec_rl
/// \since Crypto++ 8.3
template<>
inline uint32x4_p VecRotateRight64<8>(const uint32x4_p vec)
{
#if (CRYPTOPP_BIG_ENDIAN)
    const uint8x16_p m = { 7,0,1,2, 3,4,5,6, 15,8,9,10, 11,12,13,14 };
    return VecPermute(vec, m);
#else
    const uint8x16_p m = { 1,2,3,4, 5,6,7,0, 9,10,11,12, 13,14,15,8 };
    return VecPermute(vec, m);
#endif
}

#if defined(__VSX__) || defined(_ARCH_PWR8) || defined(CRYPTOPP_DOXYGEN_PROCESSING)
/// \brief Rotate a vector right as if uint64x2_p
/// \tparam C rotate bit count
/// \param vec the vector
/// \return vector
/// \details VecRotateRight64() rotates each element in a vector by
///  bit count. vec is rotated as if uint64x2_p.
/// \par Wraps
///  vec_rl
/// \since Crypto++ 8.3
template<unsigned int C>
inline uint64x2_p VecRotateRight64(const uint64x2_p vec)
{
    // 64-bit elements available at POWER7 with VSX, but vec_rl and vec_sl require POWER8
    const uint64x2_p res = VecRotateRight<C>(vec);

#if defined(CRYPTOPP_DEBUG)
    // Test 32-bit rotate in debug builds while we are here.
    const uint32x4_p x = (uint32x4_p)vec;
    const uint32x4_p r = VecRotateRight64<C>(x);

    CRYPTOPP_ASSERT(vec_all_eq((uint32x4_p)res, r) == 1);
#endif

    return res;
}
#endif

/// \brief AND two vectors as if uint64x2_p
/// \tparam T1 vector type
/// \tparam T2 vector type
/// \param vec1 the first vector
/// \param vec2 the second vector
/// \return vector
/// \details VecAnd64() performs <tt>vec1 & vec2</tt>.
///  vec2 is cast to the same type as vec1. The return vector
///  is the same type as vec1.
/// \details VecAnd64() is a convenience function that simply performs a VecAnd().
/// \par Wraps
///  vec_and
/// \since Crypto++ 8.3
template <class T1, class T2>
inline T1 VecAnd64(const T1 vec1, const T2 vec2)
{
    return (T1)vec_and(vec1, (T1)vec2);
}

/// \brief OR two vectors as if uint64x2_p
/// \tparam T1 vector type
/// \tparam T2 vector type
/// \param vec1 the first vector
/// \param vec2 the second vector
/// \return vector
/// \details VecOr64() performs <tt>vec1 | vec2</tt>.
///  vec2 is cast to the same type as vec1. The return vector
///  is the same type as vec1.
/// \details VecOr64() is a convenience function that simply performs a VecOr().
/// \par Wraps
///  vec_or
/// \since Crypto++ 8.3
template <class T1, class T2>
inline T1 VecOr64(const T1 vec1, const T2 vec2)
{
    return (T1)vec_or(vec1, (T1)vec2);
}

/// \brief XOR two vectors as if uint64x2_p
/// \tparam T1 vector type
/// \tparam T2 vector type
/// \param vec1 the first vector
/// \param vec2 the second vector
/// \return vector
/// \details VecXor64() performs <tt>vec1 ^ vec2</tt>.
///  vec2 is cast to the same type as vec1. The return vector
///  is the same type as vec1.
/// \details VecXor64() is a convenience function that simply performs a VecXor().
/// \par Wraps
///  vec_xor
/// \since Crypto++ 8.3
template <class T1, class T2>
inline T1 VecXor64(const T1 vec1, const T2 vec2)
{
    return (T1)vec_xor(vec1, (T1)vec2);
}

/// \brief Broadcast 64-bit double word to a vector
/// \param val the 64-bit value
/// \return vector
/// \par Wraps
///  vec_splats
/// \since Crypto++ 8.3
inline uint32x4_p VecSplatWord64(word64 val)
{
#if defined(_ARCH_PWR8)
    // The PPC64 ABI says so.
    return (uint32x4_p)vec_splats((unsigned long long)val);
#else
    const word64 x[2] = {val,val};
    return (uint32x4_p)VecLoad((const word32*)x);
#endif
}

/// \brief Broadcast 64-bit element to a vector as if uint64x2_p
/// \tparam the element number
/// \param val the 64-bit value
/// \return vector
/// \par Wraps
///  vec_splat
/// \since Crypto++ 8.3
template <unsigned int N>
inline uint32x4_p VecSplatElement64(const uint32x4_p val)
{
#if defined(__VSX__) || defined(_ARCH_PWR8)
    return (uint32x4_p)vec_splat((uint64x2_p)val, N);
#else
    enum {E=N&1};
    if (E == 0)
    {
        const uint8x16_p m = {0,1,2,3, 4,5,6,7, 0,1,2,3, 4,5,6,7};
        return (uint32x4_p)vec_perm(val, val, m);
    }
    else // (E == 1)
    {
        const uint8x16_p m = {8,9,10,11, 12,13,14,15, 8,9,10,11, 12,13,14,15};
        return (uint32x4_p)vec_perm(val, val, m);
    }
#endif
}

#if defined(__VSX__) || defined(_ARCH_PWR8) || defined(CRYPTOPP_DOXYGEN_PROCESSING)
/// \brief Broadcast 64-bit element to a vector
/// \tparam the element number
/// \param val the 64-bit value
/// \return vector
/// \since Crypto++ 8.3
template <unsigned int N>
inline uint64x2_p VecSplatElement64(const uint64x2_p val)
{
    return vec_splat(val, N);
}
#endif

//@}

//////////////////////// Power8 Crypto ////////////////////////

// __CRYPTO__ alone is not enough. Clang will define __CRYPTO__
// when it is not available, like with Power7. Sigh...
#if (defined(_ARCH_PWR8) && defined(__CRYPTO__)) || defined(CRYPTOPP_DOXYGEN_PROCESSING)

/// \name POLYNOMIAL MULTIPLICATION
//@{

/// \brief Polynomial multiplication
/// \param a the first term
/// \param b the second term
/// \return vector product
/// \details VecPolyMultiply() performs polynomial multiplication. POWER8
///  polynomial multiplication multiplies the high and low terms, and then
///  XOR's the high and low products. That is, the result is <tt>ah*bh XOR
///  al*bl</tt>. It is different behavior than Intel polynomial
///  multiplication. To obtain a single product without the XOR, then set
///  one of the high or low terms to 0. For example, setting <tt>ah=0</tt>
///  results in <tt>0*bh XOR al*bl = al*bl</tt>.
/// \par Wraps
///  __vpmsumw, __builtin_altivec_crypto_vpmsumw and __builtin_crypto_vpmsumw.
/// \since Crypto++ 8.1
inline uint32x4_p VecPolyMultiply(const uint32x4_p& a, const uint32x4_p& b)
{
#if defined(__ibmxl__) || (defined(_AIX) && defined(__xlC__))
    return __vpmsumw (a, b);
#elif defined(__clang__)
    return __builtin_altivec_crypto_vpmsumw (a, b);
#else
    return __builtin_crypto_vpmsumw (a, b);
#endif
}

/// \brief Polynomial multiplication
/// \param a the first term
/// \param b the second term
/// \return vector product
/// \details VecPolyMultiply() performs polynomial multiplication. POWER8
///  polynomial multiplication multiplies the high and low terms, and then
///  XOR's the high and low products. That is, the result is <tt>ah*bh XOR
///  al*bl</tt>. It is different behavior than Intel polynomial
///  multiplication. To obtain a single product without the XOR, then set
///  one of the high or low terms to 0. For example, setting <tt>ah=0</tt>
///  results in <tt>0*bh XOR al*bl = al*bl</tt>.
/// \par Wraps
///  __vpmsumd, __builtin_altivec_crypto_vpmsumd and __builtin_crypto_vpmsumd.
/// \since Crypto++ 8.1
inline uint64x2_p VecPolyMultiply(const uint64x2_p& a, const uint64x2_p& b)
{
#if defined(__ibmxl__) || (defined(_AIX) && defined(__xlC__))
    return __vpmsumd (a, b);
#elif defined(__clang__)
    return __builtin_altivec_crypto_vpmsumd (a, b);
#else
    return __builtin_crypto_vpmsumd (a, b);
#endif
}

/// \brief Polynomial multiplication
/// \param a the first term
/// \param b the second term
/// \return vector product
/// \details VecIntelMultiply00() performs polynomial multiplication and presents
///  the result like Intel's <tt>c = _mm_clmulepi64_si128(a, b, 0x00)</tt>.
///  The <tt>0x00</tt> indicates the low 64-bits of <tt>a</tt> and <tt>b</tt>
///  are multiplied.
/// \note An Intel XMM register is composed of 128-bits. The leftmost bit
///  is MSB and numbered 127, while the rightmost bit is LSB and numbered 0.
/// \par Wraps
///  __vpmsumd, __builtin_altivec_crypto_vpmsumd and __builtin_crypto_vpmsumd.
/// \since Crypto++ 8.0
inline uint64x2_p VecIntelMultiply00(const uint64x2_p& a, const uint64x2_p& b)
{
#if defined(CRYPTOPP_BIG_ENDIAN)
    return VecSwapWords(VecPolyMultiply(VecGetHigh(a), VecGetHigh(b)));
#else
    return VecPolyMultiply(VecGetHigh(a), VecGetHigh(b));
#endif
}

/// \brief Polynomial multiplication
/// \param a the first term
/// \param b the second term
/// \return vector product
/// \details VecIntelMultiply01 performs() polynomial multiplication and presents
///  the result like Intel's <tt>c = _mm_clmulepi64_si128(a, b, 0x01)</tt>.
///  The <tt>0x01</tt> indicates the low 64-bits of <tt>a</tt> and high
///  64-bits of <tt>b</tt> are multiplied.
/// \note An Intel XMM register is composed of 128-bits. The leftmost bit
///  is MSB and numbered 127, while the rightmost bit is LSB and numbered 0.
/// \par Wraps
///  __vpmsumd, __builtin_altivec_crypto_vpmsumd and __builtin_crypto_vpmsumd.
/// \since Crypto++ 8.0
inline uint64x2_p VecIntelMultiply01(const uint64x2_p& a, const uint64x2_p& b)
{
#if defined(CRYPTOPP_BIG_ENDIAN)
    return VecSwapWords(VecPolyMultiply(a, VecGetHigh(b)));
#else
    return VecPolyMultiply(a, VecGetHigh(b));
#endif
}

/// \brief Polynomial multiplication
/// \param a the first term
/// \param b the second term
/// \return vector product
/// \details VecIntelMultiply10() performs polynomial multiplication and presents
///  the result like Intel's <tt>c = _mm_clmulepi64_si128(a, b, 0x10)</tt>.
///  The <tt>0x10</tt> indicates the high 64-bits of <tt>a</tt> and low
///  64-bits of <tt>b</tt> are multiplied.
/// \note An Intel XMM register is composed of 128-bits. The leftmost bit
///  is MSB and numbered 127, while the rightmost bit is LSB and numbered 0.
/// \par Wraps
///  __vpmsumd, __builtin_altivec_crypto_vpmsumd and __builtin_crypto_vpmsumd.
/// \since Crypto++ 8.0
inline uint64x2_p VecIntelMultiply10(const uint64x2_p& a, const uint64x2_p& b)
{
#if defined(CRYPTOPP_BIG_ENDIAN)
    return VecSwapWords(VecPolyMultiply(VecGetHigh(a), b));
#else
    return VecPolyMultiply(VecGetHigh(a), b);
#endif
}

/// \brief Polynomial multiplication
/// \param a the first term
/// \param b the second term
/// \return vector product
/// \details VecIntelMultiply11() performs polynomial multiplication and presents
///  the result like Intel's <tt>c = _mm_clmulepi64_si128(a, b, 0x11)</tt>.
///  The <tt>0x11</tt> indicates the high 64-bits of <tt>a</tt> and <tt>b</tt>
///  are multiplied.
/// \note An Intel XMM register is composed of 128-bits. The leftmost bit
///  is MSB and numbered 127, while the rightmost bit is LSB and numbered 0.
/// \par Wraps
///  __vpmsumd, __builtin_altivec_crypto_vpmsumd and __builtin_crypto_vpmsumd.
/// \since Crypto++ 8.0
inline uint64x2_p VecIntelMultiply11(const uint64x2_p& a, const uint64x2_p& b)
{
#if defined(CRYPTOPP_BIG_ENDIAN)
    return VecSwapWords(VecPolyMultiply(VecGetLow(a), b));
#else
    return VecPolyMultiply(VecGetLow(a), b);
#endif
}

//@}

/// \name AES ENCRYPTION
//@{

/// \brief One round of AES encryption
/// \tparam T1 vector type
/// \tparam T2 vector type
/// \param state the state vector
/// \param key the subkey vector
/// \details VecEncrypt() performs one round of AES encryption of state
///  using subkey key. The return vector is the same type as state.
/// \details VecEncrypt() is available on POWER8 and above.
/// \par Wraps
///  __vcipher, __builtin_altivec_crypto_vcipher, __builtin_crypto_vcipher
/// \since GCC and XLC since Crypto++ 6.0, LLVM Clang since Crypto++ 8.0
template <class T1, class T2>
inline T1 VecEncrypt(const T1 state, const T2 key)
{
#if defined(__ibmxl__) || (defined(_AIX) && defined(__xlC__))
    return (T1)__vcipher((uint8x16_p)state, (uint8x16_p)key);
#elif defined(__clang__)
    return (T1)__builtin_altivec_crypto_vcipher((uint64x2_p)state, (uint64x2_p)key);
#elif defined(__GNUC__)
    return (T1)__builtin_crypto_vcipher((uint64x2_p)state, (uint64x2_p)key);
#else
    CRYPTOPP_ASSERT(0);
#endif
}

/// \brief Final round of AES encryption
/// \tparam T1 vector type
/// \tparam T2 vector type
/// \param state the state vector
/// \param key the subkey vector
/// \details VecEncryptLast() performs the final round of AES encryption
///  of state using subkey key. The return vector is the same type as state.
/// \details VecEncryptLast() is available on POWER8 and above.
/// \par Wraps
///  __vcipherlast, __builtin_altivec_crypto_vcipherlast, __builtin_crypto_vcipherlast
/// \since GCC and XLC since Crypto++ 6.0, LLVM Clang since Crypto++ 8.0
template <class T1, class T2>
inline T1 VecEncryptLast(const T1 state, const T2 key)
{
#if defined(__ibmxl__) || (defined(_AIX) && defined(__xlC__))
    return (T1)__vcipherlast((uint8x16_p)state, (uint8x16_p)key);
#elif defined(__clang__)
    return (T1)__builtin_altivec_crypto_vcipherlast((uint64x2_p)state, (uint64x2_p)key);
#elif defined(__GNUC__)
    return (T1)__builtin_crypto_vcipherlast((uint64x2_p)state, (uint64x2_p)key);
#else
    CRYPTOPP_ASSERT(0);
#endif
}

/// \brief One round of AES decryption
/// \tparam T1 vector type
/// \tparam T2 vector type
/// \param state the state vector
/// \param key the subkey vector
/// \details VecDecrypt() performs one round of AES decryption of state
///  using subkey key. The return vector is the same type as state.
/// \details VecDecrypt() is available on POWER8 and above.
/// \par Wraps
///  __vncipher, __builtin_altivec_crypto_vncipher, __builtin_crypto_vncipher
/// \since GCC and XLC since Crypto++ 6.0, LLVM Clang since Crypto++ 8.0
template <class T1, class T2>
inline T1 VecDecrypt(const T1 state, const T2 key)
{
#if defined(__ibmxl__) || (defined(_AIX) && defined(__xlC__))
    return (T1)__vncipher((uint8x16_p)state, (uint8x16_p)key);
#elif defined(__clang__)
    return (T1)__builtin_altivec_crypto_vncipher((uint64x2_p)state, (uint64x2_p)key);
#elif defined(__GNUC__)
    return (T1)__builtin_crypto_vncipher((uint64x2_p)state, (uint64x2_p)key);
#else
    CRYPTOPP_ASSERT(0);
#endif
}

/// \brief Final round of AES decryption
/// \tparam T1 vector type
/// \tparam T2 vector type
/// \param state the state vector
/// \param key the subkey vector
/// \details VecDecryptLast() performs the final round of AES decryption
///  of state using subkey key. The return vector is the same type as state.
/// \details VecDecryptLast() is available on POWER8 and above.
/// \par Wraps
///  __vncipherlast, __builtin_altivec_crypto_vncipherlast, __builtin_crypto_vncipherlast
/// \since GCC and XLC since Crypto++ 6.0, LLVM Clang since Crypto++ 8.0
template <class T1, class T2>
inline T1 VecDecryptLast(const T1 state, const T2 key)
{
#if defined(__ibmxl__) || (defined(_AIX) && defined(__xlC__))
    return (T1)__vncipherlast((uint8x16_p)state, (uint8x16_p)key);
#elif defined(__clang__)
    return (T1)__builtin_altivec_crypto_vncipherlast((uint64x2_p)state, (uint64x2_p)key);
#elif defined(__GNUC__)
    return (T1)__builtin_crypto_vncipherlast((uint64x2_p)state, (uint64x2_p)key);
#else
    CRYPTOPP_ASSERT(0);
#endif
}

//@}

/// \name SHA DIGESTS
//@{

/// \brief SHA256 Sigma functions
/// \tparam func function
/// \tparam fmask function mask
/// \tparam T vector type
/// \param data the block to transform
/// \details VecSHA256() selects sigma0, sigma1, Sigma0, Sigma1 based on
///  func and fmask. The return vector is the same type as data.
/// \details VecSHA256() is available on POWER8 and above.
/// \par Wraps
///  __vshasigmaw, __builtin_altivec_crypto_vshasigmaw, __builtin_crypto_vshasigmaw
/// \since GCC and XLC since Crypto++ 6.0, LLVM Clang since Crypto++ 8.0
template <int func, int fmask, class T>
inline T VecSHA256(const T data)
{
#if defined(__ibmxl__) || (defined(_AIX) && defined(__xlC__))
    return (T)__vshasigmaw((uint32x4_p)data, func, fmask);
#elif defined(__clang__)
    return (T)__builtin_altivec_crypto_vshasigmaw((uint32x4_p)data, func, fmask);
#elif defined(__GNUC__)
    return (T)__builtin_crypto_vshasigmaw((uint32x4_p)data, func, fmask);
#else
    CRYPTOPP_ASSERT(0);
#endif
}

/// \brief SHA512 Sigma functions
/// \tparam func function
/// \tparam fmask function mask
/// \tparam T vector type
/// \param data the block to transform
/// \details VecSHA512() selects sigma0, sigma1, Sigma0, Sigma1 based on
///  func and fmask. The return vector is the same type as data.
/// \details VecSHA512() is available on POWER8 and above.
/// \par Wraps
///  __vshasigmad, __builtin_altivec_crypto_vshasigmad, __builtin_crypto_vshasigmad
/// \since GCC and XLC since Crypto++ 6.0, LLVM Clang since Crypto++ 8.0
template <int func, int fmask, class T>
inline T VecSHA512(const T data)
{
#if defined(__ibmxl__) || (defined(_AIX) && defined(__xlC__))
    return (T)__vshasigmad((uint64x2_p)data, func, fmask);
#elif defined(__clang__)
    return (T)__builtin_altivec_crypto_vshasigmad((uint64x2_p)data, func, fmask);
#elif defined(__GNUC__)
    return (T)__builtin_crypto_vshasigmad((uint64x2_p)data, func, fmask);
#else
    CRYPTOPP_ASSERT(0);
#endif
}

//@}

#endif  // __CRYPTO__

#endif  // _ALTIVEC_

NAMESPACE_END

#if CRYPTOPP_GCC_DIAGNOSTIC_AVAILABLE
# pragma GCC diagnostic pop
#endif

#endif  // CRYPTOPP_PPC_CRYPTO_H
