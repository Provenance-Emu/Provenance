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
#include "M6532.hxx"
#include "TIA.hxx"
#include "CartX07.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartridgeX07::CartridgeX07(const ByteBuffer& image, size_t size,
                           string_view md5, const Settings& settings,
                           size_t bsSize)
  : CartridgeEnhanced(image, size, md5, settings, bsSize)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeX07::install(System& system)
{
  CartridgeEnhanced::install(system);

  // Set the page accessing methods for the hot spots
  // The hotspots use almost all addresses below 0x1000, so we simply grab them
  // all and forward the TIA/RIOT calls from the peek and poke methods.
  const System::PageAccess access(this, System::PageAccessType::READWRITE);
  for(uInt16 addr = 0x00; addr < 0x1000; addr += System::PAGE_SIZE)
    mySystem->setPageAccess(addr, access);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeX07::checkSwitchBank(uInt16 address, uInt8)
{
  // Switch banks if necessary
  if((address & 0x180f) == 0x080d)
  {
    bank((address & 0xf0) >> 4);
    return true;
  }
  else if((address & 0x1880) == 0)
  {
    if((getBank() & 0xe) == 0xe)
    {
      bank(((address & 0x40) >> 6) | 0xe);
      return true;
    }
  }

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 CartridgeX07::peek(uInt16 address)
{
  uInt8 value = 0; // JTZ: is this correct?
  // Check for RAM or TIA mirroring
  const uInt16 lowAddress = address & 0x3ff;

  if(lowAddress & 0x80)
    value = mySystem->m6532().peek(address);
  else if(!(lowAddress & 0x200))
    value = mySystem->tia().peek(address);

  checkSwitchBank(address, 0);

  return value;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeX07::poke(uInt16 address, uInt8 value)
{
  // Check for RAM or TIA mirroring
  const uInt16 lowAddress = address & 0x3ff;

  if(lowAddress & 0x80)
    mySystem->m6532().poke(address, value);
  else if(!(lowAddress & 0x200))
    mySystem->tia().poke(address, value);

  checkSwitchBank(address, 0);

  return false;
}
