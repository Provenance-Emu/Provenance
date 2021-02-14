/*
 * PicoDrive
 * (C) notaz, 2009,2010,2013
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */
#include "../pico_int.h"
#include "../sound/ym2612.h"
#include "../../cpu/sh2/compiler.h"

struct Pico32x Pico32x;
SH2 sh2s[2];

#define SH2_IDLE_STATES (SH2_STATE_CPOLL|SH2_STATE_VPOLL|SH2_STATE_SLEEP)

static int REGPARM(2) sh2_irq_cb(SH2 *sh2, int level)
{
  if (sh2->pending_irl > sh2->pending_int_irq) {
    elprintf_sh2(sh2, EL_32X, "ack/irl %d @ %08x",
      level, sh2_pc(sh2));
    return 64 + sh2->pending_irl / 2;
  } else {
    elprintf_sh2(sh2, EL_32X, "ack/int %d/%d @ %08x",
      level, sh2->pending_int_vector, sh2_pc(sh2));
    sh2->pending_int_irq = 0; // auto-clear
    sh2->pending_level = sh2->pending_irl;
    return sh2->pending_int_vector;
  }
}

// MUST specify active_sh2 when called from sh2 memhandlers
void p32x_update_irls(SH2 *active_sh2, int m68k_cycles)
{
  int irqs, mlvl = 0, slvl = 0;
  int mrun, srun;

  if (active_sh2 != NULL)
    m68k_cycles = sh2_cycles_done_m68k(active_sh2);

  // msh2
  irqs = Pico32x.sh2irqs | Pico32x.sh2irqi[0];
  while ((irqs >>= 1))
    mlvl++;
  mlvl *= 2;

  // ssh2
  irqs = Pico32x.sh2irqs | Pico32x.sh2irqi[1];
  while ((irqs >>= 1))
    slvl++;
  slvl *= 2;

  mrun = sh2_irl_irq(&msh2, mlvl, active_sh2 == &msh2);
  if (mrun) {
    p32x_sh2_poll_event(&msh2, SH2_IDLE_STATES, m68k_cycles);
    if (active_sh2 == &msh2)
      sh2_end_run(active_sh2, 1);
  }

  srun = sh2_irl_irq(&ssh2, slvl, active_sh2 == &ssh2);
  if (srun) {
    p32x_sh2_poll_event(&ssh2, SH2_IDLE_STATES, m68k_cycles);
    if (active_sh2 == &ssh2)
      sh2_end_run(active_sh2, 1);
  }

  elprintf(EL_32X, "update_irls: m %d/%d, s %d/%d", mlvl, mrun, slvl, srun);
}

// the mask register is inconsistent, CMD is supposed to be a mask,
// while others are actually irq trigger enables?
// TODO: test on hw..
void p32x_trigger_irq(SH2 *sh2, int m68k_cycles, unsigned int mask)
{
  Pico32x.sh2irqs |= mask & P32XI_VRES;
  Pico32x.sh2irqi[0] |= mask & (Pico32x.sh2irq_mask[0] << 3);
  Pico32x.sh2irqi[1] |= mask & (Pico32x.sh2irq_mask[1] << 3);

  p32x_update_irls(sh2, m68k_cycles);
}

void p32x_update_cmd_irq(SH2 *sh2, int m68k_cycles)
{
  if ((Pico32x.sh2irq_mask[0] & 2) && (Pico32x.regs[2 / 2] & 1))
    Pico32x.sh2irqi[0] |= P32XI_CMD;
  else
    Pico32x.sh2irqi[0] &= ~P32XI_CMD;

  if ((Pico32x.sh2irq_mask[1] & 2) && (Pico32x.regs[2 / 2] & 2))
    Pico32x.sh2irqi[1] |= P32XI_CMD;
  else
    Pico32x.sh2irqi[1] &= ~P32XI_CMD;

  p32x_update_irls(sh2, m68k_cycles);
}

void Pico32xStartup(void)
{
  elprintf(EL_STATUS|EL_32X, "32X startup");

  // TODO: OOM handling
  PicoAHW |= PAHW_32X;
  sh2_init(&msh2, 0, &ssh2);
  msh2.irq_callback = sh2_irq_cb;
  sh2_init(&ssh2, 1, &msh2);
  ssh2.irq_callback = sh2_irq_cb;

  PicoMemSetup32x();
  p32x_pwm_ctl_changed();
  p32x_timers_recalc();

  Pico32x.sh2_regs[0] = P32XS2_ADEN;
  if (Pico.m.ncart_in)
    Pico32x.sh2_regs[0] |= P32XS_nCART;

  if (!Pico.m.pal)
    Pico32x.vdp_regs[0] |= P32XV_nPAL;

  rendstatus_old = -1;

  emu_32x_startup();
}

