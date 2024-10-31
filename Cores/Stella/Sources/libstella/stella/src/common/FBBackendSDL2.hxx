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

#ifndef FB_BACKEND_SDL2_HXX
#define FB_BACKEND_SDL2_HXX

#include "SDL_lib.hxx"

class OSystem;
class FBSurfaceSDL2;

#include "bspf.hxx"
#include "FBBackend.hxx"

/**
  This class implements a standard SDL2 2D, hardware accelerated framebuffer
  backend.  Behind the scenes, it may be using Direct3D, OpenGL(ES), etc.

  @author  Stephen Anthony
*/
class FBBackendSDL2 : public FBBackend
{
  public:
    /**
      Creates a new SDL2 framebuffer
    */
    explicit FBBackendSDL2(OSystem& osystem);
    ~FBBackendSDL2() override;

  public:
    /**
      Get a pointer to the SDL renderer.
     */
    SDL_Renderer* renderer() { return myRenderer; }

    /**
      Is the renderer initialized?
     */
    bool isInitialized() const { return myRenderer != nullptr; }

    /**
      Get the SDL pixel format.
     */
    const SDL_PixelFormat& pixelFormat() const { return *myPixelFormat; }

    /**
      Does the renderer support render targets?
     */
    bool hasRenderTargetSupport() const { return myRenderTargetSupport; }

    /**
      Transform from window to renderer coordinates, x direction
     */
    int scaleX(int x) const override { return (x * myRenderW) / myWindowW; }

    /**
      Transform from window to renderer coordinates, y direction
     */
    int scaleY(int y) const override { return (y * myRenderH) / myWindowH; }

  protected:
    /**
      Updates window title.

      @param title  The title of the application / window
    */
    void setTitle(string_view title) override;

    /**
      Shows or hides the cursor based on the given boolean value.
    */
    void showCursor(bool show) override;

    /**
      Answers if the display is currently in fullscreen mode.
    */
    bool fullScreen() const override;

    /**
      This method is called to retrieve the R/G/B data from the given pixel.

      @param pixel  The pixel containing R/G/B data
      @param r      The red component of the color
      @param g      The green component of the color
      @param b      The blue component of the color
    */
    FORCE_INLINE void getRGB(uInt32 pixel, uInt8* r, uInt8* g, uInt8* b) const override
      { SDL_GetRGB(pixel, myPixelFormat, r, g, b); }

    /**
      This method is called to retrieve the R/G/B/A data from the given pixel.

      @param pixel  The pixel containing R/G/B data
      @param r      The red component of the color
      @param g      The green component of the color
      @param b      The blue component of the color
      @param a      The alpha component of the color.
    */
    FORCE_INLINE void getRGBA(uInt32 pixel, uInt8* r, uInt8* g, uInt8* b, uInt8* a) const override
      { SDL_GetRGBA(pixel, myPixelFormat, r, g, b, a); }

    /**
      This method is called to map a given R/G/B triple to the screen palette.

      @param r  The red component of the color.
      @param g  The green component of the color.
      @param b  The blue component of the color.
    */
    inline uInt32 mapRGB(uInt8 r, uInt8 g, uInt8 b) const override
      { return SDL_MapRGB(myPixelFormat, r, g, b); }

    /**
      This method is called to map a given R/G/B/A triple to the screen palette.

      @param r  The red component of the color.
      @param g  The green component of the color.
      @param b  The blue component of the color.
      @param a  The alpha component of the color.
    */
    inline uInt32 mapRGBA(uInt8 r, uInt8 g, uInt8 b, uInt8 a) const override
      { return SDL_MapRGBA(myPixelFormat, r, g, b, a); }

    /**
      This method is called to get a copy of the specified ARGB data from the
      viewable FrameBuffer area.  Note that this isn't the same as any
      internal surfaces that may be in use; it should return the actual data
      as it is currently seen onscreen.

      @param buffer  A copy of the pixel data in ARGB8888 format
      @param pitch   The pitch (in bytes) for the pixel data
      @param rect    The bounding rectangle for the buffer
    */
    void readPixels(uInt8* buffer, size_t pitch,
                    const Common::Rect& rect) const override;

