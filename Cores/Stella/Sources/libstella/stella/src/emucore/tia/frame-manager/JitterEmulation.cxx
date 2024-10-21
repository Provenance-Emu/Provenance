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
using std::abs;
using std::pow;
using std::round;

#include "JitterEmulation.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
JitterEmulation::JitterEmulation()
{
  reset();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void JitterEmulation::reset()
{
  setSensitivity(mySensitivity);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void JitterEmulation::setSensitivity(Int32 sensitivity)
{
  myLastFrameScanlines = myLastFrameVsyncCycles = myUnstableCount = myJitter = 0;
  mySensitivity = BSPF::clamp(sensitivity, MIN_SENSITIVITY, MAX_SENSITIVITY);

  const float factor = pow(static_cast<float>(mySensitivity - MIN_SENSITIVITY) / (MAX_SENSITIVITY - MIN_SENSITIVITY), 1.5);

  myScanlineDelta  = round(MAX_SCANLINE_DELTA  - (MAX_SCANLINE_DELTA  - MIN_SCANLINE_DELTA)  * factor);
  myVsyncCycles    = round(MIN_VSYNC_CYCLES    + (MAX_VSYNC_CYCLES    - MIN_VSYNC_CYCLES)    * factor);
  myVsyncDelta1    = round(MAX_VSYNC_DELTA_1   - (MAX_VSYNC_DELTA_1   - MIN_VSYNC_DELTA_1)   * factor);
#ifdef VSYNC_LINE_JITTER
  myVsyncDelta2    = round(MIN_VSYNC_DELTA_2   + (MAX_VSYNC_DELTA_2   - MIN_VSYNC_DELTA_2)   * factor);
#endif
  myUnstableFrames = round(MAX_UNSTABLE_FRAMES - (MAX_UNSTABLE_FRAMES - MIN_UNSTABLE_FRAMES) * factor);
  myJitterLines    = round(MIN_JITTER_LINES    + (MAX_JITTER_LINES    - MIN_JITTER_LINES)    * factor);
  myVsyncLines     = round(MIN_VSYNC_LINES     + (MAX_VSYNC_LINES     - MIN_VSYNC_LINES)     * factor);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void JitterEmulation::frameComplete(Int32 scanlineCount, Int32 vsyncCycles)
{
//#ifdef DEBUG_BUILD
//  const int  vsyncLines = round((vsyncCycles - 2) / 76.0);
//  cerr << "TV jitter " << myJitter << " - " << scanlineCount << ", " << vsyncCycles << ", " << vsyncLines << '\n';
//#endif

  // Check if current frame size is stable compared to previous frame
  const bool scanlinesStable = scanlineCount == myLastFrameScanlines;
  const bool vsyncCyclesStable = vsyncCycles >= myVsyncCycles;
  // Handle inconsistency of vsync cycles and around half lines
#ifdef VSYNC_LINE_JITTER
  const Int32 minLines = round((vsyncCycles - 2 - myVsyncDelta2) / 76.0);
  const Int32 maxLines = round((vsyncCycles - 2 + myVsyncDelta2) / 76.0);
  const Int32 minLastLines = round((myLastFrameVsyncCycles - 2 - myVsyncDelta2) / 76.0);
  const Int32 maxLastLines = round((myLastFrameVsyncCycles - 2 + myVsyncDelta2) / 76.0);
  const bool vsyncLinesStable = abs(vsyncCycles - myLastFrameVsyncCycles) < myVsyncDelta1
      && minLines == maxLastLines && maxLines == minLastLines;
#else
  const bool vsyncLinesStable = abs(vsyncCycles - myLastFrameVsyncCycles) < myVsyncDelta1;
#endif

  myVsyncCorrect = abs(vsyncCycles - 76 * 3) <= 3; // 3 cycles tolerance

  if(!scanlinesStable || !vsyncCyclesStable || !vsyncLinesStable)
  {
    if(++myUnstableCount >= myUnstableFrames)
    {
      if(!scanlinesStable)
      {
        const Int32 scanlineDifference = scanlineCount - myLastFrameScanlines;

        if(abs(scanlineDifference) >= myScanlineDelta
          && abs(myJitter) < static_cast<Int32>(myRandom.next() % myJitterLines))
        {
          // Repeated invalid frames cause randomly repeated jitter
          myJitter = std::max(std::min(scanlineDifference, myJitterLines), -myYStart);
        }
      }
      if(!vsyncCyclesStable)
      {
        // If VSYNC length is too low, the frame rolls permanently down, speed depending on missing cycles
        const Int32 jitter = std::max(
          std::min<Int32>(round(scanlineCount * (1 - static_cast<float>(vsyncCycles) / myVsyncCycles)),
            myJitterLines),
          myJitterRecovery + 1); // Roll at least one scanline

        myJitter -= jitter;
        // Limit jitter to -myYstart..262 - myYStart
        if(myJitter < -myYStart)
          myJitter += 262;
      }
      if(!vsyncLinesStable)
      {
#ifdef VSYNC_LINE_JITTER
        myJitter += minLines > maxLastLines ? myVsyncLines : -myVsyncLines;
#else
        myJitter += vsyncCycles > myLastFrameVsyncCycles ? myVsyncLines : -myVsyncLines;
#endif
      }
      myJitter = std::max(myJitter, -myYStart);
    }
  }
  else
  {
    myUnstableCount = 0;

    // Only recover during stable frames
    if(myJitter > 0)
      myJitter = std::max(myJitter - myJitterRecovery, 0);
    else if(myJitter < 0)
      myJitter = std::min(myJitter + myJitterRecovery, 0);
  }

  myLastFrameScanlines = scanlineCount;
  myLastFrameVsyncCycles = vsyncCycles;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool JitterEmulation::save(Serializer& out) const
{
  try
  {
    out.putInt(mySensitivity);
    out.putInt(myJitterRecovery);
    out.putInt(myYStart);
    out.putInt(myLastFrameScanlines);
    out.putInt(myLastFrameVsyncCycles);
    out.putInt(myUnstableCount);
    out.putInt(myJitter);
  }
  catch(...)
  {
    cerr << "ERROR: JitterEmulation::save\n";

    return false;
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool JitterEmulation::load(Serializer& in)
{
  try
  {
    mySensitivity = in.getInt();
    myJitterRecovery = in.getInt();
    myYStart = in.getInt();
    myLastFrameScanlines = in.getInt();
    myLastFrameVsyncCycles = in.getInt();
    myUnstableCount = in.getInt();
    myJitter = in.getInt();
  }
  catch (...)
  {
    cerr << "ERROR: JitterEmulation::load\n";

    return false;
  }
  setSensitivity(mySensitivity);

  return true;
}
