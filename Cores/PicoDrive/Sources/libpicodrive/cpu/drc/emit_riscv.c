/*
 * Basic macros to emit RISC-V RV64IM instructions and some utils
 * Copyright (C) 2019-2024 irixxxx
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 *
 * TODO: support for compressed instructions
 */
#define HOST_REGS	32

// RISC-V ABI: params: x10-x17, return: x10-x11, temp: x1(ra),x5-x7,x28-x31
// saved: x8(fp),x9,x18-x27, reserved: x0(zero), x4(tp), x3(gp), x2(sp)
// x28-x31(t3-t6) are used internally by the code emitter
#define RET_REG		10 // a0
#define PARAM_REGS	{ 10, 11, 12, 13, 14, 15, 16, 17 } // a0-a7
#define	PRESERVED_REGS	{ 9, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27 } // s1-s11
#define	TEMPORARY_REGS	{ 5, 6, 7 } // t0-t2

#define CONTEXT_REG	9 // s1
#define STATIC_SH2_REGS	{ SHR_SR,27 , SHR_R(0),26 , SHR_R(1),25 }

// registers usable for user code: r1-r25, others reserved or special
#define Z0		0  // zero register
#define	GP		3  // global pointer
#define	SP		2  // stack pointer
#define	FP		8  // frame pointer
#define	LR		1  // link register
// internally used by code emitter:
#define AT		31 // used to hold intermediate results
#define FNZ		30 // emulated processor flags: N (bit 31) ,Z (all bits)
#define FC		29 // emulated processor flags: C (bit 0), others 0
#define FV		28 // emulated processor flags: Nt^Ns (bit 31). others x

// All operations but ptr ops are using the lower 32 bits of the registers.
// The upper 32 bits always contain the sign extension from the lower 32 bits.

// unified conditions; virtual, not corresponding to anything real on RISC-V
#define DCOND_EQ 0x0
#define DCOND_NE 0x1
#define DCOND_HS 0x2
#define DCOND_LO 0x3
#define DCOND_MI 0x4
#define DCOND_PL 0x5
#define DCOND_VS 0x6
#define DCOND_VC 0x7
#define DCOND_HI 0x8
#define DCOND_LS 0x9
#define DCOND_GE 0xa
#define DCOND_LT 0xb
#define DCOND_GT 0xc
#define DCOND_LE 0xd

#define DCOND_CS DCOND_LO
#define DCOND_CC DCOND_HS

// unified insn
#define R5_INSN(b25, b20, b15, b12, b7, op) \
	(((b25)<<25)|((b20)<<20)|((b15)<<15)|((b12)<<12)|((b7)<<7)|((op)<<0))

#define _		0 //marker for "field unused"
#define _CB(v,l,s,d)	((((v)>>(s))&((1<<(l))-1))<<(d)) // copy l bits

#define R5_R_INSN(op, f1, f2, rd, rs, rt) \
	R5_INSN(f2, rt, rs, f1, rd, op)
#define R5_I_INSN(op, f1, rd, rs, imm) \
	R5_INSN(_, _CB(imm,12,0,0), rs, f1, rd, op)
#define R5_S_INSN(op, f1, rt, rs, imm) \
	R5_INSN(_CB(imm,7,5,0), rt, rs, f1, _CB(imm,5,0,0), op)
#define R5_U_INSN(op, rd, imm) \
	R5_INSN(_,_,_, _CB(imm,20,12,0), rd, op)
// oy vey... R5 immediate encoding in branches is really unwieldy :-/
#define R5_B_INSN(op, f1, rt, rs, imm) \
	R5_INSN(_CB(imm,1,12,6)|_CB(imm,6,5,0), rt, rs, f1, \
                _CB(imm,4,1,1)|_CB(imm,1,11,0), op)
#define R5_J_INSN(op, rd, imm) \
	R5_INSN(_CB(imm,1,20,6)|_CB(imm,6,5,0), _CB(imm,4,1,1)|_CB(imm,1,11,0),\
		_CB(imm,8,12,0), rd, op)

// opcode
enum { OP_LUI=0x37, OP_AUIPC=0x17, OP_JAL=0x6f, // 20-bit immediate
       OP_JALR=0x67, OP_BCOND=0x63, OP_LD=0x03, OP_ST=0x23, // 12-bit immediate
       OP_IMM=0x13, OP_REG=0x33, OP_IMM32=0x1b, OP_REG32=0x3b };
// func3
enum { F1_ADD, F1_SL, F1_SLT, F1_SLTU, F1_XOR, F1_SR, F1_OR, F1_AND };// IMM/REG
enum { F1_MUL, F1_MULH, F1_MULHSU, F1_MULHU, F1_DIV, F1_DIVU, F1_REM, F1_REMU };
enum { F1_BEQ, F1_BNE, F1_BLT=4, F1_BGE, F1_BLTU, F1_BGEU }; // BCOND
enum { F1_B, F1_H, F1_W, F1_D, F1_BU, F1_HU, F1_WU }; // LD/ST
// func7
enum { F2_ALT=0x20, F2_MULDIV=0x01 };

#define	R5_NOP R5_I_INSN(OP_IMM, F1_ADD, Z0, Z0, 0) // nop: ADDI r0, r0, #0

// arithmetic/logical

// rd = rs OP rt
#define R5_ADD_REG(rd, rs, rt) \
	R5_R_INSN(OP_REG, F1_ADD, _,      rd, rs, rt)
#define R5_SUB_REG(rd, rs, rt) \
	R5_R_INSN(OP_REG, F1_ADD, F2_ALT, rd, rs, rt)

#define R5_NEG_REG(rd, rt) \
	R5_SUB_REG(rd, Z0, rt)

#define R5_XOR_REG(rd, rs, rt) \
	R5_R_INSN(OP_REG, F1_XOR, _,      rd, rs, rt)
#define R5_OR_REG(rd, rs, rt) \
	R5_R_INSN(OP_REG, F1_OR , _,      rd, rs, rt)
#define R5_AND_REG(rd, rs, rt) \
	R5_R_INSN(OP_REG, F1_AND, _,      rd, rs, rt)

// rd = rs SHIFT rt
#define R5_LSL_REG(rd, rs, rt) \
	R5_R_INSN(OP_REG, F1_SL , _,      rd, rs, rt)
#define R5_LSR_REG(rd, rs, rt) \
	R5_R_INSN(OP_REG, F1_SR , _,      rd, rs, rt)
#define R5_ASR_REG(rd, rs, rt) \
	R5_R_INSN(OP_REG, F1_SR , F2_ALT, rd, rs, rt)

// rd = (rs < rt)
#define R5_SLT_REG(rd, rs, rt) \
	R5_R_INSN(OP_REG, F1_SLT, _,      rd, rs, rt)
#define R5_SLTU_REG(rd, rs, rt) \
	R5_R_INSN(OP_REG, F1_SLTU,_,      rd, rs, rt)

// rd = rs OP imm12
#define R5_ADD_IMM(rd, rs, imm12) \
	R5_I_INSN(OP_IMM, F1_ADD ,        rd, rs, imm12)

#define R5_XOR_IMM(rd, rs, imm12) \
	R5_I_INSN(OP_IMM, F1_XOR ,        rd, rs, imm12)
#define R5_OR_IMM(rd, rs, imm12) \
	R5_I_INSN(OP_IMM, F1_OR  ,        rd, rs, imm12)
#define R5_AND_IMM(rd, rs, imm12) \
	R5_I_INSN(OP_IMM, F1_AND ,        rd, rs, imm12)

#define R5_MOV_REG(rd, rs) \
	R5_ADD_IMM(rd, rs, 0)
#define R5_MVN_REG(rd, rs) \
	R5_XOR_IMM(rd, rs, -1)

// rd = (imm12 << (0|12))
#define R5_MOV_IMM(rd, imm12) \
	R5_OR_IMM(rd, Z0, imm12)
#define R5_MOVT_IMM(rd, imm20) \
	R5_U_INSN(OP_LUI, rd, imm20)
#define R5_MOVA_IMM(rd, imm20) \
	R5_U_INSN(OP_AUIPC, rd, imm20)

// rd = rs SHIFT imm5/imm6
#define R5_LSL_IMM(rd, rs, bits) \
	R5_R_INSN(OP_IMM, F1_SL , _,      rd, rs, bits)
#define R5_LSR_IMM(rd, rs, bits) \
	R5_R_INSN(OP_IMM, F1_SR , _,      rd, rs, bits)
#define R5_ASR_IMM(rd, rs, bits) \
	R5_R_INSN(OP_IMM, F1_SR , F2_ALT, rd, rs, bits)

// rd = (rs < imm12)
#define R5_SLT_IMM(rd, rs, imm12) \
	R5_I_INSN(OP_IMM, F1_SLT ,        rd, rs, imm12)
#define R5_SLTU_IMM(rd, rs, imm12) \
	R5_I_INSN(OP_IMM, F1_SLTU,        rd, rs, imm12)

// multiplication

