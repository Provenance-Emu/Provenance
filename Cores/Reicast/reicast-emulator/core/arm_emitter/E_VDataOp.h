/*
 *	E_VDataOp.h		* VFP/A.SIMD Data Processing Instruction Set Encoding
 *
 *		V{<modifier>}<operation>{<shape>}<c><q>{.<dt>} {<dest>,} <src1>, <src2>
 *
 *		<modifier>		Meaning
 *			Q		The operation uses saturating arithmetic.
 *			R		The operation performs rounding.
 *			D		The operation doubles the result (before accumulation, if any).
 *			H		The operation halves the result.
 *
 *		<shape>		Meaning														Typical register shape
 *		(none)	The operands and result are all the same width.					Dd, Dn, Dm  -  Qd, Qn, Qm
 *		L		Long operation   - result is 2 x width of both operands			Qd, Dn, Dm
 *		N		Narrow operation - result is width/2 both operands				Dd, Qn, Qm
 *		W		Wide operation   - result and oper[1] are 2x width oper[2]		Qd, Qn, Dm
 */
#pragma once


namespace ARM
{
	



#define SET_Qd					\
	I |= (((Qd<<1)&0x0E)<<12);	\
	I |= (((Qd<<1)&0x10)<<18)

#define SET_Qn					\
	I |= (((Qn<<1)&0x0E)<<16);	\
	I |= (((Qn<<1)&0x10)<<3)

#define SET_Qm					\
	I |= (((Qm<<1)&0x0E));		\
	I |= (((Qm<<1)&0x10)<<1)



#define SET_Dd					\
	I |= ((Dd&0x0F)<<12);		\
	I |= ((Dd&0x10)<<18)

#define SET_Dn					\
	I |= ((Dn&0x0F)<<16);		\
	I |= ((Dn&0x10)<<3)

#define SET_Dm					\
	I |= ((Dm&0x0F));			\
	I |= ((Dm&0x10)<<1)




#define SET_Q       I |= 0x40
#define SET_U       I |= ((U&1)<<24);
#define SET_Size    I |= (((Size>>4)&3)<<20)    // 8,16,32 -> 0,1,2


#define SET_Qdnm	\
	SET_Qd;	SET_Qn;	SET_Qm;	SET_Q

#define SET_Ddnm	\
	SET_Dd;	SET_Dn;	SET_Dm

#define DECL_Qdnm
    
    
    
    

#define VdpInstrF(viName, viId)	\
		EAPI V##viName##_F32	(eFQReg Qd, eFQReg Qn, eFQReg Qm)  {   DECL_Id(viId);  SET_Qdnm;   EMIT_I; }   \
		EAPI V##viName##_F32	(eFDReg Dd, eFDReg Dn, eFDReg Dm)  {   DECL_Id(viId);  SET_Ddnm;   EMIT_I; }   


#define VdpInstrI_EOR(viName, viId) \
		EAPI V##viName	(eFQReg Qd, eFQReg Qn, eFQReg Qm)  {   DECL_Id(viId);  SET_Qdnm;   EMIT_I; }   \
		EAPI V##viName	(eFDReg Dd, eFDReg Dn, eFDReg Dm)  {   DECL_Id(viId);  SET_Ddnm;   EMIT_I; }   \

#define VdpInstrI(viName, viId) \
		EAPI V##viName	(eFQReg Qd, eFQReg Qn, eFQReg Qm, u32 Size=32)  {   DECL_Id(viId);  SET_Qdnm;   SET_Size;   EMIT_I; }   \
		EAPI V##viName	(eFDReg Dd, eFDReg Dn, eFDReg Dm, u32 Size=32)  {   DECL_Id(viId);  SET_Ddnm;   SET_Size;   EMIT_I; }   \
                    \
                EAPI V##viName##_I8  (eFQReg Qd, eFQReg Qn, eFQReg Qm)    {   V##viName   (Qd, Qn, Qm, 8);    }   \
                EAPI V##viName##_I8  (eFDReg Dd, eFDReg Dn, eFDReg Dm)    {   V##viName   (Dd, Dn, Dm, 8);    }   \
                EAPI V##viName##_I16 (eFQReg Qd, eFQReg Qn, eFQReg Qm)    {   V##viName   (Qd, Qn, Qm, 16);   }   \
                EAPI V##viName##_I16 (eFDReg Dd, eFDReg Dn, eFDReg Dm)    {   V##viName   (Dd, Dn, Dm, 16);   }   \
                EAPI V##viName##_I32 (eFQReg Qd, eFQReg Qn, eFQReg Qm)    {   V##viName   (Qd, Qn, Qm, 32);   }   \
                EAPI V##viName##_I32 (eFDReg Dd, eFDReg Dn, eFDReg Dm)    {   V##viName   (Dd, Dn, Dm, 32);   }

#define VdpInstrU(viName, viId)	\
		EAPI V##viName	(eFQReg Qd, eFQReg Qn, eFQReg Qm, u32 Size=32, u32 U=0)	{	DECL_Id(viId);	SET_Qdnm;   SET_U;  SET_Size;	EMIT_I;	}	\
		EAPI V##viName	(eFDReg Dd, eFDReg Dn, eFDReg Dm, u32 Size=32, u32 U=0)	{	DECL_Id(viId);	SET_Ddnm;   SET_U;  SET_Size;	EMIT_I;	}       \
                    \
                EAPI V##viName##_U8  (eFQReg Qd, eFQReg Qn, eFQReg Qm)    {   V##viName   (Qd, Qn, Qm, 8,  1);   }   \
                EAPI V##viName##_U8  (eFDReg Dd, eFDReg Dn, eFDReg Dm)    {   V##viName   (Dd, Dn, Dm, 8,  1);   }   \
                EAPI V##viName##_S8  (eFQReg Qd, eFQReg Qn, eFQReg Qm)    {   V##viName   (Qd, Qn, Qm, 8,  0);   }   \
                EAPI V##viName##_S8  (eFDReg Dd, eFDReg Dn, eFDReg Dm)    {   V##viName   (Dd, Dn, Dm, 8,  0);   }   \
                EAPI V##viName##_U16 (eFQReg Qd, eFQReg Qn, eFQReg Qm)    {   V##viName   (Qd, Qn, Qm, 16, 1);   }   \
                EAPI V##viName##_U16 (eFDReg Dd, eFDReg Dn, eFDReg Dm)    {   V##viName   (Dd, Dn, Dm, 16, 1);   }   \
                EAPI V##viName##_S16 (eFQReg Qd, eFQReg Qn, eFQReg Qm)    {   V##viName   (Qd, Qn, Qm, 16, 0);   }   \
                EAPI V##viName##_S16 (eFDReg Dd, eFDReg Dn, eFDReg Dm)    {   V##viName   (Dd, Dn, Dm, 16, 0);   }   \
                EAPI V##viName##_U32 (eFQReg Qd, eFQReg Qn, eFQReg Qm)    {   V##viName   (Qd, Qn, Qm, 32, 1);   }   \
                EAPI V##viName##_U32 (eFDReg Dd, eFDReg Dn, eFDReg Dm)    {   V##viName   (Dd, Dn, Dm, 32, 1);   }   \
                EAPI V##viName##_S32 (eFQReg Qd, eFQReg Qn, eFQReg Qm)    {   V##viName   (Qd, Qn, Qm, 32, 0);   }   \
                EAPI V##viName##_S32 (eFDReg Dd, eFDReg Dn, eFDReg Dm)    {   V##viName   (Dd, Dn, Dm, 32, 0);   }

//#       define VdpInstrImm  (viName, viId)
    

