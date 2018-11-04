/*
 *	<E_DataOp.h		Title="ARMv7 ISA Emitter Middle-ware:	Data-Processing Instructions"	/>
 *
 *	<?CTYPE
 *
 *	<opcode1>{<cond>}{S} <Rd>, <shifter_operand>
 *	<opcode1> := MOV | MVN
 *
 *	<opcode2>{<cond>} <Rn>, <shifter_operand>
 *	<opcode2> := CMP | CMN | TST | TEQ
 *
 *	<opcode3>{<cond>}{S} <Rd>, <Rn>, <shifter_operand>
 *	<opcode3> := ADD | SUB | RSB | ADC | SBC | RSC | AND | BIC | EOR | ORR
 *
 *	?/>
 */
#pragma once



namespace ARM
{
	
	
	
	
	
	
	
	/*
	 *	imm				Rd,[Rn,] imm
	 *	reg				Rd,Rn,Rm shift
	 *	rsr				Rd,Rn,Rm type Rs
	 *
	 * sp.imm			Rd {SP} imm
	 * sp.reg			Rd {SP} Rm shift
	 *
	 */
	
	
#if 0
#define dpInstr(iName, iId)	\
		EAPI iName (eReg Rd, eReg Rn, u32 Imm)	;	\
		EAPI iName (eReg Rd, eReg Rn, eReg Rm, eShiftOp type=S_LSL, u32 Imm=0)	;	\
		EAPI iName (eReg Rd, eReg Rn, eReg Rm, eShiftOp type, eReg Rs)	;
#endif	
	
	/*
	
	ADC	IMM	0x02A00000
	ADC REG	0x00A00000
	ADC RSR	0x00A00010
	
	ADD IMM	0x02800000
	ADD REG	0x00800000
	ADD RSR 0x00800010
ADD.SP.IMM	0x028D0000
ADD.SP.REG	0x008D0000
	
	AND IMM	0x02000000
	AND REG	0x00000000
	AND RSR	0x00000010
	
	
//	ASR's do not fit this pattern moved elsewhere	//
	
	
	
	BIC IMM	0x03C00000
	BIC REG 0x01C00000
	BIC RSR 0x01C00010
	
	CMN IMM	0x03700000		// N imm
	CMN REG	0x01700000		// NMshift
	CMN RSR	0x01700010		// NMtypeS
	
	CMP IMM 0x03500000		// N imm
	CMP REG 0x01500000
	CMP RSR 0x01500010
	
	
	EOR IMM	0x02200000
	EOR REG	0x00200000
	EOR REG	0x00200010
	
	
	*/
	
#define DP_PARAMS   (eReg Rd, eReg Rn, ShiftOp Shift, ConditionCode CC=AL)
#define DP_RPARAMS  (eReg Rd, eReg Rn, eReg Rm, ConditionCode CC=AL)

#define DP_COMMON           \
    DECL_I;                 \
\
    SET_CC;                 \
    I |= (Rn&15)<<16;       \
    I |= (Rd&15)<<12;       \
    I |= (Shift&0xFFF)

#define DP_RCOMMON          \
    DECL_I;                 \
\
    SET_CC;                 \
    I |= (Rn&15)<<16;       \
    I |= (Rd&15)<<12;       \
    I |= (Rm&15)

#define DP_OPCODE(opcode)   \
    I |= (opcode)<<21

	
	
