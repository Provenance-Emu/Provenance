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

#ifndef VBA_GLOBALS_H
#define VBA_GLOBALS_H

namespace MDFN_IEN_GBA
{

#define VERBOSE_SWI                  1
#define VERBOSE_UNALIGNED_MEMORY     2
#define VERBOSE_ILLEGAL_WRITE        4
#define VERBOSE_ILLEGAL_READ         8
#define VERBOSE_DMA0                16
#define VERBOSE_DMA1                32
#define VERBOSE_DMA2                64
#define VERBOSE_DMA3               128
#define VERBOSE_UNDEFINED          256
#define VERBOSE_AGBPRINT           512

MDFN_HIDE extern reg_pair reg[45];
MDFN_HIDE extern bool ioReadable[0x400];

MDFN_HIDE extern uint32 N_FLAG;
MDFN_HIDE extern bool C_FLAG;
MDFN_HIDE extern bool Z_FLAG;
MDFN_HIDE extern bool V_FLAG;

MDFN_HIDE extern bool armState;
MDFN_HIDE extern bool armIrqEnable;
MDFN_HIDE extern uint32 armNextPC;
MDFN_HIDE extern int armMode;
MDFN_HIDE extern uint32 stop;
MDFN_HIDE extern int saveType;
MDFN_HIDE extern bool useBios;
MDFN_HIDE extern bool skipBios;
MDFN_HIDE extern bool cpuDisableSfx;
MDFN_HIDE extern bool cpuIsMultiBoot;
MDFN_HIDE extern int layerSettings;
MDFN_HIDE extern int layerEnable;

MDFN_HIDE extern uint8 *bios;
MDFN_HIDE extern uint8 *rom;
MDFN_HIDE extern uint8 *internalRAM;
MDFN_HIDE extern uint8 *workRAM;
MDFN_HIDE extern uint8 *paletteRAM;
MDFN_HIDE extern uint8 *vram;
MDFN_HIDE extern uint8 *oam;
MDFN_HIDE extern uint8 *ioMem;

MDFN_HIDE extern uint16 DISPCNT;
MDFN_HIDE extern uint16 DISPSTAT;
MDFN_HIDE extern uint16 VCOUNT;
MDFN_HIDE extern uint16 BG0CNT;
MDFN_HIDE extern uint16 BG1CNT;
MDFN_HIDE extern uint16 BG2CNT;
MDFN_HIDE extern uint16 BG3CNT;

MDFN_HIDE extern uint16 BGHOFS[4];
MDFN_HIDE extern uint16 BGVOFS[4];

MDFN_HIDE extern uint16 BG2PA;
MDFN_HIDE extern uint16 BG2PB;
MDFN_HIDE extern uint16 BG2PC;
MDFN_HIDE extern uint16 BG2PD;
MDFN_HIDE extern uint16 BG2X_L;
MDFN_HIDE extern uint16 BG2X_H;
MDFN_HIDE extern uint16 BG2Y_L;
MDFN_HIDE extern uint16 BG2Y_H;
MDFN_HIDE extern uint16 BG3PA;
MDFN_HIDE extern uint16 BG3PB;
MDFN_HIDE extern uint16 BG3PC;
MDFN_HIDE extern uint16 BG3PD;
MDFN_HIDE extern uint16 BG3X_L;
MDFN_HIDE extern uint16 BG3X_H;
MDFN_HIDE extern uint16 BG3Y_L;
MDFN_HIDE extern uint16 BG3Y_H;
MDFN_HIDE extern uint16 WIN0H;
MDFN_HIDE extern uint16 WIN1H;
MDFN_HIDE extern uint16 WIN0V;
MDFN_HIDE extern uint16 WIN1V;
MDFN_HIDE extern uint16 WININ;
MDFN_HIDE extern uint16 WINOUT;
MDFN_HIDE extern uint16 MOSAIC;
MDFN_HIDE extern uint16 BLDMOD;
MDFN_HIDE extern uint16 COLEV;
MDFN_HIDE extern uint16 COLY;

MDFN_HIDE extern uint16 DMSAD_L[4];
MDFN_HIDE extern uint16 DMSAD_H[4];
MDFN_HIDE extern uint16 DMDAD_L[4];
MDFN_HIDE extern uint16 DMDAD_H[4];
MDFN_HIDE extern uint16 DMCNT_L[4];
MDFN_HIDE extern uint16 DMCNT_H[4];

MDFN_HIDE extern uint16 P1;
MDFN_HIDE extern uint16 IE;
MDFN_HIDE extern uint16 IF;
MDFN_HIDE extern uint16 IME;

}

#endif // VBA_GLOBALS_H
