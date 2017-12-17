/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2012  JustBurn

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#pragma once

#include "resource.h"

enum {
	EMUMODE_RESTORE = -1,		// Restore mode
	EMUMODE_STOP = 0,			// Stopped
	EMUMODE_RUNFULL,			// Run at full speed
	EMUMODE_TERMINATE,			// Terminate
};
extern volatile int emumodeE;	// Read-Only, current emulation mode
extern volatile int emumodeA;	// Read-Only, current app emu mode
void set_emumode(int mode, int tempsave);

void PokeMiniW_RegisterClasses(HINSTANCE hInstance);
int PokeMiniW_CreateWindow(HINSTANCE hInstance, int nCmdShow);
void PokeMiniW_DestroyWindow(void);
void VMainWndClientSize(HWND hWnd, int Width, int Height);
void MainWndClientSize(HWND hWnd, int Width, int Height);
LRESULT CALLBACK PokeMiniW_WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam);
void SetStatusBarText(char *format, ...);

extern int wclc_winx;
extern int wclc_winy;
extern int wclc_winw;
extern int wclc_winh;
extern int wclc_autorun;
extern int wclc_videorend;
extern int wclc_audiorend;
extern int wclc_forcefeedback;

void render_dummyframe(void);
