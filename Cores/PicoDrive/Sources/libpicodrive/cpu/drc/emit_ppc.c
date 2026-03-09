/*
 * Basic macros to emit PowerISA 2.03 64 bit instructions and some utils
 * Copyright (C) 2020-2024 irixxxx
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

// NB bit numbers are reversed in PPC (MSB is bit 0). The emith_* functions and
// macros must take this into account.

// NB PPC was a 64 bit architecture from the onset, so basically all operations
// are operating on 64 bits. 32 bit arch was only added later on, and there are
// very few 32 bit operations (cmp*, shift/rotate, extract/insert, load/store).
// For most operations the upper bits don't spill into the lower word, for the
// others there is an appropriate 32 bit operation available.

// NB PowerPC isn't a clean RISC design. Several insns use microcode, which is
// AFAIK notably slower than using some 2-3 non-microcode insns. So, using
// such insns should by avoided if possible. Listed in Cell handbook, App. A:
//	- shift/rotate having the amount in a register
//	- arithmetic/logical having the RC flag set (except cmp*)
//	- load/store algebraic (l?a*), multiple (lmw/stmw), string (ls*/sts*)
//	- mtcrf (and some more SPR related, not used here)
// moreover, misaligned load/store crossing a cacheline boundary are microcoded.
// Note also that load/store string isn't available in little endian mode.

// NB flag handling in PPC differs grossly from the ARM/X86 model. There are 8
// fields in the condition register, each having 4 condition bits. However, only
// the EQ bit is similar to the Z flag. The CA and OV bits in the XER register
// are similar to the C and V bits, but shifts don't use CA, and cmp* doesn't
// use CA and OV.
// Moreover, there's no easy possibility to get CA and OV for 32 bit arithmetic
// since all arithmetic/logical insns use 64 bit.
// For now, use the "no flags" code from the RISC-V backend.

#define HOST_REGS	32

// PPC64: params: r3-r10, return: r3, temp: r0,r11-r12, saved: r14-r31
// reserved: r0(zero), r1(stack), r2(TOC), r13(TID)
// additionally reserved on OSX: r31(PIC), r30(frame), r11(parentframe)
// for OSX PIC code, on function calls r12 must contain the called address
#define TOC_REG		2
#define RET_REG		3
#define PARAM_REGS	{ 3, 4, 5, 6, 7, 8, 9, 10 }
#define PRESERVED_REGS	{ 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29 }
#define TEMPORARY_REGS	{ 12 }

#define CONTEXT_REG	29
#define STATIC_SH2_REGS	{ SHR_SR,28 , SHR_R(0),27 , SHR_R(1),26 }

// if RA is 0 in non-update memory insns, ADDI/ADDIS, ISEL, it aliases with zero
#define Z0		0  // zero register
#define SP		1  // stack pointer
#define CR		12 // call register
// SPR registers
#define XER		-1 // exception register
#define LR		-8 // link register
#define CTR		-9 // counter register
// internally used by code emitter:
#define AT		0  // emitter temporary (can't be fully used anyway)
#define FNZ		14 // emulated processor flags: N (bit 31) ,Z (all bits)
#define FC		15 // emulated processor flags: C (bit 0), others 0
#define FV		16 // emulated processor flags: Nt^Ns (bit 31). others x


// unified conditions; virtual, not corresponding to anything real on PPC
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

// unified insn; use right-aligned bit offsets for the bitfields
#define PPC_INSN(op, b10, b15, b20, b31) \
	(((op)<<26)|((b10)<<21)|((b15)<<16)|((b20)<<11)|((b31)<<0))

#define _		0 // marker for "field unused"
#define __(n)		o##n // enum marker for "undefined"
#define _CB(v,l,s,d)	((((v)>>(s))&((1<<(l))-1))<<(d)) // copy l bits

// NB everything privileged or unneeded at 1st sight is left out
// opcode field (encoded in OPCD, bits 0-5)
enum { OP__LMA=004, OP_MULLI=007,
  OP_SUBFIC, __(11), OP_CMPLI, OP_CMPI, OP_ADDIC, OP_ADDICF, OP_ADDI, OP_ADDIS,
  OP_BC, __(21), OP_B, OP__CR, OP_RLWIMI, OP_RLWINM, __(26), OP_RLWNM,
  OP_ORI, OP_ORIS, OP_XORI, OP_XORIS, OP_ANDI, OP_ANDIS, OP__RLD, OP__EXT,
  OP_LWZ, OP_LWZU, OP_LBZ, OP_LBZU, OP_STW, OP_STWU, OP_STB, OP_STBU,
  OP_LHZ, OP_LHZU, OP_LHA, OP_LHAU, OP_STH, OP_STHU, OP_LMW, OP_STMW,
  /*OP_LQ=070,*/ OP__LD=072, OP__ST=076 };
// CR subops (encoded in bits 21-31)
enum { OPC_MCRF=0, OPC_BCLR=32, OPC_BCCTR=1056 };
// RLD subops (encoded in XO bits 27-31)
enum { OPR_RLDICL=0, OPR_RLDICR=4, OPR_RLDIC=8, OPR_RLDIMI=12, OPR_RLDCL=16, OPR_RLDCR=18 };
// EXT subops (encoded in XO bits 21-31)
enum {
  // arith/logical
  OPE_CMP=0, OPE_SUBFC=16, OPE_ADDC=20, OPE_AND=56,
  OPE_CMPL=64, OPE_SUBF=80, OPE_ANDC=120, OPE_NEG=208, OPE_NOR=248,
  OPE_SUBFE=272, OPE_ADDE=276, OPE_SUBFZE=400, OPE_ADDZE=404, OPE_SUBFME=464, OPE_ADDME=468,
  OPE_ADD=532, OPE_EQV=568, OPE_XOR=632, OPE_ORC=824, OPE_OR=888, OPE_NAND=952,
  // shift
  OPE_SLW=48, OPE_SLD=54, OPE_SRW=1072, OPE_SRD=1078, OPE_SRAW=1584, OPE_SRAD=1588, OPE_SRAWI=1648, OPE_SRADI=1652,
  // extend, bitcount
  OPE_CNTLZW=52, OPE_CNTLZD=116, OPE_EXTSH=1844, OPE_EXTSB=1908, OPE_EXTSW=1972,
  // mult/div
  OPE_MULHDU=18, OPE_MULHWU=22, OPE_MULHD=146, OPE_MULHW=150, OPE_MULLD=466, OPE_MULLW=470,
  OPE_DIVDU=914, OPE_DIVWU=918, OPE_DIVD=978, OPE_DIVW=982,
  // load/store indexed
  OPE_LDX=42, OPE_LDUX=106, OPE_STDX=298, OPE_STDUX=362,
  OPE_LWZX=46, OPE_LWZUX=110, OPE_LWAX=682, OPE_LWAUX=746, OPE_STWX=302, OPE_STWUX=366,
  OPE_LBZX=174, OPE_LBZUX=238, /*   no LBAX/LBAUX...   */  OPE_STBX=430, OPE_STBUX=494,
  OPE_LHZX=558, OPE_LHZUX=622, OPE_LHAX=686, OPE_LHAUX=750, OPE_STHX=814, OPE_STHUX=878,
  // SPR, CR related
  OPE_ISEL=15, OPE_MFCR=38, OPE_MTCRF=288, OPE_MFSPR=678, OPE_MTSPR=934, OPE_MCRXR=1024, 
};
// LD subops (encoded in XO bits 30-31)
enum { OPL_LD, OPL_LDU, OPL_LWA };
// ST subops (encoded in XO bits 30-31)
enum { OPS_STD, OPS_STDU /*,OPS_STQ*/ };

// X*,M*-forms insns often have overflow detect in b21 and CR0 update in b31
#define XOE	(1<<10)	// (31-21)
#define XRC	(1<<0)	// (31-31)
#define XF	(XOE|XRC)
// MB and ME in M*-forms rotate left
#define MM(b,e)	(((b)<<6)|((e)<<1))
#define MD(b,s)	(_CB(b,5,0,6)|_CB(b,1,5,5)|_CB(s,5,0,11)|_CB(s,1,5,1))
// AA and LK in I,B-forms branches
#define BAA	(1<<1)
#define BLK	(1<<0)
// BO and BI condition codes in B-form, BO0-BO4:BI2-BI4 since we only need CR0
#define BLT	0x60
#define BGE	0x20
#define BGT	0x61
#define BLE	0x21
#define BEQ	0x62
#define BNE	0x22
#define BXX	0xa0	// unconditional, aka always

#define PPC_NOP \
	PPC_INSN(OP_ORI, 0, 0, _, 0) // ori r0, r0, 0

// arithmetic/logical

#define PPC_OP_REG(op, xop, rt, ra, rb) /* X*,M*-form */ \
	PPC_INSN((unsigned)op, rt, ra, rb, xop)
#define PPC_OP_IMM(op, rt, ra, imm) /* D,B,I-form */ \
	PPC_INSN((unsigned)op, rt, ra, _, imm)

