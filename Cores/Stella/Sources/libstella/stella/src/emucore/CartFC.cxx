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

#include "CartFC.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartridgeFC::CartridgeFC(const ByteBuffer& image, size_t size,
                         string_view md5, const Settings& settings,
                         size_t bsSize)
  : CartridgeEnhanced(image, size, md5, settings,
                      bsSize == 0 ? BSPF::nextPowerOfTwo(size) : bsSize)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeFC::reset()
{
  CartridgeEnhanced::reset();

  myTargetBank = 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeFC::checkSwitchBank(uInt16 address, uInt8)
{
  // Switch banks if necessary
  if(address == 0x1FFC)
  {
    // Trigger the bank switch
    bank(myTargetBank);
    return true;
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeFC::poke(uInt16 address, uInt8 value)
{
  address &= myBankMask;

  // Switch banks if necessary
  switch (address)
  {
    case 0x0FF8:
      // Set the two lowest bits of target 4k bank
      myTargetBank = value & 0b11;
      break;

    case 0x0FF9:
      // Set the high bits of target 4k bank
      if (value << 2 < romBankCount())
      {
        myTargetBank += value << 2;
        myTargetBank %= romBankCount();
      }
      else
        // special handling when both values are identical (e.g. 4/4 or 5/5)
        myTargetBank = value % romBankCount();
      break;

    default:
      checkSwitchBank(address, 0);
  }
  return false;
}
