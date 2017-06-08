/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2015  JustBurn

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

TMinxPRC MinxPRC;
int PRCAllowStall = 1;	// Allow stall CPU?
int StallCPU = 0;	// Stall CPU output flag
int PRCRenderBD = 0;	// Render backdrop? (Background overrides backdrop)
int PRCRenderBG = 1;	// Render background?
int PRCRenderSpr = 1;	// Render sprites?

const uint8_t PRCInvertBit[256] = { // Invert Bit table
	0x00, 0x80, 0x40, 0xC0, 0x20, 0xA0, 0x60, 0xE0, 0x10, 0x90, 0x50, 0xD0, 0x30, 0xB0, 0x70, 0xF0,
	0x08, 0x88, 0x48, 0xC8, 0x28, 0xA8, 0x68, 0xE8, 0x18, 0x98, 0x58, 0xD8, 0x38, 0xB8, 0x78, 0xF8,
	0x04, 0x84, 0x44, 0xC4, 0x24, 0xA4, 0x64, 0xE4, 0x14, 0x94, 0x54, 0xD4, 0x34, 0xB4, 0x74, 0xF4,
	0x0C, 0x8C, 0x4C, 0xCC, 0x2C, 0xAC, 0x6C, 0xEC, 0x1C, 0x9C, 0x5C, 0xDC, 0x3C, 0xBC, 0x7C, 0xFC,
	0x02, 0x82, 0x42, 0xC2, 0x22, 0xA2, 0x62, 0xE2, 0x12, 0x92, 0x52, 0xD2, 0x32, 0xB2, 0x72, 0xF2,
	0x0A, 0x8A, 0x4A, 0xCA, 0x2A, 0xAA, 0x6A, 0xEA, 0x1A, 0x9A, 0x5A, 0xDA, 0x3A, 0xBA, 0x7A, 0xFA,
	0x06, 0x86, 0x46, 0xC6, 0x26, 0xA6, 0x66, 0xE6, 0x16, 0x96, 0x56, 0xD6, 0x36, 0xB6, 0x76, 0xF6,
	0x0E, 0x8E, 0x4E, 0xCE, 0x2E, 0xAE, 0x6E, 0xEE, 0x1E, 0x9E, 0x5E, 0xDE, 0x3E, 0xBE, 0x7E, 0xFE,
	0x01, 0x81, 0x41, 0xC1, 0x21, 0xA1, 0x61, 0xE1, 0x11, 0x91, 0x51, 0xD1, 0x31, 0xB1, 0x71, 0xF1,
	0x09, 0x89, 0x49, 0xC9, 0x29, 0xA9, 0x69, 0xE9, 0x19, 0x99, 0x59, 0xD9, 0x39, 0xB9, 0x79, 0xF9,
	0x05, 0x85, 0x45, 0xC5, 0x25, 0xA5, 0x65, 0xE5, 0x15, 0x95, 0x55, 0xD5, 0x35, 0xB5, 0x75, 0xF5,
	0x0D, 0x8D, 0x4D, 0xCD, 0x2D, 0xAD, 0x6D, 0xED, 0x1D, 0x9D, 0x5D, 0xDD, 0x3D, 0xBD, 0x7D, 0xFD,
	0x03, 0x83, 0x43, 0xC3, 0x23, 0xA3, 0x63, 0xE3, 0x13, 0x93, 0x53, 0xD3, 0x33, 0xB3, 0x73, 0xF3,
	0x0B, 0x8B, 0x4B, 0xCB, 0x2B, 0xAB, 0x6B, 0xEB, 0x1B, 0x9B, 0x5B, 0xDB, 0x3B, 0xBB, 0x7B, 0xFB,
	0x07, 0x87, 0x47, 0xC7, 0x27, 0xA7, 0x67, 0xE7, 0x17, 0x97, 0x57, 0xD7, 0x37, 0xB7, 0x77, 0xF7,
	0x0F, 0x8F, 0x4F, 0xCF, 0x2F, 0xAF, 0x6F, 0xEF, 0x1F, 0x9F, 0x5F, 0xDF, 0x3F, 0xBF, 0x7F, 0xFF
};

