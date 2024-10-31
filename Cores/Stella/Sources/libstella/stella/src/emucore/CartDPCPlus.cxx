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

#ifdef DEBUGGER_SUPPORT
  #include "Debugger.hxx"
#endif
#include "MD5.hxx"
#include "Settings.hxx"
#include "System.hxx"
#include "CartDPCPlus.hxx"
#include "exception/FatalEmulationError.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartridgeDPCPlus::CartridgeDPCPlus(const ByteBuffer& image, size_t size,
                                   string_view md5, const Settings& settings)
  : CartridgeARM(settings, md5),
    myImage{make_unique<uInt8[]>(32_KB)},
    mySize{std::min(size, 32_KB)}
{
  // Image is always 32K, but in the case of ROM < 32K, the image is
  // copied to the end of the buffer
  if(mySize < 32_KB)
    std::fill_n(myImage.get(), mySize, 0);
  std::copy_n(image.get(), size, myImage.get() + (32_KB - mySize));
  createRomAccessArrays(24_KB);

  // Pointer to the program ROM (24K @ 3K offset; ignore first 3K)
  myProgramImage = myImage.get() + 3_KB;

  // Pointer to the display RAM
  myDisplayImage = myDPCRAM.data() + 3_KB;

  // Pointer to the Frequency RAM
  myFrequencyImage = myDisplayImage + 4_KB;

  // Create Thumbulator ARM emulator
  const bool devSettings = settings.getBool("dev.settings");
  myThumbEmulator = make_unique<Thumbulator>
      (reinterpret_cast<uInt16*>(myImage.get()),
       reinterpret_cast<uInt16*>(myDPCRAM.data()),
       static_cast<uInt32>(32_KB),
      0x00000C00,
      0x00000C08,
      0x40001FFC,
       devSettings ? settings.getBool("dev.thumb.trapfatal") : false,
       devSettings ? static_cast<double>(
          settings.getFloat("dev.thumb.cyclefactor")) : 1.0,
       Thumbulator::ConfigureFor::DPCplus,
       this);

  // Currently 4 DPC+ driver versions have been identified:
  //   17884ec14f9b1d06fe8d617a1fbdcf47  Jitter  Encore Compatible
  //   5f80b5a5adbe483addc3f6e6f1b472f8  Stable  Encore Compatible
  //   8dd73b44fd11c488326ce507cbeb19d1  Stable  NOT Encore Compatible
  //   b328dbdf787400c0f0e2b88b425872a5  Jitter  Encore Compatible
  //
  // Jitter/Stable refers to the appearance of the playfield in bB games if
  // the DFxFRACINC registers are not updated before every drawscreen.
  //
  // The default mask for DFxFRACLOW implements the Jitter behavior. This
  // changes the mask to implement the Stable behavior.
  myDriverMD5 = MD5::hash(image, 3_KB);
  if(myDriverMD5 == "5f80b5a5adbe483addc3f6e6f1b472f8" ||
     myDriverMD5 == "8dd73b44fd11c488326ce507cbeb19d1" )
    myFractionalLowMask = 0x0F0000;

  this->setInitialState();  // NOLINT

  myPlusROM = make_unique<PlusROM>(mySettings, *this);

  // Determine whether we have a PlusROM cart
  myPlusROM->initialize(myImage, mySize);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeDPCPlus::reset()
{
  setInitialState();

  // DPC+ always starts in bank 5
  initializeStartBank(5);

  // Upon reset we switch to the startup bank
  bank(startBank());

  CartridgeARM::reset();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeDPCPlus::setInitialState()
{
  // Reset various ROM and RAM locations
  myDPCRAM.fill(0);

  // Copy initial DPC display data and Frequency table state to Harmony RAM
  std::copy_n(myProgramImage + 24_KB, 5_KB, myDisplayImage);

  // Initialize the DPC data fetcher registers
  myTops.fill(0);
  myBottoms.fill(0);
  myFractionalIncrements.fill(0);
  myFractionalCounters.fill(0);
  myCounters.fill(0);

  // Set waveforms to first waveform entry
  myMusicWaveforms.fill(0);

  // Initialize the DPC's random number generator register (must be non-zero)
  myRandomNumber = 0x2B435044; // "DPC+"

  // Initialize various other parameters
  myFastFetch = myLDAimmediate = false;
  myAudioCycles = myARMCycles = 0;
  myFractionalClocks = 0.0;

  CartridgeARM::setInitialState();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeDPCPlus::install(System& system)
{
  mySystem = &system;

  // Map all of the accesses to call peek and poke
  const System::PageAccess access(this, System::PageAccessType::READ);
  for(uInt16 addr = 0x1000; addr < 0x1080; addr += System::PAGE_SIZE)
    mySystem->setPageAccess(addr, access);

  // Install pages for the startup bank
  bank(startBank());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FORCE_INLINE void CartridgeDPCPlus::clockRandomNumberGenerator()
{
  // Update random number generator (32-bit LFSR)
  myRandomNumber = ((myRandomNumber & (1<<10)) ? 0x10adab1e: 0x00) ^
                   ((myRandomNumber >> 11) | (myRandomNumber << 21));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FORCE_INLINE void CartridgeDPCPlus::priorClockRandomNumberGenerator()
{
  // Update random number generator (32-bit LFSR, reversed)
  myRandomNumber = ((myRandomNumber & (1U<<31)) ?
    ((0x10adab1e^myRandomNumber) << 11) | ((0x10adab1e^myRandomNumber) >> 21) :
    (myRandomNumber << 11) | (myRandomNumber >> 21));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FORCE_INLINE void CartridgeDPCPlus::updateMusicModeDataFetchers()
{
  // Calculate the number of cycles since the last update
  const auto cycles = static_cast<uInt32>(mySystem->cycles() - myAudioCycles);
  myAudioCycles = mySystem->cycles();

  // Calculate the number of DPC+ OSC clocks since the last update
  const double clocks = ((20000.0 * cycles) / myClockRate) + myFractionalClocks;
  const auto wholeClocks = static_cast<uInt32>(clocks);
  myFractionalClocks = clocks - static_cast<double>(wholeClocks);

  // Let's update counters and flags of the music mode data fetchers
  if(wholeClocks > 0)
    for(int x = 0; x <= 2; ++x)
      myMusicCounters[x] += myMusicFrequencies[x] * wholeClocks;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
inline void CartridgeDPCPlus::callFunction(uInt8 value)
{
  // myParameter
  const uInt16 ROMdata = (myParameter[1] << 8) + myParameter[0];
  switch (value)
  {
    case 0: // Parameter Pointer reset
      myParameterPointer = 0;
      break;
    case 1: // Copy ROM to fetcher
      for(int i = 0; i < myParameter[3]; ++i)
        myDisplayImage[myCounters[myParameter[2] & 0x7]+i] = myProgramImage[ROMdata+i];
      myParameterPointer = 0;
      break;
    case 2: // Copy value to fetcher
      for(int i = 0; i < myParameter[3]; ++i)
        myDisplayImage[myCounters[myParameter[2]]+i] = myParameter[0];
      myParameterPointer = 0;
      break;
      // Call user written ARM code (most likely be C compiled for ARM)
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
    default:  // reserved
      break;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 CartridgeDPCPlus::peek(uInt16 address)
{
  // Is this a PlusROM?
  if(myPlusROM->isValid())
  {
    uInt8 value = 0;
    if(myPlusROM->peekHotspot(address, value))
      return value;
  }

  address &= 0x0FFF;

  const uInt8 peekvalue = myProgramImage[myBankOffset + address];

  // In debugger/bank-locked mode, we ignore all hotspots and in general
  // anything that can change the internal state of the cart
  if(hotspotsLocked())
    return peekvalue;

  // Check if we're in Fast Fetch mode and the prior byte was an A9 (LDA #value)
  if(myFastFetch && myLDAimmediate)
  {
    if(peekvalue < 0x0028)
      // if #value is a read-register then we want to use that as the address
      address = peekvalue;
  }
  myLDAimmediate = false;

  if(address < 0x0028)
  {
    uInt8 result = 0;

    // Get the index of the data fetcher that's being accessed
    const uInt32 index = address & 0x07;
    const uInt32 function = (address >> 3) & 0x07;

    // Update flag for selected data fetcher
    const uInt8 flag = (((myTops[index]-(myCounters[index] & 0x00ff)) & 0xFF) > ((myTops[index]-myBottoms[index]) & 0xFF)) ? 0xFF : 0;

    switch(function)
    {
      case 0x00:
      {
        switch(index)
        {
          case 0x00:  // RANDOM0NEXT - advance and return byte 0 of random
            clockRandomNumberGenerator();
            result = myRandomNumber & 0xFF;
            break;

          case 0x01:  // RANDOM0PRIOR - return to prior and return byte 0 of random
            priorClockRandomNumberGenerator();
            result = myRandomNumber & 0xFF;
            break;

          case 0x02:  // RANDOM1
            result = (myRandomNumber>>8) & 0xFF;
            break;

          case 0x03:  // RANDOM2
            result = (myRandomNumber>>16) & 0xFF;
            break;

          case 0x04:  // RANDOM3
            result = (myRandomNumber>>24) & 0xFF;
            break;

          case 0x05: // AMPLITUDE
          {
            // Update the music data fetchers (counter & flag)
            updateMusicModeDataFetchers();

            // using myDisplayImage[] instead of myProgramImage[] because waveforms
            // can be modified during runtime.
            const uInt32 i =
                myDisplayImage[(myMusicWaveforms[0] << 5) + (myMusicCounters[0] >> 27)] +
                myDisplayImage[(myMusicWaveforms[1] << 5) + (myMusicCounters[1] >> 27)] +
                myDisplayImage[(myMusicWaveforms[2] << 5) + (myMusicCounters[2] >> 27)];

            result = static_cast<uInt8>(i);
            break;
          }

          case 0x06:  // reserved
          case 0x07:  // reserved
            break;

          default:
            break;
        }
        break;
      }

      // DFxDATA - display data read
      case 0x01:
      {
        result = myDisplayImage[myCounters[index]];
        myCounters[index] = (myCounters[index] + 0x1) & 0x0fff;
        break;
      }

      // DFxDATAW - display data read AND'd w/flag ("windowed")
      case 0x02:
      {
        result = myDisplayImage[myCounters[index]] & flag;
        myCounters[index] = (myCounters[index] + 0x1) & 0x0fff;
        break;
      }

      // DFxFRACDATA - display data read w/fractional increment
      case 0x03:
      {
        result = myDisplayImage[myFractionalCounters[index] >> 8];
        myFractionalCounters[index] = (myFractionalCounters[index] + myFractionalIncrements[index]) & 0x0fffff;
        break;
      }

      case 0x04:
      {
        switch (index)
        {
          case 0x00:  // DF0FLAG
          case 0x01:  // DF1FLAG
          case 0x02:  // DF2FLAG
          case 0x03:  // DF3FLAG
          {
            result = flag;
            break;
          }
          case 0x04:  // reserved
          case 0x05:  // reserved
          case 0x06:  // reserved
          case 0x07:  // reserved
            break;
          default:
            break;
        }
        break;
      }

      default:
      {
        result = 0;
      }
    }

    return result;
  }
  else
  {
    // Switch banks if necessary
    switch(address)
    {
      case 0x0FF6:
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
        // Set the current bank to the last 4k bank
        bank(5);
        break;

      default:
        break;
    }

    if(myFastFetch)
      myLDAimmediate = (peekvalue == 0xA9);

    return peekvalue;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeDPCPlus::poke(uInt16 address, uInt8 value)
{
  // Is this a PlusROM?
  if(myPlusROM->isValid() && myPlusROM->pokeHotspot(address, value))
    return true;

  address &= 0x0FFF;

  if((address >= 0x0028) && (address < 0x0080))
  {
    // Get the index of the data fetcher that's being accessed
    const uInt32 index = address & 0x07;
    const uInt32 function = ((address - 0x28) >> 3) & 0x0f;

    switch(function)
    {
      // DFxFRACLOW - fractional data pointer low byte
      case 0x00:
        myFractionalCounters[index] =
          (myFractionalCounters[index] & myFractionalLowMask) | (static_cast<uInt16>(value) << 8);
        break;

      // DFxFRACHI - fractional data pointer high byte
      case 0x01:
        myFractionalCounters[index] = ((static_cast<uInt16>(value) & 0x0F) << 16) |
                                       (myFractionalCounters[index] & 0x00ffff);
        break;

      //DFxFRACINC - Fractional Increment amount
      case 0x02:
        myFractionalIncrements[index] = value;
        myFractionalCounters[index] = myFractionalCounters[index] & 0x0FFF00;
        break;

      // DFxTOP - set top of window (for reads of DFxDATAW)
      case 0x03:
        myTops[index] = value;
        break;

      // DFxBOT - set bottom of window (for reads of DFxDATAW)
      case 0x04:
        myBottoms[index] = value;
        break;

      // DFxLOW - data pointer low byte
      case 0x05:
        myCounters[index] = (myCounters[index] & 0x0F00) | value ;
        break;

      // Control registers
      case 0x06:
        switch (index)
        {
          case 0x00:  // FASTFETCH - turns on LDA #<DFxDATA mode of value is 0
            myFastFetch = (value == 0);
            break;

          case 0x01:  // PARAMETER - set parameter used by CALLFUNCTION (not all functions use the parameter)
            if(myParameterPointer < 8)
              myParameter[myParameterPointer++] = value;
            break;

          case 0x02:  // CALLFUNCTION
            callFunction(value);
            break;

          case 0x03:  // reserved
          case 0x04:  // reserved
            break;

          case 0x05:  // WAVEFORM0
          case 0x06:  // WAVEFORM1
          case 0x07:  // WAVEFORM2
            myMusicWaveforms[index - 5] =  value & 0x7f;
            break;
          default:
            break;
        }
        break;

      // DFxPUSH - Push value into data bank
      case 0x07:
      {
        myCounters[index] = (myCounters[index] - 0x1) & 0x0fff;
        myDisplayImage[myCounters[index]] = value;
        break;
      }

      // DFxHI - data pointer high byte
      case 0x08:
      {
        myCounters[index] = ((static_cast<uInt16>(value) & 0x0F) << 8) | (myCounters[index] & 0x00ff);
        break;
      }

      case 0x09:
      {
        switch (index)
        {
          case 0x00:  // RRESET - Random Number Generator Reset
          {
            myRandomNumber = 0x2B435044; // "DPC+"
            break;
          }
          case 0x01:  // RWRITE0 - update byte 0 of random number
          {
            myRandomNumber = (myRandomNumber & 0xFFFFFF00) | value;
            break;
          }
          case 0x02:  // RWRITE1 - update byte 1 of random number
          {
            myRandomNumber = (myRandomNumber & 0xFFFF00FF) | (value<<8);
            break;
          }
          case 0x03:  // RWRITE2 - update byte 2 of random number
          {
            myRandomNumber = (myRandomNumber & 0xFF00FFFF) | (value<<16);
            break;
          }
          case 0x04:  // RWRITE3 - update byte 3 of random number
          {
            myRandomNumber = (myRandomNumber & 0x00FFFFFF) | (value<<24);
            break;
          }
          case 0x05:  // NOTE0
          case 0x06:  // NOTE1
          case 0x07:  // NOTE2
          {
            myMusicFrequencies[index-5] = myFrequencyImage[(value<<2)] +
            (myFrequencyImage[(value<<2)+1]<<8) +
            (myFrequencyImage[(value<<2)+2]<<16) +
            (myFrequencyImage[(value<<2)+3]<<24);
            break;
          }
          default:
            break;
        }
        break;
      }

      // DFxWRITE - write into data bank
      case 0x0a:
      {
        myDisplayImage[myCounters[index]] = value;
        myCounters[index] = (myCounters[index] + 0x1) & 0x0fff;
        break;
      }

      default:
        break;
    }
  }
  else
  {
    // Switch banks if necessary
    switch(address)
    {
      case 0x0FF6:
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
        // Set the current bank to the last 4k bank
        bank(5);
        break;

      default:
        break;
    }
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeDPCPlus::bank(uInt16 bank, uInt16)
{
  if(hotspotsLocked()) return false;

  // Remember what bank we're in
  myBankOffset = bank << 12;

  // Setup the page access methods for the current bank
  System::PageAccess access(this, System::PageAccessType::READ);

  // Map Program ROM image into the system
  for(uInt16 addr = 0x1080; addr < 0x2000; addr += System::PAGE_SIZE)
  {
    access.romAccessBase = &myRomAccessBase[myBankOffset + (addr & 0x0FFF)];
    access.romPeekCounter = &myRomAccessCounter[myBankOffset + (addr & 0x0FFF)];
    access.romPokeCounter = &myRomAccessCounter[myBankOffset + (addr & 0x0FFF) + 24_KB];
    mySystem->setPageAccess(addr, access);
  }
  return myBankChanged = true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt16 CartridgeDPCPlus::getBank(uInt16) const
{
  return myBankOffset >> 12;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt16 CartridgeDPCPlus::romBankCount() const
{
  return 6;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeDPCPlus::patch(uInt16 address, uInt8 value)
{
  address &= 0x0FFF;

  // For now, we ignore attempts to patch the DPC address space
  if(address >= 0x0080)
  {
    myProgramImage[myBankOffset + (address & 0x0FFF)] = value;
    return myBankChanged = true;
  }
  else
    return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const ByteBuffer& CartridgeDPCPlus::getImage(size_t& size) const
{
  size = mySize;
  return myImage;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 CartridgeDPCPlus::internalRamGetValue(uInt16 addr) const
{
  if(addr < internalRamSize())
    return myDPCRAM[addr];
  else
    return 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeDPCPlus::save(Serializer& out) const
{
  try
  {
    // Indicates which bank is currently active
    out.putShort(myBankOffset);

    // Harmony RAM
    out.putByteArray(myDPCRAM.data(), myDPCRAM.size());

    // The top registers for the data fetchers
    out.putByteArray(myTops.data(), myTops.size());

    // The bottom registers for the data fetchers
    out.putByteArray(myBottoms.data(), myBottoms.size());

    // The counter registers for the data fetchers
    out.putShortArray(myCounters.data(), myCounters.size());

    // The counter registers for the fractional data fetchers
    out.putIntArray(myFractionalCounters.data(), myFractionalCounters.size());

    // The fractional registers for the data fetchers
    out.putByteArray(myFractionalIncrements.data(), myFractionalIncrements.size());

    // The Fast Fetcher Enabled flag
    out.putBool(myFastFetch);
    out.putBool(myLDAimmediate);

    // Control Byte to update
    out.putByteArray(myParameter.data(), myParameter.size());

    // The music counters
    out.putIntArray(myMusicCounters.data(), myMusicCounters.size());

    // The music frequencies
    out.putIntArray(myMusicFrequencies.data(), myMusicFrequencies.size());

    // The music waveforms
    out.putShortArray(myMusicWaveforms.data(), myMusicWaveforms.size());

    // The random number generator register
    out.putInt(myRandomNumber);

    // Get system cycles and fractional clocks
    out.putLong(myAudioCycles);
    out.putDouble(myFractionalClocks);

    // Clock info for Thumbulator
    out.putLong(myARMCycles);

    CartridgeARM::save(out);
  }
  catch(...)
  {
    cerr << "ERROR: CartridgeDPCPlus::save\n";
    return false;
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeDPCPlus::load(Serializer& in)
{
  try
  {
    // Indicates which bank is currently active
    myBankOffset = in.getShort();

    // Harmony RAM
    in.getByteArray(myDPCRAM.data(), myDPCRAM.size());

    // The top registers for the data fetchers
    in.getByteArray(myTops.data(), myTops.size());

    // The bottom registers for the data fetchers
    in.getByteArray(myBottoms.data(), myBottoms.size());

    // The counter registers for the data fetchers
    in.getShortArray(myCounters.data(), myCounters.size());

    // The counter registers for the fractional data fetchers
    in.getIntArray(myFractionalCounters.data(), myFractionalCounters.size());

    // The fractional registers for the data fetchers
    in.getByteArray(myFractionalIncrements.data(), myFractionalIncrements.size());

    // The Fast Fetcher Enabled flag
    myFastFetch = in.getBool();
    myLDAimmediate = in.getBool();

    // Control Byte to update
    in.getByteArray(myParameter.data(), myParameter.size());

    // The music mode counters for the data fetchers
    in.getIntArray(myMusicCounters.data(), myMusicCounters.size());

    // The music mode frequency addends for the data fetchers
    in.getIntArray(myMusicFrequencies.data(), myMusicFrequencies.size());

    // The music waveforms
    in.getShortArray(myMusicWaveforms.data(), myMusicWaveforms.size());

    // The random number generator register
    myRandomNumber = in.getInt();

    // Get audio cycles and fractional clocks
    myAudioCycles = in.getLong();
    myFractionalClocks = in.getDouble();

    // Clock info for Thumbulator
    myARMCycles = in.getLong();

    CartridgeARM::load(in);
  }
  catch(...)
  {
    cerr << "ERROR: CartridgeDPCPlus::load\n";
    return false;
  }

  // Now, go to the current bank
  bank(myBankOffset >> 12);

  return true;
}
