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

// Include Standards
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#include "PokeMini.h"
#include "InstructionProc.h"
#include "PokeMini_Debug.h"
#include "Hardware_Debug.h"
#include "CPUWindow.h"

int PMD_TrapFound = 0;
int PMD_EnableBreakpoints = 1;
int PMD_EnableWatchpoints = 1;
int PMD_EnableExceptions = 1;
int PMD_EnableHalt = 0;
int PMD_EnableStop = 1;
int PMD_MessageBreakpoints = 0;
int PMD_MessageWatchpoints = 0;
int PMD_MessageExceptions = 1;
int PMD_MessageHalt = 0;
int PMD_MessageStop = 1;
uint8_t *PMD_TrapPoints;	// Trap points for breakpoint & watchpoint:
				// &1 = Breakpoint, &16 = Watchpoint Read, &32 = Watchpoint Write

uint32_t TRACAddr[TRACECODE_LENGTH];	// 0xFFFFFFFF == Invalid
int TRACPoint = 0;

int CYCTmr1Ena = 0;		// Cycles Timer 1
uint32_t CYCTmr1Cnt = 0;
int CYCTmr2Ena = 0;		// Cycles Timer 2
uint32_t CYCTmr2Cnt = 0;
int CYCTmr3Ena = 0;		// Cycles Timer 3
uint32_t CYCTmr3Cnt = 0;

static void BreakpointReport(void)
{
	int val;
	if (dclc_fullrange) {
		if (MinxCPU.PC.W.L >= 0x8000) {
			val = (MinxCPU.PC.B.I << 15) | (MinxCPU.PC.W.L & 0x7FFF);
			if (PMD_MessageBreakpoints) Add_InfoMessage("[Break] Breakpoint at $%06X", val);
			else Set_StatusLabel("[Break] Breakpoint at $%06X", val);
		} else {
			if (PMD_MessageBreakpoints) Add_InfoMessage("[Break] Breakpoint at $%06X", (int)MinxCPU.PC.W.L);
			else Set_StatusLabel("[Break] Breakpoint at $%06X", (int)MinxCPU.PC.W.L);
		}
	} else {
		if (PMD_MessageBreakpoints) Add_InfoMessage("[Break] Breakpoint at (%02X)$%04X", (int)MinxCPU.PC.B.I, (int)MinxCPU.PC.W.L);
		else Set_StatusLabel("[Break] Breakpoint at (%02X)$%04X", (int)MinxCPU.PC.B.I, (int)MinxCPU.PC.W.L);
	}
}

static void WatchpointReport(int access, uint32_t addr)
{
	int val;
	if (dclc_fullrange) {
		if (MinxCPU.PC.W.L >= 0x8000) {
			val = (MinxCPU.PC.B.I << 15) | (MinxCPU.PC.W.L & 0x7FFF);
			if (PMD_MessageBreakpoints) Add_InfoMessage("[Break] Watchpoint at $%06X before $%06X", access ? "write" : "read", (int)addr, val);
			else Set_StatusLabel("[Break] Watchpoint at $%06X before $%06X", access ? "write" : "read", (int)addr, val);
		} else {
			if (PMD_MessageBreakpoints) Add_InfoMessage("[Break] Watchpoint at $%06X before $%06X", access ? "write" : "read", (int)addr, (int)MinxCPU.PC.W.L);
			else Set_StatusLabel("[Break] Watchpoint at $%06X before $%06X", access ? "write" : "read", (int)addr, (int)MinxCPU.PC.W.L);
		}
	} else {
		if (PMD_MessageBreakpoints) Add_InfoMessage("[Break] Watchpoint %s at $%06X before (%02X)$%04X", access ? "write" : "read", (int)addr, (int)MinxCPU.PC.B.I, (int)MinxCPU.PC.W.L);
		else Set_StatusLabel("[Break] Watchpoint %s at $%06X before (%02X)$%04X", access ? "write" : "read", (int)addr, (int)MinxCPU.PC.B.I, (int)MinxCPU.PC.W.L);
	}
}

