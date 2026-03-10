/*
 * Basic macros to emit MIPS32/MIPS64 Release 1 or 2 instructions and some utils
 * Copyright (C) 2019-2024 irixxxx
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */
#define HOST_REGS	32

// MIPS32 ABI: params: r4-r7, return: r2-r3, temp: r1(at),r8-r15,r24-r25,r31(ra)
// saved: r16-r23,r30, reserved: r0(zero), r26-r27(irq), r28(gp), r29(sp)
// r1,r15,r24,r25(at,t7-t9) are used internally by the code emitter
// MIPSN32/MIPS64 ABI: params: r4-r11, no caller-reserved save area on stack
// for PIC code, on function calls r25(t9) must contain the called address
#define RET_REG		2 // v0
#define PARAM_REGS	{ 4, 5, 6, 7 } // a0-a3
#define	PRESERVED_REGS	{ 16, 17, 18, 19, 20, 21, 22, 23 } // s0-s7
#define	TEMPORARY_REGS	{ 2, 3, 8, 9, 10, 11, 12, 13, 14 } // v0-v1,t0-t6

#define CONTEXT_REG	23 // s7
#define STATIC_SH2_REGS	{ SHR_SR,22 , SHR_R(0),21 , SHR_R(1),20 }

// NB: the ubiquitous JZ74[46]0 uses MIPS32 Release 1, a slight MIPS II superset
#ifndef __mips_isa_rev
#define __mips_isa_rev	1  // surprisingly not always defined
#endif

// registers usable for user code: r1-r25, others reserved or special
#define Z0		0  // zero register
#define	CR		25 // call register
#define	GP		28 // global pointer
#define	SP		29 // stack pointer
#define	FP		30 // frame pointer
#define	LR		31 // link register
// internally used by code emitter:
#define AT		1  // used to hold intermediate results
#define FNZ		15 // emulated processor flags: N (bit 31) ,Z (all bits)
#define FC		24 // emulated processor flags: C (bit 0), others 0
#define FV		25 // emulated processor flags: Nt^Ns (bit 31). others x

// All operations but ptr ops are using the lower 32 bits of the registers.
// The upper 32 bits always contain the sign extension from the lower 32 bits.

// unified conditions; virtual, not corresponding to anything real on MIPS
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
#define MIPS_INSN(op, rs, rt, rd, sa, fn) \
	(((op)<<26)|((rs)<<21)|((rt)<<16)|((rd)<<11)|((sa)<<6)|((fn)<<0))

#define _	0 // marker for "field unused"
#define __(n)	o##n // enum marker for "undefined"

// opcode field (encoded in op)
enum { OP__FN=000, OP__RT, OP_J, OP_JAL, OP_BEQ, OP_BNE, OP_BLEZ, OP_BGTZ };
enum { OP_ADDI=010, OP_ADDIU, OP_SLTI, OP_SLTIU, OP_ANDI, OP_ORI, OP_XORI, OP_LUI };
enum { OP_DADDI=030, OP_DADDIU, OP_LDL, OP_LDR, OP__FN2=034, OP__FN3=037 };
enum { OP_LB=040, OP_LH, OP_LWL, OP_LW, OP_LBU, OP_LHU, OP_LWR, OP_LWU };
enum { OP_SB=050, OP_SH, OP_SWL, OP_SW, OP_SDL, OP_SDR, OP_SWR };
enum { OP_LD=067, OP_SD=077 };
// function field (encoded in fn if opcode = OP__FN)
enum { FN_SLL=000, __(01), FN_SRL, FN_SRA, FN_SLLV, __(05), FN_SRLV, FN_SRAV };
enum { FN_JR=010, FN_JALR, FN_MOVZ, FN_MOVN, FN_SYNC=017 };
enum { FN_MFHI=020, FN_MTHI, FN_MFLO, FN_MTLO, FN_DSSLV, __(25), FN_DSLRV, FN_DSRAV };
enum { FN_MULT=030, FN_MULTU, FN_DIV, FN_DIVU, FN_DMULT, FN_DMULTU, FN_DDIV, FN_DDIVU };
enum { FN_ADD=040, FN_ADDU, FN_SUB, FN_SUBU, FN_AND, FN_OR, FN_XOR, FN_NOR };
enum { FN_SLT=052, FN_SLTU, FN_DADD, FN_DADDU, FN_DSUB, FN_DSUBU };
enum { FN_DSLL=070, __(71), FN_DSRL, FN_DSRA, FN_DSLL32, __(75), FN_DSRL32, FN_DSRA32 };
// function field (encoded in fn if opcode = OP__FN2)
enum { FN2_MADD=000, FN2_MADDU, FN2_MUL, __(03), FN2_MSUB, FN2_MSUBU };
enum { FN2_CLZ=040, FN2_CLO, FN2_DCLZ=044, FN2_DCLO };
// function field (encoded in fn if opcode = OP__FN3)
enum { FN3_EXT=000, FN3_DEXTM, FN3_DEXTU, FN3_DEXT, FN3_INS, FN3_DINSM, FN3_DINSU, FN3_DINS };
enum { FN3_BSHFL=040, FN3_DBSHFL=044 };
// rt field (encoded in rt if opcode = OP__RT)
enum { RT_BLTZ=000, RT_BGEZ, RT_BLTZAL=020, RT_BGEZAL, RT_SYNCI=037 };

// bit shuffle function (encoded in sa if function = FN3_BSHFL)
enum { BS_SBH=002, BS_SHD=005, BS_SEB=020, BS_SEH=030 };
// r (rotate) bit function (encoded in rs/sa if function = FN_SRL/FN_SRLV)
enum { RB_SRL=0, RB_ROTR=1 };

#define	MIPS_NOP 000	// null operation: SLL r0, r0, #0

// arithmetic/logical

#define MIPS_OP_REG(op, sa, rd, rs, rt) \
	MIPS_INSN(OP__FN, rs, rt, rd, sa, op)	// R-type, SPECIAL
#define MIPS_OP2_REG(op, sa, rd, rs, rt) \
	MIPS_INSN(OP__FN2, rs, rt, rd, sa, op)	// R-type, SPECIAL2
#define MIPS_OP3_REG(op, sa, rd, rs, rt) \
	MIPS_INSN(OP__FN3, rs, rt, rd, sa, op)	// R-type, SPECIAL3
#define MIPS_OP_IMM(op, rt, rs, imm) \
	MIPS_INSN(op, rs, rt, _, _, (u16)(imm))	// I-type

// rd = rs OP rt
#define MIPS_ADD_REG(rd, rs, rt) \
	MIPS_OP_REG(FN_ADDU,_, rd, rs, rt)
#define MIPS_DADD_REG(rd, rs, rt) \
	MIPS_OP_REG(FN_DADDU,_, rd, rs, rt)
#define MIPS_SUB_REG(rd, rs, rt) \
	MIPS_OP_REG(FN_SUBU,_, rd, rs, rt)
#define MIPS_DSUB_REG(rd, rs, rt) \
	MIPS_OP_REG(FN_DSUBU,_, rd, rs, rt)

#define MIPS_NEG_REG(rd, rt) \
	MIPS_SUB_REG(rd, Z0, rt)

#define MIPS_XOR_REG(rd, rs, rt) \
	MIPS_OP_REG(FN_XOR,_, rd, rs, rt)
#define MIPS_OR_REG(rd, rs, rt) \
	MIPS_OP_REG(FN_OR,_, rd, rs, rt)
#define MIPS_AND_REG(rd, rs, rt) \
	MIPS_OP_REG(FN_AND,_, rd, rs, rt)
#define MIPS_NOR_REG(rd, rs, rt) \
	MIPS_OP_REG(FN_NOR,_, rd, rs, rt)

#define MIPS_MOVE_REG(rd, rs) \
	MIPS_OR_REG(rd, rs, Z0)
#define MIPS_MVN_REG(rd, rs) \
	MIPS_NOR_REG(rd, rs, Z0)

// rd = rt SHIFT rs
#define MIPS_LSL_REG(rd, rt, rs) \
	MIPS_OP_REG(FN_SLLV,_, rd, rs, rt)
#define MIPS_LSR_REG(rd, rt, rs) \
	MIPS_OP_REG(FN_SRLV,RB_SRL, rd, rs, rt)
#define MIPS_ASR_REG(rd, rt, rs) \
	MIPS_OP_REG(FN_SRAV,_, rd, rs, rt)
#define MIPS_ROR_REG(rd, rt, rs) \
	MIPS_OP_REG(FN_SRLV,RB_ROTR, rd, rs, rt)

#define MIPS_SEB_REG(rd, rt) \
	MIPS_OP3_REG(FN3_BSHFL, BS_SEB, rd, _, rt)
#define MIPS_SEH_REG(rd, rt) \
	MIPS_OP3_REG(FN3_BSHFL, BS_SEH, rd, _, rt)

#define MIPS_EXT_IMM(rt, rs, lsb, sz) \
	MIPS_OP3_REG(FN3_EXT, lsb, (sz)-1, rs, rt)
