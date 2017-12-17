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

TMinxColorPRC MinxColorPRC;
uint8_t *PRCColorVMem = NULL;		// Complete CVRAM (16KB)
uint8_t *PRCColorPixels = NULL;		// Active page (8KB)
uint8_t *PRCColorPixelsOld = NULL;
uint8_t *PRCColorMap = NULL;
unsigned int PRCColorOffset = 0;
uint8_t *PRCColorTop = 0x00000000;

// Color Flags
// Bit 0 - New Color Palette
// Bit 1 - Render to RAM
// Bit 2 to 7 - Reserved
uint8_t PRCColorFlags;

//
// Functions
//

int MinxColorPRC_Create(void)
{
	// Create color pixels array
	PRCColorVMem = (uint8_t *)malloc(8192*2);
	if (!PRCColorVMem) return 0;
	memset(PRCColorVMem, 0, 8192*2);
	PRCColorPixels = PRCColorVMem;
	PRCColorPixelsOld = (uint8_t *)malloc(96*64);
	if (!PRCColorPixelsOld) return 0;
	memset(PRCColorPixelsOld, 0, 96*64);

	// Reset
	MinxColorPRC_Reset(1);

	return 1;
}

void MinxColorPRC_Destroy(void)
{
	if (PRCColorVMem) {
		free(PRCColorVMem);
		PRCColorVMem = NULL;
	}
	if (PRCColorPixelsOld) {
		free(PRCColorPixelsOld);
		PRCColorPixelsOld = NULL;
	}
}

void MinxColorPRC_Reset(int hardreset)
{
	// Initialize State
	memset((void *)&MinxColorPRC, 0, sizeof(TMinxColorPRC));
	MinxColorPRC.LNColor1 = 0xF0;
	MinxColorPRC.HNColor1 = 0xF0;
}

int MinxColorPRC_LoadState(FILE *fi, uint32_t bsize)
{
	POKELOADSS_START(16384+32);
	POKELOADSS_A(PRCColorVMem, 16384);
	POKELOADSS_16(MinxColorPRC.UnlockCode);
	POKELOADSS_8(MinxColorPRC.Unlocked);
	POKELOADSS_8(MinxColorPRC.Access);
	POKELOADSS_8(MinxColorPRC.Modes);
	POKELOADSS_8(MinxColorPRC.ActivePage);
	POKELOADSS_16(MinxColorPRC.Address);
	POKELOADSS_8(MinxColorPRC.LNColor0);
	POKELOADSS_8(MinxColorPRC.HNColor0);
	POKELOADSS_8(MinxColorPRC.LNColor1);
	POKELOADSS_8(MinxColorPRC.HNColor1);
	POKELOADSS_X(20);
	POKELOADSS_END(16384+32);
	MinxColorPRC.Address &= 0x3FFF;
	PRCColorPixels = PRCColorVMem + (MinxColorPRC.ActivePage ? 0x2000 : 0);
}

int MinxColorPRC_SaveState(FILE *fi)
{
	POKESAVESS_START(16384+32);
	POKESAVESS_A(PRCColorVMem, 16384);
	POKESAVESS_16(MinxColorPRC.UnlockCode);
	POKESAVESS_8(MinxColorPRC.Unlocked);
	POKESAVESS_8(MinxColorPRC.Access);
	POKESAVESS_8(MinxColorPRC.Modes);
	POKESAVESS_8(MinxColorPRC.ActivePage);
	POKESAVESS_16(MinxColorPRC.Address);
	POKESAVESS_8(MinxColorPRC.LNColor0);
	POKESAVESS_8(MinxColorPRC.HNColor0);
	POKESAVESS_8(MinxColorPRC.LNColor1);
	POKESAVESS_8(MinxColorPRC.HNColor1);
	POKESAVESS_X(20);
	POKESAVESS_END(16384+32);
}

