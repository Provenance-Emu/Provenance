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

#ifndef EXPORTC_H
#define EXPORTC_H

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include "Endianess.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
	FILE *fo;
	int offset;
	int perline;
	int next;
} FILE_EC;

FILE_EC *Open_ExportC(const char *filename, const char *header);
void Begin_ExportC(FILE_EC *fec, const char *type, const char *name, int perline);
void End_ExportC(FILE_EC *fec);
void Write8B_ExportC(FILE_EC *fec, uint8_t val);
void Write16B_ExportC(FILE_EC *fec, uint16_t val);
void Write32B_ExportC(FILE_EC *fec, uint32_t val);
void WriteStr_ExportC(FILE_EC *fec, const char *s, const char *cast);
void Close_ExportC(FILE_EC *fec);

#ifdef __cplusplus
}
#endif

#endif
