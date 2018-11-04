/*
  PokeMini Color Mapper
  Copyright (C) 2011-2012  JustBurn

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

#include "Endianess.h"

#include "color_mapper.h"
#include "color_info.h"
#include "PMCommon.h"
#include "GtkXDialogs.h"

unsigned char *PM_ROM = NULL;
int PM_ROM_FSize = 0;
int PM_ROM_SSize = 0;

unsigned char *PRCColorUMap = NULL;	// Uncompressed map
uint32_t PRCColorUBytes = 0;		// Size of uncompressed map in bytes
uint32_t PRCColorUTiles = 0;		// Number of maximum tiles
uint32_t PRCColorBytesPerTile = 0;	// Number of bytes per tile
int PRCColorFormat = 0;			// Color format
int PRCColorFlags = 0x01;		// Color flags
uint32_t PRCColorCOffset = 0;		// Compress: Offset
uint32_t PRCColorCTiles = 0;		// Compress: Number of tiles

const uint8_t PRCStaticColorMap[8] = {0x00, 0xF0, 0x00, 0xF0, 0x00, 0xF0, 0x00, 0xF0};

void FreeColorInfo()
{
	if (PRCColorUMap) {
		free(PRCColorUMap);
		PRCColorUMap = NULL;
		PRCColorUTiles = 0;
		PRCColorUBytes = 0;
		PRCColorCOffset = 0;
		PRCColorCTiles = 0;
	}
}

int LoadMIN(char *filename)
{
	FILE *fmin;
	int size, readbytes;

	// Open file
	fmin = fopen(filename, "rb");
	if (fmin == NULL) {
		MessageDialog(MainWindow, "Failed to open MIN file", "Error", GTK_MESSAGE_ERROR, NULL);
		return 0;
	}

	// Check filesize
	fseek(fmin, 0, SEEK_END);
	size = ftell(fmin);

	// Check if size is valid
	if ((size <= 0x2100) || (size > 0x200000)) {
		fclose(fmin);
		MessageDialog(MainWindow, "MIN file size is invalid", "Error", GTK_MESSAGE_ERROR, NULL);
		return 0;
	}

	// Free existing color information
	FreeColorInfo();

	// Allocate ROM and set cartridge size
	if (PM_ROM) { free(PM_ROM); PM_ROM = NULL; }
	PM_ROM_FSize = size;
	PM_ROM_SSize = (size + 63) & ~63;
	PM_ROM = (uint8_t *)malloc(PM_ROM_SSize);
	if (!PM_ROM) {
		fclose(fmin);
		MessageDialog(MainWindow, "Not enough memory", "Error", GTK_MESSAGE_ERROR, NULL);
		return 0;
	}
	memset(PM_ROM, 0xFF, PM_ROM_SSize);

	// Read content
	fseek(fmin, 0x2100, SEEK_SET);
	readbytes = fread(&PM_ROM[0x2100], 1, size - 0x2100, fmin);
	fclose(fmin);

	// Check read size
	if (readbytes != (size - 0x2100)) {
		MessageDialog(MainWindow, "Read error @ MIN File", "Error", GTK_MESSAGE_ERROR, NULL);
		return 0;
	}

	return 1;
}

void ResetColorInfo()
{
	int i;
	if (PRCColorUMap) {
		// So far both color formats are compatible
		for (i=0; i<PRCColorUBytes; i+=2) {
			PRCColorUMap[i+0] = 0x00;
			PRCColorUMap[i+1] = 0xF0;
		}
	}
}

int NewColorInfo(int type)
{
	PRCColorFormat = type & 0xFF;
	PRCColorFlags = (type >> 8) & 0xFF;

	// Calculate stuff
	if (PRCColorFormat == 1) PRCColorBytesPerTile = 8;
	else PRCColorBytesPerTile = 2;
	PRCColorUTiles = PM_ROM_SSize >> 3;
	PRCColorUBytes = PRCColorUTiles * PRCColorBytesPerTile;
	PRCColorCOffset = 0;
	PRCColorCTiles = 0;

	// Allocate
	if (PRCColorUMap) {
		free(PRCColorUMap);
		PRCColorUMap = NULL;
	}
	PRCColorUMap = (uint8_t *)malloc(PRCColorUBytes);
	ResetColorInfo();

	return (PRCColorUMap != NULL);
}

int CompressColorInfo_8x8Attr(uint32_t *offset, uint32_t *tiles)
{
	int bot, top;

	// Check bottom
	for (bot=0; bot<PRCColorUBytes; bot+=2) {
		if ((PRCColorUMap[bot] != 0x00) || (PRCColorUMap[bot+1] != 0xF0)) {
			break;
		}
	}

	// Empty color info file?
	if (bot == PRCColorUBytes) {
		if (offset) *offset = 0;
		if (tiles) *tiles = 0;
		return 1;
	}

	// Check top
	for (top=PRCColorUBytes-2; top >= 0; top-=2) {
		if ((PRCColorUMap[top] != 0x00) || (PRCColorUMap[top+1] != 0xF0)) {
			top += 2;
			break;
		}
	}

	// Toward the end
	if (offset) *offset = (bot) >> 1;
	if (tiles) *tiles = (top - bot) >> 1;
	return 1;
}

int CompressColorInfo_4x4Attr(uint32_t *offset, uint32_t *tiles)
{
	int bot, top;

	// Check bottom
	for (bot=0; bot<PRCColorUBytes; bot+=8) {
		if ((PRCColorUMap[bot+0] != 0x00) || (PRCColorUMap[bot+1] != 0xF0)
		 || (PRCColorUMap[bot+2] != 0x00) || (PRCColorUMap[bot+3] != 0xF0)
		 || (PRCColorUMap[bot+4] != 0x00) || (PRCColorUMap[bot+5] != 0xF0)
		 || (PRCColorUMap[bot+6] != 0x00) || (PRCColorUMap[bot+7] != 0xF0)) {
			break;
		}
	}

	// Empty color info file?
	if (bot == PRCColorUBytes) {
		if (offset) *offset = 0;
		if (tiles) *tiles = 0;
		return 1;
	}

	// Check top
	for (top=PRCColorUBytes-8; top >= 0; top-=8) {
		if ((PRCColorUMap[top+0] != 0x00) || (PRCColorUMap[top+1] != 0xF0)
		 || (PRCColorUMap[top+2] != 0x00) || (PRCColorUMap[top+3] != 0xF0)
		 || (PRCColorUMap[top+4] != 0x00) || (PRCColorUMap[top+5] != 0xF0)
		 || (PRCColorUMap[top+6] != 0x00) || (PRCColorUMap[top+7] != 0xF0)) {
			top += 8;
			break;
		}
	}

	// Toward the end
	if (offset) *offset = (bot) >> 3;
	if (tiles) *tiles = (top - bot) >> 3;
	return 1;
}

int CompressColorInfo(uint32_t *offset, uint32_t *tiles)
{
	if (!PRCColorUMap) return 0;

	if (PRCColorFormat == 1) {
		return CompressColorInfo_4x4Attr(offset, tiles);
	} else {
		return CompressColorInfo_8x8Attr(offset, tiles);
	}
}

int Convert8x8to4x4()
{
	uint8_t *NewPRCColorUMap;
	int i;

	NewPRCColorUMap = (uint8_t *)malloc(PRCColorUTiles * 8);
	if (!NewPRCColorUMap) return 0;
	for (i=0; i<PRCColorUTiles; i++) {
		NewPRCColorUMap[i*8] = PRCColorUMap[i*2];
		NewPRCColorUMap[i*8+1] = PRCColorUMap[i*2+1];
		NewPRCColorUMap[i*8+2] = PRCColorUMap[i*2];
		NewPRCColorUMap[i*8+3] = PRCColorUMap[i*2+1];
		NewPRCColorUMap[i*8+4] = PRCColorUMap[i*2];
		NewPRCColorUMap[i*8+5] = PRCColorUMap[i*2+1];
		NewPRCColorUMap[i*8+6] = PRCColorUMap[i*2];
		NewPRCColorUMap[i*8+7] = PRCColorUMap[i*2+1];
	}
	free(PRCColorUMap);
	PRCColorUMap = NewPRCColorUMap;
	PRCColorFormat = 1;
	PRCColorBytesPerTile = 8;
	PRCColorUBytes = PRCColorUTiles * PRCColorBytesPerTile;
	PRCColorCOffset = 0;
	PRCColorCTiles = 0;
	return 1;
}

int Convert4x4to8x8()
{
	uint8_t *NewPRCColorUMap;
	int i;

	NewPRCColorUMap = (uint8_t *)malloc(PRCColorUTiles * 2);
	if (!NewPRCColorUMap) return 0;
	for (i=0; i<PRCColorUTiles; i++) {
		NewPRCColorUMap[i*2] = PRCColorUMap[i*8];
		NewPRCColorUMap[i*2+1] = PRCColorUMap[i*8+1];
	}
	free(PRCColorUMap);
	PRCColorUMap = NewPRCColorUMap;
	PRCColorFormat = 0;
	PRCColorBytesPerTile = 2;
	PRCColorUBytes = PRCColorUTiles * PRCColorBytesPerTile;
	PRCColorCOffset = 0;
	PRCColorCTiles = 0;
	return 1;
}

#define DATAREADFROMFILE(var, size) {\
	if (fread(var, 1, size, fi) != size) {\
		MessageDialog(MainWindow, "Read Error @ Color File", "Error", GTK_MESSAGE_ERROR, NULL);\
		fclose(fi);\
		return 0;\
	}\
}

const uint8_t RemapMINC10_11[16] = {
	 0, 1, 2, 4, 5, 6, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 
};

int LoadColorInfo_V0(FILE *fi, uint8_t *vcod)
{
	uint8_t tiledata[8];
	uint32_t maptiles, mapsprites;
	int i;

	PRCColorFormat = vcod[1];
	PRCColorFlags = 0x00;
	DATAREADFROMFILE(&maptiles, 4);		// Number of map tiles
	maptiles = Endian32(maptiles);
	DATAREADFROMFILE(&mapsprites, 4);	// Number of sprite tiles (Unsupported and ignored)

	// PM ROM Max is 2MB, that's 256K Map Tiles
	if (maptiles > 262144) {
		MessageDialog(MainWindow, "Map tiles exceed the limit", "Error", GTK_MESSAGE_ERROR, NULL);
		fclose(fi);
		return 0;
	}

	// Free existing color information
	FreeColorInfo();

	// Calculate stuff
	PRCColorBytesPerTile = 2;
	PRCColorUTiles = PM_ROM_SSize >> 3;
	PRCColorUBytes = PRCColorUTiles * PRCColorBytesPerTile;
	PRCColorCOffset = 0;
	PRCColorCTiles = maptiles;

	// Create and load map
	PRCColorUMap = (uint8_t *)malloc(PRCColorUBytes);
	ResetColorInfo();
	for (i=0; i<maptiles; i++) {
		DATAREADFROMFILE(tiledata, PRCColorBytesPerTile);
		if (i < PRCColorUTiles) {
			memcpy(PRCColorUMap + i * PRCColorBytesPerTile, tiledata, PRCColorBytesPerTile);
		}
	}

	// Version 0.0 have old color palette, remap colors to the new one
	if (!(PRCColorFlags & 1)) {
		for (i=0; i<PRCColorUBytes; i++) {
			PRCColorUMap[i] = RemapMINC10_11[PRCColorUMap[i] & 15] | (PRCColorUMap[i] & 0xF0);
		}
		PRCColorFlags |= 1;
	}

	// Drop a warning
	MessageDialog(MainWindow, "This was imported from old color info file format\nSprites mapping wasn't imported.", "Warning", GTK_MESSAGE_WARNING, NULL);

	return 2;
}

int LoadColorInfo_V1(FILE *fi, uint8_t *vcod)
{
	uint8_t reserved[16];
	uint8_t tiledata[8];
	uint32_t maptiles, mapoffset;
	int i, j;

	if (vcod[1] > 0x01) {	// Only color type 0 and 1 are valid
		MessageDialog(MainWindow, "Invalid color type", "Error", GTK_MESSAGE_ERROR, NULL);
		fclose(fi);
		return 0;
	}
	PRCColorFormat = vcod[1];
	PRCColorFlags = vcod[2];
	DATAREADFROMFILE(&maptiles, 4);		// Number of map tiles
	maptiles = Endian32(maptiles);
	DATAREADFROMFILE(&mapoffset, 4);	// Map offset in tiles
	mapoffset = Endian32(mapoffset);
	DATAREADFROMFILE(reserved, 16);		// Reserved area

	// PM ROM Max is 2MB, that's 256K Map Tiles
	if (maptiles > 262144) {
		MessageDialog(MainWindow, "Map tiles exceed the limit", "Error", GTK_MESSAGE_ERROR, NULL);
		fclose(fi);
		return 0;
	}
	if (mapoffset > 262144) {
		MessageDialog(MainWindow, "Map offset exceed the limit", "Error", GTK_MESSAGE_ERROR, NULL);
		fclose(fi);
		return 0;
	}

	// Free existing color information
	FreeColorInfo();

	// Calculate stuff
	if (PRCColorFormat == 1) PRCColorBytesPerTile = 8;
	else PRCColorBytesPerTile = 2;
	PRCColorUTiles = PM_ROM_SSize >> 3;
	PRCColorUBytes = PRCColorUTiles * PRCColorBytesPerTile;
	PRCColorCOffset = mapoffset;
	PRCColorCTiles = maptiles;

	// Create and load map
	PRCColorUMap = (uint8_t *)malloc(PRCColorUBytes);
	ResetColorInfo();
	for (i=0; i<maptiles; i++) {
		DATAREADFROMFILE(tiledata, PRCColorBytesPerTile);
		j = i + mapoffset;
		if (j < PRCColorUTiles) {
			memcpy(PRCColorUMap + j * PRCColorBytesPerTile, tiledata, PRCColorBytesPerTile);
		}
	}

	// Version 1.0 have old color palette, remap colors to the new one
	if (!(PRCColorFlags & 1)) {
		for (i=0; i<PRCColorUBytes; i++) {
			PRCColorUMap[i] = RemapMINC10_11[PRCColorUMap[i] & 15] | (PRCColorUMap[i] & 0xF0);
		}
		PRCColorFlags |= 1;
	}

	return 1;
}

int LoadColorInfo(char *filename)
{
	FILE *fi;
	uint8_t hdr[4], vcod[4];
	int err;

	if (!PM_ROM) {
		MessageDialog(MainWindow, "ROM isn't loaded yet!", "Error", GTK_MESSAGE_ERROR, NULL);
		return 0;
	}

	// Open file
	fi = fopen(filename, "rb");
	if (fi == NULL) {
		MessageDialog(MainWindow, "Failed to open color file", "Error", GTK_MESSAGE_ERROR, NULL);
		return 0;
	}

	// Check header
	DATAREADFROMFILE(hdr, 4);	// ID
	if ((hdr[0] != 'M') || (hdr[1] != 'I') || (hdr[2] != 'N') || (hdr[3] != 'c')) {
		MessageDialog(MainWindow, "Invalid color info file", "Error", GTK_MESSAGE_ERROR, NULL);
		fclose(fi);
		return 0;
	}
	DATAREADFROMFILE(vcod, 4);	// VCode
	if (vcod[0] == 0) {
		err = LoadColorInfo_V0(fi, vcod);
	} else if (vcod[0] == 1) {
		err = LoadColorInfo_V1(fi, vcod);
	} else {
		MessageDialog(MainWindow, "Unsupported version, please upgrade color mapper", "Error", GTK_MESSAGE_ERROR, NULL);
		fclose(fi);
		return 0;
	}

	// Done
	fclose(fi);

	return err;
}

#define DATAWRITETOFILE(var, size) {\
	if (fwrite(var, 1, size, fo) != size) {\
		MessageDialog(MainWindow, "Write Error @ Color File", "Error", GTK_MESSAGE_ERROR, NULL);\
		fclose(fo);\
		return 0;\
	}\
}

int SaveColorInfo(char *filename)
{
	FILE *fo;
	uint8_t hdr[4], vcod[4], reserved[16];
	uint8_t tiledata[8];
	uint32_t maptiles = -1, mapoffset = -1;
	int i, j;

	if (!CompressColorInfo(&mapoffset, &maptiles)) {
		MessageDialog(MainWindow, "Failed to get compression information", "Information", GTK_MESSAGE_ERROR, NULL);
		return 0;
	}

	// Open file
	fo = fopen(filename, "wb");
	if (fo == NULL) {
		MessageDialog(MainWindow, "Couldn't open file for saving", "Error", GTK_MESSAGE_ERROR, NULL);
		return 0;
	}

	// Write header
	hdr[0] = 'M'; hdr[1] = 'I'; hdr[2] = 'N'; hdr[3] = 'c';
	DATAWRITETOFILE(hdr, 4);		// ID
	vcod[0] = 0x01;				// Version
	vcod[1] = PRCColorFormat;		// Color Format
	vcod[2] = PRCColorFlags;		// Color Flags
	vcod[3] = 0x00;				// Reserved
	DATAWRITETOFILE(vcod, 4);		// VCode
	maptiles = Endian32(maptiles);
	DATAWRITETOFILE(&maptiles, 4);		// Number of map tiles
	mapoffset = Endian32(mapoffset);
	DATAWRITETOFILE(&mapoffset, 4);		// Map offset in tiles
	memset(reserved, 0, 16);
	DATAWRITETOFILE(reserved, 16);		// Reserved area

	for (i=0; i<maptiles; i++) {
		j = i + mapoffset;
		memcpy(tiledata, PRCColorUMap + j * PRCColorBytesPerTile, PRCColorBytesPerTile);
		DATAWRITETOFILE(tiledata, PRCColorBytesPerTile);
	}

	// Done
	fclose(fo);

	return 1;
}

int GetColorData(uint8_t *dst, int tileoff, int tiles)
{
	if (dst == NULL) return tiles * PRCColorBytesPerTile;

	if (tileoff >= PRCColorUTiles) return 0;
	if ((tileoff + tiles) > PRCColorUTiles) return 0;

	if (tiles > 0) memcpy(dst, PRCColorUMap + tileoff * PRCColorBytesPerTile, tiles * PRCColorBytesPerTile);
	return 1;
}

int SetColorData(uint8_t *src, int tileoff, int tiles)
{
	if (src == NULL) return tiles * PRCColorBytesPerTile;

	if (tileoff >= PRCColorUTiles) return 0;
	if ((tileoff + tiles) > PRCColorUTiles) {
		tiles = PRCColorUTiles - tileoff;
	}

	if (tiles > 0) memcpy(PRCColorUMap + tileoff * PRCColorBytesPerTile, src, tiles * PRCColorBytesPerTile);
	return 1;
}

int FillColorData(int tileoff, int tiles, int color_off, int color_on)
{
	int i;
	uint8_t *ptr;

	if (tileoff >= PRCColorUTiles) return 0;
	if ((tileoff + tiles) > PRCColorUTiles) {
		tiles = PRCColorUTiles - tileoff;
	}

	// So far both color formats are compatible
	if (tiles > 0) {
		ptr = PRCColorUMap + tileoff * PRCColorBytesPerTile;
		for (i=0; i<(tiles * PRCColorBytesPerTile); i+=2) {
			if (color_off >= 0) ptr[i] = (uint8_t)color_off;
			if (color_on >= 0) ptr[i+1] = (uint8_t)color_on;
		}
	}
	return 1;
}
