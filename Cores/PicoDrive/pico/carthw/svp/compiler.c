/*
 * SSP1601 to ARM recompiler
 * (C) notaz, 2008,2009,2010
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include "../../pico_int.h"
#include "../../../cpu/drc/cmn.h"
#include "compiler.h"

// FIXME: asm has these hardcoded
#define SSP_BLOCKTAB_ENTS       (0x5090/2)
#define SSP_BLOCKTAB_IRAM_ONE   (0x800/2) // table entries
#define SSP_BLOCKTAB_IRAM_ENTS  (15*SSP_BLOCKTAB_IRAM_ONE)

static u32 **ssp_block_table; // [0x5090/2];
static u32 **ssp_block_table_iram; // [15][0x800/2];

static u32 *tcache_ptr = NULL;

static int nblocks = 0;
static int n_in_ops = 0;

extern ssp1601_t *ssp;

#define rPC    ssp->gr[SSP_PC].h
#define rPMC   ssp->gr[SSP_PMC]

#define SSP_FLAG_Z (1<<0xd)
#define SSP_FLAG_N (1<<0xf)

#ifndef __arm__
//#define DUMP_BLOCK 0x0c9a
void ssp_drc_next(void){}
void ssp_drc_next_patch(void){}
void ssp_drc_end(void){}
#endif

#define COUNT_OP
#include "../../../cpu/drc/emit_arm.c"

// -----------------------------------------------------

static int get_inc(int mode)
{
	int inc = (mode >> 11) & 7;
	if (inc != 0) {
		if (inc != 7) inc--;
		inc = 1 << inc; // 0 1 2 4 8 16 32 128
		if (mode & 0x8000) inc = -inc; // decrement mode
	}
	return inc;
}

u32 ssp_pm_read(int reg)
{
	u32 d = 0, mode;

	if (ssp->emu_status & SSP_PMC_SET)
	{
		ssp->pmac_read[reg] = rPMC.v;
		ssp->emu_status &= ~SSP_PMC_SET;
		return 0;
	}

	// just in case
	ssp->emu_status &= ~SSP_PMC_HAVE_ADDR;

	mode = ssp->pmac_read[reg]>>16;
	if      ((mode & 0xfff0) == 0x0800) // ROM
	{
		d = ((unsigned short *)Pico.rom)[ssp->pmac_read[reg]&0xfffff];
		ssp->pmac_read[reg] += 1;
	}
	else if ((mode & 0x47ff) == 0x0018) // DRAM
	{
		unsigned short *dram = (unsigned short *)svp->dram;
		int inc = get_inc(mode);
		d = dram[ssp->pmac_read[reg]&0xffff];
		ssp->pmac_read[reg] += inc;
	}

	// PMC value corresponds to last PMR accessed
	rPMC.v = ssp->pmac_read[reg];

	return d;
}

#define overwrite_write(dst, d) \
{ \
	if (d & 0xf000) { dst &= ~0xf000; dst |= d & 0xf000; } \
	if (d & 0x0f00) { dst &= ~0x0f00; dst |= d & 0x0f00; } \
	if (d & 0x00f0) { dst &= ~0x00f0; dst |= d & 0x00f0; } \
	if (d & 0x000f) { dst &= ~0x000f; dst |= d & 0x000f; } \
}

void ssp_pm_write(u32 d, int reg)
{
	unsigned short *dram;
	int mode, addr;

	if (ssp->emu_status & SSP_PMC_SET)
	{
		ssp->pmac_write[reg] = rPMC.v;
		ssp->emu_status &= ~SSP_PMC_SET;
		return;
	}

	// just in case
	ssp->emu_status &= ~SSP_PMC_HAVE_ADDR;

	dram = (unsigned short *)svp->dram;
	mode = ssp->pmac_write[reg]>>16;
	addr = ssp->pmac_write[reg]&0xffff;
	if      ((mode & 0x43ff) == 0x0018) // DRAM
	{
		int inc = get_inc(mode);
		if (mode & 0x0400) {
		       overwrite_write(dram[addr], d);
		} else dram[addr] = d;
		ssp->pmac_write[reg] += inc;
	}
	else if ((mode & 0xfbff) == 0x4018) // DRAM, cell inc
	{
		if (mode & 0x0400) {
		       overwrite_write(dram[addr], d);
		} else dram[addr] = d;
		ssp->pmac_write[reg] += (addr&1) ? 0x1f : 1;
	}
	else if ((mode & 0x47ff) == 0x001c) // IRAM
	{
		int inc = get_inc(mode);
		((unsigned short *)svp->iram_rom)[addr&0x3ff] = d;
		ssp->pmac_write[reg] += inc;
		ssp->drc.iram_dirty = 1;
	}

	rPMC.v = ssp->pmac_write[reg];
}


// -----------------------------------------------------

// 14 IRAM blocks
static unsigned char iram_context_map[] =
{
	 0, 0, 0, 0, 1, 0, 0, 0, // 04
	 0, 0, 0, 0, 0, 0, 2, 0, // 0e
	 0, 0, 0, 0, 0, 3, 0, 4, // 15 17
	 5, 0, 0, 6, 0, 7, 0, 0, // 18 1b 1d
	 8, 9, 0, 0, 0,10, 0, 0, // 20 21 25
	 0, 0, 0, 0, 0, 0, 0, 0,
	 0, 0,11, 0, 0,12, 0, 0, // 32 35
	13,14, 0, 0, 0, 0, 0, 0  // 38 39
};

int ssp_get_iram_context(void)
{
	unsigned char *ir = (unsigned char *)svp->iram_rom;
	int val1, val = ir[0x083^1] + ir[0x4FA^1] + ir[0x5F7^1] + ir[0x47B^1];
	val1 = iram_context_map[(val>>1)&0x3f];

	if (val1 == 0) {
		elprintf(EL_ANOMALY, "svp: iram ctx val: %02x PC=%04x\n", (val>>1)&0x3f, rPC);
		//debug_dump2file(name, svp->iram_rom, 0x800);
		//exit(1);
	}
	return val1;
}

// -----------------------------------------------------

/* regs with known values */
static struct
{
	ssp_reg_t gr[8];
	unsigned char r[8];
	unsigned int pmac_read[5];
	unsigned int pmac_write[5];
	ssp_reg_t pmc;
	unsigned int emu_status;
} known_regs;

#define KRREG_X     (1 << SSP_X)
#define KRREG_Y     (1 << SSP_Y)
#define KRREG_A     (1 << SSP_A)	/* AH only */
#define KRREG_ST    (1 << SSP_ST)
#define KRREG_STACK (1 << SSP_STACK)
#define KRREG_PC    (1 << SSP_PC)
#define KRREG_P     (1 << SSP_P)
#define KRREG_PR0   (1 << 8)
#define KRREG_PR4   (1 << 12)
#define KRREG_AL    (1 << 16)
#define KRREG_PMCM  (1 << 18)		/* only mode word of PMC */
#define KRREG_PMC   (1 << 19)
#define KRREG_PM0R  (1 << 20)
#define KRREG_PM1R  (1 << 21)
#define KRREG_PM2R  (1 << 22)
#define KRREG_PM3R  (1 << 23)
#define KRREG_PM4R  (1 << 24)
#define KRREG_PM0W  (1 << 25)
#define KRREG_PM1W  (1 << 26)
#define KRREG_PM2W  (1 << 27)
#define KRREG_PM3W  (1 << 28)
#define KRREG_PM4W  (1 << 29)

/* bitfield of known register values */
static u32 known_regb = 0;

/* known vals, which need to be flushed
 * (only ST, P, r0-r7, PMCx, PMxR, PMxW)
 * ST means flags are being held in ARM PSR
 * P means that it needs to be recalculated
 */
static u32 dirty_regb = 0;

/* known values of host regs.
 * -1            - unknown
 * 000000-00ffff - 16bit value
 * 100000-10ffff - base reg (r7) + 16bit val
 * 0r0000        - means reg (low) eq gr[r].h, r != AL
 */
static int hostreg_r[4];

static void hostreg_clear(void)
{
	int i;
	for (i = 0; i < 4; i++)
		hostreg_r[i] = -1;
}

static void hostreg_sspreg_changed(int sspreg)
{
	int i;
	for (i = 0; i < 4; i++)
		if (hostreg_r[i] == (sspreg<<16)) hostreg_r[i] = -1;
}


#define PROGRAM(x)   ((unsigned short *)svp->iram_rom)[x]
#define PROGRAM_P(x) ((unsigned short *)svp->iram_rom + (x))

void tr_unhandled(void)
{
	//FILE *f = fopen("tcache.bin", "wb");
	//fwrite(tcache, 1, (tcache_ptr - tcache)*4, f);
	//fclose(f);
	elprintf(EL_ANOMALY, "unhandled @ %04x\n", known_regs.gr[SSP_PC].h<<1);
	//exit(1);
}

/* update P, if needed. Trashes r0 */
static void tr_flush_dirty_P(void)
{
	// TODO: const regs
	if (!(dirty_regb & KRREG_P)) return;
	EOP_MOV_REG_ASR(10, 4, 16);		// mov  r10, r4, asr #16
	EOP_MOV_REG_LSL( 0, 4, 16);		// mov  r0,  r4, lsl #16
	EOP_MOV_REG_ASR( 0, 0, 15);		// mov  r0,  r0, asr #15
	EOP_MUL(10, 0, 10);			// mul  r10, r0, r10
	dirty_regb &= ~KRREG_P;
	hostreg_r[0] = -1;
}

