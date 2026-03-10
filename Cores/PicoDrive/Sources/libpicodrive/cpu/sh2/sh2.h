#ifndef __SH2_H__
#define __SH2_H__

#include <pico/pico_types.h>
#include <pico/pico_port.h>

// registers - matches structure order
typedef enum {
  SHR_R0 = 0, SHR_SP = 15,
  SHR_PC,  SHR_PPC, SHR_PR,   SHR_SR,
  SHR_GBR, SHR_VBR, SHR_MACH, SHR_MACL,
  SH2_REGS, // register set size
  SHR_T = 29, SHR_MEM = 30, SHR_TMP = 31, // drc specific pseudo regs
} sh2_reg_e;
#define	SHR_R(n)	(SHR_R0+(n))

typedef struct SH2_
{
	// registers. this MUST correlate with enum sh2_reg_e.
	uint32_t	r[16] ALIGNED(32);
	uint32_t	pc;		// 40
	uint32_t	ppc;
	uint32_t	pr;
	uint32_t	sr;
	uint32_t	gbr, vbr;	// 50
	uint32_t	mach, macl;	// 58

	// common
	const void	*read8_map;
	const void	*read16_map;
	const void	*read32_map;
	const void	**write8_tab;
	const void	**write16_tab;
	const void	**write32_tab;

	// drc stuff
	int		drc_tmp;
	int		irq_cycles;
	void		*p_bios;	// convenience pointers
	void		*p_da;
	void		*p_sdram;
	void		*p_rom;
	void		*p_dram;
	void		*p_drcblk_da;
	void		*p_drcblk_ram;
	unsigned int	pdb_io_csum[2];

#define SH2_STATE_RUN   (1 << 0)	// to prevent recursion
#define SH2_STATE_SLEEP (1 << 1)	// temporarily stopped (DMA, IO, ...)
#define SH2_STATE_CPOLL (1 << 2)	// polling comm regs
#define SH2_STATE_VPOLL (1 << 3)	// polling VDP
#define SH2_STATE_RPOLL (1 << 4)	// polling address in SDRAM
#define SH2_TIMER_RUN   (1 << 6)	// SOC WDT timer is running
#define SH2_IN_DRC      (1 << 7)	// DRC in use
	unsigned int	state;
	uint32_t	poll_addr;
	unsigned int	poll_cycles;
	int		poll_cnt;
// NB MUST be a bit unused in SH2 SR, see also cpu/sh2/compiler.c!
#define SH2_NO_POLLING	(1 << 10)	// poll detection control
	int		no_polling;

	// DRC branch cache. size must be 2^n and <=128
	int rts_cache_idx;
	struct { uint32_t pc; void *code; } rts_cache[16];
	struct { uint32_t pc; void *code; } branch_cache[128];

	// interpreter stuff
	int		icount;		// cycles left in current timeslice
	unsigned int	ea;
	unsigned int	delay;
	unsigned int	test_irq;

	int	pending_level;		// MAX(pending_irl, pending_int_irq)
	int	pending_irl;
	int	pending_int_irq;	// internal irq
	int	pending_int_vector;
	int	REGPARM(2) (*irq_callback)(struct SH2_ *sh2, int level);
	int	is_slave;

	unsigned int	cycles_timeslice;

	struct SH2_	*other_sh2;
	int		(*run)(struct SH2_ *, int);

	// we use 68k reference cycles for easier sync
	unsigned int	m68krcycles_done;
	unsigned int	mult_m68k_to_sh2;
	unsigned int	mult_sh2_to_m68k;

	uint8_t		data_array[0x1000]; // cache (can be used as RAM)
	uint32_t	peri_regs[0x200/4]; // peripheral regs
} SH2;

#define CYCLE_MULT_SHIFT 10
#define C_M68K_TO_SH2(xsh2, c) \
	(int)(((uint64_t)(c) * (xsh2)->mult_m68k_to_sh2) >> CYCLE_MULT_SHIFT)
#define C_SH2_TO_M68K(xsh2, c) \
	(int)(((uint64_t)(c+3U) * (xsh2)->mult_sh2_to_m68k) >> CYCLE_MULT_SHIFT)

int  sh2_init(SH2 *sh2, int is_slave, SH2 *other_sh2);
void sh2_finish(SH2 *sh2);
void sh2_reset(SH2 *sh2);
int  sh2_irl_irq(SH2 *sh2, int level, int nested_call);
void sh2_internal_irq(SH2 *sh2, int level, int vector);
void sh2_do_irq(SH2 *sh2, int level, int vector);
void sh2_pack(const SH2 *sh2, unsigned char *buff);
void sh2_unpack(SH2 *sh2, const unsigned char *buff);

int  sh2_execute_drc(SH2 *sh2c, int cycles);
int  sh2_execute_interpreter(SH2 *sh2c, int cycles);

static __inline void sh2_execute_prepare(SH2 *sh2, int use_drc)
{
#ifdef DRC_SH2
  sh2->run = use_drc ? sh2_execute_drc : sh2_execute_interpreter;
#else
  sh2->run = sh2_execute_interpreter;
#endif
}

static __inline int sh2_execute(SH2 *sh2, int cycles)
{
  int ret;

  sh2->cycles_timeslice = cycles;
  ret = sh2->run(sh2, cycles);

  return sh2->cycles_timeslice - ret;
}

// regs, pending_int*, cycles, reserved
#define SH2_STATE_SIZE ((24 + 2 + 2 + 12) * 4)

// pico memhandlers
// XXX: move somewhere else
u32 REGPARM(2) p32x_sh2_read8(u32 a, SH2 *sh2);
u32 REGPARM(2) p32x_sh2_read16(u32 a, SH2 *sh2);
u32 REGPARM(2) p32x_sh2_read32(u32 a, SH2 *sh2);
void REGPARM(3) p32x_sh2_write8 (u32 a, u32 d, SH2 *sh2);
void REGPARM(3) p32x_sh2_write16(u32 a, u32 d, SH2 *sh2);
void REGPARM(3) p32x_sh2_write32(u32 a, u32 d, SH2 *sh2);

// debug
#ifdef DRC_CMP
void do_sh2_trace(SH2 *current, int cycles);
void REGPARM(1) do_sh2_cmp(SH2 *current);
#endif

#endif /* __SH2_H__ */
