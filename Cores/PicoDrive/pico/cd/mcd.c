/*
 * PicoDrive
 * (C) notaz, 2007,2013
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include "../pico_int.h"
#include "../sound/ym2612.h"

extern unsigned char formatted_bram[4*0x10];

static unsigned int mcd_m68k_cycle_mult;
static unsigned int mcd_m68k_cycle_base;
static unsigned int mcd_s68k_cycle_base;

void (*PicoMCDopenTray)(void) = NULL;
void (*PicoMCDcloseTray)(void) = NULL;


PICO_INTERNAL void PicoInitMCD(void)
{
  SekInitS68k();
}

PICO_INTERNAL void PicoExitMCD(void)
{
}

PICO_INTERNAL void PicoPowerMCD(void)
{
  SekCycleCntS68k = SekCycleAimS68k = 0;

  int fmt_size = sizeof(formatted_bram);
  memset(Pico_mcd->prg_ram,    0, sizeof(Pico_mcd->prg_ram));
  memset(Pico_mcd->word_ram2M, 0, sizeof(Pico_mcd->word_ram2M));
  memset(Pico_mcd->pcm_ram,    0, sizeof(Pico_mcd->pcm_ram));
  memset(Pico_mcd->bram, 0, sizeof(Pico_mcd->bram));
  memcpy(Pico_mcd->bram + sizeof(Pico_mcd->bram) - fmt_size,
    formatted_bram, fmt_size);
  memset(Pico_mcd->s68k_regs, 0, sizeof(Pico_mcd->s68k_regs));
  memset(&Pico_mcd->pcm, 0, sizeof(Pico_mcd->pcm));
  memset(&Pico_mcd->m, 0, sizeof(Pico_mcd->m));

  cdc_init();
  gfx_init();

  // cold reset state (tested)
  Pico_mcd->m.state_flags = PCD_ST_S68K_RST;
  Pico_mcd->m.busreq = 2;     // busreq on, s68k in reset
  Pico_mcd->s68k_regs[3] = 1; // 2M word RAM mode, m68k access
  memset(Pico_mcd->bios + 0x70, 0xff, 4);
}

void pcd_soft_reset(void)
{
  elprintf(EL_CD, "cd: soft reset");

  Pico_mcd->m.s68k_pend_ints = 0;
  cdc_reset();
  cdd_reset();
#ifdef _ASM_CD_MEMORY_C
  //PicoMemResetCDdecode(1); // don't have to call this in 2M mode
#endif

  memset(&Pico_mcd->s68k_regs[0x38], 0, 9);
  Pico_mcd->s68k_regs[0x38+9] = 0x0f;  // default checksum

  pcd_event_schedule_s68k(PCD_EVENT_CDC, 12500000/75);

  // TODO: test if register state/timers change
}

PICO_INTERNAL int PicoResetMCD(void)
{
  // reset button doesn't affect MCD hardware

  // use SRam.data for RAM cart
  if (PicoOpt & POPT_EN_MCD_RAMCART) {
    if (SRam.data == NULL)
      SRam.data = calloc(1, 0x12000);
  }
  else if (SRam.data != NULL) {
    free(SRam.data);
    SRam.data = NULL;
      SRam.size = 0;
  }
  SRam.start = SRam.end = 0; // unused

  return 0;
}

static void SekRunM68kOnce(void)
{
  int cyc_do;
  pevt_log_m68k_o(EVT_RUN_START);

  if ((cyc_do = SekCycleAim - SekCycleCnt) > 0) {
    SekCycleCnt += cyc_do;

#if defined(EMU_C68K)
    PicoCpuCM68k.cycles = cyc_do;
    CycloneRun(&PicoCpuCM68k);
    SekCycleCnt -= PicoCpuCM68k.cycles;
#elif defined(EMU_M68K)
    SekCycleCnt += m68k_execute(cyc_do) - cyc_do;
#elif defined(EMU_F68K)
    SekCycleCnt += fm68k_emulate(cyc_do, 0) - cyc_do;
#endif
  }

  SekCyclesLeft = 0;

  SekTrace(0);
  pevt_log_m68k_o(EVT_RUN_END);
}

static void SekRunS68k(unsigned int to)
{
  int cyc_do;

  SekCycleAimS68k = to;
  if ((cyc_do = SekCycleAimS68k - SekCycleCntS68k) <= 0)
    return;

  if (SekShouldInterrupt())
    Pico_mcd->m.s68k_poll_a = 0;

  SekCycleCntS68k += cyc_do;
#if defined(EMU_C68K)
  PicoCpuCS68k.cycles = cyc_do;
  CycloneRun(&PicoCpuCS68k);
  SekCycleCntS68k -= PicoCpuCS68k.cycles;
#elif defined(EMU_M68K)
  m68k_set_context(&PicoCpuMS68k);
  SekCycleCntS68k += m68k_execute(cyc_do) - cyc_do;
  m68k_set_context(&PicoCpuMM68k);
#elif defined(EMU_F68K)
  g_m68kcontext = &PicoCpuFS68k;
  SekCycleCntS68k += fm68k_emulate(cyc_do, 0) - cyc_do;
  g_m68kcontext = &PicoCpuFM68k;
#endif
}

static void pcd_set_cycle_mult(void)
{
  // ~1.63 for NTSC, ~1.645 for PAL
  if (Pico.m.pal)
    mcd_m68k_cycle_mult = ((12500000ull << 16) / (50*312*488));
  else
    mcd_m68k_cycle_mult = ((12500000ull << 16) / (60*262*488)) + 1;
}

unsigned int pcd_cycles_m68k_to_s68k(unsigned int c)
{
  return (long long)c * mcd_m68k_cycle_mult >> 16;
}

/* events */
static void pcd_cdc_event(unsigned int now)
{
  // 75Hz CDC update
  cdd_update();

  /* check if a new CDD command has been processed */
  if (!(Pico_mcd->s68k_regs[0x4b] & 0xf0))
  {
    /* reset CDD command wait flag */
    Pico_mcd->s68k_regs[0x4b] = 0xf0;

    if (Pico_mcd->s68k_regs[0x33] & PCDS_IEN4) {
      elprintf(EL_INTS|EL_CD, "s68k: cdd irq 4");
      SekInterruptS68k(4);
    }
  }

  pcd_event_schedule(now, PCD_EVENT_CDC, 12500000/75);
}

