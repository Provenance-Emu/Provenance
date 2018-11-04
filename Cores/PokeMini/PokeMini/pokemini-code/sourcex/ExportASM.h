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

#ifndef EXPORTASM_H
#define EXPORTASM_H

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include "Endianess.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
	FILE *fo;
	int type;
	int offset;
	int perline;
	int next;
} FILE_EASM;

enum {
	FILE_EASM_NONE,
	FILE_EASM_8BITS,
	FILE_EASM_16BITS,
	FILE_EASM_32BITS,
	FILE_EASM_EOE
};

FILE_EASM *Open_ExportASM(const char *filename, const char *header);
int Begin_ExportASM(FILE_EASM *fec, int type, const char *name, int perline);
void End_ExportASM(FILE_EASM *fec);
int Write8B_ExportASM(FILE_EASM *fec, uint8_t val);
int Write16B_ExportASM(FILE_EASM *fec, uint16_t val);
int Write32B_ExportASM(FILE_EASM *fec, uint32_t val);
void Close_ExportASM(FILE_EASM *fec);

#ifdef __cplusplus
}
#endif

#endif
