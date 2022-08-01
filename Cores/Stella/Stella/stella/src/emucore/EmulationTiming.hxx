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

#ifndef EMULATION_TIMING_HXX
#define EMULATION_TIMING_HXX

#include "bspf.hxx"
#include "FrameLayout.hxx"
#include "ConsoleTiming.hxx"

class EmulationTiming {
  public:

    EmulationTiming(FrameLayout frameLayout = FrameLayout::ntsc,
                    ConsoleTiming consoleTiming = ConsoleTiming::ntsc);

    EmulationTiming& updateFrameLayout(FrameLayout frameLayout);

    EmulationTiming& updateConsoleTiming(ConsoleTiming consoleTiming);

    EmulationTiming& updatePlaybackRate(uInt32 playbackRate);

    EmulationTiming& updatePlaybackPeriod(uInt32 period);

    EmulationTiming& updateAudioQueueExtraFragments(uInt32 audioQueueExtraFragments);

    EmulationTiming& updateAudioQueueHeadroom(uInt32 audioQueueHeadroom);

    EmulationTiming& updateSpeedFactor(float speedFactor);

    uInt32 maxCyclesPerTimeslice() const;

    uInt32 minCyclesPerTimeslice() const;

    uInt32 linesPerFrame() const;

    uInt32 cyclesPerFrame() const;

    uInt32 cyclesPerSecond() const;

    uInt32 audioFragmentSize() const;

    uInt32 audioSampleRate() const;

    uInt32 audioQueueCapacity() const;

    uInt32 prebufferFragmentCount() const;

  private:

    void recalculate();

  private:

    FrameLayout myFrameLayout{FrameLayout::ntsc};
    ConsoleTiming myConsoleTiming{ConsoleTiming::ntsc};

    uInt32 myPlaybackRate{44100};
    uInt32 myPlaybackPeriod{512};
    uInt32 myAudioQueueExtraFragments{1};
    uInt32 myAudioQueueHeadroom{2};

    uInt32 myMaxCyclesPerTimeslice{0};
    uInt32 myMinCyclesPerTimeslice{0};
    uInt32 myLinesPerFrame{0};
    uInt32 myCyclesPerFrame{0};
    uInt32 myCyclesPerSecond{0};
    uInt32 myAudioFragmentSize{0};
    uInt32 myAudioSampleRate{0};
    uInt32 myAudioQueueCapacity{0};
    uInt32 myPrebufferFragmentCount{0};

    double mySpeedFactor{1.0};

  private:

    EmulationTiming(const EmulationTiming&) = delete;
    EmulationTiming(EmulationTiming&&) = delete;
    EmulationTiming& operator=(const EmulationTiming&) = delete;
    EmulationTiming& operator=(EmulationTiming&&) = delete;

};

#endif // EMULATION_TIMING_HXX
