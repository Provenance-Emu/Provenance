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

#include "BlitterFactory.hxx"

#include "SDL_lib.hxx"
#include "BilinearBlitter.hxx"
#include "QisBlitter.hxx"

unique_ptr<Blitter>
BlitterFactory::createBlitter(FBBackendSDL2& fb, ScalingAlgorithm scaling)
{
  if (!fb.isInitialized()) {
    throw runtime_error("BlitterFactory requires an initialized framebuffer!");
  }

  switch (scaling) {
    case ScalingAlgorithm::nearestNeighbour:
      return make_unique<BilinearBlitter>(fb, false);

    case ScalingAlgorithm::bilinear:
      return make_unique<BilinearBlitter>(fb, true);

    case ScalingAlgorithm::quasiInteger:
      if (QisBlitter::isSupported(fb))
        return make_unique<QisBlitter>(fb);
      else
        return make_unique<BilinearBlitter>(fb, true);

    default:
      throw runtime_error("unreachable");
  }
}