	EAPI	AND DP_PARAMS	{ DP_COMMON;	DP_OPCODE(DP_AND);	EMIT_I; }
	EAPI	EOR DP_PARAMS	{ DP_COMMON;	DP_OPCODE(DP_EOR);	EMIT_I; }
	EAPI	SUB DP_PARAMS	{ DP_COMMON;	DP_OPCODE(DP_SUB);	EMIT_I; }
	EAPI	RSB DP_PARAMS	{ DP_COMMON;	DP_OPCODE(DP_RSB);	EMIT_I; }
	EAPI	ADD DP_PARAMS	{ DP_COMMON;	DP_OPCODE(DP_ADD);	EMIT_I; }
	EAPI	ADC DP_PARAMS	{ DP_COMMON;	DP_OPCODE(DP_ADC);	EMIT_I; }
	EAPI	SBC DP_PARAMS	{ DP_COMMON;	DP_OPCODE(DP_SBC);	EMIT_I; }
	EAPI	RSC DP_PARAMS	{ DP_COMMON;	DP_OPCODE(DP_RSC);	EMIT_I; }
	EAPI	TST DP_PARAMS	{ DP_COMMON;	DP_OPCODE(DP_TST);	EMIT_I; }
	EAPI	TEQ DP_PARAMS	{ DP_COMMON;	DP_OPCODE(DP_TEQ);	EMIT_I; }
//	EAPI	CMP DP_PARAMS	{ DP_COMMON;	DP_OPCODE(DP_CMP);	EMIT_I; }
	EAPI	CMN DP_PARAMS	{ DP_COMMON;	DP_OPCODE(DP_CMN);	EMIT_I; }
	EAPI	ORR DP_PARAMS	{ DP_COMMON;	DP_OPCODE(DP_ORR);	EMIT_I; }
	EAPI	MOV DP_PARAMS	{ DP_COMMON;	DP_OPCODE(DP_MOV);	EMIT_I; }
	EAPI	BIC DP_PARAMS	{ DP_COMMON;	DP_OPCODE(DP_BIC);	EMIT_I; }
	EAPI	MVN DP_PARAMS	{ DP_COMMON;	DP_OPCODE(DP_MVN);	EMIT_I; }
	
#if defined(_DEVEL) && defined(_NODEF_)   // These require testing -> CMP/MOV Shifter(Reg)? fmt broken?		// Simple third reg type w/ no shifter
	EAPI	AND DP_PARAMS	{ DP_RCOMMON;	DP_OPCODE(DP_AND);	EMIT_I; }
	EAPI	EOR DP_PARAMS	{ DP_RCOMMON;	DP_OPCODE(DP_EOR);	EMIT_I; }
	EAPI	SUB DP_PARAMS	{ DP_RCOMMON;	DP_OPCODE(DP_SUB);	EMIT_I; }
	EAPI	RSB DP_PARAMS	{ DP_RCOMMON;	DP_OPCODE(DP_RSB);	EMIT_I; }
	EAPI	ADD DP_PARAMS	{ DP_RCOMMON;	DP_OPCODE(DP_ADD);	EMIT_I; }
	EAPI	ADC DP_PARAMS	{ DP_RCOMMON;	DP_OPCODE(DP_ADC);	EMIT_I; }
	EAPI	SBC DP_PARAMS	{ DP_RCOMMON;	DP_OPCODE(DP_SBC);	EMIT_I; }
	EAPI	RSC DP_PARAMS	{ DP_RCOMMON;	DP_OPCODE(DP_RSC);	EMIT_I; }
	EAPI	TST DP_PARAMS	{ DP_RCOMMON;	DP_OPCODE(DP_TST);	EMIT_I; }
	EAPI	TEQ DP_PARAMS	{ DP_RCOMMON;	DP_OPCODE(DP_TEQ);	EMIT_I; }
	EAPI	CMP DP_PARAMS	{ DP_RCOMMON;	DP_OPCODE(DP_CMP);	EMIT_I; }
	EAPI	CMN DP_PARAMS	{ DP_RCOMMON;	DP_OPCODE(DP_CMN);	EMIT_I; }
	EAPI	ORR DP_PARAMS	{ DP_RCOMMON;	DP_OPCODE(DP_ORR);	EMIT_I; }
	EAPI	MOV DP_PARAMS	{ DP_RCOMMON;	DP_OPCODE(DP_MOV);	EMIT_I; }
	EAPI	BIC DP_PARAMS	{ DP_RCOMMON;	DP_OPCODE(DP_BIC);	EMIT_I; }
	EAPI	MVN DP_PARAMS	{ DP_RCOMMON;	DP_OPCODE(DP_MVN);	EMIT_I; }
#endif



