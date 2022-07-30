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

#ifndef FPS_METER_HXX
#define FPS_METER_HXX

#include <chrono>

#include "bspf.hxx"

class FpsMeter
{
  public:

    explicit FpsMeter(uInt32 queueSize);

    void reset(uInt32 garbageFrameLimit = 0);

    void render(uInt32 frameCount);

    float fps() const;

  private:

    struct entry {
      uInt32 frames{0};
      std::chrono::time_point<std::chrono::high_resolution_clock> timestamp;
    };

  private:

    vector<entry> myQueue;

    uInt32 myQueueOffset{0};

    uInt32 myFrameCount{0};

    uInt32 myGarbageFrameCounter{0};
    uInt32 myGarbageFrameLimit{0};

    float myFps{0.F};

  private:
    FpsMeter(const FpsMeter&) = delete;
    FpsMeter(FpsMeter&&) = delete;
    FpsMeter& operator=(const FpsMeter&) = delete;
    FpsMeter& operator=(FpsMeter&&) = delete;
};

#endif // FPS_METER_HXX
