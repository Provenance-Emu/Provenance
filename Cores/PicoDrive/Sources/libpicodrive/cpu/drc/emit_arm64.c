/*
 * Basic macros to emit ARM A64 instructions and some utils
 * Copyright (C) 2019-2024 irixxxx
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */
#define HOST_REGS	32

// AAPCS64: params: r0-r7, return: r0-r1, temp: r8-r17, saved: r19-r28
// reserved: r18 (for platform use), r29 (frame pointer)
#define RET_REG		0
#define PARAM_REGS	{ 0, 1, 2, 3, 4, 5, 6, 7 }
#define PRESERVED_REGS	{ 19, 20, 21, 22, 23, 24, 25, 26, 27, 28 }
#define TEMPORARY_REGS	{ 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 }

#define CONTEXT_REG	19
#define STATIC_SH2_REGS	{ SHR_SR,28 , SHR_R(0),27 , SHR_R(1),26 }

// R31 doesn't exist, it aliases either with zero or SP
#define	SP		31 // stack pointer
#define Z0		31 // zero register
#define	LR		30 // link register
#define	FP		29 // frame pointer
#define	PR		18 // platform register

// All operations but ptr ops are using the lower 32 bits of the A64 registers.
// The upper 32 bits are only used in ptr ops and are zeroed by A64 32 bit ops.


#define A64_COND_EQ 0x0
#define A64_COND_NE 0x1
#define A64_COND_HS 0x2
#define A64_COND_LO 0x3
#define A64_COND_MI 0x4
#define A64_COND_PL 0x5
#define A64_COND_VS 0x6
#define A64_COND_VC 0x7
#define A64_COND_HI 0x8
#define A64_COND_LS 0x9
#define A64_COND_GE 0xa
#define A64_COND_LT 0xb
#define A64_COND_GT 0xc
#define A64_COND_LE 0xd
#define A64_COND_CS A64_COND_HS
#define A64_COND_CC A64_COND_LO
// "fake" conditions for T bit handling
#define A64_COND_AL 0xe
#define A64_COND_NV 0xf

// DRC conditions
#define DCOND_EQ A64_COND_EQ
#define DCOND_NE A64_COND_NE
#define DCOND_MI A64_COND_MI
#define DCOND_PL A64_COND_PL
#define DCOND_HI A64_COND_HI
#define DCOND_HS A64_COND_HS
#define DCOND_LO A64_COND_LO
#define DCOND_GE A64_COND_GE
#define DCOND_GT A64_COND_GT
#define DCOND_LT A64_COND_LT
#define DCOND_LS A64_COND_LS
#define DCOND_LE A64_COND_LE
#define DCOND_VS A64_COND_VS
#define DCOND_VC A64_COND_VC

#define DCOND_CS A64_COND_HS
#define DCOND_CC A64_COND_LO


// unified insn
#define A64_INSN(op, b29, b22, b21, b16, b12, b10, b5, b0) \
	(((op)<<25)|((b29)<<29)|((b22)<<22)|((b21)<<21)|((b16)<<16)|((b12)<<12)|((b10)<<10)|((b5)<<5)|((b0)<<0))

#define _	0 // marker for "field unused"

#define	A64_NOP \
	A64_INSN(0xa,0x6,0x4,_,0x3,0x2,_,0,0x1f) // 0xd503201f

// arithmetic/logical

enum { OP_AND, OP_OR, OP_EOR, OP_ANDS, OP_ADD, OP_ADDS, OP_SUB, OP_SUBS };
enum { ST_LSL, ST_LSR, ST_ASR, ST_ROR };
enum { XT_UXTW=0x4, XT_UXTX=0x6, XT_LSL=0x7, XT_SXTW=0xc, XT_SXTX=0xe };
#define	OP_SZ64	(1 << 31)	// bit for 64 bit op selection
#define OP_N64  (1 << 22)       // N-bit for 64 bit logical immediate ops

#define A64_OP_REG(op, n, rd, rn, rm, stype, simm) /* arith+logical, ST_ */ \
	A64_INSN(0x5,(op)&3,((op)&4)|stype,n,rm,_,simm,rn,rd)
#define A64_OP_XREG(op, rd, rn, rm, xtopt, simm) /* arith, XT_ */ \
	A64_INSN(0x5,(op)&3,0x4,1,rm,xtopt,simm,rn,rd)
#define A64_OP_IMM12(op, rd, rn, imm, lsl12) /* arith */ \
	A64_INSN(0x8,(op)&3,((op)&4)|lsl12,_,_,_,(imm)&0xfff,rn,rd)
#define A64_OP_IMMBM(op, rd, rn, immr, imms) /* logical */ \
	A64_INSN(0x9,(op)&3,0x0,_,immr,_,(imms)&0x3f,rn,rd)

// rd = rn OP (rm SHIFT simm)
#define A64_ADD_REG(rd, rn, rm, stype, simm) \
	A64_OP_REG(OP_ADD,0,rd,rn,rm,stype,simm)
#define A64_ADDS_REG(rd, rn, rm, stype, simm) \
	A64_OP_REG(OP_ADDS,0,rd,rn,rm,stype,simm)
#define A64_SUB_REG(rd, rn, rm, stype, simm) \
	A64_OP_REG(OP_SUB,0,rd,rn,rm,stype,simm)
#define A64_SUBS_REG(rd, rn, rm, stype, simm) \
	A64_OP_REG(OP_SUBS,0,rd,rn,rm,stype,simm)

#define A64_NEG_REG(rd, rm, stype, simm) \
	A64_SUB_REG(rd,Z0,rm,stype,simm)
#define A64_NEGS_REG(rd, rm, stype, simm) \
	A64_SUBS_REG(rd,Z0,rm,stype,simm)
#define A64_NEGC_REG(rd, rm) \
	A64_SBC_REG(rd,Z0,rm)
#define A64_NEGCS_REG(rd, rm) \
	A64_SBCS_REG(rd,Z0,rm)
#define A64_CMP_REG(rn, rm, stype, simm) \
	A64_SUBS_REG(Z0, rn, rm, stype, simm)
#define A64_CMN_REG(rn, rm, stype, simm) \
	A64_ADDS_REG(Z0, rn, rm, stype, simm)

#define A64_EOR_REG(rd, rn, rm, stype, simm) \
	A64_OP_REG(OP_EOR,0,rd,rn,rm,stype,simm)
#define A64_OR_REG(rd, rn, rm, stype, simm) \
	A64_OP_REG(OP_OR,0,rd,rn,rm,stype,simm)
#define A64_ORN_REG(rd, rn, rm, stype, simm) \
	A64_OP_REG(OP_OR,1,rd,rn,rm,stype,simm)
#define A64_AND_REG(rd, rn, rm, stype, simm) \
	A64_OP_REG(OP_AND,0,rd,rn,rm,stype,simm)
#define A64_ANDS_REG(rd, rn, rm, stype, simm) \
	A64_OP_REG(OP_ANDS,0,rd,rn,rm,stype,simm)
#define A64_BIC_REG(rd, rn, rm, stype, simm) \
	A64_OP_REG(OP_AND,1,rd,rn,rm,stype,simm)
#define A64_BICS_REG(rd, rn, rm, stype, simm) \
	A64_OP_REG(OP_ANDS,1,rd,rn,rm,stype,simm)

#define A64_TST_REG(rn, rm, stype, simm) \
	A64_ANDS_REG(Z0, rn, rm, stype, simm)
#define A64_MOV_REG(rd, rm, stype, simm) \
	A64_OR_REG(rd, Z0, rm, stype, simm)
#define A64_MVN_REG(rd, rm, stype, simm) \
	A64_ORN_REG(rd, Z0, rm, stype, simm)

// rd = rn OP (rm EXTEND simm)
#define A64_ADD_XREG(rd, rn, rm, xtopt, simm) \
	A64_OP_XREG(OP_ADD,rd,rn,rm,xtopt,simm)
#define A64_ADDS_XREG(rd, rn, rm, xtopt, simm) \
	A64_OP_XREG(OP_ADDS,rd,rn,rm,xtopt,simm)
#define A64_SUB_XREG(rd, rn, rm, stype, simm) \
	A64_OP_XREG(OP_SUB,rd,rn,rm,xtopt,simm)
#define A64_SUBS_XREG(rd, rn, rm, stype, simm) \
	A64_OP_XREG(OP_SUBS,rd,rn,rm,xtopt,simm)

// rd = rn OP rm OP carry
#define A64_ADC_REG(rd, rn, rm) \
	A64_INSN(0xd,OP_ADD &3,0x0,_,rm,_,_,rn,rd)
