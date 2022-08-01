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

#include "bspf.hxx"
#include "HighPass.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
HighPass::HighPass(float cutOffFrequency, float frequency)
  : myAlpha{1.F / (1.F + 2.F*BSPF::PI_f*cutOffFrequency/frequency)}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
float HighPass::apply(float valueIn)
{
  const float valueOut = myAlpha * (myLastValueOut + valueIn - myLastValueIn);

  myLastValueIn = valueIn;
  myLastValueOut = valueOut;

  return valueOut;
}
