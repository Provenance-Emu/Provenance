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

#ifndef EXPORTBMP_H
#define EXPORTBMP_H

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include "Endianess.h"

#ifdef __cplusplus
extern "C" {
#endif

FILE *OpenUnique_ExportBMP(int *choosennumber, int width, int height);
FILE *Open_ExportBMP(const char *filename, int width, int height);
void WritePixel_ExportBMP(FILE *fo, uint32_t BGR);
void WriteArray_ExportBMP(FILE *fo, uint32_t *BGR, int pixels);
void Close_ExportBMP(FILE *fo);

#ifdef __cplusplus
}
#endif

#endif
