/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2014  JustBurn

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

TMinxLCD MinxLCD;
int LCDDirty = 0;
uint8_t *LCDData = NULL;
uint8_t *LCDPixelsD = NULL;
uint8_t *LCDPixelsA = NULL;
uint8_t *LCDPixelsAS = NULL;

const int LCDDirtyPixels[4] = {
	4, // LCDMODE_ANALOG
	2, // LCDMODE_3SHADES
	1, // LCDMODE_2SHADES
	2  // LCDMODE_COLORS
};

//
// Functions
//

int MinxLCD_Create(void)
{
	// Create LCD memory
	LCDData = (uint8_t *)malloc(256*9);
	if (!LCDData) return 0;
	LCDPixelsD = (uint8_t *)malloc(96*64);
	if (!LCDPixelsD) return 0;
	LCDPixelsA = (uint8_t *)malloc(96*64*2);
	if (!LCDPixelsA) return 0;
	LCDPixelsAS = (uint8_t *)LCDPixelsA + 96*64;

	// Reset
	MinxLCD_Reset(1);

	return 1;
}

void MinxLCD_Destroy(void)
{
	if (LCDData) {
		free(LCDData);
		LCDData = NULL;
	}
	if (LCDPixelsD) {
		free(LCDPixelsD);
		LCDPixelsD = NULL;
	}
	if (LCDPixelsA) {
		free(LCDPixelsA);
		LCDPixelsA = NULL;
	}
}

void MinxLCD_Reset(int hardreset)
{
	// Clean up memory
	memset(LCDData, 0x00, 256*9);
	memset(LCDPixelsD, 0x00, 96*64);
	memset(LCDPixelsA, 0x00, 96*64*2);

	// Initialize State
	memset((void *)&MinxLCD, 0, sizeof(TMinxLCD));

	// Initialize variables
	MinxLCD_SetContrast(0x1F);
}

int MinxLCD_LoadState(FILE *fi, uint32_t bsize)
{
	POKELOADSS_START(256*9 + 96*64 + 96*64 + 64);
	POKELOADSS_A(LCDData, 256*9);
	POKELOADSS_A(LCDPixelsD, 96*64);
	POKELOADSS_A(LCDPixelsA, 96*64);
	POKELOADSS_32(MinxLCD.Pixel0Intensity);
	POKELOADSS_32(MinxLCD.Pixel1Intensity);
	POKELOADSS_8(MinxLCD.Column);
	POKELOADSS_8(MinxLCD.StartLine);
	POKELOADSS_8(MinxLCD.SetContrast);
	POKELOADSS_8(MinxLCD.Contrast);
	POKELOADSS_8(MinxLCD.SegmentDir);
	POKELOADSS_8(MinxLCD.MaxContrast);
	POKELOADSS_8(MinxLCD.SetAllPix);
	POKELOADSS_8(MinxLCD.InvAllPix);
	POKELOADSS_8(MinxLCD.DisplayOn);
	POKELOADSS_8(MinxLCD.Page);
	POKELOADSS_8(MinxLCD.RowOrder);
	POKELOADSS_8(MinxLCD.ReadModifyMode);
	POKELOADSS_8(MinxLCD.RequireDummyR);
	POKELOADSS_8(MinxLCD.RMWColumn);
	POKELOADSS_X(42);
	POKELOADSS_END(256*9 + 96*64 + 96*64 + 64);
	return 1;
}

int MinxLCD_SaveState(FILE *fi)
{
	POKESAVESS_START(256*9 + 96*64 + 96*64 + 64);
	POKESAVESS_A(LCDData, 256*9);
	POKESAVESS_A(LCDPixelsD, 96*64);
	POKESAVESS_A(LCDPixelsA, 96*64);
	POKESAVESS_32(MinxLCD.Pixel0Intensity);
	POKESAVESS_32(MinxLCD.Pixel1Intensity);
	POKESAVESS_8(MinxLCD.Column);
	POKESAVESS_8(MinxLCD.StartLine);
	POKESAVESS_8(MinxLCD.SetContrast);
	POKESAVESS_8(MinxLCD.Contrast);
	POKESAVESS_8(MinxLCD.SegmentDir);
	POKESAVESS_8(MinxLCD.MaxContrast);
	POKESAVESS_8(MinxLCD.SetAllPix);
	POKESAVESS_8(MinxLCD.InvAllPix);
	POKESAVESS_8(MinxLCD.DisplayOn);
	POKESAVESS_8(MinxLCD.Page);
	POKESAVESS_8(MinxLCD.RowOrder);
	POKESAVESS_8(MinxLCD.ReadModifyMode);
	POKESAVESS_8(MinxLCD.RequireDummyR);
	POKESAVESS_8(MinxLCD.RMWColumn);
	POKESAVESS_X(42);
	POKESAVESS_END(256*9 + 96*64 + 96*64 + 64);
}