// New MIN was loaded
int PMHD_MINLoaded(void)
{
	static int PM_ROM_OldSize = 0;
	if (PMD_TrapPoints) {
		// Resize
		PMD_TrapPoints = (uint8_t *)realloc(PMD_TrapPoints, PM_ROM_Size);
		if (PM_ROM_Size > PM_ROM_OldSize) {
			memset((uint8_t *)PMD_TrapPoints + PM_ROM_OldSize, 0, PM_ROM_Size - PM_ROM_OldSize);
		}
		PM_ROM_OldSize = PM_ROM_Size;
	} else {
		// New
		PMD_TrapPoints = (uint8_t *)malloc(PM_ROM_Size);
		if (!PMD_TrapPoints) return 0;
		memset(PMD_TrapPoints, 0, PM_ROM_Size);
		PM_ROM_OldSize = PM_ROM_Size;
	}

	return 1;
}

// Free resources
void PMHD_FreeResources(void)
{
	if (PMD_TrapPoints) {
		free(PMD_TrapPoints);
		PMD_TrapPoints = NULL;
	}
}

// System reset
void PMHD_Reset(int hardreset)
{
	int i;
	for (i=0; i<TRACECODE_LENGTH; i++) TRACAddr[i] = 0xFFFFFFFF;
	TRACPoint = 0;
}

static inline int PokeMini_BreakPointTest(int cylc)
{
	uint32_t pmaddr = PhysicalPC() & PM_ROM_Mask;
	TRACAddr[TRACPoint] = pmaddr;
	TRACPoint--;
	if (TRACPoint < 0) TRACPoint = TRACECODE_LENGTH - 1;
	if (CYCTmr1Ena) CYCTmr1Cnt += cylc;
	if (CYCTmr2Ena) CYCTmr2Cnt += cylc;
	if (CYCTmr3Ena) CYCTmr3Cnt += cylc;
	if ((PMD_TrapPoints[pmaddr] & TRAPPOINT_BREAK) && PMD_EnableBreakpoints) {
		return 1;
	}
	return 0;
}

// Emulate single instruction, return cycles ran
int PokeMini_EmulateStep(void)
{
	if (RequireSoundSync) {
		if (StallCPU) PokeHWCycles = StallCycles;
		else PokeHWCycles = MinxCPU_Exec();
		MinxTimers_Sync();
		MinxPRC_Sync();
		MinxAudio_Sync();
	} else {
		if (StallCPU) PokeHWCycles = StallCycles;
		else PokeHWCycles = MinxCPU_Exec();
		MinxTimers_Sync();
		MinxPRC_Sync();
	}
	if (PokeMini_BreakPointTest(PokeHWCycles)) {
		set_emumode(EMUMODE_STOP, 0);
		BreakpointReport();
	}

	return PokeHWCycles;
}

// Skip current instruction, return cycles skipped
int PokeMini_EmulateStepSkip(void)
{
	int size, pp = MinxCPU.PC.W.L;
	if (pp >= 0x8000) {
		pp = (MinxCPU.PC.B.I << 15) | (pp & 0x7FFF);
	}
	GetInstructionInfo(MinxCPU_OnRead, 1, pp, NULL, &size);
	MinxCPU.PC.W.L += size;

	return size;
}

