/*
 * debug stuff
 * (C) notaz, 2006-2008
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include "pico_int.h"

typedef unsigned char  u8;

static unsigned int pppc, ops=0;
extern unsigned int lastread_a, lastread_d[16], lastwrite_cyc_d[16], lastwrite_mus_d[16];
extern int lrp_cyc, lrp_mus, lwp_cyc, lwp_mus;
unsigned int old_regs[16], old_sr, ppop, have_illegal = 0;
int dbg_irq_level = 0, dbg_irq_level_sub = 0;

#undef dprintf
#define dprintf(f,...) printf("%05i:%03i: " f "\n",Pico.m.frame_count,Pico.m.scanline,##__VA_ARGS__)

#if defined(EMU_C68K)
static struct Cyclone *currentC68k = NULL;
#define other_set_sub(s)   currentC68k=(s)?&PicoCpuCS68k:&PicoCpuCM68k;
#define other_get_sr()     CycloneGetSr(currentC68k)
#define other_dar(i)       currentC68k->d[i]
#define other_osp          currentC68k->osp
#define other_get_irq()    currentC68k->irq
#define other_set_irq(i)   currentC68k->irq=i
#define other_is_stopped()  (currentC68k->state_flags&1)
#define other_is_tracing() ((currentC68k->state_flags&2)?1:0)
#elif defined(EMU_F68K)
#define other_set_sub(s)   g_m68kcontext=(s)?&PicoCpuFS68k:&PicoCpuFM68k;
#define other_get_sr()     g_m68kcontext->sr
#define other_dar(i)       ((unsigned int*)g_m68kcontext->dreg)[i]
#define other_osp          g_m68kcontext->asp
#define other_get_irq()    g_m68kcontext->interrupts[0]
#define other_set_irq(irq) g_m68kcontext->interrupts[0]=irq
#define other_is_stopped() ((g_m68kcontext->execinfo&FM68K_HALTED)?1:0)
#define other_is_tracing() ((g_m68kcontext->execinfo&FM68K_EMULATE_TRACE)?1:0)
#else
#error other core missing, don't compile this file
#endif

static int otherRun(void)
{
#if defined(EMU_C68K)
  currentC68k->cycles=1;
  CycloneRun(currentC68k);
  return 1-currentC68k->cycles;
#elif defined(EMU_F68K)
  return fm68k_emulate(1, 0);
#endif
}

//static
void dumpPCandExit(int is_sub)
{
  char buff[128];
  int i;

  m68k_disassemble(buff, pppc, M68K_CPU_TYPE_68000);
  dprintf("PC: %06x: %04x: %s", pppc, ppop, buff);
  dprintf("                    this | prev");
  for(i=0; i < 8; i++)
    dprintf("d%i=%08x, a%i=%08x | d%i=%08x, a%i=%08x", i, other_dar(i), i, other_dar(i+8), i, old_regs[i], i, old_regs[i+8]);
  dprintf("SR:                 %04x | %04x (??s? 0iii 000x nzvc)", other_get_sr(), old_sr);
  dprintf("last_read: %08x @ %06x", lastread_d[--lrp_cyc&15], lastread_a);
  dprintf("ops done: %i, is_sub: %i", ops, is_sub);
  exit(1);
}

int CM_compareRun(int cyc, int is_sub)
{
  char *str;
  int cyc_done=0, cyc_other, cyc_musashi, *irq_level, err=0;
  unsigned int i, pc, mu_sr;

  m68ki_cpu_p=is_sub?&PicoCpuMS68k:&PicoCpuMM68k;
  other_set_sub(is_sub);
  lrp_cyc = lrp_mus = 0;

  while (cyc_done < cyc)
  {
    if (have_illegal && m68k_read_disassembler_16(m68ki_cpu.pc) != 0x4e73) // not rte
    {
      have_illegal = 0;
      m68ki_cpu.pc += 2;
#ifdef EMU_C68K
      currentC68k->pc=currentC68k->checkpc(currentC68k->pc + 2);
#endif
    }
    // hacks for test_misc2
    if (m68ki_cpu.pc == 0x0002e0 && m68k_read_disassembler_16(m68ki_cpu.pc) == 0x4e73)
    {
      // get out of "priviledge violation" loop
      have_illegal = 1;
      //m68ki_cpu.s_flag = SFLAG_SET;
      //currentC68k->srh|=0x20;
    }

    pppc = is_sub ? SekPcS68k : SekPc;
    ppop = m68k_read_disassembler_16(pppc);
    memcpy(old_regs, &other_dar(0), 4*16);
    old_sr = other_get_sr();

#if 0
    {
      char buff[128];
      dprintf("---");
      m68k_disassemble(buff, pppc, M68K_CPU_TYPE_68000);
      dprintf("PC: %06x: %04x: %s", pppc, ppop, buff);
      //dprintf("A7: %08x", currentC68k->a[7]);
    }
#endif

    irq_level = is_sub ? &dbg_irq_level_sub : &dbg_irq_level;
    if (*irq_level)
    {
      other_set_irq(*irq_level);
      m68k_set_irq(*irq_level);
      *irq_level=0;
    }

    cyc_other=otherRun();
    // Musashi takes irq even if it hasn't got cycles left, let othercpu do it too
    if (other_get_irq() && other_get_irq() > ((other_get_sr()>>8)&7))
      cyc_other+=otherRun();
    cyc_musashi=m68k_execute(1);

    if (cyc_other != cyc_musashi) {
      dprintf("cycles: %i vs %i", cyc_other, cyc_musashi);
      err=1;
    }

    if (lrp_cyc != lrp_mus) {
      dprintf("lrp: %i vs %i", lrp_cyc&15, lrp_mus&15);
      err=1;
    }

    if (lwp_cyc != lwp_mus) {
      dprintf("lwp: %i vs %i", lwp_cyc&15, lwp_mus&15);
      err=1;
    }

    for (i=0; i < 16; i++) {
      if (lastwrite_cyc_d[i] != lastwrite_mus_d[i]) {
        dprintf("lastwrite: [%i]= %08x vs %08x", i, lastwrite_cyc_d[i], lastwrite_mus_d[i]);
        err=1;
        break;
      }
    }

    // compare PC
    pc = is_sub ? SekPcS68k : SekPc;
    m68ki_cpu.pc&=~1;
    if (pc != m68ki_cpu.pc) {
      dprintf("PC: %06x vs %06x", pc, m68ki_cpu.pc);
      err=1;
    }

#if 0
    if( SekPc > Pico.romsize || SekPc < 0x200 ) {
      dprintf("PC out of bounds: %06x", SekPc);
      err=1;
    }
#endif

    // compare regs
    for (i=0; i < 16; i++) {
      if (other_dar(i) != m68ki_cpu.dar[i]) {
        str = (i < 8) ? "d" : "a";
        dprintf("reg: %s%i: %08x vs %08x", str, i&7, other_dar(i), m68ki_cpu.dar[i]);
        err=1;
      }
    }

    // SR
    if (other_get_sr() != (mu_sr = m68k_get_reg(NULL, M68K_REG_SR))) {
      dprintf("SR: %04x vs %04x (??s? 0iii 000x nzvc)", other_get_sr(), mu_sr);
      err=1;
    }

    // IRQl
    if (other_get_irq() != (m68ki_cpu.int_level>>8)) {
      dprintf("IRQ: %i vs %i", other_get_irq(), (m68ki_cpu.int_level>>8));
      err=1;
    }

    // OSP/USP
    if (other_osp != m68ki_cpu.sp[((mu_sr>>11)&4)^4]) {
      dprintf("OSP: %06x vs %06x", other_osp, m68ki_cpu.sp[((mu_sr>>11)&4)^4]);
      err=1;
    }

    // stopped
    if ((other_is_stopped() && !m68ki_cpu.stopped) || (!other_is_stopped() && m68ki_cpu.stopped)) {
      dprintf("stopped: %i vs %i", other_is_stopped(), m68ki_cpu.stopped);
      err=1;
    }

    // tracing
    if((other_is_tracing() && !m68ki_tracing) || (!other_is_tracing() && m68ki_tracing)) {
      dprintf("tracing: %i vs %i", other_is_tracing(), m68ki_tracing);
      err=1;
    }

    if(err) dumpPCandExit(is_sub);

#if 0
    if (m68ki_cpu.dar[15] < 0x00ff0000 || m68ki_cpu.dar[15] >= 0x01000000)
    {
      other_dar(15) = m68ki_cpu.dar[15] = 0xff8000;
    }
#endif
#if 0
    m68k_set_reg(M68K_REG_SR, ((mu_sr-1)&~0x2000)|(mu_sr&0x2000)); // broken
    CycloneSetSr(currentC68k, ((mu_sr-1)&~0x2000)|(mu_sr&0x2000));
    currentC68k->stopped = m68ki_cpu.stopped = 0;
    if(SekPc > 0x400 && (currentC68k->a[7] < 0xff0000 || currentC68k->a[7] > 0xffffff))
    currentC68k->a[7] = m68ki_cpu.dar[15] = 0xff8000;
#endif

    cyc_done += cyc_other;
    ops++;
  }

  return cyc_done;
}
