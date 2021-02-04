/*
 * common code for base/cd/32x
 * (C) notaz, 2007-2009,2013
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#define CYCLES_M68K_LINE     488 // suitable for both PAL/NTSC
#define CYCLES_M68K_VINT_LAG 112

// pad delay (for 6 button pads)
#define PAD_DELAY() { \
  if(Pico.m.padDelay[0]++ > 25) Pico.m.padTHPhase[0]=0; \
  if(Pico.m.padDelay[1]++ > 25) Pico.m.padTHPhase[1]=0; \
}

// CPUS_RUN
#ifndef CPUS_RUN
#define CPUS_RUN(m68k_cycles) \
  SekRunM68k(m68k_cycles)
#endif

// sync m68k to Pico.t.m68c_aim
static void SekSyncM68k(void)
{
  int cyc_do;
  pprof_start(m68k);
  pevt_log_m68k_o(EVT_RUN_START);

  while ((cyc_do = Pico.t.m68c_aim - Pico.t.m68c_cnt) > 0) {
    Pico.t.m68c_cnt += cyc_do;

#if defined(EMU_C68K)
    PicoCpuCM68k.cycles = cyc_do;
    CycloneRun(&PicoCpuCM68k);
    Pico.t.m68c_cnt -= PicoCpuCM68k.cycles;
#elif defined(EMU_M68K)
    Pico.t.m68c_cnt += m68k_execute(cyc_do) - cyc_do;
#elif defined(EMU_F68K)
    Pico.t.m68c_cnt += fm68k_emulate(&PicoCpuFM68k, cyc_do, 0) - cyc_do;
#endif
  }

  SekCyclesLeft = 0;

  SekTrace(0);
  pevt_log_m68k_o(EVT_RUN_END);
  pprof_end(m68k);
}

static __inline void SekRunM68k(int cyc)
{
  Pico.t.m68c_aim += cyc;
  cyc = Pico.t.m68c_aim - Pico.t.m68c_cnt;
  if (cyc <= 0)
    return;
  Pico.t.m68c_cnt += cyc >> 6; // refresh slowdowns
  SekSyncM68k();
}

static void do_hint(struct PicoVideo *pv)
{
  pv->pending_ints |= 0x10;
  if (pv->reg[0] & 0x10) {
    elprintf(EL_INTS, "hint: @ %06x [%u]", SekPc, SekCyclesDone());
    SekInterrupt(4);
  }
}

static void do_timing_hacks_as(struct PicoVideo *pv, int vdp_slots)
{
  pv->lwrite_cnt += vdp_slots - Pico.m.dma_xfers * 2; // wrong *2
  if (pv->lwrite_cnt > vdp_slots)
    pv->lwrite_cnt = vdp_slots;
  else if (pv->lwrite_cnt < 0)
    pv->lwrite_cnt = 0;
  if (Pico.m.dma_xfers)
    SekCyclesBurn(CheckDMA());
}

static void do_timing_hacks_vb(void)
{
  if (unlikely(Pico.m.dma_xfers))
    SekCyclesBurn(CheckDMA());
}

static int PicoFrameHints(void)
{
  struct PicoVideo *pv = &Pico.video;
  int line_sample = Pico.m.pal ? 68 : 93;
  int vdp_slots = (Pico.video.reg[12] & 1) ? 18 : 16;
  int lines, y, lines_vis, skip;
  int vcnt_wrap, vcnt_adj;
  unsigned int cycles;
  int hint; // Hint counter

  pevt_log_m68k_o(EVT_FRAME_START);

  if ((PicoIn.opt&POPT_ALT_RENDERER) && !PicoIn.skipFrame && (pv->reg[1]&0x40)) { // fast rend., display enabled
    // draw a frame just after vblank in alternative render mode
    // yes, this will cause 1 frame lag, but this is inaccurate mode anyway.
    PicoFrameFull();
#ifdef DRAW_FINISH_FUNC
    DRAW_FINISH_FUNC();
#endif
    skip = 1;
  }
  else skip=PicoIn.skipFrame;

  Pico.t.m68c_frame_start = Pico.t.m68c_aim;
  pv->v_counter = Pico.m.scanline = 0;
  z80_resetCycles();
  PsndStartFrame();

  hint = pv->hint_cnt;
  pv->status |= PVS_ACTIVE;

  for (y = 0; ; y++)
  {
    pv->v_counter = Pico.m.scanline = y;
    if ((pv->reg[12]&6) == 6) { // interlace mode 2
      pv->v_counter <<= 1;
      pv->v_counter |= pv->v_counter >> 8;
      pv->v_counter &= 0xff;
    }

    if ((y == 224 && !(pv->reg[1] & 8)) || y == 240)
      break;

    PAD_DELAY();

    // H-Interrupts:
    if (--hint < 0)
    {
      hint = pv->reg[10]; // Reload H-Int counter
      do_hint(pv);
    }

    // decide if we draw this line
    if (!skip && (PicoIn.opt & POPT_ALT_RENDERER))
    {
      // find the right moment for frame renderer, when display is no longer blanked
      if ((pv->reg[1]&0x40) || y > 100) {
        PicoFrameFull();
#ifdef DRAW_FINISH_FUNC
        DRAW_FINISH_FUNC();
#endif
        skip = 1;
      }
    }

    // get samples from sound chips
    if ((y == 224 || y == line_sample) && PicoIn.sndOut)
    {
      cycles = SekCyclesDone();

      if (Pico.m.z80Run && !Pico.m.z80_reset && (PicoIn.opt&POPT_EN_Z80))
        PicoSyncZ80(cycles);
#ifdef PICO_CD
      if (PicoIn.AHW & PAHW_MCD)
        pcd_sync_s68k(cycles, 0);
#endif
#ifdef PICO_32X
      p32x_sync_sh2s(cycles);
#endif
      PsndGetSamples(y);
    }

    // Run scanline:
    Pico.t.m68c_line_start = Pico.t.m68c_aim;
    do_timing_hacks_as(pv, vdp_slots);
    CPUS_RUN(CYCLES_M68K_LINE);

    if (PicoLineHook) PicoLineHook();
    pevt_log_m68k_o(EVT_NEXT_LINE);
  }

  lines_vis = (pv->reg[1] & 8) ? 240 : 224;
  if (y == lines_vis)
    pv->status &= ~PVS_ACTIVE;

  if (!skip)
  {
    if (Pico.est.DrawScanline < y)
      PicoDrawSync(y - 1, 0);
#ifdef DRAW_FINISH_FUNC
    DRAW_FINISH_FUNC();
#endif
  }

  // VDP FIFO
  pv->lwrite_cnt = 0;
  Pico.video.status |= SR_EMPT;

  memcpy(PicoIn.padInt, PicoIn.pad, sizeof(PicoIn.padInt));
  PAD_DELAY();

  // Last H-Int (normally):
  if (--hint < 0)
  {
    hint = pv->reg[10]; // Reload H-Int counter
    do_hint(pv);
  }

  pv->status |= SR_VB | PVS_VB2; // go into vblank

  // the following SekRun is there for several reasons:
  // there must be a delay after vblank bit is set and irq is asserted (Mazin Saga)
  // also delay between F bit (bit 7) is set in SR and IRQ happens (Ex-Mutants)
  // also delay between last H-int and V-int (Golden Axe 3)
  Pico.t.m68c_line_start = Pico.t.m68c_aim;
  do_timing_hacks_vb();
  CPUS_RUN(CYCLES_M68K_VINT_LAG);

  pv->status |= SR_F;
  pv->pending_ints |= 0x20;
  if (pv->reg[1] & 0x20) {
    Pico.t.m68c_aim = Pico.t.m68c_cnt + 11; // HACK
    SekSyncM68k();
    elprintf(EL_INTS, "vint: @ %06x [%u]", SekPc, SekCyclesDone());
    SekInterrupt(6);
  }

  cycles = SekCyclesDone();
  if (Pico.m.z80Run && !Pico.m.z80_reset && (PicoIn.opt&POPT_EN_Z80)) {
    PicoSyncZ80(cycles);
    elprintf(EL_INTS, "zint");
    z80_int();
  }

#ifdef PICO_CD
  if (PicoIn.AHW & PAHW_MCD)
    pcd_sync_s68k(cycles, 0);
#endif
#ifdef PICO_32X
  p32x_sync_sh2s(cycles);
  p32x_start_blank();
#endif

  // get samples from sound chips
  if (y == 224 && PicoIn.sndOut)
    PsndGetSamples(y);

  // Run scanline:
  CPUS_RUN(CYCLES_M68K_LINE - CYCLES_M68K_VINT_LAG);

  if (PicoLineHook) PicoLineHook();
  pevt_log_m68k_o(EVT_NEXT_LINE);

  if (Pico.m.pal) {
    lines = 313;
    vcnt_wrap = 0x103;
    vcnt_adj = 57;
  }
  else {
    lines = 262;
    vcnt_wrap = 0xEB;
    vcnt_adj = 6;
  }

  for (y++; y < lines - 1; y++)
  {
    pv->v_counter = Pico.m.scanline = y;
    if (y >= vcnt_wrap)
      pv->v_counter -= vcnt_adj;
    if ((pv->reg[12]&6) == 6)
      pv->v_counter = (pv->v_counter << 1) | 1;
    pv->v_counter &= 0xff;

    PAD_DELAY();

    if (unlikely(pv->status & PVS_ACTIVE) && --hint < 0)
    {
      hint = pv->reg[10]; // Reload H-Int counter
      do_hint(pv);
    }

    // Run scanline:
    Pico.t.m68c_line_start = Pico.t.m68c_aim;
    do_timing_hacks_vb();
    CPUS_RUN(CYCLES_M68K_LINE);

    if (PicoLineHook) PicoLineHook();
    pevt_log_m68k_o(EVT_NEXT_LINE);
  }

  if (unlikely(PicoIn.overclockM68k)) {
    unsigned int l = PicoIn.overclockM68k * lines / 100;
    while (l-- > 0) {
      Pico.t.m68c_cnt -= CYCLES_M68K_LINE;
      do_timing_hacks_vb();
      SekSyncM68k();
    }
  }

  pv->status &= ~(SR_VB | PVS_VB2);
  pv->status |= ((pv->reg[1] >> 3) ^ SR_VB) & SR_VB; // forced blanking

  // last scanline
  Pico.m.scanline = y;
  pv->v_counter = 0xff;
  pv->lwrite_cnt = 0;

  PAD_DELAY();

  if (unlikely(pv->status & PVS_ACTIVE)) {
    if (--hint < 0) {
      hint = pv->reg[10]; // Reload H-Int counter
      do_hint(pv);
    }
  }
  else
    hint = pv->reg[10];

  // Run scanline:
  Pico.t.m68c_line_start = Pico.t.m68c_aim;
  do_timing_hacks_as(pv, vdp_slots);
  CPUS_RUN(CYCLES_M68K_LINE);

  if (PicoLineHook) PicoLineHook();
  pevt_log_m68k_o(EVT_NEXT_LINE);

  // sync cpus
  cycles = SekCyclesDone();
  if (Pico.m.z80Run && !Pico.m.z80_reset && (PicoIn.opt&POPT_EN_Z80))
    PicoSyncZ80(cycles);
  if (PicoIn.sndOut && ym2612.dacen && Pico.snd.dac_line < lines)
    PsndDoDAC(lines - 1);
  if (PicoIn.sndOut && Pico.snd.psg_line < lines)
    PsndDoPSG(lines - 1);

#ifdef PICO_CD
  if (PicoIn.AHW & PAHW_MCD)
    pcd_sync_s68k(cycles, 0);
#endif
#ifdef PICO_32X
  p32x_sync_sh2s(cycles);
#endif
  timers_cycle();

  pv->hint_cnt = hint;

  return 0;
}

#undef PAD_DELAY
#undef CPUS_RUN

// vim:shiftwidth=2:ts=2:expandtab
