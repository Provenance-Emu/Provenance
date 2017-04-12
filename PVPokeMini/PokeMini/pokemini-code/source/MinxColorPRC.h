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

#ifndef MINXHW_COLORPRC
#define MINXHW_COLORPRC

#include <stdint.h>

typedef struct {
	uint16_t UnlockCode;
	uint8_t Unlocked;
	uint8_t Access;
	uint8_t Modes;
	uint8_t ActivePage;
	uint16_t Address;
	uint8_t LNColor0;
	uint8_t HNColor0;
	uint8_t LNColor1;
	uint8_t HNColor1;
} TMinxColorPRC;

// Export PRC state
extern TMinxColorPRC MinxColorPRC;

// For Unofficial Color Pokemon-Mini
extern int PRCColorEnable;
extern uint8_t *PRCColorPixels;
extern uint8_t *PRCColorPixelsOld;
extern uint8_t *PRCColorMap;
extern unsigned int PRCColorOffset;
extern uint8_t *PRCColorTop;
extern uint8_t PRCColorFlags;
extern const uint8_t PRCStaticColorMap[8];

//
// Functions
//

int MinxColorPRC_Create(void);

void MinxColorPRC_Destroy(void);

void MinxColorPRC_Reset(int hardreset);

int MinxColorPRC_LoadState(FILE *fi, uint32_t bsize);

int MinxColorPRC_SaveState(FILE *fi);

uint8_t MinxColorPRC_ReadReg(int cpu, uint8_t reg);

void MinxColorPRC_WriteReg(uint8_t reg, uint8_t val);

void MinxColorPRC_WriteFramebuffer(uint16_t addr, uint8_t data);

void MinxColorPRC_WriteLCD(uint16_t addr, uint8_t data);

//
// Internals
//

void MinxColorPRC_WriteCtrl(uint8_t val);

void MinxPRC_Render_Color8(void);

void MinxPRC_Render_Color4(void);

void MinxPRC_NoRender_Color(void);

#endif