#define A64_ADCS_REG(rd, rn, rm) \
	A64_INSN(0xd,OP_ADDS&3,0x0,_,rm,_,_,rn,rd)
#define A64_SBC_REG(rd, rn, rm) \
	A64_INSN(0xd,OP_SUB &3,0x0,_,rm,_,_,rn,rd)
#define A64_SBCS_REG(rd, rn, rm) \
	A64_INSN(0xd,OP_SUBS&3,0x0,_,rm,_,_,rn,rd)

// rd = rn SHIFT rm
#define A64_LSL_REG(rd, rn, rm) \
	A64_INSN(0xd,0x0,0x3,_,rm,_,0x8,rn,rd)
#define A64_LSR_REG(rd, rn, rm) \
	A64_INSN(0xd,0x0,0x3,_,rm,_,0xa,rn,rd)
#define A64_ASR_REG(rd, rn, rm) \
	A64_INSN(0xd,0x0,0x3,_,rm,_,0x9,rn,rd)
#define A64_ROR_REG(rd, rn, rm) \
	A64_INSN(0xd,0x0,0x3,_,rm,_,0xb,rn,rd)

// rd = REVERSE(rn)
#define A64_RBIT_REG(rd, rn) \
	A64_INSN(0xd,0x2,0x3,_,_,_,_,rn,rd)

// rd = rn OP (imm12 << (0|12))
#define A64_ADD_IMM(rd, rn, imm12, lsl12) \
	A64_OP_IMM12(OP_ADD, rd, rn, imm12, lsl12)
#define A64_ADDS_IMM(rd, rn, imm12, lsl12) \
	A64_OP_IMM12(OP_ADDS, rd, rn, imm12, lsl12)
#define A64_SUB_IMM(rd, rn, imm12, lsl12) \
	A64_OP_IMM12(OP_SUB, rd, rn, imm12, lsl12)
#define A64_SUBS_IMM(rd, rn, imm12, lsl12) \
	A64_OP_IMM12(OP_SUBS, rd, rn, imm12, lsl12)

#define A64_CMP_IMM(rn, imm12, lsl12) \
	A64_SUBS_IMM(Z0,rn,imm12,lsl12)
#define A64_CMN_IMM(rn, imm12, lsl12) \
	A64_ADDS_IMM(Z0,rn,imm12,lsl12)

// rd = rn OP immbm; immbm is a repeated special pattern of 2^n bits length
#define A64_EOR_IMM(rd, rn, immr, imms) \
	A64_OP_IMMBM(OP_EOR,rd,rn,immr,imms)
#define A64_OR_IMM(rd, rn, immr, imms) \
	A64_OP_IMMBM(OP_OR,rd,rn,immr,imms)
#define A64_AND_IMM(rd, rn, immr, imms) \
	A64_OP_IMMBM(OP_AND,rd,rn,immr,imms)
#define A64_ANDS_IMM(rd, rn, immr, imms) \
	A64_OP_IMMBM(OP_ANDS,rd,rn,immr,imms)
#define A64_TST_IMM(rn, immr, imms) \
	A64_OP_IMMBM(OP_ANDS,Z0,rn,immr,imms)
#define A64_MOV_IMM(rd, rn, immr, imms) \
	A64_OP_IMMBM(OP_OR,rd,Z0,immr,imms)

// rd = (imm16 << (0|16|32|48))
#define A64_MOVN_IMM(rd, imm16, lsl16) \
	A64_INSN(0x9,0x0,0x2,lsl16,_,_,_,(imm16)&0xffff,rd)
#define A64_MOVZ_IMM(rd, imm16, lsl16) \
	A64_INSN(0x9,0x2,0x2,lsl16,_,_,_,(imm16)&0xffff,rd)
#define A64_MOVK_IMM(rd, imm16, lsl16) \
	A64_INSN(0x9,0x3,0x2,lsl16,_,_,_,(imm16)&0xffff,rd)
#define A64_MOVT_IMM(rd, imm16, lsl16) \
	A64_INSN(0x9,0x3,0x2,lsl16,_,_,_,(imm16)&0xffff,rd)

// rd = rn SHIFT imm5/imm6 (for Wn/Xn)
#define A64_LSL_IMM(rd, rn, bits) /* UBFM */ \
	A64_INSN(0x9,0x2,0x4,_,32-(bits),_,31-(bits),rn,rd)
#define A64_LSR_IMM(rd, rn, bits) /* UBFM */ \
	A64_INSN(0x9,0x2,0x4,_,bits,_,31,rn,rd)
#define A64_ASR_IMM(rd, rn, bits) /* SBFM */ \
	A64_INSN(0x9,0x0,0x4,_,bits,_,31,rn,rd)
#define A64_ROR_IMM(rd, rn, bits) /* EXTR */ \
	A64_INSN(0x9,0x0,0x6,_,rn,_,bits,rn,rd)

#define A64_SXT_IMM(rd, rn, bits) /* SBFM */ \
	A64_INSN(0x9,0x0,0x4,_,0,_,bits-1,rn,rd)
#define A64_UXT_IMM(rd, rn, bits) /* UBFM */ \
	A64_INSN(0x9,0x2,0x4,_,0,_,bits-1,rn,rd)

#define A64_BFX_IMM(rd, rn, lsb, bits) /* UBFM */ \
	A64_INSN(0x9,0x2,0x4,_,lsb,_,bits-1,rn,rd)
#define A64_BFI_IMM(rd, rn, lsb, bits) /* BFM */ \
	A64_INSN(0x9,0x1,0x4,_,-(lsb)&0x1f,_,bits-1,rn,rd)

// multiplication

#define A64_SMULL(rd, rn, rm) /* Xd = Wn*Wm (+ Xa) */ \
	A64_INSN(0xd,0x4,0x4,1,rm,_,Z0,rn,rd)
#define A64_SMADDL(rd, rn, rm, ra) \
	A64_INSN(0xd,0x4,0x4,1,rm,_,ra,rn,rd)
#define A64_UMULL(rd, rn, rm) \
	A64_INSN(0xd,0x4,0x6,1,rm,_,Z0,rn,rd)
#define A64_UMADDL(rd, rn, rm, ra) \
	A64_INSN(0xd,0x4,0x6,1,rm,_,ra,rn,rd)
#define A64_MUL(rd, rn, rm) /* Wd = Wn*Wm (+ Wa) */ \
	A64_INSN(0xd,0x0,0x4,0,rm,_,Z0,rn,rd)
#define A64_MADD(rd, rn, rm, ra) \
	A64_INSN(0xd,0x0,0x4,0,rm,_,ra,rn,rd)

// branching

#define A64_B(offs26) \
	A64_INSN(0xa,0x0,_,_,_,_,_,_,(offs26) >> 2)
#define A64_BL(offs26) \
	A64_INSN(0xa,0x4,_,_,_,_,_,_,(offs26) >> 2)
#define A64_BR(rn) \
	A64_INSN(0xb,0x6,_,_,0x1f,_,_,rn,_)
#define A64_BLR(rn) \
	A64_INSN(0xb,0x6,_,_,0x3f,_,_,rn,_)
#define A64_RET(rn) /* same as BR, but hint for cpu */ \
	A64_INSN(0xb,0x6,_,_,0x5f,_,_,rn,_)
#define A64_BCOND(cond, offs19) \
	A64_INSN(0xa,0x2,_,_,_,_,_,(offs19) >> 2,(cond))

// conditional select

#define	A64_CINC(cond, rn, rm) \
	A64_INSN(0xd,0x0,0x2,0,rm,(cond)^1,0x1,rm,rn) /* CSINC */
#define	A64_CSET(cond, rn) \
	A64_CINC(cond, rn, Z0)

// load pc-relative

#define A64_LDRLIT_IMM(rd, offs19) \
	A64_INSN(0xc,0x0,0x0,_,_,_,_,(offs19) >> 2,rd)
#define A64_LDRXLIT_IMM(rd, offs19) \
	A64_INSN(0xc,0x2,0x0,_,_,_,_,(offs19) >> 2,rd)
#define A64_ADRXLIT_IMM(rd, offs21) \
	A64_INSN(0x8,(offs21)&3,0x0,_,_,_,_,(offs21) >> 2,rd)

// load/store indexed base. Only the signed unscaled variant is used here.

enum { LT_ST, LT_LD, LT_LDSX, LT_LDS };
enum { AM_B=0x1, AM_H=0x3, AM_W=0x5, AM_X=0x7 };
enum { AM_IDX, AM_IDXPOST, AM_IDXREG, AM_IDXPRE };
#define A64_LDST_AM(ir,rm,optimm) (((ir)<<9)|((rm)<<4)|((optimm)&0x1ff))
#define A64_OP_LDST(sz, op, am, mode, rm, rd) \
	A64_INSN(0xc,sz,op,_,_,am,mode,rm,rd)

