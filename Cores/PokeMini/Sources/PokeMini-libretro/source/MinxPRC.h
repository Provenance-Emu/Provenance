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

#ifndef MINXHW_PRC
#define MINXHW_PRC

#include <stdint.h>

typedef struct {
	// Internal processing
	int32_t PRCCnt;		// PRC Counter 8.24 (Need signed)
	uint32_t PRCBGBase;	// PRC Map Tile Base
	uint32_t PRCSprBase;	// PRC Sprite Base
	uint8_t PRCMode;	// PRC Mode (0 = Off, 1 = Copy, 3 = BG+Spr+Copy)
	uint8_t PRCRateMatch;	// PRC Rate Match
	uint8_t PRCMapPX;	// PRC Map X (Pixels)
	uint8_t PRCMapPY;	// PRC Map Y (Pixels)
	uint8_t PRCMapTW;	// PRC Map Width (Tiles)
	uint8_t PRCMapTH;	// PRC Map Height (Tiles)
	uint8_t PRCState;	// PRC State
} TMinxPRC;

typedef void (*TMinxPRC_Render)(void);

// Export PRC state
extern TMinxPRC MinxPRC;

// Invert bit table
extern const uint8_t PRCInvertBit[256];

// Stall CPU
extern int PRCAllowStall;
extern int StallCPU;
extern int StallCycles;

// Render backdrop? (Background overrides backdrop)
extern int PRCRenderBD;
// Render background?
extern int PRCRenderBG;
// Render sprites?
extern int PRCRenderSpr;

// Render callback
extern TMinxPRC_Render MinxPRC_Render;

enum {
	MINX_INTR_03 = 0x03, // PRC Copy Complete
	MINX_INTR_04 = 0x04  // PRC Frame Divider Overflow
};

// Aproximate value of PRC Timer (~4678 Hz) (16M / ( 4M / 855 ))
#define MINX_PRCTIMERINC (16777216/855)


int MinxPRC_Create(void);

void MinxPRC_Destroy(void);

void MinxPRC_Reset(int hardreset);

int MinxPRC_LoadState(FILE *fi, uint32_t bsize);

int MinxPRC_SaveState(FILE *fi);

void MinxPRC_Sync(void);

uint8_t MinxPRC_ReadReg(uint8_t reg);

void MinxPRC_WriteReg(uint8_t reg, uint8_t val);

//
// Internals
//

void MinxPRC_Render_Mono(void);

void MinxPRC_CopyToLCD(void);

//
// Callbacks (Written by the user)
//

void MinxPRC_On72HzRefresh(int render);

#endif
