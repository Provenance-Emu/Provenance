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

#ifndef MINXHW_TIMERS
#define MINXHW_TIMERS

#include <stdint.h>

#ifdef _BIG_ENDIAN

typedef union {
	struct {
		uint8_t H;
		uint8_t L;
	} B;
	uint16_t W;
} MinxWord;

#else

typedef union {
	struct {
		uint8_t L;
		uint8_t H;
	} B;
	uint16_t W;
} MinxWord;

#endif

typedef struct {
	// Internal processing
	uint32_t SecTimerCnt;	// Second Timer Counter
	int32_t TmrSecs;	// Second Timer Fraction (Cycles, needs signed)
	uint32_t Tmr1DecA;	// Timer 1-Lo Decrement 8.24
	uint32_t Tmr1DecB;	// Timer 1-Hi Decrement 8.24
	uint32_t Tmr1CntA;	// Timer 1-Lo Counter 8.24
	uint32_t Tmr1CntB;	// Timer 1-Hi Counter 8.24
	uint32_t Tmr1PreA;	// Timer 1-Lo Preset 8.24
	uint32_t Tmr1PreB;	// Timer 1-Hi Preset 8.24
	uint32_t Tmr2DecA;	// Timer 2-Lo Decrement 8.24
	uint32_t Tmr2DecB;	// Timer 2-Hi Decrement 8.24
	uint32_t Tmr2CntA;	// Timer 2-Lo Counter 8.24
	uint32_t Tmr2CntB;	// Timer 2-Hi Counter 8.24
	uint32_t Tmr2PreA;	// Timer 2-Lo Preset 8.24
	uint32_t Tmr2PreB;	// Timer 2-Hi Preset 8.24
	uint32_t Tmr3DecA;	// Timer 3-Lo Decrement 8.24
	uint32_t Tmr3DecB;	// Timer 3-Hi Decrement 8.24
	uint32_t Tmr3CntA;	// Timer 3-Lo Counter 8.24
	uint32_t Tmr3CntB;	// Timer 3-Hi Counter 8.24
	uint32_t Tmr3PreA;	// Timer 3-Lo Preset 8.24
	uint32_t Tmr3PreB;	// Timer 3-Hi Preset 8.24
	uint32_t Tmr8Cnt;	// 256Hz Timer Counter 8.24
	uint32_t PRCCnt;	// PRC Counter 8.24
	MinxWord Tmr3Cnt16;	// Timer 3 16-Bits count
	uint16_t Timer3Piv;	// Timer 3 Pivot
	uint8_t TmrXEna2;	// Oscillator 2 Enabled
	uint8_t TmrXEna1;	// Oscillator 1 Enabled
	// Performance cache
	int Tmr1WMode;		// Timer 1 16-bits mode
	int Tmr1LEna;		// Timer 1 low enable
	int Tmr1HEna;		// Timer 1 high enable
	int Tmr2WMode;		// Timer 2 16-bits mode
	int Tmr2LEna;		// Timer 2 low enable
	int Tmr2HEna;		// Timer 2 high enable
	int Tmr3WMode;		// Timer 3 16-bits mode
	int Tmr3LEna;		// Timer 3 low enable
	int Tmr3HEna;		// Timer 3 high enable
} TMinxTimers;

// Export Timers state
extern TMinxTimers MinxTimers;

// Interrupt table
enum {
	MINX_INTR_05 = 0x05, // Timer 2-B Underflow
	MINX_INTR_06 = 0x06, // Timer 2-A Underflow (8-Bits only)
	MINX_INTR_07 = 0x07, // Timer 1-B Underflow
	MINX_INTR_08 = 0x08, // Timer 1-A Underflow (8-Bits only)
	MINX_INTR_09 = 0x09, // Timer 3 Underflow
	MINX_INTR_0A = 0x0A, // Timer 3 Pivot
	MINX_INTR_0B = 0x0B, // 32 Hz
	MINX_INTR_0C = 0x0C, //  8 Hz
	MINX_INTR_0D = 0x0D, //  2 Hz
	MINX_INTR_0E = 0x0E  //  1 Hz
};

#define MINX_TIMER256INC (16777216/15625)   // Aproximate value of 256Hz Timer (256 Hz)

// Timers counting frequency table
extern const uint32_t MinxTimers_CountFreq[32];

int MinxTimers_Create(void);

void MinxTimers_Destroy(void);

void MinxTimers_Reset(int hardreset);

int MinxTimers_LoadState(FILE *fi, uint32_t bsize);

int MinxTimers_SaveState(FILE *fi);

void MinxTimers_Sync(void);

uint8_t MinxTimers_ReadReg(uint8_t reg);

void MinxTimers_WriteReg(unsigned char reg, unsigned char val);

#endif
