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

#include "DrawCounterDecodes.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const uInt8* const* DrawCounterDecodes::playerDecodes() const
{
  return myPlayerDecodes;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const uInt8* const* DrawCounterDecodes::missileDecodes() const
{
  return myMissileDecodes;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
DrawCounterDecodes& DrawCounterDecodes::DrawCounterDecodes::get()
{
  return myInstance;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
DrawCounterDecodes::DrawCounterDecodes()
{
  uInt8* decodeTables[] = {
    myDecodes0, myDecodes1, myDecodes2, myDecodes3, myDecodes4, myDecodes6
  };

  for (auto* decodes: decodeTables)
  {
    std::fill_n(decodes, 160, 0);         // TJ: magic number 160 = pixel/scanline
    decodes[156] = 1;                     // TJ: set for all copy pattern (first copy)
  }

  myDecodes1[12] = 2;                     // TJ: two copies close (+16)
  myDecodes2[28] = 2;                     // TJ: two copies med (+32)
  myDecodes3[12] = 2; myDecodes3[28] = 3; // TJ: three copies close (+16, +32)
  myDecodes4[60] = 2;                     // TJ: two copies wide (+64)
  myDecodes6[28] = 2; myDecodes6[60] = 3; // TJ: three copies medium (+32, +64)

  // TJ: assigning decodes to players
  myPlayerDecodes[0] = myDecodes0;
  myPlayerDecodes[1] = myDecodes1;
  myPlayerDecodes[2] = myDecodes2;
  myPlayerDecodes[3] = myDecodes3;
  myPlayerDecodes[4] = myDecodes4;
  myPlayerDecodes[5] = myDecodes0;
  myPlayerDecodes[6] = myDecodes6;
  myPlayerDecodes[7] = myDecodes0;

  // TJ: assigning decodes to missiles
  myMissileDecodes[0] = myDecodes0;
  myMissileDecodes[1] = myDecodes1;
  myMissileDecodes[2] = myDecodes2;
  myMissileDecodes[3] = myDecodes3;
  myMissileDecodes[4] = myDecodes4;
  myMissileDecodes[5] = myDecodes0;
  myMissileDecodes[6] = myDecodes6;
  myMissileDecodes[7] = myDecodes0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
DrawCounterDecodes DrawCounterDecodes::myInstance;
