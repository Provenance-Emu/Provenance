/*
 * PicoDrive - Internal Header File
 * (c) Copyright Dave, 2004
 * (C) notaz, 2006-2010
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#ifndef PICO_INTERNAL_INCLUDED
#define PICO_INTERNAL_INCLUDED

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "pico.h"
#include "carthw/carthw.h"

//
#define USE_POLL_DETECT

#ifndef PICO_INTERNAL
#define PICO_INTERNAL
#endif
#ifndef PICO_INTERNAL_ASM
#define PICO_INTERNAL_ASM
#endif

// to select core, define EMU_C68K, EMU_M68K or EMU_F68K in your makefile or project

#ifdef __cplusplus
extern "C" {
#endif


// ----------------------- 68000 CPU -----------------------
#ifdef EMU_C68K
#include "../cpu/cyclone/Cyclone.h"
extern struct Cyclone PicoCpuCM68k, PicoCpuCS68k;
#define SekCyclesLeft     PicoCpuCM68k.cycles // cycles left for this run
#define SekCyclesLeftS68k PicoCpuCS68k.cycles
#define SekPc (PicoCpuCM68k.pc-PicoCpuCM68k.membase)
#define SekPcS68k (PicoCpuCS68k.pc-PicoCpuCS68k.membase)
#define SekDar(x)     (x < 8 ? PicoCpuCM68k.d[x] : PicoCpuCM68k.a[x - 8])
#define SekDarS68k(x) (x < 8 ? PicoCpuCS68k.d[x] : PicoCpuCS68k.a[x - 8])
#define SekSr     CycloneGetSr(&PicoCpuCM68k)
#define SekSrS68k CycloneGetSr(&PicoCpuCS68k)
#define SekSetStop(x) { PicoCpuCM68k.state_flags&=~1; if (x) { PicoCpuCM68k.state_flags|=1; PicoCpuCM68k.cycles=0; } }
#define SekSetStopS68k(x) { PicoCpuCS68k.state_flags&=~1; if (x) { PicoCpuCS68k.state_flags|=1; PicoCpuCS68k.cycles=0; } }
#define SekIsStoppedM68k() (PicoCpuCM68k.state_flags&1)
#define SekIsStoppedS68k() (PicoCpuCS68k.state_flags&1)
#define SekShouldInterrupt() (PicoCpuCM68k.irq > (PicoCpuCM68k.srh&7))

#define SekNotPolling     PicoCpuCM68k.not_pol
#define SekNotPollingS68k PicoCpuCS68k.not_pol

#define SekInterrupt(i) PicoCpuCM68k.irq=i
#define SekIrqLevel     PicoCpuCM68k.irq

#endif

#ifdef EMU_F68K
#include "../cpu/fame/fame.h"
extern M68K_CONTEXT PicoCpuFM68k, PicoCpuFS68k;
#define SekCyclesLeft     PicoCpuFM68k.io_cycle_counter
#define SekCyclesLeftS68k PicoCpuFS68k.io_cycle_counter
#define SekPc     fm68k_get_pc(&PicoCpuFM68k)
#define SekPcS68k fm68k_get_pc(&PicoCpuFS68k)
#define SekDar(x)     (x < 8 ? PicoCpuFM68k.dreg[x].D : PicoCpuFM68k.areg[x - 8].D)
#define SekDarS68k(x) (x < 8 ? PicoCpuFS68k.dreg[x].D : PicoCpuFS68k.areg[x - 8].D)
#define SekSr     PicoCpuFM68k.sr
#define SekSrS68k PicoCpuFS68k.sr
#define SekSetStop(x) { \
	PicoCpuFM68k.execinfo &= ~FM68K_HALTED; \
	if (x) { PicoCpuFM68k.execinfo |= FM68K_HALTED; PicoCpuFM68k.io_cycle_counter = 0; } \
}
#define SekSetStopS68k(x) { \
	PicoCpuFS68k.execinfo &= ~FM68K_HALTED; \
	if (x) { PicoCpuFS68k.execinfo |= FM68K_HALTED; PicoCpuFS68k.io_cycle_counter = 0; } \
}
#define SekIsStoppedM68k() (PicoCpuFM68k.execinfo&FM68K_HALTED)
#define SekIsStoppedS68k() (PicoCpuFS68k.execinfo&FM68K_HALTED)
#define SekShouldInterrupt() fm68k_would_interrupt()

#define SekNotPolling     PicoCpuFM68k.not_polling
#define SekNotPollingS68k PicoCpuFS68k.not_polling

#define SekInterrupt(irq) PicoCpuFM68k.interrupts[0]=irq
#define SekIrqLevel       PicoCpuFM68k.interrupts[0]

#endif

#ifdef EMU_M68K
#include "../cpu/musashi/m68kcpu.h"
extern m68ki_cpu_core PicoCpuMM68k, PicoCpuMS68k;
#ifndef SekCyclesLeft
#define SekCyclesLeft     PicoCpuMM68k.cyc_remaining_cycles
#define SekCyclesLeftS68k PicoCpuMS68k.cyc_remaining_cycles
#define SekPc m68k_get_reg(&PicoCpuMM68k, M68K_REG_PC)
#define SekPcS68k m68k_get_reg(&PicoCpuMS68k, M68K_REG_PC)
#define SekDar(x)     PicoCpuMM68k.dar[x]
#define SekDarS68k(x) PicoCpuMS68k.dar[x]
#define SekSr     m68k_get_reg(&PicoCpuMM68k, M68K_REG_SR)
#define SekSrS68k m68k_get_reg(&PicoCpuMS68k, M68K_REG_SR)
#define SekSetStop(x) { \
	if(x) { SET_CYCLES(0); PicoCpuMM68k.stopped=STOP_LEVEL_STOP; } \
	else PicoCpuMM68k.stopped=0; \
}
#define SekSetStopS68k(x) { \
	if(x) { SET_CYCLES(0); PicoCpuMS68k.stopped=STOP_LEVEL_STOP; } \
	else PicoCpuMS68k.stopped=0; \
}
#define SekIsStoppedM68k() (PicoCpuMM68k.stopped==STOP_LEVEL_STOP)
#define SekIsStoppedS68k() (PicoCpuMS68k.stopped==STOP_LEVEL_STOP)
#define SekShouldInterrupt() (CPU_INT_LEVEL > FLAG_INT_MASK)

#define SekNotPolling     PicoCpuMM68k.not_polling
#define SekNotPollingS68k PicoCpuMS68k.not_polling

#define SekInterrupt(irq) { \
	void *oldcontext = m68ki_cpu_p; \
	m68k_set_context(&PicoCpuMM68k); \
	m68k_set_irq(irq); \
	m68k_set_context(oldcontext); \
}
#define SekIrqLevel (PicoCpuMM68k.int_level >> 8)

#endif
#endif // EMU_M68K

// while running, cnt represents target of current timeslice
// while not in SekRun(), it's actual cycles done
// (but always use SekCyclesDone() if you need current position)
// cnt may change if timeslice is ended prematurely or extended,
// so we use SekCycleAim for the actual target
extern unsigned int SekCycleCnt;
extern unsigned int SekCycleAim;

// number of cycles done (can be checked anywhere)
#define SekCyclesDone()  (SekCycleCnt - SekCyclesLeft)

// burn cycles while not in SekRun() and while in
#define SekCyclesBurn(c)    SekCycleCnt += c
#define SekCyclesBurnRun(c) { \
  SekCyclesLeft -= c; \
}

// note: sometimes may extend timeslice to delay an irq
#define SekEndRun(after) { \
  SekCycleCnt -= SekCyclesLeft - (after); \
  SekCyclesLeft = after; \
}

extern unsigned int SekCycleCntS68k;
extern unsigned int SekCycleAimS68k;

#define SekEndRunS68k(after) { \
  if (SekCyclesLeftS68k > (after)) { \
    SekCycleCntS68k -= SekCyclesLeftS68k - (after); \
    SekCyclesLeftS68k = after; \
  } \
}

#define SekCyclesDoneS68k()  (SekCycleCntS68k - SekCyclesLeftS68k)

// compare cycles, handling overflows
// check if a > b
#define CYCLES_GT(a, b) \
  ((int)((a) - (b)) > 0)
// check if a >= b
#define CYCLES_GE(a, b) \
  ((int)((a) - (b)) >= 0)

// ----------------------- Z80 CPU -----------------------

#if defined(_USE_DRZ80)
#include "../cpu/DrZ80/drz80.h"

extern struct DrZ80 drZ80;

#define z80_run(cycles)    ((cycles) - DrZ80Run(&drZ80, cycles))
#define z80_run_nr(cycles) DrZ80Run(&drZ80, cycles)
#define z80_int()          drZ80.Z80_IRQ = 1
#define z80_int()          drZ80.Z80_IRQ = 1
#define z80_nmi()          drZ80.Z80IF |= 8

#define z80_cyclesLeft     drZ80.cycles
#define z80_pc()           (drZ80.Z80PC - drZ80.Z80PC_BASE)

#elif defined(_USE_CZ80)
#include "../cpu/cz80/cz80.h"

#define z80_run(cycles)    Cz80_Exec(&CZ80, cycles)
#define z80_run_nr(cycles) Cz80_Exec(&CZ80, cycles)
#define z80_int()          Cz80_Set_IRQ(&CZ80, 0, HOLD_LINE)
#define z80_nmi()          Cz80_Set_IRQ(&CZ80, IRQ_LINE_NMI, 0)

#define z80_cyclesLeft     (CZ80.ICount - CZ80.ExtraCycles)
#define z80_pc()           Cz80_Get_Reg(&CZ80, CZ80_PC)

#else

#define z80_run(cycles)    (cycles)
#define z80_run_nr(cycles)
#define z80_int()
#define z80_nmi()

#endif

#define Z80_STATE_SIZE 0x60

extern unsigned int last_z80_sync;
extern int z80_cycle_cnt;        /* 'done' z80 cycles before z80_run() */
extern int z80_cycle_aim;
extern int z80_scanline;
extern int z80_scanline_cycles;  /* cycles done until z80_scanline */

