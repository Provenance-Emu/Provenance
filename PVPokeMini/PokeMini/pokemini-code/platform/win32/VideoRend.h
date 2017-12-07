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

#include <windows.h>

typedef struct {
	// Video was initialized?
	int (*WasInit)();

	// Video initialize, return bpp
	int (*Init)(HWND hWnd, int width, int height, int fullscreen);

	// Video terminate
	void (*Terminate)();

	// Window resize
	void (*ResizeWin)(int width, int height);

	// Get pitch in bytes and pixels
	void (*GetPitch)(int *bytpitch, int *pixpitch);

	// Clear video, do not call inside locked buffer
	void (*ClearVideo)();

	// Lock video buffer, return true on success
	int (*Lock)(void **videobuffer);

	// Unlock video buffer
	void (*Unlock)();

	// Flip and render to window
	void (*Flip)(HWND hWnd);

	// Window requesting painting
	void (*Paint)(HWND hWnd);
} TVideoRend;

extern TVideoRend *VideoRend;

extern const TVideoRend VideoRend_GDI;
extern const TVideoRend VideoRend_DDraw;
extern const TVideoRend VideoRend_D3D;

void VideoRend_Set(int index);
