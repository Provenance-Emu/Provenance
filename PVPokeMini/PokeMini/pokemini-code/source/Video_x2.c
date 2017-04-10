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
#include "Video_x2.h"

const TPokeMini_VideoSpec PokeMini_Video2x2 = {
	2, 2,
	PokeMini_GetVideo2x2_16,
	PokeMini_GetVideo2x2_32
};

const TPokeMini_VideoSpec PokeMini_Video2x2_NDS = {	// For NDS
	2, 2,
	PokeMini_GetVideo2x2_8P,
	PokeMini_GetVideo2x2_32
};

const int LCDMask2x2[2*2] = {
	256, 192,
	192, 160,
};

TPokeMini_DrawVideo32 PokeMini_GetVideo2x2_32(int filter, int lcdmode)
{
	if (filter == PokeMini_Scanline) {
		switch (lcdmode) {
			case 3: return PokeMini_VideoColorL2x2_32;
			case 2: return PokeMini_Video2ScanLine2x2_32;
			case 1: return PokeMini_Video3ScanLine2x2_32;
			default: return PokeMini_VideoAScanLine2x2_32;
		}
	} else if (filter == PokeMini_Matrix) {
		switch (lcdmode) {
			case 3: return (VidEnableHighcolor) ? PokeMini_VideoColorH2x2_32 : PokeMini_VideoColor2x2_32;
			case 2: return PokeMini_Video2Matrix2x2_32;
			case 1: return PokeMini_Video3Matrix2x2_32;
			default: return PokeMini_VideoAMatrix2x2_32;
		}
	} else {
		switch (lcdmode) {
			case 3: return PokeMini_VideoColor2x2_32;
			case 2: return PokeMini_Video2None2x2_32;
			case 1: return PokeMini_Video3None2x2_32;
			default: return PokeMini_VideoANone2x2_32;
		}
	}
}

TPokeMini_DrawVideo16 PokeMini_GetVideo2x2_16(int filter, int lcdmode)
{
	if (filter == PokeMini_Scanline) {
		switch (lcdmode) {
			case 3: return PokeMini_VideoColorL2x2_16;
			case 2: return PokeMini_Video2ScanLine2x2_16;
			case 1: return PokeMini_Video3ScanLine2x2_16;
			default: return PokeMini_VideoAScanLine2x2_16;
		}
	} else if (filter == PokeMini_Matrix) {
		switch (lcdmode) {
			case 3: return (VidEnableHighcolor) ? PokeMini_VideoColorH2x2_16 : PokeMini_VideoColor2x2_16;
			case 2: return PokeMini_Video2Matrix2x2_16;
			case 1: return PokeMini_Video3Matrix2x2_16;
			default: return PokeMini_VideoAMatrix2x2_16;
		}
	} else {
		switch (lcdmode) {
			case 3: return PokeMini_VideoColor2x2_16;
			case 2: return PokeMini_Video2None2x2_16;
			case 1: return PokeMini_Video3None2x2_16;
			default: return PokeMini_VideoANone2x2_16;
		}
	}
}

TPokeMini_DrawVideo16 PokeMini_GetVideo2x2_8P(int filter, int lcdmode)
{
	if (filter == PokeMini_Scanline) {
		switch (lcdmode) {
			case 3: return PokeMini_VideoColorL2x2_8P;
			case 2: return PokeMini_Video2ScanLine2x2_8P;
			case 1: return PokeMini_Video3ScanLine2x2_8P;
			default: return PokeMini_VideoAScanLine2x2_8P;
		}
	} else if (filter == PokeMini_Matrix) {
		switch (lcdmode) {
			case 3: return PokeMini_VideoColor2x2_8P;
			case 2: return PokeMini_Video2Matrix2x2_8P;
			case 1: return PokeMini_Video3Matrix2x2_8P;
			default: return PokeMini_VideoAMatrix2x2_8P;
		}
	} else {
		switch (lcdmode) {
			case 3: return PokeMini_VideoColor2x2_8P;
			case 2: return PokeMini_Video2None2x2_8P;
			case 1: return PokeMini_Video3None2x2_8P;
			default: return PokeMini_VideoANone2x2_8P;
		}
	}
}