#define MIPS_INS_IMM(rt, rs, lsb, sz) \
	MIPS_OP3_REG(FN3_INS, lsb, (lsb)+(sz)-1, rs, rt)

// rd = (rs < rt)
#define MIPS_SLT_REG(rd, rs, rt) \
	MIPS_OP_REG(FN_SLT,_, rd, rs, rt)
#define MIPS_SLTU_REG(rd, rs, rt) \
	MIPS_OP_REG(FN_SLTU,_, rd, rs, rt)

// rt = rs OP imm16
#define MIPS_ADD_IMM(rt, rs, imm16) \
	MIPS_OP_IMM(OP_ADDIU, rt, rs, imm16)
#define MIPS_DADD_IMM(rt, rs, imm16) \
	MIPS_OP_IMM(OP_DADDIU, rt, rs, imm16)

#define MIPS_XOR_IMM(rt, rs, imm16) \
	MIPS_OP_IMM(OP_XORI, rt, rs, imm16)
#define MIPS_OR_IMM(rt, rs, imm16) \
	MIPS_OP_IMM(OP_ORI, rt, rs, imm16)
#define MIPS_AND_IMM(rt, rs, imm16) \
	MIPS_OP_IMM(OP_ANDI, rt, rs, imm16)

// rt = (imm16 << (0|16))
#define MIPS_MOV_IMM(rt, imm16) \
	MIPS_OP_IMM(OP_ORI, rt, Z0, imm16)
#define MIPS_MOVT_IMM(rt, imm16) \
	MIPS_OP_IMM(OP_LUI, rt, _, imm16)

// rd = rt SHIFT imm5
#define MIPS_LSL_IMM(rd, rt, bits) \
	MIPS_INSN(OP__FN, _, rt, rd, bits, FN_SLL)
#define MIPS_LSR_IMM(rd, rt, bits) \
	MIPS_INSN(OP__FN, RB_SRL, rt, rd, bits, FN_SRL)
#define MIPS_ASR_IMM(rd, rt, bits) \
	MIPS_INSN(OP__FN, _, rt, rd, bits, FN_SRA)
#define MIPS_ROR_IMM(rd, rt, bits) \
	MIPS_INSN(OP__FN, RB_ROTR, rt, rd, bits, FN_SRL)

#define MIPS_DLSL_IMM(rd, rt, bits) \
	MIPS_INSN(OP__FN, _, rt, rd, bits, FN_DSLL)
#define MIPS_DLSL32_IMM(rd, rt, bits) \
	MIPS_INSN(OP__FN, _, rt, rd, bits, FN_DSLL32)

// rt = (rs < imm16)
#define MIPS_SLT_IMM(rt, rs, imm16) \
	MIPS_OP_IMM(OP_SLTI, rt, rs, imm16)
#define MIPS_SLTU_IMM(rt, rs, imm16) \
	MIPS_OP_IMM(OP_SLTIU, rt, rs, imm16)

// multiplication

#define MIPS_MULT(rt, rs) \
	MIPS_OP_REG(FN_MULT,_, _, rs, rt)
#define MIPS_MULTU(rt, rs) \
	MIPS_OP_REG(FN_MULTU,_, _, rs, rt)
#define MIPS_MADD(rt, rs) \
	MIPS_OP2_REG(FN_MADD,_, _, rs, rt)
#define MIPS_MADDU(rt, rs) \
	MIPS_OP2_REG(FN_MADDU,_, _, rs, rt)
#define MIPS_MFLO(rd) \
	MIPS_OP_REG(FN_MFLO,_, rd, _, _)
#define MIPS_MFHI(rd) \
	MIPS_OP_REG(FN_MFHI,_, rd, _, _)

// branching

#define MIPS_J(abs26) \
	MIPS_INSN(OP_J, _,_,_,_, (abs26) >> 2)	// J-type
#define MIPS_JAL(abs26) \
	MIPS_INSN(OP_JAL, _,_,_,_, (abs26) >> 2)
#define MIPS_JR(rs) \
	MIPS_OP_REG(FN_JR,_, _,rs,_)
#define MIPS_JALR(rd, rs) \
	MIPS_OP_REG(FN_JALR,_, rd,rs,_)

// conditional branches; no condition code, these compare rs against rt or Z0
#define MIPS_BEQ (OP_BEQ  << 5)			// rs == rt (rt in lower 5 bits)
#define MIPS_BNE (OP_BNE  << 5)			// rs != rt (ditto)
#define MIPS_BLE (OP_BLEZ << 5)			// rs <= 0
#define MIPS_BGT (OP_BGTZ << 5)			// rs >  0
#define MIPS_BLT ((OP__RT << 5)|RT_BLTZ)	// rs <  0
#define MIPS_BGE ((OP__RT << 5)|RT_BGEZ)	// rs >= 0
#define MIPS_BLTL ((OP__RT << 5)|RT_BLTZAL)	// rs >  0, always link $ra
#define MIPS_BGEL ((OP__RT << 5)|RT_BGEZAL)	// rs >= 0, always link $ra

#define MIPS_BCOND(cond, rs, rt, offs16) \
	MIPS_OP_IMM((cond >> 5), rt, rs, (offs16) >> 2)
#define MIPS_BCONDZ(cond, rs, offs16) \
	MIPS_OP_IMM((cond >> 5), (cond & 0x1f), rs, (offs16) >> 2)
#define MIPS_B(offs16) \
	MIPS_BCONDZ(MIPS_BEQ, Z0, offs16)
#define MIPS_BL(offs16) \
	MIPS_BCONDZ(MIPS_BGEL, Z0, offs16)

// load/store indexed base

#define MIPS_LD(rt, rs, offs16) \
	MIPS_OP_IMM(OP_LD, rt, rs, (u16)(offs16))
#define MIPS_LW(rt, rs, offs16) \
	MIPS_OP_IMM(OP_LW, rt, rs, (u16)(offs16))
#define MIPS_LH(rt, rs, offs16) \
	MIPS_OP_IMM(OP_LH, rt, rs, (u16)(offs16))
#define MIPS_LB(rt, rs, offs16) \
	MIPS_OP_IMM(OP_LB, rt, rs, (u16)(offs16))
#define MIPS_LHU(rt, rs, offs16) \
	MIPS_OP_IMM(OP_LHU, rt, rs, (u16)(offs16))
#define MIPS_LBU(rt, rs, offs16) \
	MIPS_OP_IMM(OP_LBU, rt, rs, (u16)(offs16))

#define MIPS_SD(rt, rs, offs16) \
	MIPS_OP_IMM(OP_SD, rt, rs, (u16)(offs16))
#define MIPS_SW(rt, rs, offs16) \
	MIPS_OP_IMM(OP_SW, rt, rs, (u16)(offs16))
#define MIPS_SH(rt, rs, offs16) \
	MIPS_OP_IMM(OP_SH, rt, rs, (u16)(offs16))
#define MIPS_SB(rt, rs, offs16) \
	MIPS_OP_IMM(OP_SB, rt, rs, (u16)(offs16))

// pointer operations

#if _MIPS_SZPTR == 64
#define OP_LP				OP_LD
#define OP_SP				OP_SD
#define OP_PADDIU			OP_DADDIU
#define FN_PADDU			FN_DADDU
#define FN_PSUBU			FN_DSUBU
#define PTR_SCALE			3
#else
#define OP_LP				OP_LW
#define OP_SP				OP_SW
#define OP_PADDIU			OP_ADDIU
#define FN_PADDU			FN_ADDU
#define FN_PSUBU			FN_SUBU
#define PTR_SCALE			2
#endif
#define PTR_SIZE			(1<<PTR_SCALE)

// XXX: tcache_ptr type for SVP and SH2 compilers differs..
#define EMIT_PTR(ptr, x) \
	do { \
		*(u32 *)(ptr) = x; \
		ptr = (void *)((u8 *)(ptr) + sizeof(u32)); \
	} while (0)

// FIFO for some instructions, for delay slot handling
#define	FSZ	4
static u32 emith_last_insns[FSZ];
static unsigned emith_last_idx, emith_last_cnt;

#define EMIT_PUSHOP() \
	do { \
		if (emith_last_cnt > 0) { \
			u32 *p = (u32 *)tcache_ptr - emith_last_cnt; \
			int idx = (emith_last_idx - emith_last_cnt+1) %FSZ; \
			EMIT_PTR(p, emith_last_insns[idx]);\
			emith_last_cnt --; \
		} \
	} while (0)

#define EMIT(op) \
	do { \
		if (emith_last_cnt >= FSZ) EMIT_PUSHOP(); \
		tcache_ptr = (void *)((u32 *)tcache_ptr + 1); \
		emith_last_idx = (emith_last_idx+1) %FSZ; \
		emith_last_insns[emith_last_idx] = op; \
		emith_last_cnt ++; \
		COUNT_OP; \
	} while (0)

#define emith_flush() \
	do { \
		while (emith_last_cnt) EMIT_PUSHOP(); \
		emith_flg_hint = _FHV|_FHC; \
	} while (0)

