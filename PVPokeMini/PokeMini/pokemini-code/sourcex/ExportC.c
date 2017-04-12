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
#include "ExportC.h"

// Open file
FILE_EC *Open_ExportC(const char *filename, const char *header)
{
	FILE_EC *fec;
	FILE *fo;

	// Open file
	fo = fopen(filename, "wb");
	if (fo == NULL) return NULL;
	fec = (FILE_EC *)malloc(sizeof(FILE_EC));
	fec->fo = fo;
	fec->offset = 0;
	fec->perline = 16;
	fec->next = 0;

	// Write file header
	if (header) fprintf(fo, "%s\n", header);

	return fec;
}

// Begin new variable
void Begin_ExportC(FILE_EC *fec, const char *type, const char *name, int perline)
{
	if (!fec) return;
	if (perline <= 0) perline = 8;

	fprintf(fec->fo, "\n%s %s[] = {\n", type, name);
	fec->offset = 0;
	fec->perline = perline;
	fec->next = 0;
}

// End current variable
void End_ExportC(FILE_EC *fec)
{
	if (!fec) return;

	fprintf(fec->fo, "\n};\n");
	fec->offset = 0;
	fec->next = 0;
}

// Write 8-bits into the file
void Write8B_ExportC(FILE_EC *fec, uint8_t val)
{
	if (!fec) return;

	if (fec->offset == 0) {
		// First item
		if (fec->next) fprintf(fec->fo, ",\n");
		fprintf(fec->fo, "\t0x%02X", (int)val);
		fec->offset++;
	} else if (fec->offset >= (fec->perline-1)) {
		// Last item
		fprintf(fec->fo, ",0x%02X", (int)val);
		fec->offset = 0;
		fec->next = 1;
	} else {
		// Middle item
		fprintf(fec->fo, ",0x%02X", (int)val);
		fec->offset++;
	}
}

// Write 16-bits into the file
void Write16B_ExportC(FILE_EC *fec, uint16_t val)
{
	if (!fec) return;

	if (fec->offset == 0) {
		// First item
		if (fec->next) fprintf(fec->fo, ",\n");
		fprintf(fec->fo, "\t0x%04X", (int)val);
		fec->offset++;
	} else if (fec->offset >= (fec->perline-1)) {
		// Last item
		fprintf(fec->fo, ",0x%04X", (int)val);
		fec->offset = 0;
		fec->next = 1;
	} else {
		// Middle item
		fprintf(fec->fo, ",0x%04X", (int)val);
		fec->offset++;
	}
}

// Write 32-bits into the file
void Write32B_ExportC(FILE_EC *fec, uint32_t val)
{
	if (!fec) return;

	if (fec->offset == 0) {
		// First item
		if (fec->next) fprintf(fec->fo, ",\n");
		fprintf(fec->fo, "\t0x%08X", (int)val);
		fec->offset++;
	} else if (fec->offset >= (fec->perline-1)) {
		// Last item
		fprintf(fec->fo, ",0x%08X", (int)val);
		fec->offset = 0;
		fec->next = 1;
	} else {
		// Middle item
		fprintf(fec->fo, ",0x%08X", (int)val);
		fec->offset++;
	}
}

// Write variable into the file
void WriteStr_ExportC(FILE_EC *fec, const char *s, const char *cast)
{
	if (!fec) return;

	if (fec->offset == 0) {
		// First item
		if (fec->next) fprintf(fec->fo, ",\n");
		if (cast) fprintf(fec->fo, "\t(%s)%s", cast, s);
		else fprintf(fec->fo, "\t%s", s);
		fec->offset++;
	} else if (fec->offset >= (fec->perline-1)) {
		// Last item
		if (cast) fprintf(fec->fo, ",(%s)%s", cast, s);
		else fprintf(fec->fo, ",%s", s);
		fec->offset = 0;
		fec->next = 1;
	} else {
		// Middle item
		if (cast) fprintf(fec->fo, ",(%s)%s", cast, s);
		else fprintf(fec->fo, ",%s", s);
		fec->offset++;
	}
}

// Close file
void Close_ExportC(FILE_EC *fec)
{
	if (fec) {
		fclose(fec->fo);
		free(fec);
	}
}
