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

#include "CartCV.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartridgeCV::CartridgeCV(const ByteBuffer& image, size_t size,
                         string_view md5, const Settings& settings,
                         size_t bsSize)
  : CartridgeEnhanced(image, size, md5, settings, bsSize)
{
  myRamSize = RAM_SIZE;
  myRamWpHigh = RAM_HIGH_WP;

  if(size <= 2_KB)
  {
    for(size_t i = 0; i < 2_KB; i += size)
      // Copy the ROM of <=2K files to the 2nd half of the 4K ROM
      // The 1st half is used for RAM
      std::copy_n(image.get(), size, myImage.get() + 2_KB + i);
  }
  else if(size == 4_KB)
  {
    // The game has something saved in the RAM
    // Useful for MagiCard program listings

    // Copy the ROM image into my buffer
    std::copy_n(image.get() + 2_KB, 2_KB, myImage.get());

    myInitialRAM = make_unique<uInt8[]>(1_KB);
    // Copy the RAM image into a buffer for use in reset()
    std::copy_n(image.get(), 1_KB, myInitialRAM.get());
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeCV::reset()
{
  if(myInitialRAM != nullptr)
  {
    // Copy the RAM image into my buffer
    std::copy_n(myInitialRAM.get(), 1_KB, myRAM.get());
  }
  else
    initializeRAM(myRAM.get(), myRamSize);

  myBankChanged = true;
}