static void pcd_int3_timer_event(unsigned int now)
{
  if (Pico_mcd->s68k_regs[0x33] & PCDS_IEN3) {
    elprintf(EL_INTS|EL_CD, "s68k: timer irq 3");
    SekInterruptS68k(3);
  }

  if (Pico_mcd->s68k_regs[0x31] != 0)
    pcd_event_schedule(now, PCD_EVENT_TIMER3,
      Pico_mcd->s68k_regs[0x31] * 384);
}

static void pcd_dma_event(unsigned int now)
{
  cdc_dma_update();
}

typedef void (event_cb)(unsigned int now);

/* times are in s68k (12.5MHz) cycles */
unsigned int pcd_event_times[PCD_EVENT_COUNT];
static unsigned int event_time_next;
static event_cb *pcd_event_cbs[PCD_EVENT_COUNT] = {
  [PCD_EVENT_CDC]      = pcd_cdc_event,
  [PCD_EVENT_TIMER3]   = pcd_int3_timer_event,
  [PCD_EVENT_GFX]      = gfx_update,
  [PCD_EVENT_DMA]      = pcd_dma_event,
};

void pcd_event_schedule(unsigned int now, enum pcd_event event, int after)
{
  unsigned int when;

  when = now + after;
  if (when == 0) {
    // event cancelled
    pcd_event_times[event] = 0;
    return;
  }

  when |= 1;

  elprintf(EL_CD, "cd: new event #%u %u->%u", event, now, when);
  pcd_event_times[event] = when;

  if (event_time_next == 0 || CYCLES_GT(event_time_next, when))
    event_time_next = when;
}

void pcd_event_schedule_s68k(enum pcd_event event, int after)
{
  if (SekCyclesLeftS68k > after)
    SekEndRunS68k(after);

  pcd_event_schedule(SekCyclesDoneS68k(), event, after);
}

static void pcd_run_events(unsigned int until)
{
  int oldest, oldest_diff, time;
  int i, diff;

  while (1) {
    oldest = -1, oldest_diff = 0x7fffffff;

    for (i = 0; i < PCD_EVENT_COUNT; i++) {
      if (pcd_event_times[i]) {
        diff = pcd_event_times[i] - until;
        if (diff < oldest_diff) {
          oldest_diff = diff;
          oldest = i;
        }
      }
    }

    if (oldest_diff <= 0) {
      time = pcd_event_times[oldest];
      pcd_event_times[oldest] = 0;
      elprintf(EL_CD, "cd: run event #%d %u", oldest, time);
      pcd_event_cbs[oldest](time);
    }
    else if (oldest_diff < 0x7fffffff) {
      event_time_next = pcd_event_times[oldest];
      break;
    }
    else {
      event_time_next = 0;
      break;
    }
  }

  if (oldest != -1)
    elprintf(EL_CD, "cd: next event #%d at %u",
      oldest, event_time_next);
}