void PokeMini_VideoAScanLine2x2_32(uint32_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint32_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalette32[LCDPixelsA[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 192*4);
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_VideoAScanLine2x2_16(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint16_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalette16[LCDPixelsA[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 192*2);
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_VideoAScanLine2x2_8P(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint16_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = LCDPixelsA[LCDY + xk];
			*ptr++ = pix | (pix << 8);
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<(96>>2); xk++) {
			*ptr++ = 0; *ptr++ = 0;
			*ptr++ = 0; *ptr++ = 0;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_Video3ScanLine2x2_32(uint32_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint32_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: pix = VidPalette32[MinxLCD.Pixel1Intensity]; break;
				case 1: pix = VidPalette32[(MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1]; break;
				default: pix = VidPalette32[MinxLCD.Pixel0Intensity]; break;
			}
			*ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		memset(screen, 0, 192*4);
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_Video3ScanLine2x2_16(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint16_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: pix = VidPalette16[MinxLCD.Pixel1Intensity]; break;
				case 1: pix = VidPalette16[(MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1]; break;
				default: pix = VidPalette16[MinxLCD.Pixel0Intensity]; break;
			}
			*ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		memset(screen, 0, 192*2);
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_Video3ScanLine2x2_8P(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint16_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: pix = MinxLCD.Pixel1Intensity; break;
				case 1: pix = (MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1; break;
				default: pix = MinxLCD.Pixel0Intensity; break;
			}
			*ptr++ = pix | (pix << 8);
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<(96>>2); xk++) {
			*ptr++ = 0; *ptr++ = 0;
			*ptr++ = 0; *ptr++ = 0;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_Video2ScanLine2x2_32(uint32_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint32_t *ptr, pix, pix1, pix0;

	LCDY = 0;
	pix1 = VidPalette32[MinxLCD.Pixel1Intensity];
	pix0 = VidPalette32[MinxLCD.Pixel0Intensity];
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) pix = pix1;
			else pix = pix0;
			*ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		memset(screen, 0, 192*4);
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_Video2ScanLine2x2_16(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint16_t *ptr, pix, pix1, pix0;

	LCDY = 0;
	pix1 = VidPalette16[MinxLCD.Pixel1Intensity];
	pix0 = VidPalette16[MinxLCD.Pixel0Intensity];
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) pix = pix1;
			else pix = pix0;
			*ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		memset(screen, 0, 192*2);
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_Video2ScanLine2x2_8P(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint16_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) pix = MinxLCD.Pixel1Intensity;
			else pix = MinxLCD.Pixel0Intensity;
			*ptr++ = pix | (pix << 8);
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<(96>>2); xk++) {
			*ptr++ = 0; *ptr++ = 0;
			*ptr++ = 0; *ptr++ = 0;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_VideoAMatrix2x2_32(uint32_t *screen, int pitchW)
{
	int xk, yk, level, LCDY, maskH;
	uint32_t *ptr;

	LCDY = 0;
	maskH = 0;
	for (yk=0; yk<64*2; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			level = LCDPixelsA[LCDY + xk];
			*ptr++ = VidPalette32[level * LCDMask2x2[maskH] >> 8];
			*ptr++ = VidPalette32[level * LCDMask2x2[maskH+1] >> 8];
		}
		screen += pitchW;
		maskH += 2;
		if (maskH >= 4) {
			maskH = 0;
			LCDY += 96;
		}
	}
}

void PokeMini_VideoAMatrix2x2_16(uint16_t *screen, int pitchW)
{
	int xk, yk, level, LCDY, maskH;
	uint16_t *ptr;

	LCDY = 0;
	maskH = 0;
	for (yk=0; yk<64*2; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			level = LCDPixelsA[LCDY + xk];
			*ptr++ = VidPalette16[level * LCDMask2x2[maskH] >> 8];
			*ptr++ = VidPalette16[level * LCDMask2x2[maskH+1] >> 8];
		}
		screen += pitchW;
		maskH += 2;
		if (maskH >= 4) {
			maskH = 0;
			LCDY += 96;
		}
	}
}

void PokeMini_VideoAMatrix2x2_8P(uint16_t *screen, int pitchW)
{
	int xk, yk, level, LCDY, maskH;
	uint16_t *ptr;

	LCDY = 0;
	maskH = 0;
	for (yk=0; yk<64*2; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			level = LCDPixelsA[LCDY + xk];
			*ptr++ = (level * LCDMask2x2[maskH] >> 8) | ((level * LCDMask2x2[maskH+1]) & 0xFF00);
		}
		screen += pitchW;
		maskH += 2;
		if (maskH >= 4) {
			maskH = 0;
			LCDY += 96;
		}
	}
}

void PokeMini_Video3Matrix2x2_32(uint32_t *screen, int pitchW)
{
	int xk, yk, level, LCDY, maskH;
	uint32_t *ptr;

	LCDY = 0;
	maskH = 0;
	for (yk=0; yk<64*2; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: level = MinxLCD.Pixel1Intensity; break;
				case 1: level = (MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1; break;
				default: level = MinxLCD.Pixel0Intensity; break;
			}
			*ptr++ = VidPalette32[level * LCDMask2x2[maskH] >> 8];
			*ptr++ = VidPalette32[level * LCDMask2x2[maskH+1] >> 8];
		}
		screen += pitchW;
		maskH += 2;
		if (maskH >= 4) {
			maskH = 0;
			LCDY += 96;
		}
	}
}

void PokeMini_Video3Matrix2x2_16(uint16_t *screen, int pitchW)
{
	int xk, yk, level, LCDY, maskH;
	uint16_t *ptr;

	LCDY = 0;
	maskH = 0;
	for (yk=0; yk<64*2; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: level = MinxLCD.Pixel1Intensity; break;
				case 1: level = (MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1; break;
				default: level = MinxLCD.Pixel0Intensity; break;
			}
			*ptr++ = VidPalette16[level * LCDMask2x2[maskH] >> 8];
			*ptr++ = VidPalette16[level * LCDMask2x2[maskH+1] >> 8];
		}
		screen += pitchW;
		maskH += 2;
		if (maskH >= 4) {
			maskH = 0;
			LCDY += 96;
		}
	}
}

void PokeMini_Video3Matrix2x2_8P(uint16_t *screen, int pitchW)
{
	int xk, yk, level, LCDY, maskH;
	uint16_t *ptr;

	LCDY = 0;
	maskH = 0;
	for (yk=0; yk<64*2; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: level = MinxLCD.Pixel1Intensity; break;
				case 1: level = (MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1; break;
				default: level = MinxLCD.Pixel0Intensity; break;
			}
			*ptr++ = (level * LCDMask2x2[maskH] >> 8) | ((level * LCDMask2x2[maskH+1]) & 0xFF00);
		}
		screen += pitchW;
		maskH += 2;
		if (maskH >= 4) {
			maskH = 0;
			LCDY += 96;
		}
	}
}

void PokeMini_Video2Matrix2x2_32(uint32_t *screen, int pitchW)
{
	int xk, yk, level, LCDY, maskH;
	uint32_t *ptr;

	LCDY = 0;
	maskH = 0;
	for (yk=0; yk<64*2; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) level = MinxLCD.Pixel1Intensity;
			else level = MinxLCD.Pixel0Intensity;
			*ptr++ = VidPalette32[level * LCDMask2x2[maskH] >> 8];
			*ptr++ = VidPalette32[level * LCDMask2x2[maskH+1] >> 8];
		}
		screen += pitchW;
		maskH += 2;
		if (maskH >= 4) {
			maskH = 0;
			LCDY += 96;
		}
	}
}