// rt = ra OP rb
#define PPC_ADD_REG(rt, ra, rb) \
	PPC_OP_REG(OP__EXT,OPE_ADD,rt,ra,rb)
#define PPC_ADDC_REG(rt, ra, rb) \
	PPC_OP_REG(OP__EXT,OPE_ADDC,rt,ra,rb)
#define PPC_SUB_REG(rt, rb, ra) /* NB reversed args (rb-ra) */ \
	PPC_OP_REG(OP__EXT,OPE_SUBF,rt,ra,rb)
#define PPC_SUBC_REG(rt, rb, ra) \
	PPC_OP_REG(OP__EXT,OPE_SUBFC,rt,ra,rb)
#define PPC_NEG_REG(rt, ra) \
	PPC_OP_REG(OP__EXT,OPE_NEG,rt,ra,_)

#define PPC_CMP_REG(ra, rb) \
	PPC_OP_REG(OP__EXT,OPE_CMP,1,ra,rb)
#define PPC_CMPL_REG(ra, rb) \
	PPC_OP_REG(OP__EXT,OPE_CMPL,1,ra,rb)

#define PPC_CMPW_REG(ra, rb) \
	PPC_OP_REG(OP__EXT,OPE_CMP,0,ra,rb)
#define PPC_CMPLW_REG(ra, rb) \
	PPC_OP_REG(OP__EXT,OPE_CMPL,0,ra,rb)

#define PPC_XOR_REG(ra, rt, rb) \
	PPC_OP_REG(OP__EXT,OPE_XOR,rt,ra,rb)
#define PPC_OR_REG(ra, rt, rb) \
	PPC_OP_REG(OP__EXT,OPE_OR,rt,ra,rb)
#define PPC_ORN_REG(ra, rt, rb) \
	PPC_OP_REG(OP__EXT,OPE_ORC,rt,ra,rb)
#define PPC_NOR_REG(ra, rt, rb) \
	PPC_OP_REG(OP__EXT,OPE_NOR,rt,ra,rb)
#define PPC_AND_REG(ra, rt, rb) \
	PPC_OP_REG(OP__EXT,OPE_AND,rt,ra,rb)
#define PPC_BIC_REG(ra, rt, rb) \
	PPC_OP_REG(OP__EXT,OPE_ANDC,rt,ra,rb)

#define PPC_MOV_REG(rt, ra) \
	PPC_OR_REG(rt, ra, ra)
#define PPC_MVN_REG(rt, ra) \
	PPC_NOR_REG(rt, ra, ra)

// rt = ra OP rb OP carry
#define PPC_ADC_REG(rt, ra, rb) \
	PPC_OP_REG(OP__EXT,OPE_ADDE,rt,ra,rb)
#define PPC_SBC_REG(rt, rb, ra) \
	PPC_OP_REG(OP__EXT,OPE_SUBFE,rt,ra,rb)
#define PPC_NGC_REG(rt, ra) \
	PPC_OP_REG(OP__EXT,OPE_SUBFZE,rt,ra,_)

// rt = ra SHIFT rb
#define PPC_LSL_REG(ra, rt, rb) \
	PPC_OP_REG(OP__EXT,OPE_SLD,rt,ra,rb)
#define PPC_LSR_REG(ra, rt, rb) \
	PPC_OP_REG(OP__EXT,OPE_SRD,rt,ra,rb)
#define PPC_ASR_REG(ra, rt, rb) \
	PPC_OP_REG(OP__EXT,OPE_SRAD,rt,ra,rb)
#define PPC_ROL_REG(ra, rt, rb) \
	PPC_OP_REG(OP__RLD,OPR_RLDCL,rt,ra,rb,0)

#define PPC_LSLW_REG(ra, rt, rb) \
	PPC_OP_REG(OP__EXT,OPE_SLW,rt,ra,rb)
#define PPC_LSRW_REG(ra, rt, rb) \
	PPC_OP_REG(OP__EXT,OPE_SRW,rt,ra,rb)
#define PPC_ASRW_REG(ra, rt, rb) \
	PPC_OP_REG(OP__EXT,OPE_SRAW,rt,ra,rb)
#define PPC_ROLW_REG(ra, rt, rb) \
	PPC_OP_REG(OP_RLWNM,MM(0,31),rt,ra,rb)

// rt = ra OP (imm16 << (0|16))
#define PPC_ADD_IMM(rt, ra, imm16) \
	PPC_OP_IMM(OP_ADDI, rt, ra, imm16)
#define PPC_ADDT_IMM(rt, ra, imm16) \
	PPC_OP_IMM(OP_ADDIS, rt, ra, imm16)

#define PPC_XOR_IMM(ra, rt, imm16) \
	PPC_OP_IMM(OP_XORI, rt, ra, imm16)
#define PPC_XORT_IMM(ra, rt, imm16) \
	PPC_OP_IMM(OP_XORIS, rt, ra, imm16)
#define PPC_OR_IMM(ra, rt, imm16) \
	PPC_OP_IMM(OP_ORI, rt, ra, imm16)
#define PPC_ORT_IMM(ra, rt, imm16) \
	PPC_OP_IMM(OP_ORIS, rt, ra, imm16)

#define PPC_ANDS_IMM(rt, ra, imm16) \
	PPC_OP_IMM(OP_ANDI, rt, ra, imm16)
#define PPC_ANDTS_IMM(rt, ra, imm16) \
	PPC_OP_IMM(OP_ANDIS, rt, ra, imm16)
#define PPC_CMP_IMM(ra, imm16) \
	PPC_OP_IMM(OP_CMPI, 1, ra, imm16)
#define PPC_CMPL_IMM(ra, imm16) \
	PPC_OP_IMM(OP_CMPLI, 1, ra, imm16)

#define PPC_CMPW_IMM(ra, imm16) \
	PPC_OP_IMM(OP_CMPI, 0, ra, imm16)
#define PPC_CMPLW_IMM(ra, imm16) \
	PPC_OP_IMM(OP_CMPLI, 0, ra, imm16)

#define PPC_TST_IMM(rt, imm16) \
	PPC_ANDS_IMM(Z0,ra,imm16)

#define PPC_MOV_IMM(rt, ra, imm16) \
	PPC_ADD_IMM(rt,ra,imm16)
#define PPC_MOVT_IMM(rt, ra, imm16) \
	PPC_ADDT_IMM(rt,ra,imm16)

// rt = EXTEND ra
#define PPC_EXTSW_REG(ra, rt) \
	PPC_OP_REG(OP__EXT,OPE_EXTSW,rt,ra,_)
#define PPC_EXTSH_REG(ra, rt) \
	PPC_OP_REG(OP__EXT,OPE_EXTSH,rt,ra,_)
#define PPC_EXTSB_REG(ra, rt) \
	PPC_OP_REG(OP__EXT,OPE_EXTSB,rt,ra,_)
#define PPC_EXTUW_REG(ra, rt) \
	PPC_OP_REG(OP__RLD,OPR_RLDICL|MD(32,0),rt,ra,_)
#define PPC_EXTUH_REG(ra, rt) \
	PPC_OP_REG(OP__RLD,OPR_RLDICL|MD(48,0),rt,ra,_)
#define PPC_EXTUB_REG(ra, rt) \
	PPC_OP_REG(OP__RLD,OPR_RLDICL|MD(56,0),rt,ra,_)

// rt = ra SHIFT imm5/imm6
#define PPC_LSL_IMM(ra, rt, bits) \
	PPC_OP_REG(OP__RLD,OPR_RLDICR|MD(63-(bits),bits),rt,ra,_)
#define PPC_LSR_IMM(ra, rt, bits) \
	PPC_OP_REG(OP__RLD,OPR_RLDICL|MD(bits,64-(bits)),rt,ra,_)
#define PPC_ASR_IMM(ra, rt, bits) \
	PPC_OP_REG(OP__EXT,OPE_SRADI|MD(_,bits),rt,ra,_)
#define PPC_ROL_IMM(ra, rt, bits) \
	PPC_OP_REG(OP__RLD,OPR_RLDICL|MD(0,bits),rt,ra,_)

#define PPC_LSLW_IMM(ra, rt, bits) \
	PPC_OP_REG(OP_RLWINM,MM(0,31-(bits)),rt,ra,bits)
#define PPC_LSRW_IMM(ra, rt, bits) \
	PPC_OP_REG(OP_RLWINM,MM(bits,31),rt,ra,32-(bits))
#define PPC_ASRW_IMM(ra, rt, bits) \
	PPC_OP_REG(OP__EXT,OPE_SRAWI,rt,ra,bits)
#define PPC_ROLW_IMM(ra, rt, bits) \
	PPC_OP_REG(OP_RLWINM,MM(0,31),rt,ra,bits)

// rt = EXTRACT/INSERT ra
#define PPC_BFX_IMM(ra, rt, lsb, bits) \
	PPC_OP_REG(OP__RLD,OPR_RLDICL|MD(64-(bits),63&(lsb+bits)),rt,ra,_)
#define PPC_BFXD_IMM(ra, rt, lsb, bits) /* extract to high bits, 64 bit */ \
	PPC_OP_REG(OP__RLD,OPR_RLDICR|MD(bits-1,lsb),rt,ra,_)