#define emith_insn_ptr()	(u8 *)((u32 *)tcache_ptr - emith_last_cnt)

// delay slot stuff
static int emith_is_j(u32 op)	// J, JAL
		{ return ((op>>26) & 076) == OP_J; }
static int emith_is_jr(u32 op)	// JR, JALR
		{ return  (op>>26) == OP__FN && (op & 076) == FN_JR; }
static int emith_is_b(u32 op)	// B
		{ return ((op>>26) & 074) == OP_BEQ ||
			 ((op>>26) == OP__RT && ((op>>16) & 036) == RT_BLTZ); }
// register usage for dependency evaluation XXX better do this as in emit_arm?
static uint64_t emith_has_rs[5] = // OP__FN1-3, OP__RT, others
	{  0x005ffcffffda0fd2ULL, 0x0000003300000037ULL, 0x00000000000000ffULL,
		0x800f5f0fUL, 0xf7ffffff0ff07ff0ULL };
static uint64_t emith_has_rt[5] = // OP__FN1-3, OP__RT, others
	{  0xdd5ffcffffd00cddULL, 0x0000000000000037ULL, 0x0000001100000000ULL,
		0x00000000UL, 0x80007f440c300030ULL };
static uint64_t emith_has_rd[5] = // OP__FN1-3, OP__RT, others(rt instead of rd)
	{  0xdd00fcff00d50edfULL, 0x0000003300000004ULL, 0x08000011000000ffULL,
		0x00000000UL, 0x119100ff0f00ff00ULL };
#define emith_has_(rx,ix,op,sa,m) \
	(emith_has_##rx[ix] & (1ULL << (((op)>>(sa)) & (m))))
static int emith_rs(u32 op)
		{ if ((op>>26) == OP__FN)
			return	emith_has_(rs,0,op, 0,0x3f) ? (op>>21)&0x1f : 0;
		  if ((op>>26) == OP__FN2)
			return	emith_has_(rs,1,op, 0,0x3f) ? (op>>21)&0x1f : 0;
		  if ((op>>26) == OP__FN3)
			return	emith_has_(rs,2,op, 0,0x3f) ? (op>>21)&0x1f : 0;
		  if ((op>>26) == OP__RT)
			return	emith_has_(rs,3,op,16,0x1f) ? (op>>21)&0x1f : 0;
		  return	emith_has_(rs,4,op,26,0x3f) ? (op>>21)&0x1f : 0;
		}
static int emith_rt(u32 op)
		{ if ((op>>26) == OP__FN)
			return	emith_has_(rt,0,op, 0,0x3f) ? (op>>16)&0x1f : 0;
		  if ((op>>26) == OP__FN2)
			return	emith_has_(rt,1,op, 0,0x3f) ? (op>>16)&0x1f : 0;
		  if ((op>>26) == OP__FN3)
			return	emith_has_(rt,2,op, 0,0x3f) ? (op>>16)&0x1f : 0;
		  if ((op>>26) == OP__RT)
		  	return 0;
		  return	emith_has_(rt,4,op,26,0x3f) ? (op>>16)&0x1f : 0;
		}
static int emith_rd(u32 op)
		{ int ret =	emith_has_(rd,4,op,26,0x3f) ? (op>>16)&0x1f :-1;
		  if ((op>>26) == OP__FN)
			ret =	emith_has_(rd,0,op, 0,0x3f) ? (op>>11)&0x1f :-1;
		  if ((op>>26) == OP__FN2)
			ret =	emith_has_(rd,1,op, 0,0x3f) ? (op>>11)&0x1f :-1;
		  if ((op>>26) == OP__FN3 && (op&0x3f) == FN3_BSHFL)
			ret =	emith_has_(rd,2,op, 0,0x3f) ? (op>>11)&0x1f :-1;
		  if ((op>>26) == OP__FN3 && (op&0x3f) != FN3_BSHFL)
			ret =	emith_has_(rd,2,op, 0,0x3f) ? (op>>16)&0x1f :-1;
		  if ((op>>26) == OP__RT)
		  	ret =	-1;
		  return (ret ? ret : -1);	// Z0 doesn't have dependencies
		}

static int emith_b_isswap(u32 bop, u32 lop)
{
	if (emith_is_j(bop))
		return bop;
	else if (emith_is_jr(bop) && emith_rd(lop) != emith_rs(bop))
		return bop;
	else if (emith_is_b(bop) &&  emith_rd(lop) != emith_rs(bop) &&
				     emith_rd(lop) != emith_rt(bop))
		if ((bop & 0xffff) != 0x7fff)	// displacement overflow?
			return (bop & 0xffff0000) | ((bop+1) & 0x0000ffff);
	return 0;
}

static int emith_insn_swappable(u32 op1, u32 op2)
{
	if (emith_rd(op1) != emith_rd(op2) &&
	    emith_rs(op1) != emith_rd(op2) && emith_rt(op1) != emith_rd(op2) &&
	    emith_rs(op2) != emith_rd(op1) && emith_rt(op2) != emith_rd(op1))
		return 1;
	return 0;
}

// emit branch, trying to fill the delay slot with one of the last insns
static void *emith_branch(u32 op)
{
	unsigned idx = emith_last_idx, ds = idx;
	u32 bop = 0, sop;
	void *bp;
	int i, j, s;

	// check for ds insn; older mustn't interact with newer ones to overtake
	for (i = 0; i < emith_last_cnt && !bop; i++) {
		ds = (idx-i)%FSZ;
		sop = emith_last_insns[ds];
		for (j = i, s = 1; j > 0 && s; j--)
			s = emith_insn_swappable(emith_last_insns[(ds+j)%FSZ], sop);
		if (s)
			bop = emith_b_isswap(op, sop);
	}

	// flush FIFO, but omit delay slot insn
	tcache_ptr = (void *)((u32 *)tcache_ptr - emith_last_cnt);
	idx = (idx-emith_last_cnt+1)%FSZ;
	for (i = emith_last_cnt; i > 0; i--, idx = (idx+1)%FSZ)
		if (!bop || idx != ds)
			EMIT_PTR(tcache_ptr, emith_last_insns[idx]);
	emith_last_cnt = 0;
	// emit branch and delay slot
	bp = tcache_ptr;
	if (bop) { // can swap
		EMIT_PTR(tcache_ptr, bop); COUNT_OP;
		EMIT_PTR(tcache_ptr, emith_last_insns[ds]);
	} else { // can't swap
		EMIT_PTR(tcache_ptr, op); COUNT_OP;
		EMIT_PTR(tcache_ptr, MIPS_NOP); COUNT_OP;
	}
	return bp;
}

// if-then-else conditional execution helpers
#define JMP_POS(ptr) \
	ptr = emith_branch(MIPS_BCONDZ(cond_m, cond_r, 0));

#define JMP_EMIT(cond, ptr) { \
	u32 val_ = (u8 *)tcache_ptr - (u8 *)(ptr) - 4; \
	emith_flush(); /* prohibit delay slot switching across jump targets */ \
	EMIT_PTR(ptr, MIPS_BCONDZ(cond_m, cond_r, val_ & 0x0003ffff)); \
}

#define JMP_EMIT_NC(ptr) { \
	u32 val_ = (u8 *)tcache_ptr - (u8 *)(ptr) - 4; \
	emith_flush(); \
	EMIT_PTR(ptr, MIPS_B(val_ & 0x0003ffff)); \
}

#define EMITH_JMP_START(cond) { \
	int cond_r, cond_m = emith_cond_check(cond, &cond_r); \
	u8 *cond_ptr; \
	JMP_POS(cond_ptr)

#define EMITH_JMP_END(cond) \
	JMP_EMIT(cond, cond_ptr); \
}

#define EMITH_JMP3_START(cond) { \
	int cond_r, cond_m = emith_cond_check(cond, &cond_r); \
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
			EMIT(MIPS_SLTU_REG(FC, rs, FNZ));
		else	EMIT(MIPS_SLTU_REG(FC, FNZ, rs));// C in FC, bit 0 
	}

	if (emith_flg_hint & _FHV) {
		emith_flg_noV = 0;
		if (rt > Z0)				// Nt^Ns in FV, bit 31
			EMIT(MIPS_XOR_REG(FV, rs, rt));
		else if (rt == Z0 || imm == 0)
			emith_flg_noV = 1;		// imm #0 can't overflow
		else if ((imm < 0) == !sub)
			EMIT(MIPS_NOR_REG(FV, rs, Z0));
		else if ((imm > 0) == !sub)
			EMIT(MIPS_XOR_REG(FV, rs, Z0));
	}
	// full V = Nd^Nt^Ns^C calculation is deferred until really needed

	if (rd && rd != FNZ)
		EMIT(MIPS_MOVE_REG(rd, FNZ));	// N,Z via result value in FNZ
	emith_cmp_rs = emith_cmp_rt = -1;
}

