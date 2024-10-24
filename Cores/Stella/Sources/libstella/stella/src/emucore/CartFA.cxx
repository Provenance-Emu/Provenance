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
#include "CartFA.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartridgeFA::CartridgeFA(const ByteBuffer& image, size_t size,
                         string_view md5, const Settings& settings,
                         size_t bsSize)
  : CartridgeEnhanced(image, size, md5, settings, bsSize)
{
  myRamSize = RAM_SIZE;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeFA::checkSwitchBank(uInt16 address, uInt8)
{
  // Switch banks if necessary
  if((address >= 0x1FF8) && (address <= 0x1FFA)/* && (mySystem->getDataBusState() & 1) */)
  {
    //if((mySystem->getDataBusState() & 1) == 0)
    //cerr << std::hex << address << ": " << (mySystem->getDataBusState() & 1) << ", ";
    bank(address - 0x1FF8);
    return true;
  }
  return false;
}