uint8_t MinxColorPRC_ReadReg(int cpu, uint8_t reg)
{
	uint8_t ret;
	if (!MinxColorPRC.Unlocked) return 0x00;

	// 0xF0 to 0xFD
	switch(reg) {
		case 0xF0: // Color Command
			return 0xCE;
		case 0xF1: // CVRAM Address Low
			return MinxColorPRC.Address & 0xFF;
		case 0xF2: // CVRAM Address High
			return (MinxColorPRC.Address >> 8) & 0x3F;
		case 0xF3: // CVRAM Read
			if (cpu && (MinxColorPRC.Access == 3)) MinxColorPRC.Address = (MinxColorPRC.Address + 1) & 0x3FFF;
			ret = PRCColorVMem[MinxColorPRC.Address ^ (MinxColorPRC.ActivePage ? 0x2000 : 0)];
			if (cpu && (MinxColorPRC.Access == 2)) MinxColorPRC.Address = (MinxColorPRC.Address - 1) & 0x3FFF;
			if (cpu && (MinxColorPRC.Access == 1)) MinxColorPRC.Address = (MinxColorPRC.Address + 1) & 0x3FFF;
			return ret;
		case 0xF4: // Low Nibble Pixel 0
			return MinxColorPRC.LNColor0;
		case 0xF5: // High Nibble Pixel 0
			return MinxColorPRC.HNColor0;
		case 0xF6: // Low Nibble Pixel 1
			return MinxColorPRC.LNColor1;
		case 0xF7: // High Nibble Pixel 1
			return MinxColorPRC.HNColor1;
		default:   // Unused
			return 0x00;
	}
}

void MinxColorPRC_WriteReg(uint8_t reg, uint8_t val)
{
	if (!MinxColorPRC.Unlocked) {
		if (reg != 0xF0) return;
		// Unlock sequence: ($5A, $CE)
		MinxColorPRC.UnlockCode = (MinxColorPRC.UnlockCode << 8) | val;
		if (MinxColorPRC.UnlockCode == 0x5ACE) {
			MinxColorPRC.Unlocked = 1;
		}
		return;
	}

	// 0xF0 to 0xFD
	switch(reg) {
		case 0xF0: // Color Command
			MinxColorPRC_WriteCtrl(val);
			return;
		case 0xF1: // CROM Address Low
			MinxColorPRC.Address = (MinxColorPRC.Address & 0x3F00) | val;
			return;
		case 0xF2: // CROM Address High
			MinxColorPRC.Address = (MinxColorPRC.Address & 0x00FF) | ((val & 0x3F) << 8);
			return;
		case 0xF3: // CVRAM Write
			if (MinxColorPRC.Access == 3) MinxColorPRC.Address = (MinxColorPRC.Address + 1) & 0x7FFF;
			PRCColorVMem[MinxColorPRC.Address ^ (MinxColorPRC.ActivePage ? 0x2000 : 0)] = val;
			if (MinxColorPRC.Access == 2) MinxColorPRC.Address = (MinxColorPRC.Address - 1) & 0x7FFF;
			if (MinxColorPRC.Access == 1) MinxColorPRC.Address = (MinxColorPRC.Address + 1) & 0x7FFF;
			return;
		case 0xF4: // Low Nibble Pixel 0
			MinxColorPRC.LNColor0 = val;
			return;
		case 0xF5: // High Nibble Pixel 0
			MinxColorPRC.HNColor0 = val;
			return;
		case 0xF6: // Low Nibble Pixel 1
			MinxColorPRC.LNColor1 = val;
			return;
		case 0xF7: // High Nibble Pixel 1
			MinxColorPRC.HNColor1 = val;
			return;
	}
}

//
// Unofficial Color Support
//

