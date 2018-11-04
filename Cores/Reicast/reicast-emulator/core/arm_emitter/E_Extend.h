/*
 *	E_Extend.h
 *

There are six basic instructions:
	XTAB16	Extend bits[23:16] and bits[7:0] of one register to 16 bits, and add corresponding halfwordsto the values in another register.
	XTAB	Extend bits[ 7: 0] of one register to 32 bits, and add to the value in another register.
	XTAH	Extend bits[15: 0] of one register to 32 bits, and add to the value in another register.
	XTB16	Extend bits[23:16] and bits[7:0] to 16 bits each.
	XTB		Extend bits[ 7: 0] to 32 bits.
	XTH		Extend bits[15: 0] to 32 bits.

Each of the six instructions is available in the following variations, indicated by the prefixes shown:
	S	Sign extension, with or without addition modulo 216 or 232.
	U	Zero (unsigned) extension, with or without addition modulo 216 or 232.

 */
#pragma once



namespace ARM
{

	EAPI SXTAB16(eReg Rd, eReg Rn, eReg Rm, ConditionCode CC=AL)
	{
		DECL_Id(0x06800070);

		SET_CC;
		I |= (Rn&15)<<16;
		I |= (Rd&15)<<12;
		I |= (Rm&15);
		EMIT_I;
	}

	EAPI SXTAB(eReg Rd, eReg Rn, eReg Rm, ConditionCode CC=AL)
	{
		DECL_Id(0x06A00070);

		SET_CC;
		I |= (Rn&15)<<16;
		I |= (Rd&15)<<12;
		I |= (Rm&15);
		EMIT_I;
	}

	EAPI SXTAH(eReg Rd, eReg Rn, eReg Rm, ConditionCode CC=AL)
	{
		DECL_Id(0x06B00070);

		SET_CC;
		I |= (Rn&15)<<16;
		I |= (Rd&15)<<12;
		I |= (Rm&15);
		EMIT_I;
	}

	EAPI SXTB16(eReg Rd, eReg Rm, ConditionCode CC=AL)
	{
		DECL_Id(0x068F0070);

		SET_CC;
		I |= (Rd&15)<<12;
		I |= (Rm&15);
		EMIT_I;
	}

	EAPI SXTB(eReg Rd, eReg Rm, ConditionCode CC=AL)
	{
		DECL_Id(0x06AF0070);

		SET_CC;
		I |= (Rd&15)<<12;
		I |= (Rm&15);
		EMIT_I;
	}

	EAPI SXTH(eReg Rd, eReg Rm, ConditionCode CC=AL)
	{
		DECL_Id(0x06BF0070);

		SET_CC;
		I |= (Rd&15)<<12;
		I |= (Rm&15);
		EMIT_I;
	}

	EAPI UXTAB16(eReg Rd, eReg Rn, eReg Rm, ConditionCode CC=AL)
	{
		DECL_Id(0x06C00070);

		SET_CC;
		I |= (Rn&15)<<16;
		I |= (Rd&15)<<12;
		I |= (Rm&15);
		EMIT_I;
	}

	EAPI UXTAB(eReg Rd, eReg Rn, eReg Rm, ConditionCode CC=AL)
	{
		DECL_Id(0x06E00070);

		SET_CC;
		I |= (Rn&15)<<16;
		I |= (Rd&15)<<12;
		I |= (Rm&15);
		EMIT_I;
	}

	EAPI UXTAH(eReg Rd, eReg Rn, eReg Rm, ConditionCode CC=AL)
	{
		DECL_Id(0x06F00070);

		SET_CC;
		I |= (Rn&15)<<16;
		I |= (Rd&15)<<12;
		I |= (Rm&15);
		EMIT_I;
	}

	EAPI UXTB16(eReg Rd, eReg Rm, ConditionCode CC=AL)
	{
		DECL_Id(0x06CF0070);

		SET_CC;
		I |= (Rd&15)<<12;
		I |= (Rm&15);
		EMIT_I;
	}

	EAPI UXTB(eReg Rd, eReg Rm, ConditionCode CC=AL)
	{
		DECL_Id(0x06EF0070);

		SET_CC;
		I |= (Rd&15)<<12;
		I |= (Rm&15);
		EMIT_I;
	}

	EAPI UXTH(eReg Rd, eReg Rm, ConditionCode CC=AL)
	{
		DECL_Id(0x06FF0070);

		SET_CC;
		I |= (Rd&15)<<12;
		I |= (Rm&15);
		EMIT_I;
	}

};