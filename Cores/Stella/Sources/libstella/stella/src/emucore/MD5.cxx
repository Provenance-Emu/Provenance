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
// Algorithm.  See the header file for copyright information.
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#include "MD5.hxx"

// Constants for MD5Transform routine.
namespace {
  constexpr uInt32
    S11 = 7,
    S12 = 12,
    S13 = 17,
    S14 = 22,
    S21 = 5,
    S22 = 9,
    S23 = 14,
    S24 = 20,
    S31 = 4,
    S32 = 11,
    S33 = 16,
    S34 = 23,
    S41 = 6,
    S42 = 10,
    S43 = 15,
    S44 = 21;
} // namespace

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// MD5 initialization. Begins an MD5 operation, writing a new context.
void MD5::init()
{
  finalized = false;

  count[0] = 0;
  count[1] = 0;

  // Load magic initialization constants
  state[0] = 0x67452301;
  state[1] = 0xefcdab89;
  state[2] = 0x98badcfe;
  state[3] = 0x10325476;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Decodes input (uInt8) into output (uInt32).
// Assumes len is a multiple of 4.
void MD5::decode(uInt32* output, const uInt8* const input, uInt32 len)
{
  for (uInt32 i = 0, j = 0; j < len; ++i, j += 4)
    output[i] =  (static_cast<uInt32>(input[j]))
              | ((static_cast<uInt32>(input[j+1])) << 8)
              | ((static_cast<uInt32>(input[j+2])) << 16)
              | ((static_cast<uInt32>(input[j+3])) << 24);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Encodes input (uInt32) into output (uInt8).
// Assumes len is a multiple of 4.
void MD5::encode(uInt8* output, const uInt32* const input, uInt32 len)
{
  for (uInt32 i = 0, j = 0; j < len; ++i, j += 4) {
    output[j]   = static_cast<uInt8>(input[i] & 0xff);
    output[j+1] = static_cast<uInt8>((input[i] >> 8) & 0xff);
    output[j+2] = static_cast<uInt8>((input[i] >> 16) & 0xff);
    output[j+3] = static_cast<uInt8>((input[i] >> 24) & 0xff);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Apply MD5 algo on a block.
void MD5::transform(const uInt8* const block)
{
  std::array<uInt32, 16> x;
  decode(x.data(), block, BLOCKSIZE);

  uInt32 a = state[0], b = state[1], c = state[2], d = state[3];

  /* Round 1 */
  FF (a, b, c, d, x[ 0], S11, 0xd76aa478); /* 1 */
  FF (d, a, b, c, x[ 1], S12, 0xe8c7b756); /* 2 */
  FF (c, d, a, b, x[ 2], S13, 0x242070db); /* 3 */
  FF (b, c, d, a, x[ 3], S14, 0xc1bdceee); /* 4 */
  FF (a, b, c, d, x[ 4], S11, 0xf57c0faf); /* 5 */
  FF (d, a, b, c, x[ 5], S12, 0x4787c62a); /* 6 */
  FF (c, d, a, b, x[ 6], S13, 0xa8304613); /* 7 */
  FF (b, c, d, a, x[ 7], S14, 0xfd469501); /* 8 */
  FF (a, b, c, d, x[ 8], S11, 0x698098d8); /* 9 */
  FF (d, a, b, c, x[ 9], S12, 0x8b44f7af); /* 10 */
  FF (c, d, a, b, x[10], S13, 0xffff5bb1); /* 11 */
  FF (b, c, d, a, x[11], S14, 0x895cd7be); /* 12 */
  FF (a, b, c, d, x[12], S11, 0x6b901122); /* 13 */
  FF (d, a, b, c, x[13], S12, 0xfd987193); /* 14 */
  FF (c, d, a, b, x[14], S13, 0xa679438e); /* 15 */
  FF (b, c, d, a, x[15], S14, 0x49b40821); /* 16 */

  /* Round 2 */
  GG (a, b, c, d, x[ 1], S21, 0xf61e2562); /* 17 */
  GG (d, a, b, c, x[ 6], S22, 0xc040b340); /* 18 */
  GG (c, d, a, b, x[11], S23, 0x265e5a51); /* 19 */
  GG (b, c, d, a, x[ 0], S24, 0xe9b6c7aa); /* 20 */
  GG (a, b, c, d, x[ 5], S21, 0xd62f105d); /* 21 */
  GG (d, a, b, c, x[10], S22,  0x2441453); /* 22 */
  GG (c, d, a, b, x[15], S23, 0xd8a1e681); /* 23 */
  GG (b, c, d, a, x[ 4], S24, 0xe7d3fbc8); /* 24 */
  GG (a, b, c, d, x[ 9], S21, 0x21e1cde6); /* 25 */
  GG (d, a, b, c, x[14], S22, 0xc33707d6); /* 26 */
  GG (c, d, a, b, x[ 3], S23, 0xf4d50d87); /* 27 */
  GG (b, c, d, a, x[ 8], S24, 0x455a14ed); /* 28 */
  GG (a, b, c, d, x[13], S21, 0xa9e3e905); /* 29 */
  GG (d, a, b, c, x[ 2], S22, 0xfcefa3f8); /* 30 */
  GG (c, d, a, b, x[ 7], S23, 0x676f02d9); /* 31 */
  GG (b, c, d, a, x[12], S24, 0x8d2a4c8a); /* 32 */

  /* Round 3 */
  HH (a, b, c, d, x[ 5], S31, 0xfffa3942); /* 33 */
  HH (d, a, b, c, x[ 8], S32, 0x8771f681); /* 34 */
  HH (c, d, a, b, x[11], S33, 0x6d9d6122); /* 35 */
  HH (b, c, d, a, x[14], S34, 0xfde5380c); /* 36 */
  HH (a, b, c, d, x[ 1], S31, 0xa4beea44); /* 37 */
  HH (d, a, b, c, x[ 4], S32, 0x4bdecfa9); /* 38 */
  HH (c, d, a, b, x[ 7], S33, 0xf6bb4b60); /* 39 */
  HH (b, c, d, a, x[10], S34, 0xbebfbc70); /* 40 */
  HH (a, b, c, d, x[13], S31, 0x289b7ec6); /* 41 */
  HH (d, a, b, c, x[ 0], S32, 0xeaa127fa); /* 42 */
  HH (c, d, a, b, x[ 3], S33, 0xd4ef3085); /* 43 */
  HH (b, c, d, a, x[ 6], S34,  0x4881d05); /* 44 */
  HH (a, b, c, d, x[ 9], S31, 0xd9d4d039); /* 45 */
  HH (d, a, b, c, x[12], S32, 0xe6db99e5); /* 46 */
  HH (c, d, a, b, x[15], S33, 0x1fa27cf8); /* 47 */
  HH (b, c, d, a, x[ 2], S34, 0xc4ac5665); /* 48 */

  /* Round 4 */
  II (a, b, c, d, x[ 0], S41, 0xf4292244); /* 49 */
  II (d, a, b, c, x[ 7], S42, 0x432aff97); /* 50 */
  II (c, d, a, b, x[14], S43, 0xab9423a7); /* 51 */
  II (b, c, d, a, x[ 5], S44, 0xfc93a039); /* 52 */
  II (a, b, c, d, x[12], S41, 0x655b59c3); /* 53 */
  II (d, a, b, c, x[ 3], S42, 0x8f0ccc92); /* 54 */
  II (c, d, a, b, x[10], S43, 0xffeff47d); /* 55 */
  II (b, c, d, a, x[ 1], S44, 0x85845dd1); /* 56 */
  II (a, b, c, d, x[ 8], S41, 0x6fa87e4f); /* 57 */
  II (d, a, b, c, x[15], S42, 0xfe2ce6e0); /* 58 */
  II (c, d, a, b, x[ 6], S43, 0xa3014314); /* 59 */
  II (b, c, d, a, x[13], S44, 0x4e0811a1); /* 60 */
  II (a, b, c, d, x[ 4], S41, 0xf7537e82); /* 61 */
  II (d, a, b, c, x[11], S42, 0xbd3af235); /* 62 */
  II (c, d, a, b, x[ 2], S43, 0x2ad7d2bb); /* 63 */
  II (b, c, d, a, x[ 9], S44, 0xeb86d391); /* 64 */

  state[0] += a;
  state[1] += b;
  state[2] += c;
  state[3] += d;

  // Zeroize sensitive information (not required for Stella)
  // x.fill(0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// MD5 block update operation.
// Continues an MD5 message-digest operation, processing another message block.
void MD5::update(const uInt8* const input, uInt32 length)
{
  // Compute number of bytes mod 64
  auto index = count[0] / 8 % BLOCKSIZE;

  // Update number of bits
  if ((count[0] += (length << 3)) < (length << 3)) // NOLINT
    count[1]++;
  count[1] += (length >> 29);

  // Number of bytes we need to fill in buffer
  const uInt32 firstpart = 64 - index;

  // Transform as many times as possible.
  uInt32 i = 0;
  if (length >= firstpart)
  {
    // Fill buffer first, transform
    std::copy_n(input, firstpart, buffer.data() + index);
    transform(buffer.data());

    // Transform chunks of BLOCKSIZE (64 bytes)
    for (i = firstpart; i + BLOCKSIZE <= length; i += BLOCKSIZE)
      transform(&input[i]);

    index = 0;
  }
  else
    i = 0;

  // Buffer remaining input
  std::copy_n(input + i, length - i, buffer.data() + index);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// MD5 finalization.  Ends an MD5 message-digest operation, writing the
// the message digest and zeroizing the context.
void MD5::finalize()
{
  static constexpr std::array<uInt8, BLOCKSIZE> padding = {
    0x80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  };

  if (!finalized)
  {
    // Save number of bits
    std::array<uInt8, 8> bits;
    encode(bits.data(), count.data(), 8);

    // Pad out to 56 mod 64
    const uInt32 index = count[0] / 8 % 64;
    const uInt32 padLen = (index < 56) ? (56 - index) : (120 - index);
    update(padding.data(), padLen);

    // Append length (before padding)
    update(bits.data(), 8);

    // Store state in digest
    encode(digest.data(), state.data(), 16);

    // Zeroize sensitive information (not required for Stella)
    // buffer.fill(0);
    // count.fill(0);

    finalized = true;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Return hex representation of digest as string
string MD5::hexdigest() const
{
  if (!finalized)
    return "";

  static constexpr char hex[] = "0123456789abcdef";
  string result;
  for (auto c: digest)
  {
    result += hex[(c >> 4) & 0x0f];
    result += hex[c & 0x0f];
  }

  return result;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string MD5::hash(string_view buffer)
{
  return MD5::hash(reinterpret_cast<const uInt8*>(buffer.data()), buffer.size());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string MD5::hash(const ByteBuffer& buffer, size_t length)
{
  return MD5::hash(buffer.get(), length);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string MD5::hash(const uInt8* buffer, size_t length)
{
  static MD5 ourMD5;  // singleton

  ourMD5.init();
  ourMD5.update(buffer, static_cast<uInt32>(length));
  ourMD5.finalize();

  return ourMD5.hexdigest();
}
