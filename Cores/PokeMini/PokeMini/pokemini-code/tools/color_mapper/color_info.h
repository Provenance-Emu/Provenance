/*
  PokeMini Color Mapper
  Copyright (C) 2011-2012  JustBurn

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

#ifndef COLORINFO_H
#define COLORINFO_H

#include <stdint.h>

extern unsigned char *PM_ROM;			// Pokemon-Mini ROM
extern int PM_ROM_FSize;			// Pokemon-Mini ROM File Size
extern int PM_ROM_SSize;			// Pokemon-Mini ROM Safe Size

extern unsigned char *PRCColorUMap;		// Uncompressed map
extern uint32_t PRCColorUBytes;		// Size of uncompressed map in bytes
extern uint32_t PRCColorUTiles;		// Number of maximum tiles
extern uint32_t PRCColorBytesPerTile;	// Number of bytes per tile
extern int PRCColorFormat;			// Color format
extern int PRCColorFlags;			// Color flags

extern uint32_t PRCColorCOffset;		// Compress: Offset
extern uint32_t PRCColorCTiles;		// Compress: Number of tiles

extern const uint8_t PRCStaticColorMap[8];	// Static Color Map

void FreeColorInfo();

int LoadMIN(char *filename);

void ResetColorInfo();

int NewColorInfo(int type);

int CompressColorInfo(uint32_t *offset, uint32_t *tiles);

int Convert8x8to4x4();

int Convert4x4to8x8();

int LoadColorInfo(char *filename);

int SaveColorInfo(char *filename);

int GetColorData(uint8_t *dst, int tileoff, int tiles);

int SetColorData(uint8_t *src, int tileoff, int tiles);

int FillColorData(int tileoff, int tiles, int color_off, int color_on);

#endif
