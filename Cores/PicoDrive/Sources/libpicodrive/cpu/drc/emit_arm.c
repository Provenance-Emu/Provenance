/*
 * Basic macros to emit ARM instructions and some utils
 * Copyright (C) 2008,2009,2010 notaz
 * Copyright (C) 2019-2024 irixxxx
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */
#define HOST_REGS	16

// OABI/EABI: params: r0-r3, return: r0-r1, temp: r12,r14, saved: r4-r8,r10,r11
// SP,PC: r13,r15 must not be used. saved: r9 (for platform use, e.g. on ios)
#define RET_REG		0
#define PARAM_REGS	{ 0, 1, 2, 3 }
#ifndef __MACH__
#define	PRESERVED_REGS	{ 4, 5, 6, 7, 8, 9, 10, 11 }
#else
#define	PRESERVED_REGS	{ 4, 5, 6, 7, 8,    10, 11 } // no r9..
#endif
#define TEMPORARY_REGS	{ 12, 14 }

#define CONTEXT_REG	11
#define STATIC_SH2_REGS	{ SHR_SR,10 , SHR_R(0),8 , SHR_R(1),9 }

// XXX: tcache_ptr type for SVP and SH2 compilers differs..
#define EMIT_PTR(ptr, x) \
	do { \
		*(u32 *)ptr = x; \
		ptr = (void *)((u8 *)ptr + sizeof(u32)); \
	} while (0)

// ARM special registers and peephole optimization flags
#define SP		13	// stack pointer
#define LR		14	// link (return address)
#define PC		15	// program counter
#define SR		16	// CPSR, status register
#define MEM		17	// memory access (src=LDR, dst=STR)
#define CYC1		20	// 1 cycle interlock (LDR, reg-cntrld shift)
#define CYC2		(CYC1+1)// 2+ cycles interlock (LDR[BH], MUL/MLA etc)
#define NO		32	// token for "no register"

// bitmask builders
#define M1(x)		(u32)(1ULL<<(x)) // u32 to have NO evaluate to 0
#define M2(x,y)		(M1(x)|M1(y))
#define M3(x,y,z)	(M2(x,y)|M1(z))
#define M4(x,y,z,a)	(M3(x,y,z)|M1(a))
#define M5(x,y,z,a,b)	(M4(x,y,z,a)|M1(b))
#define M6(x,y,z,a,b,c)	(M5(x,y,z,a,b)|M1(c))
#define M10(a,b,c,d,e,f,g,h,i,j) (M5(a,b,c,d,e)|M5(f,g,h,i,j))

// avoid a warning with clang
static inline uintptr_t pabs(intptr_t v) { return labs(v); }

// sys_cacheflush always flushes whole pages, and it's rather expensive on ARMs
// hold a list of pending cache updates and merge requests to reduce cacheflush
static struct { void *base, *end; } pageflush[4];
static unsigned pagesize = 4096;

static void emith_update_cache(void)
{
	int i;

	for (i = 0; i < 4 && pageflush[i].base; i++) {
		cache_flush_d_inval_i(pageflush[i].base, pageflush[i].end + pagesize-1);
		pageflush[i].base = NULL;
	}
}

static inline void emith_update_add(void *base, void *end)
{
	void *p_base = (void *)((uintptr_t)(base) & ~(pagesize-1));
	void *p_end  = (void *)((uintptr_t)(end ) & ~(pagesize-1));
	int i;

	for (i = 0; i < 4 && pageflush[i].base; i++) {
		if (p_base <= pageflush[i].end+pagesize && p_end >= pageflush[i].end) {
			if (p_base < pageflush[i].base) pageflush[i].base = p_base;
			pageflush[i].end = p_end;
			return;
		}
		if (p_base <= pageflush[i].base && p_end >= pageflush[i].base-pagesize) {
			if (p_end > pageflush[i].end) pageflush[i].end = p_end;
			pageflush[i].base = p_base;
			return;
		}
	}
	if (i == 4) {
		/* list full and not mergeable -> flush list */
		emith_update_cache();
		i = 0;
	}
	pageflush[i].base = p_base, pageflush[i].end = p_end;
}

// peephole optimizer. ATM only tries to reduce interlock
#define EMIT_CACHE_SIZE 6
struct emit_op {
	u32 op;
	u32 src, dst;
};

// peephole cache, last commited insn + cache + next insn = size+2
static struct emit_op emit_cache[EMIT_CACHE_SIZE+2];
static int emit_index;
#define emith_insn_ptr()	(u8 *)((u32 *)tcache_ptr-emit_index)

static inline void emith_pool_adjust(int tcache_offs, int move_offs);

static NOINLINE void EMIT(u32 op, u32 dst, u32 src)
{
	void * emit_ptr = (u32 *)tcache_ptr - emit_index;
	struct emit_op *const ptr = emit_cache;
	const int n = emit_index+1;
	int i, bi, bd = 0;

	// account for new insn in tcache
	tcache_ptr = (void *)((u32 *)tcache_ptr + 1);
	COUNT_OP;
	// for conditional execution SR is always source
	if (op < 0xe0000000 /*A_COND_AL << 28*/)
		src |= M1(SR);
	// put insn on back of queue // mask away the NO token
	emit_cache[n] = (struct emit_op)
			{ .op=op, .src=src & ~M1(NO), .dst=dst & ~M1(NO) };
	// check insns down the queue as long as permitted by dependencies
	for (bd = bi = 0, i = emit_index; i > 1 && !(dst & M1(PC)); i--) {
		int deps = 0;
		// dst deps between i and n must not be swapped, since any deps
		// but [i].src & [n].src lead to changed semantics if swapped.
		if ((ptr[i].dst & ptr[n].src) || (ptr[n].dst & ptr[i].src) ||
		      (ptr[i].dst & ptr[n].dst))
			break;
		// don't swap insns reading PC if it's not a word pool load
		//	(ptr[i].op&0xf700000) != EOP_C_AM2_IMM(0,0,0,1,0,0,0))
		if ((ptr[i].src & M1(PC)) && (ptr[i].op&0xf700000) != 0x5100000)
			break;

		// calculate ARM920T interlock cycles (differences only)
#define	D2(x,y)	((ptr[x].dst & ptr[y].src)?((ptr[x].src >> CYC2) & 1):0)
#define	D1(x,y)	((ptr[x].dst & ptr[y].src)?((ptr[x].src >> CYC1) & 3):0)
		//   insn sequence: [..., i-2, i-1, i, i+1, ..., n-2, n-1, n]
		deps -= D2(i-2,i)+D2(i-1,i+1)+D2(n-2,n  ) + D1(i-1,i)+D1(n-1,n);
		deps -= !!(ptr[n].src & M2(CYC1,CYC2));// favour moving LDR down
		//   insn sequence: [..., i-2, i-1, n, i, i+1, ..., n-2, n-1]
		deps += D2(i-2,n)+D2(i-1,i  )+D2(n  ,i+1) + D1(i-1,n)+D1(n  ,i);
		deps += !!(ptr[i].src & M2(CYC1,CYC2));// penalize moving LDR up
		// remember best match found
		if (bd > deps)
			bd = deps, bi = i;
	}
	// swap if fewer depencies
	if (bd < 0) {
		// make room for new insn at bi
		struct emit_op tmp = ptr[n];
		for (i = n-1; i >= bi; i--) {
			ptr[i+1] = ptr[i];
			if (ptr[i].src & M1(PC))
				emith_pool_adjust(n-i+1, 1);
		}
		// insert new insn at bi
		ptr[bi] = tmp;
		if (ptr[bi].src & M1(PC))
			emith_pool_adjust(1, bi-n);
	}
	if (dst & M1(PC)) {
		// commit everything if a branch insn is emitted
		for (i = 1; i <= emit_index+1; i++)
			EMIT_PTR(emit_ptr, emit_cache[i].op);
		emit_index = 0;
	} else if (emit_index < EMIT_CACHE_SIZE) {
		// queue not yet full
		emit_index++;
	} else {
		// commit oldest insn from cache
		EMIT_PTR(emit_ptr, emit_cache[1].op);
		for (i = 0; i <= emit_index; i++)
			emit_cache[i] = emit_cache[i+1];
	}
}