	// Another three or four like the above .. immN, above w/ size, F32 w/ sz

	
/*
 *	A.SIMD Parallel Add/Sub
 *
	Vector Add											VADD (integer),	VADD (floating-point)
	Vector Add and Narrow, returning High Half			VADDHN
	Vector Add Long, Vector Add Wide					VADDL, VADDW
	Vector Halving Add, Vector Halving Subtract			VHADD, VHSUB
	Vector Pairwise Add and Accumulate Long				VPADAL
	Vector Pairwise Add									VPADD (integer) ,	VPADD (floating-point)
	Vector Pairwise Add Long							VPADDL
	Vector Rounding Add & Narrow, returning High Half	VRADDHN
	Vector Rounding Halving Add							VRHADD
	Vector Rounding Subtract & Narrow, ret. High Half	VRSUBHN
	Vector Saturating Add								VQADD
	Vector Saturating Subtract							VQSUB
	Vector Subtract										VSUB (integer),	VSUB (floating-point)
	Vector Subtract and Narrow, returning High Half		VSUBHN
	Vector Subtract Long, Vector Subtract Wide			VSUBL, VSUBW
*/

	VdpInstrI(ADD,	0xF2000800)
	VdpInstrF(ADD,	0xF2000D00)


	VdpInstrI(HADD,      0xF2000800)
	VdpInstrI(HSUB,      0xF2000A00)

	VdpInstrI(PADD,      0xF2000B10)
	VdpInstrF(PADD,      0xF3000D00)


	VdpInstrU(RHADD,     0xF3000100)
	VdpInstrU(QADD,      0xF2000010)
	VdpInstrU(QSUB,      0xF3000210)

	VdpInstrI(SUB,       0xF3000800)
	VdpInstrF(SUB,       0xF2200D00)


