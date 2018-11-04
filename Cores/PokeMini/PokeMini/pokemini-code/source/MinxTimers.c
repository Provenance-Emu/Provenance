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

TMinxTimers MinxTimers;

// Calculate decrease on oscillator 1
const uint32_t MinxTimers_CalculateDecOsc1[16] = {
	// Osci1 disabled
	0, 0, 0, 0, 0, 0, 0, 0,
	// Osci1 Enabled
	(16777216/2),     // 2000000 Hz
	(16777216/8),     //  500000 Hz
	(16777216/32),    //  125000 Hz
	(16777216/64),    //   62500 Hz
	(16777216/128),   //   31250 Hz
	(16777216/256),   //   15625 Hz
	(16777216/1024),  //    3906.25 Hz
	(16777216/4096),  //     976.5625 Hz
};

// Calculate decrease on oscillator 2
const uint32_t MinxTimers_CalculateDecOsc2[16] = {
	// Osci2 disabled
	0, 0, 0, 0, 0, 0, 0, 0,
	// Osci2 Enabled (Aproximate values)
	(16777216/122),   // 32768 Hz
	(16777216/244),   // 16384 Hz
	(16777216/488),   //  8192 Hz
	(16777216/977),   //  4096 Hz
	(16777216/1953),  //  2048 Hz
	(16777216/3906),  //  1024 Hz
	(16777216/7812),  //   512 Hz
	(16777216/15625)  //   256 Hz
};

// Timers counting frequency table
const uint32_t MinxTimers_CountFreq[32] = {
	// Osci1 disabled
	0, 0, 0, 0, 0, 0, 0, 0,
	// Osci1 Enabled
	(4000000/2), (4000000/8), (4000000/32), (4000000/64),
	(4000000/128), (4000000/256), (4000000/1024), (4000000/4096),
	// Osci2 disabled
	0, 0, 0, 0, 0, 0, 0, 0,
	// Osci2 Enabled
	(32768/1), (32768/2), (32768/4), (32768/8),
	(32768/16), (32768/32), (32768/64), (32768/128)
};

//
// Functions
//

int MinxTimers_Create(void)
{
	// Reset
	memset((void *)&MinxTimers, 0, sizeof(TMinxTimers));
	MinxTimers_Reset(1);

	return 1;
}

void MinxTimers_Destroy(void)
{
}

void MinxTimers_Reset(int hardreset)
{
	if (hardreset) {
		// Init state
		memset((void *)&MinxTimers, 0, sizeof(TMinxTimers));
	}

	// Init variables
	MinxTimers.Tmr1PreA = 0xFFFFFFFF;
	MinxTimers.Tmr1PreB = 0xFFFFFFFF;
	MinxTimers.Tmr2PreA = 0xFFFFFFFF;
	MinxTimers.Tmr2PreB = 0xFFFFFFFF;
	MinxTimers.Tmr3PreA = 0xFFFFFFFF;
	MinxTimers.Tmr3PreB = 0xFFFFFFFF;
}