		static u32 ARMImmid8r4_enc(u32 imm32)
		{
			for (int i=0;i<=30;i+=2)
			{
				u32 immv=(imm32<<i) | (imm32>>(32-i));
				if (i == 0)
					immv = imm32;
				if (immv<256)
				{
					return ((i/2)<<8) | immv;
				}
			}

			return -1;
		}

		static u32 ARMImmid8r4(u32 imm8r4)
		{
			u32 rv = ARMImmid8r4_enc(imm8r4);

			verify(rv!=-1);
			return rv;
		}

		static bool is_i8r4(u32 i32) {	return ARMImmid8r4_enc(i32) != -1;	}

   

		EAPI ADD(eReg Rd, eReg Rn, eReg Rm, u32 RmLSL, bool S, ConditionCode CC=AL)
        {
            DECL_Id(0x00800000);

			if (S)
				I |= 1<<20;

			I |= (RmLSL&31)<<7;

            SET_CC;
            I |= (Rn&15)<<16;
            I |= (Rd&15)<<12;
            I |= (Rm&15);
            EMIT_I;
        }

		EAPI ADD(eReg Rd, eReg Rn, eReg Rm, bool S, ConditionCode CC=AL)
		{
			ADD(Rd,Rn,Rm,0,S,CC);
		}

		EAPI ADD(eReg Rd, eReg Rn, eReg Rm, ShiftOp Shift, u32 Imm8, ConditionCode CC=AL)
		{
            DECL_Id(0x00800000);
			
			SET_CC;
            I |= (Rn&15)<<16;
            I |= (Rd&15)<<12;
            I |= (Rm&15);
			I |= Shift<<5;
			I |= (Imm8&31)<<7;
			EMIT_I;
		}
		
		EAPI ADD(eReg Rd, eReg Rn, eReg Rm, ConditionCode CC=AL)
        {
			ADD(Rd,Rn,Rm,false,CC);
        }


        EAPI ADD(eReg Rd, eReg Rn, s32 Imm8, ConditionCode CC=AL)
        {
            DECL_Id(0x02800000);

            SET_CC;
            I |= (Rn&15)<<16;
            I |= (Rd&15)<<12;
            I |= ARMImmid8r4(Imm8);  // * 12b imm is 8b imm 4b rot. spec, add rot support!
            EMIT_I;
        }

		EAPI ADC(eReg Rd, eReg Rn, eReg Rm, bool S, ConditionCode CC=AL)
        {
            DECL_Id(0x00A00000);

			if (S)
				I |= 1<<20;

            SET_CC;
            I |= (Rn&15)<<16;
            I |= (Rd&15)<<12;
            I |= (Rm&15);
            EMIT_I;
        }

		EAPI ADC(eReg Rd, eReg Rn, eReg Rm, ConditionCode CC=AL)
        {
            ADC(Rd,Rn,Rm,false,CC);
        }

		EAPI ADC(eReg Rd, eReg Rn, s32 Imm8, ConditionCode CC=AL)
        {
            DECL_Id(0x02A00000);

            SET_CC;
            I |= (Rn&15)<<16;
            I |= (Rd&15)<<12;
            I |= ARMImmid8r4(Imm8);  // * 12b imm is 8b imm 4b rot. spec, add rot support!
            EMIT_I;
        }

		EAPI ADC(eReg Rd, eReg Rn, eReg Rm, bool S, ShiftOp Shift, u32 Imm8, ConditionCode CC=AL)
		{
			DECL_Id(0x00A00000);
			
			if (S)
			I |= 1<<20;
			
			SET_CC;
			I |= (Rn&15)<<16;
			I |= (Rd&15)<<12;
			I |= (Rm&15);
			I |= Shift<<5;
			I |= (Imm8&31)<<7;
			EMIT_I;
		}
		
	

        EAPI ADR(eReg Rd, s32 Imm8, ConditionCode CC=AL)
        {
            DECL_Id(0x028F0000);

            SET_CC;
            I |= (Rd&15)<<12;
            I |= ARMImmid8r4(Imm8);  // * 12b imm is 8b imm 4b rot. spec, add rot support!
            EMIT_I;
        }

