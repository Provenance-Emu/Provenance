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

#include "TimerManager.hxx"
#include "CartFA2.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartridgeFA2::CartridgeFA2(const ByteBuffer& image, size_t size,
                           string_view md5, const Settings& settings,
                           size_t bsSize)
  : CartridgeFA(image, size, md5, settings, bsSize)
{
  // 29/32K version of FA2 has valid data @ 1K - 29K
  const uInt8* img_ptr = image.get();
  if(size >= 29_KB)
  {
    img_ptr += 1_KB;
    mySize = 28_KB;
  }

  // Allocate array for the ROM image
  myImage = make_unique<uInt8[]>(mySize);

  // Copy the ROM image into my buffer
  std::copy_n(img_ptr, mySize, myImage.get());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeFA2::checkSwitchBank(uInt16 address, uInt8)
{
  // Switch banks if necessary
  if((address >= 0x1FF5) && (address <= 0x1FFB))
  {
    bank(address - 0x1FF5);
    return true;
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 CartridgeFA2::peek(uInt16 address)
{
  if((address & ROM_MASK) == 0x0FF4)
  {
    // Load/save RAM to/from Harmony cart flash
    if(mySize == 28_KB && !hotspotsLocked())
      return ramReadWrite();
  }

  return CartridgeEnhanced::peek(address);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeFA2::poke(uInt16 address, uInt8 value)
{
  if((address & ROM_MASK) == 0x0FF4)
  {
    // Load/save RAM to/from Harmony cart flash
    if(mySize == 28_KB && !hotspotsLocked())
      ramReadWrite();
    return false;
  }

  return CartridgeEnhanced::poke(address, value);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeFA2::setNVRamFile(string_view path)
{
  myFlashFile = string{path} + "_flash.dat";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 CartridgeFA2::ramReadWrite()
{
  /* The following algorithm implements accessing Harmony cart flash

    1. Wait for an access to hotspot location $1FF4 (return 1 in bit 6
       while busy).

    2. Read byte 256 of RAM+ memory to determine the operation requested
       (1 = read, 2 = write).

    3. Save or load the entire 256 bytes of RAM+ memory to a file.

    4. Set byte 256 of RAM+ memory to zero to indicate success (will
       always happen in emulation).

    5. Return 0 (in bit 6) on the next access to $1FF4, if enough time has
       passed to complete the operation on a real system (0.5 ms for read,
       101 ms for write).
  */

  // First access sets the timer
  if(myRamAccessTimeout == 0)
  {
    // Remember when the first access was made
    myRamAccessTimeout = TimerManager::getTicks();

    // We go ahead and do the access now, and only return when a sufficient
    // amount of time has passed
    Serializer serializer(myFlashFile);
    if(serializer)
    {
      if(myRAM[255] == 1)       // read
      {
        try
        {
          serializer.getByteArray(myRAM.get(), myRamSize);
        }
        catch(...)
        {
          std::fill_n(myRAM.get(), myRamSize, 0);
        }
        myRamAccessTimeout += 500;  // Add 0.5 ms delay for read
      }
      else if(myRAM[255] == 2)  // write
      {
        try
        {
          serializer.putByteArray(myRAM.get(), myRamSize);
        }
        catch(...)
        {
          // Maybe add logging here that save failed?
          cerr << name() << ": ERROR saving score table\n";
        }
        myRamAccessTimeout += 101000;  // Add 101 ms delay for write
      }
    }
    // Bit 6 is 1, busy
    return myImage[myCurrentSegOffset[0] + 0xFF4] | 0x40;
  }
  else
  {
    // Have we reached the timeout value yet?
    if(TimerManager::getTicks() >= myRamAccessTimeout)
    {
      myRamAccessTimeout = 0;  // Turn off timer
      myRAM[255] = 0;          // Successful operation

      // Bit 6 is 0, ready/success
      return myImage[myCurrentSegOffset[0] + 0xFF4] & ~0x40;
    }
    else
      // Bit 6 is 1, busy
      return myImage[myCurrentSegOffset[0] + 0xFF4] | 0x40;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeFA2::flash(uInt8 operation)
{
  Serializer serializer(myFlashFile);
  if(serializer)
  {
    if(operation == 0)       // erase
    {
      try
      {
        std::array<uInt8, 256> buf = {};
        serializer.putByteArray(buf.data(), buf.size());
      }
      catch(...)
      {
        // Maybe add logging here that erase failed?
        cerr << name() << ": ERROR erasing score table\n";
      }
    }
    else if(operation == 1)  // read
    {
      try
      {
        serializer.getByteArray(myRAM.get(), myRamSize);
      }
      catch(...)
      {
        std::fill_n(myRAM.get(), myRamSize, 0);
      }
    }
    else if(operation == 2)  // write
    {
      try
      {
        serializer.putByteArray(myRAM.get(), myRamSize);
      }
      catch(...)
      {
        // Maybe add logging here that save failed?
        cerr << name() << ": ERROR saving score table\n";
      }
    }
  }
}