// Emulate X cycles, return remaining
int PokeMini_EmulateCycles(int lcylc)
{
	PMD_TrapFound = 0;

	if (RequireSoundSync) {
		while (lcylc > 0) {
			if (StallCPU) PokeHWCycles = StallCycles;
			else PokeHWCycles = MinxCPU_Exec();
			MinxTimers_Sync();
			MinxPRC_Sync();
			MinxAudio_Sync();
			lcylc -= PokeHWCycles;
			if (PokeMini_BreakPointTest(PokeHWCycles)) {
				PMD_TrapFound = 1;
				BreakpointReport();
			}
			if (PMD_TrapFound) {
				set_emumode(EMUMODE_STOP, 0);
				return lcylc;
			}
		}
	} else {
		while (lcylc > 0) {
			if (StallCPU) PokeHWCycles = StallCycles;
			else PokeHWCycles = MinxCPU_Exec();
			MinxTimers_Sync();
			MinxPRC_Sync();
			lcylc -= PokeHWCycles;
			if (PokeMini_BreakPointTest(PokeHWCycles)) {
				PMD_TrapFound = 1;
				BreakpointReport();
			}
			if (PMD_TrapFound) {
				set_emumode(EMUMODE_STOP, 0);
				return lcylc;
			}
		}
	}

	return lcylc;
}

// Emulate 1 frame, return cycles ran
static int PokeMini_EmulateFrameRun;
int PokeMini_EmulateFrame(void)
{
	int lcylc = 0;

	PMD_TrapFound = 0;
	PokeMini_EmulateFrameRun = 1;

	if (RequireSoundSync) {
		while (PokeMini_EmulateFrameRun) {
			PokeHWCycles = 0;
			while (PokeHWCycles < CommandLine.synccycles) {
				if (StallCPU) PokeHWCycles += StallCycles;
				else {
					PokeHWCycles += MinxCPU_Exec();
					if (PokeMini_BreakPointTest(PokeHWCycles)) {
						PMD_TrapFound = 1;
						BreakpointReport();
					}
					if (PMD_TrapFound) {
						set_emumode(EMUMODE_STOP, 0);
						MinxTimers_Sync();
						MinxPRC_Sync();
						MinxAudio_Sync();
						return lcylc + PokeHWCycles;
					}
				}
			}
			MinxTimers_Sync();
			MinxPRC_Sync();
			MinxAudio_Sync();
			lcylc += PokeHWCycles;
		}
	} else {
		while (PokeMini_EmulateFrameRun) {
			PokeHWCycles = 0;
			while (PokeHWCycles < CommandLine.synccycles) {
				if (StallCPU) PokeHWCycles += StallCycles;
				else {
					PokeHWCycles += MinxCPU_Exec();
					if (PokeMini_BreakPointTest(PokeHWCycles)) {
						PMD_TrapFound = 1;
						BreakpointReport();
					}
					if (PMD_TrapFound) {
						set_emumode(EMUMODE_STOP, 0);
						MinxTimers_Sync();
						MinxPRC_Sync();
						return lcylc + PokeHWCycles;
					}
				}
			}
			MinxTimers_Sync();
			MinxPRC_Sync();
			lcylc += PokeHWCycles;
		}
	}

	return lcylc;
}

// -------------------
// Internal Processing
// -------------------