        EAPI ADR_Zero(eReg Rd, s32 Imm8, ConditionCode CC=AL) // Special case for subtraction of 0
        {
            DECL_Id(0x024F0000);

            SET_CC;
            I |= (Rd&15)<<12;
            I |= ARMImmid8r4(Imm8);  // * 12b imm is 8b imm 4b rot. spec, add rot support!
            EMIT_I;
        }


        EAPI ORR(eReg Rd, eReg Rn, eReg Rm, ConditionCode CC=AL)
        {
            DECL_Id(0x01800000);

            SET_CC;
            I |= (Rn&15)<<16;
            I |= (Rd&15)<<12;
            I |= (Rm&15);
            EMIT_I;
        }

        EAPI ORR(eReg Rd, eReg Rn, s32 Imm8, ConditionCode CC=AL)
        {
            DECL_Id(0x03800000);

            SET_CC;
            I |= (Rn&15)<<16;
            I |= (Rd&15)<<12;
            I |= ARMImmid8r4(Imm8);  // * 12b imm is 8b imm 4b rot. spec, add rot support!
            EMIT_I;
        }
		
		EAPI ORR(eReg Rd, eReg Rn, eReg Rm, ShiftOp Shift, eReg Rs, ConditionCode CC=AL)
		{
			DECL_Id(0x01800000);
			
			SET_CC;
			I |= (Rn&15)<<16;
			I |= (Rd&15)<<12;
			I |= (Rm&15);
			I |= Shift<<5;
			I |= (Rs&15)<<8;
			I |= 1<<4;
			EMIT_I;
		}
	
		EAPI ORR(eReg Rd, eReg Rn, eReg Rm, bool S, ShiftOp Shift, u32 Imm8, ConditionCode CC=AL)
		{
			DECL_Id(0x01800000);
			
			if (S)
				I |= 1<<20;
			
			SET_CC;
			I |= (Rn&15)<<16;
			I |= (Rd&15)<<12;
			I |= (Rm&15);
			I |= Shift<<5;
			I |= (Imm8&31)<<7;
			EMIT_I;
		}
		
		EAPI AND(eReg Rd, eReg Rn, eReg Rm, bool S, ConditionCode CC=AL)
        {
            DECL_Id(0x00000000);

			if (S)
				I |= 1<<20;

            SET_CC;
            I |= (Rn&15)<<16;
            I |= (Rd&15)<<12;
            I |= (Rm&15);
            EMIT_I;
        }

        EAPI AND(eReg Rd, eReg Rn, eReg Rm, ConditionCode CC=AL)
        {
            DECL_Id(0x00000000);

            SET_CC;
            I |= (Rn&15)<<16;
            I |= (Rd&15)<<12;
            I |= (Rm&15);
            EMIT_I;
        }

        EAPI AND(eReg Rd, eReg Rn, s32 Imm8, ConditionCode CC=AL)
        {
            DECL_Id(0x02000000);

            SET_CC;
            I |= (Rn&15)<<16;
            I |= (Rd&15)<<12;
            I |= ARMImmid8r4(Imm8);  // * 12b imm is 8b imm 4b rot. spec, add rot support!
            EMIT_I;
        }

        EAPI AND(eReg Rd, eReg Rn, s32 Imm8, bool S, ConditionCode CC=AL)
        {
            DECL_Id(0x02000000);

			if (S)
				I |= 1<<20;

            SET_CC;
            I |= (Rn&15)<<16;
            I |= (Rd&15)<<12;
            I |= ARMImmid8r4(Imm8);  // * 12b imm is 8b imm 4b rot. spec, add rot support!
            EMIT_I;
        }


        EAPI EOR(eReg Rd, eReg Rn, eReg Rm, ConditionCode CC=AL)
        {
            DECL_Id(0x00200000);

            SET_CC;
            I |= (Rn&15)<<16;
            I |= (Rd&15)<<12;
            I |= (Rm&15);
            EMIT_I;
        }

         EAPI EOR(eReg Rd, eReg Rn, eReg Rm, bool S, ConditionCode CC=AL)
        {
            DECL_Id(0x00200000);

			if (S)
				I |= 1<<20;

            SET_CC;
            I |= (Rn&15)<<16;
            I |= (Rd&15)<<12;
            I |= (Rm&15);
            EMIT_I;
        }