#ifdef PERFORMANCE
int StallCycles = 64;	// Stall CPU cycles
#else
int StallCycles = 32;	// Stall CPU cycles
#endif

TMinxPRC_Render MinxPRC_Render = MinxPRC_Render_Mono;

//
// Functions
//

int MinxPRC_Create(void)
{
	// Reset
	MinxPRC_Reset(1);

	return 1;
}

void MinxPRC_Destroy(void)
{
}

void MinxPRC_Reset(int hardreset)
{
	// Initialize State
	memset((void *)&MinxPRC, 0, sizeof(TMinxPRC));

	// Initialize variables
	StallCPU = 0;
	MinxPRC.PRCRateMatch = 0x10;
}

int MinxPRC_LoadState(FILE *fi, uint32_t bsize)
{
	POKELOADSS_START(1+32);
	POKELOADSS_8(StallCPU);
	POKELOADSS_32(MinxPRC.PRCCnt);
	POKELOADSS_32(MinxPRC.PRCBGBase);
	POKELOADSS_32(MinxPRC.PRCSprBase);
	POKELOADSS_8(MinxPRC.PRCMode);
	POKELOADSS_8(MinxPRC.PRCRateMatch);
	POKELOADSS_8(MinxPRC.PRCMapPX);
	POKELOADSS_8(MinxPRC.PRCMapPY);
	POKELOADSS_8(MinxPRC.PRCMapTW);
	POKELOADSS_8(MinxPRC.PRCMapTH);
	POKELOADSS_8(MinxPRC.PRCState);
	POKELOADSS_X(13);
	POKELOADSS_END(1+32);

}

int MinxPRC_SaveState(FILE *fi)
{
	POKESAVESS_START(1+32);
	POKESAVESS_8(StallCPU);
	POKESAVESS_32(MinxPRC.PRCCnt);
	POKESAVESS_32(MinxPRC.PRCBGBase);
	POKESAVESS_32(MinxPRC.PRCSprBase);
	POKESAVESS_8(MinxPRC.PRCMode);
	POKESAVESS_8(MinxPRC.PRCRateMatch);
	POKESAVESS_8(MinxPRC.PRCMapPX);
	POKESAVESS_8(MinxPRC.PRCMapPY);
	POKESAVESS_8(MinxPRC.PRCMapTW);
	POKESAVESS_8(MinxPRC.PRCMapTH);
	POKESAVESS_8(MinxPRC.PRCState);
	POKESAVESS_X(13);
	POKESAVESS_END(1+32);
}

void MinxPRC_Sync(void)
{
	// Process PRC Counter
	MinxPRC.PRCCnt += MINX_PRCTIMERINC * PokeHWCycles;
	if ((PMR_PRC_RATE & 0xF0) >= MinxPRC.PRCRateMatch) {
		// Active frame
		if (MinxPRC.PRCCnt < 0x18000000) {
			// CPU Time
			MinxPRC.PRCState = 0;
		} else if ((MinxPRC.PRCCnt & 0xFF000000) == 0x18000000) {
			// PRC BG&SPR Trigger
			if (MinxPRC.PRCState == 1) return;
			if (MinxPRC.PRCMode == 2) {
				if (PRCAllowStall) StallCPU = 1;
				MinxPRC_Render();
				MinxPRC.PRCState = 1;
			} else if (PRCColorMap) MinxPRC_NoRender_Color();
		} else if ((MinxPRC.PRCCnt & 0xFF000000) == 0x39000000) {
			// PRC Copy Trigger
			if (MinxPRC.PRCState == 2) return;
			if (MinxPRC.PRCMode) {
				if (PRCAllowStall) StallCPU = 1;
				MinxPRC_CopyToLCD();
				MinxCPU_OnIRQAct(MINX_INTR_03);
				MinxPRC.PRCState = 2;
			}
		} else if (MinxPRC.PRCCnt >= 0x42000000) {
			// End-of-frame
			StallCPU = 0;
			PMR_PRC_RATE &= 0x0F;
			MinxPRC.PRCCnt = 0x01000000;
			MinxCPU_OnIRQAct(MINX_INTR_04);
			MinxPRC_On72HzRefresh(1);
		}
	} else {
		// Non-active frame
		if (MinxPRC.PRCCnt >= 0x42000000) {
			PMR_PRC_RATE += 0x10;
			MinxPRC.PRCCnt = 0x01000000;
			MinxPRC_On72HzRefresh(0);
		}
	}
}

