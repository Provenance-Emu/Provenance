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
#include "FBSurfaceLIBRETRO.hxx"
#include "FBBackendLIBRETRO.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FBBackendLIBRETRO::queryHardware(vector<Common::Size>& fullscreenRes,
                                      vector<Common::Size>& windowedRes,
                                      VariantList& renderers)
{
  fullscreenRes.emplace_back(1920, 1080);
  windowedRes.emplace_back(1920, 1080);

  VarList::push_back(renderers, "software", "Software");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
unique_ptr<FBSurface> FBBackendLIBRETRO::createSurface(
    uInt32 w, uInt32 h, ScalingInterpolation, const uInt32*) const
{
  return make_unique<FBSurfaceLIBRETRO>(w, h);
}