#define A64_LDSTX_IMM(rd, rn, offs9, ld, mode) \
	A64_OP_LDST(AM_X,ld,A64_LDST_AM(0,_,offs9),mode,rn,rd)
#define A64_LDST_IMM(rd, rn, offs9, ld, mode) \
	A64_OP_LDST(AM_W,ld,A64_LDST_AM(0,_,offs9),mode,rn,rd)
#define A64_LDSTH_IMM(rd, rn, offs9, ld, mode) \
	A64_OP_LDST(AM_H,ld,A64_LDST_AM(0,_,offs9),mode,rn,rd)
#define A64_LDSTB_IMM(rd, rn, offs9, ld, mode) \
	A64_OP_LDST(AM_B,ld,A64_LDST_AM(0,_,offs9),mode,rn,rd)

// NB: pre/postindex isn't available with register offset
#define A64_LDSTX_REG(rd, rn, rm, ld, opt) \
	A64_OP_LDST(AM_X,ld,A64_LDST_AM(1,rm,opt),AM_IDXREG,rn,rd)
#define A64_LDST_REG(rd, rn, rm, ld, opt) \
	A64_OP_LDST(AM_W,ld,A64_LDST_AM(1,rm,opt),AM_IDXREG,rn,rd)
#define A64_LDSTH_REG(rd, rn, rm, ld, opt) \
	A64_OP_LDST(AM_H,ld,A64_LDST_AM(1,rm,opt),AM_IDXREG,rn,rd)
#define A64_LDSTB_REG(rd, rn, rm, ld, opt) \
	A64_OP_LDST(AM_B,ld,A64_LDST_AM(1,rm,opt),AM_IDXREG,rn,rd)

#define A64_LDSTPX_IMM(rn, r1, r2, offs7, ld, mode) \
	A64_INSN(0x4,0x5,(mode<<1)|ld,_,_,(offs7)&0x3f8,r2,rn,r1)

// 64 bit stuff for pointer handling

#define A64_ADDX_XREG(rd, rn, rm, xtopt, simm) \
	OP_SZ64|A64_OP_XREG(OP_ADD,rd,rn,rm,xtopt,simm)
#define A64_ADDX_REG(rd, rn, rm, stype, simm) \
	OP_SZ64|A64_ADD_REG(rd, rn, rm, stype, simm)
#define A64_ADDXS_REG(rd, rn, rm, stype, simm) \
	OP_SZ64|A64_ADDS_REG(rd, rn, rm, stype, simm)
#define A64_ORX_REG(rd, rn, rm, stype, simm) \
	OP_SZ64|A64_OR_REG(rd, rn, rm, stype, simm)
#define A64_TSTX_REG(rn, rm, stype, simm) \
	OP_SZ64|A64_TST_REG(rn, rm, stype, simm)
#define A64_MOVX_REG(rd, rm, stype, simm) \
	OP_SZ64|A64_MOV_REG(rd, rm, stype, simm)
#define A64_ADDX_IMM(rd, rn, imm12) \
	OP_SZ64|A64_ADD_IMM(rd, rn, imm12, 0)
#define A64_EORX_IMM(rd, rn, immr, imms) \
	OP_SZ64|OP_N64|A64_EOR_IMM(rd, rn, immr, imms)
#define A64_UXTX_IMM(rd, rn, bits) \
	OP_SZ64|OP_N64|A64_UXT_IMM(rd, rn, bits)
#define A64_LSRX_IMM(rd, rn, bits) \
	OP_SZ64|OP_N64|A64_LSR_IMM(rd, rn, bits)|(63<<10)


// XXX: tcache_ptr type for SVP and SH2 compilers differs..
#define EMIT_PTR(ptr, x) \
	do { \
		*(u32 *)(ptr) = x; \
		ptr = (void *)((u8 *)(ptr) + sizeof(u32)); \
	} while (0)

#define EMIT(op) \
	do { \
		EMIT_PTR(tcache_ptr, op); \
		COUNT_OP; \
	} while (0)


// if-then-else conditional execution helpers
#define JMP_POS(ptr) { \
	ptr = tcache_ptr; \
	EMIT(A64_B(0)); \
}

#define JMP_EMIT(cond, ptr) { \
	u32 val_ = (u8 *)tcache_ptr - (u8 *)(ptr); \
	EMIT_PTR(ptr, A64_BCOND(cond, val_ & 0x001fffff)); \
}

#define JMP_EMIT_NC(ptr) { \
	u32 val_ = (u8 *)tcache_ptr - (u8 *)(ptr); \
	EMIT_PTR(ptr, A64_B(val_ & 0x0fffffff)); \
}

#define EMITH_JMP_START(cond) { \
	u8 *cond_ptr; \
	JMP_POS(cond_ptr)

#define EMITH_JMP_END(cond) \
	JMP_EMIT(cond, cond_ptr); \
}

#define EMITH_JMP3_START(cond) { \
	u8 *cond_ptr, *else_ptr; \
	JMP_POS(cond_ptr)

#define EMITH_JMP3_MID(cond) \
	JMP_POS(else_ptr); \
	JMP_EMIT(cond, cond_ptr);

#define EMITH_JMP3_END() \
	JMP_EMIT_NC(else_ptr); \
}

#define EMITH_HINT_COND(cond)   /**/

// "simple" jump (no more than a few insns)
// ARM32 will use conditional instructions here
#define EMITH_SJMP_START EMITH_JMP_START
#define EMITH_SJMP_END EMITH_JMP_END

#define EMITH_SJMP3_START EMITH_JMP3_START
#define EMITH_SJMP3_MID EMITH_JMP3_MID
#define EMITH_SJMP3_END EMITH_JMP3_END

#define EMITH_SJMP2_START(cond) \
	EMITH_SJMP3_START(cond)
#define EMITH_SJMP2_MID(cond) \
	EMITH_SJMP3_MID(cond)
#define EMITH_SJMP2_END(cond) \
	EMITH_SJMP3_END()


// data processing, register
#define emith_move_r_r_ptr(d, s) \
	EMIT(A64_MOVX_REG(d, s, ST_LSL, 0))
#define emith_move_r_r_ptr_c(cond, d, s) \
	emith_move_r_r_ptr(d, s)

#define emith_move_r_r(d, s) \
	EMIT(A64_MOV_REG(d, s, ST_LSL, 0))
#define emith_move_r_r_c(cond, d, s) \
	emith_move_r_r(d, s)

#define emith_mvn_r_r(d, s) \
	EMIT(A64_MVN_REG(d, s, ST_LSL, 0))

#define emith_add_r_r_r_lsl_ptr(d, s1, s2, simm) do { \
	if (simm < 4)	EMIT(A64_ADDX_XREG(d, s1, s2, XT_SXTW, simm)); \
	else		EMIT(A64_ADDX_REG(d, s1, s2, ST_LSL, simm)); \
} while (0)
#define emith_add_r_r_r_lsl(d, s1, s2, simm) \
	EMIT(A64_ADD_REG(d, s1, s2, ST_LSL, simm))

#define emith_addf_r_r_r_lsl(d, s1, s2, simm) \
	EMIT(A64_ADDS_REG(d, s1, s2, ST_LSL, simm))

#define emith_addf_r_r_r_lsr(d, s1, s2, simm) \
	EMIT(A64_ADDS_REG(d, s1, s2, ST_LSR, simm))

#define emith_adc_r_r_r_lsl(d, s1, s2, simm) \
	if (simm) {	int _t = rcache_get_tmp(); \
			emith_lsl(_t, s2, simm); \
			emith_adc_r_r_r(d, s1, _t); \
			rcache_free_tmp(_t); \
	} else \
			emith_adc_r_r_r(d, s1, s2); \
} while (0)

#define emith_sbc_r_r_r_lsl(d, s1, s2, simm) \
	if (simm) {	int _t = rcache_get_tmp(); \
			emith_lsl(_t, s2, simm); \
			emith_sbc_r_r_r(d, s1, _t); \
			rcache_free_tmp(_t); \
	} else \
			emith_sbc_r_r_r(d, s1, s2); \
} while (0)

#define emith_sub_r_r_r_lsl(d, s1, s2, simm) \
	EMIT(A64_SUB_REG(d, s1, s2, ST_LSL, simm))

#define emith_subf_r_r_r_lsl(d, s1, s2, simm) \
	EMIT(A64_SUBS_REG(d, s1, s2, ST_LSL, simm))

