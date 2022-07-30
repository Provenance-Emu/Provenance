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

#ifndef HIGH_PASS_HXX
#define HIGH_PASS_HXX

class HighPass
{
  public:

    HighPass(float cutOffFrequency, float frequency);

    float apply(float value);

  private:

    float myLastValueIn{0.F};

    float myLastValueOut{0.F};

    float myAlpha{0.F};

  private:

    HighPass() = delete;
};

#endif // HIGH_PASS_HXX