uint8_t MinxLCD_ReadReg(int cpu, uint8_t reg)
{
	// 0xFE to 0xFF
	switch(reg) {
		case 0xFE: // Read from LCD with Control Activated
			return MinxLCD_LCDReadCtrl(cpu);
		case 0xFF: // Read from LCD with Control Desactivated
			return MinxLCD_LCDRead(cpu);
		default:   // Unused
			return 0x00;
	}
}

void MinxLCD_WriteReg(int cpu, uint8_t reg, uint8_t val)
{
	// 0xFE to 0xFF
	switch(reg) {
		case 0xFE: // Write to LCD with Control Activated
			MinxLCD_LCDWriteCtrl(val);
			return;
		case 0xFF: // Write to LCD with Control Desactivated
			MinxLCD_LCDWrite(val);
			return;
	}
}

#define DECAY_A_OFF	64
#define DECAY_ARISE	50
#define DECAY_AFALL	30
#define DECAY_L_OFF	16
#define DECAY_LRISE	4
#define DECAY_LFALL	2

void MinxLCD_DecayRefreshOld(void)
{
	int i, amt;
	if (MinxLCD.DisplayOn) {
		for (i=0; i<96*64; i++) {
			if (LCDPixelsD[i]) {
				amt = Interpolate8(LCDPixelsA[i], MinxLCD.Pixel1Intensity, DECAY_ARISE) + DECAY_LRISE;
				if (amt > MinxLCD.Pixel1Intensity) amt = MinxLCD.Pixel1Intensity;
			} else {
				amt = Interpolate8(LCDPixelsA[i], MinxLCD.Pixel0Intensity, DECAY_AFALL) - DECAY_LFALL;
				if (amt < MinxLCD.Pixel0Intensity) amt = MinxLCD.Pixel0Intensity;
			}
			LCDPixelsA[i] = amt;
		}
	} else {
		for (i=0; i<96*64; i++) {
			amt = Interpolate8(LCDPixelsA[i], 0, DECAY_A_OFF) - DECAY_L_OFF;
			if (amt < MinxLCD.Pixel0Intensity) amt = MinxLCD.Pixel0Intensity;
			LCDPixelsA[i] = amt;
		}
	}
}

static const uint8_t BitsActives[256] = {
	0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4,
	1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
	1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
	2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
	1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
	2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
	2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
	3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7,
	1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
	2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
	2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
	3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7,
	2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
	3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7,
	3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7,
	4, 5, 5, 6, 5, 6, 6, 7, 5, 6, 6, 7, 6, 7, 7, 8
};

void MinxLCD_DecayRefresh(void)
{
	int i, level;
	uint8_t sh;
	// This is tuned for 5 shades
	if (MinxLCD.DisplayOn) {
		for (i=0; i<96*64; i++) {
			sh = (LCDPixelsD[i] ? 0x08 : 0x00) | (LCDPixelsAS[i] >> 1);
			LCDPixelsAS[i] = sh;
			level = BitsActives[sh];
			LCDPixelsA[i] = (MinxLCD.Pixel0Intensity * (4 - level) + MinxLCD.Pixel1Intensity * level) >> 2;
		}
	} else {
		for (i=0; i<96*64; i++) {
			sh = (LCDPixelsAS[i] >> 1);
			LCDPixelsAS[i] = sh;
			level = BitsActives[sh];
			LCDPixelsA[i] = (MinxLCD.Pixel0Intensity * (4 - level) + MinxLCD.Pixel1Intensity * level) >> 2;
		}
	}
}

