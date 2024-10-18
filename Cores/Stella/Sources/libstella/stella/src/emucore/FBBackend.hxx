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

#ifndef FB_BACKEND_HXX
#define FB_BACKEND_HXX

class FBSurface;

#include "Rect.hxx"
#include "Variant.hxx"
#include "FrameBufferConstants.hxx"
#include "VideoModeHandler.hxx"
#include "bspf.hxx"

/**
  This class provides an interface/abstraction for platform-specific,
  framebuffer-related rendering operations.  Different graphical
  platforms will inherit from this.  For most ports that means SDL2,
  but some (such as libretro) use their own graphical subsystem.

  @author  Stephen Anthony
*/
class FBBackend
{
  friend class FrameBuffer;

  public:
    FBBackend() = default;
    virtual ~FBBackend() = default;

  protected:
    /**
      This method is called to query and initialize the video hardware
      for desktop and fullscreen resolution information.  Since several
      monitors may be attached, we need the resolution for all of them.

      @param fullscreenRes  Maximum resolution supported in fullscreen mode
      @param windowedRes    Maximum resolution supported in windowed mode
      @param renderers      List of renderer names (internal name -> end-user name)
    */
    virtual void queryHardware(vector<Common::Size>& fullscreenRes,
                               vector<Common::Size>& windowedRes,
                               VariantList& renderers) = 0;

    /**
      This method is called to change to the given video mode.

      @param mode   The video mode to use
      @param winIdx The display/monitor that the window last opened on
      @param winPos The position that the window last opened at

      @return  False on any errors, else true
    */
    virtual bool setVideoMode(const VideoModeHandler::Mode& mode,
                              int winIdx, const Common::Point& winPos) = 0;

    /**
      Clear the framebuffer.
    */
    virtual void clear() = 0;

    /**
      Transform from window to renderer coordinates, x direction
     */
    virtual int scaleX(int x) const = 0;

    /**
      Transform from window to renderer coordinates, y direction
     */
    virtual int scaleY(int y) const = 0;

    /**
      Updates window title.

      @param title   The title of the application / window
    */
    virtual void setTitle(string_view title) = 0;

    /**
      Shows or hides the cursor based on the given boolean value.
    */
    virtual void showCursor(bool show) = 0;

    /**
      Grabs or ungrabs the mouse based on the given boolean value.
    */
    virtual void grabMouse(bool grab) = 0;

    /**
      This method must be called after all drawing is done, and indicates
      that the buffers should be pushed to the physical screen.
    */
    virtual void renderToScreen() = 0;

    /**
      Answers if the display is currently in fullscreen mode.

      @return  Whether the display is actually in fullscreen mode
    */
    virtual bool fullScreen() const = 0;

    /**
      Retrieve the current display's refresh rate.
    */
    virtual int refreshRate() const = 0;

    /**
      This method is called to retrieve the R/G/B data from the given pixel.

      @param pixel  The pixel containing R/G/B data
      @param r      The red component of the color
      @param g      The green component of the color
      @param b      The blue component of the color
    */
    virtual void getRGB(uInt32 pixel, uInt8* r, uInt8* g, uInt8* b) const = 0;

    /**
      This method is called to retrieve the R/G/B/A data from the given pixel.

      @param pixel  The pixel containing R/G/B data
      @param r      The red component of the color
      @param g      The green component of the color
      @param b      The blue component of the color
      @param a      The alpha component of the color.
    */
    virtual void getRGBA(uInt32 pixel, uInt8* r, uInt8* g, uInt8* b, uInt8* a) const = 0;

    /**
      This method is called to map a given R/G/B triple to the screen palette.

      @param r  The red component of the color.
      @param g  The green component of the color.
      @param b  The blue component of the color.
    */
    virtual uInt32 mapRGB(uInt8 r, uInt8 g, uInt8 b) const = 0;

    /**
      This method is called to map a given R/G/B triple to the screen palette.

      @param r  The red component of the color.
      @param g  The green component of the color.
      @param b  The blue component of the color.
      @param a  The alpha component of the color.
    */
    virtual uInt32 mapRGBA(uInt8 r, uInt8 g, uInt8 b, uInt8 a) const = 0;

    /**
      This method is called to get the specified ARGB data from the viewable
      FrameBuffer area.  Note that this isn't the same as any internal
      surfaces that may be in use; it should return the actual data as it
      is currently seen onscreen.

      @param buffer  The actual pixel data in ARGB8888 format
      @param pitch   The pitch (in bytes) for the pixel data
      @param rect    The bounding rectangle for the buffer
    */
    virtual void readPixels(uInt8* buffer, size_t pitch,
                            const Common::Rect& rect) const = 0;

    /**
      This method is called to query if the current window is not
      centered or fullscreen.

      @return  True, if the current window is positioned
    */
    virtual bool isCurrentWindowPositioned() const = 0;

    /**
      This method is called to query the video hardware for position of
      the current window.

      @return  The position of the currently displayed window
    */
    virtual Common::Point getCurrentWindowPos() const = 0;

    /**
      This method is called to query the video hardware for the index
      of the display the current window is displayed on.

      @return  The current display index or a negative value if no
               window is displayed
    */
    virtual Int32 getCurrentDisplayIndex() const = 0;

    /**
      This method is called to create a surface with the given attributes.

      @param w      The requested width of the new surface.
      @param h      The requested height of the new surface.
      @param inter  Interpolation mode
      @param data   If non-null, use the given data values as a static surface
    */
    virtual unique_ptr<FBSurface>
        createSurface(
          uInt32 w,
          uInt32 h,
          ScalingInterpolation inter = ScalingInterpolation::none,
          const uInt32* data = nullptr
    ) const = 0;

    /**
      This method is called to provide information about the backend.
    */
    virtual string about() const = 0;

  private:
    // Following constructors and assignment operators not supported
    FBBackend(const FBBackend&) = delete;
    FBBackend(FBBackend&&) = delete;
    FBBackend& operator=(const FBBackend&) = delete;
    FBBackend& operator=(FBBackend&&) = delete;
};

#endif