uint8_t MinxCPU_OnRead(int cpu, uint32_t addr)
{
	if (cpu && (PMD_TrapPoints[addr & PM_ROM_Mask] & TRAPPOINT_WATCHREAD) && PMD_EnableWatchpoints) {
		PMD_TrapFound = 1;
		WatchpointReport(0, addr);
	}
	if (addr >= 0x2100) {
		// ROM Read
#ifdef PERFORMANCE
		if (PM_ROM) return PM_ROM[addr & PM_ROM_Mask];
#else
		return MulticartRead(addr);
#endif
	} else if (addr >= 0x2000) {
		// I/O Read
		uint8_t reg = (uint8_t)addr;
		switch(reg) {
			// Misc interface
			case 0x00: // System Control 1
				return PMR_SYS_CTRL1;
			case 0x01: // System Control 2
				return PMR_SYS_CTRL2;
			case 0x02: // System Control 3
				return PMR_SYS_CTRL3;

			// IRQ interface
			case 0x20: case 0x21: case 0x22: case 0x23:
			case 0x24: case 0x25: case 0x26: case 0x27:
			case 0x28: case 0x29: case 0x2A:
				return MinxIRQ_ReadReg(cpu, reg);

			// Timers interface
			case 0x08: case 0x09: case 0x0A: case 0x0B:
			case 0x18: case 0x19: case 0x1A: case 0x1B:
			case 0x1C: case 0x1D: case 0x1E: case 0x1F:
			case 0x30: case 0x31: case 0x32: case 0x33:
			case 0x34: case 0x35: case 0x36: case 0x37:
			case 0x38: case 0x39: case 0x3A: case 0x3B:
			case 0x3C: case 0x3D: case 0x3E: case 0x3F:
			case 0x40: case 0x41:
			case 0x48: case 0x49: case 0x4A: case 0x4B:
			case 0x4C: case 0x4D: case 0x4E: case 0x4F:
				return MinxTimers_ReadReg(reg);

			// Parallel I/O interface & Power
			case 0x10:
			case 0x44: case 0x45: case 0x46: case 0x47:
			case 0x50: case 0x51: case 0x52: case 0x53:
			case 0x54: case 0x55:
			case 0x60: case 0x61: case 0x62:
				return MinxIO_ReadReg(cpu, reg);

			// Program Rendering Chip interface
			case 0x80: case 0x81: case 0x82: case 0x83:
			case 0x84: case 0x85: case 0x86: case 0x87:
			case 0x88: case 0x89: case 0x8A:
				return MinxPRC_ReadReg(reg);

			// Color PRC interface
			case 0xF0: case 0xF1: case 0xF2: case 0xF3:
			case 0xF4: case 0xF5: case 0xF6: case 0xF7:
				return MinxColorPRC_ReadReg(cpu, reg);

			// LCD interface
			case 0xFE: case 0xFF:
				return MinxLCD_ReadReg(cpu, reg);

			// Audio interface
			case 0x70: case 0x71:
				return MinxAudio_ReadReg(reg);

			// Open bus
			default:
				return MinxCPU.IR;
		}
	} else if (addr >= 0x1000) {
		// RAM Read
		return PM_RAM[addr-0x1000];
	} else {
		// BIOS Read
		return PM_BIOS[addr];
	}
	return 0xFF;
}