#define HWSWAP(x) (((x) << 16) | ((x) >> 16))
void p32x_reset_sh2s(void)
{
  elprintf(EL_32X, "sh2 reset");

  sh2_reset(&msh2);
  sh2_reset(&ssh2);
  sh2_peripheral_reset(&msh2);
  sh2_peripheral_reset(&ssh2);

  // if we don't have BIOS set, perform it's work here.
  // MSH2
  if (p32x_bios_m == NULL) {
    unsigned int idl_src, idl_dst, idl_size; // initial data load
    unsigned int vbr;

    // initial data
    idl_src = HWSWAP(*(unsigned int *)(Pico.rom + 0x3d4)) & ~0xf0000000;
    idl_dst = HWSWAP(*(unsigned int *)(Pico.rom + 0x3d8)) & ~0xf0000000;
    idl_size= HWSWAP(*(unsigned int *)(Pico.rom + 0x3dc));
    if (idl_size > Pico.romsize || idl_src + idl_size > Pico.romsize ||
        idl_size > 0x40000 || idl_dst + idl_size > 0x40000 || (idl_src & 3) || (idl_dst & 3)) {
      elprintf(EL_STATUS|EL_ANOMALY, "32x: invalid initial data ptrs: %06x -> %06x, %06x",
        idl_src, idl_dst, idl_size);
    }
    else
      memcpy(Pico32xMem->sdram + idl_dst, Pico.rom + idl_src, idl_size);

    // GBR/VBR
    vbr = HWSWAP(*(unsigned int *)(Pico.rom + 0x3e8));
    sh2_set_gbr(0, 0x20004000);
    sh2_set_vbr(0, vbr);

    // checksum and M_OK
    Pico32x.regs[0x28 / 2] = *(unsigned short *)(Pico.rom + 0x18e);
    // program will set M_OK
  }

  // SSH2
  if (p32x_bios_s == NULL) {
    unsigned int vbr;

    // GBR/VBR
    vbr = HWSWAP(*(unsigned int *)(Pico.rom + 0x3ec));
    sh2_set_gbr(1, 0x20004000);
    sh2_set_vbr(1, vbr);
    // program will set S_OK
  }

  msh2.m68krcycles_done = ssh2.m68krcycles_done = SekCyclesDone();
}

void Pico32xInit(void)
{
  if (msh2.mult_m68k_to_sh2 == 0 || msh2.mult_sh2_to_m68k == 0)
    Pico32xSetClocks(PICO_MSH2_HZ, 0);
  if (ssh2.mult_m68k_to_sh2 == 0 || ssh2.mult_sh2_to_m68k == 0)
    Pico32xSetClocks(0, PICO_MSH2_HZ);
}

void PicoPower32x(void)
{
  memset(&Pico32x, 0, sizeof(Pico32x));

  Pico32x.regs[0] = P32XS_REN|P32XS_nRES; // verified
  Pico32x.vdp_regs[0x0a/2] = P32XV_VBLK|P32XV_PEN;
}

void PicoUnload32x(void)
{
  if (Pico32xMem != NULL)
    plat_munmap(Pico32xMem, sizeof(*Pico32xMem));
  Pico32xMem = NULL;
  sh2_finish(&msh2);
  sh2_finish(&ssh2);

  PicoAHW &= ~PAHW_32X;
}

void PicoReset32x(void)
{
  if (PicoAHW & PAHW_32X) {
    p32x_trigger_irq(NULL, SekCyclesDone(), P32XI_VRES);
    p32x_sh2_poll_event(&msh2, SH2_IDLE_STATES, 0);
    p32x_sh2_poll_event(&ssh2, SH2_IDLE_STATES, 0);
    p32x_pwm_ctl_changed();
    p32x_timers_recalc();
  }
}

