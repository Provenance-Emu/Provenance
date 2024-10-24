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
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#include "Base.hxx"

namespace Common {

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string Base::toString(int value, Common::Base::Fmt outputBase)
{
  static char vToS_buf[32];  // NOLINT : One place where C-style is acceptable

  if(outputBase == Base::Fmt::_DEFAULT)
    outputBase = myDefaultBase;

  switch(outputBase)
  {
    case Base::Fmt::_2:     // base 2:  8 or 16 bits (depending on value)
    case Base::Fmt::_2_8:   // base 2:  1 byte (8 bits) wide
    case Base::Fmt::_2_16:  // base 2:  2 bytes (16 bits) wide
    {
      int places = (outputBase == Base::Fmt::_2_8 ||
                   (outputBase == Base::Fmt::_2 && value < 0x100)) ? 8 : 16;
      vToS_buf[places] = '\0';
      int bit = 1;
      while(--places >= 0) {
        if(value & bit) vToS_buf[places] = '1';
        else            vToS_buf[places] = '0';
        bit <<= 1;
      }
      break;
    }

    case Base::Fmt::_10:    // base 10: 3 or 5 bytes (depending on value)
      if(value > -0x100 && value < 0x100)
        std::ignore = std::snprintf(vToS_buf, 5, "%3d", static_cast<Int16>(value));
      else
        std::ignore = std::snprintf(vToS_buf, 6, "%5d", value);
      break;

    case Base::Fmt::_10_02:  // base 10: 2 digits (with leading zero)
      std::ignore = std::snprintf(vToS_buf, 3, "%02d", value);
      break;

    case Base::Fmt::_10_3:  // base 10: 3 digits
      std::ignore = std::snprintf(vToS_buf, 4, "%3d", value);
      break;

    case Base::Fmt::_10_4:  // base 10: 4 digits
      std::ignore = std::snprintf(vToS_buf, 5, "%4d", value);
      break;

    case Base::Fmt::_10_5:  // base 10: 5 digits
      std::ignore = std::snprintf(vToS_buf, 6, "%5d", value);
      break;

    case Base::Fmt::_10_6:  // base 10: 6 digits
      std::ignore = std::snprintf(vToS_buf, 7, "%6d", value);
      break;

    case Base::Fmt::_10_8:  // base 10: 8 digits
      std::ignore = std::snprintf(vToS_buf, 9, "%8d", value);
      break;

    case Base::Fmt::_16_1:  // base 16: 1 byte wide
      std::ignore = std::snprintf(
          vToS_buf, 2, hexUppercase() ? "%1X" : "%1x", value);
      break;
    case Base::Fmt::_16_2:  // base 16: 2 bytes wide
      std::ignore = std::snprintf(
          vToS_buf, 3, hexUppercase() ? "%02X" : "%02x", value);
      break;
    case Base::Fmt::_16_2_2:
      std::ignore = std::snprintf(
          vToS_buf, 6, hexUppercase() ? "%02X.%02X" : "%02x.%02x",
          value >> 8, value & 0xff );
      break;
    case Base::Fmt::_16_3_2:
      std::ignore = std::snprintf(
          vToS_buf, 7, hexUppercase() ? "%03X.%02X" : "%03x.%02x",
          value >> 8, value & 0xff );
      break;
    case Base::Fmt::_16_4:  // base 16: 4 bytes wide
      std::ignore = std::snprintf(
          vToS_buf, 5, hexUppercase() ? "%04X" : "%04x", value);
      break;
    case Base::Fmt::_16_8:  // base 16: 8 bytes wide
      std::ignore = std::snprintf(
          vToS_buf, 9, hexUppercase() ? "%08X" : "%08x", value);
      break;

    case Base::Fmt::_16:    // base 16: 2, 4, 8 bytes (depending on value)
    default:
      if(value < 0x100)
        std::ignore = std::snprintf(
            vToS_buf, 3, hexUppercase() ? "%02X" : "%02x", value);
      else if(value < 0x10000)
        std::ignore = std::snprintf(
            vToS_buf, 5, hexUppercase() ? "%04X" : "%04x", value);
      else
        std::ignore = std::snprintf(
            vToS_buf, 9, hexUppercase() ? "%08X" : "%08x", value);
      break;
  }

  return {vToS_buf};
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Base::Fmt Base::myDefaultBase = Base::Fmt::_16;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
std::ios_base::fmtflags Base::myHexflags = std::ios_base::hex;  // NOLINT

} // namespace Common