#define PPC_BFI_IMM(ra, rt, lsb, bits) \
	PPC_OP_REG(OP__RLD,OPR_RLDIMI|MD(lsb,64-(lsb+bits)),rt,ra,_)

#define PPC_BFXW_IMM(ra, rt, lsb, bits) \
	PPC_OP_REG(OP_RLWINM,MM(32-(bits),31),rt,ra,31&(lsb+bits))
#define PPC_BFXT_IMM(ra, rt, lsb, bits) /* extract to high bits, 32 bit */ \
	PPC_OP_REG(OP_RLWINM,MM(0,bits-1),rt,ra,lsb)
#define PPC_BFIW_IMM(ra, rt, lsb, bits) \
	PPC_OP_REG(OP_RLWIMI,MM(lsb,lsb+bits-1),rt,ra,32-(lsb+bits))

// multiplication; NB in 32 bit results the topmost 32 bits are undefined
#define PPC_MULL(rt, ra, rb) /* 64 bit */ \
	PPC_OP_REG(OP__EXT,OPE_MULLD,rt,ra,rb)
#define PPC_MUL(rt, ra, rb) /* low 32 bit */ \
	PPC_OP_REG(OP__EXT,OPE_MULLW,rt,ra,rb)
#define PPC_MULHS(rt, ra, rb) /* high 32 bit, signed */ \
	PPC_OP_REG(OP__EXT,OPE_MULHW,rt,ra,rb)
#define PPC_MULHU(rt, ra, rb) /* high 32 bit, unsigned */ \
	PPC_OP_REG(OP__EXT,OPE_MULHWU,rt,ra,rb)
// XXX use MAC* insns from the LMA group?

// branching (only PC-relative)

#define PPC_B(offs26) \
	PPC_OP_IMM(OP_B,_,_,(offs26)&~3)
#define PPC_BL(offs26) \
	PPC_OP_IMM(OP_B,_,_,((offs26)&~3)|BLK)
#define PPC_RET() \
	PPC_OP_REG(OP__CR,OPC_BCLR,BXX>>3,_,_)
#define PPC_RETCOND(cond) \
	PPC_OP_REG(OP__CR,OPC_BCLR,(cond)>>3,(cond)&0x7,_)
#define PPC_BCTRCOND(cond) \
	PPC_OP_REG(OP__CR,OPC_BCCTR,(cond)>>3,(cond)&0x7,_)
#define PPC_BLCTRCOND(cond) \
	PPC_OP_REG(OP__CR,OPC_BCCTR|BLK,(cond)>>3,(cond)&0x7,_)
#define PPC_BCOND(cond, offs19) \
	PPC_OP_IMM(OP_BC,(cond)>>3,(cond)&0x7,(offs19)&~3)

// load/store, offset

#define	PPC_LDX_IMM(rt, ra, offs16) \
	PPC_OP_IMM(OP__LD,rt,ra,((u16)(offs16)&~3)|OPL_LD)
#define	PPC_LDW_IMM(rt, ra, offs16) \
	PPC_OP_IMM(OP_LWZ,rt,ra,(u16)(offs16))
#define	PPC_LDH_IMM(rt, ra, offs16) \
	PPC_OP_IMM(OP_LHZ,rt,ra,(u16)(offs16))
#define	PPC_LDB_IMM(rt, ra, offs16) \
	PPC_OP_IMM(OP_LBZ,rt,ra,(u16)(offs16))

#define	PPC_LDSH_IMM(rt, ra, offs16) \
	PPC_OP_IMM(OP_LHA,rt,ra,(u16)(offs16))

#define	PPC_STX_IMM(rt, ra, offs16) \
	PPC_OP_IMM(OP__ST,rt,ra,((u16)(offs16)&~3)|OPS_STD)
#define	PPC_STW_IMM(rt, ra, offs16) \
	PPC_OP_IMM(OP_STW,rt,ra,(u16)(offs16))
#define	PPC_STH_IMM(rt, ra, offs16) \
	PPC_OP_IMM(OP_STH,rt,ra,(u16)(offs16))
#define	PPC_STB_IMM(rt, ra, offs16) \
	PPC_OP_IMM(OP_STB,rt,ra,(u16)(offs16))

#define	PPC_STXU_IMM(rt, ra, offs16) \
	PPC_OP_IMM(OP__ST,rt,ra,((u16)(offs16)&~3)|OPS_STDU)
#define	PPC_STWU_IMM(rt, ra, offs16) \
	PPC_OP_IMM(OP_STWU,rt,ra,(u16)(offs16))

// load/store, indexed

#define PPC_LDX_REG(rt, ra, rb) \
	PPC_OP_REG(OP__EXT,OPE_LDX,rt,ra,rb)
#define PPC_LDW_REG(rt, ra, rb) \
	PPC_OP_REG(OP__EXT,OPE_LWZX,rt,ra,rb)
#define PPC_LDH_REG(rt, ra, rb) \
	PPC_OP_REG(OP__EXT,OPE_LHZX,rt,ra,rb)
#define PPC_LDB_REG(rt, ra, rb) \
	PPC_OP_REG(OP__EXT,OPE_LBZX,rt,ra,rb)

#define PPC_LDSH_REG(rt, ra, rb) \
	PPC_OP_REG(OP__EXT,OPE_LHAX,rt,ra,rb)

#define PPC_STX_REG(rt, ra, rb) \
	PPC_OP_REG(OP__EXT,OPE_STX,rt,ra,rb)
#define PPC_STW_REG(rt, ra, rb) \
	PPC_OP_REG(OP__EXT,OPE_STWX,rt,ra,rb)
#define PPC_STH_REG(rt, ra, rb) \
	PPC_OP_REG(OP__EXT,OPE_STHX,rt,ra,rb)
#define PPC_STB_REG(rt, ra, rb) \
	PPC_OP_REG(OP__EXT,OPE_STBX,rt,ra,rb)

// special regs: LR, CTR, XER, CR

#define	PPC_MFSP_REG(rt, spr) \
	PPC_OP_REG(OP__EXT,OPE_MFSPR,rt,_,_CB(-(spr),5,0,5)|_CB(-(spr),5,5,0))
#define	PPC_MTSP_REG(rs, spr) \
	PPC_OP_REG(OP__EXT,OPE_MTSPR,rs,_,_CB(-(spr),5,0,5)|_CB(-(spr),5,5,0))

#define	PPC_MFCR_REG(rt) \
	PPC_OP_REG(OP__EXT,OPE_MFCR,rt,_,_)
#define	PPC_MTCRF_REG(rs, fm) \
	PPC_OP_REG(OP__EXT,OPE_MTCRF,rs,_,(fm)<<1)
#define	PPC_MCRXR_REG(crt) \
	PPC_OP_REG(OP__EXT,OPE_MCRXR,(crt)<<2,_,_)
#define	PPC_MCRCR_REG(crt, crf) \
	PPC_OP_REG(OP__CR,OPC_MCRF,(crt)<<2,(crf)<<1,_)

#ifdef __powerpc64__
#define PTR_SCALE			3
#define PPC_LDP_IMM			PPC_LDX_IMM
#define PPC_LDP_REG			PPC_LDX_REG
#define PPC_STP_IMM			PPC_STX_IMM
#define PPC_STP_REG			PPC_STX_REG
#define PPC_STPU_IMM			PPC_STXU_IMM
#define PPC_BFXP_IMM			PPC_BFX_IMM

#define emith_uext_ptr(r)		EMIT(PPC_EXTUW_REG(r, r))

// "long" multiplication, 32x32 bit = 64 bit
#define EMIT_PPC_MULLU_REG(dlo, dhi, s1, s2) do { \
	int at = (dlo == s1 || dlo == s2 ? AT : dlo); \
	EMIT(PPC_MUL(at, s1, s2)); \
	EMIT(PPC_MULHU(dhi, s1, s2)); \
	if (at != dlo) emith_move_r_r(dlo, at); \
} while (0)

#define EMIT_PPC_MULLS_REG(dlo, dhi, s1, s2) do { \
	EMIT(PPC_MUL(dlo, s1, s2)); \
	EMIT(PPC_ASR_IMM(dhi, dlo, 32)); \
} while (0)

#define EMIT_PPC_MACLS_REG(dlo, dhi, s1, s2) do { \
	EMIT(PPC_MUL(AT, s1, s2)); \
	EMIT(PPC_BFI_IMM(dlo, dhi, 0, 32)); \
	emith_add_r_r(dlo, AT); \
	EMIT(PPC_ASR_IMM(dhi, dlo, 32)); \
} while (0)
#else
#define PTR_SCALE			2
#define PPC_LDP_IMM			PPC_LDW_IMM
#define PPC_LDP_REG			PPC_LDW_REG
#define PPC_STP_IMM			PPC_STW_IMM
#define PPC_STP_REG			PPC_STW_REG
#define PPC_STPU_IMM			PPC_STWU_IMM
#define PPC_BFXP_IMM			PPC_BFXW_IMM

#define emith_uext_ptr(r)		/**/

