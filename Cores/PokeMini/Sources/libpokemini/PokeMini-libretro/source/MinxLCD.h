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

#ifndef MINXHW_LCD
#define MINXHW_LCD

#include <stdint.h>

typedef struct {
	// Internal processing
	int32_t Pixel0Intensity; // Pixel 0 Intensity
	int32_t Pixel1Intensity; // Pixel 1 Intensity
	uint8_t Column;		// Column
	uint8_t StartLine;	// Start line
	uint8_t SetContrast;	// Set contrast
	uint8_t Contrast;	// Contrast level
	uint8_t SegmentDir;	// Segment Driver Direction Select
	uint8_t MaxContrast;	// Max Contrast
	uint8_t SetAllPix;	// Set All Pixels
	uint8_t InvAllPix;	// Invert All Pixels
	uint8_t DisplayOn;	// Display On
	uint8_t Page;		// Page
	uint8_t RowOrder;	// 0 = Top to bottom, 1 = Bottom to top
	uint8_t ReadModifyMode;	// Read Modify Write mode
	uint8_t RequireDummyR;	// Require Dummy Read
	uint8_t RMWColumn;	// Column when Read Modify Write started
} TMinxLCD;

#ifndef MINX_DIRTYPIX
#define MINX_DIRTYPIX	4
#endif

#ifndef MINX_DIRTYSCR
#define MINX_DIRTYSCR	4
#endif

// Export LCD state
extern TMinxLCD MinxLCD;

// LCD dirty status (1+ = graphics changed)
extern int LCDDirty;

// LCD Data (132 x 65 x 1bpp), Pitch of 256 bytes
extern uint8_t *LCDData;

// LCD Pixels Digital (96 x 64, 0 or 1)
extern uint8_t *LCDPixelsD;

// LCD Pixels Analog (96 x 64, 0 to 255)
extern uint8_t *LCDPixelsA;


int MinxLCD_Create(void);

void MinxLCD_Destroy(void);

void MinxLCD_Reset(int hardreset);

int MinxLCD_LoadState(FILE *fi, uint32_t bsize);

int MinxLCD_SaveState(FILE *fi);

uint8_t MinxLCD_ReadReg(int cpu, uint8_t reg);

void MinxLCD_WriteReg(int cpu, uint8_t reg, uint8_t val);

void MinxLCD_DecayRefresh(void);

void MinxLCD_Render(void);

uint8_t MinxLCD_LCDReadCtrl(int cpu);

uint8_t MinxLCD_LCDRead(int cpu);

void MinxLCD_LCDWriteCtrl(uint8_t data);

void MinxLCD_LCDWrite(uint8_t data);

void MinxLCD_LCDWritefb(uint8_t *fb);

void MinxLCD_SetContrast(uint8_t value);

#endif
