/*
 * SH2 peripherals/"system on chip"
 * (C) notaz, 2013
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 *
 * rough fffffe00-ffffffff map:
 * e00-e05 SCI    serial communication interface
 * e10-e1a FRT    free-running timer
 * e60-e68 VCRx   irq vectors
 * e71-e72 DRCR   dma selection
 * e80-e83 WDT    watchdog timer
 * e91     SBYCR  standby control
 * e92     CCR    cache control
 * ee0     ICR    irq control
 * ee2     IPRA   irq priorities
 * ee4     VCRWDT WDT irq vectors
 * f00-f17 DIVU
 * f40-f7b UBC   user break controller
 * f80-fb3 DMAC
 * fe0-ffb BSC   bus state controller
 */

#include "../pico_int.h"
#include "../memory.h"

// DMAC handling
struct dma_chan {
  unsigned int sar, dar;  // src, dst addr
  unsigned int tcr;       // transfer count
  unsigned int chcr;      // chan ctl
  // -- dm dm sm sm  ts ts ar am  al ds dl tb  ta ie te de
  // ts - transfer size: 1, 2, 4, 16 bytes
  // ar - auto request if 1, else dreq signal
  // ie - irq enable
  // te - transfer end
  // de - dma enable
  #define DMA_AR (1 << 9)
  #define DMA_IE (1 << 2)
  #define DMA_TE (1 << 1)
  #define DMA_DE (1 << 0)
};

struct dmac {
  struct dma_chan chan[2];
  unsigned int vcrdma0;
  unsigned int unknown0;
  unsigned int vcrdma1;
  unsigned int unknown1;
  unsigned int dmaor;
  // -- pr ae nmif dme
  // pr - priority: chan0 > chan1 or round-robin
  // ae - address error
  // nmif - nmi occurred
  // dme - DMA master enable
  #define DMA_DME  (1 << 0)
};

static void dmac_te_irq(SH2 *sh2, struct dma_chan *chan)
{
  char *regs = (void *)sh2->peri_regs;
  struct dmac *dmac = (void *)(regs + 0x180);
  int level = PREG8(regs, 0xe2) & 0x0f; // IPRA
  int vector = (chan == &dmac->chan[0]) ?
               dmac->vcrdma0 : dmac->vcrdma1;

  elprintf(EL_32XP, "dmac irq %d %d", level, vector);
  sh2_internal_irq(sh2, level, vector & 0x7f);
}

static void dmac_transfer_complete(SH2 *sh2, struct dma_chan *chan)
{
  chan->chcr |= DMA_TE; // DMA has ended normally

  p32x_sh2_poll_event(sh2, SH2_STATE_SLEEP, SekCyclesDone());
  if (chan->chcr & DMA_IE)
    dmac_te_irq(sh2, chan);
}

static void dmac_transfer_one(SH2 *sh2, struct dma_chan *chan)
{
  u32 size, d;

  size = (chan->chcr >> 10) & 3;
  switch (size) {
  case 0:
    d = p32x_sh2_read8(chan->sar, sh2);
    p32x_sh2_write8(chan->dar, d, sh2);
  case 1:
    d = p32x_sh2_read16(chan->sar, sh2);
    p32x_sh2_write16(chan->dar, d, sh2);
    break;
  case 2:
    d = p32x_sh2_read32(chan->sar, sh2);
    p32x_sh2_write32(chan->dar, d, sh2);
    break;
  case 3:
    d = p32x_sh2_read32(chan->sar + 0x00, sh2);
    p32x_sh2_write32(chan->dar + 0x00, d, sh2);
    d = p32x_sh2_read32(chan->sar + 0x04, sh2);
    p32x_sh2_write32(chan->dar + 0x04, d, sh2);
    d = p32x_sh2_read32(chan->sar + 0x08, sh2);
    p32x_sh2_write32(chan->dar + 0x08, d, sh2);
    d = p32x_sh2_read32(chan->sar + 0x0c, sh2);
    p32x_sh2_write32(chan->dar + 0x0c, d, sh2);
    chan->sar += 16; // always?
    if (chan->chcr & (1 << 15))
      chan->dar -= 16;
    if (chan->chcr & (1 << 14))
      chan->dar += 16;
    chan->tcr -= 4;
    return;
  }
  chan->tcr--;

  size = 1 << size;
  if (chan->chcr & (1 << 15))
    chan->dar -= size;
  if (chan->chcr & (1 << 14))
    chan->dar += size;
  if (chan->chcr & (1 << 13))
    chan->sar -= size;
  if (chan->chcr & (1 << 12))
    chan->sar += size;
}

