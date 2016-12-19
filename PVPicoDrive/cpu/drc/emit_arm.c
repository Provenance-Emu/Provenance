/*
 * Basic macros to emit ARM instructions and some utils
 * Copyright (C) 2008,2009,2010 notaz
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */
#define CONTEXT_REG 11

// XXX: tcache_ptr type for SVP and SH2 compilers differs..
#define EMIT_PTR(ptr, x) \
	do { \
		*(u32 *)ptr = x; \
		ptr = (void *)((u8 *)ptr + sizeof(u32)); \
		COUNT_OP; \
	} while (0)

#define EMIT(x) EMIT_PTR(tcache_ptr, x)

#define A_R4M  (1 << 4)
#define A_R5M  (1 << 5)
#define A_R6M  (1 << 6)
#define A_R7M  (1 << 7)
#define A_R8M  (1 << 8)
#define A_R9M  (1 << 9)
#define A_R10M (1 << 10)
#define A_R11M (1 << 11)
#define A_R12M (1 << 12)
#define A_R14M (1 << 14)
#define A_R15M (1 << 15)

#define A_COND_AL 0xe
#define A_COND_EQ 0x0
#define A_COND_NE 0x1
#define A_COND_HS 0x2
#define A_COND_LO 0x3
#define A_COND_MI 0x4
#define A_COND_PL 0x5
#define A_COND_VS 0x6
#define A_COND_VC 0x7
#define A_COND_HI 0x8
#define A_COND_LS 0x9
#define A_COND_GE 0xa
#define A_COND_LT 0xb
#define A_COND_GT 0xc
#define A_COND_LE 0xd
#define A_COND_CS A_COND_HS
#define A_COND_CC A_COND_LO

/* unified conditions */
#define DCOND_EQ A_COND_EQ
#define DCOND_NE A_COND_NE
#define DCOND_MI A_COND_MI
#define DCOND_PL A_COND_PL
#define DCOND_HI A_COND_HI
#define DCOND_HS A_COND_HS
#define DCOND_LO A_COND_LO
#define DCOND_GE A_COND_GE
#define DCOND_GT A_COND_GT
#define DCOND_LT A_COND_LT
#define DCOND_LS A_COND_LS
#define DCOND_LE A_COND_LE
#define DCOND_VS A_COND_VS
#define DCOND_VC A_COND_VC

/* addressing mode 1 */
#define A_AM1_LSL 0
#define A_AM1_LSR 1
#define A_AM1_ASR 2
#define A_AM1_ROR 3

#define A_AM1_IMM(ror2,imm8)                  (((ror2)<<8) | (imm8) | 0x02000000)
#define A_AM1_REG_XIMM(shift_imm,shift_op,rm) (((shift_imm)<<7) | ((shift_op)<<5) | (rm))
#define A_AM1_REG_XREG(rs,shift_op,rm)        (((rs)<<8) | ((shift_op)<<5) | 0x10 | (rm))

/* data processing op */
#define A_OP_AND 0x0
#define A_OP_EOR 0x1
#define A_OP_SUB 0x2
#define A_OP_RSB 0x3
#define A_OP_ADD 0x4
#define A_OP_ADC 0x5
#define A_OP_SBC 0x6
#define A_OP_RSC 0x7
#define A_OP_TST 0x8
#define A_OP_TEQ 0x9
#define A_OP_CMP 0xa
#define A_OP_CMN 0xa
#define A_OP_ORR 0xc
#define A_OP_MOV 0xd
#define A_OP_BIC 0xe
#define A_OP_MVN 0xf

#define EOP_C_DOP_X(cond,op,s,rn,rd,shifter_op) \
	EMIT(((cond)<<28) | ((op)<< 21) | ((s)<<20) | ((rn)<<16) | ((rd)<<12) | (shifter_op))

#define EOP_C_DOP_IMM(     cond,op,s,rn,rd,ror2,imm8)             EOP_C_DOP_X(cond,op,s,rn,rd,A_AM1_IMM(ror2,imm8))
#define EOP_C_DOP_REG_XIMM(cond,op,s,rn,rd,shift_imm,shift_op,rm) EOP_C_DOP_X(cond,op,s,rn,rd,A_AM1_REG_XIMM(shift_imm,shift_op,rm))
#define EOP_C_DOP_REG_XREG(cond,op,s,rn,rd,rs,       shift_op,rm) EOP_C_DOP_X(cond,op,s,rn,rd,A_AM1_REG_XREG(rs,       shift_op,rm))

#define EOP_MOV_IMM(rd,   ror2,imm8) EOP_C_DOP_IMM(A_COND_AL,A_OP_MOV,0, 0,rd,ror2,imm8)
#define EOP_MVN_IMM(rd,   ror2,imm8) EOP_C_DOP_IMM(A_COND_AL,A_OP_MVN,0, 0,rd,ror2,imm8)
#define EOP_ORR_IMM(rd,rn,ror2,imm8) EOP_C_DOP_IMM(A_COND_AL,A_OP_ORR,0,rn,rd,ror2,imm8)
#define EOP_EOR_IMM(rd,rn,ror2,imm8) EOP_C_DOP_IMM(A_COND_AL,A_OP_EOR,0,rn,rd,ror2,imm8)
#define EOP_ADD_IMM(rd,rn,ror2,imm8) EOP_C_DOP_IMM(A_COND_AL,A_OP_ADD,0,rn,rd,ror2,imm8)
#define EOP_BIC_IMM(rd,rn,ror2,imm8) EOP_C_DOP_IMM(A_COND_AL,A_OP_BIC,0,rn,rd,ror2,imm8)
#define EOP_AND_IMM(rd,rn,ror2,imm8) EOP_C_DOP_IMM(A_COND_AL,A_OP_AND,0,rn,rd,ror2,imm8)
#define EOP_SUB_IMM(rd,rn,ror2,imm8) EOP_C_DOP_IMM(A_COND_AL,A_OP_SUB,0,rn,rd,ror2,imm8)
#define EOP_TST_IMM(   rn,ror2,imm8) EOP_C_DOP_IMM(A_COND_AL,A_OP_TST,1,rn, 0,ror2,imm8)
#define EOP_CMP_IMM(   rn,ror2,imm8) EOP_C_DOP_IMM(A_COND_AL,A_OP_CMP,1,rn, 0,ror2,imm8)
#define EOP_RSB_IMM(rd,rn,ror2,imm8) EOP_C_DOP_IMM(A_COND_AL,A_OP_RSB,0,rn,rd,ror2,imm8)