#define emith_or_r_r_r_lsl(d, s1, s2, simm) \
	EMIT(A64_OR_REG(d, s1, s2, ST_LSL, simm))
#define emith_or_r_r_r_lsr(d, s1, s2, simm) \
	EMIT(A64_OR_REG(d, s1, s2, ST_LSR, simm))

#define emith_eor_r_r_r_lsl(d, s1, s2, simm) \
	EMIT(A64_EOR_REG(d, s1, s2, ST_LSL, simm))
#define emith_eor_r_r_r_lsr(d, s1, s2, simm) \
	EMIT(A64_EOR_REG(d, s1, s2, ST_LSR, simm))

#define emith_and_r_r_r_lsl(d, s1, s2, simm) \
	EMIT(A64_AND_REG(d, s1, s2, ST_LSL, simm))

#define emith_or_r_r_lsl(d, s, lslimm) \
	emith_or_r_r_r_lsl(d, d, s, lslimm)
#define emith_or_r_r_lsr(d, s, lsrimm) \
	emith_or_r_r_r_lsr(d, d, s, lsrimm)

#define emith_eor_r_r_lsl(d, s, lslimm) \
	emith_eor_r_r_r_lsl(d, d, s, lslimm)
#define emith_eor_r_r_lsr(d, s, lsrimm) \
	emith_eor_r_r_r_lsr(d, d, s, lsrimm)

#define emith_add_r_r_r(d, s1, s2) \
	emith_add_r_r_r_lsl(d, s1, s2, 0)

#define emith_addf_r_r_r(d, s1, s2) \
	emith_addf_r_r_r_lsl(d, s1, s2, 0)

#define emith_sub_r_r_r(d, s1, s2) \
	emith_sub_r_r_r_lsl(d, s1, s2, 0)

#define emith_subf_r_r_r(d, s1, s2) \
	emith_subf_r_r_r_lsl(d, s1, s2, 0)

#define emith_or_r_r_r(d, s1, s2) \
	emith_or_r_r_r_lsl(d, s1, s2, 0)

#define emith_eor_r_r_r(d, s1, s2) \
	emith_eor_r_r_r_lsl(d, s1, s2, 0)

#define emith_add_r_r_r_ptr(d, s1, s2) \
	emith_add_r_r_r_lsl_ptr(d, s1, s2, 0)
#define emith_and_r_r_r(d, s1, s2) \
	emith_and_r_r_r_lsl(d, s1, s2, 0)

#define emith_add_r_r_ptr(d, s) \
	emith_add_r_r_r_lsl_ptr(d, d, s, 0)
#define emith_add_r_r(d, s) \
	emith_add_r_r_r(d, d, s)

#define emith_sub_r_r(d, s) \
	emith_sub_r_r_r(d, d, s)

#define emith_neg_r_r(d, s) \
	EMIT(A64_NEG_REG(d, s, ST_LSL, 0))

#define emith_negc_r_r(d, s) \
	EMIT(A64_NEGC_REG(d, s))

#define emith_adc_r_r_r(d, s1, s2) \
	EMIT(A64_ADC_REG(d, s1, s2))

#define emith_adc_r_r(d, s) \
	EMIT(A64_ADC_REG(d, d, s))

#define emith_adcf_r_r_r(d, s1, s2) \
	EMIT(A64_ADCS_REG(d, s1, s2))

#define emith_sbc_r_r_r(d, s1, s2) \
	EMIT(A64_SBC_REG(d, s1, s2))

#define emith_sbcf_r_r_r(d, s1, s2) \
	EMIT(A64_SBCS_REG(d, s1, s2))

#define emith_and_r_r(d, s) \
	emith_and_r_r_r(d, d, s)
#define emith_and_r_r_c(cond, d, s) \
	emith_and_r_r(d, s)

#define emith_or_r_r(d, s) \
	emith_or_r_r_r(d, d, s)

#define emith_eor_r_r(d, s) \
	emith_eor_r_r_r(d, d, s)

#define emith_tst_r_r_ptr(d, s) \
	EMIT(A64_TSTX_REG(d, s, ST_LSL, 0))
#define emith_tst_r_r(d, s) \
	EMIT(A64_TST_REG(d, s, ST_LSL, 0))

#define emith_teq_r_r(d, s) do { \
	int _t = rcache_get_tmp(); \
	emith_eor_r_r_r(_t, d, s); \
	emith_cmp_r_imm(_t, 0); \
	rcache_free_tmp(_t); \
} while (0)

#define emith_cmp_r_r(d, s) \
	EMIT(A64_CMP_REG(d, s, ST_LSL, 0))

#define emith_addf_r_r(d, s) \
	emith_addf_r_r_r(d, d, s)

#define emith_subf_r_r(d, s) \
	emith_subf_r_r_r(d, d, s)

#define emith_adcf_r_r(d, s) \
	emith_adcf_r_r_r(d, d, s)

#define emith_sbcf_r_r(d, s) \
	emith_sbcf_r_r_r(d, d, s)

#define emith_negcf_r_r(d, s) \
	emith_sbcf_r_r_r(d, Z0, s)


// move immediate

static void emith_move_imm64(int r, int wx, int64_t imm)
{
	int sz64 = wx ? OP_SZ64:0;
	int c, s;

	if (!imm) {
		EMIT(sz64|A64_MOVZ_IMM(r, imm, 0));
		return;
	}
	if (imm && -imm == (u16)-imm) {
		EMIT(sz64|A64_MOVN_IMM(r, ~imm, 0));
		return;
	}

	for (c = s = 0; s < (wx ? 4:2) && imm; s++, imm >>= 16)
		if ((u16)(imm)) {
			if (c++)	EMIT(sz64|A64_MOVK_IMM(r, imm, s));
			else		EMIT(sz64|A64_MOVZ_IMM(r, imm, s));
		}
}

#define emith_move_r_ptr_imm(r, imm) \
	emith_move_imm64(r, 1, (intptr_t)(imm))

#define emith_move_r_imm(r, imm) \
	emith_move_imm64(r, 0, (s32)(imm))
#define emith_move_r_imm_c(cond, r, imm) \
	emith_move_r_imm(r, imm)

#define emith_move_r_imm_s8_patchable(r, imm) do { \
	if ((s8)(imm) < 0) \
		EMIT(A64_MOVN_IMM(r, ~(s8)(imm), 0)); \
	else \
		EMIT(A64_MOVZ_IMM(r, (s8)(imm), 0)); \
} while (0)
#define emith_move_r_imm_s8_patch(ptr, imm) do { \
	u32 *ptr_ = (u32 *)ptr; \
	int r_ = *ptr_ & 0x1f; \
	if ((s8)(imm) < 0) \
		EMIT_PTR(ptr_, A64_MOVN_IMM(r_, ~(s8)(imm), 0)); \
	else \
		EMIT_PTR(ptr_, A64_MOVZ_IMM(r_, (s8)(imm), 0)); \
} while (0)

// arithmetic, immediate
static void emith_arith_imm(int op, int wx, int rd, int rn, s32 imm)
{
	u32 sz64 = wx ? OP_SZ64:0;

	if (imm < 0) {
		op ^= (OP_ADD ^ OP_SUB);
		imm = -imm;
	}
	if (imm == 0) {
		// value 0, must emit if op is *S or source isn't dest
		if ((op & 1) || rd != rn)
			EMIT(sz64|A64_OP_IMM12(op, rd, rn, 0, 0));
	} else if (imm >> 24) {
		// value too large
		int _t = rcache_get_tmp();
		emith_move_r_imm(_t, imm);
		EMIT(sz64|A64_OP_REG(op, 0, rd, rn, _t, ST_LSL, 0));
		rcache_free_tmp(_t);
	} else {
		int rs = rn;
		if ((imm) & 0x000fff) {
			EMIT(sz64|A64_OP_IMM12(op, rd, rs, imm, 0)); rs = rd;
	       	}
		if ((imm) & 0xfff000) {
			EMIT(sz64|A64_OP_IMM12(op, rd, rs, imm >>12, 1));
	       	}
	}
}

#define emith_add_r_imm(r, imm) \
	emith_arith_imm(OP_ADD, 0, r, r, imm)
#define emith_add_r_imm_c(cond, r, imm) \
	emith_add_r_imm(r, imm)

#define emith_addf_r_imm(r, imm) \
	emith_arith_imm(OP_ADDS, 0, r, r, imm)

#define emith_sub_r_imm(r, imm) \
	emith_arith_imm(OP_SUB, 0, r, r, imm)
