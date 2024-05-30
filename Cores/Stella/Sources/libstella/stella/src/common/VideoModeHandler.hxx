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

#ifndef VIDEO_MODE_HANDLER_HXX
#define VIDEO_MODE_HANDLER_HXX

class Settings;

#include "Rect.hxx"
#include "bspf.hxx"
#include "Bezel.hxx"

class VideoModeHandler
{
  public:
    // Contains all relevant info for the dimensions of a video screen
    // Also takes care of the case when the image should be 'centered'
    // within the given screen:
    //   'image' is the image dimensions into the screen
    //   'screen' are the dimensions of the screen itself
    struct Mode
    {
      enum class Stretch {
        Preserve,   // Stretch to fill all available space; preserve aspect ratio
        Fill,       // Stretch to fill all available space
        None        // No stretching (1x zoom)
      };

      Common::Rect imageR;
      Common::Rect screenR;
      Common::Size screenS;
      Stretch stretch{Mode::Stretch::None};
      string description;
      double zoom{1.};
      Int32 fsIndex{-1};  // -1 indicates windowed mode

      Mode() = default;
      Mode(uInt32 iw, uInt32 ih, uInt32 sw, uInt32 sh, Stretch smode,
           Int32 fsindex = -1, string_view desc = "",
           double zoomLevel = 1., double overscan = 1.,
           Bezel::Info bezelInfo = Bezel::Info());
      Mode(uInt32 iw, uInt32 ih, Stretch smode, Int32 fsindex = -1,
           string_view desc = "", double zoomLevel = 1.,
           Bezel::Info bezelInfo = Bezel::Info());

      friend ostream& operator<<(ostream& os, const Mode& vm)
      {
        os << "image=" << vm.imageR << "  screen=" << vm.screenS
           << "  stretch=" << (vm.stretch == Stretch::Preserve ? "preserve" :
                               vm.stretch == Stretch::Fill ? "fill" : "none")
           << "  desc=" << vm.description << "  zoom=" << vm.zoom
           << "  fsIndex= " << vm.fsIndex;
        return os;
      }
    };

  public:
    VideoModeHandler() = default;

    /**
      Set the base size of the image. Scaling can be applied to this,
      which will change the effective size.

      @param image  The base dimensions of the image
    */
    void setImageSize(const Common::Size& image);

    /**
      Set the size of the display.  This could be either the desktop size,
      or the size of the monitor currently active.

      @param display  The dimensions of the enclosing display
      @param fsIndex  Fullscreen mode in use (-1 indicates windowed mode)
    */
    void setDisplaySize(const Common::Size& display, Int32 fsIndex = -1);

    /**
      Build a video mode based on the given parameters, assuming that
      setImageSize and setDisplaySize have been previously called.

      @param settings  Used to query various options that affect video mode
      @param inTIAMode Whether the video mode is being used for TIA emulation

      @return  A video mode based on the given criteria
    */
    const VideoModeHandler::Mode& buildMode(const Settings& settings, bool inTIAMode,
                                            Bezel::Info bezelInfo = Bezel::Info());

  private:
    Common::Size myImage, myDisplay;
    Int32 myFSIndex{-1};

    Mode myMode;

  private:
    VideoModeHandler(const VideoModeHandler&) = delete;
    VideoModeHandler(VideoModeHandler&&) = delete;
    VideoModeHandler& operator=(const VideoModeHandler&) = delete;
    VideoModeHandler& operator=(const VideoModeHandler&&) = delete;
};

#endif // VIDEO_MODE_HANDLER_HXX
