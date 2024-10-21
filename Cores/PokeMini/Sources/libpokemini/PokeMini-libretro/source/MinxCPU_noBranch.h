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

#ifndef MINXCPU_CORE
#define MINXCPU_CORE

#include <stdio.h>
#include <stdint.h>

/* For some reason, '_BIG_ENDIAN' is always defined when
 * building for 3DS with devkitarm... */
#if defined (_BIG_ENDIAN) && ! defined (_3DS)

typedef union {
	struct {
		uint8_t X;
		uint8_t I;
		uint8_t H;
		uint8_t L;
	} B;
	struct {
		uint16_t H;
		uint16_t L;
	} W;
	uint32_t D;
} MinxRegx;

#else

typedef union {
	struct {
		uint8_t L;
		uint8_t H;
		uint8_t I;
		uint8_t X;
	} B;
	struct {
		uint16_t L;
		uint16_t H;
	} W;
	uint32_t D;
} MinxRegx;

#endif

#define MINX_FLAG_ZERO    	0x01
#define MINX_FLAG_CARRY   	0x02
#define MINX_FLAG_OVERFLOW	0x04
#define MINX_FLAG_SIGN    	0x08
#define MINX_FLAG_BCD     	0x10
#define MINX_FLAG_NIBBLE  	0x20
#define MINX_FLAG_INTFLG  	0x40
#define MINX_FLAG_INTOFF  	0x80

#define MINX_FLAG_SIGN_S4	0
#define MINX_FLAG_OVER_S4	1
#define MINX_FLAG_SIGN_S8	4
#define MINX_FLAG_OVER_S8	5
#define MINX_FLAG_SIGN_S16	12
#define MINX_FLAG_OVER_S16	13

#define MINX_FLAG_SAVE_NUL	0xF0
#define MINX_FLAG_SAVE_O  	0xF4
#define MINX_FLAG_SAVE_CO 	0xF6
#define MINX_FLAG_SAVE_COS	0xFE

// OnException() reasons
enum {
	EXCEPTION_UNKNOWN_INSTRUCTION,
	EXCEPTION_CRASH_INSTRUCTION,
	EXCEPTION_UNSTABLE_INSTRUCTION,
	EXCEPTION_DIVISION_BY_ZERO
};

// OnSleep() reasons
enum {
	MINX_SLEEP_HALT,
	MINX_SLEEP_STOP
};

// Status reasons
enum {
	MINX_STATUS_NORMAL = 0, // Normal operation
	MINX_STATUS_HALT = 1,   // CPU during HALT
	MINX_STATUS_STOP = 2,   // CPU during STOP
	MINX_STATUS_IRQ = 3,    // Delay caused by hardware IRQ
};

// DebugHalt reasons
enum {
	MINX_DEBUGHALT_RECEIVE,
	MINX_DEBUGHALT_SUSPEND,
	MINX_DEBUGHALT_RESUME,
};

#ifndef inline
#define inline __inline
#endif

// Signed 8-Bits to 16-Bits converter
static inline uint16_t S8_TO_16(int8_t a)
{
	return (a & 0x80) ? (0xFF00 | a) : a;
}

typedef struct {
	// Registers
	MinxRegx BA;			// Registers A, B
	MinxRegx HL;			// Registers L, H, I
	MinxRegx X;			// Registers X, XI
	MinxRegx Y;			// Registers Y, YI
	MinxRegx SP;			// Register SP
	MinxRegx PC;			// Registers PC, V
	MinxRegx N;			// for [N+#nn], I is written here too
	uint8_t U1;			// V Shadow 1
	uint8_t U2;			// V Shadow 2
	uint8_t F;			// Flags
	uint8_t E;			// Exception
	uint8_t IR;			// Last Instruction Register (for open-bus)
	uint8_t Shift_U;		// Shift U, set to 2 when: U modify, branch, return
	uint8_t Status;			// CPU Status (0 = Normal, 1 = Halt, 2 = Stoped, 3 = IRQ)
	uint8_t IRQ_Vector;		// IRQ Vector when Status is IRQ
	uint8_t Reserved[28];		// Reserved bytes
} TMinxCPU;

