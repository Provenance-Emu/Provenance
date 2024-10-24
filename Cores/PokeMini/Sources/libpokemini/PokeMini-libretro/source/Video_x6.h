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

#ifndef POKEMINI_VIDEO_X6
#define POKEMINI_VIDEO_X6

#include <stdint.h>

// Video specs
extern const TPokeMini_VideoSpec PokeMini_Video6x6;

// Return the best blitter
TPokeMini_DrawVideo32 PokeMini_GetVideo6x6_32(int filter, int lcdmode);
TPokeMini_DrawVideo16 PokeMini_GetVideo6x6_16(int filter, int lcdmode);

// Render to 576x384, analog + scanline
void PokeMini_VideoAScanLine6x6_32(uint32_t *screen, int pitchW);
void PokeMini_VideoAScanLine6x6_16(uint16_t *screen, int pitchW);

// Render to 576x384, 3-colors + scanline
void PokeMini_Video3ScanLine6x6_32(uint32_t *screen, int pitchW);
void PokeMini_Video3ScanLine6x6_16(uint16_t *screen, int pitchW);

// Render to 576x384, 2-colors + scanline
void PokeMini_Video2ScanLine6x6_32(uint32_t *screen, int pitchW);
void PokeMini_Video2ScanLine6x6_16(uint16_t *screen, int pitchW);

// Render to 576x384, analog + dot matrix
void PokeMini_VideoAMatrix6x6_32(uint32_t *screen, int pitchW);
void PokeMini_VideoAMatrix6x6_16(uint16_t *screen, int pitchW);

// Render to 576x384, 3-colors + dot matrix
void PokeMini_Video3Matrix6x6_32(uint32_t *screen, int pitchW);
void PokeMini_Video3Matrix6x6_16(uint16_t *screen, int pitchW);

// Render to 576x384, 2-colors + dot matrix
void PokeMini_Video2Matrix6x6_32(uint32_t *screen, int pitchW);
void PokeMini_Video2Matrix6x6_16(uint16_t *screen, int pitchW);

// Render to 576x384, analog
void PokeMini_VideoANone6x6_32(uint32_t *screen, int pitchW);
void PokeMini_VideoANone6x6_16(uint16_t *screen, int pitchW);

// Render to 576x384, 3-colors
void PokeMini_Video3None6x6_32(uint32_t *screen, int pitchW);
void PokeMini_Video3None6x6_16(uint16_t *screen, int pitchW);

// Render to 576x384, 2-colors
void PokeMini_Video2None6x6_32(uint32_t *screen, int pitchW);
void PokeMini_Video2None6x6_16(uint16_t *screen, int pitchW);

// Render to 576x384, unofficial colors
void PokeMini_VideoColor6x6_32(uint32_t *screen, int pitchW);
void PokeMini_VideoColor6x6_16(uint16_t *screen, int pitchW);
void PokeMini_VideoColorL6x6_32(uint32_t *screen, int pitchW);
void PokeMini_VideoColorL6x6_16(uint16_t *screen, int pitchW);
void PokeMini_VideoColorH6x6_32(uint32_t *screen, int pitchW);
void PokeMini_VideoColorH6x6_16(uint16_t *screen, int pitchW);

#endif
