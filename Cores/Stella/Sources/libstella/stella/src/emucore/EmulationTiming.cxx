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

#include <cmath>

#include "EmulationTiming.hxx"

namespace {
  constexpr uInt32 AUDIO_HALF_FRAMES_PER_FRAGMENT = 1;

  constexpr uInt32 discreteDivCeil(uInt32 n, uInt32 d)
  {
    return n / d + ((n % d == 0) ? 0 : 1);
  }
} // namespace

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EmulationTiming::EmulationTiming(FrameLayout frameLayout, ConsoleTiming consoleTiming)
  : myFrameLayout{frameLayout},
    myConsoleTiming{consoleTiming}
{
  recalculate();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EmulationTiming& EmulationTiming::updateFrameLayout(FrameLayout frameLayout)
{
  myFrameLayout = frameLayout;
  recalculate();

  return *this;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EmulationTiming& EmulationTiming::updateConsoleTiming(ConsoleTiming consoleTiming)
{
  myConsoleTiming = consoleTiming;
  recalculate();

  return *this;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EmulationTiming& EmulationTiming::updatePlaybackRate(uInt32 playbackRate)
{
  myPlaybackRate = playbackRate;
  recalculate();

  return *this;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EmulationTiming& EmulationTiming::updatePlaybackPeriod(uInt32 playbackPeriod)
{
  myPlaybackPeriod = playbackPeriod;
  recalculate();

  return *this;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EmulationTiming& EmulationTiming::updateAudioQueueExtraFragments(uInt32 audioQueueExtraFragments)
{
  myAudioQueueExtraFragments = audioQueueExtraFragments;
  recalculate();

  return *this;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EmulationTiming& EmulationTiming::updateAudioQueueHeadroom(uInt32 audioQueueHeadroom)
{
  myAudioQueueHeadroom = audioQueueHeadroom;
  recalculate();

  return *this;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EmulationTiming& EmulationTiming::updateSpeedFactor(float speedFactor)
{
  mySpeedFactor = static_cast<double>(speedFactor);
  recalculate();

  return *this;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 EmulationTiming::maxCyclesPerTimeslice() const
{
  return myMaxCyclesPerTimeslice;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 EmulationTiming::minCyclesPerTimeslice() const
{
  return myMinCyclesPerTimeslice;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 EmulationTiming::linesPerFrame() const
{
  return myLinesPerFrame;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 EmulationTiming::cyclesPerFrame() const
{
  return myCyclesPerFrame;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 EmulationTiming::cyclesPerSecond() const
{
  return myCyclesPerSecond;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 EmulationTiming::audioFragmentSize() const
{
  return myAudioFragmentSize;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 EmulationTiming::audioSampleRate() const
{
  return myAudioSampleRate;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 EmulationTiming::audioQueueCapacity() const
{
  return myAudioQueueCapacity;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 EmulationTiming::prebufferFragmentCount() const
{
  return myPrebufferFragmentCount;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EmulationTiming::recalculate()
{
  switch (myFrameLayout) {
    case FrameLayout::ntsc:
      myLinesPerFrame = 262;
      break;

    case FrameLayout::pal:
      myLinesPerFrame = 312;
      break;

    default:
      throw runtime_error("invalid frame layout");
  }

  switch (myConsoleTiming) {
    case ConsoleTiming::ntsc:
      myAudioSampleRate = static_cast<uInt32>(round(mySpeedFactor * 262 * 76 * 60) / 38);
      break;

    case ConsoleTiming::pal:
    case ConsoleTiming::secam:
      myAudioSampleRate = static_cast<uInt32>(round(mySpeedFactor * 312 * 76 * 50) / 38);
      break;

    default:
      throw runtime_error("invalid console timing");
  }

  myCyclesPerSecond = myAudioSampleRate * 38;

  myCyclesPerFrame = 76 * myLinesPerFrame;
  myMaxCyclesPerTimeslice = static_cast<uInt32>(round(mySpeedFactor * myCyclesPerFrame * 2));
  myMinCyclesPerTimeslice = static_cast<uInt32>(round(mySpeedFactor * myCyclesPerFrame / 2));
  myAudioFragmentSize = static_cast<uInt32>(round(mySpeedFactor * AUDIO_HALF_FRAMES_PER_FRAGMENT * myLinesPerFrame));

  myPrebufferFragmentCount = discreteDivCeil(
    myPlaybackPeriod * myAudioSampleRate,
    myAudioFragmentSize * myPlaybackRate
  ) + myAudioQueueHeadroom;

  myAudioQueueCapacity = std::max(
    myPrebufferFragmentCount,
    discreteDivCeil(myMaxCyclesPerTimeslice * myAudioSampleRate, myAudioFragmentSize * myCyclesPerSecond)
  ) + myAudioQueueExtraFragments;
}