void MinxLCD_Render(void)
{
	uint8_t pixel;
	int xC, yC, yP;

	if (MinxLCD.DisplayOn) {
		for (yC=0; yC<64; yC++) {
			yP = (yC + MinxLCD.StartLine) & 63;
			if (MinxLCD.RowOrder) yP = 63 - yP;
			for (xC=0; xC<96; xC++) {
				pixel = (LCDData[((yP >> 3) * 256) + xC] >> (yP & 7)) & 1;
				LCDPixelsD[(yC * 96) + xC] = (pixel ^ MinxLCD.InvAllPix) | MinxLCD.SetAllPix;
			}
		}
	} else for (yC=0; yC<96*64; yC++) LCDPixelsD[yC] = 0;
}

uint8_t MinxLCD_LCDReadCtrl(int cpu)
{
	uint8_t data;
	if (MinxLCD.SetContrast) {
		MinxLCD.SetContrast = 0;
		// Contrast query, cause incorrect value?
		MinxLCD_SetContrast(0x3F);
		data = 0;
	} else {
		// Get status
		data = 0x40 | (MinxLCD.DisplayOn ? 0x20 : 0x00);
	}
	return data;
}

uint8_t MinxLCD_LCDRead(int cpu)
{
	static uint8_t data = 0x40;
	if (MinxLCD.SetContrast) {
		MinxLCD.SetContrast = 0;
		// Contrast query, cause incorrect value?
		MinxLCD_SetContrast(0x3F);
		data = 0;
	} else {
		// Get pixel
		if (!MinxLCD.RequireDummyR && cpu) {
			if (MinxLCD.SegmentDir) {
				data = LCDData[131 - MinxLCD.Column + (MinxLCD.Page << 8)];
			} else {
				data = LCDData[MinxLCD.Column + (MinxLCD.Page << 8)];
			}
			if (MinxLCD.Page >= 8) data &= 0x01;
			if (!MinxLCD.ReadModifyMode) {
				MinxLCD.Column++;
				if (MinxLCD.Column > 131) MinxLCD.Column = 131;
				MinxLCD.RequireDummyR = 1;
			}
		} else MinxLCD.RequireDummyR = 0;
	}
	return data;
}