uint8_t MinxPRC_ReadReg(uint8_t reg)
{
	// 0x80 to 0x8F
	switch(reg) {
		case 0x80: // PRC Stage Control
			return PMR_PRC_MODE & 0x3F;
		case 0x81: // PRC Rate Control
			return PMR_PRC_RATE;
		case 0x82: // PRC Map Tile Base (Lo)
			return PMR_PRC_MAP_LO & 0xF8;
		case 0x83: // PRC Map Tile Base (Med)
			return PMR_PRC_MAP_MID;
		case 0x84: // PRC Map Tile Base (Hi)
			return PMR_PRC_MAP_HI & 0x1F;
		case 0x85: // PRC Map Vertical Scroll
			return PMR_PRC_SCROLL_Y & 0x7F;
		case 0x86: // PRC Map Horizontal Scroll
			return PMR_PRC_SCROLL_X & 0x7F;
		case 0x87: // PRC Map Sprite Base (Lo)
			return PMR_PRC_SPR_LO & 0xC0;
		case 0x88: // PRC Map Sprite Base (Med)
			return PMR_PRC_SPR_MID;
		case 0x89: // PRC Map Sprite Base (Hi)
			return PMR_PRC_SPR_HI & 0x1F;
		case 0x8A: // PRC Counter
			return MinxPRC.PRCCnt >> 24;
		default:   // Unused
			return 0;
	}
}

void MinxPRC_WriteReg(uint8_t reg, uint8_t val)
{
	// 0x80 to 0x8F
	switch(reg) {
		case 0x80: // PRC Stage Control
			PMR_PRC_MODE = val & 0x3F;
			if (val & 0x08) {
				MinxPRC.PRCMode = (val & 0x06) ? 2 : 1;
			} else MinxPRC.PRCMode = 0;
			switch (val & 0x30) {
				case 0x00: MinxPRC.PRCMapTW = 12; MinxPRC.PRCMapTH = 16; break;
				case 0x10: MinxPRC.PRCMapTW = 16; MinxPRC.PRCMapTH = 12; break;
				case 0x20: MinxPRC.PRCMapTW = 24; MinxPRC.PRCMapTH = 8; break;
				case 0x30: MinxPRC.PRCMapTW = 24; MinxPRC.PRCMapTH = 16; break;
			}
			return;
		case 0x81: // PRC Rate Control
			if ((PMR_PRC_RATE & 0x0E) != (val & 0x0E)) PMR_PRC_RATE = (val & 0x0F);
			else PMR_PRC_RATE = (PMR_PRC_RATE & 0xF0) | (val & 0x0F);
			switch (val & 0x0E) {
				case 0x00: MinxPRC.PRCRateMatch = 0x20; break;	// Rate /3
				case 0x02: MinxPRC.PRCRateMatch = 0x50; break;	// Rate /6
				case 0x04: MinxPRC.PRCRateMatch = 0x80; break;	// Rate /9
				case 0x06: MinxPRC.PRCRateMatch = 0xB0; break;	// Rate /12
				case 0x08: MinxPRC.PRCRateMatch = 0x10; break;	// Rate /2
				case 0x0A: MinxPRC.PRCRateMatch = 0x30; break;	// Rate /4
				case 0x0C: MinxPRC.PRCRateMatch = 0x50; break;	// Rate /6
				case 0x0E: MinxPRC.PRCRateMatch = 0x70; break;	// Rate /8
			}
			return;
		case 0x82: // PRC Map Tile Base Low
			PMR_PRC_MAP_LO = val & 0xF8;
			MinxPRC.PRCBGBase = (MinxPRC.PRCBGBase & 0x1FFF00) | PMR_PRC_MAP_LO;
			return;
		case 0x83: // PRC Map Tile Base Middle
			PMR_PRC_MAP_MID = val;
			MinxPRC.PRCBGBase = (MinxPRC.PRCBGBase & 0x1F00F8) | (PMR_PRC_MAP_MID << 8);
			return;
		case 0x84: // PRC Map Tile Base High
			PMR_PRC_MAP_HI = val & 0x1F;
			MinxPRC.PRCBGBase = (MinxPRC.PRCBGBase & 0x00FFF8) | (PMR_PRC_MAP_HI << 16);
			return;
		case 0x85: // PRC Map Vertical Scroll
			PMR_PRC_SCROLL_Y = val & 0x7F;
			if (PMR_PRC_SCROLL_Y <= (MinxPRC.PRCMapTH*8-64)) MinxPRC.PRCMapPY = PMR_PRC_SCROLL_Y;
			return;
		case 0x86: // PRC Map Horizontal Scroll
			PMR_PRC_SCROLL_X = val & 0x7F;
			if (PMR_PRC_SCROLL_X <= (MinxPRC.PRCMapTW*8-96)) MinxPRC.PRCMapPX = PMR_PRC_SCROLL_X;
			return;
		case 0x87: // PRC Sprite Tile Base Low
			PMR_PRC_SPR_LO = val & 0xC0;
			MinxPRC.PRCSprBase = (MinxPRC.PRCSprBase & 0x1FFF00) | PMR_PRC_SPR_LO;
			return;
		case 0x88: // PRC Sprite Tile Base Middle
			PMR_PRC_SPR_MID = val;
			MinxPRC.PRCSprBase = (MinxPRC.PRCSprBase & 0x1F00C0) | (PMR_PRC_SPR_MID << 8);
			return;
		case 0x89: // PRC Sprite Tile Base High
			PMR_PRC_SPR_HI = val & 0x1F;
			MinxPRC.PRCSprBase = (MinxPRC.PRCSprBase & 0x00FFC0) | (PMR_PRC_SPR_HI << 16);
			return;
		case 0x8A: // PRC Counter
			return;
	}
}