#define EOP_MOV_IMM_C(cond,rd,   ror2,imm8) EOP_C_DOP_IMM(cond,A_OP_MOV,0, 0,rd,ror2,imm8)
#define EOP_ORR_IMM_C(cond,rd,rn,ror2,imm8) EOP_C_DOP_IMM(cond,A_OP_ORR,0,rn,rd,ror2,imm8)
#define EOP_RSB_IMM_C(cond,rd,rn,ror2,imm8) EOP_C_DOP_IMM(cond,A_OP_RSB,0,rn,rd,ror2,imm8)

#define EOP_MOV_REG(cond,s,rd,   rm,shift_op,shift_imm) EOP_C_DOP_REG_XIMM(cond,A_OP_MOV,s, 0,rd,shift_imm,shift_op,rm)
#define EOP_MVN_REG(cond,s,rd,   rm,shift_op,shift_imm) EOP_C_DOP_REG_XIMM(cond,A_OP_MVN,s, 0,rd,shift_imm,shift_op,rm)
#define EOP_ORR_REG(cond,s,rd,rn,rm,shift_op,shift_imm) EOP_C_DOP_REG_XIMM(cond,A_OP_ORR,s,rn,rd,shift_imm,shift_op,rm)
#define EOP_ADD_REG(cond,s,rd,rn,rm,shift_op,shift_imm) EOP_C_DOP_REG_XIMM(cond,A_OP_ADD,s,rn,rd,shift_imm,shift_op,rm)
#define EOP_ADC_REG(cond,s,rd,rn,rm,shift_op,shift_imm) EOP_C_DOP_REG_XIMM(cond,A_OP_ADC,s,rn,rd,shift_imm,shift_op,rm)
#define EOP_SUB_REG(cond,s,rd,rn,rm,shift_op,shift_imm) EOP_C_DOP_REG_XIMM(cond,A_OP_SUB,s,rn,rd,shift_imm,shift_op,rm)
#define EOP_SBC_REG(cond,s,rd,rn,rm,shift_op,shift_imm) EOP_C_DOP_REG_XIMM(cond,A_OP_SBC,s,rn,rd,shift_imm,shift_op,rm)
#define EOP_AND_REG(cond,s,rd,rn,rm,shift_op,shift_imm) EOP_C_DOP_REG_XIMM(cond,A_OP_AND,s,rn,rd,shift_imm,shift_op,rm)
#define EOP_EOR_REG(cond,s,rd,rn,rm,shift_op,shift_imm) EOP_C_DOP_REG_XIMM(cond,A_OP_EOR,s,rn,rd,shift_imm,shift_op,rm)
#define EOP_CMP_REG(cond,     rn,rm,shift_op,shift_imm) EOP_C_DOP_REG_XIMM(cond,A_OP_CMP,1,rn, 0,shift_imm,shift_op,rm)
#define EOP_TST_REG(cond,     rn,rm,shift_op,shift_imm) EOP_C_DOP_REG_XIMM(cond,A_OP_TST,1,rn, 0,shift_imm,shift_op,rm)
#define EOP_TEQ_REG(cond,     rn,rm,shift_op,shift_imm) EOP_C_DOP_REG_XIMM(cond,A_OP_TEQ,1,rn, 0,shift_imm,shift_op,rm)

#define EOP_MOV_REG2(s,rd,   rm,shift_op,rs) EOP_C_DOP_REG_XREG(A_COND_AL,A_OP_MOV,s, 0,rd,rs,shift_op,rm)
#define EOP_ADD_REG2(s,rd,rn,rm,shift_op,rs) EOP_C_DOP_REG_XREG(A_COND_AL,A_OP_ADD,s,rn,rd,rs,shift_op,rm)
#define EOP_SUB_REG2(s,rd,rn,rm,shift_op,rs) EOP_C_DOP_REG_XREG(A_COND_AL,A_OP_SUB,s,rn,rd,rs,shift_op,rm)

#define EOP_MOV_REG_SIMPLE(rd,rm)           EOP_MOV_REG(A_COND_AL,0,rd,rm,A_AM1_LSL,0)
#define EOP_MOV_REG_LSL(rd,   rm,shift_imm) EOP_MOV_REG(A_COND_AL,0,rd,rm,A_AM1_LSL,shift_imm)
#define EOP_MOV_REG_LSR(rd,   rm,shift_imm) EOP_MOV_REG(A_COND_AL,0,rd,rm,A_AM1_LSR,shift_imm)
#define EOP_MOV_REG_ASR(rd,   rm,shift_imm) EOP_MOV_REG(A_COND_AL,0,rd,rm,A_AM1_ASR,shift_imm)
#define EOP_MOV_REG_ROR(rd,   rm,shift_imm) EOP_MOV_REG(A_COND_AL,0,rd,rm,A_AM1_ROR,shift_imm)