#define emith_sub_r_imm_c(cond, r, imm) \
	emith_sub_r_imm(r, imm)

#define emith_subf_r_imm(r, imm) \
	emith_arith_imm(OP_SUBS, 0, r, r, imm)


#define emith_adc_r_imm(r, imm) do { \
	int _t = rcache_get_tmp(); \
	emith_move_r_imm(_t, imm); \
	emith_adc_r_r(r, _t); \
	rcache_free_tmp(_t); \
} while (0)

#define emith_adcf_r_imm(r, imm) do { \
	int _t = rcache_get_tmp(); \
	emith_move_r_imm(_t, imm); \
	emith_adcf_r_r(r, _t); \
	rcache_free_tmp(_t); \
} while (0)

#define emith_cmp_r_imm(r, imm) do { \
	u32 op_ = OP_SUBS, imm_ = (u8)imm; \
	if ((s8)imm_ < 0) { \
		imm_ = (u8)-imm_; \
		op_ = OP_ADDS; \
	} \
	EMIT(A64_OP_IMM12(op_, Z0, r, imm_, 0)); \
} while (0)


#define emith_add_r_r_ptr_imm(d, s, imm) \
	emith_arith_imm(OP_ADD, 1, d, s, imm)

#define emith_add_r_r_imm(d, s, imm) \
	emith_arith_imm(OP_ADD, 0, d, s, imm)

#define emith_sub_r_r_imm(d, s, imm) \
	emith_arith_imm(OP_SUB, 0, d, s, imm)
#define emith_sub_r_r_imm_c(cond, d, s, imm) \
	emith_sub_r_r_imm(d, s, imm)

#define emith_subf_r_r_imm(d, s, imm) \
	emith_arith_imm(OP_SUBS, 0, d, s, imm)


// logical, immediate; the value describes a bitmask, see ARMv8 ArchRefMan
// NB: deal only with simple masks 0{n}1{m}0{o} or 1{n}0{m}1{o}, 0<m<32 n+m+o=32
static int emith_log_isbm(u32 imm, int *n, int *m, int *invert)
{
	*invert = (s32)imm < 0; // topmost bit set?

	if (*invert)
		imm = ~imm;
	if (imm) {
		*n = __builtin_clz(imm); imm = ~(imm << *n); // insert 1's
		*m = __builtin_clz(imm); imm = ~ imm << *m;  // insert 0's
		return !imm;
	} else {
		*n = *m = 0;
		return 0;
	}
}

static void emith_log_imm(int op, int wx, int rd, int rn, u32 imm)
{
	int n, m, invert;
	u32 sz64 = wx ? OP_SZ64:0;

	if (emith_log_isbm(imm, &n, &m, &invert) && (!wx || !invert)) {
		n += (wx ? 32:0);   // extend pattern if 64 bit regs are used
		if (invert)	EMIT(sz64|A64_OP_IMMBM(op, rd, rn, n, 32-m-1));
		else		EMIT(sz64|A64_OP_IMMBM(op, rd, rn, n+m, m-1));
	} else {
		// imm too complex
		int _t = rcache_get_tmp();
		if (count_bits(imm) > 16) {
			emith_move_r_imm(_t, ~imm);
			EMIT(sz64|A64_OP_REG(op, 1, rd, rn, _t, ST_LSL, 0));
		} else {
			emith_move_r_imm(_t, imm);
			EMIT(sz64|A64_OP_REG(op, 0, rd, rn, _t, ST_LSL, 0));
		}
		rcache_free_tmp(_t);
	}
}

#define emith_and_r_imm(r, imm) \
	emith_log_imm(OP_AND, 0, r, r, imm)

#define emith_or_r_imm(r, imm) \
	emith_log_imm(OP_OR, 0, r, r, imm)
#define emith_or_r_imm_c(cond, r, imm) \
	emith_or_r_imm(r, imm)

#define emith_eor_r_imm_ptr(r, imm) \
	emith_log_imm(OP_EOR, 1, r, r, imm)
#define emith_eor_r_imm_ptr_c(cond, r, imm) \
	emith_eor_r_imm_ptr(r, imm)

#define emith_eor_r_imm(r, imm) \
	emith_log_imm(OP_EOR, 0, r, r, imm)
#define emith_eor_r_imm_c(cond, r, imm) \
	emith_eor_r_imm(r, imm)

/* NB: BIC #imm not available in A64; use AND #~imm instead */
#define emith_bic_r_imm(r, imm) \
	emith_log_imm(OP_AND, 0, r, r, ~(imm))
#define emith_bic_r_imm_c(cond, r, imm) \
	emith_bic_r_imm(r, imm)

#define emith_tst_r_imm(r, imm) \
	emith_log_imm(OP_ANDS, 0, Z0, r, imm)
#define emith_tst_r_imm_c(cond, r, imm) \
	emith_tst_r_imm(r, imm)

#define emith_and_r_r_imm(d, s, imm) \
	emith_log_imm(OP_AND, 0, d, s, imm)

#define emith_or_r_r_imm(d, s, imm) \
	emith_log_imm(OP_OR, 0, d, s, imm)

#define emith_eor_r_r_imm(d, s, imm) \
	emith_log_imm(OP_EOR, 0, d, s, imm)


// shift
#define emith_lsl(d, s, cnt) \
	EMIT(A64_LSL_IMM(d, s, cnt))

#define emith_lsr(d, s, cnt) \
	EMIT(A64_LSR_IMM(d, s, cnt))

#define emith_asr(d, s, cnt) \
	EMIT(A64_ASR_IMM(d, s, cnt))

#define emith_ror(d, s, cnt) \
	EMIT(A64_ROR_IMM(d, s, cnt))
#define emith_ror_c(cond, d, s, cnt) \
	emith_ror(d, s, cnt)

#define emith_rol(d, s, cnt) \
	EMIT(A64_ROR_IMM(d, s, 32-(cnt)))

// NB: shift with carry not directly supported in A64 :-|.
#define emith_lslf(d, s, cnt) do { \
	if ((cnt) > 1) { \
		emith_lsl(d, s, cnt-1); \
		emith_addf_r_r_r(d, d, d); \
	} else if ((cnt) > 0) \
		emith_addf_r_r_r(d, s, s); \
} while (0)

#define emith_lsrf(d, s, cnt) do { \
	EMIT(A64_RBIT_REG(d, s)); \
	emith_lslf(d, d, cnt); \
	EMIT(A64_RBIT_REG(d, d)); \
} while (0)

#define emith_asrf(d, s, cnt) do { \
	int _s = s; \
	if ((cnt) > 1) { \
		emith_asr(d, s, cnt-1); \
		_s = d; \
	} \
	if ((cnt) > 0) { \
		emith_addf_r_r_r(Z0, _s, _s); \
		EMIT(A64_RBIT_REG(d, _s)); \
		emith_adcf_r_r_r(d, d, d); \
		EMIT(A64_RBIT_REG(d, d)); \
	} \
} while (0)

#define emith_rolf(d, s, cnt) do { \
	int _s = s; \
	if ((cnt) > 1) { \
		emith_rol(d, s, cnt-1); \
		_s = d; \
	} \
	if ((cnt) > 0) { \
		emith_addf_r_r_r(d, _s, _s); \
		emith_adc_r_r_r(d, d, Z0); \
	} \
} while (0)

#define emith_rorf(d, s, cnt) do { \
	if ((cnt) > 0) { \
		emith_ror(d, s, cnt); \
		emith_addf_r_r_r(Z0, d, d); \
	} \
} while (0)

#define emith_rolcf(d) \
	emith_adcf_r_r(d, d)
#define emith_rolc(d) \
	emith_adc_r_r(d, d)

#define emith_rorcf(d) do { \
	EMIT(A64_RBIT_REG(d, d)); \
	emith_adcf_r_r(d, d); \
	EMIT(A64_RBIT_REG(d, d)); \
} while (0)
#define emith_rorc(d) do { \
	EMIT(A64_RBIT_REG(d, d)); \
	emith_adc_r_r(d, d); \
	EMIT(A64_RBIT_REG(d, d)); \
} while (0)

// signed/unsigned extend
#define emith_clear_msb(d, s, count) /* bits to clear */ \
	EMIT(A64_UXT_IMM(d, s, 32-(count)))
#define emith_clear_msb_c(cond, d, s, count) \
	emith_clear_msb(d, s, count)

#define emith_sext(d, s, count) /* bits to keep */ \
	EMIT(A64_SXT_IMM(d, s, count))

// multiply Rd = Rn*Rm (+ Ra)
#define emith_mul(d, s1, s2) \
	EMIT(A64_MUL(d, s1, s2))