void PokeMini_Video2Matrix2x2_16(uint16_t *screen, int pitchW)
{
	int xk, yk, level, LCDY, maskH;
	uint16_t *ptr;

	LCDY = 0;
	maskH = 0;
	for (yk=0; yk<64*2; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) level = MinxLCD.Pixel1Intensity;
			else level = MinxLCD.Pixel0Intensity;
			*ptr++ = VidPalette16[level * LCDMask2x2[maskH] >> 8];
			*ptr++ = VidPalette16[level * LCDMask2x2[maskH+1] >> 8];
		}
		screen += pitchW;
		maskH += 2;
		if (maskH >= 4) {
			maskH = 0;
			LCDY += 96;
		}
	}
}

void PokeMini_Video2Matrix2x2_8P(uint16_t *screen, int pitchW)
{
	int xk, yk, level, LCDY, maskH;
	uint16_t *ptr;

	LCDY = 0;
	maskH = 0;
	for (yk=0; yk<64*2; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) level = MinxLCD.Pixel1Intensity;
			else level = MinxLCD.Pixel0Intensity;
			*ptr++ = (level * LCDMask2x2[maskH] >> 8) | ((level * LCDMask2x2[maskH+1]) & 0xFF00);
		}
		screen += pitchW;
		maskH += 2;
		if (maskH >= 4) {
			maskH = 0;
			LCDY += 96;
		}
	}
}

