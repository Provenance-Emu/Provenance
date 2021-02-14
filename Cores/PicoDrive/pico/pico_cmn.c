/*
 * common code for base/cd/32x
 * (C) notaz, 2007-2009,2013
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#define CYCLES_M68K_LINE     488 // suitable for both PAL/NTSC
#define CYCLES_M68K_VINT_LAG  68
#define CYCLES_M68K_ASD      148

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

// sync m68k to SekCycleAim
static void SekSyncM68k(void)
{
  int cyc_do;
  pprof_start(m68k);
  pevt_log_m68k_o(EVT_RUN_START);

  while ((cyc_do = SekCycleAim - SekCycleCnt) > 0) {
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
  pprof_end(m68k);
}

static inline void SekRunM68k(int cyc)
{
  SekCycleAim += cyc;
  SekSyncM68k();
}

static int PicoFrameHints(void)
{
  struct PicoVideo *pv=&Pico.video;
  int lines, y, lines_vis = 224, line_sample, skip, vcnt_wrap;
  unsigned int cycles;
  int hint; // Hint counter

  pevt_log_m68k_o(EVT_FRAME_START);
  pv->v_counter = Pico.m.scanline = 0;

  if ((PicoOpt&POPT_ALT_RENDERER) && !PicoSkipFrame && (pv->reg[1]&0x40)) { // fast rend., display enabled
    // draw a frame just after vblank in alternative render mode
    // yes, this will cause 1 frame lag, but this is inaccurate mode anyway.
    PicoFrameFull();
#ifdef DRAW_FINISH_FUNC
    DRAW_FINISH_FUNC();
#endif
    skip = 1;
  }
  else skip=PicoSkipFrame;

  if (Pico.m.pal) {
    line_sample = 68;
    if (pv->reg[1]&8) lines_vis = 240;
  } else {
    line_sample = 93;
  }

  z80_resetCycles();
  PsndDacLine = 0;
  emustatus &= ~1;

  pv->status&=~0x88; // clear V-Int, come out of vblank

  hint=pv->reg[10]; // Load H-Int counter
  //dprintf("-hint: %i", hint);

  // This is to make active scan longer (needed for Double Dragon 2, mainly)
  CPUS_RUN(CYCLES_M68K_ASD);

  for (y = 0; y < lines_vis; y++)
  {
    pv->v_counter = Pico.m.scanline = y;
    if ((pv->reg[12]&6) == 6) { // interlace mode 2
      pv->v_counter <<= 1;
      pv->v_counter |= pv->v_counter >> 8;
      pv->v_counter &= 0xff;
    }

    // VDP FIFO
    pv->lwrite_cnt -= 12;
    if (pv->lwrite_cnt <= 0) {
      pv->lwrite_cnt=0;
      Pico.video.status|=0x200;
    }

    PAD_DELAY();

    // H-Interrupts:
    if (--hint < 0) // y <= lines_vis: Comix Zone, Golden Axe
    {
      hint=pv->reg[10]; // Reload H-Int counter
      pv->pending_ints|=0x10;
      if (pv->reg[0]&0x10) {
        elprintf(EL_INTS, "hint: @ %06x [%i]", SekPc, SekCyclesDone());
        SekInterrupt(4);
      }
    }

    // decide if we draw this line
    if (!skip && (PicoOpt & POPT_ALT_RENDERER))
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
    if ((y == 224 || y == line_sample) && PsndOut)
    {
      cycles = SekCyclesDone();

      if (Pico.m.z80Run && !Pico.m.z80_reset && (PicoOpt&POPT_EN_Z80))
        PicoSyncZ80(cycles);
      if (ym2612.dacen && PsndDacLine <= y)
        PsndDoDAC(y);
#ifdef PICO_CD
      if (PicoAHW & PAHW_MCD)
        pcd_sync_s68k(cycles, 0);
#endif
#ifdef PICO_32X
      p32x_sync_sh2s(cycles);
#endif
      PsndGetSamples(y);
    }

    // Run scanline:
    line_base_cycles = SekCyclesDone();
    if (Pico.m.dma_xfers) SekCyclesBurn(CheckDMA());
    CPUS_RUN(CYCLES_M68K_LINE);

    if (PicoLineHook) PicoLineHook();
    pevt_log_m68k_o(EVT_NEXT_LINE);
  }

  if (!skip)
  {
    if (DrawScanline < y)
      PicoDrawSync(y - 1, 0);
#ifdef DRAW_FINISH_FUNC
    DRAW_FINISH_FUNC();
#endif
  }

  // V-int line (224 or 240)
  Pico.m.scanline = y;
  pv->v_counter = 0xe0; // bad for 240 mode
  if ((pv->reg[12]&6) == 6) pv->v_counter = 0xc1;

  // VDP FIFO
  pv->lwrite_cnt=0;
  Pico.video.status|=0x200;

  memcpy(PicoPadInt, PicoPad, sizeof(PicoPadInt));
  PAD_DELAY();

  // Last H-Int:
  if (--hint < 0)
  {
    hint=pv->reg[10]; // Reload H-Int counter
    pv->pending_ints|=0x10;
    //printf("rhint: %i @ %06x [%i|%i]\n", hint, SekPc, y, SekCyclesDone());
    if (pv->reg[0]&0x10) SekInterrupt(4);
  }

  pv->status|=0x08; // go into vblank
  pv->pending_ints|=0x20;

  // the following SekRun is there for several reasons:
  // there must be a delay after vblank bit is set and irq is asserted (Mazin Saga)
  // also delay between F bit (bit 7) is set in SR and IRQ happens (Ex-Mutants)
  // also delay between last H-int and V-int (Golden Axe 3)
  line_base_cycles = SekCyclesDone();
  if (Pico.m.dma_xfers) SekCyclesBurn(CheckDMA());
  CPUS_RUN(CYCLES_M68K_VINT_LAG);

  if (pv->reg[1]&0x20) {
    elprintf(EL_INTS, "vint: @ %06x [%i]", SekPc, SekCyclesDone());
    SekInterrupt(6);
  }

  cycles = SekCyclesDone();
  if (Pico.m.z80Run && !Pico.m.z80_reset && (PicoOpt&POPT_EN_Z80)) {
    PicoSyncZ80(cycles);
    elprintf(EL_INTS, "zint");
    z80_int();
  }

#ifdef PICO_CD
  if (PicoAHW & PAHW_MCD)
    pcd_sync_s68k(cycles, 0);
#endif
#ifdef PICO_32X
  p32x_sync_sh2s(cycles);
  p32x_start_blank();
#endif

  // get samples from sound chips
  if (y == 224 && PsndOut)
  {
    if (ym2612.dacen && PsndDacLine <= y)
      PsndDoDAC(y);
    PsndGetSamples(y);
  }

  // Run scanline:
  CPUS_RUN(CYCLES_M68K_LINE - CYCLES_M68K_VINT_LAG - CYCLES_M68K_ASD);

  if (PicoLineHook) PicoLineHook();
  pevt_log_m68k_o(EVT_NEXT_LINE);

  lines = scanlines_total;
  vcnt_wrap = Pico.m.pal ? 0x103 : 0xEB; // based on Gens, TODO: verify

  for (y++; y < lines; y++)
  {
    pv->v_counter = Pico.m.scanline = y;
    if (y >= vcnt_wrap)
      pv->v_counter -= Pico.m.pal ? 56 : 6;
    if ((pv->reg[12]&6) == 6)
      pv->v_counter = (pv->v_counter << 1) | 1;
    pv->v_counter &= 0xff;

    PAD_DELAY();

    // Run scanline:
    line_base_cycles = SekCyclesDone();
    if (Pico.m.dma_xfers) SekCyclesBurn(CheckDMA());
    CPUS_RUN(CYCLES_M68K_LINE);

    if (PicoLineHook) PicoLineHook();
    pevt_log_m68k_o(EVT_NEXT_LINE);
  }

  // sync cpus
  cycles = SekCyclesDone();
  if (Pico.m.z80Run && !Pico.m.z80_reset && (PicoOpt&POPT_EN_Z80))
    PicoSyncZ80(cycles);
  if (PsndOut && ym2612.dacen && PsndDacLine <= lines-1)
    PsndDoDAC(lines-1);

#ifdef PICO_CD
  if (PicoAHW & PAHW_MCD)
    pcd_sync_s68k(cycles, 0);
#endif
#ifdef PICO_32X
  p32x_sync_sh2s(cycles);
#endif
  timers_cycle();

  return 0;
}

#undef PAD_DELAY
#undef CPUS_RUN

// vim:shiftwidth=2:ts=2:expandtab