// DMA trigger by SH2 register write
static void dmac_trigger(SH2 *sh2, struct dma_chan *chan)
{
  elprintf_sh2(sh2, EL_32XP, "DMA %08x->%08x, cnt %d, chcr %04x @%06x",
    chan->sar, chan->dar, chan->tcr, chan->chcr, sh2->pc);
  chan->tcr &= 0xffffff;

  if (chan->chcr & DMA_AR) {
    // auto-request transfer
    while ((int)chan->tcr > 0)
      dmac_transfer_one(sh2, chan);
    dmac_transfer_complete(sh2, chan);
    return;
  }

  // DREQ0 is only sent after first 4 words are written.
  // we do multiple of 4 words to avoid messing up alignment
  if ((chan->sar & ~0x20000000) == 0x00004012) {
    if (Pico32x.dmac0_fifo_ptr && (Pico32x.dmac0_fifo_ptr & 3) == 0) {
      elprintf(EL_32XP, "68k -> sh2 DMA");
      p32x_dreq0_trigger();
    }
    return;
  }

  // DREQ1
  if ((chan->dar & 0xc7fffff0) == 0x00004030)
    return;

  elprintf(EL_32XP|EL_ANOMALY, "unhandled DMA: "
    "%08x->%08x, cnt %d, chcr %04x @%06x",
    chan->sar, chan->dar, chan->tcr, chan->chcr, sh2->pc);
}

// timer state - FIXME
static int timer_cycles[2];
static int timer_tick_cycles[2];

// timers
void p32x_timers_recalc(void)
{
  int cycles;
  int tmp, i;

  // SH2 timer step
  for (i = 0; i < 2; i++) {
    tmp = PREG8(sh2s[i].peri_regs, 0x80) & 7;
    // Sclk cycles per timer tick
    if (tmp)
      cycles = 0x20 << tmp;
    else
      cycles = 2;
    timer_tick_cycles[i] = cycles;
    timer_cycles[i] = 0;
    elprintf(EL_32XP, "WDT cycles[%d] = %d", i, cycles);
  }
}

void p32x_timers_do(unsigned int m68k_slice)
{
  unsigned int cycles = m68k_slice * 3;
  int cnt, i;

  // WDT timers
  for (i = 0; i < 2; i++) {
    void *pregs = sh2s[i].peri_regs;
    if (PREG8(pregs, 0x80) & 0x20) { // TME
      timer_cycles[i] += cycles;
      cnt = PREG8(pregs, 0x81);
      while (timer_cycles[i] >= timer_tick_cycles[i]) {
        timer_cycles[i] -= timer_tick_cycles[i];
        cnt++;
      }
      if (cnt >= 0x100) {
        int level = PREG8(pregs, 0xe3) >> 4;
        int vector = PREG8(pregs, 0xe4) & 0x7f;
        elprintf(EL_32XP, "%csh2 WDT irq (%d, %d)",
          i ? 's' : 'm', level, vector);
        sh2_internal_irq(&sh2s[i], level, vector);
        cnt &= 0xff;
      }
      PREG8(pregs, 0x81) = cnt;
    }
  }
}

void sh2_peripheral_reset(SH2 *sh2)
{
  memset(sh2->peri_regs, 0, sizeof(sh2->peri_regs)); // ?
  PREG8(sh2->peri_regs, 0x001) = 0xff; // SCI BRR
  PREG8(sh2->peri_regs, 0x003) = 0xff; // SCI TDR
  PREG8(sh2->peri_regs, 0x004) = 0x84; // SCI SSR
  PREG8(sh2->peri_regs, 0x011) = 0x01; // TIER
  PREG8(sh2->peri_regs, 0x017) = 0xe0; // TOCR
}

