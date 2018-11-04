/*
 *	E_Misc.h
 *
 */
#pragma once



namespace ARM
{

	/*
	 *	Misc. Arithmetic Instructions
	 */

	//	Count Leading Zero's
	//
	EAPI CLZ(eReg Rd, eReg Rm, ConditionCode CC=AL)
	{
		DECL_Id(0x016F0F10);

		SET_CC;
		I |= (Rd&15)<<12;
		I |= (Rm&15);
		EMIT_I;
	}

	
	//	Unsigned sum of absolute differences
	//	
	EAPI USAD8(eReg Rd, eReg Rm, eReg Rs, ConditionCode CC=AL)
	{
		DECL_Id(0x0780F010);

		SET_CC;
		I |= (Rd&15)<<16;
		I |= (Rs&15)<<8;
		I |= (Rm&15);
		EMIT_I;
	}

	EAPI USADA8(eReg Rd, eReg Rm, eReg Rs, eReg Rn, ConditionCode CC=AL)
	{
		DECL_Id(0x07800010);

		SET_CC;
		I |= (Rd&15)<<16;
		I |= (Rn&15)<<12;
		I |= (Rs&15)<<8;
		I |= (Rm&15);
		EMIT_I;
	}
	



	/*
	 *	Packing Instructions
	 */
	
	
	EAPI PKHBT(eReg Rd, eReg Rn, eReg Rm, ConditionCode CC=AL)    // * shift_imm
	{
		DECL_Id(0x06800010);

		SET_CC;
		I |= (Rn&15)<<16;
		I |= (Rd&15)<<12;
		I |= (Rm&15);
		EMIT_I;
	}


	EAPI PKHTB(eReg Rd, eReg Rn, eReg Rm, ConditionCode CC=AL)    // * shift_imm
	{
		DECL_Id(0x06800050);

		SET_CC;
		I |= (Rn&15)<<16;
		I |= (Rd&15)<<12;
		I |= (Rm&15);
		EMIT_I;
	}



	/*
	 *	Swapping Instructions
	 */

	EAPI REV(eReg Rd, eReg Rm, ConditionCode CC=AL)
	{
		DECL_Id(0x06BF0F30);

		SET_CC;
		I |= (Rd&15)<<12;
		I |= (Rm&15);
		EMIT_I;
	}


	EAPI REV16(eReg Rd, eReg Rm, ConditionCode CC=AL)
	{
		DECL_Id(0x06BF0FB0);

		SET_CC;
		I |= (Rd&15)<<12;
		I |= (Rm&15);
		EMIT_I;
	}

	EAPI REVSH(eReg Rd, eReg Rm, ConditionCode CC=AL)
	{
		DECL_Id(0x06FF0F30);

		SET_CC;
		I |= (Rd&15)<<12;
		I |= (Rm&15);
		EMIT_I;
	}


	EAPI SEL(eReg Rd, eReg Rn, eReg Rm, ConditionCode CC=AL)
	{
		DECL_Id(0x06800FB0);

		SET_CC;
		I |= (Rn&15)<<16;
		I |= (Rd&15)<<12;
		I |= (Rm&15);
		EMIT_I;
	}




	
	/*
	 *	Saturate Instructions
	 */

	
	 
	//	SSAT{<cond>} <Rd>, #<immed>, <Rm>{, <shift>}
	//
	EAPI SSAT(eReg Rd, u32 sat_imm, eReg Rm, u32 sft_imm, ConditionCode CC=AL)	// sh&1 << 6
	{
		DECL_Id(0x06A00010);

		SET_CC;
		I |= (sat_imm&31)<<16;
		I |= (Rd&15)<<12;
		I |= (sft_imm&31)<<7;
		I |= (Rm&15);
		EMIT_I;
	}

	//	SSAT16{<cond>} <Rd>, #<immed>, <Rm>
	//
	EAPI SSAT16(eReg Rd, u32 sat_imm, eReg Rm, ConditionCode CC=AL)
	{
		DECL_Id(0x06A00030);

		SET_CC;
		I |= (sat_imm&15)<<16;
		I |= (Rd&15)<<12;
		I |= 15<<8;				// * SBO
		I |= (Rm&15);
		EMIT_I;
	}

	//	USAT{<cond>} <Rd>, #<immed>, <Rm>{, <shift>}
	//
	EAPI USAT(eReg Rd, u32 sat_imm, eReg Rm, u32 sft_imm, ConditionCode CC=AL)
	{
		DECL_Id(0x06E00010);

		SET_CC;
		I |= (sat_imm&31)<<16;
		I |= (Rd&15)<<12;
		I |= (sft_imm&31)<<7;
		I |= (Rm&15);
		EMIT_I;
	}

	//	USAT16{<cond>} <Rd>, #<immed>, <Rm>
	//
	EAPI USAT16(eReg Rd, u32 sat_imm, eReg Rm, ConditionCode CC=AL)
	{
		DECL_Id(0x06E00030);

		SET_CC;
		I |= (sat_imm&15)<<16;
		I |= (Rd&15)<<12;
		I |= 15<<8;				// * SBO
		I |= (Rm&15);
		EMIT_I;
	}









};