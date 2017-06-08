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

#ifndef EXTERNALWINDOW_H
#define EXTERNALWINDOW_H

#include <stdint.h>
#include <gtk/gtk.h>

// External launcher
int ExternalWindow_Launch(const char *execcod, int atcurrdir);

// This window management
int ExternalWindow_Create(void);
void ExternalWindow_Destroy(void);
void ExternalWindow_Activate(GtkItemFactory *itemfact);
void ExternalWindow_UpdateConfigs(void);
void ExternalWindow_UpdateMenu(GtkItemFactory *itemfact);

#endif
