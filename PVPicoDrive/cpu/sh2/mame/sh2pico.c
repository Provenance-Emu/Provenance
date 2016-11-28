#include "../sh2.h"

#ifdef DRC_CMP
#include "../compiler.c"
#define BUSY_LOOP_HACKS 0
#else
#define BUSY_LOOP_HACKS 1
#endif

// MAME types
#ifndef INT8
typedef signed char  INT8;
typedef signed short INT16;
typedef signed int   INT32;
typedef unsigned int   UINT32;
typedef unsigned short UINT16;
typedef unsigned char  UINT8;
#endif

#ifdef DRC_SH2

// this nasty conversion is needed for drc-expecting memhandlers
#define MAKE_READFUNC(name, cname) \
static inline unsigned int name(SH2 *sh2, unsigned int a) \
{ \
	unsigned int ret; \
	sh2->sr |= sh2->icount << 12; \
	ret = cname(a, sh2); \
	sh2->icount = (signed int)sh2->sr >> 12; \
	sh2->sr &= 0x3f3; \
	return ret; \
}

#define MAKE_WRITEFUNC(name, cname) \
static inline void name(SH2 *sh2, unsigned int a, unsigned int d) \
{ \
	sh2->sr |= sh2->icount << 12; \
	cname(a, d, sh2); \
	sh2->icount = (signed int)sh2->sr >> 12; \
	sh2->sr &= 0x3f3; \
}

MAKE_READFUNC(RB, p32x_sh2_read8)
MAKE_READFUNC(RW, p32x_sh2_read16)
MAKE_READFUNC(RL, p32x_sh2_read32)
MAKE_WRITEFUNC(WB, p32x_sh2_write8)
MAKE_WRITEFUNC(WW, p32x_sh2_write16)
MAKE_WRITEFUNC(WL, p32x_sh2_write32)

#else

#define RB(sh2, a) p32x_sh2_read8(a, sh2)
#define RW(sh2, a) p32x_sh2_read16(a, sh2)
#define RL(sh2, a) p32x_sh2_read32(a, sh2)
#define WB(sh2, a, d) p32x_sh2_write8(a, d, sh2)
#define WW(sh2, a, d) p32x_sh2_write16(a, d, sh2)
#define WL(sh2, a, d) p32x_sh2_write32(a, d, sh2)

#endif

// some stuff from sh2comn.h
#define T	0x00000001
#define S	0x00000002
#define I	0x000000f0
#define Q	0x00000100
#define M	0x00000200

#define AM	0xc7ffffff

#define FLAGS	(M|Q|I|S|T)

#define Rn	((opcode>>8)&15)
#define Rm	((opcode>>4)&15)

#define sh2_state SH2

extern void lprintf(const char *fmt, ...);
#define logerror lprintf

#ifdef SH2_STATS
static SH2 sh2_stats;
static unsigned int op_refs[0x10000];
# define LRN  1
# define LRM  2
# define LRNM (LRN|LRM)
# define rlog(rnm) {   \
  int op = opcode;     \
  if ((rnm) & LRN) {   \
    op &= ~0x0f00;     \
    sh2_stats.r[Rn]++; \
  }                    \
  if ((rnm) & LRM) {   \
    op &= ~0x00f0;     \
    sh2_stats.r[Rm]++; \
  }                    \
  op_refs[op]++;       \
}
# define rlog1(x) sh2_stats.r[x]++
# define rlog2(x1,x2) sh2_stats.r[x1]++; sh2_stats.r[x2]++
#else
# define rlog(x)
# define rlog1(...)
# define rlog2(...)
#endif

#include "sh2.c"

#ifndef DRC_CMP

int sh2_execute_interpreter(SH2 *sh2, int cycles)
{
	UINT32 opcode;

	sh2->icount = cycles;

	if (sh2->icount <= 0)
		goto out;

	do
	{
		if (sh2->delay)
		{
			sh2->ppc = sh2->delay;
			opcode = RW(sh2, sh2->delay);
			sh2->pc -= 2;
		}
		else
		{
			sh2->ppc = sh2->pc;
			opcode = RW(sh2, sh2->pc);
		}

		sh2->delay = 0;
		sh2->pc += 2;

		switch (opcode & ( 15 << 12))
		{
		case  0<<12: op0000(sh2, opcode); break;
		case  1<<12: op0001(sh2, opcode); break;
		case  2<<12: op0010(sh2, opcode); break;
		case  3<<12: op0011(sh2, opcode); break;
		case  4<<12: op0100(sh2, opcode); break;
		case  5<<12: op0101(sh2, opcode); break;
		case  6<<12: op0110(sh2, opcode); break;
		case  7<<12: op0111(sh2, opcode); break;
		case  8<<12: op1000(sh2, opcode); break;
		case  9<<12: op1001(sh2, opcode); break;
		case 10<<12: op1010(sh2, opcode); break;
		case 11<<12: op1011(sh2, opcode); break;
		case 12<<12: op1100(sh2, opcode); break;
		case 13<<12: op1101(sh2, opcode); break;
		case 14<<12: op1110(sh2, opcode); break;
		default: op1111(sh2, opcode); break;
		}

		sh2->icount--;

		if (sh2->test_irq && !sh2->delay && sh2->pending_level > ((sh2->sr >> 4) & 0x0f))
		{
			int level = sh2->pending_level;
			int vector = sh2->irq_callback(sh2, level);
			sh2_do_irq(sh2, level, vector);
			sh2->test_irq = 0;
		}

	}
	while (sh2->icount > 0 || sh2->delay);	/* can't interrupt before delay */

out:
	return sh2->icount;
}