/* write dirty pr to host reg. Nothing is trashed */
static void tr_flush_dirty_pr(int r)
{
	int ror = 0, reg;

	if (!(dirty_regb & (1 << (r+8)))) return;

	switch (r&3) {
		case 0: ror =    0; break;
		case 1: ror = 24/2; break;
		case 2: ror = 16/2; break;
	}
	reg = (r < 4) ? 8 : 9;
	EOP_BIC_IMM(reg,reg,ror,0xff);
	if (known_regs.r[r] != 0)
		EOP_ORR_IMM(reg,reg,ror,known_regs.r[r]);
	dirty_regb &= ~(1 << (r+8));
}

/* write all dirty pr0-pr7 to host regs. Nothing is trashed */
static void tr_flush_dirty_prs(void)
{
	int i, ror = 0, reg;
	int dirty = dirty_regb >> 8;
	if ((dirty&7) == 7) {
		emith_move_r_imm(8, known_regs.r[0]|(known_regs.r[1]<<8)|(known_regs.r[2]<<16));
		dirty &= ~7;
	}
	if ((dirty&0x70) == 0x70) {
		emith_move_r_imm(9, known_regs.r[4]|(known_regs.r[5]<<8)|(known_regs.r[6]<<16));
		dirty &= ~0x70;
	}
	/* r0-r7 */
	for (i = 0; dirty && i < 8; i++, dirty >>= 1)
	{
		if (!(dirty&1)) continue;
		switch (i&3) {
			case 0: ror =    0; break;
			case 1: ror = 24/2; break;
			case 2: ror = 16/2; break;
		}
		reg = (i < 4) ? 8 : 9;
		EOP_BIC_IMM(reg,reg,ror,0xff);
		if (known_regs.r[i] != 0)
			EOP_ORR_IMM(reg,reg,ror,known_regs.r[i]);
	}
	dirty_regb &= ~0xff00;
}

/* write dirty pr and "forget" it. Nothing is trashed. */
static void tr_release_pr(int r)
{
	tr_flush_dirty_pr(r);
	known_regb &= ~(1 << (r+8));
}

/* fush ARM PSR to r6. Trashes r1 */
static void tr_flush_dirty_ST(void)
{
	if (!(dirty_regb & KRREG_ST)) return;
	EOP_BIC_IMM(6,6,0,0x0f);
	EOP_MRS(1);
	EOP_ORR_REG_LSR(6,6,1,28);
	dirty_regb &= ~KRREG_ST;
	hostreg_r[1] = -1;
}

/* inverse of above. Trashes r1 */
static void tr_make_dirty_ST(void)
{
	if (dirty_regb & KRREG_ST) return;
	if (known_regb & KRREG_ST) {
		int flags = 0;
		if (known_regs.gr[SSP_ST].h & SSP_FLAG_N) flags |= 8;
		if (known_regs.gr[SSP_ST].h & SSP_FLAG_Z) flags |= 4;
		EOP_MSR_IMM(4/2, flags);
	} else {
		EOP_MOV_REG_LSL(1, 6, 28);
		EOP_MSR_REG(1);
		hostreg_r[1] = -1;
	}
	dirty_regb |= KRREG_ST;
}

/* load 16bit val into host reg r0-r3. Nothing is trashed */
static void tr_mov16(int r, int val)
{
	if (hostreg_r[r] != val) {
		emith_move_r_imm(r, val);
		hostreg_r[r] = val;
	}
}

static void tr_mov16_cond(int cond, int r, int val)
{
	emith_op_imm(cond, 0, A_OP_MOV, r, val);
	hostreg_r[r] = -1;
}

/* trashes r1 */
static void tr_flush_dirty_pmcrs(void)
{
	u32 i, val = (u32)-1;
	if (!(dirty_regb & 0x3ff80000)) return;

	if (dirty_regb & KRREG_PMC) {
		val = known_regs.pmc.v;
		emith_move_r_imm(1, val);
		EOP_STR_IMM(1,7,0x400+SSP_PMC*4);

		if (known_regs.emu_status & (SSP_PMC_SET|SSP_PMC_HAVE_ADDR)) {
			elprintf(EL_ANOMALY, "!! SSP_PMC_SET|SSP_PMC_HAVE_ADDR set on flush\n");
			tr_unhandled();
		}
	}
	for (i = 0; i < 5; i++)
	{
		if (dirty_regb & (1 << (20+i))) {
			if (val != known_regs.pmac_read[i]) {
				val = known_regs.pmac_read[i];
				emith_move_r_imm(1, val);
			}
			EOP_STR_IMM(1,7,0x454+i*4); // pmac_read
		}
		if (dirty_regb & (1 << (25+i))) {
			if (val != known_regs.pmac_write[i]) {
				val = known_regs.pmac_write[i];
				emith_move_r_imm(1, val);
			}
			EOP_STR_IMM(1,7,0x46c+i*4); // pmac_write
		}
	}
	dirty_regb &= ~0x3ff80000;
	hostreg_r[1] = -1;
}

/* read bank word to r0 (upper bits zero). Thrashes r1. */
static void tr_bank_read(int addr) /* word addr 0-0x1ff */
{
	int breg = 7;
	if (addr > 0x7f) {
		if (hostreg_r[1] != (0x100000|((addr&0x180)<<1))) {
			EOP_ADD_IMM(1,7,30/2,(addr&0x180)>>1);	// add  r1, r7, ((op&0x180)<<1)
			hostreg_r[1] = 0x100000|((addr&0x180)<<1);
		}
		breg = 1;
	}
	EOP_LDRH_IMM(0,breg,(addr&0x7f)<<1);	// ldrh r0, [r1, (op&0x7f)<<1]
	hostreg_r[0] = -1;
}

/* write r0 to bank. Trashes r1. */
static void tr_bank_write(int addr)
{
	int breg = 7;
	if (addr > 0x7f) {
		if (hostreg_r[1] != (0x100000|((addr&0x180)<<1))) {
			EOP_ADD_IMM(1,7,30/2,(addr&0x180)>>1);	// add  r1, r7, ((op&0x180)<<1)
			hostreg_r[1] = 0x100000|((addr&0x180)<<1);
		}
		breg = 1;
	}
	EOP_STRH_IMM(0,breg,(addr&0x7f)<<1);		// strh r0, [r1, (op&0x7f)<<1]
}

/* handle RAM bank pointer modifiers. if need_modulo, trash r1-r3, else nothing */
static void tr_ptrr_mod(int r, int mod, int need_modulo, int count)
{
	int modulo_shift = -1;	/* unknown */

	if (mod == 0) return;

	if (!need_modulo || mod == 1) // +!
		modulo_shift = 8;
	else if (need_modulo && (known_regb & KRREG_ST)) {
		modulo_shift = known_regs.gr[SSP_ST].h & 7;
		if (modulo_shift == 0) modulo_shift = 8;
	}

	if (modulo_shift == -1)
	{
		int reg = (r < 4) ? 8 : 9;
		tr_release_pr(r);
		if (dirty_regb & KRREG_ST) {
			// avoid flushing ARM flags
			EOP_AND_IMM(1, 6, 0, 0x70);
			EOP_SUB_IMM(1, 1, 0, 0x10);
			EOP_AND_IMM(1, 1, 0, 0x70);
			EOP_ADD_IMM(1, 1, 0, 0x10);
		} else {
			EOP_C_DOP_IMM(A_COND_AL,A_OP_AND,1,6,1,0,0x70);	// ands  r1, r6, #0x70
			EOP_C_DOP_IMM(A_COND_EQ,A_OP_MOV,0,0,1,0,0x80); // moveq r1, #0x80
		}
		EOP_MOV_REG_LSR(1, 1, 4);		// mov r1, r1, lsr #4
		EOP_RSB_IMM(2, 1, 0, 8);		// rsb r1, r1, #8
		EOP_MOV_IMM(3, 8/2, count);		// mov r3, #0x01000000
		if (r&3)
			EOP_ADD_IMM(1, 1, 0, (r&3)*8);	// add r1, r1, #(r&3)*8
		EOP_MOV_REG2_ROR(reg,reg,1);		// mov reg, reg, ror r1
		if (mod == 2)
		     EOP_SUB_REG2_LSL(reg,reg,3,2);	// sub reg, reg, #0x01000000 << r2
		else EOP_ADD_REG2_LSL(reg,reg,3,2);
		EOP_RSB_IMM(1, 1, 0, 32);		// rsb r1, r1, #32
		EOP_MOV_REG2_ROR(reg,reg,1);		// mov reg, reg, ror r1
		hostreg_r[1] = hostreg_r[2] = hostreg_r[3] = -1;
	}
	else if (known_regb & (1 << (r + 8)))
	{
		int modulo = (1 << modulo_shift) - 1;
		if (mod == 2)
		     known_regs.r[r] = (known_regs.r[r] & ~modulo) | ((known_regs.r[r] - count) & modulo);
		else known_regs.r[r] = (known_regs.r[r] & ~modulo) | ((known_regs.r[r] + count) & modulo);
	}
	else
	{
		int reg = (r < 4) ? 8 : 9;
		int ror = ((r&3) + 1)*8 - (8 - modulo_shift);
		EOP_MOV_REG_ROR(reg,reg,ror);
		// {add|sub} reg, reg, #1<<shift
		EOP_C_DOP_IMM(A_COND_AL,(mod==2)?A_OP_SUB:A_OP_ADD,0,reg,reg, 8/2, count << (8 - modulo_shift));
		EOP_MOV_REG_ROR(reg,reg,32-ror);
	}
}

