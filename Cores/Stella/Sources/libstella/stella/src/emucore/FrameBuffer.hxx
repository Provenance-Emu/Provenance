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

#ifndef FRAMEBUFFER_HXX
#define FRAMEBUFFER_HXX

#include <list>

class OSystem;
class Console;
class Settings;
class FBSurface;
class TIASurface;
class Bezel;

#ifdef GUI_SUPPORT
  #include "Font.hxx"
#endif

#include "Rect.hxx"
#include "Variant.hxx"
#include "TIAConstants.hxx"
#include "FBBackend.hxx"
#include "FrameBufferConstants.hxx"
#include "EventHandlerConstants.hxx"
#include "VideoModeHandler.hxx"
#include "bspf.hxx"

/**
  This class encapsulates all video buffers and is the basis for the video
  display in Stella.  The FBBackend object contained in this class is
  platform-specific, and most rendering tasks are delegated to it.

  The TIA is drawn here, and all GUI elements (ala ScummVM, which are drawn
  into FBSurfaces), are in turn drawn here as well.

  @author  Stephen Anthony
*/
class FrameBuffer
{
  public:
    // Zoom level step interval
    static constexpr double ZOOM_STEPS = 0.25;

    enum UpdateMode {
      NONE = 0,
      REDRAW = 1,
      RERENDER = 2
    };

  public:
    explicit FrameBuffer(OSystem& osystem);
    ~FrameBuffer();

    /**
      Initialize the framebuffer object (set up the underlying hardware).
      Throws an exception upon encountering any errors.
    */
    void initialize();

    /**
      (Re)creates the framebuffer display.  This must be called before any
      calls are made to derived methods.

      @param title   The title of the application / window
      @param size    The dimensions of the display
      @param honourHiDPI  If true, consult the 'hidpi' setting and enlarge
                          the display size accordingly; if false, use the
                          exact dimensions as given

      @return  Status of initialization (see FBInitStatus 'enum')
    */
    FBInitStatus createDisplay(string_view title, BufferType type,
                               Common::Size size, bool honourHiDPI = true);

    /**
      Updates the display, which depending on the current mode could mean
      drawing the TIA, any pending menus, etc.
    */
    void update(UpdateMode mode = UpdateMode::NONE);

    /**
      There is a dedicated update method for emulation mode.
    */
    void updateInEmulationMode(float framesPerSecond);

    /**
      Set pending rendering flag.
    */
    void setPendingRender() { myPendingRender = true; }

    /**
      Shows a text message onscreen.

      @param message  The message to be shown
      @param position Onscreen position for the message
      @param force    Force showing this message, even if messages are disabled
    */
    void showTextMessage(string_view message,
                         MessagePosition position = MessagePosition::BottomCenter,
                         bool force = false);
    /**
      Shows a message with a gauge bar onscreen.

      @param message    The message to be shown
      @param valueText  The value of the gauge bar as text
      @param value      The gauge bar percentage
      @param minValue   The minimal value of the gauge bar
      @param maxValue   The maximal value of the gauge bar
    */
    void showGaugeMessage(string_view message, string_view valueText,
                          float value, float minValue = 0.F, float maxValue = 100.F);

    bool messageShown() const;

    /**
      Toggles showing or hiding framerate statistics.
    */
    void toggleFrameStats(bool toggle = true);

    /**
      Shows a message containing frame statistics for the current frame.
    */
    void showFrameStats(bool enable);

    /**
      Enable/disable any pending messages.  Disabled messages aren't removed
      from the message queue; they're just not redrawn into the framebuffer.
    */
    void enableMessages(bool enable);

    /**
      Reset 'Paused' display delay counter
    */
    void setPauseDelay();

    /**
      Allocate a new surface.  The FrameBuffer class takes all responsibility
      for freeing this surface (ie, other classes must not delete it directly).

      @param w      The requested width of the new surface
      @param h      The requested height of the new surface
      @param inter  Interpolation mode
      @param data   If non-null, use the given data values as a static surface

      @return  A pointer to a valid surface object, or nullptr
    */
    shared_ptr<FBSurface> allocateSurface(
      int w,
      int h,
      ScalingInterpolation inter = ScalingInterpolation::none,
      const uInt32* data = nullptr
    );

    /**
      Deallocate a previously allocated surface.  If no such surface exists,
      this method does nothing.

      @param surface  The surface to remove/deallocate
    */
    void deallocateSurface(const shared_ptr<FBSurface>& surface);

