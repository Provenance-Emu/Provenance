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

#ifndef POKEMINI_COLORPAL
#define POKEMINI_COLORPAL

#include <stdint.h>

// PokeMini Unofficial Color Palette (RGBX8888)
extern const uint32_t PokeMini_ColorPalRGB32[];

// PokeMini Unofficial Color Palette (BGRX8888)
extern const uint32_t PokeMini_ColorPalBGR32[];

// PokeMini Unofficial Color Palette (RGB565)
extern const uint16_t PokeMini_ColorPalRGB16[];

// PokeMini Unofficial Color Palette (BGR565)
extern const uint16_t PokeMini_ColorPalBGR16[];

// PokeMini Unofficial Color Palette (RGB555)
extern const uint16_t PokeMini_ColorPalRGB15[];

#endif