#define EOP_ORR_REG_SIMPLE(rd,rm)           EOP_ORR_REG(A_COND_AL,0,rd,rd,rm,A_AM1_LSL,0)
#define EOP_ORR_REG_LSL(rd,rn,rm,shift_imm) EOP_ORR_REG(A_COND_AL,0,rd,rn,rm,A_AM1_LSL,shift_imm)
#define EOP_ORR_REG_LSR(rd,rn,rm,shift_imm) EOP_ORR_REG(A_COND_AL,0,rd,rn,rm,A_AM1_LSR,shift_imm)
#define EOP_ORR_REG_ASR(rd,rn,rm,shift_imm) EOP_ORR_REG(A_COND_AL,0,rd,rn,rm,A_AM1_ASR,shift_imm)
#define EOP_ORR_REG_ROR(rd,rn,rm,shift_imm) EOP_ORR_REG(A_COND_AL,0,rd,rn,rm,A_AM1_ROR,shift_imm)

#define EOP_ADD_REG_SIMPLE(rd,rm)           EOP_ADD_REG(A_COND_AL,0,rd,rd,rm,A_AM1_LSL,0)
#define EOP_ADD_REG_LSL(rd,rn,rm,shift_imm) EOP_ADD_REG(A_COND_AL,0,rd,rn,rm,A_AM1_LSL,shift_imm)
#define EOP_ADD_REG_LSR(rd,rn,rm,shift_imm) EOP_ADD_REG(A_COND_AL,0,rd,rn,rm,A_AM1_LSR,shift_imm)

#define EOP_TST_REG_SIMPLE(rn,rm)           EOP_TST_REG(A_COND_AL,  rn,   0,A_AM1_LSL,rm)

#define EOP_MOV_REG2_LSL(rd,   rm,rs)       EOP_MOV_REG2(0,rd,   rm,A_AM1_LSL,rs)
#define EOP_MOV_REG2_ROR(rd,   rm,rs)       EOP_MOV_REG2(0,rd,   rm,A_AM1_ROR,rs)
#define EOP_ADD_REG2_LSL(rd,rn,rm,rs)       EOP_ADD_REG2(0,rd,rn,rm,A_AM1_LSL,rs)
#define EOP_SUB_REG2_LSL(rd,rn,rm,rs)       EOP_SUB_REG2(0,rd,rn,rm,A_AM1_LSL,rs)

/* addressing mode 2 */
#define EOP_C_AM2_IMM(cond,u,b,l,rn,rd,offset_12) \
	EMIT(((cond)<<28) | 0x05000000 | ((u)<<23) | ((b)<<22) | ((l)<<20) | ((rn)<<16) | ((rd)<<12) | (offset_12))

#define EOP_C_AM2_REG(cond,u,b,l,rn,rd,shift_imm,shift_op,rm) \
	EMIT(((cond)<<28) | 0x07000000 | ((u)<<23) | ((b)<<22) | ((l)<<20) | ((rn)<<16) | ((rd)<<12) | \
		((shift_imm)<<7) | ((shift_op)<<5) | (rm))

/* addressing mode 3 */
#define EOP_C_AM3(cond,u,r,l,rn,rd,s,h,immed_reg) \
	EMIT(((cond)<<28) | 0x01000090 | ((u)<<23) | ((r)<<22) | ((l)<<20) | ((rn)<<16) | ((rd)<<12) | \
			((s)<<6) | ((h)<<5) | (immed_reg))

#define EOP_C_AM3_IMM(cond,u,l,rn,rd,s,h,offset_8) EOP_C_AM3(cond,u,1,l,rn,rd,s,h,(((offset_8)&0xf0)<<4)|((offset_8)&0xf))

#define EOP_C_AM3_REG(cond,u,l,rn,rd,s,h,rm)       EOP_C_AM3(cond,u,0,l,rn,rd,s,h,rm)

/* ldr and str */
#define EOP_LDR_IMM2(cond,rd,rn,offset_12)  EOP_C_AM2_IMM(cond,1,0,1,rn,rd,offset_12)
#define EOP_LDRB_IMM2(cond,rd,rn,offset_12) EOP_C_AM2_IMM(cond,1,1,1,rn,rd,offset_12)

#define EOP_LDR_IMM(   rd,rn,offset_12) EOP_C_AM2_IMM(A_COND_AL,1,0,1,rn,rd,offset_12)
#define EOP_LDR_NEGIMM(rd,rn,offset_12) EOP_C_AM2_IMM(A_COND_AL,0,0,1,rn,rd,offset_12)
#define EOP_LDR_SIMPLE(rd,rn)           EOP_C_AM2_IMM(A_COND_AL,1,0,1,rn,rd,0)
#define EOP_STR_IMM(   rd,rn,offset_12) EOP_C_AM2_IMM(A_COND_AL,1,0,0,rn,rd,offset_12)
#define EOP_STR_SIMPLE(rd,rn)           EOP_C_AM2_IMM(A_COND_AL,1,0,0,rn,rd,0)

#define EOP_LDR_REG_LSL(cond,rd,rn,rm,shift_imm) EOP_C_AM2_REG(cond,1,0,1,rn,rd,shift_imm,A_AM1_LSL,rm)

#define EOP_LDRH_IMM2(cond,rd,rn,offset_8)  EOP_C_AM3_IMM(cond,1,1,rn,rd,0,1,offset_8)