    /**
      Set up the TIA/emulation palette.  Due to the way the palette is stored,
      a call to this method implicitly calls setUIPalette() too.

      @param rgb_palette  The array of colors in R/G/B format
    */
    void setTIAPalette(const PaletteArray& rgb_palette);

    /**
      Set palette for user interface.
    */
    void setUIPalette();

    /**
      Returns the current dimensions of the framebuffer image.
      Note that this will take into account the current scaling (if any)
      as well as image 'centering'.
    */
    const Common::Rect& imageRect() const { return myActiveVidMode.imageR; }

    /**
      Returns the current dimensions of the framebuffer window.
      This is the entire area containing the framebuffer image as well as any
      'unusable' area.
    */
    const Common::Size& screenSize() const { return myActiveVidMode.screenS; }
    const Common::Rect& screenRect() const { return myActiveVidMode.screenR; }

    /**
      Returns the dimensions of the mode specific users' desktop.
    */
    const Common::Size& desktopSize(BufferType bufferType) const {
      return myDesktopSize[displayId(bufferType)];
    }

    /**
      Get the supported renderers for the video hardware.

      @return  An array of supported renderers
    */
    const VariantList& supportedRenderers() const { return myRenderers; }

    /**
      Get the minimum/maximum supported TIA zoom level (windowed mode)
      for the framebuffer.
    */
    double supportedTIAMinZoom() const { return myTIAMinZoom * hidpiScaleFactor(); }
    double supportedTIAMaxZoom() const { return maxWindowZoom(); }

    /**
      Get the TIA surface associated with the framebuffer.
    */
    TIASurface& tiaSurface() const { return *myTIASurface; }

    /**
      Toggles between fullscreen and window mode.
    */
    void toggleFullscreen(bool toggle = true);

  #ifdef ADAPTABLE_REFRESH_SUPPORT
    /**
      Toggles between adapt fullscreen refresh rate on and off.
    */
    void toggleAdaptRefresh(bool toggle = true);
  #endif

    /**
      Changes the fullscreen overscan.

      @param direction  +1 indicates increase, -1 indicates decrease
    */
    void changeOverscan(int direction = +1);

    /**
      This method is called when the user wants to switch to the previous/next
      available TIA video mode.  In windowed mode, this typically means going
      to the next/previous zoom level.  In fullscreen mode, this typically
      means switching between normal aspect and fully filling the screen.

      @param direction  +1 indicates next mode, -1 indicates previous mode
    */
    void switchVideoMode(int direction = +1);

    /**
      Toggles the bezel display.
    */
    void toggleBezel(bool toggle = true);

    /**
      Sets the state of the cursor (hidden or grabbed) based on the
      current mode.
    */
    void setCursorState();

    /**
      Checks if mouse grabbing is allowed.
    */
    bool grabMouseAllowed();

    /**
      Sets the use of grabmouse.
    */
    void enableGrabMouse(bool enable);

    /**
      Toggles the use of grabmouse (only has effect in emulation mode).
    */
    void toggleGrabMouse(bool toggle = true);

    /**
      Query whether grabmouse is enabled.
    */
    bool grabMouseEnabled() const { return myGrabMouse; }

    /**
      Informs the Framebuffer of a change in EventHandler state.
    */
    void stateChanged(EventHandlerState state);

    /**
      Answer whether hidpi mode is allowed.  In this mode, all FBSurfaces
      are scaled to 2x normal size.
    */
    bool hidpiAllowed() const { return myHiDPIAllowed[displayId()]; }

    /**
      Answer whether hidpi mode is enabled.  In this mode, all FBSurfaces
      are scaled to 2x normal size.
    */
    bool hidpiEnabled() const { return myHiDPIEnabled[displayId()]; }
    uInt32 hidpiScaleFactor() const { return myHiDPIEnabled[displayId()] ? 2 : 1; }

    /**
      This method should be called to save the current settings of all
      its subsystems.  Note that the this may be called when the class
      hasn't been fully initialized, so we first need to check if the
      subsytems actually exist.
    */
    void saveConfig(Settings& settings) const;

