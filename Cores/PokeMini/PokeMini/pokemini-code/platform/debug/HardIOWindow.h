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

#ifndef HARDIOWINDOW_H
#define HARDIOWINDOW_H

#include <stdint.h>
#include <gtk/gtk.h>

typedef struct {
	int regaddr;
	char *idname;
	struct {
		int type;
		char *name;
	} bit[8];	// Order is inversed!
	char *description;
} THardIOWindow_RegInfo;

// This window management
int HardIOWindow_Create(void);
void HardIOWindow_Destroy(void);
void HardIOWindow_Activate(void);
void HardIOWindow_UpdateConfigs(void);
void HardIOWindow_Sensitive(int enabled);
void HardIOWindow_Refresh(int now);

#endif