// since MIPS has less-than and compare-branch insns, handle cmp separately by
// storing the involved regs for later use in one of those MIPS insns.
// This works for all conditions but VC/VS, but this is fortunately never used.
static void emith_set_compare_flags(int rs, int rt, s32 imm)
{
	emith_cmp_rt = rt;
	emith_cmp_rs = rs;
	emith_cmp_imm = imm;
}

// data processing, register
#define emith_move_r_r_ptr(d, s) \
	EMIT(MIPS_MOVE_REG(d, s))
#define emith_move_r_r_ptr_c(cond, d, s) \
	emith_move_r_r_ptr(d, s)

#define emith_move_r_r(d, s) \
	emith_move_r_r_ptr(d, s)
#define emith_move_r_r_c(cond, d, s) \
	emith_move_r_r(d, s)

#define emith_mvn_r_r(d, s) \
	EMIT(MIPS_MVN_REG(d, s))

#define emith_add_r_r_r_lsl_ptr(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(MIPS_LSL_IMM(AT, s2, simm)); \
		EMIT(MIPS_OP_REG(FN_PADDU,_, d, s1, AT)); \
	} else	EMIT(MIPS_OP_REG(FN_PADDU,_, d, s1, s2)); \
} while (0)
#define emith_add_r_r_r_lsl(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(MIPS_LSL_IMM(AT, s2, simm)); \
		EMIT(MIPS_ADD_REG(d, s1, AT)); \
	} else	EMIT(MIPS_ADD_REG(d, s1, s2)); \
} while (0)

#define emith_add_r_r_r_lsr(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(MIPS_LSR_IMM(AT, s2, simm)); \
		EMIT(MIPS_ADD_REG(d, s1, AT)); \
	} else	EMIT(MIPS_ADD_REG(d, s1, s2)); \
} while (0)

#define emith_addf_r_r_r_lsl_ptr(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(MIPS_LSL_IMM(AT, s2, simm)); \
		EMIT(MIPS_OP_REG(FN_PADDU,_, FNZ, s1, AT)); \
		emith_set_arith_flags(d, s1, AT, 0, 0); \
	} else { \
		EMIT(MIPS_OP_REG(FN_PADDU,_, FNZ, s1, s2)); \
		emith_set_arith_flags(d, s1, s2, 0, 0); \
	} \
} while (0)
#define emith_addf_r_r_r_lsl(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(MIPS_LSL_IMM(AT, s2, simm)); \
		EMIT(MIPS_ADD_REG(FNZ, s1, AT)); \
		emith_set_arith_flags(d, s1, AT, 0, 0); \
	} else { \
		EMIT(MIPS_ADD_REG(FNZ, s1, s2)); \
		emith_set_arith_flags(d, s1, s2, 0, 0); \
	} \
} while (0)

#define emith_addf_r_r_r_lsr(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(MIPS_LSR_IMM(AT, s2, simm)); \
		EMIT(MIPS_ADD_REG(FNZ, s1, AT)); \
		emith_set_arith_flags(d, s1, AT, 0, 0); \
	} else { \
		EMIT(MIPS_ADD_REG(FNZ, s1, s2)); \
		emith_set_arith_flags(d, s1, s2, 0, 0); \
	} \
} while (0)

#define emith_sub_r_r_r_lsl(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(MIPS_LSL_IMM(AT, s2, simm)); \
		EMIT(MIPS_SUB_REG(d, s1, AT)); \
	} else	EMIT(MIPS_SUB_REG(d, s1, s2)); \
} while (0)

#define emith_subf_r_r_r_lsl(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(MIPS_LSL_IMM(AT, s2, simm)); \
		EMIT(MIPS_SUB_REG(FNZ, s1, AT)); \
		emith_set_arith_flags(d, s1, AT, 0, 1); \
	} else { \
		EMIT(MIPS_SUB_REG(FNZ, s1, s2)); \
		emith_set_arith_flags(d, s1, s2, 0, 1); \
	} \
} while (0)

#define emith_or_r_r_r_lsl(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(MIPS_LSL_IMM(AT, s2, simm)); \
		EMIT(MIPS_OR_REG(d, s1, AT)); \
	} else	EMIT(MIPS_OR_REG(d, s1, s2)); \
} while (0)

#define emith_or_r_r_r_lsr(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(MIPS_LSR_IMM(AT, s2, simm)); \
		EMIT(MIPS_OR_REG(d, s1, AT)); \
	} else  EMIT(MIPS_OR_REG(d, s1, s2)); \
} while (0)

#define emith_eor_r_r_r_lsl(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(MIPS_LSL_IMM(AT, s2, simm)); \
		EMIT(MIPS_XOR_REG(d, s1, AT)); \
	} else	EMIT(MIPS_XOR_REG(d, s1, s2)); \
} while (0)

#define emith_eor_r_r_r_lsr(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(MIPS_LSR_IMM(AT, s2, simm)); \
		EMIT(MIPS_XOR_REG(d, s1, AT)); \
	} else	EMIT(MIPS_XOR_REG(d, s1, s2)); \
} while (0)

#define emith_and_r_r_r_lsl(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(MIPS_LSL_IMM(AT, s2, simm)); \
		EMIT(MIPS_AND_REG(d, s1, AT)); \
	} else	EMIT(MIPS_AND_REG(d, s1, s2)); \
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
	emith_addf_r_r_r_lsl(d, s1, s2, 0)

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
	EMIT(MIPS_NEG_REG(d, s))

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
	EMIT(MIPS_SLTU_REG(AT, FNZ, FC)); \
	emith_add_r_r_r(FNZ, s1, FNZ); \
	emith_set_arith_flags(d, s1, s2, 0, 0); \
	emith_or_r_r(FC, AT); \
} while (0)

#define emith_sbcf_r_r_r(d, s1, s2) do { \
	emith_add_r_r_r(FNZ, s2, FC); \
	EMIT(MIPS_SLTU_REG(AT, FNZ, FC)); \
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
#define MAX_HOST_LITERALS	32	// pool must be smaller than 32 KB
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
		emith_branch(MIPS_B(sz + (pool-(u8 *)tcache_ptr)));
	emith_flush();
	// safety check - pool must be after insns and reachable
	if ((u32)(pool - (u8 *)literal_insn[0] + 8) > 0x7fff) {
		elprintf(EL_STATUS|EL_SVP|EL_ANOMALY,
			"pool offset out of range");
		exit(1);
	}
	// copy pool and adjust addresses in insns accessing the pool
	memcpy(pool, literal_pool, sz);
	for (i = 0; i < literal_iindex; i++) {
		u32 *pi = literal_insn[i];
		*pi = (*pi & 0xffff0000) | (u16)(*pi + ((u8 *)pool - (u8 *)pi));
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
		    (u8 *)tcache_ptr - (u8 *)literal_insn[0] > 0x7000))
		// pool full, or displacement is approaching the limit
		emith_pool_commit(1);
}

static void emith_move_imm(int r, uintptr_t imm)
{
	if ((s16)imm == imm) {
		EMIT(MIPS_ADD_IMM(r, Z0, imm));
	} else if (!((u32)imm >> 16)) {
		EMIT(MIPS_OR_IMM(r, Z0, imm));
	} else {
		int s = Z0;
		if ((u32)imm >> 16) {
			EMIT(MIPS_MOVT_IMM(r, (u32)imm >> 16));
			s = r;
		}
		if ((u16)imm)
			EMIT(MIPS_OR_IMM(r, s, (u16)imm));
	}
}
static void emith_move_ptr_imm(int r, uintptr_t imm)
{
#if _MIPS_SZPTR == 64
	uintptr_t offs = (u8 *)imm - (u8 *)tcache_ptr - 8;
	if ((s32)imm != imm && (s32)offs == offs) {
		// PC relative
		emith_flush(); // next insn must not change its position at all
		EMIT_PTR(tcache_ptr, MIPS_BCONDZ(MIPS_BLTL, Z0, 0)); // loads PC+8 into LR
		emith_move_imm(r, offs);
		emith_add_r_r_r_ptr(r, LR, r);
	} else if ((s32)imm != imm) {
		// via literal pool
		int idx;
		if (literal_iindex >= MAX_HOST_LITERALS)
			emith_pool_commit(1);
		idx = emith_pool_literal(imm);
		emith_flush(); // next 2 must not change their position at all
		EMIT_PTR(tcache_ptr, MIPS_BCONDZ(MIPS_BLTL, Z0, 0)); // loads PC+8 into LR
		literal_insn[literal_iindex++] = (u32 *)tcache_ptr;
		EMIT_PTR(tcache_ptr, MIPS_OP_IMM(OP_LP, r, LR, idx*sizeof(uintptr_t) - 4));
	} else
#endif
		emith_move_imm(r, imm);
}

#define emith_move_r_ptr_imm(r, imm) \
	emith_move_ptr_imm(r, (uintptr_t)(imm))

#define emith_move_r_imm(r, imm) \
	emith_move_imm(r, (s32)(imm))
#define emith_move_r_imm_c(cond, r, imm) \
	emith_move_r_imm(r, imm)

