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

#ifndef CONSOLE_TIMING_HXX
#define CONSOLE_TIMING_HXX

/**
  Contains timing information about the specified console.
*/
enum class ConsoleTiming
{
  ntsc,  // console with CPU running at 1.193182 MHz, NTSC colours
  pal,   // console with CPU running at 1.182298 MHz, PAL colours
  secam, // console with CPU running at 1.187500 MHz, SECAM colours
  numTimings
};

#endif // CONSOLE_TIMING_HXX
