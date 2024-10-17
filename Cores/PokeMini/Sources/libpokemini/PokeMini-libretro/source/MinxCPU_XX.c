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

// Note: Any write to MinxCPU.HL.B.I needs to be reflected into MinxCPU.N.B.I

#include "MinxCPU.h"

int MinxCPU_Exec(void)
{
	uint8_t I8A, I8B;
	uint16_t I16;

	// Shift U
	if (MinxCPU.Shift_U) {
		MinxCPU.U1 = MinxCPU.U2;
		MinxCPU.U2 = MinxCPU.PC.B.I;
		MinxCPU.Shift_U--;
		MinxCPU_OnIRQHandle(MinxCPU.F, MinxCPU.Shift_U);
	}

	// Check HALT or STOP status
	if (MinxCPU.Status != MINX_STATUS_NORMAL) {
		if (MinxCPU.Status == MINX_STATUS_IRQ) {
			MinxCPU.Status = MINX_STATUS_NORMAL;	// Return to normal
			CALLI(MinxCPU.IRQ_Vector);		// Jump to IRQ vector
			return 20;
		} else {
			return 8;				// Cause short NOPs
		}
	}

	// Read IR
	MinxCPU.IR = Fetch8();

	// Process instruction
	switch(MinxCPU.IR) {

		case 0x00: // ADD A, A
			MinxCPU.BA.B.L = ADD8(MinxCPU.BA.B.L, MinxCPU.BA.B.L);
			return 8;
		case 0x01: // ADD A, B
			MinxCPU.BA.B.L = ADD8(MinxCPU.BA.B.L, MinxCPU.BA.B.H);
			return 8;
		case 0x02: // ADD A, #nn
			I8A = Fetch8();
			MinxCPU.BA.B.L = ADD8(MinxCPU.BA.B.L, I8A);
			return 8;
		case 0x03: // ADD A, [HL]
			MinxCPU.BA.B.L = ADD8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.HL.D));
			return 8;
		case 0x04: // ADD A, [N+#nn]
			I8A = Fetch8();
			MinxCPU.BA.B.L = ADD8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.N.D + I8A));
			return 12;
		case 0x05: // ADD A, [#nnnn]
			I16 = Fetch16();
			MinxCPU.BA.B.L = ADD8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.HL.B.I << 16) | I16));
			return 16;
		case 0x06: // ADD A, [X]
			MinxCPU.BA.B.L = ADD8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.X.D));
			return 8;
		case 0x07: // ADD A, [Y]
			MinxCPU.BA.B.L = ADD8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.Y.D));
			return 8;

		case 0x08: // ADC A, A
			MinxCPU.BA.B.L = ADC8(MinxCPU.BA.B.L, MinxCPU.BA.B.L);
			return 8;
		case 0x09: // ADC A, B
			MinxCPU.BA.B.L = ADC8(MinxCPU.BA.B.L, MinxCPU.BA.B.H);
			return 8;
		case 0x0A: // ADC A, #nn
			I8A = Fetch8();
			MinxCPU.BA.B.L = ADC8(MinxCPU.BA.B.L, I8A);
			return 8;
		case 0x0B: // ADC A, [HL]
			MinxCPU.BA.B.L = ADC8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.HL.D));
			return 8;
		case 0x0C: // ADC A, [N+#nn]
			I8A = Fetch8();
			MinxCPU.BA.B.L = ADC8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.N.D + I8A));
			return 12;
		case 0x0D: // ADC A, [#nnnn]
			I16 = Fetch16();
			MinxCPU.BA.B.L = ADC8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.HL.B.I << 16) | I16));
			return 16;
		case 0x0E: // ADC A, [X]
			MinxCPU.BA.B.L = ADC8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.X.D));
			return 8;
		case 0x0F: // ADC A, [Y]
			MinxCPU.BA.B.L = ADC8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.Y.D));
			return 8;

		case 0x10: // SUB A, A
			MinxCPU.BA.B.L = SUB8(MinxCPU.BA.B.L, MinxCPU.BA.B.L);
			return 8;
		case 0x11: // SUB A, B
			MinxCPU.BA.B.L = SUB8(MinxCPU.BA.B.L, MinxCPU.BA.B.H);
			return 8;
		case 0x12: // SUB A, #nn
			I8A = Fetch8();
			MinxCPU.BA.B.L = SUB8(MinxCPU.BA.B.L, I8A);
			return 8;
		case 0x13: // SUB A, [HL]
			MinxCPU.BA.B.L = SUB8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.HL.D));
			return 8;
		case 0x14: // SUB A, [N+#nn]
			I8A = Fetch8();
			MinxCPU.BA.B.L = SUB8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.N.D + I8A));
			return 12;
		case 0x15: // SUB A, [#nnnn]
			I16 = Fetch16();
			MinxCPU.BA.B.L = SUB8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.HL.B.I << 16) | I16));
			return 16;
		case 0x16: // SUB A, [X]
			MinxCPU.BA.B.L = SUB8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.X.D));
			return 8;
		case 0x17: // SUB A, [Y]
			MinxCPU.BA.B.L = SUB8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.Y.D));
			return 8;

		case 0x18: // SBC A, A
			MinxCPU.BA.B.L = SBC8(MinxCPU.BA.B.L, MinxCPU.BA.B.L);
			return 8;
		case 0x19: // SBC A, B
			MinxCPU.BA.B.L = SBC8(MinxCPU.BA.B.L, MinxCPU.BA.B.H);
			return 8;
		case 0x1A: // SBC A, #nn
			I8A = Fetch8();
			MinxCPU.BA.B.L = SBC8(MinxCPU.BA.B.L, I8A);
			return 8;
		case 0x1B: // SBC A, [HL]
			MinxCPU.BA.B.L = SBC8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.HL.D));
			return 8;
		case 0x1C: // SBC A, [N+#nn]
			I8A = Fetch8();
			MinxCPU.BA.B.L = SBC8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.N.D + I8A));
			return 12;
		case 0x1D: // SBC A, [#nnnn]
			I16 = Fetch16();
			MinxCPU.BA.B.L = SBC8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.HL.B.I << 16) | I16));
			return 16;
		case 0x1E: // SBC A, [X]
			MinxCPU.BA.B.L = SBC8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.X.D));
			return 8;
		case 0x1F: // SBC A, [Y]
			MinxCPU.BA.B.L = SBC8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.Y.D));
			return 8;

		case 0x20: // AND A, A
			MinxCPU.BA.B.L = AND8(MinxCPU.BA.B.L, MinxCPU.BA.B.L);
			return 8;
		case 0x21: // AND A, B
			MinxCPU.BA.B.L = AND8(MinxCPU.BA.B.L, MinxCPU.BA.B.H);
			return 8;
		case 0x22: // AND A, #nn
			I8A = Fetch8();
			MinxCPU.BA.B.L = AND8(MinxCPU.BA.B.L, I8A);
			return 8;
		case 0x23: // AND A, [HL]
			MinxCPU.BA.B.L = AND8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.HL.D));
			return 8;
		case 0x24: // AND A, [N+#nn]
			I8A = Fetch8();
			MinxCPU.BA.B.L = AND8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.N.D + I8A));
			return 12;
		case 0x25: // AND A, [#nnnn]
			I16 = Fetch16();
			MinxCPU.BA.B.L = AND8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.HL.B.I << 16) | I16));
			return 16;
		case 0x26: // AND A, [X]
			MinxCPU.BA.B.L = AND8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.X.D));
			return 8;
		case 0x27: // AND A, [Y]
			MinxCPU.BA.B.L = AND8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.Y.D));
			return 8;

		case 0x28: // OR A, A
			MinxCPU.BA.B.L = OR8(MinxCPU.BA.B.L, MinxCPU.BA.B.L);
			return 8;
		case 0x29: // OR A, B
			MinxCPU.BA.B.L = OR8(MinxCPU.BA.B.L, MinxCPU.BA.B.H);
			return 8;
		case 0x2A: // OR A, #nn
			I8A = Fetch8();
			MinxCPU.BA.B.L = OR8(MinxCPU.BA.B.L, I8A);
			return 8;
		case 0x2B: // OR A, [HL]
			MinxCPU.BA.B.L = OR8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.HL.D));
			return 8;
		case 0x2C: // OR A, [N+#nn]
			I8A = Fetch8();
			MinxCPU.BA.B.L = OR8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.N.D + I8A));
			return 12;
		case 0x2D: // OR A, [#nnnn]
			I16 = Fetch16();
			MinxCPU.BA.B.L = OR8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.HL.B.I << 16) | I16));
			return 16;
		case 0x2E: // OR A, [X]
			MinxCPU.BA.B.L = OR8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.X.D));
			return 8;
		case 0x2F: // OR A, [Y]
			MinxCPU.BA.B.L = OR8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.Y.D));
			return 8;

		case 0x30: // CMP A, A
			SUB8(MinxCPU.BA.B.L, MinxCPU.BA.B.L);
			return 8;
		case 0x31: // CMP A, B
			SUB8(MinxCPU.BA.B.L, MinxCPU.BA.B.H);
			return 8;
		case 0x32: // CMP A, #nn
			I8A = Fetch8();
			SUB8(MinxCPU.BA.B.L, I8A);
			return 8;
		case 0x33: // CMP A, [HL]
			SUB8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.HL.D));
			return 8;
		case 0x34: // CMP A, [N+#nn]
			I8A = Fetch8();
			SUB8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.N.D + I8A));
			return 12;
		case 0x35: // CMP A, [#nnnn]
			I16 = Fetch16();
			SUB8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.HL.B.I << 16) | I16));
			return 16;
		case 0x36: // CMP A, [X]
			SUB8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.X.D));
			return 8;
		case 0x37: // CMP A, [Y]
			SUB8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.Y.D));
			return 8;

		case 0x38: // XOR A, A
			MinxCPU.BA.B.L = XOR8(MinxCPU.BA.B.L, MinxCPU.BA.B.L);
			return 8;
		case 0x39: // XOR A, B
			MinxCPU.BA.B.L = XOR8(MinxCPU.BA.B.L, MinxCPU.BA.B.H);
			return 8;
		case 0x3A: // XOR A, #nn
			I8A = Fetch8();
			MinxCPU.BA.B.L = XOR8(MinxCPU.BA.B.L, I8A);
			return 8;
		case 0x3B: // XOR A, [HL]
			MinxCPU.BA.B.L = XOR8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.HL.D));
			return 8;
		case 0x3C: // XOR A, [N+#nn]
			I8A = Fetch8();
			MinxCPU.BA.B.L = XOR8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.N.D + I8A));
			return 12;
		case 0x3D: // XOR A, [#nnnn]
			I16 = Fetch16();
			MinxCPU.BA.B.L = XOR8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, (MinxCPU.HL.B.I << 16) | I16));
			return 16;
		case 0x3E: // XOR A, [X]
			MinxCPU.BA.B.L = XOR8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.X.D));
			return 8;
		case 0x3F: // XOR A, [Y]
			MinxCPU.BA.B.L = XOR8(MinxCPU.BA.B.L, MinxCPU_OnRead(1, MinxCPU.Y.D));
			return 8;

		case 0x40: // MOV A, A
			return 4;
		case 0x41: // MOV A, B
			MinxCPU.BA.B.L = MinxCPU.BA.B.H;
			return 4;
		case 0x42: // MOV A, L
			MinxCPU.BA.B.L = MinxCPU.HL.B.L;
			return 4;
		case 0x43: // MOV A, H
			MinxCPU.BA.B.L = MinxCPU.HL.B.H;
			return 4;
		case 0x44: // MOV A, [N+#nn]
			I8A = Fetch8();
			MinxCPU.BA.B.L = MinxCPU_OnRead(1, MinxCPU.N.D + I8A);
			return 12;
		case 0x45: // MOV A, [HL]
			MinxCPU.BA.B.L = MinxCPU_OnRead(1, MinxCPU.HL.D);
			return 8;
		case 0x46: // MOV A, [X]
			MinxCPU.BA.B.L = MinxCPU_OnRead(1, MinxCPU.X.D);
			return 8;
		case 0x47: // MOV A, [Y]
			MinxCPU.BA.B.L = MinxCPU_OnRead(1, MinxCPU.Y.D);
			return 8;

		case 0x48: // MOV B, A
			MinxCPU.BA.B.H = MinxCPU.BA.B.L;
			return 4;
		case 0x49: // MOV B, B
			return 4;
		case 0x4A: // MOV B, L
			MinxCPU.BA.B.H = MinxCPU.HL.B.L;
			return 4;
		case 0x4B: // MOV B, H
			MinxCPU.BA.B.H = MinxCPU.HL.B.H;
			return 4;
		case 0x4C: // MOV B, [N+#nn]
			I8A = Fetch8();
			MinxCPU.BA.B.H = MinxCPU_OnRead(1, MinxCPU.N.D + I8A);
			return 12;
		case 0x4D: // MOV B, [HL]
			MinxCPU.BA.B.H = MinxCPU_OnRead(1, MinxCPU.HL.D);
			return 8;
		case 0x4E: // MOV B, [X]
			MinxCPU.BA.B.H = MinxCPU_OnRead(1, MinxCPU.X.D);
			return 8;
		case 0x4F: // MOV B, [Y]
			MinxCPU.BA.B.H = MinxCPU_OnRead(1, MinxCPU.Y.D);
			return 8;

		case 0x50: // MOV L, A
			MinxCPU.HL.B.L = MinxCPU.BA.B.L;
			return 4;
		case 0x51: // MOV L, B
			MinxCPU.HL.B.L = MinxCPU.BA.B.H;
			return 4;
		case 0x52: // MOV L, L
			return 4;
		case 0x53: // MOV L, H
			MinxCPU.HL.B.L = MinxCPU.HL.B.H;
			return 4;
		case 0x54: // MOV L, [N+#nn]
			I8A = Fetch8();
			MinxCPU.HL.B.L = MinxCPU_OnRead(1, MinxCPU.N.D + I8A);
			return 12;
		case 0x55: // MOV L, [HL]
			MinxCPU.HL.B.L = MinxCPU_OnRead(1, MinxCPU.HL.D);
			return 8;
		case 0x56: // MOV L, [X]
			MinxCPU.HL.B.L = MinxCPU_OnRead(1, MinxCPU.X.D);
			return 8;
		case 0x57: // MOV L, [Y]
			MinxCPU.HL.B.L = MinxCPU_OnRead(1, MinxCPU.Y.D);
			return 8;

		case 0x58: // MOV H, A
			MinxCPU.HL.B.H = MinxCPU.BA.B.L;
			return 4;
		case 0x59: // MOV H, B
			MinxCPU.HL.B.H = MinxCPU.BA.B.H;
			return 4;
		case 0x5A: // MOV H, L
			MinxCPU.HL.B.H = MinxCPU.HL.B.L;
			return 4;
		case 0x5B: // MOV H, H
			return 4;
		case 0x5C: // MOV H, [N+#nn]
			I8A = Fetch8();
			MinxCPU.HL.B.H = MinxCPU_OnRead(1, MinxCPU.N.D + I8A);
			return 12;
		case 0x5D: // MOV H, [HL]
			MinxCPU.HL.B.H = MinxCPU_OnRead(1, MinxCPU.HL.D);
			return 8;
		case 0x5E: // MOV H, [X]
			MinxCPU.HL.B.H = MinxCPU_OnRead(1, MinxCPU.X.D);
			return 8;
		case 0x5F: // MOV H, [Y]
			MinxCPU.HL.B.H = MinxCPU_OnRead(1, MinxCPU.Y.D);
			return 8;

		case 0x60: // MOV [X], A
			MinxCPU_OnWrite(1, MinxCPU.X.D, MinxCPU.BA.B.L);
			return 8;
		case 0x61: // MOV [X], B
			MinxCPU_OnWrite(1, MinxCPU.X.D, MinxCPU.BA.B.H);
			return 8;
		case 0x62: // MOV [X], L
			MinxCPU_OnWrite(1, MinxCPU.X.D, MinxCPU.HL.B.L);
			return 8;
		case 0x63: // MOV [X], H
			MinxCPU_OnWrite(1, MinxCPU.X.D, MinxCPU.HL.B.H);
			return 8;
		case 0x64: // MOV [X], [N+#nn]
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.X.D, MinxCPU_OnRead(1, MinxCPU.N.D + I8A));
			return 16;
		case 0x65: // MOV [X], [HL]
			MinxCPU_OnWrite(1, MinxCPU.X.D, MinxCPU_OnRead(1, MinxCPU.HL.D));
			return 12;
		case 0x66: // MOV [X], [X]
			MinxCPU_OnWrite(1, MinxCPU.X.D, MinxCPU_OnRead(1, MinxCPU.X.D));
			return 12;
		case 0x67: // MOV [X], [Y]
			MinxCPU_OnWrite(1, MinxCPU.X.D, MinxCPU_OnRead(1, MinxCPU.Y.D));
			return 12;

		case 0x68: // MOV [HL], A
			MinxCPU_OnWrite(1, MinxCPU.HL.D, MinxCPU.BA.B.L);
			return 8;
		case 0x69: // MOV [HL], B
			MinxCPU_OnWrite(1, MinxCPU.HL.D, MinxCPU.BA.B.H);
			return 8;
		case 0x6A: // MOV [HL], L
			MinxCPU_OnWrite(1, MinxCPU.HL.D, MinxCPU.HL.B.L);
			return 8;
		case 0x6B: // MOV [HL], H
			MinxCPU_OnWrite(1, MinxCPU.HL.D, MinxCPU.HL.B.H);
			return 8;
		case 0x6C: // MOV [HL], [N+#nn]
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.HL.D, MinxCPU_OnRead(1, MinxCPU.N.D + I8A));
			return 16;
		case 0x6D: // MOV [HL], [HL]
			MinxCPU_OnWrite(1, MinxCPU.HL.D, MinxCPU_OnRead(1, MinxCPU.HL.D));
			return 12;
		case 0x6E: // MOV [HL], [X]
			MinxCPU_OnWrite(1, MinxCPU.HL.D, MinxCPU_OnRead(1, MinxCPU.X.D));
			return 12;
		case 0x6F: // MOV [HL], [Y]
			MinxCPU_OnWrite(1, MinxCPU.HL.D, MinxCPU_OnRead(1, MinxCPU.Y.D));
			return 12;

		case 0x70: // MOV [Y], A
			MinxCPU_OnWrite(1, MinxCPU.Y.D, MinxCPU.BA.B.L);
			return 8;
		case 0x71: // MOV [Y], B
			MinxCPU_OnWrite(1, MinxCPU.Y.D, MinxCPU.BA.B.H);
			return 8;
		case 0x72: // MOV [Y], L
			MinxCPU_OnWrite(1, MinxCPU.Y.D, MinxCPU.HL.B.L);
			return 8;
		case 0x73: // MOV [Y], H
			MinxCPU_OnWrite(1, MinxCPU.Y.D, MinxCPU.HL.B.H);
			return 8;
		case 0x74: // MOV [Y], [N+#nn]
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.Y.D, MinxCPU_OnRead(1, MinxCPU.N.D + I8A));
			return 16;
		case 0x75: // MOV [Y], [HL]
			MinxCPU_OnWrite(1, MinxCPU.Y.D, MinxCPU_OnRead(1, MinxCPU.HL.D));
			return 12;
		case 0x76: // MOV [Y], [X]
			MinxCPU_OnWrite(1, MinxCPU.Y.D, MinxCPU_OnRead(1, MinxCPU.X.D));
			return 12;
		case 0x77: // MOV [Y], [Y]
			MinxCPU_OnWrite(1, MinxCPU.Y.D, MinxCPU_OnRead(1, MinxCPU.Y.D));
			return 12;

		case 0x78: // MOV [N+#nn], A
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.N.D + I8A, MinxCPU.BA.B.L);
			return 8;
		case 0x79: // MOV [N+#nn], B
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.N.D + I8A, MinxCPU.BA.B.H);
			return 8;
		case 0x7A: // MOV [N+#nn], L
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.N.D + I8A, MinxCPU.HL.B.L);
			return 8;
		case 0x7B: // MOV [N+#nn], H
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.N.D + I8A, MinxCPU.HL.B.H);
			return 8;
		case 0x7C: // NOTHING #nn
			I8A = Fetch8();
			return 64;
		case 0x7D: // MOV [N+#nn], [HL]
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.N.D + I8A, MinxCPU_OnRead(1, MinxCPU.HL.D));
			return 16;
		case 0x7E: // MOV [N+#nn], [X]
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.N.D + I8A, MinxCPU_OnRead(1, MinxCPU.X.D));
			return 16;
		case 0x7F: // MOV [N+#nn], [Y]
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.N.D + I8A, MinxCPU_OnRead(1, MinxCPU.Y.D));
			return 16;

		case 0x80: // INC A
			MinxCPU.BA.B.L = INC8(MinxCPU.BA.B.L);
			return 8;
		case 0x81: // INC B
			MinxCPU.BA.B.H = INC8(MinxCPU.BA.B.H);
			return 8;
		case 0x82: // INC L
			MinxCPU.HL.B.L = INC8(MinxCPU.HL.B.L);
			return 8;
		case 0x83: // INC H
			MinxCPU.HL.B.H = INC8(MinxCPU.HL.B.H);
			return 8;
		case 0x84: // INC N
			MinxCPU.N.B.H = INC8(MinxCPU.N.B.H);
			return 8;
		case 0x85: // INC [N+#nn]
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.N.D + I8A, INC8(MinxCPU_OnRead(1, MinxCPU.N.D + I8A)));
			return 16;
		case 0x86: // INC [HL]
			MinxCPU_OnWrite(1, MinxCPU.HL.D, INC8(MinxCPU_OnRead(1, MinxCPU.HL.D)));
			return 12;
		case 0x87: // INC SP
			MinxCPU.SP.W.L = INC16(MinxCPU.SP.W.L);
			return 8;

		case 0x88: // DEC A
			MinxCPU.BA.B.L = DEC8(MinxCPU.BA.B.L);
			return 8;
		case 0x89: // DEC B
			MinxCPU.BA.B.H = DEC8(MinxCPU.BA.B.H);
			return 8;
		case 0x8A: // DEC L
			MinxCPU.HL.B.L = DEC8(MinxCPU.HL.B.L);
			return 8;
		case 0x8B: // DEC H
			MinxCPU.HL.B.H = DEC8(MinxCPU.HL.B.H);
			return 8;
		case 0x8C: // DEC N
			MinxCPU.N.B.H = DEC8(MinxCPU.N.B.H);
			return 8;
		case 0x8D: // DEC [N+#nn]
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.N.D + I8A, DEC8(MinxCPU_OnRead(1, MinxCPU.N.D + I8A)));
			return 16;
		case 0x8E: // DEC [HL]
			MinxCPU_OnWrite(1, MinxCPU.HL.D, DEC8(MinxCPU_OnRead(1, MinxCPU.HL.D)));
			return 12;
		case 0x8F: // DEC SP
			MinxCPU.SP.W.L = DEC16(MinxCPU.SP.W.L);
			return 8;

		case 0x90: // INC BA
			MinxCPU.BA.W.L = INC16(MinxCPU.BA.W.L);
			return 8;
		case 0x91: // INC HL
			MinxCPU.HL.W.L = INC16(MinxCPU.HL.W.L);
			return 8;
		case 0x92: // INC X
			MinxCPU.X.W.L = INC16(MinxCPU.X.W.L);
			return 8;
		case 0x93: // INC Y
			MinxCPU.Y.W.L = INC16(MinxCPU.Y.W.L);
			return 8;

		case 0x94: // TST A, B
			AND8(MinxCPU.BA.B.L, MinxCPU.BA.B.H);
			return 8;
		case 0x95: // TST [HL], #nn
			I8A = Fetch8();
			AND8(MinxCPU_OnRead(1, MinxCPU.HL.D), I8A);
			return 12;
		case 0x96: // TST A, #nn
			I8A = Fetch8();
			AND8(MinxCPU.BA.B.L, I8A);
			return 8;
		case 0x97: // TST B, #nn
			I8A = Fetch8();
			AND8(MinxCPU.BA.B.H, I8A);
			return 8;

		case 0x98: // DEC BA
			MinxCPU.BA.W.L = DEC16(MinxCPU.BA.W.L);
			return 8;
		case 0x99: // DEC HL
			MinxCPU.HL.W.L = DEC16(MinxCPU.HL.W.L);
			return 8;
		case 0x9A: // DEC X
			MinxCPU.X.W.L = DEC16(MinxCPU.X.W.L);
			return 8;
		case 0x9B: // DEC Y
			MinxCPU.Y.W.L = DEC16(MinxCPU.Y.W.L);
			return 8;

		case 0x9C: // AND F, #nn
			I8A = Fetch8();
			MinxCPU.F = MinxCPU.F & I8A;
			MinxCPU_OnIRQHandle(MinxCPU.F, MinxCPU.Shift_U);
			return 12;
		case 0x9D: // OR F, #nn
			I8A = Fetch8();
			MinxCPU.F = MinxCPU.F | I8A;
			MinxCPU_OnIRQHandle(MinxCPU.F, MinxCPU.Shift_U);
			return 12;
		case 0x9E: // XOR F, #nn
			I8A = Fetch8();
			MinxCPU.F = MinxCPU.F ^ I8A;
			MinxCPU_OnIRQHandle(MinxCPU.F, MinxCPU.Shift_U);
			return 12;
		case 0x9F: // MOV F, #nn
			I8A = Fetch8();
			MinxCPU.F = I8A;
			MinxCPU_OnIRQHandle(MinxCPU.F, MinxCPU.Shift_U);
			return 12;

		case 0xA0: // PUSH BA
			PUSH(MinxCPU.BA.B.H);
			PUSH(MinxCPU.BA.B.L);
			return 16;
		case 0xA1: // PUSH HL
			PUSH(MinxCPU.HL.B.H);
			PUSH(MinxCPU.HL.B.L);
			return 16;
		case 0xA2: // PUSH X
			PUSH(MinxCPU.X.B.H);
			PUSH(MinxCPU.X.B.L);
			return 16;
		case 0xA3: // PUSH Y
			PUSH(MinxCPU.Y.B.H);
			PUSH(MinxCPU.Y.B.L);
			return 16;
		case 0xA4: // PUSH N
			PUSH(MinxCPU.N.B.H);
			return 12;
		case 0xA5: // PUSH I
			PUSH(MinxCPU.HL.B.I);
			return 12;
		case 0xA6: // PUSHX
			PUSH(MinxCPU.X.B.I);
			PUSH(MinxCPU.Y.B.I);
			return 16;
		case 0xA7: // PUSH F
			PUSH(MinxCPU.F);
			return 12;

		case 0xA8: // POP BA
			MinxCPU.BA.B.L = POP();
			MinxCPU.BA.B.H = POP();
			return 12;
		case 0xA9: // POP HL
			MinxCPU.HL.B.L = POP();
			MinxCPU.HL.B.H = POP();
			return 12;
		case 0xAA: // POP X
			MinxCPU.X.B.L = POP();
			MinxCPU.X.B.H = POP();
			return 12;
		case 0xAB: // POP Y
			MinxCPU.Y.B.L = POP();
			MinxCPU.Y.B.H = POP();
			return 12;
		case 0xAC: // POP N
			MinxCPU.N.B.H = POP();
			return 8;
		case 0xAD: // POP I
			MinxCPU.HL.B.I = POP();
			MinxCPU.N.B.I = MinxCPU.HL.B.I;
			return 8;
		case 0xAE: // POPX
			MinxCPU.Y.B.I = POP();
			MinxCPU.X.B.I = POP();
			return 12;
		case 0xAF: // POP F
			MinxCPU.F = POP();
			MinxCPU_OnIRQHandle(MinxCPU.F, MinxCPU.Shift_U);
			return 8;

		case 0xB0: // MOV A, #nn
			I8A = Fetch8();
			MinxCPU.BA.B.L = I8A;
			return 8;
		case 0xB1: // MOV B, #nn
			I8A = Fetch8();
			MinxCPU.BA.B.H = I8A;
			return 8;
		case 0xB2: // MOV L, #nn
			I8A = Fetch8();
			MinxCPU.HL.B.L = I8A;
			return 8;
		case 0xB3: // MOV H, #nn
			I8A = Fetch8();
			MinxCPU.HL.B.H = I8A;
			return 8;
		case 0xB4: // MOV N, #nn
			I8A = Fetch8();
			MinxCPU.N.B.H = I8A;
			return 8;
		case 0xB5: // MOV [HL], #nn
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.HL.D, I8A);
			return 12;
		case 0xB6: // MOV [X], #nn
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.X.D, I8A);
			return 12;
		case 0xB7: // MOV [Y], #nn
			I8A = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.Y.D, I8A);
			return 12;

		case 0xB8: // MOV BA, [#nnnn]
			I16 = Fetch16();
			MinxCPU.BA.B.L = MinxCPU_OnRead(1, (MinxCPU.HL.B.I << 16) | I16++);
			MinxCPU.BA.B.H = MinxCPU_OnRead(1, (MinxCPU.HL.B.I << 16) | I16);
			return 20;
		case 0xB9: // MOV HL, [#nnnn]
			I16 = Fetch16();
			MinxCPU.HL.B.L = MinxCPU_OnRead(1, (MinxCPU.HL.B.I << 16) | I16++);
			MinxCPU.HL.B.H = MinxCPU_OnRead(1, (MinxCPU.HL.B.I << 16) | I16);
			return 20;
		case 0xBA: // MOV X, [#nnnn]
			I16 = Fetch16();
			MinxCPU.X.B.L = MinxCPU_OnRead(1, (MinxCPU.HL.B.I << 16) | I16++);
			MinxCPU.X.B.H = MinxCPU_OnRead(1, (MinxCPU.HL.B.I << 16) | I16);
			return 20;
		case 0xBB: // MOV Y, [#nnnn]
			I16 = Fetch16();
			MinxCPU.Y.B.L = MinxCPU_OnRead(1, (MinxCPU.HL.B.I << 16) | I16++);
			MinxCPU.Y.B.H = MinxCPU_OnRead(1, (MinxCPU.HL.B.I << 16) | I16);
			return 20;

		case 0xBC: // MOV [#nnnn], BA
			I16 = Fetch16();
			MinxCPU_OnWrite(1, (MinxCPU.HL.B.I << 16) | I16++, MinxCPU.BA.B.L);
			MinxCPU_OnWrite(1, (MinxCPU.HL.B.I << 16) | I16, MinxCPU.BA.B.H);
			return 20;
		case 0xBD: // MOV [#nnnn], HL
			I16 = Fetch16();
			MinxCPU_OnWrite(1, (MinxCPU.HL.B.I << 16) | I16++, MinxCPU.HL.B.L);
			MinxCPU_OnWrite(1, (MinxCPU.HL.B.I << 16) | I16, MinxCPU.HL.B.H);
			return 20;
		case 0xBE: // MOV [#nnnn], X
			I16 = Fetch16();
			MinxCPU_OnWrite(1, (MinxCPU.HL.B.I << 16) | I16++, MinxCPU.X.B.L);
			MinxCPU_OnWrite(1, (MinxCPU.HL.B.I << 16) | I16, MinxCPU.X.B.H);
			return 20;
		case 0xBF: // MOV [#nnnn], Y
			I16 = Fetch16();
			MinxCPU_OnWrite(1, (MinxCPU.HL.B.I << 16) | I16++, MinxCPU.Y.B.L);
			MinxCPU_OnWrite(1, (MinxCPU.HL.B.I << 16) | I16, MinxCPU.Y.B.H);
			return 20;

		case 0xC0: // ADD BA, #nnnn
			I16 = Fetch16();
			MinxCPU.BA.W.L = ADD16(MinxCPU.BA.W.L, I16);
			return 12;
		case 0xC1: // ADD HL, #nnnn
			I16 = Fetch16();
			MinxCPU.HL.W.L = ADD16(MinxCPU.HL.W.L, I16);
			return 12;
		case 0xC2: // ADD X, #nnnn
			I16 = Fetch16();
			MinxCPU.X.W.L = ADD16(MinxCPU.X.W.L, I16);
			return 12;
		case 0xC3: // ADD Y, #nnnn
			I16 = Fetch16();
			MinxCPU.Y.W.L = ADD16(MinxCPU.Y.W.L, I16);
			return 12;

		case 0xC4: // MOV BA, #nnnn
			I16 = Fetch16();
			MinxCPU.BA.W.L = I16;
			return 12;
		case 0xC5: // MOV HL, #nnnn
			I16 = Fetch16();
			MinxCPU.HL.W.L = I16;
			return 12;
		case 0xC6: // MOV X, #nnnn
			I16 = Fetch16();
			MinxCPU.X.W.L = I16;
			return 12;
		case 0xC7: // MOV Y, #nnnn
			I16 = Fetch16();
			MinxCPU.Y.W.L = I16;
			return 12;

		case 0xC8: // XCHG BA, HL
			I16 = MinxCPU.HL.W.L;
			MinxCPU.HL.W.L = MinxCPU.BA.W.L;
			MinxCPU.BA.W.L = I16;
			return 12;
		case 0xC9: // XCHG BA, X
			I16 = MinxCPU.X.W.L;
			MinxCPU.X.W.L = MinxCPU.BA.W.L;
			MinxCPU.BA.W.L = I16;
			return 12;
		case 0xCA: // XCHG BA, Y
			I16 = MinxCPU.Y.W.L;
			MinxCPU.Y.W.L = MinxCPU.BA.W.L;
			MinxCPU.BA.W.L = I16;
			return 12;
		case 0xCB: // XCHG BA, SP
			I16 = MinxCPU.SP.W.L;
			MinxCPU.SP.W.L = MinxCPU.BA.W.L;
			MinxCPU.BA.W.L = I16;
			return 12;

		case 0xCC: // XCHG A, B
			I8A = MinxCPU.BA.B.H;
			MinxCPU.BA.B.H = MinxCPU.BA.B.L;
			MinxCPU.BA.B.L = I8A;
			return 8;
		case 0xCD: // XCHG A, [HL]
			I8A = MinxCPU_OnRead(1, MinxCPU.HL.D);
			MinxCPU_OnWrite(1, MinxCPU.HL.D, MinxCPU.BA.B.L);
			MinxCPU.BA.B.L = I8A;
			return 12;

		case 0xCE: // Expand 0
			return MinxCPU_ExecCE();

		case 0xCF: // Expand 1
			return MinxCPU_ExecCF();

		case 0xD0: // SUB BA, #nnnn
			I16 = Fetch16();
			MinxCPU.BA.W.L = SUB16(MinxCPU.BA.W.L, I16);
			return 12;
		case 0xD1: // SUB HL, #nnnn
			I16 = Fetch16();
			MinxCPU.HL.W.L = SUB16(MinxCPU.HL.W.L, I16);
			return 12;
		case 0xD2: // SUB X, #nnnn
			I16 = Fetch16();
			MinxCPU.X.W.L = SUB16(MinxCPU.X.W.L, I16);
			return 12;
		case 0xD3: // SUB Y, #nnnn
			I16 = Fetch16();
			MinxCPU.Y.W.L = SUB16(MinxCPU.Y.W.L, I16);
			return 12;

		case 0xD4: // CMP BA, #nnnn
			I16 = Fetch16();
			SUB16(MinxCPU.BA.W.L, I16);
			return 12;
		case 0xD5: // CMP HL, #nnnn
			I16 = Fetch16();
			SUB16(MinxCPU.HL.W.L, I16);
			return 12;
		case 0xD6: // CMP X, #nnnn
			I16 = Fetch16();
			SUB16(MinxCPU.X.W.L, I16);
			return 12;
		case 0xD7: // CMP Y, #nnnn
			I16 = Fetch16();
			SUB16(MinxCPU.Y.W.L, I16);
			return 12;

		case 0xD8: // AND [N+#nn], #nn
			I8A = Fetch8();
			I8B = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.N.D + I8A, AND8(MinxCPU_OnRead(1, MinxCPU.N.D + I8A), I8B));
			return 20;
		case 0xD9: // OR [N+#nn], #nn
			I8A = Fetch8();
			I8B = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.N.D + I8A, OR8(MinxCPU_OnRead(1, MinxCPU.N.D + I8A), I8B));
			return 20;
		case 0xDA: // XOR [N+#nn], #nn
			I8A = Fetch8();
			I8B = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.N.D + I8A, XOR8(MinxCPU_OnRead(1, MinxCPU.N.D + I8A), I8B));
			return 20;
		case 0xDB: // CMP [N+#nn], #nn
			I8A = Fetch8();
			I8B = Fetch8();
			SUB8(MinxCPU_OnRead(1, MinxCPU.N.D + I8A), I8B);
			return 16;
		case 0xDC: // TST [N+#nn], #nn
			I8A = Fetch8();
			I8B = Fetch8();
			AND8(MinxCPU_OnRead(1, MinxCPU.N.D + I8A), I8B);
			return 16;
		case 0xDD: // MOV [N+#nn], #nn
			I8A = Fetch8();
			I8B = Fetch8();
			MinxCPU_OnWrite(1, MinxCPU.N.D + I8A, I8B);
			return 16;

		case 0xDE: // PACK
			MinxCPU.BA.B.L = (MinxCPU.BA.B.L & 0x0F) | (MinxCPU.BA.B.H << 4);
			return 8;

		case 0xDF: // UNPACK
			MinxCPU.BA.B.H = (MinxCPU.BA.B.L >> 4);
			MinxCPU.BA.B.L = MinxCPU.BA.B.L & 0x0F;
			return 8;

		case 0xE0: // CALLC #ss
			I8A = Fetch8();
			if (MinxCPU.F & MINX_FLAG_CARRY) {
				CALLS(S8_TO_16(I8A));
				return 20;
			}
			return 8;
		case 0xE1: // CALLNC #ss
			I8A = Fetch8();
			if (!(MinxCPU.F & MINX_FLAG_CARRY)) {
				CALLS(S8_TO_16(I8A));
				return 20;
			}
			return 8;
		case 0xE2: // CALLZ #ss
			I8A = Fetch8();
			if (MinxCPU.F & MINX_FLAG_ZERO) {
				CALLS(S8_TO_16(I8A));
				return 20;
			}
			return 8;
		case 0xE3: // CALLNZ #ss
			I8A = Fetch8();
			if (!(MinxCPU.F & MINX_FLAG_ZERO)) {
				CALLS(S8_TO_16(I8A));
				return 20;
			}
			return 8;

		case 0xE4: // JC #ss
			I8A = Fetch8();
			if (MinxCPU.F & MINX_FLAG_CARRY) {
				JMPS(S8_TO_16(I8A));
			}
			return 8;
		case 0xE5: // JNC #ss
			I8A = Fetch8();
			if (!(MinxCPU.F & MINX_FLAG_CARRY)) {
				JMPS(S8_TO_16(I8A));
			}
			return 8;
		case 0xE6: // JZ #ss
			I8A = Fetch8();
			if (MinxCPU.F & MINX_FLAG_ZERO) {
				JMPS(S8_TO_16(I8A));
			}
			return 8;
		case 0xE7: // JNZ #ss
			I8A = Fetch8();
			if (!(MinxCPU.F & MINX_FLAG_ZERO)) {
				JMPS(S8_TO_16(I8A));
			}
			return 8;

		case 0xE8: // CALLC #ssss
			I16 = Fetch16();
			if (MinxCPU.F & MINX_FLAG_CARRY) {
				CALLS(I16);
				return 24;
			}
			return 12;
		case 0xE9: // CALLNC #ssss
			I16 = Fetch16();
			if (!(MinxCPU.F & MINX_FLAG_CARRY)) {
				CALLS(I16);
				return 24;
			}
			return 12;
		case 0xEA: // CALLZ #ssss
			I16 = Fetch16();
			if (MinxCPU.F & MINX_FLAG_ZERO) {
				CALLS(I16);
				return 24;
			}
			return 12;
		case 0xEB: // CALLNZ #ssss
			I16 = Fetch16();
			if (!(MinxCPU.F & MINX_FLAG_ZERO)) {
				CALLS(I16);
				return 24;
			}
			return 12;

		case 0xEC: // JC #ssss
			I16 = Fetch16();
			if (MinxCPU.F & MINX_FLAG_CARRY) {
				JMPS(I16);
			}
			return 12;
		case 0xED: // JNC #ssss
			I16 = Fetch16();
			if (!(MinxCPU.F & MINX_FLAG_CARRY)) {
				JMPS(I16);
			}
			return 12;
		case 0xEE: // JZ #ssss
			I16 = Fetch16();
			if (MinxCPU.F & MINX_FLAG_ZERO) {
				JMPS(I16);
			}
			return 12;
		case 0xEF: // JNZ #ssss
			I16 = Fetch16();
			if (!(MinxCPU.F & MINX_FLAG_ZERO)) {
				JMPS(I16);
			}
			return 12;

		case 0xF0: // CALL #ss
			I8A = Fetch8();
			CALLS(S8_TO_16(I8A));
			return 20;
		case 0xF1: // JMP #ss
			I8A = Fetch8();
			JMPS(S8_TO_16(I8A));
			return 8;
		case 0xF2: // CALL #ssss
			I16 = Fetch16();
			CALLS(I16);
			return 24;
		case 0xF3: // JMP #ssss
			I16 = Fetch16();
			JMPS(I16);
			return 12;

		case 0xF4: // JMP HL
			JMPU(MinxCPU.HL.W.L);
			return 8;

		case 0xF5: // JDBNZ #ss
			I8A = Fetch8();
			JDBNZ(S8_TO_16(I8A));
			return 16;

		case 0xF6: // SWAP A
			MinxCPU.BA.B.L = SWAP(MinxCPU.BA.B.L);
			return 8;
		case 0xF7: // SWAP [HL]
			MinxCPU_OnWrite(1, MinxCPU.HL.D, SWAP(MinxCPU_OnRead(1, MinxCPU.HL.D)));
			return 12;

		case 0xF8: // RET
			RET();
			return 16;
		case 0xF9: // RETI
			RETI();
			return 16;
		case 0xFA: // RETSKIP
			RET();
			MinxCPU.PC.W.L = MinxCPU.PC.W.L + 2;
			return 16;

		case 0xFB: // CALL [#nnnn]
			I16 = Fetch16();
			CALLX(I16);
			return 20;
		case 0xFC: // CINT #nn
			I16 = Fetch8();
			CALLI(I16);
			return 20;
		case 0xFD: // JINT #nn
			I16 = Fetch8();
			JMPI(I16);
			return 8;

		case 0xFE: // CRASH
			MinxCPU_OnException(EXCEPTION_CRASH_INSTRUCTION, 0xFE);
			return 4;

		case 0xFF: // NOP
			return 8;

		default:
			MinxCPU_OnException(EXCEPTION_UNKNOWN_INSTRUCTION, MinxCPU.IR);
			return 4;
	}
}