#define emith_move_r_imm_s8_patchable(r, imm) \
	EMIT(MIPS_ADD_IMM(r, Z0, (s8)(imm)))
#define emith_move_r_imm_s8_patch(ptr, imm) do { \
	u32 *ptr_ = (u32 *)ptr; \
	while (*ptr_ >> 26 != OP_ADDIU) ptr_++; \
	EMIT_PTR(ptr_, (*ptr_ & 0xffff0000) | (u16)(s8)(imm)); \
} while (0)

// arithmetic, immediate - can only be ADDI[U], since SUBI[U] doesn't exist
static void emith_add_imm(int ptr, int rd, int rs, u32 imm)
{
	if ((s16)imm == imm) {
		if (imm || rd != rs)
			EMIT(MIPS_OP_IMM(ptr ? OP_PADDIU:OP_ADDIU, rd,rs,imm));
	} else if ((s32)imm  < 0) {
		emith_move_r_imm(AT, -imm);
		EMIT(MIPS_OP_REG((ptr ? FN_PSUBU:FN_SUBU),_, rd,rs,AT));
	} else {
		emith_move_r_imm(AT, imm);
		EMIT(MIPS_OP_REG((ptr ? FN_PADDU:FN_ADDU),_, rd,rs,AT));
	}
}

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
	emith_adc_r_r_imm(r, r, imm)

#define emith_adcf_r_imm(r, imm) \
	emith_adcf_r_r_imm(r, r, imm)

#define emith_cmp_r_imm(r, imm) \
	emith_set_compare_flags(r, -1, imm)
//	emith_subf_r_r_imm(FNZ, r, (s16)imm)

#define emith_add_r_r_ptr_imm(d, s, imm) \
	emith_add_imm(1, d, s, imm)

#define emith_add_r_r_imm(d, s, imm) \
	emith_add_imm(0, d, s, imm)

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
		EMIT(MIPS_SLTU_REG(AT, FNZ, FC)); \
		emith_add_r_r_imm(FNZ, FNZ, imm); \
		emith_set_arith_flags(d, s, -1, imm, 0); \
		emith_or_r_r(FC, AT); \
	} \
} while (0)

// NB: no SUBI in MIPS II, since ADDI takes a signed imm
#define emith_sub_r_r_imm(d, s, imm) \
	emith_add_r_r_imm(d, s, -(imm))
#define emith_sub_r_r_imm_c(cond, d, s, imm) \
	emith_sub_r_r_imm(d, s, imm)

#define emith_subf_r_r_imm(d, s, imm) do { \
	emith_sub_r_r_imm(FNZ, s, imm); \
	emith_set_arith_flags(d, s, -1, imm, 1); \
} while (0)

// logical, immediate
static void emith_log_imm(int op, int rd, int rs, u32 imm)
{
	if (imm >> 16) {
		emith_move_r_imm(AT, imm);
		EMIT(MIPS_OP_REG(FN_AND + (op-OP_ANDI),_, rd, rs, AT));
	} else if (op == OP_ANDI || imm || rd != rs)
		EMIT(MIPS_OP_IMM(op, rd, rs, imm));
}

#define emith_and_r_imm(r, imm) \
	emith_log_imm(OP_ANDI, r, r, imm)

#define emith_or_r_imm(r, imm) \
	emith_log_imm(OP_ORI, r, r, imm)
#define emith_or_r_imm_c(cond, r, imm) \
	emith_or_r_imm(r, imm)

#define emith_eor_r_imm_ptr(r, imm) \
	emith_log_imm(OP_XORI, r, r, imm)
#define emith_eor_r_imm_ptr_c(cond, r, imm) \
	emith_eor_r_imm_ptr(r, imm)

#define emith_eor_r_imm(r, imm) \
	emith_eor_r_imm_ptr(r, imm)
#define emith_eor_r_imm_c(cond, r, imm) \
	emith_eor_r_imm(r, imm)

/* NB: BIC #imm not available in MIPS; use AND #~imm instead */
#define emith_bic_r_imm(r, imm) \
	emith_log_imm(OP_ANDI, r, r, ~(imm))
#define emith_bic_r_imm_c(cond, r, imm) \
	emith_bic_r_imm(r, imm)

#define emith_tst_r_imm(r, imm) do { \
	emith_log_imm(OP_ANDI, FNZ, r, imm); \
	emith_cmp_rs = emith_cmp_rt = -1; \
} while (0)
#define emith_tst_r_imm_c(cond, r, imm) \
	emith_tst_r_imm(r, imm)

#define emith_and_r_r_imm(d, s, imm) \
	emith_log_imm(OP_ANDI, d, s, imm)

#define emith_or_r_r_imm(d, s, imm) \
	emith_log_imm(OP_ORI, d, s, imm)

#define emith_eor_r_r_imm(d, s, imm) \
	emith_log_imm(OP_XORI, d, s, imm)

// shift
#define emith_lsl(d, s, cnt) \
	EMIT(MIPS_LSL_IMM(d, s, cnt))

#define emith_lsr(d, s, cnt) \
	EMIT(MIPS_LSR_IMM(d, s, cnt))

#define emith_asr(d, s, cnt) \
	EMIT(MIPS_ASR_IMM(d, s, cnt))

#define emith_ror(d, s, cnt) do { \
	if (__mips_isa_rev < 2) { \
		EMIT(MIPS_LSL_IMM(AT, s, 32-(cnt))); \
		EMIT(MIPS_LSR_IMM(d, s, cnt)); \
		EMIT(MIPS_OR_REG(d, d, AT)); \
	} else	EMIT(MIPS_ROR_IMM(d, s, cnt)); \
} while (0)
#define emith_ror_c(cond, d, s, cnt) \
	emith_ror(d, s, cnt)

#define emith_rol(d, s, cnt) do { \
	if (__mips_isa_rev < 2) { \
		EMIT(MIPS_LSR_IMM(AT, s, 32-(cnt))); \
		EMIT(MIPS_LSL_IMM(d, s, cnt)); \
		EMIT(MIPS_OR_REG(d, d, AT)); \
	} else	EMIT(MIPS_ROR_IMM(d, s, 32-(cnt))); \
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
	if (__mips_isa_rev >= 2) \
		EMIT(MIPS_EXT_IMM(d, s, 0, 32-(count))); \
	else if ((count) >= 16) { \
		t = (count) - 16; \
		t = 0xffff >> t; \
		emith_and_r_r_imm(d, s, t); \
	} else { \
		emith_lsl(d, s, count); \
		emith_lsr(d, d, count); \
	} \
} while (0)
#define emith_clear_msb_c(cond, d, s, count) \
	emith_clear_msb(d, s, count)

#define emith_sext(d, s, count) /* bits to keep */ do { \
	if (__mips_isa_rev >= 2 && count == 8) \
		EMIT(MIPS_SEB_REG(d, s)); \
	else if (__mips_isa_rev >= 2 && count == 16) \
		EMIT(MIPS_SEH_REG(d, s)); \
	else { \
		emith_lsl(d, s, 32-(count)); \
		emith_asr(d, d, 32-(count)); \
	} \
} while (0)

// multiply Rd = Rn*Rm (+ Ra); NB: next 2 insns after MFLO/MFHI mustn't be MULT
static u8 *last_lohi;
static void emith_lohi_nops(void)
{
	u32 d;
	while ((d = (u8 *)tcache_ptr - last_lohi) < 8 && d >= 0) EMIT(MIPS_NOP);
}

#define emith_mul(d, s1, s2) do { \
	emith_lohi_nops(); \
	EMIT(MIPS_MULTU(s1, s2)); \
	EMIT(MIPS_MFLO(d)); \
	last_lohi = (u8 *)tcache_ptr; \
} while (0)

#define emith_mul_u64(dlo, dhi, s1, s2) do { \
	emith_lohi_nops(); \
	EMIT(MIPS_MULTU(s1, s2)); \
	EMIT(MIPS_MFLO(dlo)); \
	EMIT(MIPS_MFHI(dhi)); \
	last_lohi = (u8 *)tcache_ptr; \
} while (0)

#define emith_mul_s64(dlo, dhi, s1, s2) do { \
	emith_lohi_nops(); \
	EMIT(MIPS_MULT(s1, s2)); \
	EMIT(MIPS_MFLO(dlo)); \
	EMIT(MIPS_MFHI(dhi)); \
	last_lohi = (u8 *)tcache_ptr; \
} while (0)

#define emith_mula_s64(dlo, dhi, s1, s2) do { \
	int t_ = rcache_get_tmp(); \
	emith_lohi_nops(); \
	EMIT(MIPS_MULT(s1, s2)); \
	EMIT(MIPS_MFLO(AT)); \
	EMIT(MIPS_MFHI(t_)); \
	last_lohi = (u8 *)tcache_ptr; \
	emith_add_r_r(dlo, AT); \
	EMIT(MIPS_SLTU_REG(AT, dlo, AT)); \
	emith_add_r_r(dhi, AT); \
	emith_add_r_r(dhi, t_); \
	rcache_free_tmp(t_); \
} while (0)
#define emith_mula_s64_c(cond, dlo, dhi, s1, s2) \
	emith_mula_s64(dlo, dhi, s1, s2)

