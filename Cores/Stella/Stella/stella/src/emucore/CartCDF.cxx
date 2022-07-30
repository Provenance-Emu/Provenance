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
// Copyright (c) 1995-2022 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#include <cstring>

#ifdef DEBUGGER_SUPPORT
  #include "Debugger.hxx"
  #include "CartCDFWidget.hxx"
  #include "CartCDFInfoWidget.hxx"
#endif

#include "System.hxx"
#include "CartCDF.hxx"
#include "TIA.hxx"
#include "exception/FatalEmulationError.hxx"

static constexpr bool FAST_FETCH_ON(uInt8 mode)    { return (mode & 0x0F) == 0; }
static constexpr bool DIGITAL_AUDIO_ON(uInt8 mode) { return (mode & 0xF0) == 0; }

static constexpr uInt32 getUInt32(const uInt8* _array, size_t _address) {
  return static_cast<uInt32>((_array)[(_address) + 0]        +
                            ((_array)[(_address) + 1] << 8)  +
                            ((_array)[(_address) + 2] << 16) +
                            ((_array)[(_address) + 3] << 24));
}

namespace {
  Thumbulator::ConfigureFor thumulatorConfiguration(CartridgeCDF::CDFSubtype subtype)
  {
    switch (subtype) {
      case CartridgeCDF::CDFSubtype::CDF0:
        return Thumbulator::ConfigureFor::CDF;

      case CartridgeCDF::CDFSubtype::CDF1:
        return Thumbulator::ConfigureFor::CDF1;

      case CartridgeCDF::CDFSubtype::CDFJ:
        return Thumbulator::ConfigureFor::CDFJ;

      case CartridgeCDF::CDFSubtype::CDFJplus:
        return Thumbulator::ConfigureFor::CDFJplus;

      default:
        throw runtime_error("unreachable");
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartridgeCDF::CartridgeCDF(const ByteBuffer& image, size_t size,
                           const string& md5, const Settings& settings)
  : CartridgeARM(md5, settings)
{
  // Copy the ROM image into my buffer
  mySize = std::min(size, 512_KB);
  myImage = make_unique<uInt8[]>(mySize);
  std::copy_n(image.get(), mySize, myImage.get());

  // Detect cart version
  setupVersion();

  // The lowest 2K is not accessible to the debugger
  createRomAccessArrays(isCDFJplus() ? mySize - 2_KB : 28_KB);

  // Pointer to the program ROM
  // which starts after the 2K driver (and 2K C Code for CDF)
  myProgramImage = myImage.get() + (isCDFJplus() ? 2_KB : 4_KB);

  // Pointer to CDF driver in RAM
  myDriverImage = myRAM.data();

  // Pointer to the display RAM (starts after 2K driver)
  myDisplayImage = myRAM.data() + 2_KB;

  // C addresses
  uInt32 cBase = 0, cStart = 0, cStack = 0;
  if (isCDFJplus()) {
    cBase = getUInt32(myImage.get(), 0x17F8) & 0xFFFFFFFE;    // C Base Address
    cStart = cBase;                                           // C Start Address
    cStack = getUInt32(myImage.get(), 0x17F4);                // C Stack
  } else {
    cBase = 0x800;          // C Base Address
    cStart = 0x808;         // C Start Address (skip ARM header)
    cStack = 0x40001FFC;    // C Stack
  }

  // Create Thumbulator ARM emulator
  bool devSettings = settings.getBool("dev.settings");
  myThumbEmulator = make_unique<Thumbulator>(
    reinterpret_cast<uInt16*>(myImage.get()),
    reinterpret_cast<uInt16*>(myRAM.data()),
    static_cast<uInt32>(mySize),
    cBase, cStart, cStack,
    devSettings ? settings.getBool("dev.thumb.trapfatal") : false,
    devSettings ? static_cast<double>(
      settings.getFloat("dev.thumb.cyclefactor")) : 1.0,
    thumulatorConfiguration(myCDFSubtype),
    this);

  this->setInitialState();

  myPlusROM = make_unique<PlusROM>(mySettings, *this);

  // Determine whether we have a PlusROM cart
  myPlusROM->initialize(myImage, mySize);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeCDF::reset()
{
  initializeRAM(myRAM.data()+2_KB, myRAM.size()-2_KB);

  // CDF always starts in bank 6, CDFJ+ in bank 0
  initializeStartBank(isCDFJplus() ? 0 : 6);

  myAudioCycles = myARMCycles = 0;
  myFractionalClocks = 0.0;

  setInitialState();

  // Upon reset we switch to the startup bank
  bank(startBank());

  CartridgeARM::reset();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeCDF::setInitialState()
{
  // Copy initial CDF driver to Harmony RAM
  std::copy_n(myImage.get(), 2_KB, myDriverImage);

  myMusicWaveformSize.fill(27);

  // Assuming mode starts out with Fast Fetch off and 3-Voice music,
  // need to confirm with Chris
  myMode = 0xFF;

  myBankOffset = myJMPoperandAddress = 0;
  myFastJumpActive = myFastJumpStream = 0;
  myLDAXYimmediateOperandAddress = LDAXY_OVERRIDE_INACTIVE;

  CartridgeARM::setInitialState();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeCDF::install(System& system)
{
  mySystem = &system;

  // Map all of the accesses to call peek and poke
  const System::PageAccess access(this, System::PageAccessType::READ);
  for(uInt16 addr = 0x1000; addr < 0x1040; addr += System::PAGE_SIZE)
    mySystem->setPageAccess(addr, access);

  // Install pages for the startup bank
  bank(startBank());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
inline void CartridgeCDF::updateMusicModeDataFetchers()
{
  // Calculate the number of cycles since the last update
  const uInt32 cycles = static_cast<uInt32>(mySystem->cycles() - myAudioCycles);
  myAudioCycles = mySystem->cycles();

  // Calculate the number of CDF OSC clocks since the last update
  const double clocks = ((20000.0 * cycles) / myClockRate) + myFractionalClocks;
  uInt32 wholeClocks = static_cast<uInt32>(clocks);
  myFractionalClocks = clocks - static_cast<double>(wholeClocks);

  // Let's update counters and flags of the music mode data fetchers
  if(wholeClocks > 0)
    for(int x = 0; x <= 2; ++x)
      myMusicCounters[x] += myMusicFrequencies[x] * wholeClocks;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
inline void CartridgeCDF::callFunction(uInt8 value)
{
  switch (value)
  {
    // Call user written ARM code (will most likely be C compiled for ARM)
    case 254: // call with IRQ driven audio, no special handling needed at this
              // time for Stella as ARM code "runs in zero 6507 cycles".
    case 255: // call without IRQ driven audio
      try {
        uInt32 cycles = static_cast<uInt32>(mySystem->cycles() - myARMCycles);

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
uInt8 CartridgeCDF::peek(uInt16 address)
{
  // Is this a PlusROM?
  if(myPlusROM->isValid())
  {
    uInt8 value = 0;
    if(myPlusROM->peekHotspot(address, value))
      return value;
  }

  address &= 0x0FFF;
  uInt8 peekvalue = myProgramImage[myBankOffset + address];

  // In debugger/bank-locked mode, we ignore all hotspots and in general
  // anything that can change the internal state of the cart
  if(hotspotsLocked())
    return peekvalue;

  // implement JMP FASTJMP which fetches the destination address from stream 33
  if (myFastJumpActive
      && myJMPoperandAddress == address)
  {
    --myFastJumpActive;
    ++myJMPoperandAddress;

    uInt32 pointer = getDatastreamPointer(myFastJumpStream);
    uInt8 value = 0;
    if (isCDFJplus()) {
      value = myDisplayImage[ pointer >> 16 ];
      pointer += 0x00010000;  // always increment by 1
    } else {
      value = myDisplayImage[ pointer >> 20 ];
      pointer += 0x00100000;  // always increment by 1
    }

    setDatastreamPointer(myFastJumpStream, pointer);

    return value;
  }

  // test for JMP FASTJUMP where FASTJUMP = $0000
  if (FAST_FETCH_ON(myMode)
      && peekvalue == 0x4C
      && (myProgramImage[myBankOffset + address+1] & myFastjumpStreamIndexMask) == 0
      && myProgramImage[myBankOffset + address+2] == 0)
  {
    myFastJumpActive = 2; // return next two peeks from datastream 31
    myJMPoperandAddress = address + 1;
    myFastJumpStream = myProgramImage[myBankOffset + address+1] + JUMPSTREAM_BASE;
    return peekvalue;
  }

  myJMPoperandAddress = 0;

  // Do a FAST FETCH LDA# if:
  //  1) in Fast Fetch mode
  //  2) peeking the operand of an LDA # instruction
  //  3) peek value is between myDSfetcherOffset and myDSfetcherOffset+34 inclusive
  bool fastfetch = false;
  if (myFastFetcherOffset)
    fastfetch = (FAST_FETCH_ON(myMode) && myLDAXYimmediateOperandAddress == address
                 && peekvalue >= myRAM[myFastFetcherOffset]
                 && peekvalue <= myRAM[myFastFetcherOffset]+myAmplitudeStream);
  else
    fastfetch = (FAST_FETCH_ON(myMode) && myLDAXYimmediateOperandAddress == address
                 && peekvalue <= myAmplitudeStream);
  if (fastfetch)
  {
    myLDAXYimmediateOperandAddress = LDAXY_OVERRIDE_INACTIVE;
    if (myFastFetcherOffset)
      peekvalue -= myRAM[myFastFetcherOffset]; // normalize peekvalue to 0 - 35
    if (peekvalue == myAmplitudeStream)
    {
      updateMusicModeDataFetchers();

      if (DIGITAL_AUDIO_ON(myMode))
      {
        // retrieve packed sample (max size is 2K, or 4K of unpacked data)

        const uInt32 sampleaddress = getSample() + (myMusicCounters[0] >> (isCDFJplus() ? 13 : 21));

        // get sample value from ROM or RAM
        if (sampleaddress < 0x00080000)
          peekvalue = myImage[sampleaddress];
        else if (sampleaddress >= 0x40000000 && sampleaddress < 0x40008000) // check for RAM
          peekvalue = myRAM[sampleaddress - 0x40000000];
        else
          peekvalue = 0;

        // make sure current volume value is in the lower nybble
        if ((myMusicCounters[0] & (1<<(isCDFJplus() ? 12 : 20))) == 0)
          peekvalue >>= 4;
        peekvalue &= 0x0f;
      }
      else
      {
        peekvalue = myDisplayImage[getWaveform(0) + (myMusicCounters[0] >> myMusicWaveformSize[0])]
                  + myDisplayImage[getWaveform(1) + (myMusicCounters[1] >> myMusicWaveformSize[1])]
                  + myDisplayImage[getWaveform(2) + (myMusicCounters[2] >> myMusicWaveformSize[2])];
      }
      return peekvalue;
    }
    else
    {
      return readFromDatastream(peekvalue);
    }
  }
  myLDAXYimmediateOperandAddress = LDAXY_OVERRIDE_INACTIVE;

  // Switch banks if necessary
  switch(address)
  {
    case 0x0FF4:
      bank(isCDFJplus() ? 0 : 6);
      break;

    case 0x0FF5:
      bank(isCDFJplus() ? 1 : 0);
      break;

    case 0x0FF6:
      bank(isCDFJplus() ? 2 : 1);
      break;

    case 0x0FF7:
      bank(isCDFJplus() ? 3 : 2);
      break;

    case 0x0FF8:
      bank(isCDFJplus() ? 4 : 3);
      break;

    case 0x0FF9:
      bank(isCDFJplus() ? 5 : 4);
      break;

    case 0x0FFA:
      bank(isCDFJplus() ? 6 : 5);
      break;

    case 0x0FFB:
      bank(isCDFJplus() ? 0 : 6);
      break;

    default:
      break;
  }

  if (FAST_FETCH_ON(myMode))
  {
    if ((peekvalue == 0xA9) ||
        (myLDXenabled && peekvalue == 0xA2 ) ||
        (myLDYenabled && peekvalue == 0xA0))
      myLDAXYimmediateOperandAddress = address + 1;
  }

  return peekvalue;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeCDF::poke(uInt16 address, uInt8 value)
{
  uInt32 pointer = 0;

  // Is this a PlusROM?
  if(myPlusROM->isValid() && myPlusROM->pokeHotspot(address, value))
    return true;

  address &= 0x0FFF;
  switch(address)
  {
    case 0x0FF0:   // DSWRITE
      pointer = getDatastreamPointer(COMMSTREAM);
      if (isCDFJplus()) {
        myDisplayImage[ pointer >> 16 ] = value;
        pointer += 0x00010000;  // always increment by 1 when writing
      } else {
        myDisplayImage[ pointer >> 20 ] = value;
        pointer += 0x00100000;  // always increment by 1 when writing
      }
      setDatastreamPointer(COMMSTREAM, pointer);
      break;

    case 0x0FF1:   // DSPTR
      pointer = getDatastreamPointer(COMMSTREAM);
      pointer <<= 8;
      if (isCDFJplus()) {
        pointer &= 0xff000000;
        pointer |= (value << 16);
      } else {
        pointer &= 0xf0000000;
        pointer |= (value << 20);
      }
      setDatastreamPointer(COMMSTREAM, pointer);
      break;

    case 0x0FF2:   // SETMODE
      myMode = value;
      break;

    case 0x0FF3:   // CALLFN
      callFunction(value);
      break;

   case 0x00FF4:
      bank(isCDFJplus() ? 0 : 6);
      break;

    case 0x0FF5:
      bank(isCDFJplus() ? 1 : 0);
      break;

    case 0x0FF6:
      bank(isCDFJplus() ? 2 : 1);
      break;

    case 0x0FF7:
      bank(isCDFJplus() ? 3 : 2);
      break;

    case 0x0FF8:
      bank(isCDFJplus() ? 4 : 3);
      break;

    case 0x0FF9:
      bank(isCDFJplus() ? 5 : 4);
      break;

    case 0x0FFA:
      bank(isCDFJplus() ? 6 : 5);
      break;

    case 0x0FFB:
      bank(isCDFJplus() ? 0 : 6);
      break;

    default:
      break;
  }

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeCDF::bank(uInt16 bank, uInt16)
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
    access.romPokeCounter = &myRomAccessCounter[myBankOffset + (addr & 0x0FFF) + 28_KB];  // TODO: Change for CDFJ+???
    mySystem->setPageAccess(addr, access);
  }
  return myBankChanged = true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt16 CartridgeCDF::getBank(uInt16) const
{
  return myBankOffset >> 12;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt16 CartridgeCDF::romBankCount() const
{
  return 7;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeCDF::patch(uInt16 address, uInt8 value)
{
  address &= 0x0FFF;

  // For now, we ignore attempts to patch the CDF address space
  if(address >= 0x0040)
  {
    myProgramImage[myBankOffset + (address & 0x0FFF)] = value;
    return myBankChanged = true;
  }
  else
    return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const ByteBuffer& CartridgeCDF::getImage(size_t& size) const
{
  size = mySize;
  return myImage;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 CartridgeCDF::thumbCallback(uInt8 function, uInt32 value1, uInt32 value2)
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
uInt8 CartridgeCDF::internalRamGetValue(uInt16 addr) const
{
  if(addr < internalRamSize())
    return myRAM[addr];
  else
    return 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeCDF::save(Serializer& out) const
{
  try
  {
    // Indicates which bank is currently active
    out.putShort(myBankOffset);

    // Indicates current mode
    out.putByte(myMode);

    // State of FastJump
    out.putByte(myFastJumpActive);

    // operand addresses
    out.putShort(myLDAXYimmediateOperandAddress);
    out.putShort(myJMPoperandAddress);

    // Harmony RAM
    out.putByteArray(myRAM.data(), myRAM.size());

    // Audio info
    out.putIntArray(myMusicCounters.data(), myMusicCounters.size());
    out.putIntArray(myMusicFrequencies.data(), myMusicFrequencies.size());
    out.putByteArray(myMusicWaveformSize.data(), myMusicWaveformSize.size());

    // Save cycles and clocks
    out.putLong(myAudioCycles);
    out.putDouble(myFractionalClocks);
    out.putLong(myARMCycles);

    CartridgeARM::save(out);
  }
  catch(...)
  {
    cerr << "ERROR: CartridgeCDF::save" << endl;
    return false;
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeCDF::load(Serializer& in)
{
  try
  {
    // Indicates which bank is currently active
    myBankOffset = in.getShort();

    // Indicates current mode
    myMode = in.getByte();

    // State of FastJump
    myFastJumpActive = in.getByte();

    // Address of LDA # operand
    myLDAXYimmediateOperandAddress = in.getShort();
    myJMPoperandAddress = in.getShort();

    // Harmony RAM
    in.getByteArray(myRAM.data(), myRAM.size());

    // Audio info
    in.getIntArray(myMusicCounters.data(), myMusicCounters.size());
    in.getIntArray(myMusicFrequencies.data(), myMusicFrequencies.size());
    in.getByteArray(myMusicWaveformSize.data(), myMusicWaveformSize.size());

    // Get cycles and clocks
    myAudioCycles = in.getLong();
    myFractionalClocks = in.getDouble();
    myARMCycles = in.getLong();

    CartridgeARM::load(in);
  }
  catch(...)
  {
    cerr << "ERROR: CartridgeCDF::load" << endl;
    return false;
  }

  // Now, go to the current bank
  bank(myBankOffset >> 12);

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 CartridgeCDF::getDatastreamPointer(uInt8 index) const
{
  const uInt16 address = myDatastreamBase + index * 4;

  return myRAM[address + 0]        +  // low byte
        (myRAM[address + 1] << 8)  +
        (myRAM[address + 2] << 16) +
        (myRAM[address + 3] << 24) ;  // high byte
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeCDF::setDatastreamPointer(uInt8 index, uInt32 value)
{
  const uInt16 address = myDatastreamBase + index * 4;

  myRAM[address + 0] = value & 0xff;          // low byte
  myRAM[address + 1] = (value >> 8) & 0xff;
  myRAM[address + 2] = (value >> 16) & 0xff;
  myRAM[address + 3] = (value >> 24) & 0xff;  // high byte
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 CartridgeCDF::getDatastreamIncrement(uInt8 index) const
{
  const uInt16 address = myDatastreamIncrementBase + index * 4;

  return myRAM[address + 0]        +   // low byte
        (myRAM[address + 1] << 8)  +
        (myRAM[address + 2] << 16) +
        (myRAM[address + 3] << 24) ;   // high byte
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 CartridgeCDF::getWaveform(uInt8 index) const
{
  const uInt16 address = myWaveformBase + index * 4;

  uInt32 result = myRAM[address + 0]        +  // low byte
                 (myRAM[address + 1] << 8)  +
                 (myRAM[address + 2] << 16) +
                 (myRAM[address + 3] << 24);   // high byte

  result -= (0x40000000 + static_cast<uInt32>(2_KB));

  if (!isCDFJplus()) {
    if (result >= 4096) {
      result &= 4095;
    }
  }
  return result;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 CartridgeCDF::getSample()
{
  const uInt16 address = myWaveformBase;

  const uInt32 result = myRAM[address + 0]        +  // low byte
                       (myRAM[address + 1] << 8)  +
                       (myRAM[address + 2] << 16) +
                       (myRAM[address + 3] << 24);   // high byte

  return result;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 CartridgeCDF::getWaveformSize(uInt8 index) const
{
  return myMusicWaveformSize[index];
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 CartridgeCDF::readFromDatastream(uInt8 index)
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

  uInt8 value = 0;
  if (isCDFJplus())
  {
    value = myDisplayImage[ pointer >> 16 ];
    pointer += (increment << 8);
  }
  else
  {
    value = myDisplayImage[ pointer >> 20 ];
    pointer += (increment << 12);
  }

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
uInt32 CartridgeCDF::scanCDFDriver(uInt32 searchValue)
{
  for (int i = 0; i < 2048; i += 4)
    if (getUInt32(myImage.get(), i) == searchValue)
      return i;

  return 0xFFFFFFFF;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeCDF::setupVersion()
{
  // CDFJ+ detection

  // get offset of CDFJPlus ID
  uInt32 cdfjOffset = 0;

  if ((cdfjOffset = scanCDFDriver(0x53554c50)) != 0xFFFFFFFF && // Plus
      getUInt32(myImage.get(), cdfjOffset+4) == 0x4a464443 &&   // CDFJ
      getUInt32(myImage.get(), cdfjOffset+8) == 0x00000001) {   // V1
    myCDFSubtype = CDFSubtype::CDFJplus;
    myAmplitudeStream = 0x23;
    myFastjumpStreamIndexMask = 0xfe;
    myDatastreamBase = 0x0098;
    myDatastreamIncrementBase = 0x0124;
    myFastFetcherOffset = 0;
    myWaveformBase = 0x01b0;

    for (int i = 0; i < 2048; i += 4)
    {
      const uInt32 cdfjValue = getUInt32(myImage.get(), i);
      if (cdfjValue == 0x135200A2)
        myLDXenabled = true;
      if (cdfjValue == 0x135200A0)
        myLDYenabled = true;

      // search for Fast Fetcher Offset (default is 0)
      if ((cdfjValue & 0xFFFFFF00) == 0xE2422000)
        myFastFetcherOffset = i;
    }

    return;
  }

  uInt8 subversion = 0;
  for(uInt32 i = 0; i < 2048; i += 4)
  {
    // CDF signature occurs 3 times in a row, i+3 (+7 or +11) is version
    if (    myImage[i+0] == 0x43 && myImage[i + 4] == 0x43 && myImage[i + 8] == 0x43) // C
      if (  myImage[i+1] == 0x44 && myImage[i + 5] == 0x44 && myImage[i + 9] == 0x44) // D
        if (myImage[i+2] == 0x46 && myImage[i + 6] == 0x46 && myImage[i +10] == 0x46) // F
        {
          subversion = myImage[i+3];
          break;
        }
  }

  switch (subversion)
  {
    case 0x4a:
      myCDFSubtype = CDFSubtype::CDFJ;

      myAmplitudeStream = 0x23;
      myFastjumpStreamIndexMask = 0xfe;
      myDatastreamBase = 0x0098;
      myDatastreamIncrementBase = 0x0124;
      myWaveformBase = 0x01b0;

      break;

    case 0:
      myCDFSubtype = CDFSubtype::CDF0;

      myAmplitudeStream = 0x22;
      myFastjumpStreamIndexMask = 0xff;
      myDatastreamBase = 0x06e0;
      myDatastreamIncrementBase = 0x0768;
      myWaveformBase = 0x07f0;

      break;

    default:
      myCDFSubtype = CDFSubtype::CDF1;

      myAmplitudeStream = 0x22;
      myFastjumpStreamIndexMask = 0xff;
      myDatastreamBase = 0x00a0;
      myDatastreamIncrementBase = 0x0128;
      myWaveformBase = 0x01b0;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartridgeCDF::name() const
{
  switch(myCDFSubtype)
  {
    case CDFSubtype::CDF0:
      return "CartridgeCDF0";
    case CDFSubtype::CDF1:
      return "CartridgeCDF1";
    case CDFSubtype::CDFJ:
      return "CartridgeCDFJ";
    case CDFSubtype::CDFJplus:
      return "CartridgeCDFJ+";
    default:
      return "Cart unknown";
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeCDF::isCDFJplus() const
{
  return (myCDFSubtype == CDFSubtype::CDFJplus);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 CartridgeCDF::ramSize() const
{
  return static_cast<uInt32>(isCDFJplus() ? 32_KB : 8_KB);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 CartridgeCDF::romSize() const
{
  return static_cast<uInt32>(isCDFJplus() ? mySize : 32_KB);
}

#ifdef DEBUGGER_SUPPORT
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  CartDebugWidget* CartridgeCDF::debugWidget(GuiObject* boss, const GUI::Font& lfont,
                               const GUI::Font& nfont, int x, int y, int w, int h)
  {
    return new CartridgeCDFWidget(boss, lfont, nfont, x, y, w, h, *this);
  }

  CartDebugWidget* CartridgeCDF::infoWidget(GuiObject* boss, const GUI::Font& lfont,
                                             const GUI::Font& nfont, int x, int y, int w, int h)
  {
    return new CartridgeCDFInfoWidget(boss, lfont, nfont, x, y, w, h, *this);
  }
#endif
