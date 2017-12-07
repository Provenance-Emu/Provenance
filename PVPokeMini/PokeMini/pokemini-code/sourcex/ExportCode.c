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
#include <stdarg.h>
#include "ExportCode.h"
#include "ExportASM.h"
#include "ExportC.h"

FILE_ECODE *Open_ExportCode(int format, const char *filename)
{
	FILE_ECODE *fec;

	fec = (FILE_ECODE *)malloc(sizeof(FILE_ECODE));
	if (!fec) return NULL;
	fec->format = format;

	if (format == FILE_ECODE_RAW) {
		fec->foptr = (void *)fopen(filename, "wb");
	} else if (format == FILE_ECODE_ASM) {
		fec->foptr = (void *)Open_ExportASM(filename, NULL);
	} else if (format == FILE_ECODE_C) {
		fec->foptr = (void *)Open_ExportC(filename, NULL);
	}

	if (!fec->foptr) {
		free(fec);
		return NULL;
	}

	return fec;
}

void Comment_ExportCode(FILE_ECODE *fec, const char *fmt, ...)
{
	va_list args;
	FILE *fo = NULL;
	if (!fec) return;

	va_start(args, fmt);
	if (fec->format == FILE_ECODE_RAW) {
		return;
	} else if (fec->format == FILE_ECODE_ASM) {
		fo = ((FILE_EASM *)fec->foptr)->fo;
		fprintf(fo, "; ");
	} else if (fec->format == FILE_ECODE_C) {
		fo = ((FILE_EC *)fec->foptr)->fo;
		fprintf(fo, "// ");
	}
	vfprintf(fo, fmt, args);
	fprintf(fo, "\n");
	va_end(args);
}

void PrintASM_ExportCode(FILE_ECODE *fec, const char *fmt, ...)
{
	va_list args;
	FILE *fo = NULL;
	if (!fec) return;

	va_start(args, fmt);
	if (fec->format == FILE_ECODE_RAW) {
		return;
	} else if (fec->format == FILE_ECODE_ASM) {
		fo = ((FILE_EASM *)fec->foptr)->fo;
	} else if (fec->format == FILE_ECODE_C) {
		return;
	}
	vfprintf(fo, fmt, args);
	fprintf(fo, "\n");
	va_end(args);
}

void PrintC_ExportCode(FILE_ECODE *fec, const char *fmt, ...)
{
	va_list args;
	FILE *fo = NULL;
	if (!fec) return;

	va_start(args, fmt);
	if (fec->format == FILE_ECODE_RAW) {
		return;
	} else if (fec->format == FILE_ECODE_ASM) {
		return;
	} else if (fec->format == FILE_ECODE_C) {
		fo = ((FILE_EC *)fec->foptr)->fo;
	}
	vfprintf(fo, fmt, args);
	fprintf(fo, "\n");
	va_end(args);
}

int BlockOpen_ExportCode(FILE_ECODE *fec, int bits, const char *varname)
{
	if (!fec) return 0;
	
	fec->blockbits = bits;
	if (fec->format == FILE_ECODE_RAW) {
		return 1;
	} else if (fec->format == FILE_ECODE_ASM) {
		if (fec->blockbits == FILE_ECODE_8BITS) Begin_ExportASM((FILE_EASM *)fec->foptr, FILE_EASM_8BITS, varname, 16);
		if (fec->blockbits == FILE_ECODE_16BITS) Begin_ExportASM((FILE_EASM *)fec->foptr, FILE_EASM_16BITS, varname, 8);
		if (fec->blockbits == FILE_ECODE_32BITS) Begin_ExportASM((FILE_EASM *)fec->foptr, FILE_EASM_32BITS, varname, 4);
		return 1;
	} else if (fec->format == FILE_ECODE_C) {
		if (fec->blockbits == FILE_ECODE_8BITS) Begin_ExportC((FILE_EC *)fec->foptr, "const unsigned char", varname, 16);
		if (fec->blockbits == FILE_ECODE_16BITS) Begin_ExportC((FILE_EC *)fec->foptr, "const unsigned short", varname, 8);
		if (fec->blockbits == FILE_ECODE_32BITS) Begin_ExportC((FILE_EC *)fec->foptr, "const unsigned long", varname, 4);
		return 1;
	}

	return 0;
}

int BlockWrite_ExportCode(FILE_ECODE *fec, int data)
{
	if (!fec) return 0;

	data = Endian32(data);
	if (fec->format == FILE_ECODE_RAW) {
		if (fec->blockbits == FILE_ECODE_8BITS) fwrite(&data, 1, 1, (FILE *)fec->foptr);
		if (fec->blockbits == FILE_ECODE_16BITS) fwrite(&data, 1, 2, (FILE *)fec->foptr);
		if (fec->blockbits == FILE_ECODE_32BITS) fwrite(&data, 1, 4, (FILE *)fec->foptr);
		return 1;
	} else if (fec->format == FILE_ECODE_ASM) {
		if (fec->blockbits == FILE_ECODE_8BITS) Write8B_ExportASM((FILE_EASM *)fec->foptr, data);
		if (fec->blockbits == FILE_ECODE_16BITS) Write16B_ExportASM((FILE_EASM *)fec->foptr, data);
		if (fec->blockbits == FILE_ECODE_32BITS) Write32B_ExportASM((FILE_EASM *)fec->foptr, data);
		return 1;
	} else if (fec->format == FILE_ECODE_C) {
		if (fec->blockbits == FILE_ECODE_8BITS) Write8B_ExportC((FILE_EC *)fec->foptr, data);
		if (fec->blockbits == FILE_ECODE_16BITS) Write16B_ExportC((FILE_EC *)fec->foptr, data);
		if (fec->blockbits == FILE_ECODE_32BITS) Write32B_ExportC((FILE_EC *)fec->foptr, data);
		return 1;
	}

	return 0;
}