#define z80_resetCycles() \
  last_z80_sync = SekCyclesDone(); \
  z80_cycle_cnt = z80_cycle_aim = z80_scanline = z80_scanline_cycles = 0;

#define z80_cyclesDone() \
  (z80_cycle_aim - z80_cyclesLeft)

#define cycles_68k_to_z80(x) ((x)*957 >> 11)

// ----------------------- SH2 CPU -----------------------

#include "cpu/sh2/sh2.h"

extern SH2 sh2s[2];
#define msh2 sh2s[0]
#define ssh2 sh2s[1]

#ifndef DRC_SH2
# define sh2_end_run(sh2, after_) do { \
  if ((sh2)->icount > (after_)) { \
    (sh2)->cycles_timeslice -= (sh2)->icount - (after_); \
    (sh2)->icount = after_; \
  } \
} while (0)
# define sh2_cycles_left(sh2) (sh2)->icount
# define sh2_burn_cycles(sh2, n) (sh2)->icount -= n
# define sh2_pc(sh2) (sh2)->ppc
#else
# define sh2_end_run(sh2, after_) do { \
  int left_ = (signed int)(sh2)->sr >> 12; \
  if (left_ > (after_)) { \
    (sh2)->cycles_timeslice -= left_ - (after_); \
    (sh2)->sr &= 0xfff; \
    (sh2)->sr |= (after_) << 12; \
  } \
} while (0)
# define sh2_cycles_left(sh2) ((signed int)(sh2)->sr >> 12)
# define sh2_burn_cycles(sh2, n) (sh2)->sr -= ((n) << 12)
# define sh2_pc(sh2) (sh2)->pc
#endif