void MinxColorPRC_WriteCtrl(uint8_t val)
{
	switch (val) {
		case 0xA0: // CVRAM Access: Fixed
			MinxColorPRC.Access = 0;
			break;
		case 0xA1: // CVRAM Access: Post-increment
			MinxColorPRC.Access = 1;
			break;
		case 0xA2: // CVRAM Access: Post-decrement
			MinxColorPRC.Access = 2;
			break;
		case 0xA3: // CVRAM Access: Pre-increment
			MinxColorPRC.Access = 3;
			break;

		case 0xD0: // Enable framebuffer update
			MinxColorPRC.Modes &= ~0x01;
			break;
		case 0xD1: // Enable LCD update
			MinxColorPRC.Modes &= ~0x02;
			break;
		case 0xD2: // Enable PRC update
			MinxColorPRC.Modes &= ~0x04;
			break;

		case 0xD8: // Disable framebuffer update
			MinxColorPRC.Modes |= 0x01;
			break;
		case 0xD9: // Disable LCD update
			MinxColorPRC.Modes |= 0x02;
			break;
		case 0xDA: // Disable PRC update
			MinxColorPRC.Modes |= 0x04;
			break;

		case 0xCF: // Lock
			MinxColorPRC.Unlocked = 0;
			MinxColorPRC.UnlockCode = 0;
			break;

		case 0xF0: // Flip page
			MinxColorPRC.ActivePage = !MinxColorPRC.ActivePage;
			break;			

		case 0x5A: // UnLock sequence
		case 0xCE:
			break;
	}
}

void MinxColorPRC_WriteFramebuffer(uint16_t addr, uint8_t data)
{
	int i;
	if (MinxColorPRC.Modes & 1) return;
	addr = (addr / 96) * 8*96 + (addr % 96);
	for (i=0; i<4; i++) {
		PRCColorPixels[addr] = (data & 1) ? MinxColorPRC.LNColor1 : MinxColorPRC.LNColor0;
		data >>= 1; addr += 96;
	}
	for (i=4; i<8; i++) {
		PRCColorPixels[addr] = (data & 1) ? MinxColorPRC.HNColor1 : MinxColorPRC.HNColor0;
		data >>= 1; addr += 96;
	}
}

void MinxColorPRC_WriteLCD(uint16_t addr, uint8_t data)
{
	int i, vaddr = addr & 0xFF;
	if (MinxColorPRC.Modes & 2) return;
	if (addr >= 2048) return;
	if (vaddr >= 96) return;
	vaddr = ((addr & 0x700) >> 8) * 8*96 + vaddr;
	for (i=0; i<4; i++) {
		PRCColorPixels[vaddr] = (data & 1) ? MinxColorPRC.LNColor1 : MinxColorPRC.LNColor0;
		data >>= 1; vaddr += 96;
	}
	for (i=4; i<8; i++) {
		PRCColorPixels[vaddr] = (data & 1) ? MinxColorPRC.HNColor1 : MinxColorPRC.HNColor0;
		data >>= 1; vaddr += 96;
	}
}

const uint8_t PRCStaticColorMap[8] = {0x00, 0xF0, 0x00, 0xF0, 0x00, 0xF0, 0x00, 0xF0};

