//---------------------------------------------------------------------------
// NEOPOP : Emulator as in Dreamland
//
// Copyright (c) 2001-2002 by neopop_uk
//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
//	This program is free software; you can redistribute it and/or modify
//	it under the terms of the GNU General Public License as published by
//	the Free Software Foundation; either version 2 of the License, or
//	(at your option) any later version. See also the license.txt file for
//	additional informations.
//---------------------------------------------------------------------------

/*
//---------------------------------------------------------------------------
//=========================================================================

	TLCS900h_interpret.h

//=========================================================================
//---------------------------------------------------------------------------

  History of changes:
  ===================

20 JUL 2002 - neopop_uk
=======================================
- Cleaned and tidied up for the source release

21 JUL 2002 - neopop_uk
=======================================
- Added the 'instruction_error' function declaration here.

28 JUL 2002 - neopop_uk
=======================================
- Removed CYCLE_WARNING as it is now obsolete.
- Added generic DIV prototypes.

//---------------------------------------------------------------------------
*/

#ifndef __TLCS900H_INTERPRET__
#define __TLCS900H_INTERPRET__
namespace TLCS900H
{

//=============================================================================

//Interprets a single instruction from 'pc', 
//pc is incremented to the start of the next instruction.
//Returns the number of cycles taken for this instruction
int32 TLCS900h_interpret(void);

//=============================================================================

MDFN_HIDE extern uint32 mem;	
MDFN_HIDE extern int size;
MDFN_HIDE extern uint8 first;			//First byte
MDFN_HIDE extern uint8 second;			//Second byte
MDFN_HIDE extern uint8 R;				//(second & 7)
MDFN_HIDE extern uint8 rCode;
MDFN_HIDE extern int32 cycles;
MDFN_HIDE extern bool brCode;

//=============================================================================

MDFN_HIDE extern void (*instruction_error)(const char* vaMessage,...);

//=============================================================================

#define FETCH8		loadB(pc++)

uint16 fetch16(void);
uint32 fetch24(void);
uint32 fetch32(void);

//=============================================================================

MDFN_FASTCALL void parityB(uint8 value);
MDFN_FASTCALL void parityW(uint16 value);

//=============================================================================

MDFN_FASTCALL void push8(uint8 data);
MDFN_FASTCALL void push16(uint16 data);
MDFN_FASTCALL void push32(uint32 data);

uint8 pop8(void);
uint16 pop16(void);
uint32 pop32(void);

//=============================================================================

//DIV ===============
MDFN_FASTCALL uint16 generic_DIV_B(uint16 val, uint8 div);
MDFN_FASTCALL uint32 generic_DIV_W(uint32 val, uint16 div);

//DIVS ===============
MDFN_FASTCALL uint16 generic_DIVS_B(int16 val, int8 div);
MDFN_FASTCALL uint32 generic_DIVS_W(int32 val, int16 div);

//ADD ===============
MDFN_FASTCALL uint8	generic_ADD_B(uint8 dst, uint8 src);
MDFN_FASTCALL uint16 generic_ADD_W(uint16 dst, uint16 src);
MDFN_FASTCALL uint32 generic_ADD_L(uint32 dst, uint32 src);

//ADC ===============
MDFN_FASTCALL uint8	generic_ADC_B(uint8 dst, uint8 src);
MDFN_FASTCALL uint16 generic_ADC_W(uint16 dst, uint16 src);
MDFN_FASTCALL uint32 generic_ADC_L(uint32 dst, uint32 src);

//SUB ===============
MDFN_FASTCALL uint8	generic_SUB_B(uint8 dst, uint8 src);
MDFN_FASTCALL uint16 generic_SUB_W(uint16 dst, uint16 src);
MDFN_FASTCALL uint32 generic_SUB_L(uint32 dst, uint32 src);

//SBC ===============
MDFN_FASTCALL uint8	generic_SBC_B(uint8 dst, uint8 src);
MDFN_FASTCALL uint16 generic_SBC_W(uint16 dst, uint16 src);
MDFN_FASTCALL uint32 generic_SBC_L(uint32 dst, uint32 src);

//=============================================================================

//Confirms a condition code check
MDFN_FASTCALL bool conditionCode(int cc);

//=============================================================================

//Translate an rr or RR value for MUL/MULS/DIV/DIVS
uint8 get_rr_Target(void);
uint8 get_RR_Target(void);

}

//=============================================================================
#endif
