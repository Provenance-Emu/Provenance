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

#include "Settings.hxx"
#include "System.hxx"
#include "AudioSettings.hxx"
#include "CartDPC.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartridgeDPC::CartridgeDPC(const ByteBuffer& image, size_t size,
                           string_view md5, const Settings& settings,
                           size_t bsSize)
  : CartridgeF8(image, size, md5, settings, bsSize)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeDPC::reset()
{
  CartridgeEnhanced::reset();

  myAudioCycles = 0;
  myFractionalClocks = 0.0;
  myDpcPitch = mySettings.getInt(AudioSettings::SETTING_DPC_PITCH);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeDPC::consoleChanged(ConsoleTiming timing)
{
  constexpr double NTSC  = 1193191.66666667;  // NTSC  6507 clock rate
  constexpr double PAL   = 1182298.0;         // PAL   6507 clock rate
  constexpr double SECAM = 1187500.0;         // SECAM 6507 clock rate

  switch(timing)
  {
    case ConsoleTiming::ntsc:   myClockRate = NTSC;   break;
    case ConsoleTiming::pal:    myClockRate = PAL;    break;
    case ConsoleTiming::secam:  myClockRate = SECAM;  break;
    default:  break;  // satisfy compiler
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeDPC::install(System& system)
{
  CartridgeEnhanced::install(system);

  myRomOffset = 0x80;

  // Pointer to the display ROM (2K @ 8K offset)
  myDisplayImage = myImage.get() + 8_KB;

  createRomAccessArrays(8_KB);

  // Set the page accessing method for the DPC reading & writing pages
  const System::PageAccess access(this, System::PageAccessType::READWRITE);
  for(uInt16 addr = 0x1000; addr < 0x1080; addr += System::PAGE_SIZE)
    mySystem->setPageAccess(addr, access);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FORCE_INLINE void CartridgeDPC::clockRandomNumberGenerator()
{
  // Table for computing the input bit of the random number generator's
  // shift register (it's the NOT of the EOR of four bits)
  static constexpr std::array<uInt8, 16> f = {
    1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1
  };

  // Using bits 7, 5, 4, & 3 of the shift register compute the input
  // bit for the shift register
  const uInt8 bit = f[((myRandomNumber >> 3) & 0x07) |
      ((myRandomNumber & 0x80) ? 0x08 : 0x00)];

  // Update the shift register
  myRandomNumber = (myRandomNumber << 1) | bit;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FORCE_INLINE void CartridgeDPC::updateMusicModeDataFetchers()
{
  // Calculate the number of cycles since the last update
  const auto cycles = static_cast<uInt32>(mySystem->cycles() - myAudioCycles);
  myAudioCycles = mySystem->cycles();

  // Calculate the number of DPC OSC clocks since the last update
  const double clocks = ((myDpcPitch * cycles) / myClockRate) + myFractionalClocks;
  const auto wholeClocks = static_cast<uInt32>(clocks);
  myFractionalClocks = clocks - static_cast<double>(wholeClocks);

  if(wholeClocks == 0)
    return;

  // Let's update counters and flags of the music mode data fetchers
  for(int x = 5; x <= 7; ++x)
  {
    // Update only if the data fetcher is in music mode
    if(myMusicMode[x - 5])
    {
      const Int32 top = myTops[x] + 1;
      auto newLow = static_cast<Int32>(myCounters[x] & 0x00ff);

      if(myTops[x] != 0)
      {
        newLow -= (wholeClocks % top);
        if(newLow < 0)
          newLow += top;
      }
      else
        newLow = 0;

      // Update flag register for this data fetcher
      if(newLow <= myBottoms[x])
        myFlags[x] = 0x00;
      else if(newLow <= myTops[x])
        myFlags[x] = 0xff;

      myCounters[x] = (myCounters[x] & 0x0700) | static_cast<uInt16>(newLow);
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 CartridgeDPC::peek(uInt16 address)
{
  const uInt16 peekAddress = address;

  address &= 0x0FFF;

  // In debugger/bank-locked mode, we ignore all hotspots and in general
  // anything that can change the internal state of the cart
  if(hotspotsLocked())
    return myImage[myCurrentSegOffset[0] + address];

  // Clock the random number generator.  This should be done for every
  // cartridge access, however, we're only doing it for the DPC and
  // hot-spot accesses to save time.
  clockRandomNumberGenerator();

  if(address < 0x0040)
  {
    uInt8 result = 0;

    // Get the index of the data fetcher that's being accessed
    const uInt32 index = address & 0x07;
    const uInt32 function = (address >> 3) & 0x07;

    // Update flag register for selected data fetcher
    if((myCounters[index] & 0x00ff) == myTops[index])
    {
      myFlags[index] = 0xff;
    }
    else if((myCounters[index] & 0x00ff) == myBottoms[index])
    {
      myFlags[index] = 0x00;
    }

    switch(function)
    {
      case 0x00:
      {
        // Is this a random number read
        if(index < 4)
        {
          result = myRandomNumber;
        }
        // No, it's a music read
        else
        {
          static constexpr std::array<uInt8, 8> musicAmplitudes = {
              0x00, 0x04, 0x05, 0x09, 0x06, 0x0a, 0x0b, 0x0f
          };

          // Update the music data fetchers (counter & flag)
          updateMusicModeDataFetchers();

          uInt8 i = 0;
          if(myMusicMode[0] && myFlags[5])
          {
            i |= 0x01;
          }
          if(myMusicMode[1] && myFlags[6])
          {
            i |= 0x02;
          }
          if(myMusicMode[2] && myFlags[7])
          {
            i |= 0x04;
          }

          result = musicAmplitudes[i];
        }
        break;
      }

      // DFx display data read
      case 0x01:
      {
        result = myDisplayImage[2047 - myCounters[index]];
        break;
      }

      // DFx display data read AND'd w/flag
      case 0x02:
      {
        result = myDisplayImage[2047 - myCounters[index]] & myFlags[index];
        break;
      }

      // DFx flag
      case 0x07:
      {
        result = myFlags[index];
        break;
      }

      default:
      {
        result = 0;
      }
    }

    // Clock the selected data fetcher's counter if needed
    if(index < 5 || !myMusicMode[index - 5])
    {
      myCounters[index] = (myCounters[index] - 1) & 0x07ff;
    }

    return result;
  }
  else
    return CartridgeEnhanced::peek(peekAddress);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeDPC::poke(uInt16 address, uInt8 value)
{
  const uInt16 pokeAddress = address;

  address &= 0x0FFF;

  // Clock the random number generator.  This should be done for every
  // cartridge access, however, we're only doing it for the DPC and
  // hot-spot accesses to save time.
  clockRandomNumberGenerator();

  if((address >= 0x0040) && (address < 0x0080))
  {
    // Get the index of the data fetcher that's being accessed
    const uInt32 index = address & 0x07;
    const uInt32 function = (address >> 3) & 0x07;

    switch(function)
    {
      // DFx top count
      case 0x00:
      {
        myTops[index] = value;
        myFlags[index] = 0x00;
        break;
      }

      // DFx bottom count
      case 0x01:
      {
        myBottoms[index] = value;
        break;
      }

      // DFx counter low
      case 0x02:
      {
        if((index >= 5) && myMusicMode[index - 5])
        {
          // Data fetcher is in music mode so its low counter value
          // should be loaded from the top register not the poked value
          myCounters[index] = (myCounters[index] & 0x0700) |
            static_cast<uInt16>(myTops[index]);
        }
        else
        {
          // Data fetcher is either not a music mode data fetcher or it
          // isn't in music mode so it's low counter value should be loaded
          // with the poked value
          myCounters[index] = (myCounters[index] & 0x0700) | static_cast<uInt16>(value);
        }
        break;
      }

      // DFx counter high
      case 0x03:
      {
        myCounters[index] = ((static_cast<uInt16>(value) & 0x07) << 8) |
            (myCounters[index] & 0x00ff);

        // Execute special code for music mode data fetchers
        if(index >= 5)
        {
          myMusicMode[index - 5] = (value & 0x10);

          // NOTE: We are not handling the clock source input for
          // the music mode data fetchers.  We're going to assume
          // they always use the OSC input.
        }
        break;
      }

      // Random Number Generator Reset
      case 0x06:
      {
        myRandomNumber = 1;
        break;
      }

      default:
        break;
    }
  }
  else
    CartridgeEnhanced::poke(pokeAddress, value);

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeDPC::patch(uInt16 address, uInt8 value)
{
  // For now, we ignore attempts to patch the DPC address space
  if((address & ADDR_MASK) >= ROM_OFFSET + myRomOffset)
  {
    return CartridgeEnhanced::patch(address, value);
  }
  else
    return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeDPC::save(Serializer& out) const
{
  if(!CartridgeEnhanced::save(out))
    return false;

  try
  {
    // The top registers for the data fetchers
    out.putByteArray(myTops.data(), myTops.size());

    // The bottom registers for the data fetchers
    out.putByteArray(myBottoms.data(), myBottoms.size());

    // The counter registers for the data fetchers
    out.putShortArray(myCounters.data(), myCounters.size());

    // The flag registers for the data fetchers
    out.putByteArray(myFlags.data(), myFlags.size());

    // The music mode flags for the data fetchers
    for(const auto& mode: myMusicMode)
      out.putBool(mode);

    // The random number generator register
    out.putByte(myRandomNumber);

    out.putLong(myAudioCycles);
    out.putDouble(myFractionalClocks);
  }
  catch(...)
  {
    cerr << "ERROR: CartridgeDPC::save\n";
    return false;
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeDPC::load(Serializer& in)
{
  if(!CartridgeEnhanced::load(in))
    return false;

  try
  {
    // The top registers for the data fetchers
    in.getByteArray(myTops.data(), myTops.size());

    // The bottom registers for the data fetchers
    in.getByteArray(myBottoms.data(), myBottoms.size());

    // The counter registers for the data fetchers
    in.getShortArray(myCounters.data(), myCounters.size());

    // The flag registers for the data fetchers
    in.getByteArray(myFlags.data(), myFlags.size());

    // The music mode flags for the data fetchers
    for(auto& mode: myMusicMode)
      mode = in.getBool();

    // The random number generator register
    myRandomNumber = in.getByte();

    // Get system cycles and fractional clocks
    myAudioCycles = in.getLong();
    myFractionalClocks = in.getDouble();
  }
  catch(...)
  {
    cerr << "ERROR: CartridgeDPC::load\n";
    return false;
  }
  return true;
}