//
// Default PRC Rendering
//

static inline void MinxPRC_DrawSprite8x8_Mono(uint8_t cfg, int X, int Y, int DrawT, int MaskT)
{
	int xC, xP, vaddr;
	uint8_t vdata, sdata, smask;
	uint8_t data;

	// No point to proceed if it's offscreen
	if ((X < -7) || (X >= 96)) return;
	if ((Y < -7) || (Y >= 64)) return;

	// Pre calculate
	vaddr = 0x1000 + ((Y >> 3) * 96) + X;

	// Process top columns
	if (Y >= 0) {
		for (xC=0; xC<8; xC++) {
			if ((X >= 0) && (X < 96)) {
				xP = (cfg & 0x01) ? (7 - xC) : xC;

				vdata = MinxPRC_OnRead(0, vaddr + xC);
				sdata = MinxPRC_OnRead(0, MinxPRC.PRCSprBase + (DrawT * 8) + xP);
				smask = MinxPRC_OnRead(0, MinxPRC.PRCSprBase + (MaskT * 8) + xP);

				if (cfg & 0x02) {
					sdata = PRCInvertBit[sdata];
					smask = PRCInvertBit[smask];
				}
				if (cfg & 0x04) sdata = ~sdata;

				data = vdata & ((smask << (Y & 7)) | (0xFF >> (8 - (Y & 7))));
				data |= (sdata & ~smask) << (Y & 7);

				MinxPRC_OnWrite(0, vaddr + xC, data);
			}
			X++;
		}
		X -= 8;
	}

	// Calculate new vaddr;
	vaddr += 96;

	// Process bottom columns
	if ((Y < 56) && (Y & 7)) {
		for (xC=0; xC<8; xC++) {
			if ((X >= 0) && (X < 96)) {
				xP = (cfg & 0x01) ? (7 - xC) : xC;

				vdata = MinxPRC_OnRead(0, vaddr + xC);
				sdata = MinxPRC_OnRead(0, MinxPRC.PRCSprBase + (DrawT * 8) + xP);
				smask = MinxPRC_OnRead(0, MinxPRC.PRCSprBase + (MaskT * 8) + xP);

				if (cfg & 0x02) {
					sdata = PRCInvertBit[sdata];
					smask = PRCInvertBit[smask];
				}
				if (cfg & 0x04) sdata = ~sdata;

				data = vdata & ((smask >> (8-(Y & 7))) | (0xFF << (Y & 7)));
				data |= (sdata & ~smask) >> (8-(Y & 7));

				MinxPRC_OnWrite(0, vaddr + xC, data);
			}
			X++;
		}
	}
}

