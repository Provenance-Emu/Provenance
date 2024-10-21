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

#include <cstring>

#ifdef DEBUGGER_SUPPORT
  #include "Debugger.hxx"
  #include "CartBUSWidget.hxx"
  #include "CartBUSInfoWidget.hxx"
#endif
#include "System.hxx"
#include "M6532.hxx"
#include "TIA.hxx"
#include "CartBUS.hxx"
#include "exception/FatalEmulationError.hxx"

namespace {
  // Location of data within the RAM copy of the BUS Driver.
  constexpr int
    COMMSTREAM = 0x10,
    JUMPSTREAM = 0x11;

  constexpr bool BUS_STUFF_ON(uInt8 mode) { return (mode & 0x0F) == 0; }
  constexpr bool DIGITAL_AUDIO_ON(uInt8 mode) { return (mode & 0xF0) == 0; }

  constexpr uInt32 getUInt32(const uInt8* _array, size_t _address) {
    return static_cast<uInt32>((_array)[(_address) + 0]        +
                              ((_array)[(_address) + 1] << 8)  +
                              ((_array)[(_address) + 2] << 16) +
                              ((_array)[(_address) + 3] << 24));
  }
} // namespace

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartridgeBUS::CartridgeBUS(const ByteBuffer& image, size_t size,
                           string_view md5, const Settings& settings)
  : CartridgeARM(settings, md5),
    myImage{make_unique<uInt8[]>(32_KB)}
{
  // Copy the ROM image into my buffer
  std::copy_n(image.get(), std::min(32_KB, size), myImage.get());

  // Detect cart version
  setupVersion();

  // Pointer to BUS driver in RAM
  myDriverImage = myRAM.data();

  const bool devSettings = settings.getBool("dev.settings");

  if (myBUSSubtype == BUSSubtype::BUS0)
  {
    // BUS0 driver is 3K, so configuration is different from others
    createRomAccessArrays(24_KB);

    // Pointer to the program ROM (28K @ 0 byte offset)
    myProgramImage = myImage.get() + 3_KB;

    // Pointer to the display RAM
    myDisplayImage = myRAM.data() + 0x0C00;

    // Create Thumbulator ARM emulator
    myThumbEmulator = make_unique<Thumbulator>(
      reinterpret_cast<uInt16*>(myImage.get()),
      reinterpret_cast<uInt16*>(myRAM.data()),
      static_cast<uInt32>(32_KB),
      0x00000C00,
      0x00000C08,
      0x40001FFC,
      devSettings ? settings.getBool("dev.thumb.trapfatal") : false,
      devSettings ? static_cast<double>(
          settings.getFloat("dev.thumb.cyclefactor")) : 1.0,
      Thumbulator::ConfigureFor::BUS,
      this);
  }
  else
  {
    // BUS1+ drivers are 2K
    createRomAccessArrays(28_KB);

    // Pointer to the program ROM (28K @ 0 byte offset)
    myProgramImage = myImage.get() + 4_KB;

    // Pointer to the display RAM
    myDisplayImage = myRAM.data() + 0x0800;

    // Create Thumbulator ARM emulator
    myThumbEmulator = make_unique<Thumbulator>(
      reinterpret_cast<uInt16*>(myImage.get()),
      reinterpret_cast<uInt16*>(myRAM.data()),
      static_cast<uInt32>(32_KB),
      0x00000800,
      0x00000808,
      0x40001FFC,
      devSettings ? settings.getBool("dev.thumb.trapfatal") : false,
      devSettings ? static_cast<double>(
          settings.getFloat("dev.thumb.cyclefactor")) : 1.0,
      Thumbulator::ConfigureFor::BUS,
      this);
  }

  this->setInitialState();  // NOLINT

  myPlusROM = make_unique<PlusROM>(mySettings, *this);

  // Determine whether we have a PlusROM cart
  myPlusROM->initialize(myImage, size);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeBUS::reset()
{
  if (myBUSSubtype == BUSSubtype::BUS0)
  {
    initializeRAM(myRAM.data() + 3_KB, 5_KB);
    initializeStartBank(5); // BUS0 always starts in bank 5
  }
  else
  {
    initializeRAM(myRAM.data() + 2_KB, 6_KB);
    initializeStartBank(6); // BUS1+ always starts in bank 6
  }

  // Update cycles to the current system cycles
  myAudioCycles = myARMCycles = 0;
  myFractionalClocks = 0.0;

  setInitialState();

  // Upon reset we switch to the startup bank
  bank(startBank());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeBUS::setInitialState()
{
  // Copy initial BUS driver to Harmony RAM
  if (myBUSSubtype == BUSSubtype::BUS0)
    std::copy_n(myImage.get(), 3_KB, myDriverImage);
  else
    std::copy_n(myImage.get(), 2_KB, myDriverImage);

  myMusicWaveformSize.fill(27);

  // Assuming mode starts out with Fast Fetch off and 3-Voice music,
  // need to confirm with Chris
  myMode = 0xFF;

  myBankOffset = myBusOverdriveAddress =
    mySTYZeroPageAddress = myJMPoperandAddress = 0;

  myFastJumpActive = 0;

  CartridgeARM::setInitialState();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeBUS::install(System& system)
{
  mySystem = &system;

  // Map all of the accesses to call peek and poke
  const System::PageAccess access(this, System::PageAccessType::READ);
  for(uInt16 addr = 0x1000; addr < 0x1040; addr += System::PAGE_SIZE)
    mySystem->setPageAccess(addr, access);

  // Mirror all access in TIA and RIOT; by doing so we're taking responsibility
  // for that address space in peek and poke below.
  mySystem->tia().installDelegate(system, *this);
  mySystem->m6532().installDelegate(system, *this);

  // Install pages for the startup bank
  bank(startBank());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
inline void CartridgeBUS::updateMusicModeDataFetchers()
{
  // Calculate the number of cycles since the last update
  const auto cycles = static_cast<uInt32>(mySystem->cycles() - myAudioCycles);
  myAudioCycles = mySystem->cycles();

  // Calculate the number of BUS OSC clocks since the last update
  const double clocks = ((20000.0 * cycles) / myClockRate) + myFractionalClocks;
  const auto wholeClocks = static_cast<uInt32>(clocks);
  myFractionalClocks = clocks - static_cast<double>(wholeClocks);

  // Let's update counters and flags of the music mode data fetchers
  if(wholeClocks > 0)
    for(int x = 0; x <= 2; ++x)
      myMusicCounters[x] += myMusicFrequencies[x] * wholeClocks;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
inline void CartridgeBUS::callFunction(uInt8 value)
{
  switch (value)
  {
    // Call user written ARM code (will most likely be C compiled for ARM)
    case 254: // call with IRQ driven audio, no special handling needed at this
              // time for Stella as ARM code "runs in zero 6507 cycles".
    case 255: // call without IRQ driven audio
      try {
        auto cycles = static_cast<uInt32>(mySystem->cycles() - myARMCycles);

        myARMCycles = mySystem->cycles();
        myThumbEmulator->run(cycles, value == 254);
        updateCycles(cycles);
      }
      catch(const runtime_error& e) {
        if(!mySystem->autodetectMode())
        {
          FatalEmulationError::raise(e.what());
        }
      }
      break;
    default:
      break;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 CartridgeBUS::peek(uInt16 address)
{
  // Is this a PlusROM?
  if(myPlusROM->isValid())
  {
    uInt8 value = 0;
    if(myPlusROM->peekHotspot(address, value))
      return value;
  }

  if(!(address & 0x1000))                      // Hotspots below 0x1000
  {
    // Check for RAM or TIA mirroring
    const uInt16 lowAddress = address & 0x3ff;
    if(lowAddress & 0x80)
      return mySystem->m6532().peek(address);
    else if(!(lowAddress & 0x200))
      return mySystem->tia().peek(address);
  }
  else
  {
    address &= 0x0FFF;

    uInt8 peekvalue = myProgramImage[myBankOffset + address];

    // In debugger/bank-locked mode, we ignore all hotspots and in general
    // anything that can change the internal state of the cart
    if(hotspotsLocked())
      return peekvalue;

    if (myBUSSubtype == BUSSubtype::BUS3)
    {
      // Fast Jump only supported in BUS3
      // implement JMP FASTJMP which fetches the destination address from stream 17
      if (myFastJumpActive
          && myJMPoperandAddress == address)
      {
        --myFastJumpActive;
        ++myJMPoperandAddress;

        uInt32 pointer = getDatastreamPointer(JUMPSTREAM);
        const uInt8 value = myDisplayImage[pointer >> 20];
        pointer += 0x100000;  // always increment by 1
        setDatastreamPointer(JUMPSTREAM, pointer);

        return value;
      }

      // test for JMP FASTJUMP where FASTJUMP = $0000
      if (BUS_STUFF_ON(myMode)
          && peekvalue == 0x4C
          && myProgramImage[myBankOffset + address+1] == 0
          && myProgramImage[myBankOffset + address+2] == 0)
      {
        myFastJumpActive = 2; // return next two peeks from datastream 17
        myJMPoperandAddress = address + 1;
        return peekvalue;
      }

      myJMPoperandAddress = 0;
    }

    // save the STY's zero page address
    if (BUS_STUFF_ON(myMode) && mySTYZeroPageAddress == address)
      myBusOverdriveAddress =  peekvalue;

    mySTYZeroPageAddress = 0;

    if (address < 0x20 &&
        (myBUSSubtype == BUSSubtype::BUS1 || myBUSSubtype == BUSSubtype::BUS2))
    {
      uInt8 result = 0;

      // Get the index of the data fetcher that's being accessed
      const uInt32 index = address & 0x0f;
      const uInt32 function = (address >> 4) & 0x01;

      switch(function)
      {
        case 0x00:  // read from a datastream
        {
          result = readFromDatastream(index);
          break;
        }
        case 0x01:  // misc read registers
        {
          switch(index)
          {
              // the following are POKE ONLY
            case 0x00:  // 0x10 DF0WRITE
            case 0x01:  // 0x11 DF1WRITE
            case 0x02:  // 0x12 DF2WRITE
            case 0x03:  // 0x13 DF3WRITE
            case 0x04:  // 0x14 DF0PTR
            case 0x05:  // 0x15 DF1PTR
            case 0x06:  // 0x16 DF2PTR
            case 0x07:  // 0x17 DF3PTR
            case 0x09:  // 0x19 STUFFMODE
            case 0x0a:  // 0x1A CALLFN
              break;

            case 0x08:  // 0x18 = AMPLITUDE
            {
              // Update the music data fetchers (counter & flag)
              updateMusicModeDataFetchers();

              // using myDisplayImage[] instead of myProgramImage[] because waveforms
              // can be modified during runtime.
              const uInt32 i = myDisplayImage[(getWaveform(0)) + (myMusicCounters[0] >> myMusicWaveformSize[0])] +
                myDisplayImage[(getWaveform(1)) + (myMusicCounters[1] >> myMusicWaveformSize[1])] +
                myDisplayImage[(getWaveform(2)) + (myMusicCounters[2] >> myMusicWaveformSize[2])];

              result = static_cast<uInt8>(i);
              break;
            }

            default:
              break;
          }
          break;
        }

        default:
          break;
      }

      return result;
    }
    else if (address >= 0xFEE && address <= 0xFF3 && myBUSSubtype == BUSSubtype::BUS3)
    {
      switch(address)
      {
        case 0xFEE: // AMPLITUDE
          // Update the music data fetchers (counter & flag)
          updateMusicModeDataFetchers();

          if (DIGITAL_AUDIO_ON(myMode))
          {
            // retrieve packed sample (max size is 2K, or 4K of unpacked data)
            const uInt32 sampleaddress = getSample() + (myMusicCounters[0] >> 21);

            // get sample value from ROM or RAM
            if (sampleaddress < 0x8000)
              peekvalue = myImage[sampleaddress];
            else if (sampleaddress >= 0x40000000 && sampleaddress < 0x40002000) // check for RAM
              peekvalue = myRAM[sampleaddress - 0x40000000];
            else
              peekvalue = 0;

            // make sure current volume value is in the lower nybble
            if ((myMusicCounters[0] & (1<<20)) == 0)
              peekvalue >>= 4;
            peekvalue &= 0x0f;
          }
          else
          {
            // using myDisplayImage[] instead of myProgramImage[] because waveforms
            // can be modified during runtime.
            const uInt32 i =
                myDisplayImage[(getWaveform(0) ) + (myMusicCounters[0] >> myMusicWaveformSize[0])] +
                myDisplayImage[(getWaveform(1) ) + (myMusicCounters[1] >> myMusicWaveformSize[1])] +
                myDisplayImage[(getWaveform(2) ) + (myMusicCounters[2] >> myMusicWaveformSize[2])];

            peekvalue = static_cast<uInt8>(i);
          }
          break;

        case 0xFEF: // DSREAD
          peekvalue = readFromDatastream(COMMSTREAM);
          break;

        case 0xFF0: // DSWRITE
        case 0xFF1: // DSPTR
        case 0xFF2: // SETMODE
        case 0xFF3: // CALLFN
          // these are write-only
          break;

        default:
          break;
      }
    }
    else if (myBUSSubtype == BUSSubtype::BUS0)
    {
      switch(address)
      {
        case 0x00: case 0x01: case 0x02: case 0x03:
        case 0x04: case 0x05: case 0x06: case 0x07:
        case 0x08: case 0x09: case 0x0a: case 0x0b:
        case 0x0c: case 0x0d: case 0x0e: case 0x0f:
          peekvalue = readFromDatastream(address);
          break;

        case 0xFF6:
          // Set the current bank to the first 4k bank
          bank(0);
          break;

        case 0x0FF7:
          // Set the current bank to the second 4k bank
          bank(1);
          break;

        case 0x0FF8:
          // Set the current bank to the third 4k bank
          bank(2);
          break;

        case 0x0FF9:
          // Set the current bank to the fourth 4k bank
          bank(3);
          break;

        case 0x0FFA:
          // Set the current bank to the fifth 4k bank
          bank(4);
          break;

        case 0x0FFB:
          // Set the current bank to the sixth 4k bank
          bank(5);
          break;

        default:
          break;
      }
//      return result;
    }
    else
    {
      switch(address)
      {
        case 0xFF5:
          // Set the current bank to the first 4k bank
          bank(0);
          break;

        case 0x0FF6:
          // Set the current bank to the second 4k bank
          bank(1);
          break;

        case 0x0FF7:
          // Set the current bank to the third 4k bank
          bank(2);
          break;

        case 0x0FF8:
          // Set the current bank to the fourth 4k bank
          bank(3);
          break;

        case 0x0FF9:
          // Set the current bank to the fifth 4k bank
          bank(4);
          break;

        case 0x0FFA:
          // Set the current bank to the sixth 4k bank
          bank(5);
          break;

        case 0x0FFB:
          // Set the current bank to the last 4k bank
          bank(6);
          break;

        default:
          break;
      }
    }

    // this might not work right for STY $84
    if (BUS_STUFF_ON(myMode) && peekvalue == 0x84)
      mySTYZeroPageAddress = address + 1;

    return peekvalue;
  }

  return 0;  // make compiler happy
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeBUS::poke(uInt16 address, uInt8 value)
{
  // Is this a PlusROM?
  if(myPlusROM->isValid() && myPlusROM->pokeHotspot(address, value))
    return true;

  if (!(address & 0x1000))
  {
    value &= busOverdrive(address);

    // Check for RAM or TIA mirroring
    const uInt16 lowAddress = address & 0x3ff;
    if(lowAddress & 0x80)
      mySystem->m6532().poke(address, value);
    else if(!(lowAddress & 0x200))
      mySystem->tia().poke(address, value);
  }
  else
  {
    address &= 0x0FFF;

    if (myBUSSubtype == BUSSubtype::BUS0)
    {
      uInt32 index = address & 0x0f;
      uInt32 pointer = 0, increment = 0;

      switch(address)
      {
        case 0x10:  // DS0WRITE
        case 0x11:  // DS1WRITE
        case 0x12:  // DS2WRITE
        case 0x13:  // DS3WRITE
          // Pointers are stored as:
          // PPPFF---
          //
          // P = Pointer
          // F = Fractional

          pointer = getDatastreamPointer(index);
          myDisplayImage[ pointer >> 20 ] = value;
          pointer += 0x100000;  // always increment by 1 when writing
          setDatastreamPointer(index, pointer);
          break;

        case 0x1B:  // CALLFN
          callFunction(value);
          break;

        case 0x1c:  // BUSSTUFF
          if (value==0)
            myMode = 0;     // lower nybble 0 = STUFFON in BUS3
          else
            myMode = 0x0f;  // lower nybble f = STUFFOFF in BUS3
          break;

        case 0x20: case 0x21: case 0x22: case 0x23:
        case 0x24: case 0x25: case 0x26: case 0x27:
        case 0x28: case 0x29: case 0x2a: case 0x2b:
        case 0x2c: case 0x2d: case 0x2e: case 0x2f:
          // Pointers are stored as:
          // PPPFF---
          //
          // P = Pointer
          // F = Fractional
          pointer = getDatastreamPointer(index);
          pointer <<=8;
          pointer &= 0xf0000000;
          pointer |= (value << 20);
          setDatastreamPointer(index, pointer);
          break;

        case 0x30: case 0x31: case 0x32: case 0x33: // DSxINC
        case 0x34: case 0x35: case 0x36: case 0x37:
        case 0x38: case 0x39: case 0x3a: case 0x3b:
        case 0x3c: case 0x3d: case 0x3e: case 0x3f:
          // Increments are stored as
          // ----IIFF
          //
          // I = Increment
          // F = Fractional
          increment = getDatastreamIncrement(index);
          index <<= 8;
          index |= value;
          index &= 0xffff;
          setDatastreamIncrement(index, increment);
          break;


        case 0xFF6:
          // Set the current bank to the first 4k bank
          bank(0);
          break;

        case 0x0FF7:
          // Set the current bank to the second 4k bank
          bank(1);
          break;

        case 0x0FF8:
          // Set the current bank to the third 4k bank
          bank(2);
          break;

        case 0x0FF9:
          // Set the current bank to the fourth 4k bank
          bank(3);
          break;

        case 0x0FFA:
          // Set the current bank to the fifth 4k bank
          bank(4);
          break;

        case 0x0FFB:
          // Set the current bank to the sixth 4k bank
          bank(5);
          break;

        default:
          break;
      }
    }
    else if (address >= 0xFF5)
    {
      // bankswitch hotspots same for BUS1+ versions
      switch(address)
      {
        case 0xFF5:
          // Set the current bank to the first 4k bank
          bank(0);
          break;

        case 0x0FF6:
          // Set the current bank to the second 4k bank
          bank(1);
          break;

        case 0x0FF7:
          // Set the current bank to the third 4k bank
          bank(2);
          break;

        case 0x0FF8:
          // Set the current bank to the fourth 4k bank
          bank(3);
          break;

        case 0x0FF9:
          // Set the current bank to the fifth 4k bank
          bank(4);
          break;

        case 0x0FFA:
          // Set the current bank to the sixth 4k bank
          bank(5);
          break;

        case 0x0FFB:
          // Set the current bank to the last 4k bank
          bank(6);
          break;

        default:
          break;
      }
    }
    else if (myBUSSubtype == BUSSubtype::BUS3)
    {
      uInt32 pointer = 0;
      switch(address)
      {
        case 0xFEE: // AMPLITUDE
        case 0xFEF: // DSREAD
          // these are read-only
          break;

        case 0xFF0: // DSWRITE
          pointer = getDatastreamPointer(COMMSTREAM);
          myDisplayImage[ pointer >> 20 ] = value;
          pointer += 0x100000;  // always increment by 1 when writing
          setDatastreamPointer(COMMSTREAM, pointer);
          break;

        case 0xFF1: // DSPTR
          pointer = getDatastreamPointer(COMMSTREAM);
          pointer <<=8;
          pointer &= 0xf0000000;
          pointer |= (value << 20);
          setDatastreamPointer(COMMSTREAM, pointer);
          break;

        case 0xFF2: // SETMODE
          myMode = value;
          break;

        case 0xFF3: // CALLFN
          callFunction(value);
          break;

        default:
          break;
      }
    }
    else // BUS1 and BUS2
    {
      if ((address >= 0x10) && (address <= 0x1F))
      {
        // Get the index of the data fetcher that's being accessed
        uInt32 index = address & 0x0f;
        uInt32 pointer = 0;

        switch (index)
        {
          case 0x00:  // DS0WRITE
          case 0x01:  // DS1WRITE
          case 0x02:  // DS2WRITE
          case 0x03:  // DS3WRITE
            // Pointers are stored as:
            // PPPFF---
            //
            // P = Pointer
            // F = Fractional

            pointer = getDatastreamPointer(index);
            myDisplayImage[ pointer >> 20 ] = value;
            pointer += 0x100000;  // always increment by 1 when writing
            setDatastreamPointer(index, pointer);
            break;

          case 0x04:  // 0x14 DS0PTR
          case 0x05:  // 0x15 DS1PTR
          case 0x06:  // 0x16 DS2PTR
          case 0x07:  // 0x17 DS3PTR
            // Pointers are stored as:
            // PPPFF---
            //
            // P = Pointer
            // F = Fractional

            index &= 0x03;
            pointer = getDatastreamPointer(index);
            pointer <<=8;
            pointer &= 0xf0000000;
            pointer |= (value << 20);
            setDatastreamPointer(index, pointer);
            break;

          case 0x09:  // 0x19 turn on STY ZP bus stuffing if value is 0
            if (value==0)
              myMode = 0;     // lower nybble 0 = STUFFON in BUS3
            else
              myMode = 0x0f;  // lower nybble f = STUFFOFF in BUS3
            break;

          case 0x0A:  // 0x1A CALLFUNCTION
            callFunction(value);
            break;

          default:
            break;
        }
      }
    }
  }

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeBUS::bank(uInt16 bank, uInt16)
{
  if(hotspotsLocked()) return false;

  // Remember what bank we're in
  myBankOffset = bank << 12;

  // Setup the page access methods for the current bank
  System::PageAccess access(this, System::PageAccessType::READ);

  // Map Program ROM image into the system
  for(uInt16 addr = 0x1040; addr < 0x2000; addr += System::PAGE_SIZE)
  {
    access.romAccessBase = &myRomAccessBase[myBankOffset + (addr & 0x0FFF)];
    access.romPeekCounter = &myRomAccessCounter[myBankOffset + (addr & 0x0FFF)];
    access.romPokeCounter = &myRomAccessCounter[myBankOffset + (addr & 0x0FFF) + 28_KB];
    mySystem->setPageAccess(addr, access);
  }
  return myBankChanged = true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt16 CartridgeBUS::getBank(uInt16) const
{
  return myBankOffset >> 12;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt16 CartridgeBUS::romBankCount() const
{
  return 7;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeBUS::patch(uInt16 address, uInt8 value)
{
  address &= 0x0FFF;

  // For now, we ignore attempts to patch the BUS address space
  if(address >= 0x0040)
  {
    myProgramImage[myBankOffset + (address & 0x0FFF)] = value;
    return myBankChanged = true;
  }
  else
    return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const ByteBuffer& CartridgeBUS::getImage(size_t& size) const
{
  size = 32_KB;
  return myImage;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 CartridgeBUS::busOverdrive(uInt16 address)
{
  uInt8 overdrive = 0xff;

  // only overdrive if the address matches
  if (address == myBusOverdriveAddress)
  {
    const uInt8 map = address & 0x7f;
    if (map <= 0x24) // map TIA registers VSYNC thru HMBL inclusive
    {
      uInt32 alldatastreams = getAddressMap(map);
      const uInt8 datastream = alldatastreams & 0x0f;  // lowest nybble has the current datastream to use
      overdrive = readFromDatastream(datastream);

      // rotate map nybbles for next time
      alldatastreams >>= 4;
      alldatastreams |= (datastream << 28);
      setAddressMap(map, alldatastreams);
    }
  }

  myBusOverdriveAddress = 0xff; // turns off overdrive for next poke event

  return overdrive;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 CartridgeBUS::thumbCallback(uInt8 function, uInt32 value1, uInt32 value2)
{
  switch (function)
  {
    case 0:
      // _SetNote - set the note/frequency
      myMusicFrequencies[value1] = value2;
      break;

      // _ResetWave - reset counter,
      // used to make sure digital samples start from the beginning
    case 1:
      myMusicCounters[value1] = 0;
      break;

      // _GetWavePtr - return the counter
    case 2:
      return myMusicCounters[value1];

      // _SetWaveSize - set size of waveform buffer
    case 3:
      myMusicWaveformSize[value1] = value2;
      break;

    default:
      break;
  }

  return 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 CartridgeBUS::internalRamGetValue(uInt16 addr) const
{
  if(addr < internalRamSize())
    return myRAM[addr];
  else
    return 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeBUS::save(Serializer& out) const
{
  try
  {
    // Indicates which bank is currently active
    out.putShort(myBankOffset);

    // Harmony RAM
    out.putByteArray(myRAM.data(), myRAM.size());

    // Addresses for bus override logic
    out.putShort(myBusOverdriveAddress);
    out.putShort(mySTYZeroPageAddress);
    out.putShort(myJMPoperandAddress);

    // Save cycles and clocks
    out.putLong(myAudioCycles);
    out.putDouble(myFractionalClocks);
    out.putLong(myARMCycles);

    // Audio info
    out.putIntArray(myMusicCounters.data(), myMusicCounters.size());
    out.putIntArray(myMusicFrequencies.data(), myMusicFrequencies.size());
    out.putByteArray(myMusicWaveformSize.data(), myMusicWaveformSize.size());

    // Indicates current mode
    out.putByte(myMode);

    // Indicates if in the middle of a fast jump
    out.putByte(myFastJumpActive);

    CartridgeARM::save(out);
  }
  catch(...)
  {
    cerr << "ERROR: CartridgeBUS::save\n";
    return false;
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeBUS::load(Serializer& in)
{
  try
  {
    // Indicates which bank is currently active
    myBankOffset = in.getShort();

    // Harmony RAM
    in.getByteArray(myRAM.data(), myRAM.size());

    // Addresses for bus override logic
    myBusOverdriveAddress = in.getShort();
    mySTYZeroPageAddress = in.getShort();
    myJMPoperandAddress = in.getShort();

    // Get system cycles and fractional clocks
    myAudioCycles = in.getLong();
    myFractionalClocks = in.getDouble();
    myARMCycles = in.getLong();

    // Audio info
    in.getIntArray(myMusicCounters.data(), myMusicCounters.size());
    in.getIntArray(myMusicFrequencies.data(), myMusicFrequencies.size());
    in.getByteArray(myMusicWaveformSize.data(), myMusicWaveformSize.size());

    // Indicates current mode
    myMode = in.getByte();

    // Indicates if in the middle of a fast jump
    myFastJumpActive = in.getByte();

    CartridgeARM::load(in);
  }
  catch(...)
  {
    cerr << "ERROR: CartridgeBUS::load\n";
    return false;
  }

  // Now, go to the current bank
  bank(myBankOffset >> 12);

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 CartridgeBUS::getDatastreamPointer(uInt8 index) const
{
  const uInt16 address = myDatastreamBase + index * 4;

  return myRAM[address + 0]        +  // low byte
        (myRAM[address + 1] << 8)  +
        (myRAM[address + 2] << 16) +
        (myRAM[address + 3] << 24) ;  // high byte
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeBUS::setDatastreamPointer(uInt8 index, uInt32 value)
{
  const uInt16 address = myDatastreamBase + index * 4;

  myRAM[address + 0] = value & 0xff;          // low byte
  myRAM[address + 1] = (value >> 8) & 0xff;
  myRAM[address + 2] = (value >> 16) & 0xff;
  myRAM[address + 3] = (value >> 24) & 0xff;  // high byte
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 CartridgeBUS::getDatastreamIncrement(uInt8 index) const
{
  const uInt16 address = myDatastreamIncrementBase + index * 4;

  return myRAM[address + 0]        +   // low byte
        (myRAM[address + 1] << 8)  +
        (myRAM[address + 2] << 16) +
        (myRAM[address + 3] << 24) ;   // high byte
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeBUS::setDatastreamIncrement(uInt8 index, uInt32 value)
{
  const uInt16 address = myDatastreamIncrementBase + index * 4;

  myRAM[address + 0] = value & 0xff;          // low byte
  myRAM[address + 1] = (value >> 8) & 0xff;
  myRAM[address + 2] = (value >> 16) & 0xff;
  myRAM[address + 3] = (value >> 24) & 0xff;  // high byte
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 CartridgeBUS::getAddressMap(uInt8 index) const
{
  const uInt16 address = myDatastreamMapBase + index * 4;

  return myRAM[address + 0]        +   // low byte
        (myRAM[address + 1] << 8)  +
        (myRAM[address + 2] << 16) +
        (myRAM[address + 3] << 24) ;   // high byte
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 CartridgeBUS::getWaveform(uInt8 index) const
{
  // instead of 0, 1, 2, etc. this returned
  // 0x40000800 for 0
  // 0x40000820 for 1
  // 0x40000840 for 2
  // ...

//  return myBUSRAM[WAVEFORM + index*4 + 0]        +   // low byte
//        (myBUSRAM[WAVEFORM + index*4 + 1] << 8)  +
//        (myBUSRAM[WAVEFORM + index*4 + 2] << 16) +
//        (myBUSRAM[WAVEFORM + index*4 + 3] << 24) -   // high byte
//         0x40000800;

  const uInt16 address = myWaveformBase + index * 4;

  uInt32 result = myRAM[address + 0]        +  // low byte
                 (myRAM[address + 1] << 8)  +
                 (myRAM[address + 2] << 16) +
                 (myRAM[address + 3] << 24);   // high byte

  result -= 0x40000800;

  if (result >= 4096)
    result = 0;

  return result;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 CartridgeBUS::getSample()
{
  const uInt16 address = myWaveformBase;

  const uInt32 result = myRAM[address + 0]        +  // low byte
                       (myRAM[address + 1] << 8)  +
                       (myRAM[address + 2] << 16) +
                       (myRAM[address + 3] << 24);   // high byte
  return result;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 CartridgeBUS::getWaveformSize(uInt8 index) const
{
  return myMusicWaveformSize[index];
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeBUS::setAddressMap(uInt8 index, uInt32 value)
{
  const uInt16 address = myDatastreamMapBase + index * 4;

  myRAM[address + 0] = value & 0xff;          // low byte
  myRAM[address + 1] = (value >> 8) & 0xff;
  myRAM[address + 2] = (value >> 16) & 0xff;
  myRAM[address + 3] = (value >> 24) & 0xff;  // high byte

}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 CartridgeBUS::readFromDatastream(uInt8 index)
{
  // Pointers are stored as:
  // PPPFF---
  //
  // Increments are stored as
  // ----IIFF
  //
  // P = Pointer
  // I = Increment
  // F = Fractional

  uInt32 pointer = getDatastreamPointer(index);
  const uInt16 increment = getDatastreamIncrement(index);
  const uInt8 value = myDisplayImage[pointer >> 20];
  pointer += (increment << 12);
  setDatastreamPointer(index, pointer);
  return value;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// params:
//  - searchValue: uInt32 value to search for; assumes it is on a DWORD boundary
//
// returns:
//  - offset in image where value was found
//  - 0xFFFFFFFF if not found
uInt32 CartridgeBUS::scanBUSDriver(uInt32 searchValue)
{
  // original BUS driver is 3K in size. Later BUS drivers are 2K in size.
  for (int i = 0; i < 3072; i += 4)
    if (getUInt32(myImage.get(), i) == searchValue)
      return i;

  return 0xFFFFFFFF;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeBUS::setupVersion()
{
  // 3 versions of the BUS driver have been found. Location of the BUS
  // strings are in a different location for each.

  // get offset of BUS ID
  const uInt32 busOffset = scanBUSDriver(0x00535542);

  switch(busOffset)
  {
    case 0x7f4: // draconian_20161102.bin
      myBUSSubtype = BUSSubtype::BUS1;
      myDatastreamBase = 0x06E0;
      myDatastreamIncrementBase = 0x0720;
      myDatastreamMapBase = 0x0760;
      myWaveformBase = 0x07F4;
      break;

    case 0x778: // 128bus_20170120.bin, 128chronocolour_20170101.bin, parrot_20161231_NTSC.bin
      myBUSSubtype = BUSSubtype::BUS2;
      myDatastreamBase = 0x06E0;
      myDatastreamIncrementBase = 0x0720;
      myDatastreamMapBase = 0x0760;
      myWaveformBase = 0x07F4;
      break;

    case 0x770: //  rpg_20170616_NTSC.bin newest
      myBUSSubtype = BUSSubtype::BUS3;
      myDatastreamBase = 0x06D8;
      myDatastreamIncrementBase = 0x0720;
      myDatastreamMapBase = 0x0760;
      myWaveformBase = 0x07F4;
      break;

    default: // case 0xbf8: // original BUS driver was 3K in size
      myBUSSubtype = BUSSubtype::BUS0;
//       unsupported
      myDatastreamBase = 0x0AE0;
      myDatastreamIncrementBase = 0x0B20;
      myDatastreamMapBase = 0x0B64;
//      myWaveformBase = 0x07F4;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartridgeBUS::name() const
{
  switch(myBUSSubtype)
  {
    case BUSSubtype::BUS0:
      return "CartridgeBUS0";
    case BUSSubtype::BUS1:
      return "CartridgeBUS1";
    case BUSSubtype::BUS2:
      return "CartridgeBUS2";
    case BUSSubtype::BUS3:
      return "CartridgeBUS3";
    default:
      return "Unsupported BUS";
  }
}

#ifdef DEBUGGER_SUPPORT
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  CartDebugWidget* CartridgeBUS::debugWidget(GuiObject* boss, const GUI::Font& lfont,
                               const GUI::Font& nfont, int x, int y, int w, int h)
  {
    return new CartridgeBUSWidget(boss, lfont, nfont, x, y, w, h, *this);
  }

  CartDebugWidget* CartridgeBUS::infoWidget(GuiObject* boss, const GUI::Font& lfont,
                                             const GUI::Font& nfont, int x, int y, int w, int h)
  {
    return new CartridgeBUSInfoWidget(boss, lfont, nfont, x, y, w, h, *this);
  }
#endif