#define EOP_LDRH_IMM(   rd,rn,offset_8)  EOP_C_AM3_IMM(A_COND_AL,1,1,rn,rd,0,1,offset_8)
#define EOP_LDRH_SIMPLE(rd,rn)           EOP_C_AM3_IMM(A_COND_AL,1,1,rn,rd,0,1,0)
#define EOP_LDRH_REG(   rd,rn,rm)        EOP_C_AM3_REG(A_COND_AL,1,1,rn,rd,0,1,rm)
#define EOP_STRH_IMM(   rd,rn,offset_8)  EOP_C_AM3_IMM(A_COND_AL,1,0,rn,rd,0,1,offset_8)
#define EOP_STRH_SIMPLE(rd,rn)           EOP_C_AM3_IMM(A_COND_AL,1,0,rn,rd,0,1,0)
#define EOP_STRH_REG(   rd,rn,rm)        EOP_C_AM3_REG(A_COND_AL,1,0,rn,rd,0,1,rm)

/* ldm and stm */
#define EOP_XXM(cond,p,u,s,w,l,rn,list) \
	EMIT(((cond)<<28) | (1<<27) | ((p)<<24) | ((u)<<23) | ((s)<<22) | ((w)<<21) | ((l)<<20) | ((rn)<<16) | (list))

#define EOP_STMIA(rb,list) EOP_XXM(A_COND_AL,0,1,0,0,0,rb,list)
#define EOP_LDMIA(rb,list) EOP_XXM(A_COND_AL,0,1,0,0,1,rb,list)

#define EOP_STMFD_SP(list) EOP_XXM(A_COND_AL,1,0,0,1,0,13,list)
#define EOP_LDMFD_SP(list) EOP_XXM(A_COND_AL,0,1,0,1,1,13,list)

/* branches */
#define EOP_C_BX(cond,rm) \
	EMIT(((cond)<<28) | 0x012fff10 | (rm))

#define EOP_C_B_PTR(ptr,cond,l,signed_immed_24) \
	EMIT_PTR(ptr, ((cond)<<28) | 0x0a000000 | ((l)<<24) | (signed_immed_24))

#define EOP_C_B(cond,l,signed_immed_24) \
	EOP_C_B_PTR(tcache_ptr,cond,l,signed_immed_24)

#define EOP_B( signed_immed_24) EOP_C_B(A_COND_AL,0,signed_immed_24)
#define EOP_BL(signed_immed_24) EOP_C_B(A_COND_AL,1,signed_immed_24)

/* misc */
#define EOP_C_MUL(cond,s,rd,rs,rm) \
	EMIT(((cond)<<28) | ((s)<<20) | ((rd)<<16) | ((rs)<<8) | 0x90 | (rm))

#define EOP_C_UMULL(cond,s,rdhi,rdlo,rs,rm) \
	EMIT(((cond)<<28) | 0x00800000 | ((s)<<20) | ((rdhi)<<16) | ((rdlo)<<12) | ((rs)<<8) | 0x90 | (rm))

#define EOP_C_SMULL(cond,s,rdhi,rdlo,rs,rm) \
	EMIT(((cond)<<28) | 0x00c00000 | ((s)<<20) | ((rdhi)<<16) | ((rdlo)<<12) | ((rs)<<8) | 0x90 | (rm))

#define EOP_C_SMLAL(cond,s,rdhi,rdlo,rs,rm) \
	EMIT(((cond)<<28) | 0x00e00000 | ((s)<<20) | ((rdhi)<<16) | ((rdlo)<<12) | ((rs)<<8) | 0x90 | (rm))

#define EOP_MUL(rd,rm,rs) EOP_C_MUL(A_COND_AL,0,rd,rs,rm) // note: rd != rm

#define EOP_C_MRS(cond,rd) \
	EMIT(((cond)<<28) | 0x010f0000 | ((rd)<<12))

#define EOP_C_MSR_IMM(cond,ror2,imm) \
	EMIT(((cond)<<28) | 0x0328f000 | ((ror2)<<8) | (imm)) // cpsr_f

#define EOP_C_MSR_REG(cond,rm) \
	EMIT(((cond)<<28) | 0x0128f000 | (rm)) // cpsr_f

#define EOP_MRS(rd)           EOP_C_MRS(A_COND_AL,rd)
#define EOP_MSR_IMM(ror2,imm) EOP_C_MSR_IMM(A_COND_AL,ror2,imm)
#define EOP_MSR_REG(rm)       EOP_C_MSR_REG(A_COND_AL,rm)


// XXX: AND, RSB, *C, will break if 1 insn is not enough
static void emith_op_imm2(int cond, int s, int op, int rd, int rn, unsigned int imm)
{
	int ror2;
	u32 v;

	switch (op) {
	case A_OP_MOV:
		rn = 0;
		if (~imm < 0x10000) {
			imm = ~imm;
			op = A_OP_MVN;
		}
		break;

	case A_OP_EOR:
	case A_OP_SUB:
	case A_OP_ADD:
	case A_OP_ORR:
	case A_OP_BIC:
		if (s == 0 && imm == 0)
			return;
		break;
	}

	for (v = imm, ror2 = 0; ; ror2 -= 8/2) {
		/* shift down to get 'best' rot2 */
		for (; v && !(v & 3); v >>= 2)
			ror2--;

		EOP_C_DOP_IMM(cond, op, s, rn, rd, ror2 & 0x0f, v & 0xff);

		v >>= 8;
		if (v == 0)
			break;
		if (op == A_OP_MOV)
			op = A_OP_ORR;
		if (op == A_OP_MVN)
			op = A_OP_BIC;
		rn = rd;
	}
}

#define emith_op_imm(cond, s, op, r, imm) \
	emith_op_imm2(cond, s, op, r, r, imm)

// test op
#define emith_top_imm(cond, op, r, imm) do { \
	u32 ror2, v; \
	for (ror2 = 0, v = imm; v && !(v & 3); v >>= 2) \
		ror2--; \
	EOP_C_DOP_IMM(cond, op, 1, r, 0, ror2 & 0x0f, v & 0xff); \
} while (0)

