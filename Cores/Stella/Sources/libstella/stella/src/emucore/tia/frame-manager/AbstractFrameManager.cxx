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

#include "AbstractFrameManager.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
AbstractFrameManager::AbstractFrameManager()
{
  layout(FrameLayout::ntsc);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AbstractFrameManager::reset()
{
  myIsRendering = false;
  myVsync = false;
  myVblank = false;
  myCurrentFrameTotalLines = 0;
  myCurrentFrameFinalLines = 0;
  myPreviousFrameFinalLines = 0;
  myTotalFrames = 0;

  onReset();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AbstractFrameManager::nextLine()
{
  ++myCurrentFrameTotalLines;

  onNextLine();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AbstractFrameManager::setHandlers(
  const callback& frameStartCallback,
  const callback& frameCompletionCallback
)
{
  myOnFrameStart = frameStartCallback;
  myOnFrameComplete = frameCompletionCallback;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AbstractFrameManager::clearHandlers()
{
  myOnFrameStart = myOnFrameComplete = nullptr;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AbstractFrameManager::setVblank(bool vblank)
{
  if (vblank == myVblank) return;

  myVblank = vblank;

  onSetVblank();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AbstractFrameManager::setVsync(bool vsync, uInt64 cycles)
{
  if (vsync == myVsync) return;

  myVsync = vsync;

  onSetVsync(cycles);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AbstractFrameManager::notifyFrameStart()
{
  if (myOnFrameStart) myOnFrameStart();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AbstractFrameManager::notifyFrameComplete()
{
  myPreviousFrameFinalLines = myCurrentFrameFinalLines;
  myCurrentFrameFinalLines = myCurrentFrameTotalLines;
  myCurrentFrameTotalLines = 0;
  ++myTotalFrames;

  if (myOnFrameComplete) myOnFrameComplete();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AbstractFrameManager::layout(FrameLayout layout)
{
  if (layout == myLayout) return;

  myLayout = layout;

  onLayoutChange();  // NOLINT
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool AbstractFrameManager::save(Serializer& out) const
{
  try
  {
    out.putBool(myIsRendering);
    out.putBool(myVsync);
    out.putBool(myVblank);
    out.putInt(myCurrentFrameTotalLines);
    out.putInt(myCurrentFrameFinalLines);
    out.putInt(myPreviousFrameFinalLines);
    out.putInt(myTotalFrames);
    out.putInt(static_cast<uInt32>(myLayout));

    return onSave(out);
  }
  catch(...)
  {
    cerr << "ERROR: AbstractFrameManager::save\n";
    return false;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool AbstractFrameManager::load(Serializer& in)
{
  try
  {
    myIsRendering = in.getBool();
    myVsync = in.getBool();
    myVblank = in.getBool();
    myCurrentFrameTotalLines = in.getInt();
    myCurrentFrameFinalLines = in.getInt();
    myPreviousFrameFinalLines = in.getInt();
    myTotalFrames = in.getInt();
    myLayout = static_cast<FrameLayout>(in.getInt());

    return onLoad(in);
  }
  catch(...)
  {
    cerr << "ERROR: AbstractFrameManager::load\n";
    return false;
  }
}
