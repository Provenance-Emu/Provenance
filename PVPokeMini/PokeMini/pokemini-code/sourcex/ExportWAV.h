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

#ifndef EXPORTWAV_H
#define EXPORTWAV_H

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include "Endianess.h"

#ifdef __cplusplus
extern "C" {
#endif

enum {
	// Frequency
	EXPORTWAV_11KHZ = (0<<0),
	EXPORTWAV_22KHZ = (1<<0),
	EXPORTWAV_44KHZ = (2<<0),
	EXPORTWAV_MASK = (3<<0),
	// Channels
	EXPORTWAV_MONO = (0<<2),
	EXPORTWAV_STEREO = (1<<2),
	// Bit format
	EXPORTWAV_8BITS = (0<<3),
	EXPORTWAV_16BITS = (1<<3),
};

FILE *OpenUnique_ExportWAV(uint8_t format);
FILE *Open_ExportWAV(const char *filename, uint8_t format);
void WriteU8_ExportWAV(FILE *fo, uint8_t sample);
void WriteS16_ExportWAV(FILE *fo, int16_t sample);
void WriteU8A_ExportWAV(FILE *fo, uint8_t *samples, int len);
void WriteS16A_ExportWAV(FILE *fo, int16_t *samples, int len);
void Close_ExportWAV(FILE *fo);

#ifdef __cplusplus
}
#endif

#endif
