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
#include "Video.h"
#include "Video_x1.h"

const TPokeMini_VideoSpec PokeMini_Video1x1 = {
	1, 1,
	PokeMini_GetVideo1x1_16,
	PokeMini_GetVideo1x1_32
};

TPokeMini_DrawVideo32 PokeMini_GetVideo1x1_32(int filter, int lcdmode)
{
	switch (lcdmode) {
		case 3: if (filter == PokeMini_Matrix) return (VidEnableHighcolor) ? PokeMini_VideoColorH1x1_32 : PokeMini_VideoColor1x1_32;
			else return PokeMini_VideoColor1x1_32;
		case 2: return PokeMini_Video2None1x1_32;
		case 1: return PokeMini_Video3None1x1_32;
		default: return PokeMini_VideoANone1x1_32;
	}
}

TPokeMini_DrawVideo16 PokeMini_GetVideo1x1_16(int filter, int lcdmode)
{
	switch (lcdmode) {
		case 3: if (filter == PokeMini_Matrix) return (VidEnableHighcolor) ? PokeMini_VideoColorH1x1_16 : PokeMini_VideoColor1x1_16;
			else return PokeMini_VideoColor1x1_16;
		case 2: return PokeMini_Video2None1x1_16;
		case 1: return PokeMini_Video3None1x1_16;
		default: return PokeMini_VideoANone1x1_16;
	}
}

void PokeMini_VideoANone1x1_32(uint32_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint32_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalette32[LCDPixelsA[LCDY + xk]];
			*ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_VideoANone1x1_16(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint16_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalette16[LCDPixelsA[LCDY + xk]];
			*ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_Video3None1x1_32(uint32_t *screen, int pitchW)
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
			*ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_Video3None1x1_16(uint16_t *screen, int pitchW)
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
			*ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_Video2None1x1_32(uint32_t *screen, int pitchW)
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
			*ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_Video2None1x1_16(uint16_t *screen, int pitchW)
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
			*ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_VideoColor1x1_32(uint32_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint32_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColor32[PRCColorPixels[LCDY + xk]];
			*ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_VideoColor1x1_16(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint16_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColor16[PRCColorPixels[LCDY + xk]];
			*ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_VideoColorH1x1_32(uint32_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint32_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColorH32[PRCColorPixels[LCDY + xk] * 256 + PRCColorPixelsOld[LCDY + xk]];
			*ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
	}
}

void PokeMini_VideoColorH1x1_16(uint16_t *screen, int pitchW)
{
	int xk, yk, LCDY;
	uint16_t *ptr, pix;

	LCDY = 0;
	for (yk=0; yk<64; yk++) {
		ptr = screen;
		for (xk=0; xk<96; xk++) {
			pix = VidPalColorH16[PRCColorPixels[LCDY + xk] * 256 + PRCColorPixelsOld[LCDY + xk]];
			*ptr++ = pix;
		}
		screen += pitchW;
		LCDY += 96;
	}
}
