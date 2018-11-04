/*
 *	E_Parallel.h
 *

ADD8 Adds each byte of the second operand register to the corresponding byte of the first operand
		register to form the corresponding byte of the result.

ADD16 Adds the top halfwords of two registers to form the top halfword of the result.
		Adds the bottom halfwords of the same two registers to form the bottom halfword of the result.

SUB8 Subtracts each byte of the second operand register from the corresponding byte of the first
		operand register to form the corresponding byte of the result.

SUB16 Subtracts the top halfword of the first operand register from the top halfword of the second operand register to form the top halfword of the result.
		Subtracts the bottom halfword of the second operand registers from the bottom halfword of
		the first operand register to form the bottom halfword of the result.

ADDSUBX Does the following:
	1. Exchanges halfwords of the second operand register.
	2. Adds top halfwords and subtracts bottom halfwords.

SUBADDX Does the following:
	1. Exchanges halfwords of the second operand register.
	2. Subtracts top halfwords and adds bottom halfwords.


Each of the six instructions is available in the following variations, indicated by the prefixes shown:

	S	Signed arithmetic modulo 28 or 216. Sets the CPSR GE bits (see The GE[3:0] bits on page A2-13).
	Q	Signed saturating arithmetic.
	SH	Signed arithmetic, halving the results to avoid overflow.
	U	Unsigned arithmetic modulo 28 or 216. Sets the CPSR GE bits (see The GE[3:0] bits on page A2-13).
	UQ	Unsigned saturating arithmetic.
	UH	Unsigned arithmetic, halving the results to avoid overflow.


Status:
	These routines require implementation if needed.

 */
#pragma once


namespace ARM
{	
	
#if defined(_DEVEL) && 0

	//	S
	//
	EAPI SADD8   (eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;
	EAPI SADD16  (eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;
	EAPI SSUB8   (eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;
	EAPI SSUB16  (eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;
	EAPI SADDSUBX(eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;
	EAPI SSUBADDX(eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;

	
	//	Q
	//
	EAPI QADD8   (eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;
	EAPI QADD16  (eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;
	EAPI QSUB8   (eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;
	EAPI QSUB16  (eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;
	EAPI QADDSUBX(eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;
	EAPI QSUBADDX(eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;


	//	SH
	//
	EAPI SHADD8   (eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;
	EAPI SHADD16  (eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;
	EAPI SHSUB8   (eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;
	EAPI SHSUB16  (eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;
	EAPI SHADDSUBX(eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;
	EAPI SHSUBADDX(eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;


	//	U
	//
	EAPI UADD8   (eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;
	EAPI UADD16  (eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;
	EAPI USUB8   (eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;
	EAPI USUB16  (eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;
	EAPI UADDSUBX(eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;
	EAPI USUBADDX(eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;


	//	UQ
	//
	EAPI UQADD8   (eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;
	EAPI UQADD16  (eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;
	EAPI UQSUB8   (eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;
	EAPI UQSUB16  (eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;
	EAPI UQADDSUBX(eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;
	EAPI UQSUBADDX(eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;


	//	UH
	//
	EAPI UHADD8   (eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;
	EAPI UHADD16  (eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;
	EAPI UHSUB8   (eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;
	EAPI UHSUB16  (eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;
	EAPI UHADDSUBX(eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;
	EAPI UHSUBADDX(eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL) ;

#endif


	
};