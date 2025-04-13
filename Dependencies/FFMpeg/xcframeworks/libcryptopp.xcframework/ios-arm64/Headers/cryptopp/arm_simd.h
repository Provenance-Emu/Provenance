// arm_simd.h - written and placed in public domain by Jeffrey Walton

/// \file arm_simd.h
/// \brief Support functions for ARM and vector operations

#ifndef CRYPTOPP_ARM_SIMD_H
#define CRYPTOPP_ARM_SIMD_H

#include "config.h"

#if (CRYPTOPP_ARM_NEON_HEADER)
# include <stdint.h>
# include <arm_neon.h>
#endif

#if (CRYPTOPP_ARM_ACLE_HEADER)
# include <stdint.h>
# include <arm_acle.h>
#endif

#if (CRYPTOPP_ARM_CRC32_AVAILABLE) || defined(CRYPTOPP_DOXYGEN_PROCESSING)
///	\name CRC32 checksum
//@{

/// \brief CRC32 checksum
/// \param crc the starting crc value
/// \param val the value to checksum
/// \return CRC32 value
/// \since Crypto++ 8.6
inline uint32_t CRC32B (uint32_t crc, uint8_t val)
{
#if defined(CRYPTOPP_MSC_VERSION)
	return __crc32b(crc, val);
#else
    __asm__ ("crc32b   %w0, %w0, %w1   \n\t"
            :"+r" (crc) : "r" (val) );
    return crc;
#endif
}

/// \brief CRC32 checksum
/// \param crc the starting crc value
/// \param val the value to checksum
/// \return CRC32 value
/// \since Crypto++ 8.6
inline uint32_t CRC32W (uint32_t crc, uint32_t val)
{
#if defined(CRYPTOPP_MSC_VERSION)
	return __crc32w(crc, val);
#else
    __asm__ ("crc32w   %w0, %w0, %w1   \n\t"
            :"+r" (crc) : "r" (val) );
    return crc;
#endif
}

/// \brief CRC32 checksum
/// \param crc the starting crc value
/// \param vals the values to checksum
/// \return CRC32 value
/// \since Crypto++ 8.6
inline uint32_t CRC32Wx4 (uint32_t crc, const uint32_t vals[4])
{
#if defined(CRYPTOPP_MSC_VERSION)
	return __crc32w(__crc32w(__crc32w(__crc32w(
             crc, vals[0]), vals[1]), vals[2]), vals[3]);
#else
    __asm__ ("crc32w   %w0, %w0, %w1   \n\t"
             "crc32w   %w0, %w0, %w2   \n\t"
             "crc32w   %w0, %w0, %w3   \n\t"
             "crc32w   %w0, %w0, %w4   \n\t"
            :"+r" (crc) : "r" (vals[0]), "r" (vals[1]),
                          "r" (vals[2]), "r" (vals[3]));
    return crc;
#endif
}

//@}
///	\name CRC32-C checksum

/// \brief CRC32-C checksum
/// \param crc the starting crc value
/// \param val the value to checksum
/// \return CRC32-C value
/// \since Crypto++ 8.6
inline uint32_t CRC32CB (uint32_t crc, uint8_t val)
{
#if defined(CRYPTOPP_MSC_VERSION)
	return __crc32cb(crc, val);
#else
    __asm__ ("crc32cb   %w0, %w0, %w1   \n\t"
            :"+r" (crc) : "r" (val) );
    return crc;
#endif
}

/// \brief CRC32-C checksum
/// \param crc the starting crc value
/// \param val the value to checksum
/// \return CRC32-C value
/// \since Crypto++ 8.6
inline uint32_t CRC32CW (uint32_t crc, uint32_t val)
{
#if defined(CRYPTOPP_MSC_VERSION)
	return __crc32cw(crc, val);
#else
    __asm__ ("crc32cw   %w0, %w0, %w1   \n\t"
            :"+r" (crc) : "r" (val) );
    return crc;
#endif
}

/// \brief CRC32-C checksum
/// \param crc the starting crc value
/// \param vals the values to checksum
/// \return CRC32-C value
/// \since Crypto++ 8.6
inline uint32_t CRC32CWx4 (uint32_t crc, const uint32_t vals[4])
{
#if defined(CRYPTOPP_MSC_VERSION)
	return __crc32cw(__crc32cw(__crc32cw(__crc32cw(
             crc, vals[0]), vals[1]), vals[2]), vals[3]);
#else
    __asm__ ("crc32cw   %w0, %w0, %w1   \n\t"
             "crc32cw   %w0, %w0, %w2   \n\t"
             "crc32cw   %w0, %w0, %w3   \n\t"
             "crc32cw   %w0, %w0, %w4   \n\t"
            :"+r" (crc) : "r" (vals[0]), "r" (vals[1]),
                          "r" (vals[2]), "r" (vals[3]));
    return crc;
#endif
}
//@}
#endif  // CRYPTOPP_ARM_CRC32_AVAILABLE

