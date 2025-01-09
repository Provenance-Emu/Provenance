//============================================================================
//
//  BBBBB    SSSS   PPPPP   FFFFFF
//  BB  BB  SS  SS  PP  PP  FF
//  BB  BB  SS      PP  PP  FF
//  BBBBB    SSSS   PPPPP   FFFF    --  "Brad's Simple Portability Framework"
//  BB  BB      SS  PP      FF
//  BB  BB  SS  SS  PP      FF
//  BBBBB    SSSS   PP      FF
//
// Copyright (c) 1995-2024 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#ifndef BSPF_HXX
#define BSPF_HXX

/**
  This file defines various basic data types and preprocessor variables
  that need to be defined for different operating systems.

  @author Bradford W. Mott and Stephen Anthony
*/

#include <climits>
#include <cstdint>
// Types for 8/16/32/64-bit signed and unsigned integers
using Int8   = int8_t;
using uInt8  = uint8_t;
using Int16  = int16_t;
using uInt16 = uint16_t;
using Int32  = int32_t;
using uInt32 = uint32_t;
using Int64  = int64_t;
using uInt64 = uint64_t;

// The following code should provide access to the standard C++ objects and
// types: cout, cerr, string, ostream, istream, etc.
#include <array>
#include <algorithm>
#include <iostream>
#include <fstream>
#include <functional>
#include <iomanip>
#include <memory>
#include <string>
#include <string_view>
#include <charconv>
#include <sstream>
#include <cstring>
#include <cctype>
#include <cstdio>
#include <ctime>
#include <utility>
#include <vector>

using std::cin;
using std::cout;
using std::cerr;
using std::string;
using std::string_view;
using std::istream;
using std::ostream;
using std::fstream;
using std::iostream;
using std::ostringstream;
using std::istringstream;
using std::stringstream;
using std::unique_ptr;
using std::shared_ptr;
using std::make_unique;
using std::make_shared;
using std::array;
using std::vector;
using std::runtime_error;

// Common array types
using IntArray = std::vector<Int32>;
using uIntArray = std::vector<uInt32>;
using BoolArray = std::vector<bool>;
using ByteArray = std::vector<uInt8>;
using ShortArray = std::vector<uInt16>;
using StringList = std::vector<std::string>;
using ByteBuffer = std::unique_ptr<uInt8[]>;  // NOLINT
using DWordBuffer = std::unique_ptr<uInt32[]>;  // NOLINT

// We use KB a lot; let's make a literal for it
constexpr size_t operator "" _KB(unsigned long long size)
{
  return static_cast<size_t>(size * 1024);
}

// Output contents of a vector
template<typename T>
std::ostream& operator<< (std::ostream& out, const std::vector<T>& v) {
  for(const auto& elem: v)
    out << elem << " ";
  return out;
}

static const string EmptyString("");

// This is defined by some systems, but Stella has other uses for it
#undef PAGE_SIZE
#undef PAGE_MASK

// Adaptable refresh is currently not available on MacOS
// In the future, this may expand to other systems
#if !defined(BSPF_MACOS)
  #define ADAPTABLE_REFRESH_SUPPORT
#endif

namespace BSPF
{
  static constexpr float PI_f = 3.141592653589793238462643383279502884F;
  static constexpr double PI_d = 3.141592653589793238462643383279502884;

  // CPU architecture type
  // This isn't complete yet, but takes care of all the major platforms
  #if defined(__i386__) || defined(_M_IX86)
    static const string ARCH = "i386";
  #elif defined(__x86_64__) || defined(_WIN64)
    static const string ARCH = "x86_64";
  #elif defined(__powerpc__) || defined(__ppc__)
    static const string ARCH = "ppc";
  #elif defined(__arm__) || defined(__thumb__)
    static const string ARCH = "arm32";
  #elif defined(__aarch64__)
    static const string ARCH = "arm64";
  #else
    static const string ARCH = "NOARCH";
  #endif

  #if defined(BSPF_WINDOWS) || defined(__WIN32__)
    #define FORCE_INLINE __forceinline
  #else
    #define FORCE_INLINE inline __attribute__((always_inline))
  #endif

  // Get next power of two greater than or equal to the given value
  inline constexpr size_t nextPowerOfTwo(size_t size) {
    if(size < 2) return 1;
    size_t power2 = 1;
    while(power2 < size)
      power2 <<= 1;
    return power2;
  }

  // Get next multiple of the given value
  // Note that this only works when multiple is a power of two
  inline constexpr size_t nextMultipleOf(size_t size, size_t multiple) {
    return (size + multiple - 1) & ~(multiple - 1);
  }

