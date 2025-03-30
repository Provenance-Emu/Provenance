// donna_sse.h - written and placed in public domain by Jeffrey Walton
//               Crypto++ specific implementation wrapped around Andrew
//               Moon's public domain curve25519-donna and ed25519-donna,
//               https://github.com/floodyberry/curve25519-donna and
//               https://github.com/floodyberry/ed25519-donna.

// This source file multiplexes two different repos using namespaces. This
// was a little easier from a project management standpoint. We only need
// two files per architecture at the expense of namespaces and bloat.

#ifndef CRYPTOPP_DONNA_SSE_H
#define CRYPTOPP_DONNA_SSE_H
#ifndef CRYPTOPP_DOXYGEN_PROCESSING

#include "config.h"
#include <emmintrin.h>

NAMESPACE_BEGIN(CryptoPP)
NAMESPACE_BEGIN(Donna)
NAMESPACE_BEGIN(ArchSSE)

using CryptoPP::byte;
using CryptoPP::word32;

typedef __m128i xmmi;
#define ALIGN(n) CRYPTOPP_ALIGN_DATA(n)

typedef union packedelem8_t {
    byte u[16];
    xmmi v;
} packedelem8;

typedef union packedelem32_t {
    word32 u[4];
    xmmi v;
} packedelem32;

typedef union packedelem64_t {
    word64 u[2];
    xmmi v;
} packedelem64;

/* 10 elements + an extra 2 to fit in 3 xmm registers */
typedef word32 bignum25519[12];
typedef packedelem32 packed32bignum25519[5];
typedef packedelem64 packed64bignum25519[10];

const word32 reduce_mask_26 = (1 << 26) - 1;
const word32 reduce_mask_25 = (1 << 25) - 1;

const packedelem32 sse2_bot32bitmask = {{0xffffffff, 0x00000000, 0xffffffff, 0x00000000}};
const packedelem32 sse2_top32bitmask = {{0x00000000, 0xffffffff, 0x00000000, 0xffffffff}};
const packedelem32 sse2_top64bitmask = {{0x00000000, 0x00000000, 0xffffffff, 0xffffffff}};
const packedelem32 sse2_bot64bitmask = {{0xffffffff, 0xffffffff, 0x00000000, 0x00000000}};

/* reduction masks */
const packedelem64 packedmask26 = {{0x03ffffff, 0x03ffffff}};
const packedelem64 packedmask25 = {{0x01ffffff, 0x01ffffff}};
const packedelem32 packedmask2625 = {{0x3ffffff,0,0x1ffffff,0}};
const packedelem32 packedmask26262626 = {{0x03ffffff, 0x03ffffff, 0x03ffffff, 0x03ffffff}};
const packedelem32 packedmask25252525 = {{0x01ffffff, 0x01ffffff, 0x01ffffff, 0x01ffffff}};

/* multipliers */
const packedelem64 packednineteen = {{19, 19}};
const packedelem64 packednineteenone = {{19, 1}};
const packedelem64 packedthirtyeight = {{38, 38}};
const packedelem64 packed3819 = {{19*2,19}};
const packedelem64 packed9638 = {{19*4,19*2}};

/* 121666,121665 */
const packedelem64 packed121666121665 = {{121666, 121665}};

/* 2*(2^255 - 19) = 0 mod p */
const packedelem32 packed2p0 = {{0x7ffffda,0x3fffffe,0x7fffffe,0x3fffffe}};
const packedelem32 packed2p1 = {{0x7fffffe,0x3fffffe,0x7fffffe,0x3fffffe}};
const packedelem32 packed2p2 = {{0x7fffffe,0x3fffffe,0x0000000,0x0000000}};

const packedelem32 packed32zeromodp0 = {{0x7ffffda,0x7ffffda,0x3fffffe,0x3fffffe}};
const packedelem32 packed32zeromodp1 = {{0x7fffffe,0x7fffffe,0x3fffffe,0x3fffffe}};

NAMESPACE_END  // ArchSSE
NAMESPACE_END  // Donna
NAMESPACE_END  // CryptoPP

#endif  // CRYPTOPP_DOXYGEN_PROCESSING
#endif  // CRYPTOPP_DONNA_SSE_H