#define R5_MULHU(rd, rs, rt) \
	R5_R_INSN(OP_REG, F1_MULHU, F2_MULDIV, rd, rs, rt)
#define R5_MULHS(rd, rs, rt) \
	R5_R_INSN(OP_REG, F1_MULH, F2_MULDIV, rd, rs, rt)
#define R5_MUL(rd, rs, rt) \
	R5_R_INSN(OP_REG, F1_MUL, F2_MULDIV, rd, rs, rt)

// branching

#define R5_J(imm20) \
	R5_J_INSN(OP_JAL, Z0, imm20)
#define R5_JAL(rd, imm20) \
	R5_J_INSN(OP_JAL, rd, imm20)
#define R5_JR(rs, offs12) \
	R5_I_INSN(OP_JALR, _, Z0, rs, offs12)
#define R5_JALR(rd, rs, offs12) \
	R5_I_INSN(OP_JALR, _, rd, rs, offs12)

// conditional branches; no condition code, these compare rs against rt
#define R5_BCOND(cond, rs, rt, offs13) \
	R5_B_INSN(OP_BCOND, cond, rt, rs, offs13)
#define R5_BCONDZ(cond, rs, offs13) \
	R5_B_INSN(OP_BCOND, cond, Z0, rs, offs13)
#define R5_B(offs13) \
	R5_BCOND(F1_BEQ, Z0, Z0, offs13)

// load/store indexed base

#define R5_LW(rd, rs, offs12) \
	R5_I_INSN(OP_LD, F1_W, rd, rs, offs12)
#define R5_LH(rd, rs, offs12) \
	R5_I_INSN(OP_LD, F1_H, rd, rs, offs12)
#define R5_LB(rd, rs, offs12) \
	R5_I_INSN(OP_LD, F1_B, rd, rs, offs12)
#define R5_LHU(rd, rs, offs12) \
	R5_I_INSN(OP_LD, F1_HU, rd, rs, offs12)
#define R5_LBU(rd, rs, offs12) \
	R5_I_INSN(OP_LD, F1_BU, rd, rs, offs12)

#define R5_SW(rt, rs, offs12) \
	R5_S_INSN(OP_ST, F1_W, rt, rs, offs12)
#define R5_SH(rt, rs, offs12) \
	R5_S_INSN(OP_ST, F1_H, rt, rs, offs12)
#define R5_SB(rt, rs, offs12) \
	R5_S_INSN(OP_ST, F1_B, rt, rs, offs12)

// pointer operations

#if __riscv_xlen == 64
#define R5_OP32				(OP_REG32 ^ OP_REG)
#define F1_P				F1_D
#define PTR_SCALE			3

// NB: must split 64 bit result into 2 32 bit registers
#define EMIT_R5_MULLU_REG(dlo, dhi, s1, s2) do { \
	EMIT(R5_LSL_IMM(AT, s1, 32)); \
	EMIT(R5_LSL_IMM(dhi, s2, 32)); \
	EMIT(R5_MULHU(dlo, AT, dhi)); \
	EMIT(R5_ASR_IMM(dhi, dlo, 32)); \
	EMIT(R5_ADDW_IMM(dlo, dlo, 0)); \
} while (0)

#define EMIT_R5_MULLS_REG(dlo, dhi, s1, s2) do { \
	EMIT(R5_MUL(dlo, s1, s2)); \
	EMIT(R5_ASR_IMM(dhi, dlo, 32)); \
	EMIT(R5_ADDW_IMM(dlo, dlo, 0)); \
} while (0)

#else
#define R5_OP32				0
#define F1_P				F1_W
#define PTR_SCALE			2

#define EMIT_R5_MULLU_REG(dlo, dhi, s1, s2) do { \
	int at = (dhi == s1 || dhi == s2 ? AT : dhi); \
	EMIT(R5_MULHU(at, s1, s2)); \
	EMIT(R5_MUL(dlo, s1, s2)); \
	if (at != dhi) emith_move_r_r(dhi, at); \
} while (0)

#define EMIT_R5_MULLS_REG(dlo, dhi, s1, s2) do { \
	int at = (dhi == s1 || dhi == s2 ? AT : dhi); \
	EMIT(R5_MULHS(at, s1, s2)); \
	EMIT(R5_MUL(dlo, s1, s2)); \
	if (at != dhi) emith_move_r_r(dhi, at); \
} while (0)
#endif

#define PTR_SIZE	(1<<PTR_SCALE)

#define R5_ADDW_REG(rd, rs, rt)		(R5_ADD_REG(rd, rs, rt)^R5_OP32)
#define R5_SUBW_REG(rd, rs, rt)		(R5_SUB_REG(rd, rs, rt)^R5_OP32)
#define R5_LSLW_REG(rd, rs, rt)		(R5_LSL_REG(rd, rs, rt)^R5_OP32)
#define R5_LSRW_REG(rd, rs, rt)		(R5_LSR_REG(rd, rs, rt)^R5_OP32)
#define R5_ASRW_REG(rd, rs, rt)		(R5_ASR_REG(rd, rs, rt)^R5_OP32)

#define R5_NEGW_REG(rd, rt)		(R5_NEG_REG(rd, rt)    ^R5_OP32)
#define R5_MULW(rd, rs, rt)		(R5_MUL(rd, rs, rt)    ^R5_OP32)

#define R5_ADDW_IMM(rd, rs, imm)	(R5_ADD_IMM(rd, rs, imm) ^R5_OP32)
#define R5_LSLW_IMM(rd, rs, bits)	(R5_LSL_IMM(rd, rs, bits)^R5_OP32)
#define R5_LSRW_IMM(rd, rs, bits)	(R5_LSR_IMM(rd, rs, bits)^R5_OP32)
#define R5_ASRW_IMM(rd, rs, bits)	(R5_ASR_IMM(rd, rs, bits)^R5_OP32)

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
	EMIT(R5_B(0)); \
}

#define JMP_EMIT(cond, ptr) { \
	u32 val_ = (u8 *)tcache_ptr - (u8 *)(ptr); \
	EMIT_PTR(ptr, R5_BCOND(cond_m, cond_r, cond_s, val_ & 0x00001fff)); \
}

#define JMP_EMIT_NC(ptr) { \
	u32 val_ = (u8 *)tcache_ptr - (u8 *)(ptr); \
	EMIT_PTR(ptr, R5_B(val_ & 0x00001fff)); \
}

#define EMITH_JMP_START(cond) { \
	int cond_r, cond_s, cond_m = emith_cond_check(cond, &cond_r, &cond_s); \
	u8 *cond_ptr; \
	JMP_POS(cond_ptr)

#define EMITH_JMP_END(cond) \
	JMP_EMIT(cond, cond_ptr); \
}

#define EMITH_JMP3_START(cond) { \
	int cond_r, cond_s, cond_m = emith_cond_check(cond, &cond_r, &cond_s); \
	u8 *cond_ptr, *else_ptr; \
	JMP_POS(cond_ptr)

#define EMITH_JMP3_MID(cond) \
	JMP_POS(else_ptr); \
	JMP_EMIT(cond, cond_ptr);

#define EMITH_JMP3_END() \
	JMP_EMIT_NC(else_ptr); \
}

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


// flag register emulation. this is modelled after arm/x86.
// the FNZ register stores the result of the last flag setting operation for
// N and Z flag, used for EQ,NE,MI,PL branches.
// the FC register stores the C flag (used for HI,HS,LO,LS,CC,CS).
// the FV register stores information for V flag calculation (used for
// GT,GE,LT,LE,VC,VS). V flag is costly and only fully calculated when needed.
// the core registers may be temp registers, since the condition after calls
// is undefined anyway. 

// flag emulation creates 2 (ie cmp #0/beq) up to 9 (ie adcf/ble) extra insns.
// flag handling shortcuts may reduce this by 1-4 insns, see emith_cond_check()
static int emith_cmp_rs, emith_cmp_rt;	// registers used in cmp_r_r/cmp_r_imm
static s32 emith_cmp_imm;		// immediate value used in cmp_r_imm
enum { _FHC=1, _FHV=2 } emith_flg_hint;	// C/V flag usage hinted by compiler
static int emith_flg_noV;		// V flag known not to be set

#define EMITH_HINT_COND(cond) do { \
	/* only need to check cond>>1 since the lowest bit inverts the cond */ \
	unsigned _mv = BITMASK3(DCOND_VS>>1,DCOND_GE>>1,DCOND_GT>>1); \
	unsigned _mc = _mv | BITMASK2(DCOND_HS>>1,DCOND_HI>>1); \
	emith_flg_hint  = (_mv & BITMASK1(cond >> 1) ? _FHV : 0); \
	emith_flg_hint |= (_mc & BITMASK1(cond >> 1) ? _FHC : 0); \
} while (0)

