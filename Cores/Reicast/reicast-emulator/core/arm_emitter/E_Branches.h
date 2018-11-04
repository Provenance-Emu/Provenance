/*
 *	E_Branches.h
 *
 */
#pragma once



namespace ARM
{	
	
	EAPI B(u32 sImm24, ConditionCode CC=AL)
	{
		DECL_Id(0x0A000000);

		SET_CC;
		I |= ((sImm24>>2)&0xFFFFFF);
		EMIT_I;
	}

	EAPI BL(u32 sImm24, ConditionCode CC=AL)
	{
		DECL_Id(0x0B000000);

		SET_CC;
		I |= ((sImm24>>2)&0xFFFFFF);
		EMIT_I;
	}
	

	// Note: Either X variant will switch to THUMB* if bit0 of addr is 1
	//

	EAPI BX(eReg Rm, ConditionCode CC=AL)
	{
		DECL_Id(0x012FFF10);

		SET_CC;
		I |= (Rm&15);
		EMIT_I;
	}

	EAPI BLX(eReg Rm, ConditionCode CC=AL)   // Form II
	{
		DECL_Id(0x012FFF30);

		SET_CC;
		I |= (Rm&15);
		EMIT_I;
	}

	EAPI BXJ(eReg Rm, ConditionCode CC=AL)
	{
		DECL_Id(0x012FFF20);

		SET_CC;
		I |= (Rm&15);
		EMIT_I;
	}


	

	// This encoding looks correct,  but segfaults,  the pc val is align(pc,4) but this should be right in ARM
	//
#if defined(_DEVEL)
	EAPI BLX(u32 sImm24, bool toThumb)   // Form I     * H is derived so not needed, fixup sImm24 so one can just pass a real addr
	{
		DECL_Id(0xFA000000);

		if(toThumb)
		    I |= 1<<24; // SET_H

		I |= ((sImm24>>2)&0xFFFFFF);
		EMIT_I;
	}
#endif





};