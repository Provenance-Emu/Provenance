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
#include "ExportWAV.h"

// Open a unique files for saving the capture
FILE *OpenUnique_ExportWAV(uint8_t format)
{
	int i;
	char file[32];
	FILE *ft;
	for (i=0; i<16777216; i++) {
		sprintf(file, "dump_%03d.wav", i);
		ft = fopen(file, "r");
		if (!ft) break;
		fclose(ft);
	}
	return Open_ExportWAV(file, format);
}

// Open file for saving the capture
FILE *Open_ExportWAV(const char *filename, uint8_t format)
{
	const char *text_RIFF = "RIFF";
	const char *text_WAVE = "WAVE";
	const char *text_fmt_ = "fmt ";
	const char *text_data = "data";
	uint32_t tl;
	uint16_t tw;
	int frequency, channels, bits;
	FILE *fo;

	switch (format & EXPORTWAV_MASK) {
		case EXPORTWAV_11KHZ: frequency = 11025; break;
		case EXPORTWAV_22KHZ: frequency = 22050; break;
		case EXPORTWAV_44KHZ: frequency = 44100; break;
		default: frequency = 0; break;
	}
	channels = (format & EXPORTWAV_STEREO) ? 2 : 1;
	bits = (format & EXPORTWAV_16BITS) ? 16 : 8;

	fo = fopen(filename, "wb");
	if (fo == NULL) return NULL;

	// Write file header
	fwrite(text_RIFF, 4, 1, fo);
	tl = 0;
	fwrite(&tl, 4, 1, fo);
	fwrite(text_WAVE, 4, 1, fo);
	fwrite(text_fmt_, 4, 1, fo);
	tl = Endian32(16);
	fwrite(&tl, 4, 1, fo);
	tw = Endian16(1);
	fwrite(&tw, 2, 1, fo);
	tw = Endian16(channels);
	fwrite(&tw, 2, 1, fo);
	tl = Endian32(frequency);
	fwrite(&tl, 4, 1, fo);
	tl = Endian32(frequency * channels * bits / 8);
	fwrite(&tl, 4, 1, fo);
	tw = Endian16(channels * bits / 8);
	fwrite(&tw, 2, 1, fo);
	tw = Endian16(bits);
	fwrite(&tw, 2, 1, fo);
	fwrite(text_data, 4, 1, fo);
	tl = 0;
	fwrite(&tl, 4, 1, fo);

	return fo;
}

// Write unsigned 8-bits sample
void WriteU8_ExportWAV(FILE *fo, uint8_t sample)
{
	fwrite(&sample, 1, 1, fo);
}

// Write signed 16-bits sample
void WriteS16_ExportWAV(FILE *fo, int16_t sample)
{
	uint16_t tsamp = Endian16(sample);
	fwrite(&tsamp, 2, 1, fo);
}

// Write unsigned 8-bits array
void WriteU8A_ExportWAV(FILE *fo, uint8_t *samples, int len)
{
	if (len <= 0) return;
	fwrite(samples, 1, len, fo);
}

// Write signed 16-bits array
void WriteS16A_ExportWAV(FILE *fo, int16_t *samples, int len)
{
	uint16_t tsamp;
	int i;
	if (len <= 0) return;
	for (i=0; i<len; i++) {
		tsamp = Endian16(samples[i]);
		fwrite(&tsamp, 2, 1, fo);
	}
}

// Close file for saving the capture
void Close_ExportWAV(FILE *fo)
{
	uint32_t tl, filesize = ftell(fo);

	// Mark file size
	fseek(fo, 4, SEEK_SET);
	tl = Endian32(filesize - 8);
	fwrite(&tl, 4, 1, fo);

	// Mark data size
	fseek(fo, 40, SEEK_SET);
	tl = Endian32(filesize - 44);
	fwrite(&tl, 4, 1, fo);

	fclose(fo);
}
