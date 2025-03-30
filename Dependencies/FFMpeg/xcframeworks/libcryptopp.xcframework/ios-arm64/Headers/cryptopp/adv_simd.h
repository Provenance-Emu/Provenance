// adv_simd.h - written and placed in the public domain by Jeffrey Walton

/// \file adv_simd.h
/// \brief Template for AdvancedProcessBlocks and SIMD processing

//    The SIMD based implementations for ciphers that use SSE, NEON and Power7
//    have a common pattern. Namely, they have a specialized implementation of
//    AdvancedProcessBlocks which processes multiple block using hardware
//    acceleration. After several implementations we noticed a lot of copy and
//    paste occurring. adv_simd.h provides a template to avoid the copy and paste.
//
//    There are 6 templates provided in this file. The number following the
//    function name, 128, is the block size in bits. The name following the
//    block size is the arrangement and acceleration. For example 4x1_SSE means
//    Intel SSE using two encrypt (or decrypt) functions: one that operates on
//    4 SIMD words, and one that operates on 1 SIMD words.
//
//      * AdvancedProcessBlocks128_4x1_SSE
//      * AdvancedProcessBlocks128_6x2_SSE
//      * AdvancedProcessBlocks128_4x1_NEON
//      * AdvancedProcessBlocks128_6x1_NEON
//      * AdvancedProcessBlocks128_4x1_ALTIVEC
//      * AdvancedProcessBlocks128_6x1_ALTIVEC
//
//    If an arrangement ends in 2, like 6x2, then the template will handle the
//    single block case by padding with 0's and using the two SIMD word
//    function. This happens at most one time when processing multiple blocks.
//    The extra processing of a zero block is trivial and worth the tradeoff.
//
//    The MAYBE_CONST macro present on x86 is a SunCC workaround. Some versions
//    of SunCC lose/drop the const-ness in the F1 and F4 functions. It eventually
//    results in a failed link due to the const/non-const mismatch.
//
//    In July 2020 the library stopped using 64-bit block version of
//    AdvancedProcessBlocks. Testing showed unreliable results and failed
//    self tests on occasion. Also see Issue 945 and
//    https://github.com/weidai11/cryptopp/commit/dd7598e638bb.

#ifndef CRYPTOPP_ADVANCED_SIMD_TEMPLATES
#define CRYPTOPP_ADVANCED_SIMD_TEMPLATES

#include "config.h"
#include "misc.h"
#include "stdcpp.h"

#if (CRYPTOPP_ARM_NEON_HEADER)
# include <arm_neon.h>
#endif

#if (CRYPTOPP_ARM_ACLE_HEADER)
# include <stdint.h>
# include <arm_acle.h>
#endif

#if (CRYPTOPP_SSE2_INTRIN_AVAILABLE)
# include <emmintrin.h>
# include <xmmintrin.h>
#endif

// SunCC needs CRYPTOPP_SSSE3_AVAILABLE, too
#if (CRYPTOPP_SSSE3_AVAILABLE)
# include <emmintrin.h>
# include <pmmintrin.h>
# include <xmmintrin.h>
#endif

#if defined(__ALTIVEC__)
# include "ppc_simd.h"
#endif

// ************************ All block ciphers *********************** //

ANONYMOUS_NAMESPACE_BEGIN

using CryptoPP::BlockTransformation;

CRYPTOPP_CONSTANT(BT_XorInput = BlockTransformation::BT_XorInput);
CRYPTOPP_CONSTANT(BT_AllowParallel = BlockTransformation::BT_AllowParallel);
CRYPTOPP_CONSTANT(BT_InBlockIsCounter = BlockTransformation::BT_InBlockIsCounter);
CRYPTOPP_CONSTANT(BT_ReverseDirection = BlockTransformation::BT_ReverseDirection);
CRYPTOPP_CONSTANT(BT_DontIncrementInOutPointers = BlockTransformation::BT_DontIncrementInOutPointers);

ANONYMOUS_NAMESPACE_END

// *************************** ARM NEON ************************** //

#if (CRYPTOPP_ARM_NEON_AVAILABLE) || (CRYPTOPP_ARM_ASIMD_AVAILABLE) || \
    defined(CRYPTOPP_DOXYGEN_PROCESSING)
NAMESPACE_BEGIN(CryptoPP)

