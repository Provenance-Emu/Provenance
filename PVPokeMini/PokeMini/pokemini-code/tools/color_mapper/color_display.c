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

#include <stdint.h>

#define min(a, b) ((a) < (b) ? (a) : (b))
#define max(a, b) ((a) > (b) ? (a) : (b))

#include "color_info.h"
#include "PokeMini_ColorPal.h"
#include "Video.h"

static const unsigned int drawline_coloridx[] = {0xFFFFFF, 0x000000, 0x808080};

static void colordisplay_drawhline(unsigned int *imgptr, int width, int height, int pitch,
	int y, int start, int end, int coloridx)
{
	if ((y < 0) || (y >= height)) return;
	if (start < 0) start = 0;
	else if (start >= width) return;
	if (end < 0) return;
	else if (end >= width) end = width-1;
	imgptr = (unsigned int *)imgptr + y * pitch + start;
	while (start != end) {
		*imgptr = drawline_coloridx[coloridx];
		imgptr++;
		start++;
	}
}

static void colordisplay_drawvline(unsigned int *imgptr, int width, int height, int pitch,
	int x, int start, int end, int coloridx)
{
	if ((x < 0) || (x >= width)) return;
	if (start < 0) start = 0;
	else if (start >= height) return;
	if (end < 0) return;
	else if (end >= height) end = height-1;
	imgptr = (unsigned int *)imgptr + start * pitch + x;
	while (start != end) {
		*imgptr = drawline_coloridx[coloridx];
		imgptr += pitch;
		start++;
	}
}

void colordisplay_decodespriteidx(int spriteidx, int x, int y, int *dataidx, int *maskidx)
{
	switch ((y & 8) + ((x & 8) >> 1)) {
		case 0: // Top-Left
			if (dataidx) *dataidx = (spriteidx << 3) + 2;
			if (maskidx) *maskidx = (spriteidx << 3) + 0;
			break;
		case 4: // Top-Right
			if (dataidx) *dataidx = (spriteidx << 3) + 6;
			if (maskidx) *maskidx = (spriteidx << 3) + 4;
			break;
		case 8: // Bottom-Left
			if (dataidx) *dataidx = (spriteidx << 3) + 3;
			if (maskidx) *maskidx = (spriteidx << 3) + 1;
			break;
		case 12: // Bottom-Right
			if (dataidx) *dataidx = (spriteidx << 3) + 7;
			if (maskidx) *maskidx = (spriteidx << 3) + 5;
			break;
	}
}