#define is_offset_24(val) \
	((val) >= (int)0xff000000 && (val) <= 0x00ffffff)

static int emith_xbranch(int cond, void *target, int is_call)
{
	int val = (u32 *)target - (u32 *)tcache_ptr - 2;
	int direct = is_offset_24(val);
	u32 *start_ptr = (u32 *)tcache_ptr;

	if (direct)
	{
		EOP_C_B(cond,is_call,val & 0xffffff);		// b, bl target
	}
	else
	{
#ifdef __EPOC32__
//		elprintf(EL_SVP, "emitting indirect jmp %08x->%08x", tcache_ptr, target);
		if (is_call)
			EOP_ADD_IMM(14,15,0,8);			// add lr,pc,#8
		EOP_C_AM2_IMM(cond,1,0,1,15,15,0);		// ldrcc pc,[pc]
		EOP_MOV_REG_SIMPLE(15,15);			// mov pc, pc
		EMIT((u32)target);
#else
		// should never happen
		elprintf(EL_STATUS|EL_SVP|EL_ANOMALY, "indirect jmp %08x->%08x", target, tcache_ptr);
		exit(1);
#endif
	}

	return (u32 *)tcache_ptr - start_ptr;
}

#define JMP_POS(ptr) \
	ptr = tcache_ptr; \
	tcache_ptr += sizeof(u32)

#define JMP_EMIT(cond, ptr) { \
	u32 val_ = (u32 *)tcache_ptr - (u32 *)(ptr) - 2; \
	EOP_C_B_PTR(ptr, cond, 0, val_ & 0xffffff); \
}

#define EMITH_JMP_START(cond) { \
	void *cond_ptr; \
	JMP_POS(cond_ptr)

#define EMITH_JMP_END(cond) \
	JMP_EMIT(cond, cond_ptr); \
}

// fake "simple" or "short" jump - using cond insns instead
#define EMITH_NOTHING1(cond) \
	(void)(cond)

#define EMITH_SJMP_START(cond)	EMITH_NOTHING1(cond)
#define EMITH_SJMP_END(cond)	EMITH_NOTHING1(cond)
#define EMITH_SJMP3_START(cond)	EMITH_NOTHING1(cond)
#define EMITH_SJMP3_MID(cond)	EMITH_NOTHING1(cond)
#define EMITH_SJMP3_END()

#define emith_move_r_r(d, s) \
	EOP_MOV_REG_SIMPLE(d, s)

#define emith_mvn_r_r(d, s) \
	EOP_MVN_REG(A_COND_AL,0,d,s,A_AM1_LSL,0)

#define emith_add_r_r_r_lsl(d, s1, s2, lslimm) \
	EOP_ADD_REG(A_COND_AL,0,d,s1,s2,A_AM1_LSL,lslimm)

#define emith_or_r_r_r_lsl(d, s1, s2, lslimm) \
	EOP_ORR_REG(A_COND_AL,0,d,s1,s2,A_AM1_LSL,lslimm)

#define emith_eor_r_r_r_lsl(d, s1, s2, lslimm) \
	EOP_EOR_REG(A_COND_AL,0,d,s1,s2,A_AM1_LSL,lslimm)

#define emith_eor_r_r_r_lsr(d, s1, s2, lsrimm) \
	EOP_EOR_REG(A_COND_AL,0,d,s1,s2,A_AM1_LSR,lsrimm)

#define emith_or_r_r_lsl(d, s, lslimm) \
	emith_or_r_r_r_lsl(d, d, s, lslimm)

#define emith_eor_r_r_lsr(d, s, lsrimm) \
	emith_eor_r_r_r_lsr(d, d, s, lsrimm)

#define emith_add_r_r_r(d, s1, s2) \
	emith_add_r_r_r_lsl(d, s1, s2, 0)

#define emith_or_r_r_r(d, s1, s2) \
	emith_or_r_r_r_lsl(d, s1, s2, 0)

#define emith_eor_r_r_r(d, s1, s2) \
	emith_eor_r_r_r_lsl(d, s1, s2, 0)

#define emith_add_r_r(d, s) \
	emith_add_r_r_r(d, d, s)

#define emith_sub_r_r(d, s) \
	EOP_SUB_REG(A_COND_AL,0,d,d,s,A_AM1_LSL,0)

#define emith_adc_r_r(d, s) \
	EOP_ADC_REG(A_COND_AL,0,d,d,s,A_AM1_LSL,0)

#define emith_and_r_r(d, s) \
	EOP_AND_REG(A_COND_AL,0,d,d,s,A_AM1_LSL,0)

#define emith_or_r_r(d, s) \
	emith_or_r_r_r(d, d, s)

#define emith_eor_r_r(d, s) \
	emith_eor_r_r_r(d, d, s)

#define emith_tst_r_r(d, s) \
	EOP_TST_REG(A_COND_AL,d,s,A_AM1_LSL,0)

#define emith_teq_r_r(d, s) \
	EOP_TEQ_REG(A_COND_AL,d,s,A_AM1_LSL,0)

#define emith_cmp_r_r(d, s) \
	EOP_CMP_REG(A_COND_AL,d,s,A_AM1_LSL,0)

#define emith_addf_r_r(d, s) \
	EOP_ADD_REG(A_COND_AL,1,d,d,s,A_AM1_LSL,0)

#define emith_subf_r_r(d, s) \
	EOP_SUB_REG(A_COND_AL,1,d,d,s,A_AM1_LSL,0)

#define emith_adcf_r_r(d, s) \
	EOP_ADC_REG(A_COND_AL,1,d,d,s,A_AM1_LSL,0)