/// \brief AdvancedProcessBlocks for 1 and 6 blocks
/// \tparam F1 function to process 1 128-bit block
/// \tparam F6 function to process 6 128-bit blocks
/// \tparam W word type of the subkey table
/// \details AdvancedProcessBlocks128_6x1_NEON processes 6 and 2 NEON SIMD words
///  at a time.
/// \details The subkey type is usually word32 or word64. F1 and F6 must use the
///  same word type.
template <typename F1, typename F6, typename W>
inline size_t AdvancedProcessBlocks128_6x1_NEON(F1 func1, F6 func6,
            const W *subKeys, size_t rounds, const byte *inBlocks,
            const byte *xorBlocks, byte *outBlocks, size_t length, word32 flags)
{
    CRYPTOPP_ASSERT(subKeys);
    CRYPTOPP_ASSERT(inBlocks);
    CRYPTOPP_ASSERT(outBlocks);
    CRYPTOPP_ASSERT(length >= 16);

    const unsigned int w_one[] = {0, 0<<24, 0, 1<<24};
    const uint32x4_t s_one = vld1q_u32(w_one);

    const size_t blockSize = 16;
    // const size_t neonBlockSize = 16;

    size_t inIncrement = (flags & (EnumToInt(BT_InBlockIsCounter)|EnumToInt(BT_DontIncrementInOutPointers))) ? 0 : blockSize;
    size_t xorIncrement = (xorBlocks != NULLPTR) ? blockSize : 0;
    size_t outIncrement = (flags & EnumToInt(BT_DontIncrementInOutPointers)) ? 0 : blockSize;

    // Clang and Coverity are generating findings using xorBlocks as a flag.
    const bool xorInput = (xorBlocks != NULLPTR) && (flags & EnumToInt(BT_XorInput));
    const bool xorOutput = (xorBlocks != NULLPTR) && !(flags & EnumToInt(BT_XorInput));

    if (flags & BT_ReverseDirection)
    {
        inBlocks = PtrAdd(inBlocks, length - blockSize);
        xorBlocks = PtrAdd(xorBlocks, length - blockSize);
        outBlocks = PtrAdd(outBlocks, length - blockSize);
        inIncrement = 0-inIncrement;
        xorIncrement = 0-xorIncrement;
        outIncrement = 0-outIncrement;
    }

    if (flags & BT_AllowParallel)
    {
        while (length >= 6*blockSize)
        {
            uint64x2_t block0, block1, block2, block3, block4, block5;
            if (flags & BT_InBlockIsCounter)
            {
                const uint64x2_t one = vreinterpretq_u64_u32(s_one);
                block0 = vreinterpretq_u64_u8(vld1q_u8(inBlocks));
                block1 = vaddq_u64(block0, one);
                block2 = vaddq_u64(block1, one);
                block3 = vaddq_u64(block2, one);
                block4 = vaddq_u64(block3, one);
                block5 = vaddq_u64(block4, one);
                vst1q_u8(const_cast<byte*>(inBlocks),
                    vreinterpretq_u8_u64(vaddq_u64(block5, one)));
            }
            else
            {
                block0 = vreinterpretq_u64_u8(vld1q_u8(inBlocks));
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block1 = vreinterpretq_u64_u8(vld1q_u8(inBlocks));
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block2 = vreinterpretq_u64_u8(vld1q_u8(inBlocks));
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block3 = vreinterpretq_u64_u8(vld1q_u8(inBlocks));
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block4 = vreinterpretq_u64_u8(vld1q_u8(inBlocks));
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block5 = vreinterpretq_u64_u8(vld1q_u8(inBlocks));
                inBlocks = PtrAdd(inBlocks, inIncrement);
            }

            if (xorInput)
            {
                block0 = veorq_u64(block0, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block1 = veorq_u64(block1, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block2 = veorq_u64(block2, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block3 = veorq_u64(block3, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block4 = veorq_u64(block4, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block5 = veorq_u64(block5, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
            }

            func6(block0, block1, block2, block3, block4, block5, subKeys, static_cast<unsigned int>(rounds));

            if (xorOutput)
            {
                block0 = veorq_u64(block0, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block1 = veorq_u64(block1, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block2 = veorq_u64(block2, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block3 = veorq_u64(block3, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block4 = veorq_u64(block4, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block5 = veorq_u64(block5, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
            }

            vst1q_u8(outBlocks, vreinterpretq_u8_u64(block0));
            outBlocks = PtrAdd(outBlocks, outIncrement);
            vst1q_u8(outBlocks, vreinterpretq_u8_u64(block1));
            outBlocks = PtrAdd(outBlocks, outIncrement);
            vst1q_u8(outBlocks, vreinterpretq_u8_u64(block2));
            outBlocks = PtrAdd(outBlocks, outIncrement);
            vst1q_u8(outBlocks, vreinterpretq_u8_u64(block3));
            outBlocks = PtrAdd(outBlocks, outIncrement);
            vst1q_u8(outBlocks, vreinterpretq_u8_u64(block4));
            outBlocks = PtrAdd(outBlocks, outIncrement);
            vst1q_u8(outBlocks, vreinterpretq_u8_u64(block5));
            outBlocks = PtrAdd(outBlocks, outIncrement);

            length -= 6*blockSize;
        }
    }

    while (length >= blockSize)
    {
        uint64x2_t block;
        block = vreinterpretq_u64_u8(vld1q_u8(inBlocks));

        if (xorInput)
            block = veorq_u64(block, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));

        if (flags & BT_InBlockIsCounter)
            const_cast<byte *>(inBlocks)[15]++;

        func1(block, subKeys, static_cast<unsigned int>(rounds));

        if (xorOutput)
            block = veorq_u64(block, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));

        vst1q_u8(outBlocks, vreinterpretq_u8_u64(block));

        inBlocks = PtrAdd(inBlocks, inIncrement);
        outBlocks = PtrAdd(outBlocks, outIncrement);
        xorBlocks = PtrAdd(xorBlocks, xorIncrement);
        length -= blockSize;
    }

    return length;
}

/// \brief AdvancedProcessBlocks for 1 and 4 blocks
/// \tparam F1 function to process 1 128-bit block
/// \tparam F4 function to process 4 128-bit blocks
/// \tparam W word type of the subkey table
/// \details AdvancedProcessBlocks128_4x1_NEON processes 4 and 1 NEON SIMD words
///  at a time.
/// \details The subkey type is usually word32 or word64. V is the vector type and it is
///  usually uint32x4_t or uint32x4_t. F1, F4, and W must use the same word and
///  vector type.
template <typename F1, typename F4, typename W>
inline size_t AdvancedProcessBlocks128_4x1_NEON(F1 func1, F4 func4,
            const W *subKeys, size_t rounds, const byte *inBlocks,
            const byte *xorBlocks, byte *outBlocks, size_t length, word32 flags)
{
    CRYPTOPP_ASSERT(subKeys);
    CRYPTOPP_ASSERT(inBlocks);
    CRYPTOPP_ASSERT(outBlocks);
    CRYPTOPP_ASSERT(length >= 16);

    const unsigned int w_one[] = {0, 0<<24, 0, 1<<24};
    const uint32x4_t s_one = vld1q_u32(w_one);

    const size_t blockSize = 16;
    // const size_t neonBlockSize = 16;

    size_t inIncrement = (flags & (EnumToInt(BT_InBlockIsCounter)|EnumToInt(BT_DontIncrementInOutPointers))) ? 0 : blockSize;
    size_t xorIncrement = (xorBlocks != NULLPTR) ? blockSize : 0;
    size_t outIncrement = (flags & EnumToInt(BT_DontIncrementInOutPointers)) ? 0 : blockSize;

    // Clang and Coverity are generating findings using xorBlocks as a flag.
    const bool xorInput = (xorBlocks != NULLPTR) && (flags & EnumToInt(BT_XorInput));
    const bool xorOutput = (xorBlocks != NULLPTR) && !(flags & EnumToInt(BT_XorInput));

    if (flags & BT_ReverseDirection)
    {
        inBlocks = PtrAdd(inBlocks, length - blockSize);
        xorBlocks = PtrAdd(xorBlocks, length - blockSize);
        outBlocks = PtrAdd(outBlocks, length - blockSize);
        inIncrement = 0-inIncrement;
        xorIncrement = 0-xorIncrement;
        outIncrement = 0-outIncrement;
    }

    if (flags & BT_AllowParallel)
    {
        while (length >= 4*blockSize)
        {
            uint32x4_t block0, block1, block2, block3;
            if (flags & BT_InBlockIsCounter)
            {
                const uint32x4_t one = s_one;
                block0 = vreinterpretq_u32_u8(vld1q_u8(inBlocks));
                block1 = vreinterpretq_u32_u64(vaddq_u64(vreinterpretq_u64_u32(block0), vreinterpretq_u64_u32(one)));
                block2 = vreinterpretq_u32_u64(vaddq_u64(vreinterpretq_u64_u32(block1), vreinterpretq_u64_u32(one)));
                block3 = vreinterpretq_u32_u64(vaddq_u64(vreinterpretq_u64_u32(block2), vreinterpretq_u64_u32(one)));
                vst1q_u8(const_cast<byte*>(inBlocks), vreinterpretq_u8_u64(vaddq_u64(
                    vreinterpretq_u64_u32(block3), vreinterpretq_u64_u32(one))));
            }
            else
            {
                block0 = vreinterpretq_u32_u8(vld1q_u8(inBlocks));
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block1 = vreinterpretq_u32_u8(vld1q_u8(inBlocks));
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block2 = vreinterpretq_u32_u8(vld1q_u8(inBlocks));
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block3 = vreinterpretq_u32_u8(vld1q_u8(inBlocks));
                inBlocks = PtrAdd(inBlocks, inIncrement);
            }

            if (xorInput)
            {
                block0 = veorq_u32(block0, vreinterpretq_u32_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block1 = veorq_u32(block1, vreinterpretq_u32_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block2 = veorq_u32(block2, vreinterpretq_u32_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block3 = veorq_u32(block3, vreinterpretq_u32_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
            }

            func4(block0, block1, block2, block3, subKeys, static_cast<unsigned int>(rounds));

            if (xorOutput)
            {
                block0 = veorq_u32(block0, vreinterpretq_u32_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block1 = veorq_u32(block1, vreinterpretq_u32_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block2 = veorq_u32(block2, vreinterpretq_u32_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block3 = veorq_u32(block3, vreinterpretq_u32_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
            }

            vst1q_u8(outBlocks, vreinterpretq_u8_u32(block0));
            outBlocks = PtrAdd(outBlocks, outIncrement);
            vst1q_u8(outBlocks, vreinterpretq_u8_u32(block1));
            outBlocks = PtrAdd(outBlocks, outIncrement);
            vst1q_u8(outBlocks, vreinterpretq_u8_u32(block2));
            outBlocks = PtrAdd(outBlocks, outIncrement);
            vst1q_u8(outBlocks, vreinterpretq_u8_u32(block3));
            outBlocks = PtrAdd(outBlocks, outIncrement);

            length -= 4*blockSize;
        }
    }

    while (length >= blockSize)
    {
        uint32x4_t block = vreinterpretq_u32_u8(vld1q_u8(inBlocks));

        if (xorInput)
            block = veorq_u32(block, vreinterpretq_u32_u8(vld1q_u8(xorBlocks)));

        if (flags & BT_InBlockIsCounter)
            const_cast<byte *>(inBlocks)[15]++;

        func1(block, subKeys, static_cast<unsigned int>(rounds));

        if (xorOutput)
            block = veorq_u32(block, vreinterpretq_u32_u8(vld1q_u8(xorBlocks)));

        vst1q_u8(outBlocks, vreinterpretq_u8_u32(block));

        inBlocks = PtrAdd(inBlocks, inIncrement);
        outBlocks = PtrAdd(outBlocks, outIncrement);
        xorBlocks = PtrAdd(xorBlocks, xorIncrement);
        length -= blockSize;
    }

    return length;
}

/// \brief AdvancedProcessBlocks for 2 and 6 blocks
/// \tparam F2 function to process 2 128-bit blocks
/// \tparam F6 function to process 6 128-bit blocks
/// \tparam W word type of the subkey table
/// \details AdvancedProcessBlocks128_6x2_NEON processes 6 and 2 NEON SIMD words
///  at a time. For a single block the template uses F2 with a zero block.
/// \details The subkey type is usually word32 or word64. F2 and F6 must use the
///  same word type.
template <typename F2, typename F6, typename W>
inline size_t AdvancedProcessBlocks128_6x2_NEON(F2 func2, F6 func6,
            const W *subKeys, size_t rounds, const byte *inBlocks,
            const byte *xorBlocks, byte *outBlocks, size_t length, word32 flags)
{
    CRYPTOPP_ASSERT(subKeys);
    CRYPTOPP_ASSERT(inBlocks);
    CRYPTOPP_ASSERT(outBlocks);
    CRYPTOPP_ASSERT(length >= 16);

    const unsigned int w_one[] = {0, 0<<24, 0, 1<<24};
    const uint32x4_t s_one = vld1q_u32(w_one);

    const size_t blockSize = 16;
    // const size_t neonBlockSize = 16;

    size_t inIncrement = (flags & (EnumToInt(BT_InBlockIsCounter)|EnumToInt(BT_DontIncrementInOutPointers))) ? 0 : blockSize;
    size_t xorIncrement = (xorBlocks != NULLPTR) ? blockSize : 0;
    size_t outIncrement = (flags & EnumToInt(BT_DontIncrementInOutPointers)) ? 0 : blockSize;

    // Clang and Coverity are generating findings using xorBlocks as a flag.
    const bool xorInput = (xorBlocks != NULLPTR) && (flags & EnumToInt(BT_XorInput));
    const bool xorOutput = (xorBlocks != NULLPTR) && !(flags & EnumToInt(BT_XorInput));

    if (flags & BT_ReverseDirection)
    {
        inBlocks = PtrAdd(inBlocks, length - blockSize);
        xorBlocks = PtrAdd(xorBlocks, length - blockSize);
        outBlocks = PtrAdd(outBlocks, length - blockSize);
        inIncrement = 0-inIncrement;
        xorIncrement = 0-xorIncrement;
        outIncrement = 0-outIncrement;
    }

    if (flags & BT_AllowParallel)
    {
        while (length >= 6*blockSize)
        {
            uint64x2_t block0, block1, block2, block3, block4, block5;
            if (flags & BT_InBlockIsCounter)
            {
                const uint64x2_t one = vreinterpretq_u64_u32(s_one);
                block0 = vreinterpretq_u64_u8(vld1q_u8(inBlocks));
                block1 = vaddq_u64(block0, one);
                block2 = vaddq_u64(block1, one);
                block3 = vaddq_u64(block2, one);
                block4 = vaddq_u64(block3, one);
                block5 = vaddq_u64(block4, one);
                vst1q_u8(const_cast<byte*>(inBlocks),
                    vreinterpretq_u8_u64(vaddq_u64(block5, one)));
            }
            else
            {
                block0 = vreinterpretq_u64_u8(vld1q_u8(inBlocks));
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block1 = vreinterpretq_u64_u8(vld1q_u8(inBlocks));
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block2 = vreinterpretq_u64_u8(vld1q_u8(inBlocks));
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block3 = vreinterpretq_u64_u8(vld1q_u8(inBlocks));
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block4 = vreinterpretq_u64_u8(vld1q_u8(inBlocks));
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block5 = vreinterpretq_u64_u8(vld1q_u8(inBlocks));
                inBlocks = PtrAdd(inBlocks, inIncrement);
            }

            if (xorInput)
            {
                block0 = veorq_u64(block0, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block1 = veorq_u64(block1, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block2 = veorq_u64(block2, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block3 = veorq_u64(block3, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block4 = veorq_u64(block4, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block5 = veorq_u64(block5, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
            }

            func6(block0, block1, block2, block3, block4, block5, subKeys, static_cast<unsigned int>(rounds));

            if (xorOutput)
            {
                block0 = veorq_u64(block0, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block1 = veorq_u64(block1, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block2 = veorq_u64(block2, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block3 = veorq_u64(block3, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block4 = veorq_u64(block4, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block5 = veorq_u64(block5, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
            }

            vst1q_u8(outBlocks, vreinterpretq_u8_u64(block0));
            outBlocks = PtrAdd(outBlocks, outIncrement);
            vst1q_u8(outBlocks, vreinterpretq_u8_u64(block1));
            outBlocks = PtrAdd(outBlocks, outIncrement);
            vst1q_u8(outBlocks, vreinterpretq_u8_u64(block2));
            outBlocks = PtrAdd(outBlocks, outIncrement);
            vst1q_u8(outBlocks, vreinterpretq_u8_u64(block3));
            outBlocks = PtrAdd(outBlocks, outIncrement);
            vst1q_u8(outBlocks, vreinterpretq_u8_u64(block4));
            outBlocks = PtrAdd(outBlocks, outIncrement);
            vst1q_u8(outBlocks, vreinterpretq_u8_u64(block5));
            outBlocks = PtrAdd(outBlocks, outIncrement);

            length -= 6*blockSize;
        }

        while (length >= 2*blockSize)
        {
            uint64x2_t block0, block1;
            if (flags & BT_InBlockIsCounter)
            {
                const uint64x2_t one = vreinterpretq_u64_u32(s_one);
                block0 = vreinterpretq_u64_u8(vld1q_u8(inBlocks));
                block1 = vaddq_u64(block0, one);
                vst1q_u8(const_cast<byte*>(inBlocks),
                    vreinterpretq_u8_u64(vaddq_u64(block1, one)));
            }
            else
            {
                block0 = vreinterpretq_u64_u8(vld1q_u8(inBlocks));
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block1 = vreinterpretq_u64_u8(vld1q_u8(inBlocks));
                inBlocks = PtrAdd(inBlocks, inIncrement);
            }

            if (xorInput)
            {
                block0 = veorq_u64(block0, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block1 = veorq_u64(block1, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
            }

            func2(block0, block1, subKeys, static_cast<unsigned int>(rounds));

            if (xorOutput)
            {
                block0 = veorq_u64(block0, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block1 = veorq_u64(block1, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
            }

            vst1q_u8(outBlocks, vreinterpretq_u8_u64(block0));
            outBlocks = PtrAdd(outBlocks, outIncrement);
            vst1q_u8(outBlocks, vreinterpretq_u8_u64(block1));
            outBlocks = PtrAdd(outBlocks, outIncrement);

            length -= 2*blockSize;
        }
    }

    while (length >= blockSize)
    {
        uint64x2_t block, zero = {0,0};
        block = vreinterpretq_u64_u8(vld1q_u8(inBlocks));

        if (xorInput)
            block = veorq_u64(block, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));

        if (flags & BT_InBlockIsCounter)
            const_cast<byte *>(inBlocks)[15]++;

        func2(block, zero, subKeys, static_cast<unsigned int>(rounds));

        if (xorOutput)
            block = veorq_u64(block, vreinterpretq_u64_u8(vld1q_u8(xorBlocks)));

        vst1q_u8(outBlocks, vreinterpretq_u8_u64(block));

        inBlocks = PtrAdd(inBlocks, inIncrement);
        outBlocks = PtrAdd(outBlocks, outIncrement);
        xorBlocks = PtrAdd(xorBlocks, xorIncrement);
        length -= blockSize;
    }

    return length;
}

NAMESPACE_END  // CryptoPP

#endif  // CRYPTOPP_ARM_NEON_AVAILABLE

// *************************** Intel SSE ************************** //

#if defined(CRYPTOPP_SSSE3_AVAILABLE) || defined(CRYPTOPP_DOXYGEN_PROCESSING)

#if defined(CRYPTOPP_DOXYGEN_PROCESSING)
/// \brief SunCC workaround
/// \details SunCC loses the const on AES_Enc_Block and AES_Dec_Block
/// \sa <A HREF="http://github.com/weidai11/cryptopp/issues/224">Issue
///  224, SunCC and failed compile for rijndael.cpp</A>
# define MAYBE_CONST const
/// \brief SunCC workaround
/// \details SunCC loses the const on AES_Enc_Block and AES_Dec_Block
/// \sa <A HREF="http://github.com/weidai11/cryptopp/issues/224">Issue
///  224, SunCC and failed compile for rijndael.cpp</A>
# define MAYBE_UNCONST_CAST(T, x) (x)
#elif (__SUNPRO_CC >= 0x5130)
# define MAYBE_CONST
# define MAYBE_UNCONST_CAST(T, x) const_cast<MAYBE_CONST T>(x)
#else
# define MAYBE_CONST const
# define MAYBE_UNCONST_CAST(T, x) (x)
#endif

#if defined(CRYPTOPP_DOXYGEN_PROCESSING)
/// \brief Clang workaround
/// \details Clang issues spurious alignment warnings
/// \sa <A HREF="http://bugs.llvm.org/show_bug.cgi?id=20670">Issue
///  20670, _mm_loadu_si128 parameter has wrong type</A>
# define M128_CAST(x) ((__m128i *)(void *)(x))
/// \brief Clang workaround
/// \details Clang issues spurious alignment warnings
/// \sa <A HREF="http://bugs.llvm.org/show_bug.cgi?id=20670">Issue
///  20670, _mm_loadu_si128 parameter has wrong type</A>
# define CONST_M128_CAST(x) ((const __m128i *)(const void *)(x))
#else
# ifndef M128_CAST
#  define M128_CAST(x) ((__m128i *)(void *)(x))
# endif
# ifndef CONST_M128_CAST
#  define CONST_M128_CAST(x) ((const __m128i *)(const void *)(x))
# endif
#endif

NAMESPACE_BEGIN(CryptoPP)

/// \brief AdvancedProcessBlocks for 2 and 6 blocks
/// \tparam F2 function to process 2 128-bit blocks
/// \tparam F6 function to process 6 128-bit blocks
/// \tparam W word type of the subkey table
/// \details AdvancedProcessBlocks128_6x2_SSE processes 6 and 2 SSE SIMD words
///  at a time. For a single block the template uses F2 with a zero block.
/// \details The subkey type is usually word32 or word64. F2 and F6 must use the
///  same word type.
template <typename F2, typename F6, typename W>
inline size_t AdvancedProcessBlocks128_6x2_SSE(F2 func2, F6 func6,
        MAYBE_CONST W *subKeys, size_t rounds, const byte *inBlocks,
        const byte *xorBlocks, byte *outBlocks, size_t length, word32 flags)
{
    CRYPTOPP_ASSERT(subKeys);
    CRYPTOPP_ASSERT(inBlocks);
    CRYPTOPP_ASSERT(outBlocks);
    CRYPTOPP_ASSERT(length >= 16);

    const size_t blockSize = 16;
    // const size_t xmmBlockSize = 16;

    size_t inIncrement = (flags & (EnumToInt(BT_InBlockIsCounter)|EnumToInt(BT_DontIncrementInOutPointers))) ? 0 : blockSize;
    size_t xorIncrement = (xorBlocks != NULLPTR) ? blockSize : 0;
    size_t outIncrement = (flags & EnumToInt(BT_DontIncrementInOutPointers)) ? 0 : blockSize;

    // Clang and Coverity are generating findings using xorBlocks as a flag.
    const bool xorInput = (xorBlocks != NULLPTR) && (flags & EnumToInt(BT_XorInput));
    const bool xorOutput = (xorBlocks != NULLPTR) && !(flags & EnumToInt(BT_XorInput));

    if (flags & BT_ReverseDirection)
    {
        inBlocks = PtrAdd(inBlocks, length - blockSize);
        xorBlocks = PtrAdd(xorBlocks, length - blockSize);
        outBlocks = PtrAdd(outBlocks, length - blockSize);
        inIncrement = 0-inIncrement;
        xorIncrement = 0-xorIncrement;
        outIncrement = 0-outIncrement;
    }

    if (flags & BT_AllowParallel)
    {
        while (length >= 6*blockSize)
        {
            __m128i block0, block1, block2, block3, block4, block5;
            if (flags & BT_InBlockIsCounter)
            {
                // Increment of 1 in big-endian compatible with the ctr byte array.
                const __m128i s_one = _mm_set_epi32(1<<24, 0, 0, 0);
                block0 = _mm_loadu_si128(CONST_M128_CAST(inBlocks));
                block1 = _mm_add_epi32(block0, s_one);
                block2 = _mm_add_epi32(block1, s_one);
                block3 = _mm_add_epi32(block2, s_one);
                block4 = _mm_add_epi32(block3, s_one);
                block5 = _mm_add_epi32(block4, s_one);
                _mm_storeu_si128(M128_CAST(inBlocks), _mm_add_epi32(block5, s_one));
            }
            else
            {
                block0 = _mm_loadu_si128(CONST_M128_CAST(inBlocks));
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block1 = _mm_loadu_si128(CONST_M128_CAST(inBlocks));
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block2 = _mm_loadu_si128(CONST_M128_CAST(inBlocks));
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block3 = _mm_loadu_si128(CONST_M128_CAST(inBlocks));
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block4 = _mm_loadu_si128(CONST_M128_CAST(inBlocks));
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block5 = _mm_loadu_si128(CONST_M128_CAST(inBlocks));
                inBlocks = PtrAdd(inBlocks, inIncrement);
            }

            if (xorInput)
            {
                block0 = _mm_xor_si128(block0, _mm_loadu_si128(CONST_M128_CAST(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block1 = _mm_xor_si128(block1, _mm_loadu_si128(CONST_M128_CAST(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block2 = _mm_xor_si128(block2, _mm_loadu_si128(CONST_M128_CAST(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block3 = _mm_xor_si128(block3, _mm_loadu_si128(CONST_M128_CAST(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block4 = _mm_xor_si128(block4, _mm_loadu_si128(CONST_M128_CAST(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block5 = _mm_xor_si128(block5, _mm_loadu_si128(CONST_M128_CAST(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
            }

            func6(block0, block1, block2, block3, block4, block5, subKeys, static_cast<unsigned int>(rounds));

            if (xorOutput)
            {
                block0 = _mm_xor_si128(block0, _mm_loadu_si128(CONST_M128_CAST(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block1 = _mm_xor_si128(block1, _mm_loadu_si128(CONST_M128_CAST(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block2 = _mm_xor_si128(block2, _mm_loadu_si128(CONST_M128_CAST(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block3 = _mm_xor_si128(block3, _mm_loadu_si128(CONST_M128_CAST(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block4 = _mm_xor_si128(block4, _mm_loadu_si128(CONST_M128_CAST(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block5 = _mm_xor_si128(block5, _mm_loadu_si128(CONST_M128_CAST(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
            }

            _mm_storeu_si128(M128_CAST(outBlocks), block0);
            outBlocks = PtrAdd(outBlocks, outIncrement);
            _mm_storeu_si128(M128_CAST(outBlocks), block1);
            outBlocks = PtrAdd(outBlocks, outIncrement);
            _mm_storeu_si128(M128_CAST(outBlocks), block2);
            outBlocks = PtrAdd(outBlocks, outIncrement);
            _mm_storeu_si128(M128_CAST(outBlocks), block3);
            outBlocks = PtrAdd(outBlocks, outIncrement);
            _mm_storeu_si128(M128_CAST(outBlocks), block4);
            outBlocks = PtrAdd(outBlocks, outIncrement);
            _mm_storeu_si128(M128_CAST(outBlocks), block5);
            outBlocks = PtrAdd(outBlocks, outIncrement);

            length -= 6*blockSize;
        }

        while (length >= 2*blockSize)
        {
            __m128i block0, block1;
            if (flags & BT_InBlockIsCounter)
            {
                // Increment of 1 in big-endian compatible with the ctr byte array.
                const __m128i s_one = _mm_set_epi32(1<<24, 0, 0, 0);
                block0 = _mm_loadu_si128(CONST_M128_CAST(inBlocks));
                block1 = _mm_add_epi32(block0, s_one);
                _mm_storeu_si128(M128_CAST(inBlocks), _mm_add_epi32(block1, s_one));
            }
            else
            {
                block0 = _mm_loadu_si128(CONST_M128_CAST(inBlocks));
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block1 = _mm_loadu_si128(CONST_M128_CAST(inBlocks));
                inBlocks = PtrAdd(inBlocks, inIncrement);
            }

            if (xorInput)
            {
                block0 = _mm_xor_si128(block0, _mm_loadu_si128(CONST_M128_CAST(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block1 = _mm_xor_si128(block1, _mm_loadu_si128(CONST_M128_CAST(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
            }

            func2(block0, block1, subKeys, static_cast<unsigned int>(rounds));

            if (xorOutput)
            {
                block0 = _mm_xor_si128(block0, _mm_loadu_si128(CONST_M128_CAST(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block1 = _mm_xor_si128(block1, _mm_loadu_si128(CONST_M128_CAST(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
            }

            _mm_storeu_si128(M128_CAST(outBlocks), block0);
            outBlocks = PtrAdd(outBlocks, outIncrement);
            _mm_storeu_si128(M128_CAST(outBlocks), block1);
            outBlocks = PtrAdd(outBlocks, outIncrement);

            length -= 2*blockSize;
        }
    }

    while (length >= blockSize)
    {
        __m128i block, zero = _mm_setzero_si128();
        block = _mm_loadu_si128(CONST_M128_CAST(inBlocks));

        if (xorInput)
            block = _mm_xor_si128(block, _mm_loadu_si128(CONST_M128_CAST(xorBlocks)));

        if (flags & BT_InBlockIsCounter)
            const_cast<byte *>(inBlocks)[15]++;

        func2(block, zero, subKeys, static_cast<unsigned int>(rounds));

        if (xorOutput)
            block = _mm_xor_si128(block, _mm_loadu_si128(CONST_M128_CAST(xorBlocks)));

        _mm_storeu_si128(M128_CAST(outBlocks), block);

        inBlocks = PtrAdd(inBlocks, inIncrement);
        outBlocks = PtrAdd(outBlocks, outIncrement);
        xorBlocks = PtrAdd(xorBlocks, xorIncrement);
        length -= blockSize;
    }

    return length;
}

/// \brief AdvancedProcessBlocks for 1 and 4 blocks
/// \tparam F1 function to process 1 128-bit block
/// \tparam F4 function to process 4 128-bit blocks
/// \tparam W word type of the subkey table
/// \details AdvancedProcessBlocks128_4x1_SSE processes 4 and 1 SSE SIMD words
///  at a time.
/// \details The subkey type is usually word32 or word64. F1 and F4 must use the
///  same word type.
template <typename F1, typename F4, typename W>
inline size_t AdvancedProcessBlocks128_4x1_SSE(F1 func1, F4 func4,
        MAYBE_CONST W *subKeys, size_t rounds, const byte *inBlocks,
        const byte *xorBlocks, byte *outBlocks, size_t length, word32 flags)
{
    CRYPTOPP_ASSERT(subKeys);
    CRYPTOPP_ASSERT(inBlocks);
    CRYPTOPP_ASSERT(outBlocks);
    CRYPTOPP_ASSERT(length >= 16);

    const size_t blockSize = 16;
    // const size_t xmmBlockSize = 16;

    size_t inIncrement = (flags & (EnumToInt(BT_InBlockIsCounter)|EnumToInt(BT_DontIncrementInOutPointers))) ? 0 : blockSize;
    size_t xorIncrement = (xorBlocks != NULLPTR) ? blockSize : 0;
    size_t outIncrement = (flags & EnumToInt(BT_DontIncrementInOutPointers)) ? 0 : blockSize;

    // Clang and Coverity are generating findings using xorBlocks as a flag.
    const bool xorInput = (xorBlocks != NULLPTR) && (flags & EnumToInt(BT_XorInput));
    const bool xorOutput = (xorBlocks != NULLPTR) && !(flags & EnumToInt(BT_XorInput));

    if (flags & BT_ReverseDirection)
    {
        inBlocks = PtrAdd(inBlocks, length - blockSize);
        xorBlocks = PtrAdd(xorBlocks, length - blockSize);
        outBlocks = PtrAdd(outBlocks, length - blockSize);
        inIncrement = 0-inIncrement;
        xorIncrement = 0-xorIncrement;
        outIncrement = 0-outIncrement;
    }

    if (flags & BT_AllowParallel)
    {
        while (length >= 4*blockSize)
        {
            __m128i block0, block1, block2, block3;
            if (flags & BT_InBlockIsCounter)
            {
                // Increment of 1 in big-endian compatible with the ctr byte array.
                const __m128i s_one = _mm_set_epi32(1<<24, 0, 0, 0);
                block0 = _mm_loadu_si128(CONST_M128_CAST(inBlocks));
                block1 = _mm_add_epi32(block0, s_one);
                block2 = _mm_add_epi32(block1, s_one);
                block3 = _mm_add_epi32(block2, s_one);
                _mm_storeu_si128(M128_CAST(inBlocks), _mm_add_epi32(block3, s_one));
            }
            else
            {
                block0 = _mm_loadu_si128(CONST_M128_CAST(inBlocks));
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block1 = _mm_loadu_si128(CONST_M128_CAST(inBlocks));
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block2 = _mm_loadu_si128(CONST_M128_CAST(inBlocks));
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block3 = _mm_loadu_si128(CONST_M128_CAST(inBlocks));
                inBlocks = PtrAdd(inBlocks, inIncrement);
            }

            if (xorInput)
            {
                block0 = _mm_xor_si128(block0, _mm_loadu_si128(CONST_M128_CAST(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block1 = _mm_xor_si128(block1, _mm_loadu_si128(CONST_M128_CAST(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block2 = _mm_xor_si128(block2, _mm_loadu_si128(CONST_M128_CAST(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block3 = _mm_xor_si128(block3, _mm_loadu_si128(CONST_M128_CAST(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
            }

            func4(block0, block1, block2, block3, subKeys, static_cast<unsigned int>(rounds));

            if (xorOutput)
            {
                block0 = _mm_xor_si128(block0, _mm_loadu_si128(CONST_M128_CAST(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block1 = _mm_xor_si128(block1, _mm_loadu_si128(CONST_M128_CAST(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block2 = _mm_xor_si128(block2, _mm_loadu_si128(CONST_M128_CAST(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block3 = _mm_xor_si128(block3, _mm_loadu_si128(CONST_M128_CAST(xorBlocks)));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
            }

            _mm_storeu_si128(M128_CAST(outBlocks), block0);
            outBlocks = PtrAdd(outBlocks, outIncrement);
            _mm_storeu_si128(M128_CAST(outBlocks), block1);
            outBlocks = PtrAdd(outBlocks, outIncrement);
            _mm_storeu_si128(M128_CAST(outBlocks), block2);
            outBlocks = PtrAdd(outBlocks, outIncrement);
            _mm_storeu_si128(M128_CAST(outBlocks), block3);
            outBlocks = PtrAdd(outBlocks, outIncrement);

            length -= 4*blockSize;
        }
    }

    while (length >= blockSize)
    {
        __m128i block = _mm_loadu_si128(CONST_M128_CAST(inBlocks));

        if (xorInput)
            block = _mm_xor_si128(block, _mm_loadu_si128(CONST_M128_CAST(xorBlocks)));

        if (flags & BT_InBlockIsCounter)
            const_cast<byte *>(inBlocks)[15]++;

        func1(block, subKeys, static_cast<unsigned int>(rounds));

        if (xorOutput)
            block = _mm_xor_si128(block, _mm_loadu_si128(CONST_M128_CAST(xorBlocks)));

        _mm_storeu_si128(M128_CAST(outBlocks), block);

        inBlocks = PtrAdd(inBlocks, inIncrement);
        outBlocks = PtrAdd(outBlocks, outIncrement);
        xorBlocks = PtrAdd(xorBlocks, xorIncrement);
        length -= blockSize;
    }

    return length;
}

NAMESPACE_END  // CryptoPP

#endif  // CRYPTOPP_SSSE3_AVAILABLE

// ************************** Altivec/Power 4 ************************** //

#if defined(__ALTIVEC__) || defined(CRYPTOPP_DOXYGEN_PROCESSING)

NAMESPACE_BEGIN(CryptoPP)

/// \brief AdvancedProcessBlocks for 1 and 4 blocks
/// \tparam F1 function to process 1 128-bit block
/// \tparam F4 function to process 4 128-bit blocks
/// \tparam W word type of the subkey table
/// \details AdvancedProcessBlocks128_4x1_ALTIVEC processes 4 and 1 Altivec SIMD words
///  at a time.
/// \details The subkey type is usually word32 or word64. F1 and F4 must use the
///  same word type.
template <typename F1, typename F4, typename W>
inline size_t AdvancedProcessBlocks128_4x1_ALTIVEC(F1 func1, F4 func4,
        const W *subKeys, size_t rounds, const byte *inBlocks,
        const byte *xorBlocks, byte *outBlocks, size_t length, word32 flags)
{
    CRYPTOPP_ASSERT(subKeys);
    CRYPTOPP_ASSERT(inBlocks);
    CRYPTOPP_ASSERT(outBlocks);
    CRYPTOPP_ASSERT(length >= 16);

#if (CRYPTOPP_LITTLE_ENDIAN)
    const uint32x4_p s_one  = {1,0,0,0};
#else
    const uint32x4_p s_one = {0,0,0,1};
#endif

    const size_t blockSize = 16;
    // const size_t simdBlockSize = 16;

    size_t inIncrement = (flags & (EnumToInt(BT_InBlockIsCounter)|EnumToInt(BT_DontIncrementInOutPointers))) ? 0 : blockSize;
    size_t xorIncrement = (xorBlocks != NULLPTR) ? blockSize : 0;
    size_t outIncrement = (flags & EnumToInt(BT_DontIncrementInOutPointers)) ? 0 : blockSize;

    // Clang and Coverity are generating findings using xorBlocks as a flag.
    const bool xorInput = (xorBlocks != NULLPTR) && (flags & EnumToInt(BT_XorInput));
    const bool xorOutput = (xorBlocks != NULLPTR) && !(flags & EnumToInt(BT_XorInput));

    if (flags & BT_ReverseDirection)
    {
        inBlocks = PtrAdd(inBlocks, length - blockSize);
        xorBlocks = PtrAdd(xorBlocks, length - blockSize);
        outBlocks = PtrAdd(outBlocks, length - blockSize);
        inIncrement = 0-inIncrement;
        xorIncrement = 0-xorIncrement;
        outIncrement = 0-outIncrement;
    }

    if (flags & BT_AllowParallel)
    {
        while (length >= 4*blockSize)
        {
            uint32x4_p block0, block1, block2, block3;

            if (flags & BT_InBlockIsCounter)
            {
                block0 = VecLoadBE(inBlocks);
                block1 = VecAdd(block0, s_one);
                block2 = VecAdd(block1, s_one);
                block3 = VecAdd(block2, s_one);

                // Hack due to big-endian loads used by POWER8 (and maybe ARM-BE).
                // CTR_ModePolicy::OperateKeystream is wired such that after
                // returning from this function CTR_ModePolicy will detect wrap on
                // on the last counter byte and increment the next to last byte.
                // The problem is, with a big-endian load, inBlocks[15] is really
                // located at index 15. The vector addition using a 32-bit element
                // generates a carry into inBlocks[14] and then CTR_ModePolicy
                // increments inBlocks[14] too.
                const_cast<byte*>(inBlocks)[15] += 6;
            }
            else
            {
                block0 = VecLoadBE(inBlocks);
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block1 = VecLoadBE(inBlocks);
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block2 = VecLoadBE(inBlocks);
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block3 = VecLoadBE(inBlocks);
                inBlocks = PtrAdd(inBlocks, inIncrement);
            }

            if (xorInput)
            {
                block0 = VecXor(block0, VecLoadBE(xorBlocks));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block1 = VecXor(block1, VecLoadBE(xorBlocks));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block2 = VecXor(block2, VecLoadBE(xorBlocks));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block3 = VecXor(block3, VecLoadBE(xorBlocks));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
            }

            func4(block0, block1, block2, block3, subKeys, rounds);

            if (xorOutput)
            {
                block0 = VecXor(block0, VecLoadBE(xorBlocks));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block1 = VecXor(block1, VecLoadBE(xorBlocks));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block2 = VecXor(block2, VecLoadBE(xorBlocks));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block3 = VecXor(block3, VecLoadBE(xorBlocks));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
            }

            VecStoreBE(block0, outBlocks);
            outBlocks = PtrAdd(outBlocks, outIncrement);
            VecStoreBE(block1, outBlocks);
            outBlocks = PtrAdd(outBlocks, outIncrement);
            VecStoreBE(block2, outBlocks);
            outBlocks = PtrAdd(outBlocks, outIncrement);
            VecStoreBE(block3, outBlocks);
            outBlocks = PtrAdd(outBlocks, outIncrement);

            length -= 4*blockSize;
        }
    }

    while (length >= blockSize)
    {
        uint32x4_p block = VecLoadBE(inBlocks);

        if (xorInput)
            block = VecXor(block, VecLoadBE(xorBlocks));

        if (flags & BT_InBlockIsCounter)
            const_cast<byte *>(inBlocks)[15]++;

        func1(block, subKeys, rounds);

        if (xorOutput)
            block = VecXor(block, VecLoadBE(xorBlocks));

        VecStoreBE(block, outBlocks);

        inBlocks = PtrAdd(inBlocks, inIncrement);
        outBlocks = PtrAdd(outBlocks, outIncrement);
        xorBlocks = PtrAdd(xorBlocks, xorIncrement);
        length -= blockSize;
    }

    return length;
}

/// \brief AdvancedProcessBlocks for 1 and 6 blocks
/// \tparam F1 function to process 1 128-bit block
/// \tparam F6 function to process 6 128-bit blocks
/// \tparam W word type of the subkey table
/// \details AdvancedProcessBlocks128_6x1_ALTIVEC processes 6 and 1 Altivec SIMD words
///  at a time.
/// \details The subkey type is usually word32 or word64. F1 and F6 must use the
///  same word type.
template <typename F1, typename F6, typename W>
inline size_t AdvancedProcessBlocks128_6x1_ALTIVEC(F1 func1, F6 func6,
        const W *subKeys, size_t rounds, const byte *inBlocks,
        const byte *xorBlocks, byte *outBlocks, size_t length, word32 flags)
{
    CRYPTOPP_ASSERT(subKeys);
    CRYPTOPP_ASSERT(inBlocks);
    CRYPTOPP_ASSERT(outBlocks);
    CRYPTOPP_ASSERT(length >= 16);

#if (CRYPTOPP_LITTLE_ENDIAN)
    const uint32x4_p s_one  = {1,0,0,0};
#else
    const uint32x4_p s_one = {0,0,0,1};
#endif

    const size_t blockSize = 16;
    // const size_t simdBlockSize = 16;

    size_t inIncrement = (flags & (EnumToInt(BT_InBlockIsCounter)|EnumToInt(BT_DontIncrementInOutPointers))) ? 0 : blockSize;
    size_t xorIncrement = (xorBlocks != NULLPTR) ? blockSize : 0;
    size_t outIncrement = (flags & EnumToInt(BT_DontIncrementInOutPointers)) ? 0 : blockSize;

    // Clang and Coverity are generating findings using xorBlocks as a flag.
    const bool xorInput = (xorBlocks != NULLPTR) && (flags & EnumToInt(BT_XorInput));
    const bool xorOutput = (xorBlocks != NULLPTR) && !(flags & EnumToInt(BT_XorInput));

    if (flags & BT_ReverseDirection)
    {
        inBlocks = PtrAdd(inBlocks, length - blockSize);
        xorBlocks = PtrAdd(xorBlocks, length - blockSize);
        outBlocks = PtrAdd(outBlocks, length - blockSize);
        inIncrement = 0-inIncrement;
        xorIncrement = 0-xorIncrement;
        outIncrement = 0-outIncrement;
    }

    if (flags & BT_AllowParallel)
    {
        while (length >= 6*blockSize)
        {
            uint32x4_p block0, block1, block2, block3, block4, block5;

            if (flags & BT_InBlockIsCounter)
            {
                block0 = VecLoadBE(inBlocks);
                block1 = VecAdd(block0, s_one);
                block2 = VecAdd(block1, s_one);
                block3 = VecAdd(block2, s_one);
                block4 = VecAdd(block3, s_one);
                block5 = VecAdd(block4, s_one);

                // Hack due to big-endian loads used by POWER8 (and maybe ARM-BE).
                // CTR_ModePolicy::OperateKeystream is wired such that after
                // returning from this function CTR_ModePolicy will detect wrap on
                // on the last counter byte and increment the next to last byte.
                // The problem is, with a big-endian load, inBlocks[15] is really
                // located at index 15. The vector addition using a 32-bit element
                // generates a carry into inBlocks[14] and then CTR_ModePolicy
                // increments inBlocks[14] too.
                //
                // To find this bug we needed a test case with a ctr of 0xNN...FA.
                // The last octet is 0xFA and adding 6 creates the wrap to trigger
                // the issue. If the last octet was 0xFC then 4 would trigger it.
                // We dumb-lucked into the test with SPECK-128. The test case of
                // interest is the one with IV 348ECA9766C09F04 826520DE47A212FA.
                uint8x16_p temp = VecAdd((uint8x16_p)block5, (uint8x16_p)s_one);
                VecStoreBE(temp, const_cast<byte*>(inBlocks));
            }
            else
            {
                block0 = VecLoadBE(inBlocks);
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block1 = VecLoadBE(inBlocks);
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block2 = VecLoadBE(inBlocks);
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block3 = VecLoadBE(inBlocks);
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block4 = VecLoadBE(inBlocks);
                inBlocks = PtrAdd(inBlocks, inIncrement);
                block5 = VecLoadBE(inBlocks);
                inBlocks = PtrAdd(inBlocks, inIncrement);
            }

            if (xorInput)
            {
                block0 = VecXor(block0, VecLoadBE(xorBlocks));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block1 = VecXor(block1, VecLoadBE(xorBlocks));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block2 = VecXor(block2, VecLoadBE(xorBlocks));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block3 = VecXor(block3, VecLoadBE(xorBlocks));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block4 = VecXor(block4, VecLoadBE(xorBlocks));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block5 = VecXor(block5, VecLoadBE(xorBlocks));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
            }

            func6(block0, block1, block2, block3, block4, block5, subKeys, rounds);

            if (xorOutput)
            {
                block0 = VecXor(block0, VecLoadBE(xorBlocks));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block1 = VecXor(block1, VecLoadBE(xorBlocks));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block2 = VecXor(block2, VecLoadBE(xorBlocks));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block3 = VecXor(block3, VecLoadBE(xorBlocks));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block4 = VecXor(block4, VecLoadBE(xorBlocks));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
                block5 = VecXor(block5, VecLoadBE(xorBlocks));
                xorBlocks = PtrAdd(xorBlocks, xorIncrement);
            }

            VecStoreBE(block0, outBlocks);
            outBlocks = PtrAdd(outBlocks, outIncrement);
            VecStoreBE(block1, outBlocks);
            outBlocks = PtrAdd(outBlocks, outIncrement);
            VecStoreBE(block2, outBlocks);
            outBlocks = PtrAdd(outBlocks, outIncrement);
            VecStoreBE(block3, outBlocks);
            outBlocks = PtrAdd(outBlocks, outIncrement);
            VecStoreBE(block4, outBlocks);
            outBlocks = PtrAdd(outBlocks, outIncrement);
            VecStoreBE(block5, outBlocks);
            outBlocks = PtrAdd(outBlocks, outIncrement);

            length -= 6*blockSize;
        }
    }

    while (length >= blockSize)
    {
        uint32x4_p block = VecLoadBE(inBlocks);

        if (xorInput)
            block = VecXor(block, VecLoadBE(xorBlocks));

        if (flags & BT_InBlockIsCounter)
            const_cast<byte *>(inBlocks)[15]++;

        func1(block, subKeys, rounds);

        if (xorOutput)
            block = VecXor(block, VecLoadBE(xorBlocks));

        VecStoreBE(block, outBlocks);

        inBlocks = PtrAdd(inBlocks, inIncrement);
        outBlocks = PtrAdd(outBlocks, outIncrement);
        xorBlocks = PtrAdd(xorBlocks, xorIncrement);
        length -= blockSize;
    }

    return length;
}

NAMESPACE_END  // CryptoPP

#endif  // __ALTIVEC__

#endif  // CRYPTOPP_ADVANCED_SIMD_TEMPLATES