void MinxLCD_LCDWriteCtrl(uint8_t data)
{
	if (MinxLCD.SetContrast) {
		MinxLCD.SetContrast = 0;
		MinxLCD_SetContrast(data & 0x3F);
		return;
	}
	switch(data) {
		case 0x00: case 0x01: case 0x02: case 0x03: case 0x04: case 0x05: case 0x06: case 0x07:
		case 0x08: case 0x09: case 0x0A: case 0x0B: case 0x0C: case 0x0D: case 0x0E: case 0x0F:
			if (!MinxLCD.ReadModifyMode) {
				MinxLCD.Column = (MinxLCD.Column & 0xF0) | (data & 0x0F);
				MinxLCD.RequireDummyR = 1;
			}
			return;
		case 0x10: case 0x11: case 0x12: case 0x13: case 0x14: case 0x15: case 0x16: case 0x17:
		case 0x18: case 0x19: case 0x1A: case 0x1B: case 0x1C: case 0x1D: case 0x1E: case 0x1F:
			if (!MinxLCD.ReadModifyMode) {
				MinxLCD.Column = (MinxLCD.Column & 0x0F) | ((data & 0x0F) << 4);
				MinxLCD.RequireDummyR = 1;
			}
			return;
		case 0x20: case 0x21: case 0x22: case 0x23: case 0x24: case 0x25: case 0x26: case 0x27:
			// Do nothing?
			return;
		case 0x28: case 0x29: case 0x2A: case 0x2B: case 0x2C: case 0x2D: case 0x2E: case 0x2F:
			// Modify LCD voltage? (2F Default)
			// 0x28 = Blank
			// 0x29 = Blank
			// 0x2A = Blue screen then blank
			// 0x2B = Blank
			// 0x2C = Blank
			// 0x2D = Blank
			// 0x2E = Blue screen (overpower?)
			// 0x2F = Normal
			// User shouldn't mess with this ones as may damage the LCD
			return;
		case 0x30: case 0x31: case 0x32: case 0x33: case 0x34: case 0x35: case 0x36: case 0x37:
		case 0x38: case 0x39: case 0x3A: case 0x3B: case 0x3C: case 0x3D: case 0x3E: case 0x3F:
			// Do nothing?
			return;
		case 0x40: case 0x41: case 0x42: case 0x43: case 0x44: case 0x45: case 0x46: case 0x47:
		case 0x48: case 0x49: case 0x4A: case 0x4B: case 0x4C: case 0x4D: case 0x4E: case 0x4F:
		case 0x50: case 0x51: case 0x52: case 0x53: case 0x54: case 0x55: case 0x56: case 0x57:
		case 0x58: case 0x59: case 0x5A: case 0x5B: case 0x5C: case 0x5D: case 0x5E: case 0x5F:
		case 0x60: case 0x61: case 0x62: case 0x63: case 0x64: case 0x65: case 0x66: case 0x67:
		case 0x68: case 0x69: case 0x6A: case 0x6B: case 0x6C: case 0x6D: case 0x6E: case 0x6F:
		case 0x70: case 0x71: case 0x72: case 0x73: case 0x74: case 0x75: case 0x76: case 0x77:
		case 0x78: case 0x79: case 0x7A: case 0x7B: case 0x7C: case 0x7D: case 0x7E: case 0x7F:
			// Set starting LCD scanline (cause warp around)
			MinxLCD.StartLine = data - 0x40;
			LCDDirty = MINX_DIRTYSCR;
			return;
		case 0x80:
			// Do nothing?
			return;
		case 0x81:
			// Set contrast at the next write
			MinxLCD.SetContrast = 1;
			return;
		case 0x82: case 0x83: case 0x84: case 0x85: case 0x86: case 0x87:
		case 0x88: case 0x89: case 0x8A: case 0x8B: case 0x8C: case 0x8D: case 0x8E: case 0x8F:
		case 0x90: case 0x91: case 0x92: case 0x93: case 0x94: case 0x95: case 0x96: case 0x97:
		case 0x98: case 0x99: case 0x9A: case 0x9B: case 0x9C: case 0x9D: case 0x9E: case 0x9F:
			// Do nothing?
			return;
		case 0xA0:
			// Segment Driver Direction Select: Normal
			MinxLCD.SegmentDir = 0;
			LCDDirty = MINX_DIRTYSCR;
			return;
		case 0xA1:
			// Segment Driver Direction Select: Reverse
			MinxLCD.SegmentDir = 1;
			LCDDirty = MINX_DIRTYSCR;
			return;
		case 0xA2:
			// Max Contrast: Disable
			MinxLCD.MaxContrast = 0;
			MinxLCD_SetContrast(MinxLCD.Contrast);
			return;
		case 0xA3:
			// Max Contrast: Enable
			MinxLCD.MaxContrast = 1;
			MinxLCD_SetContrast(MinxLCD.Contrast);
			return;
		case 0xA4:
			// Set All Pixels: Disable
			MinxLCD.SetAllPix = 0;
			LCDDirty = MINX_DIRTYSCR;
			return;
		case 0xA5:
			// Set All Pixels: Enable
			MinxLCD.SetAllPix = 1;
			LCDDirty = MINX_DIRTYSCR;
			return;
		case 0xA6:
			// Invert All Pixels: Disable
			MinxLCD.InvAllPix = 0;
			LCDDirty = MINX_DIRTYSCR;
			return;
		case 0xA7:
			// Invert All Pixels: Enable
			MinxLCD.InvAllPix = 1;
			LCDDirty = MINX_DIRTYSCR;
			return;
		case 0xA8: case 0xA9: case 0xAA: case 0xAB:
			// Do nothing!?
			return;
		case 0xAC: case 0xAD:
			// User shouldn't mess with this ones as may damage the LCD
			return;
		case 0xAE:
			// Display Off
			MinxLCD.DisplayOn = 0;
			LCDDirty = MINX_DIRTYSCR;
			return;
		case 0xAF:
			// Display On
			MinxLCD.DisplayOn = 1;
			LCDDirty = MINX_DIRTYSCR;
			return;
		case 0xB0: case 0xB1: case 0xB2: case 0xB3: case 0xB4: case 0xB5: case 0xB6: case 0xB7:
		case 0xB8:
			// Set page (0-8, each page is 8px high)
			MinxLCD.Page = data & 15;
			return;
		case 0xB9: case 0xBA: case 0xBB: case 0xBC: case 0xBD: case 0xBE: case 0xBF:
			// uh... do nothing?
			return;
		case 0xC0: case 0xC1: case 0xC2: case 0xC3: case 0xC4: case 0xC5: case 0xC6: case 0xC7:
			// Display rows from top to bottom as 0 to 63
			MinxLCD.RowOrder = 0;
			LCDDirty = MINX_DIRTYSCR;
			return;
		case 0xC8: case 0xC9: case 0xCA: case 0xCB: case 0xCC: case 0xCD: case 0xCE: case 0xCF:
			// Display rows from top to bottom as 63 to 0
			MinxLCD.RowOrder = 1;
			LCDDirty = MINX_DIRTYSCR;
			return;
		case 0xD0: case 0xD1: case 0xD2: case 0xD3: case 0xD4: case 0xD5: case 0xD6: case 0xD7:
		case 0xD8: case 0xD9: case 0xDA: case 0xDB: case 0xDC: case 0xDD: case 0xDE: case 0xDF:
			// Do nothing?
			return;
		case 0xE0:
			// Start "Read Modify Write"
			MinxLCD.ReadModifyMode = 1;
			MinxLCD.RMWColumn = MinxLCD.Column;
			return;
		case 0xE2:
			// Reset
			MinxLCD.SetContrast = 0;
			MinxLCD_SetContrast(0x20);
			MinxLCD.Column = 0;
			MinxLCD.StartLine = 0;
			MinxLCD.SegmentDir = 0;
			MinxLCD.MaxContrast = 0;
			MinxLCD.SetAllPix = 0;
			MinxLCD.InvAllPix = 0;
			MinxLCD.DisplayOn = 0;
			MinxLCD.Page = 0;
			MinxLCD.RowOrder = 0;
			MinxLCD.ReadModifyMode = 0;
			MinxLCD.RequireDummyR = 1;
			MinxLCD.RMWColumn = 0;
			return;
		case 0xE3:
			// No operation
			return;
		case 0xEE:
			// End "Read Modify Write"
			MinxLCD.ReadModifyMode = 0;
			MinxLCD.Column = MinxLCD.RMWColumn;
			return;
		case 0xE1: case 0xE4: case 0xE5: case 0xE6: case 0xE7:
		case 0xE8: case 0xE9: case 0xEA: case 0xEB: case 0xEC: case 0xED: case 0xEF:
			// User shouldn't mess with this ones as may damage the LCD
			return;
		case 0xF0: case 0xF1: case 0xF2: case 0xF3: case 0xF4: case 0xF5: case 0xF6: case 0xF7:
			// 0xF1 and 0xF5 freeze LCD and cause malfunction (need to power off the device to restore)
			// User shouldn't mess with this ones as may damage the LCD
			return;
		case 0xF8: case 0xF9: case 0xFA: case 0xFB: case 0xFC: case 0xFD: case 0xFE: case 0xFF:
			// Contrast voltage control, FC = Default
			// User shouldn't mess with this ones as may damage the LCD
			return;
	}
}