#define emith_sbcf_r_r(d, s) \
	EOP_SBC_REG(A_COND_AL,1,d,d,s,A_AM1_LSL,0)

#define emith_eorf_r_r(d, s) \
	EOP_EOR_REG(A_COND_AL,1,d,d,s,A_AM1_LSL,0)

#define emith_move_r_imm(r, imm) \
	emith_op_imm(A_COND_AL, 0, A_OP_MOV, r, imm)

#define emith_add_r_imm(r, imm) \
	emith_op_imm(A_COND_AL, 0, A_OP_ADD, r, imm)

#define emith_adc_r_imm(r, imm) \
	emith_op_imm(A_COND_AL, 0, A_OP_ADC, r, imm)

#define emith_sub_r_imm(r, imm) \
	emith_op_imm(A_COND_AL, 0, A_OP_SUB, r, imm)

#define emith_bic_r_imm(r, imm) \
	emith_op_imm(A_COND_AL, 0, A_OP_BIC, r, imm)

#define emith_and_r_imm(r, imm) \
	emith_op_imm(A_COND_AL, 0, A_OP_AND, r, imm)

#define emith_or_r_imm(r, imm) \
	emith_op_imm(A_COND_AL, 0, A_OP_ORR, r, imm)

#define emith_eor_r_imm(r, imm) \
	emith_op_imm(A_COND_AL, 0, A_OP_EOR, r, imm)

// note: only use 8bit imm for these
#define emith_tst_r_imm(r, imm) \
	emith_top_imm(A_COND_AL, A_OP_TST, r, imm)

#define emith_cmp_r_imm(r, imm) { \
	u32 op = A_OP_CMP, imm_ = imm; \
	if (~imm_ < 0x100) { \
		imm_ = ~imm_; \
		op = A_OP_CMN; \
	} \
	emith_top_imm(A_COND_AL, op, r, imm); \
}

#define emith_subf_r_imm(r, imm) \
	emith_op_imm(A_COND_AL, 1, A_OP_SUB, r, imm)

#define emith_move_r_imm_c(cond, r, imm) \
	emith_op_imm(cond, 0, A_OP_MOV, r, imm)

#define emith_add_r_imm_c(cond, r, imm) \
	emith_op_imm(cond, 0, A_OP_ADD, r, imm)

#define emith_sub_r_imm_c(cond, r, imm) \
	emith_op_imm(cond, 0, A_OP_SUB, r, imm)

#define emith_or_r_imm_c(cond, r, imm) \
	emith_op_imm(cond, 0, A_OP_ORR, r, imm)

#define emith_eor_r_imm_c(cond, r, imm) \
	emith_op_imm(cond, 0, A_OP_EOR, r, imm)

#define emith_bic_r_imm_c(cond, r, imm) \
	emith_op_imm(cond, 0, A_OP_BIC, r, imm)

#define emith_move_r_imm_s8(r, imm) { \
	if ((imm) & 0x80) \
		EOP_MVN_IMM(r, 0, ((imm) ^ 0xff)); \
	else \
		EOP_MOV_IMM(r, 0, imm); \
}

#define emith_and_r_r_imm(d, s, imm) \
	emith_op_imm2(A_COND_AL, 0, A_OP_AND, d, s, imm)

#define emith_add_r_r_imm(d, s, imm) \
	emith_op_imm2(A_COND_AL, 0, A_OP_ADD, d, s, imm)

#define emith_sub_r_r_imm(d, s, imm) \
	emith_op_imm2(A_COND_AL, 0, A_OP_SUB, d, s, imm)

#define emith_neg_r_r(d, s) \
	EOP_RSB_IMM(d, s, 0, 0)

#define emith_lsl(d, s, cnt) \
	EOP_MOV_REG(A_COND_AL,0,d,s,A_AM1_LSL,cnt)

#define emith_lsr(d, s, cnt) \
	EOP_MOV_REG(A_COND_AL,0,d,s,A_AM1_LSR,cnt)

#define emith_asr(d, s, cnt) \
	EOP_MOV_REG(A_COND_AL,0,d,s,A_AM1_ASR,cnt)

#define emith_ror_c(cond, d, s, cnt) \
	EOP_MOV_REG(cond,0,d,s,A_AM1_ROR,cnt)

#define emith_ror(d, s, cnt) \
	emith_ror_c(A_COND_AL, d, s, cnt)

#define emith_rol(d, s, cnt) \
	EOP_MOV_REG(A_COND_AL,0,d,s,A_AM1_ROR,32-(cnt)); \

#define emith_lslf(d, s, cnt) \
	EOP_MOV_REG(A_COND_AL,1,d,s,A_AM1_LSL,cnt)

#define emith_lsrf(d, s, cnt) \
	EOP_MOV_REG(A_COND_AL,1,d,s,A_AM1_LSR,cnt)

#define emith_asrf(d, s, cnt) \
	EOP_MOV_REG(A_COND_AL,1,d,s,A_AM1_ASR,cnt)

// note: only C flag updated correctly
#define emith_rolf(d, s, cnt) { \
	EOP_MOV_REG(A_COND_AL,1,d,s,A_AM1_ROR,32-(cnt)); \
	/* we don't have ROL so we shift to get the right carry */ \
	EOP_TST_REG(A_COND_AL,d,d,A_AM1_LSR,1); \
}

#define emith_rorf(d, s, cnt) \
	EOP_MOV_REG(A_COND_AL,1,d,s,A_AM1_ROR,cnt)

#define emith_rolcf(d) \
	emith_adcf_r_r(d, d)

#define emith_rorcf(d) \
	EOP_MOV_REG(A_COND_AL,1,d,d,A_AM1_ROR,0) /* ROR #0 -> RRX */

