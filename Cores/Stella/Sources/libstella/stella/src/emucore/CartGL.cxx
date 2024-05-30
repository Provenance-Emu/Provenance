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
#include "CartGL.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartridgeGL::CartridgeGL(const ByteBuffer& image, size_t size,
                         string_view md5, const Settings& settings,
                         size_t bsSize)
  : CartridgeEnhanced(image, size, md5, settings, bsSize)
{
  myBankShift = myRamBankShift = BANK_SHIFT;
  myRamSize = RAM_SIZE;
  myRamBankCount = RAM_BANKS;

  if(size == 4_KB + 2_KB) // ROM containing RAM data?
  {
    myInitialRAM = make_unique<uInt8[]>(2_KB);
    // Copy the RAM image into a buffer for use in reset()
    std::copy_n(image.get() + 4_KB, 2_KB, myInitialRAM.get());
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeGL::reset()
{
  CartridgeEnhanced::reset();

  // Initially bank 0 is mapped into all four segments
  bank(0, 0);
  bank(0, 1);
  bank(0, 2);
  bank(0, 3);
  myBankChanged = true;

  myOrgAccess = mySystem->getPageAccess(0x1fc0);

  initializeRAM(myRAM.get(), myRamSize);
  if(myInitialRAM != nullptr)
  {
    // Copy the RAM image into my RAM buffer
    std::copy_n(myInitialRAM.get(), 2_KB, myRAM.get());
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeGL::install(System& system)
{
  CartridgeEnhanced::install(system);

  const System::PageAccess access(this, System::PageAccessType::READ);

  mySystem->setPageAccess(0x480, access);
  mySystem->setPageAccess(0x580, access);
  mySystem->setPageAccess(0x680, access);
  mySystem->setPageAccess(0x880, access);
  mySystem->setPageAccess(0x980, access);
  mySystem->setPageAccess(0xc80, access);
  mySystem->setPageAccess(0xd80, access);

  myReadOffset = myWriteOffset = 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeGL::checkSwitchBank(uInt16 address, uInt8)
{
  int slice = -1;
  bool control = false;

  // Switch banks if necessary
  switch(address & 0x1f80)
  {
    case 0x480:
      slice = 0;
      break;
    case 0x580:
      slice = 1;
      break;
    case 0x880:
      slice = 2;
      break;
    case 0x980:
      slice = 3;
      break;
    case 0xc80:
      control = true;
      break;
    default:
      break;  // satisfy compiler
  }
  if(slice >= 0)
  {
    //const bool isWrite = address & 0x20; // could be checked, but not necessary for known GL ROMs
    bank(address & 0xf, slice);
    return true;
  }
  if(control)
  {
    myEnablePROM = (address & 0x30) == 0x30;
    if(myEnablePROM)
      mySystem->setPageAccess(0x1fc0, System::PageAccess(this, System::PageAccessType::READ));
    else
      mySystem->setPageAccess(0x1fc0, myOrgAccess);
    return true;
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 CartridgeGL::peek(uInt16 address)
{
  if(myEnablePROM && ((address & ADDR_MASK) >= 0x1fc0) && ((address & ADDR_MASK) <= 0x1fdf))
  {
    return 0; // sufficient for PROM check
  }

  checkSwitchBank(address, 0);

  return myRWPRandomValues[address & 0xFF];
}