	//	VADD I			{	DECL_Id(0xF2000800);	SET_Qdnm;	EMIT_I;	}
	//	VADD F			{	DECL_Id(0xF2000D00);	SET_Qdnm;	EMIT_I;	}
	//	VADDHN			{	DECL_Id(0xF2800400);	SET_Qdnm;	EMIT_I;	}   // DQQ
	//	VADD{L,W}		{	DECL_Id(0xF2800000);	SET_Qdnm;	EMIT_I;	}   // QDD || QQD
	//	VH{ADD,SUB}		{	DECL_Id(0xF2000000);	SET_Qdnm;	EMIT_I;	}
	//	VPADAL			{	DECL_Id(0xF3B00600);	SET_Qdnm;	EMIT_I;	}   // QdQm || DdDm
	//	VPADD I			{	DECL_Id(0xF2000B10);	SET_Qdnm;	EMIT_I;	}   // DDD only
	//	VPADD F			{	DECL_Id(0xF3000D00);	SET_Qdnm;	EMIT_I;	}   // DDD only
	//	VPADDL			{	DECL_Id(0xF3B00200);	SET_Qdnm;	EMIT_I;	}   // QdQm || DdDm
	//	VRADDHN			{	DECL_Id(0xF3800400);	SET_Qdnm;	EMIT_I;	}   // DQQ
	//	VRHADD			{	DECL_Id(0xF3000100);	SET_Qdnm;	EMIT_I;	}
	//	VRSUBHN			{	DECL_Id(0xF3800600);	SET_Qdnm;	EMIT_I;	}   // DQQ
	//	VQADD			{	DECL_Id(0xF2000010);	SET_Qdnm;	EMIT_I;	}
	//	VQSUB			{	DECL_Id(0xF3000210);	SET_Qdnm;	EMIT_I;	}
	//	VSUB I			{	DECL_Id(0xF3000800);	SET_Qdnm;	EMIT_I;	}
	//	VSUB F			{	DECL_Id(0xF2200D00);	SET_Qdnm;	EMIT_I;	}
	//	VSUBHN			{	DECL_Id(0xF2800600);	SET_Qdnm;	EMIT_I;	}   // DQQ
	//	VSUB{L,W}		{	DECL_Id(0xF2800200);	SET_Qdnm;	EMIT_I;	}   // QDD || QQD






/*
 *	A.SIMD Bitwise
 *
	Vector Bitwise AND							VAND (register)
	Vector Bitwise Bit Clear (AND complement)	VBIC (immediate), VBIC (register)
	Vector Bitwise Exclusive OR					VEOR
	Vector Bitwise Move							VMOV (immediate),	VMOV (register)
	Vector Bitwise NOT							VMVN (immediate),	VMVN (register)
	Vector Bitwise OR							VORR (immediate), 	VORR (register)
	Vector Bitwise OR NOT						VORN (register)
	Vector Bitwise Insert if False				VBIF
	Vector Bitwise Insert if True				VBIT
	Vector Bitwise Select						VBSL
*/

	VdpInstrI(AND,      0xF2000110)
	VdpInstrI(BIC,      0xF2100110)
	VdpInstrI_EOR(EOR,      0xF3000110)
	VdpInstrI_EOR(BSL,      0xF3100110)
	VdpInstrI_EOR(BIT,      0xF3200110)
	VdpInstrI_EOR(BIF,      0xF3300110)
	VdpInstrI(ORN,      0xF2300110)
	//	VAND R			{	DECL_Id(0xF2000110);	SET_Qdnm;	EMIT_I;	}
	//	VBIC R			{	DECL_Id(0xF2100110);	SET_Qdnm;	EMIT_I;	}
	//	VEOR			{	DECL_Id(0xF3000110);	SET_Qdnm;	EMIT_I;	}
	//	VBSL			{	DECL_Id(0xF3100110);	SET_Qdnm;	EMIT_I;	}
	//	VBIT			{	DECL_Id(0xF3200110);	SET_Qdnm;	EMIT_I;	}
	//	VBIF			{	DECL_Id(0xF3300110);	SET_Qdnm;	EMIT_I;	}
	//	VORN R			{	DECL_Id(0xF2300110);	SET_Qdnm;	EMIT_I;	}

	//	VBIC I			{	DECL_Id(0xF2800030);	SET_Qd;	SET_IMM??;	EMIT_I;	}
	//	VMOV I			{	DECL_Id(0xF2800010);	SET_Qd;	SET_IMM??;	EMIT_I;	}
	//	VMVN I			{	DECL_Id(0xF2800030);	SET_Qd;	SET_IMM??;	EMIT_I;	}
	//	VORR I			{	DECL_Id(0xF2800010);	SET_Qd;	SET_IMM??;	EMIT_I;	}
	//	VAND I		VBIC I
	//	VORN I		VORR I





/*
 *	A.SIMD comparison
 *
	Vector Absolute Compare							VACGE, VACGT, VACLE,VACLT
	Vector Compare Equal							VCEQ (register)
	Vector Compare Equal to Zer						VCEQ (immediate #0)
	Vector Compare Greater Than or Equal			VCGE (register)
	Vector Compare Greater Than or Equal to Zero	VCGE (immediate #0)
	Vector Compare Greater Than						VCGT (register)
	Vector Compare Greater Than Zero				VCGT (immediate #0)
	Vector Compare Less Than or Equal to Zero		VCLE (immediate #0)
	Vector Compare Less Than Zero					VCLT (immediate #0)
	Vector Test Bits VTST
*/
	//	VAC{COND}		{	DECL_Id(0xF3000E10);	SET_Vdnm;	EMIT_I;	}