// load/store. offs has 16 bits signed, which is currently sufficient
#define emith_read_r_r_offs_ptr(r, rs, offs) \
	EMIT(MIPS_OP_IMM(OP_LP, r, rs, offs))
#define emith_read_r_r_offs_ptr_c(cond, r, rs, offs) \
	emith_read_r_r_offs_ptr(r, rs, offs)

#define emith_read_r_r_offs(r, rs, offs) \
	EMIT(MIPS_LW(r, rs, offs))
#define emith_read_r_r_offs_c(cond, r, rs, offs) \
	emith_read_r_r_offs(r, rs, offs)
 
#define emith_read_r_r_r_ptr(r, rs, rm) do { \
	emith_add_r_r_r_ptr(AT, rs, rm); \
	EMIT(MIPS_OP_IMM(OP_LP, r, AT, 0)); \
} while (0)

#define emith_read_r_r_r(r, rs, rm) do { \
	emith_add_r_r_r_ptr(AT, rs, rm); \
	EMIT(MIPS_LW(r, AT, 0)); \
} while (0)
#define emith_read_r_r_r_c(cond, r, rs, rm) \
	emith_read_r_r_r(r, rs, rm)

#define emith_read8_r_r_offs(r, rs, offs) \
	EMIT(MIPS_LBU(r, rs, offs))
#define emith_read8_r_r_offs_c(cond, r, rs, offs) \
	emith_read8_r_r_offs(r, rs, offs)

#define emith_read8_r_r_r(r, rs, rm) do { \
	emith_add_r_r_r_ptr(AT, rs, rm); \
	EMIT(MIPS_LBU(r, AT, 0)); \
} while (0)
#define emith_read8_r_r_r_c(cond, r, rs, rm) \
	emith_read8_r_r_r(r, rs, rm)

#define emith_read16_r_r_offs(r, rs, offs) \
	EMIT(MIPS_LHU(r, rs, offs))
#define emith_read16_r_r_offs_c(cond, r, rs, offs) \
	emith_read16_r_r_offs(r, rs, offs)

#define emith_read16_r_r_r(r, rs, rm) do { \
	emith_add_r_r_r_ptr(AT, rs, rm); \
	EMIT(MIPS_LHU(r, AT, 0)); \
} while (0)
#define emith_read16_r_r_r_c(cond, r, rs, rm) \
	emith_read16_r_r_r(r, rs, rm)

#define emith_read8s_r_r_offs(r, rs, offs) \
	EMIT(MIPS_LB(r, rs, offs))
#define emith_read8s_r_r_offs_c(cond, r, rs, offs) \
	emith_read8s_r_r_offs(r, rs, offs)

#define emith_read8s_r_r_r(r, rs, rm) do { \
	emith_add_r_r_r_ptr(AT, rs, rm); \
	EMIT(MIPS_LB(r, AT, 0)); \
} while (0)
#define emith_read8s_r_r_r_c(cond, r, rs, rm) \
	emith_read8s_r_r_r(r, rs, rm)

#define emith_read16s_r_r_offs(r, rs, offs) \
	EMIT(MIPS_LH(r, rs, offs))
#define emith_read16s_r_r_offs_c(cond, r, rs, offs) \
	emith_read16s_r_r_offs(r, rs, offs)

#define emith_read16s_r_r_r(r, rs, rm) do { \
	emith_add_r_r_r_ptr(AT, rs, rm); \
	EMIT(MIPS_LH(r, AT, 0)); \
} while (0)
#define emith_read16s_r_r_r_c(cond, r, rs, rm) \
	emith_read16s_r_r_r(r, rs, rm)


#define emith_write_r_r_offs_ptr(r, rs, offs) \
	EMIT(MIPS_OP_IMM(OP_SP, r, rs, offs))
#define emith_write_r_r_offs_ptr_c(cond, r, rs, offs) \
	emith_write_r_r_offs_ptr(r, rs, offs)

#define emith_write_r_r_r_ptr(r, rs, rm) do { \
	emith_add_r_r_r_ptr(AT, rs, rm); \
	EMIT(MIPS_OP_IMM(OP_SP, r, AT, 0)); \
} while (0)
#define emith_write_r_r_r_ptr_c(cond, r, rs, rm) \
	emith_write_r_r_r_ptr(r, rs, rm)

#define emith_write_r_r_offs(r, rs, offs) \
	EMIT(MIPS_SW(r, rs, offs))
#define emith_write_r_r_offs_c(cond, r, rs, offs) \
	emith_write_r_r_offs(r, rs, offs)

#define emith_write_r_r_r(r, rs, rm) do { \
	emith_add_r_r_r_ptr(AT, rs, rm); \
	EMIT(MIPS_SW(r, AT, 0)); \
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
	int _c; u32 _m = mask & 0x300fffc; /* r2-r15,r24-r25 */ \
	if (__builtin_parity(_m) == 1) _m |= 0x1; /* ABI align */ \
	int _s = count_bits(_m) * 4, _o = _s; \
	if (_s) emith_add_r_r_ptr_imm(SP, SP, -_s); \
	for (_c = HOST_REGS-1; _m && _c >= 0; _m &= ~(1 << _c), _c--) \
		if (_m & (1 << _c)) \
			{ _o -= 4; if (_c) emith_write_r_r_offs(_c, SP, _o); } \
} while (0)

#define emith_restore_caller_regs(mask) do { \
	int _c; u32 _m = mask & 0x300fffc; \
	if (__builtin_parity(_m) == 1) _m |= 0x1; \
	int _s = count_bits(_m) * 4, _o = 0; \
	for (_c = 0; _m && _c < HOST_REGS; _m &= ~(1 << _c), _c++) \
		if (_m & (1 << _c)) \
			{ if (_c) emith_read_r_r_offs(_c, SP, _o); _o += 4; } \
	if (_s) emith_add_r_r_ptr_imm(SP, SP, _s); \
} while (0)

#define host_call(addr, args) \
	addr

#define host_arg2reg(rd, arg) \
	rd = (arg+4)

#define emith_pass_arg_r(arg, reg) \
	emith_move_r_r_ptr(arg, reg)

#define emith_pass_arg_imm(arg, imm) \
	emith_move_r_ptr_imm(arg, imm)

// branching
#define emith_invert_branch(cond) /* inverted conditional branch */ \
	(((cond) >> 5) == OP__RT ? (cond) ^ 0x01 : (cond) ^ 0x20)

// evaluate the emulated condition, returns a register/branch type pair
static int emith_cmpr_check(int rs, int rt, int cond, int *r)
{
	int b = 0;

	// condition check for comparing 2 registers
	switch (cond) {
	case DCOND_EQ:	*r = rs; b = MIPS_BEQ|rt; break;
	case DCOND_NE:	*r = rs; b = MIPS_BNE|rt; break;
	case DCOND_LO:	EMIT(MIPS_SLTU_REG(AT, rs, rt));
			*r = AT, b = MIPS_BNE; break;	// s <  t unsigned
	case DCOND_HS:	EMIT(MIPS_SLTU_REG(AT, rs, rt));
			*r = AT, b = MIPS_BEQ; break;	// s >= t unsigned
	case DCOND_LS:	EMIT(MIPS_SLTU_REG(AT, rt, rs));
			*r = AT, b = MIPS_BEQ; break;	// s <= t unsigned
	case DCOND_HI:	EMIT(MIPS_SLTU_REG(AT, rt, rs));
			*r = AT, b = MIPS_BNE; break;	// s >  t unsigned
	case DCOND_LT:	if (rt == 0) { *r = rs, b = MIPS_BLT; break; } // s <  0
			EMIT(MIPS_SLT_REG(AT, rs, rt));
			*r = AT, b = MIPS_BNE; break;	// s <  t
	case DCOND_GE:	if (rt == 0) { *r = rs, b = MIPS_BGE; break; } // s >= 0
			EMIT(MIPS_SLT_REG(AT, rs, rt));
			*r = AT, b = MIPS_BEQ; break;	// s >= t
	case DCOND_LE:	if (rt == 0) { *r = rs, b = MIPS_BLE; break; } // s <= 0
			EMIT(MIPS_SLT_REG(AT, rt, rs));
			*r = AT, b = MIPS_BEQ; break;	// s <= t
	case DCOND_GT:	if (rt == 0) { *r = rs, b = MIPS_BGT; break; } // s >  0
			EMIT(MIPS_SLT_REG(AT, rt, rs));
			*r = AT, b = MIPS_BNE; break;	// s >  t
	}

	return b;
}