// "long" multiplication, 32x32 bit = 64 bit
#define EMIT_PPC_MULLU_REG(dlo, dhi, s1, s2) do { \
	int at = (dlo == s1 || dlo == s2 ? AT : dlo); \
	EMIT(PPC_MUL(at, s1, s2)); \
	EMIT(PPC_MULHU(dhi, s1, s2)); \
	if (at != dlo) emith_move_r_r(dlo, at); \
} while (0)

#define EMIT_PPC_MULLS_REG(dlo, dhi, s1, s2) do { \
	int at = (dlo == s1 || dlo == s2 ? AT : dlo); \
	EMIT(PPC_MUL(at, s1, s2)); \
	EMIT(PPC_MULHS(dhi, s1, s2)); \
	if (at != dlo) emith_move_r_r(dlo, at); \
} while (0)

#define EMIT_PPC_MACLS_REG(dlo, dhi, s1, s2) do { \
	int t_ = rcache_get_tmp(); \
	EMIT_PPC_MULLS_REG(t_, AT, s1, s2); \
	EMIT(PPC_ADDC_REG(dlo, dlo, t_)); \
	EMIT(PPC_ADC_REG(dhi, dhi, AT)); \
	rcache_free_tmp(t_); \
} while (0)
#endif
#define PTR_SIZE	(1<<PTR_SCALE)

// "emulated" RISC-V SLTU insn for the flag handling stuff XXX cumbersome
#define EMIT_PPC_SLTWU_REG(rt, ra, rb) do { \
	EMIT(PPC_CMPLW_REG(ra, rb)); \
	EMIT(PPC_MFCR_REG(rt)); \
	EMIT(PPC_BFXW_IMM(rt, rt, 0, 1)); \
} while (0)

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
	EMIT(PPC_BCOND(cond_m, 0)); \
}

#define JMP_EMIT(cond, ptr) { \
	u32 val_ = (u8 *)tcache_ptr - (u8 *)(ptr); \
	EMIT_PTR(ptr, PPC_BCOND(cond_m, val_ & 0x0000fffc)); \
}

#define JMP_EMIT_NC(ptr) { \
	u32 val_ = (u8 *)tcache_ptr - (u8 *)(ptr); \
	EMIT_PTR(ptr, PPC_B(val_ & 0x03ffffffc)); \
}

#define EMITH_JMP_START(cond) { \
	int cond_m = emith_cond_check(cond); \
	u8 *cond_ptr; \
	JMP_POS(cond_ptr)

#define EMITH_JMP_END(cond) \
	JMP_EMIT(cond, cond_ptr); \
}

#define EMITH_JMP3_START(cond) { \
	int cond_m = emith_cond_check(cond); \
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
static int emith_cmp_ra, emith_cmp_rb;	// registers used in cmp_r_r/cmp_r_imm
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

// store minimal cc information: rt, rb^ra, carry
// NB: the result *must* first go to FNZ, in case rt == ra or rt == rb.
// NB: for adcf and sbcf, carry-in must be dealt with separately (see there)
static void emith_set_arith_flags(int rt, int ra, int rb, s32 imm, int sub)
{
	if (emith_flg_hint & _FHC) {
		if (sub)			// C = sub:rb<rt, add:rt<rb
			EMIT_PPC_SLTWU_REG(FC, ra, FNZ);
		else	EMIT_PPC_SLTWU_REG(FC, FNZ, ra);// C in FC, bit 0 
	}

	if (emith_flg_hint & _FHV) {
		emith_flg_noV = 0;
		if (rb >= 0)				// Nt^Ns in FV, bit 31
			EMIT(PPC_XOR_REG(FV, ra, rb));
		else if (imm == 0)
			emith_flg_noV = 1;		// imm #0 can't overflow
		else if ((imm < 0) == !sub)
			EMIT(PPC_MVN_REG(FV, ra));
		else if ((imm > 0) == !sub)
			EMIT(PPC_MOV_REG(FV, ra));
	}
	// full V = Nd^Nt^Ns^C calculation is deferred until really needed

	if (rt && rt != FNZ)
		EMIT(PPC_MOV_REG(rt, FNZ));	// N,Z via result value in FNZ
	emith_cmp_ra = emith_cmp_rb = -1;
}

// handle cmp separately by storing the involved regs for later use.
// this works for all conditions but VC/VS, but this is fortunately never used.
static void emith_set_compare_flags(int ra, int rb, s32 imm)
{
	emith_cmp_rb = rb;
	emith_cmp_ra = ra;
	emith_cmp_imm = imm;
}


// data processing, register

#define emith_move_r_r_ptr(d, s) \
	EMIT(PPC_MOV_REG(d, s))
#define emith_move_r_r_ptr_c(cond, d, s) \
	emith_move_r_r_ptr(d, s)

#define emith_move_r_r(d, s) \
	emith_move_r_r_ptr(d, s)
#define emith_move_r_r_c(cond, d, s) \
	emith_move_r_r(d, s)

#define emith_mvn_r_r(d, s) \
	EMIT(PPC_MVN_REG(d, s))

#define emith_add_r_r_r_lsl_ptr(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(PPC_LSLW_IMM(AT, s2, simm)); \
		EMIT(PPC_ADD_REG(d, s1, AT)); \
	} else	EMIT(PPC_ADD_REG(d, s1, s2)); \
} while (0)
#define emith_add_r_r_r_lsl(d, s1, s2, simm) \
	emith_add_r_r_r_lsl_ptr(d, s1, s2, simm)

#define emith_add_r_r_r_lsr(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(PPC_LSRW_IMM(AT, s2, simm)); \
		EMIT(PPC_ADD_REG(d, s1, AT)); \
	} else	EMIT(PPC_ADD_REG(d, s1, s2)); \
} while (0)

#define emith_addf_r_r_r_lsl_ptr(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(PPC_LSLW_IMM(AT, s2, simm)); \
		EMIT(PPC_ADD_REG(FNZ, s1, AT)); \
		emith_set_arith_flags(d, s1, AT, 0, 0); \
	} else { \
		EMIT(PPC_ADD_REG(FNZ, s1, s2)); \
		emith_set_arith_flags(d, s1, s2, 0, 0); \
	} \
} while (0)
#define emith_addf_r_r_r_lsl(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(PPC_LSLW_IMM(AT, s2, simm)); \
		EMIT(PPC_ADD_REG(FNZ, s1, AT)); \
		emith_set_arith_flags(d, s1, AT, 0, 0); \
	} else { \
		EMIT(PPC_ADD_REG(FNZ, s1, s2)); \
		emith_set_arith_flags(d, s1, s2, 0, 0); \
	} \
} while (0)

#define emith_addf_r_r_r_lsr(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(PPC_LSRW_IMM(AT, s2, simm)); \
		EMIT(PPC_ADD_REG(FNZ, s1, AT)); \
		emith_set_arith_flags(d, s1, AT, 0, 0); \
	} else { \
		EMIT(PPC_ADD_REG(FNZ, s1, s2)); \
		emith_set_arith_flags(d, s1, s2, 0, 0); \
	} \
} while (0)

#define emith_sub_r_r_r_lsl(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(PPC_LSLW_IMM(AT, s2, simm)); \
		EMIT(PPC_SUB_REG(d, s1, AT)); \
	} else	EMIT(PPC_SUB_REG(d, s1, s2)); \
} while (0)

#define emith_subf_r_r_r_lsl(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(PPC_LSLW_IMM(AT, s2, simm)); \
		EMIT(PPC_SUB_REG(FNZ, s1, AT)); \
		emith_set_arith_flags(d, s1, AT, 0, 1); \
	} else { \
		EMIT(PPC_SUB_REG(FNZ, s1, s2)); \
		emith_set_arith_flags(d, s1, s2, 0, 1); \
	} \
} while (0)

#define emith_or_r_r_r_lsl(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(PPC_LSLW_IMM(AT, s2, simm)); \
		EMIT(PPC_OR_REG(d, s1, AT)); \
	} else	EMIT(PPC_OR_REG(d, s1, s2)); \
} while (0)

#define emith_or_r_r_r_lsr(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(PPC_LSRW_IMM(AT, s2, simm)); \
		EMIT(PPC_OR_REG(d, s1, AT)); \
	} else  EMIT(PPC_OR_REG(d, s1, s2)); \
} while (0)

#define emith_eor_r_r_r_lsl(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(PPC_LSLW_IMM(AT, s2, simm)); \
		EMIT(PPC_XOR_REG(d, s1, AT)); \
	} else	EMIT(PPC_XOR_REG(d, s1, s2)); \
} while (0)

#define emith_eor_r_r_r_lsr(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(PPC_LSRW_IMM(AT, s2, simm)); \
		EMIT(PPC_XOR_REG(d, s1, AT)); \
	} else	EMIT(PPC_XOR_REG(d, s1, s2)); \
} while (0)

#define emith_and_r_r_r_lsl(d, s1, s2, simm) do { \
	if (simm) { \
		EMIT(PPC_LSLW_IMM(AT, s2, simm)); \
		EMIT(PPC_AND_REG(d, s1, AT)); \
	} else	EMIT(PPC_AND_REG(d, s1, s2)); \
} while (0)

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
	EMIT(PPC_NEG_REG(d, s))

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