static void emith_flush(void)
{
	int i;
	void *emit_ptr = tcache_ptr - emit_index*sizeof(u32);

	for (i = 1; i <= emit_index; i++)
		EMIT_PTR(emit_ptr, emit_cache[i].op);
	emit_index = 0;
}

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
#define A_COND_NV 0xf // Not Valid (aka NeVer :-) - ATTN: not a real condition!

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

#define DCOND_CS A_COND_HS
#define DCOND_CC A_COND_LO

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
#define A_OP_CMN 0xb
#define A_OP_ORR 0xc
#define A_OP_MOV 0xd
#define A_OP_BIC 0xe
#define A_OP_MVN 0xf

// operation specific register usage in DOP
#define A_Rn(op,rn)	(((op)&0xd)!=0xd ? rn:NO) // no rn for MOV,MVN
#define A_Rd(op,rd)	(((op)&0xc)!=0x8 ? rd:NO) // no rd for TST,TEQ,CMP,CMN
// CSPR is dst if S set, CSPR is src if op is ADC/SBC/RSC or shift is RRX
#define A_Sd(s)		((s) ? SR:NO)
#define A_Sr(op,sop)	(((op)>=0x5 && (op)<=0x7) || (sop)>>4==A_AM1_ROR<<1 ? SR:NO)

#define EOP_C_DOP_X(cond,op,s,rn,rd,sop,rm,rs) \
	EMIT(((cond)<<28) | ((op)<< 21) | ((s)<<20) | ((rn)<<16) | ((rd)<<12) | (sop), \
		M2(A_Rd(op,rd),A_Sd(s)), M5(A_Sr(op,sop),A_Rn(op,rn),rm,rs,rs==NO?NO:CYC1))

#define EOP_C_DOP_IMM(     cond,op,s,rn,rd,ror2,imm8)             EOP_C_DOP_X(cond,op,s,rn,rd,A_AM1_IMM(ror2,imm8), NO, NO)
#define EOP_C_DOP_REG_XIMM(cond,op,s,rn,rd,shift_imm,shift_op,rm) EOP_C_DOP_X(cond,op,s,rn,rd,A_AM1_REG_XIMM(shift_imm,shift_op,rm), rm, NO)
#define EOP_C_DOP_REG_XREG(cond,op,s,rn,rd,rs,       shift_op,rm) EOP_C_DOP_X(cond,op,s,rn,rd,A_AM1_REG_XREG(rs,       shift_op,rm), rm, rs)

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
	EMIT(((cond)<<28) | 0x05000000 | ((u)<<23) | ((b)<<22) | ((l)<<20) | ((rn)<<16) | ((rd)<<12) | \
		((offset_12) & 0xfff), M1(l?rd:MEM), M3(rn,l?MEM:rd,l?b?CYC2:CYC1:NO))

#define EOP_C_AM2_REG(cond,u,b,l,rn,rd,shift_imm,shift_op,rm) \
	EMIT(((cond)<<28) | 0x07000000 | ((u)<<23) | ((b)<<22) | ((l)<<20) | ((rn)<<16) | ((rd)<<12) | \
		A_AM1_REG_XIMM(shift_imm, shift_op, rm), M1(l?rd:MEM), M4(rn,rm,l?MEM:rd,l?b?CYC2:CYC1:NO))

/* addressing mode 3 */
#define EOP_C_AM3(cond,u,r,l,rn,rd,s,h,immed_reg) \
	EMIT(((cond)<<28) | 0x01000090 | ((u)<<23) | ((r)<<22) | ((l)<<20) | ((rn)<<16) | ((rd)<<12) | \
		((s)<<6) | ((h)<<5) | (immed_reg), M1(l?rd:MEM), M4(rn,r?NO:immed_reg,l?MEM:rd,l?CYC2:NO))

#define EOP_C_AM3_IMM(cond,u,l,rn,rd,s,h,offset_8) EOP_C_AM3(cond,u,1,l,rn,rd,s,h,(((offset_8)&0xf0)<<4)|((offset_8)&0xf))

#define EOP_C_AM3_REG(cond,u,l,rn,rd,s,h,rm)       EOP_C_AM3(cond,u,0,l,rn,rd,s,h,rm)

/* ldr and str */
#define EOP_LDR_IMM2(cond,rd,rn,offset_12)  EOP_C_AM2_IMM(cond,(offset_12) >= 0,0,1,rn,rd,pabs(offset_12))
#define EOP_LDRB_IMM2(cond,rd,rn,offset_12) EOP_C_AM2_IMM(cond,(offset_12) >= 0,1,1,rn,rd,pabs(offset_12))
#define EOP_STR_IMM2(cond,rd,rn,offset_12)  EOP_C_AM2_IMM(cond,(offset_12) >= 0,0,0,rn,rd,pabs(offset_12))

#define EOP_LDR_IMM(   rd,rn,offset_12) EOP_C_AM2_IMM(A_COND_AL,(offset_12) >= 0,0,1,rn,rd,pabs(offset_12))
#define EOP_LDR_SIMPLE(rd,rn)           EOP_C_AM2_IMM(A_COND_AL,1,0,1,rn,rd,0)
#define EOP_STR_IMM(   rd,rn,offset_12) EOP_C_AM2_IMM(A_COND_AL,(offset_12) >= 0,0,0,rn,rd,pabs(offset_12))
#define EOP_STR_SIMPLE(rd,rn)           EOP_C_AM2_IMM(A_COND_AL,1,0,0,rn,rd,0)

#define EOP_LDR_REG_LSL(cond,rd,rn,rm,shift_imm) EOP_C_AM2_REG(cond,1,0,1,rn,rd,shift_imm,A_AM1_LSL,rm)
#define EOP_LDR_REG_LSL_WB(cond,rd,rn,rm,shift_imm) EOP_C_AM2_REG(cond,1,0,3,rn,rd,shift_imm,A_AM1_LSL,rm)
#define EOP_LDRB_REG_LSL(cond,rd,rn,rm,shift_imm) EOP_C_AM2_REG(cond,1,1,1,rn,rd,shift_imm,A_AM1_LSL,rm)
#define EOP_STR_REG_LSL_WB(cond,rd,rn,rm,shift_imm) EOP_C_AM2_REG(cond,1,0,2,rn,rd,shift_imm,A_AM1_LSL,rm)