static int emith_cmpi_check(int rs, s32 imm, int cond, int *r)
{
	int b = 0;

	// condition check for comparing register with immediate
	if (imm == 0) return emith_cmpr_check(rs, Z0, cond, r);
	switch (cond) {
	case DCOND_EQ:	emith_move_r_imm(AT, imm);
			*r = rs; b = MIPS_BEQ|AT; break;
	case DCOND_NE:	emith_move_r_imm(AT, imm);
			*r = rs; b = MIPS_BNE|AT; break;
	case DCOND_LO:	EMIT(MIPS_SLTU_IMM(AT, rs, imm));
			*r = AT, b = MIPS_BNE; break;	// s <  imm unsigned
	case DCOND_HS:	EMIT(MIPS_SLTU_IMM(AT, rs, imm));
			*r = AT, b = MIPS_BEQ; break;	// s >= imm unsigned
	case DCOND_LS:	emith_move_r_imm(AT, imm);
			EMIT(MIPS_SLTU_REG(AT, AT, rs));
			*r = AT, b = MIPS_BEQ; break;	// s <= imm unsigned
	case DCOND_HI:	emith_move_r_imm(AT, imm);
			EMIT(MIPS_SLTU_REG(AT, AT, rs));
			*r = AT, b = MIPS_BNE; break;	// s >  imm unsigned
	case DCOND_LT:	EMIT(MIPS_SLT_IMM(AT, rs, imm));
			*r = AT, b = MIPS_BNE; break;	// s <  imm
	case DCOND_GE: 	EMIT(MIPS_SLT_IMM(AT, rs, imm));
			*r = AT, b = MIPS_BEQ; break;	// s >= imm
	case DCOND_LE:	emith_move_r_imm(AT, imm);
			EMIT(MIPS_SLT_REG(AT, AT, rs));
			*r = AT, b = MIPS_BEQ; break;	// s <= imm
	case DCOND_GT:	emith_move_r_imm(AT, imm);
			EMIT(MIPS_SLT_REG(AT, AT, rs));
			*r = AT, b = MIPS_BNE; break;	// s >  imm
	}
	return b;
}

static int emith_cond_check(int cond, int *r)
{
	int b = 0;

	if (emith_cmp_rs >= 0) {
		if (emith_cmp_rt != -1)
			b = emith_cmpr_check(emith_cmp_rs,emith_cmp_rt, cond,r);
		else	b = emith_cmpi_check(emith_cmp_rs,emith_cmp_imm,cond,r);
	}

	// shortcut for V known to be 0
	if (!b && emith_flg_noV) switch (cond) {
	case DCOND_VS:	*r = Z0; b = MIPS_BNE; break;		// never
	case DCOND_VC:	*r = Z0; b = MIPS_BEQ; break;		// always
	case DCOND_LT:	*r = FNZ, b = MIPS_BLT;	break;		// N
	case DCOND_GE:	*r = FNZ, b = MIPS_BGE;	break;		// !N
	case DCOND_LE:	*r = FNZ, b = MIPS_BLE;	break;		// N || Z
	case DCOND_GT:	*r = FNZ, b = MIPS_BGT;	break;		// !N && !Z
	}

	// the full monty if no shortcut
	if (!b) switch (cond) {
	// conditions using NZ
	case DCOND_EQ:	*r = FNZ; b = MIPS_BEQ; break;		// Z
	case DCOND_NE:	*r = FNZ; b = MIPS_BNE; break;		// !Z
	case DCOND_MI:	*r = FNZ; b = MIPS_BLT; break;		// N
	case DCOND_PL:	*r = FNZ; b = MIPS_BGE; break;		// !N
	// conditions using C
	case DCOND_LO:	*r = FC; b = MIPS_BNE; break;		// C
	case DCOND_HS:	*r = FC; b = MIPS_BEQ; break;		// !C
	// conditions using CZ
	case DCOND_LS:						// C || Z
	case DCOND_HI:						// !C && !Z
		EMIT(MIPS_ADD_IMM(AT, FC, -1)); // !C && !Z
		EMIT(MIPS_AND_REG(AT, FNZ, AT));
		*r = AT, b = (cond == DCOND_HI ? MIPS_BNE : MIPS_BEQ);
		break;

	// conditions using V
	case DCOND_VS:						// V
	case DCOND_VC:						// !V
		EMIT(MIPS_XOR_REG(AT, FV, FNZ)); // V = Nt^Ns^Nd^C
		EMIT(MIPS_LSR_IMM(AT, AT, 31));
		EMIT(MIPS_XOR_REG(AT, AT, FC));
		*r = AT, b = (cond == DCOND_VS ? MIPS_BNE : MIPS_BEQ);
		break;
	// conditions using VNZ
	case DCOND_LT:						// N^V
	case DCOND_GE:						// !(N^V)
		EMIT(MIPS_LSR_IMM(AT, FV, 31)); // Nd^V = Nt^Ns^C
		EMIT(MIPS_XOR_REG(AT, FC, AT));
		*r = AT, b = (cond == DCOND_LT ? MIPS_BNE : MIPS_BEQ);
		break;
	case DCOND_LE:						// (N^V) || Z
	case DCOND_GT:						// !(N^V) && !Z
		EMIT(MIPS_LSR_IMM(AT, FV, 31)); // Nd^V = Nt^Ns^C
		EMIT(MIPS_XOR_REG(AT, FC, AT));
		EMIT(MIPS_ADD_IMM(AT, AT, -1)); // !(Nd^V) && !Z
		EMIT(MIPS_AND_REG(AT, FNZ, AT));
		*r = AT, b = (cond == DCOND_GT ? MIPS_BNE : MIPS_BEQ);
		break;
	}
	return b;
}

// NB: assumes all targets are in the same 256MB segment
#define emith_jump(target) \
	emith_branch(MIPS_J((uintptr_t)target & 0x0fffffff))
#define emith_jump_patchable(target) \
	emith_jump(target)

// NB: MIPS conditional branches have only +/- 128KB range
#define emith_jump_cond(cond, target) do { \
	int r_, mcond_ = emith_cond_check(cond, &r_); \
	u32 disp_ = (u8 *)target - (u8 *)tcache_ptr - 4; \
	emith_branch(MIPS_BCONDZ(mcond_,r_,disp_ & 0x0003ffff)); \
} while (0)
#define emith_jump_cond_patchable(cond, target) \
	emith_jump_cond(cond, target)

#define emith_jump_cond_inrange(target) \
	((u8 *)target - (u8 *)tcache_ptr - 4 <   0x20000 && \
	 (u8 *)target - (u8 *)tcache_ptr - 4 >= -0x20000+0x10) //mind cond_check

// NB: returns position of patch for cache maintenance
#define emith_jump_patch(ptr, target, pos) do { \
	u32 *ptr_ = (u32 *)ptr-1; /* must skip condition check code */ \
	u32 disp_, mask_; \
	while (!emith_is_j(*ptr_) && !emith_is_b(*ptr_)) ptr_ ++; \
	if (emith_is_b(*ptr_)) \
		mask_ = 0xffff0000, disp_ = (u8 *)target - (u8 *)ptr_ - 4; \
	else	mask_ = 0xfc000000, disp_ = (uintptr_t)target; \
	EMIT_PTR(ptr_, (*ptr_ & mask_) | ((disp_ >> 2) & ~mask_)); \
	if ((void *)(pos) != NULL) *(u8 **)(pos) = (u8 *)(ptr_-1); \
} while (0)

#define emith_jump_patch_inrange(ptr, target) \
	((u8 *)target - (u8 *)ptr - 4 <   0x20000 && \
	 (u8 *)target - (u8 *)ptr - 4 >= -0x20000+0x10) // mind cond_check
#define emith_jump_patch_size() 4

#define emith_jump_at(ptr, target) do { \
	u32 *ptr_ = (u32 *)ptr; \
	EMIT_PTR(ptr_, MIPS_J((uintptr_t)target & 0x0fffffff)); \
	EMIT_PTR(ptr_, MIPS_NOP); \
} while (0)
#define emith_jump_at_size() 8

#define emith_jump_reg(r) \
	emith_branch(MIPS_JR(r))
#define emith_jump_reg_c(cond, r) \
	emith_jump_reg(r)

#define emith_jump_ctx(offs) do { \
	emith_ctx_read_ptr(CR, offs); \
	emith_jump_reg(CR); \
} while (0)
#define emith_jump_ctx_c(cond, offs) \
	emith_jump_ctx(offs)

#define emith_call(target) \
	emith_branch(MIPS_JAL((uintptr_t)target & 0x0fffffff))
#define emith_call_cond(cond, target) \
	emith_call(target)

#define emith_call_reg(r) \
	emith_branch(MIPS_JALR(LR, r))
#define emith_abicall_ctx(offs) do { \
	emith_ctx_read_ptr(CR, offs); \
	emith_call_reg(CR); \
} while (0)

#define emith_abijump_reg(r) do { \
	if ((r) != CR) emith_move_r_r(CR, r); \
	emith_branch(MIPS_JR(CR)); \
} while (0)
#define emith_abijump_reg_c(cond, r) \
	emith_abijump_reg(r)
#define emith_abicall(target) do { \
	emith_move_r_ptr_imm(CR, target); \
	emith_branch(MIPS_JALR(LR, CR)); \
} while (0)
#define emith_abicall_cond(cond, target) \
	emith_abicall(target)