#define emith_negc_r_r(d, s) do { \
	emith_neg_r_r(d, s); \
	emith_sub_r_r(d, FC); \
} while (0)

// NB: the incoming carry Cin can cause Cout if s2+Cin=0 (or s1+Cin=0 FWIW)
// moreover, if s2+Cin=0 caused Cout, s1+s2+Cin=s1+0 can't cause another Cout
#define emith_adcf_r_r_r(d, s1, s2) do { \
	emith_add_r_r_r(FNZ, s2, FC); \
	EMIT_PPC_SLTWU_REG(AT, FNZ, FC); \
	emith_add_r_r_r(FNZ, s1, FNZ); \
	emith_set_arith_flags(d, s1, s2, 0, 0); \
	emith_or_r_r(FC, AT); \
} while (0)

#define emith_sbcf_r_r_r(d, s1, s2) do { \
	emith_add_r_r_r(FNZ, s2, FC); \
	EMIT_PPC_SLTWU_REG(AT, FNZ, FC); \
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
		emith_cmp_ra = emith_cmp_rb = -1; \
	} else	emith_cmp_ra = s, emith_cmp_rb = -1, emith_cmp_imm = 0; \
} while (0)
#define emith_tst_r_r(d, s) \
	emith_tst_r_r_ptr(d, s)

#define emith_teq_r_r(d, s) do { \
	emith_eor_r_r_r(FNZ, d, s); \
	emith_cmp_ra = emith_cmp_rb = -1; \
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

#define emith_negcf_r_r(d, s) do { \
	emith_add_r_r_r(FNZ, s, FC); \
	EMIT_PPC_SLTWU_REG(AT, FNZ, FC); \
	emith_neg_r_r(FNZ, FNZ); \
	emith_set_arith_flags(d, Z0, s, 0, 1); \
	emith_or_r_r(FC, AT); \
} while (0)

// move immediate

static void emith_move_imm(int r, int ptr, uintptr_t imm)
{
#ifdef __powerpc64__
	if (ptr && (s32)imm != imm) {
		emith_move_imm(r, 0, imm >> 32);
		if (imm >> 32)
			EMIT(PPC_LSL_IMM(r, r, 32));
		if (imm & 0x0000ffff)
			EMIT(PPC_OR_IMM(r, r, imm & 0x0000ffff));
		if (imm & 0xffff0000)
			EMIT(PPC_ORT_IMM(r, r, (imm & 0xffff0000) >> 16));
	} else
#endif
	if ((s16)imm != (s32)imm) {
		EMIT(PPC_ADDT_IMM(r, Z0, (u16)(imm>>16)));
		if ((s16)imm)
			EMIT(PPC_OR_IMM(r, r, (u16)(imm)));
	} else	EMIT(PPC_ADD_IMM(r, Z0, (u16)imm));
}

#define emith_move_r_ptr_imm(r, imm) \
	emith_move_imm(r, 1, (uintptr_t)(imm))

#define emith_move_r_imm(r, imm) \
	emith_move_imm(r, 0, (u32)(imm))
#define emith_move_r_imm_c(cond, r, imm) \
	emith_move_r_imm(r, imm)

#define emith_move_r_imm_s8_patchable(r, imm) \
	EMIT(PPC_ADD_IMM(r, Z0, (s8)(imm)))
#define emith_move_r_imm_s8_patch(ptr, imm) do { \
	u32 *ptr_ = (u32 *)ptr; \
	EMIT_PTR(ptr_, (*ptr_ & 0xffff0000) | (u16)(s8)(imm)); \
} while (0)

// arithmetic, immediate - can only be ADDI, since SUBI doesn't exist

static void emith_add_imm(int rt, int ra, u32 imm)
{
	int s = ra;
	if ((u16)imm) {
		EMIT(PPC_ADD_IMM(rt, s, (u16)imm));
		s = rt;
	}
	// adjust for sign extension in ADDI
	imm = (imm >> 16) + ((s16)imm < 0);
	if ((u16)imm || rt != s)
		EMIT(PPC_ADDT_IMM(rt, s, (u16)imm));
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
	emith_add_imm(d, s, imm)

#define emith_add_r_r_imm(d, s, imm) \
	emith_add_r_r_ptr_imm(d, s, imm)

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
		EMIT_PPC_SLTWU_REG(AT, FNZ, FC); \
		emith_add_r_r_imm(FNZ, FNZ, imm); \
		emith_set_arith_flags(d, s, -1, imm, 0); \
		emith_or_r_r(FC, AT); \
	} \
} while (0)

// NB: no SUBI, since ADDI takes a signed imm
#define emith_sub_r_r_imm(d, s, imm) \
	emith_add_r_r_imm(d, s, -(imm))
#define emith_sub_r_r_imm_c(cond, d, s, imm) \
	emith_sub_r_r_imm(d, s, imm)

#define emith_subf_r_r_imm(d, s, imm) do { \
	emith_sub_r_r_imm(FNZ, s, imm); \
	emith_set_arith_flags(d, s, -1, imm, 1); \
} while (0)

// logical, immediate

#define emith_log_imm2(opi, opr, rt, ra, imm) do { \
	if ((imm) >> 16 || opi == OP_ANDI) { /* too big, or microcoded ANDI */ \
		emith_move_r_imm(AT, imm); \
		EMIT(PPC_OP_REG(OP__EXT, opr, ra, rt, AT)); \
	} else if (/*opi == OP_ANDI ||*/ imm || rt != ra) \
		EMIT(PPC_OP_IMM(opi, ra, rt, imm)); \
} while (0)
#define emith_log_imm(op, rt, ra, imm) \
	emith_log_imm2(OP_##op##I, OPE_##op, rt, ra, imm)

#define emith_and_r_imm(r, imm) \
	emith_log_imm(AND, r, r, imm)

#define emith_or_r_imm(r, imm) \
	emith_log_imm(OR, r, r, imm)
#define emith_or_r_imm_c(cond, r, imm) \
	emith_or_r_imm(r, imm)

#define emith_eor_r_imm_ptr(r, imm) \
	emith_log_imm(XOR, r, r, imm)
#define emith_eor_r_imm_ptr_c(cond, r, imm) \
	emith_eor_r_imm_ptr(r, imm)

#define emith_eor_r_imm(r, imm) \
	emith_eor_r_imm_ptr(r, imm)
#define emith_eor_r_imm_c(cond, r, imm) \
	emith_eor_r_imm(r, imm)

/* NB: BIC #imm not available; use AND #~imm instead */
#define emith_bic_r_imm(r, imm) \
	emith_log_imm(AND, r, r, ~(imm))
#define emith_bic_r_imm_c(cond, r, imm) \
	emith_bic_r_imm(r, imm)

#define emith_tst_r_imm(r, imm) do { \
	emith_log_imm(AND, FNZ, r, imm); \
	emith_cmp_ra = emith_cmp_rb = -1; \
} while (0)
#define emith_tst_r_imm_c(cond, r, imm) \
	emith_tst_r_imm(r, imm)

#define emith_and_r_r_imm(d, s, imm) \
	emith_log_imm(AND, d, s, imm)

#define emith_or_r_r_imm(d, s, imm) \
	emith_log_imm(OR, d, s, imm)

#define emith_eor_r_r_imm(d, s, imm) \
	emith_log_imm(XOR, d, s, imm)

// shift

#define emith_lsl(d, s, cnt) \
	EMIT(PPC_LSLW_IMM(d, s, cnt))

#define emith_lsr(d, s, cnt) \
	EMIT(PPC_LSRW_IMM(d, s, cnt))

#define emith_asr(d, s, cnt) \
	EMIT(PPC_ASRW_IMM(d, s, cnt))

#define emith_ror(d, s, cnt) \
	EMIT(PPC_ROLW_IMM(d, s, 32-(cnt)))
#define emith_ror_c(cond, d, s, cnt) \
	emith_ror(d, s, cnt)

#define emith_rol(d, s, cnt) \
	EMIT(PPC_ROLW_IMM(d, s, cnt)); \

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
	emith_cmp_ra = emith_cmp_rb = -1; \
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
	emith_cmp_ra = emith_cmp_rb = -1; \
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
	emith_cmp_ra = emith_cmp_rb = -1; \
} while (0)

#define emith_rolf(d, s, cnt) do { \
	emith_rol(d, s, cnt); \
	emith_and_r_r_imm(FC, d, 1); \
	emith_move_r_r(FNZ, d); \
	emith_cmp_ra = emith_cmp_rb = -1; \
} while (0)

#define emith_rorf(d, s, cnt) do { \
	emith_ror(d, s, cnt); \
	emith_lsr(FC, d, 31); \
	emith_move_r_r(FNZ, d); \
	emith_cmp_ra = emith_cmp_rb = -1; \
} while (0)

#define emith_rolcf(d) do { \
	emith_lsr(AT, d, 31); \
	emith_lsl(d, d, 1); \
	emith_or_r_r(d, FC); \
	emith_move_r_r(FC, AT); \
	emith_move_r_r(FNZ, d); \
	emith_cmp_ra = emith_cmp_rb = -1; \
} while (0)

