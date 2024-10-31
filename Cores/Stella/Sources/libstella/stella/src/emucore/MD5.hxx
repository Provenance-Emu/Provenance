//============================================================================
//
//   SSSS    tt          lll  lll
//  SS  SS   tt           ll   ll
//  SS     tttttt  eeee   ll   ll   aaaa
//   SSSS    tt   ee  ee  ll   ll      aa
//      SS   tt   eeeeee  ll   ll   aaaaa  --  "An Atari 2600 VCS Emulator"
//  SS  SS   tt   ee      ll   ll  aa  aa
//   SSSS     ttt  eeeee llll llll  aaaaa
//
// Copyright (c) 1995-2024 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// This file is derived from the RSA Data Security, Inc. MD5 Message-Digest
// Algorithm.  See the header below for copyright information.
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

/* MD5
 converted to C++ class by Frank Thilo (thilo@unix-ag.org)
 for bzflag (http://www.bzflag.org)

   based on:

   md5.h and md5.c
   reference implementation of RFC 1321

   Copyright (C) 1991-2, RSA Data Security, Inc. Created 1991. All
rights reserved.

License to copy and use this software is granted provided that it
is identified as the "RSA Data Security, Inc. MD5 Message-Digest
Algorithm" in all material mentioning or referencing this software
or this function.

License is also granted to make and use derivative works provided
that such works are identified as "derived from the RSA Data
Security, Inc. MD5 Message-Digest Algorithm" in all material
mentioning or referencing the derived work.

RSA Data Security, Inc. makes no representations concerning either
the merchantability of this software or the suitability of this
software for any particular purpose. It is provided "as is"
without express or implied warranty of any kind.

These notices must be retained in any copies of any part of this
documentation and/or software.
*/

#ifndef MD5_HXX
#define MD5_HXX

#include "bspf.hxx"

class MD5
{
  public:
    /**
      Get the MD5 Message-Digest of the specified message with the
      given length.  The digest consists of 32 hexadecimal digits.

      @param buffer  The message to compute the digest of
      @param length  The length of the message

      @return   The message-digest
    */
    static string hash(const ByteBuffer& buffer, size_t length);
    static string hash(const uInt8* buffer, size_t length);
    /**
      Ditto.

      @param buffer  The message to compute the digest of

      @return   The message - digest
    */
    static string hash(string_view buffer);

  public:
    MD5() = default;

  private:
    void init();
    void update(const uInt8* const input, uInt32 length);
    void finalize();
    string hexdigest() const;
    void transform(const uInt8* block);
    static void decode(uInt32* output, const uInt8* const input, uInt32 len);
    static void encode(uInt8* output, const uInt32* const input, uInt32 len);

    // F, G, H and I are basic MD5 functions.
    FORCE_INLINE constexpr uInt32 F(uInt32 x, uInt32 y, uInt32 z) {
      return (x&y) | (~x&z);
    }
    FORCE_INLINE constexpr uInt32 G(uInt32 x, uInt32 y, uInt32 z) {
      return (x&z) | (y&~z);
    }
    FORCE_INLINE constexpr uInt32 H(uInt32 x, uInt32 y, uInt32 z) {
      return x^y^z;
    }
    FORCE_INLINE constexpr uInt32 I(uInt32 x, uInt32 y, uInt32 z) {
      return y ^ (x | ~z);
    }
    // rotate_left rotates x left n bits.
    FORCE_INLINE constexpr uInt32 rotate_left(uInt32 x, int n) {
      return (x << n) | (x >> (32-n));
    }
    // FF, GG, HH, and II transformations for rounds 1, 2, 3, and 4.
    // Rotation is separate from addition to prevent recomputation.
    FORCE_INLINE constexpr void FF(uInt32 &a, uInt32 b, uInt32 c,
                                   uInt32 d, uInt32 x, uInt32 s, uInt32 ac) {
      a = rotate_left(a+ F(b,c,d) + x + ac, s) + b;
    }
    FORCE_INLINE constexpr void GG(uInt32 &a, uInt32 b, uInt32 c, uInt32 d,
                                   uInt32 x, uInt32 s, uInt32 ac) {
      a = rotate_left(a + G(b,c,d) + x + ac, s) + b;
    }
    FORCE_INLINE constexpr void HH(uInt32 &a, uInt32 b, uInt32 c, uInt32 d,
                                   uInt32 x, uInt32 s, uInt32 ac) {
      a = rotate_left(a + H(b,c,d) + x + ac, s) + b;
    }
    FORCE_INLINE constexpr void II(uInt32 &a, uInt32 b, uInt32 c, uInt32 d,
                                   uInt32 x, uInt32 s, uInt32 ac) {
      a = rotate_left(a + I(b,c,d) + x + ac, s) + b;
    }

  private:
    static inline constexpr uInt32 BLOCKSIZE = 64;
    bool finalized{false};
    std::array<uInt8, BLOCKSIZE> buffer; // bytes that didn't fit in last chunk
    std::array<uInt32, 2> count;   // 64bit counter for number of bits (lo, hi)
    std::array<uInt32, 4> state;   // digest so far
    std::array<uInt8, 16> digest;  // the result

  private:
    MD5(const MD5&) = delete;
    MD5(MD5&&) = delete;
    MD5& operator=(const MD5&) = delete;
    MD5& operator=(MD5&&) = delete;
};

#endif