#define emith_abicall_reg(r) do { \
	if ((r) != CR) emith_move_r_r(CR, r); \
	emith_branch(MIPS_JALR(LR, CR)); \
} while (0)

#define emith_call_cleanup()	/**/

#define emith_ret() \
	emith_branch(MIPS_JR(LR))
#define emith_ret_c(cond) \
	emith_ret()

#define emith_ret_to_ctx(offs) \
	emith_ctx_write_ptr(LR, offs)

#define emith_add_r_ret(r) \
	emith_add_r_r_ptr(r, LR)

// NB: ABI SP alignment is 8 for 64 bit, O32 has a 16 byte arg save area
#define emith_push_ret(r) do { \
	int offs_ = 8+16 - 2*PTR_SIZE; \
	emith_add_r_r_ptr_imm(SP, SP, -8-16); \
	emith_write_r_r_offs_ptr(LR, SP, offs_ + PTR_SIZE); \
	if ((r) > 0) emith_write_r_r_offs(r, SP, offs_); \
} while (0)

#define emith_pop_and_ret(r) do { \
	int offs_ = 8+16 - 2*PTR_SIZE; \
	if ((r) > 0) emith_read_r_r_offs(r, SP, offs_); \
	emith_read_r_r_offs_ptr(LR, SP, offs_ + PTR_SIZE); \
	emith_add_r_r_ptr_imm(SP, SP, 8+16); \
	emith_ret(); \
} while (0)


// emitter ABI stuff
#define	emith_update_cache()	/**/
#define emith_rw_offs_max()	0x7fff
#define emith_uext_ptr(r)	/**/

#if __mips_isa_rev >= 2 && defined(MIPS_USE_SYNCI) && defined(__GNUC__)
// this should normally be in libc clear_cache; however, it sometimes isn't.
// core function taken from SYNCI description, MIPS32 instruction set manual
static NOINLINE void host_instructions_updated(void *base, void *end, int force)
{
	int step, tmp;
	asm volatile(
	"	rdhwr	%2, $1;"
	"	bal	0f;"			// needed to allow for jr.hb:
#if _MIPS_SZPTR == 64
	"0:	daddiu	$ra, $ra, 3f-0b;"	//   set ra to insn after jr.hb
#else
	"0:	addiu	$ra, $ra, 3f-0b;"	//   set ra to insn after jr.hb
#endif
	"	beqz	%2, 3f;"

	"1:	synci	0(%0);"
	"	sltu	%3, %0, %1;"
#if _MIPS_SZPTR == 64
	"	daddu	%0, %0, %2;"
#else
	"	addu	%0, %0, %2;"
#endif
	"	bnez	%3, 1b;"

	"	sync;"
	"2:	jr.hb	$ra;"
	"3:	" : "+r"(base), "+r"(end), "=r"(step), "=r"(tmp) :: "$31");
}
#else
#define host_instructions_updated(base, end, force) __builtin___clear_cache(base, end)
#endif

// SH2 drc specific
#define emith_sh2_drc_entry() do { \
	int _c, _z = PTR_SIZE; u32 _m = 0xd0ff0000; \
	if (__builtin_parity(_m) == 1) _m |= 0x1; /* ABI align for SP is 8 */ \
	int _s = count_bits(_m) * _z + 16, _o = _s; /* 16 O32 arg save area */ \
	if (_s) emith_add_r_r_ptr_imm(SP, SP, -_s); \
	for (_c = HOST_REGS-1; _m && _c >= 0; _m &= ~(1 << _c), _c--) \
		if (_m & (1 << _c)) \
			{ _o -= _z; if (_c) emith_write_r_r_offs_ptr(_c, SP, _o); } \
} while (0)
#define emith_sh2_drc_exit() do { \
	int _c, _z = PTR_SIZE; u32 _m = 0xd0ff0000; \
	if (__builtin_parity(_m) == 1) _m |= 0x1; \
	int _s = count_bits(_m) * _z + 16, _o = 16; \
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
	emith_read_r_r_offs(mask, tab, (1 << PTR_SCALE)); \
	emith_addf_r_r_r_ptr(func, func, func); \
} while (0)

// NB: assumes a, val are in arg0 and arg1, tab and func are temp
#define emith_sh2_wcall(a, val, tab, func) do { \
	emith_lsr(func, a, SH2_WRITE_SHIFT); \
	emith_lsl(func, func, PTR_SCALE); \
	emith_read_r_r_r_ptr(CR, tab, func); \
	emith_move_r_r_ptr(6, CONTEXT_REG); /* arg2 */ \
	emith_abijump_reg(CR); \
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
	EMIT(MIPS_SLTU_REG(FC, rn, t_));          \
	EMITH_JMP3_MID(DCOND_EQ);                 \
	emith_sub_r_r_r(rn, t_, rm);              \
	EMIT(MIPS_SLTU_REG(FC, t_, rn));          \
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
	EMITH_SJMP_START(DCOND_MI); /* sum < 0 -> +ovrfl */ \
	emith_sub_r_imm_c(DCOND_PL, ml, 1); /* 0x7fffffff */ \
	EMITH_SJMP_END(DCOND_MI);                 \
	EMITH_SJMP_END(DCOND_EQ);                 \
	EMITH_SJMP_END(DCOND_EQ);                 \
} while (0)

#define emith_write_sr(sr, srcr) do { \
	if (__mips_isa_rev < 2) { \
		emith_lsr(sr, sr  , 10); emith_lsl(sr, sr, 10); \
		emith_lsl(AT, srcr, 22); emith_lsr(AT, AT, 22); \
		emith_or_r_r(sr, AT); \
	} else	EMIT(MIPS_INS_IMM(sr, srcr, 0, 10)); \
} while (0)

#define emith_carry_to_t(sr, is_sub) do { \
	if (__mips_isa_rev < 2) { \
		emith_and_r_imm(sr, 0xfffffffe); \
		emith_or_r_r(sr, FC); \
	} else	EMIT(MIPS_INS_IMM(sr, FC, 0, 1)); \
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
  int b, r;
  u8 *ptr;
  u32 val = 0, inv = 0;

  // try to avoid jumping around if possible
  if (emith_cmp_rs >= 0) {
    if (emith_cmp_rt >= 0)
      b = emith_cmpr_check(emith_cmp_rs, emith_cmp_rt,  cond, &r);
    else
      b = emith_cmpi_check(emith_cmp_rs, emith_cmp_imm, cond, &r);

    // XXX this relies on the inner workings of cmp_check...
    if (r == AT)
      // result of slt check which returns either 0 or 1 in AT
      val++, inv = (b == MIPS_BEQ);
  } else {
    b = emith_cond_check(cond, &r);
    if (r == Z0) {
      if (b == MIPS_BEQ || b == MIPS_BLE || b == MIPS_BGE)
        emith_or_r_imm(sr, T);
      return;
    } else if (r == FC)
      val++, inv = (b == MIPS_BEQ);
  }

  if (!val) switch (b) { // cases: b..z r, aka cmp r,Z0 or cmp r,#0
  case MIPS_BEQ:  EMIT(MIPS_SLTU_IMM(AT, r, 1)); r=AT; val++; break;
  case MIPS_BNE:  EMIT(MIPS_SLTU_REG(AT,Z0, r)); r=AT; val++; break;
  case MIPS_BLT:  EMIT(MIPS_SLT_REG(AT, r, Z0)); r=AT; val++; break;
  case MIPS_BGE:  EMIT(MIPS_SLT_REG(AT, r, Z0)); r=AT; val++; inv++; break;
  case MIPS_BLE:  EMIT(MIPS_SLT_REG(AT, Z0, r)); r=AT; val++; inv++; break;
  case MIPS_BGT:  EMIT(MIPS_SLT_REG(AT, Z0, r)); r=AT; val++; break;
  default: // cases: beq/bne r,s, aka cmp r,s
      if ((b>>5) == OP_BEQ) {
                  EMIT(MIPS_XOR_REG(AT, r, b&0x1f));
                  EMIT(MIPS_SLTU_IMM(AT,AT, 1)); r=AT; val++; break;
      } else if ((b>>5) == OP_BNE) {
                  EMIT(MIPS_XOR_REG(AT, r, b&0x1f));
                  EMIT(MIPS_SLTU_REG(AT,Z0,AT)); r=AT; val++; break;
      }
  }
  if (val) {
    emith_or_r_r(sr, r);
    if (inv)
      emith_eor_r_imm(sr, T);
    return;
  }

  // can't obtain result directly, use presumably slower jump !cond + or sr,T
  b = emith_invert_branch(b);
  ptr = emith_branch(MIPS_BCONDZ(b, r, 0));
  emith_or_r_imm(sr, T);
  emith_flush(); // prohibit delay slot switching across jump targets
  val = (u8 *)tcache_ptr - (u8 *)(ptr) - 4;
  EMIT_PTR(ptr, MIPS_BCONDZ(b, r, val & 0x0003ffff));
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
