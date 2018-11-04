/*
 *	E_VRegXfer.h		* VFP/A.SIMD Register Transfer Instruction Set Encoding
 *
 */
#pragma once


namespace ARM
{



	/////// REPLACE THIS MESS W.  SET_Rto16 / SET_Rto16_H22 ,  SET_Rto12 ,  SET_Rto0_H5  OR just leave it all in the fn's //////


#define SET_Qd	\
	I |= (((Qd<<1)&0x0E)<<16);	\
	I |= (((Qd<<1)&0x10)<<3)

#define SET_Qm	\
	I |= (((Qm<<1)&0x0E));	\
	I |= (((Qm<<1)&0x10)<<1)


#define SET_Dd	\
	I |= ((Dd&0x0F)<<16);	\
	I |= ((Dd&0x10)<<3)

#define SET_Dm	\
	I |= ((Dm&0x0F));		\
	I |= ((Dm&0x10)<<1)


#define SET_Sn	\
	I |= ((Sn&0x1E)<<15);	\
	I |= ((Sn&0x01)<<7)

#define SET_Sm	\
	I |= ((Sm&0x1E)>>1);	\
	I |= ((Sm&0x01)<<5)


#define SET_Rn	\
	I |= ((Rn&15)<<16)

#define SET_Rt	\
	I |= ((Rt&15)<<12)

#define SET_Rtx2	\
	I |= ((Rt&15)<<12) | ((Rt2&15)<<16)

	// VDUP VMOV VMRS VMSR

	/*
	 *	VDUP.SZ:	Duplicates an element from ARM reg Rt into every element of {Q,D}d		A.SIMD
	 *
	 */
	EAPI VDUP(eFQReg Qd, eReg Rt, u32 Size=32, ConditionCode CC=AL)
	{
		DECL_Id(0x0E800B10);	SET_CC;
		SET_Qd;		SET_Rt;		I |= (1<<21);	// Q
		if (Size==16)	{ I |= (1<<5);  }		// e
		if (Size==8)	{ I |= (1<<22); }		// b
		EMIT_I;
	}

	EAPI VDUP(eFDReg Dd, eReg Rt, u32 Size=32, ConditionCode CC=AL)
	{
		DECL_Id(0x0E800B10);	SET_CC;
		SET_Dd;		SET_Rt;		// No Q
		if (Size==16)	{ I |= (1<<5);  }	// e
		if (Size==8)	{ I |= (1<<22); }	// b
		EMIT_I;
	}

	EAPI VDUP8 (eFQReg Qd, eReg Rt, ConditionCode=AL)	{ VDUP(Qd,Rt,8, CC); }
	EAPI VDUP8 (eFDReg Dd, eReg Rt, ConditionCode=AL)	{ VDUP(Dd,Rt,8, CC); }
	EAPI VDUP16(eFQReg Qd, eReg Rt, ConditionCode=AL)	{ VDUP(Qd,Rt,16,CC); }
	EAPI VDUP16(eFDReg Dd, eReg Rt, ConditionCode=AL)	{ VDUP(Dd,Rt,16,CC); }
	EAPI VDUP32(eFQReg Qd, eReg Rt, ConditionCode=AL)	{ VDUP(Qd,Rt,32,CC); }
	EAPI VDUP32(eFDReg Dd, eReg Rt, ConditionCode=AL)	{ VDUP(Dd,Rt,32,CC); }

	EAPI VDUP32(eFQReg Qd, eFDReg Dm, int idx)	
	{
		DECL_Id(0xF3B00C00);
		
		//Set_Qd seems to be incompitable here ?
		I |= (((Qd<<1)&0x0E)<<12);	\
		I |= (((Qd<<1)&0x10)<<18);
		SET_Dm;
		I |= 0x40;	//SET_Q
		I |= 0x4 << 16;	// 32 bits 4=0100
		I |= (idx&1) << 19;	// set idx 

		EMIT_I;
	}




	/*
	 *	VMOV:	(register)
	 *
	 *		VMOV { <Qd, Qm> , <Dd, Dm> }		A.SIMD
	 *		VMOV { <Dd, Dm> , <Sd, Sm> }		VFP		sz1 UNDEFINED in single only VFP
	 */

	EAPI VMOV(eFQReg Qd, eFQReg Qm)	// UNCONDITIONAL
	{
		DECL_Id(0xF2200110);

		I |= ((Qd&0x0F)<<12) | ((Qd&0x10)<<18);
		I |= ((Qm&0x0F)<<16) | ((Qm&0x10)<<1);	// If !Consistent(M:Qm) then its VORR
		I |= ((Qm&0x0F))     | ((Qm&0x10)<<3);	// If !Consistent(M:Qm) then its VORR
		EMIT_I;
	}