  #ifdef GUI_SUPPORT
    /**
      Get the font object(s) of the framebuffer
    */
    const GUI::Font& font() const { return *myFont; }
    const GUI::Font& infoFont() const { return *myInfoFont; }
    const GUI::Font& smallFont() const { return *mySmallFont; }
    const GUI::Font& launcherFont() const { return *myLauncherFont; }

    /**
      Get the font description from the font name

      @param name  The settings name of the font

      @return  The description of the font
    */
    static FontDesc getFontDesc(string_view name);
  #endif

    /**
      Shows or hides the cursor based on the given boolean value.
    */
    void showCursor(bool show) { myBackend->showCursor(show); }

    /**
      Answers if the display is currently in fullscreen mode.
    */
    bool fullScreen() const { return myBackend->fullScreen(); }

    /**
      This method is called to retrieve the R/G/B data from the given pixel.

      @param pixel  The pixel containing R/G/B data
      @param r      The red component of the color
      @param g      The green component of the color
      @param b      The blue component of the color
    */
    void getRGB(uInt32 pixel, uInt8* r, uInt8* g, uInt8* b) const {
      myBackend->getRGB(pixel, r, g, b);
    }

    /**
      This method is called to retrieve the R/G/B/A data from the given pixel.

      @param pixel  The pixel containing R/G/B data
      @param r      The red component of the color
      @param g      The green component of the color
      @param b      The blue component of the color
      @param a      The alpha component of the color.
    */
    void getRGBA(uInt32 pixel, uInt8* r, uInt8* g, uInt8* b, uInt8* a) const {
      myBackend->getRGBA(pixel, r, g, b, a);
    }

    /**
      This method is called to map a given R/G/B triple to the screen palette.

      @param r  The red component of the color.
      @param g  The green component of the color.
      @param b  The blue component of the color.
    */
    uInt32 mapRGB(uInt8 r, uInt8 g, uInt8 b) const {
      return myBackend->mapRGB(r, g, b);
    }

    /**
      This method is called to map a given R/G/B/A triple to the screen palette.

    @param r  The red component of the color.
    @param g  The green component of the color.
    @param b  The blue component of the color.
      @param a  The alpha component of the color.
    */
    uInt32 mapRGBA(uInt8 r, uInt8 g, uInt8 b, uInt8 a) const {
      return myBackend->mapRGBA(r, g, b, a);
    }

    /**
      This method is called to get the specified ARGB data from the viewable
      FrameBuffer area.  Note that this isn't the same as any internal
      surfaces that may be in use; it should return the actual data as it
      is currently seen onscreen.

      @param buffer  The actual pixel data in ARGB8888 format
      @param pitch   The pitch (in bytes) for the pixel data
      @param rect    The bounding rectangle for the buffer
    */
    void readPixels(uInt8* buffer, size_t pitch, const Common::Rect& rect) const {
      myBackend->readPixels(buffer, pitch, rect);
    }

    /**
      Clear the framebuffer.
    */
    void clear() { myBackend->clear(); }

    /**
      Transform from window to renderer coordinates, x/y direction
     */
    int scaleX(int x) const { return myBackend->scaleX(x); }
    int scaleY(int y) const { return myBackend->scaleY(y); }

  private:
    /**
      These methods are used to load/save position and display of the
      current window.
    */
    string getPositionKey() const;
    string getDisplayKey(BufferType bufferType = BufferType::None) const;
    void saveCurrentWindowPosition() const;

    /**
      Frees and reloads all surfaces that the framebuffer knows about.
    */
    void resetSurfaces();

    /**
      Renders TIA and overlaying, optional bezel surface

      @param doClear  Clear the framebuffer before rendering
      @param shade    Shade the TIA surface after rendering
    */
    //void renderTIA(bool shade = false, bool doClear = true);
    void renderTIA(bool doClear = true, bool shade = false);

  #ifdef GUI_SUPPORT
    /**
      Helps to create a basic message onscreen.

      @param message  The message to be shown
      @param position Onscreen position for the message
      @param force    Force showing this message, even if messages are disabled
    */
    void createMessage(string_view message, MessagePosition position,
                       bool force = false);
  #endif

    /**
      Draw pending messages.

      @return  Indicates whether any changes actually occurred.
    */
    bool drawMessage();

    /**
      Hide pending messages.
    */
    void hideMessage();

    /**
      Draws the frame stats overlay.
    */
    void drawFrameStats(float framesPerSecond);


    /**
      Get the display used for the current mode.
    */
    int displayId(BufferType bufferType = BufferType::None) const;

