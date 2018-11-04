/*
 *	E_Status.h
 *
 */
#pragma once



namespace ARM
{

#if defined(_DEVEL)
	
	//	MRS	Move PSR to General-purpose Register.
	//
	EAPI MRS(eReg Rd, u32 R, ConditionCode CC=AL)
	{
		DECL_Id(0x01000000);

		SET_CC;
		I |= (R&1) << 22;
		I |= 15<<16;			// * SBO
		I |= (Rd  &15)<<12;
		EMIT_I;
	}


	/*	MSR	Move General-purpose Register to PSR.

		MSR{<cond>} CPSR_<fields>, #<immediate>
		MSR{<cond>} CPSR_<fields>, <Rm>
		MSR{<cond>} SPSR_<fields>, #<immediate>
		MSR{<cond>} SPSR_<fields>, <Rm>
	*/
	

	// MSR: Immediate operand
	//
	EAPI MSR(u32 R, u32 fmask, u32 rot_imm, u32 imm8, ConditionCode CC=AL)
	{
		DECL_Id(0x03200000);

		SET_CC;
		I |= (R&1) << 22;
		I |= (fmask &15)<<16;
		I |= 15<<12;			// * SBO
		I |= (rot_imm &15)<<8;
		I |= (imm8 &255);
		EMIT_I;
	}

		
	// MSR: Register operand
	//
	EAPI MSR(u32 R, u32 fmask, eReg Rm, ConditionCode CC=AL)
	{
		DECL_Id(0x01200000);

		SET_CC;
		I |= (R&1) << 22;
		I |= (fmask &15)<<16;
		I |= 15<<12;			// * SBO
		I |= (Rm&15);
		EMIT_I;
	}



	//	CPS	Change Processor State.
	//
	EAPI CPS(u32 imod, u32 mmod, u32 mode)	// ** [A|I|F] 
	{
		DECL_Id(0xF1000000);	

		//	Note: UNconditional instruction!
		I |= (imod&3)<<18;
		I |= (mmod&1)<<17;
		I |= (mode&15);
		EMIT_I;
	}





	//	SETEND	Modifies the CPSR endianness, E, bit, without changing any other bits in the CPSR.
	//
	EAPI SETEND(u32 E)
	{
		DECL_Id(0xF1010000);

		//	Note: UNconditional instruction!
		I |= (E &1) << 9;
		EMIT_I;
	}

#endif

};