	//	VCEQ			{	DECL_Id(0xF3000810);	SET_Vdnm;	EMIT_I;	}	.F32	{	DECL_Id(0xF2000E00);	SET_Vdnm;	EMIT_I;	}
	VdpInstrI(CEQ, 0xF3200810)
//	VdpInstrF(CEQ, 0xF2000e00)	
	//	VCGE			{	DECL_Id(0xF2000310);	SET_Vdnm;	EMIT_I;	}	.F32	{	DECL_Id(0xF3000E00);	SET_Vdnm;	EMIT_I;	}
	VdpInstrI(CGE, 0xF2200310)
//	VdpInstrF(CGE, 0xF3000e00)	
	//	VCGT			{	DECL_Id(0xF2000300);	SET_Vdnm;	EMIT_I;	}	.F32	{	DECL_Id(0xF3200E00);	SET_Vdnm;	EMIT_I;	}
	//*SEB*  0xF220030 for S32, 0xF3200300 for U32, 0xF2000300 is for S8.
	VdpInstrI(CGT, 0xF2200300)
	//VdpInstrF(CGT, 0xF3200e00)
	//	VCLE			{	DECL_Id(0xF3B10180);	SET_Vdnm;	EMIT_I;	}	//	R is VCGE w/ operands reversed
	//	VCLT			{	DECL_Id(0xF3B10200);	SET_Vdnm;	EMIT_I;	}	//	R is VCGT w/ operands reversed
	//	VTST			{	DECL_Id(0xF2000810);	SET_Vdnm;	EMIT_I;	}

	//	VCEQZ			{	DECL_Id(0xF3B10100);	SET_Vd;	SET_Vm;	EMIT_I;	}
	//	VCGEZ			{	DECL_Id(0xF3B10080);	SET_Vd;	SET_Vm;	EMIT_I;	}
	//	VCGTZ			{	DECL_Id(0xF3B10000);	SET_Vd;	SET_Vm;	EMIT_I;	}






/*
 *	A.SIMD shift			** SET_imm6;	needed for non Vdnm 
 *
	Vector Saturating Rounding Shift Left				VQRSHL
	Vector Saturating Rounding Shift Right and Narrow	VQRSHRN, VQRSHRUN
	Vector Saturating Shift Left						VQSHL (register), VQSHL, VQSHLU (immediate)
	Vector Saturating Shift Right and Narrow			VQSHRN, VQSHRUN 
	Vector Rounding Shift Left							VRSHL
	Vector Rounding Shift Right							VRSHR
	Vector Rounding Shift Right and Accumulate			VRSRA
	Vector Rounding Shift Right and Narrow				VRSHRN
	Vector Shift Left VSHL (immediate) on page A8-750	VSHL (register)
	Vector Shift Left Long								VSHLL
	Vector Shift Right									VSHR
	Vector Shift Right and Narrow						VSHRN
	Vector Shift Left and Insert						VSLI
	Vector Shift Right and Accumulate					VSRA
	Vector Shift Right and Insert						VSRI
*/
	//	VQRSHL			{	DECL_Id(0xF SET_Vdnm;		EMIT_I;	}		// * TODO
	//	VQRSHRN			{	DECL_Id(0xF SET_Vd;	SET_Vm;	EMIT_I;	}
	//	VQRSHRUN		{	DECL_Id(0xF SET_Vd;	SET_Vm;	EMIT_I;	}
	//	VQSHL R			{	DECL_Id(0xF SET_Vdnm;		EMIT_I;	}
	//	VQSHL I			{	DECL_Id(0xF SET_Vd;	SET_Vm;	EMIT_I;	}
	//	VQSHLU			{	DECL_Id(0xF SET_Vd;	SET_Vm;	EMIT_I;	}
	//	VQSHRN			{	DECL_Id(0xF SET_Vd;	SET_Vm;	EMIT_I;	}
	//	VQSHRUN			{	DECL_Id(0xF SET_Vd;	SET_Vm;	EMIT_I;	}
	//	VRSHL			{	DECL_Id(0xF SET_Vdnm;		EMIT_I;	}
	//	VRSHR			{	DECL_Id(0xF SET_Vd;	SET_Vm;	EMIT_I;	}
	//	VRSRA			{	DECL_Id(0xF SET_Vd;	SET_Vm;	EMIT_I;	}
	//	VRSHRN			{	DECL_Id(0xF SET_Vd;	SET_Vm;	EMIT_I;	}
	//	VSHL I			{	DECL_Id(0xF SET_Vd;	SET_Vm;	EMIT_I;	}
	//	VSHL R			{	DECL_Id(0xF SET_Vdnm;		EMIT_I;	}
	//	VSHLL			{	DECL_Id(0xF SET_Vd;	SET_Vm;	EMIT_I;	}
	//	VSHR			{	DECL_Id(0xF SET_Vd;	SET_Vm;	EMIT_I;	}
	//	VSHRN			{	DECL_Id(0xF SET_Vd;	SET_Vm;	EMIT_I;	}
	//	VSLI			{	DECL_Id(0xF SET_Vd;	SET_Vm;	EMIT_I;	}
	//	VSRA			{	DECL_Id(0xF SET_Vd;	SET_Vm;	EMIT_I;	}
	//	VSRI			{	DECL_Id(0xF SET_Vd;	SET_Vm;	EMIT_I;	}




/*
 *	A.SIMD multiply
 *
	Vector Multiply Accumulate										VMLA, VMLAL, VMLS, VMLSL (integer) ,	VMLA, VMLS (floating-point),	VMLA, VMLAL, VMLS, VMLSL (by scalar)
	Vector Multiply Accumulate Long
	Vector Multiply Subtract
	Vector Multiply Subtract Long
	Vector Multiply													VMUL, VMULL (integer and polynomial)
	Vector Multiply Long											VMUL (floating-point) on page A8-664 	VMUL, VMULL (by scalar)
	Vector Saturating Doubling Multiply Accumulate Long				VQDMLAL, VQDMLSL
	Vector Saturating Doubling Multiply Subtract Long
	Vector Saturating Doubling Multiply Returning High Half			VQDMULH
	Vector Saturating Rounding Doubling Multiply Ret. High Half		VQRDMULH
	Vector Saturating Doubling Multiply Long						VQDMULL
*/