void MinxLCD_LCDWrite(uint8_t data)
{
	int addr;
	if (MinxLCD.SetContrast) {
		MinxLCD.SetContrast = 0;
		// Set contrast
		MinxLCD_SetContrast(data & 0x3F);
	} else {
		// Set pixel
		if (MinxLCD.SegmentDir) {
			addr = 131 - MinxLCD.Column + (MinxLCD.Page << 8);
		} else {
			addr = MinxLCD.Column + (MinxLCD.Page << 8);
		}
		LCDData[addr] = data;
		if (PRCColorMap) MinxColorPRC_WriteLCD(addr, data);
		MinxLCD.Column++;
		if (MinxLCD.Column > 131) MinxLCD.Column = 131;
		MinxLCD.RequireDummyR = 1;
		LCDDirty = LCDDirtyPixels[CommandLine.lcdmode];
	}
}

void MinxLCD_LCDWritefb(uint8_t *fb)
{
	int i;
	uint8_t *dst = (uint8_t *)LCDData, pages = 8;
	if (MinxLCD.SegmentDir) {
		while (pages--) {
			for (i=0; i<96; i++) dst[131-i] = fb[i];
			dst += 256; fb += 96;
		}
	} else {
		while (pages--) {
			memcpy(dst, fb, 96);
			dst += 256; fb += 96;
		}
	}
	MinxLCD.Page = 7;
	MinxLCD.Column = 96;
	MinxLCD.RequireDummyR = 1;
	MinxLCD.ReadModifyMode = 0;
	LCDDirty = LCDDirtyPixels[CommandLine.lcdmode];
}