#if (CRYPTOPP_ARM_PMULL_AVAILABLE) || defined(CRYPTOPP_DOXYGEN_PROCESSING)
///	\name Polynomial multiplication
//@{

/// \brief Polynomial multiplication
/// \param a the first value
/// \param b the second value
/// \return vector product
/// \details PMULL_00() performs polynomial multiplication and presents
///  the result like Intel's <tt>c = _mm_clmulepi64_si128(a, b, 0x00)</tt>.
///  The <tt>0x00</tt> indicates the low 64-bits of <tt>a</tt> and <tt>b</tt>
///  are multiplied.
/// \note An Intel XMM register is composed of 128-bits. The leftmost bit
///  is MSB and numbered 127, while the rightmost bit is LSB and
///  numbered 0.
/// \since Crypto++ 8.0
inline uint64x2_t PMULL_00(const uint64x2_t a, const uint64x2_t b)
{
#if defined(CRYPTOPP_MSC_VERSION)
    const __n64 x = { vgetq_lane_u64(a, 0) };
    const __n64 y = { vgetq_lane_u64(b, 0) };
    return vmull_p64(x, y);
#elif defined(__GNUC__)
    uint64x2_t r;
    __asm__ ("pmull    %0.1q, %1.1d, %2.1d   \n\t"
            :"=w" (r) : "w" (a), "w" (b) );
    return r;
#else
    return (uint64x2_t)(vmull_p64(
        vgetq_lane_u64(vreinterpretq_u64_u8(a),0),
        vgetq_lane_u64(vreinterpretq_u64_u8(b),0)));
#endif
}

/// \brief Polynomial multiplication
/// \param a the first value
/// \param b the second value
/// \return vector product
/// \details PMULL_01 performs() polynomial multiplication and presents
///  the result like Intel's <tt>c = _mm_clmulepi64_si128(a, b, 0x01)</tt>.
///  The <tt>0x01</tt> indicates the low 64-bits of <tt>a</tt> and high
///  64-bits of <tt>b</tt> are multiplied.
/// \note An Intel XMM register is composed of 128-bits. The leftmost bit
///  is MSB and numbered 127, while the rightmost bit is LSB and
///  numbered 0.
/// \since Crypto++ 8.0
inline uint64x2_t PMULL_01(const uint64x2_t a, const uint64x2_t b)
{
#if defined(CRYPTOPP_MSC_VERSION)
    const __n64 x = { vgetq_lane_u64(a, 0) };
    const __n64 y = { vgetq_lane_u64(b, 1) };
    return vmull_p64(x, y);
#elif defined(__GNUC__)
    uint64x2_t r;
    __asm__ ("pmull    %0.1q, %1.1d, %2.1d   \n\t"
            :"=w" (r) : "w" (a), "w" (vget_high_u64(b)) );
    return r;
#else
    return (uint64x2_t)(vmull_p64(
        vgetq_lane_u64(vreinterpretq_u64_u8(a),0),
        vgetq_lane_u64(vreinterpretq_u64_u8(b),1)));
#endif
}

/// \brief Polynomial multiplication
/// \param a the first value
/// \param b the second value
/// \return vector product
/// \details PMULL_10() performs polynomial multiplication and presents
///  the result like Intel's <tt>c = _mm_clmulepi64_si128(a, b, 0x10)</tt>.
///  The <tt>0x10</tt> indicates the high 64-bits of <tt>a</tt> and low
///  64-bits of <tt>b</tt> are multiplied.
/// \note An Intel XMM register is composed of 128-bits. The leftmost bit
///  is MSB and numbered 127, while the rightmost bit is LSB and
///  numbered 0.
/// \since Crypto++ 8.0
inline uint64x2_t PMULL_10(const uint64x2_t a, const uint64x2_t b)
{
#if defined(CRYPTOPP_MSC_VERSION)
    const __n64 x = { vgetq_lane_u64(a, 1) };
    const __n64 y = { vgetq_lane_u64(b, 0) };
    return vmull_p64(x, y);
#elif defined(__GNUC__)
    uint64x2_t r;
    __asm__ ("pmull    %0.1q, %1.1d, %2.1d   \n\t"
            :"=w" (r) : "w" (vget_high_u64(a)), "w" (b) );
    return r;
#else
    return (uint64x2_t)(vmull_p64(
        vgetq_lane_u64(vreinterpretq_u64_u8(a),1),
        vgetq_lane_u64(vreinterpretq_u64_u8(b),0)));
#endif
}

