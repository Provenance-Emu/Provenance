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

#ifndef SIMPLE_RESAMPLER_HXX
#define SIMPLE_RESAMPLER_HXX

#include "bspf.hxx"
#include "Resampler.hxx"

class SimpleResampler : public Resampler
{
  public:
    SimpleResampler(
      Resampler::Format formatFrom,
      Resampler::Format formatTo,
      const Resampler::NextFragmentCallback& NextFragmentCallback
    );

    void fillFragment(float* fragment, uInt32 length) override;

  private:
    Int16* myCurrentFragment{nullptr};
    uInt32 myTimeIndex{0};
    uInt32 myFragmentIndex{0};
    bool myIsUnderrun{true};

  private:
    SimpleResampler() = delete;
    SimpleResampler(const SimpleResampler&) = delete;
    SimpleResampler(SimpleResampler&&) = delete;
    SimpleResampler& operator=(const SimpleResampler&) = delete;
    SimpleResampler& operator=(const SimpleResampler&&) = delete;
};

#endif // SIMPLE_RESAMPLER_HXX