/* handle writes r0 to (rX). Trashes r1.
 * fortunately we can ignore modulo increment modes for writes. */
static void tr_rX_write(int op)
{
	if ((op&3) == 3)
	{
		int mod = (op>>2) & 3; // direct addressing
		tr_bank_write((op & 0x100) + mod);
	}
	else
	{
		int r = (op&3) | ((op>>6)&4);
		if (known_regb & (1 << (r + 8))) {
			tr_bank_write((op&0x100) | known_regs.r[r]);
		} else {
			int reg = (r < 4) ? 8 : 9;
			int ror = ((4 - (r&3))*8) & 0x1f;
			EOP_AND_IMM(1,reg,ror/2,0xff);			// and r1, r{7,8}, <mask>
			if (r >= 4)
				EOP_ORR_IMM(1,1,((ror-8)&0x1f)/2,1);		// orr r1, r1, 1<<shift
			if (r&3) EOP_ADD_REG_LSR(1,7,1, (r&3)*8-1);	// add r1, r7, r1, lsr #lsr
			else     EOP_ADD_REG_LSL(1,7,1,1);
			EOP_STRH_SIMPLE(0,1);				// strh r0, [r1]
			hostreg_r[1] = -1;
		}
		tr_ptrr_mod(r, (op>>2) & 3, 0, 1);
	}
}

/* read (rX) to r0. Trashes r1-r3. */
static void tr_rX_read(int r, int mod)
{
	if ((r&3) == 3)
	{
		tr_bank_read(((r << 6) & 0x100) + mod); // direct addressing
	}
	else
	{
		if (known_regb & (1 << (r + 8))) {
			tr_bank_read(((r << 6) & 0x100) | known_regs.r[r]);
		} else {
			int reg = (r < 4) ? 8 : 9;
			int ror = ((4 - (r&3))*8) & 0x1f;
			EOP_AND_IMM(1,reg,ror/2,0xff);			// and r1, r{7,8}, <mask>
			if (r >= 4)
				EOP_ORR_IMM(1,1,((ror-8)&0x1f)/2,1);		// orr r1, r1, 1<<shift
			if (r&3) EOP_ADD_REG_LSR(1,7,1, (r&3)*8-1);	// add r1, r7, r1, lsr #lsr
			else     EOP_ADD_REG_LSL(1,7,1,1);
			EOP_LDRH_SIMPLE(0,1);				// ldrh r0, [r1]
			hostreg_r[0] = hostreg_r[1] = -1;
		}
		tr_ptrr_mod(r, mod, 1, 1);
	}
}

/* read ((rX)) to r0. Trashes r1,r2. */
static void tr_rX_read2(int op)
{
	int r = (op&3) | ((op>>6)&4); // src

	if ((r&3) == 3) {
		tr_bank_read((op&0x100) | ((op>>2)&3));
	} else if (known_regb & (1 << (r+8))) {
		tr_bank_read((op&0x100) | known_regs.r[r]);
	} else {
		int reg = (r < 4) ? 8 : 9;
		int ror = ((4 - (r&3))*8) & 0x1f;
		EOP_AND_IMM(1,reg,ror/2,0xff);			// and r1, r{7,8}, <mask>
		if (r >= 4)
			EOP_ORR_IMM(1,1,((ror-8)&0x1f)/2,1);		// orr r1, r1, 1<<shift
		if (r&3) EOP_ADD_REG_LSR(1,7,1, (r&3)*8-1);	// add r1, r7, r1, lsr #lsr
		else     EOP_ADD_REG_LSL(1,7,1,1);
		EOP_LDRH_SIMPLE(0,1);				// ldrh r0, [r1]
	}
	EOP_LDR_IMM(2,7,0x48c);					// ptr_iram_rom
	EOP_ADD_REG_LSL(2,2,0,1);				// add  r2, r2, r0, lsl #1
	EOP_ADD_IMM(0,0,0,1);					// add  r0, r0, #1
	if ((r&3) == 3) {
		tr_bank_write((op&0x100) | ((op>>2)&3));
	} else if (known_regb & (1 << (r+8))) {
		tr_bank_write((op&0x100) | known_regs.r[r]);
	} else {
		EOP_STRH_SIMPLE(0,1);				// strh r0, [r1]
		hostreg_r[1] = -1;
	}
	EOP_LDRH_SIMPLE(0,2);					// ldrh r0, [r2]
	hostreg_r[0] = hostreg_r[2] = -1;
}

// check if AL is going to be used later in block
static int tr_predict_al_need(void)
{
	int tmpv, tmpv2, op, pc = known_regs.gr[SSP_PC].h;

	while (1)
	{
		op = PROGRAM(pc);
		switch (op >> 9)
		{
			// ld d, s
			case 0x00:
				tmpv2 = (op >> 4) & 0xf; // dst
				tmpv  = op & 0xf; // src
				if ((tmpv2 == SSP_A && tmpv == SSP_P) || tmpv2 == SSP_AL) // ld A, P; ld AL, *
					return 0;
				break;

			// ld (ri), s
			case 0x02:
			// ld ri, s
			case 0x0a:
			// OP a, s
			case 0x10: case 0x30: case 0x40: case 0x60: case 0x70:
				tmpv  = op & 0xf; // src
				if (tmpv == SSP_AL) // OP *, AL
					return 1;
				break;

			case 0x04:
			case 0x06:
			case 0x14:
			case 0x34:
			case 0x44:
			case 0x64:
			case 0x74: pc++; break;

			// call cond, addr
			case 0x24:
			// bra cond, addr
			case 0x26:
			// mod cond, op
			case 0x48:
			// mpys?
			case 0x1b:
			// mpya (rj), (ri), b
			case 0x4b: return 1;

			// mld (rj), (ri), b
			case 0x5b: return 0; // cleared anyway

			// and A, *
			case 0x50:
				tmpv  = op & 0xf; // src
				if (tmpv == SSP_AL) return 1;
			case 0x51: case 0x53: case 0x54: case 0x55: case 0x59: case 0x5c:
				return 0;
		}
		pc++;
	}
}


/* get ARM cond which would mean that SSP cond is satisfied. No trash. */
static int tr_cond_check(int op)
{
	int f = (op & 0x100) >> 8;
	switch (op&0xf0) {
		case 0x00: return A_COND_AL;	/* always true */
		case 0x50:			/* Z matches f(?) bit */
			if (dirty_regb & KRREG_ST) return f ? A_COND_EQ : A_COND_NE;
			EOP_TST_IMM(6, 0, 4);
			return f ? A_COND_NE : A_COND_EQ;
		case 0x70:			/* N matches f(?) bit */
			if (dirty_regb & KRREG_ST) return f ? A_COND_MI : A_COND_PL;
			EOP_TST_IMM(6, 0, 8);
			return f ? A_COND_NE : A_COND_EQ;
		default:
			elprintf(EL_ANOMALY, "unimplemented cond?\n");
			tr_unhandled();
			return 0;
	}
}

static int tr_neg_cond(int cond)
{
	switch (cond) {
		case A_COND_AL: elprintf(EL_ANOMALY, "neg for AL?\n"); exit(1);
		case A_COND_EQ: return A_COND_NE;
		case A_COND_NE: return A_COND_EQ;
		case A_COND_MI: return A_COND_PL;
		case A_COND_PL: return A_COND_MI;
		default:        elprintf(EL_ANOMALY, "bad cond for neg\n"); exit(1);
	}
	return 0;
}

static int tr_aop_ssp2arm(int op)
{
	switch (op) {
		case 1: return A_OP_SUB;
		case 3: return A_OP_CMP;
		case 4: return A_OP_ADD;
		case 5: return A_OP_AND;
		case 6: return A_OP_ORR;
		case 7: return A_OP_EOR;
	}

	tr_unhandled();
	return 0;
}

#ifdef __MACH__
/* spacial version of call for calling C needed on ios, since we use r9.. */
static void emith_call_c_func(void *target)
{
	EOP_STMFD_SP(A_R7M|A_R9M);
	emith_call(target);
	EOP_LDMFD_SP(A_R7M|A_R9M);
}
#else
#define emith_call_c_func emith_call
#endif

// -----------------------------------------------------

//@ r4:  XXYY
//@ r5:  A
//@ r6:  STACK and emu flags
//@ r7:  SSP context
//@ r10: P

// read general reg to r0. Trashes r1
static void tr_GR0_to_r0(int op)
{
	tr_mov16(0, 0xffff);
}

static void tr_X_to_r0(int op)
{
	if (hostreg_r[0] != (SSP_X<<16)) {
		EOP_MOV_REG_LSR(0, 4, 16);	// mov  r0, r4, lsr #16
		hostreg_r[0] = SSP_X<<16;
	}
}

static void tr_Y_to_r0(int op)
{
	if (hostreg_r[0] != (SSP_Y<<16)) {
		EOP_MOV_REG_SIMPLE(0, 4);	// mov  r0, r4
		hostreg_r[0] = SSP_Y<<16;
	}
}

static void tr_A_to_r0(int op)
{
	if (hostreg_r[0] != (SSP_A<<16)) {
		EOP_MOV_REG_LSR(0, 5, 16);	// mov  r0, r5, lsr #16  @ AH
		hostreg_r[0] = SSP_A<<16;
	}
}

static void tr_ST_to_r0(int op)
{
	// VR doesn't need much accuracy here..
	EOP_MOV_REG_LSR(0, 6, 4);		// mov  r0, r6, lsr #4
	EOP_AND_IMM(0, 0, 0, 0x67);		// and  r0, r0, #0x67
	hostreg_r[0] = -1;
}