// NB: must combine/split Xd from/into 2 Wd's; play safe and clear upper bits
#define emith_combine64(dlo, dhi) \
	EMIT(A64_UXTX_IMM(dlo, dlo, 32)); \
	EMIT(A64_ORX_REG(dlo, dlo, dhi, ST_LSL, 32));

#define emith_split64(dlo, dhi) \
	EMIT(A64_LSRX_IMM(dhi, dlo, 32)); \
	EMIT(A64_UXTX_IMM(dlo, dlo, 32));

#define emith_mul_u64(dlo, dhi, s1, s2) do { \
	EMIT(A64_UMULL(dlo, s1, s2)); \
	emith_split64(dlo, dhi); \
} while (0)

#define emith_mul_s64(dlo, dhi, s1, s2) do { \
	EMIT(A64_SMULL(dlo, s1, s2)); \
	emith_split64(dlo, dhi); \
} while (0)

#define emith_mula_s64(dlo, dhi, s1, s2) do { \
	emith_combine64(dlo, dhi); \
	EMIT(A64_SMADDL(dlo, s1, s2, dlo)); \
	emith_split64(dlo, dhi); \
} while (0)
#define emith_mula_s64_c(cond, dlo, dhi, s1, s2) \
	emith_mula_s64(dlo, dhi, s1, s2)

// load/store. offs has 9 bits signed, hence larger offs may use a temp
static void emith_ldst_offs(int sz, int rd, int rn, int o9, int ld, int mode)
{
	if (o9 >= -256 && o9 < 256) {
		EMIT(A64_OP_LDST(sz, ld, A64_LDST_AM(0,_,o9), mode, rn, rd));
	} else if (mode == AM_IDXPRE) {
		emith_add_r_r_ptr_imm(rn, rn, o9);
		EMIT(A64_OP_LDST(sz, ld, A64_LDST_AM(0,_,0), AM_IDX, rn, rd));
	} else if (mode == AM_IDXPOST) {
		EMIT(A64_OP_LDST(sz, ld, A64_LDST_AM(0,_,0), AM_IDX, rn, rd));
		emith_add_r_r_ptr_imm(rn, rn, o9);
	} else {
		int _t = rcache_get_tmp();
		emith_add_r_r_ptr_imm(_t, rn, o9);
		EMIT(A64_OP_LDST(sz, ld, A64_LDST_AM(0,_,0), AM_IDX, _t, rd));
		rcache_free_tmp(_t);
	}
}

#define emith_read_r_r_offs_ptr(r, rs, offs) \
	emith_ldst_offs(AM_X, r, rs, offs, LT_LD, AM_IDX)
#define emith_read_r_r_offs_ptr_c(cond, r, rs, offs) \
	emith_read_r_r_offs_ptr(r, rs, offs)

#define emith_read_r_r_offs(r, rs, offs) \
	emith_ldst_offs(AM_W, r, rs, offs, LT_LD, AM_IDX)
#define emith_read_r_r_offs_c(cond, r, rs, offs) \
	emith_read_r_r_offs(r, rs, offs)
 
#define emith_read_r_r_r_ptr(r, rs, rm) \
	EMIT(A64_LDSTX_REG(r, rs, rm, LT_LD, XT_SXTW))

#define emith_read_r_r_r(r, rs, rm) \
	EMIT(A64_LDST_REG(r, rs, rm, LT_LD, XT_SXTW))
#define emith_read_r_r_r_c(cond, r, rs, rm) \
	emith_read_r_r_r(r, rs, rm)

#define emith_read8_r_r_offs(r, rs, offs) \
	emith_ldst_offs(AM_B, r, rs, offs, LT_LD, AM_IDX)
#define emith_read8_r_r_offs_c(cond, r, rs, offs) \
	emith_read8_r_r_offs(r, rs, offs)

#define emith_read8_r_r_r(r, rs, rm) \
	EMIT(A64_LDSTB_REG(r, rs, rm, LT_LD, XT_SXTW))
#define emith_read8_r_r_r_c(cond, r, rs, rm) \
	emith_read8_r_r_r(r, rs, rm)

#define emith_read16_r_r_offs(r, rs, offs) \
	emith_ldst_offs(AM_H, r, rs, offs, LT_LD, AM_IDX)
#define emith_read16_r_r_offs_c(cond, r, rs, offs) \
	emith_read16_r_r_offs(r, rs, offs)

#define emith_read16_r_r_r(r, rs, rm) \
	EMIT(A64_LDSTH_REG(r, rs, rm, LT_LD, XT_SXTW))
#define emith_read16_r_r_r_c(cond, r, rs, rm) \
	emith_read16_r_r_r(r, rs, rm)

#define emith_read8s_r_r_offs(r, rs, offs) \
	emith_ldst_offs(AM_B, r, rs, offs, LT_LDS, AM_IDX)
#define emith_read8s_r_r_offs_c(cond, r, rs, offs) \
	emith_read8s_r_r_offs(r, rs, offs)

#define emith_read8s_r_r_r(r, rs, rm) \
	EMIT(A64_LDSTB_REG(r, rs, rm, LT_LDS, XT_SXTW))
#define emith_read8s_r_r_r_c(cond, r, rs, rm) \
	emith_read8s_r_r_r(r, rs, rm)

#define emith_read16s_r_r_offs(r, rs, offs) \
	emith_ldst_offs(AM_H, r, rs, offs, LT_LDS, AM_IDX)
#define emith_read16s_r_r_offs_c(cond, r, rs, offs) \
	emith_read16s_r_r_offs(r, rs, offs)

#define emith_read16s_r_r_r(r, rs, rm) \
	EMIT(A64_LDSTH_REG(r, rs, rm, LT_LDS, XT_SXTW))
#define emith_read16s_r_r_r_c(cond, r, rs, rm) \
	emith_read16s_r_r_r(r, rs, rm)


#define emith_write_r_r_offs_ptr(r, rs, offs) \
	emith_ldst_offs(AM_X, r, rs, offs, LT_ST, AM_IDX)
#define emith_write_r_r_offs_ptr_c(cond, r, rs, offs) \
	emith_write_r_r_offs_ptr(r, rs, offs)

#define emith_write_r_r_r_ptr(r, rs, rm) \
	EMIT(A64_LDSTX_REG(r, rs, rm, LT_ST, XT_SXTW))
#define emith_write_r_r_r_ptr_c(cond, r, rs, rm) \
	emith_write_r_r_r_ptr(r, rs, rm)

#define emith_write_r_r_offs(r, rs, offs) \
	emith_ldst_offs(AM_W, r, rs, offs, LT_ST, AM_IDX)
#define emith_write_r_r_offs_c(cond, r, rs, offs) \
	emith_write_r_r_offs(r, rs, offs)

#define emith_write_r_r_r(r, rs, rm) \
	EMIT(A64_LDST_REG(r, rs, rm, LT_ST, XT_SXTW))
#define emith_write_r_r_r_c(cond, r, rs, rm) \
	emith_write_r_r_r(r, rs, rm)

#define emith_ctx_read_ptr(r, offs) \
	emith_read_r_r_offs_ptr(r, CONTEXT_REG, offs)

#define emith_ctx_read(r, offs) \
	emith_read_r_r_offs(r, CONTEXT_REG, offs)
#define emith_ctx_read_c(cond, r, offs) \
	emith_ctx_read(r, offs)

#define emith_ctx_write_ptr(r, offs) \
	emith_write_r_r_offs_ptr(r, CONTEXT_REG, offs)

#define emith_ctx_write(r, offs) \
	emith_write_r_r_offs(r, CONTEXT_REG, offs)

#define emith_ctx_read_multiple(r, offs, cnt, tmpr) do { \
	int r_ = r, offs_ = offs, cnt_ = cnt;     \
	for (; cnt_ > 0; r_++, offs_ += 4, cnt_--) \
		emith_ctx_read(r_, offs_);        \
} while (0)

#define emith_ctx_write_multiple(r, offs, cnt, tmpr) do { \
	int r_ = r, offs_ = offs, cnt_ = cnt;     \
	for (; cnt_ > 0; r_++, offs_ += 4, cnt_--) \
		emith_ctx_write(r_, offs_);       \
} while (0)

// push pairs; NB: SP must be 16 byte aligned (HW requirement!)
#define emith_push2(r1, r2) \
	EMIT(A64_LDSTPX_IMM(SP, r1, r2, -2*8, LT_ST, AM_IDXPRE))
#define emith_pop2(r1, r2) \
	EMIT(A64_LDSTPX_IMM(SP, r1, r2,  2*8, LT_LD, AM_IDXPOST))