static inline void MinxPRC_DrawSprite8x8_Color8(uint8_t cfg, int X, int Y, int DrawT, int MaskT)
{
	uint8_t *ColorMap;
	int yC, xC, xP, level, out;
	uint8_t sdata, smask;

	// No point to proceed if it's offscreen
	if (X >= 96) return;
	if (Y >= 64) return;

	// Pre calculate
	level = (((MinxLCD.Contrast + 2) & 0x3C) << 2) - 0x80;
	ColorMap = (uint8_t *)PRCColorMap + (MinxPRC.PRCSprBase >> 2) + (DrawT << 1) - PRCColorOffset;
	if ((ColorMap < PRCColorMap) || (ColorMap >= PRCColorTop)) ColorMap = (uint8_t *)PRCStaticColorMap;

	// Draw sprite
	for (yC=0; yC<8; yC++) {
		if ((Y >= 0) && (Y < 64)) {
			for (xC=0; xC<8; xC++) {
				if ((X >= 0) && (X < 96)) {
					xP = (cfg & 0x01) ? (7 - xC) : xC;

					smask = MinxPRC_OnRead(0, MinxPRC.PRCSprBase + (MaskT * 8) + xP);
					if (cfg & 0x02) smask = PRCInvertBit[smask];
					smask = smask & (1 << (yC & 7));

					// Write result
					if (!smask) {
						sdata = MinxPRC_OnRead(0, MinxPRC.PRCSprBase + (DrawT * 8) + xP);
						if (cfg & 0x02) sdata = PRCInvertBit[sdata];
						if (cfg & 0x04) sdata = ~sdata;
						sdata = sdata & (1 << (yC & 7));

						out = level + (int)(sdata ? ColorMap[1] : *ColorMap);
						if (out > 255) out = 255;
						if (out < 0) out = 0;
						PRCColorPixels[Y * 96 + X] = (uint8_t)out;
					}
				}
				X++;
			}
			X -= 8;
		}
		Y++;
	}
}

void MinxPRC_Render_Color8(void)
{
	int xC, yC, tx, ty, tileidxaddr, ltileidxaddr, outaddr, level, out;
	int tiledataddr = 0;
	uint8_t *ColorMap = (uint8_t *)PRCStaticColorMap;
	uint8_t tileidx = 0, tdata, data;

	int SprTB, SprAddr;
	int SprX, SprY, SprC;

	if (!PRCColorMap) return;
	if (VidEnableHighcolor) memcpy(PRCColorPixelsOld, PRCColorPixels, 96*64);
	if (PRCColorFlags & 2) MinxPRC_Render_Mono();
	PRCColorPixels = PRCColorVMem + (MinxColorPRC.ActivePage ? 0x2000 : 0);
	if (MinxColorPRC.Modes & 4) return;

	// Color contrast level
	level = (((MinxLCD.Contrast + 2) & 0x3C) << 2) - 0x80;

	if (PRCRenderBD) {
		for (xC=0; xC<96*64; xC++) PRCColorPixels[xC] = 0x00;
	}

	if ((PRCRenderBG) && (PMR_PRC_MODE & 0x02)) {
		outaddr = 0;
		ltileidxaddr = -1;
		for (yC=0; yC<64; yC++) {
			ty = yC + MinxPRC.PRCMapPY;
			for (xC=0; xC<96; xC++) {
				tx = xC + MinxPRC.PRCMapPX;
				tileidxaddr = 0x1360 + (ty >> 3) * MinxPRC.PRCMapTW + (tx >> 3);

				// Read tile index
				if (ltileidxaddr != tileidxaddr) {
					ltileidxaddr = tileidxaddr;
					tileidx = MinxPRC_OnRead(0, tileidxaddr);
					tiledataddr = MinxPRC.PRCBGBase + (tileidx << 3);
					ColorMap = (uint8_t *)PRCColorMap + (MinxPRC.PRCBGBase >> 2) + (tileidx << 1) - PRCColorOffset;
					if ((ColorMap < PRCColorMap) || (ColorMap >= PRCColorTop)) ColorMap = (uint8_t *)PRCStaticColorMap;
				}

				// Read tile data
				tdata = MinxPRC_OnRead(0, tiledataddr + (tx & 7));
				if (PMR_PRC_MODE & 0x01) tdata = ~tdata;
				data = (tdata & (1 << (ty & 7))) ? ColorMap[1] : *ColorMap;

				// Write result
				out = level + (int)data;
				if (out > 255) out = 255;
				if (out < 0) out = 0;
				PRCColorPixels[outaddr++] = (uint8_t)out;
			}
		}
	}

	if ((PRCRenderSpr) && (PMR_PRC_MODE & 0x04)) {
		SprAddr = 0x1300 + (24 * 4);
		do {
			SprC = MinxPRC_OnRead(0, --SprAddr);
			SprTB = MinxPRC_OnRead(0, --SprAddr) << 3;
			SprY = (MinxPRC_OnRead(0, --SprAddr) & 0x7F) - 16;
			SprX = (MinxPRC_OnRead(0, --SprAddr) & 0x7F) - 16;
			if (SprC & 0x08) {
				MinxPRC_DrawSprite8x8_Color8(SprC, SprX + (SprC & 0x01 ? 8 : 0), SprY + (SprC & 0x02 ? 8 : 0), SprTB+2, SprTB);
				MinxPRC_DrawSprite8x8_Color8(SprC, SprX + (SprC & 0x01 ? 8 : 0), SprY + (SprC & 0x02 ? 0 : 8), SprTB+3, SprTB+1);
				MinxPRC_DrawSprite8x8_Color8(SprC, SprX + (SprC & 0x01 ? 0 : 8), SprY + (SprC & 0x02 ? 8 : 0), SprTB+6, SprTB+4);
				MinxPRC_DrawSprite8x8_Color8(SprC, SprX + (SprC & 0x01 ? 0 : 8), SprY + (SprC & 0x02 ? 0 : 8), SprTB+7, SprTB+5);
			}
		} while (SprAddr > 0x1300);
	}
}