static void tr_STACK_to_r0(int op)
{
	// 448
	EOP_SUB_IMM(6, 6,  8/2, 0x20);		// sub  r6, r6, #1<<29
	EOP_ADD_IMM(1, 7, 24/2, 0x04);		// add  r1, r7, 0x400
	EOP_ADD_IMM(1, 1, 0, 0x48);		// add  r1, r1, 0x048
	EOP_ADD_REG_LSR(1, 1, 6, 28);		// add  r1, r1, r6, lsr #28
	EOP_LDRH_SIMPLE(0, 1);			// ldrh r0, [r1]
	hostreg_r[0] = hostreg_r[1] = -1;
}

static void tr_PC_to_r0(int op)
{
	tr_mov16(0, known_regs.gr[SSP_PC].h);
}

static void tr_P_to_r0(int op)
{
	tr_flush_dirty_P();
	EOP_MOV_REG_LSR(0, 10, 16);		// mov  r0, r10, lsr #16
	hostreg_r[0] = -1;
}

static void tr_AL_to_r0(int op)
{
	if (op == 0x000f) {
		if (known_regb & KRREG_PMC) {
			known_regs.emu_status &= ~(SSP_PMC_SET|SSP_PMC_HAVE_ADDR);
		} else {
			EOP_LDR_IMM(0,7,0x484);			// ldr r1, [r7, #0x484] // emu_status
			EOP_BIC_IMM(0,0,0,SSP_PMC_SET|SSP_PMC_HAVE_ADDR);
			EOP_STR_IMM(0,7,0x484);
		}
	}

	if (hostreg_r[0] != (SSP_AL<<16)) {
		EOP_MOV_REG_SIMPLE(0, 5);	// mov  r0, r5
		hostreg_r[0] = SSP_AL<<16;
	}
}

static void tr_PMX_to_r0(int reg)
{
	if ((known_regb & KRREG_PMC) && (known_regs.emu_status & SSP_PMC_SET))
	{
		known_regs.pmac_read[reg] = known_regs.pmc.v;
		known_regs.emu_status &= ~SSP_PMC_SET;
		known_regb |= 1 << (20+reg);
		dirty_regb |= 1 << (20+reg);
		return;
	}

	if ((known_regb & KRREG_PMC) && (known_regb & (1 << (20+reg))))
	{
		u32 pmcv = known_regs.pmac_read[reg];
		int mode = pmcv>>16;
		known_regs.emu_status &= ~SSP_PMC_HAVE_ADDR;

		if      ((mode & 0xfff0) == 0x0800)
		{
			EOP_LDR_IMM(1,7,0x488);		// rom_ptr
			emith_move_r_imm(0, (pmcv&0xfffff)<<1);
			EOP_LDRH_REG(0,1,0);		// ldrh r0, [r1, r0]
			known_regs.pmac_read[reg] += 1;
		}
		else if ((mode & 0x47ff) == 0x0018) // DRAM
		{
			int inc = get_inc(mode);
			EOP_LDR_IMM(1,7,0x490);		// dram_ptr
			emith_move_r_imm(0, (pmcv&0xffff)<<1);
			EOP_LDRH_REG(0,1,0);		// ldrh r0, [r1, r0]
			if (reg == 4 && (pmcv == 0x187f03 || pmcv == 0x187f04)) // wait loop detection
			{
				int flag = (pmcv == 0x187f03) ? SSP_WAIT_30FE06 : SSP_WAIT_30FE08;
				tr_flush_dirty_ST();
				EOP_LDR_IMM(1,7,0x484);			// ldr r1, [r7, #0x484] // emu_status
				EOP_TST_REG_SIMPLE(0,0);
				EOP_C_DOP_IMM(A_COND_EQ,A_OP_SUB,0,11,11,22/2,1);	// subeq r11, r11, #1024
				EOP_C_DOP_IMM(A_COND_EQ,A_OP_ORR,0, 1, 1,24/2,flag>>8);	// orreq r1, r1, #SSP_WAIT_30FE08
				EOP_STR_IMM(1,7,0x484);			// str r1, [r7, #0x484] // emu_status
			}
			known_regs.pmac_read[reg] += inc;
		}
		else
		{
			tr_unhandled();
		}
		known_regs.pmc.v = known_regs.pmac_read[reg];
		//known_regb |= KRREG_PMC;
		dirty_regb |= KRREG_PMC;
		dirty_regb |= 1 << (20+reg);
		hostreg_r[0] = hostreg_r[1] = -1;
		return;
	}

	known_regb &= ~KRREG_PMC;
	dirty_regb &= ~KRREG_PMC;
	known_regb &= ~(1 << (20+reg));
	dirty_regb &= ~(1 << (20+reg));

	// call the C code to handle this
	tr_flush_dirty_ST();
	//tr_flush_dirty_pmcrs();
	tr_mov16(0, reg);
	emith_call_c_func(ssp_pm_read);
	hostreg_clear();
}

static void tr_PM0_to_r0(int op)
{
	tr_PMX_to_r0(0);
}

static void tr_PM1_to_r0(int op)
{
	tr_PMX_to_r0(1);
}

static void tr_PM2_to_r0(int op)
{
	tr_PMX_to_r0(2);
}

static void tr_XST_to_r0(int op)
{
	EOP_ADD_IMM(0, 7, 24/2, 4);	// add r0, r7, #0x400
	EOP_LDRH_IMM(0, 0, SSP_XST*4+2);
}

static void tr_PM4_to_r0(int op)
{
	tr_PMX_to_r0(4);
}

static void tr_PMC_to_r0(int op)
{
	if (known_regb & KRREG_PMC)
	{
		if (known_regs.emu_status & SSP_PMC_HAVE_ADDR) {
			known_regs.emu_status |= SSP_PMC_SET;
			known_regs.emu_status &= ~SSP_PMC_HAVE_ADDR;
			// do nothing - this is handled elsewhere
		} else {
			tr_mov16(0, known_regs.pmc.l);
			known_regs.emu_status |= SSP_PMC_HAVE_ADDR;
		}
	}
	else
	{
		EOP_LDR_IMM(1,7,0x484);			// ldr r1, [r7, #0x484] // emu_status
		tr_flush_dirty_ST();
		if (op != 0x000e)
			EOP_LDR_IMM(0, 7, 0x400+SSP_PMC*4);
		EOP_TST_IMM(1, 0, SSP_PMC_HAVE_ADDR);
		EOP_C_DOP_IMM(A_COND_EQ,A_OP_ORR,0, 1, 1, 0, SSP_PMC_HAVE_ADDR); // orreq r1, r1, #..
		EOP_C_DOP_IMM(A_COND_NE,A_OP_BIC,0, 1, 1, 0, SSP_PMC_HAVE_ADDR); // bicne r1, r1, #..
		EOP_C_DOP_IMM(A_COND_NE,A_OP_ORR,0, 1, 1, 0, SSP_PMC_SET);       // orrne r1, r1, #..
		EOP_STR_IMM(1,7,0x484);
		hostreg_r[0] = hostreg_r[1] = -1;
	}
}


typedef void (tr_read_func)(int op);

static tr_read_func *tr_read_funcs[16] =
{
	tr_GR0_to_r0,
	tr_X_to_r0,
	tr_Y_to_r0,
	tr_A_to_r0,
	tr_ST_to_r0,
	tr_STACK_to_r0,
	tr_PC_to_r0,
	tr_P_to_r0,
	tr_PM0_to_r0,
	tr_PM1_to_r0,
	tr_PM2_to_r0,
	tr_XST_to_r0,
	tr_PM4_to_r0,
	(tr_read_func *)tr_unhandled,
	tr_PMC_to_r0,
	tr_AL_to_r0
};


// write r0 to general reg handlers. Trashes r1
#define TR_WRITE_R0_TO_REG(reg) \
{ \
	hostreg_sspreg_changed(reg); \
	hostreg_r[0] = (reg)<<16; \
	if (const_val != -1) { \
		known_regs.gr[reg].h = const_val; \
		known_regb |= 1 << (reg); \
	} else { \
		known_regb &= ~(1 << (reg)); \
	} \
}

static void tr_r0_to_GR0(int const_val)
{
	// do nothing
}

static void tr_r0_to_X(int const_val)
{
	EOP_MOV_REG_LSL(4, 4, 16);		// mov  r4, r4, lsl #16
	EOP_MOV_REG_LSR(4, 4, 16);		// mov  r4, r4, lsr #16
	EOP_ORR_REG_LSL(4, 4, 0, 16);		// orr  r4, r4, r0, lsl #16
	dirty_regb |= KRREG_P;			// touching X or Y makes P dirty.
	TR_WRITE_R0_TO_REG(SSP_X);
}

static void tr_r0_to_Y(int const_val)
{
	EOP_MOV_REG_LSR(4, 4, 16);		// mov  r4, r4, lsr #16
	EOP_ORR_REG_LSL(4, 4, 0, 16);		// orr  r4, r4, r0, lsl #16
	EOP_MOV_REG_ROR(4, 4, 16);		// mov  r4, r4, ror #16
	dirty_regb |= KRREG_P;
	TR_WRITE_R0_TO_REG(SSP_Y);
}

