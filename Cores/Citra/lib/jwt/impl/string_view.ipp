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

#ifndef JWT_STRING_VIEW_IPP
#define JWT_STRING_VIEW_IPP

namespace jwt {

template <typename CharT, typename Traits>
auto basic_string_view<CharT, Traits>::find(
    const CharT* str, 
    size_type pos, 
    size_type n) const noexcept -> size_type
{
  assert (str);
  assert (n < (len_ - pos) && "Comparison size out of bounds");

  if (n == 0) {
    return pos <= len_ ? pos : npos;
  }
  if (n <= len_) {
    for (; pos <= (len_ - n); ++pos) {
      if (traits_type::eq(data_[pos], str[0]) &&
          traits_type::compare(data_ + pos + 1, str + 1, n - 1) == 0) {
        return pos;
      }
    }
  }

  return npos;
}

template <typename CharT, typename Traits>
auto basic_string_view<CharT, Traits>::rfind(
    const CharT* str,
    size_type pos,
    size_type n) const noexcept -> size_type
{
  assert (str);
  assert (pos < len_ && "Position out of bounds");

  if (n <= len_) {
    pos = std::min(len_ - n, pos);
    do {
      if (traits_type::eq(data_[pos], str[0]) &&
          traits_type::compare(data_ + pos + 1, str + 1, n - 1) == 0) {
        return pos;
      }
    } while (pos-- != 0);
  }

  return npos;
}

template <typename CharT, typename Traits>
auto basic_string_view<CharT, Traits>::find(
    const CharT ch, 
    size_type pos) const noexcept -> size_type
{
  if (pos < len_) {
    for (size_type i = pos; i < len_; ++i) {
      if (traits_type::eq(data_[i], ch)) return i;
    }
  }
  return npos;
}

template <typename CharT, typename Traits>
auto basic_string_view<CharT, Traits>::rfind(
    const CharT ch,
    size_type pos) const noexcept -> size_type
{
  if (pos < len_) {
    do {
      if (traits_type::eq(data_[pos], ch)) {
        return pos;
      }
    } while (pos-- != 0);
  }

  return npos;
}

template <typename CharT, typename Traits>
auto basic_string_view<CharT, Traits>::find_first_of(
    const CharT* str, 
    size_type pos, 
    size_type count) const noexcept -> size_type
{
  assert (str);

  for (size_type i = pos; i < len_; ++i) {
    auto p = traits_type::find(str, count, data_[i]);
    if (p) {
      return i;
    }
  }

  return npos;
}

template <typename CharT, typename Traits>
auto basic_string_view<CharT, Traits>::find_last_of(
    const CharT* str, 
    size_type pos, 
    size_type count) const noexcept -> size_type
{
  assert (str);
  assert (pos < len_ && "Position must be within the bounds of the view");
  size_type siz = len_;

  if (siz && count) {
    siz = std::min(pos, siz);

    do {
      auto p = traits_type::find(str, count, data_[siz]);
      if (p) {
        return siz;
      }
    } while (siz-- != 0);
  }

  return npos;
}

template <typename CharT, typename Traits>
auto basic_string_view<CharT, Traits>::find_first_not_of(
    const CharT* str,
    size_type pos,
    size_type n) const noexcept -> size_type
{
  assert (str);
  assert (pos < len_&& "Position must be within the bounds of the view");

  for (size_type i = pos; i < len_; ++i)
  {
    auto p = traits_type::find(str, n, data_[i]);
    if (!p) return i;
  }

  return npos;
}

template <typename CharT, typename Traits>
auto basic_string_view<CharT, Traits>::find_last_not_of(
    const CharT* str,
    size_type pos,
    size_type n) const noexcept -> size_type
{
  assert (str);
  assert (pos < len_ && "Position must be within the bounds of the view");

  do {
    for (size_type i = 0; i < n; ++i) {
      if (!traits_type::eq(data_[pos], str[i])) return pos;
    }
  } while (pos-- != 0);

  return npos;
}

template <typename CharT, typename Traits>
auto basic_string_view<CharT, Traits>::find_first_not_of(
    CharT ch,
    size_type pos) const noexcept -> size_type
{
  assert (pos < len_&& "Position must be within the bounds of the view");

  for (size_type i = pos; i < len_; ++i) {
    if (!traits_type::eq(data_[i], ch)) return i;
  }

  return npos;
}

template <typename CharT, typename Traits>
auto basic_string_view<CharT, Traits>::find_last_not_of(
    CharT ch,
    size_type pos) const noexcept -> size_type
{
  assert (pos < len_ && "Position must be within the bounds of the view");

  do {
    if (!traits_type::eq(data_[pos], ch)) return pos;
  } while (pos-- != 0);

  return npos;
}

// Comparison Operators

template <typename CharT, typename Traits>
bool operator== (basic_string_view<CharT, Traits> a,
                 basic_string_view<CharT, Traits> b) noexcept
{
  if (a.length() != b.length()) return false;
  using traits_type = typename basic_string_view<CharT, Traits>::traits_type;
  using size_type = typename basic_string_view<CharT, Traits>::size_type;

  for (size_type i = 0; i < a.length(); ++i) {
    if (!traits_type::eq(a[i], b[i])) return false;
  }

  return true;
}

template <typename CharT, typename Traits>
bool operator!= (basic_string_view<CharT, Traits> a,
                 basic_string_view<CharT, Traits> b) noexcept
{
  return !( a == b );
}

template <typename CharT, typename Traits>
bool operator< (basic_string_view<CharT, Traits> a,
                basic_string_view<CharT, Traits> b) noexcept
{
  return a.compare(b) < 0;
}

template <typename CharT, typename Traits>
bool operator> (basic_string_view<CharT, Traits> a,
                basic_string_view<CharT, Traits> b) noexcept
{
  return a.compare(b) > 0;
}

template <typename CharT, typename Traits>
bool operator<= (basic_string_view<CharT, Traits> a,
                 basic_string_view<CharT, Traits> b) noexcept
{
  return a.compare(b) <= 0;
}

template <typename CharT, typename Traits>
bool operator>= (basic_string_view<CharT, Traits> a,
                 basic_string_view<CharT, Traits> b) noexcept
{
  return a.compare(b) >= 0;
}

template <typename CharT, typename Traits>
std::ostream& operator<< (std::ostream& os, basic_string_view<CharT, Traits> sv)
{
  os.write(sv.data(), sv.length());
  return os;
}

namespace {

/*
 * Copy of gcc implementation of murmurhash
 * hash_bytes.cc
 */

inline size_t
unaligned_load(const char* p) noexcept
{
  std::size_t result;
  std::memcpy(&result, p, sizeof(result));
  return result;
}

inline size_t
hash_bytes(const void* ptr, size_t len, size_t seed) noexcept
{
  const size_t m = 0x5bd1e995;
  size_t hash = seed ^ len;
  const char* buf = static_cast<const char*>(ptr);

  // Mix 4 bytes at a time into the hash.
  while(len >= 4)
  {
    size_t k = unaligned_load(buf);
    k *= m;
    k ^= k >> 24;
    k *= m;
    hash *= m;
    hash ^= k;
    buf += 4;
    len -= 4;
  }

  // Handle the last few bytes of the input array.
  switch(len)
  {
  case 3:
    hash ^= static_cast<unsigned char>(buf[2]) << 16;
    //FALLTHROUGH 
  case 2:
    hash ^= static_cast<unsigned char>(buf[1]) << 8;
    //FALLTHROUGH
  case 1:
    hash ^= static_cast<unsigned char>(buf[0]);
    hash *= m;
  };

  // Do a few final mixes of the hash.
  hash ^= hash >> 13;
  hash *= m;
  hash ^= hash >> 15;
  return hash;
}
}

} // END namespace jwt

/// Provide a hash specialization
namespace std {
  template <>
  struct hash<jwt::string_view>
  {
    size_t operator()(const jwt::string_view& sv) const noexcept
    {
      return jwt::hash_bytes((void*)sv.data(), sv.length(), static_cast<size_t>(0xc70f6907UL));
    }
  };
}

#endif
