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

#ifndef EXPORTCODE_H
#define EXPORTCODE_H

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdarg.h>
#include "Endianess.h"

#ifdef __cplusplus
extern "C" {
#endif

enum {
	FILE_ECODE_RAW,
	FILE_ECODE_ASM,
	FILE_ECODE_C
};

enum {
	FILE_ECODE_8BITS,
	FILE_ECODE_16BITS,
	FILE_ECODE_32BITS
};

typedef struct {
	void *foptr;
	int format;
	int blockbits;
} FILE_ECODE;

FILE_ECODE *Open_ExportCode(int format, const char *filename);
void Comment_ExportCode(FILE_ECODE *fec, const char *fmt, ...);
void PrintASM_ExportCode(FILE_ECODE *fec, const char *fmt, ...);
void PrintC_ExportCode(FILE_ECODE *fec, const char *fmt, ...);
int WriteArray_ExportCode(FILE_ECODE *fec, int bits, const char *varname, void *data, int bytes);
int BlockOpen_ExportCode(FILE_ECODE *fec, int bits, const char *varname);
int BlockWrite_ExportCode(FILE_ECODE *fec, int data);
int BlockVarWrite_ExportCode(FILE_ECODE *fec, const char *varname);
int BlockClose_ExportCode(FILE_ECODE *fec);
void Close_ExportCode(FILE_ECODE *fec);

#ifdef __cplusplus
}
#endif

#endif