// ------------------------------------------------------------------
// SH2 internal peripheral memhandlers
// we keep them in little endian format

u32 sh2_peripheral_read8(u32 a, SH2 *sh2)
{
  u8 *r = (void *)sh2->peri_regs;
  u32 d;

  a &= 0x1ff;
  d = PREG8(r, a);

  elprintf_sh2(sh2, EL_32XP, "peri r8  [%08x]       %02x @%06x",
    a | ~0x1ff, d, sh2_pc(sh2));
  return d;
}

u32 sh2_peripheral_read16(u32 a, SH2 *sh2)
{
  u16 *r = (void *)sh2->peri_regs;
  u32 d;

  a &= 0x1ff;
  d = r[(a / 2) ^ 1];

  elprintf_sh2(sh2, EL_32XP, "peri r16 [%08x]     %04x @%06x",
    a | ~0x1ff, d, sh2_pc(sh2));
  return d;
}

u32 sh2_peripheral_read32(u32 a, SH2 *sh2)
{
  u32 d;
  a &= 0x1fc;
  d = sh2->peri_regs[a / 4];

  elprintf_sh2(sh2, EL_32XP, "peri r32 [%08x] %08x @%06x",
    a | ~0x1ff, d, sh2_pc(sh2));
  return d;
}

static void sci_trigger(SH2 *sh2, u8 *r)
{
  u8 *oregs;

  if (!(PREG8(r, 2) & 0x20))
    return; // transmitter not enabled
  if ((PREG8(r, 4) & 0x80)) // TDRE - TransmitDataR Empty
    return;

  oregs = (u8 *)sh2->other_sh2->peri_regs;
  if (!(PREG8(oregs, 2) & 0x10))
    return; // receiver not enabled

  PREG8(oregs, 5) = PREG8(r, 3); // other.RDR = this.TDR
  PREG8(r, 4) |= 0x80;     // TDRE - TDR empty
  PREG8(oregs, 4) |= 0x40; // RDRF - RDR Full

  // might need to delay these a bit..
  if (PREG8(r, 2) & 0x80) { // TIE - tx irq enabled
    int level = PREG8(oregs, 0x60) >> 4;
    int vector = PREG8(oregs, 0x64) & 0x7f;
    elprintf_sh2(sh2, EL_32XP, "SCI tx irq (%d, %d)",
      level, vector);
    sh2_internal_irq(sh2, level, vector);
  }
  // TODO: TEIE
  if (PREG8(oregs, 2) & 0x40) { // RIE - rx irq enabled
    int level = PREG8(oregs, 0x60) >> 4;
    int vector = PREG8(oregs, 0x63) & 0x7f;
    elprintf_sh2(sh2->other_sh2, EL_32XP, "SCI rx irq (%d, %d)",
      level, vector);
    sh2_internal_irq(sh2->other_sh2, level, vector);
  }
}

void REGPARM(3) sh2_peripheral_write8(u32 a, u32 d, SH2 *sh2)
{
  u8 *r = (void *)sh2->peri_regs;
  u8 old;

  elprintf_sh2(sh2, EL_32XP, "peri w8  [%08x]       %02x @%06x",
    a, d, sh2_pc(sh2));

  a &= 0x1ff;
  old = PREG8(r, a);

  switch (a) {
  case 0x002: // SCR - serial control
    if (!(PREG8(r, a) & 0x20) && (d & 0x20)) { // TE being set
      PREG8(r, a) = d;
      sci_trigger(sh2, r);
    }
    break;
  case 0x003: // TDR - transmit data
    break;
  case 0x004: // SSR - serial status
    d = (old & (d | 0x06)) | (d & 1);
    PREG8(r, a) = d;
    sci_trigger(sh2, r);
    return;
  case 0x005: // RDR - receive data
    break;
  case 0x010: // TIER
    if (d & 0x8e)
      elprintf(EL_32XP|EL_ANOMALY, "TIER: %02x", d);
    d = (d & 0x8e) | 1;
    break;
  case 0x017: // TOCR
    d |= 0xe0;
    break;
  }
  PREG8(r, a) = d;
}

