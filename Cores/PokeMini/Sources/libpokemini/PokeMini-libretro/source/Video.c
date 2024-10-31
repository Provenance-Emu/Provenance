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

#include "PokeMini.h"
#include "PokeMini_ColorPal.h"

int VidPixelLayout = 0;
int VidEnableHighcolor = 0;
uint32_t *VidPalette32 = NULL;
uint16_t *VidPalette16 = NULL;
uint32_t *VidPalColor32 = NULL;
uint16_t *VidPalColor16 = NULL;
uint32_t *VidPalColorH32 = NULL;
uint16_t *VidPalColorH16 = NULL;
TPokeMini_VideoSpec *PokeMini_VideoCurrent = NULL;
int PokeMini_VideoDepth = 0;
TPokeMini_DrawVideo16 PokeMini_VideoBlit16 = NULL;
TPokeMini_DrawVideo32 PokeMini_VideoBlit32 = NULL;
TPokeMini_DrawVideoPtr PokeMini_VideoBlit = NULL;

int PokeMini_SetVideo(TPokeMini_VideoSpec *videospec, int bpp, int dotmatrix, int lcdmode)
{
	if (!videospec) return 0;
	PokeMini_VideoCurrent = (TPokeMini_VideoSpec *)videospec;
	PokeMini_VideoBlit16 = PokeMini_VideoCurrent->Get16(dotmatrix, lcdmode);
	PokeMini_VideoBlit32 = PokeMini_VideoCurrent->Get32(dotmatrix, lcdmode);
	if (bpp == 32) {
		PokeMini_VideoBlit = (TPokeMini_DrawVideoPtr)PokeMini_VideoBlit32;
		PokeMini_VideoDepth = 32;
	} else {
		PokeMini_VideoBlit = (TPokeMini_DrawVideoPtr)PokeMini_VideoBlit16;
		PokeMini_VideoDepth = 16;
	}
	return PokeMini_VideoDepth;
}

void PokeMini_VideoRect_32(uint32_t *screen, int pitchW, int x, int y, int width, int height, uint32_t color)
{
	int xc, yc;
	screen += (y * pitchW) + x;
	for (yc=0; yc<height; yc++) {
		for (xc=0; xc<width; xc++) {
			screen[xc] = color;
		}
		screen += pitchW;
	}
}

void PokeMini_VideoRect_16(uint16_t *screen, int pitchW, int x, int y, int width, int height, uint16_t color)
{
	int xc, yc;
	screen += (y * pitchW) + x;
	for (yc=0; yc<height; yc++) {
		for (xc=0; xc<width; xc++) {
			screen[xc] = color;
		}
		screen += pitchW;
	}
}

void PokeMini_VideoPalette_Init(int pixellayout, int enablehighcolor)
{
	VidPixelLayout = pixellayout & 15;
	VidEnableHighcolor = enablehighcolor;
}

static inline int ExpCurve(int value, int strength)
{
	int curve;
	if (value < 0) value = 0;
	if (value > 255) value = 255;
	curve = 255 - value;
	curve = 255 - (curve * curve * curve / 65536);
	return Interpolate8(value, curve, strength);
}

void PokeMini_VideoPalette_32(uint32_t P0Color, uint32_t P1Color, int contrastboost, int brightoffset)
{
	int i;
	contrastboost = contrastboost * 255 / 100;
	brightoffset = brightoffset * 255 / 100;
	if (!VidPalette32) VidPalette32 = (uint32_t *)malloc(256*4);
	for (i=0; i<256; i++) VidPalette32[i] = InterpolateRGB24(P0Color, P1Color, ExpCurve(i - brightoffset, contrastboost));
	if (VidPixelLayout) {
		VidPalColor32 = (uint32_t *)PokeMini_ColorPalRGB32;
	} else {
		VidPalColor32 = (uint32_t *)PokeMini_ColorPalBGR32;
	}
	if (VidEnableHighcolor) {
		if (!VidPalColorH32) VidPalColorH32 = (uint32_t *)malloc(256*256*4);
		if (VidPixelLayout) {
			for (i=0; i<256*256; i++) VidPalColorH32[i] = InterpolateRGB24(VidPalColor32[i & 255], VidPalColor32[i >> 8], 128);
		} else {
			for (i=0; i<256*256; i++) VidPalColorH32[i] = InterpolateRGB24(VidPalColor32[i & 255], VidPalColor32[i >> 8], 128);
		}
	}
}

