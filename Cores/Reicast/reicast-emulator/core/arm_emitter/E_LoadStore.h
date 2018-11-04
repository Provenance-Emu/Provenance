/*
 *	E_LoadStore.h
 *
 *	LDR|STR{<cond>}{B}{T} Rd, <addressing_mode>
 *
 */
#pragma once



namespace ARM
{

	
	enum AddrMode {

		Offset,			// [Rn, offset]		- Base:Offset used for access, no writeback
		PostIndexed,	// [Rn, offset] !	- Base:Offset used for access, written back to Base reg.
		PreIndexed		// [Rn],offset		- Base used then Base:Offset written back to Base reg.

		// offset:  imm{8,12}, Rm, Rm <Shifter> #Shift
	};


#define SET_Rn		I |= (Rn&15)<<16
#define SET_Rt		I |= (Rt&15)<<12
#define SET_Rm		I |= (Rm&15)


#define SET_Rtn		SET_Rt; SET_Rn
#define SET_Rtnm	SET_Rt; SET_Rn; SET_Rm



#define SET_I		I |= (1<<25)		// Sets Register (Rather than Immediate) Addressing
#define SET_P		I |= (1<<24)		// If NOT Set: post-indexed, else offset||pre-indexed (W. determines which)
#define SET_U		I |= (1<<23)		// If SET: Offset is added to base, else its subtracted (Sign of sImm12)
#define SET_B		I |= (1<<22)		// If SET: Access is a byte access, else its a word access.
#define SET_W		I |= (1<<21)		// (P==0) [ W==0: reg. post indexed,  W==1: Unprivileged T variant ]  (P==1) [ W==0: Offset , W==1: Pre-indexed ]
#define SET_L		I |= (1<<20)		// (L==1) Load / Store


#define SET_AddrMode	\
	if(mode==Offset)			{ SET_P; }	\
	else if(mode==PreIndexed)	{ SET_P; SET_W; }

/*
#define SET_AddrMode	\
	\
	switch(mode) {	\
	case PostIndexed:	break;	\
	case Offset:		SET_P;	break;	\
	case PreIndexed:	SET_P;	SET_W;	break;	\
	}
*/


#define SET_sImm12	\
	\
	if (0 != sImm12) {				\
		if (sImm12 > 0)	{ SET_U; }	\
		I |= (abs(sImm12) &0xFFF);	\
	}

#define SET_sImm8	\
	\
	if(0 != sImm8) {				\
		verify(is_s8(sImm8));		\
		if(sImm8 > 0) { SET_U; }	\
		sImm8 = abs(sImm8);			\
		I |= ((u32)sImm8 &0x0F);	\
		I |= ((u32)sImm8 &0xF0)<<4;	\
	}


#define SET_Imm5	I |= ((Imm5&0x1F)<<7)
#define SET_type	I |= ((type&3)<<5)






/*	- Load/Store Encoding

	--------------------------------------------------------------------------------------

	cond 01-IPUBWL Rn Rt addr_mode						-- Load/Store Word || Unsigned Byte

		I,P,U,W	- Specify type of addressing mode
		L		- Specify Load (L==1), else Store
		B		- Specify Byte (B==1), else Word

	--------------------------------------------------------------------------------------

	cond 000-PUIWL Rn Rt addr_mode 1SH1 addr_mode		-- Load/Store Halfword || Signed byte

		I,P,U,W	- Specify type of addressing mode
		L		- Specify Load (L==1), else Store
		S		- Specify signed (S==1), else unsigned access
		H		- Specify Halfword access, else signed byte	

	--------------------------------------------------------------------------------------


	cond 010-PUBWL Rn Rt sImm12-iiii-iiii		Imm Offset
	cond 011-PUBWL Rn Rt #sft sft_op 0 Rm		Reg Offset

	cond 000 PU1WL Rn Rt imHI 1011 imLO			Imm Offset - halfword
	cond 000 PU0WL Rn Rt SBZ  1011 Rm			Reg Offset - halfword
	cond 000 PU1W1 Rn Rt imHI 11H1 imLO			Imm Offset - signed halfword/byte
	cond 000 PU0W1 Rn Rt SBZ  11H1 Rm			Reg Offset - signed halfword/byte
	cond 000 PU1W0 Rn Rt imHI 11S1 imLO			Imm Offset - two words
	cond 000 PU0W0 Rn Rt SBZ  11S1 Rm			Reg Offset - two words

	cond 100-PUSWL Rn Register-list				Multiple
	cond 110-PUNWL Rn CRd cp_num offs8			COP & double reg xfer

	cond 0001 0B00 Rn Rt SBZ  1001 Rm			Swap [byte]

	--------------------------------------------------------------------------------------

	LDR  L	010 1U001 11 Rt imm12				-	*no literal stores*
	LDR  I	010 PU0W1 Rn Rt imm12				-	STR  I	010 PU0W0 Rn Rt imm12
	LDR  R	011	PU0W1 Rn Rt imm5 type 0 Rm		-	STR  R	011 PU0W0 Rn Rt imm5 type 0 Rm

	LDRT I	010 0U011 Rn Rt imm12				-	STRT I	010 0U010 Rn Rt imm12
	LDRT R	011 0U011 Rn Rt imm5 type 0 Rm		-	STRT R	011 0U010 Rn Rt imm5 type 0 Rm

	LDRB L	010 1U101 11 Rt imm12				-	*^^
	LDRB I	010 PU1W1 Rn Rt imm12				-	STRB I	010 PU1W0 Rn Rt imm12
	LDRB R	011 PU1W1 Rn Rt imm5 type 0 Rm		-	STRB R	011 PU1W0 Rn Rt imm5 type 0 Rm

	LDRBT I	
	LDRBT R	

	--------------------------------------------------------------------------------------

	LDRH L	000 1U101 11 Rt imm4H 1011 imm4L	-	*^^
	LDRH I	000 PU1W1 Rn Rt imm4H 1011 imm4L	-	STRH I	000 PU1W0 Rn Rt imm4H 1011 imm4L
	LDRH R	000 PU0W1 Rn Rt 0000  1011 Rm		-	STRH R	000 PU0W0 Rn Rt 0000  1011 Rm

	LDRD L	000 1U100 11 Rt imm4H 1101 imm4L	-	*^^
	LDRD I	000 PU1W0 Rn Rt imm4H 1101 imm4L	-	STRD I	000 PU1W0 Rn Rt imm4H 1111 imm4L
	LDRD R	000 PU0W0 Rn Rt 0000  1101 Rm		-	STRD R	000 PU0W0 Rn Rt 0000  1111 Rm

	--------------------------------------------------------------------------------------

	LDRHT/STRHT

	LDREX/STREX
	LDREXB/STREXB
	LDREXH/STREXH
	LDREXD/STREXD
	--------------------------------------------------------------------------------------


	EAPI LDR   0x04100000	// These were all the A1 Versions for Imm IIRC
	EAPI LDRB  0x04500000
	EAPI LDRBT 0x06700000
	EAPI LDRD  0x00000000
	EAPI LDREX 0x01900090
	EAPI LDRH  0x00100090
	EAPI LDRSB 0x00100000
	EAPI LDRSH 0x00100000
	EAPI LDRT  0x04300000

	EAPI STR   0x04000000
	EAPI STRB  0x04400000
	EAPI STRBT 0x06600000
	EAPI STRD  0x00000000
	EAPI STREX 0x01800090
	EAPI STRH  0x00000090
	EAPI STRT  0x04200000

*/


extern u8* emit_opt;
extern eReg reg_addr;
extern eReg reg_dst;
extern s32 imma;

EAPI LDR (eReg Rt, eReg Rn, s32 sImm12=0, AddrMode mode=Offset, ConditionCode CC=AL)	
{	
	if (emit_opt+4==(u8*)EMIT_GET_PTR() && reg_addr==Rn && imma==sImm12)
	{
		if (reg_dst!=Rt)
			MOV(Rt,reg_dst);
	}
	else
	{
		DECL_Id(0x04100000); SET_CC; SET_Rtn; SET_AddrMode; SET_sImm12; EMIT_I;	
	}
}
EAPI STR (eReg Rt, eReg Rn, s32 sImm12=0, AddrMode mode=Offset, ConditionCode CC=AL)	
{	
	emit_opt=0;//(u8*)EMIT_GET_PTR();
	reg_addr=Rn;
	reg_dst=Rt;
	imma=sImm12;
	DECL_Id(0x04000000); SET_CC; SET_Rtn; SET_AddrMode; SET_sImm12; EMIT_I;	
}
EAPI LDRB(eReg Rt, eReg Rn, s32 sImm12=0, AddrMode mode=Offset, ConditionCode CC=AL)	{	DECL_Id(0x04500000); SET_CC; SET_Rtn; SET_AddrMode; SET_sImm12; SET_B; EMIT_I;	}	// Prob don't need SET_B, in iID
EAPI STRB(eReg Rt, eReg Rn, s32 sImm12=0, AddrMode mode=Offset, ConditionCode CC=AL)	{	DECL_Id(0x04400000); SET_CC; SET_Rtn; SET_AddrMode; SET_sImm12; SET_B; EMIT_I;	}	// Prob don't need SET_B, in iID

EAPI LDRT (eReg Rt, eReg Rn, s32 sImm12=0, ConditionCode CC=AL)	{	DECL_Id(0x04300000); SET_CC; SET_Rtn; SET_sImm12; EMIT_I;	}
EAPI STRT (eReg Rt, eReg Rn, s32 sImm12=0, ConditionCode CC=AL)	{	DECL_Id(0x04200000); SET_CC; SET_Rtn; SET_sImm12; EMIT_I;	}
EAPI LDRBT(eReg Rt, eReg Rn, s32 sImm12=0, ConditionCode CC=AL)	{	DECL_Id(0x04700000); SET_CC; SET_Rtn; SET_sImm12; SET_B; EMIT_I;	}	// Prob don't need SET_B, in iID
EAPI STRBT(eReg Rt, eReg Rn, s32 sImm12=0, ConditionCode CC=AL)	{	DECL_Id(0x04600000); SET_CC; SET_Rtn; SET_sImm12; SET_B; EMIT_I;	}	// Prob don't need SET_B, in iID