	VdpInstrI(MLA,       0xF2000900)
	VdpInstrI(MLS,       0xF3000900)
	
	VdpInstrF(MLA,       0xF2000D10)
	VdpInstrF(MLS,       0xF2200D10)
	
	//by scalar
	//this should be really qd,dn,sm not dm
	EAPI VMUL_F32(eFQReg Qd,eFQReg Qn, eFDReg Dm, int idx)	
	{
		DECL_Id(0xF2800840);
		
		SET_Qd;
		SET_Qn;
		I |= 1<<8;	//SET_F
		
		SET_Dm;
		I |= 0x1<<24;	//SET_Q not compatible

		I |= 2<<20;		//size to 32
		
		I |= Dm&15;		//only lower 15 regs are avail


		//set register sub index
		if (idx)
			I |= 1<<5;
 
		EMIT_I;
	}
		
	EAPI VMLA_F32(eFQReg Qd,eFQReg Qn, eFDReg Dm, int idx)	
	{
		DECL_Id(0xF2800040);
		
		SET_Qd;
		SET_Qn;
		I |= 1<<8;	//SET_F
		
		SET_Dm;
		I |= 0x1<<24;	//SET_Q not compatible

		I |= 2<<20;		//size to 32
		
		I |= Dm&15;		//only lower 15 regs are avail


		//set register sub index
		if (idx)
			I |= 1<<5;
 
		EMIT_I;
	}
//	VdpInstrU(MLAL,       0xF2000D10)	*QDD
//	VdpInstrU(MLSL,       0xF2200D10)	*QDD
	
	
	VdpInstrI(MUL,       0xF2000910)
	
	VdpInstrF(MUL,       0xF3000D10)
	
//	VdpInstrU(MULL,       0xF3000D10)	*QDD

	//	VMLA  I			{	DECL_Id(0xF2000900);	SET_Vdnm;	EMIT_I;	}	// * I |= ((size&3)<<20)
	//	VMLS  I			{	DECL_Id(0xF3000900);	SET_Vdnm;	EMIT_I;	}	// * I |= ((size&3)<<20)
	//	VMLAL I			{	DECL_Id(0xF2800800);	SET_Vdnm;	EMIT_I;	}	// * I |= ((size&3)<<20)	* I |= ((U&1)<<24)
	//	VMLSL I			{	DECL_Id(0xF2800A00);	SET_Vdnm;	EMIT_I;	}	// * I |= ((size&3)<<20)	* I |= ((U&1)<<24)

	//	VMLA  F			{	DECL_Id(0xF2000D10);	SET_Vdnm;	EMIT_I;	}	// * I |= ((sz&1)<<20)
	//	VMLS  F			{	DECL_Id(0xF2200D10);	SET_Vdnm;	EMIT_I;	}	// * I |= ((sz&1)<<20)

	//	VMLA  S			{	DECL_Id(0xF2800040);	SET_Vdnm;	EMIT_I;	}	// * I |= ((size&3)<<20)
	//	VMLS  S			{	DECL_Id(0xF2800440);	SET_Vdnm;	EMIT_I;	}	// * I |= ((size&3)<<20)
	//	CMLAL S			{	DECL_Id(0xF2800240);	SET_Vdnm;	EMIT_I;	}	// * I |= ((size&3)<<20)	* I |= ((U&1)<<24)
	//	VMLSL S			{	DECL_Id(0xF2800640);	SET_Vdnm;	EMIT_I;	}	// * I |= ((size&3)<<20)	* I |= ((U&1)<<24)