// Contrast level on light and dark pixel
const uint8_t MinxLCD_ContrastLvl[64][2] = {
	{  0,   4},	//  0 (0x00)
	{  0,   4},	//  1 (0x01)
	{  0,   4},	//  2 (0x02)
	{  0,   4},	//  3 (0x03)
	{  0,   6},	//  4 (0x04)
	{  0,  11},	//  5 (0x05)
	{  0,  17},	//  6 (0x06)
	{  0,  24},	//  7 (0x07)
	{  0,  31},	//  8 (0x08)
	{  0,  40},	//  9 (0x09)
	{  0,  48},	// 10 (0x0A)
	{  0,  57},	// 11 (0x0B)
	{  0,  67},	// 12 (0x0C)
	{  0,  77},	// 13 (0x0D)
	{  0,  88},	// 14 (0x0E)
	{  0,  99},	// 15 (0x0F)
	{  0, 110},	// 16 (0x10)
	{  0, 122},	// 17 (0x11)
	{  0, 133},	// 18 (0x12)
	{  0, 146},	// 19 (0x13)
	{  0, 158},	// 20 (0x14)
	{  0, 171},	// 21 (0x15)
	{  0, 184},	// 22 (0x16)
	{  0, 198},	// 23 (0x17)
	{  0, 212},	// 24 (0x18)
	{  0, 226},	// 25 (0x19)
	{  0, 240},	// 26 (0x1A)
	{  0, 255},	// 27 (0x1B)
	{  2, 255},	// 28 (0x1C)
	{  5, 255},	// 29 (0x1D)
	{ 10, 255},	// 30 (0x1E)
	{ 15, 255},	// 31 (0x1F)
	{ 21, 255},	// 32 (0x20)
	{ 27, 255},	// 33 (0x21)
	{ 34, 255},	// 34 (0x22)
	{ 41, 255},	// 35 (0x23)
	{ 48, 255},	// 36 (0x24)
	{ 56, 255},	// 37 (0x25)
	{ 64, 255},	// 38 (0x26)
	{ 73, 255},	// 39 (0x27)
	{ 81, 255},	// 40 (0x28)
	{ 90, 255},	// 41 (0x29)
	{100, 255},	// 42 (0x2A)
	{109, 255},	// 43 (0x2B)
	{119, 255},	// 44 (0x2C)
	{129, 255},	// 45 (0x2D)
	{139, 255},	// 46 (0x2E)
	{149, 255},	// 47 (0x2F)
	{160, 255},	// 48 (0x30)
	{171, 255},	// 49 (0x31)
	{182, 255},	// 50 (0x32)
	{193, 255},	// 51 (0x33)
	{204, 255},	// 52 (0x34)
	{216, 255},	// 53 (0x35)
	{228, 255},	// 54 (0x36)
	{240, 255},	// 55 (0x37)
	{240, 255},	// 56 (0x38)
	{240, 255},	// 57 (0x39)
	{240, 255},	// 58 (0x3A)
	{240, 255},	// 59 (0x3B)
	{240, 255},	// 60 (0x3C)
	{240, 255},	// 61 (0x3D)
	{240, 255},	// 62 (0x3E)
	{240, 255},	// 63 (0x3F)
};

void MinxLCD_SetContrast(uint8_t value)
{
	MinxLCD.Contrast = value & 0x3F;
	if (MinxLCD.MaxContrast) {
		MinxLCD.Pixel0Intensity = 240;
		MinxLCD.Pixel1Intensity = 255;
	} else {
		MinxLCD.Pixel0Intensity = MinxLCD_ContrastLvl[MinxLCD.Contrast][0];
		MinxLCD.Pixel1Intensity = MinxLCD_ContrastLvl[MinxLCD.Contrast][1];
	}
	LCDDirty = MINX_DIRTYSCR;
}