        EAPI EOR(eReg Rd, eReg Rn, s32 Imm8, ConditionCode CC=AL)
        {
            DECL_Id(0x02200000);

            SET_CC;
            I |= (Rn&15)<<16;
            I |= (Rd&15)<<12;
            I |= ARMImmid8r4(Imm8);  // * 12b imm is 8b imm 4b rot. spec, add rot support!
            EMIT_I;
        }



        EAPI SUB(eReg Rd, eReg Rn, eReg Rm, ConditionCode CC=AL)
        {
            DECL_Id(0x00400000);

            SET_CC;
            I |= (Rn&15)<<16;
            I |= (Rd&15)<<12;
            I |= (Rm&15);
            EMIT_I;
        }

        EAPI SUB(eReg Rd, eReg Rn, s32 Imm8, bool S, ConditionCode CC=AL)
        {
            DECL_Id(0x02400000);

            SET_CC;
            I |= (Rn&15)<<16;
            I |= (Rd&15)<<12;
            I |= ARMImmid8r4(Imm8);  // * 12b imm is 8b imm 4b rot. spec, add rot support!
			if (S)
				I |= 1<<20;
            EMIT_I;
        }
		EAPI SUB(eReg Rd, eReg Rn, s32 Imm8, ConditionCode CC=AL) { SUB(Rd,Rn,Imm8,false,CC); }

		EAPI SBC(eReg Rd, eReg Rn, eReg Rm, bool S, ConditionCode CC=AL)
		{
			DECL_Id(0x00C00000);
			
			if (S)
			I |= 1<<20;
			
			SET_CC;
			I |= (Rn&15)<<16;
			I |= (Rd&15)<<12;
			I |= (Rm&15);
			EMIT_I;
		}
		
		EAPI SBC(eReg Rd, eReg Rn, eReg Rm, ConditionCode CC=AL)
		{
			SBC(Rd,Rn,Rm,false,CC);
		}
	
        EAPI RSB(eReg Rd, eReg Rn, eReg Rm, ConditionCode CC=AL)
        {
            DECL_Id(0x00600000);

            SET_CC;
            I |= (Rn&15)<<16;
            I |= (Rd&15)<<12;
            I |= (Rm&15);
            EMIT_I;
        }


        EAPI RSB(eReg Rd, eReg Rn, s32 Imm8, ConditionCode CC=AL)
        {
            DECL_Id(0x02600000);

            SET_CC;
            I |= (Rn&15)<<16;
            I |= (Rd&15)<<12;
            I |= ARMImmid8r4(Imm8);  // * 12b imm is 8b imm 4b rot. spec, add rot support!
            EMIT_I;
        }

        EAPI RSB(eReg Rd, eReg Rn, s32 Imm8, bool S, ConditionCode CC=AL)
        {
            DECL_Id(0x02600000);

			if (S)
			I |= 1<<20;
			
            SET_CC;
            I |= (Rn&15)<<16;
            I |= (Rd&15)<<12;
            I |= ARMImmid8r4(Imm8);  // * 12b imm is 8b imm 4b rot. spec, add rot support!
            EMIT_I;
        }


        EAPI MVN(eReg Rd, eReg Rm, ConditionCode CC=AL)
        {
            DECL_Id(0x01E00000);

            SET_CC;
            I |= (Rd&15)<<12;
            I |= (Rm&15);
            EMIT_I;
        }


        EAPI MVN(eReg Rd, s32 Imm8, ConditionCode CC=AL)
        {
            DECL_Id(0x03E00000);

            SET_CC;
            I |= (Rd&15)<<12;
            I |= ARMImmid8r4(Imm8);  // * 12b imm is 8b imm 4b rot. spec, add rot support!
            EMIT_I;
        }


        EAPI TST(eReg Rn, eReg Rm, ConditionCode CC=AL)
        {
            DECL_Id(0x01100000);

            SET_CC;
            I |= (Rn&15)<<16;
            I |= (Rm&15);
            EMIT_I;
        }