#else // if DRC_CMP

int sh2_execute_interpreter(SH2 *sh2, int cycles)
{
	static unsigned int base_pc_[2] = { 0, 0 };
	static unsigned int end_pc_[2] = { 0, 0 };
	static unsigned char op_flags_[2][BLOCK_INSN_LIMIT];
	unsigned int *base_pc = &base_pc_[sh2->is_slave];
	unsigned int *end_pc = &end_pc_[sh2->is_slave];
	unsigned char *op_flags = op_flags_[sh2->is_slave];
	unsigned int pc_expect;
	UINT32 opcode;

	sh2->icount = sh2->cycles_timeslice = cycles;

	if (sh2->pending_level > ((sh2->sr >> 4) & 0x0f))
	{
		int level = sh2->pending_level;
		int vector = sh2->irq_callback(sh2, level);
		sh2_do_irq(sh2, level, vector);
	}
	pc_expect = sh2->pc;

	if (sh2->icount <= 0)
		goto out;

	do
	{
		if (!sh2->delay) {
			if (sh2->pc < *base_pc || sh2->pc >= *end_pc) {
				*base_pc = sh2->pc;
				scan_block(*base_pc, sh2->is_slave,
					op_flags, end_pc, NULL);
			}
			if ((op_flags[(sh2->pc - *base_pc) / 2]
				& OF_BTARGET) || sh2->pc == *base_pc
				|| pc_expect != sh2->pc) // branched
			{
				pc_expect = sh2->pc;
				if (sh2->icount < 0)
					break;
			}

			do_sh2_trace(sh2, sh2->icount);
		}
		pc_expect += 2;

		if (sh2->delay)
		{
			sh2->ppc = sh2->delay;
			opcode = RW(sh2, sh2->delay);
			sh2->pc -= 2;
		}
		else
		{
			sh2->ppc = sh2->pc;
			opcode = RW(sh2, sh2->pc);
		}

		sh2->delay = 0;
		sh2->pc += 2;

		switch (opcode & ( 15 << 12))
		{
		case  0<<12: op0000(sh2, opcode); break;
		case  1<<12: op0001(sh2, opcode); break;
		case  2<<12: op0010(sh2, opcode); break;
		case  3<<12: op0011(sh2, opcode); break;
		case  4<<12: op0100(sh2, opcode); break;
		case  5<<12: op0101(sh2, opcode); break;
		case  6<<12: op0110(sh2, opcode); break;
		case  7<<12: op0111(sh2, opcode); break;
		case  8<<12: op1000(sh2, opcode); break;
		case  9<<12: op1001(sh2, opcode); break;
		case 10<<12: op1010(sh2, opcode); break;
		case 11<<12: op1011(sh2, opcode); break;
		case 12<<12: op1100(sh2, opcode); break;
		case 13<<12: op1101(sh2, opcode); break;
		case 14<<12: op1110(sh2, opcode); break;
		default: op1111(sh2, opcode); break;
		}

		sh2->icount--;

		if (sh2->test_irq && !sh2->delay && sh2->pending_level > ((sh2->sr >> 4) & 0x0f))
		{
			int level = sh2->pending_level;
			int vector = sh2->irq_callback(sh2, level);
			sh2_do_irq(sh2, level, vector);
			sh2->test_irq = 0;
		}

	}
	while (1);

out:
	return sh2->icount;
}

#endif // DRC_CMP

#ifdef SH2_STATS
#include <stdio.h>
#include <string.h>
#include "sh2dasm.h"

void sh2_dump_stats(void)
{
	static const char *rnames[] = {
		"R0", "R1", "R2",  "R3",  "R4",  "R5",  "R6",  "R7",
		"R8", "R9", "R10", "R11", "R12", "R13", "R14", "SP",
		"PC", "", "PR", "SR", "GBR", "VBR", "MACH", "MACL"
	};
	long long total;
	char buff[64];
	int u, i;

	// dump reg usage
	total = 0;
	for (i = 0; i < 24; i++)
		total += sh2_stats.r[i];

	for (i = 0; i < 24; i++) {
		if (i == 16 || i == 17 || i == 19)
			continue;
		printf("r %6.3f%% %-4s %9d\n", (double)sh2_stats.r[i] * 100.0 / total,
			rnames[i], sh2_stats.r[i]);
	}

	memset(&sh2_stats, 0, sizeof(sh2_stats));

	// dump ops
	printf("\n");
	total = 0;
	for (i = 0; i < 0x10000; i++)
		total += op_refs[i];

	for (u = 0; u < 16; u++) {
		int max = 0, op = 0;
		for (i = 0; i < 0x10000; i++) {
			if (op_refs[i] > max) {
				max = op_refs[i];
				op = i;
			}
		}
		DasmSH2(buff, 0, op);
		printf("i %6.3f%% %9d %s\n", (double)op_refs[op] * 100.0 / total,
			op_refs[op], buff);
		op_refs[op] = 0;
	}
	memset(op_refs, 0, sizeof(op_refs));
}
#endif