#define emith_rorcf(d) do { \
	emith_and_r_r_imm(AT, d, 1); \
	emith_lsr(d, d, 1); \
	emith_lsl(FC, FC, 31); \
	emith_or_r_r(d, FC); \
	emith_move_r_r(FC, AT); \
	emith_move_r_r(FNZ, d); \
	emith_cmp_ra = emith_cmp_rb = -1; \
} while (0)

// signed/unsigned extend

#define emith_clear_msb(d, s, count) /* bits to clear */ \
	EMIT(PPC_BFXW_IMM(d, s, count, 32-(count)))

#define emith_clear_msb_c(cond, d, s, count) \
	emith_clear_msb(d, s, count)

#define emith_sext(d, s, count) /* bits to keep */ do { \
	if (count == 8) \
		EMIT(PPC_EXTSB_REG(d, s)); \
	else if (count == 16) \
		EMIT(PPC_EXTSH_REG(d, s)); \
	else { \
		emith_lsl(d, s, 32-(count)); \
		emith_asr(d, d, 32-(count)); \
	} \
} while (0)

// multiply Rd = Rn*Rm (+ Ra)

#define emith_mul(d, s1, s2) \
	EMIT(PPC_MUL(d, s1, s2))

#define emith_mul_u64(dlo, dhi, s1, s2) \
	EMIT_PPC_MULLU_REG(dlo, dhi, s1, s2)

#define emith_mul_s64(dlo, dhi, s1, s2) \
	EMIT_PPC_MULLS_REG(dlo, dhi, s1, s2)

#define emith_mula_s64(dlo, dhi, s1, s2) \
	EMIT_PPC_MACLS_REG(dlo, dhi, s1, s2)
#define emith_mula_s64_c(cond, dlo, dhi, s1, s2) \
	emith_mula_s64(dlo, dhi, s1, s2)

// load/store. offs has 16 bits signed, which is currently sufficient
#define emith_read_r_r_offs_ptr(r, ra, offs) \
	EMIT(PPC_LDP_IMM(r, ra, offs))
#define emith_read_r_r_offs_ptr_c(cond, r, ra, offs) \
	emith_read_r_r_offs_ptr(r, ra, offs)

#define emith_read_r_r_offs(r, ra, offs) \
	EMIT(PPC_LDW_IMM(r, ra, offs))
#define emith_read_r_r_offs_c(cond, r, ra, offs) \
	emith_read_r_r_offs(r, ra, offs)
 
#define emith_read_r_r_r_ptr(r, ra, rm) \
	EMIT(PPC_LDP_REG(r, ra, rm))

#define emith_read_r_r_r(r, ra, rm) \
	EMIT(PPC_LDW_REG(r, ra, rm))
#define emith_read_r_r_r_c(cond, r, ra, rm) \
	emith_read_r_r_r(r, ra, rm)

#define emith_read8_r_r_offs(r, ra, offs) \
	EMIT(PPC_LDB_IMM(r, ra, offs))
#define emith_read8_r_r_offs_c(cond, r, ra, offs) \
	emith_read8_r_r_offs(r, ra, offs)

#define emith_read8_r_r_r(r, ra, rm) \
	EMIT(PPC_LDB_REG(r, ra, rm))
#define emith_read8_r_r_r_c(cond, r, ra, rm) \
	emith_read8_r_r_r(r, ra, rm)

#define emith_read16_r_r_offs(r, ra, offs) \
	EMIT(PPC_LDH_IMM(r, ra, offs))
#define emith_read16_r_r_offs_c(cond, r, ra, offs) \
	emith_read16_r_r_offs(r, ra, offs)

#define emith_read16_r_r_r(r, ra, rm) \
	EMIT(PPC_LDH_REG(r, ra, rm))
#define emith_read16_r_r_r_c(cond, r, ra, rm) \
	emith_read16_r_r_r(r, ra, rm)

#define emith_read8s_r_r_offs(r, ra, offs) do { \
	EMIT(PPC_LDB_IMM(r, ra, offs)); \
	EMIT(PPC_EXTSB_REG(r, r)); \
} while (0)
#define emith_read8s_r_r_offs_c(cond, r, ra, offs) \
	emith_read8s_r_r_offs(r, ra, offs)

#define emith_read8s_r_r_r(r, ra, rm) do { \
	EMIT(PPC_LDB_REG(r, ra, rm)); \
	EMIT(PPC_EXTSB_REG(r, r)); \
} while (0)
#define emith_read8s_r_r_r_c(cond, r, ra, rm) \
	emith_read8s_r_r_r(r, ra, rm)

#define emith_read16s_r_r_offs(r, ra, offs) do { \
	EMIT(PPC_LDH_IMM(r, ra, offs)); \
	EMIT(PPC_EXTSH_REG(r, r)); \
} while (0)
#define emith_read16s_r_r_offs_c(cond, r, ra, offs) \
	emith_read16s_r_r_offs(r, ra, offs)

#define emith_read16s_r_r_r(r, ra, rm) do { \
	EMIT(PPC_LDH_REG(r, ra, rm)); \
	EMIT(PPC_EXTSH_REG(r, r)); \
} while (0)
#define emith_read16s_r_r_r_c(cond, r, ra, rm) \
	emith_read16s_r_r_r(r, ra, rm)


#define emith_write_r_r_offs_ptr(r, ra, offs) \
	EMIT(PPC_STP_IMM(r, ra, offs))
#define emith_write_r_r_offs_ptr_c(cond, r, ra, offs) \
	emith_write_r_r_offs_ptr(r, ra, offs)

#define emith_write_r_r_r_ptr(r, ra, rm) \
	EMIT(PPC_STP_REG(r, ra, rm))
#define emith_write_r_r_r_ptr_c(cond, r, ra, rm) \
	emith_write_r_r_r_ptr(r, ra, rm)

#define emith_write_r_r_offs(r, ra, offs) \
	EMIT(PPC_STW_IMM(r, ra, offs))
#define emith_write_r_r_offs_c(cond, r, ra, offs) \
	emith_write_r_r_offs(r, ra, offs)

#define emith_write_r_r_r(r, ra, rm) \
	EMIT(PPC_STW_REG(r, ra, rm))
#define emith_write_r_r_r_c(cond, r, ra, rm) \
	emith_write_r_r_r(r, ra, rm)

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
	int _c, _z = PTR_SIZE; u32 _m = mask & 0x1ff8; /* r3-r12 */ \
	if (__builtin_parity(_m) == 1) _m |= 0x1; /* ABI align */ \
	int _s = count_bits(_m) * _z, _o = _s; \
	if (_s) emith_add_r_r_ptr_imm(SP, SP, -_s); \
	for (_c = HOST_REGS-1; _m && _c >= 0; _m &= ~(1 << _c), _c--) \
		if (_m & (1 << _c)) \
			{ _o -= _z; if (_c) emith_write_r_r_offs_ptr(_c, SP, _o); } \
} while (0)

#define emith_restore_caller_regs(mask) do { \
	int _c, _z = PTR_SIZE; u32 _m = mask & 0x1ff8; \
	if (__builtin_parity(_m) == 1) _m |= 0x1; \
	int _s = count_bits(_m) * _z, _o = 0; \
	for (_c = 0; _m && _c < HOST_REGS; _m &= ~(1 << _c), _c++) \
		if (_m & (1 << _c)) \
			{ if (_c) emith_read_r_r_offs_ptr(_c, SP, _o); _o += _z; } \
	if (_s) emith_add_r_r_ptr_imm(SP, SP, _s); \
} while (0)

#if defined __PS3__
// on PS3 a C function pointer points to an array of 2 ptrs containing the start
// address and the TOC pointer for this function. TOC isn't used by the DRC though.
static void *fptr[2];
#define host_call(addr, args)	(fptr[0] = addr, (void (*) args)fptr)
#else
// with ELF we have the PLT which wraps functions needing any ABI register setup,
// hence a function ptr is simply the entry address of the function to execute.
#define host_call(addr, args)	addr
#endif

#define host_arg2reg(rt, arg) \
	rt = (arg+3)

#define emith_pass_arg_r(arg, reg) \
	emith_move_r_r_ptr(arg, reg)

#define emith_pass_arg_imm(arg, imm) \
	emith_move_r_ptr_imm(arg, imm)

// branching
#define emith_invert_branch(cond) /* inverted conditional branch */ \
	((cond) ^ 0x40)