int MinxTimers_LoadState(FILE *fi, uint32_t bsize)
{
	POKELOADSS_START(128);
	POKELOADSS_32(MinxTimers.SecTimerCnt);
	POKELOADSS_32(MinxTimers.TmrSecs);
	POKELOADSS_32(MinxTimers.Tmr1DecA);
	POKELOADSS_32(MinxTimers.Tmr1DecB);
	POKELOADSS_32(MinxTimers.Tmr1CntA);
	POKELOADSS_32(MinxTimers.Tmr1CntB);
	POKELOADSS_32(MinxTimers.Tmr1PreA);
	POKELOADSS_32(MinxTimers.Tmr1PreB);
	POKELOADSS_32(MinxTimers.Tmr2DecA);
	POKELOADSS_32(MinxTimers.Tmr2DecB);
	POKELOADSS_32(MinxTimers.Tmr2CntA);
	POKELOADSS_32(MinxTimers.Tmr2CntB);
	POKELOADSS_32(MinxTimers.Tmr2PreA);
	POKELOADSS_32(MinxTimers.Tmr2PreB);
	POKELOADSS_32(MinxTimers.Tmr3DecA);
	POKELOADSS_32(MinxTimers.Tmr3DecB);
	POKELOADSS_32(MinxTimers.Tmr3CntA);
	POKELOADSS_32(MinxTimers.Tmr3CntB);
	POKELOADSS_32(MinxTimers.Tmr3PreA);
	POKELOADSS_32(MinxTimers.Tmr3PreB);
	POKELOADSS_32(MinxTimers.Tmr8Cnt);
	POKELOADSS_32(MinxTimers.PRCCnt);
	POKELOADSS_16(MinxTimers.Tmr3Cnt16.W);
	POKELOADSS_16(MinxTimers.Timer3Piv);
	POKELOADSS_8(MinxTimers.TmrXEna2);
	POKELOADSS_8(MinxTimers.TmrXEna1);
	POKELOADSS_X(34);
	POKELOADSS_END(128);
	MinxTimers.Tmr1WMode = PMR_TMR1_CTRL_L & 0x80;
	MinxTimers.Tmr1LEna = PMR_TMR1_CTRL_L & 0x04;
	MinxTimers.Tmr1HEna = PMR_TMR1_CTRL_H & 0x04;
	MinxTimers.Tmr2WMode = PMR_TMR2_CTRL_L & 0x80;
	MinxTimers.Tmr2LEna = PMR_TMR2_CTRL_L & 0x04;
	MinxTimers.Tmr2HEna = PMR_TMR2_CTRL_H & 0x04;
	MinxTimers.Tmr3WMode = PMR_TMR3_CTRL_L & 0x80;
	MinxTimers.Tmr3LEna = PMR_TMR3_CTRL_L & 0x04;
	MinxTimers.Tmr3HEna = PMR_TMR3_CTRL_H & 0x04;
}

int MinxTimers_SaveState(FILE *fi)
{
	POKESAVESS_START(128);
	POKESAVESS_32(MinxTimers.SecTimerCnt);
	POKESAVESS_32(MinxTimers.TmrSecs);
	POKESAVESS_32(MinxTimers.Tmr1DecA);
	POKESAVESS_32(MinxTimers.Tmr1DecB);
	POKESAVESS_32(MinxTimers.Tmr1CntA);
	POKESAVESS_32(MinxTimers.Tmr1CntB);
	POKESAVESS_32(MinxTimers.Tmr1PreA);
	POKESAVESS_32(MinxTimers.Tmr1PreB);
	POKESAVESS_32(MinxTimers.Tmr2DecA);
	POKESAVESS_32(MinxTimers.Tmr2DecB);
	POKESAVESS_32(MinxTimers.Tmr2CntA);
	POKESAVESS_32(MinxTimers.Tmr2CntB);
	POKESAVESS_32(MinxTimers.Tmr2PreA);
	POKESAVESS_32(MinxTimers.Tmr2PreB);
	POKESAVESS_32(MinxTimers.Tmr3DecA);
	POKESAVESS_32(MinxTimers.Tmr3DecB);
	POKESAVESS_32(MinxTimers.Tmr3CntA);
	POKESAVESS_32(MinxTimers.Tmr3CntB);
	POKESAVESS_32(MinxTimers.Tmr3PreA);
	POKESAVESS_32(MinxTimers.Tmr3PreB);
	POKESAVESS_32(MinxTimers.Tmr8Cnt);
	POKESAVESS_32(MinxTimers.PRCCnt);
	POKESAVESS_16(MinxTimers.Tmr3Cnt16.W);
	POKESAVESS_16(MinxTimers.Timer3Piv);
	POKESAVESS_8(MinxTimers.TmrXEna2);
	POKESAVESS_8(MinxTimers.TmrXEna1);
	POKESAVESS_X(34);
	POKESAVESS_END(128);
}