    /**
      This method is called to query if the current window is not centered
      or fullscreen.

      @return  True, if the current window is positioned
    */
    bool isCurrentWindowPositioned() const override;

    /**
      This method is called to query the video hardware for position of
      the current window

      @return  The position of the currently displayed window
    */
    Common::Point getCurrentWindowPos() const override;

    /**
      This method is called to query the video hardware for the index
      of the display the current window is displayed on

      @return  the current display index or a negative value if no
               window is displayed
    */
    Int32 getCurrentDisplayIndex() const override;

    /**
      Clear the frame buffer.
    */
    void clear() override;

    /**
      This method is called to query and initialize the video hardware
      for desktop and fullscreen resolution information.  Since several
      monitors may be attached, we need the resolution for all of them.

      @param fullscreenRes  Maximum resolution supported in fullscreen mode
      @param windowedRes    Maximum resolution supported in windowed mode
      @param renderers      List of renderer names (internal name -> end-user name)
    */
    void queryHardware(vector<Common::Size>& fullscreenRes,
                       vector<Common::Size>& windowedRes,
                       VariantList& renderers) override;

    /**
      This method is called to change to the given video mode.

      @param mode   The video mode to use
      @param winIdx The display/monitor that the window last opened on
      @param winPos The position that the window last opened at

      @return  False on any errors, else true
    */
    bool setVideoMode(const VideoModeHandler::Mode& mode,
                      int winIdx, const Common::Point& winPos) override;

    /**
      This method is called to create a surface with the given attributes.

      @param w      The requested width of the new surface.
      @param h      The requested height of the new surface.
      @param inter  Interpolation mode
      @param data   If non-null, use the given data values as a static surface
    */
    unique_ptr<FBSurface>
        createSurface(
          uInt32 w,
          uInt32 h,
          ScalingInterpolation inter,
          const uInt32* data
        ) const override;

    /**
      Grabs or ungrabs the mouse based on the given boolean value.
    */
    void grabMouse(bool grab) override;

    /**
      This method is called to provide information about the backend.
    */
    string about() const override;

    /**
      Create a new renderer if required.

      @return  False on any errors, else true
    */
    bool createRenderer();

    /**
      This method must be called after all drawing is done, and indicates
      that the buffers should be pushed to the physical screen.
    */
    void renderToScreen() override;

    /**
      Retrieve the current display's refresh rate, or 0 if no window.
    */
    int refreshRate() const override;

    /**
      Checks if the display refresh rate should be adapted to game refresh
      rate in (real) fullscreen mode.

      @param displayIndex   The display which should be checked
      @param adaptedSdlMode The best matching mode if the refresh rate
                            should be changed

      @return  True if the refresh rate should be changed
    */
    bool adaptRefreshRate(Int32 displayIndex, SDL_DisplayMode& adaptedSdlMode);

    /**
      After the renderer has been created, detect the features it supports.
     */
    void detectFeatures();

    /**
      Detect render target support.
     */
    bool detectRenderTargetSupport();

    /**
      Determine window and renderer dimensions.
     */
    void determineDimensions();

    /**
      Set the icon for the main SDL window.
    */
    void setWindowIcon();

  private:
    OSystem& myOSystem;

    // The SDL video buffer
    SDL_Window* myWindow{nullptr};
    SDL_Renderer* myRenderer{nullptr};

    // Used by mapRGB (when palettes are created)
    SDL_PixelFormat* myPixelFormat{nullptr};

    // Center setting of current window
    bool myCenter{false};

    // Does the renderer support render targets?
    bool myRenderTargetSupport{false};

    // Title of the main window/screen
    string myScreenTitle;

    // Number of displays
    int myNumDisplays{1};

    // Window and renderer dimensions
    int myWindowW{0}, myWindowH{0}, myRenderW{0}, myRenderH{0};

  private:
    // Following constructors and assignment operators not supported
    FBBackendSDL2() = delete;
    FBBackendSDL2(const FBBackendSDL2&) = delete;
    FBBackendSDL2(FBBackendSDL2&&) = delete;
    FBBackendSDL2& operator=(const FBBackendSDL2&) = delete;
    FBBackendSDL2& operator=(FBBackendSDL2&&) = delete;
};

#endif
