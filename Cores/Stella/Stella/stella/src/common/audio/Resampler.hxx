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

#ifndef RESAMPLER_HXX
#define RESAMPLER_HXX

#include <functional>

#include "bspf.hxx"
#include "StaggeredLogger.hxx"

class Resampler {
  public:

    using NextFragmentCallback = std::function<Int16*()>;

    class Format {
      public:

        Format(uInt32 f_sampleRate, uInt32 f_fragmentSize, bool f_stereo) :
          sampleRate(f_sampleRate),
          fragmentSize(f_fragmentSize),
          stereo(f_stereo)
        {}

      public:

        uInt32 sampleRate{31400};
        uInt32 fragmentSize{512};
        bool stereo{false};

      private:

        Format() = delete;
    };

  public:

    Resampler(Format formatFrom, Format formatTo,
              const NextFragmentCallback& nextFragmentCallback)
      : myFormatFrom{formatFrom},
        myFormatTo{formatTo},
        myNextFragmentCallback{nextFragmentCallback},
        myUnderrunLogger{"audio buffer underrun", Logger::Level::INFO} { }

    virtual void fillFragment(float* fragment, uInt32 length) = 0;

    virtual ~Resampler() = default;

  protected:

    Format myFormatFrom;
    Format myFormatTo;

    NextFragmentCallback myNextFragmentCallback;

    StaggeredLogger myUnderrunLogger;

  private:

    Resampler() = delete;
    Resampler(const Resampler&) = delete;
    Resampler(Resampler&&) = delete;
    Resampler& operator=(const Resampler&) = delete;
    Resampler& operator=(Resampler&&) = delete;

};

#endif // RESAMPLER_HXX
