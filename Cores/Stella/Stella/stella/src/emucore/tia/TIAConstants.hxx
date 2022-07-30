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

#ifndef TIA_CONSTANTS_HXX
#define TIA_CONSTANTS_HXX

#include "bspf.hxx"

namespace TIAConstants {

  static constexpr uInt32 frameBufferWidth = 160;
  static constexpr uInt32 frameBufferHeight = 320;
  static constexpr Int32 minVcenter = -20; // limit to reasonable values
  static constexpr Int32 maxVcenter = 20; // limit to reasonable values
  static constexpr uInt32 viewableWidth = 320;
  static constexpr uInt32 viewableHeight = 240;
  static constexpr uInt32 initialGarbageFrames = 10;

  static constexpr uInt16
    H_PIXEL = 160, H_CYCLES = 76, CYCLE_CLOCKS = 3,
    H_CLOCKS = H_CYCLES * CYCLE_CLOCKS,   // = 228
    H_BLANK_CLOCKS = H_CLOCKS - H_PIXEL;  // = 68
}

enum TIABit {
  P0Bit       = 0x01,  // Bit for Player 0
  M0Bit       = 0x02,  // Bit for Missle 0
  P1Bit       = 0x04,  // Bit for Player 1
  M1Bit       = 0x08,  // Bit for Missle 1
  BLBit       = 0x10,  // Bit for Ball
  PFBit       = 0x20,  // Bit for Playfield
  ScoreBit    = 0x40,  // Bit for Playfield score mode
  PriorityBit = 0x80   // Bit for Playfield priority
};

enum TIAColor {
  BKColor     = 0,  // Color index for Background
  PFColor     = 1,  // Color index for Playfield
  P0Color     = 2,  // Color index for Player 0
  P1Color     = 3,  // Color index for Player 1
  M0Color     = 4,  // Color index for Missle 0
  M1Color     = 5,  // Color index for Missle 1
  BLColor     = 6,  // Color index for Ball
  HBLANKColor = 7   // Color index for HMove blank area
};

enum class CollisionBit
{
  M0P1 = 1 << 0,   // Missle0 - Player1   collision
  M0P0 = 1 << 1,   // Missle0 - Player0   collision
  M1P0 = 1 << 2,   // Missle1 - Player0   collision
  M1P1 = 1 << 3,   // Missle1 - Player1   collision
  P0PF = 1 << 4,   // Player0 - Playfield collision
  P0BL = 1 << 5,   // Player0 - Ball      collision
  P1PF = 1 << 6,   // Player1 - Playfield collision
  P1BL = 1 << 7,   // Player1 - Ball      collision
  M0PF = 1 << 8,   // Missle0 - Playfield collision
  M0BL = 1 << 9,   // Missle0 - Ball      collision
  M1PF = 1 << 10,  // Missle1 - Playfield collision
  M1BL = 1 << 11,  // Missle1 - Ball      collision
  BLPF = 1 << 12,  // Ball - Playfield    collision
  P0P1 = 1 << 13,  // Player0 - Player1   collision
  M0M1 = 1 << 14   // Missle0 - Missle1   collision
};

