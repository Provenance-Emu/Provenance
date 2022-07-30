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

#ifndef TIASURFACE_HXX
#define TIASURFACE_HXX

class TIA;
class Console;
class OSystem;
class FBSurface;
class PaletteHandler;

#include <thread>

#include "Rect.hxx"
#include "FrameBuffer.hxx"
#include "NTSCFilter.hxx"
#include "PhosphorHandler.hxx"
#include "bspf.hxx"
#include "TIAConstants.hxx"

/**
  This class is basically a wrapper around all things related to rendering
  the TIA image to FBSurface's, and presenting the results to the screen.
  This is placed in a separate class since currently, rendering a TIA image
  can consist of TV filters, a separate scanline surface, phosphor modes, etc.

  @author  Stephen Anthony
*/

class TIASurface
{
  public:
    // Setting names of palette types
    static constexpr const char* SETTING_STANDARD = "standard";
    static constexpr const char* SETTING_THIN     = "thin";
    static constexpr const char* SETTING_PIXELS   = "pixels";
    static constexpr const char* SETTING_APERTURE = "aperture";
    static constexpr const char* SETTING_MAME     = "mame";

    /**
      Creates a new TIASurface object
    */
    explicit TIASurface(OSystem& system);
    ~TIASurface();

    /**
      Set the TIA object, which is needed for actually rendering the TIA image.
    */
    void initialize(const Console& console, const VideoModeHandler::Mode& mode);

    /**
      Set the palette for TIA rendering.  This currently consists of two
      components: the actual TIA palette, and a mixed TIA palette used
      in phosphor mode.  The latter may eventually disappear once a better
      phosphor emulation is developed.

      @param tia_palette  An actual TIA palette, converted to data values
                          that are actually usable by the framebuffer
      @param rgb_palette  The RGB components of the palette, needed for
                          calculating a phosphor palette
    */
    void setPalette(const PaletteArray& tia_palette,
                    const PaletteArray& rgb_palette);

    /**
      Get a TIA surface that has no post-processing whatsoever.  This is
      currently used to save PNG image in the so-called '1x mode'.

      @param rect   Specifies the area in which the surface data is valid
    */
    const FBSurface& baseSurface(Common::Rect& rect) const;

    /**
      Get a underlying FBSurface that the TIA is being rendered into.
    */
    const FBSurface& tiaSurface() const { return *myTiaSurface; }

    /**
      Use the palette to map a single indexed pixel color. This is used by the
      TIA output widget.
     */
    uInt32 mapIndexedPixel(uInt8 indexedColor, uInt8 shift = 0) const;

    /**
      Get the NTSCFilter object associated with the framebuffer
    */
    NTSCFilter& ntsc() { return myNTSCFilter; }

    /**
      Use NTSC filtering effects specified by the given preset.
    */
    void setNTSC(NTSCFilter::Preset preset, bool show = true);

    /**
      Switch to next/previous NTSC filtering effect.

      @param direction  +1 indicates increase, -1 indicates decrease.
    */
    void changeNTSC(int direction = +1);

    /**
      Switch to next/previous NTSC filtering adjustable.

      @param direction  +1 indicates increase, -1 indicates decrease.
    */
    void setNTSCAdjustable(int direction = +1);

    /**
      Increase/decrease given NTSC filtering adjustable.

      @param adjustable  The adjustable to change
      @param direction   +1 indicates increase, -1 indicates decrease.
    */
    void changeNTSCAdjustable(int adjustable, int direction);

    /**
      Increase/decrease current NTSC filtering adjustable.

      @param direction  +1 indicates increase, -1 indicates decrease.
    */
    void changeCurrentNTSCAdjustable(int direction = +1);

    /**
      Retrieve palette handler.
    */
    PaletteHandler& paletteHandler() const { return *myPaletteHandler; }

    /**
      Increase/decrease current scanline intensity by given relative amount.

      @param direction  +1 indicates increase, -1 indicates decrease.
    */
    void changeScanlineIntensity(int direction = +1);

    /**
      Cycle through available scanline masks.

      @param direction  +1 next mask, -1 mask.
    */
    void cycleScanlineMask(int direction = +1);

    /**
      Enable/disable/query phosphor effect.
    */
    void enablePhosphor(bool enable, int blend = -1);
    bool phosphorEnabled() const { return myPhosphorHandler.phosphorEnabled(); }

    /**
      Creates a scanline surface for the current TIA resolution
    */
    void createScanlineSurface();

    /**
      Enable/disable/query NTSC filtering effects.
    */
    void enableNTSC(bool enable);
    bool ntscEnabled() const { return uInt8(myFilter) & 0x10; }
    string effectsInfo() const;

    /**
      This method should be called to draw the TIA image(s) to the screen.
    */
    void render(bool shade = false);

    /**
      This method prepares the current frame for taking a snapshot.
      In particular, in phosphor modes the blending is adjusted slightly to
      generate better images.
    */
    void renderForSnapshot();

    /**
      Save a snapshot after rendering.
    */
    void saveSnapShot() { mySaveSnapFlag = true; }

    /**
      Update surface settings.
     */
    void updateSurfaceSettings();

  private:
    enum class ScanlineMask {
      Standard,
      Thin,
      Pixels,
      Aperture,
      Mame,
      NumMasks
    };

    // Enumeration created such that phosphor off/on is in LSB,
    // and Blargg off/on is in MSB
    enum class Filter: uInt8 {
      Normal         = 0x00,
      Phosphor       = 0x01,
      BlarggNormal   = 0x10,
      BlarggPhosphor = 0x11
    };

  private:
    /**
      Average current calculated buffer's pixel with previous calculated buffer's pixel (50:50).
    */
    uInt32 averageBuffers(uInt32 bufOfs);

    // Is plain video mode enabled?
    bool correctAspect() const;

    // Convert scanline mask setting name into type
    ScanlineMask scanlineMaskType(int direction = 0);

    Filter myFilter{Filter::Normal};

  private:
    OSystem& myOSystem;
    FrameBuffer& myFB;
    TIA* myTIA{nullptr};

    shared_ptr<FBSurface> myTiaSurface, mySLineSurface,
                          myBaseTiaSurface, myShadeSurface;

    // NTSC object to use in TIA rendering mode
    NTSCFilter myNTSCFilter;

    /////////////////////////////////////////////////////////////
    // Phosphor mode items (aka reduced flicker on 30Hz screens)
    // RGB frame buffer
    PhosphorHandler myPhosphorHandler;

    // Phosphor blend
    int myPBlend{0};

    std::array<uInt32, AtariNTSC::outWidth(TIAConstants::frameBufferWidth) *
        TIAConstants::frameBufferHeight> myRGBFramebuffer;
    std::array<uInt32, AtariNTSC::outWidth(TIAConstants::frameBufferWidth) *
        TIAConstants::frameBufferHeight> myPrevRGBFramebuffer;
    /////////////////////////////////////////////////////////////

    // Use scanlines in TIA rendering mode
    bool myScanlinesEnabled{false};

    // Palette for normal TIA rendering mode
    PaletteArray myPalette;

    // Flag for saving a snapshot
    bool mySaveSnapFlag{false};

    // The palette handler
    unique_ptr<PaletteHandler> myPaletteHandler;

  private:
    // Following constructors and assignment operators not supported
    TIASurface() = delete;
    TIASurface(const TIASurface&) = delete;
    TIASurface(TIASurface&&) = delete;
    TIASurface& operator=(const TIASurface&) = delete;
    TIASurface& operator=(TIASurface&&) = delete;
};

#endif
