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

#ifndef WINDOWS_LIB_HXX
#define WINDOWS_LIB_HXX

/*
  Using window.h directly can cause problems, since it's a C library
  that doesn't support namespacing, etc.

  Anyone needing 'windows.h' should include this file instead.
*/

#include <windows.h>

#undef MessageBox
#undef ARRAYSIZE

#endif  // WINDOWS_LIB_HXX
