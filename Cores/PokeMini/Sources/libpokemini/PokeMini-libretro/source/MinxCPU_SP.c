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

#include "MinxCPU.h"

int MinxCPU_ExecSPCE(void)
{
	// Read IR
	MinxCPU.IR = Fetch8();

	// Process instruction
	switch(MinxCPU.IR) {
		// TODO!
		default:
			MinxCPU_OnException(EXCEPTION_UNKNOWN_INSTRUCTION, (MinxCPU.IR << 16) + 0xCEFF);
			return 64;
	}
}

int MinxCPU_ExecSPCF(void)
{
	// Read IR
	MinxCPU.IR = Fetch8();

	// Process instruction
	switch(MinxCPU.IR) {
		case 0x00: case 0x01: case 0x02: case 0x03: // Decrement BA
			MinxCPU.BA.W.L = DEC16(MinxCPU.BA.W.L);
			return 16;
		case 0x04: case 0x05: case 0x06: case 0x07: // Decrement BA if Carry = 0
			if (!(MinxCPU.F & MINX_FLAG_CARRY)) MinxCPU.BA.W.L = DEC16(MinxCPU.BA.W.L);
			return 16;
		case 0x08: case 0x09: case 0x0A: case 0x0B: // Increment BA
			MinxCPU.BA.W.L = INC16(MinxCPU.BA.W.L);
			return 16;
		case 0x0C: case 0x0D: case 0x0E: case 0x0F: // Increment BA if Carry = 0
			if (!(MinxCPU.F & MINX_FLAG_CARRY)) MinxCPU.BA.W.L = INC16(MinxCPU.BA.W.L);
			return 16;
		case 0x10: case 0x11: case 0x12: case 0x13: // Decrement BA
			MinxCPU.BA.W.L = DEC16(MinxCPU.BA.W.L);
			return 16;
		case 0x14: case 0x15: case 0x16: case 0x17: // Decrement BA if Carry = 0
			if (!(MinxCPU.F & MINX_FLAG_CARRY)) MinxCPU.BA.W.L = DEC16(MinxCPU.BA.W.L);
			return 16;
		case 0x18: case 0x19: case 0x1A: case 0x1B: // Increment BA (Doesn't save result!!)
			INC16(MinxCPU.BA.W.L);
			return 16;
		case 0x1C: case 0x1D: case 0x1E: case 0x1F: // Increment BA if Carry = 0
			if (!(MinxCPU.F & MINX_FLAG_CARRY)) MinxCPU.BA.W.L = INC16(MinxCPU.BA.W.L);
			return 16;

		case 0x20: case 0x21: case 0x22: case 0x23: // Decrement HL
			MinxCPU.HL.W.L = DEC16(MinxCPU.HL.W.L);
			return 16;
		case 0x24: case 0x25: case 0x26: case 0x27: // Decrement HL if Carry = 0
			if (!(MinxCPU.F & MINX_FLAG_CARRY)) MinxCPU.HL.W.L = DEC16(MinxCPU.HL.W.L);
			return 16;
		case 0x28: case 0x29: case 0x2A: case 0x2B: // Increment HL
			MinxCPU.HL.W.L = INC16(MinxCPU.HL.W.L);
			return 16;
		case 0x2C: case 0x2D: case 0x2E: case 0x2F: // Increment HL if Carry = 0
			if (!(MinxCPU.F & MINX_FLAG_CARRY)) MinxCPU.HL.W.L = INC16(MinxCPU.HL.W.L);
			return 16;
		case 0x30: case 0x31: case 0x32: case 0x33: // Decrement HL
			MinxCPU.HL.W.L = DEC16(MinxCPU.HL.W.L);
			return 16;
		case 0x34: case 0x35: case 0x36: case 0x37: // Decrement HL if Carry = 0
			if (!(MinxCPU.F & MINX_FLAG_CARRY)) MinxCPU.HL.W.L = DEC16(MinxCPU.HL.W.L);
			return 16;
		case 0x38: case 0x39: case 0x3A: case 0x3B: // Increment HL (Doesn't save result!!)
			INC16(MinxCPU.HL.W.L);
			return 16;
		case 0x3C: case 0x3D: case 0x3E: case 0x3F: // Increment HL if Carry = 0
			if (!(MinxCPU.F & MINX_FLAG_CARRY)) MinxCPU.HL.W.L = INC16(MinxCPU.HL.W.L);
			return 16;

		case 0x40: case 0x41: // Decrement X
			MinxCPU.X.W.L = DEC16(MinxCPU.X.W.L);
			return 16;
		case 0x42: case 0x43: // Decrement Y
			MinxCPU.X.W.L = DEC16(MinxCPU.X.W.L);
			return 16;
		case 0x44: case 0x45: // Decrement SP
			MinxCPU.SP.W.L = DEC16(MinxCPU.SP.W.L);
			return 16;
		case 0x46: case 0x47: // CRASH
			MinxCPU_OnException(EXCEPTION_CRASH_INSTRUCTION, (MinxCPU.IR << 16) | 0xBFCF);
			return 16;

		case 0x48: case 0x49: // Increment X
			MinxCPU.X.W.L = INC16(MinxCPU.X.W.L);
			return 16;
		case 0x4A: case 0x4B: // Increment Y
			MinxCPU.X.W.L = INC16(MinxCPU.X.W.L);
			return 16;
		case 0x4C: case 0x4D: // Increment SP
			MinxCPU.SP.W.L = INC16(MinxCPU.SP.W.L);
			return 16;
		case 0x4E: case 0x4F: // CRASH
			MinxCPU_OnException(EXCEPTION_CRASH_INSTRUCTION, (MinxCPU.IR << 16) | 0xBFCF);
			return 16;

		case 0x50: case 0x51: // Decrement X
			MinxCPU.X.W.L = DEC16(MinxCPU.X.W.L);
			return 16;
		case 0x52: case 0x53: // Decrement Y
			MinxCPU.X.W.L = DEC16(MinxCPU.X.W.L);
			return 16;
		case 0x54: case 0x55: // Decrement SP
			MinxCPU.SP.W.L = DEC16(MinxCPU.SP.W.L);
			return 16;
		case 0x56: case 0x57: // CRASH
			MinxCPU_OnException(EXCEPTION_CRASH_INSTRUCTION, (MinxCPU.IR << 16) | 0xBFCF);
			return 16;

		case 0x58: case 0x59: // Increment X
			MinxCPU.X.W.L = INC16(MinxCPU.X.W.L);
			return 16;
		case 0x5A: case 0x5B: // Increment Y
			MinxCPU.X.W.L = INC16(MinxCPU.X.W.L);
			return 16;
		case 0x5C: case 0x5D: // Increment SP
			MinxCPU.SP.W.L = INC16(MinxCPU.SP.W.L);
			return 16;
		case 0x5E: case 0x5F: // CRASH
			MinxCPU_OnException(EXCEPTION_CRASH_INSTRUCTION, (MinxCPU.IR << 16) | 0xBFCF);
			return 16;

		case 0x60: case 0x61: case 0x62: case 0x63: // CRASH
		case 0x64: case 0x65: case 0x66: case 0x67:
		case 0x68: case 0x69: case 0x6A: case 0x6B:
		case 0x6C: case 0x6D: case 0x6E: case 0x6F:
			MinxCPU_OnException(EXCEPTION_CRASH_INSTRUCTION, (MinxCPU.IR << 16) | 0xBFCF);
			return 16;

		case 0x70: // BA = (0x4D << 8) | V
			MinxCPU.BA.W.L = 0x4D00 | MinxCPU.PC.B.I;
			return 24;
		case 0x71: // HL = (0x4D << 8) | V
			MinxCPU.HL.W.L = 0x4D00 | MinxCPU.PC.B.I;
			return 24;
		case 0x72: // X = (0x4D << 8) | V
			MinxCPU.X.W.L = 0x4D00 | MinxCPU.PC.B.I;
			return 24;
		case 0x73: // Y = (0x4D << 8) | V
			MinxCPU.Y.W.L = 0x4D00 | MinxCPU.PC.B.I;
			return 24;

		case 0x74: case 0x75: case 0x76: case 0x77: // NOTHING
			return 24;

		case 0x78: case 0x79: case 0x7A: case 0x7B: // CRASH
		case 0x7C: case 0x7D: case 0x7E: case 0x7F:
		case 0x80: case 0x81: case 0x82: case 0x83:
		case 0x84: case 0x85: case 0x86: case 0x87:
		case 0x88: case 0x89: case 0x8A: case 0x8B:
		case 0x8C: case 0x8D: case 0x8E: case 0x8F:
		case 0x90: case 0x91: case 0x92: case 0x93:
		case 0x94: case 0x95: case 0x96: case 0x97:
		case 0x98: case 0x99: case 0x9A: case 0x9B:
		case 0x9C: case 0x9D: case 0x9E: case 0x9F:
		case 0xA0: case 0xA1: case 0xA2: case 0xA3:
		case 0xA4: case 0xA5: case 0xA6: case 0xA7:
		case 0xA8: case 0xA9: case 0xAA: case 0xAB:
		case 0xAC: case 0xAD: case 0xAE: case 0xAF:
			MinxCPU_OnException(EXCEPTION_CRASH_INSTRUCTION, (MinxCPU.IR << 16) | 0xBFCF);
			return 24;

		case 0xB0: case 0xB1: case 0xB2: case 0xB3: // NOTHING
			return 12;

		case 0xB4: case 0xB5: case 0xB6: case 0xB7: // CRASH
		case 0xB8: case 0xB9: case 0xBA: case 0xBB:
		case 0xBC: case 0xBD: case 0xBE: case 0xBF:
			MinxCPU_OnException(EXCEPTION_CRASH_INSTRUCTION, (MinxCPU.IR << 16) | 0xBFCF);
			return 12;

		case 0xC0: // BA = (0x20 << 8) | V
			MinxCPU.BA.W.L = 0x2000 | MinxCPU.PC.B.I;
			return 20;
		case 0xC1: // HL = (0x20 << 8) | V
			MinxCPU.HL.W.L = 0x2000 | MinxCPU.PC.B.I;
			return 20;
		case 0xC2: // X = (0x20 << 8) | V
			MinxCPU.X.W.L = 0x2000 | MinxCPU.PC.B.I;
			return 20;
		case 0xC3: // Y = (0x20 << 8) | V
			MinxCPU.Y.W.L = 0x2000 | MinxCPU.PC.B.I;
			return 20;

		case 0xC4: case 0xC5: case 0xC6: case 0xC7: // NOTHING
			return 20;

		case 0xC8: case 0xC9: case 0xCA: case 0xCB: // CRASH
		case 0xCC: case 0xCD: case 0xCE: case 0xCF:
			MinxCPU_OnException(EXCEPTION_CRASH_INSTRUCTION, (MinxCPU.IR << 16) | 0xBFCF);
			return 20;

		case 0xD0: // BA = (0x20 << 8) | V
			MinxCPU.BA.W.L = 0x2000 | MinxCPU.PC.B.I;
			return 20;
		case 0xD1: // HL = (0x20 << 8) | V
			MinxCPU.HL.W.L = 0x2000 | MinxCPU.PC.B.I;
			return 20;
		case 0xD2: // X = (0x20 << 8) | V
			MinxCPU.X.W.L = 0x2000 | MinxCPU.PC.B.I;
			return 20;
		case 0xD3: // Y = (0x00 << 8) | V ? (EH!?)
			MinxCPU.Y.W.L = 0x0000 | MinxCPU.PC.B.I;
			return 20;

		case 0xD4: case 0xD5: case 0xD6: case 0xD7: // NOTHING
			return 20;

		case 0xD8: // BA = (0x20 << 8) | V
			MinxCPU.BA.W.L = 0x2000 | MinxCPU.PC.B.I;
			return 20;
		case 0xD9: // HL = (0x20 << 8) | V
			MinxCPU.HL.W.L = 0x2000 | MinxCPU.PC.B.I;
			return 20;
		case 0xDA: // X = (0x20 << 8) | V
			MinxCPU.X.W.L = 0x2000 | MinxCPU.PC.B.I;
			return 20;
		case 0xDB: // Y = (0x20 << 8) | V
			MinxCPU.Y.W.L = 0x2000 | MinxCPU.PC.B.I;
			return 20;

		case 0xDC: case 0xDD: case 0xDE: case 0xDF: // NOTHING
			return 20;
		
		case 0xE0: case 0xE1: case 0xE2: case 0xE3: // CRASH
		case 0xE4: case 0xE5: case 0xE6: case 0xE7:
		case 0xE8: case 0xE9: case 0xEA: case 0xEB:
		case 0xEC: case 0xED: case 0xEE: case 0xEF:
		case 0xF0: case 0xF1: case 0xF2: case 0xF3:
		case 0xF4: case 0xF5: case 0xF6: case 0xF7:
		case 0xF8: case 0xF9: case 0xFA: case 0xFB:
		case 0xFC: case 0xFD: case 0xFE: case 0xFF:
			MinxCPU_OnException(EXCEPTION_CRASH_INSTRUCTION, (MinxCPU.IR << 16) | 0xBFCF);
			return 24;

		default:
			MinxCPU_OnException(EXCEPTION_UNKNOWN_INSTRUCTION, (MinxCPU.IR << 16) + 0xBFCF);
			return 64;
	}
}
