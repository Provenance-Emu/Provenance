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
// Copyright (c) 1995-2022 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#ifndef BASE_HXX
#define BASE_HXX

#include <iostream>
#include <iomanip>

#include "bspf.hxx"

namespace Common {

/**
  This class implements several functions for converting integer data
  into strings in multiple bases, with different formats (# of characters,
  upper/lower-case, etc).

  @author  Stephen Anthony
*/
class Base
{
  public:
    // The base to use for conversion from integers to strings
    // Note that the actual number of places will be determined by
    // the magnitude of the value itself in the general case
    enum class Fmt {
      _16,      // base 16: 2, 4, 8 bytes (depending on value)
      _16_1,    // base 16: 1 byte wide
      _16_2,    // base 16: 2 bytes wide
      _16_2_2,  // base 16: fractional value shown as xx.xx
      _16_3_2,  // base 16: fractional value shown as xxx.xx
      _16_4,    // base 16: 4 bytes wide
      _16_8,    // base 16: 8 bytes wide
      _10,      // base 10: 3 or 5 bytes (depending on value)
      _10_02,   // base 10: 02 digits
      _10_3,    // base 10: 3 digits
      _10_4,    // base 10: 4 digits
      _10_5,    // base 10: 5 digits
      _10_6,    // base 10: 6 digits
      _10_8,    // base 10: 8 digits
      _2,       // base 2:  8 or 16 bits (depending on value)
      _2_8,     // base 2:  1 byte (8 bits) wide
      _2_16,    // base 2:  2 bytes (16 bits) wide
      _DEFAULT
    };

  public:
    /** Get/set the number base when parsing numeric values */
    static void setFormat(Base::Fmt base) { myDefaultBase = base; }
    static Base::Fmt format()             { return myDefaultBase; }

    /** Get/set HEX output to be upper/lower case */
    static void setHexUppercase(bool enable) {
      if(enable) myHexflags |= std::ios_base::uppercase;
      else       myHexflags &= ~std::ios_base::uppercase;
    }
    static bool hexUppercase() { return myHexflags & std::ios_base::uppercase; }

    /** Output HEX digits in 0.5/1/2/4 byte format */
    static inline std::ostream& HEX1(std::ostream& os) {
      os.flags(myHexflags);
      return os << std::setw(1);
    }
    static inline std::ostream& HEX2(std::ostream& os) {
      os.flags(myHexflags);
      return os << std::setw(2) << std::setfill('0');
    }
    static inline std::ostream& HEX3(std::ostream& os)
    {
      os.flags(myHexflags);
      return os << std::setw(3) << std::setfill('0');
    }
    static inline std::ostream& HEX4(std::ostream& os) {
      os.flags(myHexflags);
      return os << std::setw(4) << std::setfill('0');
    }
    static inline std::ostream& HEX8(std::ostream& os) {
      os.flags(myHexflags);
      return os << std::setw(8) << std::setfill('0');
    }

    /** Convert integer to a string in the given base format */
    static string toString(int value,
      Common::Base::Fmt outputBase = Common::Base::Fmt::_DEFAULT);

  private:
    // Default format to use when none is specified
    static Base::Fmt myDefaultBase;

    // Upper or lower case for HEX digits
    static std::ios_base::fmtflags myHexflags;

  private:
    // Following constructors and assignment operators not supported
    Base() = delete;
    Base(const Base&) = delete;
    Base(Base&&) = delete;
    Base& operator=(const Base&) = delete;
    Base& operator=(Base&&) = delete;
};

} // Namespace Common

#endif
