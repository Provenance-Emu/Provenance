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

#include "Settings.hxx"
#include "VideoModeHandler.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void VideoModeHandler::setImageSize(const Common::Size& image)
{
  myImage = image;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void VideoModeHandler::setDisplaySize(const Common::Size& display, Int32 fsIndex)
{
  myDisplay = display;
  myFSIndex = fsIndex;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const VideoModeHandler::Mode&
VideoModeHandler::buildMode(const Settings& settings, bool inTIAMode)
{
  const bool windowedRequested = myFSIndex == -1;

  // TIA mode allows zooming at non-integral factors in most cases
  if(inTIAMode)
  {
    if(windowedRequested)
    {
      const float zoom = settings.getFloat("tia.zoom");
      ostringstream desc;
      desc << (zoom * 100) << "%";

      // Image and screen (aka window) dimensions are the same
      // Overscan is not applicable in this mode
      myMode = Mode(myImage.w * zoom, myImage.h * zoom, Mode::Stretch::Fill,
                    myFSIndex, desc.str(), zoom);
    }
    else
    {
      const float overscan = 1 - settings.getInt("tia.fs_overscan") / 100.0;

      // First calculate maximum zoom that keeps aspect ratio
      const float scaleX = static_cast<float>(myImage.w) / myDisplay.w,
                  scaleY = static_cast<float>(myImage.h) / myDisplay.h;
      float zoom = 1.F / std::max(scaleX, scaleY);

      // When aspect ratio correction is off, we want pixel-exact images,
      // so we default to integer zooming
      if(!settings.getBool("tia.correct_aspect"))
        zoom = static_cast<uInt32>(zoom);

      if(!settings.getBool("tia.fs_stretch"))  // preserve aspect, use all space
      {
        myMode = Mode(myImage.w * zoom, myImage.h * zoom,
                      myDisplay.w, myDisplay.h,
                      Mode::Stretch::Preserve, myFSIndex,
                      "Fullscreen: Preserve aspect, no stretch", zoom, overscan);
      }
      else  // ignore aspect, use all space
      {
        myMode = Mode(myImage.w * zoom, myImage.h * zoom,
                      myDisplay.w, myDisplay.h,
                      Mode::Stretch::Fill, myFSIndex,
                      "Fullscreen: Ignore aspect, full stretch", zoom, overscan);
      }
    }
  }
  else  // UI mode (no zooming)
  {
    if(windowedRequested)
      myMode = Mode(myImage.w, myImage.h, Mode::Stretch::None);
    else
      myMode = Mode(myImage.w, myImage.h, myDisplay.w, myDisplay.h,
                    Mode::Stretch::None, myFSIndex);
  }

  return myMode;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
VideoModeHandler::Mode::Mode(uInt32 iw, uInt32 ih, Stretch smode,
                             Int32 fsindex, const string& desc,
                             float zoomLevel)
  : Mode(iw, ih, iw, ih, smode, fsindex, desc, zoomLevel)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
VideoModeHandler::Mode::Mode(uInt32 iw, uInt32 ih, uInt32 sw, uInt32 sh,
                             Stretch smode, Int32 fsindex, const string& desc,
                             float zoomLevel, float overscan)
  : screenS(sw, sh),
    stretch(smode),
    description(desc),
    zoom(zoomLevel),
    fsIndex(fsindex)
{
  // Now resize based on windowed/fullscreen mode and stretch factor
  if(fsIndex != -1)  // fullscreen mode
  {
    switch(stretch)
    {
      case Stretch::Preserve:
        iw *= overscan;
        ih *= overscan;
        break;

      case Stretch::Fill:
        // Scale to all available space
        iw = screenS.w * overscan;
        ih = screenS.h * overscan;
        break;

      case Stretch::None:
        // Don't do any scaling at all
        iw = std::min(iw, screenS.w) * overscan;
        ih = std::min(ih, screenS.h) * overscan;
        break;
    }
  }
  else
  {
    // In windowed mode, currently the size is scaled to the screen
    // TODO - this may be updated if/when we allow variable-sized windows
    switch(stretch)
    {
      case Stretch::Preserve:
      case Stretch::Fill:
        screenS.w = iw;
        screenS.h = ih;
        break;

      case Stretch::None:
        break;  // Do not change image or screen rects whatsoever
    }
  }

  // Now re-calculate the dimensions
  iw = std::min(iw, screenS.w);
  ih = std::min(ih, screenS.h);

  imageR.moveTo((screenS.w - iw) >> 1, (screenS.h - ih) >> 1);
  imageR.setWidth(iw);
  imageR.setHeight(ih);

  screenR = Common::Rect(screenS);
}
