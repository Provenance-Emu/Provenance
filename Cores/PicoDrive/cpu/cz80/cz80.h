/******************************************************************************
 *
 * CZ80 (Z80 CPU emulator) version 0.9
 * Compiled with Dev-C++
 * Copyright 2004-2005 Stéphane Dallongeville
 *
 * (Modified by NJ)
 *
 *****************************************************************************/

#ifndef CZ80_H
#define CZ80_H

#ifdef __cplusplus
extern "C" {
#endif

/******************************/
/* Compiler dependant defines */
/******************************/

#ifndef UINT8
#define UINT8	unsigned char
#endif

#ifndef INT8
#define INT8	signed char
#endif

#ifndef UINT16
#define UINT16	unsigned short
#endif

#ifndef INT16
#define INT16	signed short
#endif

#ifndef UINT32
#define UINT32	unsigned int
#endif

#ifndef INT32
#define INT32	signed int
#endif

#ifndef FPTR
#define FPTR	unsigned long
#endif

/*************************************/
/* Z80 core Structures & definitions */
/*************************************/

#define CZ80_FETCH_BITS			4   // [4-12]   default = 8

#define CZ80_FETCH_SFT			(16 - CZ80_FETCH_BITS)
#define CZ80_FETCH_BANK			(1 << CZ80_FETCH_BITS)

#define PICODRIVE_HACKS		1
#define CZ80_LITTLE_ENDIAN		1
#define CZ80_USE_JUMPTABLE		1
#define CZ80_BIG_FLAGS_ARRAY	1
//#ifdef BUILD_CPS1PSP
//#define CZ80_ENCRYPTED_ROM		1
//#else
#define CZ80_ENCRYPTED_ROM		0
//#endif
#define CZ80_EMULATE_R_EXACTLY	1

#define zR8(A)		(*CPU->pzR8[A])
#define zR16(A)		(CPU->pzR16[A]->W)

#define pzAF		&(CPU->AF)
#define zAF			CPU->AF.W
#define zlAF		CPU->AF.B.L
#define zhAF		CPU->AF.B.H
#define zA			zhAF
#define zF			zlAF

#define pzBC		&(CPU->BC)
#define zBC			CPU->BC.W
#define zlBC		CPU->BC.B.L
#define zhBC		CPU->BC.B.H
#define zB			zhBC
#define zC			zlBC

#define pzDE		&(CPU->DE)
#define zDE			CPU->DE.W
#define zlDE		CPU->DE.B.L
#define zhDE		CPU->DE.B.H
#define zD			zhDE
#define zE			zlDE

#define pzHL		&(CPU->HL)
#define zHL			CPU->HL.W
#define zlHL		CPU->HL.B.L
#define zhHL		CPU->HL.B.H
#define zH			zhHL
#define zL			zlHL

#define zAF2		CPU->AF2.W
#define zlAF2		CPU->AF2.B.L
#define zhAF2		CPU->AF2.B.H
#define zA2			zhAF2
#define zF2			zlAF2

#define zBC2		CPU->BC2.W
#define zDE2		CPU->DE2.W
#define zHL2		CPU->HL2.W

#define pzIX		&(CPU->IX)
#define zIX			CPU->IX.W
#define zlIX		CPU->IX.B.L
#define zhIX		CPU->IX.B.H

#define pzIY		&(CPU->IY)
#define zIY			CPU->IY.W
#define zlIY		CPU->IY.B.L
#define zhIY		CPU->IY.B.H

#define pzSP		&(CPU->SP)
#define zSP			CPU->SP.W
#define zlSP		CPU->SP.B.L
#define zhSP		CPU->SP.B.H

#define zRealPC		(PC - CPU->BasePC)
#define zPC			PC

#define zI			CPU->I
#define zIM			CPU->IM

#define zwR			CPU->R.W
#define zR1			CPU->R.B.L
#define zR2			CPU->R.B.H
#define zR			zR1

#define zIFF		CPU->IFF.W
#define zIFF1		CPU->IFF.B.L
#define zIFF2		CPU->IFF.B.H

#define CZ80_SF_SFT	 7
#define CZ80_ZF_SFT	 6
#define CZ80_YF_SFT	 5
#define CZ80_HF_SFT	 4
#define CZ80_XF_SFT	 3
#define CZ80_PF_SFT	 2
#define CZ80_VF_SFT	 2
#define CZ80_NF_SFT	 1
#define CZ80_CF_SFT	 0

#define CZ80_SF		(1 << CZ80_SF_SFT)
#define CZ80_ZF		(1 << CZ80_ZF_SFT)
#define CZ80_YF		(1 << CZ80_YF_SFT)
#define CZ80_HF		(1 << CZ80_HF_SFT)
#define CZ80_XF		(1 << CZ80_XF_SFT)
#define CZ80_PF		(1 << CZ80_PF_SFT)
#define CZ80_VF		(1 << CZ80_VF_SFT)
#define CZ80_NF		(1 << CZ80_NF_SFT)
#define CZ80_CF		(1 << CZ80_CF_SFT)

#define CZ80_IFF_SFT	CZ80_PF_SFT
#define CZ80_IFF		CZ80_PF

#ifndef IRQ_LINE_STATE
#define IRQ_LINE_STATE
#define CLEAR_LINE		0		/* clear (a fired, held or pulsed) line */
#define ASSERT_LINE		1		/* assert an interrupt immediately */
#define HOLD_LINE		2		/* hold interrupt line until acknowledged */
#define PULSE_LINE		3		/* pulse interrupt line for one instruction */
#define IRQ_LINE_NMI	127		/* IRQ line for NMIs */
#endif

enum
{
	CZ80_PC = 1,
	CZ80_SP,
	CZ80_AF,
	CZ80_BC,
	CZ80_DE,
	CZ80_HL,
	CZ80_IX,
	CZ80_IY,
	CZ80_AF2,
	CZ80_BC2,
	CZ80_DE2,
	CZ80_HL2,
	CZ80_R,
	CZ80_I,
	CZ80_IM,
	CZ80_IFF1,
	CZ80_IFF2,
	CZ80_HALT,
	CZ80_IRQ
};

typedef union
{
	struct
	{
#if CZ80_LITTLE_ENDIAN
		UINT8 L;
		UINT8 H;
#else
		UINT8 H;
		UINT8 L;
#endif
	} B;
	UINT16 W;
} union16;

typedef struct cz80_t
{
	union
	{
		UINT8 r8[8];
		union16 r16[4];
		struct
		{
			union16 BC;
			union16 DE;
			union16 HL;
			union16 AF;
		};
	};

	union16 IX;
	union16 IY;
	union16 SP;
	UINT32 unusedPC;	/* left for binary compat */

	union16 BC2;
	union16 DE2;
	union16 HL2;
	union16 AF2;

	union16 R;
	union16 IFF;

	UINT8 I;
	UINT8 IM;
	UINT8 HaltState;
	UINT8 dummy;

	INT32 IRQLine;
	INT32 IRQState;
	INT32 ICount;
	INT32 ExtraCycles;

	FPTR BasePC;
	FPTR PC;
	FPTR Fetch[CZ80_FETCH_BANK];
#if CZ80_ENCRYPTED_ROM
	FPTR OPBase;
	FPTR OPFetch[CZ80_FETCH_BANK];
#endif

	UINT8 *pzR8[8];
	union16 *pzR16[4];

	UINT8   (*Read_Byte)(UINT32 address);
	void (*Write_Byte)(UINT32 address, UINT8 data);

	UINT8   (*IN_Port)(UINT16 port);
	void (*OUT_Port)(UINT16 port, UINT8 value);

	INT32  (*Interrupt_Callback)(INT32 irqline);

} cz80_struc;


/*************************/
/* Publics Z80 variables */
/*************************/

extern cz80_struc CZ80;

/*************************/
/* Publics Z80 functions */
/*************************/

void Cz80_Init(cz80_struc *CPU);

void Cz80_Reset(cz80_struc *CPU);

INT32  Cz80_Exec(cz80_struc *CPU, INT32 cycles);

void Cz80_Set_IRQ(cz80_struc *CPU, INT32 line, INT32 state);

UINT32  Cz80_Get_Reg(cz80_struc *CPU, INT32 regnum);
void Cz80_Set_Reg(cz80_struc *CPU, INT32 regnum, UINT32 value);

void Cz80_Set_Fetch(cz80_struc *CPU, UINT32 low_adr, UINT32 high_adr, FPTR fetch_adr);
#if CZ80_ENCRYPTED_ROM
void Cz80_Set_Encrypt_Range(cz80_struc *CPU, UINT32 low_adr, UINT32 high_adr, UINT32 decrypted_rom);
#endif

void Cz80_Set_ReadB(cz80_struc *CPU, UINT8 (*Func)(UINT32 address));
void Cz80_Set_WriteB(cz80_struc *CPU, void (*Func)(UINT32 address, UINT8 data));

void Cz80_Set_INPort(cz80_struc *CPU, UINT8 (*Func)(UINT16 port));
void Cz80_Set_OUTPort(cz80_struc *CPU, void (*Func)(UINT16 port, UINT8 value));

void Cz80_Set_IRQ_Callback(cz80_struc *CPU, INT32 (*Func)(INT32 irqline));

#ifdef __cplusplus
};
#endif

#endif	/* CZ80_H */
