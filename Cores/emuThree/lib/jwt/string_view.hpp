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

#ifndef JWT_STRING_VIEW_HPP
#define JWT_STRING_VIEW_HPP

#if defined(__cpp_lib_string_view)

#include <string_view>

namespace jwt {
  using string_view = std::string_view;
}

#else // defined(__cpp_lib_string_view)

#include <limits>
#include <string>
#include <cassert>

namespace jwt {

/*
 * Implements c++17 string_view.
 * Could have used boost::string_ref, but wanted to 
 * keep boost dependency off from this library.
 */

template <
  typename CharT, 
  typename Traits = std::char_traits<CharT>
>
class basic_string_view
{
public: // Member Types
  using traits_type = std::char_traits<CharT>;
  using value_type = CharT;
  using pointer = const CharT*;
  using const_pointer = const CharT*;
  using reference = const CharT&;
  using const_reference = const CharT&;
  using iterator = const CharT*;
  using const_iterator = const CharT*;
  using reverse_iterator = std::reverse_iterator<iterator>;
  using const_reverse_iterator = std::reverse_iterator<const_iterator>;
  using size_type = size_t;
  using difference_type = std::ptrdiff_t;

  static constexpr size_type npos = size_type(-1);

public: // 'tors
  /// The default constructor;
  basic_string_view() = default;

  /// Construct from string literal
  basic_string_view(const CharT* str) noexcept
    : data_(str)
    , len_(str ? traits_type::length(str) : 0)
  {
  }

  /// Construct from CharT pointer and provided length
  basic_string_view(const CharT* p, size_type len) noexcept
    : data_(p)
    , len_(len)
  {
  }

  /// Construct from std::string
  template <typename Allocator>
  basic_string_view(
      const std::basic_string<CharT, Traits, Allocator>& str) noexcept
    : data_(str.data())
    , len_(str.length())
  {
  }

  /// Copy constructor
  basic_string_view(const basic_string_view&) = default;

  /// Assignment operator
  basic_string_view& operator=(const basic_string_view&) = default;

  /// Destructor
  ~basic_string_view()
  {
    data_ = nullptr;
    len_ = 0;
  }

public: // Exposed APIs
  /// Iterator Member Functions

  iterator begin() const noexcept { return data_;        }
  iterator end()   const noexcept { return data_ + len_; }

  iterator rbegin() const noexcept { return reverse_iterator(end());   }
  iterator rend()   const noexcept { return reverse_iterator(begin()); }

  const_iterator cbegin() const noexcept { return begin(); }
  const_iterator cend()   const noexcept { return end();   }

  const_iterator crbegin() const noexcept { return rbegin(); }
  const_iterator crend()   const noexcept { return rend();   }

  /// Capacity Member Functions

  size_type length() const noexcept { return len_; }
  size_type size()   const noexcept { return len_; }

  size_type max_size() const noexcept
  {
    return (npos - sizeof(size_type) - sizeof(void*))
      / sizeof(value_type) / 4;
  }

  bool empty() const noexcept { return len_ == 0; }

  /// Element Access Member Functions
  const_reference operator[](size_type idx) const noexcept
  {
    assert(idx < len_ && "string_view subscript out of range");
    return data_[idx];
  }

  // NOTE: 'at' not supported
  //CharT at(size_type idx) const;

  const_reference front() const noexcept
  {
    return data_[0];
  }

  const_reference back() const noexcept
  {
    return data_[len_ - 1];
  }

  const_pointer data() const noexcept
  {
    return data_;
  }

  /// Modifier Member Functions
  void remove_prefix(size_type n) noexcept
  {
    assert (n < len_ && "Data would point out of bounds");
    data_ += n;
    len_ -= n;
  }

  void remove_suffix(size_type n) noexcept
  {
    assert (n < len_ && "Suffix length more than data length");
    len_ -= n;
  }

  void swap(basic_string_view& other)
  {
    std::swap(data_, other.data_);
    std::swap(len_, other.len_);
  }

  /// String Operation Member Functions

  template <typename Allocator>
  explicit operator std::basic_string<CharT, Traits, Allocator>() const
  {
    return {data_, len_};
  }

  // NOTE: Does not throw 
  size_type copy(CharT* dest, size_type n, size_type pos = 0) const noexcept
  {
    assert (pos < len_ && n < len_);
    size_type to_copy = std::min(n, len_ - pos);

    for (size_type i = 0; i < to_copy; i++) {
      dest[i] = data_[i + pos];
    }

    return to_copy;
  }

  // NOTE: Does not throw
  basic_string_view substr(size_type pos, size_type n = npos) const noexcept
  {
    assert (pos < len_ && "Start position should be less than length of the view");
    assert (n == npos ? 1 : (n - pos) < len_ && 
        "Substring length asked for is more than the view length");

    if (n == npos) n = len_;

    return basic_string_view{data_ + pos, n};
  }

  /// Comparison Member Functions
  int compare(const basic_string_view& other) const noexcept
  {
    int ret = traits_type::compare(data_, other.data_, std::min(len_, other.len_));
    if (ret == 0) {
      ret = compare_length(len_, other.len_);
    }
    return ret;
  }