void REGPARM(3) sh2_peripheral_write16(u32 a, u32 d, SH2 *sh2)
{
  u16 *r = (void *)sh2->peri_regs;
  elprintf_sh2(sh2, EL_32XP, "peri w16 [%08x]     %04x @%06x",
    a, d, sh2_pc(sh2));

  a &= 0x1ff;

  // evil WDT
  if (a == 0x80) {
    if ((d & 0xff00) == 0xa500) { // WTCSR
      PREG8(r, 0x80) = d;
      p32x_timers_recalc();
    }
    if ((d & 0xff00) == 0x5a00) // WTCNT
      PREG8(r, 0x81) = d;
    return;
  }

  r[(a / 2) ^ 1] = d;
}

void REGPARM(3) sh2_peripheral_write32(u32 a, u32 d, SH2 *sh2)
{
  u32 *r = sh2->peri_regs;
  u32 old;

  elprintf_sh2(sh2, EL_32XP, "peri w32 [%08x] %08x @%06x",
    a, d, sh2_pc(sh2));

  a &= 0x1fc;
  old = r[a / 4];
  r[a / 4] = d;

  switch (a) {
    // division unit (TODO: verify):
    case 0x104: // DVDNT: divident L, starts divide
      elprintf_sh2(sh2, EL_32XP, "divide %08x / %08x",
        d, r[0x100 / 4]);
      if (r[0x100 / 4]) {
        signed int divisor = r[0x100 / 4];
                       r[0x118 / 4] = r[0x110 / 4] = (signed int)d % divisor;
        r[0x104 / 4] = r[0x11c / 4] = r[0x114 / 4] = (signed int)d / divisor;
      }
      else
        r[0x110 / 4] = r[0x114 / 4] = r[0x118 / 4] = r[0x11c / 4] = 0; // ?
      break;
    case 0x114:
      elprintf_sh2(sh2, EL_32XP, "divide %08x%08x / %08x @%08x",
        r[0x110 / 4], d, r[0x100 / 4], sh2_pc(sh2));
      if (r[0x100 / 4]) {
        signed long long divident = (signed long long)r[0x110 / 4] << 32 | d;
        signed int divisor = r[0x100 / 4];
        // XXX: undocumented mirroring to 0x118,0x11c?
        r[0x118 / 4] = r[0x110 / 4] = divident % divisor;
        divident /= divisor;
        r[0x11c / 4] = r[0x114 / 4] = divident;
        divident >>= 31;
        if ((unsigned long long)divident + 1 > 1) {
          //elprintf_sh2(sh2, EL_32XP, "divide overflow! @%08x", sh2_pc(sh2));
          r[0x11c / 4] = r[0x114 / 4] = divident > 0 ? 0x7fffffff : 0x80000000; // overflow
        }
      }
      else
        r[0x110 / 4] = r[0x114 / 4] = r[0x118 / 4] = r[0x11c / 4] = 0; // ?
      break;
  }

  // perhaps starting a DMA?
  if (a == 0x1b0 || a == 0x18c || a == 0x19c) {
    struct dmac *dmac = (void *)&sh2->peri_regs[0x180 / 4];
    if (a == 0x1b0 && !((old ^ d) & d & DMA_DME))
      return;
    if (!(dmac->dmaor & DMA_DME))
      return;

    if ((dmac->chan[0].chcr & (DMA_TE|DMA_DE)) == DMA_DE)
      dmac_trigger(sh2, &dmac->chan[0]);
    if ((dmac->chan[1].chcr & (DMA_TE|DMA_DE)) == DMA_DE)
      dmac_trigger(sh2, &dmac->chan[1]);
  }
}