// function call handling
#define emith_save_caller_regs(mask) do { \
	int _c, _r1, _r2; u32 _m = mask & 0x3ffff; \
	if (__builtin_parity(_m) == 1) _m |= 0x40000; /* hardware align */ \
	for (_c = HOST_REGS-1, _r1 = -1; _m && _c >= 0; _m &= ~(1 << _c), _c--)\
		if (_m & (1 << _c)) { \
			_r2 = _r1, _r1 = _c; \
			if (_r2 != -1) { \
				emith_push2(_r1, _r2); \
				_r1 = -1; \
			} \
		} \
} while (0)

#define emith_restore_caller_regs(mask) do { \
	int _c, _r1, _r2; u32 _m = mask & 0x3ffff; \
	if (__builtin_parity(_m) == 1) _m |= 0x40000; /* hardware align */ \
	for (_c = 0, _r1 = -1; _m && _c < HOST_REGS; _m &= ~(1 << _c), _c++) \
		if (_m & (1 << _c)) { \
			_r2 = _r1, _r1 = _c; \
			if (_r2 != -1) { \
				emith_pop2(_r2, _r1); \
				_r1 = -1; \
			} \
		} \
} while (0)

#define host_call(addr, args) \
	addr

#define host_arg2reg(rd, arg) \
	rd = arg

#define emith_pass_arg_r(arg, reg) \
	emith_move_r_r_ptr(arg, reg)

#define emith_pass_arg_imm(arg, imm) \
	emith_move_r_ptr_imm(arg, imm)

// branching; NB: A64 B.cond has only +/- 1MB range

#define emith_jump(target) do {\
	u32 disp_ = (u8 *)target - (u8 *)tcache_ptr; \
	EMIT(A64_B(disp_ & 0x0fffffff)); \
} while (0)

#define emith_jump_patchable(target) \
	emith_jump(target)

#define emith_jump_cond(cond, target) do { \
	u32 disp_ = (u8 *)target - (u8 *)tcache_ptr; \
	EMIT(A64_BCOND(cond, disp_ & 0x001fffff)); \
} while (0)

#define emith_jump_cond_patchable(cond, target) \
	emith_jump_cond(cond, target)

#define emith_jump_cond_inrange(target) \
	!(((u8 *)target - (u8 *)tcache_ptr + 0x100000) >> 21)

#define emith_jump_patch(ptr, target, pos) do { \
	u32 *ptr_ = (u32 *)ptr; \
	u32 disp_ = (u8 *)target - (u8 *)ptr, mask_; \
	if ((*ptr_ & 0xff000000) == 0x54000000) \
		mask_ = 0xff00001f, disp_ <<= 5; /* B.cond, range 21 bit */ \
	else	mask_ = 0xfc000000;		 /* B[L], range 28 bit */ \
	EMIT_PTR(ptr_, (*ptr_ & mask_) | ((disp_ >> 2) & ~mask_)); \
	if ((void *)(pos) != NULL) *(u8 **)(pos) = (u8 *)(ptr_-1); \
} while (0)

#define emith_jump_patch_inrange(ptr, target) \
	!(((u8 *)target - (u8 *)ptr + 0x100000) >> 21)
#define emith_jump_patch_size()	4

#define emith_jump_at(ptr, target) do { \
	u32 *ptr_ = (u32 *)ptr; \
	u32 disp_ = (u8 *)target - (u8 *)ptr; \
	EMIT_PTR(ptr_, A64_B(disp_ & 0x0fffffff)); \
} while (0)
#define emith_jump_at_size() 4

#define emith_jump_reg(r) \
	EMIT(A64_BR(r))
#define emith_jump_reg_c(cond, r) \
	emith_jump_reg(r)

#define emith_jump_ctx(offs) do { \
	int _t = rcache_get_tmp(); \
	emith_ctx_read_ptr(_t, offs); \
	emith_jump_reg(_t); \
	rcache_free_tmp(_t); \
} while (0)
#define emith_jump_ctx_c(cond, offs) \
	emith_jump_ctx(offs)

#define emith_call(target) do { \
	u32 disp_ = (u8 *)target - (u8 *)tcache_ptr; \
	EMIT(A64_BL(disp_ & 0x0fffffff)); \
} while (0)
#define emith_call_cond(cond, target) \
	emith_call(target)

#define emith_call_reg(r) \
	EMIT(A64_BLR(r))

#define emith_abicall_ctx(offs) do { \
	int _t = rcache_get_tmp(); \
	emith_ctx_read_ptr(_t, offs); \
	emith_call_reg(_t); \
	rcache_free_tmp(_t); \
} while (0)

#define emith_abijump_reg(r) \
	emith_jump_reg(r)
#define emith_abijump_reg_c(cond, r) \
	emith_abijump_reg(r)
#define emith_abicall(target) \
	emith_call(target)
#define emith_abicall_cond(cond, target) \
	emith_abicall(target)
#define emith_abicall_reg(r) \
	emith_call_reg(r)

#define emith_call_cleanup()	/**/

#define emith_ret() \
	EMIT(A64_RET(LR))
#define emith_ret_c(cond) \
	emith_ret()

#define emith_ret_to_ctx(offs) \
	emith_ctx_write_ptr(LR, offs)

#define emith_add_r_ret(r) \
	emith_add_r_r_r_ptr(r, LR, r)

// NB: pushes r or r18 for SP hardware alignment
#define emith_push_ret(r) do { \
	int r_ = (r >= 0 ? r : 18); \
	emith_push2(r_, LR); \
} while (0)

#define emith_pop_and_ret(r) do { \
	int r_ = (r >= 0 ? r : 18); \
	emith_pop2(r_, LR); \
	emith_ret(); \
} while (0)


// emitter ABI stuff
#define emith_pool_check()	/**/
#define emith_pool_commit(j)	/**/
#define emith_insn_ptr()	((u8 *)tcache_ptr)
#define	emith_flush()		/**/
#define host_instructions_updated(base, end, force) \
	do { if (force) __builtin___clear_cache(base, end); } while (0)
#define	emith_update_cache()	/**/
#define emith_rw_offs_max()	0x1ff
#define emith_uext_ptr(r)	/**/


// SH2 drc specific
#define emith_sh2_drc_entry() do { \
	emith_push2(LR, FP); \
	emith_push2(28, 27); \
	emith_push2(26, 25); \
	emith_push2(24, 23); \
	emith_push2(22, 21); \
	emith_push2(20, 19); \
} while (0)
#define emith_sh2_drc_exit() do { \
	emith_pop2(20, 19); \
	emith_pop2(22, 21); \
	emith_pop2(24, 23); \
	emith_pop2(26, 25); \
	emith_pop2(28, 27); \
	emith_pop2(LR, FP); \
	emith_ret(); \
} while (0)

// NB: assumes a is in arg0, tab, func and mask are temp
#define emith_sh2_rcall(a, tab, func, mask) do { \
	emith_lsr(mask, a, SH2_READ_SHIFT); \
	EMIT(A64_ADDX_REG(tab, tab, mask, ST_LSL, 4)); \
	emith_read_r_r_offs_ptr(func, tab, 0); \
	emith_read_r_r_offs(mask, tab, 8); \
	EMIT(A64_ADDXS_REG(func, func, func, ST_LSL, 0)); \
} while (0)

// NB: assumes a, val are in arg0 and arg1, tab and func are temp
#define emith_sh2_wcall(a, val, tab, func) do { \
	emith_lsr(func, a, SH2_WRITE_SHIFT); \
	emith_lsl(func, func, 3); \
	emith_read_r_r_r_ptr(func, tab, func); \
	emith_move_r_r_ptr(2, CONTEXT_REG); /* arg2 */ \
	emith_abijump_reg(func); \
} while (0)

