// ----------------------------------------------------------------------------
//   ___  ___  ___  ___       ___  ____  ___  _  _
//  /__/ /__/ /  / /__  /__/ /__    /   /_   / |/ /
// /    / \  /__/ ___/ ___/ ___/   /   /__  /    /  emulator
//
// ----------------------------------------------------------------------------
// Copyright 2005 Greg Stanton
// 
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
// ----------------------------------------------------------------------------
// Display.h
// ----------------------------------------------------------------------------
#ifndef DISPLAY_H
#define DISPLAY_H
#define NULL 0

#include <Windows.h>
#include <DDraw.h>
#include <Vector>
#include "Palette.h"
#include "Maria.h"
#include "Common.h"
#include "Logger.h"

typedef unsigned char byte;
typedef unsigned short word;
typedef unsigned int uint;

struct Mode {
  uint width;
  uint height;
  uint bpp;
  uint rmask;
  uint gmask;
  uint bmask;
};

extern bool display_Initialize(HWND hWnd);
extern bool display_SetFullscreen( );
extern bool display_SetWindowed( );
extern bool display_Show( );
extern bool display_ResetPalette( );
extern bool display_TakeScreenshot(std::string filename);
extern bool display_Clear( );
extern bool display_IsFullscreen( );
extern void display_Release( );
extern bool display_stretched;
extern bool display_fullscreen;
extern bool display_menuenabled;
extern byte display_zoom;
extern std::vector<Mode> display_modes;
extern Mode display_mode;

#endif