    /**
      Build an applicable video mode based on the current settings in
      effect, whether TIA mode is active, etc.  Then tell the backend
      to actually use the new mode.

      @return  Whether the operation succeeded or failed
    */
    FBInitStatus applyVideoMode();

    /**
      Calculate the maximum level by which the base window can be zoomed and
      still fit in the desktop screen.
    */
    double maxWindowZoom() const;

    /**
      Enables/disables fullscreen mode.
    */
    void setFullscreen(bool enable);

  #ifdef GUI_SUPPORT
    /**
      Setup the UI fonts
    */
    void setupFonts();
  #endif

  private:
    // The parent system for the framebuffer
    OSystem& myOSystem;

    // Backend used for all platform-specific graphics operations
    unique_ptr<FBBackend> myBackend;

    // Indicates the number of times the framebuffer was initialized
    uInt32 myInitializedCount{0};

    // Used to set intervals between messages while in pause mode
    Int32 myPausedCount{0};

    // Maximum dimensions of the desktop area
    // Note that this takes 'hidpi' mode into account, so in some cases
    // it will be less than the absolute desktop size
    vector<Common::Size> myDesktopSize;

    // Maximum absolute dimensions of the desktop area
    vector<Common::Size> myAbsDesktopSize;

    // The resolution of the attached displays in fullscreen mode
    // The primary display is typically the first in the array
    // Windowed modes use myDesktopSize directly
    vector<Common::Size> myFullscreenDisplays;

    // The resolution of the attached displays in windowed mode
    vector<Common::Size> myWindowedDisplays;

    // Supported renderers
    VariantList myRenderers;

    // Flag for pending render
    bool myPendingRender{false};

    // The VideoModeHandler class takes responsibility for all video
    // mode functionality
    VideoModeHandler myVidModeHandler;
    VideoModeHandler::Mode myActiveVidMode;

    // Type of the frame buffer
    BufferType myBufferType{BufferType::None};

  #ifdef GUI_SUPPORT
    // The font object to use for the normal in-game GUI
    unique_ptr<GUI::Font> myFont;

    // The info font object to use for the normal in-game GUI
    unique_ptr<GUI::Font> myInfoFont;

    // The font object to use when space is very limited
    unique_ptr<GUI::Font> mySmallFont;

    // The font object to use for the ROM launcher
    unique_ptr<GUI::Font> myLauncherFont;
  #endif

    // The TIASurface class takes responsibility for TIA rendering
    shared_ptr<TIASurface> myTIASurface;

    // The BezelSurface which blends over the TIA surface
    unique_ptr<Bezel> myBezel;

    // Used for onscreen messages and frame statistics
    // (scanline count and framerate)
    struct Message {
      string text;
      int counter{-1};
      int x{0}, y{0}, w{0}, h{0};
      MessagePosition position{MessagePosition::BottomCenter};
      ColorId color{kNone};
      shared_ptr<FBSurface> surface;
      bool enabled{false};
      bool dirty{false};
      bool showGauge{false};
      float value{0.F};
      string valueText;
    };
    Message myMsg;
    Message myStatsMsg;
    bool myStatsEnabled{false};
    uInt32 myLastScanlines{0};

    bool myGrabMouse{false};
    vector<bool> myHiDPIAllowed;
    vector<bool> myHiDPIEnabled;

    // Minimum TIA zoom level that can be used for this framebuffer
    double myTIAMinZoom{2.};

    // Holds a reference to all the surfaces that have been created
    std::list<shared_ptr<FBSurface>> mySurfaceList;

    // Maximum message width [chars]
    static constexpr int MESSAGE_WIDTH = 56;
    // Maximum gauge bar width [chars]
    static constexpr int GAUGEBAR_WIDTH = 30;

    FullPaletteArray myFullPalette{0};
    // Holds UI palette data (for each variation)
    static UIPaletteArray ourStandardUIPalette, ourClassicUIPalette,
                          ourLightUIPalette, ourDarkUIPalette;

  private:
    // Following constructors and assignment operators not supported
    FrameBuffer() = delete;
    FrameBuffer(const FrameBuffer&) = delete;
    FrameBuffer(FrameBuffer&&) = delete;
    FrameBuffer& operator=(const FrameBuffer&) = delete;
    FrameBuffer& operator=(FrameBuffer&&) = delete;
};

#endif