// store minimal cc information: rd, rt^rs, carry
// NB: the result *must* first go to FNZ, in case rd == rs or rd == rt.
// NB: for adcf and sbcf, carry-in must be dealt with separately (see there)
static void emith_set_arith_flags(int rd, int rs, int rt, s32 imm, int sub)
{
	if (emith_flg_hint & _FHC) {
		if (sub)			// C = sub:rt<rd, add:rd<rt
			EMIT(R5_SLTU_REG(FC, rs, FNZ));
		else	EMIT(R5_SLTU_REG(FC, FNZ, rs));// C in FC, bit 0 
	}

	if (emith_flg_hint & _FHV) {
		emith_flg_noV = 0;
		if (rt > Z0)				// Nt^Ns in FV, bit 31
			EMIT(R5_XOR_REG(FV, rs, rt));
		else if (rt == Z0 || imm == 0)
			emith_flg_noV = 1;		// imm #0 can't overflow
		else if ((imm < 0) == !sub)
			EMIT(R5_XOR_IMM(FV, rs, -1));
		else if ((imm > 0) == !sub)
			EMIT(R5_XOR_REG(FV, rs, Z0));
	}
	// full V = Nd^Nt^Ns^C calculation is deferred until really needed

	if (rd && rd != FNZ)
		EMIT(R5_MOV_REG(rd, FNZ));	// N,Z via result value in FNZ
	emith_cmp_rs = emith_cmp_rt = -1;
}

// since R5 has less-than and compare-branch insns, handle cmp separately by
// storing the involved regs for later use in one of those R5 insns.
// This works for all conditions but VC/VS, but this is fortunately never used.
static void emith_set_compare_flags(int rs, int rt, s32 imm)
{
	emith_cmp_rt = rt;
	emith_cmp_rs = rs;
	emith_cmp_imm = imm;
}

// data processing, register
#define emith_move_r_r_ptr(d, s) \
	EMIT(R5_MOV_REG(d, s))
#define emith_move_r_r_ptr_c(cond, d, s) \
	emith_move_r_r_ptr(d, s)

#define emith_move_r_r(d, s) \
	emith_move_r_r_ptr(d, s)
#define emith_move_r_r_c(cond, d, s) \
	emith_move_r_r(d, s)

#define emith_mvn_r_r(d, s) \
	EMIT(R5_MVN_REG(d, s))

#define emith_add_r_r_r_lsl_ptr(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(R5_LSL_IMM(AT, s2, simm)); \
		EMIT(R5_ADD_REG(d, s1, AT)); \
	} else	EMIT(R5_ADD_REG(d, s1, s2)); \
} while (0)
#define emith_add_r_r_r_lsl(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(R5_LSLW_IMM(AT, s2, simm)); \
		EMIT(R5_ADDW_REG(d, s1, AT)); \
	} else	EMIT(R5_ADDW_REG(d, s1, s2)); \
} while (0)

#define emith_add_r_r_r_lsr(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(R5_LSRW_IMM(AT, s2, simm)); \
		EMIT(R5_ADDW_REG(d, s1, AT)); \
	} else	EMIT(R5_ADDW_REG(d, s1, s2)); \
} while (0)

#define emith_addf_r_r_r_lsl_ptr(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(R5_LSL_IMM(AT, s2, simm)); \
		EMIT(R5_ADD_REG(FNZ, s1, AT)); \
		emith_set_arith_flags(d, s1, AT, 0, 0); \
	} else { \
		EMIT(R5_ADD_REG(FNZ, s1, s2)); \
		emith_set_arith_flags(d, s1, s2, 0, 0); \
	} \
} while (0)
#define emith_addf_r_r_r_lsl(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(R5_LSLW_IMM(AT, s2, simm)); \
		EMIT(R5_ADDW_REG(FNZ, s1, AT)); \
		emith_set_arith_flags(d, s1, AT, 0, 0); \
	} else { \
		EMIT(R5_ADDW_REG(FNZ, s1, s2)); \
		emith_set_arith_flags(d, s1, s2, 0, 0); \
	} \
} while (0)

#define emith_addf_r_r_r_lsr(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(R5_LSRW_IMM(AT, s2, simm)); \
		EMIT(R5_ADDW_REG(FNZ, s1, AT)); \
		emith_set_arith_flags(d, s1, AT, 0, 0); \
	} else { \
		EMIT(R5_ADDW_REG(FNZ, s1, s2)); \
		emith_set_arith_flags(d, s1, s2, 0, 0); \
	} \
} while (0)

#define emith_sub_r_r_r_lsl(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(R5_LSLW_IMM(AT, s2, simm)); \
		EMIT(R5_SUBW_REG(d, s1, AT)); \
	} else	EMIT(R5_SUBW_REG(d, s1, s2)); \
} while (0)

#define emith_subf_r_r_r_lsl(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(R5_LSLW_IMM(AT, s2, simm)); \
		EMIT(R5_SUBW_REG(FNZ, s1, AT)); \
		emith_set_arith_flags(d, s1, AT, 0, 1); \
	} else { \
		EMIT(R5_SUBW_REG(FNZ, s1, s2)); \
		emith_set_arith_flags(d, s1, s2, 0, 1); \
	} \
} while (0)

#define emith_or_r_r_r_lsl(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(R5_LSLW_IMM(AT, s2, simm)); \
		EMIT(R5_OR_REG(d, s1, AT)); \
	} else	EMIT(R5_OR_REG(d, s1, s2)); \
} while (0)

#define emith_or_r_r_r_lsr(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(R5_LSRW_IMM(AT, s2, simm)); \
		EMIT(R5_OR_REG(d, s1, AT)); \
	} else  EMIT(R5_OR_REG(d, s1, s2)); \
} while (0)

#define emith_eor_r_r_r_lsl(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(R5_LSLW_IMM(AT, s2, simm)); \
		EMIT(R5_XOR_REG(d, s1, AT)); \
	} else	EMIT(R5_XOR_REG(d, s1, s2)); \
} while (0)

#define emith_eor_r_r_r_lsr(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(R5_LSRW_IMM(AT, s2, simm)); \
		EMIT(R5_XOR_REG(d, s1, AT)); \
	} else	EMIT(R5_XOR_REG(d, s1, s2)); \
} while (0)

#define emith_and_r_r_r_lsl(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(R5_LSLW_IMM(AT, s2, simm)); \
		EMIT(R5_AND_REG(d, s1, AT)); \
	} else	EMIT(R5_AND_REG(d, s1, s2)); \
} while (0)

#define emith_or_r_r_lsl(d, s, lslimm) \
	emith_or_r_r_r_lsl(d, d, s, lslimm)
#define emith_or_r_r_lsr(d, s, lsrimm) \
	emith_or_r_r_r_lsr(d, d, s, lsrimm)

#define emith_eor_r_r_lsl(d, s, lslimm) \
	emith_eor_r_r_r_lsl(d, d, s, lslimm)
#define emith_eor_r_r_lsr(d, s, lsrimm) \
	emith_eor_r_r_r_lsr(d, d, s, lsrimm)

#define emith_add_r_r_r_ptr(d, s1, s2) \
	emith_add_r_r_r_lsl_ptr(d, s1, s2, 0)
#define emith_add_r_r_r(d, s1, s2) \
	emith_add_r_r_r_lsl(d, s1, s2, 0)

#define emith_addf_r_r_r_ptr(d, s1, s2) \
	emith_addf_r_r_r_lsl_ptr(d, s1, s2, 0)
#define emith_addf_r_r_r(d, s1, s2) \
	emith_addf_r_r_r_ptr(d, s1, s2)

#define emith_sub_r_r_r(d, s1, s2) \
	emith_sub_r_r_r_lsl(d, s1, s2, 0)

#define emith_subf_r_r_r(d, s1, s2) \
	emith_subf_r_r_r_lsl(d, s1, s2, 0)

#define emith_or_r_r_r(d, s1, s2) \
	emith_or_r_r_r_lsl(d, s1, s2, 0)

#define emith_eor_r_r_r(d, s1, s2) \
	emith_eor_r_r_r_lsl(d, s1, s2, 0)

#define emith_and_r_r_r(d, s1, s2) \
	emith_and_r_r_r_lsl(d, s1, s2, 0)

#define emith_add_r_r_ptr(d, s) \
	emith_add_r_r_r_lsl_ptr(d, d, s, 0)
#define emith_add_r_r(d, s) \
	emith_add_r_r_r(d, d, s)

#define emith_sub_r_r(d, s) \
	emith_sub_r_r_r(d, d, s)

#define emith_neg_r_r(d, s) \
	EMIT(R5_NEGW_REG(d, s))

#define emith_adc_r_r_r(d, s1, s2) do { \
	emith_add_r_r_r(AT, s2, FC); \
	emith_add_r_r_r(d, s1, AT); \
} while (0)

#define emith_sbc_r_r_r(d, s1, s2) do { \
	emith_add_r_r_r(AT, s2, FC); \
	emith_sub_r_r_r(d, s1, AT); \
} while (0)

#define emith_adc_r_r(d, s) \
	emith_adc_r_r_r(d, d, s)

#define emith_negc_r_r(d, s) \
	emith_sbc_r_r_r(d, Z0, s)