void MinxTimers_Sync(void)
{
	register uint32_t PreCount;

	// Process 256Hz Timer (Increment)
	if (PMR_TMR256_CTRL) {
		PreCount = MinxTimers.Tmr8Cnt;
		MinxTimers.Tmr8Cnt += MINX_TIMER256INC * PokeHWCycles;
		if ((PreCount & 0x08000000) ^ (MinxTimers.Tmr8Cnt & 0x08000000)) {
			// 32Hz
			MinxCPU_OnIRQAct(MINX_INTR_0B);
		}
		if ((PreCount & 0x20000000) ^ (MinxTimers.Tmr8Cnt & 0x20000000)) {
			// 8Hz
			MinxCPU_OnIRQAct(MINX_INTR_0C);
		}
		if ((PreCount & 0x80000000) ^ (MinxTimers.Tmr8Cnt & 0x80000000)) {
			// 2Hz
			MinxCPU_OnIRQAct(MINX_INTR_0D);
		}
		if (PreCount > MinxTimers.Tmr8Cnt) {
			// 1Hz
			MinxCPU_OnIRQAct(MINX_INTR_0E);
		}
	}

	// Process Second Timer (Increment)
	if (PMR_SEC_CTRL) {
		MinxTimers.TmrSecs += PokeHWCycles;
		if (MinxTimers.TmrSecs >= 4000000) {
			MinxTimers.SecTimerCnt++;
			MinxTimers.TmrSecs -= 4000000;
		}
	}

	// Process Timer 1 (Decrement)
	if (MinxTimers.Tmr1WMode) {
		// 1x 16-Bits Timer
		if (MinxTimers.Tmr1LEna) {
			PreCount = MinxTimers.Tmr1CntA;
			MinxTimers.Tmr1CntA -= MinxTimers.Tmr1DecA * PokeHWCycles;
			if (PreCount < MinxTimers.Tmr1CntA) {
				PreCount = MinxTimers.Tmr1CntB;
				MinxTimers.Tmr1CntB -= 0x01000000;
				if (PreCount < MinxTimers.Tmr1CntB) {
					MinxTimers.Tmr1CntA = MinxTimers.Tmr1PreA;
					MinxTimers.Tmr1CntB = MinxTimers.Tmr1PreB;
					// IRQ Timer 1-Hi underflow
					MinxCPU_OnIRQAct(MINX_INTR_07);
				}
			}
		}
	} else {
		// 2x 8-Bits Timers
		if (MinxTimers.Tmr1LEna) {
			// Timer Lo
			PreCount = MinxTimers.Tmr1CntA;
			MinxTimers.Tmr1CntA -= MinxTimers.Tmr1DecA * PokeHWCycles;
			if (PreCount < MinxTimers.Tmr1CntA) {
				MinxTimers.Tmr1CntA = MinxTimers.Tmr1PreA;
				// IRQ Timer 1-Lo underflow
				MinxCPU_OnIRQAct(MINX_INTR_08);
			}
		}
		if (MinxTimers.Tmr1HEna) {
			// Timer Hi
			PreCount = MinxTimers.Tmr1CntB;
			MinxTimers.Tmr1CntB -= MinxTimers.Tmr1DecB * PokeHWCycles;
			if (PreCount < MinxTimers.Tmr1CntB) {
				MinxTimers.Tmr1CntB = MinxTimers.Tmr1PreB;
				// IRQ Timer 1-Hi underflow
				MinxCPU_OnIRQAct(MINX_INTR_07);
			}
		}
	}

	// Process Timer 2 (Decrement)
	if (MinxTimers.Tmr2WMode) {
		// 1x 16-Bits Timer
		if (MinxTimers.Tmr2LEna) {
			PreCount = MinxTimers.Tmr2CntA;
			MinxTimers.Tmr2CntA -= MinxTimers.Tmr2DecA * PokeHWCycles;
			if (PreCount < MinxTimers.Tmr2CntA) {
				PreCount = MinxTimers.Tmr2CntB;
				MinxTimers.Tmr2CntB -= 0x01000000;
				if (PreCount < MinxTimers.Tmr2CntB) {
					MinxTimers.Tmr2CntA = MinxTimers.Tmr2PreA;
					MinxTimers.Tmr2CntB = MinxTimers.Tmr2PreB;
					// IRQ Timer 2-Hi underflow
					MinxCPU_OnIRQAct(MINX_INTR_05);
				}
			}
		}
	} else {
		// 2x 8-Bits Timers
		if (MinxTimers.Tmr2LEna) {
			// Timer Lo
			PreCount = MinxTimers.Tmr2CntA;
			MinxTimers.Tmr2CntA -= MinxTimers.Tmr2DecA * PokeHWCycles;
			if (PreCount < MinxTimers.Tmr2CntA) {
				MinxTimers.Tmr2CntA = MinxTimers.Tmr2PreA;
				// IRQ Timer 2-Lo underflow
				MinxCPU_OnIRQAct(MINX_INTR_06);
			}
		}
		if (MinxTimers.Tmr2HEna) {
			// Timer Hi
			PreCount = MinxTimers.Tmr2CntB;
			MinxTimers.Tmr2CntB -= MinxTimers.Tmr2DecB * PokeHWCycles;
			if (PreCount < MinxTimers.Tmr2CntB) {
				MinxTimers.Tmr2CntB = MinxTimers.Tmr2PreB;
				// IRQ Timer 2-Hi underflow
				MinxCPU_OnIRQAct(MINX_INTR_05);
			}
		}
	}

	// Process Timer 3 (Decrement)
	if (MinxTimers.Tmr3WMode) {
		// 1x 16-Bits Timer
		if (MinxTimers.Tmr3LEna) {
			PreCount = MinxTimers.Tmr3CntA;
			MinxTimers.Tmr3CntA -= MinxTimers.Tmr3DecA * PokeHWCycles;
			if (PreCount < MinxTimers.Tmr3CntA) {
				PreCount = MinxTimers.Tmr3CntB;
				MinxTimers.Tmr3CntB -= 0x01000000;
				if (PreCount < MinxTimers.Tmr3CntB) {
					MinxTimers.Tmr3CntA = MinxTimers.Tmr3PreA;
					MinxTimers.Tmr3CntB = MinxTimers.Tmr3PreB;
					// IRQ Timer 3 underflow
					MinxCPU_OnIRQAct(MINX_INTR_09);
				}
				MinxTimers.Tmr3Cnt16.B.H = MinxTimers.Tmr3CntB >> 24;
			}
			// Check pivot
			PreCount = MinxTimers.Tmr3Cnt16.W;
			MinxTimers.Tmr3Cnt16.B.L = MinxTimers.Tmr3CntA >> 24;
			if ((PreCount > MinxTimers.Timer3Piv) && (MinxTimers.Tmr3Cnt16.W <= MinxTimers.Timer3Piv)) {
				// IRQ Timer 3 Pivot
				MinxCPU_OnIRQAct(MINX_INTR_0A);
			}
		}
	} else {
		// 2x 8-Bits Timers
		if (MinxTimers.Tmr3LEna) {
			// Timer Lo
			PreCount = MinxTimers.Tmr3CntA;
			MinxTimers.Tmr3CntA -= MinxTimers.Tmr3DecA * PokeHWCycles; // Osci2
			if (PreCount < MinxTimers.Tmr3CntA) {
				MinxTimers.Tmr3CntA = MinxTimers.Tmr3PreA;
			}
			MinxTimers.Tmr3Cnt16.B.L = MinxTimers.Tmr3CntA >> 24;
		}
		if (MinxTimers.Tmr3HEna) {
			// Timer Hi
			PreCount = MinxTimers.Tmr3CntB;
			MinxTimers.Tmr3CntB -= MinxTimers.Tmr3DecB * PokeHWCycles; // Osci2
			if (PreCount < MinxTimers.Tmr3CntB) {
				MinxTimers.Tmr3CntB = MinxTimers.Tmr3PreB;
				// IRQ Timer 3 underflow
				MinxCPU_OnIRQAct(MINX_INTR_09);
			}
			// Check pivot
			PreCount = MinxTimers.Tmr3Cnt16.W;
			MinxTimers.Tmr3Cnt16.B.H = MinxTimers.Tmr3CntB >> 24;
			if ((PreCount > MinxTimers.Timer3Piv) && (MinxTimers.Tmr3Cnt16.W <= MinxTimers.Timer3Piv)) {
				// IRQ Timer 3 Pivot
				MinxCPU_OnIRQAct(MINX_INTR_0A);
			}
		}
	}
}