void MinxPRC_Render_Mono(void)
{
	int xC, yC, tx, ty, ltileidxaddr, tileidxaddr, outaddr;
	int tiletopaddr = 0, tilebotaddr = 0;
	uint8_t data;

	int SprTB, SprAddr;
	int SprX, SprY, SprC;
	int SprFX, SprFY;

	if (PRCRenderBD) {
		for (xC=0x1000; xC<0x1300; xC++) MinxPRC_OnWrite(0, xC, 0x00);
	}

	if ((PRCRenderBG) && (PMR_PRC_MODE & 0x02)) {
		outaddr = 0x1000;
		ltileidxaddr = -1;
		for (yC=0; yC<8; yC++) {
			ty = (yC << 3) + MinxPRC.PRCMapPY;
			for (xC=0; xC<96; xC++) {
				tx = xC + MinxPRC.PRCMapPX;
				tileidxaddr = 0x1360 + (ty >> 3) * MinxPRC.PRCMapTW + (tx >> 3);

				// Read tile index
				if (ltileidxaddr != tileidxaddr) {
					tiletopaddr = MinxPRC.PRCBGBase + (MinxPRC_OnRead(0, tileidxaddr) * 8);
					tilebotaddr = MinxPRC.PRCBGBase + (MinxPRC_OnRead(0, tileidxaddr + MinxPRC.PRCMapTW) * 8);
					ltileidxaddr = tileidxaddr;
				}

				// Read tile data
				data = (MinxPRC_OnRead(0, tiletopaddr + (tx & 7)) >> (ty & 7))
				     | (MinxPRC_OnRead(0, tilebotaddr + (tx & 7)) << (8 - (ty & 7)));

				// Write to VRAM
				MinxPRC_OnWrite(0, outaddr++, (PMR_PRC_MODE & 0x01) ? ~data : data);
			}
		}
	}

	if ((PRCRenderSpr) && (PMR_PRC_MODE & 0x04)) {
		SprAddr = 0x1300 + (24 * 4);
		do {
			SprC = MinxPRC_OnRead(0, --SprAddr);
			SprTB = MinxPRC_OnRead(0, --SprAddr) * 8;
			SprY = (MinxPRC_OnRead(0, --SprAddr) & 0x7F) - 16;
			SprX = (MinxPRC_OnRead(0, --SprAddr) & 0x7F) - 16;
			if (SprC & 0x08) {
				SprFX = SprC & 0x01 ? 8 : 0;
				SprFY = SprC & 0x02 ? 8 : 0;
				MinxPRC_DrawSprite8x8_Mono(SprC, SprX + SprFX, SprY + SprFY, SprTB+2, SprTB);
				MinxPRC_DrawSprite8x8_Mono(SprC, SprX + SprFX, SprY + 8 - SprFY, SprTB+3, SprTB+1);
				MinxPRC_DrawSprite8x8_Mono(SprC, SprX + 8 - SprFX, SprY + SprFY, SprTB+6, SprTB+4);
				MinxPRC_DrawSprite8x8_Mono(SprC, SprX + 8 - SprFX, SprY + 8 - SprFY, SprTB+7, SprTB+5);
			}
		} while (SprAddr > 0x1300);
	}
}

void MinxPRC_CopyToLCD(void)
{
	MinxLCD_LCDWritefb(MinxPRC_LCDfb);
/*
	// Can't be used with the new color mode support for LCD
	int i, j;
	MinxLCD_LCDWriteCtrl(0xEE);
	for (i=0; i<8; i++) {
		MinxLCD_LCDWriteCtrl(0xB0 + i);
		MinxLCD_LCDWriteCtrl(0x00);
		MinxLCD_LCDWriteCtrl(0x10);
		for (j=0; j<96; j++) {
			MinxLCD_LCDWrite(MinxPRC_OnRead(0, 0x1000 + (i * 96) + j));
		}
	}
*/
}
