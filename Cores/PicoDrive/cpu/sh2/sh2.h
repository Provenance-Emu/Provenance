#ifndef __SH2_H__
#define __SH2_H__

#if !defined(REGPARM) && defined(__i386__) 
#define REGPARM(x) __attribute__((regparm(x)))
#else
#define REGPARM(x)
#endif

// registers - matches structure order
typedef enum {
  SHR_R0 = 0, SHR_SP = 15,
  SHR_PC,  SHR_PPC, SHR_PR,   SHR_SR,
  SHR_GBR, SHR_VBR, SHR_MACH, SHR_MACL,
} sh2_reg_e;

typedef struct SH2_
{
	unsigned int	r[16];		// 00
	unsigned int	pc;		// 40
	unsigned int	ppc;
	unsigned int	pr;
	unsigned int	sr;
	unsigned int	gbr, vbr;	// 50
	unsigned int	mach, macl;	// 58

	// common
	const void	*read8_map;	// 60
	const void	*read16_map;
	const void	**write8_tab;
	const void	**write16_tab;

	// drc stuff
	int		drc_tmp;	// 70
	int		irq_cycles;
	void		*p_bios;	// convenience pointers
	void		*p_da;
	void		*p_sdram;	// 80
	void		*p_rom;
	unsigned int	pdb_io_csum[2];

#define SH2_STATE_RUN   (1 << 0)	// to prevent recursion
#define SH2_STATE_SLEEP (1 << 1)
#define SH2_STATE_CPOLL (1 << 2)	// polling comm regs
#define SH2_STATE_VPOLL (1 << 3)	// polling VDP
	unsigned int	state;
	unsigned int	poll_addr;
	int		poll_cycles;
	int		poll_cnt;

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

	// we use 68k reference cycles for easier sync
	unsigned int	m68krcycles_done;
	unsigned int	mult_m68k_to_sh2;
	unsigned int	mult_sh2_to_m68k;

	unsigned char	data_array[0x1000]; // cache (can be used as RAM)
	unsigned int	peri_regs[0x200/4]; // periphereal regs
} SH2;

#define CYCLE_MULT_SHIFT 10
#define C_M68K_TO_SH2(xsh2, c) \
	((int)((c) * (xsh2).mult_m68k_to_sh2) >> CYCLE_MULT_SHIFT)
#define C_SH2_TO_M68K(xsh2, c) \
	((int)((c + 3) * (xsh2).mult_sh2_to_m68k) >> CYCLE_MULT_SHIFT)

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

static inline int sh2_execute(SH2 *sh2, int cycles, int use_drc)
{
  int ret;

  sh2->cycles_timeslice = cycles;
#ifdef DRC_SH2
  if (use_drc)
    ret = sh2_execute_drc(sh2, cycles);
  else
#endif
    ret = sh2_execute_interpreter(sh2, cycles);

  return sh2->cycles_timeslice - ret;
}

// regs, pending_int*, cycles, reserved
#define SH2_STATE_SIZE ((24 + 2 + 2 + 12) * 4)

// pico memhandlers
// XXX: move somewhere else
unsigned int REGPARM(2) p32x_sh2_read8(unsigned int a, SH2 *sh2);
unsigned int REGPARM(2) p32x_sh2_read16(unsigned int a, SH2 *sh2);
unsigned int REGPARM(2) p32x_sh2_read32(unsigned int a, SH2 *sh2);
void REGPARM(3) p32x_sh2_write8 (unsigned int a, unsigned int d, SH2 *sh2);
void REGPARM(3) p32x_sh2_write16(unsigned int a, unsigned int d, SH2 *sh2);
void REGPARM(3) p32x_sh2_write32(unsigned int a, unsigned int d, SH2 *sh2);

// debug
#ifdef DRC_CMP
void do_sh2_trace(SH2 *current, int cycles);
void do_sh2_cmp(SH2 *current);
#endif

#endif /* __SH2_H__ */
