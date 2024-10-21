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

#include "CompuMate.hxx"
#include "System.hxx"
#include "M6532.hxx"
#include "CartCM.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartridgeCM::CartridgeCM(const ByteBuffer& image, size_t size,
                         string_view md5, const Settings& settings)
  : Cartridge(settings, md5),
    myImage{make_unique<uInt8[]>(16_KB)}
{
  // Copy the ROM image into my buffer
  std::copy_n(image.get(), std::min(16_KB, size), myImage.get());
  createRomAccessArrays(16_KB);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeCM::reset()
{
  initializeRAM(myRAM.data(), myRAM.size());

  // On powerup, the last bank of ROM is enabled and RAM is disabled
  mySWCHA = 0xFF;
  initializeStartBank(mySWCHA & 0x3);

  // Upon reset we switch to the startup bank
  bank(startBank());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeCM::install(System& system)
{
  mySystem = &system;

  // Mirror all access in RIOT; by doing so we're taking responsibility
  // for that address space in peek and poke below.
  mySystem->m6532().installDelegate(system, *this);

  // Install pages for the startup bank
  bank(startBank());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 CartridgeCM::peek(uInt16 address)
{
  // NOTE: This does not handle accessing cart ROM/RAM, however, this method
  // should never be called for ROM/RAM because of the way page accessing
  // has been setup (it will only ever be called for RIOT reads)
  return mySystem->m6532().peek(address);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeCM::poke(uInt16 address, uInt8 value)
{
  // NOTE: This could be called for RIOT writes or cart ROM writes
  // In the latter case, the write is ignored
  if(!(address & 0x1000))
  {
    // RIOT mirroring, check bankswitch
    if(address == 0x280)
    {
      mySWCHA = value;
      bank(mySWCHA & 0x3);
      if(myCompuMate)
      {
        uInt8& column = myCompuMate->column();
        if(value & 0x20)
          column = 0;
        if(value & 0x40)
          column = (column + 1) % 10;
      }
    }
    mySystem->m6532().poke(address, value);
  }
  return myBankChanged;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 CartridgeCM::column() const
{
  return myCompuMate->column();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeCM::bank(uInt16 bank, uInt16)
{
  if(hotspotsLocked()) return false;

  // Remember what bank we're in
  myBankOffset = bank << 12;

  // Although this scheme contains four 4K ROM banks and one 2K RAM bank,
  // it's easier to think of things in terms of 2K slices, as follows:
  //
  // The lower 2K of cart address space always points to the lower 2K of the
  // current ROM bank
  // The upper 2K of cart address space can point to either the 2K of RAM or
  // the upper 2K of the current ROM bank

  System::PageAccess access(this, System::PageAccessType::READ);

  // Lower 2K (always ROM)
  for(uInt16 addr = 0x1000; addr < 0x1800; addr += System::PAGE_SIZE)
  {
    access.directPeekBase = &myImage[myBankOffset + (addr & 0x0FFF)];
    access.romAccessBase = &myRomAccessBase[myBankOffset + (addr & 0x0FFF)];
    access.romPeekCounter = &myRomAccessCounter[myBankOffset + (addr & 0x0FFF)];
    access.romPokeCounter = &myRomAccessCounter[myBankOffset + (addr & 0x0FFF) + myAccessSize];
    mySystem->setPageAccess(addr, access);
  }

  // Upper 2K (RAM or ROM)
  for(uInt16 addr = 0x1800; addr < 0x2000; addr += System::PAGE_SIZE)
  {
    access.type = System::PageAccessType::READWRITE;

    if(mySWCHA & 0x10)
    {
      access.directPeekBase = &myImage[myBankOffset + (addr & 0x0FFF)];
      access.romAccessBase = &myRomAccessBase[myBankOffset + (addr & 0x0FFF)];
      access.romPeekCounter = &myRomAccessCounter[myBankOffset + (addr & 0x0FFF)];
      access.romPokeCounter = &myRomAccessCounter[myBankOffset + (addr & 0x0FFF) + myAccessSize];
    }
    else
    {
      access.directPeekBase = &myRAM[addr & 0x7FF];
      access.romAccessBase = &myRomAccessBase[myBankOffset + (addr & 0x07FF)];
      access.romPeekCounter = &myRomAccessCounter[myBankOffset + (addr & 0x07FF)];
      access.romPokeCounter = &myRomAccessCounter[myBankOffset + (addr & 0x07FF) + myAccessSize];
    }

    if((mySWCHA & 0x30) == 0x20)
      access.directPokeBase = &myRAM[addr & 0x7FF];
    else
      access.directPokeBase = nullptr;

    mySystem->setPageAccess(addr, access);
  }

  return myBankChanged = true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt16 CartridgeCM::getBank(uInt16) const
{
  return myBankOffset >> 12;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt16 CartridgeCM::romBankCount() const
{
  // We report 4 banks (of ROM), even though RAM can overlap the upper 2K
  // of cart address space at some times
  // However, this RAM isn't enabled in the normal way that bankswitching
  // works, so it is ignored here
  return 4;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeCM::patch(uInt16 address, uInt8 value)
{
  if((mySWCHA & 0x30) == 0x20)
    myRAM[address & 0x7FF] = value;
  else
    myImage[myBankOffset + address] = value;

  return myBankChanged = true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const ByteBuffer& CartridgeCM::getImage(size_t& size) const
{
  size = 16_KB;
  return myImage;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeCM::save(Serializer& out) const
{
  try
  {
    out.putShort(myBankOffset);
    out.putByte(mySWCHA);
    out.putByte(myCompuMate->column());
    out.putByteArray(myRAM.data(), myRAM.size());
  }
  catch(...)
  {
    cerr << "ERROR: CartridgeCM::save\n";
    return false;
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeCM::load(Serializer& in)
{
  try
  {
    myBankOffset = in.getShort();
    mySWCHA = in.getByte();
    myCompuMate->column() = in.getByte();
    in.getByteArray(myRAM.data(), myRAM.size());
  }
  catch(...)
  {
    cerr << "ERROR: CartridgeCM::load\n";
    return false;
  }

  // Remember what bank we were in
  bank(myBankOffset >> 12);

  return true;
}
