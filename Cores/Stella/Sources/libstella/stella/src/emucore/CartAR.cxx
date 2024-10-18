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

#include <numeric>

#include "M6502.hxx"
#include "System.hxx"
#include "Settings.hxx"
#include "CartAR.hxx"

namespace {
  // Compute the sum of the array of bytes
  uInt8 checksum(const uInt8* s, uInt16 length) {
    return static_cast<uInt8>(std::accumulate(s, s + length, 0));
  }
} // namespace

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartridgeAR::CartridgeAR(const ByteBuffer& image, size_t size,
                         string_view md5, const Settings& settings)
  : Cartridge(settings, md5),
    mySize{std::max(size, LOAD_SIZE)}
{
  // Create a load image buffer and copy the given image
  myLoadImages = make_unique<uInt8[]>(mySize);
  myNumberOfLoadImages = static_cast<uInt8>(mySize / LOAD_SIZE);
  std::copy_n(image.get(), size, myLoadImages.get());

  // Add header if image doesn't include it
  if(size < LOAD_SIZE)
    std::copy_n(ourDefaultHeader.data(), ourDefaultHeader.size(),
                myLoadImages.get() + myImage.size());

  // We use System::PageAccess.romAccessBase, but don't allow its use
  // through a pointer, since the AR scheme doesn't support bankswitching
  // in the normal sense
  //
  // Instead, access will be through the getAccessFlags and setAccessFlags
  // methods below
  createRomAccessArrays(mySize);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeAR::reset()
{
  // Initialize RAM
#if 0  // TODO - figure out actual behaviour of the real cart
  initializeRAM(myImage.data(), myImage.size());
#else
  myImage.fill(0);
#endif

  // Initialize SC BIOS ROM
  initializeROM();

  myWriteEnabled = false;
  myPower = true;

  myDataHoldRegister = 0;
  myNumberOfDistinctAccesses = 0;
  myWritePending = false;

  // Set bank configuration upon reset so ROM is selected and powered up
  bankConfiguration(0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeAR::install(System& system)
{
  mySystem = &system;

  // Map all of the accesses to call peek and poke (we don't yet indicate RAM areas)
  const System::PageAccess access(this, System::PageAccessType::READ);
  for(uInt16 addr = 0x1000; addr < 0x2000; addr += System::PAGE_SIZE)
    mySystem->setPageAccess(addr, access);

  bankConfiguration(0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 CartridgeAR::peek(uInt16 addr)
{
  // In debugger/bank-locked mode, we ignore all hotspots and in general
  // anything that can change the internal state of the cart
  if(hotspotsLocked())
    return myImage[(addr & 0x07FF) + myImageOffset[(addr & 0x0800) ? 1 : 0]];

  // Is the "dummy" SC BIOS hotspot for reading a load being accessed?
  if(((addr & 0x1FFF) == 0x1850) && (myImageOffset[1] == RAM_SIZE))
  {
    // Get load that's being accessed (BIOS places load number at 0x80)
    const uInt8 load = mySystem->peek(0x0080);

    // Read the specified load into RAM
    loadIntoRAM(load);

    return myImage[(addr & 0x07FF) + myImageOffset[1]];
  }

  // Cancel any pending write if more than 5 distinct accesses have occurred
  // TODO: Modify to handle when the distinct counter wraps around...
  if(myWritePending &&
      (mySystem->m6502().distinctAccesses() > myNumberOfDistinctAccesses + 5))
  {
    myWritePending = false;
  }

  // Is the data hold register being set?
  if(!(addr & 0x0F00) && (!myWriteEnabled || !myWritePending))
  {
    myDataHoldRegister = static_cast<uInt8>(addr);  // FIXME - check cast here
    myNumberOfDistinctAccesses = mySystem->m6502().distinctAccesses();
    myWritePending = true;
  }
  // Is the bank configuration hotspot being accessed?
  else if((addr & 0x1FFF) == 0x1FF8)
  {
    // Yes, so handle bank configuration
    myWritePending = false;
    bankConfiguration(myDataHoldRegister);
  }
  // Handle poke if writing enabled
  else if(myWriteEnabled && myWritePending &&
      (mySystem->m6502().distinctAccesses() == (myNumberOfDistinctAccesses + 5)))
  {
    if((addr & 0x0800) == 0)
    {
      myImage[(addr & 0x07FF) + myImageOffset[0]] = myDataHoldRegister;
      mySystem->setDirtyPage(addr);
    }
    else if(myImageOffset[1] != (3 * BANK_SIZE))    // Can't poke to ROM :-)
    {
      myImage[(addr & 0x07FF) + myImageOffset[1]] = myDataHoldRegister;
      mySystem->setDirtyPage(addr);
    }
    myWritePending = false;
  }

  return myImage[(addr & 0x07FF) + myImageOffset[(addr & 0x0800) ? 1 : 0]];
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeAR::poke(uInt16 addr, uInt8)
{
  bool modified = false;

  // Cancel any pending write if more than 5 distinct accesses have occurred
  // TODO: Modify to handle when the distinct counter wraps around...
  if(myWritePending &&
      (mySystem->m6502().distinctAccesses() > myNumberOfDistinctAccesses + 5))
  {
    myWritePending = false;
  }

  // Is the data hold register being set?
  if(!(addr & 0x0F00) && (!myWriteEnabled || !myWritePending))
  {
    myDataHoldRegister = static_cast<uInt8>(addr);  // FIXME - check cast here
    myNumberOfDistinctAccesses = mySystem->m6502().distinctAccesses();
    myWritePending = true;
  }
  // Is the bank configuration hotspot being accessed?
  else if((addr & 0x1FFF) == 0x1FF8)
  {
    // Yes, so handle bank configuration
    myWritePending = false;
    bankConfiguration(myDataHoldRegister);
  }
  // Handle poke if writing enabled
  else if(myWriteEnabled && myWritePending &&
      (mySystem->m6502().distinctAccesses() == (myNumberOfDistinctAccesses + 5)))
  {
    if((addr & 0x0800) == 0)
    {
      myImage[(addr & 0x07FF) + myImageOffset[0]] = myDataHoldRegister;
      modified = true;
    }
    else if(myImageOffset[1] != (3 * BANK_SIZE))    // Can't poke to ROM :-)
    {
      myImage[(addr & 0x07FF) + myImageOffset[1]] = myDataHoldRegister;
      modified = true;
    }
    myWritePending = false;
  }

  return modified;
}

#ifdef DEBUGGER_SUPPORT
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Device::AccessFlags CartridgeAR::getAccessFlags(uInt16 address) const
{
  return myRomAccessBase[(address & 0x07FF) +
           myImageOffset[(address & 0x0800) ? 1 : 0]];
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeAR::setAccessFlags(uInt16 address, Device::AccessFlags flags)
{
  myRomAccessBase[(address & 0x07FF) +
    myImageOffset[(address & 0x0800) ? 1 : 0]] |= flags;
}
#endif

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeAR::bankConfiguration(uInt8 configuration)
{
  // D7-D5 of this byte: Write Pulse Delay (n/a for emulator)
  //
  // D4-D0: RAM/ROM configuration:
  //       $F000-F7FF    $F800-FFFF Address range that banks map into
  //  000wp     2            ROM
  //  001wp     0            ROM
  //  010wp     2            0      as used in Commie Mutants and many others
  //  011wp     0            2      as used in Suicide Mission
  //  100wp     2            ROM
  //  101wp     1            ROM
  //  110wp     2            1      as used in Killer Satellites
  //  111wp     1            2      as we use for 2k/4k ROM cloning
  //
  //  w = Write Enable (1 = enabled; accesses to $F000-$F0FF cause writes
  //    to happen.  0 = disabled, and the cart acts like ROM.)
  //  p = ROM Power (0 = enabled, 1 = off.)  Only power the ROM if you're
  //    wanting to access the ROM for multiloads.  Otherwise set to 1.
  const uInt32 OFFSET_0[8] = {2 * BANK_SIZE, 0 * BANK_SIZE, 2 * BANK_SIZE, 0 * BANK_SIZE,
                              2 * BANK_SIZE, 1 * BANK_SIZE, 2 * BANK_SIZE, 1 * BANK_SIZE};
  const uInt32 OFFSET_1[8] = {3 * BANK_SIZE, 3 * BANK_SIZE, 0 * BANK_SIZE, 2 * BANK_SIZE,
                              3 * BANK_SIZE, 3 * BANK_SIZE, 1 * BANK_SIZE, 2 * BANK_SIZE};
  const int bankConfig = (configuration & 0b11100) >> 2;

  myCurrentBank = configuration & 0b11111; // remember for the bank() method

  // Handle ROM power configuration
  myPower = !(configuration & 0b00001);

  myWriteEnabled = configuration & 0b00010;

  myImageOffset[0] = OFFSET_0[bankConfig];
  myImageOffset[1] = OFFSET_1[bankConfig];

  return myBankChanged = true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeAR::initializeROM()
{
  // Note that the following offsets depend on the 'scrom.asm' file
  // in src/tools.  If that file is ever recompiled (and its
  // contents placed in the ourDummyROMCode array), the offsets will
  // almost definitely change

  // The scrom.asm code checks a value at offset 109 as follows:
  //   0xFF -> do a complete jump over the SC BIOS progress bars code
  //   0x00 -> show SC BIOS progress bars as normal
  ourDummyROMCode[109] = mySettings.getBool("fastscbios") ? 0xFF : 0x00;

  // The accumulator should contain a random value after exiting the
  // SC BIOS code - a value placed in offset 281 will be stored in A
  ourDummyROMCode[281] = mySystem->randGenerator().next();

  // Initialize ROM with illegal 6502 opcode that causes a real 6502 to jam
  std::fill_n(myImage.begin() + (RAM_SIZE), BANK_SIZE, 0x02);

  // Copy the "dummy" Supercharger BIOS code into the ROM area
  std::copy_n(ourDummyROMCode.data(), ourDummyROMCode.size(), myImage.data() + (RAM_SIZE));

  // Finally set 6502 vectors to point to initial load code at 0xF80A of BIOS
  myImage[(RAM_SIZE) + BANK_SIZE - 4] = 0x0A;
  myImage[(RAM_SIZE) + BANK_SIZE - 3] = 0xF8;
  myImage[(RAM_SIZE) + BANK_SIZE - 2] = 0x0A;
  myImage[(RAM_SIZE) + BANK_SIZE - 1] = 0xF8;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeAR::loadIntoRAM(uInt8 load)
{
  bool success = true;

  // Scan through all of the loads to see if we find the one we're looking for
  for(uInt16 image = 0; image < myNumberOfLoadImages; ++image)
  {
    const size_t image_off = image * LOAD_SIZE;

    // Is this the correct load?
    if(myLoadImages[image_off + myImage.size() + 5] == load)
    {
      // Copy the load's header
      std::copy_n(myLoadImages.get() + image_off + myImage.size(),
                  myHeader.size(), myHeader.data());

      // Verify the load's header
      if(checksum(myHeader.data(), 8) != 0x55)
      {
        cerr << "WARNING: The Supercharger header checksum is invalid...\n";
        myMsgCallback("Supercharger load #" + std::to_string(load) +
                      " done with hearder checksum error");
        success = false;
      }

      // Load all of the pages from the load
      bool invalidPageChecksumSeen = false;
      for(size_t j = 0; j < myHeader[3]; ++j)
      {
        const size_t bank = myHeader[16 + j] & 0b00011;
        const size_t page = (myHeader[16 + j] & 0b11100) >> 2;
        const uInt8* const src = myLoadImages.get() + image_off + j * 256;
        const uInt8 sum = checksum(src, 256) + myHeader[16 + j] + myHeader[64 + j];

        if(!invalidPageChecksumSeen && (sum != 0x55))
        {
          cerr << "WARNING: Some Supercharger page checksums are invalid...\n";
          myMsgCallback("Supercharger load #" + std::to_string(load) +
                        " done with page #" + std::to_string(j) +
                        " checksum error");
          invalidPageChecksumSeen = true;
        }

        // Copy page to Supercharger RAM (don't allow a copy into ROM area)
        if(bank < 3)
          std::copy_n(src, 256, myImage.data() + (bank * BANK_SIZE) + (page * 256));
      }
      success &= !invalidPageChecksumSeen;

      // Copy the bank switching byte and starting address into the 2600's
      // RAM for the "dummy" SC BIOS to access it
      mySystem->poke(0xfe, myHeader[0]);
      mySystem->poke(0xff, myHeader[1]);
      mySystem->poke(0x80, myHeader[2]);

      myBankChanged = true;
      if(success)
        myMsgCallback("Supercharger load #" + std::to_string(load) + " done");
      return;
    }
  }

  // TODO: Should probably switch to an internal ROM routine to display
  // this message to the user...
  cerr << "ERROR: Supercharger load is missing from ROM image...\n";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeAR::bank(uInt16 bank, uInt16)
{
  if(!hotspotsLocked())
    return bankConfiguration(static_cast<uInt8>(bank));
  else
    return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt16 CartridgeAR::getBank(uInt16) const
{
  return myCurrentBank;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt16 CartridgeAR::romBankCount() const
{
  return 32;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeAR::patch(uInt16 address, uInt8 value)
{
  // TODO - add support for debugger
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const ByteBuffer& CartridgeAR::getImage(size_t& size) const
{
  size = mySize;
  return myLoadImages;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeAR::save(Serializer& out) const
{
  try
  {
    // Indicates the offest within the image for the corresponding bank
    out.putIntArray(myImageOffset.data(), myImageOffset.size());

    // The 6K of RAM and 2K of ROM contained in the Supercharger
    out.putByteArray(myImage.data(), myImage.size());

    // The 256 byte header for the current 8448 byte load
    out.putByteArray(myHeader.data(), myHeader.size());

    // All of the 8448 byte loads associated with the game
    // Note that the size of this array is myNumberOfLoadImages * 8448
    out.putByteArray(myLoadImages.get(), myNumberOfLoadImages * LOAD_SIZE);

    // Indicates how many 8448 loads there are
    out.putByte(myNumberOfLoadImages);

    // Indicates if the RAM is write enabled
    out.putBool(myWriteEnabled);

    // Indicates if the ROM's power is on or off
    out.putBool(myPower);

    // Data hold register used for writing
    out.putByte(myDataHoldRegister);

    // Indicates number of distinct accesses when data hold register was set
    out.putInt(myNumberOfDistinctAccesses);

    // Indicates if a write is pending or not
    out.putBool(myWritePending);
  }
  catch(...)
  {
    cerr << "ERROR: CartridgeAR::save\n";
    return false;
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeAR::load(Serializer& in)
{
  try
  {
    // Indicates the offest within the image for the corresponding bank
    in.getIntArray(myImageOffset.data(), myImageOffset.size());

    // The 6K of RAM and 2K of ROM contained in the Supercharger
    in.getByteArray(myImage.data(), myImage.size());

    // The 256 byte header for the current 8448 byte load
    in.getByteArray(myHeader.data(), myHeader.size());

    // All of the 8448 byte loads associated with the game
    // Note that the size of this array is myNumberOfLoadImages * 8448
    in.getByteArray(myLoadImages.get(), myNumberOfLoadImages * LOAD_SIZE);

    // Indicates how many 8448 loads there are
    myNumberOfLoadImages = in.getByte();

    // Indicates if the RAM is write enabled
    myWriteEnabled = in.getBool();

    // Indicates if the ROM's power is on or off
    myPower = in.getBool();

    // Data hold register used for writing
    myDataHoldRegister = in.getByte();

    // Indicates number of distinct accesses when data hold register was set
    myNumberOfDistinctAccesses = in.getInt();

    // Indicates if a write is pending or not
    myWritePending = in.getBool();
  }
  catch(...)
  {
    cerr << "ERROR: CartridgeAR::load\n";
    return false;
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
std::array<uInt8, 294> CartridgeAR::ourDummyROMCode = {
  0xa5, 0xfa, 0x85, 0x80, 0x4c, 0x18, 0xf8, 0xff,
  0xff, 0xff, 0x78, 0xd8, 0xa0, 0x00, 0xa2, 0x00,
  0x94, 0x00, 0xe8, 0xd0, 0xfb, 0x4c, 0x50, 0xf8,
  0xa2, 0x00, 0xbd, 0x06, 0xf0, 0xad, 0xf8, 0xff,
  0xa2, 0x00, 0xad, 0x00, 0xf0, 0xea, 0xbd, 0x00,
  0xf7, 0xca, 0xd0, 0xf6, 0x4c, 0x50, 0xf8, 0xff,
  0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
  0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
  0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
  0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
  0xa2, 0x03, 0xbc, 0x22, 0xf9, 0x94, 0xfa, 0xca,
  0x10, 0xf8, 0xa0, 0x00, 0xa2, 0x28, 0x94, 0x04,
  0xca, 0x10, 0xfb, 0xa2, 0x1c, 0x94, 0x81, 0xca,
  0x10, 0xfb, 0xa9, 0xff, 0xc9, 0x00, 0xd0, 0x03,
  0x4c, 0x13, 0xf9, 0xa9, 0x00, 0x85, 0x1b, 0x85,
  0x1c, 0x85, 0x1d, 0x85, 0x1e, 0x85, 0x1f, 0x85,
  0x19, 0x85, 0x1a, 0x85, 0x08, 0x85, 0x01, 0xa9,
  0x10, 0x85, 0x21, 0x85, 0x02, 0xa2, 0x07, 0xca,
  0xca, 0xd0, 0xfd, 0xa9, 0x00, 0x85, 0x20, 0x85,
  0x10, 0x85, 0x11, 0x85, 0x02, 0x85, 0x2a, 0xa9,
  0x05, 0x85, 0x0a, 0xa9, 0xff, 0x85, 0x0d, 0x85,
  0x0e, 0x85, 0x0f, 0x85, 0x84, 0x85, 0x85, 0xa9,
  0xf0, 0x85, 0x83, 0xa9, 0x74, 0x85, 0x09, 0xa9,
  0x0c, 0x85, 0x15, 0xa9, 0x1f, 0x85, 0x17, 0x85,
  0x82, 0xa9, 0x07, 0x85, 0x19, 0xa2, 0x08, 0xa0,
  0x00, 0x85, 0x02, 0x88, 0xd0, 0xfb, 0x85, 0x02,
  0x85, 0x02, 0xa9, 0x02, 0x85, 0x02, 0x85, 0x00,
  0x85, 0x02, 0x85, 0x02, 0x85, 0x02, 0xa9, 0x00,
  0x85, 0x00, 0xca, 0x10, 0xe4, 0x06, 0x83, 0x66,
  0x84, 0x26, 0x85, 0xa5, 0x83, 0x85, 0x0d, 0xa5,
  0x84, 0x85, 0x0e, 0xa5, 0x85, 0x85, 0x0f, 0xa6,
  0x82, 0xca, 0x86, 0x82, 0x86, 0x17, 0xe0, 0x0a,
  0xd0, 0xc3, 0xa9, 0x02, 0x85, 0x01, 0xa2, 0x1c,
  0xa0, 0x00, 0x84, 0x19, 0x84, 0x09, 0x94, 0x81,
  0xca, 0x10, 0xfb, 0xa6, 0x80, 0xdd, 0x00, 0xf0,
  0xa9, 0x9a, 0xa2, 0xff, 0xa0, 0x00, 0x9a, 0x4c,
  0xfa, 0x00, 0xcd, 0xf8, 0xff, 0x4c
};
