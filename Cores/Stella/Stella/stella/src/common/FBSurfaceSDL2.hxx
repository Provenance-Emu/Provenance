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

#ifndef FBSURFACE_SDL2_HXX
#define FBSURFACE_SDL2_HXX

#include "bspf.hxx"
#include "FBSurface.hxx"
#include "FBBackendSDL2.hxx"
#include "sdl_blitter/Blitter.hxx"

/**
  An FBSurface suitable for the SDL2 Render2D API, making use of hardware
  acceleration behind the scenes.

  @author  Stephen Anthony
*/
class FBSurfaceSDL2 : public FBSurface
{
  public:
    FBSurfaceSDL2(FBBackendSDL2& backend, uInt32 width, uInt32 height,
                  ScalingInterpolation inter, const uInt32* staticData);
    ~FBSurfaceSDL2() override;

    // Most of the surface drawing primitives are implemented in FBSurface;
    // the ones implemented here use SDL-specific code for extra performance
    //
    void fillRect(uInt32 x, uInt32 y, uInt32 w, uInt32 h, ColorId color) override;

    uInt32 width() const override;
    uInt32 height() const override;

    const Common::Rect& srcRect() const override;
    const Common::Rect& dstRect() const override;
    void setSrcPos(uInt32 x, uInt32 y) override;
    void setSrcSize(uInt32 w, uInt32 h) override;
    void setSrcRect(const Common::Rect& r) override;
    void setDstPos(uInt32 x, uInt32 y) override;
    void setDstSize(uInt32 w, uInt32 h) override;
    void setDstRect(const Common::Rect& r) override;

    void setVisible(bool visible) override;

    void translateCoords(Int32& x, Int32& y) const override;
    bool render() override;
    void invalidate() override;
    void invalidateRect(uInt32 x, uInt32 y, uInt32 w, uInt32 h) override;

    void reload() override;
    void resize(uInt32 width, uInt32 height) override;

    void setScalingInterpolation(ScalingInterpolation) override;

  protected:
    void applyAttributes() override;

  private:
    inline bool setSrcPosInternal(uInt32 x, uInt32 y) {
      if(x != static_cast<uInt32>(mySrcR.x) || y != static_cast<uInt32>(mySrcR.y))
      {
        mySrcR.x = x;  mySrcR.y = y;
        mySrcGUIR.moveTo(x, y);
        return true;
      }
      return false;
    }
    inline bool setSrcSizeInternal(uInt32 w, uInt32 h) {
      if(w != static_cast<uInt32>(mySrcR.w) || h != static_cast<uInt32>(mySrcR.h))
      {
        mySrcR.w = w;  mySrcR.h = h;
        mySrcGUIR.setWidth(w);  mySrcGUIR.setHeight(h);
        return true;
      }
      return false;
    }
    inline bool setDstPosInternal(uInt32 x, uInt32 y) {
      if(x != static_cast<uInt32>(myDstR.x) || y != static_cast<uInt32>(myDstR.y))
      {
        myDstR.x = x;  myDstR.y = y;
        myDstGUIR.moveTo(x, y);
        return true;
      }
      return false;
    }
    inline bool setDstSizeInternal(uInt32 w, uInt32 h) {
      if(w != static_cast<uInt32>(myDstR.w) || h != static_cast<uInt32>(myDstR.h))
      {
        myDstR.w = w;  myDstR.h = h;
        myDstGUIR.setWidth(w);  myDstGUIR.setHeight(h);
        return true;
      }
      return false;
    }

    void createSurface(uInt32 width, uInt32 height, const uInt32* data);

    void reinitializeBlitter(bool force = false);

    // Following constructors and assignment operators not supported
    FBSurfaceSDL2() = delete;
    FBSurfaceSDL2(const FBSurfaceSDL2&) = delete;
    FBSurfaceSDL2(FBSurfaceSDL2&&) = delete;
    FBSurfaceSDL2& operator=(const FBSurfaceSDL2&) = delete;
    FBSurfaceSDL2& operator=(FBSurfaceSDL2&&) = delete;

  private:
    FBBackendSDL2& myBackend;

    unique_ptr<Blitter> myBlitter;
    ScalingInterpolation myInterpolationMode
        {ScalingInterpolation::none};

    SDL_Surface* mySurface{nullptr};
    SDL_Rect mySrcR{-1, -1, -1, -1}, myDstR{-1, -1, -1, -1};

    bool myIsVisible{true};
    bool myIsStatic{false};

    Common::Rect mySrcGUIR, myDstGUIR;
};

#endif