// CPU registers
extern TMinxCPU MinxCPU;

// Callbacks (Must be coded by the user)
uint8_t MinxCPU_OnRead(int cpu, uint32_t addr);
void MinxCPU_OnWrite(int cpu, uint32_t addr, uint8_t data);
void MinxCPU_OnException(int type, uint32_t opc);
void MinxCPU_OnSleep(int type);
void MinxCPU_OnIRQHandle(uint8_t flag, uint8_t shift_u);
void MinxCPU_OnIRQAct(uint8_t intr);

// Functions
int MinxCPU_Create(void);		// Create MinxCPU
void MinxCPU_Destroy(void);		// Destroy MinxCPU
void MinxCPU_Reset(int hardreset);	// Reset CPU
int MinxCPU_LoadState(FILE *fi, uint32_t bsize); // Load State
int MinxCPU_SaveState(FILE *fi);	// Save State
int MinxCPU_Exec(void);			// Execute 1 CPU instruction
int MinxCPU_CallIRQ(uint8_t IRQ);	// Call an IRQ

// Helpers
static inline uint16_t ReadMem16(uint32_t addr)
{
	return MinxCPU_OnRead(1, addr) + (MinxCPU_OnRead(1, addr+1) << 8);
}

static inline void WriteMem16(uint32_t addr, uint16_t data)
{
	MinxCPU_OnWrite(1, addr, (uint8_t)data);
	MinxCPU_OnWrite(1, addr+1, data >> 8);
}

static inline uint8_t Fetch8(void)
{
	if (MinxCPU.PC.W.L & 0x8000) {
		// Banked area
		MinxCPU.IR = MinxCPU_OnRead(1, (MinxCPU.PC.W.L++ & 0x7FFF) | (MinxCPU.PC.B.I << 15));
	} else {
		// Unbanked area
		MinxCPU.IR = MinxCPU_OnRead(1, MinxCPU.PC.W.L++);
	}
	return MinxCPU.IR;
}

static inline uint16_t Fetch16(void)
{
	uint8_t LB = Fetch8();
	return (Fetch8() << 8) | LB;
}

static inline void Set_U(uint8_t val)
{
	if (val != MinxCPU.U2) MinxCPU.Shift_U = 2;
	MinxCPU.U1 = val;
	MinxCPU.U2 = MinxCPU.U1;
	MinxCPU_OnIRQHandle(MinxCPU.F, MinxCPU.Shift_U);
}

// Instruction exec. prototypes

int MinxCPU_ExecCE(void);
int MinxCPU_ExecCF(void);
int MinxCPU_ExecSPCE(void);
int MinxCPU_ExecSPCF(void);

// Instructions Macros

static inline uint8_t ADD8(uint8_t A, uint8_t B)
{
	register uint8_t RES;
	MinxCPU.F &= MINX_FLAG_SAVE_NUL;
	switch (MinxCPU.F & 0x30) {
	case 0x00: // Normal
		RES = A + B;
		MinxCPU.F |=
			((RES == 0) ? MINX_FLAG_ZERO : 0) | // Zero
			((RES < A) ? MINX_FLAG_CARRY : 0) | // Carry
			(((A ^ RES) & (A ^ B ^ 0x80) & 0x80) >> MINX_FLAG_OVER_S8) | // Overflow
			((RES & 0x80) >> MINX_FLAG_SIGN_S8); // Sign
		return RES & 0xFF;
	case 0x10: // BCD
		if ((uint8_t)((A & 15) + (B & 15)) >= 10) {
			RES = A + B + 6;
		} else {
			RES = A + B;
		}
		if (RES >= 0xA0) RES += 0x60;
		MinxCPU.F |=
			((RES == 0) ? MINX_FLAG_ZERO : 0) | // Zero
			((RES < A) ? MINX_FLAG_CARRY : 0); // Carry
		return RES & 0xFF;
	case 0x20: // Nibble
		RES = (A & 15) + (B & 15);
		MinxCPU.F |=
			(((RES & 15) == 0) ? MINX_FLAG_ZERO : 0) | // Zero
			((RES >= 16) ? MINX_FLAG_CARRY : 0) | // Carry
			(((A ^ RES) & (A ^ B ^ 0x08) & 0x08) >> MINX_FLAG_OVER_S4) | // Overflow
			((RES & 0x08) >> MINX_FLAG_SIGN_S4); // Sign
		return RES & 0x0F;
	default:   // BCD and Nibble
		if ((uint8_t)((A & 15) + (B & 15)) >= 10) {
			RES = (A & 15) + (B & 15) + 6;
		} else {
			RES = (A & 15) + (B & 15);
		}
		MinxCPU.F |=
			(((RES & 15) == 0) ? MINX_FLAG_ZERO : 0) | // Zero
			((RES >= 16) ? MINX_FLAG_CARRY : 0); // Carry
		return RES & 0x0F;
	}
}