void colordisplay_8x8Attr(unsigned int *imgptr, int width, int height, int pitch,
	int spritemode, int zoom, unsigned int offset, int select_a, int select_b,
	int negative, unsigned int transparency, int grid, int monorender, int contrast)
{
	unsigned int *scanptr, mapoff;
	int x, y, odata;
	int xp, yp, pitchp;
	int tileidx, tileidxD = 0, tileidxM = 0, tiledataaddr, tilemaskaddr;

	negative &= 1;
	uint8_t *ColorMap = (uint8_t *)PRCStaticColorMap;
	uint8_t ddata = 0, mdata = 0;

	int selectStart = min(select_a, select_b) << 3;
	int selectEnd = max(select_a, select_b) << 3;

	if (spritemode) {
		// Draw sprites
		offset = offset & ~7;
		pitchp = pitch / zoom;
		for (y=0; y<height; y++) {
			yp = y / zoom;
			scanptr = &imgptr[y * pitch];
			for (x=0; x<width; x++) {
				xp = x / zoom;

				// Calculate
				tileidx = (yp >> 4) * (pitchp >> 4) + (xp >> 4);
				colordisplay_decodespriteidx(tileidx, xp, yp, &tileidxD, &tileidxM);
				tiledataaddr = (offset << 3) + (tileidxD << 3);
				tilemaskaddr = (offset << 3) + (tileidxM << 3);
				mapoff = (offset << 1) + (tileidxD << 1);

				// Draw sprite
				if (tiledataaddr < PM_ROM_FSize) {
					// Get map offset
					ColorMap = (uint8_t *)PRCColorUMap + mapoff;
					if ((mapoff < 0) || (mapoff >= PRCColorUBytes) || (monorender)) ColorMap = (uint8_t *)PRCStaticColorMap;

					// Decode and draw sprite
					mdata = PM_ROM[tilemaskaddr + (xp & 7)] & (1 << (yp & 7));
					if (!mdata) {
						ddata = PM_ROM[tiledataaddr + (xp & 7)] & (1 << (yp & 7));
						odata = ddata ? ColorMap[1 ^ negative] : ColorMap[0 ^ negative];
						odata += contrast << 4;
						if (odata < 0x00) odata = 0x00;
						if (odata > 0xFF) odata = 0xFF;
						scanptr[x] = PokeMini_ColorPalBGR32[odata];
					} else {
						scanptr[x] = transparency;
					}
				} else {
					// Outside ROM range
					if (monorender) scanptr[x] = PokeMini_ColorPalBGR32[ColorMap[0]];
					else scanptr[x] = (yp ^ xp) & 1 ? 0x808080 : 0x404040;
				}

				// Draw mask
				if ((selectStart >= 0) && (tiledataaddr >= selectStart) && (tiledataaddr < selectEnd)) {
					if (((x ^ y) & 3) == 3) scanptr[x] = ~scanptr[x];
				}
			}
		}
	} else {
		// Draw tiles
		pitchp = pitch / zoom;
		for (y=0; y<height; y++) {
			yp = y / zoom;
			scanptr = &imgptr[y * pitch];
			for (x=0; x<width; x++) {
				xp = x / zoom;

				// Calculate
				tileidx = (yp >> 3) * (pitchp >> 3) + (xp >> 3);
				tiledataaddr = (offset << 3) + (tileidx << 3);
				mapoff = (offset << 1) + (tileidx << 1);

				// Draw tile
				if (tiledataaddr < PM_ROM_FSize) {
					// Get map offset
					ColorMap = (uint8_t *)PRCColorUMap + mapoff;
					if ((mapoff < 0) || (mapoff >= PRCColorUBytes) || (monorender)) ColorMap = (uint8_t *)PRCStaticColorMap;

					// Decode and draw tile
					ddata = PM_ROM[tiledataaddr + (xp & 7)] & (1 << (yp & 7));
					odata = ddata ? ColorMap[1 ^ negative] : ColorMap[0 ^ negative];
					odata += contrast << 4;
					if (odata < 0x00) odata = 0x00;
					if (odata > 0xFF) odata = 0xFF;
					scanptr[x] = PokeMini_ColorPalBGR32[odata];
				} else {
					// Outside ROM range
					if (monorender) scanptr[x] = PokeMini_ColorPalBGR32[ColorMap[0]];
					else scanptr[x] = (yp ^ xp) & 1 ? 0x808080 : 0x404040;
				}

				// Draw mask
				if ((selectStart >= 0) && (tiledataaddr >= selectStart) && (tiledataaddr < selectEnd)) {
					if (((x ^ y) & 3) == 3) scanptr[x] = ~scanptr[x];
				}
			}
		}
	}

	// Draw grid
	if (grid) {
		for (x=0; x<width; x+=(zoom*8)) {
			colordisplay_drawvline(imgptr, width, height, pitch, x, 0, height, 0);
			colordisplay_drawvline(imgptr, width, height, pitch, x+1, 0, height, 1);
		}
		for (y=0; y<height; y+=(zoom*8)) {
			colordisplay_drawhline(imgptr, width, height, pitch, y, 0, width, 0);
			colordisplay_drawhline(imgptr, width, height, pitch, y+1, 0, width, 1);
		}
	}
}