// evaluate the emulated condition, returns a register/branch type pair
static int emith_cmpr_check(int rs, int rt, int cond, u32 *op)
{
	int b = -1;

	// condition check for comparing 2 registers
	switch (cond) {
	case DCOND_EQ:	*op = PPC_CMPW_REG(rs, rt); b = BEQ; break;
	case DCOND_NE:	*op = PPC_CMPW_REG(rs, rt); b = BNE; break;
	case DCOND_LO:	*op = PPC_CMPLW_REG(rs, rt); b = BLT; break;
	case DCOND_HS:	*op = PPC_CMPLW_REG(rs, rt); b = BGE; break;
	case DCOND_LS:	*op = PPC_CMPLW_REG(rs, rt); b = BLE; break;
	case DCOND_HI:	*op = PPC_CMPLW_REG(rs, rt); b = BGT; break;
	case DCOND_LT:	*op = PPC_CMPW_REG(rs, rt); b = BLT; break;
	case DCOND_GE:	*op = PPC_CMPW_REG(rs, rt); b = BGE; break;
	case DCOND_LE:	*op = PPC_CMPW_REG(rs, rt); b = BLE; break;
	case DCOND_GT:	*op = PPC_CMPW_REG(rs, rt); b = BGT; break;
	}

	return b;
}

static int emith_cmpi_check(int rs, s32 imm, int cond, u32 *op)
{
	int b = -1;

	// condition check for comparing register with immediate
	switch (cond) {
	case DCOND_EQ:	*op = PPC_CMPW_IMM(rs, (u16)imm), b = BEQ; break;
	case DCOND_NE:	*op = PPC_CMPW_IMM(rs, (u16)imm), b = BNE; break;
	case DCOND_LO:	*op = PPC_CMPLW_IMM(rs, (u16)imm), b = BLT; break;
	case DCOND_HS:	*op = PPC_CMPLW_IMM(rs, (u16)imm), b = BGE; break;
	case DCOND_LS:	*op = PPC_CMPLW_IMM(rs, (u16)imm), b = BLE; break;
	case DCOND_HI:	*op = PPC_CMPLW_IMM(rs, (u16)imm), b = BGT; break;
	case DCOND_LT:	*op = PPC_CMPW_IMM(rs, (u16)imm), b = BLT; break;
	case DCOND_GE:	*op = PPC_CMPW_IMM(rs, (u16)imm), b = BGE; break;
	case DCOND_LE:	*op = PPC_CMPW_IMM(rs, (u16)imm), b = BLE; break;
	case DCOND_GT:	*op = PPC_CMPW_IMM(rs, (u16)imm), b = BGT; break;
	}

	return b;
}

static int emith_cond_check(int cond)
{
	int b = -1;
	u32 op = 0;

	if (emith_cmp_ra >= 0) {
		if (emith_cmp_rb != -1)
			b = emith_cmpr_check(emith_cmp_ra,emith_cmp_rb, cond,&op);
		else	b = emith_cmpi_check(emith_cmp_ra,emith_cmp_imm,cond,&op);
	}

	// shortcut for V known to be 0
	if (b < 0 && emith_flg_noV) switch (cond) {
	case DCOND_VS:	/* no branch */	break;		// never
	case DCOND_VC:	b = BXX;	break;		// always
	case DCOND_LT:	op = PPC_CMPW_IMM(FNZ, 0); b = BLT; break; // N
	case DCOND_GE:	op = PPC_CMPW_IMM(FNZ, 0); b = BGE; break; // !N
	case DCOND_LE:	op = PPC_CMPW_IMM(FNZ, 0); b = BLE; break; // N || Z
	case DCOND_GT:	op = PPC_CMPW_IMM(FNZ, 0); b = BGT; break; // !N && !Z
	}

	// the full monty if no shortcut
	if (b < 0) switch (cond) {
	// conditions using NZ
	case DCOND_EQ:	op = PPC_CMPW_IMM(FNZ, 0); b = BEQ; break; // Z
	case DCOND_NE:	op = PPC_CMPW_IMM(FNZ, 0); b = BNE; break; // !Z
	case DCOND_MI:	op = PPC_CMPW_IMM(FNZ, 0); b = BLT; break; // N
	case DCOND_PL:	op = PPC_CMPW_IMM(FNZ, 0); b = BGE; break; // !N
	// conditions using C
	case DCOND_LO:	op = PPC_CMPW_IMM(FC , 0); b = BNE; break; // C
	case DCOND_HS:	op = PPC_CMPW_IMM(FC , 0); b = BEQ; break; // !C
	// conditions using CZ
	case DCOND_LS:						// C || Z
	case DCOND_HI:						// !C && !Z
		EMIT(PPC_ADD_IMM(AT, FC, -1)); // !C && !Z
		EMIT(PPC_AND_REG(AT, FNZ, AT));
		op = PPC_CMPW_IMM(AT , 0); b = (cond == DCOND_HI ? BNE : BEQ);
		break;

	// conditions using V
	case DCOND_VS:						// V
	case DCOND_VC:						// !V
		EMIT(PPC_XOR_REG(AT, FV, FNZ)); // V = Nt^Ns^Nd^C
		EMIT(PPC_LSRW_IMM(AT, AT, 31));
		EMIT(PPC_XOR_REG(AT, AT, FC));
		op = PPC_CMPW_IMM(AT , 0); b = (cond == DCOND_VS ? BNE : BEQ);
		break;
	// conditions using VNZ
	case DCOND_LT:						// N^V
	case DCOND_GE:						// !(N^V)
		EMIT(PPC_LSRW_IMM(AT, FV, 31)); // Nd^V = Nt^Ns^C
		EMIT(PPC_XOR_REG(AT, FC, AT));
		op = PPC_CMPW_IMM(AT , 0); b = (cond == DCOND_LT ? BNE : BEQ);
		break;
	case DCOND_LE:						// (N^V) || Z
	case DCOND_GT:						// !(N^V) && !Z
		EMIT(PPC_LSRW_IMM(AT, FV, 31)); // Nd^V = Nt^Ns^C
		EMIT(PPC_XOR_REG(AT, FC, AT));
		EMIT(PPC_ADD_IMM(AT, AT, -1)); // !(Nd^V) && !Z
		EMIT(PPC_AND_REG(AT, FNZ, AT));
		op = PPC_CMPW_IMM(AT , 0); b = (cond == DCOND_GT ? BNE : BEQ);
		break;
	}

	if (op) EMIT(op);
	return b;
}

#define emith_jump(target) do { \
	u32 disp_ = (u8 *)target - (u8 *)tcache_ptr; \
	EMIT(PPC_B((uintptr_t)disp_ & 0x03ffffff)); \
} while (0)
#define emith_jump_patchable(target) \
	emith_jump(target)

// NB: PPC conditional branches have only +/- 64KB range
#define emith_jump_cond(cond, target) do { \
	int mcond_ = emith_cond_check(cond); \
	u32 disp_ = (u8 *)target - (u8 *)tcache_ptr; \
	if (mcond_ >= 0) EMIT(PPC_BCOND(mcond_,disp_ & 0x0000ffff)); \
} while (0)
#define emith_jump_cond_patchable(cond, target) \
	emith_jump_cond(cond, target)

#define emith_jump_cond_inrange(target) \
	((u8 *)target - (u8 *)tcache_ptr <   0x8000 && \
	 (u8 *)target - (u8 *)tcache_ptr >= -0x8000+0x14) //mind cond_check

// NB: returns position of patch for cache maintenance
#define emith_jump_patch(ptr, target, pos) do { \
	u32 *ptr_ = (u32 *)ptr; /* must skip condition check code */ \
	u32 disp_, mask_; \
	while (*ptr_>>26 != OP_BC && *ptr_>>26 != OP_B) ptr_ ++; \
	disp_ = (u8 *)target - (u8 *)ptr_; \
	mask_ = (*ptr_>>26 == OP_BC ? 0xffff0003 : 0xfc000003); \
	EMIT_PTR(ptr_, (*ptr_ & mask_) | (disp_  & ~mask_)); \
	if ((void *)(pos) != NULL) *(u8 **)(pos) = (u8 *)(ptr_-1); \
} while (0)

#define emith_jump_patch_inrange(ptr, target) \
	((u8 *)target - (u8 *)ptr <   0x8000 && \
	 (u8 *)target - (u8 *)ptr >= -0x8000+0x10) // mind cond_check
#define emith_jump_patch_size() 4

#define emith_jump_at(ptr, target) do { \
	u32 disp_ = (u8 *)target - (u8 *)ptr; \
	u32 *ptr_ = (u32 *)ptr; \
	EMIT_PTR(ptr_, PPC_B((uintptr_t)disp_ & 0x03ffffff)); \
} while (0)
#define emith_jump_at_size() 4

#define emith_jump_reg(r) do { \
	EMIT(PPC_MTSP_REG(r, CTR)); \
	EMIT(PPC_BCTRCOND(BXX)); \
} while(0)
#define emith_jump_reg_c(cond, r) \
	emith_jump_reg(r)

#define emith_jump_ctx(offs) do { \
	emith_ctx_read_ptr(CR, offs); \
	emith_jump_reg(CR); \
} while (0)
#define emith_jump_ctx_c(cond, offs) \
	emith_jump_ctx(offs)

#define emith_call(target) do { \
	u32 disp_ = (u8 *)target - (u8 *)tcache_ptr; \
	EMIT(PPC_BL((uintptr_t)disp_ & 0x03ffffff)); \
} while(0)
#define emith_call_cond(cond, target) \
	emith_call(target)

