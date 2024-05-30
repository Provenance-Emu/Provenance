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
#include "CartSB.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartridgeSB::CartridgeSB(const ByteBuffer& image, size_t size,
                         string_view md5, const Settings& settings,
                         size_t bsSize)
  : CartridgeEnhanced(image, size, md5, settings,
                      bsSize == 0 ? BSPF::nextPowerOfTwo(size) : bsSize)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeSB::install(System& system)
{
  CartridgeEnhanced::install(system);

  // Get the page accessing methods for the hot spots since they overlap
  // areas within the TIA we'll need to forward requests to the TIA
  myHotSpotPageAccess[0] = mySystem->getPageAccess(0x0800);
  myHotSpotPageAccess[1] = mySystem->getPageAccess(0x0900);
  myHotSpotPageAccess[2] = mySystem->getPageAccess(0x0A00);
  myHotSpotPageAccess[3] = mySystem->getPageAccess(0x0B00);
  myHotSpotPageAccess[4] = mySystem->getPageAccess(0x0C00);
  myHotSpotPageAccess[5] = mySystem->getPageAccess(0x0D00);
  myHotSpotPageAccess[6] = mySystem->getPageAccess(0x0E00);
  myHotSpotPageAccess[7] = mySystem->getPageAccess(0x0F00);

  // Set the page accessing methods for the hot spots
  const System::PageAccess access(this, System::PageAccessType::READ);
  for(uInt16 addr = 0x0800; addr < 0x0FFF; addr += System::PAGE_SIZE)
    mySystem->setPageAccess(addr, access);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeSB::checkSwitchBank(uInt16 address, uInt8)
{
  // Switch banks if necessary
  if((address & 0x1800) == 0x0800)
  {
    bank(address & (romBankCount() - 1));
    return true;
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 CartridgeSB::peek(uInt16 address)
{
  address &= (0x17FF + romBankCount());

  checkSwitchBank(address, 0);

  if(!(address & 0x1000))
  {
    // Because of the way we've set up accessing above, we can only
    // get here when the addresses are from 0x800 - 0xFFF
    const int hotspot = ((address & 0x0F00) >> 8) - 8;
    return myHotSpotPageAccess[hotspot].device->peek(address);
  }

  return 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeSB::poke(uInt16 address, uInt8 value)
{
  address &= (0x17FF + romBankCount());

  checkSwitchBank(address, 0);

  if(!(address & 0x1000))
  {
    // Because of the way we've set up accessing above, we can only
    // get here when the addresses are from 0x800 - 0xFFF
    const int hotspot = ((address & 0x0F00) >> 8) - 8;
    myHotSpotPageAccess[hotspot].device->poke(address, value);
  }
  return false;
}