		// LDR(r1,r2,r3, Offset, true, L_LSL, 5, EQ);	... LDR r1, r2, +r3 LSL #5
EAPI LDR (eReg Rt, eReg Rn, eReg Rm, AddrMode mode=Offset, bool Add=false, ShiftOp type=S_LSL, u32 Imm5=0, ConditionCode CC=AL)	{	DECL_Id(0x06100000); SET_CC; SET_Rtnm; SET_AddrMode; SET_Imm5; SET_type; if(Add){ SET_U; } EMIT_I;	}
EAPI STR (eReg Rt, eReg Rn, eReg Rm, AddrMode mode=Offset, bool Add=false, ShiftOp type=S_LSL, u32 Imm5=0, ConditionCode CC=AL)	{	DECL_Id(0x06000000); SET_CC; SET_Rtnm; SET_AddrMode; SET_Imm5; SET_type; if(Add){ SET_U; } EMIT_I;	}
EAPI LDRB(eReg Rt, eReg Rn, eReg Rm, AddrMode mode=Offset, bool Add=false, ShiftOp type=S_LSL, u32 Imm5=0, ConditionCode CC=AL)	{	DECL_Id(0x06500000); SET_CC; SET_Rtnm; SET_AddrMode; SET_Imm5; SET_type; if(Add){ SET_U; } SET_B; EMIT_I;	}	// Prob don't need SET_B, in iID
EAPI STRB(eReg Rt, eReg Rn, eReg Rm, AddrMode mode=Offset, bool Add=false, ShiftOp type=S_LSL, u32 Imm5=0, ConditionCode CC=AL)	{	DECL_Id(0x06400000); SET_CC; SET_Rtnm; SET_AddrMode; SET_Imm5; SET_type; if(Add){ SET_U; } SET_B; EMIT_I;	}	// Prob don't need SET_B, in iID

EAPI LDRT (eReg Rt, eReg Rn, eReg Rm, bool Add=false, ShiftOp type=S_LSL, u32 Imm5=0, ConditionCode CC=AL)	{	DECL_Id(0x06300000); SET_CC; SET_Rtnm; SET_Imm5; SET_type; if(Add){ SET_U; } EMIT_I;	}
EAPI STRT (eReg Rt, eReg Rn, eReg Rm, bool Add=false, ShiftOp type=S_LSL, u32 Imm5=0, ConditionCode CC=AL)	{	DECL_Id(0x06200000); SET_CC; SET_Rtnm; SET_Imm5; SET_type; if(Add){ SET_U; } EMIT_I;	}
EAPI LDRBT(eReg Rt, eReg Rn, eReg Rm, bool Add=false, ShiftOp type=S_LSL, u32 Imm5=0, ConditionCode CC=AL)	{	DECL_Id(0x06700000); SET_CC; SET_Rtnm; SET_Imm5; SET_type; if(Add){ SET_U; } SET_B; EMIT_I;	}	// Prob don't need SET_B, in iID
EAPI STRBT(eReg Rt, eReg Rn, eReg Rm, bool Add=false, ShiftOp type=S_LSL, u32 Imm5=0, ConditionCode CC=AL)	{	DECL_Id(0x06600000); SET_CC; SET_Rtnm; SET_Imm5; SET_type; if(Add){ SET_U; } SET_B; EMIT_I;	}	// Prob don't need SET_B, in iID



// LDR Rt,[PC, #(s:+/-)Imm12]	*Special Case - Literal / PC Relative
EAPI LDR(eReg Rt, s32 sImm12, ConditionCode CC=AL) {
	DECL_Id(0x051F0000); SET_CC; SET_Rt; SET_sImm12; EMIT_I;
}

// LDRB Rt,[PC, #(s:+/-)Imm12]	*Special Case - Literal / PC Relative
EAPI LDRB(eReg Rt, s32 sImm12, ConditionCode CC=AL) {
	DECL_Id(0x055F0000); SET_CC; SET_Rt; SET_sImm12; EMIT_I;
}




// Note: Following support Post-Indexed addressing only //


EAPI LDRH(eReg Rt, eReg Rn, s32 sImm8, ConditionCode CC=AL)	{	DECL_Id(0x005000B0);	SET_CC;	SET_Rtn;	SET_P;	SET_sImm8;	EMIT_I;	}
EAPI STRH(eReg Rt, eReg Rn, s32 sImm8, ConditionCode CC=AL)	{	DECL_Id(0x004000B0);	SET_CC;	SET_Rtn;	SET_P;	SET_sImm8;	EMIT_I;	}
EAPI LDRD(eReg Rt, eReg Rn, s32 sImm8, ConditionCode CC=AL)	{	DECL_Id(0x004000D0);	SET_CC;	SET_Rtn;	SET_P;	SET_sImm8;	EMIT_I;	}
EAPI STRD(eReg Rt, eReg Rn, s32 sImm8, ConditionCode CC=AL)	{	DECL_Id(0x004000F0);	SET_CC;	SET_Rtn;	SET_P;	SET_sImm8;	EMIT_I;	}

EAPI LDRH(eReg Rt, eReg Rn, eReg Rm, bool Add=true,ConditionCode CC=AL)	{	DECL_Id(0x001000B0);	SET_CC;	SET_Rtnm;	SET_P;	if (Add) {SET_U;} EMIT_I;	}
EAPI STRH(eReg Rt, eReg Rn, eReg Rm, bool Add=true,ConditionCode CC=AL)	{	DECL_Id(0x000000B0);	SET_CC;	SET_Rtnm;	SET_P;	if (Add) {SET_U;} EMIT_I;	}
EAPI LDRD(eReg Rt, eReg Rn, eReg Rm, bool Add=true, ConditionCode CC=AL)	{	DECL_Id(0x000000D0);	SET_CC;	SET_Rtnm;	SET_P;	if (Add) {SET_U;} EMIT_I;	}
EAPI STRD(eReg Rt, eReg Rn, eReg Rm, bool Add=true, ConditionCode CC=AL)	{	DECL_Id(0x000000F0);	SET_CC;	SET_Rtnm;	SET_P;	if (Add) {SET_U;} EMIT_I;	}

EAPI LDRSB(eReg Rt, eReg Rn, eReg Rm, bool Add=true,ConditionCode CC=AL)	{	DECL_Id(0x001000D0);	SET_CC;	SET_Rtnm;	SET_P;	if (Add) {SET_U;} EMIT_I;	}
EAPI LDRSH(eReg Rt, eReg Rn, eReg Rm, bool Add=true,ConditionCode CC=AL)	{	DECL_Id(0x001000F0);	SET_CC;	SET_Rtnm;	SET_P;	if (Add) {SET_U;} EMIT_I;	}


EAPI LDRH(eReg Rt, s32 sImm8, ConditionCode CC=AL)			{	DECL_Id(0x015F00B0);	SET_CC;	SET_Rt;	SET_sImm8;	EMIT_I;	}	//	*Special Case - Literal / PC Relative
EAPI STRH(eReg Rt, s32 sImm8, ConditionCode CC=AL)			{	DECL_Id(0x014F00D0);	SET_CC;	SET_Rt;	SET_sImm8;	EMIT_I;	}	//	*Special Case - Literal / PC Relative



// TODO: {LD,ST}R{SB,EX*} && friends (If required).


// Must use _Reg format
EAPI PUSH(u32 RegList, ConditionCode CC=AL)
{
	DECL_Id(0x092D0000);

	SET_CC;
	I |= (RegList&0xFFFF);
	EMIT_I;
}


EAPI POP(u32 RegList, ConditionCode CC=AL)
{
	DECL_Id(0x08BD0000);

	SET_CC;
	I |= (RegList&0xFFFF);
	EMIT_I;
}


#undef SET_Rtn
#undef SET_Rtnm

#undef SET_Rn
#undef SET_Rt
#undef SET_Rm

#undef SET_I
#undef SET_P
#undef SET_U
#undef SET_B
#undef SET_W
#undef SET_L

#undef SET_AddrMode

#undef SET_sImm12
#undef SET_sImm8
#undef SET_Imm5
#undef SET_type






};