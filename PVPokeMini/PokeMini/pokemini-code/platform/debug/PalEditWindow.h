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

#ifndef PALEDITWINDOW_H
#define PALEDITWINDOW_H

#include <stdint.h>
#include <gtk/gtk.h>

// This window management
int PalEditWindow_Create(void);
void PalEditWindow_Destroy(void);
void PalEditWindow_Activate(void);
void PalEditWindow_UpdateConfigs(void);

#endif