int BlockVarWrite_ExportCode(FILE_ECODE *fec, const char *varname)
{
	FILE *fo = NULL;
	if (!fec) return 0;

	if (fec->format == FILE_ECODE_RAW) {
		return 0;
	} else if (fec->format == FILE_ECODE_ASM) {
		fo = ((FILE_EASM *)fec->foptr)->fo;
		if (fec->blockbits == FILE_ECODE_8BITS) fprintf(fo, "\t.db %s\n", varname);
		if (fec->blockbits == FILE_ECODE_16BITS) fprintf(fo, "\t.dw %s\n", varname);
		if (fec->blockbits == FILE_ECODE_32BITS) fprintf(fo, "\t.dd %s\n", varname);
		return 1;
	} else if (fec->format == FILE_ECODE_C) {
		if (fec->blockbits == FILE_ECODE_8BITS) WriteStr_ExportC((FILE_EC *)fec->foptr, varname, "unsigned char");
		if (fec->blockbits == FILE_ECODE_16BITS) WriteStr_ExportC((FILE_EC *)fec->foptr, varname, "unsigned short");
		if (fec->blockbits == FILE_ECODE_32BITS) WriteStr_ExportC((FILE_EC *)fec->foptr, varname, "unsigned long");
		return 1;
	}

	return 0;
}

int BlockClose_ExportCode(FILE_ECODE *fec)
{
	if (!fec) return 0;

	if (fec->format == FILE_ECODE_RAW) {
		return 1;
	} else if (fec->format == FILE_ECODE_ASM) {
		End_ExportASM((FILE_EASM *)fec->foptr);
		return 1;
	} else if (fec->format == FILE_ECODE_C) {
		End_ExportC((FILE_EC *)fec->foptr);
		return 1;
	}

	return 0;
}

int WriteArray_ExportCode(FILE_ECODE *fec, int bits, const char *varname, void *data, int bytes)
{
	uint8_t *data8 = (uint8_t *)data;
	uint16_t *data16 = (uint16_t *)data;
	uint32_t *data32 = (uint32_t *)data;
	int i;

	if (!fec) return 0;

	if (fec->format == FILE_ECODE_RAW) {
		fwrite(data, 1, bytes, (FILE *)fec->foptr);
		return 1;
	} else if (fec->format == FILE_ECODE_ASM) {
		if (bits == FILE_ECODE_8BITS) {
			Begin_ExportASM((FILE_EASM *)fec->foptr, FILE_EASM_8BITS, varname, 16);
			for (i=0; i<bytes; i++) Write8B_ExportASM((FILE_EASM *)fec->foptr, data8[i]);
		}
		if (bits == FILE_ECODE_16BITS) {
			Begin_ExportASM((FILE_EASM *)fec->foptr, FILE_EASM_16BITS, varname, 8);
			for (i=0; i<(bytes>>1); i++) Write16B_ExportASM((FILE_EASM *)fec->foptr, data16[i]);
		}
		if (bits == FILE_ECODE_32BITS) {
			Begin_ExportASM((FILE_EASM *)fec->foptr, FILE_EASM_32BITS, varname, 4);
			for (i=0; i<(bytes>>2); i++) Write32B_ExportASM((FILE_EASM *)fec->foptr, data32[i]);
		}
		End_ExportASM((FILE_EASM *)fec->foptr);
		return 1;
	} else if (fec->format == FILE_ECODE_C) {
		if (bits == FILE_ECODE_8BITS) {
			Begin_ExportC((FILE_EC *)fec->foptr, "const unsigned char", varname, 16);
			for (i=0; i<bytes; i++) Write8B_ExportC((FILE_EC *)fec->foptr, data8[i]);
		}
		if (bits == FILE_ECODE_16BITS) {
			Begin_ExportC((FILE_EC *)fec->foptr, "const unsigned short", varname, 8);
			for (i=0; i<(bytes>>1); i++) Write16B_ExportC((FILE_EC *)fec->foptr, data16[i]);
		}
		if (bits == FILE_ECODE_32BITS) {
			Begin_ExportC((FILE_EC *)fec->foptr, "const unsigned long", varname, 4);
			for (i=0; i<(bytes>>2); i++) Write32B_ExportC((FILE_EC *)fec->foptr, data32[i]);
		}
		End_ExportC((FILE_EC *)fec->foptr);
		return 1;
	}

	return 0;
}

void Close_ExportCode(FILE_ECODE *fec)
{
	if (fec) {
		if (fec->format == FILE_ECODE_RAW) {
			if (fec->foptr) fclose((FILE *)fec->foptr);
		} else if (fec->format == FILE_ECODE_ASM) {
			if (fec->foptr) Close_ExportASM((FILE_EASM *)fec->foptr);
		} else if (fec->format == FILE_ECODE_C) {
			if (fec->foptr) Close_ExportC((FILE_EC *)fec->foptr);
		}
		fec->foptr = NULL;
	}
}