#define EOP_LDRH_IMM2(cond,rd,rn,offset_8)  EOP_C_AM3_IMM(cond,(offset_8) >= 0,1,rn,rd,0,1,pabs(offset_8))
#define EOP_LDRH_REG2(cond,rd,rn,rm)        EOP_C_AM3_REG(cond,1,1,rn,rd,0,1,rm)

#define EOP_LDRH_IMM(   rd,rn,offset_8)  EOP_C_AM3_IMM(A_COND_AL,(offset_8) >= 0,1,rn,rd,0,1,pabs(offset_8))
#define EOP_LDRH_SIMPLE(rd,rn)           EOP_C_AM3_IMM(A_COND_AL,1,1,rn,rd,0,1,0)
#define EOP_LDRH_REG(   rd,rn,rm)        EOP_C_AM3_REG(A_COND_AL,1,1,rn,rd,0,1,rm)
#define EOP_STRH_IMM(   rd,rn,offset_8)  EOP_C_AM3_IMM(A_COND_AL,(offset_8) >= 0,0,rn,rd,0,1,pabs(offset_8))
#define EOP_STRH_SIMPLE(rd,rn)           EOP_C_AM3_IMM(A_COND_AL,1,0,rn,rd,0,1,0)
#define EOP_STRH_REG(   rd,rn,rm)        EOP_C_AM3_REG(A_COND_AL,1,0,rn,rd,0,1,rm)

#define EOP_LDRSB_IMM2(cond,rd,rn,offset_8) EOP_C_AM3_IMM(cond,(offset_8) >= 0,1,rn,rd,1,0,pabs(offset_8))
#define EOP_LDRSB_REG2(cond,rd,rn,rm)       EOP_C_AM3_REG(cond,1,1,rn,rd,1,0,rm)
#define EOP_LDRSH_IMM2(cond,rd,rn,offset_8) EOP_C_AM3_IMM(cond,(offset_8) >= 0,1,rn,rd,1,1,pabs(offset_8))
#define EOP_LDRSH_REG2(cond,rd,rn,rm)       EOP_C_AM3_REG(cond,1,1,rn,rd,1,1,rm)

/* ldm and stm */
#define EOP_XXM(cond,p,u,s,w,l,rn,list) \
	EMIT(((cond)<<28) | (1<<27) | ((p)<<24) | ((u)<<23) | ((s)<<22) | ((w)<<21) | ((l)<<20) | ((rn)<<16) | (list), \
		M2(rn,l?NO:MEM)|(l?list:0), M3(rn,l?MEM:NO,l?CYC2:NO)|(l?0:list))

#define EOP_STMIA(rb,list) EOP_XXM(A_COND_AL,0,1,0,0,0,rb,list)
#define EOP_LDMIA(rb,list) EOP_XXM(A_COND_AL,0,1,0,0,1,rb,list)

#define EOP_STMFD_SP(list) EOP_XXM(A_COND_AL,1,0,0,1,0,SP,list)
#define EOP_LDMFD_SP(list) EOP_XXM(A_COND_AL,0,1,0,1,1,SP,list)

/* branches */
#define EOP_C_BX(cond,rm) \
	EMIT(((cond)<<28) | 0x012fff10 | (rm), M1(PC), M1(rm))

#define EOP_C_B_PTR(ptr,cond,l,signed_immed_24) \
	EMIT_PTR(ptr, ((cond)<<28) | 0x0a000000 | ((l)<<24) | (signed_immed_24))

#define EOP_C_B(cond,l,signed_immed_24) \
	EMIT(((cond)<<28) | 0x0a000000 | ((l)<<24) | (signed_immed_24), M2(PC,l?LR:NO), M1(PC))

#define EOP_B( signed_immed_24) EOP_C_B(A_COND_AL,0,signed_immed_24)
#define EOP_BL(signed_immed_24) EOP_C_B(A_COND_AL,1,signed_immed_24)

/* misc */
#define EOP_C_MUL(cond,s,rd,rs,rm) \
	EMIT(((cond)<<28) | ((s)<<20) | ((rd)<<16) | ((rs)<<8) | 0x90 | (rm), M2(rd,s?SR:NO), M3(rs,rm,CYC2))

#define EOP_C_UMULL(cond,s,rdhi,rdlo,rs,rm) \
	EMIT(((cond)<<28) | 0x00800000 | ((s)<<20) | ((rdhi)<<16) | ((rdlo)<<12) | ((rs)<<8) | 0x90 | (rm), M3(rdhi,rdlo,s?SR:NO), M4(rs,rm,CYC1,CYC2))

#define EOP_C_SMULL(cond,s,rdhi,rdlo,rs,rm) \
	EMIT(((cond)<<28) | 0x00c00000 | ((s)<<20) | ((rdhi)<<16) | ((rdlo)<<12) | ((rs)<<8) | 0x90 | (rm), M3(rdhi,rdlo,s?SR:NO), M4(rs,rm,CYC1,CYC2))

#define EOP_C_SMLAL(cond,s,rdhi,rdlo,rs,rm) \
	EMIT(((cond)<<28) | 0x00e00000 | ((s)<<20) | ((rdhi)<<16) | ((rdlo)<<12) | ((rs)<<8) | 0x90 | (rm), M3(rdhi,rdlo,s?SR:NO), M6(rs,rm,rdlo,rdhi,CYC1,CYC2))

#define EOP_MUL(rd,rm,rs) EOP_C_MUL(A_COND_AL,0,rd,rs,rm) // note: rd != rm

#define EOP_C_MRS(cond,rd) \
	EMIT(((cond)<<28) | 0x010f0000 | ((rd)<<12), M1(rd), M1(SR))

#define EOP_C_MSR_IMM(cond,ror2,imm) \
	EMIT(((cond)<<28) | 0x0328f000 | ((ror2)<<8) | (imm), M1(SR), 0) // cpsr_f

#define EOP_C_MSR_REG(cond,rm) \
	EMIT(((cond)<<28) | 0x0128f000 | (rm), M1(SR), M1(rm)) // cpsr_f

#define EOP_MRS(rd)           EOP_C_MRS(A_COND_AL,rd)
#define EOP_MSR_IMM(ror2,imm) EOP_C_MSR_IMM(A_COND_AL,ror2,imm)
#define EOP_MSR_REG(rm)       EOP_C_MSR_REG(A_COND_AL,rm)

#define EOP_MOVW(cond,rd,imm) \
	EMIT(((cond)<<28) | 0x03000000 | ((rd)<<12) | ((imm)&0xfff) | (((imm)<<4)&0xf0000), M1(rd), NO)

#define EOP_MOVT(cond,rd,imm) \
	EMIT(((cond)<<28) | 0x03400000 | ((rd)<<12) | (((imm)>>16)&0xfff) | (((imm)>>12)&0xf0000), M1(rd), NO)

// host literal pool; must be significantly smaller than 1024 (max LDR offset = 4096)
#define MAX_HOST_LITERALS	128
static u32 literal_pool[MAX_HOST_LITERALS];
static u32 *literal_insn[MAX_HOST_LITERALS];
static int literal_pindex, literal_iindex;

static inline int emith_pool_literal(u32 imm, int *offs)
{
	int idx = literal_pindex - 8; // max look behind in pool
	// see if one of the last literals was the same (or close enough)
	for (idx = (idx < 0 ? 0 : idx); idx < literal_pindex; idx++)
		if (abs((int)(imm - literal_pool[idx])) <= 0xff)
			break;
	if (idx == literal_pindex)	// store new literal
		literal_pool[literal_pindex++] = imm;
	*offs = imm - literal_pool[idx];
	return idx;
}