static void p32x_start_blank(void)
{
  if (Pico32xDrawMode != PDM32X_OFF && !PicoSkipFrame) {
    int offs, lines;

    pprof_start(draw);

    offs = 8; lines = 224;
    if ((Pico.video.reg[1] & 8) && !(PicoOpt & POPT_ALT_RENDERER)) {
      offs = 0;
      lines = 240;
    }

    // XXX: no proper handling of 32col mode..
    if ((Pico32x.vdp_regs[0] & P32XV_Mx) != 0 && // 32x not blanking
        (Pico.video.reg[12] & 1) && // 40col mode
        (PicoDrawMask & PDRAW_32X_ON))
    {
      int md_bg = Pico.video.reg[7] & 0x3f;

      // we draw full layer (not line-by-line)
      PicoDraw32xLayer(offs, lines, md_bg);
    }
    else if (Pico32xDrawMode != PDM32X_32X_ONLY)
      PicoDraw32xLayerMdOnly(offs, lines);

    pprof_end(draw);
  }

  // enter vblank
  Pico32x.vdp_regs[0x0a/2] |= P32XV_VBLK|P32XV_PEN;

  // FB swap waits until vblank
  if ((Pico32x.vdp_regs[0x0a/2] ^ Pico32x.pending_fb) & P32XV_FS) {
    Pico32x.vdp_regs[0x0a/2] &= ~P32XV_FS;
    Pico32x.vdp_regs[0x0a/2] |= Pico32x.pending_fb;
    Pico32xSwapDRAM(Pico32x.pending_fb ^ 1);
  }

  p32x_trigger_irq(NULL, SekCyclesDone(), P32XI_VINT);
  p32x_sh2_poll_event(&msh2, SH2_STATE_VPOLL, 0);
  p32x_sh2_poll_event(&ssh2, SH2_STATE_VPOLL, 0);
}

void p32x_schedule_hint(SH2 *sh2, int m68k_cycles)
{
  // rather rough, 32x hint is useless in practice
  int after;

  if (!((Pico32x.sh2irq_mask[0] | Pico32x.sh2irq_mask[1]) & 4))
    return; // nobody cares
  // note: when Pico.m.scanline is 224, SH2s might
  // still be at scanline 93 (or so)
  if (!(Pico32x.sh2_regs[0] & 0x80) && Pico.m.scanline > 224)
    return;

  after = (Pico32x.sh2_regs[4 / 2] + 1) * 488;
  if (sh2 != NULL)
    p32x_event_schedule_sh2(sh2, P32X_EVENT_HINT, after);
  else
    p32x_event_schedule(m68k_cycles, P32X_EVENT_HINT, after);
}

/* events */
static void fillend_event(unsigned int now)
{
  Pico32x.vdp_regs[0x0a/2] &= ~P32XV_nFEN;
  p32x_sh2_poll_event(&msh2, SH2_STATE_VPOLL, now);
  p32x_sh2_poll_event(&ssh2, SH2_STATE_VPOLL, now);
}

static void hint_event(unsigned int now)
{
  p32x_trigger_irq(NULL, now, P32XI_HINT);
  p32x_schedule_hint(NULL, now);
}

typedef void (event_cb)(unsigned int now);

/* times are in m68k (7.6MHz) cycles */
unsigned int p32x_event_times[P32X_EVENT_COUNT];
static unsigned int event_time_next;
static event_cb *p32x_event_cbs[P32X_EVENT_COUNT] = {
  [P32X_EVENT_PWM]      = p32x_pwm_irq_event,
  [P32X_EVENT_FILLEND]  = fillend_event,
  [P32X_EVENT_HINT]     = hint_event,
};

// schedule event at some time 'after', in m68k clocks
void p32x_event_schedule(unsigned int now, enum p32x_event event, int after)
{
  unsigned int when;

  when = (now + after) | 1;

  elprintf(EL_32X, "32x: new event #%u %u->%u", event, now, when);
  p32x_event_times[event] = when;

  if (event_time_next == 0 || CYCLES_GT(event_time_next, when))
    event_time_next = when;
}

void p32x_event_schedule_sh2(SH2 *sh2, enum p32x_event event, int after)
{
  unsigned int now = sh2_cycles_done_m68k(sh2);
  int left_to_next;

  p32x_event_schedule(now, event, after);

  left_to_next = (event_time_next - now) * 3;
  sh2_end_run(sh2, left_to_next);
}

static void p32x_run_events(unsigned int until)
{
  int oldest, oldest_diff, time;
  int i, diff;

  while (1) {
    oldest = -1, oldest_diff = 0x7fffffff;

    for (i = 0; i < P32X_EVENT_COUNT; i++) {
      if (p32x_event_times[i]) {
        diff = p32x_event_times[i] - until;
        if (diff < oldest_diff) {
          oldest_diff = diff;
          oldest = i;
        }
      }
    }

    if (oldest_diff <= 0) {
      time = p32x_event_times[oldest];
      p32x_event_times[oldest] = 0;
      elprintf(EL_32X, "32x: run event #%d %u", oldest, time);
      p32x_event_cbs[oldest](time);
    }
    else if (oldest_diff < 0x7fffffff) {
      event_time_next = p32x_event_times[oldest];
      break;
    }
    else {
      event_time_next = 0;
      break;
    }
  }

  if (oldest != -1)
    elprintf(EL_32X, "32x: next event #%d at %u",
      oldest, event_time_next);
}