static void tr_r0_to_A(int const_val)
{
	if (tr_predict_al_need()) {
		EOP_MOV_REG_LSL(5, 5, 16);	// mov  r5, r5, lsl #16
		EOP_MOV_REG_LSR(5, 5, 16);	// mov  r5, r5, lsr #16  @ AL
		EOP_ORR_REG_LSL(5, 5, 0, 16);	// orr  r5, r5, r0, lsl #16
	}
	else
		EOP_MOV_REG_LSL(5, 0, 16);
	TR_WRITE_R0_TO_REG(SSP_A);
}

static void tr_r0_to_ST(int const_val)
{
	// VR doesn't need much accuracy here..
	EOP_AND_IMM(1, 0,   0, 0x67);		// and   r1, r0, #0x67
	EOP_AND_IMM(6, 6, 8/2, 0xe0);		// and   r6, r6, #7<<29     @ preserve STACK
	EOP_ORR_REG_LSL(6, 6, 1, 4);		// orr   r6, r6, r1, lsl #4
	TR_WRITE_R0_TO_REG(SSP_ST);
	hostreg_r[1] = -1;
	dirty_regb &= ~KRREG_ST;
}

static void tr_r0_to_STACK(int const_val)
{
	// 448
	EOP_ADD_IMM(1, 7, 24/2, 0x04);		// add  r1, r7, 0x400
	EOP_ADD_IMM(1, 1, 0, 0x48);		// add  r1, r1, 0x048
	EOP_ADD_REG_LSR(1, 1, 6, 28);		// add  r1, r1, r6, lsr #28
	EOP_STRH_SIMPLE(0, 1);			// strh r0, [r1]
	EOP_ADD_IMM(6, 6,  8/2, 0x20);		// add  r6, r6, #1<<29
	hostreg_r[1] = -1;
}

static void tr_r0_to_PC(int const_val)
{
/*
 * do nothing - dispatcher will take care of this
	EOP_MOV_REG_LSL(1, 0, 16);		// mov  r1, r0, lsl #16
	EOP_STR_IMM(1,7,0x400+6*4);		// str  r1, [r7, #(0x400+6*8)]
	hostreg_r[1] = -1;
*/
}

static void tr_r0_to_AL(int const_val)
{
	EOP_MOV_REG_LSR(5, 5, 16);		// mov  r5, r5, lsr #16
	EOP_ORR_REG_LSL(5, 5, 0, 16);		// orr  r5, r5, r0, lsl #16
	EOP_MOV_REG_ROR(5, 5, 16);		// mov  r5, r5, ror #16
	hostreg_sspreg_changed(SSP_AL);
	if (const_val != -1) {
		known_regs.gr[SSP_A].l = const_val;
		known_regb |= 1 << SSP_AL;
	} else
		known_regb &= ~(1 << SSP_AL);
}

static void tr_r0_to_PMX(int reg)
{
	if ((known_regb & KRREG_PMC) && (known_regs.emu_status & SSP_PMC_SET))
	{
		known_regs.pmac_write[reg] = known_regs.pmc.v;
		known_regs.emu_status &= ~SSP_PMC_SET;
		known_regb |= 1 << (25+reg);
		dirty_regb |= 1 << (25+reg);
		return;
	}

	if ((known_regb & KRREG_PMC) && (known_regb & (1 << (25+reg))))
	{
		int mode, addr;

		known_regs.emu_status &= ~SSP_PMC_HAVE_ADDR;

		mode = known_regs.pmac_write[reg]>>16;
		addr = known_regs.pmac_write[reg]&0xffff;
		if      ((mode & 0x43ff) == 0x0018) // DRAM
		{
			int inc = get_inc(mode);
			if (mode & 0x0400) tr_unhandled();
			EOP_LDR_IMM(1,7,0x490);		// dram_ptr
			emith_move_r_imm(2, addr << 1);
			EOP_STRH_REG(0,1,2);		// strh r0, [r1, r2]
			known_regs.pmac_write[reg] += inc;
		}
		else if ((mode & 0xfbff) == 0x4018) // DRAM, cell inc
		{
			if (mode & 0x0400) tr_unhandled();
			EOP_LDR_IMM(1,7,0x490);		// dram_ptr
			emith_move_r_imm(2, addr << 1);
			EOP_STRH_REG(0,1,2);		// strh r0, [r1, r2]
			known_regs.pmac_write[reg] += (addr&1) ? 31 : 1;
		}
		else if ((mode & 0x47ff) == 0x001c) // IRAM
		{
			int inc = get_inc(mode);
			EOP_LDR_IMM(1,7,0x48c);		// iram_ptr
			emith_move_r_imm(2, (addr&0x3ff) << 1);
			EOP_STRH_REG(0,1,2);		// strh r0, [r1, r2]
			EOP_MOV_IMM(1,0,1);
			EOP_STR_IMM(1,7,0x494);		// iram_dirty
			known_regs.pmac_write[reg] += inc;
		}
		else
			tr_unhandled();

		known_regs.pmc.v = known_regs.pmac_write[reg];
		//known_regb |= KRREG_PMC;
		dirty_regb |= KRREG_PMC;
		dirty_regb |= 1 << (25+reg);
		hostreg_r[1] = hostreg_r[2] = -1;
		return;
	}

	known_regb &= ~KRREG_PMC;
	dirty_regb &= ~KRREG_PMC;
	known_regb &= ~(1 << (25+reg));
	dirty_regb &= ~(1 << (25+reg));

	// call the C code to handle this
	tr_flush_dirty_ST();
	//tr_flush_dirty_pmcrs();
	tr_mov16(1, reg);
	emith_call_c_func(ssp_pm_write);
	hostreg_clear();
}

static void tr_r0_to_PM0(int const_val)
{
	tr_r0_to_PMX(0);
}

static void tr_r0_to_PM1(int const_val)
{
	tr_r0_to_PMX(1);
}

static void tr_r0_to_PM2(int const_val)
{
	tr_r0_to_PMX(2);
}

static void tr_r0_to_PM4(int const_val)
{
	tr_r0_to_PMX(4);
}

static void tr_r0_to_PMC(int const_val)
{
	if ((known_regb & KRREG_PMC) && const_val != -1)
	{
		if (known_regs.emu_status & SSP_PMC_HAVE_ADDR) {
			known_regs.emu_status |= SSP_PMC_SET;
			known_regs.emu_status &= ~SSP_PMC_HAVE_ADDR;
			known_regs.pmc.h = const_val;
		} else {
			known_regs.emu_status |= SSP_PMC_HAVE_ADDR;
			known_regs.pmc.l = const_val;
		}
	}
	else
	{
		tr_flush_dirty_ST();
		if (known_regb & KRREG_PMC) {
			emith_move_r_imm(1, known_regs.pmc.v);
			EOP_STR_IMM(1,7,0x400+SSP_PMC*4);
			known_regb &= ~KRREG_PMC;
			dirty_regb &= ~KRREG_PMC;
		}
		EOP_LDR_IMM(1,7,0x484);			// ldr r1, [r7, #0x484] // emu_status
		EOP_ADD_IMM(2,7,24/2,4);		// add r2, r7, #0x400
		EOP_TST_IMM(1, 0, SSP_PMC_HAVE_ADDR);
		EOP_C_AM3_IMM(A_COND_EQ,1,0,2,0,0,1,SSP_PMC*4);		// strxx r0, [r2, #SSP_PMC]
		EOP_C_AM3_IMM(A_COND_NE,1,0,2,0,0,1,SSP_PMC*4+2);
		EOP_C_DOP_IMM(A_COND_EQ,A_OP_ORR,0, 1, 1, 0, SSP_PMC_HAVE_ADDR); // orreq r1, r1, #..
		EOP_C_DOP_IMM(A_COND_NE,A_OP_BIC,0, 1, 1, 0, SSP_PMC_HAVE_ADDR); // bicne r1, r1, #..
		EOP_C_DOP_IMM(A_COND_NE,A_OP_ORR,0, 1, 1, 0, SSP_PMC_SET);       // orrne r1, r1, #..
		EOP_STR_IMM(1,7,0x484);
		hostreg_r[1] = hostreg_r[2] = -1;
	}
}

typedef void (tr_write_func)(int const_val);

static tr_write_func *tr_write_funcs[16] =
{
	tr_r0_to_GR0,
	tr_r0_to_X,
	tr_r0_to_Y,
	tr_r0_to_A,
	tr_r0_to_ST,
	tr_r0_to_STACK,
	tr_r0_to_PC,
	(tr_write_func *)tr_unhandled,
	tr_r0_to_PM0,
	tr_r0_to_PM1,
	tr_r0_to_PM2,
	(tr_write_func *)tr_unhandled,
	tr_r0_to_PM4,
	(tr_write_func *)tr_unhandled,
	tr_r0_to_PMC,
	tr_r0_to_AL
};

static void tr_mac_load_XY(int op)
{
	tr_rX_read(op&3, (op>>2)&3); // X
	EOP_MOV_REG_LSL(4, 0, 16);
	tr_rX_read(((op>>4)&3)|4, (op>>6)&3); // Y
	EOP_ORR_REG_SIMPLE(4, 0);
	dirty_regb |= KRREG_P;
	hostreg_sspreg_changed(SSP_X);
	hostreg_sspreg_changed(SSP_Y);
	known_regb &= ~KRREG_X;
	known_regb &= ~KRREG_Y;
}

// -----------------------------------------------------

