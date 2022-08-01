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

#include "PhosphorHandler.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool PhosphorHandler::initialize(bool enable, int blend)
{
  if(myUsePhosphor == enable && myPhosphorPercent == blend / 100.F)
    return false;

  myUsePhosphor = enable;
  if(blend >= 0 && blend <= 100)
    myPhosphorPercent = blend / 100.F;

  // Used to calculate an averaged color for the 'phosphor' effect
  const auto getPhosphor = [&] (const uInt8 c1, uInt8 c2) -> uInt8 {
    // Use maximum of current and decayed previous values
    c2 = static_cast<uInt8>(c2 * myPhosphorPercent);
    if(c1 > c2)  return c1; // raise (assumed immediate)
    else         return c2; // decay
  };

  // Precalculate the average colors for the 'phosphor' effect
  if(myUsePhosphor)
  {
    for(int c = 255; c >= 0; --c)
      for(int p = 255; p >= 0; --p)
        ourPhosphorLUT[c][p] = getPhosphor(static_cast<uInt8>(c), static_cast<uInt8>(p));
  }
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PhosphorHandler::PhosphorLUT PhosphorHandler::ourPhosphorLUT;