#define emith_negcf_r_r(d, s) \
	EOP_C_DOP_IMM(A_COND_AL,A_OP_RSC,1,s,d,0,0)

#define emith_mul(d, s1, s2) { \
	if ((d) != (s1)) /* rd != rm limitation */ \
		EOP_MUL(d, s1, s2); \
	else \
		EOP_MUL(d, s2, s1); \
}

#define emith_mul_u64(dlo, dhi, s1, s2) \
	EOP_C_UMULL(A_COND_AL,0,dhi,dlo,s1,s2)

#define emith_mul_s64(dlo, dhi, s1, s2) \
	EOP_C_SMULL(A_COND_AL,0,dhi,dlo,s1,s2)

#define emith_mula_s64(dlo, dhi, s1, s2) \
	EOP_C_SMLAL(A_COND_AL,0,dhi,dlo,s1,s2)

// misc
#define emith_read_r_r_offs_c(cond, r, rs, offs) \
	EOP_LDR_IMM2(cond, r, rs, offs)

#define emith_read8_r_r_offs_c(cond, r, rs, offs) \
	EOP_LDRB_IMM2(cond, r, rs, offs)

#define emith_read16_r_r_offs_c(cond, r, rs, offs) \
	EOP_LDRH_IMM2(cond, r, rs, offs)

#define emith_read_r_r_offs(r, rs, offs) \
	emith_read_r_r_offs_c(A_COND_AL, r, rs, offs)

#define emith_read8_r_r_offs(r, rs, offs) \
	emith_read8_r_r_offs_c(A_COND_AL, r, rs, offs)

#define emith_read16_r_r_offs(r, rs, offs) \
	emith_read16_r_r_offs_c(A_COND_AL, r, rs, offs)

#define emith_ctx_read(r, offs) \
	emith_read_r_r_offs(r, CONTEXT_REG, offs)

#define emith_ctx_write(r, offs) \
	EOP_STR_IMM(r, CONTEXT_REG, offs)

#define emith_ctx_do_multiple(op, r, offs, count, tmpr) do { \
	int v_, r_ = r, c_ = count, b_ = CONTEXT_REG;        \
	for (v_ = 0; c_; c_--, r_++)                         \
		v_ |= 1 << r_;                               \
	if ((offs) != 0) {                                   \
		EOP_ADD_IMM(tmpr,CONTEXT_REG,30/2,(offs)>>2);\
		b_ = tmpr;                                   \
	}                                                    \
	op(b_,v_);                                           \
} while(0)

#define emith_ctx_read_multiple(r, offs, count, tmpr) \
	emith_ctx_do_multiple(EOP_LDMIA, r, offs, count, tmpr)

#define emith_ctx_write_multiple(r, offs, count, tmpr) \
	emith_ctx_do_multiple(EOP_STMIA, r, offs, count, tmpr)

#define emith_clear_msb_c(cond, d, s, count) { \
	u32 t; \
	if ((count) <= 8) { \
		t = (count) - 8; \
		t = (0xff << t) & 0xff; \
		EOP_BIC_IMM(d,s,8/2,t); \
		EOP_C_DOP_IMM(cond,A_OP_BIC,0,s,d,8/2,t); \
	} else if ((count) >= 24) { \
		t = (count) - 24; \
		t = 0xff >> t; \
		EOP_AND_IMM(d,s,0,t); \
		EOP_C_DOP_IMM(cond,A_OP_AND,0,s,d,0,t); \
	} else { \
		EOP_MOV_REG(cond,0,d,s,A_AM1_LSL,count); \
		EOP_MOV_REG(cond,0,d,d,A_AM1_LSR,count); \
	} \
}

#define emith_clear_msb(d, s, count) \
	emith_clear_msb_c(A_COND_AL, d, s, count)

#define emith_sext(d, s, bits) { \
	EOP_MOV_REG_LSL(d,s,32 - (bits)); \
	EOP_MOV_REG_ASR(d,d,32 - (bits)); \
}

#define emith_do_caller_regs(mask, func) { \
	u32 _reg_mask = (mask) & 0x500f; \
	if (_reg_mask) { \
		if (__builtin_parity(_reg_mask) == 1) \
			_reg_mask |= 0x10; /* eabi align */ \
		func(_reg_mask); \
	} \
}

#define emith_save_caller_regs(mask) \
	emith_do_caller_regs(mask, EOP_STMFD_SP)

#define emith_restore_caller_regs(mask) \
	emith_do_caller_regs(mask, EOP_LDMFD_SP)

// upto 4 args
#define emith_pass_arg_r(arg, reg) \
	EOP_MOV_REG_SIMPLE(arg, reg)

#define emith_pass_arg_imm(arg, imm) \
	emith_move_r_imm(arg, imm)

#define emith_jump(target) \
	emith_jump_cond(A_COND_AL, target)

#define emith_jump_patchable(target) \
	emith_jump(target)

#define emith_jump_cond(cond, target) \
	emith_xbranch(cond, target, 0)

#define emith_jump_cond_patchable(cond, target) \
	emith_jump_cond(cond, target)

#define emith_jump_patch(ptr, target) do { \
	u32 *ptr_ = ptr; \
	u32 val_ = (u32 *)(target) - ptr_ - 2; \
	*ptr_ = (*ptr_ & 0xff000000) | (val_ & 0x00ffffff); \
} while (0)

#define emith_jump_at(ptr, target) { \
	u32 val_ = (u32 *)(target) - (u32 *)(ptr) - 2; \
	EOP_C_B_PTR(ptr, A_COND_AL, 0, val_ & 0xffffff); \
}

#define emith_jump_reg_c(cond, r) \
	EOP_C_BX(cond, r)

#define emith_jump_reg(r) \
	emith_jump_reg_c(A_COND_AL, r)

