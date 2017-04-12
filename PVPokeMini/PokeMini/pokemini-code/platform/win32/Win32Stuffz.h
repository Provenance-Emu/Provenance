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

// Open file dialog
int OpenFileDialogEx(HWND parentwindow, const char *title, char *fileout, const char *filein, const char *exts, int extidx);

// Save file dialog
int SaveFileDialogEx(HWND parentwindow, const char *title, char *fileout, const char *filein, const char *exts, int extidx);

// For Visual C++ compability
#ifdef _MSC_VER
int strcasecmp(const char *s1, const char *s2);
#endif

