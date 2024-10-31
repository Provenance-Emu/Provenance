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

#ifndef POKEMINI_FONT12
#define POKEMINI_FONT12

#include <stdint.h>

// PokeMini Font Data
// 128 Chars, 192 x 96 - 4bpp
extern const uint8_t PokeMini_Font12[];

// PokeMini Font Palette (RGBX8888)
extern const uint32_t PokeMini_Font12_PalRGB32[];

// PokeMini Font Palette (BGRX8888)
extern const uint32_t PokeMini_Font12_PalBGR32[];

// PokeMini Font Palette (RGB565)
extern const uint16_t PokeMini_Font12_PalRGB16[];

// PokeMini Font Palette (BGR565)
extern const uint16_t PokeMini_Font12_PalBGR16[];

// PokeMini Font Palette (RGB555)
extern const uint16_t PokeMini_Font12_PalRGB15[];

// PokeMini Title Font Palette (RGBX8888)
extern const uint32_t PokeMini_TFont12_PalRGB32[];

// PokeMini Title Font Palette (BGRX8888)
extern const uint32_t PokeMini_TFont12_PalBGR32[];

// PokeMini Title Font Palette (RGB565)
extern const uint16_t PokeMini_TFont12_PalRGB16[];

// PokeMini Title Font Palette (BGR565)
extern const uint16_t PokeMini_TFont12_PalBGR16[];

// PokeMini Title Font Palette (RGB555)
extern const uint16_t PokeMini_TFont12_PalRGB15[];

#endif