  int compare(size_type pos, size_type n, basic_string_view other) const noexcept
  {
    return substr(pos, n).compare(other);
  }

  int compare(const CharT* str) const noexcept
  {
    return compare(basic_string_view{str});
  }

  int compare(size_type pos, size_type n, const CharT* str) const noexcept
  {
    return compare(pos, n, basic_string_view{str});
  }

  int compare(size_type pos, size_type n1, const CharT* str, size_type n2) const noexcept
  {
    return compare(pos, n1, basic_string_view{str, n2});
  }

  /// Find operations
  size_type find(const CharT* str, size_type pos, size_type n) const noexcept;

  size_type find(const CharT ch, size_type pos) const noexcept;

  size_type find(basic_string_view sv, size_type pos = 0) const noexcept
  {
    return find(sv.data(), pos, sv.length());
  }

  size_type find(const CharT* str, size_type pos = 0) const noexcept
  {
    return find(str, pos, traits_type::length(str));
  }

  size_type rfind(const CharT* str, size_type pos, size_type n) const noexcept;

  size_type rfind(const CharT ch, size_type pos) const noexcept;

  size_type rfind(basic_string_view sv, size_type pos = 0) const noexcept
  {
    return rfind(sv.data(), pos, sv.length());
  }

  size_type rfind(const CharT* str, size_type pos = 0) const noexcept
  {
    return rfind(str, pos, traits_type::length(str));
  }

  size_type find_first_of(const CharT* str, size_type pos, size_type count) const noexcept;

  size_type find_first_of(basic_string_view str, size_type pos = 0) const noexcept
  {
    return find_first_of(str.data(), pos, str.length());
  }

  size_type find_first_of(CharT ch, size_type pos = 0) const noexcept
  {
    return find(ch, pos);
  }

  size_type find_first_of(const CharT* str, size_type pos = 0) const noexcept
  {
    return find_first_of(str, pos, traits_type::length(str));
  }

  size_type find_last_of(const CharT* str, size_type pos, size_type count) const noexcept;

  size_type find_last_of(basic_string_view str, size_type pos = npos) const noexcept
  {
    return find_last_of(str.data(), (pos == npos ? len_ - 1 : pos), str.length());
  }

  size_type find_last_of(CharT ch, size_type pos = npos) const noexcept
  {
    return rfind(ch, pos == npos ? len_ - 1 : pos);
  }

  size_type find_last_of(const CharT* str, size_type pos = npos) const noexcept
  {
    return find_last_of(str, (pos == npos ? len_ - 1 : pos), traits_type::length(str));
  }

  size_type find_first_not_of(const CharT* str, size_type pos, size_type n) const noexcept;

  size_type find_first_not_of(CharT ch, size_type pos) const noexcept;

  size_type find_first_not_of(basic_string_view str, size_type pos = 0) const noexcept
  {
    return find_first_not_of(str.data(), pos, str.length());
  }

  size_type find_first_not_of(const CharT* str, size_type pos = 0) const noexcept
  {
    return find_first_not_of(str, pos, traits_type::length(str));
  }

  size_type find_last_not_of(const CharT* str, size_type pos, size_type n) const noexcept;

  size_type find_last_not_of(CharT ch, size_type pos) const noexcept;

  size_type find_last_not_of(basic_string_view str, size_type pos = npos) const noexcept
  {
    return find_last_not_of(str.data(), (pos == npos ? len_ - 1 : pos), str.length());
  }

  size_type find_last_not_of(const CharT* str, size_type pos = npos) const noexcept
  {
    return find_last_not_of(str, (pos == npos ? len_ - 1 : pos), traits_type::length(str));
  }

  /// Comparison operators Member Functions
  /*
  friend bool operator== (basic_string_view a, basic_string_view b) noexcept;

  friend bool operator!= (basic_string_view a, basic_string_view b) noexcept;

  friend bool operator< (basic_string_view a, basic_string_view b) noexcept;

  friend bool operator> (basic_string_view a, basic_string_view b) noexcept;

  friend bool operator<= (basic_string_view a, basic_string_view b) noexcept;

  friend bool operator>= (basic_string_view a, basic_string_view b) noexcept;
  */

private: // private implementations

  static constexpr int compare_length(size_type n1, size_type n2) noexcept
  {
    return static_cast<difference_type>(n1 - n2) > std::numeric_limits<int>::max()
      ? std::numeric_limits<int>::max()
      : static_cast<difference_type>(n1 - n2) < std::numeric_limits<int>::min()
        ? std::numeric_limits<int>::min()
        : static_cast<int>(n1 - n2)
      ;
  }

private:
  // This is what view is basically...
  const char* data_ = nullptr;
  size_type len_ = 0;
};


/// Helper typedef
using string_view = basic_string_view<char>;


} // END namespace jwt

#include "jwt/impl/string_view.ipp"

#endif // defined(__cpp_lib_string_view)

#endif