void colordisplay_4x4Attr(unsigned int *imgptr, int width, int height, int pitch,
	int spritemode, int zoom, unsigned int offset, int select_a, int select_b,
	int negative, unsigned int transparency, int grid, int monorender, int contrast)
{
	unsigned int *scanptr, mapoff;
	int x, y, odata;
	int xp, yp, pitchp, subtile2;
	int tileidx, tileidxD = 0, tileidxM = 0, tiledataaddr, tilemaskaddr;

	negative &= 1;
	uint8_t *ColorMap = (uint8_t *)PRCStaticColorMap;
	uint8_t ddata = 0, mdata = 0;

	int selectStart = min(select_a, select_b) << 3;
	int selectEnd = max(select_a, select_b) << 3;

	if (spritemode) {
		// Draw sprites
		offset = offset & ~7;
		pitchp = pitch / zoom;
		for (y=0; y<height; y++) {
			yp = y / zoom;
			scanptr = &imgptr[y * pitch];
			for (x=0; x<width; x++) {
				xp = x / zoom;

				// Calculate
				tileidx = (yp >> 4) * (pitchp >> 4) + (xp >> 4);
				colordisplay_decodespriteidx(tileidx, xp, yp, &tileidxD, &tileidxM);
				tiledataaddr = (offset << 3) + (tileidxD << 3);
				tilemaskaddr = (offset << 3) + (tileidxM << 3);
				mapoff = (offset << 3) + (tileidxD << 3);
				subtile2 = (yp & 4) + ((xp & 4) >> 1);

				// Draw sprite
				if (tiledataaddr < PM_ROM_FSize) {
					// Get map offset
					ColorMap = (uint8_t *)PRCColorUMap + mapoff;
					if ((mapoff < 0) || (mapoff >= PRCColorUBytes) || (monorender)) ColorMap = (uint8_t *)PRCStaticColorMap;

					// Decode and draw
					mdata = PM_ROM[tilemaskaddr + (xp & 7)] & (1 << (yp & 7));
					if (!mdata) {
						ddata = PM_ROM[tiledataaddr + (xp & 7)] & (1 << (yp & 7));
						odata = ddata ? ColorMap[(subtile2 + 1) ^ negative] : ColorMap[subtile2 ^ negative];
						odata += contrast << 4;
						if (odata < 0x00) odata = 0x00;
						if (odata > 0xFF) odata = 0xFF;
						scanptr[x] = PokeMini_ColorPalBGR32[odata];
					} else {
						scanptr[x] = transparency;
					}
				} else {
					// Outside ROM range
					if (monorender) scanptr[x] = PokeMini_ColorPalBGR32[ColorMap[0]];
					else scanptr[x] = (yp ^ xp) & 1 ? 0x808080 : 0x404040;
				}

				// Draw mask
				if ((selectStart >= 0) && (tiledataaddr >= selectStart) && (tiledataaddr < selectEnd)) {
					if (((x ^ y) & 3) == 3) scanptr[x] = ~scanptr[x];
				}
			}
		}
	} else {
		// Draw tiles
		pitchp = pitch / zoom;
		for (y=0; y<height; y++) {
			yp = y / zoom;
			scanptr = &imgptr[y * pitch];
			for (x=0; x<width; x++) {
				xp = x / zoom;

				// Calculate
				tileidx = (yp >> 3) * (pitchp >> 3) + (xp >> 3);
				tiledataaddr = (offset << 3) + (tileidx << 3);
				mapoff = (offset << 3) + (tileidx << 3);
				subtile2 = (yp & 4) + ((xp & 4) >> 1);

				// Draw tile
				if (tiledataaddr < PM_ROM_FSize) {
					// Get map offset
					ColorMap = (uint8_t *)PRCColorUMap + mapoff;
					if ((mapoff < 0) || (mapoff >= PRCColorUBytes)) ColorMap = (uint8_t *)PRCStaticColorMap;

					// Decode and draw tile
					ddata = PM_ROM[tiledataaddr + (xp & 7)] & (1 << (yp & 7));
					odata = ddata ? ColorMap[(subtile2 + 1) ^ negative] : ColorMap[subtile2 ^ negative];
					odata += contrast << 4;
					if (odata < 0x00) odata = 0x00;
					if (odata > 0xFF) odata = 0xFF;
					scanptr[x] = PokeMini_ColorPalBGR32[odata];
				} else {
					// Outside ROM range
					if (monorender) scanptr[x] = PokeMini_ColorPalBGR32[ColorMap[0]];
					else scanptr[x] = (yp ^ xp) & 1 ? 0x808080 : 0x404040;
				}

				// Draw mask
				if ((selectStart >= 0) && (tiledataaddr >= selectStart) && (tiledataaddr < selectEnd)) {
					if (((x ^ y) & 3) == 3) scanptr[x] = ~scanptr[x];
				}
			}
		}
	}

	// Draw grid
	if (grid) {
		for (x=0; x<width; x+=(zoom*8)) {
			colordisplay_drawvline(imgptr, width, height, pitch, x+(zoom*4), 0, height, 2);
			colordisplay_drawvline(imgptr, width, height, pitch, x, 0, height, 0);
			colordisplay_drawvline(imgptr, width, height, pitch, x+1, 0, height, 1);
		}
		for (y=0; y<height; y+=(zoom*8)) {
			colordisplay_drawhline(imgptr, width, height, pitch, y+(zoom*4), 0, width, 2);
			colordisplay_drawhline(imgptr, width, height, pitch, y, 0, width, 0);
			colordisplay_drawhline(imgptr, width, height, pitch, y+1, 0, width, 1);
		}
	}
}
