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
#include "Cart03E0.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Cartridge03E0::Cartridge03E0(const ByteBuffer& image, size_t size,
                             string_view md5, const Settings& settings,
                             size_t bsSize)
  : CartridgeEnhanced(image, size, md5, settings, bsSize)
{
  myBankShift = BANK_SHIFT;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Cartridge03E0::install(System& system)
{
  CartridgeEnhanced::install(system);

  // Get the page accessing methods for the hot spots since they overlap
  // areas within the TIA we'll need to forward requests to the TIA
  myHotSpotPageAccess[0] = mySystem->getPageAccess(0x0380);
  myHotSpotPageAccess[1] = mySystem->getPageAccess(0x03c0);

  // Set the page accessing methods for the hot spots
  const System::PageAccess access(this, System::PageAccessType::READ);
  for(uInt16 addr = 0x0380; addr < 0x03FF; addr += System::PAGE_SIZE)
    mySystem->setPageAccess(addr, access);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Cartridge03E0::reset()
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
bool Cartridge03E0::checkSwitchBank(uInt16 address, uInt8)
{
  bool switched = false;

  if((address & 0x10) == 0)
  {
    bank(address & 0x0007, 0);
    switched = true;
  }
  if((address & 0x20) == 0)
  {
    bank(address & 0x0007, 1);
    switched = true;
  }
  if((address & 0x40) == 0)
  {
    bank(address & 0x0007, 2);
    switched = true;
  }
  return switched;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 Cartridge03E0::peek(uInt16 address)
{
  checkSwitchBank(address, 0);

  // Because of the way we've set up accessing above, we can only
  // get here when the addresses are from 0x380 - 0x3FF
  const int hotspot = ((address & 0x40) >> 6);
  return myHotSpotPageAccess[hotspot].device->peek(address);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Cartridge03E0::poke(uInt16 address, uInt8 value)
{
  // Because of the way accessing is set up, we will may get here by
  // doing a write to 0x380 - 0x3FF or cart; we ignore the cart write
  if(!(address & 0x1000))
  {
    checkSwitchBank(address, 0);

    const int hotspot = ((address & 0x40) >> 6);
    myHotSpotPageAccess[hotspot].device->poke(address, value);
  }

  return false;
}