	//	VMUL  IP		{	DECL_Id(0xF2000910);	SET_Vdnm;	EMIT_I;	}	// * I |= ((size&3)<<20)	* I |= 1<<24 for polynomial
	//	VMULL IP		{	DECL_Id(0xF2800C00);	SET_Vdnm;	EMIT_I;	}	// * I |= ((size&3)<<20)	* I |= 1<<9  for polynomial		* I |= ((U&1)<<24)

	//	VMUL  F			{	DECL_Id(0xF3000D10);	SET_Vdnm;	EMIT_I;	}	// * I |= ((sz&1)<<20)

	//	VMUL  S			{	DECL_Id(0xF2800840);	SET_Vdnm;	EMIT_I;	}	// * I |= ((size&3)<<20)
	//	VMULL S			{	DECL_Id(0xF2800A40);	SET_Vdnm;	EMIT_I;	}	// * I |= ((size&3)<<20)	* I |= ((U&1)<<24)
	//	VQDMLAL			{	DECL_Id(0xF2800900);	SET_Vdnm;	EMIT_I;	}	// * I |= ((size&3)<<20)
	//	VQDMLSL			{	DECL_Id(0xF2800B00);	SET_Vdnm;	EMIT_I;	}	// * I |= ((size&3)<<20)
	//	VQDMULH			{	DECL_Id(0xF2000B00);	SET_Vdnm;	EMIT_I;	}	// * I |= ((size&3)<<20)
	//	VQRDMULH		{	DECL_Id(0xF3000B00);	SET_Vdnm;	EMIT_I;	}	// * I |= ((size&3)<<20)
	//	VQDMULL			{	DECL_Id(0xF2800D00);	SET_Vdnm;	EMIT_I;	}	// * I |= ((size&3)<<20)



 



/*
 *	A.SIMD misc
 *
	Vector Absolute Difference and Accumulate						VABA, VABAL
	Vector Absolute Difference										VABD, VABDL (integer) ,	VABD (floating-point)
	Vector Absolute													VABS
	Vector Convert between floating-point and fixed point			VCVT (between floating-point and fixed-point, Advanced SIMD)
	Vector Convert between floating-point and integer				VCVT (between floating-point and integer, Advanced SIMD)
	Vector Convert between half-precision and single-precision		VCVT (between half-precision and single-precision, Advanced	SIMD)
	Vector Count Leading Sign Bits									VCLS
	Vector Count Leading Zeros										VCLZ
	Vector Count Set Bits											VCNT
	Vector Duplicate scalar											VDUP (scalar)
	Vector Extract													VEXT
	Vector Move and Narrow											VMOVN
	Vector Move Long												VMOVL
	Vector Maximum, Minimum											VMAX, VMIN (integer) ,	VMAX, VMIN (floating-point)
	Vector Negate													VNEG
	Vector Pairwise Maximum, Minimum								VPMAX, VPMIN (integer) , VPMAX, VPMIN (floating-point)
	Vector Reciprocal Estimate										VRECPE
	Vector Reciprocal Step											VRECPS
	Vector Reciprocal Square Root Estimate							VRSQRTE
	Vector Reciprocal Square Root Step								VRSQRTS
	Vector Reverse													VREV16, VREV32, VREV64
	Vector Saturating Absolute										VQABS
	Vector Saturating Move and Narrow								VQMOVN, VQMOVUN
	Vector Saturating Negate										VQNEG
	Vector Swap														VSWP
	Vector Table Lookup												VTBL, VTBX
	Vector Transpose												VTRN
	Vector Unzip													VUZP
	Vector Zip														VZIP
*/
	//	VABA			{	DECL_Id(0xF2000710);		// WIP
	//	VABAL			{	DECL_Id(0xF2800500);

	//	VABD  I			{	DECL_Id(0xF);
	//	VABDL I			{	DECL_Id(0xF);
	
	//	VABD  F			{	DECL_Id(0xF);

	//	VABS			{	DECL_Id(0xF);	SET_Vd;	SET_Vm;		EMIT_I;	}
	
	EAPI VSQRT_F32(eFSReg Sd, eFSReg Sm, ConditionCode CC=AL)
	{
		DECL_Id(0x0EB10AC0);	SET_CC;

		I |= ((Sd&0x1E)<<11) | ((Sd&1)<<22);
		I |= ((Sm&0x1E)>>1)  | ((Sm&1)<<5);
		EMIT_I;
	}

	EAPI VABS_F32(eFSReg Sd, eFSReg Sm, ConditionCode CC=AL)
	{
		DECL_Id(0x0EB00AC0);	SET_CC;

		I |= ((Sd&0x1E)<<11) | ((Sd&1)<<22);
		I |= ((Sm&0x1E)>>1)  | ((Sm&1)<<5);
		EMIT_I;
	}
	EAPI VNEG_F32(eFSReg Sd, eFSReg Sm, ConditionCode CC=AL)
	{
		DECL_Id(0x0EB10A40);	SET_CC;

		I |= ((Sd&0x1E)<<11) | ((Sd&1)<<22);
		I |= ((Sm&0x1E)>>1)  | ((Sm&1)<<5);
		EMIT_I;
	}
	