void MinxCPU_OnWrite(int cpu, uint32_t addr, uint8_t data)
{
	static uint8_t dataold = 0x00;
	if (cpu && (PMD_TrapPoints[addr & PM_ROM_Mask] & TRAPPOINT_WATCHWRITE) && PMD_EnableWatchpoints) {
		PMD_TrapFound = 1;
		WatchpointReport(1, addr);
	}
	if (addr >= 0x2100) {
		// ROM Write
#ifndef PERFORMANCE
		MulticartWrite(addr, data);
#endif
		return;
	} else if (addr >= 0x2000) {
		// I/O Write
		uint8_t reg = (uint8_t)addr;
		switch(reg) {
			// Misc interface
			case 0x00: // System Control 1
				PMR_SYS_CTRL1 = data;
				return;
			case 0x01: // System Control 2
				PMR_SYS_CTRL2 = data;
				return;
			case 0x02: // System Control 3
				PMR_SYS_CTRL3 = data;
				return;

			// IRQ interface
			case 0x20: case 0x21: case 0x22: case 0x23:
			case 0x24: case 0x25: case 0x26: case 0x27:
			case 0x28: case 0x29: case 0x2A:
				MinxIRQ_WriteReg(cpu, reg, data);
				return;

			// Timers interface
			case 0x08: case 0x09: case 0x0A: case 0x0B:
			case 0x18: case 0x19: case 0x1A: case 0x1B:
			case 0x1C: case 0x1D: case 0x1E: case 0x1F:
			case 0x30: case 0x31: case 0x32: case 0x33:
			case 0x34: case 0x35: case 0x36: case 0x37:
			case 0x38: case 0x39: case 0x3A: case 0x3B:
			case 0x3C: case 0x3D: case 0x3E: case 0x3F:
			case 0x40: case 0x41:
			case 0x48: case 0x49: case 0x4A: case 0x4B:
			case 0x4C: case 0x4D: case 0x4E: case 0x4F:
				MinxTimers_WriteReg(reg, data);
				return;

			// Parallel I/O interface & Power
			case 0x10:
			case 0x44: case 0x45: case 0x46: case 0x47:
			case 0x50: case 0x51: case 0x52: case 0x53:
			case 0x54: case 0x55:
			case 0x60: case 0x61: case 0x62:
				MinxIO_WriteReg(cpu, reg, data);
				return;

			// Program Rendering Chip interface
			case 0x80: case 0x81: case 0x82: case 0x83:
			case 0x84: case 0x85: case 0x86: case 0x87:
			case 0x88: case 0x89: case 0x8A: case 0x8B:
			case 0x8C: case 0x8D: case 0x8E: case 0x8F:
				MinxPRC_WriteReg(reg, data);
				return;

			// Color PRC interface
			case 0xF0: case 0xF1: case 0xF2: case 0xF3:
			case 0xF4: case 0xF5: case 0xF6: case 0xF7:
				MinxColorPRC_WriteReg(reg, data);
				return;

			// LCD interface
			case 0xFE: case 0xFF:
				MinxLCD_WriteReg(cpu, reg, data);
				return;

			// Audio interface
			case 0x70: case 0x71:
				MinxAudio_WriteReg(reg, data);
				return;

			// Debug output (Char, Hex, Dec)
			case 0xD0:
				if (dclc_debugout) {
					if (data != 27) {
						if (dataold == 27) {
							Cmd_DebugOutput((int)data);
						} else {
							Add_DebugOutputChar(data);
						}
					}
				}
				dataold = data;
				return;
			case 0xD1: case 0xD2: case 0xD3:
				if (dclc_debugout) Add_DebugOutputNumber8(data, reg & 3);
				return;
			case 0xD4: case 0xD5: case 0xD6: case 0xD7:
				if (dclc_debugout) Add_DebugOutputNumber16(data, reg & 3);
				return;
			case 0xDE: case 0xDF:
				if (dclc_debugout) Add_DebugOutputFixed8_8(data, reg & 1);
				return;
		}
	} else if (addr >= 0x1300) {
		// RAM Write
		PM_RAM[addr-0x1000] = data;
		return;
	} else if (addr >= 0x1000) {
		// RAM Write / FrameBuffer
		PM_RAM[addr-0x1000] = data;
		if (PRCColorMap) MinxColorPRC_WriteFramebuffer(addr-0x1000, data);
		return;
	} else {
		// BIOS Write (Ignored)
		return;
	}
}