/// \brief Polynomial multiplication
/// \param a the first value
/// \param b the second value
/// \return vector product
/// \details PMULL_11() performs polynomial multiplication and presents
///  the result like Intel's <tt>c = _mm_clmulepi64_si128(a, b, 0x11)</tt>.
///  The <tt>0x11</tt> indicates the high 64-bits of <tt>a</tt> and <tt>b</tt>
///  are multiplied.
/// \note An Intel XMM register is composed of 128-bits. The leftmost bit
///  is MSB and numbered 127, while the rightmost bit is LSB and
///  numbered 0.
/// \since Crypto++ 8.0
inline uint64x2_t PMULL_11(const uint64x2_t a, const uint64x2_t b)
{
#if defined(CRYPTOPP_MSC_VERSION)
    const __n64 x = { vgetq_lane_u64(a, 1) };
    const __n64 y = { vgetq_lane_u64(b, 1) };
    return vmull_p64(x, y);
#elif defined(__GNUC__)
    uint64x2_t r;
    __asm__ ("pmull2   %0.1q, %1.2d, %2.2d   \n\t"
            :"=w" (r) : "w" (a), "w" (b) );
    return r;
#else
    return (uint64x2_t)(vmull_p64(
        vgetq_lane_u64(vreinterpretq_u64_u8(a),1),
        vgetq_lane_u64(vreinterpretq_u64_u8(b),1)));
#endif
}

/// \brief Polynomial multiplication
/// \param a the first value
/// \param b the second value
/// \return vector product
/// \details PMULL() performs vmull_p64(). PMULL is provided as
///  GCC inline assembly due to Clang and lack of support for the intrinsic.
/// \since Crypto++ 8.0
inline uint64x2_t PMULL(const uint64x2_t a, const uint64x2_t b)
{
#if defined(CRYPTOPP_MSC_VERSION)
    const __n64 x = { vgetq_lane_u64(a, 0) };
    const __n64 y = { vgetq_lane_u64(b, 0) };
    return vmull_p64(x, y);
#elif defined(__GNUC__)
    uint64x2_t r;
    __asm__ ("pmull    %0.1q, %1.1d, %2.1d   \n\t"
            :"=w" (r) : "w" (a), "w" (b) );
    return r;
#else
    return (uint64x2_t)(vmull_p64(
        vgetq_lane_u64(vreinterpretq_u64_u8(a),0),
        vgetq_lane_u64(vreinterpretq_u64_u8(b),0)));
#endif
}

/// \brief Polynomial multiplication
/// \param a the first value
/// \param b the second value
/// \return vector product
/// \details PMULL_HIGH() performs vmull_high_p64(). PMULL_HIGH is provided as
///  GCC inline assembly due to Clang and lack of support for the intrinsic.
/// \since Crypto++ 8.0
inline uint64x2_t PMULL_HIGH(const uint64x2_t a, const uint64x2_t b)
{
#if defined(CRYPTOPP_MSC_VERSION)
    const __n64 x = { vgetq_lane_u64(a, 1) };
    const __n64 y = { vgetq_lane_u64(b, 1) };
    return vmull_p64(x, y);
#elif defined(__GNUC__)
    uint64x2_t r;
    __asm__ ("pmull2   %0.1q, %1.2d, %2.2d   \n\t"
            :"=w" (r) : "w" (a), "w" (b) );
    return r;
#else
    return (uint64x2_t)(vmull_p64(
        vgetq_lane_u64(vreinterpretq_u64_u8(a),1),
        vgetq_lane_u64(vreinterpretq_u64_u8(b),1))));
#endif
}