	//imm move, fpu
	EAPI VMOV(eFSReg Sd, u32 imm8_fpu, ConditionCode CC=AL)
	{
		DECL_Id(0x0EB10A00);	SET_CC;

		I |= (imm8_fpu&0x0F);		//bits 3:0
		I |= (imm8_fpu&0xF0)<<12;	//bits 19:16

		I |= ((Sd&0x1E)<<11) | ((Sd&1)<<22);
		EMIT_I;
	}

	const u32 fpu_imm_1=0x70;//01110000

	EAPI VCMP_F32(eFSReg Sd, eFSReg Sm, ConditionCode CC=AL)
	{
		DECL_Id(0x0EB40A40);	SET_CC;

		I |= ((Sd&0x1E)<<11) | ((Sd&1)<<22);
		I |= ((Sm&0x1E)>>1)  | ((Sm&1)<<5);
		EMIT_I;
	}

	VdpInstrF(CEQ,	0xF2000E00)
	VdpInstrF(CGE,	0xF3000E00)
	VdpInstrF(CGT,	0xF3200E00)

	//	VCVT FFP		{	DECL_Id(0xF);	SET_Vd;	SET_Vm;		EMIT_I;	}
	//	VCVT FI			{	DECL_Id(0xF);	SET_Vd;	SET_Vm;		EMIT_I;	}
	//	VCVT HS			{	DECL_Id(0xF);	SET_Vd;	SET_Vm;		EMIT_I;	}

	//	VCLS			{	DECL_Id(0xF);	SET_Vd;	SET_Vm;		EMIT_I;	}
	//	VCLZ			{	DECL_Id(0xF);	SET_Vd;	SET_Vm;		EMIT_I;	}
	//	VCNT			{	DECL_Id(0xF);	SET_Vd;	SET_Vm;		EMIT_I;	}


	//	VEXT			{	DECL_Id(0xF);	SET_Vdnm;	EMIT_I;	}

	//	VMAX I			{	DECL_Id(0xF);
	//	VMIN I			{	DECL_Id(0xF);
	//	VMAX F			{	DECL_Id(0xF);
	//	VMIN F			{	DECL_Id(0xF);
	//	VNEG			{	DECL_Id(0xF);

	//	VPMAX I			{	DECL_Id(0xF);
	//	VPMIN I			{	DECL_Id(0xF);
	//	VPMAX F			{	DECL_Id(0xF);
	//	VPMIN F			{	DECL_Id(0xF);

	//	VRECPE			{	DECL_Id(0xF3B30400);	SET_Vd;	SET_Vm;		EMIT_I;	}		// size&3<<18
	//	VRECPS			{	DECL_Id(0xF2000F10);	SET_Vdnm;			EMIT_I;	}		// sz&1<<20		(.F32)
	//	VRSQRTE			{	DECL_Id(0xF3B30480);	SET_Vd;	SET_Vm;		EMIT_I;	}		// size&3<<18	F&1<<8		***
	//	VRSQRTS			{	DECL_Id(0xF2200F10);	SET_Vdnm;			EMIT_I;	}		// sz&1<<20		(.F32)
	//	VREVsz			{	DECL_Id(0xF3B00000);	SET_Vd;	SET_Vm;		EMIT_I;	}		// size&3<<18	op&3<<7		***	

	//	VQABS			{	DECL_Id(0xF3B00700);	SET_Vd;	SET_Vm;		EMIT_I;	}		// size&3<<18
	//	VQMOVN			{	DECL_Id(0xF3B20200);	SET_Vd;	SET_Vm;		EMIT_I;	}		// size&3<<18	op&3<<6	op:00=MOVN op11=srcUnsigned op:x1=dstUnsigned
	//	VQMOVUN			{	DECL_Id(0xF3B20200);	SET_Vd;	SET_Vm;		EMIT_I;	}		// size&3<<18
	//	VQNEG			{	DECL_Id(0xF3B00780);	SET_Vd;	SET_Vm;		EMIT_I;	}		// size&3<<18

	//	VSWP			{	DECL_Id(0xF3B20000);	SET_Vd;	SET_Vm;		EMIT_I;	}		// size&3<<18
	//	VTBL			{	DECL_Id(0xF3B00800);	SET_Vdnm;			EMIT_I;	}		// len&3<<8
	//	VTBX			{	DECL_Id(0xF3B00840);	SET_Vdnm;			EMIT_I;	}		// len&3<<8
	//	VTRN			{	DECL_Id(0xF3B20080);	SET_Vd;	SET_Vm;		EMIT_I;	}		// size&3<<18
	//	VUZP			{	DECL_Id(0xF3B20100);	SET_Vd;	SET_Vm;		EMIT_I;	}		// size&3<<18
	//	VZIP			{	DECL_Id(0xF3B20180);	SET_Vd;	SET_Vm;		EMIT_I;	}		// size&3<<18
	//	


//	VDUP	&	VMOVN	&	VMOVL	are implemented in VRegXfer.h ...