static inline uint16_t ADD16(uint16_t A, uint16_t B)
{
	register uint16_t RES;
	RES = A + B;
	MinxCPU.F &= MINX_FLAG_SAVE_NUL;
	MinxCPU.F |=
		((RES == 0) ? MINX_FLAG_ZERO : 0) | // Zero
		((RES < A) ? MINX_FLAG_CARRY : 0) | // Carry
		(((A ^ RES) & (A ^ B ^ 0x8000) & 0x8000) >> MINX_FLAG_OVER_S16) | // Overflow
		((RES & 0x8000) >> MINX_FLAG_SIGN_S16); // Sign
	return (uint16_t)RES;
}

static inline uint8_t ADC8(uint8_t A, uint8_t B)
{
	register uint8_t RES;
	register uint8_t CARRY = (MinxCPU.F & MINX_FLAG_CARRY) ? 1 : 0;
	MinxCPU.F &= MINX_FLAG_SAVE_NUL;
	switch (MinxCPU.F & 0x30) {
	case 0x00: // Normal
		RES = A + B + CARRY;
		MinxCPU.F |=
			((RES == 0) ? MINX_FLAG_ZERO : 0) | // Zero
			((RES < A) ? MINX_FLAG_CARRY : 0) | // Carry
			(((A ^ RES) & (A ^ B ^ 0x80) & 0x80) >> MINX_FLAG_OVER_S8) | // Overflow
			((RES & 0x80) >> MINX_FLAG_SIGN_S8); // Sign
		return RES & 0xFF;
	case 0x10: // BCD
		if ((uint8_t)((A & 15) + (B & 15) + CARRY) >= 10) {
			RES = A + B + CARRY + 6;
		} else {
			RES = A + B + CARRY;
		}
		if (RES >= 0xA0) RES += 0x60;
		MinxCPU.F |=
			((RES == 0) ? MINX_FLAG_ZERO : 0) | // Zero
			((RES < A) ? MINX_FLAG_CARRY : 0); // Carry
		return RES & 0xFF;
	case 0x20: // Nibble
		RES = (A & 15) + (B & 15) + CARRY;
		MinxCPU.F |=
			(((RES & 15) == 0) ? MINX_FLAG_ZERO : 0) | // Zero
			((RES >= 16) ? MINX_FLAG_CARRY : 0) | // Carry
			(((A ^ RES) & (A ^ B ^ 0x08) & 0x08) >> MINX_FLAG_OVER_S4) | // Overflow
			((RES & 0x08) >> MINX_FLAG_SIGN_S4); // Sign
		return RES & 0x0F;
	default:   // BCD and Nibble
		if ((uint8_t)((A & 15) + (B & 15) + CARRY) >= 10) {
			RES = (A & 15) + (B & 15) + CARRY + 6;
		} else {
			RES = (A & 15) + (B & 15) + CARRY;
		}
		MinxCPU.F |=
			(((RES & 15) == 0) ? MINX_FLAG_ZERO : 0) | // Zero
			((RES >= 16) ? MINX_FLAG_CARRY : 0); // Carry
		return RES & 0x0F;
	}
}