uint8_t MinxTimers_ReadReg(uint8_t reg)
{
	// 0x08 to 0x0F, 0x18 to 0x1F, 0x30 to 0x41, 0x48 to 0x4F
	switch(reg) {
		case 0x08: // Second Counter Control
			return PMR_SEC_CTRL & 0x01;
		case 0x09: // Second Counter Low
			return (uint8_t)MinxTimers.SecTimerCnt;
		case 0x0A: // Second Counter Med
			return (uint8_t)(MinxTimers.SecTimerCnt >> 8);
		case 0x0B: // Second Counter High
			return (uint8_t)(MinxTimers.SecTimerCnt >> 16);
		case 0x18: // Timer 1 Prescaler
			return PMR_TMR1_SCALE;
		case 0x19: // Timer 1 Osc. Select + Osc. Enable
			return PMR_TMR1_ENA_OSC & 0x33;
		case 0x1A: // Timer 2 Prescaler
			return PMR_TMR2_SCALE;
		case 0x1B: // Timer 2 Osc. Select
			return PMR_TMR2_OSC & 0x03;
		case 0x1C: // Timer 3 Prescaler
			return PMR_TMR3_SCALE;
		case 0x1D: // Timer 3 Osc. Select
			return PMR_TMR3_OSC & 0x03;
		case 0x30: // Timer 1 Control A
			if (PMR_TMR1_CTRL_L & 0x80) {
				return PMR_TMR1_CTRL_L & 0x85; // 16-Bits
			} else {
				return PMR_TMR1_CTRL_L & 0x0D; // 8-Bits Mode
			}
		case 0x31: // Timer 1 Control B
			if (PMR_TMR1_CTRL_L & 0x80) {
				return PMR_TMR1_CTRL_H & 0x08; // 16-Bits Mode
			} else {
				return PMR_TMR1_CTRL_H & 0x0D; // 8-Bits Mode
			}
		case 0x32: // Timer 1 Preset A
			return (uint8_t)(MinxTimers.Tmr1PreA >> 24);
		case 0x33: // Timer 1 Preset B
			return (uint8_t)(MinxTimers.Tmr1PreB >> 24);
		case 0x34: // Timer 1 Pivot A
			return PMR_TMR1_PVT_L;
		case 0x35: // Timer 1 Pivot B
			return PMR_TMR1_PVT_H;
		case 0x36: // Timer 1 Count A
			return (uint8_t)(MinxTimers.Tmr1CntA >> 24);
		case 0x37: // Timer 1 Count B
			return (uint8_t)(MinxTimers.Tmr1CntB >> 24);
		case 0x38: // Timer 2 Control A
			if (PMR_TMR2_CTRL_L & 0x80) {
				return PMR_TMR2_CTRL_L & 0x85; // 16-Bits
			} else {
				return PMR_TMR2_CTRL_L & 0x0D; // 8-Bits Mode
			}
		case 0x39: // Timer 2 Control B
			if (PMR_TMR2_CTRL_L & 0x80) {	
				return PMR_TMR2_CTRL_H & 0x08; // 16-Bits Mode
			} else {
				return PMR_TMR2_CTRL_H & 0x0D; // 8-Bits Mode
			}
		case 0x3A: // Timer 2 Preset A
			return (uint8_t)(MinxTimers.Tmr2PreA >> 24);
		case 0x3B: // Timer 2 Preset B
			return (uint8_t)(MinxTimers.Tmr2PreB >> 24);
		case 0x3C: // Timer 2 Pivot A
			return PMR_TMR2_PVT_L;
		case 0x3D: // Timer 2 Pivot B
			return PMR_TMR2_PVT_H;
		case 0x3E: // Timer 2 Count A
			return (uint8_t)(MinxTimers.Tmr2CntA >> 24);
		case 0x3F: // Timer 2 Count B
			return (uint8_t)(MinxTimers.Tmr2CntB >> 24);
		case 0x40: // 256 Hz Timer Control
			return PMR_TMR256_CTRL;
		case 0x41: // 256 Hz Timer Counter
			return MinxTimers.Tmr8Cnt >> 24;
		case 0x48: // Timer 3 Control A
			if (PMR_TMR3_CTRL_L & 0x80) {	
				return PMR_TMR3_CTRL_L & 0x85; // 16-Bits
			} else {
				return PMR_TMR3_CTRL_L & 0x0D; // 8-Bits Mode
			}
		case 0x49: // Timer 3 Control B
			if (PMR_TMR3_CTRL_L & 0x80) {	
				return PMR_TMR3_CTRL_H & 0x08; // 16-Bits Mode
			} else {
				return PMR_TMR3_CTRL_H & 0x0D; // 8-Bits Mode
			}
		case 0x4A: // Timer 3 Preset A
			return (uint8_t)(MinxTimers.Tmr3PreA >> 24);
		case 0x4B: // Timer 3 Preset B
			return (uint8_t)(MinxTimers.Tmr3PreB >> 24);
		case 0x4C: // Timer 3 Pivot A
			return (uint8_t)MinxTimers.Timer3Piv;
		case 0x4D: // Timer 3 Pivot B
			return (uint8_t)(MinxTimers.Timer3Piv >> 8);
		case 0x4E: // Timer 3 Count A
			return (uint8_t)(MinxTimers.Tmr3CntA >> 24);
		case 0x4F: // Timer 3 Count B
			return (uint8_t)(MinxTimers.Tmr3CntB >> 24);
		default:   // Unused
			return reg;
	}
}

