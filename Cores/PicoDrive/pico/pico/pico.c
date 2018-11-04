/*
 * PicoDrive
 * (C) notaz, 2008
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */
#include "../pico_int.h"

// x: 0x03c - 0x19d
// y: 0x1fc - 0x2f7
//    0x2f8 - 0x3f3
picohw_state PicoPicohw;

static int prev_line_cnt_irq3 = 0, prev_line_cnt_irq5 = 0;
static int fifo_bytes_line = (16000<<16)/60/262/2;

static const int guessed_rates[] = { 8000, 14000, 12000, 14000, 16000, 18000, 16000, 16000 }; // ?

#define PICOHW_FIFO_IRQ_THRESHOLD 12

PICO_INTERNAL void PicoReratePico(void)
{
  int rate = guessed_rates[PicoPicohw.r12 & 7];
  if (Pico.m.pal)
       fifo_bytes_line = (rate<<16)/50/312/2;
  else fifo_bytes_line = (rate<<16)/60/262/2;
  PicoPicoPCMRerate(rate);
}

static void PicoLinePico(void)
{
  PicoPicohw.line_counter++;

#if 1
  if ((PicoPicohw.r12 & 0x4003) && PicoPicohw.line_counter - prev_line_cnt_irq3 > 200) {
    prev_line_cnt_irq3 = PicoPicohw.line_counter;
    // just a guess/hack, allows 101 Dalmantians to boot
    elprintf(EL_PICOHW, "irq3");
    SekInterrupt(3);
    return;
  }
#endif

  if (PicoPicohw.fifo_bytes > 0)
  {
    PicoPicohw.fifo_line_bytes += fifo_bytes_line;
    if (PicoPicohw.fifo_line_bytes >= (1<<16)) {
      PicoPicohw.fifo_bytes -= PicoPicohw.fifo_line_bytes >> 16;
      PicoPicohw.fifo_line_bytes &= 0xffff;
      if (PicoPicohw.fifo_bytes < 0)
        PicoPicohw.fifo_bytes = 0;
    }
  }
  else
    PicoPicohw.fifo_line_bytes = 0;

#if 1
  if (PicoPicohw.fifo_bytes_prev >= PICOHW_FIFO_IRQ_THRESHOLD &&
      PicoPicohw.fifo_bytes < PICOHW_FIFO_IRQ_THRESHOLD) {
    prev_line_cnt_irq3 = PicoPicohw.line_counter; // ?
    elprintf(EL_PICOHW, "irq3, fb=%i", PicoPicohw.fifo_bytes);
    SekInterrupt(3);
  }
  PicoPicohw.fifo_bytes_prev = PicoPicohw.fifo_bytes;
#endif

#if 0
  if (PicoPicohw.line_counter - prev_line_cnt_irq5 > 512) {
    prev_line_cnt_irq5 = PicoPicohw.line_counter;
    elprintf(EL_PICOHW, "irq5");
    SekInterrupt(5);
  }
#endif
}

static void PicoResetPico(void)
{
  PicoPicoPCMReset();
  PicoPicohw.xpcm_ptr = PicoPicohw.xpcm_buffer;
}

PICO_INTERNAL void PicoInitPico(void)
{
  elprintf(EL_STATUS, "Pico startup");
  PicoLineHook = PicoLinePico;
  PicoResetHook = PicoResetPico;

  PicoAHW = PAHW_PICO;
  memset(&PicoPicohw, 0, sizeof(PicoPicohw));
  PicoPicohw.pen_pos[0] = 0x03c + 320/2;
  PicoPicohw.pen_pos[1] = 0x200 + 240/2;
  prev_line_cnt_irq3 = prev_line_cnt_irq5 = 0;

  // map version register
  PicoDetectRegion();
  switch (Pico.m.hardware >> 6) {
    case 0: PicoPicohw.r1 = 0x00; break;
    case 1: PicoPicohw.r1 = 0x00; break;
    case 2: PicoPicohw.r1 = 0x40; break;
    case 3: PicoPicohw.r1 = 0x20; break;
  }
}

