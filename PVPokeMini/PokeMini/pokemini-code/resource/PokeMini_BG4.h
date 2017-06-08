/*
  PokeMini - Pok�mon-Mini Emulator
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

#ifndef POKEMINI_BG_X4
#define POKEMINI_BG_X4

#include <stdint.h>

// PokeMini Background Image
// 384 x 256 (4x4) - 4bpp (LSn Left pixel)
extern const uint8_t PokeMini_BG4[];

// PokeMini Background Palette (RGBX8888)
extern const uint32_t PokeMini_BG4_PalRGB32[];

// PokeMini Background Palette (BGRX8888)
extern const uint32_t PokeMini_BG4_PalBGR32[];

// PokeMini Background Palette (RGB565)
extern const uint16_t PokeMini_BG4_PalRGB16[];

// PokeMini Background Palette (BGR565)
extern const uint16_t PokeMini_BG4_PalBGR16[];

// PokeMini Background Palette (RGB555)
extern const uint16_t PokeMini_BG4_PalRGB15[];

#endif
