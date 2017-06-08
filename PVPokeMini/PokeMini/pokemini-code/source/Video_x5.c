/*
  PokeMini - Pok�mon-Mini Emulator
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
#include "Video_x5.h"

const TPokeMini_VideoSpec PokeMini_Video5x5 = {
	5, 5,
	PokeMini_GetVideo5x5_16,
	PokeMini_GetVideo5x5_32
};

const int LCDMask5x5[5*5] = {
	240, 256, 256, 240, 128,
	256, 256, 256, 256, 160,
	256, 256, 256, 256, 160,
	240, 256, 256, 240, 192,
	128, 160, 160, 192, 160
};

TPokeMini_DrawVideo32 PokeMini_GetVideo5x5_32(int filter, int lcdmode)
{
	if (filter == PokeMini_Scanline) {
		switch (lcdmode) {
			case 3: return PokeMini_VideoColorL5x5_32;
			case 2: return PokeMini_Video2ScanLine5x5_32;
			case 1: return PokeMini_Video3ScanLine5x5_32;
			default: return PokeMini_VideoAScanLine5x5_32;
		}
	} else if (filter == PokeMini_Matrix) {
		switch (lcdmode) {
			case 3: return (VidEnableHighcolor) ? PokeMini_VideoColorH5x5_32 : PokeMini_VideoColor5x5_32;
			case 2: return PokeMini_Video2Matrix5x5_32;
			case 1: return PokeMini_Video3Matrix5x5_32;
			default: return PokeMini_VideoAMatrix5x5_32;
		}
	} else {
		switch (lcdmode) {
			case 3: return PokeMini_VideoColor5x5_32;
			case 2: return PokeMini_Video2None5x5_32;
			case 1: return PokeMini_Video3None5x5_32;
			default: return PokeMini_VideoANone5x5_32;
		}
	}
}

TPokeMini_DrawVideo16 PokeMini_GetVideo5x5_16(int filter, int lcdmode)
{
	if (filter == PokeMini_Scanline) {
		switch (lcdmode) {
			case 3: return PokeMini_VideoColorL5x5_16;
			case 2: return PokeMini_Video2ScanLine5x5_16;
			case 1: return PokeMini_Video3ScanLine5x5_16;
			default: return PokeMini_VideoAScanLine5x5_16;
		}
	} else if (filter == PokeMini_Matrix) {
		switch (lcdmode) {
			case 3: return (VidEnableHighcolor) ? PokeMini_VideoColorH5x5_16 : PokeMini_VideoColor5x5_16;
			case 2: return PokeMini_Video2Matrix5x5_16;
			case 1: return PokeMini_Video3Matrix5x5_16;
			default: return PokeMini_VideoAMatrix5x5_16;
		}
	} else {
		switch (lcdmode) {
			case 3: return PokeMini_VideoColor5x5_16;
			case 2: return PokeMini_Video2None5x5_16;
			case 1: return PokeMini_Video3None5x5_16;
			default: return PokeMini_VideoANone5x5_16;
		}
	}
}

void PokeMini_VideoAScanLine5x5_32(uint32_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint32_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<32; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalette32[LCDPixelsA[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*4);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalette32[LCDPixelsA[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*4);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalette32[LCDPixelsA[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
		memset(screen, 0, 480*4);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalette32[LCDPixelsA[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*4);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalette32[LCDPixelsA[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*4);
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_VideoAScanLine5x5_16(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint16_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<32; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalette16[LCDPixelsA[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*2);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalette16[LCDPixelsA[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*2);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalette16[LCDPixelsA[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
		memset(screen, 0, 480*2);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalette16[LCDPixelsA[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*2);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalette16[LCDPixelsA[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*2);
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_Video3ScanLine5x5_32(uint32_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint32_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<32; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: pix = VidPalette32[MinxLCD.Pixel1Intensity]; break;
				case 1: pix = VidPalette32[(MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1]; break;
				default: pix = VidPalette32[MinxLCD.Pixel0Intensity]; break;
			}
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*4);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: pix = VidPalette32[MinxLCD.Pixel1Intensity]; break;
				case 1: pix = VidPalette32[(MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1]; break;
				default: pix = VidPalette32[MinxLCD.Pixel0Intensity]; break;
			}
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*4);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: pix = VidPalette32[MinxLCD.Pixel1Intensity]; break;
				case 1: pix = VidPalette32[(MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1]; break;
				default: pix = VidPalette32[MinxLCD.Pixel0Intensity]; break;
			}
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
		memset(screen, 0, 480*4);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: pix = VidPalette32[MinxLCD.Pixel1Intensity]; break;
				case 1: pix = VidPalette32[(MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1]; break;
				default: pix = VidPalette32[MinxLCD.Pixel0Intensity]; break;
			}
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*4);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: pix = VidPalette32[MinxLCD.Pixel1Intensity]; break;
				case 1: pix = VidPalette32[(MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1]; break;
				default: pix = VidPalette32[MinxLCD.Pixel0Intensity]; break;
			}
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*4);
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_Video3ScanLine5x5_16(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint16_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<32; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: pix = VidPalette16[MinxLCD.Pixel1Intensity]; break;
				case 1: pix = VidPalette16[(MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1]; break;
				default: pix = VidPalette16[MinxLCD.Pixel0Intensity]; break;
			}
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*2);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: pix = VidPalette16[MinxLCD.Pixel1Intensity]; break;
				case 1: pix = VidPalette16[(MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1]; break;
				default: pix = VidPalette16[MinxLCD.Pixel0Intensity]; break;
			}
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*2);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: pix = VidPalette16[MinxLCD.Pixel1Intensity]; break;
				case 1: pix = VidPalette16[(MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1]; break;
				default: pix = VidPalette16[MinxLCD.Pixel0Intensity]; break;
			}
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
		memset(screen, 0, 480*2);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: pix = VidPalette16[MinxLCD.Pixel1Intensity]; break;
				case 1: pix = VidPalette16[(MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1]; break;
				default: pix = VidPalette16[MinxLCD.Pixel0Intensity]; break;
			}
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*2);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: pix = VidPalette16[MinxLCD.Pixel1Intensity]; break;
				case 1: pix = VidPalette16[(MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1]; break;
				default: pix = VidPalette16[MinxLCD.Pixel0Intensity]; break;
			}
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*2);
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_Video2ScanLine5x5_32(uint32_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint32_t *ptr, pix, pix1, pix0;

	LCDY = 0;
	pix1 = VidPalette32[MinxLCD.Pixel1Intensity];
	pix0 = VidPalette32[MinxLCD.Pixel0Intensity];
	for (yk=0; yk<32; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) pix = pix1;
			else pix = pix0;
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*4);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) pix = pix1;
			else pix = pix0;
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*4);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) pix = pix1;
			else pix = pix0;
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
		memset(screen, 0, 480*4);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) pix = pix1;
			else pix = pix0;
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*4);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) pix = pix1;
			else pix = pix0;
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*4);
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_Video2ScanLine5x5_16(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint16_t *ptr, pix, pix1, pix0;

	LCDY = 0;
	pix1 = VidPalette16[MinxLCD.Pixel1Intensity];
	pix0 = VidPalette16[MinxLCD.Pixel0Intensity];
	for (yk=0; yk<32; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) pix = pix1;
			else pix = pix0;
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*2);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) pix = pix1;
			else pix = pix0;
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*2);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) pix = pix1;
			else pix = pix0;
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
		memset(screen, 0, 480*2);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) pix = pix1;
			else pix = pix0;
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*2);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) pix = pix1;
			else pix = pix0;
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*2);
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_VideoAMatrix5x5_32(uint32_t *screen, int pitchW)
{
	int xk, yk, level, LCDY, maskH;
	uint32_t *ptr;

	LCDY = 0;
	maskH = 0;
	for (yk=0; yk<64*5; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			level = LCDPixelsA[LCDY + xk];
			*ptr++ = VidPalette32[level * LCDMask5x5[maskH] >> 8];
			*ptr++ = VidPalette32[level * LCDMask5x5[maskH+1] >> 8];
			*ptr++ = VidPalette32[level * LCDMask5x5[maskH+2] >> 8];
			*ptr++ = VidPalette32[level * LCDMask5x5[maskH+3] >> 8];
			*ptr++ = VidPalette32[level * LCDMask5x5[maskH+4] >> 8];
		}
		screen += pitchW;
		maskH += 5;
		if (maskH >= 25) {
			maskH = 0;
			LCDY += 96;
		}
	}
}

void PokeMini_VideoAMatrix5x5_16(uint16_t *screen, int pitchW)
{
	int xk, yk, level, LCDY, maskH;
	uint16_t *ptr;

	LCDY = 0;
	maskH = 0;
	for (yk=0; yk<64*5; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			level = LCDPixelsA[LCDY + xk];
			*ptr++ = VidPalette16[level * LCDMask5x5[maskH] >> 8];
			*ptr++ = VidPalette16[level * LCDMask5x5[maskH+1] >> 8];
			*ptr++ = VidPalette16[level * LCDMask5x5[maskH+2] >> 8];
			*ptr++ = VidPalette16[level * LCDMask5x5[maskH+3] >> 8];
			*ptr++ = VidPalette16[level * LCDMask5x5[maskH+4] >> 8];
		}
		screen += pitchW;
		maskH += 5;
		if (maskH >= 25) {
			maskH = 0;
			LCDY += 96;
		}
	}
}

void PokeMini_Video3Matrix5x5_32(uint32_t *screen, int pitchW)
{
	int xk, yk, level, LCDY, maskH;
	uint32_t *ptr;

	LCDY = 0;
	maskH = 0;
	for (yk=0; yk<64*5; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: level = MinxLCD.Pixel1Intensity; break;
				case 1: level = (MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1; break;
				default: level = MinxLCD.Pixel0Intensity; break;
			}
			*ptr++ = VidPalette32[level * LCDMask5x5[maskH] >> 8];
			*ptr++ = VidPalette32[level * LCDMask5x5[maskH+1] >> 8];
			*ptr++ = VidPalette32[level * LCDMask5x5[maskH+2] >> 8];
			*ptr++ = VidPalette32[level * LCDMask5x5[maskH+3] >> 8];
			*ptr++ = VidPalette32[level * LCDMask5x5[maskH+4] >> 8];
		}
		screen += pitchW;
		maskH += 5;
		if (maskH >= 25) {
			maskH = 0;
			LCDY += 96;
		}
	}
}

void PokeMini_Video3Matrix5x5_16(uint16_t *screen, int pitchW)
{
	int xk, yk, level, LCDY, maskH;
	uint16_t *ptr;

	LCDY = 0;
	maskH = 0;
	for (yk=0; yk<64*5; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: level = MinxLCD.Pixel1Intensity; break;
				case 1: level = (MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1; break;
				default: level = MinxLCD.Pixel0Intensity; break;
			}
			*ptr++ = VidPalette16[level * LCDMask5x5[maskH] >> 8];
			*ptr++ = VidPalette16[level * LCDMask5x5[maskH+1] >> 8];
			*ptr++ = VidPalette16[level * LCDMask5x5[maskH+2] >> 8];
			*ptr++ = VidPalette16[level * LCDMask5x5[maskH+3] >> 8];
			*ptr++ = VidPalette16[level * LCDMask5x5[maskH+4] >> 8];
		}
		screen += pitchW;
		maskH += 5;
		if (maskH >= 25) {
			maskH = 0;
			LCDY += 96;
		}
	}
}

void PokeMini_Video2Matrix5x5_32(uint32_t *screen, int pitchW)
{
	int xk, yk, level, LCDY, maskH;
	uint32_t *ptr;

	LCDY = 0;
	maskH = 0;
	for (yk=0; yk<64*5; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) level = MinxLCD.Pixel1Intensity;
			else level = MinxLCD.Pixel0Intensity;
			*ptr++ = VidPalette32[level * LCDMask5x5[maskH] >> 8];
			*ptr++ = VidPalette32[level * LCDMask5x5[maskH+1] >> 8];
			*ptr++ = VidPalette32[level * LCDMask5x5[maskH+2] >> 8];
			*ptr++ = VidPalette32[level * LCDMask5x5[maskH+3] >> 8];
			*ptr++ = VidPalette32[level * LCDMask5x5[maskH+4] >> 8];
		}
		screen += pitchW;
		maskH += 5;
		if (maskH >= 25) {
			maskH = 0;
			LCDY += 96;
		}
	}
}

void PokeMini_Video2Matrix5x5_16(uint16_t *screen, int pitchW)
{
	int xk, yk, level, LCDY, maskH;
	uint16_t *ptr;

	LCDY = 0;
	maskH = 0;
	for (yk=0; yk<64*5; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) level = MinxLCD.Pixel1Intensity;
			else level = MinxLCD.Pixel0Intensity;
			*ptr++ = VidPalette16[level * LCDMask5x5[maskH] >> 8];
			*ptr++ = VidPalette16[level * LCDMask5x5[maskH+1] >> 8];
			*ptr++ = VidPalette16[level * LCDMask5x5[maskH+2] >> 8];
			*ptr++ = VidPalette16[level * LCDMask5x5[maskH+3] >> 8];
			*ptr++ = VidPalette16[level * LCDMask5x5[maskH+4] >> 8];
		}
		screen += pitchW;
		maskH += 5;
		if (maskH >= 25) {
			maskH = 0;
			LCDY += 96;
		}
	}
}

void PokeMini_VideoANone5x5_32(uint32_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint32_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalette32[LCDPixelsA[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalette32[LCDPixelsA[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalette32[LCDPixelsA[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalette32[LCDPixelsA[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalette32[LCDPixelsA[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_VideoANone5x5_16(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint16_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalette16[LCDPixelsA[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalette16[LCDPixelsA[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalette16[LCDPixelsA[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalette16[LCDPixelsA[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalette16[LCDPixelsA[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_Video3None5x5_32(uint32_t *screen, int pitchW)
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
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: pix = VidPalette32[MinxLCD.Pixel1Intensity]; break;
				case 1: pix = VidPalette32[(MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1]; break;
				default: pix = VidPalette32[MinxLCD.Pixel0Intensity]; break;
			}
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: pix = VidPalette32[MinxLCD.Pixel1Intensity]; break;
				case 1: pix = VidPalette32[(MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1]; break;
				default: pix = VidPalette32[MinxLCD.Pixel0Intensity]; break;
			}
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: pix = VidPalette32[MinxLCD.Pixel1Intensity]; break;
				case 1: pix = VidPalette32[(MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1]; break;
				default: pix = VidPalette32[MinxLCD.Pixel0Intensity]; break;
			}
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: pix = VidPalette32[MinxLCD.Pixel1Intensity]; break;
				case 1: pix = VidPalette32[(MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1]; break;
				default: pix = VidPalette32[MinxLCD.Pixel0Intensity]; break;
			}
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_Video3None5x5_16(uint16_t *screen, int pitchW)
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
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: pix = VidPalette16[MinxLCD.Pixel1Intensity]; break;
				case 1: pix = VidPalette16[(MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1]; break;
				default: pix = VidPalette16[MinxLCD.Pixel0Intensity]; break;
			}
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: pix = VidPalette16[MinxLCD.Pixel1Intensity]; break;
				case 1: pix = VidPalette16[(MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1]; break;
				default: pix = VidPalette16[MinxLCD.Pixel0Intensity]; break;
			}
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: pix = VidPalette16[MinxLCD.Pixel1Intensity]; break;
				case 1: pix = VidPalette16[(MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1]; break;
				default: pix = VidPalette16[MinxLCD.Pixel0Intensity]; break;
			}
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			switch (LCDPixelsD[LCDY + xk] + LCDPixelsA[LCDY + xk]) {
				case 2: pix = VidPalette16[MinxLCD.Pixel1Intensity]; break;
				case 1: pix = VidPalette16[(MinxLCD.Pixel0Intensity + MinxLCD.Pixel1Intensity) >> 1]; break;
				default: pix = VidPalette16[MinxLCD.Pixel0Intensity]; break;
			}
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_Video2None5x5_32(uint32_t *screen, int pitchW)
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
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) pix = pix1;
			else pix = pix0;
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) pix = pix1;
			else pix = pix0;
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) pix = pix1;
			else pix = pix0;
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) pix = pix1;
			else pix = pix0;
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_Video2None5x5_16(uint16_t *screen, int pitchW)
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
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) pix = pix1;
			else pix = pix0;
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) pix = pix1;
			else pix = pix0;
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) pix = pix1;
			else pix = pix0;
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			if (LCDPixelsD[LCDY + xk]) pix = pix1;
			else pix = pix0;
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_VideoColor5x5_32(uint32_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint32_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColor32[PRCColorPixels[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColor32[PRCColorPixels[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColor32[PRCColorPixels[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColor32[PRCColorPixels[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColor32[PRCColorPixels[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_VideoColor5x5_16(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint16_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColor16[PRCColorPixels[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColor16[PRCColorPixels[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColor16[PRCColorPixels[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColor16[PRCColorPixels[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColor16[PRCColorPixels[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_VideoColorL5x5_32(uint32_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint32_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<32; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColor32[PRCColorPixels[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*4);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColor32[PRCColorPixels[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*4);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColor32[PRCColorPixels[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
		memset(screen, 0, 480*4);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColor32[PRCColorPixels[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*4);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColor32[PRCColorPixels[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*4);
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_VideoColorL5x5_16(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint16_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<32; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColor16[PRCColorPixels[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*2);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColor16[PRCColorPixels[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*2);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColor16[PRCColorPixels[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
		memset(screen, 0, 480*2);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColor16[PRCColorPixels[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*2);
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColor16[PRCColorPixels[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		memset(screen, 0, 480*2);
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_VideoColorH5x5_32(uint32_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint32_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColorH32[PRCColorPixels[LCDY + xk] * 256 + PRCColorPixelsOld[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColorH32[PRCColorPixels[LCDY + xk] * 256 + PRCColorPixelsOld[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColorH32[PRCColorPixels[LCDY + xk] * 256 + PRCColorPixelsOld[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColorH32[PRCColorPixels[LCDY + xk] * 256 + PRCColorPixelsOld[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColorH32[PRCColorPixels[LCDY + xk] * 256 + PRCColorPixelsOld[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_VideoColorH5x5_16(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint16_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColorH16[PRCColorPixels[LCDY + xk] * 256 + PRCColorPixelsOld[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColorH16[PRCColorPixels[LCDY + xk] * 256 + PRCColorPixelsOld[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColorH16[PRCColorPixels[LCDY + xk] * 256 + PRCColorPixelsOld[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColorH16[PRCColorPixels[LCDY + xk] * 256 + PRCColorPixelsOld[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColorH16[PRCColorPixels[LCDY + xk] * 256 + PRCColorPixelsOld[LCDY + xk]];
			*ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix; *ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
	}
}
