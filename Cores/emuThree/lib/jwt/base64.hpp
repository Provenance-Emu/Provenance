/*
Copyright (c) 2017 Arun Muralidharan

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */

#ifndef CPP_JWT_BASE64_HPP
#define CPP_JWT_BASE64_HPP

#include <array>
#include <cassert>
#include <cstring>
#include <ostream>
#include "jwt/config.hpp"
#include "jwt/string_view.hpp"

namespace jwt {

// Returns the maximum number of bytes required to
// encode an input byte string of length `n` to base64.
inline constexpr 
size_t encoding_size(size_t n)
{
  return 4 * ((n + 2) / 3);
}


// Returns the maximum number of bytes required
// to store a decoded base64 byte string.
inline constexpr
size_t decoding_size(size_t n)
{
  return n / 4 * 3;
}

/**
 * Encoding map.
 * A constexpr helper class for performing base64
 * encoding on the input byte string.
 */
class EMap
{
public:
  constexpr EMap() = default;

public:
  constexpr char at(size_t pos) const noexcept
  {
    return X_ASSERT(pos < chars_.size()), chars_.at(pos);
  }

private:
  std::array<char, 64> chars_ = {{
    'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
    'a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z',
    '0','1','2','3','4','5','6','7','8','9',
    '+','/',
  }};
};

/**
 * Encodes a sequence of octet into base64 string.
 * Returns std::string resized to contain only the
 * encoded data (as usual without null terminator).
 *
 * The encoded string is atleast `encoding_size(input len)`
 * in size.
 *
 * Arguments:
 *  @in : Input byte string to be encoded.
 *  @len : Length of the input byte string.
 */
inline std::string base64_encode(const char* in, size_t len)
{
  std::string result;
  const auto encoded_siz = encoding_size(len);
  result.resize(encoded_siz);

  constexpr static const EMap emap{};

  int i = 0;
  int j = 0;
  for (; i < static_cast<int>(len) - 2; i += 3) {
    const auto first  = in[i];
    const auto second = in[i+1];
    const auto third  = in[i+2];

    result[j++] = emap.at( (first >> 2) & 0x3F                           );
    result[j++] = emap.at(((first  & 0x03) << 4) | ((second & 0xF0) >> 4));
    result[j++] = emap.at(((second & 0x0F) << 2) | ((third  & 0xC0) >> 6));
    result[j++] = emap.at(                          (third  & 0x3F)      );
  }

  switch (len % 3) {
  case 2:
  {
    const auto first  = in[i];
    const auto second = in[i+1];

    result[j++] = emap.at( (first >> 2) & 0x3F                          );
    result[j++] = emap.at(((first & 0x03) << 4) | ((second & 0xF0) >> 4));
    result[j++] = emap.at(                         (second & 0x0F) << 2 );
    result[j++] = '=';
    break;
  }
  case 1:
  {
    const auto first = in[i];

    result[j++] = emap.at((first >> 2) & 0x3F);
    result[j++] = emap.at((first & 0x03) << 4);
    result[j++] = '=';
    result[j++] = '=';
    break;
  }
  case 0:
    break;
  };

  result.resize(j);

  return result;
}



//======================= Decoder ==========================

/**
 * Decoding map.
 * A helper constexpr class for providing interface
 * to the decoding map for base64.
 */
class DMap
{
public:
  constexpr DMap() = default;

public:
  constexpr signed char at(size_t pos) const noexcept
  {
    return X_ASSERT(pos < map_.size()), map_[pos];
  }

private:
  std::array<signed char, 256> map_ = {{
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, //   0-15
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, //  16-31
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 62, -1, -1, -1, 63, //  32-47
    52, 53, 54, 55, 56, 57, 58, 59, 60, 61, -1, -1, -1, -1, -1, -1, //  48-63
    -1,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, //  64-79
    15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, -1, -1, -1, -1, -1, //  80-95
    -1, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, //  96-111
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, -1, -1, -1, -1, -1, // 112-127
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, // 128-143
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, // 144-159
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, // 160-175
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, // 176-191
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, // 192-207
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, // 208-223
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, // 224-239
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1  // 240-255
  }};
};

/**
 * Decodes octet of base64 encoded byte string.
 *
 * Returns a std::string with the decoded byte string.
 *
 * Arguments:
 *  @in : Encoded base64 byte string.
 *  @len : Length of the encoded input byte string.
 */
inline std::string base64_decode(const char* in, size_t len)
{
  std::string result;
  const auto decoded_siz = decoding_size(len);
  result.resize(decoded_siz);

  int i = 0;
  size_t bytes_rem = len;
  size_t bytes_wr = 0;

  constexpr static const DMap dmap{};

  while (bytes_rem > 0 && dmap.at(in[bytes_rem - 1]) == -1) { bytes_rem--; }

  while (bytes_rem > 4)
  {
    // Error case in input
    if (dmap.at(*in) == -1) return result;

    const auto first  = dmap.at(in[0]);
    const auto second = dmap.at(in[1]);
    const auto third  = dmap.at(in[2]);
    const auto fourth = dmap.at(in[3]);

    result[i]     = (first  << 2) | (second >> 4);
    result[i + 1] = (second << 4) | (third  >> 2);
    result[i + 2] = (third  << 6) | fourth;

    bytes_rem -= 4;
    i += 3;
    in += 4;
  }
  bytes_wr = i;

  switch(bytes_rem) {
  case 4:
  {
    const auto third  = dmap.at(in[2]);
    const auto fourth = dmap.at(in[3]);
    result[i + 2] = (third << 6) | fourth;
    bytes_wr++;
  }
  //FALLTHROUGH
  case 3:
  {
    const auto second = dmap.at(in[1]);
    const auto third  = dmap.at(in[2]);
    result[i + 1] = (second << 4) | (third >> 2);
    bytes_wr++;
  }
  //FALLTHROUGH
  case 2:
  {
    const auto first  = dmap.at(in[0]);
    const auto second = dmap.at(in[1]);
    result[i] = (first << 2) | (second >> 4);
    bytes_wr++;
  }
  };

  result.resize(bytes_wr);

  return result;
}

/**
 * Makes the base64 encoded byte string URL safe.
 * Overwrites/skips few URL unsafe characters
 * from the input sequence.
 *
 * Arguments:
 *  @data : Base64 encoded byte string.
 *  @len : Length of the base64 byte string.
 *
 * Returns:
 *  Length of the URL safe base64 encoded byte string.
 */
inline size_t base64_uri_encode(char* data, size_t len) noexcept
{
  size_t i = 0;
  size_t j = 0;

  for (; i < len; ++i) {
    switch (data[i]) {
    case '+':
      data[j++] = '-';
      break;
    case '/':
      data[j++] = '_';
      break;
    case '=':
      break;
    default:
      data[j++] = data[i];
    };
  }

  return j;
}

/**
 * Decodes an input URL safe base64 encoded byte string.
 *
 * NOTE: To be used only for decoding URL safe base64 encoded
 * byte string.
 *
 * Arguments:
 *  @data : URL safe base64 encoded byte string.
 *  @len : Length of the input byte string.
 */
inline std::string base64_uri_decode(const char* data, size_t len)
{
  std::string uri_dec;
  uri_dec.resize(len + 4);

  size_t i = 0;

  for (; i < len; ++i) 
  {
    switch (data[i]) {
    case '-':
      uri_dec[i] = '+';
      break;
    case '_':
      uri_dec[i] = '/';
      break;
    default:
      uri_dec[i] = data[i];
    };
  }

  size_t trailer = 4 - (i % 4);
  if (trailer && trailer < 4) {
    while (trailer--) {
      uri_dec[i++] = '=';
    }
  }

  return base64_decode(uri_dec.c_str(), uri_dec.length());
}

} // END namespace jwt


#endif