static inline uint16_t ADC16(uint16_t A, uint16_t B)
{
	register uint16_t RES;
	RES = A + B + ((MinxCPU.F & MINX_FLAG_CARRY) ? 1 : 0);
	MinxCPU.F &= MINX_FLAG_SAVE_NUL;
	MinxCPU.F |=
		((RES == 0) ? MINX_FLAG_ZERO : 0) | // Zero
		((RES < A) ? MINX_FLAG_CARRY : 0) | // Carry
		(((A ^ RES) & (A ^ B ^ 0x8000) & 0x8000) >> MINX_FLAG_OVER_S16) | // Overflow
		((RES & 0x8000) >> MINX_FLAG_SIGN_S16); // Sign
	return (uint16_t)RES;
}

static inline uint8_t SUB8(uint8_t A, uint8_t B)
{
	register uint8_t RES;
	MinxCPU.F &= MINX_FLAG_SAVE_NUL;
	switch (MinxCPU.F & 0x30) {
	case 0x00: // Normal
		RES = A - B;
		MinxCPU.F |=
			((RES == 0) ? MINX_FLAG_ZERO : 0) | // Zero
			((A < B) ? MINX_FLAG_CARRY : 0) | // Carry
			(((A ^ RES) & (A ^ B) & 0x80) >> MINX_FLAG_OVER_S8) | // Overflow
			((RES & 0x80) >> MINX_FLAG_SIGN_S8); // Sign
		return RES & 0xFF;
	case 0x10: // BCD
		if ((uint8_t)((A & 15) - (B & 15)) >= 10) {
			RES = A - B - 6;
		} else {
			RES = A - B;
		}
		if (RES >= 0xA0) RES -= 0x60;
		MinxCPU.F |=
			((RES == 0) ? MINX_FLAG_ZERO : 0) | // Zero
			((A < B) ? MINX_FLAG_CARRY : 0); // Carry
		return RES & 0xFF;
	case 0x20: // Nibble
		RES = (A & 15) - (B & 15);
		MinxCPU.F |=
			(((RES & 15) == 0) ? MINX_FLAG_ZERO : 0) | // Zero
			((RES >= 16) ? MINX_FLAG_CARRY : 0) | // Carry
			(((A ^ RES) & (A ^ B) & 0x08) >> MINX_FLAG_OVER_S4) | // Overflow
			((RES & 0x08) >> MINX_FLAG_SIGN_S4); // Sign
		return RES & 0x0F;
	default:   // BCD and Nibble
		if ((uint8_t)((A & 15) - (B & 15)) >= 10) {
			RES = (A & 15) - (B & 15) - 6;
		} else {
			RES = (A & 15) - (B & 15);
		}
		MinxCPU.F |=
			(((RES & 15) == 0) ? MINX_FLAG_ZERO : 0) | // Zero
			((RES >= 16) ? MINX_FLAG_CARRY : 0); // Carry
		return RES & 0x0F;
	}
}

static inline uint16_t SUB16(uint16_t A, uint16_t B)
{
	register uint16_t RES;
	RES = A - B;
	MinxCPU.F &= MINX_FLAG_SAVE_NUL;
	MinxCPU.F |=
		((RES == 0) ? MINX_FLAG_ZERO : 0) | // Zero
		((A < B) ? MINX_FLAG_CARRY : 0) | // Carry
		(((A ^ RES) & (A ^ B) & 0x8000) >> MINX_FLAG_OVER_S16) | // Overflow
		((RES & 0x8000) >> MINX_FLAG_SIGN_S16); // Sign
	return (uint16_t)RES;
}