#define sh2_cycles_done(sh2) ((int)(sh2)->cycles_timeslice - sh2_cycles_left(sh2))
#define sh2_cycles_done_t(sh2) \
  ((sh2)->m68krcycles_done * 3 + sh2_cycles_done(sh2))
#define sh2_cycles_done_m68k(sh2) \
  ((sh2)->m68krcycles_done + (sh2_cycles_done(sh2) / 3))

#define sh2_reg(c, x) (c) ? ssh2.r[x] : msh2.r[x]
#define sh2_gbr(c)    (c) ? ssh2.gbr : msh2.gbr
#define sh2_vbr(c)    (c) ? ssh2.vbr : msh2.vbr
#define sh2_sr(c)   (((c) ? ssh2.sr : msh2.sr) & 0xfff)

#define sh2_set_gbr(c, v) \
  { if (c) ssh2.gbr = v; else msh2.gbr = v; }
#define sh2_set_vbr(c, v) \
  { if (c) ssh2.vbr = v; else msh2.vbr = v; }

#define elprintf_sh2(sh2, w, f, ...) \
	elprintf(w,"%csh2 "f,(sh2)->is_slave?'s':'m',##__VA_ARGS__)

// ---------------------------------------------------------

// main oscillator clock which controls timing
#define OSC_NTSC 53693100
#define OSC_PAL  53203424

struct PicoVideo
{
  unsigned char reg[0x20];
  unsigned int command;       // 32-bit Command
  unsigned char pending;      // 1 if waiting for second half of 32-bit command
  unsigned char type;         // Command type (v/c/vsram read/write)
  unsigned short addr;        // Read/Write address
  int status;                 // Status bits
  unsigned char pending_ints; // pending interrupts: ??VH????
  signed char lwrite_cnt;     // VDP write count during active display line
  unsigned short v_counter;   // V-counter
  unsigned char pad[0x10];
};

struct PicoMisc
{
  unsigned char rotate;
  unsigned char z80Run;
  unsigned char padTHPhase[2]; // 02 phase of gamepad TH switches
  unsigned short scanline;     // 04 0 to 261||311
  char dirtyPal;               // 06 Is the palette dirty (1 - change @ this frame, 2 - some time before)
  unsigned char hardware;      // 07 Hardware value for country
  unsigned char pal;           // 08 1=PAL 0=NTSC
  unsigned char sram_reg;      // 09 SRAM reg. See SRR_* below
  unsigned short z80_bank68k;  // 0a
  unsigned short pad0;
  unsigned char  ncart_in;     // 0e !cart_in
  unsigned char  z80_reset;    // 0f z80 reset held
  unsigned char  padDelay[2];  // 10 gamepad phase time outs, so we count a delay
  unsigned short eeprom_addr;  // EEPROM address register
  unsigned char  eeprom_cycle; // EEPROM cycle number
  unsigned char  eeprom_slave; // EEPROM slave word for X24C02 and better SRAMs
  unsigned char  eeprom_status;
  unsigned char  pad2;
  unsigned short dma_xfers;    // 18
  unsigned char  eeprom_wb[2]; // EEPROM latch/write buffer
  unsigned int  frame_count;   // 1c for movies and idle det
};

struct PicoMS
{
  unsigned char carthw[0x10];
  unsigned char io_ctl;
  unsigned char nmi_state;
  unsigned char pad[0x4e];
};

// some assembly stuff depend on these, do not touch!
struct Pico
{
  unsigned char ram[0x10000];  // 0x00000 scratch ram
  union {                      // vram is byteswapped for easier reads when drawing
    unsigned short vram[0x8000];  // 0x10000
    unsigned char  vramb[0x4000]; // VRAM in SMS mode
  };
  unsigned char zram[0x2000];  // 0x20000 Z80 ram
  unsigned char ioports[0x10]; // XXX: fix asm and mv
  unsigned char pad[0xf0];     // unused
  unsigned short cram[0x40];   // 0x22100
  unsigned short vsram[0x40];  // 0x22180

  unsigned char *rom;          // 0x22200
  unsigned int romsize;        // 0x22204 (on 32bits)

  struct PicoMisc m;
  struct PicoVideo video;
  struct PicoMS ms;
};

// sram
#define SRR_MAPPED   (1 << 0)
#define SRR_READONLY (1 << 1)

#define SRF_ENABLED  (1 << 0)
#define SRF_EEPROM   (1 << 1)

struct PicoSRAM
{
  unsigned char *data;		// actual data
  unsigned int start;		// start address in 68k address space
  unsigned int end;
  unsigned char flags;		// 0c: SRF_*
  unsigned char unused2;
  unsigned char changed;
  unsigned char eeprom_type;    // eeprom type: 0: 7bit (24C01), 2: 2 addr words (X24C02+), 3: 3 addr words
  unsigned char unused3;
  unsigned char eeprom_bit_cl;	// bit number for cl
  unsigned char eeprom_bit_in;  // bit number for in
  unsigned char eeprom_bit_out; // bit number for out
  unsigned int size;
};

// MCD
#define PCM_MIXBUF_LEN ((12500000 / 384) / 50 + 1)

struct mcd_pcm
{
	unsigned char control; // reg7
	unsigned char enabled; // reg8
	unsigned char cur_ch;
	unsigned char bank;
	unsigned int update_cycles;

	struct pcm_chan			// 08, size 0x10
	{
		unsigned char regs[8];
		unsigned int  addr;	// .08: played sample address
		int pad;
	} ch[8];
};

#define PCD_ST_S68K_RST 1

struct mcd_misc
{
  unsigned short hint_vector;
  unsigned char  busreq;          // not s68k_regs[1]
  unsigned char  s68k_pend_ints;
  unsigned int   state_flags;     // 04
  unsigned int   stopwatch_base_c;
  unsigned short m68k_poll_a;
  unsigned short m68k_poll_cnt;
  unsigned short s68k_poll_a;
  unsigned short s68k_poll_cnt;
  unsigned int   s68k_poll_clk;
  unsigned char  bcram_reg;       // 18: battery-backed RAM cart register
  unsigned char  dmna_ret_2m;
  unsigned char  need_sync;
  unsigned char  pad3;
  int pad4[9];
};

typedef struct
{
  unsigned char bios[0x20000];			// 000000: 128K
  union {					// 020000: 512K
    unsigned char prg_ram[0x80000];
    unsigned char prg_ram_b[4][0x20000];
  };
  union {					// 0a0000: 256K
    struct {
      unsigned char word_ram2M[0x40000];
      unsigned char unused0[0x20000];
    };
    struct {
      unsigned char unused1[0x20000];
      unsigned char word_ram1M[2][0x20000];
    };
  };
  union {					// 100000: 64K
    unsigned char pcm_ram[0x10000];
    unsigned char pcm_ram_b[0x10][0x1000];
  };
  unsigned char s68k_regs[0x200];		// 110000: GA, not CPU regs
  unsigned char bram[0x2000];			// 110200: 8K
  struct mcd_misc m;				// 112200: misc
  struct mcd_pcm pcm;				// 112240:
  void *cdda_stream;
  int cdda_type;
  int pcm_mixbuf[PCM_MIXBUF_LEN * 2];
  int pcm_mixpos;
  char pcm_mixbuf_dirty;
  char pcm_regs_dirty;
} mcd_state;

// XXX: this will need to be reworked for cart+cd support.
#define Pico_mcd ((mcd_state *)Pico.rom)

// 32X
#define P32XS_FM    (1<<15)
#define P32XS_nCART (1<< 8)
#define P32XS_REN   (1<< 7)
#define P32XS_nRES  (1<< 1)
#define P32XS_ADEN  (1<< 0)
#define P32XS2_ADEN (1<< 9)
#define P32XS_FULL  (1<< 7) // DREQ FIFO full
#define P32XS_68S   (1<< 2)
#define P32XS_DMA   (1<< 1)
#define P32XS_RV    (1<< 0)

#define P32XV_nPAL  (1<<15) // VDP
#define P32XV_PRI   (1<< 7)
#define P32XV_Mx    (3<< 0) // display mode mask

#define P32XV_SFT   (1<< 0)

#define P32XV_VBLK  (1<<15)
#define P32XV_HBLK  (1<<14)
#define P32XV_PEN   (1<<13)
#define P32XV_nFEN  (1<< 1)
#define P32XV_FS    (1<< 0)

#define P32XP_RTP   (1<<7)  // PWM control
#define P32XP_FULL  (1<<15) // PWM pulse
#define P32XP_EMPTY (1<<14)

#define P32XF_68KCPOLL   (1 << 0)
#define P32XF_68KVPOLL   (1 << 1)
#define P32XF_Z80_32X_IO (1 << 7) // z80 does 32x io

#define P32XI_VRES (1 << 14/2) // IRL/2
#define P32XI_VINT (1 << 12/2)
#define P32XI_HINT (1 << 10/2)
#define P32XI_CMD  (1 <<  8/2)
#define P32XI_PWM  (1 <<  6/2)

// peripheral reg access
#define PREG8(regs,offs) ((unsigned char *)regs)[offs ^ 3]

#define DMAC_FIFO_LEN (4*2)
#define PWM_BUFF_LEN 1024 // in one channel samples

#define SH2_DRCBLK_RAM_SHIFT 1
#define SH2_DRCBLK_DA_SHIFT  1

#define SH2_READ_SHIFT 25
#define SH2_WRITE_SHIFT 25

struct Pico32x
{
  unsigned short regs[0x20];
  unsigned short vdp_regs[0x10]; // 0x40
  unsigned short sh2_regs[3];    // 0x60
  unsigned char pending_fb;
  unsigned char dirty_pal;
  unsigned int emu_flags;
  unsigned char sh2irq_mask[2];
  unsigned char sh2irqi[2];      // individual
  unsigned int sh2irqs;          // common irqs
  unsigned short dmac_fifo[DMAC_FIFO_LEN];
  unsigned int pad[4];
  unsigned int dmac0_fifo_ptr;
  unsigned short vdp_fbcr_fake;
  unsigned short pad2;
  unsigned char comm_dirty_68k;
  unsigned char comm_dirty_sh2;
  unsigned char pwm_irq_cnt;
  unsigned char pad1;
  unsigned short pwm_p[2];       // pwm pos in fifo
  unsigned int pwm_cycle_p;      // pwm play cursor (32x cycles)
  unsigned int reserved[6];
};

struct Pico32xMem
{
  unsigned char  sdram[0x40000];
#ifdef DRC_SH2
  unsigned short drcblk_ram[1 << (18 - SH2_DRCBLK_RAM_SHIFT)];
#endif
  unsigned short dram[2][0x20000/2];    // AKA fb
  union {
    unsigned char  m68k_rom[0x100];
    unsigned char  m68k_rom_bank[0x10000]; // M68K_BANK_SIZE
  };
#ifdef DRC_SH2
  unsigned short drcblk_da[2][1 << (12 - SH2_DRCBLK_DA_SHIFT)];
#endif
  union {
    unsigned char  b[0x800];
    unsigned short w[0x800/2];
  } sh2_rom_m;
  union {
    unsigned char  b[0x400];
    unsigned short w[0x400/2];
  } sh2_rom_s;
  unsigned short pal[0x100];
  unsigned short pal_native[0x100];     // converted to native (for renderer)
  signed short   pwm[2*PWM_BUFF_LEN];   // PWM buffer for current frame
  signed short   pwm_current[2];        // current converted samples
  unsigned short pwm_fifo[2][4];        // [0] - current raw, others - fifo entries
};

// area.c
extern void (*PicoLoadStateHook)(void);

typedef struct {
	int chunk;
	int size;
	void *ptr;
} carthw_state_chunk;
extern carthw_state_chunk *carthw_chunks;
#define CHUNK_CARTHW 64

// cart.c
extern int PicoCartResize(int newsize);
extern void Byteswap(void *dst, const void *src, int len);
extern void (*PicoCartMemSetup)(void);
extern void (*PicoCartUnloadHook)(void);

// debug.c
int CM_compareRun(int cyc, int is_sub);

// draw.c
PICO_INTERNAL void PicoFrameStart(void);
void PicoDrawSync(int to, int blank_last_line);
void BackFill(int reg7, int sh);
void FinalizeLine555(int sh, int line);
extern int (*PicoScanBegin)(unsigned int num);
extern int (*PicoScanEnd)(unsigned int num);
extern int DrawScanline;
#define MAX_LINE_SPRITES 29
extern unsigned char HighLnSpr[240][3 + MAX_LINE_SPRITES];
extern void *DrawLineDestBase;
extern int DrawLineDestIncrement;

// draw2.c
PICO_INTERNAL void PicoFrameFull();

// mode4.c
void PicoFrameStartMode4(void);
void PicoLineMode4(int line);
void PicoDoHighPal555M4(void);
void PicoDrawSetOutputMode4(pdso_t which);

// memory.c
PICO_INTERNAL void PicoMemSetup(void);
unsigned int PicoRead8_io(unsigned int a);
unsigned int PicoRead16_io(unsigned int a);
void PicoWrite8_io(unsigned int a, unsigned int d);
void PicoWrite16_io(unsigned int a, unsigned int d);

// pico/memory.c
PICO_INTERNAL void PicoMemSetupPico(void);

// cd/cdc.c
void cdc_init(void);
void cdc_reset(void);
int  cdc_context_save(unsigned char *state);
int  cdc_context_load(unsigned char *state);
int  cdc_context_load_old(unsigned char *state);
void cdc_dma_update(void);
int  cdc_decoder_update(unsigned char header[4]);
void cdc_reg_w(unsigned char data);
unsigned char  cdc_reg_r(void);
unsigned short cdc_host_r(void);

// cd/cdd.c
void cdd_reset(void);
int cdd_context_save(unsigned char *state);
int cdd_context_load(unsigned char *state);
int cdd_context_load_old(unsigned char *state);
void cdd_read_data(unsigned char *dst);
void cdd_read_audio(unsigned int samples);
void cdd_update(void);
void cdd_process(void);

// cd/cd_image.c
int load_cd_image(const char *cd_img_name, int *type);

// cd/gfx.c
void gfx_init(void);
void gfx_start(unsigned int base);
void gfx_update(unsigned int cycles);
int gfx_context_save(unsigned char *state);
int gfx_context_load(const unsigned char *state);

// cd/gfx_dma.c
void DmaSlowCell(unsigned int source, unsigned int a, int len, unsigned char inc);

// cd/memory.c
PICO_INTERNAL void PicoMemSetupCD(void);
unsigned int PicoRead8_mcd_io(unsigned int a);
unsigned int PicoRead16_mcd_io(unsigned int a);
void PicoWrite8_mcd_io(unsigned int a, unsigned int d);
void PicoWrite16_mcd_io(unsigned int a, unsigned int d);
void pcd_state_loaded_mem(void);

// pico.c
extern struct Pico Pico;
extern struct PicoSRAM SRam;
extern int PicoPadInt[2];
extern int emustatus;
extern int scanlines_total;
extern void (*PicoResetHook)(void);
extern void (*PicoLineHook)(void);
PICO_INTERNAL int  CheckDMA(void);
PICO_INTERNAL void PicoDetectRegion(void);
PICO_INTERNAL void PicoSyncZ80(unsigned int m68k_cycles_done);

// cd/mcd.c
#define PCDS_IEN1     (1<<1)
#define PCDS_IEN2     (1<<2)
#define PCDS_IEN3     (1<<3)
#define PCDS_IEN4     (1<<4)
#define PCDS_IEN5     (1<<5)
#define PCDS_IEN6     (1<<6)

PICO_INTERNAL void PicoInitMCD(void);
PICO_INTERNAL void PicoExitMCD(void);
PICO_INTERNAL void PicoPowerMCD(void);
PICO_INTERNAL int  PicoResetMCD(void);
PICO_INTERNAL void PicoFrameMCD(void);

enum pcd_event {
  PCD_EVENT_CDC,
  PCD_EVENT_TIMER3,
  PCD_EVENT_GFX,
  PCD_EVENT_DMA,
  PCD_EVENT_COUNT,
};
extern unsigned int pcd_event_times[PCD_EVENT_COUNT];
void pcd_event_schedule(unsigned int now, enum pcd_event event, int after);
void pcd_event_schedule_s68k(enum pcd_event event, int after);
void pcd_prepare_frame(void);
unsigned int pcd_cycles_m68k_to_s68k(unsigned int c);
int  pcd_sync_s68k(unsigned int m68k_target, int m68k_poll_sync);
void pcd_run_cpus(int m68k_cycles);
void pcd_soft_reset(void);
void pcd_state_loaded(void);

// cd/pcm.c
void pcd_pcm_sync(unsigned int to);
void pcd_pcm_update(int *buffer, int length, int stereo);
void pcd_pcm_write(unsigned int a, unsigned int d);
unsigned int pcd_pcm_read(unsigned int a);

// pico/pico.c
PICO_INTERNAL void PicoInitPico(void);
PICO_INTERNAL void PicoReratePico(void);

// pico/xpcm.c
PICO_INTERNAL void PicoPicoPCMUpdate(short *buffer, int length, int stereo);
PICO_INTERNAL void PicoPicoPCMReset(void);
PICO_INTERNAL void PicoPicoPCMRerate(int xpcm_rate);

// sek.c
PICO_INTERNAL void SekInit(void);
PICO_INTERNAL int  SekReset(void);
PICO_INTERNAL void SekState(int *data);
PICO_INTERNAL void SekSetRealTAS(int use_real);
PICO_INTERNAL void SekPackCpu(unsigned char *cpu, int is_sub);
PICO_INTERNAL void SekUnpackCpu(const unsigned char *cpu, int is_sub);
void SekStepM68k(void);
void SekInitIdleDet(void);
void SekFinishIdleDet(void);
#if defined(CPU_CMP_R) || defined(CPU_CMP_W)
void SekTrace(int is_s68k);
#else
#define SekTrace(x)
#endif

// cd/sek.c
PICO_INTERNAL void SekInitS68k(void);
PICO_INTERNAL int  SekResetS68k(void);
PICO_INTERNAL int  SekInterruptS68k(int irq);
void SekInterruptClearS68k(int irq);

// sound/sound.c
extern short cdda_out_buffer[2*1152];
extern int PsndLen_exc_cnt;
extern int PsndLen_exc_add;
extern int timer_a_next_oflow, timer_a_step; // in z80 cycles
extern int timer_b_next_oflow, timer_b_step;

void cdda_start_play(int lba_base, int lba_offset, int lb_len);

void ym2612_sync_timers(int z80_cycles, int mode_old, int mode_new);
void ym2612_pack_state(void);
void ym2612_unpack_state(void);

#define TIMER_NO_OFLOW 0x70000000
// tA =   72 * (1024 - NA) / M
#define TIMER_A_TICK_ZCYCLES  17203
// tB = 1152 * (256 - NA) / M
#define TIMER_B_TICK_ZCYCLES 262800 // 275251 broken, see Dai Makaimura

#define timers_cycle() \
  if (timer_a_next_oflow > 0 && timer_a_next_oflow < TIMER_NO_OFLOW) \
    timer_a_next_oflow -= Pico.m.pal ? 70938*256 : 59659*256; \
  if (timer_b_next_oflow > 0 && timer_b_next_oflow < TIMER_NO_OFLOW) \
    timer_b_next_oflow -= Pico.m.pal ? 70938*256 : 59659*256; \
  ym2612_sync_timers(0, ym2612.OPN.ST.mode, ym2612.OPN.ST.mode);

#define timers_reset() \
  timer_a_next_oflow = timer_b_next_oflow = TIMER_NO_OFLOW; \
  timer_a_step = TIMER_A_TICK_ZCYCLES * 1024; \
  timer_b_step = TIMER_B_TICK_ZCYCLES * 256;


// videoport.c
extern int line_base_cycles;
PICO_INTERNAL_ASM void PicoVideoWrite(unsigned int a,unsigned short d);
PICO_INTERNAL_ASM unsigned int PicoVideoRead(unsigned int a);
PICO_INTERNAL_ASM unsigned int PicoVideoRead8(unsigned int a);
extern int (*PicoDmaHook)(unsigned int source, int len, unsigned short **srcp, unsigned short **limitp);

// misc.c
PICO_INTERNAL_ASM void memcpy16(unsigned short *dest, unsigned short *src, int count);
PICO_INTERNAL_ASM void memcpy16bswap(unsigned short *dest, void *src, int count);
PICO_INTERNAL_ASM void memcpy32(int *dest, int *src, int count); // 32bit word count
PICO_INTERNAL_ASM void memset32(int *dest, int c, int count);

// eeprom.c
void EEPROM_write8(unsigned int a, unsigned int d);
void EEPROM_write16(unsigned int d);
unsigned int EEPROM_read(void);

// z80 functionality wrappers
PICO_INTERNAL void z80_init(void);
PICO_INTERNAL void z80_pack(void *data);
PICO_INTERNAL int  z80_unpack(const void *data);
PICO_INTERNAL void z80_reset(void);
PICO_INTERNAL void z80_exit(void);

// cd/misc.c
PICO_INTERNAL_ASM void wram_2M_to_1M(unsigned char *m);
PICO_INTERNAL_ASM void wram_1M_to_2M(unsigned char *m);

// sound/sound.c
PICO_INTERNAL void PsndReset(void);
PICO_INTERNAL void PsndDoDAC(int line_to);
PICO_INTERNAL void PsndClear(void);
PICO_INTERNAL void PsndGetSamples(int y);
PICO_INTERNAL void PsndGetSamplesMS(void);
extern int PsndDacLine;

// sms.c
#ifndef NO_SMS
void PicoPowerMS(void);
void PicoResetMS(void);
void PicoMemSetupMS(void);
void PicoStateLoadedMS(void);
void PicoFrameMS(void);
void PicoFrameDrawOnlyMS(void);
#else
#define PicoPowerMS()
#define PicoResetMS()
#define PicoMemSetupMS()
#define PicoStateLoadedMS()
#define PicoFrameMS()
#define PicoFrameDrawOnlyMS()
#endif

// 32x/32x.c
#ifndef NO_32X
extern struct Pico32x Pico32x;
enum p32x_event {
  P32X_EVENT_PWM,
  P32X_EVENT_FILLEND,
  P32X_EVENT_HINT,
  P32X_EVENT_COUNT,
};
extern unsigned int p32x_event_times[P32X_EVENT_COUNT];

void Pico32xInit(void);
void PicoPower32x(void);
void PicoReset32x(void);
void Pico32xStartup(void);
void PicoUnload32x(void);
void PicoFrame32x(void);
void Pico32xStateLoaded(int is_early);
void p32x_sync_sh2s(unsigned int m68k_target);
void p32x_sync_other_sh2(SH2 *sh2, unsigned int m68k_target);
void p32x_update_irls(SH2 *active_sh2, int m68k_cycles);
void p32x_trigger_irq(SH2 *sh2, int m68k_cycles, unsigned int mask);
void p32x_update_cmd_irq(SH2 *sh2, int m68k_cycles);
void p32x_reset_sh2s(void);
void p32x_event_schedule(unsigned int now, enum p32x_event event, int after);
void p32x_event_schedule_sh2(SH2 *sh2, enum p32x_event event, int after);
void p32x_schedule_hint(SH2 *sh2, int m68k_cycles);

// 32x/memory.c
struct Pico32xMem *Pico32xMem;
unsigned int PicoRead8_32x(unsigned int a);
unsigned int PicoRead16_32x(unsigned int a);
void PicoWrite8_32x(unsigned int a, unsigned int d);
void PicoWrite16_32x(unsigned int a, unsigned int d);
void PicoMemSetup32x(void);
void Pico32xSwapDRAM(int b);
void Pico32xMemStateLoaded(void);
void p32x_m68k_poll_event(unsigned int flags);
void p32x_sh2_poll_event(SH2 *sh2, unsigned int flags, unsigned int m68k_cycles);

// 32x/draw.c
void PicoDrawSetOutFormat32x(pdso_t which, int use_32x_line_mode);
void FinalizeLine32xRGB555(int sh, int line);
void PicoDraw32xLayer(int offs, int lines, int mdbg);
void PicoDraw32xLayerMdOnly(int offs, int lines);
extern int (*PicoScan32xBegin)(unsigned int num);
extern int (*PicoScan32xEnd)(unsigned int num);
enum {
  PDM32X_OFF,
  PDM32X_32X_ONLY,
  PDM32X_BOTH,
};
extern int Pico32xDrawMode;

// 32x/pwm.c
unsigned int p32x_pwm_read16(unsigned int a, SH2 *sh2,
  unsigned int m68k_cycles);
void p32x_pwm_write16(unsigned int a, unsigned int d,
  SH2 *sh2, unsigned int m68k_cycles);
void p32x_pwm_update(int *buf32, int length, int stereo);
void p32x_pwm_ctl_changed(void);
void p32x_pwm_schedule(unsigned int m68k_now);
void p32x_pwm_schedule_sh2(SH2 *sh2);
void p32x_pwm_sync_to_sh2(SH2 *sh2);
void p32x_pwm_irq_event(unsigned int m68k_now);
void p32x_pwm_state_loaded(void);

// 32x/sh2soc.c
void p32x_dreq0_trigger(void);
void p32x_dreq1_trigger(void);
void p32x_timers_recalc(void);
void p32x_timers_do(unsigned int m68k_slice);
void sh2_peripheral_reset(SH2 *sh2);
unsigned int sh2_peripheral_read8(unsigned int a, SH2 *sh2);
unsigned int sh2_peripheral_read16(unsigned int a, SH2 *sh2);
unsigned int sh2_peripheral_read32(unsigned int a, SH2 *sh2);
void REGPARM(3) sh2_peripheral_write8(unsigned int a, unsigned int d, SH2 *sh2);
void REGPARM(3) sh2_peripheral_write16(unsigned int a, unsigned int d, SH2 *sh2);
void REGPARM(3) sh2_peripheral_write32(unsigned int a, unsigned int d, SH2 *sh2);

#else
#define Pico32xInit()
#define PicoPower32x()
#define PicoReset32x()
#define PicoFrame32x()
#define PicoUnload32x()
#define Pico32xStateLoaded()
#define FinalizeLine32xRGB555 NULL
#define p32x_pwm_update(...)
#define p32x_timers_recalc()
#endif

/* avoid dependency on newer glibc */
static __inline int isspace_(int c)
{
	return (0x09 <= c && c <= 0x0d) || c == ' ';
}

#ifndef ARRAY_SIZE
#define ARRAY_SIZE(x) (sizeof(x) / sizeof(x[0]))
#endif

// emulation event logging
#ifndef EL_LOGMASK
# ifdef __x86_64__ // HACK
#  define EL_LOGMASK (EL_STATUS|EL_IDLE|EL_ANOMALY)
# else
#  define EL_LOGMASK (EL_STATUS)
# endif
#endif

#define EL_HVCNT   0x00000001 /* hv counter reads */
#define EL_SR      0x00000002 /* SR reads */
#define EL_INTS    0x00000004 /* ints and acks */
#define EL_YMTIMER 0x00000008 /* ym2612 timer stuff */
#define EL_INTSW   0x00000010 /* log irq switching on/off */
#define EL_ASVDP   0x00000020 /* VDP accesses during active scan */
#define EL_VDPDMA  0x00000040 /* VDP DMA transfers and their timing */
#define EL_BUSREQ  0x00000080 /* z80 busreq r/w or reset w */
#define EL_Z80BNK  0x00000100 /* z80 i/o through bank area */
#define EL_SRAMIO  0x00000200 /* sram i/o */
#define EL_EEPROM  0x00000400 /* eeprom debug */
#define EL_UIO     0x00000800 /* unmapped i/o */
#define EL_IO      0x00001000 /* all i/o */
#define EL_CDPOLL  0x00002000 /* MCD: log poll detection */
#define EL_SVP     0x00004000 /* SVP stuff */
#define EL_PICOHW  0x00008000 /* Pico stuff */
#define EL_IDLE    0x00010000 /* idle loop det. */
#define EL_CDREGS  0x00020000 /* MCD: register access */
#define EL_CDREG3  0x00040000 /* MCD: register 3 only */
#define EL_32X     0x00080000
#define EL_PWM     0x00100000 /* 32X PWM stuff (LOTS of output) */
#define EL_32XP    0x00200000 /* 32X peripherals */
#define EL_CD      0x00400000 /* MCD */

#define EL_STATUS  0x40000000 /* status messages */
#define EL_ANOMALY 0x80000000 /* some unexpected conditions (during emulation) */

#if EL_LOGMASK
#define elprintf(w,f,...) \
do { \
	if ((w) & EL_LOGMASK) \
		lprintf("%05i:%03i: " f "\n",Pico.m.frame_count,Pico.m.scanline,##__VA_ARGS__); \
} while (0)
#elif defined(_MSC_VER)
#define elprintf
#else
#define elprintf(w,f,...)
#endif

// profiling
#ifdef PPROF
#include <platform/linux/pprof.h>
#else
#define pprof_init()
#define pprof_finish()
#define pprof_start(x)
#define pprof_end(...)
#define pprof_end_sub(...)
#endif

#ifdef EVT_LOG
enum evt {
  EVT_FRAME_START,
  EVT_NEXT_LINE,
  EVT_RUN_START,
  EVT_RUN_END,
  EVT_POLL_START,
  EVT_POLL_END,
  EVT_CNT
};

enum evt_cpu {
  EVT_M68K,
  EVT_S68K,
  EVT_MSH2,
  EVT_SSH2,
  EVT_CPU_CNT
};

void pevt_log(unsigned int cycles, enum evt_cpu c, enum evt e);
void pevt_dump(void);

#define pevt_log_m68k(e) \
  pevt_log(SekCyclesDone(), EVT_M68K, e)
#define pevt_log_m68k_o(e) \
  pevt_log(SekCyclesDone(), EVT_M68K, e)
#define pevt_log_sh2(sh2, e) \
  pevt_log(sh2_cycles_done_m68k(sh2), EVT_MSH2 + (sh2)->is_slave, e)
#define pevt_log_sh2_o(sh2, e) \
  pevt_log((sh2)->m68krcycles_done, EVT_MSH2 + (sh2)->is_slave, e)
#else
#define pevt_log(c, e)
#define pevt_log_m68k(e)
#define pevt_log_m68k_o(e)
#define pevt_log_sh2(sh2, e)
#define pevt_log_sh2_o(sh2, e)
#define pevt_dump()
#endif

// misc
#ifdef _MSC_VER
#define cdprintf
#else
#define cdprintf(x...)
#endif

#if defined(__GNUC__) && defined(__i386__)
#define REGPARM(x) __attribute__((regparm(x)))
#else
#define REGPARM(x)
#endif

#ifdef __GNUC__
#define NOINLINE __attribute__((noinline))
#else
#define NOINLINE
#endif

#ifdef __cplusplus
} // End of extern "C"
#endif

#endif // PICO_INTERNAL_INCLUDED