// XXX: RSB, *S will break if 1 insn is not enough
static void emith_op_imm2(int cond, int s, int op, int rd, int rn, unsigned int imm)
{
	int ror2;
	u32 v;
	int i;

	if (cond == A_COND_NV)
		return;

	do {
		u32 u;
		// try to get the topmost byte empty to possibly save an insn
		for (v = imm, ror2 = 0; (v >> 24) && ror2 < 32/2; ror2++)
			v = (v << 2) | (v >> 30);

		switch (op) {
		case A_OP_MOV:
		case A_OP_MVN:
			rn = 0;
			// use MVN if more bits 1 than 0
			if (count_bits(imm) > 16) {
				imm = ~imm;
				op = A_OP_MVN;
				ror2 = -1;
				break;
			}
			// count insns needed for mov/orr #imm
#ifdef HAVE_ARMV7
			for (i = 2, u = v; i > 0 && u; i--, u >>= 8)
				while (u > 0xff && !(u & 3))
					u >>= 2;
			if (u) { // 3+ insns needed...
				if (op == A_OP_MVN)
					imm = ~imm;
				// ...prefer movw/movt
				EOP_MOVW(cond,rd, imm);
				if (imm & 0xffff0000)
					EOP_MOVT(cond,rd, imm);
				return;
			}
#else
			for (i = 2, u = v; i > 0 && u; i--, u >>= 8)
				while (u > 0xff && !(u & 3))
					u >>= 2;
			if (u) { // 3+ insns needed...
				if (op == A_OP_MVN)
					imm = ~imm;
				// ...emit literal load
				int idx, o;
				if (literal_iindex >= MAX_HOST_LITERALS) {
					elprintf(EL_STATUS|EL_SVP|EL_ANOMALY,
						"pool overflow");
					exit(1);
				}
				idx = emith_pool_literal(imm, &o);
				literal_insn[literal_iindex++] = (u32 *)tcache_ptr;
				EOP_LDR_IMM2(cond, rd, PC, idx * sizeof(u32));
				if (o > 0)
				    EOP_C_DOP_IMM(cond, A_OP_ADD, 0,rd,rd,0,o);
				else if (o < 0)
				    EOP_C_DOP_IMM(cond, A_OP_SUB, 0,rd,rd,0,-o);
				return;
			}
#endif
			break;

		case A_OP_AND:
			// AND must fit into 1 insn. if not, use BIC
			for (u = v; u > 0xff && !(u & 3); u >>= 2) ;
			if (u >> 8) {
				imm = ~imm;
				op = A_OP_BIC;
				ror2 = -1;
			}
			break;

		case A_OP_SUB:
		case A_OP_ADD:
			// swap ADD and SUB if more bits 1 than 0
			if (s == 0 && count_bits(imm) > 16) {
				imm = -imm;
				op ^= (A_OP_ADD^A_OP_SUB);
				ror2 = -1;
			}
		case A_OP_EOR:
		case A_OP_ORR:
		case A_OP_BIC:
			if (s == 0 && imm == 0 && rd == rn)
				return;
			break;
		}
	} while (ror2 < 0);

	do {
		// shift down to get 'best' rot2
		while (v > 0xff && !(v & 3))
			v >>= 2, ror2--;
		EOP_C_DOP_IMM(cond, op, s, rn, rd, ror2 & 0xf, v & 0xff);

		switch (op) {
		case A_OP_MOV:	op = A_OP_ORR; break;
		case A_OP_MVN:	op = A_OP_BIC; break;
		case A_OP_ADC:	op = A_OP_ADD; break;
		case A_OP_SBC:	op = A_OP_SUB; break;
		}
		rn = rd;

		v >>= 8, ror2 -= 8/2;
		if (v && s) {
			elprintf(EL_STATUS|EL_SVP|EL_ANOMALY, "op+s %x value too big", op);
			exit(1);
		}
	} while (v);
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

	if (cond == A_COND_NV)
		return 0; // never taken

	if (direct)
	{
		EOP_C_B(cond,is_call,val & 0xffffff);		// b, bl target
	}
	else
	{
#ifdef __EPOC32__
//		elprintf(EL_SVP, "emitting indirect jmp %08x->%08x", tcache_ptr, target);
		if (is_call)
			EOP_ADD_IMM(LR,PC,0,8);			// add lr,pc,#8
		EOP_C_AM2_IMM(cond,1,0,1,PC,PC,0);		// ldrcc pc,[pc]
		EOP_MOV_REG_SIMPLE(PC,PC);			// mov pc, pc
		EMIT((u32)target,M1(PC),0);
#else
		// should never happen
		elprintf(EL_STATUS|EL_SVP|EL_ANOMALY, "indirect jmp %8p->%8p", target, tcache_ptr);
		exit(1);
#endif
	}

	return (u32 *)tcache_ptr - start_ptr;
}

static void emith_pool_commit(int jumpover)
{
	int i, sz = literal_pindex * sizeof(u32);
	u8 *pool = (u8 *)tcache_ptr;

	// nothing to commit if pool is empty
	if (sz == 0)
		return;
	// need branch over pool if not at block end
	if (jumpover < 0 && sz == sizeof(u32)) {
		// hack for SVP drc (patch logic detects distance 4)
		sz += sizeof(u32);
	} else if (jumpover) {
		pool += sizeof(u32);
		emith_xbranch(A_COND_AL, (u8 *)pool + sz, 0);
	}
	emith_flush();
	// safety check - pool must be after insns and reachable
	if ((u32)(pool - (u8 *)literal_insn[0] + 8) > 0xfff) {
		elprintf(EL_STATUS|EL_SVP|EL_ANOMALY,
			"pool offset out of range");
		exit(1);
	}
	// copy pool and adjust addresses in insns accessing the pool
	memcpy(pool, literal_pool, sz);
	for (i = 0; i < literal_iindex; i++) {
		*literal_insn[i] += (u8 *)pool - ((u8 *)literal_insn[i] + 8);
	}
	// count pool constants as insns for statistics
	for (i = 0; i < literal_pindex; i++)
		COUNT_OP;

	tcache_ptr = (void *)((u8 *)pool + sz);
	literal_pindex = literal_iindex = 0;
}

static inline void emith_pool_check(void)
{
	// check if pool must be committed
	if (literal_iindex > MAX_HOST_LITERALS-4 || (literal_pindex &&
		    (u8 *)tcache_ptr - (u8 *)literal_insn[0] > 0xe00))
		// pool full, or displacement is approaching the limit
		emith_pool_commit(1);
}

static inline void emith_pool_adjust(int tcache_offs, int move_offs)
{
	u32 *ptr = (u32 *)tcache_ptr - tcache_offs;
	int i;

	for (i = literal_iindex-1; i >= 0 && literal_insn[i] >= ptr; i--)
		if (literal_insn[i] == ptr)
			literal_insn[i] += move_offs;
}

#define EMITH_HINT_COND(cond)	/**/

#define JMP_POS(ptr) { \
	ptr = tcache_ptr; \
	EMIT(0,M1(PC),0); \
}

