// -*- C++ -*-
// VisualBoyAdvance - Nintendo Gameboy/GameboyAdvance (TM) emulator.
// Copyright (C) 1999-2003 Forgotten
// Copyright (C) 2005 Forgotten and the VBA development team

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

#ifndef VBA_GFX_H
#define VBA_GFX_H

#include "GBA.h"
#include "Gfx.h"
#include "Globals.h"

#include "Port.h"

namespace MDFN_IEN_GBA
{

//#define SPRITE_DEBUG

void mode0RenderLine();
void mode0RenderLineNoWindow();
void mode0RenderLineAll();

void mode1RenderLine();
void mode1RenderLineNoWindow();
void mode1RenderLineAll();

void mode2RenderLine();
void mode2RenderLineNoWindow();
void mode2RenderLineAll();

void mode3RenderLine();
void mode3RenderLineNoWindow();
void mode3RenderLineAll();

void mode4RenderLine();
void mode4RenderLineNoWindow();
void mode4RenderLineAll();

void mode5RenderLine();
void mode5RenderLineNoWindow();
void mode5RenderLineAll();

MDFN_HIDE extern int all_coeff[32];
MDFN_HIDE extern uint32 AlphaClampLUT[64];
alignas(16) MDFN_HIDE extern uint32 line0[512];
alignas(16) MDFN_HIDE extern uint32 line1[512];
alignas(16) MDFN_HIDE extern uint32 line2[512];
alignas(16) MDFN_HIDE extern uint32 line3[512];
alignas(16) MDFN_HIDE extern uint32 lineOBJ[512];
alignas(16) MDFN_HIDE extern uint32 lineOBJWin[512];
alignas(16) MDFN_HIDE extern uint32 lineMix[512];
MDFN_HIDE extern bool gfxInWin0[512];
MDFN_HIDE extern bool gfxInWin1[512];

MDFN_HIDE extern int gfxBG2Changed;
MDFN_HIDE extern int gfxBG3Changed;

MDFN_HIDE extern int gfxBG2X;
MDFN_HIDE extern int gfxBG2Y;
MDFN_HIDE extern int gfxBG2LastX;
MDFN_HIDE extern int gfxBG2LastY;
MDFN_HIDE extern int gfxBG3X;
MDFN_HIDE extern int gfxBG3Y;
MDFN_HIDE extern int gfxBG3LastX;
MDFN_HIDE extern int gfxBG3LastY;
MDFN_HIDE extern int gfxLastVCOUNT;

}

#endif // VBA_GFX_H
