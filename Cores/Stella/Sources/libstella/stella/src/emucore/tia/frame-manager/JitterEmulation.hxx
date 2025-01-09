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

#ifndef TIA_JITTER_EMULATION
#define TIA_JITTER_EMULATION

//#define VSYNC_LINE_JITTER // makes e.g. Alien jitter, but not on my TV (TJ)

#include "bspf.hxx"
#include "Serializable.hxx"
#include "Random.hxx"

class JitterEmulation : public Serializable
{
  public:
    JitterEmulation();

  public:
    // sensitivity:
    static constexpr Int32 MIN_SENSITIVITY = 1;
    static constexpr Int32 MAX_SENSITIVITY = 10;
    static constexpr Int32 PLR_SENSITIVITY = 3;
    static constexpr Int32 DEV_SENSITIVITY = 8;
    // roll speed:
    static constexpr Int32 MIN_RECOVERY = 1;
    static constexpr Int32 MAX_RECOVERY = 20;
    static constexpr Int32 PLR_RECOVERY = 10;
    static constexpr Int32 DEV_RECOVERY = 2;

  public:
    void reset();
    void setSensitivity(Int32 sensitivity);
    void setRecovery(Int32 recoveryFactor) { myJitterRecovery = recoveryFactor; }
    void setYStart(Int32 ystart) { myYStart = ystart; }

    void frameComplete(Int32 scanlineCount, Int32 vsyncCycles);
    Int32 jitter() const { return myJitter; }

    bool vsyncCorrect() const { return myVsyncCorrect; }

    /**
     * Save state.
     */
    bool save(Serializer& out) const override;

    /**
     * Restore state.
     */
    bool load(Serializer& in) override;

  private:
    // varying scanlines:
    static constexpr Int32 MIN_SCANLINE_DELTA = 1;     // was: 3
    static constexpr Int32 MAX_SCANLINE_DELTA = 5;
    // varying VSYNC timing:
    static constexpr Int32 MIN_VSYNC_CYCLES = 76 * 3 / 4;
    static constexpr Int32 MAX_VSYNC_CYCLES = 76 * 3;
    static constexpr Int32 MIN_VSYNC_DELTA_1 = 1;
    static constexpr Int32 MAX_VSYNC_DELTA_1 = 76 / 3;
#ifdef VSYNC_LINE_JITTER
    static constexpr Int32 MIN_VSYNC_DELTA_2 = 1;
    static constexpr Int32 MAX_VSYNC_DELTA_2 = 10;
#endif
    // threshold for jitter:
    static constexpr Int32 MIN_UNSTABLE_FRAMES = 1;    // was: 10
    static constexpr Int32 MAX_UNSTABLE_FRAMES = 10;
    // resulting jitter:
    static constexpr Int32 MIN_JITTER_LINES = 1;       // was: 50
    static constexpr Int32 MAX_JITTER_LINES = 200;
    static constexpr Int32 MIN_VSYNC_LINES = 1;
    static constexpr Int32 MAX_VSYNC_LINES = 5;

  private:
    Random myRandom;

    Int32 myLastFrameScanlines{0};
    Int32 myLastFrameVsyncCycles{0};
    Int32 myUnstableCount{0};
    Int32 myJitter{0};
    Int32 myJitterRecovery{0};
    Int32 myYStart{0};
    Int32 mySensitivity{MIN_SENSITIVITY};
    Int32 myScanlineDelta{MAX_SCANLINE_DELTA};
    Int32 myVsyncCycles{MIN_VSYNC_CYCLES};
    Int32 myVsyncDelta1{MAX_VSYNC_DELTA_1};
#ifdef VSYNC_LINE_JITTER
    Int32 myVsyncDelta2{MIN_VSYNC_DELTA_2};
#endif
    Int32 myUnstableFrames{MAX_UNSTABLE_FRAMES};
    Int32 myJitterLines{MIN_JITTER_LINES};
    Int32 myVsyncLines{MIN_VSYNC_LINES};
    bool myVsyncCorrect{true};

  private:
    JitterEmulation(const JitterEmulation&) = delete;
    JitterEmulation(JitterEmulation&&) = delete;
    JitterEmulation& operator=(const JitterEmulation&) = delete;
    JitterEmulation& operator=(JitterEmulation&&) = delete;
};

#endif // TIA_JITTER_EMULATION
