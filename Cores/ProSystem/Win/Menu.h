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
// Menu.h
// ----------------------------------------------------------------------------
#ifndef MENU_H
#define MENU_H
#define NULL 0

#include <Windows.h>
#include <String>
#include "Resource.h"
#include "Logger.h"
#include "Console.h"
#include "Common.h"
#include "Display.h"
#include "Sound.h"
#include "Database.h"
#include "Bios.h"

typedef unsigned char byte;
typedef unsigned short word;
typedef unsigned int uint;

extern bool menu_Initialize(HWND hWnd, HINSTANCE hInstance);
extern void menu_Refresh( );
extern void menu_SetEnabled(bool enabled);
extern bool menu_IsEnabled( );
extern HACCEL menu_hAccel;
extern bool screenshot1;
extern bool screenshot2;


#endif