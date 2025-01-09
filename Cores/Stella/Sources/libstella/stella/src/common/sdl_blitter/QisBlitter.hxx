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

#ifndef QIS_BLITTER_HXX
#define QIS_BLITTER_HXX

class FBBackendSDL2;

#include "Blitter.hxx"
#include "SDL_lib.hxx"

class QisBlitter : public Blitter {

  public:

    explicit QisBlitter(FBBackendSDL2& fb);

    static bool isSupported(const FBBackendSDL2& fb);

    ~QisBlitter() override;

    void reinitialize(
      SDL_Rect srcRect,
      SDL_Rect destRect,
      FBSurface::Attributes attributes,
      SDL_Surface* staticData
    ) override;

    void blit(SDL_Surface& surface) override;

  private:

    FBBackendSDL2& myFB;

    SDL_Texture* mySrcTexture{nullptr};
    SDL_Texture* mySecondarySrcTexture{nullptr};
    SDL_Texture* myIntermediateTexture{nullptr};
    SDL_Texture* mySecondaryIntermedateTexture{nullptr};

    SDL_Rect mySrcRect{0, 0, 0, 0}, myIntermediateRect{0, 0, 0, 0}, myDstRect{0, 0, 0, 0};
    FBSurface::Attributes myAttributes;

    bool myTexturesAreAllocated{false};
    bool myRecreateTextures{false};

    SDL_Surface* myStaticData{nullptr};

  private:

    void free();

    void recreateTexturesIfNecessary();

    void blitToIntermediate();

  private:

    QisBlitter(const QisBlitter&) = delete;

    QisBlitter(QisBlitter&&) = delete;

    QisBlitter& operator=(const QisBlitter&) = delete;

    QisBlitter& operator=(QisBlitter&&) = delete;
};

#endif // QIS_BLITTER_HXX
