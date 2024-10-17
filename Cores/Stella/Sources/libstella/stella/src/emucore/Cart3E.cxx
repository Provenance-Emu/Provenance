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
#include "TIA.hxx"
#include "Cart3E.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Cartridge3E::Cartridge3E(const ByteBuffer& image, size_t size,
                         string_view md5, const Settings& settings,
                         size_t bsSize)
  : CartridgeEnhanced(image, size, md5, settings,
                      bsSize == 0 ? BSPF::nextMultipleOf(size, 2_KB) : bsSize)
{
  myBankShift = BANK_SHIFT;
  myRamSize = RAM_SIZE;
  myRamBankCount = RAM_BANKS;
  myRamWpHigh = RAM_HIGH_WP;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Cartridge3E::install(System& system)
{
  CartridgeEnhanced::install(system);

  const System::PageAccess access(this, System::PageAccessType::WRITE);

  // The hotspots ($3E and $3F) are in TIA address space, so we claim it here
  for(uInt16 addr = 0x00; addr < 0x40; addr += System::PAGE_SIZE)
    mySystem->setPageAccess(addr, access);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Cartridge3E::checkSwitchBank(uInt16 address, uInt8 value)
{
  // Switch banks if necessary
  if(address == 0x003F) {
    // Switch ROM bank into segment 0
    bank(value);
    return true;
  }
  else if(address == 0x003E)
  {
    // Switch RAM bank into segment 0
    bank(value + romBankCount());
    return true;
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 Cartridge3E::peek(uInt16 address)
{
  const uInt16 peekAddress = address;
  address &= ROM_MASK;

  if(address < 0x0040)  // TIA access
    return mySystem->tia().peek(address);

  return CartridgeEnhanced::peek(peekAddress);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Cartridge3E::poke(uInt16 address, uInt8 value)
{
  const uInt16 pokeAddress = address;
  address &= ROM_MASK;

  if(address < 0x0040)  // TIA access
  {
    checkSwitchBank(address, value);
    return mySystem->tia().poke(address, value);
  }

  return CartridgeEnhanced::poke(pokeAddress, value);
}