static inline void run_sh2(SH2 *sh2, int m68k_cycles)
{
  int cycles, done;

  pevt_log_sh2_o(sh2, EVT_RUN_START);
  sh2->state |= SH2_STATE_RUN;
  cycles = C_M68K_TO_SH2(*sh2, m68k_cycles);
  elprintf_sh2(sh2, EL_32X, "+run %u %d @%08x",
    sh2->m68krcycles_done, cycles, sh2->pc);

  done = sh2_execute(sh2, cycles, PicoOpt & POPT_EN_DRC);

  sh2->m68krcycles_done += C_SH2_TO_M68K(*sh2, done);
  sh2->state &= ~SH2_STATE_RUN;
  pevt_log_sh2_o(sh2, EVT_RUN_END);
  elprintf_sh2(sh2, EL_32X, "-run %u %d",
    sh2->m68krcycles_done, done);
}

// sync other sh2 to this one
// note: recursive call
void p32x_sync_other_sh2(SH2 *sh2, unsigned int m68k_target)
{
  SH2 *osh2 = sh2->other_sh2;
  int left_to_event;
  int m68k_cycles;

  if (osh2->state & SH2_STATE_RUN)
    return;

  m68k_cycles = m68k_target - osh2->m68krcycles_done;
  if (m68k_cycles < 200)
    return;

  if (osh2->state & SH2_IDLE_STATES) {
    osh2->m68krcycles_done = m68k_target;
    return;
  }

  elprintf_sh2(osh2, EL_32X, "sync to %u %d",
    m68k_target, m68k_cycles);

  run_sh2(osh2, m68k_cycles);

  // there might be new event to schedule current sh2 to
  if (event_time_next) {
    left_to_event = event_time_next - m68k_target;
    left_to_event *= 3;
    if (sh2_cycles_left(sh2) > left_to_event) {
      if (left_to_event < 1)
        left_to_event = 1;
      sh2_end_run(sh2, left_to_event);
    }
  }
}

#define sync_sh2s_normal p32x_sync_sh2s
//#define sync_sh2s_lockstep p32x_sync_sh2s

/* most timing is in 68k clock */
void sync_sh2s_normal(unsigned int m68k_target)
{
  unsigned int now, target, timer_cycles;
  int cycles;

  elprintf(EL_32X, "sh2 sync to %u", m68k_target);

  if (!(Pico32x.regs[0] & P32XS_nRES)) {
    msh2.m68krcycles_done = ssh2.m68krcycles_done = m68k_target;
    return; // rare
  }

  now = msh2.m68krcycles_done;
  if (CYCLES_GT(now, ssh2.m68krcycles_done))
    now = ssh2.m68krcycles_done;
  timer_cycles = now;

  while (CYCLES_GT(m68k_target, now))
  {
    if (event_time_next && CYCLES_GE(now, event_time_next))
      p32x_run_events(now);

    target = m68k_target;
    if (event_time_next && CYCLES_GT(target, event_time_next))
      target = event_time_next;

    while (CYCLES_GT(target, now))
    {
      elprintf(EL_32X, "sh2 exec to %u %d,%d/%d, flags %x", target,
        target - msh2.m68krcycles_done, target - ssh2.m68krcycles_done,
        m68k_target - now, Pico32x.emu_flags);

      if (!(ssh2.state & SH2_IDLE_STATES)) {
        cycles = target - ssh2.m68krcycles_done;
        if (cycles > 0) {
          run_sh2(&ssh2, cycles);

          if (event_time_next && CYCLES_GT(target, event_time_next))
            target = event_time_next;
        }
      }

      if (!(msh2.state & SH2_IDLE_STATES)) {
        cycles = target - msh2.m68krcycles_done;
        if (cycles > 0) {
          run_sh2(&msh2, cycles);

          if (event_time_next && CYCLES_GT(target, event_time_next))
            target = event_time_next;
        }
      }

      now = target;
      if (!(msh2.state & SH2_IDLE_STATES)) {
        if (CYCLES_GT(now, msh2.m68krcycles_done))
          now = msh2.m68krcycles_done;
      }
      if (!(ssh2.state & SH2_IDLE_STATES)) {
        if (CYCLES_GT(now, ssh2.m68krcycles_done))
          now = ssh2.m68krcycles_done;
      }
    }

    p32x_timers_do(now - timer_cycles);
    timer_cycles = now;
  }

  // advance idle CPUs
  if (msh2.state & SH2_IDLE_STATES) {
    if (CYCLES_GT(m68k_target, msh2.m68krcycles_done))
      msh2.m68krcycles_done = m68k_target;
  }
  if (ssh2.state & SH2_IDLE_STATES) {
    if (CYCLES_GT(m68k_target, ssh2.m68krcycles_done))
      ssh2.m68krcycles_done = m68k_target;
  }
}