void MinxCPU_OnException(int type, uint32_t ir)
{
	switch (type) {
		case EXCEPTION_UNKNOWN_INSTRUCTION:
			if (PMD_EnableExceptions) {
				PMD_TrapFound = 1;
				if (PMD_MessageExceptions) Add_InfoMessage("[Break] Unknown instruction %08X before V=%02X,PC=%04X\n", ir, (int)MinxCPU.PC.B.I, (int)MinxCPU.PC.W.L);
				else Set_StatusLabel("[Break] Unknown instruction %08X before V=%02X,PC=%04X\n", ir, (int)MinxCPU.PC.B.I, (int)MinxCPU.PC.W.L);
			}
			return;
		case EXCEPTION_CRASH_INSTRUCTION:
			if (PMD_EnableExceptions) {
				PMD_TrapFound = 1;
				if (PMD_MessageExceptions) Add_InfoMessage("[Break] Crash instruction %08X before V=%02X,PC=%04X\n", ir, (int)MinxCPU.PC.B.I, (int)MinxCPU.PC.W.L);
				else Set_StatusLabel("[Break] Crash instruction %08X before V=%02X,PC=%04X\n", ir, (int)MinxCPU.PC.B.I, (int)MinxCPU.PC.W.L);
			}
			return;
		case EXCEPTION_UNSTABLE_INSTRUCTION:
			if (PMD_EnableExceptions) {
				PMD_TrapFound = 1;
				if (PMD_MessageExceptions) Add_InfoMessage("[Break] Unstable instruction %08X before V=%02X,PC=%04X\n", ir, (int)MinxCPU.PC.B.I, (int)MinxCPU.PC.W.L);
				else Set_StatusLabel("[Break] Unstable instruction %08X before V=%02X,PC=%04X\n", ir, (int)MinxCPU.PC.B.I, (int)MinxCPU.PC.W.L);
			}
			return;
		case EXCEPTION_DIVISION_BY_ZERO:
			if (PMD_EnableExceptions) {
				PMD_TrapFound = 1;
				if (PMD_MessageExceptions) Add_InfoMessage("[Break] Division by zero before V=%02X,PC=%04X\n", (int)MinxCPU.PC.B.I, (int)MinxCPU.PC.W.L);
				else Set_StatusLabel("[Break] Division by zero before V=%02X,PC=%04X\n", (int)MinxCPU.PC.B.I, (int)MinxCPU.PC.W.L);
			}
			return;
		default:
			return;
	}
}

void MinxCPU_OnSleep(int type)
{
	switch (type) {
		case MINX_SLEEP_HALT:
			if (PMD_EnableHalt) {
				PMD_TrapFound = 1;
				if (PMD_MessageHalt) Add_InfoMessage("[Sleep] Halt called before V=%02X,PC=%04X\n", (int)MinxCPU.PC.B.I, (int)MinxCPU.PC.W.L);
				else Set_StatusLabel("[Sleep] Halt called before V=%02X,PC=%04X\n", (int)MinxCPU.PC.B.I, (int)MinxCPU.PC.W.L);
			}
			return;
		case MINX_SLEEP_STOP:
			if (PMD_EnableStop) {
				PMD_TrapFound = 1;
				if (PMD_MessageStop) Add_InfoMessage("[Sleep] Stop called before V=%02X,PC=%04X\n", (int)MinxCPU.PC.B.I, (int)MinxCPU.PC.W.L);
				else Set_StatusLabel("[Sleep] Stop called before V=%02X,PC=%04X\n", (int)MinxCPU.PC.B.I, (int)MinxCPU.PC.W.L);
			}
			return;
		default:
			return;
	}
}

void MinxCPU_OnIRQHandle(uint8_t cpuflag, uint8_t shift_u)
{
	// Disable or enable master interrupt and check for interrupts
	if (shift_u) {
		MinxIRQ_MasterIRQ = 0;
	} else {
		if ((cpuflag & 0xC0) == 0xC0) MinxIRQ_MasterIRQ = 0;
		else {
			MinxIRQ_MasterIRQ = 1;
			MinxIRQ_Process();
		}
	}
}

void MinxCPU_OnIRQAct(uint8_t intr)
{
	// Set and process interrupt
	MinxIRQ_SetIRQ(intr);
}

void MinxIRQ_OnIRQ(uint8_t intr)
{
	// From IRQ module, call the CPU interrupt
	MinxCPU_CallIRQ(intr << 1);
}

void MinxPRC_On72HzRefresh(int prcrender)
{
	// Frame rendered
	if ((PokeMini_LCDMode == LCDMODE_3SHADES) && (prcrender)) memcpy(LCDPixelsA, LCDPixelsD, 96*64);
	if (LCDDirty) MinxLCD_Render();
	if (PokeMini_LCDMode == LCDMODE_ANALOG) MinxLCD_DecayRefresh();
	PokeMini_EmulateFrameRun = 0;
}
