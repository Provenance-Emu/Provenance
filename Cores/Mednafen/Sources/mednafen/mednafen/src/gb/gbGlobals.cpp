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

#include <mednafen/mednafen.h>
#include "gbGlobals.h"

namespace MDFN_IEN_GB
{

uint8 *gbMemoryMap[16];

int gbRomSizeMask;
int gbRomSize;
int gbRamSizeMask;
int gbRamSize;

uint8 *gbVram = NULL;
uint8 *gbRom = NULL;
uint8 *gbRam = NULL;
uint8 *gbWram = NULL;

uint16 gbPalette[128];
uint8 gbBgp[4];
uint8 gbObp0[4];
uint8 gbObp1[4];

int gbWindowLine;

int gbCgbMode;

int gbPaletteOption;
int gbEmulatorType;
int gbDmaTicks;

uint8 (*gbSerialFunction)(uint8) = NULL;

}