static inline uint8_t SBC8(uint8_t A, uint8_t B)
{
	register uint8_t RES;
	register uint8_t CARRY = (MinxCPU.F & MINX_FLAG_CARRY) ? 1 : 0;
	MinxCPU.F &= MINX_FLAG_SAVE_NUL;
	switch (MinxCPU.F & 0x30) {
	case 0x00: // Normal
		RES = A - B - CARRY;
		MinxCPU.F |=
			((RES == 0) ? MINX_FLAG_ZERO : 0) | // Zero
			((A < B) ? MINX_FLAG_CARRY : 0) | // Carry
			(((A ^ RES) & (A ^ B) & 0x80) >> MINX_FLAG_OVER_S8) | // Overflow
			((RES & 0x80) >> MINX_FLAG_SIGN_S8); // Sign
		return RES & 0xFF;
	case 0x10: // BCD
		if ((uint8_t)((A & 15) - (B & 15) - CARRY) >= 10) {
			RES = A - B - CARRY - 6;
		} else {
			RES = A - B - CARRY;
		}
		if (RES >= 0xA0) RES -= 0x60;
		MinxCPU.F |=
			((RES == 0) ? MINX_FLAG_ZERO : 0) | // Zero
			((A < B) ? MINX_FLAG_CARRY : 0); // Carry
		return RES & 0xFF;
	case 0x20: // Nibble
		RES = (A & 15) - (B & 15) - CARRY;
		MinxCPU.F |=
			(((RES & 15) == 0) ? MINX_FLAG_ZERO : 0) | // Zero
			((RES >= 16) ? MINX_FLAG_CARRY : 0) | // Carry
			(((A ^ RES) & (A ^ B) & 0x08) >> MINX_FLAG_OVER_S4) | // Overflow
			((RES & 0x08) >> MINX_FLAG_SIGN_S4); // Sign
		return RES & 0x0F;
	default:   // BCD and Nibble
		if ((uint8_t)((A & 15) - (B & 15) - CARRY) >= 10) {
			RES = (A & 15) - (B & 15) - CARRY - 6;
		} else {
			RES = (A & 15) - (B & 15) - CARRY;
		}
		MinxCPU.F |=
			(((RES & 15) == 0) ? MINX_FLAG_ZERO : 0) | // Zero
			((RES >= 16) ? MINX_FLAG_CARRY : 0); // Carry
		return RES & 0x0F;
	}
}

static inline uint16_t SBC16(uint16_t A, uint16_t B)
{
	register uint16_t RES;
	RES = A - B - ((MinxCPU.F & MINX_FLAG_CARRY) ? 1 : 0);
	MinxCPU.F &= MINX_FLAG_SAVE_NUL;
	MinxCPU.F |=
		((RES == 0) ? MINX_FLAG_ZERO : 0) | // Zero
		((A < B) ? MINX_FLAG_CARRY : 0) | // Carry
		(((A ^ RES) & (A ^ B) & 0x8000) >> MINX_FLAG_OVER_S16) | // Overflow
		((RES & 0x8000) >> MINX_FLAG_SIGN_S16); // Sign
	return (uint16_t)RES;
}

static inline uint8_t AND8(uint8_t A, uint8_t B)
{
	A &= B;
	MinxCPU.F &= MINX_FLAG_SAVE_CO;
	MinxCPU.F |= 
		((A == 0) ? MINX_FLAG_ZERO : 0) |
		((A & 0x80) >> MINX_FLAG_SIGN_S8);
	return A;
}

static inline uint8_t OR8(uint8_t A, uint8_t B)
{
	A |= B;
	MinxCPU.F &= MINX_FLAG_SAVE_CO;
	MinxCPU.F |= 
		((A == 0) ? MINX_FLAG_ZERO : 0) |
		((A & 0x80) >> MINX_FLAG_SIGN_S8);
	return A;
}

static inline uint8_t XOR8(uint8_t A, uint8_t B)
{
	A ^= B;
	MinxCPU.F &= MINX_FLAG_SAVE_CO;
	MinxCPU.F |= 
		((A == 0) ? MINX_FLAG_ZERO : 0) |
		((A & 0x80) >> MINX_FLAG_SIGN_S8);
	return A;
}