// NB: the incoming carry Cin can cause Cout if s2+Cin=0 (or s1+Cin=0 FWIW)
// moreover, if s2+Cin=0 caused Cout, s1+s2+Cin=s1+0 can't cause another Cout
#define emith_adcf_r_r_r(d, s1, s2) do { \
	emith_add_r_r_r(FNZ, s2, FC); \
	EMIT(R5_SLTU_REG(AT, FNZ, FC)); \
	emith_add_r_r_r(FNZ, s1, FNZ); \
	emith_set_arith_flags(d, s1, s2, 0, 0); \
	emith_or_r_r(FC, AT); \
} while (0)

#define emith_sbcf_r_r_r(d, s1, s2) do { \
	emith_add_r_r_r(FNZ, s2, FC); \
	EMIT(R5_SLTU_REG(AT, FNZ, FC)); \
	emith_sub_r_r_r(FNZ, s1, FNZ); \
	emith_set_arith_flags(d, s1, s2, 0, 1); \
	emith_or_r_r(FC, AT); \
} while (0)

#define emith_and_r_r(d, s) \
	emith_and_r_r_r(d, d, s)
#define emith_and_r_r_c(cond, d, s) \
	emith_and_r_r(d, s)

#define emith_or_r_r(d, s) \
	emith_or_r_r_r(d, d, s)

#define emith_eor_r_r(d, s) \
	emith_eor_r_r_r(d, d, s)

#define emith_tst_r_r_ptr(d, s) do { \
	if (d != s) { \
		emith_and_r_r_r(FNZ, d, s); \
		emith_cmp_rs = emith_cmp_rt = -1; \
	} else	emith_cmp_rs = s, emith_cmp_rt = Z0; \
} while (0)
#define emith_tst_r_r(d, s) \
	emith_tst_r_r_ptr(d, s)

#define emith_teq_r_r(d, s) do { \
	emith_eor_r_r_r(FNZ, d, s); \
	emith_cmp_rs = emith_cmp_rt = -1; \
} while (0)

#define emith_cmp_r_r(d, s) \
	emith_set_compare_flags(d, s, 0)
//	emith_subf_r_r_r(FNZ, d, s)

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
#define MAX_HOST_LITERALS	32	// pool must be smaller than 4 KB
static uintptr_t literal_pool[MAX_HOST_LITERALS];
static u32 *literal_insn[MAX_HOST_LITERALS];
static int literal_pindex, literal_iindex;

static inline int emith_pool_literal(uintptr_t imm)
{
	int idx = literal_pindex - 8; // max look behind in pool
	// see if one of the last literals was the same
	for (idx = (idx < 0 ? 0 : idx); idx < literal_pindex; idx++)
		if (imm == literal_pool[idx])
			break;
	if (idx == literal_pindex)	// store new literal
		literal_pool[literal_pindex++] = imm;
	return idx;
}

static void emith_pool_commit(int jumpover)
{
	int i, sz = literal_pindex * sizeof(uintptr_t);
	u8 *pool = (u8 *)tcache_ptr;

	// nothing to commit if pool is empty
	if (sz == 0)
		return;
	// align pool to pointer size
	if (jumpover)
		pool += sizeof(u32);
	i = (uintptr_t)pool & (sizeof(void *)-1);
	pool += (i ? sizeof(void *)-i : 0);
	// need branch over pool if not at block end
	if (jumpover)
		EMIT(R5_B(sz + (pool-(u8 *)tcache_ptr)));
	// safety check - pool must be after insns and reachable
	if ((u32)(pool - (u8 *)literal_insn[0] + 8) > 0x7ff) {
		elprintf(EL_STATUS|EL_SVP|EL_ANOMALY,
			"pool offset out of range");
		exit(1);
	}
	// copy pool and adjust addresses in insns accessing the pool
	memcpy(pool, literal_pool, sz);
	for (i = 0; i < literal_iindex; i++) {
		*literal_insn[i] += ((u8 *)pool - (u8 *)literal_insn[i]) << 20;
	}
	// count pool constants as insns for statistics
	for (i = 0; i < literal_pindex * sizeof(uintptr_t)/sizeof(u32); i++)
		COUNT_OP;

	tcache_ptr = (void *)((u8 *)pool + sz);
	literal_pindex = literal_iindex = 0;
}

static void emith_pool_check(void)
{
	// check if pool must be committed
	if (literal_iindex > MAX_HOST_LITERALS-4 || (literal_pindex &&
		    (u8 *)tcache_ptr - (u8 *)literal_insn[0] > 0x700))
		// pool full, or displacement is approaching the limit
		emith_pool_commit(1);
}

static void emith_move_imm(int r, uintptr_t imm)
{
	u32 lui = imm + _CB(imm,1,11,12); // compensate for ADDI sign extension
	if (lui >> 12) {
		EMIT(R5_MOVT_IMM(r, lui));
		if (imm & 0xfff)
			EMIT(R5_ADDW_IMM(r, r, imm));
	} else
		EMIT(R5_ADDW_IMM(r, Z0, imm));
}

static void emith_move_ptr_imm(int r, uintptr_t imm)
{
#if __riscv_xlen == 64
	uintptr_t offs = (u8 *)imm - (u8 *)tcache_ptr;
	if ((s32)imm != imm && (s32)offs == offs) {
		// PC relative
		EMIT(R5_MOVA_IMM(r, offs + _CB(offs,1,11,12)));
		if (offs & 0xfff)
			EMIT(R5_ADD_IMM(r, r, offs));
	} else if ((s32)imm != imm) {
		// via literal pool
		int idx;
		if (literal_iindex >= MAX_HOST_LITERALS)
			emith_pool_commit(1);
		idx = emith_pool_literal(imm);
		EMIT(R5_MOVA_IMM(AT, 0)); // loads PC of MOVA insn... + 4 in LD
		literal_insn[literal_iindex++] = (u32 *)tcache_ptr;
		EMIT(R5_I_INSN(OP_LD, F1_P, r, AT, idx*sizeof(uintptr_t) + 4));
	} else
#endif
		emith_move_imm(r, imm);
}

#define emith_move_r_ptr_imm(r, imm) \
	emith_move_ptr_imm(r, (uintptr_t)(imm))

#define emith_move_r_imm(r, imm) \
	emith_move_imm(r, (u32)(imm))
#define emith_move_r_imm_c(cond, r, imm) \
	emith_move_r_imm(r, imm)

#define emith_move_r_imm_s8_patchable(r, imm) \
	EMIT(R5_ADD_IMM(r, Z0, (s8)(imm)))
#define emith_move_r_imm_s8_patch(ptr, imm) do { \
	u32 *ptr_ = (u32 *)ptr; \
	EMIT_PTR(ptr_, (*ptr_ & 0x000fffff) | ((u16)(s8)(imm)<<20)); \
} while (0)

// arithmetic/logical, immediate - R5 always takes a signed 12 bit immediate

static void emith_op_imm(int f1, int rd, int rs, u32 imm)
{
	int op32 = (f1 == F1_ADD ? R5_OP32 : 0);
	if ((imm + _CB(imm,1,11,12)) >> 12) {
		emith_move_r_imm(AT, imm);
		EMIT(R5_R_INSN(OP_REG^op32, f1&7,_, rd, rs, AT));
	} else if (imm || f1 == F1_AND || rd != rs)
		EMIT(R5_I_INSN(OP_IMM^op32, f1&7, rd, rs, imm));
}

// arithmetic, immediate - can only be ADDI, since SUBI doesn't exist
#define emith_add_r_imm(r, imm) \
	emith_add_r_r_imm(r, r, imm)
#define emith_add_r_imm_c(cond, r, imm) \
	emith_add_r_imm(r, imm)

#define emith_addf_r_imm(r, imm) \
	emith_addf_r_r_imm(r, imm)

#define emith_sub_r_imm(r, imm) \
	emith_sub_r_r_imm(r, r, imm)
#define emith_sub_r_imm_c(cond, r, imm) \
	emith_sub_r_imm(r, imm)

#define emith_subf_r_imm(r, imm) \
	emith_subf_r_r_imm(r, r, imm)

#define emith_adc_r_imm(r, imm) \
	emith_adc_r_r_imm(r, r, imm);

#define emith_adcf_r_imm(r, imm) \
	emith_adcf_r_r_imm(r, r, imm)

#define emith_cmp_r_imm(r, imm) \
	emith_set_compare_flags(r, -1, imm)
//	emith_subf_r_r_imm(FNZ, r, imm)

#define emith_add_r_r_ptr_imm(d, s, imm) \
	emith_op_imm(F1_ADD|F2_ALT, d, s, imm)

#define emith_add_r_r_imm(d, s, imm) \
	emith_op_imm(F1_ADD, d, s, imm)

#define emith_addf_r_r_imm(d, s, imm) do { \
	emith_add_r_r_imm(FNZ, s, imm); \
	emith_set_arith_flags(d, s, -1, imm, 0); \
} while (0)

