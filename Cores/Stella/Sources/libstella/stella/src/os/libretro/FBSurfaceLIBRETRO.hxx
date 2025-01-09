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

#ifndef FBSURFACE_LIBRETRO_HXX
#define FBSURFACE_LIBRETRO_HXX

#include "bspf.hxx"
#include "FBSurface.hxx"

/**
  An FBSurface suitable for the LIBRETRO API.  As with FBBackend,
  most of the functionality here is handled by libretro directly.

  @author  Stephen Anthony
*/
class FBSurfaceLIBRETRO : public FBSurface
{
  public:
    FBSurfaceLIBRETRO(uInt32 width, uInt32 height)
      : myWidth{width},
        myHeight{height},
        myPixelData{make_unique<uInt32[]>(myWidth * myHeight)}
    {
      ////////////////////////////////////////////////////
      // These *must* be set for the parent class
      myPixels = myPixelData.get();
      myPitch = myWidth;
      ////////////////////////////////////////////////////
    }
    ~FBSurfaceLIBRETRO() override { }

    // Most of the surface drawing primitives are implemented in FBSurface;
    void fillRect(uInt32 x, uInt32 y, uInt32 w,
                  uInt32 h, ColorId color) override { }

    uInt32 width() const override { return myWidth; }
    uInt32 height() const override { return myHeight; }

    const Common::Rect& srcRect() const override { return mySrcGUIR; }
    const Common::Rect& dstRect() const override { return myDstGUIR; }
    void setSrcPos(uInt32 x, uInt32 y) override { }
    void setSrcSize(uInt32 w, uInt32 h) override { }
    void setSrcRect(const Common::Rect& r) override { }
    void setDstPos(uInt32 x, uInt32 y) override { }
    void setDstSize(uInt32 w, uInt32 h) override { }
    void setDstRect(const Common::Rect& r) override { }

    void setVisible(bool visible) override { }

    void translateCoords(Int32& x, Int32& y) const override { }
    bool render() override { return true; }
    void invalidate() override { }
    void invalidateRect(uInt32, uInt32, uInt32, uInt32) override { }
    void reload() override { }
    void resize(uInt32 width, uInt32 height) override { }
    void setScalingInterpolation(ScalingInterpolation) override { }

  protected:
    void applyAttributes() override { }

  private:
    uInt32 myWidth{0}, myHeight{0};
    unique_ptr<uInt32[]> myPixelData;
    Common::Rect mySrcGUIR, myDstGUIR;

  private:
    // Following constructors and assignment operators not supported
    FBSurfaceLIBRETRO() = delete;
    FBSurfaceLIBRETRO(const FBSurfaceLIBRETRO&) = delete;
    FBSurfaceLIBRETRO(FBSurfaceLIBRETRO&&) = delete;
    FBSurfaceLIBRETRO& operator=(const FBSurfaceLIBRETRO&) = delete;
    FBSurfaceLIBRETRO& operator=(FBSurfaceLIBRETRO&&) = delete;
};

#endif