#define JMP_EMIT(cond, ptr) { \
	u32 val_ = (u32 *)tcache_ptr - (u32 *)(ptr) - 2; \
	emith_flush(); /* NO insn swapping across jump targets */ \
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
#define EMITH_SJMP2_START(cond)	EMITH_NOTHING1(cond)
#define EMITH_SJMP2_MID(cond)	EMITH_JMP_START((cond)^1) // inverse cond
#define EMITH_SJMP2_END(cond)	EMITH_JMP_END((cond)^1)
#define EMITH_SJMP3_START(cond)	EMITH_NOTHING1(cond)
#define EMITH_SJMP3_MID(cond)	EMITH_NOTHING1(cond)
#define EMITH_SJMP3_END()

#define emith_move_r_r_c(cond, d, s) \
	EOP_MOV_REG(cond,0,d,s,A_AM1_LSL,0)
#define emith_move_r_r(d, s) \
	emith_move_r_r_c(A_COND_AL, d, s)

#define emith_move_r_r_ptr_c(cond, d, s) \
	emith_move_r_r_c(cond, d, s)
#define emith_move_r_r_ptr(d, s) \
	emith_move_r_r(d, s)

#define emith_mvn_r_r(d, s) \
	EOP_MVN_REG(A_COND_AL,0,d,s,A_AM1_LSL,0)

#define emith_add_r_r_r_lsl(d, s1, s2, lslimm) \
	EOP_ADD_REG(A_COND_AL,0,d,s1,s2,A_AM1_LSL,lslimm)
#define emith_add_r_r_r_lsl_ptr(d, s1, s2, lslimm) \
	emith_add_r_r_r_lsl(d, s1, s2, lslimm)

#define emith_adc_r_r_r_lsl(d, s1, s2, lslimm) \
	EOP_ADC_REG(A_COND_AL,0,d,s1,s2,A_AM1_LSL,lslimm)

#define emith_addf_r_r_r_lsl(d, s1, s2, lslimm) \
	EOP_ADD_REG(A_COND_AL,1,d,s1,s2,A_AM1_LSL,lslimm)
#define emith_addf_r_r_r_lsr(d, s1, s2, lslimm) \
	EOP_ADD_REG(A_COND_AL,1,d,s1,s2,A_AM1_LSR,lslimm)

#define emith_adcf_r_r_r_lsl(d, s1, s2, lslimm) \
	EOP_ADC_REG(A_COND_AL,1,d,s1,s2,A_AM1_LSL,lslimm)

#define emith_sub_r_r_r_lsl(d, s1, s2, lslimm) \
	EOP_SUB_REG(A_COND_AL,0,d,s1,s2,A_AM1_LSL,lslimm)

#define emith_sbc_r_r_r_lsl(d, s1, s2, lslimm) \
	EOP_SBC_REG(A_COND_AL,0,d,s1,s2,A_AM1_LSL,lslimm)

#define emith_subf_r_r_r_lsl(d, s1, s2, lslimm) \
	EOP_SUB_REG(A_COND_AL,1,d,s1,s2,A_AM1_LSL,lslimm)

#define emith_sbcf_r_r_r_lsl(d, s1, s2, lslimm) \
	EOP_SBC_REG(A_COND_AL,1,d,s1,s2,A_AM1_LSL,lslimm)

#define emith_or_r_r_r_lsl(d, s1, s2, lslimm) \
	EOP_ORR_REG(A_COND_AL,0,d,s1,s2,A_AM1_LSL,lslimm)
#define emith_or_r_r_r_lsr(d, s1, s2, lsrimm) \
	EOP_ORR_REG(A_COND_AL,0,d,s1,s2,A_AM1_LSR,lsrimm)

#define emith_eor_r_r_r_lsl(d, s1, s2, lslimm) \
	EOP_EOR_REG(A_COND_AL,0,d,s1,s2,A_AM1_LSL,lslimm)
#define emith_eor_r_r_r_lsr(d, s1, s2, lsrimm) \
	EOP_EOR_REG(A_COND_AL,0,d,s1,s2,A_AM1_LSR,lsrimm)

#define emith_and_r_r_r_lsl(d, s1, s2, lslimm) \
	EOP_AND_REG(A_COND_AL,0,d,s1,s2,A_AM1_LSL,lslimm)

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

#define emith_adc_r_r_r(d, s1, s2) \
	emith_adc_r_r_r_lsl(d, s1, s2, 0)

#define emith_addf_r_r_r(d, s1, s2) \
	emith_addf_r_r_r_lsl(d, s1, s2, 0)

#define emith_adcf_r_r_r(d, s1, s2) \
	emith_adcf_r_r_r_lsl(d, s1, s2, 0)

#define emith_sub_r_r_r(d, s1, s2) \
	emith_sub_r_r_r_lsl(d, s1, s2, 0)

#define emith_sbc_r_r_r(d, s1, s2) \
	emith_sbc_r_r_r_lsl(d, s1, s2, 0)

#define emith_subf_r_r_r(d, s1, s2) \
	emith_subf_r_r_r_lsl(d, s1, s2, 0)

#define emith_sbcf_r_r_r(d, s1, s2) \
	emith_sbcf_r_r_r_lsl(d, s1, s2, 0)

#define emith_or_r_r_r(d, s1, s2) \
	emith_or_r_r_r_lsl(d, s1, s2, 0)

#define emith_eor_r_r_r(d, s1, s2) \
	emith_eor_r_r_r_lsl(d, s1, s2, 0)

#define emith_and_r_r_r(d, s1, s2) \
	emith_and_r_r_r_lsl(d, s1, s2, 0)

#define emith_add_r_r(d, s) \
	emith_add_r_r_r(d, d, s)

#define emith_add_r_r_ptr(d, s) \
	emith_add_r_r_r(d, d, s)

#define emith_adc_r_r(d, s) \
	emith_adc_r_r_r(d, d, s)

#define emith_sub_r_r(d, s) \
	emith_sub_r_r_r(d, d, s)

#define emith_sbc_r_r(d, s) \
	emith_sbc_r_r_r(d, d, s)

#define emith_negc_r_r(d, s) \
	EOP_C_DOP_IMM(A_COND_AL,A_OP_RSC,0,s,d,0,0)

#define emith_and_r_r_c(cond, d, s) \
	EOP_AND_REG(cond,0,d,d,s,A_AM1_LSL,0)
#define emith_and_r_r(d, s) \
	EOP_AND_REG(A_COND_AL,0,d,d,s,A_AM1_LSL,0)

#define emith_or_r_r(d, s) \
	emith_or_r_r_r(d, d, s)

#define emith_eor_r_r(d, s) \
	emith_eor_r_r_r(d, d, s)

#define emith_tst_r_r(d, s) \
	EOP_TST_REG(A_COND_AL,d,s,A_AM1_LSL,0)

#define emith_tst_r_r_ptr(d, s) \
	emith_tst_r_r(d, s)

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

#define emith_move_r_ptr_imm(r, imm) \
	emith_move_r_imm(r, (u32)(imm))

#define emith_add_r_imm(r, imm) \
	emith_op_imm(A_COND_AL, 0, A_OP_ADD, r, imm)

#define emith_adc_r_imm(r, imm) \
	emith_op_imm(A_COND_AL, 0, A_OP_ADC, r, imm)

#define emith_adcf_r_imm(r, imm) \
	emith_op_imm(A_COND_AL, 1, A_OP_ADC, r, imm)

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

