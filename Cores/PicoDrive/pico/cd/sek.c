/*
 * PicoDrive
 * (C) notaz, 2007
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include "../pico_int.h"


unsigned int SekCycleCntS68k;
unsigned int SekCycleAimS68k;


/* context */
// Cyclone 68000
#ifdef EMU_C68K
struct Cyclone PicoCpuCS68k;
#endif
// MUSASHI 68000
#ifdef EMU_M68K
m68ki_cpu_core PicoCpuMS68k;
#endif
// FAME 68000
#ifdef EMU_F68K
M68K_CONTEXT PicoCpuFS68k;
#endif


static int new_irq_level(int level)
{
  int level_new = 0, irqs;
  Pico_mcd->m.s68k_pend_ints &= ~(1 << level);
  irqs = Pico_mcd->m.s68k_pend_ints;
  irqs &= Pico_mcd->s68k_regs[0x33];
  while ((irqs >>= 1)) level_new++;

  return level_new;
}

#ifdef EMU_C68K
// interrupt acknowledgement
static int SekIntAckS68k(int level)
{
  int level_new = new_irq_level(level);

  elprintf(EL_INTS, "s68kACK %i -> %i", level, level_new);
  PicoCpuCS68k.irq = level_new;
  return CYCLONE_INT_ACK_AUTOVECTOR;
}

static void SekResetAckS68k(void)
{
  elprintf(EL_ANOMALY, "s68k: Reset encountered @ %06x", SekPcS68k);
}

static int SekUnrecognizedOpcodeS68k(void)
{
  elprintf(EL_ANOMALY, "Unrecognized Opcode @ %06x", SekPcS68k);
  //exit(1);
  return 0;
}
#endif

#ifdef EMU_M68K
static int SekIntAckMS68k(int level)
{
#ifndef EMU_CORE_DEBUG
  int level_new = new_irq_level(level);
  elprintf(EL_INTS, "s68kACK %i -> %i", level, level_new);
  CPU_INT_LEVEL = level_new << 8;
#else
  CPU_INT_LEVEL = 0;
#endif
  return M68K_INT_ACK_AUTOVECTOR;
}
#endif

#ifdef EMU_F68K
static void SekIntAckFS68k(unsigned level)
{
  int level_new = new_irq_level(level);
  elprintf(EL_INTS, "s68kACK %i -> %i", level, level_new);
#ifndef EMU_CORE_DEBUG
  PicoCpuFS68k.interrupts[0] = level_new;
#else
  {
    extern int dbg_irq_level_sub;
    dbg_irq_level_sub = level_new;
    PicoCpuFS68k.interrupts[0] = 0;
  }
#endif
}
#endif


PICO_INTERNAL void SekInitS68k(void)
{
#ifdef EMU_C68K
//  CycloneInit();
  memset(&PicoCpuCS68k,0,sizeof(PicoCpuCS68k));
  PicoCpuCS68k.IrqCallback=SekIntAckS68k;
  PicoCpuCS68k.ResetCallback=SekResetAckS68k;
  PicoCpuCS68k.UnrecognizedCallback=SekUnrecognizedOpcodeS68k;
#endif
#ifdef EMU_M68K
  {
    // Musashi is not very context friendly..
    void *oldcontext = m68ki_cpu_p;
    m68k_set_context(&PicoCpuMS68k);
    m68k_set_cpu_type(M68K_CPU_TYPE_68000);
    m68k_init();
    m68k_set_int_ack_callback(SekIntAckMS68k);
//  m68k_pulse_reset(); // not yet, memmap is not set up
    m68k_set_context(oldcontext);
  }
#endif
#ifdef EMU_F68K
  {
    void *oldcontext = g_m68kcontext;
    g_m68kcontext = &PicoCpuFS68k;
    memset(&PicoCpuFS68k, 0, sizeof(PicoCpuFS68k));
    fm68k_init();
    PicoCpuFS68k.iack_handler = SekIntAckFS68k;
    PicoCpuFS68k.sr = 0x2704; // Z flag
    g_m68kcontext = oldcontext;
  }
#endif
}

// Reset the 68000:
PICO_INTERNAL int SekResetS68k(void)
{
  if (Pico.rom==NULL) return 1;

#ifdef EMU_C68K
  CycloneReset(&PicoCpuCS68k);
#endif
#ifdef EMU_M68K
  {
    void *oldcontext = m68ki_cpu_p;

    m68k_set_context(&PicoCpuMS68k);
    m68ki_cpu.sp[0]=0;
    m68k_set_irq(0);
    m68k_pulse_reset();
    m68k_set_context(oldcontext);
  }
#endif
#ifdef EMU_F68K
  {
    void *oldcontext = g_m68kcontext;
    g_m68kcontext = &PicoCpuFS68k;
    fm68k_reset();
    g_m68kcontext = oldcontext;
  }
#endif

  return 0;
}

PICO_INTERNAL int SekInterruptS68k(int irq)
{
  int irqs, real_irq = 1;
  Pico_mcd->m.s68k_pend_ints |= 1 << irq;
  irqs = Pico_mcd->m.s68k_pend_ints >> 1;
  while ((irqs >>= 1)) real_irq++;

#ifdef EMU_CORE_DEBUG
  {
    extern int dbg_irq_level_sub;
    dbg_irq_level_sub=real_irq;
    return 0;
  }
#endif
#ifdef EMU_C68K
  PicoCpuCS68k.irq=real_irq;
#endif
#ifdef EMU_M68K
  void *oldcontext = m68ki_cpu_p;
  m68k_set_context(&PicoCpuMS68k);
  m68k_set_irq(real_irq);
  m68k_set_context(oldcontext);
#endif
#ifdef EMU_F68K
  PicoCpuFS68k.interrupts[0]=real_irq;
#endif
  return 0;
}

void SekInterruptClearS68k(int irq)
{
  int level_new = new_irq_level(irq);

#ifdef EMU_C68K
  PicoCpuCS68k.irq = level_new;
#endif
#ifdef EMU_M68K
  CPU_INT_LEVEL = level_new << 8;
#endif
#ifdef EMU_F68K
  PicoCpuFS68k.interrupts[0] = level_new;
#endif
}
