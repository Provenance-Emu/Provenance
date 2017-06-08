/*
  PokeMini - Pok�mon-Mini Emulator
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

#ifndef MISCWINDOW_H
#define MISCWINDOW_H

#include <stdint.h>
#include <gtk/gtk.h>

// This window management
int MiscWindow_Create(void);
void MiscWindow_Destroy(void);
void MiscWindow_Activate(void);
void MiscWindow_UpdateConfigs(void);
void MiscWindow_Sensitive(int enabled);
void MiscWindow_Refresh(int now);

#endif