static int tr_detect_set_pm(unsigned int op, int *pc, int imm)
{
	u32 pmcv, tmpv;
	if (!((op&0xfef0) == 0x08e0 && (PROGRAM(*pc)&0xfef0) == 0x08e0)) return 0;

	// programming PMC:
	// ldi PMC, imm1
	// ldi PMC, imm2
	(*pc)++;
	pmcv = imm | (PROGRAM((*pc)++) << 16);
	known_regs.pmc.v = pmcv;
	known_regb |= KRREG_PMC;
	dirty_regb |= KRREG_PMC;
	known_regs.emu_status |= SSP_PMC_SET;
	n_in_ops++;

	// check for possible reg programming
	tmpv = PROGRAM(*pc);
	if ((tmpv & 0xfff8) == 0x08 || (tmpv & 0xff8f) == 0x80)
	{
		int is_write = (tmpv & 0xff8f) == 0x80;
		int reg = is_write ? ((tmpv>>4)&0x7) : (tmpv&0x7);
		if (reg > 4) tr_unhandled();
		if ((tmpv & 0x0f) != 0 && (tmpv & 0xf0) != 0) tr_unhandled();
		if (is_write)
			known_regs.pmac_write[reg] = pmcv;
		else
			known_regs.pmac_read[reg] = pmcv;
		known_regb |= is_write ? (1 << (reg+25)) : (1 << (reg+20));
		dirty_regb |= is_write ? (1 << (reg+25)) : (1 << (reg+20));
		known_regs.emu_status &= ~SSP_PMC_SET;
		(*pc)++;
		n_in_ops++;
		return 5;
	}

	tr_unhandled();
	return 4;
}

static const short pm0_block_seq[] = { 0x0880, 0, 0x0880, 0, 0x0840, 0x60 };

static int tr_detect_pm0_block(unsigned int op, int *pc, int imm)
{
	// ldi ST, 0
	// ldi PM0, 0
	// ldi PM0, 0
	// ldi ST, 60h
	unsigned short *pp;
	if (op != 0x0840 || imm != 0) return 0;
	pp = PROGRAM_P(*pc);
	if (memcmp(pp, pm0_block_seq, sizeof(pm0_block_seq)) != 0) return 0;

	EOP_AND_IMM(6, 6, 8/2, 0xe0);		// and   r6, r6, #7<<29     @ preserve STACK
	EOP_ORR_IMM(6, 6, 24/2, 6);		// orr   r6, r6, 0x600
	hostreg_sspreg_changed(SSP_ST);
	known_regs.gr[SSP_ST].h = 0x60;
	known_regb |= 1 << SSP_ST;
	dirty_regb &= ~KRREG_ST;
	(*pc) += 3*2;
	n_in_ops += 3;
	return 4*2;
}

static int tr_detect_rotate(unsigned int op, int *pc, int imm)
{
	// @ 3DA2 and 426A
	// ld PMC, (r3|00)
	// ld (r3|00), PMC
	// ld -, AL
	if (op != 0x02e3 || PROGRAM(*pc) != 0x04e3 || PROGRAM(*pc + 1) != 0x000f) return 0;

	tr_bank_read(0);
	EOP_MOV_REG_LSL(0, 0, 4);
	EOP_ORR_REG_LSR(0, 0, 0, 16);
	tr_bank_write(0);
	(*pc) += 2;
	n_in_ops += 2;
	return 3;
}

// -----------------------------------------------------