	/*
	 *	VFPv3 Instructions 
	 *
	 */




#define SET_Sd					\
	I |= ((Sd&0x1E)<<11);		\
	I |= ((Sd&0x01)<<22)

#define SET_Sn					\
	I |= ((Sn&0x1E)<<15);		\
	I |= ((Sn&0x01)<<7)

#define SET_Sm					\
	I |= ((Sm&0x1E)>>1);		\
	I |= ((Sm&0x01)<<5)



#define SET_Sdnm	SET_Sd; SET_Sn; SET_Sm


#define VfpInstrS(viName, viId)		EAPI V##viName##_VFP	(eFSReg Sd, eFSReg Sn, eFSReg Sm, ConditionCode CC=CC_AL)  {   DECL_Id(viId);  SET_CC;	SET_Sdnm;   EMIT_I; }

	VfpInstrS(MLA,	0x0E000A00)
	VfpInstrS(MLS,	0x0E000A40)

	VfpInstrS(NMLA,	0x0E100A40)
	VfpInstrS(NMLS,	0x0E100A00)
	VfpInstrS(NMUL,	0x0E200A40)


	VfpInstrS(MUL,	0x0E200A00)

	VfpInstrS(ADD,	0x0E300A00)
	VfpInstrS(SUB,	0x0E300A40)

	VfpInstrS(DIV,	0x0E800A00)

	
	EAPI VCVT_to_S32_VFP (eFSReg Sd, eFSReg Sm, ConditionCode CC=CC_AL)  {   DECL_Id(0x0EBD0AC0);  SET_CC;	SET_Sd; SET_Sm;   EMIT_I; }		//	VfpInstrS(ABS,	0x0EB00AC0)		** {D,S}dm
	// 0x0EB80A40 is to_U32. to_S32 is 0x0EB80AC0
	EAPI VCVT_from_S32_VFP (eFSReg Sd, eFSReg Sm, ConditionCode CC=CC_AL)  {   DECL_Id(0x0EB80AC0);  SET_CC;	SET_Sd; SET_Sm;   EMIT_I; }		//	VfpInstrS(ABS,	0x0EB00AC0)		** {D,S}dm

	EAPI VABS_VFP (eFSReg Sd, eFSReg Sm, ConditionCode CC=CC_AL)  {   DECL_Id(0x0EB00AC0);  SET_CC;	SET_Sd; SET_Sm;   EMIT_I; }		//	VfpInstrS(ABS,	0x0EB00AC0)		** {D,S}dm
	EAPI VNEG_VFP (eFSReg Sd, eFSReg Sm, ConditionCode CC=CC_AL)  {   DECL_Id(0x0EB10A40);  SET_CC;	SET_Sd; SET_Sm;   EMIT_I; }		//	VfpInstrS(NEG,	0x0EB10A40)		** {D,S}dm
	EAPI VSQRT_VFP(eFSReg Sd, eFSReg Sm, ConditionCode CC=CC_AL)  {   DECL_Id(0x0EB10AC0);  SET_CC;	SET_Sd; SET_Sm;   EMIT_I; }		//	VfpInstrS(SQRT,	0x0EB10AC0)		** {D,S}dm

//	- x0 Vector Move VMOV (immediate) on page A8-640
//	0000 01 Vector Move VMOV (register) on page A8-642

//	001x x1 Vector Convert VCVTB, VCVTT (between half-precision and single-precision, VFP) on page A8-588
//	010x x1 Vector Compare VCMP, VCMPE on page A8-572
//	0111 11 Vector Convert VCVT (between double-precision and single-precision) on page A8-584
//	1000 x1 Vector Convert VCVT, VCVTR (between floating-point and integer, VFP) on page A8-578
//	101x x1 Vector Convert VCVT (between floating-point and fixed-point, VFP) on page A8-582
//	110x x1 Vector Convert VCVT, VCVTR (between floating-point and integer, VFP) on page A8-578
//	111x x1 Vector Convert VCVT (between floating-point and fixed-point, VFP) on page A8-582

	////// hack

	EAPI VDIV_HACKF32(eFDReg Sd, eFDReg Sn, eFDReg Sm)
	{
		ConditionCode CC=AL;

		eFSReg SdS=(eFSReg)(Sd*2);
		eFSReg SnS=(eFSReg)(Sn*2);
		eFSReg SmS=(eFSReg)(Sm*2);

		verify(Sd<32 && Sn<32 && Sm<32);

		VDIV_VFP(SdS,SnS,SmS);
	}













	



#undef SET_Qd
#undef SET_Dd

#undef SET_Qn
#undef SET_Dn

#undef SET_Qm
#undef SET_Dm

#undef SET_Q

#undef SET_Qdnm
#undef SET_Ddnm



};
