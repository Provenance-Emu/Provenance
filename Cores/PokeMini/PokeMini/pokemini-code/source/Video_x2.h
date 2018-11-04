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

#ifndef POKEMINI_VIDEO_X2
#define POKEMINI_VIDEO_X2

#include <stdint.h>

// Video specs
extern const TPokeMini_VideoSpec PokeMini_Video2x2;
extern const TPokeMini_VideoSpec PokeMini_Video2x2_NDS;	// For NDS

// Return the best blitter
TPokeMini_DrawVideo32 PokeMini_GetVideo2x2_32(int filter, int lcdmode);
TPokeMini_DrawVideo16 PokeMini_GetVideo2x2_16(int filter, int lcdmode);
TPokeMini_DrawVideo16 PokeMini_GetVideo2x2_8P(int filter, int lcdmode);

// Render to 192x128, analog + scanline
void PokeMini_VideoAScanLine2x2_32(uint32_t *screen, int pitchW);
void PokeMini_VideoAScanLine2x2_16(uint16_t *screen, int pitchW);
void PokeMini_VideoAScanLine2x2_8P(uint16_t *screen, int pitchW);

// Render to 192x128, 3-colors + scanline
void PokeMini_Video3ScanLine2x2_32(uint32_t *screen, int pitchW);
void PokeMini_Video3ScanLine2x2_16(uint16_t *screen, int pitchW);
void PokeMini_Video3ScanLine2x2_8P(uint16_t *screen, int pitchW);

// Render to 192x128, 2-colors + scanline
void PokeMini_Video2ScanLine2x2_32(uint32_t *screen, int pitchW);
void PokeMini_Video2ScanLine2x2_16(uint16_t *screen, int pitchW);
void PokeMini_Video2ScanLine2x2_8P(uint16_t *screen, int pitchW);

// Render to 192x128, analog + dot matrix
void PokeMini_VideoAMatrix2x2_32(uint32_t *screen, int pitchW);
void PokeMini_VideoAMatrix2x2_16(uint16_t *screen, int pitchW);
void PokeMini_VideoAMatrix2x2_8P(uint16_t *screen, int pitchW);

// Render to 192x128, 3-colors + dot matrix
void PokeMini_Video3Matrix2x2_32(uint32_t *screen, int pitchW);
void PokeMini_Video3Matrix2x2_16(uint16_t *screen, int pitchW);
void PokeMini_Video3Matrix2x2_8P(uint16_t *screen, int pitchW);

// Render to 192x128, 2-colors + dot matrix
void PokeMini_Video2Matrix2x2_32(uint32_t *screen, int pitchW);
void PokeMini_Video2Matrix2x2_16(uint16_t *screen, int pitchW);
void PokeMini_Video2Matrix2x2_8P(uint16_t *screen, int pitchW);

// Render to 192x128, analog
void PokeMini_VideoANone2x2_32(uint32_t *screen, int pitchW);
void PokeMini_VideoANone2x2_16(uint16_t *screen, int pitchW);
void PokeMini_VideoANone2x2_8P(uint16_t *screen, int pitchW);

// Render to 192x128, 3-colors
void PokeMini_Video3None2x2_32(uint32_t *screen, int pitchW);
void PokeMini_Video3None2x2_16(uint16_t *screen, int pitchW);
void PokeMini_Video3None2x2_8P(uint16_t *screen, int pitchW);

// Render to 192x128, 2-colors
void PokeMini_Video2None2x2_32(uint32_t *screen, int pitchW);
void PokeMini_Video2None2x2_16(uint16_t *screen, int pitchW);
void PokeMini_Video2None2x2_8P(uint16_t *screen, int pitchW);

// Render to 192x128, unofficial colors
void PokeMini_VideoColor2x2_32(uint32_t *screen, int pitchW);
void PokeMini_VideoColor2x2_16(uint16_t *screen, int pitchW);
void PokeMini_VideoColor2x2_8P(uint16_t *screen, int pitchW);
void PokeMini_VideoColorL2x2_32(uint32_t *screen, int pitchW);
void PokeMini_VideoColorL2x2_16(uint16_t *screen, int pitchW);
void PokeMini_VideoColorL2x2_8P(uint16_t *screen, int pitchW);
void PokeMini_VideoColorH2x2_32(uint32_t *screen, int pitchW);
void PokeMini_VideoColorH2x2_16(uint16_t *screen, int pitchW);

#endif
