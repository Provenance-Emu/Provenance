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

#ifndef BILINEAR_BLITTER_HXX
#define BILINEAR_BLITTER_HXX

class FBBackendSDL2;

#include "Blitter.hxx"
#include "SDL_lib.hxx"

class BilinearBlitter : public Blitter {

  public:

    BilinearBlitter(FBBackendSDL2& fb, bool interpolate);

    ~BilinearBlitter() override;

    void reinitialize(
      SDL_Rect srcRect,
      SDL_Rect destRect,
      FBSurface::Attributes attributes,
      SDL_Surface* staticData = nullptr
    ) override;

    void blit(SDL_Surface& surface) override;

  private:
    FBBackendSDL2& myFB;

    SDL_Texture* myTexture{nullptr};
    SDL_Texture* mySecondaryTexture{nullptr};
    SDL_Rect mySrcRect{0, 0, 0, 0}, myDstRect{0, 0, 0, 0};
    FBSurface::Attributes myAttributes;

    bool myInterpolate{false};
    bool myTexturesAreAllocated{false};
    bool myRecreateTextures{false};

    SDL_Surface* myStaticData{nullptr};

  private:

    void free();

    void recreateTexturesIfNecessary();

  private:

    BilinearBlitter(const BilinearBlitter&) = delete;

    BilinearBlitter(BilinearBlitter&&) = delete;

    BilinearBlitter& operator=(const BilinearBlitter&) = delete;

    BilinearBlitter& operator=(BilinearBlitter&&) = delete;
};

#endif // BILINEAR_BLITTER_HXX
