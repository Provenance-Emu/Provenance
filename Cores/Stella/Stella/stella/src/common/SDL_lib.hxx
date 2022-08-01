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

#ifndef SDL_LIB_HXX
#define SDL_LIB_HXX

#include "bspf.hxx"

/*
 * We can't control the quality of code from outside projects, so for now
 * just disable warnings for it.
 */
#if defined(__clang__)
  #pragma clang diagnostic push
  #pragma clang diagnostic ignored "-Wdocumentation"
  #pragma clang diagnostic ignored "-Wdocumentation-unknown-command"
  #pragma clang diagnostic ignored "-Wimplicit-fallthrough"
  #pragma clang diagnostic ignored "-Wreserved-id-macro"
  #pragma clang diagnostic ignored "-Wold-style-cast"
  #include <SDL.h>
  #pragma clang diagnostic pop
#elif defined(BSPF_WINDOWS)
  #pragma warning(push, 0)
  #include <SDL.h>
  #pragma warning(pop)
#else
  #include <SDL.h>
#endif

/*
 * Seems to be needed for ppc64le, doesn't hurt other archs
 * Note that this is a problem in SDL2, which includes <altivec.h>
 *  https://bugzilla.redhat.com/show_bug.cgi?id=1419452
 */
#undef vector
#undef pixel
#undef bool

static inline string SDLVersion()
{
  ostringstream buf;
  SDL_version ver;
  SDL_GetVersion(&ver);
  buf << "SDL " << static_cast<int>(ver.major) << "." << static_cast<int>(ver.minor)
      << "." << static_cast<int>(ver.patch);
  return buf.str();
}

static inline bool SDLOpenURL(const string& url)
{
#if SDL_VERSION_ATLEAST(2,0,14)
  return SDL_OpenURL(url.c_str()) == 0;
#else
  cerr << "OpenURL requires at least SDL 2.0.14\n";
  return false;
#endif
}

#endif  // SDL_LIB_HXX
