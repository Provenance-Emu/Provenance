/*
 *	E_VLoadStore.h		* VFP/A.SIMD Load/Store Instruction Set Encoding
 *
 */
#pragma once


namespace ARM
{
	
	//	[cond][110][Opcode][-Rn-][----][101][---------]
	//
	//	cond != 0b1111	| LDC && STC consume these



#define SET_Dd	\
	I |= ((Dd&0x0F)<<12);	\
	I |= ((Dd&0x10)<<18)

#define SET_Sd	\
	I |= ((Sd&0x1E)<<11);	\
	I |= ((Sd&0x01)<<22)


#define SET_Rn	\
	I |= ((Rn&15)<<16)

#define SET_uImm8		\
	I |= (uImm8 & 255)

#define SET_sImm8		\
	if (sImm8 > 0) {	\
		I |= (1<<23);	\
	}					\
	I |= (abs(sImm8) & 255)


#define SET_PUW(_P,_U,_W)	\
	I |= ( ((_P&1)<<24) | ((_U&1)<<23) | ((_W&1)<<21) )




	/*
	 *	V{LD,ST}R:	Vector Load/Store Register
	 *
	 *		V{LD,ST}R.64		// VFP && A.SIMD
	 *		V{LD,ST}R.32		// VFP
	 */

	EAPI VLDR(eFDReg Dd, eReg Rn, s32 sImm8, ConditionCode CC=AL)	// VLDR.64
	{
		DECL_Id(0x0D100B00);	SET_CC;
		SET_Dd;		SET_Rn;		SET_sImm8;
		EMIT_I;
	}

	EAPI VLDR(eFSReg Sd, eReg Rn, s32 sImm8, ConditionCode CC=AL)	// VLDR.32
	{
		DECL_Id(0x0D100A00);	SET_CC;
		SET_Sd;		SET_Rn;		SET_sImm8;
		EMIT_I;
	}


	EAPI VSTR(eFDReg Dd, eReg Rn, s32 sImm8, ConditionCode CC=AL)	// VSTR.64
	{
		DECL_Id(0x0D000B00);	SET_CC;
		SET_Dd;		SET_Rn;		SET_sImm8;
		EMIT_I;
	}

	EAPI VSTR(eFSReg Sd, eReg Rn, s32 sImm8, ConditionCode CC=AL)	// VSTR.32
	{
		DECL_Id(0x0D000A00);	SET_CC;
		SET_Sd;		SET_Rn;		SET_sImm8;
		EMIT_I;
	}

	

	/*
	 *	V{LD,ST}M:	Vector Load/Store Multiple
	 *
	 *		V{LD,ST}R.64		// VFP && A.SIMD
	 *		V{LD,ST}R.32		// VFP
	 *
	 *	uImm8:	directional count, abs(sImm8) is the reg. count
	 *	Dd:		Register to start sequential operation from..
	 *
	 *	suffix DB:	P=1 U=0 W=1,	Decrement Before,	Addresses end just before the address in Rn.
	 *	suffix IA:	P=0 U=1 W=?,	Increment After,	Addresses start at address in Rn
	 *
	 *	** These are very complicated encoding and require a lot of error checking and even more thought when used. **
	 *	** Simply using,  MOV32(R4, &double_array[0]);	VLDM(D0, R4, 4);  should however work to load an array of 4 doubles **
	 */

	EAPI VLDM(eFDReg Dd, eReg Rn, u32 uImm8, u32 WB=0, ConditionCode CC=AL)	// VLDM.64
	{
		// ASSERT( (uImm8>0) && (uImm8<=16) && ((Dd+uImm8) <= 32) )
		uImm8<<=1;
		DECL_Id(0x0C100B00);	SET_CC;
		SET_Dd;		SET_Rn;
		SET_uImm8;	SET_PUW(0,1,WB);			// Defaulting to IA w/o ! (Write-back)
		EMIT_I;
	}

	EAPI VLDM(eFSReg Sd, eReg Rn, u32 uImm8, ConditionCode CC=AL)	// VLDM.32
	{
		// ASSERT( (uImm8>0) && ((Dd+uImm8) <= 32) )
		DECL_Id(0x0C100A00);	SET_CC;
		SET_Sd;		SET_Rn;
		SET_uImm8;	SET_PUW(0,1,0);			// Defaulting to IA w/o ! (Write-back)
		EMIT_I;
	}


	EAPI VSTM(eFDReg Dd, eReg Rn, u32 uImm8, ConditionCode CC=AL)	// VSTM.64
	{
		// ASSERT( (uImm8>0) && (uImm8<=16) && ((Dd+uImm8) <= 32) )
		uImm8<<=1;
		DECL_Id(0x0C000B00);	SET_CC;
		SET_Dd;		SET_Rn;
		SET_uImm8;	SET_PUW(0,1,0);			// Defaulting to IA w/o ! (Write-back)
		EMIT_I;
	}

	EAPI VSTM(eFSReg Sd, eReg Rn, u32 uImm8, ConditionCode CC=AL)	// VSTM.32
	{
		// ASSERT( (uImm8>0) && ((Dd+uImm8) <= 32) )
		DECL_Id(0x0C000A00);	SET_CC;
		SET_Sd;		SET_Rn;
		SET_uImm8;	SET_PUW(0,1,0);			// Defaulting to IA w/o ! (Write-back)
		EMIT_I;
	}




	/*
	 *	V{LD,ST}n:	Various extra load/store multiple.
	 *
	 *		Not Implemented.
	 *
	 */






	/*
	 *	VPUSH/VPOP:	Vector Load/Store multiple consecutive vector registers to the stack.
	 *
	 *	V{PUSH,POP}	.64: A.SIMD		.32 VFP
	 */

	EAPI VPUSH(eFDReg Dd, eReg Rn, u32 uImm8, ConditionCode CC=AL)	// VPUSH.64
	{
		uImm8<<=1;
		DECL_Id(0x0D2D0B00);	SET_CC;
		SET_Dd;		SET_uImm8;
		EMIT_I;
	}

	EAPI VPUSH(eFSReg Sd, eReg Rn, u32 uImm8, ConditionCode CC=AL)	// VPUSH.32
	{
		DECL_Id(0x0D2D0A00);	SET_CC;
		SET_Sd;		SET_uImm8;
		EMIT_I;
	}


	EAPI VPOP(eFDReg Dd, eReg Rn, u32 uImm8, ConditionCode CC=AL)	// VPOP.64
	{
		uImm8<<=1;
		DECL_Id(0x0CBD0B00);	SET_CC;
		SET_Dd;		SET_uImm8;
		EMIT_I;
	}

	EAPI VPOP(eFSReg Sd, eReg Rn, u32 uImm8, ConditionCode CC=AL)	// VPOP.32
	{
		DECL_Id(0x0CBD0A00);	SET_CC;
		SET_Sd;		SET_uImm8;
		EMIT_I;
	}




	/*
	 *	Best practice is to remove macro definitions,
	 *	this way they can't affect subsequent headers.
	 */

#undef SET_Dd
#undef SET_Sd

#undef SET_Rn

#undef SET_uImm8
#undef SET_sImm8

#undef SET_PUW



};