// TIA Write/Read register names
enum TIARegister {
  VSYNC   = 0x00,  // Write: vertical sync set-clear (D1)
  VBLANK  = 0x01,  // Write: vertical blank set-clear (D7-6,D1)
  WSYNC   = 0x02,  // Write: wait for leading edge of hrz. blank (strobe)
  RSYNC   = 0x03,  // Write: reset hrz. sync counter (strobe)
  NUSIZ0  = 0x04,  // Write: number-size player-missle 0 (D5-0)
  NUSIZ1  = 0x05,  // Write: number-size player-missle 1 (D5-0)
  COLUP0  = 0x06,  // Write: color-lum player 0 (D7-1)
  COLUP1  = 0x07,  // Write: color-lum player 1 (D7-1)
  COLUPF  = 0x08,  // Write: color-lum playfield (D7-1)
  COLUBK  = 0x09,  // Write: color-lum background (D7-1)
  CTRLPF  = 0x0a,  // Write: cntrl playfield ballsize & coll. (D5-4,D2-0)
  REFP0   = 0x0b,  // Write: reflect player 0 (D3)
  REFP1   = 0x0c,  // Write: reflect player 1 (D3)
  PF0     = 0x0d,  // Write: playfield register byte 0 (D7-4)
  PF1     = 0x0e,  // Write: playfield register byte 1 (D7-0)
  PF2     = 0x0f,  // Write: playfield register byte 2 (D7-0)
  RESP0   = 0x10,  // Write: reset player 0 (strobe)
  RESP1   = 0x11,  // Write: reset player 1 (strobe)
  RESM0   = 0x12,  // Write: reset missle 0 (strobe)
  RESM1   = 0x13,  // Write: reset missle 1 (strobe)
  RESBL   = 0x14,  // Write: reset ball (strobe)
  AUDC0   = 0x15,  // Write: audio control 0 (D3-0)
  AUDC1   = 0x16,  // Write: audio control 1 (D4-0)
  AUDF0   = 0x17,  // Write: audio frequency 0 (D4-0)
  AUDF1   = 0x18,  // Write: audio frequency 1 (D3-0)
  AUDV0   = 0x19,  // Write: audio volume 0 (D3-0)
  AUDV1   = 0x1a,  // Write: audio volume 1 (D3-0)
  GRP0    = 0x1b,  // Write: graphics player 0 (D7-0)
  GRP1    = 0x1c,  // Write: graphics player 1 (D7-0)
  ENAM0   = 0x1d,  // Write: graphics (enable) missle 0 (D1)
  ENAM1   = 0x1e,  // Write: graphics (enable) missle 1 (D1)
  ENABL   = 0x1f,  // Write: graphics (enable) ball (D1)
  HMP0    = 0x20,  // Write: horizontal motion player 0 (D7-4)
  HMP1    = 0x21,  // Write: horizontal motion player 1 (D7-4)
  HMM0    = 0x22,  // Write: horizontal motion missle 0 (D7-4)
  HMM1    = 0x23,  // Write: horizontal motion missle 1 (D7-4)
  HMBL    = 0x24,  // Write: horizontal motion ball (D7-4)
  VDELP0  = 0x25,  // Write: vertical delay player 0 (D0)
  VDELP1  = 0x26,  // Write: vertical delay player 1 (D0)
  VDELBL  = 0x27,  // Write: vertical delay ball (D0)
  RESMP0  = 0x28,  // Write: reset missle 0 to player 0 (D1)
  RESMP1  = 0x29,  // Write: reset missle 1 to player 1 (D1)
  HMOVE   = 0x2a,  // Write: apply horizontal motion (strobe)
  HMCLR   = 0x2b,  // Write: clear horizontal motion registers (strobe)
  CXCLR   = 0x2c,  // Write: clear collision latches (strobe)

  CXM0P   = 0x00,  // Read collision: D7=(M0,P1); D6=(M0,P0)
  CXM1P   = 0x01,  // Read collision: D7=(M1,P0); D6=(M1,P1)
  CXP0FB  = 0x02,  // Read collision: D7=(P0,PF); D6=(P0,BL)
  CXP1FB  = 0x03,  // Read collision: D7=(P1,PF); D6=(P1,BL)
  CXM0FB  = 0x04,  // Read collision: D7=(M0,PF); D6=(M0,BL)
  CXM1FB  = 0x05,  // Read collision: D7=(M1,PF); D6=(M1,BL)
  CXBLPF  = 0x06,  // Read collision: D7=(BL,PF); D6=(unused)
  CXPPMM  = 0x07,  // Read collision: D7=(P0,P1); D6=(M0,M1)
  INPT0   = 0x08,  // Read pot port: D7
  INPT1   = 0x09,  // Read pot port: D7
  INPT2   = 0x0a,  // Read pot port: D7
  INPT3   = 0x0b,  // Read pot port: D7
  INPT4   = 0x0c,  // Read P1 joystick trigger: D7
  INPT5   = 0x0d   // Read P2 joystick trigger: D7
};

#endif // TIA_CONSTANTS_HXX