static int translate_op(unsigned int op, int *pc, int imm, int *end_cond, int *jump_pc)
{
	u32 tmpv, tmpv2, tmpv3;
	int ret = 0;
	known_regs.gr[SSP_PC].h = *pc;

	switch (op >> 9)
	{
		// ld d, s
		case 0x00:
			if (op == 0) { ret++; break; } // nop
			tmpv  = op & 0xf; // src
			tmpv2 = (op >> 4) & 0xf; // dst
			if (tmpv2 == SSP_A && tmpv == SSP_P) { // ld A, P
				tr_flush_dirty_P();
				EOP_MOV_REG_SIMPLE(5, 10);
				hostreg_sspreg_changed(SSP_A);
				known_regb &= ~(KRREG_A|KRREG_AL);
				ret++; break;
			}
			tr_read_funcs[tmpv](op);
			tr_write_funcs[tmpv2]((known_regb & (1 << tmpv)) ? known_regs.gr[tmpv].h : -1);
			if (tmpv2 == SSP_PC) {
				ret |= 0x10000;
				*end_cond = -A_COND_AL;
			}
			ret++; break;

		// ld d, (ri)
		case 0x01: {
			int r = (op&3) | ((op>>6)&4);
			int mod = (op>>2)&3;
			tmpv = (op >> 4) & 0xf; // dst
			ret = tr_detect_rotate(op, pc, imm);
			if (ret > 0) break;
			if (tmpv != 0)
				tr_rX_read(r, mod);
			else {
				int cnt = 1;
				while (PROGRAM(*pc) == op) {
					(*pc)++; cnt++; ret++;
					n_in_ops++;
				}
				tr_ptrr_mod(r, mod, 1, cnt); // skip
			}
			tr_write_funcs[tmpv](-1);
			if (tmpv == SSP_PC) {
				ret |= 0x10000;
				*end_cond = -A_COND_AL;
			}
			ret++; break;
		}

		// ld (ri), s
		case 0x02:
			tmpv = (op >> 4) & 0xf; // src
			tr_read_funcs[tmpv](op);
			tr_rX_write(op);
			ret++; break;

		// ld a, adr
		case 0x03:
			tr_bank_read(op&0x1ff);
			tr_r0_to_A(-1);
			ret++; break;

		// ldi d, imm
		case 0x04:
			tmpv = (op & 0xf0) >> 4; // dst
			ret = tr_detect_pm0_block(op, pc, imm);
			if (ret > 0) break;
			ret = tr_detect_set_pm(op, pc, imm);
			if (ret > 0) break;
			tr_mov16(0, imm);
			tr_write_funcs[tmpv](imm);
			if (tmpv == SSP_PC) {
				ret |= 0x10000;
				*jump_pc = imm;
			}
			ret += 2; break;

		// ld d, ((ri))
		case 0x05:
			tmpv2 = (op >> 4) & 0xf;  // dst
			tr_rX_read2(op);
			tr_write_funcs[tmpv2](-1);
			if (tmpv2 == SSP_PC) {
				ret |= 0x10000;
				*end_cond = -A_COND_AL;
			}
			ret += 3; break;

		// ldi (ri), imm
		case 0x06:
			tr_mov16(0, imm);
			tr_rX_write(op);
			ret += 2; break;

		// ld adr, a
		case 0x07:
			tr_A_to_r0(op);
			tr_bank_write(op&0x1ff);
			ret++; break;

		// ld d, ri
		case 0x09: {
			int r;
			r = (op&3) | ((op>>6)&4); // src
			tmpv2 = (op >> 4) & 0xf;  // dst
			if ((r&3) == 3) tr_unhandled();

			if (known_regb & (1 << (r+8))) {
				tr_mov16(0, known_regs.r[r]);
				tr_write_funcs[tmpv2](known_regs.r[r]);
			} else {
				int reg = (r < 4) ? 8 : 9;
				if (r&3) EOP_MOV_REG_LSR(0, reg, (r&3)*8);	// mov r0, r{7,8}, lsr #lsr
				EOP_AND_IMM(0, (r&3)?0:reg, 0, 0xff);		// and r0, r{7,8}, <mask>
				hostreg_r[0] = -1;
				tr_write_funcs[tmpv2](-1);
			}
			ret++; break;
		}

		// ld ri, s
		case 0x0a: {
			int r;
			r = (op&3) | ((op>>6)&4); // dst
			tmpv = (op >> 4) & 0xf;   // src
			if ((r&3) == 3) tr_unhandled();

			if (known_regb & (1 << tmpv)) {
				known_regs.r[r] = known_regs.gr[tmpv].h;
				known_regb |= 1 << (r + 8);
				dirty_regb |= 1 << (r + 8);
			} else {
				int reg = (r < 4) ? 8 : 9;
				int ror = ((4 - (r&3))*8) & 0x1f;
				tr_read_funcs[tmpv](op);
				EOP_BIC_IMM(reg, reg, ror/2, 0xff);		// bic r{7,8}, r{7,8}, <mask>
				EOP_AND_IMM(0, 0, 0, 0xff);			// and r0, r0, 0xff
				EOP_ORR_REG_LSL(reg, reg, 0, (r&3)*8);		// orr r{7,8}, r{7,8}, r0, lsl #lsl
				hostreg_r[0] = -1;
				known_regb &= ~(1 << (r+8));
				dirty_regb &= ~(1 << (r+8));
			}
			ret++; break;
		}

		// ldi ri, simm
		case 0x0c: case 0x0d: case 0x0e: case 0x0f:
			tmpv = (op>>8)&7;
			known_regs.r[tmpv] = op;
			known_regb |= 1 << (tmpv + 8);
			dirty_regb |= 1 << (tmpv + 8);
			ret++; break;

		// call cond, addr
		case 0x24: {
			u32 *jump_op = NULL;
			tmpv = tr_cond_check(op);
			if (tmpv != A_COND_AL) {
				jump_op = tcache_ptr;
				EOP_MOV_IMM(0, 0, 0); // placeholder for branch
			}
			tr_mov16(0, *pc);
			tr_r0_to_STACK(*pc);
			if (tmpv != A_COND_AL) {
				u32 *real_ptr = tcache_ptr;
				tcache_ptr = jump_op;
				EOP_C_B(tr_neg_cond(tmpv),0,real_ptr - jump_op - 2);
				tcache_ptr = real_ptr;
			}
			tr_mov16_cond(tmpv, 0, imm);
			if (tmpv != A_COND_AL)
				tr_mov16_cond(tr_neg_cond(tmpv), 0, *pc);
			tr_r0_to_PC(tmpv == A_COND_AL ? imm : -1);
			ret |= 0x10000;
			*end_cond = tmpv;
			*jump_pc = imm;
			ret += 2; break;
		}

		// ld d, (a)
		case 0x25:
			tmpv2 = (op >> 4) & 0xf;  // dst
			tr_A_to_r0(op);
			EOP_LDR_IMM(1,7,0x48c);					// ptr_iram_rom
			EOP_ADD_REG_LSL(0,1,0,1);				// add  r0, r1, r0, lsl #1
			EOP_LDRH_SIMPLE(0,0);					// ldrh r0, [r0]
			hostreg_r[0] = hostreg_r[1] = -1;
			tr_write_funcs[tmpv2](-1);
			if (tmpv2 == SSP_PC) {
				ret |= 0x10000;
				*end_cond = -A_COND_AL;
			}
			ret += 3; break;

		// bra cond, addr
		case 0x26:
			tmpv = tr_cond_check(op);
			tr_mov16_cond(tmpv, 0, imm);
			if (tmpv != A_COND_AL)
				tr_mov16_cond(tr_neg_cond(tmpv), 0, *pc);
			tr_r0_to_PC(tmpv == A_COND_AL ? imm : -1);
			ret |= 0x10000;
			*end_cond = tmpv;
			*jump_pc = imm;
			ret += 2; break;

		// mod cond, op
		case 0x48: {
			// check for repeats of this op
			tmpv = 1; // count
			while (PROGRAM(*pc) == op && (op & 7) != 6) {
				(*pc)++; tmpv++;
				n_in_ops++;
			}
			if ((op&0xf0) != 0) // !always
				tr_make_dirty_ST();

			tmpv2 = tr_cond_check(op);
			switch (op & 7) {
				case 2: EOP_C_DOP_REG_XIMM(tmpv2,A_OP_MOV,1,0,5,tmpv,A_AM1_ASR,5); break; // shr (arithmetic)
				case 3: EOP_C_DOP_REG_XIMM(tmpv2,A_OP_MOV,1,0,5,tmpv,A_AM1_LSL,5); break; // shl
				case 6: EOP_C_DOP_IMM(tmpv2,A_OP_RSB,1,5,5,0,0); break; // neg
				case 7: EOP_C_DOP_REG_XIMM(tmpv2,A_OP_EOR,0,5,1,31,A_AM1_ASR,5); // eor  r1, r5, r5, asr #31
					EOP_C_DOP_REG_XIMM(tmpv2,A_OP_ADD,1,1,5,31,A_AM1_LSR,5); // adds r5, r1, r5, lsr #31
					hostreg_r[1] = -1; break; // abs
				default: tr_unhandled();
			}

			hostreg_sspreg_changed(SSP_A);
			dirty_regb |=  KRREG_ST;
			known_regb &= ~KRREG_ST;
			known_regb &= ~(KRREG_A|KRREG_AL);
			ret += tmpv; break;
		}

		// mpys?
		case 0x1b:
			tr_flush_dirty_P();
			tr_mac_load_XY(op);
			tr_make_dirty_ST();
			EOP_C_DOP_REG_XIMM(A_COND_AL,A_OP_SUB,1,5,5,0,A_AM1_LSL,10); // subs r5, r5, r10
			hostreg_sspreg_changed(SSP_A);
			known_regb &= ~(KRREG_A|KRREG_AL);
			dirty_regb |= KRREG_ST;
			ret++; break;

		// mpya (rj), (ri), b
		case 0x4b:
			tr_flush_dirty_P();
			tr_mac_load_XY(op);
			tr_make_dirty_ST();
			EOP_C_DOP_REG_XIMM(A_COND_AL,A_OP_ADD,1,5,5,0,A_AM1_LSL,10); // adds r5, r5, r10
			hostreg_sspreg_changed(SSP_A);
			known_regb &= ~(KRREG_A|KRREG_AL);
			dirty_regb |= KRREG_ST;
			ret++; break;

		// mld (rj), (ri), b
		case 0x5b:
			EOP_C_DOP_IMM(A_COND_AL,A_OP_MOV,1,0,5,0,0); // movs r5, #0
			hostreg_sspreg_changed(SSP_A);
			known_regs.gr[SSP_A].v = 0;
			known_regb |= (KRREG_A|KRREG_AL);
			dirty_regb |= KRREG_ST;
			tr_mac_load_XY(op);
			ret++; break;

		// OP a, s
		case 0x10:
		case 0x30:
		case 0x40:
		case 0x50:
		case 0x60:
		case 0x70:
			tmpv = op & 0xf; // src
			tmpv2 = tr_aop_ssp2arm(op>>13); // op
			tmpv3 = (tmpv2 == A_OP_CMP) ? 0 : 5;
			if (tmpv == SSP_P) {
				tr_flush_dirty_P();
				EOP_C_DOP_REG_XIMM(A_COND_AL,tmpv2,1,5,tmpv3, 0,A_AM1_LSL,10); // OPs r5, r5, r10
			} else if (tmpv == SSP_A) {
				EOP_C_DOP_REG_XIMM(A_COND_AL,tmpv2,1,5,tmpv3, 0,A_AM1_LSL, 5); // OPs r5, r5, r5
			} else {
				tr_read_funcs[tmpv](op);
				EOP_C_DOP_REG_XIMM(A_COND_AL,tmpv2,1,5,tmpv3,16,A_AM1_LSL, 0); // OPs r5, r5, r0, lsl #16
			}
			hostreg_sspreg_changed(SSP_A);
			known_regb &= ~(KRREG_A|KRREG_AL|KRREG_ST);
			dirty_regb |= KRREG_ST;
			ret++; break;

		// OP a, (ri)
		case 0x11:
		case 0x31:
		case 0x41:
		case 0x51:
		case 0x61:
		case 0x71:
			tmpv2 = tr_aop_ssp2arm(op>>13); // op
			tmpv3 = (tmpv2 == A_OP_CMP) ? 0 : 5;
			tr_rX_read((op&3)|((op>>6)&4), (op>>2)&3);
			EOP_C_DOP_REG_XIMM(A_COND_AL,tmpv2,1,5,tmpv3,16,A_AM1_LSL,0);	// OPs r5, r5, r0, lsl #16
			hostreg_sspreg_changed(SSP_A);
			known_regb &= ~(KRREG_A|KRREG_AL|KRREG_ST);
			dirty_regb |= KRREG_ST;
			ret++; break;

		// OP a, adr
		case 0x13:
		case 0x33:
		case 0x43:
		case 0x53:
		case 0x63:
		case 0x73:
			tmpv2 = tr_aop_ssp2arm(op>>13); // op
			tmpv3 = (tmpv2 == A_OP_CMP) ? 0 : 5;
			tr_bank_read(op&0x1ff);
			EOP_C_DOP_REG_XIMM(A_COND_AL,tmpv2,1,5,tmpv3,16,A_AM1_LSL,0);	// OPs r5, r5, r0, lsl #16
			hostreg_sspreg_changed(SSP_A);
			known_regb &= ~(KRREG_A|KRREG_AL|KRREG_ST);
			dirty_regb |= KRREG_ST;
			ret++; break;

		// OP a, imm
		case 0x14:
		case 0x34:
		case 0x44:
		case 0x54:
		case 0x64:
		case 0x74:
			tmpv = (op & 0xf0) >> 4;
			tmpv2 = tr_aop_ssp2arm(op>>13); // op
			tmpv3 = (tmpv2 == A_OP_CMP) ? 0 : 5;
			tr_mov16(0, imm);
			EOP_C_DOP_REG_XIMM(A_COND_AL,tmpv2,1,5,tmpv3,16,A_AM1_LSL,0);	// OPs r5, r5, r0, lsl #16
			hostreg_sspreg_changed(SSP_A);
			known_regb &= ~(KRREG_A|KRREG_AL|KRREG_ST);
			dirty_regb |= KRREG_ST;
			ret += 2; break;

		// OP a, ((ri))
		case 0x15:
		case 0x35:
		case 0x45:
		case 0x55:
		case 0x65:
		case 0x75:
			tmpv2 = tr_aop_ssp2arm(op>>13); // op
			tmpv3 = (tmpv2 == A_OP_CMP) ? 0 : 5;
			tr_rX_read2(op);
			EOP_C_DOP_REG_XIMM(A_COND_AL,tmpv2,1,5,tmpv3,16,A_AM1_LSL,0);	// OPs r5, r5, r0, lsl #16
			hostreg_sspreg_changed(SSP_A);
			known_regb &= ~(KRREG_A|KRREG_AL|KRREG_ST);
			dirty_regb |= KRREG_ST;
			ret += 3; break;

		// OP a, ri
		case 0x19:
		case 0x39:
		case 0x49:
		case 0x59:
		case 0x69:
		case 0x79: {
			int r;
			tmpv2 = tr_aop_ssp2arm(op>>13); // op
			tmpv3 = (tmpv2 == A_OP_CMP) ? 0 : 5;
			r = (op&3) | ((op>>6)&4); // src
			if ((r&3) == 3) tr_unhandled();

			if (known_regb & (1 << (r+8))) {
				EOP_C_DOP_IMM(A_COND_AL,tmpv2,1,5,tmpv3,16/2,known_regs.r[r]);	// OPs r5, r5, #val<<16
			} else {
				int reg = (r < 4) ? 8 : 9;
				if (r&3) EOP_MOV_REG_LSR(0, reg, (r&3)*8);	// mov r0, r{7,8}, lsr #lsr
				EOP_AND_IMM(0, (r&3)?0:reg, 0, 0xff);		// and r0, r{7,8}, <mask>
				EOP_C_DOP_REG_XIMM(A_COND_AL,tmpv2,1,5,tmpv3,16,A_AM1_LSL,0);	// OPs r5, r5, r0, lsl #16
				hostreg_r[0] = -1;
			}
			hostreg_sspreg_changed(SSP_A);
			known_regb &= ~(KRREG_A|KRREG_AL|KRREG_ST);
			dirty_regb |= KRREG_ST;
			ret++; break;
		}

		// OP simm
		case 0x1c:
		case 0x3c:
		case 0x4c:
		case 0x5c:
		case 0x6c:
		case 0x7c:
			tmpv2 = tr_aop_ssp2arm(op>>13); // op
			tmpv3 = (tmpv2 == A_OP_CMP) ? 0 : 5;
			EOP_C_DOP_IMM(A_COND_AL,tmpv2,1,5,tmpv3,16/2,op & 0xff);	// OPs r5, r5, #val<<16
			hostreg_sspreg_changed(SSP_A);
			known_regb &= ~(KRREG_A|KRREG_AL|KRREG_ST);
			dirty_regb |= KRREG_ST;
			ret++; break;
	}

	n_in_ops++;

	return ret;
}