  // Make 2D-arrays using std::array less verbose
  template<typename T, size_t ROW, size_t COL>
  using array2D = std::array<std::array<T, COL>, ROW>;

  // Combines 'max' and 'min', and clamps value to the upper/lower value
  // if it is outside the specified range
  template<typename T> inline constexpr T clamp(T val, T lower, T upper)
  {
    return (val < lower) ? lower : (val > upper) ? upper : val;
  }
  template<typename T> inline constexpr void clamp(T& val, T lower, T upper, T setVal)
  {
    if(val < lower || val > upper)  val = setVal;
  }
  template<typename T> inline constexpr T clampw(T val, T lower, T upper)
  {
    return (val < lower) ? upper : (val > upper) ? lower : val;
  }

  // Test whether a container contains the given value
  template<typename Container>
  bool contains(const Container& c, typename Container::const_reference elem) {
    return std::find(c.cbegin(), c.cend(), elem) != c.end();
  }

  // Convert string to given case
  inline const string& toUpperCase(string& s)
  {
    transform(s.begin(), s.end(), s.begin(), ::toupper);
    return s;
  }
  inline const string& toLowerCase(string& s)
  {
    transform(s.begin(), s.end(), s.begin(), ::tolower);
    return s;
  }

  // Convert string to integer, using default value on any error
  template<int BASE = 10>
  inline int stoi(string_view s, const int defaultValue = 0)
  {
    try {
      int i{};
      s = s.substr(s.find_first_not_of(" "));
      auto result = std::from_chars(s.data(), s.data() + s.size(), i, BASE);
      return result.ec == std::errc() ? i : defaultValue;
    }
    catch(...) { return defaultValue; }
  }

  // Compare two strings (case insensitive)
  // Return negative, zero, positive result for <,==,> respectively
  static constexpr int compareIgnoreCase(string_view s1, string_view s2)
  {
    // Only compare up to the length of the shorter string
    const auto maxsize = std::min(s1.size(), s2.size());
    for(size_t i = 0; i < maxsize; ++i)
      if(toupper(s1[i]) != toupper(s2[i]))
        return toupper(s1[i]) - toupper(s2[i]);

    // Otherwise the length of the string takes priority
    return static_cast<int>(s1.size() - s2.size());
  }

  // Test whether two strings are equal (case insensitive)
  inline constexpr bool equalsIgnoreCase(string_view s1, string_view s2)
  {
    return s1.size() == s2.size() ? (compareIgnoreCase(s1, s2) == 0) : false;
  }

  // Test whether the first string starts with the second one (case insensitive)
  inline constexpr bool startsWithIgnoreCase(string_view s1, string_view s2)
  {
    if(s1.size() >= s2.size())
      return compareIgnoreCase(s1.substr(0, s2.size()), s2) == 0;

    return false;
  }

  // Test whether the first string ends with the second one (case insensitive)
  inline constexpr bool endsWithIgnoreCase(string_view s1, string_view s2)
  {
    if(s1.size() >= s2.size())
      return compareIgnoreCase(s1.substr(s1.size() - s2.size()), s2) == 0;

    return false;
  }

  // Find location (if any) of the second string within the first,
  // starting from 'startpos' in the first string
  static size_t findIgnoreCase(string_view s1, string_view s2, size_t startpos = 0)
  {
    const auto pos = std::search(s1.cbegin()+startpos, s1.cend(),
      s2.cbegin(), s2.cend(), [](char ch1, char ch2) {
        return toupper(static_cast<uInt8>(ch1)) == toupper(static_cast<uInt8>(ch2));
      });
    return pos == s1.cend() ? string::npos : pos - (s1.cbegin()+startpos);
  }

  // Test whether the first string contains the second one (case insensitive)
  inline bool containsIgnoreCase(string_view s1, string_view s2)
  {
    return findIgnoreCase(s1, s2) != string::npos;
  }

  // Test whether the first string matches the second one (case insensitive)
  // - the first character must match
  // - the following characters must appear in the order of the first string
  inline bool matchesIgnoreCase(string_view s1, string_view s2)
  {
    if(startsWithIgnoreCase(s1, s2.substr(0, 1)))
    {
      size_t pos = 1;
      for(uInt32 j = 1; j < s2.size(); ++j)
      {
        const size_t found = findIgnoreCase(s1, s2.substr(j, 1), pos);
        if(found == string::npos)
          return false;
        pos += found + 1;
      }
      return true;
    }
    return false;
  }

