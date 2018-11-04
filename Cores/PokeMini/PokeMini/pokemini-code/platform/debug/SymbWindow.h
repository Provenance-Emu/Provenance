/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2015  JustBurn

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

#ifndef SYMBWINDOW_H
#define SYMBWINDOW_H

#include <stdint.h>
#include <gtk/gtk.h>

typedef struct TSymbItem {
	struct TSymbItem *prev;
	struct TSymbItem *next;
	char name[PMTMPV];
	uint32_t addr;
	int size;	// Data only: 0 = 8-Bits, 1 = 16-Bits, 2 = 24-Bits, 3 = 32-Bits
	int ctrl;	// Data only: Control / Display
			// Bit 0-1: 0 = None, 1 = Hexadecimal, 2 = Signed integer, 3 = Unsigned integer
} SymbItem;

// This window management
int SymbWindow_Create(void);
void SymbWindow_Destroy(void);
void SymbWindow_Activate(void);
void SymbWindow_UpdateConfigs(void);
void SymbWindow_ROMLoaded(const char *filename);
void SymbWindow_Sensitive(int enabled);
void SymbWindow_Refresh(int now);

#endif