#define emith_adc_r_r_imm(d, s, imm) do { \
	emith_add_r_r_r(AT, s, FC); \
	emith_add_r_r_imm(d, AT, imm); \
} while (0)

#define emith_adcf_r_r_imm(d, s, imm) do { \
	if (imm == 0) { \
		emith_add_r_r_r(FNZ, s, FC); \
		emith_set_arith_flags(d, s, -1, 1, 0); \
	} else { \
		emith_add_r_r_r(FNZ, s, FC); \
		EMIT(R5_SLTU_REG(AT, FNZ, FC)); \
		emith_add_r_r_imm(FNZ, FNZ, imm); \
		emith_set_arith_flags(d, s, -1, imm, 0); \
		emith_or_r_r(FC, AT); \
	} \
} while (0)

// NB: no SUBI in R5, since ADDI takes a signed imm
#define emith_sub_r_r_imm(d, s, imm) \
	emith_add_r_r_imm(d, s, -(imm))
#define emith_sub_r_r_imm_c(cond, d, s, imm) \
	emith_sub_r_r_imm(d, s, imm)

#define emith_subf_r_r_imm(d, s, imm) do { \
	emith_sub_r_r_imm(FNZ, s, imm); \
	emith_set_arith_flags(d, s, -1, imm, 1); \
} while (0)

// logical, immediate
#define emith_and_r_imm(r, imm) \
	emith_op_imm(F1_AND, r, r, imm)

#define emith_or_r_imm(r, imm) \
	emith_op_imm(F1_OR, r, r, imm)
#define emith_or_r_imm_c(cond, r, imm) \
	emith_or_r_imm(r, imm)

#define emith_eor_r_imm_ptr(r, imm) \
	emith_op_imm(F1_XOR, r, r, imm)
#define emith_eor_r_imm_ptr_c(cond, r, imm) \
	emith_eor_r_imm_ptr(r, imm)

#define emith_eor_r_imm(r, imm) \
	emith_eor_r_imm_ptr(r, imm)
#define emith_eor_r_imm_c(cond, r, imm) \
	emith_eor_r_imm(r, imm)

/* NB: BIC #imm not available in R5; use AND #~imm instead */
#define emith_bic_r_imm(r, imm) \
	emith_op_imm(F1_AND, r, r, ~(imm))
#define emith_bic_r_imm_c(cond, r, imm) \
	emith_bic_r_imm(r, imm)

#define emith_tst_r_imm(r, imm) do { \
	emith_op_imm(F1_AND, FNZ, r, imm); \
	emith_cmp_rs = emith_cmp_rt = -1; \
} while (0)
#define emith_tst_r_imm_c(cond, r, imm) \
	emith_tst_r_imm(r, imm)

#define emith_and_r_r_imm(d, s, imm) \
	emith_op_imm(F1_AND, d, s, imm)

#define emith_or_r_r_imm(d, s, imm) \
	emith_op_imm(F1_OR, d, s, imm)

#define emith_eor_r_r_imm(d, s, imm) \
	emith_op_imm(F1_XOR, d, s, imm)

// shift
#define emith_lsl(d, s, cnt) \
	EMIT(R5_LSLW_IMM(d, s, cnt))

#define emith_lsr(d, s, cnt) \
	EMIT(R5_LSRW_IMM(d, s, cnt))

#define emith_asr(d, s, cnt) \
	EMIT(R5_ASRW_IMM(d, s, cnt))

#define emith_ror(d, s, cnt) do { \
	EMIT(R5_LSLW_IMM(AT, s, 32-(cnt))); \
	EMIT(R5_LSRW_IMM(d, s, cnt)); \
	EMIT(R5_OR_REG(d, d, AT)); \
} while (0)
#define emith_ror_c(cond, d, s, cnt) \
	emith_ror(d, s, cnt)

#define emith_rol(d, s, cnt) do { \
	EMIT(R5_LSRW_IMM(AT, s, 32-(cnt))); \
	EMIT(R5_LSLW_IMM(d, s, cnt)); \
	EMIT(R5_OR_REG(d, d, AT)); \
} while (0)

#define emith_rorc(d) do { \
	emith_lsr(d, d, 1); \
	emith_lsl(AT, FC, 31); \
	emith_or_r_r(d, AT); \
} while (0)

#define emith_rolc(d) do { \
	emith_lsl(d, d, 1); \
	emith_or_r_r(d, FC); \
} while (0)

// NB: all flag setting shifts make V undefined
#define emith_lslf(d, s, cnt) do { \
	int _s = s; \
	if ((cnt) > 1) { \
		emith_lsl(d, s, cnt-1); \
		_s = d; \
	} \
	if ((cnt) > 0) { \
		emith_lsr(FC, _s, 31); \
		emith_lsl(d, _s, 1); \
	} \
	emith_move_r_r(FNZ, d); \
	emith_cmp_rs = emith_cmp_rt = -1; \
} while (0)

#define emith_lsrf(d, s, cnt) do { \
	int _s = s; \
	if ((cnt) > 1) { \
		emith_lsr(d, s, cnt-1); \
		_s = d; \
	} \
	if ((cnt) > 0) { \
		emith_and_r_r_imm(FC, _s, 1); \
		emith_lsr(d, _s, 1); \
	} \
	emith_move_r_r(FNZ, d); \
	emith_cmp_rs = emith_cmp_rt = -1; \
} while (0)

#define emith_asrf(d, s, cnt) do { \
	int _s = s; \
	if ((cnt) > 1) { \
		emith_asr(d, s, cnt-1); \
		_s = d; \
	} \
	if ((cnt) > 0) { \
		emith_and_r_r_imm(FC, _s, 1); \
		emith_asr(d, _s, 1); \
	} \
	emith_move_r_r(FNZ, d); \
	emith_cmp_rs = emith_cmp_rt = -1; \
} while (0)

#define emith_rolf(d, s, cnt) do { \
	emith_rol(d, s, cnt); \
	emith_and_r_r_imm(FC, d, 1); \
	emith_move_r_r(FNZ, d); \
	emith_cmp_rs = emith_cmp_rt = -1; \
} while (0)

#define emith_rorf(d, s, cnt) do { \
	emith_ror(d, s, cnt); \
	emith_lsr(FC, d, 31); \
	emith_move_r_r(FNZ, d); \
	emith_cmp_rs = emith_cmp_rt = -1; \
} while (0)

#define emith_rolcf(d) do { \
	emith_lsr(AT, d, 31); \
	emith_lsl(d, d, 1); \
	emith_or_r_r(d, FC); \
	emith_move_r_r(FC, AT); \
	emith_move_r_r(FNZ, d); \
	emith_cmp_rs = emith_cmp_rt = -1; \
} while (0)

#define emith_rorcf(d) do { \
	emith_and_r_r_imm(AT, d, 1); \
	emith_lsr(d, d, 1); \
	emith_lsl(FC, FC, 31); \
	emith_or_r_r(d, FC); \
	emith_move_r_r(FC, AT); \
	emith_move_r_r(FNZ, d); \
	emith_cmp_rs = emith_cmp_rt = -1; \
} while (0)

// signed/unsigned extend

#define emith_clear_msb(d, s, count) /* bits to clear */ do { \
	u32 t; \
	if ((count) >= 21) { \
		t = (count) - 21; \
		t = 0x7ff >> t; \
		emith_and_r_r_imm(d, s, t); \
	} else { \
		emith_lsl(d, s, count); \
		emith_lsr(d, d, count); \
	} \
} while (0)
#define emith_clear_msb_c(cond, d, s, count) \
	emith_clear_msb(d, s, count)

#define emith_sext(d, s, count) /* bits to keep */ do { \
	emith_lsl(d, s, 32-(count)); \
	emith_asr(d, d, 32-(count)); \
} while (0)

// multiply Rd = Rn*Rm (+ Ra)

#define emith_mul(d, s1, s2) \
	EMIT(R5_MULW(d, s1, s2)) \

#define emith_mul_u64(dlo, dhi, s1, s2) \
	EMIT_R5_MULLU_REG(dlo, dhi, s1, s2)

#define emith_mul_s64(dlo, dhi, s1, s2) \
	EMIT_R5_MULLS_REG(dlo, dhi, s1, s2)

#define emith_mula_s64(dlo, dhi, s1, s2) do { \
	int t_ = rcache_get_tmp(); \
	EMIT_R5_MULLS_REG(t_, AT, s1, s2); \
	emith_add_r_r(dhi, AT); \
	emith_add_r_r(dlo, t_); \
	EMIT(R5_SLTU_REG(AT, dlo, t_)); \
	emith_add_r_r(dhi, AT); \
	rcache_free_tmp(t_); \
} while (0)
#define emith_mula_s64_c(cond, dlo, dhi, s1, s2) \
	emith_mula_s64(dlo, dhi, s1, s2)

