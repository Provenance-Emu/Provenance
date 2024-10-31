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

#include "TIA.hxx"
#include "M6502.hxx"
#include "System.hxx"
#include "CartWD.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartridgeWD::CartridgeWD(const ByteBuffer& image, size_t size,
                         string_view md5, const Settings& settings,
                         size_t bsSize)
  : CartridgeEnhanced(image, size, md5, settings, bsSize)
{
  // Copy the ROM image into my buffer
  if(size == 8_KB + 3)
  {
    // swap banks 2 & 3 of bad dump and correct size
    std::copy_n(image.get() + 1_KB * 3, 1_KB * 1, myImage.get() + 1_KB * 2);
    std::copy_n(image.get() + 1_KB * 2, 1_KB * 1, myImage.get() + 1_KB * 3);
    mySize = 8_KB;
  }
  myDirectPeek = false;

  myBankShift = BANK_SHIFT;
  myRamSize = RAM_SIZE;
  myRamWpHigh = RAM_HIGH_WP;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeWD::reset()
{
  CartridgeEnhanced::reset();

  myCyclesAtBankswitchInit = 0;
  myPendingBank = 0xF0;  // one more than the allowable bank #
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeWD::install(System& system)
{
  CartridgeEnhanced::install(system);

  const System::PageAccess access(this, System::PageAccessType::READ);

  // The hotspots are in TIA address space, so we claim it here
  for(uInt16 addr = 0x00; addr < 0x40; addr += System::PAGE_SIZE)
    mySystem->setPageAccess(addr, access);

  // Mirror all access in TIA; by doing so we're taking responsibility
  // for that address space in peek and poke below.
  //mySystem->tia().installDelegate(system, *this);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 CartridgeWD::peek(uInt16 address)
{
  // Is it time to do an actual bankswitch?
  if(myPendingBank != 0xF0 && !hotspotsLocked() &&
     mySystem->cycles() > (myCyclesAtBankswitchInit + 3))
  {
    bank(myPendingBank);
    myPendingBank = 0xF0;
  }

  if(!(address & 0x1000))   // Hotspots below 0x1000 are also TIA addresses
  {
    // Hotspots at $30 - $3F
    // Note that a hotspot read triggers a bankswitch after at least 3 cycles
    // have passed, so we only initiate the switch here
    if(!hotspotsLocked() && (address & 0x00FF) >= 0x30 && (address & 0x00FF) <= 0x3F)
    {
      myCyclesAtBankswitchInit = mySystem->cycles();
      myPendingBank = address & 0x000F;
    }
    return mySystem->tia().peek(address);
  }
  else
    return CartridgeEnhanced::peek(address);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeWD::poke(uInt16 address, uInt8 value)
{
  if(address < 0x40)
    return mySystem->tia().poke(address, value);

  return CartridgeEnhanced::poke(address, value);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeWD::bank(uInt16 bank, uInt16)
{
  if(hotspotsLocked()) return false;

  myCurrentBank = bank % romBankCount();

  CartridgeEnhanced::bank(ourBankOrg[myCurrentBank].zero,  0);
  CartridgeEnhanced::bank(ourBankOrg[myCurrentBank].one,   1);
  CartridgeEnhanced::bank(ourBankOrg[myCurrentBank].two,   2);
  CartridgeEnhanced::bank(ourBankOrg[myCurrentBank].three, 3);

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt16 CartridgeWD::getBank(uInt16) const
{
  return myCurrentBank;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeWD::save(Serializer& out) const
{
  CartridgeEnhanced::save(out);
  try
  {
    out.putShort(myCurrentBank);
    out.putLong(myCyclesAtBankswitchInit);
    out.putShort(myPendingBank);
  }
  catch(...)
  {
    cerr << "ERROR: CartridgeWD::save\n";
    return false;
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeWD::load(Serializer& in)
{
  CartridgeEnhanced::load(in);
  try
  {
    myCurrentBank = in.getShort();
    myCyclesAtBankswitchInit = in.getLong();
    myPendingBank = in.getShort();

    bank(myCurrentBank);
  }
  catch(...)
  {
    cerr << "ERROR: CartridgeWD::load\n";
    return false;
  }

  return true;
}