#define emith_eor_r_imm_ptr(r, imm) \
	emith_eor_r_imm(r, imm)

// note: only use 8bit imm for these
#define emith_tst_r_imm(r, imm) \
	emith_top_imm(A_COND_AL, A_OP_TST, r, imm)

#define emith_cmp_r_imm(r, imm) do { \
	u32 op_ = A_OP_CMP, imm_ = (u8)imm; \
	if ((s8)imm_ < 0) { \
		imm_ = (u8)-imm_; \
		op_ = A_OP_CMN; \
	} \
	emith_top_imm(A_COND_AL, op_, r, imm_); \
} while (0)

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

#define emith_eor_r_imm_ptr_c(cond, r, imm) \
	emith_eor_r_imm_c(cond, r, imm)

#define emith_bic_r_imm_c(cond, r, imm) \
	emith_op_imm(cond, 0, A_OP_BIC, r, imm)

#define emith_tst_r_imm_c(cond, r, imm) \
	emith_top_imm(cond, A_OP_TST, r, imm)

#define emith_move_r_imm_s8_patchable(r, imm) do { \
	emith_flush(); /* pin insn at current tcache_ptr for patching */ \
	if ((s8)(imm) < 0) \
		EOP_MVN_IMM(r, 0, (u8)~(imm)); \
	else \
		EOP_MOV_IMM(r, 0, (u8)(imm)); \
} while (0)
#define emith_move_r_imm_s8_patch(ptr, imm) do { \
	u32 *ptr_ = (u32 *)ptr; u32 op_ = *ptr_ & 0xfe1ff000; \
	if ((s8)(imm) < 0) \
		EMIT_PTR(ptr_, op_ | (A_OP_MVN<<21) | (u8)~(imm));\
	else \
		EMIT_PTR(ptr_, op_ | (A_OP_MOV<<21) | (u8)(imm));\
} while (0)

#define emith_and_r_r_imm(d, s, imm) \
	emith_op_imm2(A_COND_AL, 0, A_OP_AND, d, s, imm)

#define emith_add_r_r_imm(d, s, imm) \
	emith_op_imm2(A_COND_AL, 0, A_OP_ADD, d, s, imm)

#define emith_add_r_r_ptr_imm(d, s, imm) \
	emith_add_r_r_imm(d, s, imm)

#define emith_sub_r_r_imm_c(cond, d, s, imm) \
	emith_op_imm2(cond, 0, A_OP_SUB, d, s, (imm))

#define emith_sub_r_r_imm(d, s, imm) \
	emith_op_imm2(A_COND_AL, 0, A_OP_SUB, d, s, imm)

#define emith_subf_r_r_imm(d, s, imm) \
	emith_op_imm2(A_COND_AL, 1, A_OP_SUB, d, s, imm)

#define emith_or_r_r_imm(d, s, imm) \
	emith_op_imm2(A_COND_AL, 0, A_OP_ORR, d, s, imm)

#define emith_eor_r_r_imm(d, s, imm) \
	emith_op_imm2(A_COND_AL, 0, A_OP_EOR, d, s, imm)

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
#define emith_rolf(d, s, cnt) do { \
	EOP_MOV_REG(A_COND_AL,1,d,s,A_AM1_ROR,32-(cnt)); \
	/* we don't have ROL so we shift to get the right carry */ \
	EOP_TST_REG(A_COND_AL,d,d,A_AM1_LSR,1); \
} while (0)

#define emith_rorf(d, s, cnt) \
	EOP_MOV_REG(A_COND_AL,1,d,s,A_AM1_ROR,cnt)

#define emith_rolcf(d) \
	emith_adcf_r_r(d, d)
#define emith_rolc(d) \
	emith_adc_r_r(d, d)

#define emith_rorcf(d) \
	EOP_MOV_REG(A_COND_AL,1,d,d,A_AM1_ROR,0) /* ROR #0 -> RRX */
#define emith_rorc(d) \
	EOP_MOV_REG(A_COND_AL,0,d,d,A_AM1_ROR,0) /* ROR #0 -> RRX */

#define emith_negcf_r_r(d, s) \
	EOP_C_DOP_IMM(A_COND_AL,A_OP_RSC,1,s,d,0,0)

#define emith_mul(d, s1, s2) do { \
	if ((d) != (s1)) /* rd != rm limitation */ \
		EOP_MUL(d, s1, s2); \
	else \
		EOP_MUL(d, s2, s1); \
} while (0)

#define emith_mul_u64(dlo, dhi, s1, s2) \
	EOP_C_UMULL(A_COND_AL,0,dhi,dlo,s1,s2)

#define emith_mul_s64(dlo, dhi, s1, s2) \
	EOP_C_SMULL(A_COND_AL,0,dhi,dlo,s1,s2)

#define emith_mula_s64_c(cond, dlo, dhi, s1, s2) \
	EOP_C_SMLAL(cond,0,dhi,dlo,s1,s2)
#define emith_mula_s64(dlo, dhi, s1, s2) \
	EOP_C_SMLAL(A_COND_AL,0,dhi,dlo,s1,s2)

// misc
#define emith_read_r_r_offs_c(cond, r, rs, offs) \
	EOP_LDR_IMM2(cond, r, rs, offs)
#define emith_read_r_r_offs_ptr_c(cond, r, rs, offs) \
	emith_read_r_r_offs_c(cond, r, rs, offs)
#define emith_read_r_r_r_c(cond, r, rs, rm) \
	EOP_LDR_REG_LSL(cond, r, rs, rm, 0)
#define emith_read_r_r_offs(r, rs, offs) \
	emith_read_r_r_offs_c(A_COND_AL, r, rs, offs)
#define emith_read_r_r_offs_ptr(r, rs, offs) \
	emith_read_r_r_offs_c(A_COND_AL, r, rs, offs)
#define emith_read_r_r_r(r, rs, rm) \
	EOP_LDR_REG_LSL(A_COND_AL, r, rs, rm, 0)

#define emith_read8_r_r_offs_c(cond, r, rs, offs) \
	EOP_LDRB_IMM2(cond, r, rs, offs)
#define emith_read8_r_r_r_c(cond, r, rs, rm) \
	EOP_LDRB_REG_LSL(cond, r, rs, rm, 0)
#define emith_read8_r_r_offs(r, rs, offs) \
	emith_read8_r_r_offs_c(A_COND_AL, r, rs, offs)
#define emith_read8_r_r_r(r, rs, rm) \
	emith_read8_r_r_r_c(A_COND_AL, r, rs, rm)

#define emith_read16_r_r_offs_c(cond, r, rs, offs) \
	EOP_LDRH_IMM2(cond, r, rs, offs)
#define emith_read16_r_r_r_c(cond, r, rs, rm) \
	EOP_LDRH_REG2(cond, r, rs, rm)
#define emith_read16_r_r_offs(r, rs, offs) \
	emith_read16_r_r_offs_c(A_COND_AL, r, rs, offs)
#define emith_read16_r_r_r(r, rs, rm) \
	emith_read16_r_r_r_c(A_COND_AL, r, rs, rm)

#define emith_read8s_r_r_offs_c(cond, r, rs, offs) \
	EOP_LDRSB_IMM2(cond, r, rs, offs)
#define emith_read8s_r_r_r_c(cond, r, rs, rm) \
	EOP_LDRSB_REG2(cond, r, rs, rm)
