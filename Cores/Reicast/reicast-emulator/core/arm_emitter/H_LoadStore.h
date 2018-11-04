/*
 *	H_LoadStore.h
 *
 *
 */
#pragma once



namespace ARM
{

	/*
	 *	Load Helpers
	 */

	EAPI LoadImmBase(eReg Rt, u32 Base, ConditionCode CC=AL)
	{
		MOV32(Rt, Base, CC);

#if defined(_DEVEL)
		LDR(Rt,Rt,0, Offset, CC);
#else
		LDR(Rt,Rt,0, CC);
#endif
	}

	EAPI LoadImmBase(eReg Rt, eReg Rn, u32 Base, ConditionCode CC=AL)
	{
		MOV32(Rn, Base, CC);

#if defined(_DEVEL)
		LDR(Rt,Rn,0, Offset, CC);
#else
		LDR(Rt,Rn,0, CC);
#endif
	}

	EAPI LoadImmBase16(eReg Rt, u32 Base, bool Extend=false, ConditionCode CC=AL)
	{
		MOV32(Rt, Base, CC);
		LDRH(Rt,Rt,0, CC);

		if(Extend)
			SXTH(Rt,Rt);
	}

	EAPI LoadImmBase16(eReg Rt, eReg Rn, u32 Base, bool Extend=false, ConditionCode CC=AL)
	{
		MOV32(Rn, Base, CC);
		LDRH(Rt,Rn,0, CC);

		if(Extend)
			SXTH(Rt,Rt);
	}

	

	/*
	 *	Store Helpers
	 */

	// you pick regs, loads Base with reg addr, you supply data in Rt
	EAPI StoreImmBase(eReg Rt, eReg Rn, u32 Base, ConditionCode CC=AL)
	{
		MOV32(Rn, Base, CC);

#if defined(_DEVEL)
		STR(Rt,Rn,0, Offset, CC);
#else
		STR(Rt,Rn,0, CC);
#endif
	}

	// you pick regs, loads Rt with const val, you supply base for Rn
	EAPI StoreImmVal(eReg Rt, eReg Rn, u32 Val, ConditionCode CC=AL)
	{
		MOV32(Rt, Val, CC);

#if defined(_DEVEL)
		STR(Rt,Rn,0, Offset, CC);
#else
		STR(Rt,Rn,0, CC);
#endif
	}

	// you pick regs, loads Base with reg addr, loads Rt with const val
	EAPI StoreImms(eReg Rt, eReg Rn, u32 Base, u32 Val, ConditionCode CC=AL)
	{
		MOV32(Rn, Base, CC);
		MOV32(Rt, Val, CC);

#if defined(_DEVEL)
		STR(Rt,Rn,0, Offset, CC);
#else
		STR(Rt,Rn,0, CC);
#endif
	}


	
#if defined(_DEVEL) && 0	// These require testing //

	EAPI LoadImmBase8(eReg Rt, u32 Base, bool Extend=false, ConditionCode CC=AL)
	{
		MOV32(Rt, Base, CC);
		LDRB(Rt,Rt,0, CC);

		if(Extend)
			SXTB(Rt,Rt);
	}

	EAPI LoadImmBase8(eReg Rt, eReg Rn, u32 Base, bool Extend=false, ConditionCode CC=AL)
	{
		MOV32(Rn, Base, CC);
		LDRB(Rt,Rn,0, CC);

		if(Extend)
			SXTB(Rt,Rt);
	}

#endif	// defined(_DEVEL)



}
























