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

// Emulate X cycles, return remaining
int PokeMini_EmulateCycles(int lcylc)
{
	if (RequireSoundSync) {
		while (lcylc > 0) {
			if (StallCPU) PokeHWCycles = StallCycles;
			else PokeHWCycles = MinxCPU_Exec();
			MinxTimers_Sync();
			MinxPRC_Sync();
			MinxAudio_Sync();
			lcylc -= PokeHWCycles;
		}
	} else {
		while (lcylc > 0) {
			if (StallCPU) PokeHWCycles = StallCycles;
			else PokeHWCycles = MinxCPU_Exec();
			MinxTimers_Sync();
			MinxPRC_Sync();
			lcylc -= PokeHWCycles;
		}
	}

	return lcylc;
}

// Emulate 1 frame, return cycles ran
static int PokeMini_EmulateFrameRun;
int PokeMini_EmulateFrame(void)
{
	int lcylc = 0;
	int synccylc = CommandLine.synccycles;

	PokeMini_EmulateFrameRun = 1;

	if (RequireSoundSync) {
		while (PokeMini_EmulateFrameRun) {
			PokeHWCycles = 0;
			while (PokeHWCycles < synccylc) {
				if (StallCPU) PokeHWCycles += StallCycles;
				else PokeHWCycles += MinxCPU_Exec();
			}
			MinxTimers_Sync();
			MinxPRC_Sync();
			MinxAudio_Sync();
			lcylc += PokeHWCycles;
		}
	} else {
		while (PokeMini_EmulateFrameRun) {
			PokeHWCycles = 0;
			while (PokeHWCycles < synccylc) {
				if (StallCPU) PokeHWCycles += StallCycles;
				else PokeHWCycles += MinxCPU_Exec();
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
#ifdef PERFORMANCE
	if (addr >= 0x2100) {
		// ROM Read (ROM Cartridge)
		if (PM_ROM) return PM_ROM[addr & PM_ROM_Mask];
#else
	if (addr >= 0x200000) {
		// Open bus
		return MinxCPU.IR;
	} else if (addr >= 0x2100) {
		// ROM Read (Multicard)
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
			case 0x88: case 0x89: case 0x8A: case 0x8B:
			case 0x8C: case 0x8D: case 0x8E: case 0x8F:
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
#ifdef PERFORMANCE
	if (addr >= 0x2100) {
		// Do nothing...
#else
	if (addr >= 0x200000) {
		// Open bus
	} else if (addr >= 0x2100) {
		// ROM Write
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
			case 0x88: case 0x89: case 0x8A:
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
			PokeDPrint(POKEMSG_ERR, "Unknown instruction %08X before V=%02X,PC=%04X\n", (unsigned int)ir, (int)MinxCPU.PC.B.I, (int)MinxCPU.PC.W.L);
			return;
		case EXCEPTION_CRASH_INSTRUCTION:
			PokeDPrint(POKEMSG_ERR, "Crash instruction %08X before V=%02X,PC=%04X\n", (unsigned int)ir, (int)MinxCPU.PC.B.I, (int)MinxCPU.PC.W.L);
			return;
		case EXCEPTION_UNSTABLE_INSTRUCTION:
			PokeDPrint(POKEMSG_ERR, "Unstable instruction %08X before V=%02X,PC=%04X\n", (unsigned int)ir, (int)MinxCPU.PC.B.I, (int)MinxCPU.PC.W.L);
			return;
		case EXCEPTION_DIVISION_BY_ZERO:
			PokeDPrint(POKEMSG_ERR, "Division by zero before V=%02X,PC=%04X\n", (int)MinxCPU.PC.B.I, (int)MinxCPU.PC.W.L);
			return;
		default:
			return;
	}
}

void MinxCPU_OnSleep(int type)
{
	switch (type) {
		case MINX_SLEEP_HALT:
			//PokeDPrint(POKEMSG_ERR, "Halt called before V=%02X,PC=%04X\n", (int)MinxCPU.PC.B.I, (int)MinxCPU.PC.W.L); // TOO NOISY!
			return;
		case MINX_SLEEP_STOP:
			PokeDPrint(POKEMSG_ERR, "Sleep called before V=%02X,PC=%04X\n", (int)MinxCPU.PC.B.I, (int)MinxCPU.PC.W.L);
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