// load/store. offs has 12 bits signed, hence larger offs may use a temp
static void emith_ld_offs(int sz, int rd, int rs, int o12)
{
	if (o12 >= -0x800 && o12 < 0x800) {
		EMIT(R5_I_INSN(OP_LD, sz, rd, rs, o12));
	} else {
		EMIT(R5_MOVT_IMM(AT, o12 + _CB(o12,1,11,12))); \
		EMIT(R5_ADD_REG(AT, rs, AT)); \
		EMIT(R5_I_INSN(OP_LD, sz, rd, AT, o12));
	}
}

#define emith_read_r_r_offs_ptr(r, rs, offs) \
	emith_ld_offs(F1_P, r, rs, offs)
#define emith_read_r_r_offs_ptr_c(cond, r, rs, offs) \
	emith_read_r_r_offs_ptr(r, rs, offs)

#define emith_read_r_r_offs(r, rs, offs) \
	emith_ld_offs(F1_W, r, rs, offs)
#define emith_read_r_r_offs_c(cond, r, rs, offs) \
	emith_read_r_r_offs(r, rs, offs)
 
#define emith_read_r_r_r_ptr(r, rs, rm) do { \
	emith_add_r_r_r_ptr(AT, rs, rm); \
	emith_ld_offs(F1_P, r, AT, 0); \
} while (0)
#define emith_read_r_r_r(r, rs, rm) do { \
	emith_add_r_r_r_ptr(AT, rs, rm); \
	emith_ld_offs(F1_W, r, AT, 0); \
} while (0)
#define emith_read_r_r_r_c(cond, r, rs, rm) \
	emith_read_r_r_r(r, rs, rm)

#define emith_read8_r_r_offs(r, rs, offs) \
	emith_ld_offs(F1_BU, r, rs, offs)
#define emith_read8_r_r_offs_c(cond, r, rs, offs) \
	emith_read8_r_r_offs(r, rs, offs)

#define emith_read8_r_r_r(r, rs, rm) do { \
	emith_add_r_r_r_ptr(AT, rs, rm); \
	emith_ld_offs(F1_BU, r, AT, 0); \
} while (0)
#define emith_read8_r_r_r_c(cond, r, rs, rm) \
	emith_read8_r_r_r(r, rs, rm)

#define emith_read16_r_r_offs(r, rs, offs) \
	emith_ld_offs(F1_HU, r, rs, offs)
#define emith_read16_r_r_offs_c(cond, r, rs, offs) \
	emith_read16_r_r_offs(r, rs, offs)

#define emith_read16_r_r_r(r, rs, rm) do { \
	emith_add_r_r_r_ptr(AT, rs, rm); \
	emith_ld_offs(F1_HU, r, AT, 0); \
} while (0)
#define emith_read16_r_r_r_c(cond, r, rs, rm) \
	emith_read16_r_r_r(r, rs, rm)

#define emith_read8s_r_r_offs(r, rs, offs) \
	emith_ld_offs(F1_B, r, rs, offs)
#define emith_read8s_r_r_offs_c(cond, r, rs, offs) \
	emith_read8s_r_r_offs(r, rs, offs)

#define emith_read8s_r_r_r(r, rs, rm) do { \
	emith_add_r_r_r_ptr(AT, rs, rm); \
	emith_ld_offs(F1_B, r, AT, 0); \
} while (0)
#define emith_read8s_r_r_r_c(cond, r, rs, rm) \
	emith_read8s_r_r_r(r, rs, rm)

#define emith_read16s_r_r_offs(r, rs, offs) \
	emith_ld_offs(F1_H, r, rs, offs)
#define emith_read16s_r_r_offs_c(cond, r, rs, offs) \
	emith_read16s_r_r_offs(r, rs, offs)

#define emith_read16s_r_r_r(r, rs, rm) do { \
	emith_add_r_r_r_ptr(AT, rs, rm); \
	emith_ld_offs(F1_H, r, AT, 0); \
} while (0)
#define emith_read16s_r_r_r_c(cond, r, rs, rm) \
	emith_read16s_r_r_r(r, rs, rm)

static void emith_st_offs(int sz, int rt, int rs, int o12)
{
	if (o12 >= -0x800 && o12 < 800) {
		EMIT(R5_S_INSN(OP_ST, sz, rt, rs, o12));
	} else {
		EMIT(R5_MOVT_IMM(AT, o12 + _CB(o12,1,11,12))); \
		EMIT(R5_ADD_REG(AT, rs, AT)); \
		EMIT(R5_S_INSN(OP_ST, sz, rt, AT, o12));
	}
}

#define emith_write_r_r_offs_ptr(r, rs, offs) \
	emith_st_offs(F1_P, r, rs, offs)
#define emith_write_r_r_offs_ptr_c(cond, r, rs, offs) \
	emith_write_r_r_offs_ptr(r, rs, offs)

#define emith_write_r_r_r_ptr(r, rs, rm) do { \
	emith_add_r_r_r_ptr(AT, rs, rm); \
	emith_st_offs(F1_P, r, AT, 0); \
} while (0)
#define emith_write_r_r_r_ptr_c(cond, r, rs, rm) \
	emith_write_r_r_r_ptr(r, rs, rm)

#define emith_write_r_r_offs(r, rs, offs) \
	emith_st_offs(F1_W, r, rs, offs)
#define emith_write_r_r_offs_c(cond, r, rs, offs) \
	emith_write_r_r_offs(r, rs, offs)

#define emith_write_r_r_r(r, rs, rm) do { \
	emith_add_r_r_r_ptr(AT, rs, rm); \
	emith_st_offs(F1_W, r, AT, 0); \
} while (0)
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

// function call handling
#define emith_save_caller_regs(mask) do { \
	int _c, _z = PTR_SIZE; u32 _m = mask & 0x3fce0; /* x5-x7,x10-x17 */ \
	_c = count_bits(_m)&3; _m |= (1<<((4-_c)&3))-1; /* ABI align */ \
	int _s = count_bits(_m) * _z, _o = _s; \
	if (_s) emith_add_r_r_ptr_imm(SP, SP, -_s); \
	for (_c = HOST_REGS-1; _m && _c >= 0; _m &= ~(1 << _c), _c--) \
		if (_m & (1 << _c)) \
			{ _o -= _z; if (_c) emith_write_r_r_offs_ptr(_c, SP, _o); } \
} while (0)

#define emith_restore_caller_regs(mask) do { \
	int _c, _z =  PTR_SIZE; u32 _m = mask & 0x3fce0; \
	_c = count_bits(_m)&3; _m |= (1<<((4-_c)&3))-1; /* ABI align */ \
	int _s = count_bits(_m) * _z, _o = 0; \
	for (_c = 0; _m && _c < HOST_REGS; _m &= ~(1 << _c), _c++) \
		if (_m & (1 << _c)) \
			{ if (_c) emith_read_r_r_offs_ptr(_c, SP, _o); _o += _z; } \
	if (_s) emith_add_r_r_ptr_imm(SP, SP, _s); \
} while (0)

#define host_call(addr, args) \
	addr

#define host_arg2reg(rd, arg) \
	rd = (arg+10)

#define emith_pass_arg_r(arg, reg) \
	emith_move_r_r_ptr(arg, reg)

#define emith_pass_arg_imm(arg, imm) \
	emith_move_r_ptr_imm(arg, imm)

// branching
#define emith_invert_branch(cond) /* inverted conditional branch */ \
	((cond) ^ 0x01)

// evaluate the emulated condition, returns a register/branch type pair
static int emith_cmpr_check(int rs, int rt, int cond, int *r, int *s)
{
	int b = -1;

	// condition check for comparing 2 registers
	switch (cond) {
	case DCOND_EQ:	*r = rs; *s = rt; b = F1_BEQ; break;
	case DCOND_NE:	*r = rs; *s = rt; b = F1_BNE; break;
	case DCOND_LO:	*r = rs, *s = rt, b = F1_BLTU; break;   // s <  t, u
	case DCOND_HS:	*r = rs, *s = rt, b = F1_BGEU; break;   // s >= t, u
	case DCOND_LS:	*r = rt, *s = rs, b = F1_BGEU; break;   // s <= t, u
	case DCOND_HI:	*r = rt, *s = rs, b = F1_BLTU; break;   // s >  t, u
	case DCOND_LT:	*r = rs, *s = rt, b = F1_BLT; break;    // s <  t
	case DCOND_GE:	*r = rs, *s = rt, b = F1_BGE; break;    // s >= t
	case DCOND_LE:	*r = rt, *s = rs, b = F1_BGE; break;    // s <= t
	case DCOND_GT:	*r = rt, *s = rs, b = F1_BLT; break;    // s >  t
	}

	return b;
}

