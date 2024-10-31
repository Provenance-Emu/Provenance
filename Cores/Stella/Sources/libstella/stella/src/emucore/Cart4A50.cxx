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
#include "Cart4A50.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Cartridge4A50::Cartridge4A50(const ByteBuffer& image, size_t size,
                             string_view md5, const Settings& settings)
  : Cartridge(settings, md5),
    myImage{make_unique<uInt8[]>(128_KB)},
    mySize{size}
{
  // Copy the ROM image into my buffer
  // Supported file sizes are 32/64/128K, which are duplicated if necessary
  if(size < 64_KB)        size = 32_KB;
  else if(size < 128_KB)  size = 64_KB;
  else                    size = 128_KB;
  for(uInt32 slice = 0; slice < 128_KB / size; ++slice)
    std::copy_n(image.get(), size, myImage.get() + (slice*size));

  // We use System::PageAccess.romAccessBase, but don't allow its use
  // through a pointer, since the address space of 4A50 carts can change
  // at the instruction level, and PageAccess is normally defined at an
  // interval of 64 bytes
  //
  // Instead, access will be through the getAccessFlags and setAccessFlags
  // methods below
  createRomAccessArrays(128_KB + myRAM.size());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Cartridge4A50::reset()
{
  initializeRAM(myRAM.data(), myRAM.size());

  mySliceLow = mySliceMiddle = mySliceHigh = 0;
  myIsRomLow = myIsRomMiddle = myIsRomHigh = true;

  myLastData    = 0xff;
  myLastAddress = 0xffff;

  myBankChanged = true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Cartridge4A50::install(System& system)
{
  mySystem = &system;

  // Map all of the accesses to call peek and poke (We don't yet indicate RAM areas)
  const System::PageAccess access(this, System::PageAccessType::READ);
  for(uInt16 addr = 0x1000; addr < 0x2000; addr += System::PAGE_SIZE)
    mySystem->setPageAccess(addr, access);

  // Mirror all access in TIA and RIOT; by doing so we're taking responsibility
  // for that address space in peek and poke below.
  mySystem->tia().installDelegate(system, *this);
  mySystem->m6532().installDelegate(system, *this);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 Cartridge4A50::peek(uInt16 address)
{
  uInt8 value = 0;

  if(!(address & 0x1000))                      // Hotspots below 0x1000
  {
    // Check for RAM or TIA mirroring
    const uInt16 lowAddress = address & 0x3ff;
    if(lowAddress & 0x80)
      value = mySystem->m6532().peek(address);
    else if(!(lowAddress & 0x200))
      value = mySystem->tia().peek(address);

    checkBankSwitch(address, value);
  }
  else
  {
    if((address & 0x1800) == 0x1000)           // 2K region from 0x1000 - 0x17ff
    {
      value = myIsRomLow ? myImage[(address & 0x7ff) + mySliceLow]
                         : myRAM[(address & 0x7ff) + mySliceLow];
    }
    else if(((address & 0x1fff) >= 0x1800) &&  // 1.5K region from 0x1800 - 0x1dff
            ((address & 0x1fff) <= 0x1dff))
    {
      value = myIsRomMiddle ? myImage[(address & 0x7ff) + mySliceMiddle + 0x10000]
                            : myRAM[(address & 0x7ff) + mySliceMiddle];
    }
    else if((address & 0x1f00) == 0x1e00)      // 256B region from 0x1e00 - 0x1eff
    {
      value = myIsRomHigh ? myImage[(address & 0xff) + mySliceHigh + 0x10000]
                          : myRAM[(address & 0xff) + mySliceHigh];
    }
    else if((address & 0x1f00) == 0x1f00)      // 256B region from 0x1f00 - 0x1fff
    {
      value = myImage[(address & 0xff) + 0x1ff00];
      if(!hotspotsLocked() && ((myLastData & 0xe0) == 0x60) &&
         ((myLastAddress >= 0x1000) || (myLastAddress < 0x200)))
        mySliceHigh = (mySliceHigh & 0xf0ff) | ((address & 0x8) << 8) |
                      ((address & 0x70) << 4);
    }
  }
  myLastData = value;
  myLastAddress = address & 0x1fff;

  return value;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Cartridge4A50::poke(uInt16 address, uInt8 value)
{
  if(!(address & 0x1000))                      // Hotspots below 0x1000
  {
    // Check for RAM or TIA mirroring
    const uInt16 lowAddress = address & 0x3ff;
    if(lowAddress & 0x80)
      mySystem->m6532().poke(address, value);
    else if(!(lowAddress & 0x200))
      mySystem->tia().poke(address, value);

    checkBankSwitch(address, value);
  }
  else
  {
    if((address & 0x1800) == 0x1000)           // 2K region at 0x1000 - 0x17ff
    {
      if(!myIsRomLow)
      {
        myRAM[(address & 0x7ff) + mySliceLow] = value;
        myBankChanged = true;
      }
    }
    else if(((address & 0x1fff) >= 0x1800) &&  // 1.5K region at 0x1800 - 0x1dff
            ((address & 0x1fff) <= 0x1dff))
    {
      if(!myIsRomMiddle)
      {
        myRAM[(address & 0x7ff) + mySliceMiddle] = value;
        myBankChanged = true;
      }
    }
    else if((address & 0x1f00) == 0x1e00)      // 256B region at 0x1e00 - 0x1eff
    {
      if(!myIsRomHigh)
      {
        myRAM[(address & 0xff) + mySliceHigh] = value;
        myBankChanged = true;
      }
    }
    else if((address & 0x1f00) == 0x1f00)      // 256B region at 0x1f00 - 0x1fff
    {
      if(!hotspotsLocked() && ((myLastData & 0xe0) == 0x60) &&
         ((myLastAddress >= 0x1000) || (myLastAddress < 0x200)))
      {
        mySliceHigh = (mySliceHigh & 0xf0ff) | ((address & 0x8) << 8) |
                      ((address & 0x70) << 4);
        myBankChanged = true;
      }
    }
  }
  myLastData = value;
  myLastAddress = address & 0x1fff;

  return myBankChanged;
}

#ifdef DEBUGGER_SUPPORT
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Device::AccessFlags Cartridge4A50::getAccessFlags(uInt16 address) const
{
  if((address & 0x1800) == 0x1000)           // 2K region from 0x1000 - 0x17ff
  {
    if(myIsRomLow)
      return myRomAccessBase[(address & 0x7ff) + mySliceLow];
    else
      return myRomAccessBase[131072 + (address & 0x7ff) + mySliceLow];
  }
  else if(((address & 0x1fff) >= 0x1800) &&  // 1.5K region from 0x1800 - 0x1dff
          ((address & 0x1fff) <= 0x1dff))
  {
    if(myIsRomMiddle)
      return myRomAccessBase[(address & 0x7ff) + mySliceMiddle + 0x10000];
    else
      return myRomAccessBase[131072 + (address & 0x7ff) + mySliceMiddle];
  }
  else if((address & 0x1f00) == 0x1e00)      // 256B region from 0x1e00 - 0x1eff
  {
    if(myIsRomHigh)
      return myRomAccessBase[(address & 0xff) + mySliceHigh + 0x10000];
    else
      return myRomAccessBase[131072 + (address & 0xff) + mySliceHigh];
  }
  else if((address & 0x1f00) == 0x1f00)      // 256B region from 0x1f00 - 0x1fff
  {
    return myRomAccessBase[(address & 0xff) + 0x1ff00];
  }
  return 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Cartridge4A50::setAccessFlags(uInt16 address, Device::AccessFlags flags)
{
  if((address & 0x1800) == 0x1000)           // 2K region from 0x1000 - 0x17ff
  {
    if(myIsRomLow)
      myRomAccessBase[(address & 0x7ff) + mySliceLow] |= flags;
    else
      myRomAccessBase[131072 + (address & 0x7ff) + mySliceLow] |= flags;
  }
  else if(((address & 0x1fff) >= 0x1800) &&  // 1.5K region from 0x1800 - 0x1dff
          ((address & 0x1fff) <= 0x1dff))
  {
    if(myIsRomMiddle)
      myRomAccessBase[(address & 0x7ff) + mySliceMiddle + 0x10000] |= flags;
    else
      myRomAccessBase[131072 + (address & 0x7ff) + mySliceMiddle] |= flags;
  }
  else if((address & 0x1f00) == 0x1e00)      // 256B region from 0x1e00 - 0x1eff
  {
    if(myIsRomHigh)
      myRomAccessBase[(address & 0xff) + mySliceHigh + 0x10000] |= flags;
    else
      myRomAccessBase[131072 + (address & 0xff) + mySliceHigh] |= flags;
  }
  else if((address & 0x1f00) == 0x1f00)      // 256B region from 0x1f00 - 0x1fff
  {
    myRomAccessBase[(address & 0xff) + 0x1ff00] |= flags;
  }
}
#endif

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Cartridge4A50::checkBankSwitch(uInt16 address, uInt8 value)
{
  if(hotspotsLocked()) return;

  // This scheme contains so many hotspots that it's easier to just check
  // all of them
  if(((myLastData & 0xe0) == 0x60) &&      // Switch lower/middle/upper bank
     ((myLastAddress >= 0x1000) || (myLastAddress < 0x200)))
  {
    if((address & 0x0f00) == 0x0c00)       // Enable 256B of ROM at 0x1e00 - 0x1eff
      bankROMHigh(address & 0xff);
    else if((address & 0x0f00) == 0x0d00)  // Enable 256B of RAM at 0x1e00 - 0x1eff
      bankRAMHigh(address & 0x7f);
    else if((address & 0x0f40) == 0x0e00)  // Enable 2K of ROM at 0x1000 - 0x17ff
      bankROMLower(address & 0x1f);
    else if((address & 0x0f40) == 0x0e40)  // Enable 2K of RAM at 0x1000 - 0x17ff
      bankRAMLower(address & 0xf);
    else if((address & 0x0f40) == 0x0f00)  // Enable 1.5K of ROM at 0x1800 - 0x1dff
      bankROMMiddle(address & 0x1f);
    else if((address & 0x0f50) == 0x0f40)  // Enable 1.5K of RAM at 0x1800 - 0x1dff
      bankRAMMiddle(address & 0xf);

    // Stella helper functions
    else if((address & 0x0f00) == 0x0400)   // Toggle bit A11 of lower block address
    {
      mySliceLow = mySliceLow ^ 0x800;
      myBankChanged = true;
    }
    else if((address & 0x0f00) == 0x0500)   // Toggle bit A12 of lower block address
    {
      mySliceLow = mySliceLow ^ 0x1000;
      myBankChanged = true;
    }
    else if((address & 0x0f00) == 0x0800)   // Toggle bit A11 of middle block address
    {
      mySliceMiddle = mySliceMiddle ^ 0x800;
      myBankChanged = true;
    }
    else if((address & 0x0f00) == 0x0900)   // Toggle bit A12 of middle block address
    {
      mySliceMiddle = mySliceMiddle ^ 0x1000;
      myBankChanged = true;
    }
  }

  // Zero-page hotspots for upper page
  //   0xf4, 0xf6, 0xfc, 0xfe for ROM
  //   0xf5, 0xf7, 0xfd, 0xff for RAM
  //   0x74 - 0x7f (0x80 bytes lower)
  if((address & 0xf75) == 0x74)         // Enable 256B of ROM at 0x1e00 - 0x1eff
    bankROMHigh(value);
  else if((address & 0xf75) == 0x75)    // Enable 256B of RAM at 0x1e00 - 0x1eff
    bankRAMHigh(value & 0x7f);

  // Zero-page hotspots for lower and middle blocks
  //   0xf8, 0xf9, 0xfa, 0xfb
  //   0x78, 0x79, 0x7a, 0x7b (0x80 bytes lower)
  else if((address & 0xf7c) == 0x78)
  {
    if((value & 0xf0) == 0)           // Enable 2K of ROM at 0x1000 - 0x17ff
      bankROMLower(value & 0xf);
    else if((value & 0xf0) == 0x40)   // Enable 2K of RAM at 0x1000 - 0x17ff
      bankRAMLower(value & 0xf);
    else if((value & 0xf0) == 0x90)   // Enable 1.5K of ROM at 0x1800 - 0x1dff
      bankROMMiddle((value & 0xf) | 0x10);
    else if((value & 0xf0) == 0xc0)   // Enable 1.5K of RAM at 0x1800 - 0x1dff
      bankRAMMiddle(value & 0xf);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Cartridge4A50::patch(uInt16 address, uInt8 value)
{
  if((address & 0x1800) == 0x1000)           // 2K region from 0x1000 - 0x17ff
  {
    if(myIsRomLow)
      myImage[(address & 0x7ff) + mySliceLow] = value;
    else
      myRAM[(address & 0x7ff) + mySliceLow] = value;
  }
  else if(((address & 0x1fff) >= 0x1800) &&  // 1.5K region from 0x1800 - 0x1dff
          ((address & 0x1fff) <= 0x1dff))
  {
    if(myIsRomMiddle)
      myImage[(address & 0x7ff) + mySliceMiddle + 0x10000] = value;
    else
      myRAM[(address & 0x7ff) + mySliceMiddle] = value;
  }
  else if((address & 0x1f00) == 0x1e00)      // 256B region from 0x1e00 - 0x1eff
  {
    if(myIsRomHigh)
      myImage[(address & 0xff) + mySliceHigh + 0x10000] = value;
    else
      myRAM[(address & 0xff) + mySliceHigh] = value;
  }
  else if((address & 0x1f00) == 0x1f00)      // 256B region from 0x1f00 - 0x1fff
  {
    myImage[(address & 0xff) + 0x1ff00] = value;
  }
  return myBankChanged = true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const ByteBuffer& Cartridge4A50::getImage(size_t& size) const
{
  size = mySize;
  return myImage;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Cartridge4A50::save(Serializer& out) const
{
  try
  {
    // The 32K bytes of RAM
    out.putByteArray(myRAM.data(), myRAM.size());

    // Index pointers
    out.putShort(mySliceLow);
    out.putShort(mySliceMiddle);
    out.putShort(mySliceHigh);

    // Whether index pointers are for ROM or RAM
    out.putBool(myIsRomLow);
    out.putBool(myIsRomMiddle);
    out.putBool(myIsRomHigh);

    // Last address and data values
    out.putByte(myLastData);
    out.putShort(myLastAddress);
  }
  catch(...)
  {
    cerr << "ERROR: Cartridge4A40::save\n";
    return false;
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Cartridge4A50::load(Serializer& in)
{
  try
  {
    in.getByteArray(myRAM.data(), myRAM.size());

    // Index pointers
    mySliceLow = in.getShort();
    mySliceMiddle = in.getShort();
    mySliceHigh = in.getShort();

    // Whether index pointers are for ROM or RAM
    myIsRomLow = in.getBool();
    myIsRomMiddle = in.getBool();
    myIsRomHigh = in.getBool();

    // Last address and data values
    myLastData = in.getByte();
    myLastAddress = in.getShort();
  }
  catch(...)
  {
    cerr << "ERROR: Cartridge4A50::load\n";
    return false;
  }

  return true;
}