#define MinxTimers_UpdateScalarTimer1() {	\
	if (PMR_TMR1_ENA_OSC & 0x01) {	\
		if (MinxTimers.TmrXEna2) MinxTimers.Tmr1DecA = MinxTimers_CalculateDecOsc2[(PMR_TMR1_SCALE & 0xF)];	\
		else MinxTimers.Tmr1DecA = 0;	\
	} else {	\
		if (MinxTimers.TmrXEna1) MinxTimers.Tmr1DecA = MinxTimers_CalculateDecOsc1[(PMR_TMR1_SCALE & 0xF)];	\
		else MinxTimers.Tmr1DecA = 0;	\
	}	\
	if (PMR_TMR1_ENA_OSC & 0x02) {	\
		if (MinxTimers.TmrXEna2) MinxTimers.Tmr1DecB = MinxTimers_CalculateDecOsc2[((PMR_TMR1_SCALE >> 4) & 0xF)];	\
		else MinxTimers.Tmr1DecB = 0;	\
	} else {	\
		if (MinxTimers.TmrXEna1) MinxTimers.Tmr1DecB = MinxTimers_CalculateDecOsc1[((PMR_TMR1_SCALE >> 4) & 0xF)];	\
		else MinxTimers.Tmr1DecB = 0;	\
	}	\
}