static inline void MinxPRC_DrawSprite8x8_Color4(uint8_t cfg, int X, int Y, int DrawT, int MaskT)
{
	uint8_t *ColorMap;
	int yC, xC, xP, level, quad, out;
	uint8_t sdata, smask;

	// No point to proceed if it's offscreen
	if (X >= 96) return;
	if (Y >= 64) return;

	// Pre calculate
	level = (((MinxLCD.Contrast + 2) & 0x3C) << 2) - 0x80;
	ColorMap = (uint8_t *)PRCColorMap + MinxPRC.PRCSprBase + (DrawT << 3) - PRCColorOffset;
	if ((ColorMap < PRCColorMap) || (ColorMap >= PRCColorTop)) ColorMap = (uint8_t *)PRCStaticColorMap;

	// Draw sprite
	for (yC=0; yC<8; yC++) {
		if ((Y >= 0) && (Y < 64)) {
			for (xC=0; xC<8; xC++) {
				if ((X >= 0) && (X < 96)) {
					quad = (yC & 4) + ((xC & 4) >> 1);
					xP = (cfg & 0x01) ? (7 - xC) : xC;

					smask = MinxPRC_OnRead(0, MinxPRC.PRCSprBase + (MaskT * 8) + xP);
					if (cfg & 0x02)	smask = PRCInvertBit[smask];
					smask = smask & (1 << (yC & 7));

					// Write result
					if (!smask) {
						sdata = MinxPRC_OnRead(0, MinxPRC.PRCSprBase + (DrawT * 8) + xP);
						if (cfg & 0x02)	sdata = PRCInvertBit[sdata];
						if (cfg & 0x04) sdata = ~sdata;
						sdata = sdata & (1 << (yC & 7));

						out = level + (int)(sdata ? ColorMap[quad+1] : ColorMap[quad]);
						if (out > 255) out = 255;
						if (out < 0) out = 0;
						PRCColorPixels[Y * 96 + X] = (uint8_t)out;
					}
				}
				X++;
			}
			X -= 8;
		}
		Y++;
	}
}