#define STEP_68K 24

void sync_sh2s_lockstep(unsigned int m68k_target)
{
  unsigned int mcycles;
  
  mcycles = msh2.m68krcycles_done;
  if (ssh2.m68krcycles_done < mcycles)
    mcycles = ssh2.m68krcycles_done;

  while (mcycles < m68k_target) {
    mcycles += STEP_68K;
    sync_sh2s_normal(mcycles);
  }
}

#define CPUS_RUN(m68k_cycles) do { \
  if (PicoAHW & PAHW_MCD) \
    pcd_run_cpus(m68k_cycles); \
  else \
    SekRunM68k(m68k_cycles); \
  \
  if ((Pico32x.emu_flags & P32XF_Z80_32X_IO) && Pico.m.z80Run \
      && !Pico.m.z80_reset && (PicoOpt & POPT_EN_Z80)) \
    PicoSyncZ80(SekCyclesDone()); \
  if (Pico32x.emu_flags & (P32XF_68KCPOLL|P32XF_68KVPOLL)) \
    p32x_sync_sh2s(SekCyclesDone()); \
} while (0)

#define PICO_32X
#define PICO_CD
#include "../pico_cmn.c"

void PicoFrame32x(void)
{
  Pico.m.scanline = 0;

  Pico32x.vdp_regs[0x0a/2] &= ~P32XV_VBLK; // get out of vblank
  if ((Pico32x.vdp_regs[0] & P32XV_Mx) != 0) // no forced blanking
    Pico32x.vdp_regs[0x0a/2] &= ~P32XV_PEN; // no palette access

  if (!(Pico32x.sh2_regs[0] & 0x80))
    p32x_schedule_hint(NULL, SekCyclesDone());
  p32x_sh2_poll_event(&msh2, SH2_STATE_VPOLL, 0);
  p32x_sh2_poll_event(&ssh2, SH2_STATE_VPOLL, 0);

  if (PicoAHW & PAHW_MCD)
    pcd_prepare_frame();

  PicoFrameStart();
  PicoFrameHints();
  sh2_drc_frame();

  elprintf(EL_32X, "poll: %02x %02x %02x",
    Pico32x.emu_flags & 3, msh2.state, ssh2.state);
}

// calculate multipliers against 68k clock (7670442)
// normally * 3, but effectively slower due to high latencies everywhere
// however using something lower breaks MK2 animations
void Pico32xSetClocks(int msh2_hz, int ssh2_hz)
{
  float m68k_clk = (float)(OSC_NTSC / 7);
  if (msh2_hz > 0) {
    msh2.mult_m68k_to_sh2 = (int)((float)msh2_hz * (1 << CYCLE_MULT_SHIFT) / m68k_clk);
    msh2.mult_sh2_to_m68k = (int)(m68k_clk * (1 << CYCLE_MULT_SHIFT) / (float)msh2_hz);
  }
  if (ssh2_hz > 0) {
    ssh2.mult_m68k_to_sh2 = (int)((float)ssh2_hz * (1 << CYCLE_MULT_SHIFT) / m68k_clk);
    ssh2.mult_sh2_to_m68k = (int)(m68k_clk * (1 << CYCLE_MULT_SHIFT) / (float)ssh2_hz);
  }
}

void Pico32xStateLoaded(int is_early)
{
  if (is_early) {
    Pico32xMemStateLoaded();
    return;
  }

  sh2s[0].m68krcycles_done = sh2s[1].m68krcycles_done = SekCyclesDone();
  p32x_update_irls(NULL, SekCyclesDone());
  p32x_pwm_state_loaded();
  p32x_run_events(SekCyclesDone());
}

// vim:shiftwidth=2:ts=2:expandtab
