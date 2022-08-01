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

#ifndef BLITTER_HXX
#define BLITTER_HXX

#include "bspf.hxx"
#include "SDL_lib.hxx"
#include "FBSurface.hxx"

class Blitter {

  public:

    virtual ~Blitter() = default;

    virtual void reinitialize(
      SDL_Rect srcRect,
      SDL_Rect destRect,
      FBSurface::Attributes attributes,
      SDL_Surface* staticData = nullptr
    ) = 0;

    virtual void blit(SDL_Surface& surface) = 0;

  protected:

    Blitter() = default;

  private:

    Blitter(const Blitter&) = delete;

    Blitter(Blitter&&) = delete;

    Blitter& operator=(const Blitter&) = delete;

    Blitter& operator=(Blitter&&) = delete;
};

#endif // BLITTER_HXX
