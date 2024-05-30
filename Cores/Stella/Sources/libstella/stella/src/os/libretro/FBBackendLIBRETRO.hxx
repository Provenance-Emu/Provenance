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

#ifndef FB_BACKEND_LIBRETRO_HXX
#define FB_BACKEND_LIBRETRO_HXX

class OSystem;

#include "bspf.hxx"
#include "FBBackend.hxx"
#include "FBSurfaceLIBRETRO.hxx"

/**
  This class implements a standard LIBRETRO framebuffer backend.  Most of
  the functionality is not used, since libretro has its own rendering system.

  @author  Stephen Anthony
*/
class FBBackendLIBRETRO : public FBBackend
{
  public:
    explicit FBBackendLIBRETRO(OSystem&) { }
    ~FBBackendLIBRETRO() override { }

  protected:
    /**
      This method is called to map a given R/G/B triple to the screen palette.

      @param r  The red component of the color.
      @param g  The green component of the color.
      @param b  The blue component of the color.
    */
    uInt32 mapRGB(uInt8 r, uInt8 g, uInt8 b) const override {
      return (r << 16) | (g << 8) | b;
    }
    uInt32 mapRGBA(uInt8 r, uInt8 g, uInt8 b, uInt8 a) const override {
      return (a << 24) | (r << 16) | (g << 8) | b;
    }

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
                       VariantList& renderers) override
    {
      fullscreenRes.emplace_back(1920, 1080);
      windowedRes.emplace_back(1920, 1080);

      VarList::push_back(renderers, "software", "Software");
    }

    /**
      This method is called to create a surface with the given attributes.

      @param w     The requested width of the new surface.
      @param h     The requested height of the new surface.
    */
    unique_ptr<FBSurface>
      createSurface(uInt32 w, uInt32 h, ScalingInterpolation,
                    const uInt32*) const override
    {
      return make_unique<FBSurfaceLIBRETRO>(w, h);
    }

    /**
      This method is called to provide information about the backend.
    */
    string about() const override { return "Video system: libretro"; }


    //////////////////////////////////////////////////////////////////////
    // Most methods here aren't used at all.  See FBBacked class for
    // description, if needed.
    //////////////////////////////////////////////////////////////////////

    int scaleX(int x) const override { return x; }
    int scaleY(int y) const override { return y; }
    void setTitle(string_view) override { }
    void showCursor(bool) override { }
    bool fullScreen() const override { return true; }
    void getRGB(uInt32, uInt8*, uInt8*, uInt8*) const override { }
    void getRGBA(uInt32, uInt8*, uInt8*, uInt8*, uInt8*) const override { }
    void readPixels(uInt8*, size_t, const Common::Rect&) const override { }
    bool isCurrentWindowPositioned() const override { return true; }
    Common::Point getCurrentWindowPos() const override { return Common::Point{}; }
    Int32 getCurrentDisplayIndex() const override { return 0; }
    void clear() override { }
    bool setVideoMode(const VideoModeHandler::Mode&,
                      int, const Common::Point&) override { return true; }
    void grabMouse(bool) override { }
    void renderToScreen() override { }
    int refreshRate() const override { return 0; }

  private:
    // Following constructors and assignment operators not supported
    FBBackendLIBRETRO() = delete;
    FBBackendLIBRETRO(const FBBackendLIBRETRO&) = delete;
    FBBackendLIBRETRO(FBBackendLIBRETRO&&) = delete;
    FBBackendLIBRETRO& operator=(const FBBackendLIBRETRO&) = delete;
    FBBackendLIBRETRO& operator=(FBBackendLIBRETRO&&) = delete;
};

#endif