#define emith_read8s_r_r_offs(r, rs, offs) \
	emith_read8s_r_r_offs_c(A_COND_AL, r, rs, offs)
#define emith_read8s_r_r_r(r, rs, rm) \
	emith_read8s_r_r_r_c(A_COND_AL, r, rs, rm)

#define emith_read16s_r_r_offs_c(cond, r, rs, offs) \
	EOP_LDRSH_IMM2(cond, r, rs, offs)
#define emith_read16s_r_r_r_c(cond, r, rs, rm) \
	EOP_LDRSH_REG2(cond, r, rs, rm)
#define emith_read16s_r_r_offs(r, rs, offs) \
	emith_read16s_r_r_offs_c(A_COND_AL, r, rs, offs)
#define emith_read16s_r_r_r(r, rs, rm) \
	emith_read16s_r_r_r_c(A_COND_AL, r, rs, rm)

#define emith_write_r_r_offs_c(cond, r, rs, offs) \
	EOP_STR_IMM2(cond, r, rs, offs)
#define emith_write_r_r_offs_ptr_c(cond, r, rs, offs) \
	emith_write_r_r_offs_c(cond, r, rs, offs)
#define emith_write_r_r_offs(r, rs, offs) \
	emith_write_r_r_offs_c(A_COND_AL, r, rs, offs)
#define emith_write_r_r_offs_ptr(r, rs, offs) \
	emith_write_r_r_offs_c(A_COND_AL, r, rs, offs)

#define emith_ctx_read_c(cond, r, offs) \
	emith_read_r_r_offs_c(cond, r, CONTEXT_REG, offs)
#define emith_ctx_read(r, offs) \
	emith_ctx_read_c(A_COND_AL, r, offs)

#define emith_ctx_read_ptr(r, offs) \
	emith_ctx_read(r, offs)

#define emith_ctx_write(r, offs) \
	EOP_STR_IMM(r, CONTEXT_REG, offs)

#define emith_ctx_do_multiple(op, r, offs, count, tmpr) do { \
	int v_, r_ = r, c_ = count, b_ = CONTEXT_REG;        \
	for (v_ = 0; c_; c_--, r_++)                         \
		v_ |= M1(r_);                                \
	if ((offs) != 0) {                                   \
		EOP_ADD_IMM(tmpr,CONTEXT_REG,30/2,(offs)>>2);\
		b_ = tmpr;                                   \
	}                                                    \
	op(b_,v_);                                           \
} while (0)

#define emith_ctx_read_multiple(r, offs, count, tmpr) \
	emith_ctx_do_multiple(EOP_LDMIA, r, offs, count, tmpr)

#define emith_ctx_write_multiple(r, offs, count, tmpr) \
	emith_ctx_do_multiple(EOP_STMIA, r, offs, count, tmpr)

#define emith_clear_msb_c(cond, d, s, count) do { \
	u32 t; \
	if ((count) <= 8) { \
		t = 8 - (count); \
		t = (0xff << t) & 0xff; \
		EOP_C_DOP_IMM(cond,A_OP_BIC,0,s,d,8/2,t); \
	} else if ((count) >= 24) { \
		t = (count) - 24; \
		t = 0xff >> t; \
		EOP_C_DOP_IMM(cond,A_OP_AND,0,s,d,0,t); \
	} else { \
		EOP_MOV_REG(cond,0,d,s,A_AM1_LSL,count); \
		EOP_MOV_REG(cond,0,d,d,A_AM1_LSR,count); \
	} \
} while (0)

#define emith_clear_msb(d, s, count) \
	emith_clear_msb_c(A_COND_AL, d, s, count)

#define emith_sext(d, s, bits) do { \
	EOP_MOV_REG_LSL(d,s,32 - (bits)); \
	EOP_MOV_REG_ASR(d,d,32 - (bits)); \
} while (0)

#define emith_uext_ptr(r)	/**/

#define emith_do_caller_regs(mask, func) do { \
	u32 _reg_mask = (mask) & 0x500f; \
	if (_reg_mask) { \
		if (__builtin_parity(_reg_mask) == 1) \
			_reg_mask |= 0x10; /* eabi align */ \
		func(_reg_mask); \
	} \
} while (0)

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
#define emith_jump_cond_inrange(target) !0

#define emith_jump_cond_patchable(cond, target) \
	emith_jump_cond(cond, target)

#define emith_jump_patch(ptr, target, pos) do { \
	u32 *ptr_ = (u32 *)ptr; \
	u32 val_ = (u32 *)(target) - ptr_ - 2; \
	*ptr_ = (*ptr_ & 0xff000000) | (val_ & 0x00ffffff); \
	if ((void *)(pos) != NULL) *(u8 **)(pos) = (u8 *)ptr; \
} while (0)
#define emith_jump_patch_inrange(ptr, target) !0
#define emith_jump_patch_size() 4

#define emith_jump_at(ptr, target) do { \
	u32 *ptr_ = (u32 *)ptr; \
	u32 val_ = (u32 *)(target) - ptr_ - 2; \
	EOP_C_B_PTR(ptr_, A_COND_AL, 0, val_ & 0xffffff); \
} while (0)
#define emith_jump_at_size() 4

#define emith_jump_reg_c(cond, r) \
	EOP_C_BX(cond, r)

#define emith_jump_reg(r) \
	emith_jump_reg_c(A_COND_AL, r)

#define emith_jump_ctx_c(cond, offs) \
	EOP_LDR_IMM2(cond,PC,CONTEXT_REG,offs)

#define emith_jump_ctx(offs) \
	emith_jump_ctx_c(A_COND_AL, offs)

#define emith_call_cond(cond, target) \
	emith_xbranch(cond, target, 1)

#define emith_call(target) \
	emith_call_cond(A_COND_AL, target)

#define emith_call_reg(r) do { \
        emith_move_r_r(LR, PC); \
        EOP_C_BX(A_COND_AL, r); \
} while (0)

#define emith_abicall_ctx(offs) do { \
	emith_move_r_r(LR, PC); \
	emith_jump_ctx(offs); \
} while (0)

#define emith_abijump_reg(r) \
	emith_jump_reg(r)
#define emith_abijump_reg_c(cond, r) \
	emith_jump_reg_c(cond, r)
#define emith_abicall(target) \
	emith_call(target)
#define emith_abicall_cond(cond, target) \
	emith_call_cond(cond, target)
#define emith_abicall_reg(r) \
	emith_call_reg(r)

#define emith_call_cleanup()	/**/

#define emith_ret_c(cond) \
	emith_jump_reg_c(cond, LR)

#define emith_ret() \
	emith_ret_c(A_COND_AL)

#define emith_ret_to_ctx(offs) \
	emith_ctx_write(LR, offs)

#define emith_add_r_ret(r) \
	emith_add_r_r_ptr(r, LR)

/* pushes r12 for eabi alignment */
#define emith_push_ret(r) do { \
	int r_ = (r >= 0 ? r : 12); \
	EOP_STMFD_SP(M2(r_,LR)); \
} while (0)

#define emith_pop_and_ret(r) do { \
	int r_ = (r >= 0 ? r : 12); \
	EOP_LDMFD_SP(M2(r_,PC)); \
} while (0)

#define host_instructions_updated(base, end, force) \
	do { if (force) emith_update_add(base, end); } while (0)