int pcd_sync_s68k(unsigned int m68k_target, int m68k_poll_sync)
{
  #define now SekCycleCntS68k
  unsigned int s68k_target;
  unsigned int target;

  target = m68k_target - mcd_m68k_cycle_base;
  s68k_target = mcd_s68k_cycle_base +
    ((unsigned long long)target * mcd_m68k_cycle_mult >> 16);

  elprintf(EL_CD, "s68k sync to %u, %u->%u",
    m68k_target, now, s68k_target);

  if (Pico_mcd->m.busreq != 1) { /* busreq/reset */
    SekCycleCntS68k = SekCycleAimS68k = s68k_target;
    pcd_run_events(m68k_target);
    return 0;
  }

  while (CYCLES_GT(s68k_target, now)) {
    if (event_time_next && CYCLES_GE(now, event_time_next))
      pcd_run_events(now);

    target = s68k_target;
    if (event_time_next && CYCLES_GT(target, event_time_next))
      target = event_time_next;

    SekRunS68k(target);
    if (m68k_poll_sync && Pico_mcd->m.m68k_poll_cnt == 0)
      break;
  }

  return s68k_target - now;
  #undef now
}

#define pcd_run_cpus_normal pcd_run_cpus
//#define pcd_run_cpus_lockstep pcd_run_cpus

static void SekSyncM68k(void);

void pcd_run_cpus_normal(int m68k_cycles)
{
  SekCycleAim += m68k_cycles;
  if (SekShouldInterrupt() || Pico_mcd->m.m68k_poll_cnt < 12)
    Pico_mcd->m.m68k_poll_cnt = 0;
  else if (Pico_mcd->m.m68k_poll_cnt >= 16) {
    int s68k_left = pcd_sync_s68k(SekCycleAim, 1);
    if (s68k_left <= 0) {
      elprintf(EL_CDPOLL, "m68k poll [%02x] x%d @%06x",
        Pico_mcd->m.m68k_poll_a, Pico_mcd->m.m68k_poll_cnt, SekPc);
      SekCycleCnt = SekCycleAim;
      return;
    }
    SekCycleCnt = SekCycleAim - (s68k_left * 40220 >> 16);
  }

  while (CYCLES_GT(SekCycleAim, SekCycleCnt)) {
    SekRunM68kOnce();
    if (Pico_mcd->m.need_sync) {
      Pico_mcd->m.need_sync = 0;
      pcd_sync_s68k(SekCycleCnt, 0);
    }
  }
}

void pcd_run_cpus_lockstep(int m68k_cycles)
{
  unsigned int target = SekCycleAim + m68k_cycles;
  do {
    SekCycleAim += 8;
    SekSyncM68k();
    pcd_sync_s68k(SekCycleAim, 0);
  } while (CYCLES_GT(target, SekCycleAim));

  SekCycleAim = target;
}

#define PICO_CD
#define CPUS_RUN(m68k_cycles) \
  pcd_run_cpus(m68k_cycles)

#include "../pico_cmn.c"


void pcd_prepare_frame(void)
{
  pcd_set_cycle_mult();

  // need this because we can't have direct mapping between
  // master<->slave cycle counters because of overflows
  mcd_m68k_cycle_base = SekCycleAim;
  mcd_s68k_cycle_base = SekCycleAimS68k;
}

PICO_INTERNAL void PicoFrameMCD(void)
{
  PicoFrameStart();

  pcd_prepare_frame();
  PicoFrameHints();
}

void pcd_state_loaded(void)
{
  unsigned int cycles;
  int diff;

  pcd_set_cycle_mult();
  pcd_state_loaded_mem();

  memset(Pico_mcd->pcm_mixbuf, 0, sizeof(Pico_mcd->pcm_mixbuf));
  Pico_mcd->pcm_mixbuf_dirty = 0;
  Pico_mcd->pcm_mixpos = 0;
  Pico_mcd->pcm_regs_dirty = 1;

  // old savestates..
  cycles = pcd_cycles_m68k_to_s68k(SekCycleAim);
  diff = cycles - SekCycleAimS68k;
  if (diff < -1000 || diff > 1000) {
    SekCycleCntS68k = SekCycleAimS68k = cycles;
  }
  if (pcd_event_times[PCD_EVENT_CDC] == 0) {
    pcd_event_schedule(SekCycleAimS68k, PCD_EVENT_CDC, 12500000/75);

    if (Pico_mcd->s68k_regs[0x31])
      pcd_event_schedule(SekCycleAimS68k, PCD_EVENT_TIMER3,
        Pico_mcd->s68k_regs[0x31] * 384);
  }

  diff = cycles - Pico_mcd->pcm.update_cycles;
  if ((unsigned int)diff > 12500000/50)
    Pico_mcd->pcm.update_cycles = cycles;

  // reschedule
  event_time_next = 0;
  pcd_run_events(SekCycleCntS68k);
}

// vim:shiftwidth=2:ts=2:expandtab
