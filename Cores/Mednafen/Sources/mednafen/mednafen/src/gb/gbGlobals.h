// -*- C++ -*-
// VisualBoyAdvance - Nintendo Gameboy/GameboyAdvance (TM) emulator.
// Copyright (C) 1999-2003 Forgotten
// Copyright (C) 2004 Forgotten and the VBA development team

// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2, or(at your option)
// any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software Foundation,
// Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

using namespace Mednafen;

namespace MDFN_IEN_GB
{

MDFN_HIDE extern int gbRomSizeMask;
MDFN_HIDE extern int gbRomSize;
MDFN_HIDE extern int gbRamSize;
MDFN_HIDE extern int gbRamSizeMask;

MDFN_HIDE extern uint8 *gbRom;
MDFN_HIDE extern uint8 *gbRam;
MDFN_HIDE extern uint8 *gbVram;
MDFN_HIDE extern uint8 *gbWram;

MDFN_HIDE extern uint8 *gbMemoryMap[16];

MDFN_HIDE extern int gbFrameSkip;
MDFN_HIDE extern int gbEmulatorType;
MDFN_HIDE extern int gbCgbMode;
MDFN_HIDE extern int gbSgbMode;
MDFN_HIDE extern int gbWindowLine;
MDFN_HIDE extern int gbSpeed;
MDFN_HIDE extern uint8 gbBgp[4];
MDFN_HIDE extern uint8 gbObp0[4];
MDFN_HIDE extern uint8 gbObp1[4];
MDFN_HIDE extern uint16 gbPalette[128];
union gblmt
{
 uint16 cgb[160];
 uint8 dmg[160];
 uint32 dmg_32[40];
};
MDFN_HIDE extern gblmt gbLineMix;

MDFN_HIDE extern uint8 register_LCDC;
MDFN_HIDE extern uint8 register_LY;
MDFN_HIDE extern uint8 register_SCY;
MDFN_HIDE extern uint8 register_SCX;
MDFN_HIDE extern uint8 register_WY;
MDFN_HIDE extern uint8 register_WX;
MDFN_HIDE extern uint8 register_VBK;

MDFN_HIDE extern int emulating;

MDFN_HIDE extern int gbDmaTicks;

void gbRenderLine(void);

MDFN_HIDE extern uint32 gblayerSettings;
MDFN_HIDE extern uint8 (*gbSerialFunction)(uint8);

}