/* 32X specific */
static void dreq0_do(SH2 *sh2, struct dma_chan *chan)
{
  unsigned short dreqlen = Pico32x.regs[0x10 / 2];
  int i;

  // debug/sanity checks
  if (chan->tcr < dreqlen || chan->tcr > dreqlen + 4)
    elprintf(EL_32XP|EL_ANOMALY, "dreq0: tcr0/len inconsistent: %d/%d",
      chan->tcr, dreqlen);
  // note: DACK is not connected, single addr mode should not be used
  if ((chan->chcr & 0x3f08) != 0x0400)
    elprintf(EL_32XP|EL_ANOMALY, "dreq0: bad control: %04x", chan->chcr);
  if ((chan->sar & ~0x20000000) != 0x00004012)
    elprintf(EL_32XP|EL_ANOMALY, "dreq0: bad sar?: %08x", chan->sar);

  // HACK: assume bus is busy and SH2 is halted
  sh2->state |= SH2_STATE_SLEEP;

  for (i = 0; i < Pico32x.dmac0_fifo_ptr && chan->tcr > 0; i++) {
    elprintf_sh2(sh2, EL_32XP, "dreq0 [%08x] %04x, dreq_len %d",
      chan->dar, Pico32x.dmac_fifo[i], dreqlen);
    p32x_sh2_write16(chan->dar, Pico32x.dmac_fifo[i], sh2);
    chan->dar += 2;
    chan->tcr--;
  }

  if (Pico32x.dmac0_fifo_ptr != i)
    memmove(Pico32x.dmac_fifo, &Pico32x.dmac_fifo[i],
      (Pico32x.dmac0_fifo_ptr - i) * 2);
  Pico32x.dmac0_fifo_ptr -= i;

  Pico32x.regs[6 / 2] &= ~P32XS_FULL;
  if (chan->tcr == 0)
    dmac_transfer_complete(sh2, chan);
  else
    sh2_end_run(sh2, 16);
}

static void dreq1_do(SH2 *sh2, struct dma_chan *chan)
{
  // debug/sanity checks
  if ((chan->chcr & 0xc308) != 0x0000)
    elprintf(EL_32XP|EL_ANOMALY, "dreq1: bad control: %04x", chan->chcr);
  if ((chan->dar & ~0xf) != 0x20004030)
    elprintf(EL_32XP|EL_ANOMALY, "dreq1: bad dar?: %08x\n", chan->dar);

  dmac_transfer_one(sh2, chan);
  if (chan->tcr == 0)
    dmac_transfer_complete(sh2, chan);
}

void p32x_dreq0_trigger(void)
{
  struct dmac *mdmac = (void *)&msh2.peri_regs[0x180 / 4];
  struct dmac *sdmac = (void *)&ssh2.peri_regs[0x180 / 4];

  elprintf(EL_32XP, "dreq0_trigger");
  if ((mdmac->dmaor & DMA_DME) && (mdmac->chan[0].chcr & 3) == DMA_DE) {
    dreq0_do(&msh2, &mdmac->chan[0]);
  }
  if ((sdmac->dmaor & DMA_DME) && (sdmac->chan[0].chcr & 3) == DMA_DE) {
    dreq0_do(&ssh2, &sdmac->chan[0]);
  }
}

void p32x_dreq1_trigger(void)
{
  struct dmac *mdmac = (void *)&msh2.peri_regs[0x180 / 4];
  struct dmac *sdmac = (void *)&ssh2.peri_regs[0x180 / 4];
  int hit = 0;

  elprintf(EL_32XP, "dreq1_trigger");
  if ((mdmac->dmaor & DMA_DME) && (mdmac->chan[1].chcr & 3) == DMA_DE) {
    dreq1_do(&msh2, &mdmac->chan[1]);
    hit = 1;
  }
  if ((sdmac->dmaor & DMA_DME) && (sdmac->chan[1].chcr & 3) == DMA_DE) {
    dreq1_do(&ssh2, &sdmac->chan[1]);
    hit = 1;
  }

  // debug
#if (EL_LOGMASK & (EL_32XP|EL_ANOMALY))
  {
    static int miss_count;
    if (!hit) {
      if (++miss_count == 4)
        elprintf(EL_32XP|EL_ANOMALY, "dreq1: nobody cared");
    }
    else
      miss_count = 0;
  }
#endif
  (void)hit;
}

// vim:shiftwidth=2:ts=2:expandtab