	EAPI VMOV(eFDReg Dd, eFDReg Dm)	// UNCONDITIONAL
	{
		DECL_Id(0xF2200110);

		I |= ((Dd&0x0F)<<12) | ((Dd&0x10)<<18);
		I |= ((Dm&0x0F)<<16) | ((Dm&0x10)<<3);	// If !Consistent(M:Dm) then its VORR
		I |= ((Dm&0x0F))     | ((Dm&0x10)<<1);	// If !Consistent(M:Dm) then its VORR
		EMIT_I;
	}


//	EAPI VMOV(eFDReg Dd, eFDReg Dm, ConditionCode CC=AL)	{}		VFP Double Version Not Implemented here for obvious reasons : same as below except would set SZ @bit8 : 0x0EB00B40

	EAPI VMOV(eFSReg Sd, eFSReg Sm, ConditionCode CC=AL)
	{
		DECL_Id(0x0EB00A40);	SET_CC;

		I |= ((Sd&0x1E)<<11) | ((Sd&1)<<22);
		I |= ((Sm&0x1E)>>1)  | ((Sm&1)<<5);
		EMIT_I;
	}



	/*
	 *	VMOV:	(Immediate)		A.SIMD / VFP
	 *
	 */

	//// TO BE IMPLEMENTED ////




	/*
	 *	VMOV:	(ARM to scalar)		A.SIMD / VFP IF Size=32
	 *
	 */
	EAPI VMOV(eFDReg Dd, u32 Index, eReg Rt, u32 Size=32, ConditionCode CC=AL)
	{
		DECL_Id(0x0E000B10);	SET_CC;
		SET_Dd;		SET_Rt;
		// Dd[x]  where x==Index  Dd is 64b, 2x32[0,1](1bit) 4x16[0-3](2bits) 8x8[0-7](3bits)
		if (Size== 8) { I |= (1<<22) | ((Index&4)<<18) | ((Index&3)<<5) ;	}	// x -> opc1:0, opc2	(3bits)	| opc1:1 SET
		if (Size==16) { I |= (1<<5) | ((Index&2)<<20) | ((Index&1<<6)) ;	}	// x -> opc1:0, opc2:1	(2bits)	| opc2:0 SET
		if (Size==32) { I |= ((Index&1)<<21) ;								}	// x -> opc1:0			(1bit)	
		EMIT_I;
	}

	

	/*
	 *	VMOV:	(scalar to ARM)		A.SIMD / VFP IF Size=32
	 *
	 *	Note: U (bit32) is unsigned bit,  invalid for 32b and we do not handle it at all.. might want to set it for byte,short
	 */
	EAPI VMOV(eReg Rt, eFDReg Dd, u32 Index, u32 Size=32, ConditionCode CC=AL)	// This is really Vn, but we'll use the same macros..
	{
		DECL_Id(0x0E100B10);	SET_CC;
		SET_Dd;		SET_Rt;
		// Dd[x]  where x==Index  Dd is 64b, 2x32[0,1](1bit) 4x16[0-3](2bits) 8x8[0-7](3bits)
		if (Size== 8) { I |= (1<<22) | ((Index&4)<<18) | ((Index&3)<<5) ;	}	// x -> opc1:0, opc2	(3bits)	| opc1:1 SET
		if (Size==16) { I |= (1<<5) | ((Index&2)<<20) | ((Index&1<<6)) ;	}	// x -> opc1:0, opc2:1	(2bits)	| opc2:0 SET
		if (Size==32) { I |= ((Index&1)<<21) ;								}	// x -> opc1:0			(1bit)	
		EMIT_I;
	}

	
	

	/*
	 *	VMOV:	(between ARM and single either direction)		VFP
	 *
	 */
	EAPI VMOV(eReg Rt, eFSReg Sn, ConditionCode CC=AL)	// Sn !d
	{
		DECL_Id(0x0E000A10);	SET_CC;
		SET_Sn;		SET_Rt;		I |= (1<<20);	// op set = TO ARM reg
		EMIT_I;
	}
	EAPI VMOV(eFSReg Sn, eReg Rt, ConditionCode CC=AL)	// Sn !d
	{
		DECL_Id(0x0E000A10);	SET_CC;
		SET_Sn;		SET_Rt;		// op NOT set = TO FP Single reg
		EMIT_I;
	}

	
	
	