#define MinxTimers_UpdateScalarTimer2() {	\
	if (PMR_TMR2_OSC & 0x01) {	\
		if (MinxTimers.TmrXEna2) MinxTimers.Tmr2DecA = MinxTimers_CalculateDecOsc2[(PMR_TMR2_SCALE & 0xF)];	\
		else MinxTimers.Tmr2DecA = 0;	\
	} else {	\
		if (MinxTimers.TmrXEna1) MinxTimers.Tmr2DecA = MinxTimers_CalculateDecOsc1[(PMR_TMR2_SCALE & 0xF)];	\
		else MinxTimers.Tmr2DecA = 0;	\
	}	\
	if (PMR_TMR2_OSC & 0x02) {	\
		if (MinxTimers.TmrXEna2) MinxTimers.Tmr2DecB = MinxTimers_CalculateDecOsc2[((PMR_TMR2_SCALE >> 4) & 0xF)];	\
		else MinxTimers.Tmr2DecB = 0;	\
	} else {	\
		if (MinxTimers.TmrXEna1) MinxTimers.Tmr2DecB = MinxTimers_CalculateDecOsc1[((PMR_TMR2_SCALE >> 4) & 0xF)];	\
		else MinxTimers.Tmr2DecB = 0;	\
	}	\
}

#define MinxTimers_UpdateScalarTimer3() {	\
	if (PMR_TMR3_OSC & 0x01) {	\
		if (MinxTimers.TmrXEna2) MinxTimers.Tmr3DecA = MinxTimers_CalculateDecOsc2[(PMR_TMR3_SCALE & 0xF)];	\
		else MinxTimers.Tmr3DecA = 0;	\
	} else {	\
		if (MinxTimers.TmrXEna1) MinxTimers.Tmr3DecA = MinxTimers_CalculateDecOsc1[(PMR_TMR3_SCALE & 0xF)];	\
		else MinxTimers.Tmr3DecA = 0;	\
	}	\
	if (PMR_TMR3_OSC & 0x02) {	\
		if (MinxTimers.TmrXEna2) MinxTimers.Tmr3DecB = MinxTimers_CalculateDecOsc2[((PMR_TMR3_SCALE >> 4) & 0xF)];	\
		else MinxTimers.Tmr3DecB = 0;	\
	} else {	\
		if (MinxTimers.TmrXEna1) MinxTimers.Tmr3DecB = MinxTimers_CalculateDecOsc1[((PMR_TMR3_SCALE >> 4) & 0xF)];	\
		else MinxTimers.Tmr3DecB = 0;	\
	}	\
}