void PokeMini_VideoPalette_16(uint16_t P0Color, uint16_t P1Color, int contrastboost, int brightoffset)
{
	int i;
	contrastboost = contrastboost * 255 / 100;
	brightoffset = brightoffset * 255 / 100;
	if (!VidPalette16) VidPalette16 = (uint16_t *)malloc(256*2);
	if (VidPixelLayout == PokeMini_RGB15) {
		// RGB 15-Bits
		for (i=0; i<256; i++) VidPalette16[i] = InterpolateRGB15(P0Color, P1Color, ExpCurve(i - brightoffset, contrastboost));
	} else {
		// *** 16-Bits
		for (i=0; i<256; i++) VidPalette16[i] = InterpolateRGB16(P0Color, P1Color, ExpCurve(i - brightoffset, contrastboost));
	}
	if (VidPixelLayout == PokeMini_RGB15) {
		// RGB 15-Bits
		VidPalColor16 = (uint16_t *)PokeMini_ColorPalRGB15;
	} else if (VidPixelLayout == PokeMini_RGB16) {
		// RGB 16-Bits
		VidPalColor16 = (uint16_t *)PokeMini_ColorPalRGB16;
	} else {
		// BGR 16-Bits
		VidPalColor16 = (uint16_t *)PokeMini_ColorPalBGR16;
	}
	if (VidEnableHighcolor) {
		if (!VidPalColorH16) VidPalColorH16 = (uint16_t *)malloc(256*256*2);
		if (VidPixelLayout == PokeMini_RGB15) {
			// RGB 15-Bits
			for (i=0; i<256*256; i++) VidPalColorH16[i] = InterpolateRGB15(VidPalColor16[i & 255], VidPalColor16[i >> 8], 128);
		} else if (VidPixelLayout == PokeMini_RGB16) {
			// RGB 16-Bits
			for (i=0; i<256*256; i++) VidPalColorH16[i] = InterpolateRGB16(VidPalColor16[i & 255], VidPalColor16[i >> 8], 128);
		} else {
			// BGR 16-Bits
			for (i=0; i<256*256; i++) VidPalColorH16[i] = InterpolateRGB16(VidPalColor16[i & 255], VidPalColor16[i >> 8], 128);
		}
	}
}

void PokeMini_VideoPalette_Free(void)
{
	if (VidPalette32) { free(VidPalette32); VidPalette32 = NULL; }
	if (VidPalette16) { free(VidPalette16); VidPalette16 = NULL; }
	if (VidPalColorH32) { free(VidPalColorH32); VidPalColorH32 = NULL; }
	if (VidPalColorH16) { free(VidPalColorH16); VidPalColorH16 = NULL; }
}

void PokeMini_VideoPalette_Convert(uint32_t bgr32, int pixellayout, uint32_t *out32, uint16_t *out16)
{
	int r = GetValH24(bgr32);
	int g = GetValM24(bgr32);
	int b = GetValL24(bgr32);
	switch (pixellayout & 15) {
		case PokeMini_BGR16: // BGR32 / BGR16
			if (out32) *out32 = (r << 16) | (g << 8) | b;
			if (out16) *out16 = ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3);
			return;
		case PokeMini_RGB16: // RGB32 / RGB16
			if (out32) *out32 = (b << 16) | (g << 8) | r;
			if (out16) *out16 = ((b >> 3) << 11) | ((g >> 2) << 5) | (r >> 3);
			return;
		case PokeMini_RGB15: // RGB15
			if (out32) *out32 = (b << 16) | (g << 8) | r;
			if (out16) *out16 = ((b >> 3) << 10) | ((g >> 3) << 5) | (r >> 3) | 0x8000;
			return;
	}
}

