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

#include "FpsMeter.hxx"

using namespace std::chrono;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FpsMeter::FpsMeter(uInt32 queueSize)
  : myQueue{queueSize}
{
  reset();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FpsMeter::reset(uInt32 garbageFrameLimit)
{
  myQueue.clear();
  myQueueOffset = 0;
  myFrameCount = 0;
  myFps = 0;
  myGarbageFrameCounter = 0;
  myGarbageFrameLimit = garbageFrameLimit;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FpsMeter::render(uInt32 frameCount)
{
  if (myGarbageFrameCounter < myGarbageFrameLimit) {
    myGarbageFrameCounter += frameCount;
    return;
  }

  const size_t queueSize = myQueue.capacity();
  entry first, last;

  last.frames = frameCount;
  last.timestamp = high_resolution_clock::now();

  if (myQueue.size() < queueSize) {
    myQueue.push_back(last);
    myFrameCount += frameCount;

    first = myQueue.at(myQueueOffset);
  } else {
    myFrameCount = myFrameCount - myQueue.at(myQueueOffset).frames + frameCount;
    myQueue.at(myQueueOffset) = last;

    myQueueOffset = (myQueueOffset + 1) % queueSize;
    first = myQueue.at(myQueueOffset);
  }

  const float myTimeInterval =
    duration_cast<duration<float>>(last.timestamp - first.timestamp).count();

  if (myTimeInterval > 0) myFps = (myFrameCount - first.frames) / myTimeInterval;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
float FpsMeter::fps() const
{
  return myFps;
}
