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

// #define TIA_FRAMEMANAGER_DEBUG_LOG

#include <cmath>

#include "FrameManager.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FrameManager::FrameManager()
{
  reset();
  recalculateMetrics();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameManager::onReset()
{
  myState = State::waitForVsyncStart;
  myLineInState = 0;
  myTotalFrames = 0;
  myVsyncLines = 0;
  myY = 0;

  myJitterEmulation.reset();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameManager::onNextLine()
{
  const State previousState = myState;
  ++myLineInState;

  switch (myState)
  {
    case State::waitForVsyncStart:
      if ((myCurrentFrameTotalLines > myFrameLines - 3) || myTotalFrames == 0)
        ++myVsyncLines;

      if (myVsyncLines > Metrics::maxLinesVsync) setState(State::waitForFrameStart);

      break;

    case State::waitForVsyncEnd:
      if (++myVsyncLines > Metrics::maxLinesVsync)
        setState(State::waitForFrameStart);

      break;

    case State::waitForFrameStart:
    {
      const Int32 jitter =
        (myJitterEnabled && myTotalFrames > Metrics::initialGarbageFrames) ? myJitterEmulation.jitter() : 0;

      if (myLineInState >= (myYStart + jitter)) setState(State::frame);
      break;
    }

    case State::frame:
      if (myLineInState >= myHeight)
      {
        myLastY = myYStart + myY;  // Last line drawn in this frame
        setState(State::waitForVsyncStart);
      }
      break;

    default:
      throw runtime_error("frame manager: invalid state");
  }

  if (myState == State::frame && previousState == State::frame) ++myY;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Int32 FrameManager::missingScanlines() const
{
  if (myLastY == myYStart + myY)
    return 0;
  else {
    return myHeight - myY;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameManager::setVcenter(Int32 vcenter)
{
  if (vcenter < TIAConstants::minVcenter || vcenter > TIAConstants::maxVcenter) return;

  myVcenter = vcenter;
  recalculateMetrics();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameManager::setAdjustVSize(Int32 adjustVSize)
{
  myVSizeAdjust = adjustVSize;
  recalculateMetrics();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameManager::onSetVsync(uInt64 cycles)
{
  if (myState == State::waitForVsyncEnd) {
    myVsyncEnd = cycles;
    setState(State::waitForFrameStart);
  }
  else {
    myVsyncStart = cycles;
    setState(State::waitForVsyncEnd);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameManager::setState(FrameManager::State state)
{
  if (myState == state) return;

  myState = state;
  myLineInState = 0;

  switch (myState) {
    case State::waitForFrameStart:
      notifyFrameComplete();

      if (myTotalFrames > Metrics::initialGarbageFrames)
        myJitterEmulation.frameComplete(myCurrentFrameFinalLines,
            static_cast<Int32>(myVsyncEnd - myVsyncStart));

      notifyFrameStart();

      myVsyncLines = 0;
      break;

    case State::frame:
      myVsyncLines = 0;
      myY = 0;
      break;

    default:
      break;
  }

  updateIsRendering();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameManager::onLayoutChange()
{
  recalculateMetrics();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameManager::updateIsRendering() {
  myIsRendering = myState == State::frame;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FrameManager::onSave(Serializer& out) const
{
  if (!myJitterEmulation.save(out)) return false;

  out.putInt(static_cast<uInt32>(myState));
  out.putInt(myLineInState);
  out.putInt(myVsyncLines);
  out.putInt(myY);
  out.putInt(myLastY);

  out.putInt(myVblankLines);
  out.putInt(myFrameLines);
  out.putInt(myHeight);
  out.putInt(myYStart);
  out.putInt(myVcenter);
  out.putInt(myMaxVcenter);
  out.putInt(myVSizeAdjust);

  out.putBool(myJitterEnabled);

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FrameManager::onLoad(Serializer& in)
{
  if (!myJitterEmulation.load(in)) return false;

  myState = static_cast<State>(in.getInt());
  myLineInState = in.getInt();
  myVsyncLines = in.getInt();
  myY = in.getInt();
  myLastY = in.getInt();

  myVblankLines = in.getInt();
  myFrameLines = in.getInt();
  myHeight = in.getInt();
  myYStart = in.getInt();
  myVcenter = in.getInt();
  myMaxVcenter = in.getInt();
  myVSizeAdjust = in.getInt();

  myJitterEnabled = in.getBool();

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FrameManager::recalculateMetrics() {
  Int32 ystartBase = 0;
  Int32 baseHeight = 0;

  switch (layout())
  {
    case FrameLayout::ntsc:
      myVblankLines   = Metrics::vblankNTSC;
      myFrameLines    = Metrics::frameSizeNTSC;
      ystartBase      = Metrics::ystartNTSC;
      baseHeight      = Metrics::baseHeightNTSC;
      break;

    case FrameLayout::pal:
      myVblankLines   = Metrics::vblankPAL;
      myFrameLines    = Metrics::frameSizePAL;
      ystartBase      = Metrics::ystartPAL;
      baseHeight      = Metrics::baseHeightPAL;
      break;

    default:
      throw runtime_error("frame manager: invalid TV mode");
  }

  myHeight = BSPF::clamp<uInt32>(roundf(static_cast<float>(baseHeight) * (1.F - myVSizeAdjust / 100.F)), 0, myFrameLines);
  myYStart = BSPF::clamp<uInt32>(ystartBase + (baseHeight - static_cast<Int32>(myHeight)) / 2 - myVcenter, 0, myFrameLines);
  // TODO: why "- 1" here: ???
  myMaxVcenter = BSPF::clamp<Int32>(ystartBase + (baseHeight - static_cast<Int32>(myHeight)) / 2 - 1, 0, TIAConstants::maxVcenter);

  //cout << "myVSizeAdjust " << myVSizeAdjust << " " << myHeight << '\n' << std::flush;

  myJitterEmulation.setYStart(myYStart);
}