static inline uint8_t INC8(uint8_t A)
{
	A++;
	MinxCPU.F &= MINX_FLAG_SAVE_COS;
	if (A == 0) MinxCPU.F |= MINX_FLAG_ZERO;
	return A;
}

static inline uint16_t INC16(uint16_t A)
{
	A++;
	MinxCPU.F &= MINX_FLAG_SAVE_COS;
	if (A == 0) MinxCPU.F |= MINX_FLAG_ZERO;
	return A;
}

static inline uint8_t DEC8(uint8_t A)
{
	A--;
	MinxCPU.F &= MINX_FLAG_SAVE_COS;
	if (A == 0) MinxCPU.F |= MINX_FLAG_ZERO;
	return A;
}

static inline uint16_t DEC16(uint16_t A)
{
	A--;
	MinxCPU.F &= MINX_FLAG_SAVE_COS;
	if (A == 0) MinxCPU.F |= MINX_FLAG_ZERO;
	return A;
}

static inline void PUSH(uint8_t A)
{
	MinxCPU.SP.W.L--;
	MinxCPU_OnWrite(1, MinxCPU.SP.D, A);
}

static inline uint8_t POP(void)
{
	register uint8_t data;
	data = MinxCPU_OnRead(1, MinxCPU.SP.D);
	MinxCPU.SP.W.L++;
	return data;
}

static inline void CALLS(uint16_t OFFSET)
{
	PUSH(MinxCPU.PC.B.I);
	PUSH(MinxCPU.PC.B.H);
	PUSH(MinxCPU.PC.B.L);
	MinxCPU.PC.B.I = MinxCPU.U1;
	MinxCPU.U2 = MinxCPU.U1;
	MinxCPU.PC.W.L = MinxCPU.PC.W.L + OFFSET - 1;
}

static inline void JMPS(uint16_t OFFSET)
{
	MinxCPU.PC.B.I = MinxCPU.U1;
	MinxCPU.U2 = MinxCPU.U1;
	MinxCPU.PC.W.L = MinxCPU.PC.W.L + OFFSET - 1;
}

static inline void CALLU(uint16_t ADDR)
{
	PUSH(MinxCPU.PC.B.I);
	PUSH(MinxCPU.PC.B.H);
	PUSH(MinxCPU.PC.B.L);
	MinxCPU.PC.B.I = MinxCPU.U1;
	MinxCPU.U2 = MinxCPU.U1;
	MinxCPU.PC.W.L = ADDR;
}

static inline void JMPU(uint16_t ADDR)
{
	MinxCPU.PC.B.I = MinxCPU.U1;
	MinxCPU.U2 = MinxCPU.U1;
	MinxCPU.PC.W.L = ADDR;
}

static inline void JDBNZ(uint16_t OFFSET)
{
	MinxCPU.BA.B.H = DEC8(MinxCPU.BA.B.H);
	if (MinxCPU.BA.B.H != 0) {
		JMPS(OFFSET);
	}
}

static inline uint8_t SWAP(uint8_t A)
{
	return (A << 4) | (A >> 4);
}

static inline void RET(void)
{
	MinxCPU.PC.B.L = POP();
	MinxCPU.PC.B.H = POP();
	MinxCPU.PC.B.I = POP();
	Set_U(MinxCPU.PC.B.I);
}

static inline void RETI(void)
{
	MinxCPU.F = POP();
	MinxCPU.PC.B.L = POP();
	MinxCPU.PC.B.H = POP();
	MinxCPU.PC.B.I = POP();
	Set_U(MinxCPU.PC.B.I);
	MinxCPU_OnIRQHandle(MinxCPU.F, MinxCPU.Shift_U);
}