#define host_call(addr, args) \
	addr

#define host_arg2reg(rd, arg) \
	rd = arg

#define emith_rw_offs_max()	0x1ff	// minimum of offset in AM2 and AM3

/* SH2 drc specific */
/* pushes r12 for eabi alignment */
#define emith_sh2_drc_entry() \
	EOP_STMFD_SP(M10(4,5,6,7,8,9,10,11,12,LR))

#define emith_sh2_drc_exit() \
	EOP_LDMFD_SP(M10(4,5,6,7,8,9,10,11,12,PC))

// assumes a is in arg0, tab, func and mask are temp
#define emith_sh2_rcall(a, tab, func, mask) do { \
	emith_lsr(mask, a, SH2_READ_SHIFT); \
	EOP_ADD_REG_LSL(tab, tab, mask, 3); \
	if (func < mask) EOP_LDMIA(tab, M2(func,mask)); /* ldm if possible */ \
	else {	emith_read_r_r_offs(func, tab, 0); \
		emith_read_r_r_offs(mask, tab, 4); } \
	emith_addf_r_r_r(func,func,func); \
} while (0)

// assumes a, val are in arg0 and arg1, tab and func are temp
#define emith_sh2_wcall(a, val, tab, func) do { \
	emith_lsr(func, a, SH2_WRITE_SHIFT); \
	EOP_LDR_REG_LSL(A_COND_AL,func,tab,func,2); \
	emith_move_r_r(2, CONTEXT_REG); /* arg2 */ \
	emith_abijump_reg(func); \
} while (0)

#define emith_sh2_dtbf_loop() do { \
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
		emith_sub_r_r_imm_c(DCOND_LS, t2, t3, 1);	\
		/* if (reg <= 1) turns = 0 */			\
		emith_cmp_r_imm(t3, 1);				\
		emith_move_r_imm_c(DCOND_LS, t2, 0);		\
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

#define emith_write_sr(sr, srcr) do { \
	emith_lsr(sr, sr, 10); \
	emith_or_r_r_r_lsl(sr, sr, srcr, 22); \
	emith_ror(sr, sr, 22); \
} while (0)

#define emith_carry_to_t(srr, is_sub) do { \
	emith_bic_r_imm(srr, 1); \
	if (is_sub) /* has inverted C on ARM */ \
		emith_or_r_imm_c(A_COND_CC, srr, 1); \
	else \
		emith_or_r_imm_c(A_COND_CS, srr, 1); \
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
	emith_lsrf(sr, sr, 1);          \
} while (0)

#define emith_tpush_carry(sr, is_sub) do { \
	emith_adc_r_r(sr, sr);          \
	if (is_sub)                     \
		emith_eor_r_imm(sr, 1); \
} while (0)

/*
 * T = carry(Rn = (Rn << 1) | T)
 * if Q
 *   T ^= !carry(Rn += Rm)
 * else
 *   T ^= !carry(Rn -= Rm)
 */
#define emith_sh2_div1_step(rn, rm, sr) do {      \
	void *jmp0, *jmp1;                        \
	emith_tpop_carry(sr, 0); /* Rn = 2*Rn+T */\
	emith_adcf_r_r_r(rn, rn, rn);             \
	emith_tpush_carry(sr, 0);                 \
	emith_tst_r_imm(sr, Q);  /* if (Q ^ M) */ \
	JMP_POS(jmp0);           /* beq do_sub */ \
	emith_addf_r_r(rn, rm);  /* Rn += Rm */   \
	emith_eor_r_imm_c(A_COND_CC, sr, T);      \
	JMP_POS(jmp1);           /* b done */     \
	JMP_EMIT(A_COND_EQ, jmp0); /* do_sub: */  \
	emith_subf_r_r(rn, rm);  /* Rn -= Rm */   \
	emith_eor_r_imm_c(A_COND_CS, sr, T);      \
	JMP_EMIT(A_COND_AL, jmp1); /* done: */    \
} while (0)

/* mh:ml += rn*rm, does saturation if required by S bit. rn, rm must be TEMP */
#define emith_sh2_macl(ml, mh, rn, rm, sr) do {   \
	emith_tst_r_imm(sr, S);                   \
	EMITH_SJMP2_START(DCOND_NE);              \
	emith_mula_s64_c(DCOND_EQ, ml, mh, rn, rm); \
	EMITH_SJMP2_MID(DCOND_NE);                \
	/* MACH top 16 bits unused if saturated. sign ext for overfl detect */ \
	emith_sext(mh, mh, 16);                   \
	emith_mula_s64(ml, mh, rn, rm);           \
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
	EMITH_SJMP2_END(DCOND_NE);                \
} while (0)

/* mh:ml += rn*rm, does saturation if required by S bit. rn, rm must be TEMP */
#define emith_sh2_macw(ml, mh, rn, rm, sr) do {   \
	emith_tst_r_imm(sr, S);                   \
	EMITH_SJMP2_START(DCOND_NE);              \
	emith_mula_s64_c(DCOND_EQ, ml, mh, rn, rm); \
	EMITH_SJMP2_MID(DCOND_NE);                \
	/* XXX: MACH should be untouched when S is set? */ \
	emith_asr(mh, ml, 31); /* sign ext MACL to MACH for ovrfl check */ \
	emith_mula_s64(ml, mh, rn, rm);           \
	/* overflow if top 33 bits of MACH:MACL aren't all 1 or 0 */ \
	/* to check: add MACL[31] to MACH. this is 0 if no overflow */ \
	emith_addf_r_r_r_lsr(mh, mh, ml, 31); /* sum = MACH + ((MACL>>31)&1) */\
	EMITH_SJMP_START(DCOND_EQ); /* sum != 0 -> overflow */ \
	/* XXX: LSB signalling only in SH1, or in SH2 too? */ \
	emith_move_r_imm_c(DCOND_NE, mh, 0x00000001); /* LSB of MACH */ \
	emith_move_r_imm_c(DCOND_NE, ml, 0x80000000); /* -ovrfl */ \
	EMITH_SJMP_START(DCOND_MI); /* sum > 0 -> +ovrfl */ \
	emith_sub_r_imm_c(DCOND_PL, ml, 1); /* 0x7fffffff */ \
	EMITH_SJMP_END(DCOND_MI);                 \
	EMITH_SJMP_END(DCOND_EQ);                 \
	EMITH_SJMP2_END(DCOND_NE);                \
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
	tcond = ((val) ? A_COND_AL: A_COND_NV)

static void emith_sync_t(int sr)
{
	if (tcond == A_COND_AL)
		emith_or_r_imm(sr, T);
	else if (tcond == A_COND_NV)
		emith_bic_r_imm(sr, T);
	else if (tcond >= 0) {
		emith_bic_r_imm(sr, T);
		emith_or_r_imm_c(tcond, sr, T);
	}
	tcond = -1;
}

static int emith_tst_t(int sr, int tf)
{
	if (tcond < 0) {
		emith_tst_r_imm(sr, T);
		return tf ? DCOND_NE: DCOND_EQ;
	} else if (tcond >= A_COND_AL) {
		// MUST sync because A_COND_NV isn't a real condition
		emith_sync_t(sr);
		emith_tst_r_imm(sr, T);
		return tf ? DCOND_NE: DCOND_EQ;
	} else
		return tf ? tcond : emith_invert_cond(tcond);
}
#endif