#define emith_sh2_delay_loop(cycles, reg) do {			\
	int sr = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);	\
	int t1 = rcache_get_tmp();				\
	int t2 = rcache_get_tmp();				\
	int t3 = rcache_get_tmp();				\
	/* if (sr < 0) return */				\
	emith_cmp_r_imm(sr, 0);					\
	EMITH_JMP_START(DCOND_LE);				\
	/* turns = sr.cycles / cycles */			\
	emith_asr(t2, sr, 12);					\
	emith_move_r_imm(t3, (u32)((1ULL<<32) / (cycles)));	\
	emith_mul_u64(t1, t2, t2, t3); /* multiply by 1/x */	\
	rcache_free_tmp(t3);					\
	if (reg >= 0) {						\
		/* if (reg <= turns) turns = reg-1 */		\
		t3 = rcache_get_reg(reg, RC_GR_RMW, NULL);	\
		emith_cmp_r_r(t3, t2);				\
		EMITH_SJMP_START(DCOND_HI);			\
		emith_sub_r_r_imm_c(DCOND_LS, t2, t3, 1);	\
		EMITH_SJMP_END(DCOND_HI);			\
		/* if (reg <= 1) turns = 0 */			\
		emith_cmp_r_imm(t3, 1);				\
		EMITH_SJMP_START(DCOND_HI);			\
		emith_move_r_imm_c(DCOND_LS, t2, 0);		\
		EMITH_SJMP_END(DCOND_HI);			\
		/* reg -= turns */				\
		emith_sub_r_r(t3, t2);				\
	}							\
	/* sr.cycles -= turns * cycles; */			\
	emith_move_r_imm(t1, cycles);				\
	emith_mul(t1, t2, t1);					\
	emith_sub_r_r_r_lsl(sr, sr, t1, 12);			\
	EMITH_JMP_END(DCOND_LE);				\
	rcache_free_tmp(t1);					\
	rcache_free_tmp(t2);					\
} while (0)

/*
 * T = carry(Rn = (Rn << 1) | T)
 * if Q
 *   t = !carry(Rn += Rm)
 * else
 *   t = !carry(Rn -= Rm)
 * T ^= t
 */
#define emith_sh2_div1_step(rn, rm, sr) do {      \
	int tmp_ = rcache_get_tmp();              \
	emith_tpop_carry(sr, 0);                  \
	emith_adcf_r_r_r(rn, rn, rn);             \
	emith_tpush_carry(sr, 0);                 \
	emith_tst_r_imm(sr, Q);                   \
	EMITH_SJMP3_START(DCOND_EQ);              \
	emith_addf_r_r(rn, rm);                   \
	emith_adc_r_r_r(tmp_, Z0, Z0);            \
	emith_eor_r_imm(tmp_, 1);                 \
	EMITH_SJMP3_MID(DCOND_EQ);                \
	emith_subf_r_r(rn, rm);                   \
	emith_adc_r_r_r(tmp_, Z0, Z0);            \
	EMITH_SJMP3_END();                        \
	emith_eor_r_r(sr, tmp_);                  \
	rcache_free_tmp(tmp_);                    \
} while (0)

/* mh:ml += rn*rm, does saturation if required by S bit. rn, rm must be TEMP */
#define emith_sh2_macl(ml, mh, rn, rm, sr) do {   \
	emith_tst_r_imm(sr, S);                   \
	EMITH_SJMP_START(DCOND_EQ);               \
	/* MACH top 16 bits unused if saturated. sign ext for overfl detect */ \
	emith_sext(mh, mh, 16);                   \
	EMITH_SJMP_END(DCOND_EQ);                 \
	emith_mula_s64(ml, mh, rn, rm);           \
	emith_tst_r_imm(sr, S);                   \
	EMITH_SJMP_START(DCOND_EQ);               \
	/* overflow if top 17 bits of MACH aren't all 1 or 0 */ \
	/* to check: add MACH >> 31 to MACH >> 15. this is 0 if no overflow */ \
	emith_asr(rn, mh, 15);                    \
	emith_addf_r_r_r_lsr(rn, rn, mh, 31);     \
	EMITH_SJMP_START(DCOND_EQ); /* sum != 0 -> -ovl */ \
	emith_move_r_imm_c(DCOND_NE, ml, 0x00000000); \
	emith_move_r_imm_c(DCOND_NE, mh, 0x00008000); \
	EMITH_SJMP_START(DCOND_MI); /* sum > 0 -> +ovl */ \
	emith_sub_r_imm_c(DCOND_PL, ml, 1); /* 0xffffffff */ \
	emith_sub_r_imm_c(DCOND_PL, mh, 1); /* 0x00007fff */ \
	EMITH_SJMP_END(DCOND_MI);                 \
	EMITH_SJMP_END(DCOND_EQ);                 \
	EMITH_SJMP_END(DCOND_EQ);                 \
} while (0)

/* mh:ml += rn*rm, does saturation if required by S bit. rn, rm must be TEMP */
#define emith_sh2_macw(ml, mh, rn, rm, sr) do {   \
	emith_tst_r_imm(sr, S);                   \
	EMITH_SJMP_START(DCOND_EQ);               \
	/* XXX: MACH should be untouched when S is set? */ \
	emith_asr(mh, ml, 31); /* sign ext MACL to MACH for ovrfl check */ \
	EMITH_SJMP_END(DCOND_EQ);                 \
	emith_mula_s64(ml, mh, rn, rm);           \
	emith_tst_r_imm(sr, S);                   \
	EMITH_SJMP_START(DCOND_EQ);               \
	/* overflow if top 33 bits of MACH:MACL aren't all 1 or 0 */ \
	/* to check: add MACL[31] to MACH. this is 0 if no overflow */ \
	emith_addf_r_r_r_lsr(rn, mh, ml, 31); /* sum = MACH + (MACL>>31) */ \
	EMITH_SJMP_START(DCOND_EQ); /* sum != 0 -> overflow */ \
	/* XXX: LSB signalling only in SH1, or in SH2 too? */ \
	emith_move_r_imm_c(DCOND_NE, mh, 0x00000001); /* LSB of MACH */ \
	emith_move_r_imm_c(DCOND_NE, ml, 0x80000000); /* -ovrfl */ \
	EMITH_SJMP_START(DCOND_MI); /* sum > 0 -> +ovrfl */ \
	emith_sub_r_imm_c(DCOND_PL, ml, 1); /* 0x7fffffff */ \
	EMITH_SJMP_END(DCOND_MI);                 \
	EMITH_SJMP_END(DCOND_EQ);                 \
	EMITH_SJMP_END(DCOND_EQ);                 \
} while (0)

#define emith_write_sr(sr, srcr) \
	EMIT(A64_BFI_IMM(sr, srcr, 0, 10))

#define emith_carry_to_t(srr, is_sub) do { \
	emith_lsr(sr, sr, 1); \
	emith_adc_r_r(sr, sr); \
	if (is_sub) /* SUB has inverted C on ARM */ \
		emith_eor_r_imm(sr, 1); \
} while (0)

#define emith_t_to_carry(srr, is_sub) do { \
	if (is_sub) { \
		int t_ = rcache_get_tmp(); \
		emith_eor_r_r_imm(t_, srr, 1); \
		emith_rorf(t_, t_, 1); \
		rcache_free_tmp(t_); \
	} else { \
		emith_rorf(srr, srr, 1); \
		emith_rol(srr, srr, 1); \
	} \
} while (0)

#define emith_tpop_carry(sr, is_sub) do { \
	if (is_sub)                     \
		emith_eor_r_imm(sr, 1); \
	emith_ror(sr, sr, 1); \
	emith_addf_r_r(sr, sr); \
} while (0)

#define emith_tpush_carry(sr, is_sub) do { \
	emith_adc_r_r(sr, Z0);          \
	if (is_sub)                     \
		emith_eor_r_imm(sr, 1); \
} while (0)

#ifdef T
// T bit handling
static int tcond = -1;

#define emith_invert_cond(cond) \
	((cond) ^ 1)

#define emith_clr_t_cond(sr) \
	(void)sr

#define emith_set_t_cond(sr, cond) \
	tcond = cond

#define emith_get_t_cond() \
	tcond

#define emith_invalidate_t() \
	tcond = -1

#define emith_set_t(sr, val) \
	tcond = ((val) ? A64_COND_AL: A64_COND_NV)

static void emith_sync_t(int sr)
{
	if (tcond == A64_COND_AL)
		emith_or_r_imm(sr, T);
	else if (tcond == A64_COND_NV)
		emith_bic_r_imm(sr, T);
	else if (tcond >= 0) {
		int tmp = rcache_get_tmp();
		EMIT(A64_CSET(tcond, tmp));
		EMIT(A64_BFI_IMM(sr, tmp, __builtin_ffs(T)-1, 1));
		rcache_free_tmp(tmp);
	}
	tcond = -1;
}

static int emith_tst_t(int sr, int tf)
{
	if (tcond < 0) {
		emith_tst_r_imm(sr, T);
		return tf ? DCOND_NE: DCOND_EQ;
	} else if (tcond >= A64_COND_AL) {
		// MUST sync because A64_COND_AL/NV isn't a real condition
		emith_sync_t(sr);
		emith_tst_r_imm(sr, T);
		return tf ? DCOND_NE: DCOND_EQ;
	} else
		return tf ? tcond : emith_invert_cond(tcond);
}
#endif