static inline void CALLX(uint16_t ADDR)
{
	PUSH(MinxCPU.PC.B.I);
	PUSH(MinxCPU.PC.B.H);
	PUSH(MinxCPU.PC.B.L);
	MinxCPU.PC.B.I = MinxCPU.U1;
	MinxCPU.U2 = MinxCPU.U1;
	MinxCPU.PC.W.L = ReadMem16((MinxCPU.HL.B.I << 16) + ADDR);
}

static inline void CALLI(uint16_t ADDR)
{
	PUSH(MinxCPU.PC.B.I);
	PUSH(MinxCPU.PC.B.H);
	PUSH(MinxCPU.PC.B.L);
	PUSH(MinxCPU.F);
	MinxCPU.F |= 0xC0;
	MinxCPU.PC.B.I = MinxCPU.U1;
	MinxCPU.U2 = MinxCPU.U1;
	MinxCPU.PC.W.L = ReadMem16(ADDR);
	MinxCPU_OnIRQHandle(MinxCPU.F, MinxCPU.Shift_U);
}

static inline void JMPI(uint16_t ADDR)
{
	PUSH(MinxCPU.F);
	MinxCPU.F |= 0xC0;
	MinxCPU.PC.B.I = MinxCPU.U1;
	MinxCPU.U2 = MinxCPU.U1;
	MinxCPU.PC.W.L = ReadMem16(ADDR);
	MinxCPU_OnIRQHandle(MinxCPU.F, MinxCPU.Shift_U);
}

static inline uint8_t SAL(uint8_t A)
{
	MinxCPU.F &= MINX_FLAG_SAVE_NUL;
	if (A & 0x80) MinxCPU.F |= MINX_FLAG_CARRY;
	if ((!(A & 0x40)) != (!(A & 0x80))) MinxCPU.F |= MINX_FLAG_OVERFLOW;
	A = A << 1;
	MinxCPU.F |= 
		((A == 0) ? MINX_FLAG_ZERO : 0) |
		((A & 0x80) >> MINX_FLAG_SIGN_S8);
	return A;
}

static inline uint8_t SHL(uint8_t A)
{
	MinxCPU.F &= MINX_FLAG_SAVE_O;
	if (A & 0x80) MinxCPU.F |= MINX_FLAG_CARRY;
	A = A << 1;
	MinxCPU.F |= 
		((A == 0) ? MINX_FLAG_ZERO : 0) |
		((A & 0x80) >> MINX_FLAG_SIGN_S8);
	return A;
}

static inline uint8_t SAR(uint8_t A)
{
	MinxCPU.F &= MINX_FLAG_SAVE_NUL;
	if (A & 0x01) MinxCPU.F |= MINX_FLAG_CARRY;
	A = (A & 0x80) | (A >> 1);
	MinxCPU.F |= 
		((A == 0) ? MINX_FLAG_ZERO : 0) |
		((A & 0x80) >> MINX_FLAG_SIGN_S8);
	return A;
}

static inline uint8_t SHR(uint8_t A)
{
	MinxCPU.F &= MINX_FLAG_SAVE_O;
	if (A & 0x01) MinxCPU.F |= MINX_FLAG_CARRY;
	A = A >> 1;
	MinxCPU.F |= 
		((A == 0) ? MINX_FLAG_ZERO : 0) |
		((A & 0x80) >> MINX_FLAG_SIGN_S8);
	return A;
}

static inline uint8_t ROLC(uint8_t A)
{
	register uint8_t CARRY = (MinxCPU.F & MINX_FLAG_CARRY) ? 1 : 0;
	MinxCPU.F &= MINX_FLAG_SAVE_O;
	if (A & 0x80) MinxCPU.F |= MINX_FLAG_CARRY;
	A = (A << 1) | CARRY;
	MinxCPU.F |= 
		((A == 0) ? MINX_FLAG_ZERO : 0) |
		((A & 0x80) >> MINX_FLAG_SIGN_S8);
	return A;
}

