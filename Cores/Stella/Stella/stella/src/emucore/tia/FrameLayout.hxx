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

#ifndef FRAME_LAYOUT
#define FRAME_LAYOUT

enum class FrameLayout {
  ntsc,   // ROM display has NTSC timings (~60Hz, ~262 scanlines, etc)
  pal,    // ROM display has PAL timings (~50Hz, ~312 scanlines, etc)
  pal60,  // ROM display has NTSC timings (~60Hz, ~262 scanlines, etc), but uses PAL colors
  ntsc50  // ROM display has PAL timings (~50Hz, ~312 scanlines, etc), but uses NTSC colors
};

#endif // FRAME_LAYOUT
