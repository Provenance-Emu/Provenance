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
// Console.h
// ----------------------------------------------------------------------------
#ifndef CONSOLE_H
#define CONSOLE_H
#define CONSOLE_VERSION 1.3
#define CONSOLE_TITLE "ProSystem Emulator"
#define NULL 0

#include <Windows.h>
#include <String>
#include "Resource.h"
#include "Menu.h"
#include "Configuration.h"
#include "Display.h"
#include "Input.h"
#include "Database.h"
#include "Sound.h"
#include "Timer.h"
#include "ProSystem.h"
#include "Help.h"
#include "About.h"

typedef unsigned char byte;
typedef unsigned short word;
typedef unsigned int uint;

extern bool console_Initialize(HINSTANCE hInstance, std::string commandLine);
extern void console_Run( );
extern void console_Open(std::string filename);
extern void console_SetZoom(byte zoom);
extern void console_SetFullscreen(bool fullscreen);
extern RECT console_GetWindowRect( );
extern void console_SetWindowRect(RECT windowRect);
extern void console_SetMenuEnabled(bool enabled);
extern void console_SetUserInput(byte *data, int index);
extern void console_Exit(void);
extern std::string console_recent[10];
extern std::string console_savePath;
extern byte console_frameSkip;

#endif
