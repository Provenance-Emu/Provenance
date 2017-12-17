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

// Note: Any write to MinxCPU.HL.B.I needs to be reflected into N.B.I

#include "MinxCPU.h"

int MinxCPU_ExecCE(void)
{
	uint8_t I8A;
	uint16_t I16;

	// Read IR
	MinxCPU.IR = Fetch8();

	// Process instruction
	switch(MinxCPU.IR) {

		case 0x00: // ADD A, [X+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.X.W.L + S8_TO_16(I8A);
			MinxCPU.BA.B.L = ADD8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16));
			return 16;
		case 0x01: // ADD A, [Y+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.Y.W.L + S8_TO_16(I8A);
			MinxCPU.BA.B.L = ADD8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16));
			return 16;
		case 0x02: // ADD A, [X+L]
			I16 = MinxCPU.X.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU.BA.B.L = ADD8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16));
			return 16;
		case 0x03: // ADD A, [Y+L]
			I16 = MinxCPU.Y.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU.BA.B.L = ADD8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16));
			return 16;

		case 0x04: // ADD [HL], A
			MinxCPU_OnWrite(1, MinxCPU.HL.D, ADD8(MinxCPU_OnRead(1, MinxCPU.HL.D), MinxCPU.BA.B.L));
			return 16;
		case 0x05: // ADD [HL], #nn
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.HL.D, ADD8(MinxCPU_OnRead(1, MinxCPU.HL.D), I8A));
			return 20;
		case 0x06: // ADD [HL], [X]
			MinxCPU_OnWrite(1, MinxCPU.HL.D, ADD8(MinxCPU_OnRead(1, MinxCPU.HL.D), MinxCPU_OnRead(1, MinxCPU.X.D)));
			return 20;
		case 0x07: // ADD [HL], [Y]
			MinxCPU_OnWrite(1, MinxCPU.HL.D, ADD8(MinxCPU_OnRead(1, MinxCPU.HL.D), MinxCPU_OnRead(1, MinxCPU.Y.D)));
			return 20;

		case 0x08: // ADC A, [X+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.X.W.L + S8_TO_16(I8A);
			MinxCPU.BA.B.L = ADC8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16));
			return 16;
		case 0x09: // ADC A, [Y+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.Y.W.L + S8_TO_16(I8A);
			MinxCPU.BA.B.L = ADC8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16));
			return 16;
		case 0x0A: // ADC A, [X+L]
			I16 = MinxCPU.X.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU.BA.B.L = ADC8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16));
			return 16;
		case 0x0B: // ADC A, [Y+L]
			I16 = MinxCPU.Y.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU.BA.B.L = ADC8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16));
			return 16;

		case 0x0C: // ADC [HL], A
			MinxCPU_OnWrite(1, MinxCPU.HL.D, ADC8(MinxCPU_OnRead(1, MinxCPU.HL.D), MinxCPU.BA.B.L));
			return 16;
		case 0x0D: // ADC [HL], #nn
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.HL.D, ADC8(MinxCPU_OnRead(1, MinxCPU.HL.D), I8A));
			return 20;
		case 0x0E: // ADC [HL], [X]
			MinxCPU_OnWrite(1, MinxCPU.HL.D, ADC8(MinxCPU_OnRead(1, MinxCPU.HL.D), MinxCPU_OnRead(1, MinxCPU.X.D)));
			return 20;
		case 0x0F: // ADC [HL], [Y]
			MinxCPU_OnWrite(1, MinxCPU.HL.D, ADC8(MinxCPU_OnRead(1, MinxCPU.HL.D), MinxCPU_OnRead(1, MinxCPU.Y.D)));
			return 20;

		case 0x10: // SUB A, [X+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.X.W.L + S8_TO_16(I8A);
			MinxCPU.BA.B.L = SUB8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16));
			return 16;
		case 0x11: // SUB A, [Y+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.Y.W.L + S8_TO_16(I8A);
			MinxCPU.BA.B.L = SUB8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16));
			return 16;
		case 0x12: // SUB A, [X+L]
			I16 = MinxCPU.X.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU.BA.B.L = SUB8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16));
			return 16;
		case 0x13: // SUB A, [Y+L]
			I16 = MinxCPU.Y.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU.BA.B.L = SUB8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16));
			return 16;

		case 0x14: // SUB [HL], A
			MinxCPU_OnWrite(1, MinxCPU.HL.D, SUB8(MinxCPU_OnRead(1, MinxCPU.HL.D), MinxCPU.BA.B.L));
			return 16;
		case 0x15: // SUB [HL], #nn
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.HL.D, SUB8(MinxCPU_OnRead(1, MinxCPU.HL.D), I8A));
			return 20;
		case 0x16: // SUB [HL], [X]
			MinxCPU_OnWrite(1, MinxCPU.HL.D, SUB8(MinxCPU_OnRead(1, MinxCPU.HL.D), MinxCPU_OnRead(1, MinxCPU.X.D)));
			return 20;
		case 0x17: // SUB [HL], [Y]
			MinxCPU_OnWrite(1, MinxCPU.HL.D, SUB8(MinxCPU_OnRead(1, MinxCPU.HL.D), MinxCPU_OnRead(1, MinxCPU.Y.D)));
			return 20;

		case 0x18: // SBC A, [X+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.X.W.L + S8_TO_16(I8A);
			MinxCPU.BA.B.L = SBC8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16));
			return 16;
		case 0x19: // SBC A, [Y+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.Y.W.L + S8_TO_16(I8A);
			MinxCPU.BA.B.L = SBC8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16));
			return 16;
		case 0x1A: // SBC A, [X+L]
			I16 = MinxCPU.X.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU.BA.B.L = SBC8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16));
			return 16;
		case 0x1B: // SBC A, [Y+L]
			I16 = MinxCPU.Y.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU.BA.B.L = SBC8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16));
			return 16;

		case 0x1C: // SBC [HL], A
			MinxCPU_OnWrite(1, MinxCPU.HL.D, SBC8(MinxCPU_OnRead(1, MinxCPU.HL.D), MinxCPU.BA.B.L));
			return 16;
		case 0x1D: // SBC [HL], #nn
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.HL.D, SBC8(MinxCPU_OnRead(1, MinxCPU.HL.D), I8A));
			return 20;
		case 0x1E: // SBC [HL], [X]
			MinxCPU_OnWrite(1, MinxCPU.HL.D, SBC8(MinxCPU_OnRead(1, MinxCPU.HL.D), MinxCPU_OnRead(1, MinxCPU.X.D)));
			return 20;
		case 0x1F: // SBC [HL], [Y]
			MinxCPU_OnWrite(1, MinxCPU.HL.D, SBC8(MinxCPU_OnRead(1, MinxCPU.HL.D), MinxCPU_OnRead(1, MinxCPU.Y.D)));
			return 20;

		case 0x20: // AND A, [X+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.X.W.L + S8_TO_16(I8A);
			MinxCPU.BA.B.L = AND8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16));
			return 16;
		case 0x21: // AND A, [Y+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.Y.W.L + S8_TO_16(I8A);
			MinxCPU.BA.B.L = AND8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16));
			return 16;
		case 0x22: // AND A, [X+L]
			I16 = MinxCPU.X.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU.BA.B.L = AND8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16));
			return 16;
		case 0x23: // AND A, [Y+L]
			I16 = MinxCPU.Y.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU.BA.B.L = AND8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16));
			return 16;

		case 0x24: // AND [HL], A
			MinxCPU_OnWrite(1, MinxCPU.HL.D, AND8(MinxCPU_OnRead(1, MinxCPU.HL.D), MinxCPU.BA.B.L));
			return 16;
		case 0x25: // AND [HL], #nn
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.HL.D, AND8(MinxCPU_OnRead(1, MinxCPU.HL.D), I8A));
			return 20;
		case 0x26: // AND [HL], [X]
			MinxCPU_OnWrite(1, MinxCPU.HL.D, AND8(MinxCPU_OnRead(1, MinxCPU.HL.D), MinxCPU_OnRead(1, MinxCPU.X.D)));
			return 20;
		case 0x27: // AND [HL], [Y]
			MinxCPU_OnWrite(1, MinxCPU.HL.D, AND8(MinxCPU_OnRead(1, MinxCPU.HL.D), MinxCPU_OnRead(1, MinxCPU.Y.D)));
			return 20;

		case 0x28: // OR A, [X+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.X.W.L + S8_TO_16(I8A);
			MinxCPU.BA.B.L = OR8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16));
			return 16;
		case 0x29: // OR A, [Y+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.Y.W.L + S8_TO_16(I8A);
			MinxCPU.BA.B.L = OR8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16));
			return 16;
		case 0x2A: // OR A, [X+L]
			I16 = MinxCPU.X.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU.BA.B.L = OR8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16));
			return 16;
		case 0x2B: // OR A, [Y+L]
			I16 = MinxCPU.Y.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU.BA.B.L = OR8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16));
			return 16;

		case 0x2C: // OR [HL], A
			MinxCPU_OnWrite(1, MinxCPU.HL.D, OR8(MinxCPU_OnRead(1, MinxCPU.HL.D), MinxCPU.BA.B.L));
			return 16;
		case 0x2D: // OR [HL], #nn
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.HL.D, OR8(MinxCPU_OnRead(1, MinxCPU.HL.D), I8A));
			return 20;
		case 0x2E: // OR [HL], [X]
			MinxCPU_OnWrite(1, MinxCPU.HL.D, OR8(MinxCPU_OnRead(1, MinxCPU.HL.D), MinxCPU_OnRead(1, MinxCPU.X.D)));
			return 20;
		case 0x2F: // OR [HL], [Y]
			MinxCPU_OnWrite(1, MinxCPU.HL.D, OR8(MinxCPU_OnRead(1, MinxCPU.HL.D), MinxCPU_OnRead(1, MinxCPU.Y.D)));
			return 20;

		case 0x30: // CMP A, [X+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.X.W.L + S8_TO_16(I8A);
			SUB8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16));
			return 16;
		case 0x31: // CMP A, [Y+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.Y.W.L + S8_TO_16(I8A);
			SUB8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16));
			return 16;
		case 0x32: // CMP A, [X+L]
			I16 = MinxCPU.X.W.L + S8_TO_16(MinxCPU.HL.B.L);
			SUB8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16));
			return 16;
		case 0x33: // CMP A, [Y+L]
			I16 = MinxCPU.Y.W.L + S8_TO_16(MinxCPU.HL.B.L);
			SUB8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16));
			return 16;

		case 0x34: // CMP [HL], A
			SUB8(MinxCPU_OnRead(1, MinxCPU.HL.D), MinxCPU.BA.B.L);
			return 16;
		case 0x35: // CMP [HL], #nn
			I8A = Fetch8();
			SUB8(MinxCPU_OnRead(1, MinxCPU.HL.D), I8A);
			return 20;
		case 0x36: // CMP [HL], [X]
			SUB8(MinxCPU_OnRead(1, MinxCPU.HL.D), MinxCPU_OnRead(1, MinxCPU.X.D));
			return 20;
		case 0x37: // CMP [HL], [Y]
			SUB8(MinxCPU_OnRead(1, MinxCPU.HL.D), MinxCPU_OnRead(1, MinxCPU.Y.D));
			return 20;

		case 0x38: // XOR A, [X+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.X.W.L + S8_TO_16(I8A);
			MinxCPU.BA.B.L = XOR8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16));
			return 16;
		case 0x39: // XOR A, [Y+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.Y.W.L + S8_TO_16(I8A);
			MinxCPU.BA.B.L = XOR8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16));
			return 16;
		case 0x3A: // XOR A, [X+L]
			I16 = MinxCPU.X.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU.BA.B.L = XOR8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16));
			return 16;
		case 0x3B: // XOR A, [Y+L]
			I16 = MinxCPU.Y.W.L+ S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU.BA.B.L = XOR8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16));
			return 16;

		case 0x3C: // XOR [HL], A
			MinxCPU_OnWrite(1, MinxCPU.HL.D, XOR8(MinxCPU_OnRead(1, MinxCPU.HL.D), MinxCPU.BA.B.L));
			return 16;
		case 0x3D: // XOR [HL], #nn
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.HL.D, XOR8(MinxCPU_OnRead(1, MinxCPU.HL.D), I8A));
			return 20;
		case 0x3E: // XOR [HL], [X]
			MinxCPU_OnWrite(1, MinxCPU.HL.D, XOR8(MinxCPU_OnRead(1, MinxCPU.HL.D), MinxCPU_OnRead(1, MinxCPU.X.D)));
			return 20;
		case 0x3F: // XOR [HL], [Y]
			MinxCPU_OnWrite(1, MinxCPU.HL.D, XOR8(MinxCPU_OnRead(1, MinxCPU.HL.D), MinxCPU_OnRead(1, MinxCPU.Y.D)));
			return 20;

		case 0x40: // MOV A, [X+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.X.W.L + S8_TO_16(I8A);
			MinxCPU.BA.B.L = MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16);
			return 16;
		case 0x41: // MOV A, [Y+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.Y.W.L + S8_TO_16(I8A);
			MinxCPU.BA.B.L = MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16);
			return 16;
		case 0x42: // MOV A, [X+L]
			I16 = MinxCPU.X.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU.BA.B.L = MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16);
			return 16;
		case 0x43: // MOV A, [Y+L]
			I16 = MinxCPU.Y.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU.BA.B.L = MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16);
			return 16;

		case 0x44: // MOV [X+#ss], A
			I8A = Fetch8();
			I16 = MinxCPU.X.W.L + S8_TO_16(I8A);
			MinxCPU_OnWrite(1, (MinxCPU.X.B.I << 16) | I16, MinxCPU.BA.B.L);
			return 16;
		case 0x45: // MOV [Y+#ss], A
			I8A = Fetch8();
			I16 = MinxCPU.Y.W.L + S8_TO_16(I8A);
			MinxCPU_OnWrite(1, (MinxCPU.Y.B.I << 16) | I16, MinxCPU.BA.B.L);
			return 16;
		case 0x46: // MOV [X+L], A
			I16 = MinxCPU.X.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU_OnWrite(1, (MinxCPU.X.B.I << 16) | I16, MinxCPU.BA.B.L);
			return 16;
		case 0x47: // MOV [Y+L], A
			I16 = MinxCPU.Y.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU_OnWrite(1, (MinxCPU.Y.B.I << 16) | I16, MinxCPU.BA.B.L);
			return 16;

		case 0x48: // MOV B, [X+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.X.W.L + S8_TO_16(I8A);
			MinxCPU.BA.B.H = MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16);
			return 16;
		case 0x49: // MOV B, [Y+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.Y.W.L + S8_TO_16(I8A);
			MinxCPU.BA.B.H = MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16);
			return 16;
		case 0x4A: // MOV B, [X+L]
			I16 = MinxCPU.X.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU.BA.B.H = MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16);
			return 16;
		case 0x4B: // MOV B, [Y+L]
			I16 = MinxCPU.Y.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU.BA.B.H = MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16);
			return 16;

		case 0x4C: // MOV [X+#ss], B
			I8A = Fetch8();
			I16 = MinxCPU.X.W.L + S8_TO_16(I8A);
			MinxCPU_OnWrite(1, (MinxCPU.X.B.I << 16) | I16, MinxCPU.BA.B.H);
			return 16;
		case 0x4D: // MOV [Y+#ss], B
			I8A = Fetch8();
			I16 = MinxCPU.Y.W.L + S8_TO_16(I8A);
			MinxCPU_OnWrite(1, (MinxCPU.Y.B.I << 16) | I16, MinxCPU.BA.B.H);
			return 16;
		case 0x4E: // MOV [X+L], B
			I16 = MinxCPU.X.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU_OnWrite(1, (MinxCPU.X.B.I << 16) | I16, MinxCPU.BA.B.H);
			return 16;
		case 0x4F: // MOV [Y+L], B
			I16 = MinxCPU.Y.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU_OnWrite(1, (MinxCPU.Y.B.I << 16) | I16, MinxCPU.BA.B.H);
			return 16;

		case 0x50: // MOV L, [X+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.X.W.L + S8_TO_16(I8A);
			MinxCPU.HL.B.L = MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16);
			return 16;
		case 0x51: // MOV L, [Y+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.Y.W.L + S8_TO_16(I8A);
			MinxCPU.HL.B.L = MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16);
			return 16;
		case 0x52: // MOV L, [X+L]
			I16 = MinxCPU.X.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU.HL.B.L = MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16);
			return 16;
		case 0x53: // MOV L, [Y+L]
			I16 = MinxCPU.Y.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU.HL.B.L = MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16);
			return 16;

		case 0x54: // MOV [X+#ss], L
			I8A = Fetch8();
			I16 = MinxCPU.X.W.L + S8_TO_16(I8A);
			MinxCPU_OnWrite(1, (MinxCPU.X.B.I << 16) | I16, MinxCPU.HL.B.L);
			return 16;
		case 0x55: // MOV [Y+#ss], L
			I8A = Fetch8();
			I16 = MinxCPU.Y.W.L + S8_TO_16(I8A);
			MinxCPU_OnWrite(1, (MinxCPU.Y.B.I << 16) | I16, MinxCPU.HL.B.L);
			return 16;
		case 0x56: // MOV [X+L], L
			I16 = MinxCPU.X.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU_OnWrite(1, (MinxCPU.X.B.I << 16) | I16, MinxCPU.HL.B.L);
			return 16;
		case 0x57: // MOV [Y+L], L
			I16 = MinxCPU.Y.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU_OnWrite(1, (MinxCPU.Y.B.I << 16) | I16, MinxCPU.HL.B.L);
			return 16;

		case 0x58: // MOV H, [X+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.X.W.L + S8_TO_16(I8A);
			MinxCPU.HL.B.H = MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16);
			return 16;
		case 0x59: // MOV H, [Y+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.Y.W.L + S8_TO_16(I8A);
			MinxCPU.HL.B.H = MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16);
			return 16;
		case 0x5A: // MOV H, [X+L]
			I16 = MinxCPU.X.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU.HL.B.H = MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16);
			return 16;
		case 0x5B: // MOV H, [Y+L]
			I16 = MinxCPU.Y.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU.HL.B.H = MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16);
			return 16;

		case 0x5C: // MOV [X+#ss], H
			I8A = Fetch8();
			I16 = MinxCPU.X.W.L + S8_TO_16(I8A);
			MinxCPU_OnWrite(1, (MinxCPU.X.B.I << 16) | I16, MinxCPU.HL.B.H);
			return 16;
		case 0x5D: // MOV [Y+#ss], H
			I8A = Fetch8();
			I16 = MinxCPU.Y.W.L + S8_TO_16(I8A);
			MinxCPU_OnWrite(1, (MinxCPU.Y.B.I << 16) | I16, MinxCPU.HL.B.H);
			return 16;
		case 0x5E: // MOV [X+L], H
			I16 = MinxCPU.X.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU_OnWrite(1, (MinxCPU.X.B.I << 16) | I16, MinxCPU.HL.B.H);
			return 16;
		case 0x5F: // MOV [Y+L], H
			I16 = MinxCPU.Y.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU_OnWrite(1, (MinxCPU.Y.B.I << 16) | I16, MinxCPU.HL.B.H);
			return 16;

		case 0x60: // MOV [HL], [X+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.X.W.L + S8_TO_16(I8A);
			MinxCPU_OnWrite(1, MinxCPU.HL.D, MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16));
			return 20;
		case 0x61: // MOV [HL], [Y+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.Y.W.L + S8_TO_16(I8A);
			MinxCPU_OnWrite(1, MinxCPU.HL.D, MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16));
			return 20;
		case 0x62: // MOV [HL], [X+L]
			I16 = MinxCPU.X.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU_OnWrite(1, MinxCPU.HL.D, MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16));
			return 20;
		case 0x63: // MOV [HL], [Y+L]
			I16 = MinxCPU.Y.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU_OnWrite(1, MinxCPU.HL.D, MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16));
			return 20;

		case 0x64: // *ADC BA, #nnnn
			I16 = Fetch16();
			MinxCPU.BA.W.L = ADC16(MinxCPU.BA.W.L, I16);
			return 16;
		case 0x65: // *ADC HL, #nnnn
			I16 = Fetch16();
			MinxCPU.HL.W.L = ADC16(MinxCPU.HL.W.L, I16);
			return 16;

		case 0x66: // ??? BA, #nn00+L
			I8A = Fetch8();
			MinxCPU.BA.W.L = ADC16(MinxCPU.BA.W.L, (I8A << 8) | MinxCPU.HL.B.L);
			return 24;
		case 0x67: // ??? HL, #nn00+L
			I8A = Fetch8();
			MinxCPU.HL.W.L = ADC16(MinxCPU.HL.W.L, (I8A << 8) | MinxCPU.HL.B.L);
			return 24;

		case 0x68: // MOV [X], [X+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.X.W.L + S8_TO_16(I8A);
			MinxCPU_OnWrite(1, MinxCPU.X.D, MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16));
			return 20;
		case 0x69: // MOV [X], [Y+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.Y.W.L + S8_TO_16(I8A);
			MinxCPU_OnWrite(1, MinxCPU.X.D, MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16));
			return 20;
		case 0x6A: // MOV [X], [X+L]
			I16 = MinxCPU.X.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU_OnWrite(1, MinxCPU.X.D, MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16));
			return 20;
		case 0x6B: // MOV [X], [Y+L]
			I16 = MinxCPU.Y.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU_OnWrite(1, MinxCPU.X.D, MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16));
			return 20;

		case 0x6C: // *ADD SP, #nnnn
			I16 = Fetch8();
			MinxCPU.SP.W.L = ADD16(MinxCPU.SP.W.L, I16);

		case 0x6D: // ??? HL, #nn
			I8A = Fetch8();
			MinxCPU.HL.W.L = ADD16(MinxCPU.X.W.L, ((I8A << 4) * 3) + ((I8A & 0x08) >> 3));
			MinxCPU.F &= ~MINX_FLAG_CARRY; // It seems that carry gets clear?
			return 40;
		case 0x6E: // ??? SP, #nn00+L
			I8A = Fetch8();
			MinxCPU.SP.W.L = ADD16(MinxCPU.SP.W.L, (I8A << 8) | MinxCPU.HL.B.L);
			return 16;
		case 0x6F: // ??? HL, L
			MinxCPU.HL.W.L = ADD16(MinxCPU.X.W.L, ((MinxCPU.HL.B.L << 4) * 3) + ((MinxCPU.HL.B.L & 0x08) >> 3));
			MinxCPU.F &= ~MINX_FLAG_CARRY; // It seems that carry gets clear?
			return 40;

		case 0x70: // NOTHING
			MinxCPU.PC.W.L++;
			return 64;
		case 0x71: // NOTHING
			MinxCPU.PC.W.L++;
			return 64;
		case 0x72: // NOTHING
			return 64;
		case 0x73: // NOTHING
			return 64;

		case 0x74: // *MOV A, [X+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.X.W.L + S8_TO_16(I8A);
			MinxCPU.BA.B.L = MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16);
			return 64;
		case 0x75: // *MOV L, [Y+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.Y.W.L + S8_TO_16(I8A);
			MinxCPU.HL.B.L = MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16);
			return 64;
		case 0x76: // *MOV A, [X+L]
			I16 = MinxCPU.X.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU.BA.B.L = MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16);
			return 64;
		case 0x77: // *MOV L, [Y+L]
			I16 = MinxCPU.Y.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU.HL.B.L = MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16);
			return 64;

		case 0x78: // MOV [Y], [X+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.X.W.L + S8_TO_16(I8A);
			MinxCPU_OnWrite(1, MinxCPU.Y.D, MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16));
			return 20;
		case 0x79: // MOV [Y], [Y+#ss]
			I8A = Fetch8();
			I16 = MinxCPU.Y.W.L + S8_TO_16(I8A);
			MinxCPU_OnWrite(1, MinxCPU.Y.D, MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16));
			return 20;
		case 0x7A: // MOV [Y], [X+L]
			I16 = MinxCPU.X.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU_OnWrite(1, MinxCPU.Y.D, MinxCPU_OnRead(1, (MinxCPU.X.B.I << 16) | I16));
			return 20;
		case 0x7B: // MOV [Y], [Y+L]
			I16 = MinxCPU.Y.W.L + S8_TO_16(MinxCPU.HL.B.L);
			MinxCPU_OnWrite(1, MinxCPU.Y.D, MinxCPU_OnRead(1, (MinxCPU.Y.B.I << 16) | I16));
			return 20;

		case 0x7C: // NOTHING #nn
			MinxCPU.PC.W.L++;
			return 20;
		case 0x7D: // NOTHING #nn
			MinxCPU.PC.W.L++;
			return 16;
		case 0x7E: // NOTHING
			return 20;
		case 0x7F: // NOTHING
			return 16;

		case 0x80: // SAL A
			MinxCPU.BA.B.L = SAL(MinxCPU.BA.B.L);
			return 12;
		case 0x81: // SAL B
			MinxCPU.BA.B.H = SAL(MinxCPU.BA.B.H);
			return 12;
		case 0x82: // SAL [N+#nn]
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.N.D | I8A, SAL(MinxCPU_OnRead(1, MinxCPU.N.D | I8A)));
			return 20;
		case 0x83: // SAL [HL]
			MinxCPU_OnWrite(1, MinxCPU.HL.D, SAL(MinxCPU_OnRead(1, MinxCPU.HL.D)));
			return 16;

		case 0x84: // SHL A
			MinxCPU.BA.B.L = SHL(MinxCPU.BA.B.L);
			return 12;
		case 0x85: // SHL B
			MinxCPU.BA.B.H = SHL(MinxCPU.BA.B.H);
			return 12;
		case 0x86: // SHL [N+#nn]
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.N.D | I8A, SHL(MinxCPU_OnRead(1, MinxCPU.N.D | I8A)));
			return 20;
		case 0x87: // SHL [HL]
			MinxCPU_OnWrite(1, MinxCPU.HL.D, SHL(MinxCPU_OnRead(1, MinxCPU.HL.D)));
			return 16;

		case 0x88: // SAR A
			MinxCPU.BA.B.L = SAR(MinxCPU.BA.B.L);
			return 12;
		case 0x89: // SAR B
			MinxCPU.BA.B.H = SAR(MinxCPU.BA.B.H);
			return 12;
		case 0x8A: // SAR [N+#nn]
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.N.D | I8A, SAR(MinxCPU_OnRead(1, MinxCPU.N.D | I8A)));
			return 20;
		case 0x8B: // SAR [HL]
			MinxCPU_OnWrite(1, MinxCPU.HL.D, SAR(MinxCPU_OnRead(1, MinxCPU.HL.D)));
			return 16;

		case 0x8C: // SHR A
			MinxCPU.BA.B.L = SHR(MinxCPU.BA.B.L);
			return 12;
		case 0x8D: // SHR B
			MinxCPU.BA.B.H = SHR(MinxCPU.BA.B.H);
			return 12;
		case 0x8E: // SHR [N+#nn]
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.N.D | I8A, SHR(MinxCPU_OnRead(1, MinxCPU.N.D | I8A)));
			return 20;
		case 0x8F: // SHR [HL]
			MinxCPU_OnWrite(1, MinxCPU.HL.D, SHR(MinxCPU_OnRead(1, MinxCPU.HL.D)));
			return 16;

		case 0x90: // ROLC A
			MinxCPU.BA.B.L = ROLC(MinxCPU.BA.B.L);
			return 12;
		case 0x91: // ROLC B
			MinxCPU.BA.B.H = ROLC(MinxCPU.BA.B.H);
			return 12;
		case 0x92: // ROLC [N+#nn]
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.N.D | I8A, ROLC(MinxCPU_OnRead(1, MinxCPU.N.D | I8A)));
			return 20;
		case 0x93: // ROLC [HL]
			MinxCPU_OnWrite(1, MinxCPU.HL.D, ROLC(MinxCPU_OnRead(1, MinxCPU.HL.D)));
			return 16;

		case 0x94: // ROL A
			MinxCPU.BA.B.L = ROL(MinxCPU.BA.B.L);
			return 12;
		case 0x95: // ROL B
			MinxCPU.BA.B.H = ROL(MinxCPU.BA.B.H);
			return 12;
		case 0x96: // ROL [N+#nn]
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.N.D | I8A, ROL(MinxCPU_OnRead(1, MinxCPU.N.D | I8A)));
			return 20;
		case 0x97: // ROL [HL]
			MinxCPU_OnWrite(1, MinxCPU.HL.D, ROL(MinxCPU_OnRead(1, MinxCPU.HL.D)));
			return 16;

		case 0x98: // RORC A
			MinxCPU.BA.B.L = RORC(MinxCPU.BA.B.L);
			return 12;
		case 0x99: // RORC B
			MinxCPU.BA.B.H = RORC(MinxCPU.BA.B.H);
			return 12;
		case 0x9A: // RORC [N+#nn]
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.N.D | I8A, RORC(MinxCPU_OnRead(1, MinxCPU.N.D | I8A)));
			return 20;
		case 0x9B: // RORC [HL]
			MinxCPU_OnWrite(1, MinxCPU.HL.D, RORC(MinxCPU_OnRead(1, MinxCPU.HL.D)));
			return 16;

		case 0x9C: // ROR A
			MinxCPU.BA.B.L = ROR(MinxCPU.BA.B.L);
			return 12;
		case 0x9D: // ROR B
			MinxCPU.BA.B.H = ROR(MinxCPU.BA.B.H);
			return 12;
		case 0x9E: // ROR [N+#nn]
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.N.D | I8A, ROR(MinxCPU_OnRead(1, MinxCPU.N.D | I8A)));
			return 20;
		case 0x9F: // ROR [HL]
			MinxCPU_OnWrite(1, MinxCPU.HL.D, ROR(MinxCPU_OnRead(1, MinxCPU.HL.D)));
			return 16;

		case 0xA0: // NOT A
			MinxCPU.BA.B.L = NOT(MinxCPU.BA.B.L);
			return 12;
		case 0xA1: // NOT B
			MinxCPU.BA.B.H = NOT(MinxCPU.BA.B.H);
			return 12;
		case 0xA2: // NOT [N+#nn]
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.N.D | I8A, NOT(MinxCPU_OnRead(1, MinxCPU.N.D | I8A)));
			return 20;
		case 0xA3: // NOT [HL]
			MinxCPU_OnWrite(1, MinxCPU.HL.D, NOT(MinxCPU_OnRead(1, MinxCPU.HL.D)));
			return 16;

		case 0xA4: // NEG A
			MinxCPU.BA.B.L = NEG(MinxCPU.BA.B.L);
			return 12;
		case 0xA5: // NEG B
			MinxCPU.BA.B.H = NEG(MinxCPU.BA.B.H);
			return 12;
		case 0xA6: // NEG [N+#nn]
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.N.D | I8A, NEG(MinxCPU_OnRead(1, MinxCPU.N.D | I8A)));
			return 20;
		case 0xA7: // NEG [HL]
			MinxCPU_OnWrite(1, MinxCPU.HL.D, NEG(MinxCPU_OnRead(1, MinxCPU.HL.D)));
			return 16;

		case 0xA8: // EX BA, A
			MinxCPU.BA.W.L = S8_TO_16(MinxCPU.BA.B.L);
			return 12;

		case 0xA9: // NOTHING
			return 8;
		case 0xAA: // NOTHING
			return 12;

		case 0xAB: // CRASH
			MinxCPU_OnException(EXCEPTION_CRASH_INSTRUCTION, 0xABCE);
			return 64;
		case 0xAC: // CRASH
			MinxCPU_OnException(EXCEPTION_CRASH_INSTRUCTION, 0xACCE);
			return 64;
		case 0xAD: // CRASH
			MinxCPU_OnException(EXCEPTION_CRASH_INSTRUCTION, 0xACCE);
			return 64;

		case 0xAE: // HALT
			HALT();
			return 8;
		case 0xAF: // STOP
			STOP();
			return 8;

		case 0xB0: // AND B, #nn
			I8A = Fetch8();
			MinxCPU.BA.B.H = AND8(MinxCPU.BA.B.H, I8A);
			return 12;
		case 0xB1: // AND L, #nn
			I8A = Fetch8();
			MinxCPU.HL.B.L = AND8(MinxCPU.HL.B.L, I8A);
			return 12;
		case 0xB2: // AND H, #nn
			I8A = Fetch8();
			MinxCPU.HL.B.H = AND8(MinxCPU.HL.B.H, I8A);
			return 12;
		case 0xB3: // MOV H, V
			MinxCPU.HL.B.H = MinxCPU.PC.B.I;
			return 12;

		case 0xB4: // OR B, #nn
			I8A = Fetch8();
			MinxCPU.BA.B.H = OR8(MinxCPU.BA.B.H, I8A);
			return 12;
		case 0xB5: // OR L, #nn
			I8A = Fetch8();
			MinxCPU.HL.B.L = OR8(MinxCPU.HL.B.L, I8A);
			return 12;
		case 0xB6: // OR H, #nn
			I8A = Fetch8();
			MinxCPU.HL.B.H = OR8(MinxCPU.HL.B.H, I8A);
			return 12;
		case 0xB7: // ??? X
			MinxCPU.X.B.H = MinxCPU.PC.B.I;
			return 12;

		case 0xB8: // XOR B, #nn
			I8A = Fetch8();
			MinxCPU.BA.B.H = XOR8(MinxCPU.BA.B.H, I8A);
			return 12;
		case 0xB9: // XOR L, #nn
			I8A = Fetch8();
			MinxCPU.HL.B.L = XOR8(MinxCPU.HL.B.L, I8A);
			return 12;
		case 0xBA: // XOR H, #nn
			I8A = Fetch8();
			MinxCPU.HL.B.H = XOR8(MinxCPU.HL.B.H, I8A);
			return 12;
		case 0xBB: // ??? Y
			MinxCPU.Y.B.H = MinxCPU.PC.B.I;
			return 12;

		case 0xBC: // CMP B, #nn
			I8A = Fetch8();
			SUB8(MinxCPU.BA.B.H, I8A);
			return 12;
		case 0xBD: // CMP L, #nn
			I8A = Fetch8();
			SUB8(MinxCPU.HL.B.L, I8A);
			return 12;
		case 0xBE: // CMP H, #nn
			I8A = Fetch8();
			SUB8(MinxCPU.HL.B.H, I8A);
			return 12;
		case 0xBF: // CMP N, #nn
			I8A = Fetch8();
			SUB8(MinxCPU.N.B.H, I8A);
			return 12;

		case 0xC0: // MOV A, N
			MinxCPU.BA.B.L = MinxCPU.N.B.H;
			return 8;
		case 0xC1: // MOV A, F
			MinxCPU.BA.B.L = MinxCPU.F;
			return 8;
		case 0xC2: // MOV N, A
			MinxCPU.N.B.H = MinxCPU.BA.B.L;
			return 8;
		case 0xC3: // MOV F, A
			MinxCPU.F = MinxCPU.BA.B.L;
			MinxCPU_OnIRQHandle(MinxCPU.F, MinxCPU.Shift_U);
			return 8;

		case 0xC4: // MOV U, #nn
			I8A = Fetch8();
			Set_U(I8A);
			return 16;
		case 0xC5: // MOV I, #nn
			I8A = Fetch8();
			MinxCPU.HL.B.I = I8A;
			MinxCPU.N.B.I = MinxCPU.HL.B.I;
			return 12;
		case 0xC6: // MOV XI, #nn
			I8A = Fetch8();
			MinxCPU.X.B.I = I8A;
			return 12;
		case 0xC7: // MOV YI, #nn
			I8A = Fetch8();
			MinxCPU.Y.B.I = I8A;
			return 12;

		case 0xC8: // MOV A, V
			MinxCPU.BA.B.L = MinxCPU.PC.B.I;
			return 8;
		case 0xC9: // MOV A, I
			MinxCPU.BA.B.L = MinxCPU.HL.B.I;
			return 8;
		case 0xCA: // MOV A, XI
			MinxCPU.BA.B.L = MinxCPU.X.B.I;
			return 8;
		case 0xCB: // MOV A, YI
			MinxCPU.BA.B.L = MinxCPU.Y.B.I;
			return 8;

		case 0xCC: // MOV U, A
			Set_U(MinxCPU.BA.B.L);
			return 8;
		case 0xCD: // MOV I, A
			MinxCPU.HL.B.I = MinxCPU.BA.B.L;
			MinxCPU.N.B.I = MinxCPU.HL.B.I;
			return 8;
		case 0xCE: // MOV XI, A
			MinxCPU.X.B.I = MinxCPU.BA.B.L;
			return 8;
		case 0xCF: // MOV YI, A
			MinxCPU.Y.B.I = MinxCPU.BA.B.L;
			return 8;

		case 0xD0: // MOV A, [#nnnn]
			I16 = Fetch16();
			MinxCPU.BA.B.L = MinxCPU_OnRead(1, I16);
			return 20;
		case 0xD1: // MOV B, [#nnnn]
			I16 = Fetch16();
			MinxCPU.BA.B.H = MinxCPU_OnRead(1, I16);
			return 20;
		case 0xD2: // MOV L, [#nnnn]
			I16 = Fetch16();
			MinxCPU.HL.B.L = MinxCPU_OnRead(1, I16);
			return 20;
		case 0xD3: // MOV H, [#nnnn]
			I16 = Fetch16();
			MinxCPU.HL.B.H = MinxCPU_OnRead(1, I16);
			return 20;

		case 0xD4: // MOV [#nnnn], A
			I16 = Fetch16();
			MinxCPU_OnWrite(1, I16, MinxCPU.BA.B.L);
			return 20;
		case 0xD5: // MOV [#nnnn], B
			I16 = Fetch16();
			MinxCPU_OnWrite(1, I16, MinxCPU.BA.B.H);
			return 20;
		case 0xD6: // MOV [#nnnn], L
			I16 = Fetch16();
			MinxCPU_OnWrite(1, I16, MinxCPU.HL.B.L);
			return 20;
		case 0xD7: // MOV [#nnnn], H
			I16 = Fetch16();
			MinxCPU_OnWrite(1, I16, MinxCPU.HL.B.H);
			return 20;

		case 0xD8: // MUL L, A
			MUL();
			return 48;

		case 0xD9: // DIV HL, A
			DIV();
			return 52;

		case 0xDA: // ??? #nn
		case 0xDB: // ??? #nn
			return MinxCPU_ExecSPCE();
		case 0xDC: // CRASH
			MinxCPU_OnException(EXCEPTION_CRASH_INSTRUCTION, 0xDCCE);
			return 64;
		case 0xDD: // NOTHING
			return 16;
		case 0xDE: // ??? #nn
		case 0xDF: // ??? #nn
			return MinxCPU_ExecSPCE();

		case 0xE0: // JL #ss
			I8A = Fetch8();
			if ( ((MinxCPU.F & MINX_FLAG_OVERFLOW)!=0) != ((MinxCPU.F & MINX_FLAG_SIGN)!=0) ) {
				JMPS(S8_TO_16(I8A));
			}
			return 12;
		case 0xE1: // JLE #ss
			I8A = Fetch8();
			if ( (((MinxCPU.F & MINX_FLAG_OVERFLOW)==0) != ((MinxCPU.F & MINX_FLAG_SIGN)==0)) || ((MinxCPU.F & MINX_FLAG_ZERO)!=0) ) {
				JMPS(S8_TO_16(I8A));
			}
			return 12;
		case 0xE2: // JG #ss
			I8A = Fetch8();
			if ( (((MinxCPU.F & MINX_FLAG_OVERFLOW)!=0) == ((MinxCPU.F & MINX_FLAG_SIGN)!=0)) && ((MinxCPU.F & MINX_FLAG_ZERO)==0) ) {
				JMPS(S8_TO_16(I8A));
			}
			return 12;
		case 0xE3: // JGE #ss
			I8A = Fetch8();
			if ( ((MinxCPU.F & MINX_FLAG_OVERFLOW)==0) == ((MinxCPU.F & MINX_FLAG_SIGN)==0) ) {
				JMPS(S8_TO_16(I8A));
			}
			return 12;

		case 0xE4: // JO #ss
			I8A = Fetch8();
			if (MinxCPU.F & MINX_FLAG_OVERFLOW) {
				JMPS(S8_TO_16(I8A));
			}
			return 12;
		case 0xE5: // JNO #ss
			I8A = Fetch8();
			if (!(MinxCPU.F & MINX_FLAG_OVERFLOW)) {
				JMPS(S8_TO_16(I8A));
			}
			return 12;
		case 0xE6: // JP #ss
			I8A = Fetch8();
			if (!(MinxCPU.F & MINX_FLAG_SIGN)) {
				JMPS(S8_TO_16(I8A));
			}
			return 12;
		case 0xE7: // JNP #ss
			I8A = Fetch8();
			if (MinxCPU.F & MINX_FLAG_SIGN) {
				JMPS(S8_TO_16(I8A));
			}
			return 12;

		case 0xE8: // JNX0 #ss
			I8A = Fetch8();
			if (!(MinxCPU.E & 0x01)) {
				JMPS(S8_TO_16(I8A));
			}
			return 12;
		case 0xE9: // JNX1 #ss
			I8A = Fetch8();
			if (!(MinxCPU.E & 0x02)) {
				JMPS(S8_TO_16(I8A));
			}
			return 12;
		case 0xEA: // JNX2 #ss
			I8A = Fetch8();
			if (!(MinxCPU.E & 0x04)) {
				JMPS(S8_TO_16(I8A));
			}
			return 12;
		case 0xEB: // JNX3 #ss
			I8A = Fetch8();
			if (!(MinxCPU.E & 0x08)) {
				JMPS(S8_TO_16(I8A));
			}
			return 12;

		case 0xEC: // JX0 #ss
			I8A = Fetch8();
			if (MinxCPU.E & 0x01) {
				JMPS(S8_TO_16(I8A));
			}
			return 12;
		case 0xED: // JX1 #ss
			I8A = Fetch8();
			if (MinxCPU.E & 0x02) {
				JMPS(S8_TO_16(I8A));
			}
			return 12;
		case 0xEE: // JX2 #ss
			I8A = Fetch8();
			if (MinxCPU.E & 0x04) {
				JMPS(S8_TO_16(I8A));
			}
			return 12;
		case 0xEF: // JX3 #ss
			I8A = Fetch8();
			if (MinxCPU.E & 0x08) {
				JMPS(S8_TO_16(I8A));
			}
			return 12;

		case 0xF0: // CALLL #ss
			I8A = Fetch8();
			if ( ((MinxCPU.F & MINX_FLAG_OVERFLOW)!=0) != ((MinxCPU.F & MINX_FLAG_SIGN)!=0) ) {
				CALLS(S8_TO_16(I8A));
			}
			return 12;
		case 0xF1: // CALLLE #ss
			I8A = Fetch8();
			if ( (((MinxCPU.F & MINX_FLAG_OVERFLOW)==0) != ((MinxCPU.F & MINX_FLAG_SIGN)==0)) || ((MinxCPU.F & MINX_FLAG_ZERO)!=0) ) {
				CALLS(S8_TO_16(I8A));
			}
			return 12;
		case 0xF2: // CALLG #ss
			I8A = Fetch8();
			if ( (((MinxCPU.F & MINX_FLAG_OVERFLOW)!=0) == ((MinxCPU.F & MINX_FLAG_SIGN)!=0)) && ((MinxCPU.F & MINX_FLAG_ZERO)==0) ) {
				CALLS(S8_TO_16(I8A));
			}
			return 12;
		case 0xF3: // CALLGE #ss
			I8A = Fetch8();
			if ( ((MinxCPU.F & MINX_FLAG_OVERFLOW)==0) == ((MinxCPU.F & MINX_FLAG_SIGN)==0) ) {
				CALLS(S8_TO_16(I8A));
			}
			return 12;

		case 0xF4: // CALLO #ss
			I8A = Fetch8();
			if (MinxCPU.F & MINX_FLAG_OVERFLOW) {
				CALLS(S8_TO_16(I8A));
			}
			return 12;
		case 0xF5: // CALLNO #ss
			I8A = Fetch8();
			if (!(MinxCPU.F & MINX_FLAG_OVERFLOW)) {
				CALLS(S8_TO_16(I8A));
			}
			return 12;
		case 0xF6: // CALLNS #ss
			I8A = Fetch8();
			if (!(MinxCPU.F & MINX_FLAG_SIGN)) {
				CALLS(S8_TO_16(I8A));
			}
			return 12;
		case 0xF7: // CALLS #ss
			I8A = Fetch8();
			if (MinxCPU.F & MINX_FLAG_SIGN) {
				CALLS(S8_TO_16(I8A));
			}
			return 12;

		case 0xF8: // CALLNX0 #ss
			I8A = Fetch8();
			if (!(MinxCPU.E & 0x01)) {
				CALLS(S8_TO_16(I8A));
			}
			return 12;
		case 0xF9: // CALLNX1 #ss
			I8A = Fetch8();
			if (!(MinxCPU.E & 0x02)) {
				CALLS(S8_TO_16(I8A));
			}
			return 12;
		case 0xFA: // CALLNX2 #ss
			I8A = Fetch8();
			if (!(MinxCPU.E & 0x04)) {
				CALLS(S8_TO_16(I8A));
			}
			return 12;
		case 0xFB: // CALLNX3 #ss
			I8A = Fetch8();
			if (!(MinxCPU.E & 0x08)) {
				CALLS(S8_TO_16(I8A));
			}
			return 12;

		case 0xFC: // CALLX0 #ss
			I8A = Fetch8();
			if (MinxCPU.E & 0x01) {
				CALLS(S8_TO_16(I8A));
			}
			return 12;
		case 0xFD: // CALLX1 #ss
			I8A = Fetch8();
			if (MinxCPU.E & 0x02) {
				CALLS(S8_TO_16(I8A));
			}
			return 12;
		case 0xFE: // CALLX2 #ss
			I8A = Fetch8();
			if (MinxCPU.E & 0x04) {
				CALLS(S8_TO_16(I8A));
			}
			return 12;
		case 0xFF: // CALLX3 #ss
			I8A = Fetch8();
			if (MinxCPU.E & 0x08) {
				CALLS(S8_TO_16(I8A));
			}
			return 12;

		default:
			MinxCPU_OnException(EXCEPTION_UNKNOWN_INSTRUCTION, (MinxCPU.IR << 8) + 0xCE);
			return 4;
	}
}