void MinxPRC_Render_Color4(void)
{
	int xC, yC, tx, ty, tileidxaddr, ltileidxaddr, outaddr, level, quad, out;
	int tiledataddr = 0;
	uint8_t *ColorMap = (uint8_t *)PRCStaticColorMap;
	uint8_t tileidx = 0, tdata, data;

	int SprTB, SprAddr;
	int SprX, SprY, SprC;

	if (!PRCColorMap) return;
	if (VidEnableHighcolor) memcpy(PRCColorPixelsOld, PRCColorPixels, 96*64);
	if (PRCColorFlags & 2) MinxPRC_Render_Mono();
	PRCColorPixels = PRCColorVMem + (MinxColorPRC.ActivePage ? 0x2000 : 0);
	if (MinxColorPRC.Modes & 4) return;

	// Color contrast level
	level = (((MinxLCD.Contrast + 2) & 0x3C) << 2) - 0x80;

	if (PRCRenderBD) {
		for (xC=0; xC<96*64; xC++) PRCColorPixels[xC] = 0x00;
	}

	if ((PRCRenderBG) && (PMR_PRC_MODE & 0x02)) {
		outaddr = 0;
		ltileidxaddr = -1;
		for (yC=0; yC<64; yC++) {
			ty = yC + MinxPRC.PRCMapPY;
			for (xC=0; xC<96; xC++) {
				tx = xC + MinxPRC.PRCMapPX;
				quad = (ty & 4) + ((tx & 4) >> 1);
				tileidxaddr = 0x1360 + (ty >> 3) * MinxPRC.PRCMapTW + (tx >> 3);

				// Read tile index
				if (ltileidxaddr != tileidxaddr) {
					ltileidxaddr = tileidxaddr;
					tileidx = MinxPRC_OnRead(0, tileidxaddr);
					tiledataddr = MinxPRC.PRCBGBase + (tileidx << 3);
					ColorMap = (uint8_t *)PRCColorMap + MinxPRC.PRCBGBase + (tileidx << 3) - PRCColorOffset;
					if ((ColorMap < PRCColorMap) || (ColorMap >= PRCColorTop)) ColorMap = (uint8_t *)PRCStaticColorMap;
				}

				// Read tile data
				tdata = MinxPRC_OnRead(0, tiledataddr + (tx & 7));
				if (PMR_PRC_MODE & 0x01) tdata = ~tdata;
				data = (tdata & (1 << (ty & 7))) ? ColorMap[quad+1] : ColorMap[quad];

				// Write result
				out = level + (int)data;
				if (out > 255) out = 255;
				if (out < 0) out = 0;
				PRCColorPixels[outaddr++] = (uint8_t)out;
			}
		}
	}
	if (PRCRenderSpr && (PMR_PRC_MODE & 0x04)) {
		SprAddr = 0x1300 + (24 * 4);
		do {
			SprC = MinxPRC_OnRead(0, --SprAddr);
			SprTB = MinxPRC_OnRead(0, --SprAddr) << 3;
			SprY = (MinxPRC_OnRead(0, --SprAddr) & 0x7F) - 16;
			SprX = (MinxPRC_OnRead(0, --SprAddr) & 0x7F) - 16;
			if (SprC & 0x08) {
				MinxPRC_DrawSprite8x8_Color4(SprC, SprX + (SprC & 0x01 ? 8 : 0), SprY + (SprC & 0x02 ? 8 : 0), SprTB+2, SprTB);
				MinxPRC_DrawSprite8x8_Color4(SprC, SprX + (SprC & 0x01 ? 8 : 0), SprY + (SprC & 0x02 ? 0 : 8), SprTB+3, SprTB+1);
				MinxPRC_DrawSprite8x8_Color4(SprC, SprX + (SprC & 0x01 ? 0 : 8), SprY + (SprC & 0x02 ? 8 : 0), SprTB+6, SprTB+4);
				MinxPRC_DrawSprite8x8_Color4(SprC, SprX + (SprC & 0x01 ? 0 : 8), SprY + (SprC & 0x02 ? 0 : 8), SprTB+7, SprTB+5);
			}
		} while (SprAddr > 0x1300);
	}
}

void MinxPRC_NoRender_Color(void)
{
	if (VidEnableHighcolor) memcpy(PRCColorPixelsOld, PRCColorPixels, 96*64);
	PRCColorPixels = PRCColorVMem + (MinxColorPRC.ActivePage ? 0x2000 : 0);
}
