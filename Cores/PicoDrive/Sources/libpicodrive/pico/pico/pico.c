/*
 * PicoDrive
 * (C) notaz, 2008
 * (C) irixxxx, 2024
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */
#include "../pico_int.h"

// x: 0x03c - 0x19d
// y: 0x1fc - 0x2f7
//    0x2f8 - 0x3f3
picohw_state PicoPicohw;



PICO_INTERNAL void PicoReratePico(void)
{
  PicoPicoPCMRerate();
  PicoPicohw.xpcm_ptr = PicoPicohw.xpcm_buffer + PicoPicohw.fifo_bytes;
}

static void PicoLinePico(void)
{
  // update sound so that irq for FIFO refill is generated
  if ((PicoPicohw.fifo_bytes | !PicoPicoPCMBusyN()) && (Pico.m.scanline & 7) == 7)
    PsndDoPCM(cycles_68k_to_z80(SekCyclesDone() - Pico.t.m68c_frame_start));
}

static void PicoResetPico(void)
{
  PicoPicoPCMResetN(1);
  PicoPicoPCMStartN(1);
  PicoPicohw.xpcm_ptr = PicoPicohw.xpcm_buffer;
  PicoPicohw.fifo_bytes = 0;
  PicoPicohw.r12 = 0;

  PicoPicohw.pen_pos[0] = PicoPicohw.pen_pos[1] = 0x8000;

  PicoPicoPCMIrqEn(0);
  PicoPicoPCMFilter(0);
  PicoPicoPCMGain(8);

  // map version register
  PicoDetectRegion();
  switch (Pico.m.hardware >> 6) {
    case 0: PicoPicohw.r1 = 0x40; break; // JP NTSC
    case 1: PicoPicohw.r1 = 0x00; break; // JP PAL
    case 2: PicoPicohw.r1 = 0x60; break; // US
    case 3: PicoPicohw.r1 = 0x20; break; // EU
  }
}

PICO_INTERNAL void PicoInitPico(void)
{
  elprintf(EL_STATUS, "Pico startup");
  PicoLineHook = PicoLinePico;
  PicoResetHook = PicoResetPico;

  PicoIn.AHW = PAHW_PICO;
  memset(&PicoPicohw, 0, sizeof(PicoPicohw));
  PicoPicohw.pen_pos[0] = PicoPicohw.pen_pos[1] = 0x8000;
}