#define emith_jump_ctx_c(cond, offs) \
	EOP_LDR_IMM2(cond,15,CONTEXT_REG,offs)

#define emith_jump_ctx(offs) \
	emith_jump_ctx_c(A_COND_AL, offs)

#define emith_call_cond(cond, target) \
	emith_xbranch(cond, target, 1)

#define emith_call(target) \
	emith_call_cond(A_COND_AL, target)

#define emith_call_ctx(offs) { \
	emith_move_r_r(14, 15); \
	emith_jump_ctx(offs); \
}

#define emith_ret_c(cond) \
	emith_jump_reg_c(cond, 14)

#define emith_ret() \
	emith_ret_c(A_COND_AL)

#define emith_ret_to_ctx(offs) \
	emith_ctx_write(14, offs)

#define emith_push_ret() \
	EOP_STMFD_SP(A_R14M)

#define emith_pop_and_ret() \
	EOP_LDMFD_SP(A_R15M)

#define host_instructions_updated(base, end) \
	cache_flush_d_inval_i(base, end)

#define host_arg2reg(rd, arg) \
	rd = arg

/* SH2 drc specific */
/* pushes r12 for eabi alignment */
#define emith_sh2_drc_entry() \
	EOP_STMFD_SP(A_R4M|A_R5M|A_R6M|A_R7M|A_R8M|A_R9M|A_R10M|A_R11M|A_R12M|A_R14M)

#define emith_sh2_drc_exit() \
	EOP_LDMFD_SP(A_R4M|A_R5M|A_R6M|A_R7M|A_R8M|A_R9M|A_R10M|A_R11M|A_R12M|A_R15M)

#define emith_sh2_wcall(a, tab) { \
	emith_lsr(12, a, SH2_WRITE_SHIFT); \
	EOP_LDR_REG_LSL(A_COND_AL,12,tab,12,2); \
	emith_move_r_r(2, CONTEXT_REG); \
	emith_jump_reg(12); \
}

#define emith_sh2_dtbf_loop() { \
	int cr, rn;                                                          \
	int tmp_ = rcache_get_tmp();                                         \
	cr = rcache_get_reg(SHR_SR, RC_GR_RMW);                              \
	rn = rcache_get_reg((op >> 8) & 0x0f, RC_GR_RMW);                    \
	emith_sub_r_imm(rn, 1);                /* sub rn, #1 */              \
	emith_bic_r_imm(cr, 1);                /* bic cr, #1 */              \
	emith_sub_r_imm(cr, (cycles+1) << 12); /* sub cr, #(cycles+1)<<12 */ \
	cycles = 0;                                                          \
	emith_asrf(tmp_, cr, 2+12);            /* movs tmp_, cr, asr #2+12 */\
	EOP_MOV_IMM_C(A_COND_MI,tmp_,0,0);     /* movmi tmp_, #0 */          \
	emith_lsl(cr, cr, 20);                 /* mov cr, cr, lsl #20 */     \
	emith_lsr(cr, cr, 20);                 /* mov cr, cr, lsr #20 */     \
	emith_subf_r_r(rn, tmp_);              /* subs rn, tmp_ */           \
	EOP_RSB_IMM_C(A_COND_LS,tmp_,rn,0,0);  /* rsbls tmp_, rn, #0 */      \
	EOP_ORR_REG(A_COND_LS,0,cr,cr,tmp_,A_AM1_LSL,12+2); /* orrls cr,tmp_,lsl #12+2 */\
	EOP_ORR_IMM_C(A_COND_LS,cr,cr,0,1);    /* orrls cr, #1 */            \
	EOP_MOV_IMM_C(A_COND_LS,rn,0,0);       /* movls rn, #0 */            \
	rcache_free_tmp(tmp_);                                               \
}

#define emith_write_sr(sr, srcr) { \
	emith_lsr(sr, sr, 10); \
	emith_or_r_r_r_lsl(sr, sr, srcr, 22); \
	emith_ror(sr, sr, 22); \
}

#define emith_carry_to_t(srr, is_sub) { \
	if (is_sub) { /* has inverted C on ARM */ \
		emith_or_r_imm_c(A_COND_CC, srr, 1); \
		emith_bic_r_imm_c(A_COND_CS, srr, 1); \
	} else { \
		emith_or_r_imm_c(A_COND_CS, srr, 1); \
		emith_bic_r_imm_c(A_COND_CC, srr, 1); \
	} \
}

#define emith_tpop_carry(sr, is_sub) {  \
	if (is_sub)                     \
		emith_eor_r_imm(sr, 1); \
	emith_lsrf(sr, sr, 1);          \
}

#define emith_tpush_carry(sr, is_sub) { \
	emith_adc_r_r(sr, sr);          \
	if (is_sub)                     \
		emith_eor_r_imm(sr, 1); \
}

/*
 * if Q
 *   t = carry(Rn += Rm)
 * else
 *   t = carry(Rn -= Rm)
 * T ^= t
 */
#define emith_sh2_div1_step(rn, rm, sr) {         \
	void *jmp0, *jmp1;                        \
	emith_tst_r_imm(sr, Q);  /* if (Q ^ M) */ \
	JMP_POS(jmp0);           /* beq do_sub */ \
	emith_addf_r_r(rn, rm);                   \
	emith_eor_r_imm_c(A_COND_CS, sr, T);      \
	JMP_POS(jmp1);           /* b done */     \
	JMP_EMIT(A_COND_EQ, jmp0); /* do_sub: */  \
	emith_subf_r_r(rn, rm);                   \
	emith_eor_r_imm_c(A_COND_CC, sr, T);      \
	JMP_EMIT(A_COND_AL, jmp1); /* done: */    \
}