static int emith_cmpi_check(int rs, s32 imm, int cond, int *r, int *s)
{
	int b = -1;

	// condition check for comparing register with immediate
	if (imm == 0) return emith_cmpr_check(rs, Z0, cond, r, s);

	emith_move_r_imm(AT, imm);
	switch (cond) {
	case DCOND_EQ:	*r = AT, *s = rs, b = F1_BEQ; break;
	case DCOND_NE:	*r = AT, *s = rs, b = F1_BNE; break;
	case DCOND_LO:	*r = rs, *s = AT, b = F1_BLTU; break;   // s <  imm, u
	case DCOND_HS:	*r = rs, *s = AT, b = F1_BGEU; break;   // s >= imm, u
	case DCOND_LS:	*r = AT, *s = rs, b = F1_BGEU; break;   // s <= imm, u
	case DCOND_HI:	*r = AT, *s = rs, b = F1_BLTU; break;   // s >  imm, u
	case DCOND_LT:	*r = rs, *s = AT, b = F1_BLT; break;    // s <  imm
	case DCOND_GE:	*r = rs, *s = AT, b = F1_BGE; break;    // s >= imm
	case DCOND_LE:	*r = AT, *s = rs, b = F1_BGE; break;    // s <= imm
	case DCOND_GT:	*r = AT, *s = rs, b = F1_BLT; break;    // s >  imm
	}
	return b;
}

static int emith_cond_check(int cond, int *r, int *s)
{
	int b = -1;

	*s = *r = Z0;
	if (emith_cmp_rs >= 0) {
		if (emith_cmp_rt != -1)
			b = emith_cmpr_check(emith_cmp_rs,emith_cmp_rt, cond,r,s);
		else	b = emith_cmpi_check(emith_cmp_rs,emith_cmp_imm,cond,r,s);
	}

	// shortcut for V known to be 0
	if (b < 0 && emith_flg_noV) switch (cond) {
	case DCOND_VS:	*r = Z0; b = F1_BNE; break;		// never
	case DCOND_VC:	*r = Z0; b = F1_BEQ; break;		// always
	case DCOND_LT:	*r = FNZ, b = F1_BLT;	break;		// N
	case DCOND_GE:	*r = FNZ, b = F1_BGE;	break;		// !N
	case DCOND_LE:	*r = Z0, *s = FNZ, b = F1_BGE;	break;	// N || Z
	case DCOND_GT:	*r = Z0, *s = FNZ, b = F1_BLT;	break;	// !N && !Z
	}

	// the full monty if no shortcut
	if (b < 0) switch (cond) {
	// conditions using NZ
	case DCOND_EQ:	*r = FNZ; b = F1_BEQ; break;		// Z
	case DCOND_NE:	*r = FNZ; b = F1_BNE; break;		// !Z
	case DCOND_MI:	*r = FNZ; b = F1_BLT; break;		// N
	case DCOND_PL:	*r = FNZ; b = F1_BGE; break;		// !N
	// conditions using C
	case DCOND_LO:	*r = FC; b = F1_BNE; break;		// C
	case DCOND_HS:	*r = FC; b = F1_BEQ; break;		// !C
	// conditions using CZ
	case DCOND_LS:						// C || Z
	case DCOND_HI:						// !C && !Z
		EMIT(R5_ADD_IMM(AT, FC, -1)); // !C && !Z
		EMIT(R5_AND_REG(AT, FNZ, AT));
		*r = AT, b = (cond == DCOND_HI ? F1_BNE : F1_BEQ);
		break;

	// conditions using V
	case DCOND_VS:						// V
	case DCOND_VC:						// !V
		EMIT(R5_XOR_REG(AT, FV, FNZ)); // V = Nt^Ns^Nd^C
		EMIT(R5_LSRW_IMM(AT, AT, 31));
		EMIT(R5_XOR_REG(AT, AT, FC));
		*r = AT, b = (cond == DCOND_VS ? F1_BNE : F1_BEQ);
		break;
	// conditions using VNZ
	case DCOND_LT:						// N^V
	case DCOND_GE:						// !(N^V)
		EMIT(R5_LSRW_IMM(AT, FV, 31)); // Nd^V = Nt^Ns^C
		EMIT(R5_XOR_REG(AT, FC, AT));
		*r = AT, b = (cond == DCOND_LT ? F1_BNE : F1_BEQ);
		break;
	case DCOND_LE:						// (N^V) || Z
	case DCOND_GT:						// !(N^V) && !Z
		EMIT(R5_LSRW_IMM(AT, FV, 31)); // Nd^V = Nt^Ns^C
		EMIT(R5_XOR_REG(AT, FC, AT));
		EMIT(R5_ADD_IMM(AT, AT, -1)); // !(Nd^V) && !Z
		EMIT(R5_AND_REG(AT, FNZ, AT));
		*r = AT, b = (cond == DCOND_GT ? F1_BNE : F1_BEQ);
		break;
	}
	return b;
}

// NB: R5 unconditional jumps have only +/- 1MB range, hence use reg jumps
#define emith_jump(target) do { \
	uintptr_t target_ = (uintptr_t)(target) - (uintptr_t)tcache_ptr; \
	EMIT(R5_MOVA_IMM(AT, target_ + _CB(target_,1,11,12))); \
	EMIT(R5_JR(AT, target_));  \
} while (0)
#define emith_jump_patchable(target) \
	emith_jump(target)

// NB: R5 conditional branches have only +/- 4KB range
#define emith_jump_cond(cond, target) do { \
	int r_, s_, mcond_ = emith_cond_check(cond, &r_, &s_); \
	u32 disp_ = (u8 *)target - (u8 *)tcache_ptr; \
	EMIT(R5_BCOND(mcond_,r_,s_,disp_ & 0x00001fff)); \
} while (0)
#define emith_jump_cond_patchable(cond, target) \
	emith_jump_cond(cond, target)

#define emith_jump_cond_inrange(target) \
	((u8 *)target - (u8 *)tcache_ptr <   0x1000 && \
	 (u8 *)target - (u8 *)tcache_ptr >= -0x1000+0x10) // mind cond_check

// NB: returns position of patch for cache maintenance
#define emith_jump_patch(ptr, target, pos) do { \
	u32 *ptr_ = (u32 *)ptr; /* must skip condition check code */ \
	while ((*ptr_&0x77) != OP_BCOND && (*ptr_&0x77) != OP_AUIPC) ptr_ ++; \
	if ((*ptr_&0x77) == OP_BCOND) { \
		u32 *p_ = ptr_, disp_ = (u8 *)target - (u8 *)ptr_; \
		u32 f1_ = _CB(*ptr_,3,12,0); \
		u32 r_ = _CB(*ptr_,5,15,0), s_ = _CB(*ptr_,5,20,0); \
		EMIT_PTR(p_, R5_BCOND(f1_, r_, s_, disp_ & 0x00001fff)); \
	} else { \
		u32 *p_ = ptr_; \
		uintptr_t target_ = (uintptr_t)(target) - (uintptr_t)ptr_; \
		EMIT_PTR(p_, R5_MOVA_IMM(AT, target_ + _CB(target_,1,11,12))); \
		EMIT_PTR(p_, R5_JR(AT, target_));  \
	} \
	if ((void *)(pos) != NULL) *(u8 **)(pos) = (u8 *)(ptr_); \
} while (0)

#define emith_jump_patch_inrange(ptr, target) \
	((u8 *)target - (u8 *)ptr <   0x1000 && \
	 (u8 *)target - (u8 *)ptr >= -0x1000+0x10) // mind cond_check
#define emith_jump_patch_size() 8

#define emith_jump_at(ptr, target) do { \
	u32 *ptr_ = (u32 *)ptr; \
	uintptr_t target_ = (uintptr_t)(target) - (uintptr_t)ptr_; \
	EMIT_PTR(ptr_, R5_MOVA_IMM(AT, target_ + _CB(target_,1,11,12))); \
	EMIT_PTR(ptr_, R5_JR(AT, target_));  \
} while (0)
#define emith_jump_at_size() 8

#define emith_jump_reg(r) \
	EMIT(R5_JR(r, 0))
#define emith_jump_reg_c(cond, r) \
	emith_jump_reg(r)

#define emith_jump_ctx(offs) do { \
	emith_ctx_read_ptr(AT, offs); \
	emith_jump_reg(AT); \
} while (0)
#define emith_jump_ctx_c(cond, offs) \
	emith_jump_ctx(offs)

#define emith_call(target) do { \
	uintptr_t target_ = (uintptr_t)(target) - (uintptr_t)tcache_ptr; \
	EMIT(R5_MOVA_IMM(AT, target_ + _CB(target_,1,11,12))); \
	EMIT(R5_JALR(LR, AT, target_));  \
} while (0)
#define emith_call_cond(cond, target) \
	emith_call(target)

#define emith_call_reg(r) \
	EMIT(R5_JALR(LR, r, 0))

#define emith_abicall_ctx(offs) do { \
	emith_ctx_read_ptr(AT, offs); \
	emith_call_reg(AT); \
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
	EMIT(R5_JR(LR, 0))
#define emith_ret_c(cond) \
	emith_ret()

#define emith_ret_to_ctx(offs) \
	emith_ctx_write_ptr(LR, offs)

#define emith_add_r_ret(r) \
	emith_add_r_r_ptr(r, LR)