	/*
	 *	VMOV:	(between two ARM regs and two contiguous singles either direction)		VFP
	 *
	 */
	EAPI VMOV(eReg Rt, eReg Rt2, eFSReg Sm, ConditionCode CC=AL)	// Sn !d
	{
		DECL_Id(0x0E000A10);	SET_CC;
		SET_Sm;		SET_Rtx2;		I |= (1<<20);	// op set = TO ARM regs
		EMIT_I;
	}
	EAPI VMOV(eFSReg Sm, eReg Rt, eReg Rt2, ConditionCode CC=AL)	// Sn !d
	{
		DECL_Id(0x0E000A10);	SET_CC;
		SET_Sm;		SET_Rtx2;		// op NOT set = TO FP Single(s)
		EMIT_I;
	}

	
	
	

	/*
	 *	VMOV:	(between two ARM regs and a Double)	Dm <-> Rt2:Rt	A.SIMD/VFP
	 *
	 */
	EAPI VMOV(eReg Rt, eReg Rt2, eFDReg Dm, ConditionCode CC=AL)	// Sn !d
	{
		DECL_Id(0x0C400B10);	SET_CC;
		SET_Dm;		SET_Rtx2;		I |= (1<<20);	// op set = TO ARM regs
		EMIT_I;
	}
	EAPI VMOV(eFDReg Dm, eReg Rt, eReg Rt2, ConditionCode CC=AL)	// Sn !d
	{
		DECL_Id(0x0C400B10);	SET_CC;
		SET_Dm;		SET_Rtx2;		// op NOT set = TO FP Single(s)
		EMIT_I;
	}

	
	

	/*
	 *	VMOVL:	Takes each element in a VDouble && Sign or Zero extends into a VQuad	A.SIMD
	 *
	 */
	EAPI VMOVL(eFQReg Qd, eFDReg Dm, u32 Size=32, u32 Sign=0)	// UNCONDITIONAL	Q & ~1
	{
		Size >>= 3;				// Sz/8 = 1,2 or 4	else if >0 its VSHLL
		Sign = (Sign>0)?0:1;	// Invert to Unsigned
		DECL_Id(0xF2800A10);

		SET_Dm;
		I |= ((Qd&0x0F)<<12);
		I |= ((Qd&0x10)<<18);
		I |= ((Size &7)<<19);	// imm3
		I |= ((Sign &1)<<24);	// U
		EMIT_I;
	}

	EAPI VMOVL_S8 (eFQReg Qd, eFDReg Dm)	{ VMOVL(Qd,Dm,8,1);		}
	EAPI VMOVL_U8 (eFQReg Qd, eFDReg Dm)	{ VMOVL(Qd,Dm,8,0);		}
	EAPI VMOVL_S16(eFQReg Qd, eFDReg Dm)	{ VMOVL(Qd,Dm,16,1);	}
	EAPI VMOVL_U16(eFQReg Qd, eFDReg Dm)	{ VMOVL(Qd,Dm,16,0);	}
	EAPI VMOVL_S32(eFQReg Qd, eFDReg Dm)	{ VMOVL(Qd,Dm,32,1);	}
	EAPI VMOVL_U32(eFQReg Qd, eFDReg Dm)	{ VMOVL(Qd,Dm,32,0);	}

	
	
	

	/*
	 *	VMOVN:	Copies least significant half of each element of a VQuad into the elements of a VDouble 	A.SIMD
	 *
	 */
	EAPI VMOVN(eFDReg Dd, eFQReg Qm, u32 Size=32)	// UNCONDITIONAL	Q & ~1
	{
		Size >>= 4;				// Sz/32 = 0,1 or 2
		DECL_Id(0xF3B20200);

		SET_Qm;
		I |= ((Dd&0x0F)<<12);
		I |= ((Dd&0x10)<<18);
		I |= ((Size &3)<<18);	// size
		EMIT_I;
	}

	EAPI VMOVN16(eFDReg Dd, eFQReg Qm)	{ VMOVN(Dd,Qm,16);	}
	EAPI VMOVN32(eFDReg Dd, eFQReg Qm)	{ VMOVN(Dd,Qm,32);	}
	EAPI VMOVN64(eFDReg Dd, eFQReg Qm)	{ VMOVN(Dd,Qm,64);	}







	/*
	 *	VM{RS,SR}	Move ARM reg To/From FPSCR		A.SIMD/VFP
	 */
	EAPI VMRS(eReg Rt, ConditionCode CC=AL)
	{
		DECL_Id(0x0EF10A10);
		SET_CC;		SET_Rt;
		EMIT_I;
	}
	EAPI VMSR(eReg Rt, ConditionCode CC=AL)
	{
		DECL_Id(0x0EE10A10);
		SET_CC;		SET_Rt;
		EMIT_I;
	}










#undef SET_Qd
#undef SET_Qm

#undef SET_Dd
#undef SET_Dm

#undef SET_Sn
#undef SET_Sm

#undef SET_Rn
#undef SET_Rt
#undef SET_Rtx2

	
};