#define emith_call_reg(r) do { \
	EMIT(PPC_MTSP_REG(r, CTR)); \
	EMIT(PPC_BLCTRCOND(BXX)); \
} while(0)

#define emith_abicall_ctx(offs) do { \
	emith_ctx_read_ptr(CR, offs); \
	emith_abicall_reg(CR); \
} while (0)

#ifdef __PS3__
#define emith_abijump_reg(r) \
	emith_read_r_r_offs_ptr(TOC_REG, r, PTR_SIZE); \
	emith_read_r_r_offs_ptr(CR, r, 0); \
	emith_jump_reg(CR)
#else
#define emith_abijump_reg(r) \
	if ((r) != CR) emith_move_r_r(CR, r); \
	emith_jump_reg(CR)
#endif
#define emith_abijump_reg_c(cond, r) \
	emith_abijump_reg(r)
#define emith_abicall(target) \
	emith_move_r_ptr_imm(CR, target); \
	emith_abicall_reg(CR);
#define emith_abicall_cond(cond, target) \
	emith_abicall(target)
#ifdef __PS3__
#define emith_abicall_reg(r) do { \
	emith_read_r_r_offs_ptr(TOC_REG, r, PTR_SIZE); \
	emith_read_r_r_offs_ptr(CR, r, 0); \
	emith_call_reg(CR); \
} while(0)
#else
#define emith_abicall_reg(r) do { \
	if ((r) != CR) emith_move_r_r(CR, r); \
	emith_call_reg(CR); \
} while(0)
#endif

#define emith_call_cleanup()	/**/

#define emith_ret() \
	EMIT(PPC_RET())
#define emith_ret_c(cond) \
	emith_ret()

#define emith_ret_to_ctx(offs) do { \
	EMIT(PPC_MFSP_REG(AT, LR)); \
	emith_ctx_write_ptr(AT, offs); \
} while (0)

#define emith_add_r_ret(r) do { \
	EMIT(PPC_MFSP_REG(AT, LR)); \
	emith_add_r_r_ptr(r, AT); \
} while (0)

// NB: ABI SP alignment is 16 in 64 bit mode
#define emith_push_ret(r) do { \
	int offs_ = 16 - 2*PTR_SIZE; \
	emith_add_r_r_ptr_imm(SP, SP, -16); \
	EMIT(PPC_MFSP_REG(AT, LR)); \
	emith_write_r_r_offs_ptr(AT, SP, offs_ + PTR_SIZE); \
	if ((r) > 0) emith_write_r_r_offs(r, SP, offs_); \
} while (0)

#define emith_pop_and_ret(r) do { \
	int offs_ = 16 - 2*PTR_SIZE; \
	if ((r) > 0) emith_read_r_r_offs(r, SP, offs_); \
	emith_read_r_r_offs_ptr(AT, SP, offs_ + PTR_SIZE); \
	EMIT(PPC_MTSP_REG(AT, LR)); \
	emith_add_r_r_ptr_imm(SP, SP, 16); \
	emith_ret(); \
} while (0)


// this should normally be in libc clear_cache; however, it sometimes isn't.
static NOINLINE void host_instructions_updated(void *base, void *end, int force)
{
	int step = 32, lgstep = 5;
	char *_base = (char *)((uptr)base & ~(step-1));
	int count = (((char *)end - _base) >> lgstep) + 1;

	if (count <= 0) count = 1;	// make sure count is positive
	base = _base;

	asm volatile(
	"	mtctr	%1;"
	"0:	dcbst	0,%0;"
	"	add	%0, %0, %2;"
	"	bdnz	0b;"
	"	sync"
	: "+r"(_base) : "r"(count), "r"(step) : "ctr");

	asm volatile(
	"	mtctr	%1;"
	"0:	icbi	0,%0;"
	"	add	%0, %0, %2;"
	"	bdnz	0b;"
	"	isync"
	: "+r"(base) : "r"(count), "r"(step) : "ctr");
}

// emitter ABI stuff
#define emith_pool_check()	/**/
#define emith_pool_commit(j)	/**/
#define emith_insn_ptr()	((u8 *)tcache_ptr)
#define emith_flush()		/**/
#define emith_update_cache()	/**/
#define emith_rw_offs_max()	0x7fff

// SH2 drc specific
#define STACK_EXTRA	((8+6)*PTR_SIZE) // Param, ABI (LR,CR,FP etc) save areas
#define emith_sh2_drc_entry() do { \
	int _c, _z = PTR_SIZE; u32 _m = 0xffffc000; /* r14-r31 */ \
	if (__builtin_parity(_m) == 1) _m |= 0x1; /* ABI align for SP is 16 */ \
	int _s = count_bits(_m) * _z, _o = STACK_EXTRA; \
	EMIT(PPC_STPU_IMM(SP, SP, -_s-STACK_EXTRA)); \
	EMIT(PPC_MFSP_REG(AT, LR)); \
	for (_c = 0; _m && _c < HOST_REGS; _m &= ~(1 << _c), _c++) \
		if (_m & (1 << _c)) \
			{ if (_c) emith_write_r_r_offs_ptr(_c, SP, _o); _o += _z; } \
	emith_write_r_r_offs_ptr(AT, SP, _o + _z); \
} while (0)
#define emith_sh2_drc_exit() do { \
	int _c, _z = PTR_SIZE; u32 _m = 0xffffc000; \
	if (__builtin_parity(_m) == 1) _m |= 0x1; \
	int _s = count_bits(_m) * _z, _o = STACK_EXTRA; \
	emith_read_r_r_offs_ptr(AT, SP, _o+_s + _z); \
	EMIT(PPC_MTSP_REG(AT, LR)); \
	for (_c = 0; _m && _c < HOST_REGS; _m &= ~(1 << _c), _c++) \
		if (_m & (1 << _c)) \
			{ if (_c) emith_read_r_r_offs_ptr(_c, SP, _o); _o += _z; } \
	emith_add_r_r_ptr_imm(SP, SP, _s+STACK_EXTRA); \
	emith_ret(); \
} while (0)

// NB: assumes a is in arg0, tab, func and mask are temp
#define emith_sh2_rcall(a, tab, func, mask) do { \
	emith_lsr(mask, a, SH2_READ_SHIFT); \
	emith_add_r_r_r_lsl_ptr(tab, tab, mask, PTR_SCALE+1); \
	emith_read_r_r_offs_ptr(func, tab, 0); \
	emith_read_r_r_offs(mask, tab, PTR_SIZE); \
	EMIT(PPC_BFXP_IMM(FC, func, 0, 1)); \
	emith_add_r_r_ptr(func, func); \
	emith_cmp_ra = emith_cmp_rb = -1; \
} while (0)

// NB: assumes a, val are in arg0 and arg1, tab and func are temp
#define emith_sh2_wcall(a, val, tab, func) do { \
	emith_lsr(func, a, SH2_WRITE_SHIFT); \
	emith_lsl(func, func, PTR_SCALE); \
	emith_read_r_r_r_ptr(CR, tab, func); \
	emith_move_r_r_ptr(5, CONTEXT_REG); /* arg2 */ \
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
	EMIT(PPC_CMPLW_REG(rn, t_));              \
	EMITH_JMP3_MID(DCOND_EQ);                 \
	emith_sub_r_r_r(rn, t_, rm);              \
	EMIT(PPC_CMPLW_REG(t_, rn));              \
	EMITH_JMP3_END();                         \
	EMIT(PPC_MFCR_REG(FC));                   \
	EMIT(PPC_BFXW_IMM(FC, FC, 0, 1));         \
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
	emith_tst_r_r(rn, rn); /* (need only N and Z flags) */ \
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
	emith_tst_r_r(rn, rn); /* (need only N and Z flags) */ \
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
	EMIT(PPC_BFIW_IMM(sr, srcr, 22, 10))

#define emith_carry_to_t(sr, is_sub) \
	EMIT(PPC_BFIW_IMM(sr, FC, 32-__builtin_ffs(T), 1))

#define emith_t_to_carry(sr, is_sub) \
	emith_and_r_r_imm(FC, sr, 1)

#define emith_tpop_carry(sr, is_sub) do { \
	emith_and_r_r_imm(FC, sr, 1); \
	emith_eor_r_r(sr, FC); \
} while (0)

#define emith_tpush_carry(sr, is_sub) \
	emith_or_r_r(sr, FC)

#ifdef T
#define emith_invert_cond(cond) \
	((cond) ^ 1)

// T bit handling
static void emith_set_t_cond(int sr, int cond)
{
  int b;

  // catch never and always cases
  if ((b = emith_cond_check(cond)) < 0)
    return;
  else if (b == BXX) {
    emith_or_r_imm(sr, T);
    return;
  }

  // extract bit from CR and insert into T
  EMIT(PPC_MFCR_REG(AT));
  EMIT(PPC_BFXW_IMM(AT, AT, (b&7), 1));
  if (!(b & 0x40)) EMIT(PPC_XOR_IMM(AT, AT, 1));
  EMIT(PPC_BFIW_IMM(sr, AT, 32-__builtin_ffs(T), 1));
}

#define emith_clr_t_cond(sr)	((void)sr)

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