#define emith_push_ret(r) do { \
	emith_add_r_r_ptr_imm(SP, SP, -16); /* ABI requires 16 byte aligment */\
	emith_write_r_r_offs_ptr(LR, SP, 8); \
	if ((r) > 0) emith_write_r_r_offs(r, SP, 0); \
} while (0)

#define emith_pop_and_ret(r) do { \
	if ((r) > 0) emith_read_r_r_offs(r, SP, 0); \
	emith_read_r_r_offs_ptr(LR, SP, 8); \
	emith_add_r_r_ptr_imm(SP, SP, 16); \
	emith_ret(); \
} while (0)


// emitter ABI stuff
#define emith_insn_ptr()	((u8 *)tcache_ptr)
#define	emith_flush()		/**/
#define host_instructions_updated(base, end, force) __builtin___clear_cache(base, end)
#define	emith_update_cache()	/**/
#define emith_rw_offs_max()	0x7ff
#define emith_uext_ptr(r)	/**/

// SH2 drc specific
#define emith_sh2_drc_entry() do { \
	int _c, _z = PTR_SIZE; u32 _m = 0x0ffc0202; /* x1,x9,x18-x27 */ \
	_c = count_bits(_m)&3; _m |= (1<<((4-_c)&3))-1; /* ABI align */ \
	int _s = count_bits(_m) * _z, _o = _s; \
	if (_s) emith_add_r_r_ptr_imm(SP, SP, -_s); \
	for (_c = HOST_REGS-1; _m && _c >= 0; _m &= ~(1 << _c), _c--) \
		if (_m & (1 << _c)) \
			{ _o -= _z; if (_c) emith_write_r_r_offs_ptr(_c, SP, _o); } \
} while (0)
#define emith_sh2_drc_exit() do { \
	int _c, _z = PTR_SIZE; u32 _m = 0x0ffc0202; \
	_c = count_bits(_m)&3; _m |= (1<<((4-_c)&3))-1; /* ABI align */ \
	int _s = count_bits(_m) * _z, _o = 0; \
	for (_c = 0; _m && _c < HOST_REGS; _m &= ~(1 << _c), _c++) \
		if (_m & (1 << _c)) \
			{ if (_c) emith_read_r_r_offs_ptr(_c, SP, _o); _o += _z; } \
	if (_s) emith_add_r_r_ptr_imm(SP, SP, _s); \
	emith_ret(); \
} while (0)

// NB: assumes a is in arg0, tab, func and mask are temp
#define emith_sh2_rcall(a, tab, func, mask) do { \
	emith_lsr(mask, a, SH2_READ_SHIFT); \
	emith_add_r_r_r_lsl_ptr(tab, tab, mask, PTR_SCALE+1); \
	emith_read_r_r_offs_ptr(func, tab, 0); \
	emith_read_r_r_offs(mask, tab, PTR_SIZE); \
	emith_addf_r_r_r_ptr(func, func, func); \
} while (0)

// NB: assumes a, val are in arg0 and arg1, tab and func are temp
#define emith_sh2_wcall(a, val, tab, func) do { \
	emith_lsr(func, a, SH2_WRITE_SHIFT); \
	emith_lsl(func, func, PTR_SCALE); \
	emith_read_r_r_r_ptr(func, tab, func); \
	emith_move_r_r_ptr(12, CONTEXT_REG); /* arg2 */ \
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
 * T = !carry(Rn = (Rn << 1) | T)
 * if Q
 *   C = carry(Rn += Rm)
 * else
 *   C = carry(Rn -= Rm)
 * T ^= C
 */
#define emith_sh2_div1_step(rn, rm, sr) do {      \
	int t_ = rcache_get_tmp();                \
	emith_and_r_r_imm(AT, sr, T);             \
	emith_lsr(FC, rn, 31); /*Rn = (Rn<<1)+T*/ \
	emith_lsl(t_, rn, 1);                     \
	emith_or_r_r(t_, AT);                     \
	emith_or_r_imm(sr, T); /* T = !carry */   \
	emith_eor_r_r(sr, FC);                    \
	emith_tst_r_imm(sr, Q);  /* if (Q ^ M) */ \
	EMITH_JMP3_START(DCOND_EQ);               \
	emith_add_r_r_r(rn, t_, rm);              \
	EMIT(R5_SLTU_REG(FC, rn, t_));            \
	EMITH_JMP3_MID(DCOND_EQ);                 \
	emith_sub_r_r_r(rn, t_, rm);              \
	EMIT(R5_SLTU_REG(FC, t_, rn));            \
	EMITH_JMP3_END();                         \
	emith_eor_r_r(sr, FC); /* T ^= carry */   \
	rcache_free_tmp(t_);                      \
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
	emith_add_r_r_r_lsr(rn, rn, mh, 31); /* sum = (MACH>>31)+(MACH>>15) */ \
	emith_teq_r_r(rn, Z0); /* (need only N and Z flags) */ \
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
	emith_lsr(rn, ml, 31);                    \
	emith_add_r_r(rn, mh); /* sum = MACH + ((MACL>>31)&1) */ \
	emith_teq_r_r(rn, Z0); /* (need only N and Z flags) */ \
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

#define emith_write_sr(sr, srcr) do { \
	emith_lsr(sr, sr  , 10); emith_lsl(sr, sr, 10); \
	emith_lsl(AT, srcr, 22); emith_lsr(AT, AT, 22); \
	emith_or_r_r(sr, AT); \
} while (0)

#define emith_carry_to_t(sr, is_sub) do { \
	emith_and_r_imm(sr, 0xfffffffe); \
	emith_or_r_r(sr, FC); \
} while (0)

#define emith_t_to_carry(sr, is_sub) do { \
	emith_and_r_r_imm(FC, sr, 1); \
} while (0)

#define emith_tpop_carry(sr, is_sub) do { \
	emith_and_r_r_imm(FC, sr, 1); \
	emith_eor_r_r(sr, FC); \
} while (0)

#define emith_tpush_carry(sr, is_sub) \
	emith_or_r_r(sr, FC)

#ifdef T
// T bit handling
#define emith_invert_cond(cond) \
	((cond) ^ 1)

static void emith_clr_t_cond(int sr)
{
  emith_bic_r_imm(sr, T);
}

static void emith_set_t_cond(int sr, int cond)
{
  int b, r, s;
  u8 *ptr;
  u32 val = 0, inv = 0;

  // try to avoid jumping around if possible
  b = emith_cond_check(cond, &r, &s);
  if (r == s) {
    if (b == F1_BEQ || b == F1_BGE || b == F1_BGEU)
      emith_or_r_imm(sr, T);
    return;
  } else if (r == FC)
    val++, inv = (b == F1_BEQ);

  if (!val) switch (b) {
  case F1_BEQ:  if (s == Z0) { EMIT(R5_SLTU_IMM(AT,r ,1)); r=AT; val++; break; }
                if (r == Z0) { EMIT(R5_SLTU_IMM(AT,s ,1)); r=AT; val++; break; }
                EMIT(R5_XOR_REG(AT, r, s));
                EMIT(R5_SLTU_IMM(AT,AT, 1)); r=AT; val++; break;
  case F1_BNE:  if (s == Z0) { EMIT(R5_SLTU_REG(AT,Z0,r)); r=AT; val++; break; }
                if (r == Z0) { EMIT(R5_SLTU_REG(AT,Z0,s)); r=AT; val++; break; }
                EMIT(R5_XOR_REG(AT, r, s));
                EMIT(R5_SLTU_REG(AT,Z0,AT)); r=AT; val++; break;
  case F1_BLTU: EMIT(R5_SLTU_REG(AT, r, s)); r=AT; val++; break;
  case F1_BGEU: EMIT(R5_SLTU_REG(AT, r, s)); r=AT; val++; inv++; break;
  case F1_BLT:  EMIT(R5_SLT_REG(AT, r, s)); r=AT; val++; break;
  case F1_BGE:  EMIT(R5_SLT_REG(AT, r, s)); r=AT; val++; inv++; break;
  }
  if (val) {
    emith_or_r_r(sr, r);
    if (inv)
      emith_eor_r_imm(sr, T);
    return;
  }

  // can't obtain result directly, use presumably slower jump !cond + or sr,T
  b = emith_invert_branch(b);
  ptr = tcache_ptr;
  EMIT(R5_BCOND(b, r, s, 0));
  emith_or_r_imm(sr, T);
  val = (u8 *)tcache_ptr - (u8 *)(ptr);
  EMIT_PTR(ptr, R5_BCOND(b, r, s, val & 0x00001fff));
}

#define emith_get_t_cond()      -1

#define emith_sync_t(sr)	((void)sr)

#define emith_invalidate_t()

static void emith_set_t(int sr, int val)
{
  if (val) 
    emith_or_r_imm(sr, T);
  else
    emith_bic_r_imm(sr, T);
}

static int emith_tst_t(int sr, int tf)
{
  emith_tst_r_imm(sr, T);
  return tf ? DCOND_NE: DCOND_EQ;
}
#endif
