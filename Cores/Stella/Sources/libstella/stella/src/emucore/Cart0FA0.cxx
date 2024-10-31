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
#include "Cart0FA0.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Cartridge0FA0::Cartridge0FA0(const ByteBuffer& image, size_t size,
    string_view md5, const Settings& settings)
  : CartridgeEnhanced(image, size, md5, settings, 8_KB)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Cartridge0FA0::install(System& system)
{
  CartridgeEnhanced::install(system);

  // Get the page accessing methods for the hot spots since they overlap
  // areas within the TIA we'll need to forward requests to the TIA
  myHotSpotPageAccess = mySystem->getPageAccess(0x06a0);

  // Set the page accessing methods for the hot spots
  const System::PageAccess access(this, System::PageAccessType::READ);
  // Map all potential addresses
  // - A11 and A8 are not connected to RIOT
  // - A10, A9 and A7 are the fixed part of the hotspot address
  // - A6 and A5 determine bank
  for(uInt16 a11 = 0; a11 <= 1; ++a11)
  {
    for(uInt16 a8 = 0; a8 <= 1; ++a8)
    {
      const uInt16 addr = (a11 << 11) + (a8 << 8);

      mySystem->setPageAccess(0x06a0 | addr, access);
      mySystem->setPageAccess(0x06c0 | addr, access);
    }
  }
  // Install pages for the startup bank
  bank(startBank());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Cartridge0FA0::checkSwitchBank(uInt16 address, uInt8)
{
  // Switch banks if necessary
  switch(address & 0x16e0)
  {
    case 0x06a0:
      // Set the current bank to the lower 4k bank
      bank(0);
      return true;

    case 0x06c0:
      // Set the current bank to the upper 4k bank
      bank(1);
      return true;

    default:
      break;
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 Cartridge0FA0::peek(uInt16 address)
{
  address &= myBankMask;

  checkSwitchBank(address, 0);

  // Because of the way accessing is set up, we will only get here
  // when doing a TIA read
  return myHotSpotPageAccess.device->peek(address);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Cartridge0FA0::poke(uInt16 address, uInt8 value)
{
  address &= myBankMask;

  checkSwitchBank(address, 0);

  // Because of the way accessing is set up, we will may get here by
  // doing a write to TIA or cart; we ignore the cart write
  if (!(address & 0x1000))
  {
    myHotSpotPageAccess.device->poke(address, value);
  }

  return false;
}