void PokeMini_VideoPalette_Index(int index, uint32_t *CustomMonoPal, int contrastboost, int brightoffset)
{
	uint32_t p0_32 = 0xFFFFFF, p1_32 = 0x000000;
	uint16_t p0_16 = 0xFFFF, p1_16 = 0x0000;

	switch (index) {
		default:// Default
			PokeMini_VideoPalette_Convert(0xB4C8B4, VidPixelLayout, &p0_32, &p0_16);
			PokeMini_VideoPalette_Convert(0x122412, VidPixelLayout, &p1_32, &p1_16);
			break;
		case 1:	// Old PokeMini
			PokeMini_VideoPalette_Convert(0x8EAD92, VidPixelLayout, &p0_32, &p0_16);
			PokeMini_VideoPalette_Convert(0x4A5542, VidPixelLayout, &p1_32, &p1_16);
			break;
		case 2:	// Black & White
			PokeMini_VideoPalette_Convert(0xFFFFFF, VidPixelLayout, &p0_32, &p0_16);
			PokeMini_VideoPalette_Convert(0x000000, VidPixelLayout, &p1_32, &p1_16);
			break;
		case 3:	// Green Palette
			PokeMini_VideoPalette_Convert(0x00FF00, VidPixelLayout, &p0_32, &p0_16);
			PokeMini_VideoPalette_Convert(0x000000, VidPixelLayout, &p1_32, &p1_16);
			break;
		case 4:	// Green Vector
			PokeMini_VideoPalette_Convert(0x000000, VidPixelLayout, &p0_32, &p0_16);
			PokeMini_VideoPalette_Convert(0x00FF00, VidPixelLayout, &p1_32, &p1_16);
			break;
		case 5:	// Red Palette
			PokeMini_VideoPalette_Convert(0xFF0000, VidPixelLayout, &p0_32, &p0_16);
			PokeMini_VideoPalette_Convert(0x000000, VidPixelLayout, &p1_32, &p1_16);
			break;
		case 6:	// Red Vector
			PokeMini_VideoPalette_Convert(0x000000, VidPixelLayout, &p0_32, &p0_16);
			PokeMini_VideoPalette_Convert(0xFF0000, VidPixelLayout, &p1_32, &p1_16);
			break;
		case 7:	// Blue LCD
			PokeMini_VideoPalette_Convert(0xC0C0FF, VidPixelLayout, &p0_32, &p0_16);
			PokeMini_VideoPalette_Convert(0x4040FF, VidPixelLayout, &p1_32, &p1_16);
			break;
		case 8:  // LED Backlight
			PokeMini_VideoPalette_Convert(0xD4D4CF, VidPixelLayout, &p0_32, &p0_16);
			PokeMini_VideoPalette_Convert(0x2A2A17, VidPixelLayout, &p1_32, &p1_16);
			break;
		case 9:  // Girlish
			PokeMini_VideoPalette_Convert(0xFF80E0, VidPixelLayout, &p0_32, &p0_16);
			PokeMini_VideoPalette_Convert(0xA01880, VidPixelLayout, &p1_32, &p1_16);
			break;
		case 10: // Blue Palette
			PokeMini_VideoPalette_Convert(0x0000FF, VidPixelLayout, &p0_32, &p0_16);
			PokeMini_VideoPalette_Convert(0x000000, VidPixelLayout, &p1_32, &p1_16);
			break;
		case 11: // Blue Vector
			PokeMini_VideoPalette_Convert(0x000000, VidPixelLayout, &p0_32, &p0_16);
			PokeMini_VideoPalette_Convert(0x0000FF, VidPixelLayout, &p1_32, &p1_16);
			break;
		case 12:  // Sepia
			PokeMini_VideoPalette_Convert(0xD4BC8C, VidPixelLayout, &p0_32, &p0_16);
			PokeMini_VideoPalette_Convert(0x704214, VidPixelLayout, &p1_32, &p1_16);
			break;
		case 13: // Inv. B&W
			PokeMini_VideoPalette_Convert(0x000000, VidPixelLayout, &p0_32, &p0_16);
			PokeMini_VideoPalette_Convert(0xFFFFFF, VidPixelLayout, &p1_32, &p1_16);
			break;
		case 14: // Custom 1
			if (CustomMonoPal) {
				PokeMini_VideoPalette_Convert(CustomMonoPal[0], VidPixelLayout, &p0_32, &p0_16);
				PokeMini_VideoPalette_Convert(CustomMonoPal[1], VidPixelLayout, &p1_32, &p1_16);
			}
			break;
		case 15: // Custom 2
			if (CustomMonoPal) {
				PokeMini_VideoPalette_Convert(CustomMonoPal[2], VidPixelLayout, &p0_32, &p0_16);
				PokeMini_VideoPalette_Convert(CustomMonoPal[3], VidPixelLayout, &p1_32, &p1_16);
			}
			break;
	}
	PokeMini_VideoPalette_32(p0_32, p1_32, contrastboost, brightoffset);
	PokeMini_VideoPalette_16(p0_16, p1_16, contrastboost, brightoffset);
}

void PokeMini_VideoPreview_32(uint32_t *screen, int pitchW, int lcdmode)
{
	switch (lcdmode) {
		case LCDMODE_3SHADES: PokeMini_VideoPreview3_32(screen, pitchW); break;
		case LCDMODE_2SHADES: PokeMini_VideoPreview2_32(screen, pitchW); break;
		case LCDMODE_COLORS:
			if (VidEnableHighcolor) PokeMini_VideoPreviewCH_32(screen, pitchW);
			else PokeMini_VideoPreviewC_32(screen, pitchW);
			break;
		default: PokeMini_VideoPreviewA_32(screen, pitchW); break;
	}
}