        EAPI TST(eReg Rn, u32 Imm12, ConditionCode CC=AL)
        {
            DECL_Id(0x03100000);

            SET_CC;
            I |= (Rn&15)<<16;
            I |= ARMImmid8r4(Imm12);
            EMIT_I;
        }

		EAPI BIC(eReg Rd, eReg Rn, s32 Imm8, ConditionCode CC=AL)
        {
            DECL_Id(0x03C00000);

            SET_CC;
            I |= (Rn&15)<<16;
            I |= (Rd&15)<<12;
            I |= ARMImmid8r4(Imm8);  // * 12b imm is 8b imm 4b rot. spec, add rot support!
            EMIT_I;
        }


		/*
		 *
		 */

		EAPI UBFX(eReg Rd, eReg Rm, u8 lsb, u8 width, ConditionCode CC=AL)
		{
			DECL_Id(0x07E00050);
			verify(lsb+width<=32);

			SET_CC;
			I |= (Rd&15)<<12;
			I |= (Rm&15);
			I |= (lsb&31)<<7;
		    I |= ((width-1)&31)<<16;
		 	EMIT_I;
		}

		EAPI MOV(eReg Rd, eReg Rm, ConditionCode CC=AL)
		{
			DECL_Id(0x01A00000);

			SET_CC;
			I |= (Rd&15)<<12;
			I |= (Rm&15);
			EMIT_I;
		}

		EAPI MOV(eReg Rd, eReg Rm, bool S, ConditionCode CC=AL)
		{
			DECL_Id(0x01A00000);
			
			if (S)
				I |= 1<<20;
			
			SET_CC;
			I |= (Rd&15)<<12;
			I |= (Rm&15);
			EMIT_I;
		}
		
		EAPI MOV(eReg Rd, eReg Rm, ShiftOp Shift, u32 Imm8, ConditionCode CC=AL)
		{
			DECL_Id(0x01A00000);
			
			SET_CC;
			I |= (Rd&15)<<12;
			I |= (Rm&15);
			I |= Shift<<5;
			I |= (Imm8&31)<<7;
			EMIT_I;
		}
		
		EAPI MOV(eReg Rd, eReg Rm, ShiftOp Shift, eReg Rs, ConditionCode CC=AL)
		{
			DECL_Id(0x01A00000);
			
			SET_CC;
			I |= (Rd&15)<<12;
			I |= (Rm&15);
			I |= Shift<<5;
			I |= (Rs&15)<<8;
			I |= 1<<4;
			EMIT_I;
		}
	
		EAPI MOVW(eReg Rd, u32 Imm16, ConditionCode CC=AL)
		{
			DECL_Id(0x03000000);

			SET_CC;
			I |= (Imm16&0xF000)<<4;
			I |= (Rd&15)<<12;
			I |= (Imm16&0x0FFF);
			EMIT_I;
		}

		EAPI MOVT(eReg Rd, u32 Imm16, ConditionCode CC=AL)
		{
			DECL_Id(0x03400000);

			SET_CC;
			I |= (Imm16&0xF000)<<4;
			I |= (Rd&15)<<12;
			I |= (Imm16&0x0FFF);
			EMIT_I;
		}
		
		EAPI MOV(eReg Rd, s32 Imm8, ConditionCode CC=AL)
		{
			DECL_Id(0x03A00000);
			
			SET_CC;
			I |= (Rd&15)<<12;
			I |= ARMImmid8r4(Imm8);  // * 12b imm is 8b imm 4b rot. spec, add rot support!
			EMIT_I;
		}
		
	



		EAPI CMP(eReg Rn, eReg Rm, ConditionCode CC=AL)
		{
			DECL_Id(0x01500000);

			SET_CC;
			I |= (Rn&15)<<16;
			I |= (Rm&15);
			EMIT_I;
		}


		EAPI CMP(eReg Rn, s32 Imm8, ConditionCode CC=AL)
		{
			DECL_Id(0x03500000);

			SET_CC;
			I |= (Rn&15)<<16;
			I |= ARMImmid8r4(Imm8);  // *FIXME* 12b imm is 8b imm 4b rot. spec, add rot support!
			EMIT_I;
		}