/// \brief Vector extraction
/// \tparam C the byte count
/// \param a the first value
/// \param b the second value
/// \return vector
/// \details VEXT_U8() extracts the first <tt>C</tt> bytes of vector
///  <tt>a</tt> and the remaining bytes in <tt>b</tt>. VEXT_U8 is provided
///  as GCC inline assembly due to Clang and lack of support for the intrinsic.
/// \since Crypto++ 8.0
template <unsigned int C>
inline uint64x2_t VEXT_U8(uint64x2_t a, uint64x2_t b)
{
    // https://github.com/weidai11/cryptopp/issues/366
#if defined(CRYPTOPP_MSC_VERSION)
    return vreinterpretq_u64_u8(vextq_u8(
        vreinterpretq_u8_u64(a), vreinterpretq_u8_u64(b), C));
#else
    uint64x2_t r;
    __asm__ ("ext   %0.16b, %1.16b, %2.16b, %3   \n\t"
            :"=w" (r) : "w" (a), "w" (b), "I" (C) );
    return r;
#endif
}

//@}
#endif // CRYPTOPP_ARM_PMULL_AVAILABLE

#if CRYPTOPP_ARM_SHA3_AVAILABLE  || defined(CRYPTOPP_DOXYGEN_PROCESSING)
///	\name ARMv8.2 operations
//@{

/// \brief Three-way XOR
/// \param a the first value
/// \param b the second value
/// \param c the third value
/// \return three-way exclusive OR of the values
/// \details VEOR3() performs veor3q_u64(). VEOR3 is provided as GCC inline assembly due
///  to Clang and lack of support for the intrinsic.
/// \details VEOR3 requires ARMv8.2.
/// \since Crypto++ 8.6
inline uint64x2_t VEOR3(uint64x2_t a, uint64x2_t b, uint64x2_t c)
{
#if defined(CRYPTOPP_MSC_VERSION)
    return veor3q_u64(a, b, c);
#else
    uint64x2_t r;
    __asm__ ("eor3   %0.16b, %1.16b, %2.16b, %3.16b   \n\t"
            :"=w" (r) : "w" (a), "w" (b), "w" (c));
    return r;
#endif
}

/// \brief XOR and rotate
/// \param a the first value
/// \param b the second value
/// \param c the third value
/// \return two-way exclusive OR of the values, then rotated by c
/// \details VXARQ() performs vxarq_u64(). VXARQ is provided as GCC inline assembly due
///  to Clang and lack of support for the intrinsic.
/// \details VXARQ requires ARMv8.2.
/// \since Crypto++ 8.6
inline uint64x2_t VXAR(uint64x2_t a, uint64x2_t b, const int c)
{
#if defined(CRYPTOPP_MSC_VERSION)
    return vxarq_u64(a, b, c);
#else
    uint64x2_t r;
    __asm__ ("xar   %0.2d, %1.2d, %2.2d, %3   \n\t"
            :"=w" (r) : "w" (a), "w" (b), "I" (c));
    return r;
#endif
}

/// \brief XOR and rotate
/// \tparam C the rotate amount
/// \param a the first value
/// \param b the second value
/// \return two-way exclusive OR of the values, then rotated by C
/// \details VXARQ() performs vxarq_u64(). VXARQ is provided as GCC inline assembly due
///  to Clang and lack of support for the intrinsic.
/// \details VXARQ requires ARMv8.2.
/// \since Crypto++ 8.6
template <unsigned int C>
inline uint64x2_t VXAR(uint64x2_t a, uint64x2_t b)
{
#if defined(CRYPTOPP_MSC_VERSION)
    return vxarq_u64(a, b, C);
#else
    uint64x2_t r;
    __asm__ ("xar   %0.2d, %1.2d, %2.2d, %3   \n\t"
            :"=w" (r) : "w" (a), "w" (b), "I" (C));
    return r;
#endif
}

/// \brief XOR and rotate
/// \param a the first value
/// \param b the second value
/// \return two-way exclusive OR of the values, then rotated 1-bit
/// \details VRAX1() performs vrax1q_u64(). VRAX1 is provided as GCC inline assembly due
///  to Clang and lack of support for the intrinsic.
/// \details VRAX1 requires ARMv8.2.
/// \since Crypto++ 8.6
inline uint64x2_t VRAX1(uint64x2_t a, uint64x2_t b)
{
#if defined(CRYPTOPP_MSC_VERSION)
    return vrax1q_u64(a, b);
#else
    uint64x2_t r;
    __asm__ ("rax1   %0.2d, %1.2d, %2.2d   \n\t"
            :"=w" (r) : "w" (a), "w" (b));
    return r;
#endif
}
//@}
#endif  // CRYPTOPP_ARM_SHA3_AVAILABLE

#endif // CRYPTOPP_ARM_SIMD_H