void PokeMini_VideoPreview_16(uint16_t *screen, int pitchW, int lcdmode)
{
	switch (lcdmode) {
		case LCDMODE_3SHADES: PokeMini_VideoPreview3_16(screen, pitchW); break;
		case LCDMODE_2SHADES: PokeMini_VideoPreview2_16(screen, pitchW); break;
		case LCDMODE_COLORS:
			if (VidEnableHighcolor) PokeMini_VideoPreviewCH_16(screen, pitchW);
			else PokeMini_VideoPreviewC_16(screen, pitchW);
			break;
		default: PokeMini_VideoPreviewA_16(screen, pitchW); break;
	}
}

void PokeMini_VideoPreview2_32(uint32_t *screen, int pitchW)
{
	int xk, yk, LCDP = 0;
	uint32_t pix0, pix1;

	pix1 = VidPalette32[MinxLCD.Pixel1Intensity];
	pix0 = VidPalette32[MinxLCD.Pixel0Intensity];
	for (yk=0; yk<64; yk++) {
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDP++]) screen[xk] = pix1;
			else screen[xk] = pix0;
		}
		screen += pitchW;
	}
}

void PokeMini_VideoPreview2_16(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDP = 0;
	uint32_t pix0, pix1;

	pix1 = VidPalette16[MinxLCD.Pixel1Intensity];
	pix0 = VidPalette16[MinxLCD.Pixel0Intensity];
	for (yk=0; yk<64; yk++) {
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDP++]) screen[xk] = pix1;
			else screen[xk] = pix0;
		}
		screen += pitchW;
	}
}

void PokeMini_VideoPreviewA_32(uint32_t *screen, int pitchW)
{
	int xk, yk, LCDP = 0;

	for (yk=0; yk<64; yk++) {
		for (xk=0; xk<96; xk++) {
			screen[xk] = VidPalette32[LCDPixelsA[LCDP++]];
		}
		screen += pitchW;
	}
}

void PokeMini_VideoPreviewA_16(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDP = 0;

	for (yk=0; yk<64; yk++) {
		for (xk=0; xk<96; xk++) {
			screen[xk] = VidPalette16[LCDPixelsA[LCDP++]];
		}
		screen += pitchW;
	}
}

void PokeMini_VideoPreview3_32(uint32_t *screen, int pitchW)
{
	int xk, yk, LCDP = 0;

	for (yk=0; yk<64; yk++) {
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDP] + LCDPixelsA[LCDP]) {
				case 2: screen[xk] = VidPalette32[MinxLCD.Pixel1Intensity]; break;
				case 1: screen[xk] = VidPalette32[(MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1]; break;
				default: screen[xk] = VidPalette32[MinxLCD.Pixel0Intensity]; break;
			}
			LCDP++;
		}
		screen += pitchW;
	}
}

void PokeMini_VideoPreview3_16(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDP = 0;

	for (yk=0; yk<64; yk++) {
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDP] + LCDPixelsA[LCDP]) {
				case 2: screen[xk] = VidPalette16[MinxLCD.Pixel1Intensity]; break;
				case 1: screen[xk] = VidPalette16[(MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1]; break;
				default: screen[xk] = VidPalette16[MinxLCD.Pixel0Intensity]; break;
			}
			LCDP++;
		}
		screen += pitchW;
	}
}

void PokeMini_VideoPreviewC_32(uint32_t *screen, int pitchW)
{
	int xk, yk, LCDP = 0;

	for (yk=0; yk<64; yk++) {
		for (xk=0; xk<96; xk++) {
			screen[xk] = VidPalColor32[PRCColorPixels[LCDP++]];
		}
		screen += pitchW;
	}
}

void PokeMini_VideoPreviewC_16(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDP = 0;

	for (yk=0; yk<64; yk++) {
		for (xk=0; xk<96; xk++) {
			screen[xk] = VidPalColor16[PRCColorPixels[LCDP++]];
		}
		screen += pitchW;
	}
}

void PokeMini_VideoPreviewCH_32(uint32_t *screen, int pitchW)
{
	int xk, yk, LCDP = 0;

	for (yk=0; yk<64; yk++) {
		for (xk=0; xk<96; xk++) {
			screen[xk] = VidPalColorH32[PRCColorPixels[LCDP] * 256 + PRCColorPixelsOld[LCDP]];
			LCDP++;
		}
		screen += pitchW;
	}
}

void PokeMini_VideoPreviewCH_16(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDP = 0;

	for (yk=0; yk<64; yk++) {
		for (xk=0; xk<96; xk++) {
			screen[xk] = VidPalColorH16[PRCColorPixels[LCDP] * 256 + PRCColorPixelsOld[LCDP]];
			LCDP++;
		}
		screen += pitchW;
	}
}
