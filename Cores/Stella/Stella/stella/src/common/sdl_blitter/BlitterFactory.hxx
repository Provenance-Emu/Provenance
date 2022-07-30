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

#ifndef BLITTER_FACTORY_HXX
#define BLITTER_FACTORY_HXX

#include <string>

#include "Blitter.hxx"
#include "FBBackendSDL2.hxx"
#include "bspf.hxx"

class BlitterFactory {
  public:

    enum class ScalingAlgorithm {
      nearestNeighbour,
      bilinear,
      quasiInteger
    };

  public:

    static unique_ptr<Blitter> createBlitter(FBBackendSDL2& fb, ScalingAlgorithm scaling);
};

#endif // BLITTER_FACTORY_HXX
