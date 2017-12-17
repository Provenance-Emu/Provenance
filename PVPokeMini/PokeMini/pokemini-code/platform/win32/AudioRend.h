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

typedef void (*AudioRend_Callback)(unsigned char *buf, int len);

typedef struct {
	// Audio was initialized?
	int (*WasInit)();

	// Audio initialize, return if was successful
	int (*Init)(HWND hWnd, int freq, int bits, int channels, int buffsize, AudioRend_Callback callback);

	// Audio terminate
	void (*Terminate)();

	// Audio enable stream?
	void (*Enable)(int play);
} TAudioRend;

extern TAudioRend *AudioRend;

extern const TAudioRend AudioRend_DSound;

void AudioRend_Set(int index);