void PokeMini_VideoANone2x2_32(uint32_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint32_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalette32[LCDPixelsA[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalette32[LCDPixelsA[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_VideoANone2x2_16(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint16_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalette16[LCDPixelsA[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalette16[LCDPixelsA[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_VideoANone2x2_8P(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint16_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = LCDPixelsA[LCDY + xk];
			*ptr++ = pix | (pix << 8);
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = LCDPixelsA[LCDY + xk];
			*ptr++ = pix | (pix << 8);
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_Video3None2x2_32(uint32_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint32_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: pix = VidPalette32[MinxLCD.Pixel1Intensity]; break;
				case 1: pix = VidPalette32[(MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1]; break;
				default: pix = VidPalette32[MinxLCD.Pixel0Intensity]; break;
			}
			*ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: pix = VidPalette32[MinxLCD.Pixel1Intensity]; break;
				case 1: pix = VidPalette32[(MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1]; break;
				default: pix = VidPalette32[MinxLCD.Pixel0Intensity]; break;
			}
			*ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_Video3None2x2_16(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint16_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: pix = VidPalette16[MinxLCD.Pixel1Intensity]; break;
				case 1: pix = VidPalette16[(MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1]; break;
				default: pix = VidPalette16[MinxLCD.Pixel0Intensity]; break;
			}
			*ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: pix = VidPalette16[MinxLCD.Pixel1Intensity]; break;
				case 1: pix = VidPalette16[(MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1]; break;
				default: pix = VidPalette16[MinxLCD.Pixel0Intensity]; break;
			}
			*ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_Video3None2x2_8P(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint16_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: pix = MinxLCD.Pixel1Intensity; break;
				case 1: pix = (MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1; break;
				default: pix = MinxLCD.Pixel0Intensity; break;
			}
			*ptr++ = pix | (pix << 8);
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: pix = MinxLCD.Pixel1Intensity; break;
				case 1: pix = (MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1; break;
				default: pix = MinxLCD.Pixel0Intensity; break;
			}
			*ptr++ = pix | (pix << 8);
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_Video2None2x2_32(uint32_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint32_t *ptr, pix, pix1, pix0;

	LCDY = 0;
	pix1 = VidPalette32[MinxLCD.Pixel1Intensity];
	pix0 = VidPalette32[MinxLCD.Pixel0Intensity];
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) pix = pix1;
			else pix = pix0;
			*ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) pix = pix1;
			else pix = pix0;
			*ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_Video2None2x2_16(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint16_t *ptr, pix, pix1, pix0;

	LCDY = 0;
	pix1 = VidPalette16[MinxLCD.Pixel1Intensity];
	pix0 = VidPalette16[MinxLCD.Pixel0Intensity];
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) pix = pix1;
			else pix = pix0;
			*ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) pix = pix1;
			else pix = pix0;
			*ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_Video2None2x2_8P(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint16_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) pix = MinxLCD.Pixel1Intensity;
			else pix = MinxLCD.Pixel0Intensity;
			*ptr++ = pix | (pix << 8);
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) pix = MinxLCD.Pixel1Intensity;
			else pix = MinxLCD.Pixel0Intensity;
			*ptr++ = pix | (pix << 8);
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_VideoColor2x2_32(uint32_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint32_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColor32[PRCColorPixels[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColor32[PRCColorPixels[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_VideoColor2x2_16(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint16_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColor16[PRCColorPixels[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColor16[PRCColorPixels[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

// WARNING! Color palette should be in CRAM!
void PokeMini_VideoColor2x2_8P(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint16_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = PRCColorPixels[LCDY + xk];
			*ptr++ = pix | (pix << 8);
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = PRCColorPixels[LCDY + xk];
			*ptr++ = pix | (pix << 8);
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_VideoColorL2x2_32(uint32_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint32_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColor32[PRCColorPixels[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<(96>>2); xk++) {
			*ptr++ = 0; *ptr++ = 0;
			*ptr++ = 0; *ptr++ = 0;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_VideoColorL2x2_16(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint16_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColor16[PRCColorPixels[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<(96>>2); xk++) {
			*ptr++ = 0; *ptr++ = 0;
			*ptr++ = 0; *ptr++ = 0;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

// WARNING! Color palette should be in CRAM!
void PokeMini_VideoColorL2x2_8P(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint16_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = PRCColorPixels[LCDY + xk];
			*ptr++ = pix | (pix << 8);
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<(96>>2); xk++) {
			*ptr++ = 0; *ptr++ = 0;
			*ptr++ = 0; *ptr++ = 0;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_VideoColorH2x2_32(uint32_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint32_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColorH32[PRCColorPixels[LCDY + xk] * 256 + PRCColorPixelsOld[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColorH32[PRCColorPixels[LCDY + xk] * 256 + PRCColorPixelsOld[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_VideoColorH2x2_16(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint16_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColorH16[PRCColorPixels[LCDY + xk] * 256 + PRCColorPixelsOld[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColorH16[PRCColorPixels[LCDY + xk] * 256 + PRCColorPixelsOld[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
	}
}
