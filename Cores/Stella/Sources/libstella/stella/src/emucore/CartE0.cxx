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

#include "System.hxx"
#include "CartE0.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartridgeE0::CartridgeE0(const ByteBuffer& image, size_t size,
                         string_view md5, const Settings& settings,
                         size_t bsSize)
  : CartridgeEnhanced(image, size, md5, settings, bsSize)
{
  myBankShift = BANK_SHIFT;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeE0::reset()
{
  // Setup segments to some default banks
  if(randomStartBank())
  {
    bank(mySystem->randGenerator().next() % 8, 0);
    bank(mySystem->randGenerator().next() % 8, 1);
    bank(mySystem->randGenerator().next() % 8, 2);
  }
  else
  {
    bank(4, 0);
    bank(5, 1);
    bank(6, 2);
  }
  myBankChanged = true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeE0::checkSwitchBank(uInt16 address, uInt8)
{
  address &= ROM_MASK;

  // Switch banks if necessary
  if((address >= 0x0FE0) && (address <= 0x0FE7))
  {
    bank(address & 0x0007, 0);
    return true;
  }
  else if((address >= 0x0FE8) && (address <= 0x0FEF))
  {
    bank(address & 0x0007, 1);
    return true;
  }
  else if((address >= 0x0FF0) && (address <= 0x0FF7))
  {
    bank(address & 0x0007, 2);
    return true;
  }

  return false;
}
