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

#include "ExportBMP.h"

// Open a unique files
FILE *OpenUnique_ExportBMP(int *choosennumber, int width, int height)
{
	int i;
	char file[32];
	FILE *ft;
	for (i=0; i<16777216; i++) {
		sprintf(file, "snap_%03d.bmp", i);
		ft = fopen(file, "r");
		if (!ft) break;
		fclose(ft);
	}
	if (choosennumber) *choosennumber = i;
	return Open_ExportBMP(file, width, height);
}

// Open file
FILE *Open_ExportBMP(const char *filename, int width, int height)
{
	uint32_t tl;
	uint16_t tw;
	FILE *fo;
	fo = fopen(filename, "wb");
	if (fo == NULL) return NULL;

	// Write file header
	tw = Endian16(('M' << 8) | 'B');
	fwrite(&tw, 2, 1, fo);
	tl = Endian32(14 + 40 + (width * height * 3));
	fwrite(&tl, 4, 1, fo);
	tl = 0;
	fwrite(&tl, 4, 1, fo);
	tl = Endian32(14 + 40);
	fwrite(&tl, 4, 1, fo);

	// Write info header
	tl = Endian32(40);
	fwrite(&tl, 4, 1, fo);
	tl = Endian32(width);
	fwrite(&tl, 4, 1, fo);
	tl = Endian32(height);
	fwrite(&tl, 4, 1, fo);
	tw = Endian16(1);
	fwrite(&tw, 2, 1, fo);
	tw = Endian16(24);
	fwrite(&tw, 2, 1, fo);
	tl = 0;
	fwrite(&tl, 4, 1, fo);
	tl = 0;
	fwrite(&tl, 4, 1, fo);
	tl = Endian32(92);
	fwrite(&tl, 4, 1, fo);
	tl = Endian32(92);
	fwrite(&tl, 4, 1, fo);
	tl = 0;
	fwrite(&tl, 4, 1, fo);
	tl = 0;
	fwrite(&tl, 4, 1, fo);

	return fo;
}

// Write pixel into the file
void WritePixel_ExportBMP(FILE *fo, uint32_t BGR)
{
	BGR = Endian32(BGR);
	fwrite(&BGR, 1, 1, fo);
	BGR >>= 8;
	fwrite(&BGR, 1, 1, fo);
	BGR >>= 8;
	fwrite(&BGR, 1, 1, fo);
}

// Write pixel into the file
void WriteArray_ExportBMP(FILE *fo, uint32_t *BGR, int pixels)
{
	int i;
	uint32_t pixel;
	for (i=0; i<pixels; i++) {
		pixel = Endian32(*BGR++);
		fwrite(&pixel, 1, 1, fo);
		pixel >>= 8;
		fwrite(&pixel, 1, 1, fo);
		pixel >>= 8;
		fwrite(&pixel, 1, 1, fo);
	}
}

// Close file
void Close_ExportBMP(FILE *fo)
{
	fclose(fo);
}
