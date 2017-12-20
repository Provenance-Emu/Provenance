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

#ifndef HARDWARE_EMU
#define HARDWARE_EMU

#include <stdint.h>

enum {
	TRAPPOINT_BREAK      = 1,	// Break
	TRAPPOINT_WATCHREAD  = 2,	// Watch (Read)
	TRAPPOINT_WATCHWRITE = 4,	// Watch (Write)
	TRAPPOINT_WATCH      = 6	// Watch (Read & Write)
};

// Trap points for breakpoints/watchpoints
extern uint8_t *PMD_TrapPoints;

// Trace code addresses
#define TRACECODE_LENGTH 10000
extern uint32_t TRACAddr[TRACECODE_LENGTH];
extern int TRACPoint;

// Cycle timers
extern int CYCTmr1Ena;
extern uint32_t CYCTmr1Cnt;
extern int CYCTmr2Ena;
extern uint32_t CYCTmr2Cnt;
extern int CYCTmr3Ena;
extern uint32_t CYCTmr3Cnt;

// Breakpoints, watchpoints, exceptions and halt/stop
extern int PMD_EnableBreakpoints;
extern int PMD_EnableWatchpoints;
extern int PMD_EnableExceptions;
extern int PMD_EnableHalt;
extern int PMD_EnableStop;
extern int PMD_MessageBreakpoints;
extern int PMD_MessageWatchpoints;
extern int PMD_MessageExceptions;
extern int PMD_MessageHalt;
extern int PMD_MessageStop;

// Get physical PC location
static inline uint32_t PhysicalPC()
{
	if (MinxCPU.PC.W.L >= 0x8000) {
		return (MinxCPU.PC.B.I << 15) | (MinxCPU.PC.W.L & 0x7FFF);
	} else {
		return MinxCPU.PC.W.L;
	}
}

// New MIN was loaded
int PMHD_MINLoaded();

// Free resources
void PMHD_FreeResources();

// System reset
void PMHD_Reset(int hardreset);

// Get physical PC location
uint32_t PokeMini_GetPhysicalPC();

// Emulate single instruction, return cycles ran
int PokeMini_EmulateStep();

// Skip current instruction, return cycles skipped
int PokeMini_EmulateStepSkip();

// Emulate X cycles, return remaining
int PokeMini_EmulateCycles(int lcylc);

// Emulate 1 frame, return cycles ran
int PokeMini_EmulateFrame();

#endif
