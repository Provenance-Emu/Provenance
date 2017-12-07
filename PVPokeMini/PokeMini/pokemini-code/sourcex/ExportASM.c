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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "ExportASM.h"

// Open file
FILE_EASM *Open_ExportASM(const char *filename, const char *header)
{
	FILE_EASM *fec;
	FILE *fo;

	// Open file
	fo = fopen(filename, "wb");
	if (fo == NULL) return NULL;
	fec = (FILE_EASM *)malloc(sizeof(FILE_EASM));
	fec->fo = fo;
	fec->type = FILE_EASM_NONE;
	fec->offset = 0;
	fec->perline = 16;
	fec->next = 0;

	// Write file header
	if (header) fprintf(fo, "%s\n", header);

	return fec;
}

// Begin new variable
int Begin_ExportASM(FILE_EASM *fec, int type, const char *name, int perline)
{
	if (!fec) return 0;
	if ((type < 0) || (type >= FILE_EASM_EOE)) return 0;
	if (perline <= 0) perline = 8;

	if (name && strlen(name)) fprintf(fec->fo, "\n%s:\n", name);
	else fprintf(fec->fo, "\n");
	fec->type = type;
	fec->offset = 0;
	fec->perline = perline;
	fec->next = 0;

	return 1;
}

// End current variable
void End_ExportASM(FILE_EASM *fec)
{
	if (!fec) return;

	fprintf(fec->fo, "\n");
	fec->type = FILE_EASM_NONE;
	fec->offset = 0;
	fec->next = 0;
}

// Write 8-bits into the file
int Write8B_ExportASM(FILE_EASM *fec, uint8_t val)
{
	if (!fec) return 0;
	if (fec->type != FILE_EASM_8BITS) return 0;

	if (fec->offset == 0) {
		// First item
		if (fec->next) fprintf(fec->fo, "\n");
		fprintf(fec->fo, "\t.db $%02X", (int)val);
		fec->offset++;
	} else if (fec->offset >= (fec->perline-1)) {
		// Last item
		fprintf(fec->fo, ",$%02X", (int)val);
		fec->offset = 0;
		fec->next = 1;
	} else {
		// Middle item
		fprintf(fec->fo, ",$%02X", (int)val);
		fec->offset++;
	}

	return 1;
}

// Write 16-bits into the file
int Write16B_ExportASM(FILE_EASM *fec, uint16_t val)
{
	if (!fec) return 0;
	if (fec->type != FILE_EASM_16BITS) return 0;

	if (fec->offset == 0) {
		// First item
		if (fec->next) fprintf(fec->fo, "\n");
		fprintf(fec->fo, "\t.dw $%04X", (int)val);
		fec->offset++;
	} else if (fec->offset >= (fec->perline-1)) {
		// Last item
		fprintf(fec->fo, ",$%04X", (int)val);
		fec->offset = 0;
		fec->next = 1;
	} else {
		// Middle item
		fprintf(fec->fo, ",$%04X", (int)val);
		fec->offset++;
	}

	return 1;
}

// Write 32-bits into the file
int Write32B_ExportASM(FILE_EASM *fec, uint32_t val)
{
	if (!fec) return 0;
	if (fec->type != FILE_EASM_32BITS) return 0;

	if (fec->offset == 0) {
		// First item
		if (fec->next) fprintf(fec->fo, ",\n");
		fprintf(fec->fo, "\t.dd $%08X", (int)val);
		fec->offset++;
	} else if (fec->offset >= (fec->perline-1)) {
		// Last item
		fprintf(fec->fo, ",$%08X", (int)val);
		fec->offset = 0;
		fec->next = 1;
	} else {
		// Middle item
		fprintf(fec->fo, ",$%08X", (int)val);
		fec->offset++;
	}

	return 1;
}

// Close file
void Close_ExportASM(FILE_EASM *fec)
{
	if (fec) {
		fclose(fec->fo);
		free(fec);
	}
}