void MinxTimers_WriteReg(unsigned char reg, unsigned char val)
{
	// 0x08 to 0x0F, 0x18 to 0x1F, 0x30 to 0x41, 0x48 to 0x4F
	switch(reg) {
		case 0x08: // Second Counter Control
			if (val & 0x02) MinxTimers.SecTimerCnt = 0x000000;
			PMR_SEC_CTRL = val & 0x01;
			return;
		case 0x09: // Second Counter Low
		case 0x0A: // Second Counter Med
		case 0x0B: // Second Counter High
			return;
		case 0x18: // Timer 1 Prescaler
			PMR_TMR1_SCALE = val;
			MinxTimers_UpdateScalarTimer1();
			return;
		case 0x19: // Timer 1 Osc. Select + Osc. Enable
			PMR_TMR1_ENA_OSC = val & 0x33;
			MinxTimers.TmrXEna2 = val & 0x10;
			MinxTimers.TmrXEna1 = val & 0x20;
			MinxTimers_UpdateScalarTimer1();
			MinxTimers_UpdateScalarTimer2(); // Because of the TmrXEna#
			MinxTimers_UpdateScalarTimer3(); // Because of the TmrXEna#
			return;
		case 0x1A: // Timer 2 Prescaler
			PMR_TMR2_SCALE = val;
			MinxTimers_UpdateScalarTimer2();
			return;
		case 0x1B: // Timer 2 Osc. Select
			PMR_TMR2_OSC = val & 0x03;
			MinxTimers_UpdateScalarTimer2();
			return;
		case 0x1C: // Timer 3 Prescaler
			PMR_TMR3_SCALE = val;
			MinxTimers_UpdateScalarTimer3();
			return;
		case 0x1D: // Timer 3 Osc. Select
			PMR_TMR3_OSC = val & 0x03;
			MinxTimers_UpdateScalarTimer3();
			return;
		case 0x30: // Timer 1 Control A
			PMR_TMR1_CTRL_L = val & 0x8D;
			MinxTimers.Tmr1LEna = val & 0x04;
			if (PMR_TMR1_CTRL_L & 0x80) {
				// 16-Bits
				MinxTimers.Tmr1WMode = 1;
				if (val & 0x02) {
					MinxTimers.Tmr1CntA = MinxTimers.Tmr1PreA;
					MinxTimers.Tmr1CntB = MinxTimers.Tmr1PreB;
				}
			} else {
				// 8-Bits
				MinxTimers.Tmr1WMode = 0;
				if (val & 0x02) {
					MinxTimers.Tmr1CntA = MinxTimers.Tmr1PreA;
				}
			}
			return;
		case 0x31: // Timer 1 Control B
			PMR_TMR1_CTRL_H = val & 0x0D;
			MinxTimers.Tmr1HEna = val & 0x04;
			if (PMR_TMR1_CTRL_L & 0x80) {
				// 16-Bits, unused
			} else {
				// 8-Bits
				if (val & 0x02) {
					MinxTimers.Tmr1CntB = MinxTimers.Tmr1PreB;
				}
			}
			return;
		case 0x32: // Timer 1 Preset A
			MinxTimers.Tmr1PreA = val << 24;
			return;
		case 0x33: // Timer 1 Preset B
			MinxTimers.Tmr1PreB = val << 24;
			return;
		case 0x34: // Timer 1 Pivot A
			PMR_TMR1_PVT_L = val;
			return;
		case 0x35: // Timer 1 Pivot B
			PMR_TMR1_PVT_H = val;
			return;
		case 0x36: // Timer 1 Count A
			return;
		case 0x37: // Timer 1 Count B
			return;
		case 0x38: // Timer 2 Control A
			PMR_TMR2_CTRL_L = val & 0x8D;
			MinxTimers.Tmr2LEna = val & 0x04;
			if (PMR_TMR2_CTRL_L & 0x80) {
				// 16-Bits
				MinxTimers.Tmr2WMode = 1;
				if (val & 0x02) {
					MinxTimers.Tmr2CntA = MinxTimers.Tmr2PreA;
					MinxTimers.Tmr2CntB = MinxTimers.Tmr2PreB;
				}
			} else {
				// 8-Bits
				MinxTimers.Tmr2WMode = 0;
				if (val & 0x02) {
					MinxTimers.Tmr2CntA = MinxTimers.Tmr2PreA;
				}
			}
			return;
		case 0x39: // Timer 2 Control B
			PMR_TMR2_CTRL_H = val & 0x0D;
			MinxTimers.Tmr2HEna = val & 0x04;
			if (PMR_TMR2_CTRL_L & 0x80) {
				// 16-Bits, unused
			} else {
				// 8-Bits
				if (val & 0x02) {
					MinxTimers.Tmr2CntB = MinxTimers.Tmr2PreB;
				}
			}
			return;
		case 0x3A: // Timer 2 Preset A
			MinxTimers.Tmr2PreA = val << 24;
			return;
		case 0x3B: // Timer 2 Preset B
			MinxTimers.Tmr2PreB = val << 24;
			return;
		case 0x3C: // Timer 2 Pivot A
			PMR_TMR2_PVT_L = val;
			return;
		case 0x3D: // Timer 2 Pivot B
			PMR_TMR2_PVT_H = val;
			return;
		case 0x3E: // Timer 2 Count A
			return;
		case 0x3F: // Timer 2 Count B
			return;
		case 0x40: // 256 Hz Timer Control
			PMR_TMR256_CTRL = val & 0x01;
			if (val & 0x02) {
				MinxTimers.Tmr8Cnt = 0;
			}
			return;
		case 0x41: // 256 Hz Timer Counter
			return;
		case 0x48: // Timer 3 Control A
			PMR_TMR3_CTRL_L = val & 0x8D;
			MinxTimers.Tmr3LEna = val & 0x04;
			if (PMR_TMR3_CTRL_L & 0x80) {
				// 16-Bits
				MinxTimers.Tmr3WMode = 1;
				if (val & 0x02) {
					MinxTimers.Tmr3CntA = MinxTimers.Tmr3PreA;
					MinxTimers.Tmr3CntB = MinxTimers.Tmr3PreB;
				}
			} else {
				// 8-Bits
				MinxTimers.Tmr3WMode = 0;
				if (val & 0x02) {
					MinxTimers.Tmr3CntA = MinxTimers.Tmr3PreA;
				}
			}
			return;
		case 0x49: // Timer 3 Control B
			PMR_TMR3_CTRL_H = val & 0x0D;
			MinxTimers.Tmr3HEna = val & 0x04;
			if (PMR_TMR3_CTRL_L & 0x80) {
				// 16-Bits, unused
			} else {
				// 8-Bits
				if (val & 0x02) {
					MinxTimers.Tmr3CntB = MinxTimers.Tmr3PreB;
				}
			}
			return;
		case 0x4A: // Timer 3 Preset A
			MinxTimers.Tmr3PreA = val << 24;
			return;
		case 0x4B: // Timer 3 Preset B
			MinxTimers.Tmr3PreB = val << 24;
			return;
		case 0x4C: // Timer 3 Pivot A
			MinxTimers.Timer3Piv = (MinxTimers.Timer3Piv & 0xFF00) | val;
			return;
		case 0x4D: // Timer 3 Pivot B
			MinxTimers.Timer3Piv = (MinxTimers.Timer3Piv & 0x00FF) | (val << 8);
			return;
		case 0x4E: // Timer 3 Count A
			return;
		case 0x4F: // Timer 3 Count B
			return;
	}
}
