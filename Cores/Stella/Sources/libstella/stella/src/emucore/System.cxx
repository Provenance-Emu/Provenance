//============================================================================
//
// MM     MM  6666  555555  0000   2222
// MMMM MMMM 66  66 55     00  00 22  22
// MM MMM MM 66     55     00  00     22
// MM  M  MM 66666  55555  00  00  22222  --  "A 6502 Microprocessor Emulator"
// MM     MM 66  66     55 00  00 22
// MM     MM 66  66 55  55 00  00 22
// MM     MM  6666   5555   0000  222222
//
// Copyright (c) 1995-2024 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#include <iostream>

#include "Device.hxx"
#include "M6502.hxx"
#include "M6532.hxx"
#include "TIA.hxx"
#include "Cart.hxx"
#include "System.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
System::System(Random& random, M6502& m6502, M6532& m6532,
               TIA& mTIA, Cartridge& mCart)
  : myRandom{random},
    myM6502{m6502},
    myM6532{m6532},
    myTIA{mTIA},
    myCart{mCart}
{
  // Initialize page access table
  const PageAccess access(&myNullDevice, System::PageAccessType::READ);
  myPageAccessTable.fill(access);
  myPageIsDirtyTable.fill(false);

  // Bus starts out unlocked (in other words, peek() changes myDataBusState)
  myDataBusLocked = false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void System::initialize()
{
  // Install all devices
  myM6532.install(*this);
  myTIA.install(*this);
  myCart.install(*this);
  myM6502.install(*this);  // Must always be installed last
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void System::reset(bool autodetect)
{
  // Provide hint to devices that autodetection is active (or not)
  mySystemInAutodetect = autodetect;

  // Reset all devices
  myCycles = 0;     // Must be done first (the reset() methods may use its value)
  myM6532.reset();
  myTIA.reset();
  myCart.reset();
  myM6502.reset();  // Must always be reset last

  // There are no dirty pages upon startup
  clearDirtyPages();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void System::consoleChanged(ConsoleTiming timing)
{
  myM6532.consoleChanged(timing);
  myTIA.consoleChanged(timing);
  myCart.consoleChanged(timing);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool System::isPageDirty(uInt16 start_addr, uInt16 end_addr) const
{
  const uInt16 start_page = (start_addr & ADDRESS_MASK) >> PAGE_SHIFT;
  const uInt16 end_page = (end_addr & ADDRESS_MASK) >> PAGE_SHIFT;

  for(uInt16 page = start_page; page <= end_page; ++page)
    if(myPageIsDirtyTable[page])
      return true;

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void System::clearDirtyPages()
{
  myPageIsDirtyTable.fill(false);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 System::peek(uInt16 addr, Device::AccessFlags flags)
{
  const PageAccess& access = getPageAccess(addr);

#ifdef DEBUGGER_SUPPORT
  // Set access type
  if(access.romAccessBase)
    *(access.romAccessBase + (addr & PAGE_MASK)) |= (flags | (addr & Device::HADDR));
  else
    access.device->setAccessFlags(addr, flags);
  // Increase access counter
  if(flags != Device::NONE)
  {
    if(access.romPeekCounter)
      *(access.romPeekCounter + (addr & PAGE_MASK)) += 1;
    else
      access.device->increaseAccessCounter(addr);
  }
#endif

  // See if this page uses direct accessing or not
  const uInt8 result = access.directPeekBase
      ? *(access.directPeekBase + (addr & PAGE_MASK))
      : access.device->peek(addr);

#ifdef DEBUGGER_SUPPORT
  if(!myDataBusLocked)
#endif
    myDataBusState = result;

  return result;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void System::poke(uInt16 addr, uInt8 value, Device::AccessFlags flags)
{
  const uInt16 page = (addr & ADDRESS_MASK) >> PAGE_SHIFT;
  const PageAccess& access = myPageAccessTable[page];

#ifdef DEBUGGER_SUPPORT
  // Set access type
  if(access.romAccessBase)
    *(access.romAccessBase + (addr & PAGE_MASK)) |= (flags | (addr & Device::HADDR));
  else
    access.device->setAccessFlags(addr, flags);
  // Increase access counter
  if(flags != Device::NONE)
  {
    if(access.romPokeCounter)
      *(access.romPokeCounter + (addr & PAGE_MASK)) += 1;
    else
      access.device->increaseAccessCounter(addr, true);
  }
#endif

  // See if this page uses direct accessing or not
  if(access.directPokeBase)
  {
    // Since we have direct access to this poke, we can dirty its page
    *(access.directPokeBase + (addr & PAGE_MASK)) = value;
    myPageIsDirtyTable[page] = true;
  }
  else
  {
    // The specific device informs us if the poke succeeded
    myPageIsDirtyTable[page] = access.device->poke(addr, value);
  }

#ifdef DEBUGGER_SUPPORT
  if(!myDataBusLocked)
#endif
    myDataBusState = value;
}

#ifdef DEBUGGER_SUPPORT
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Device::AccessFlags System::getAccessFlags(uInt16 addr) const
{
  const PageAccess& access = getPageAccess(addr);

  if(access.romAccessBase)
    return *(access.romAccessBase + (addr & PAGE_MASK));
  else
    return access.device->getAccessFlags(addr);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void System::setAccessFlags(uInt16 addr, Device::AccessFlags flags) const
{
  const PageAccess& access = getPageAccess(addr);

  if(access.romAccessBase)
    *(access.romAccessBase + (addr & PAGE_MASK)) |= (flags | (addr & Device::HADDR));
  else
    access.device->setAccessFlags(addr, flags);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void System::increaseAccessCounter(uInt16 addr, bool isWrite) const
{
  const PageAccess& access = getPageAccess(addr);

  if(isWrite)
  {
    if(access.romPokeCounter)
    {
      *(access.romPokeCounter + (addr & PAGE_MASK)) += 1;
      return;
    }
  }
  else
  {
    if(access.romPeekCounter)
    {
      *(access.romPeekCounter + (addr & PAGE_MASK)) += 1;
      return;
    }
  }
  access.device->increaseAccessCounter(addr, isWrite);
}
#endif

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool System::save(Serializer& out) const
{
  try
  {
    out.putLong(myCycles);
    out.putByte(myDataBusState);

    // Save the state of each device
    if(!myM6502.save(out))
      return false;
    if(!myM6532.save(out))
      return false;
    if(!myTIA.save(out))
      return false;
    if(!myCart.save(out))
      return false;
    if(!randGenerator().save(out))
      return false;
  }
  catch(...)
  {
    cerr << "ERROR: System::save\n";
    return false;
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool System::load(Serializer& in)
{
  try
  {
    myCycles = in.getLong();
    myDataBusState = in.getByte();

    // Load the state of each device
    if(!myM6502.load(in))
      return false;
    if(!myM6532.load(in))
      return false;
    if(!myTIA.load(in))
      return false;
    if(!myCart.load(in))
      return false;
    if(!randGenerator().load(in))
      return false;
  }
  catch(...)
  {
    cerr << "ERROR: System::load\n";
    return false;
  }

  return true;
}
