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

#ifndef TIA_DRAW_COUNTER_DECODES
#define TIA_DRAW_COUNTER_DECODES

#include "bspf.hxx"

class DrawCounterDecodes
{
  public:

    const uInt8* const* playerDecodes() const;

    const uInt8* const* missileDecodes() const;

    static DrawCounterDecodes& get();

  protected:

    DrawCounterDecodes();

  private:

    uInt8* myPlayerDecodes[8]{nullptr}; // TJ: one per NUSIZ number and size

    uInt8* myMissileDecodes[8]{nullptr}; // TJ: one per NUSIZ number and size

    // TJ: 6 scanline pixel arrays, one for each copy pattern
    uInt8 myDecodes0[160], myDecodes1[160], myDecodes2[160], myDecodes3[160],
          myDecodes4[160], myDecodes6[160];

    static DrawCounterDecodes myInstance;

  private:
    DrawCounterDecodes(const DrawCounterDecodes&) = delete;
    DrawCounterDecodes(DrawCounterDecodes&&) = delete;
    DrawCounterDecodes& operator=(const DrawCounterDecodes&) = delete;
    DrawCounterDecodes& operator=(DrawCounterDecodes&&) = delete;
};

#endif // TIA_DRAW_COUNTER_DECODES