static void emit_block_prologue(void)
{
	// check if there are enough cycles..
	// note: r0 must contain PC of current block
	EOP_CMP_IMM(11,0,0);			// cmp r11, #0
	emith_jump_cond(A_COND_LE, ssp_drc_end);
}

/* cond:
 * >0: direct (un)conditional jump
 * <0: indirect jump
 */
static void *emit_block_epilogue(int cycles, int cond, int pc, int end_pc)
{
	void *end_ptr = NULL;

	if (cycles > 0xff) {
		elprintf(EL_ANOMALY, "large cycle count: %i\n", cycles);
		cycles = 0xff;
	}
	EOP_SUB_IMM(11,11,0,cycles);		// sub r11, r11, #cycles

	if (cond < 0 || (end_pc >= 0x400 && pc < 0x400)) {
		// indirect jump, or rom -> iram jump, must use dispatcher
		emith_jump(ssp_drc_next);
	}
	else if (cond == A_COND_AL) {
		u32 *target = (pc < 0x400) ?
			ssp_block_table_iram[ssp->drc.iram_context * SSP_BLOCKTAB_IRAM_ONE + pc] :
			ssp_block_table[pc];
		if (target != NULL)
			emith_jump(target);
		else {
			int ops = emith_jump(ssp_drc_next);
			end_ptr = tcache_ptr;
			// cause the next block to be emitted over jump instruction
			tcache_ptr -= ops;
		}
	}
	else {
		u32 *target1 = (pc     < 0x400) ?
			ssp_block_table_iram[ssp->drc.iram_context * SSP_BLOCKTAB_IRAM_ONE + pc] :
			ssp_block_table[pc];
		u32 *target2 = (end_pc < 0x400) ?
			ssp_block_table_iram[ssp->drc.iram_context * SSP_BLOCKTAB_IRAM_ONE + end_pc] :
			ssp_block_table[end_pc];
		if (target1 != NULL)
		     emith_jump_cond(cond, target1);
		if (target2 != NULL)
		     emith_jump_cond(tr_neg_cond(cond), target2); // neg_cond, to be able to swap jumps if needed
#ifndef __EPOC32__
		// emit patchable branches
		if (target1 == NULL)
			emith_call_cond(cond, ssp_drc_next_patch);
		if (target2 == NULL)
			emith_call_cond(tr_neg_cond(cond), ssp_drc_next_patch);
#else
		// won't patch indirect jumps
		if (target1 == NULL || target2 == NULL)
			emith_jump(ssp_drc_next);
#endif
	}

	if (end_ptr == NULL)
		end_ptr = tcache_ptr;

	return end_ptr;
}

void *ssp_translate_block(int pc)
{
	unsigned int op, op1, imm, ccount = 0;
	unsigned int *block_start, *block_end;
	int ret, end_cond = A_COND_AL, jump_pc = -1;

	//printf("translate %04x -> %04x\n", pc<<1, (tcache_ptr-tcache)<<2);

	block_start = tcache_ptr;
	known_regb = 0;
	dirty_regb = KRREG_P;
	known_regs.emu_status = 0;
	hostreg_clear();

	emit_block_prologue();

	for (; ccount < 100;)
	{
		op = PROGRAM(pc++);
		op1 = op >> 9;
		imm = (u32)-1;

		if ((op1 & 0xf) == 4 || (op1 & 0xf) == 6)
			imm = PROGRAM(pc++); // immediate

		ret = translate_op(op, &pc, imm, &end_cond, &jump_pc);
		if (ret <= 0)
		{
			elprintf(EL_ANOMALY, "NULL func! op=%08x (%02x)\n", op, op1);
			//exit(1);
		}

		ccount += ret & 0xffff;
		if (ret & 0x10000) break;
	}

	if (ccount >= 100) {
		end_cond = A_COND_AL;
		jump_pc = pc;
		emith_move_r_imm(0, pc);
	}

	tr_flush_dirty_prs();
	tr_flush_dirty_ST();
	tr_flush_dirty_pmcrs();
	block_end = emit_block_epilogue(ccount, end_cond, jump_pc, pc);

	if (tcache_ptr - (u32 *)tcache > DRC_TCACHE_SIZE/4) {
		elprintf(EL_ANOMALY|EL_STATUS|EL_SVP, "tcache overflow!\n");
		fflush(stdout);
		exit(1);
	}

	// stats
	nblocks++;
	//printf("%i blocks, %i bytes, k=%.3f\n", nblocks, (tcache_ptr - tcache)*4,
	//	(double)(tcache_ptr - tcache) / (double)n_in_ops);

#ifdef DUMP_BLOCK
	{
		FILE *f = fopen("tcache.bin", "wb");
		fwrite(tcache, 1, (tcache_ptr - tcache)*4, f);
		fclose(f);
	}
	printf("dumped tcache.bin\n");
	exit(0);
#endif

#ifdef __arm__
	cache_flush_d_inval_i(block_start, block_end);
#endif

	return block_start;
}



// -----------------------------------------------------

static void ssp1601_state_load(void)
{
	ssp->drc.iram_dirty = 1;
	ssp->drc.iram_context = 0;
}

void ssp1601_dyn_exit(void)
{
	free(ssp_block_table);
	free(ssp_block_table_iram);
	ssp_block_table = ssp_block_table_iram = NULL;

	drc_cmn_cleanup();
}

int ssp1601_dyn_startup(void)
{
	drc_cmn_init();

	ssp_block_table = calloc(sizeof(ssp_block_table[0]), SSP_BLOCKTAB_ENTS);
	if (ssp_block_table == NULL)
		return -1;
	ssp_block_table_iram = calloc(sizeof(ssp_block_table_iram[0]), SSP_BLOCKTAB_IRAM_ENTS);
	if (ssp_block_table_iram == NULL) {
		free(ssp_block_table);
		return -1;
	}

	memset(tcache, 0, DRC_TCACHE_SIZE);
	tcache_ptr = (void *)tcache;

	PicoLoadStateHook = ssp1601_state_load;

	n_in_ops = 0;
#ifdef __arm__
	// hle'd blocks
	ssp_block_table[0x800/2] = (void *) ssp_hle_800;
	ssp_block_table[0x902/2] = (void *) ssp_hle_902;
	ssp_block_table_iram[ 7 * SSP_BLOCKTAB_IRAM_ONE + 0x030/2] = (void *) ssp_hle_07_030;
	ssp_block_table_iram[ 7 * SSP_BLOCKTAB_IRAM_ONE + 0x036/2] = (void *) ssp_hle_07_036;
	ssp_block_table_iram[ 7 * SSP_BLOCKTAB_IRAM_ONE + 0x6d6/2] = (void *) ssp_hle_07_6d6;
	ssp_block_table_iram[11 * SSP_BLOCKTAB_IRAM_ONE + 0x12c/2] = (void *) ssp_hle_11_12c;
	ssp_block_table_iram[11 * SSP_BLOCKTAB_IRAM_ONE + 0x384/2] = (void *) ssp_hle_11_384;
	ssp_block_table_iram[11 * SSP_BLOCKTAB_IRAM_ONE + 0x38a/2] = (void *) ssp_hle_11_38a;
#endif

	return 0;
}


void ssp1601_dyn_reset(ssp1601_t *ssp)
{
	ssp1601_reset(ssp);
	ssp->drc.iram_dirty = 1;
	ssp->drc.iram_context = 0;
	// must do this here because ssp is not available @ startup()
	ssp->drc.ptr_rom = (u32) Pico.rom;
	ssp->drc.ptr_iram_rom = (u32) svp->iram_rom;
	ssp->drc.ptr_dram = (u32) svp->dram;
	ssp->drc.ptr_btable = (u32) ssp_block_table;
	ssp->drc.ptr_btable_iram = (u32) ssp_block_table_iram;

	// prevent new versions of IRAM from appearing
	memset(svp->iram_rom, 0, 0x800);
}


void ssp1601_dyn_run(int cycles)
{
	if (ssp->emu_status & SSP_WAIT_MASK) return;

#ifdef DUMP_BLOCK
	ssp_translate_block(DUMP_BLOCK >> 1);
#endif
#ifdef __arm__
	ssp_drc_entry(ssp, cycles);
#endif
}