static inline uint8_t ROL(uint8_t A)
{
	MinxCPU.F &= MINX_FLAG_SAVE_O;
	if (A & 0x80) MinxCPU.F |= MINX_FLAG_CARRY;
	A = (A << 1) | (A >> 7);
	MinxCPU.F |= 
		((A == 0) ? MINX_FLAG_ZERO : 0) |
		((A & 0x80) >> MINX_FLAG_SIGN_S8);
	return A;
}

static inline uint8_t RORC(uint8_t A)
{
	register uint8_t CARRY = (MinxCPU.F & MINX_FLAG_CARRY) ? 0x80 : 0x00;
	MinxCPU.F &= MINX_FLAG_SAVE_O;
	if (A & 0x01) MinxCPU.F |= MINX_FLAG_CARRY;
	A = (A >> 1) | CARRY;
	MinxCPU.F |= 
		((A == 0) ? MINX_FLAG_ZERO : 0) |
		((A & 0x80) >> MINX_FLAG_SIGN_S8);
	return A;
}

static inline uint8_t ROR(uint8_t A)
{
	MinxCPU.F &= MINX_FLAG_SAVE_O;
	if (A & 0x01) MinxCPU.F |= MINX_FLAG_CARRY;
	A = (A >> 1) | (A << 7);
	MinxCPU.F |= 
		((A == 0) ? MINX_FLAG_ZERO : 0) |
		((A & 0x80) >> MINX_FLAG_SIGN_S8);
	return A;
}

static inline uint8_t NOT(uint8_t A)
{
	MinxCPU.F &= MINX_FLAG_SAVE_CO;
	A = A ^ 0xFF;
	MinxCPU.F |= 
		((A == 0) ? MINX_FLAG_ZERO : 0) |
		((A & 0x80) >> MINX_FLAG_SIGN_S8);
	return A;	
}

static inline uint8_t NEG(uint8_t A)
{
	MinxCPU.F &= MINX_FLAG_SAVE_NUL;
	A = -A;
	MinxCPU.F |= 
		((A == 0) ? MINX_FLAG_ZERO : MINX_FLAG_CARRY) |
		((A == 0x80) ? MINX_FLAG_OVERFLOW : 0) |
		((A & 0x80) >> MINX_FLAG_SIGN_S8);
	return A;
}

static inline void HALT(void)
{
	MinxCPU.Status = MINX_STATUS_HALT;
	MinxCPU_OnSleep(MINX_SLEEP_HALT);
}

static inline void STOP(void)
{
	MinxCPU.Status = MINX_STATUS_STOP;
	MinxCPU_OnSleep(MINX_SLEEP_STOP);
}

static inline void MUL(void)
{
	MinxCPU.F &= MINX_FLAG_SAVE_NUL;
	MinxCPU.HL.W.L = (uint16_t)MinxCPU.HL.B.L * (uint16_t)MinxCPU.BA.B.L;
	MinxCPU.F |= 
		((MinxCPU.HL.W.L == 0) ? MINX_FLAG_ZERO : 0) |
		((MinxCPU.HL.W.L & 0x8000) ? MINX_FLAG_SIGN : 0);
}

static inline void DIV(void)
{
	uint16_t RES;
	MinxCPU.F &= MINX_FLAG_SAVE_NUL;
	if (MinxCPU.BA.B.L == 0) {
		MinxCPU_OnException(EXCEPTION_DIVISION_BY_ZERO, 0);
		return;
	}
	RES = MinxCPU.HL.W.L / MinxCPU.BA.B.L;
	if (RES < 256) {
		MinxCPU.HL.B.H = MinxCPU.HL.W.L % MinxCPU.BA.B.L;
		MinxCPU.HL.B.L = (uint8_t)RES;
		MinxCPU.F |= 
			((MinxCPU.HL.B.L == 0) ? MINX_FLAG_ZERO : 0) |
			((MinxCPU.HL.B.L & 0x80) ? MINX_FLAG_SIGN : 0);
	} else MinxCPU.F |= MINX_FLAG_OVERFLOW | MINX_FLAG_SIGN;
}

#endif