  // Test whether the first string matches the second one
  //  (case sensitive for upper case characters in second string, except first one)
  // - the first character must match
  // - the following characters must appear in the order of the first string
  inline bool matchesCamelCase(string_view s1, string_view s2)
  {
    // skip leading '_' for matching
    const uInt32 ofs = (s1[0] == '_' && s2[0] == '_') ? 1 : 0;

    if(startsWithIgnoreCase(s1.substr(ofs), s2.substr(ofs, 1)))
    {
      size_t lastUpper = ofs, pos = 1;

      for(uInt32 j = 1 + ofs; j < s2.size(); ++j)
      {
        if(std::isupper(s2[j]))
        {
          const size_t found = s1.find_first_of(s2[j], pos + ofs);

          if(found == string::npos)
            return false;
          // make sure no upper case characters are skipped
          for(size_t k = lastUpper + 1; k < found; ++k)
            if(isupper(s1[k]))
              return false;

          pos = found + 1;
          lastUpper = found;
        }
        else
        {
          const size_t found = findIgnoreCase(s1, s2.substr(j, 1), pos + ofs);

          if(found == string::npos)
            return false;

          pos += found + 1;
        }
      }
      return true;
    }
    return false;
  }

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Search if string contains pattern including '?' as joker.
  // @param str      The searched string
  // @param pattern  The pattern to search for
  // @return  Position of pattern in string.
  inline size_t matchWithJoker(string_view str, string_view pattern)
  {
    if(str.length() >= pattern.length())
    {
      // optimize a bit
      if(pattern.find('?') != string::npos)
      {
        for(size_t pos = 0; pos < str.length() - pattern.length() + 1; ++pos)
        {
          bool found = true;

          for(size_t i = 0; found && i < pattern.length(); ++i)
            if(pattern[i] != str[pos + i] && pattern[i] != '?')
              found = false;

          if(found)
            return pos;
        }
      }
      else
        return str.find(pattern);
    }
    return string::npos;
  }

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Search if string contains pattern including wildcard '*'
  // and '?' as joker.
  // @param str      The searched string
  // @param pattern  The pattern to search for
  // @return  True if pattern was found.
  inline bool matchWithWildcards(string_view str, string_view pattern)
  {
    string pat{pattern};  // TODO: don't use copy

    // remove leading and trailing '*'
    size_t i = 0;
    while(pat[i++] == '*');
    pat = pat.substr(i - 1);

    i = pat.length();
    while(pat[--i] == '*');
    pat.erase(i + 1);

    // Search for first '*'
    const size_t pos = pat.find('*');

    if(pos != string::npos)
    {
      // '*' found, split pattern into left and right part, search recursively
      const string leftPat = pat.substr(0, pos);
      const string rightPat = pat.substr(pos + 1);
      const size_t posLeft = matchWithJoker(str, leftPat);

      if(posLeft != string::npos)
        return matchWithWildcards(str.substr(pos + posLeft), rightPat);
      else
        return false;
    }
    // no further '*' found
    return matchWithJoker(str, pat) != string::npos;
  }

  // Modify 'str', replacing all occurrences of 'from' with 'to'
  inline void replaceAll(string& str, string_view from, string_view to)
  {
    if(from.empty()) return;
    size_t start_pos = 0;
    while((start_pos = str.find(from, start_pos)) != string::npos)
    {
      str.replace(start_pos, from.length(), to);
      start_pos += to.length(); // In case 'to' contains 'from',
                                // like replacing 'x' with 'yx'
    }
  }

  // Trim leading and trailing whitespace from a string
  inline string trim(string_view str)
  {
    const auto first = str.find_first_not_of(' ');
    return (first == string::npos) ? EmptyString :
            string{str.substr(first, str.find_last_not_of(' ')-first+1)};
  }

  // C++11 way to get local time
  // Equivalent to the C-style localtime() function, but is thread-safe
  inline std::tm localTime()
  {
    const auto currtime = std::time(nullptr);
    std::tm tm_snapshot;
  #if (defined BSPF_WINDOWS || defined __WIN32__) && (!defined __GNUG__ || defined __MINGW32__)
    localtime_s(&tm_snapshot, &currtime);
  #else
    localtime_r(&currtime, &tm_snapshot);
  #endif
    return tm_snapshot;
  }

  inline bool isWhiteSpace(const char c)
  {
    static constexpr string_view spaces{" ,.;:+-*&/\\'"};
    return spaces.find(c) != string_view::npos;
  }
} // namespace BSPF

#endif
