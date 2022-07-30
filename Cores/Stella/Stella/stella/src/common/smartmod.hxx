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

#ifndef SMARTMOD_HXX
#define SMARTMOD_HXX

#include "bspf.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
template<unsigned base>
constexpr uInt8 smartmod(uInt8 x)
{
  return x % base;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
template<>
inline constexpr uInt8 smartmod<2>(uInt8 x)
{
  return x & 0x01;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
template<>
inline constexpr uInt8 smartmod<4>(uInt8 x)
{
  return x & 0x03;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
template<>
inline constexpr uInt8 smartmod<8>(uInt8 x)
{
  return x & 0x07;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
template<>
inline constexpr uInt8 smartmod<16>(uInt8 x)
{
  return x & 0x0F;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
template<>
inline constexpr uInt8 smartmod<32>(uInt8 x)
{
  return x & 0x1F;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
template<>
inline constexpr uInt8 smartmod<64>(uInt8 x)
{
  return x & 0x3F;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
template<>
inline constexpr uInt8 smartmod<128>(uInt8 x)
{
  return x & 0x7F;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
template<>
inline constexpr uInt8 smartmod<256>(uInt8 x)
{
  return x & 0xFF;
}

#endif // SMARTMOD_HXX