		EAPI CMP(eReg Rd, eReg Rm, ShiftOp Shift, eReg Rs, ConditionCode CC=AL)
		{
			DECL_Id(0x01500000);
			
			SET_CC;
			I |= (Rd&15)<<12;
			I |= (Rm&15);
			I |= Shift<<5;
			I |= (Rs&15)<<8;
			I |= 1<<4;
			EMIT_I;
		}
		
		EAPI CMP(eReg Rd, eReg Rm, ShiftOp Shift, u32 Imm8, ConditionCode CC=AL)
		{
			DECL_Id(0x01500000);
			
			SET_CC;
			I |= (Rd&15)<<12;
			I |= (Rm&15);
			I |= Shift<<5;
			I |= (Imm8&31)<<7;
			EMIT_I;
		}
		
		EAPI LSL(eReg Rd, eReg Rn, eReg Rm, ConditionCode CC=AL)
		{
			DECL_Id(0x01A00010);

			SET_CC;
			I |= (Rd&15)<<12;
			I |= (Rm&15)<<8;
			I |= (Rn&15)<<0;
			EMIT_I;
		}
		EAPI LSL(eReg Rd, eReg Rm, s32 imm5, ConditionCode CC=AL)
		{
			DECL_Id(0x01A00000);

			SET_CC;
			I |= (Rd&15)<<12;
			I |= (Rm&15)<<0;
			I |= (imm5&31)<<7;
			EMIT_I;
		}

		EAPI LSR(eReg Rd, eReg Rn, eReg Rm, ConditionCode CC=AL)
		{
			DECL_Id(0x01A00030);

			SET_CC;
			I |= (Rd&15)<<12;
			I |= (Rm&15)<<8;
			I |= (Rn&15)<<0;
			EMIT_I;
		}

		EAPI RRX(eReg Rd, eReg Rm,bool S=false, ConditionCode CC=AL)
		{
			DECL_Id(0x01A00060);

			if (S)
				I |= 1<<20;

			SET_CC;
			I |= (Rd&15)<<12;
			I |= (Rm&15)<<0;
			EMIT_I;
		}

		
		EAPI LSR(eReg Rd, eReg Rm, s32 imm5, bool S, ConditionCode CC=AL)
		{
			DECL_Id(0x01A00020);

			if (S)
				I |= 1<<20;

			SET_CC;
			I |= (Rd&15)<<12;
			I |= (Rm&15)<<0;
			I |= (imm5&31)<<7;
			EMIT_I;
		}

		EAPI LSR(eReg Rd, eReg Rm, s32 imm5, ConditionCode CC=AL)
		{
			LSR(Rd,Rm,imm5,false,CC);
		}


		EAPI ASR(eReg Rd, eReg Rn, eReg Rm, ConditionCode CC=AL)
		{
			DECL_Id(0x01A00050);

			SET_CC;
			I |= (Rd&15)<<12;
			I |= (Rm&15)<<8;
			I |= (Rn&15)<<0;
			EMIT_I;
		}

		EAPI ASR(eReg Rd, eReg Rm, s32 imm5, ConditionCode CC=AL)
		{
			DECL_Id(0x01A00040);

			SET_CC;
			I |= (Rd&15)<<12;
			I |= (Rm&15)<<0;
			I |= (imm5&31)<<7;
			EMIT_I;
		}

		EAPI ROR(eReg Rd, eReg Rn, eReg Rm, ConditionCode CC=AL)
		{
			DECL_Id(0x01A00070);

			SET_CC;
			I |= (Rd&15)<<12;
			I |= (Rm&15)<<8;
			I |= (Rn&15)<<0;
			EMIT_I;
		}

		EAPI ROR(eReg Rd, eReg Rm, s32 imm5, ConditionCode CC=AL)
		{
			DECL_Id(0x01A00060);

			SET_CC;
			I |= (Rd&15)<<12;
			I |= (Rm&15)<<0;
			I |= (imm5&31)<<7;
			EMIT_I;
		}




#undef DP_PARAMS
#undef DP_RPARAMS

#undef DP_COMMON
#undef DP_RCOMMON

#undef DP_OPCODE



};