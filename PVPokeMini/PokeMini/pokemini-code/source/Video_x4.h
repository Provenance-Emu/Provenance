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

#ifndef POKEMINI_VIDEO_X4
#define POKEMINI_VIDEO_X4

#include <stdint.h>

// Video specs
extern const TPokeMini_VideoSpec PokeMini_Video4x4;

// Return the best blitter
TPokeMini_DrawVideo32 PokeMini_GetVideo4x4_32(int filter, int lcdmode);
TPokeMini_DrawVideo16 PokeMini_GetVideo4x4_16(int filter, int lcdmode);

// Render to 384x256, analog + scanline
void PokeMini_VideoAScanLine4x4_32(uint32_t *screen, int pitchW);
void PokeMini_VideoAScanLine4x4_16(uint16_t *screen, int pitchW);

// Render to 384x256, 3-colors + scanline
void PokeMini_Video3ScanLine4x4_32(uint32_t *screen, int pitchW);
void PokeMini_Video3ScanLine4x4_16(uint16_t *screen, int pitchW);

// Render to 384x256, 2-colors + scanline
void PokeMini_Video2ScanLine4x4_32(uint32_t *screen, int pitchW);
void PokeMini_Video2ScanLine4x4_16(uint16_t *screen, int pitchW);

// Render to 384x256, analog + dot matrix
void PokeMini_VideoAMatrix4x4_32(uint32_t *screen, int pitchW);
void PokeMini_VideoAMatrix4x4_16(uint16_t *screen, int pitchW);

// Render to 384x256, 3-colors + dot matrix
void PokeMini_Video3Matrix4x4_32(uint32_t *screen, int pitchW);
void PokeMini_Video3Matrix4x4_16(uint16_t *screen, int pitchW);

// Render to 384x256, 2-colors + dot matrix
void PokeMini_Video2Matrix4x4_32(uint32_t *screen, int pitchW);
void PokeMini_Video2Matrix4x4_16(uint16_t *screen, int pitchW);

// Render to 384x256, analog
void PokeMini_VideoANone4x4_32(uint32_t *screen, int pitchW);
void PokeMini_VideoANone4x4_16(uint16_t *screen, int pitchW);

// Render to 384x256, 3-colors
void PokeMini_Video3None4x4_32(uint32_t *screen, int pitchW);
void PokeMini_Video3None4x4_16(uint16_t *screen, int pitchW);

// Render to 384x256, 2-colors
void PokeMini_Video2None4x4_32(uint32_t *screen, int pitchW);
void PokeMini_Video2None4x4_16(uint16_t *screen, int pitchW);

// Render to 384x256, unofficial colors
void PokeMini_VideoColor4x4_32(uint32_t *screen, int pitchW);
void PokeMini_VideoColor4x4_16(uint16_t *screen, int pitchW);
void PokeMini_VideoColorL4x4_32(uint32_t *screen, int pitchW);
void PokeMini_VideoColorL4x4_16(uint16_t *screen, int pitchW);
void PokeMini_VideoColorH4x4_32(uint32_t *screen, int pitchW);
void PokeMini_VideoColorH4x4_16(uint16_t *screen, int pitchW);

#endif
