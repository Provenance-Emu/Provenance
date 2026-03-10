/*
 * Memory I/O handlers for Sega/Mega CD.
 * (C) notaz, 2007-2009
 * (C) irixxxx, 2019-2024
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include "../pico_int.h"
#include "../memory.h"
#include "megasd.h"

uptr s68k_read8_map  [0x1000000 >> M68K_MEM_SHIFT];
uptr s68k_read16_map [0x1000000 >> M68K_MEM_SHIFT];
uptr s68k_write8_map [0x1000000 >> M68K_MEM_SHIFT];
uptr s68k_write16_map[0x1000000 >> M68K_MEM_SHIFT];

#ifndef _ASM_CD_MEMORY_C
MAKE_68K_READ8(s68k_read8, s68k_read8_map)
MAKE_68K_READ16(s68k_read16, s68k_read16_map)
MAKE_68K_READ32(s68k_read32, s68k_read16_map)
MAKE_68K_WRITE8(s68k_write8, s68k_write8_map)
MAKE_68K_WRITE16(s68k_write16, s68k_write16_map)
MAKE_68K_WRITE32(s68k_write32, s68k_write16_map)
#endif

u32 pcd_base_address;
#define BASE pcd_base_address

// -----------------------------------------------------------------

// provided by ASM code:
#ifdef _ASM_CD_MEMORY_C
u32 PicoReadS68k8_pr(u32 a);
u32 PicoReadS68k16_pr(u32 a);
void PicoWriteS68k8_pr(u32 a, u32 d);
void PicoWriteS68k16_pr(u32 a, u32 d);

u32 PicoReadM68k8_cell0(u32 a);
u32 PicoReadM68k8_cell1(u32 a);
u32 PicoReadM68k16_cell0(u32 a);
u32 PicoReadM68k16_cell1(u32 a);
void PicoWriteM68k8_cell0(u32 a, u32 d);
void PicoWriteM68k8_cell1(u32 a, u32 d);
void PicoWriteM68k16_cell0(u32 a, u32 d);
void PicoWriteM68k16_cell1(u32 a, u32 d);

u32 PicoReadS68k8_dec0(u32 a);
u32 PicoReadS68k8_dec1(u32 a);
u32 PicoReadS68k16_dec0(u32 a);
u32 PicoReadS68k16_dec1(u32 a);
void PicoWriteS68k8_dec_m0b0(u32 a, u32 d);
void PicoWriteS68k8_dec_m1b0(u32 a, u32 d);
void PicoWriteS68k8_dec_m2b0(u32 a, u32 d);
void PicoWriteS68k8_dec_m0b1(u32 a, u32 d);
void PicoWriteS68k8_dec_m1b1(u32 a, u32 d);
void PicoWriteS68k8_dec_m2b1(u32 a, u32 d);
void PicoWriteS68k16_dec_m0b0(u32 a, u32 d);
void PicoWriteS68k16_dec_m1b0(u32 a, u32 d);
void PicoWriteS68k16_dec_m2b0(u32 a, u32 d);
void PicoWriteS68k16_dec_m0b1(u32 a, u32 d);
void PicoWriteS68k16_dec_m1b1(u32 a, u32 d);
void PicoWriteS68k16_dec_m2b1(u32 a, u32 d);
#endif

static void remap_prg_window(u32 r1, u32 r3);
static void remap_word_ram(u32 r3);

// poller detection
#define POLL_LIMIT 16
#define POLL_CYCLES 52

void m68k_comm_check(u32 a)
{
  u32 cycles = SekCyclesDone();
  u32 clkdiff = cycles - Pico_mcd->m.m68k_poll_clk;
  pcd_sync_s68k(cycles, 0);
  if (a == 0x0e && !(Pico_mcd->m.state_flags & PCD_ST_S68K_SYNC) && (Pico_mcd->s68k_regs[3]&0x4)) {
    // there are cases when slave updates comm and only switches RAM
    // over after that (mcd1 bios), so there must be a resync..
    SekEndRun(64);
    Pico_mcd->m.state_flags |= PCD_ST_S68K_SYNC;
  }
  Pico_mcd->m.m68k_poll_clk = cycles;
  if (SekNotPolling || a != Pico_mcd->m.m68k_poll_a || clkdiff > POLL_CYCLES || clkdiff <= 16) {
    Pico_mcd->m.m68k_poll_a = a;
    Pico_mcd->m.m68k_poll_cnt = 0;
    SekNotPolling = 0;
    return;
  }
  Pico_mcd->m.m68k_poll_cnt++;
  Pico_mcd->m.state_flags &= ~PCD_ST_M68K_POLL;
  if (Pico_mcd->m.m68k_poll_cnt >= POLL_LIMIT) {
    Pico_mcd->m.state_flags |= PCD_ST_M68K_POLL;
    SekEndRun(8);
  }
}

u32 pcd_stopwatch_read(int sub)
{
  // ugh... stopwatch runs 384 cycles per step, divide by mult with inverse
  u32 d = sub ? SekCyclesDoneS68k() : pcd_cycles_m68k_to_s68k(SekCyclesDone());
  d = ((d - Pico_mcd->m.stopwatch_base_c) * ((1LL << 32) / 384)) >> 32;
  return d & 0x0fff;
}

#ifndef _ASM_CD_MEMORY_C
static u32 m68k_reg_read16(u32 a)
{
  u32 d = 0;
  a &= 0x3e;

  switch (a) {
    case 0:
      pcd_sync_s68k(SekCyclesDone(), 0);
      d = ((Pico_mcd->s68k_regs[0x33] & PCDS_IEN2) << 13) |
          (Pico_mcd->m.state_flags & PCD_ST_S68K_IFL2) | Pico_mcd->m.busreq;
      goto end;
    case 2:
      m68k_comm_check(a);
      d = (Pico_mcd->s68k_regs[a]<<8) | (Pico_mcd->s68k_regs[a+1]&0xc7);
      elprintf(EL_CDREG3, "m68k_regs r3: %02x @%06x", (u8)d, SekPc);
      goto end;
    case 4:
      pcd_sync_s68k(SekCyclesDone(), 0);
      d = Pico_mcd->s68k_regs[4]<<8;
      goto end;
    case 6:
      d = *(u16 *)(Pico_mcd->bios + 0x72);
      goto end;
    case 8:
      d = cdc_host_r(0);
      goto end;
    case 0xa:
      elprintf(EL_UIO, "m68k FIXME: reserved read");
      goto end;
    case 0xc: // 384 cycle stopwatch timer
      pcd_sync_s68k(SekCyclesDone(), 0);
      d = pcd_stopwatch_read(0);
      elprintf(EL_CDREGS, "m68k stopwatch timer read (%04x)", d);
      goto end;
  }

  if (a < 0x30) {
    // comm flag/cmd/status (0xE-0x2F)
    m68k_comm_check(a);
    d = (Pico_mcd->s68k_regs[a]<<8) | Pico_mcd->s68k_regs[a+1];
    return d;
  }

  elprintf(EL_UIO, "m68k_regs FIXME invalid read @ %02x", a);

end:
  return d;
}
#endif

#ifndef _ASM_CD_MEMORY_C
static
#endif
void m68k_reg_write8(u32 a, u32 d)
{
  u32 dold;
  a &= 0x3f;

  Pico_mcd->m.state_flags &= ~PCD_ST_M68K_POLL;
  Pico_mcd->m.m68k_poll_cnt = 0;

  switch (a) {
    case 0:
      d &= 1;
      pcd_sync_s68k(SekCyclesDone(), 0);
      if (d && (Pico_mcd->s68k_regs[0x33] & PCDS_IEN2)) {
        elprintf(EL_INTS, "m68k: s68k irq 2");
        Pico_mcd->m.state_flags |= PCD_ST_S68K_IFL2;
        pcd_irq_s68k(2, 1);
      } else {
        Pico_mcd->m.state_flags &= ~PCD_ST_S68K_IFL2;
        pcd_irq_s68k(2, 0);
      }
      return;
    case 1:
      d &= 3;
      dold = Pico_mcd->m.busreq;
//      if (!(d & 1))
//        d |= 2; // verified: can't release bus on reset
      if (dold == d)
        return;

      pcd_sync_s68k(SekCyclesDone(), 0);

      if ((dold ^ d) & 1)
        elprintf(EL_INTSW, "m68k: s68k reset %i", !(d&1));
      if (!(d & 1))
        Pico_mcd->m.state_flags |= PCD_ST_S68K_RST;
      else if (d == 1 && (Pico_mcd->m.state_flags & PCD_ST_S68K_RST)) {
        Pico_mcd->m.state_flags &= ~(PCD_ST_S68K_RST|PCD_ST_S68K_POLL|PCD_ST_S68K_SLEEP);
        elprintf(EL_CDREGS, "m68k: resetting s68k");
        SekResetS68k();
        SekCycleCntS68k += 40;
      }
      if (((dold & 3) == 1) != ((d & 3) == 1)) {
        elprintf(EL_INTSW, "m68k: s68k brq %i", d >> 1);
        remap_prg_window(d, Pico_mcd->s68k_regs[3]);
      }
      Pico_mcd->m.busreq = d;
      return;
    case 2:
      elprintf(EL_CDREGS, "m68k: prg wp=%02x", d);
      goto write_comm;
    case 3:
      elprintf(EL_CDREG3, "m68k_regs w3: %02x @%06x", (u8)d, SekPc);
      dold = Pico_mcd->s68k_regs[3];
      if ((d ^ dold) & 0xc0) {
        elprintf(EL_CDREGS, "m68k: prg bank: %i -> %i",
          (Pico_mcd->s68k_regs[a]>>6), ((d>>6)&3));
        remap_prg_window(Pico_mcd->m.busreq, d);
      }

      // 2M mode state is tracked regardless of current mode
      if (d & 2) {
        Pico_mcd->m.dmna_ret_2m |= 2;
        Pico_mcd->m.dmna_ret_2m &= ~1;
      }
      if (dold & 4) { // 1M mode
        d ^= 2;       // 0 sets DMNA, 1 does nothing
        d = (d & 0xc2) | (dold & 0x1f);
      }
      else
        d = (d & 0xc0) | (dold & 0x1c) | Pico_mcd->m.dmna_ret_2m;
      if ((dold ^ d) & 0x1f)
        remap_word_ram(d);
      goto write_comm;
    case 6:
      Pico_mcd->bios[MEM_BE2(0x72)] = d; // simple hint vector changer
      return;
    case 7:
      Pico_mcd->bios[MEM_BE2(0x73)] = d;
      elprintf(EL_CDREGS, "hint vector set to %04x%04x",
        ((u16 *)Pico_mcd->bios)[0x70/2], ((u16 *)Pico_mcd->bios)[0x72/2]);
      return;
    case 8:
      (void) cdc_host_r(0); // acts same as reading
      return;
    case 0x0f:
      a = 0x0e;
    case 0x0e:
      goto write_comm;
  }

  if ((a&0xf0) == 0x10)
    goto write_comm;

  elprintf(EL_UIO, "m68k FIXME: invalid write? [%02x] %02x", a, d);
  return;

write_comm:
  if (Pico_mcd->s68k_regs[a] == (u8)d)
    return;

  pcd_sync_s68k(SekCyclesDone(), 0);
  Pico_mcd->s68k_regs[a] = d;
  if (a == 0x03) {
    // There are cases when master checks for successful switching of RAM to
    // slave. This can produce race conditions where slave switches RAM back to
    // master while master is delayed by interrupt before the check executes.
    // Delay slave a bit to make sure master can check before slave changes.
    SekCycleCntS68k += 24; // Silpheed
  }
  if (!((Pico_mcd->m.s68k_poll_a ^ a) & ~1)) {
    if (Pico_mcd->m.state_flags & PCD_ST_S68K_POLL)
      elprintf(EL_CDPOLL, "s68k poll release, a=%02x", a);
    Pico_mcd->m.state_flags &= ~PCD_ST_S68K_POLL;
    Pico_mcd->m.s68k_poll_cnt = 0;
  }
}

u32 s68k_poll_detect(u32 a, u32 d)
{
#ifdef USE_POLL_DETECT
  u32 cycles, cnt = 0;
  if (Pico_mcd->m.state_flags & (PCD_ST_S68K_POLL|PCD_ST_S68K_SLEEP))
    return d;

  cycles = SekCyclesDoneS68k();
  if (!SekNotPollingS68k && a == Pico_mcd->m.s68k_poll_a) {
    u32 clkdiff = cycles - Pico_mcd->m.s68k_poll_clk;
    if (clkdiff <= POLL_CYCLES) {
      cnt = Pico_mcd->m.s68k_poll_cnt + 1;
      //printf("-- diff: %u, cnt = %i\n", clkdiff, cnt);
      Pico_mcd->m.state_flags &= ~PCD_ST_S68K_POLL;
      if (cnt > POLL_LIMIT) {
        Pico_mcd->m.state_flags |= PCD_ST_S68K_POLL;
        SekEndRunS68k(8);
        elprintf(EL_CDPOLL, "s68k poll detected @%06x, a=%02x",
          SekPcS68k, a);
      } else if (cnt > 2)
        SekEndRunS68k(240);
    }
  }
  Pico_mcd->m.s68k_poll_a = a;
  Pico_mcd->m.s68k_poll_clk = cycles;
  Pico_mcd->m.s68k_poll_cnt = cnt;
  SekNotPollingS68k = 0;
#endif
  return d;
}

#define READ_FONT_DATA(basemask) \
{ \
      unsigned int fnt = CPU_LE4(*(u32 *)(Pico_mcd->s68k_regs + 0x4c)); \
      unsigned int col0 = (fnt >> 8) & 0x0f, col1 = (fnt >> 12) & 0x0f;   \
      if (fnt & (basemask << 0)) d  = col1      ; else d  = col0;       \
      if (fnt & (basemask << 1)) d |= col1 <<  4; else d |= col0 <<  4; \
      if (fnt & (basemask << 2)) d |= col1 <<  8; else d |= col0 <<  8; \
      if (fnt & (basemask << 3)) d |= col1 << 12; else d |= col0 << 12; \
}


#ifndef _ASM_CD_MEMORY_C
static
#endif
u32 s68k_reg_read16(u32 a)
{
  u32 d=0;

  switch (a) {
    case 0:
      d = ((Pico_mcd->s68k_regs[0]&3)<<8) | 1; // ver = 0, not in reset state
      goto end;
    case 2:
      d = (Pico_mcd->s68k_regs[2]<<8) | (Pico_mcd->s68k_regs[3]&0x1f);
      elprintf(EL_CDREG3, "s68k_regs r3: %02x @%06x", (u8)d, SekPcS68k);
      s68k_poll_detect(a, d);
      goto end;
    case 4:
      d = (Pico_mcd->s68k_regs[4]<<8) | (Pico_mcd->s68k_regs[5]&0x1f);
      goto end;
    case 6:
      d = cdc_reg_r();
      goto end;
    case 8:
      d = cdc_host_r(1);
      goto end;
    case 0xc:
      d = pcd_stopwatch_read(1);
      elprintf(EL_CDREGS, "s68k stopwatch timer read (%04x)", d);
      goto end;
    case 0x30:
      elprintf(EL_CDREGS, "s68k int3 timer read (%02x)", Pico_mcd->s68k_regs[0x31]);
      d = Pico_mcd->s68k_regs[0x31];
      goto end;
    case 0x34: // fader
      d = 0; // no busy bit
      goto end;
    case 0x50: // font data (check: Lunar 2, Silpheed)
      READ_FONT_DATA(0x00100000);
      goto end;
    case 0x52:
      READ_FONT_DATA(0x00010000);
      goto end;
    case 0x54:
      READ_FONT_DATA(0x10000000);
      goto end;
    case 0x56:
      READ_FONT_DATA(0x01000000);
      goto end;
  }

  d = (Pico_mcd->s68k_regs[a]<<8) | Pico_mcd->s68k_regs[a+1];

  if ((a >= 0x0e && a < 0x30) || a == 0x58)
    d = s68k_poll_detect(a, d);

end:
  return d;
}

#ifndef _ASM_CD_MEMORY_C
static
#endif
void s68k_reg_write8(u32 a, u32 d)
{
  // Warning: d might have upper bits set
  switch (a) {
    case 1:
      if (!(d & 1))
        pcd_soft_reset();
      return;
    case 2: a++; // byte access only, ignores LDS/UDS
    case 3: {
      int dold = Pico_mcd->s68k_regs[3];
      elprintf(EL_CDREG3, "s68k_regs w3: %02x @%06x", (u8)d, SekPcS68k);
      d &= 0x1d;
      d |= dold & 0xc2;

      // 2M mode state
      if (d & 1) {
        Pico_mcd->m.dmna_ret_2m |= 1;
        Pico_mcd->m.dmna_ret_2m &= ~2; // DMNA clears
      }

      if (d & 4)
      {
        if (!(dold & 4)) {
          elprintf(EL_CDREG3, "wram mode 2M->1M");
          wram_2M_to_1M(Pico_mcd->word_ram2M);
        }

        if ((d ^ dold) & 0x05)
          d &= ~2; // clear DMNA - swap complete
      }
      else
      {
        if (dold & 4) {
          elprintf(EL_CDREG3, "wram mode 1M->2M");
          wram_1M_to_2M(Pico_mcd->word_ram2M);
        }
        d = (d & ~3) | Pico_mcd->m.dmna_ret_2m;
      }
      if ((dold ^ d) & 0x1f)
        remap_word_ram(d);
      goto write_comm;
    }
    case 4:
      elprintf(EL_CDREGS, "s68k CDC dest: %x", d&7);
      Pico_mcd->s68k_regs[a] = (d&7); // CDC mode
      Pico_mcd->s68k_regs[0xa] = Pico_mcd->s68k_regs[0xb] = 0; // resets DMA
      return;
    case 5:
      //dprintf("s68k CDC reg addr: %x", d&0x1f);
      Pico_mcd->s68k_regs[a] = (d&0x1f);
      return;
    case 7:
      cdc_reg_w(d & 0xff);
      return;
    case 0xa:
    case 0xb:
      // word access only. 68k sets both bus halves to value d.
      elprintf(EL_CDREGS, "s68k set CDC dma addr");
      Pico_mcd->s68k_regs[0xa] = Pico_mcd->s68k_regs[0xb] = d;
      return;
    case 0xc:
    case 0xd: // 384 cycle stopwatch timer
      elprintf(EL_CDREGS|EL_CD, "s68k clear stopwatch (%x)", d);
      // does this also reset internal 384 cycle counter?
      Pico_mcd->m.stopwatch_base_c = SekCyclesDoneS68k();
      return;
    case 0x0e: a++;
    case 0x0f:
      goto write_comm;
    case 0x30: a++;
    case 0x31: // 384 cycle int3 timer
      d &= 0xff;
      elprintf(EL_CDREGS|EL_CD, "s68k set int3 timer: %02x", d);
      Pico_mcd->s68k_regs[a] = (u8) d;
      if (d) // XXX: d or d+1? mcd-verificator results suggest d+1
        pcd_event_schedule_s68k(PCD_EVENT_TIMER3, (d+1) * 384);
      else
        pcd_event_schedule(0, PCD_EVENT_TIMER3, 0);
      break;
    case 0x33: // IRQ mask
      elprintf(EL_CDREGS|EL_CD, "s68k irq mask: %02x", d);
      d &= 0x7e;
      if ((d ^ Pico_mcd->s68k_regs[0x33]) & PCDS_IEN4) {
        // XXX: emulate pending irq instead?
        if ((d & PCDS_IEN4) && (Pico_mcd->s68k_regs[0x37] & 4)) {
          elprintf(EL_INTS, "cdd export irq 4 (unmask)");
          pcd_irq_s68k(4, 1);
        }
      }
      if ((d ^ Pico_mcd->s68k_regs[0x33]) & ~d & PCDS_IEN2)
	pcd_irq_s68k(2, 0);
      break;
    case 0x34: // fader
      Pico_mcd->s68k_regs[a] = (u8) d & 0x7f;
      return;
    case 0x36:
      return; // d/m bit is unsetable
    case 0x37: {
      u32 d_old = Pico_mcd->s68k_regs[0x37];
      Pico_mcd->s68k_regs[0x37] = d & 7;
      if ((d ^ d_old) & 4) {
        if ((d & 4) && (Pico_mcd->s68k_regs[0x33] & PCDS_IEN4)) {
          elprintf(EL_INTS, "cdd export irq 4");
          pcd_irq_s68k(4, 1);
        }
      }
      return;
    }
    case 0x4b:
      Pico_mcd->s68k_regs[a] = 0; // (u8) d; ?
      cdd_process();
      {
        static const char *nm[] =
          { "stat", "stop", "read_toc", "play",
            "seek", "???",  "pause",    "resume",
            "ff",   "fr",   "tjump",    "???",
            "close","open", "???",      "???" };
        u8 *c = &Pico_mcd->s68k_regs[0x42];
        u8 *s = &Pico_mcd->s68k_regs[0x38];
        elprintf(EL_CD,
          "CDD command: %02x %02x %02x %02x %02x %02x %02x %02x %12s",
          c[0], c[1], c[2], c[3], c[4], c[5], c[6], c[7], nm[c[0] & 0x0f]);
        elprintf(EL_CD,
          "CDD status:  %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x",
          s[0], s[1], s[2], s[3], s[4], s[5], s[6], s[7], s[8], s[9]);
      }
      return;
    case 0x4c: a++;
      break;
    case 0x58:
      return;
  }

  if ((a&0x1f0) == 0x20)
    goto write_comm;

  if ((a&0x1f0) == 0x10 || (a >= 0x38 && a < 0x42))
  {
    elprintf(EL_UIO, "s68k FIXME: invalid write @ %02x?", a);
    return;
  }

  Pico_mcd->s68k_regs[a] = (u8) d;
  return;

write_comm:
  if (Pico_mcd->s68k_regs[a] == (u8)d)
    return;

  Pico_mcd->s68k_regs[a] = (u8) d;
  if (!((Pico_mcd->m.m68k_poll_a ^ a) & ~1)) {
    SekEndRunS68k(8);
    Pico_mcd->m.state_flags &= ~PCD_ST_M68K_POLL;
    Pico_mcd->m.m68k_poll_cnt = 0;
  }
}

void s68k_reg_write16(u32 a, u32 d)
{
  u8 *r = Pico_mcd->s68k_regs;

  Pico_mcd->m.state_flags &= ~PCD_ST_S68K_POLL;
  Pico_mcd->m.s68k_poll_cnt = 0;

  if ((a & 0x1f0) == 0x20)
    goto write_comm;

  switch (a) {
    case 0x02:
    case 0x0e:
    case 0x30:
    case 0x4c:
      // these are only byte registers, LDS/UDS ignored
      return s68k_reg_write8(a + 1, d);
    case 0x08:
      return (void) cdc_host_r(1); // acts same as reading
    case 0x0a: // DMA address
      r[0xa] = d >> 8;
      r[0xb] = d;
      return;
    case 0x58: // stamp data size
      r[0x59] = d & 7;
      return;
    case 0x5a: // stamp map base address
      r[0x5a] = d >> 8;
      r[0x5b] = d & 0xe0;
      return;
    case 0x5c: // V cell size
      r[0x5d] = d & 0x1f;
      return;
    case 0x5e: // image buffer start address
      r[0x5e] = d >> 8;
      r[0x5f] = d & 0xf8;
      return;
    case 0x60: // image buffer offset
      r[0x61] = d & 0x3f;
      return;
    case 0x62: // h dot size
      r[0x62] = (d >> 8) & 1;
      r[0x63] = d;
      return;
    case 0x64: // v dot size
      r[0x65] = d;
      return;
    case 0x66: // trace vector base address
      d &= 0xfffe;
      r[0x66] = d >> 8;
      r[0x67] = d;
      gfx_start(d);
      return;
    default:
      break;
  }

  s68k_reg_write8(a,     d >> 8);
  s68k_reg_write8(a + 1, d & 0xff);
  return;

write_comm:
  if (r[a] == (u8)(d >> 8) && r[a + 1] == (u8)d)
    return;

  r[a] = d >> 8;
  r[a + 1] = d;
  if (!((Pico_mcd->m.m68k_poll_a ^ a) & ~1)) {
    SekEndRunS68k(8);
    Pico_mcd->m.state_flags &= ~PCD_ST_M68K_POLL;
    Pico_mcd->m.m68k_poll_cnt = 0;
  }
}

// -----------------------------------------------------------------
//                          Main 68k
// -----------------------------------------------------------------

#ifndef _ASM_CD_MEMORY_C
#include "cell_map.c"

// WORD RAM, cell aranged area (220000 - 23ffff)
static u32 PicoReadM68k8_cell0(u32 a)
{
  a = (a&3) | (cell_map(a >> 2) << 2); // cell arranged
  return Pico_mcd->word_ram1M[0][MEM_BE2(a)];
}

static u32 PicoReadM68k8_cell1(u32 a)
{
  a = (a&3) | (cell_map(a >> 2) << 2);
  return Pico_mcd->word_ram1M[1][MEM_BE2(a)];
}

static u32 PicoReadM68k16_cell0(u32 a)
{
  a = (a&2) | (cell_map(a >> 2) << 2);
  return *(u16 *)(Pico_mcd->word_ram1M[0] + a);
}

static u32 PicoReadM68k16_cell1(u32 a)
{
  a = (a&2) | (cell_map(a >> 2) << 2);
  return *(u16 *)(Pico_mcd->word_ram1M[1] + a);
}

static void PicoWriteM68k8_cell0(u32 a, u32 d)
{
  a = (a&3) | (cell_map(a >> 2) << 2);
  Pico_mcd->word_ram1M[0][MEM_BE2(a)] = d;
}

static void PicoWriteM68k8_cell1(u32 a, u32 d)
{
  a = (a&3) | (cell_map(a >> 2) << 2);
  Pico_mcd->word_ram1M[1][MEM_BE2(a)] = d;
}

static void PicoWriteM68k16_cell0(u32 a, u32 d)
{
  a = (a&3) | (cell_map(a >> 2) << 2);
  *(u16 *)(Pico_mcd->word_ram1M[0] + a) = d;
}

static void PicoWriteM68k16_cell1(u32 a, u32 d)
{
  a = (a&3) | (cell_map(a >> 2) << 2);
  *(u16 *)(Pico_mcd->word_ram1M[1] + a) = d;
}
#endif

// RAM cart (400000 - 7fffff, optional)
static u32 PicoReadM68k8_ramc(u32 a)
{
  u32 d = 0;

  if (Pico.romsize == 0 && (PicoIn.opt & POPT_EN_MCD_RAMCART)) {
    if ((a & 0xf00001) == 0x400001) {
      if (Pico.sv.data != NULL)
        d = 3; // 64k cart
      return d;
    }

    if ((a & 0xf00001) == 0x600001) {
      if (Pico.sv.data != NULL)
        d = Pico.sv.data[((a >> 1) & 0xffff) + 0x2000];
      return d;
    }

    if ((a & 0xf00001) == 0x700001)
      return Pico_mcd->m.bcram_reg;
  }

  elprintf(EL_UIO, "m68k unmapped r8  [%06x] @%06x", a, SekPc);
  return d;
}

static u32 PicoReadM68k16_ramc(u32 a)
{
  elprintf(EL_ANOMALY, "ramcart r16: [%06x] @%06x", a, SekPc);
  return PicoReadM68k8_ramc(a + 1);
}

static void PicoWriteM68k8_ramc(u32 a, u32 d)
{
  if (Pico.romsize == 0 && (PicoIn.opt & POPT_EN_MCD_RAMCART)) {
    if ((a & 0xf00001) == 0x600001) {
      if (Pico.sv.data != NULL && (Pico_mcd->m.bcram_reg & 1)) {
        Pico.sv.data[((a >> 1) & 0xffff) + 0x2000] = d;
        Pico.sv.changed = 1;
      }
      return;
    }

    if ((a & 0xf00001) == 0x700001) {
      Pico_mcd->m.bcram_reg = d;
      return;
    }
  }

  elprintf(EL_UIO, "m68k unmapped w8  [%06x]   %02x @%06x",
    a, d & 0xff, SekPc);
}

static void PicoWriteM68k16_ramc(u32 a, u32 d)
{
  elprintf(EL_ANOMALY, "ramcart w16: [%06x] %04x @%06x",
    a, d, SekPcS68k);
  PicoWriteM68k8_ramc(a + 1, d);
}

// IO/control/cd registers (a10000 - ...)
#ifndef _ASM_CD_MEMORY_C
u32 PicoRead8_mcd_io(u32 a)
{
  u32 d;
  if ((a & 0xff00) == 0x2000) { // a12000 - a120ff
    d = m68k_reg_read16(a); // TODO: m68k_reg_read8
    if (!(a & 1))
      d >>= 8;
    d &= 0xff;
    elprintf(EL_CDREGS, "m68k_regs r8:  [%02x]   %02x @%06x",
      a & 0x3f, d, SekPc);
    return d;
  }

  // fallback to default MD handler
  return PicoRead8_io(a);
}

u32 PicoRead16_mcd_io(u32 a)
{
  u32 d;
  if ((a & 0xff00) == 0x2000) {
    d = m68k_reg_read16(a);
    elprintf(EL_CDREGS, "m68k_regs r16: [%02x] %04x @%06x",
      a & 0x3f, d, SekPc);
    return d;
  }

  return PicoRead16_io(a);
}

void PicoWrite8_mcd_io(u32 a, u32 d)
{
  if ((a & 0xff00) == 0x2000) { // a12000 - a120ff
    elprintf(EL_CDREGS, "m68k_regs w8:  [%02x]   %02x @%06x",
      a & 0x3f, d, SekPc);
    m68k_reg_write8(a, d);
    return;
  }

  if (carthw_ssf2_active)
    carthw_ssf2_write8(a, d); // for MSU/MD+
  else
    PicoWrite8_io(a, d);
}

void PicoWrite16_mcd_io(u32 a, u32 d)
{
  if ((a & 0xff00) == 0x2000) { // a12000 - a120ff
    elprintf(EL_CDREGS, "m68k_regs w16: [%02x] %04x @%06x",
      a & 0x3f, d, SekPc);

    m68k_reg_write8(a, d >> 8);
    if ((a & 0x3e) != 0x0e) // special case
      m68k_reg_write8(a + 1, d & 0xff);
    return;
  }

  if (carthw_ssf2_active)
    carthw_ssf2_write16(a, d); // for MSU/MD+
  else
    PicoWrite16_io(a, d);
}
#endif

// -----------------------------------------------------------------
//                           Sub 68k
// -----------------------------------------------------------------

static u32 s68k_unmapped_read8(u32 a)
{
  elprintf(EL_UIO, "s68k unmapped r8  [%06x] @%06x", a, SekPc);
  return 0;
}

static u32 s68k_unmapped_read16(u32 a)
{
  elprintf(EL_UIO, "s68k unmapped r16 [%06x] @%06x", a, SekPc);
  return 0;
}

static void s68k_unmapped_write8(u32 a, u32 d)
{
  elprintf(EL_UIO, "s68k unmapped w8  [%06x]   %02x @%06x",
    a, d & 0xff, SekPc);
}

static void s68k_unmapped_write16(u32 a, u32 d)
{
  elprintf(EL_UIO, "s68k unmapped w16 [%06x] %04x @%06x",
    a, d & 0xffff, SekPc);
}

// PRG RAM protected range (000000 - 01fdff)?
// XXX verify: ff00 or 1fe00 max?
static void PicoWriteS68k8_prgwp(u32 a, u32 d)
{
  if (a >= (Pico_mcd->s68k_regs[2] << 9))
    Pico_mcd->prg_ram[MEM_BE2(a)] = d;
}

static void PicoWriteS68k16_prgwp(u32 a, u32 d)
{
  if (a >= (Pico_mcd->s68k_regs[2] << 9))
    *(u16 *)(Pico_mcd->prg_ram + a) = d;
}

#ifndef _ASM_CD_MEMORY_C

// decode (080000 - 0bffff, in 1M mode)
static u32 PicoReadS68k8_dec0(u32 a)
{
  u32 d = Pico_mcd->word_ram1M[0][MEM_BE2(a >> 1) & 0x1ffff];
  if (a & 1)
    d &= 0x0f;
  else
    d >>= 4;
  return d;
}

static u32 PicoReadS68k8_dec1(u32 a)
{
  u32 d = Pico_mcd->word_ram1M[1][MEM_BE2(a >> 1) & 0x1ffff];
  if (a & 1)
    d &= 0x0f;
  else
    d >>= 4;
  return d;
}

static u32 PicoReadS68k16_dec0(u32 a)
{
  u32 d = Pico_mcd->word_ram1M[0][MEM_BE2(a >> 1) & 0x1ffff];
  d |= d << 4;
  d &= ~0xf0;
  return d;
}

static u32 PicoReadS68k16_dec1(u32 a)
{
  u32 d = Pico_mcd->word_ram1M[1][MEM_BE2(a >> 1) & 0x1ffff];
  d |= d << 4;
  d &= ~0xf0;
  return d;
}

/* check: jaguar xj 220 (draws entire world using decode) */
#define mk_decode_w8(bank)                                        \
static void PicoWriteS68k8_dec_m0b##bank(u32 a, u32 d)            \
{                                                                 \
  u8 *pd = &Pico_mcd->word_ram1M[bank][MEM_BE2(a >> 1) & 0x1ffff];\
                                                                  \
  if (!(a & 1))                                                   \
    *pd = (*pd & 0x0f) | (d << 4);                                \
  else                                                            \
    *pd = (*pd & 0xf0) | (d & 0x0f);                              \
}                                                                 \
                                                                  \
static void PicoWriteS68k8_dec_m1b##bank(u32 a, u32 d)            \
{                                                                 \
  u8 *pd = &Pico_mcd->word_ram1M[bank][MEM_BE2(a >> 1) & 0x1ffff];\
  u8 mask = (a & 1) ? 0x0f : 0xf0;                                \
                                                                  \
  if (!(*pd & mask) && (d & 0x0f)) /* underwrite */               \
    PicoWriteS68k8_dec_m0b##bank(a, d);                           \
}                                                                 \
                                                                  \
static void PicoWriteS68k8_dec_m2b##bank(u32 a, u32 d) /* ...and m3? */ \
{                                                                 \
  if (d & 0x0f) /* overwrite */                                   \
    PicoWriteS68k8_dec_m0b##bank(a, d);                           \
}

mk_decode_w8(0)
mk_decode_w8(1)

#define mk_decode_w16(bank)                                       \
static void PicoWriteS68k16_dec_m0b##bank(u32 a, u32 d)           \
{                                                                 \
  u8 *pd = &Pico_mcd->word_ram1M[bank][MEM_BE2(a >> 1) & 0x1ffff];\
                                                                  \
  d &= 0x0f0f;                                                    \
  *pd = d | (d >> 4);                                             \
}                                                                 \
                                                                  \
static void PicoWriteS68k16_dec_m1b##bank(u32 a, u32 d)           \
{                                                                 \
  u8 *pd = &Pico_mcd->word_ram1M[bank][MEM_BE2(a >> 1) & 0x1ffff];\
                                                                  \
  d &= 0x0f0f; /* underwrite */                                   \
  if (!(*pd & 0xf0)) *pd |= d >> 4;                               \
  if (!(*pd & 0x0f)) *pd |= d;                                    \
}                                                                 \
                                                                  \
static void PicoWriteS68k16_dec_m2b##bank(u32 a, u32 d)           \
{                                                                 \
  u8 *pd = &Pico_mcd->word_ram1M[bank][MEM_BE2(a >> 1) & 0x1ffff];\
                                                                  \
  d &= 0x0f0f; /* overwrite */                                    \
  d |= d >> 4;                                                    \
                                                                  \
  if (!(d & 0xf0)) d |= *pd & 0xf0;                               \
  if (!(d & 0x0f)) d |= *pd & 0x0f;                               \
  *pd = d;                                                        \
}

mk_decode_w16(0)
mk_decode_w16(1)

#endif

// backup RAM (fe0000 - feffff)
static u32 PicoReadS68k8_bram(u32 a)
{
  return Pico_mcd->bram[(a>>1)&0x1fff];
}

static u32 PicoReadS68k16_bram(u32 a)
{
  u32 d;
  elprintf(EL_ANOMALY, "FIXME: s68k_bram r16: [%06x] @%06x", a, SekPcS68k);
  a = (a >> 1) & 0x1fff;
  d = Pico_mcd->bram[a];
  return d;
}

static void PicoWriteS68k8_bram(u32 a, u32 d)
{
  if (a & 1) {
    Pico_mcd->bram[(a >> 1) & 0x1fff] = d;
    Pico.sv.changed = 1;
  }
}

static void PicoWriteS68k16_bram(u32 a, u32 d)
{
  elprintf(EL_ANOMALY, "s68k_bram w16: [%06x] %04x @%06x", a, d, SekPcS68k);
  a = (a >> 1) & 0x1fff;
  Pico_mcd->bram[a++] = d;
  Pico.sv.changed = 1;
}

#ifndef _ASM_CD_MEMORY_C

// PCM and registers (ff0000 - ffffff)
static u32 PicoReadS68k8_pr(u32 a)
{
  u32 d = 0;

  // regs
  if ((a & 0xfe00) == 0x8000) {
    a &= 0x1ff;
    if (a >= 0x0e && a < 0x30) {
      d = Pico_mcd->s68k_regs[a];
      d = s68k_poll_detect(a & ~1, d);
      goto regs_done;
    }
    d = s68k_reg_read16(a & ~1);
    if (!(a & 1))
      d >>= 8;

regs_done:
    d &= 0xff;
    elprintf(EL_CDREGS, "s68k_regs r8: [%02x] %02x @%06x",
      a, d, SekPcS68k);
    return d;
  }

  // PCM
  // XXX: verify: probably odd addrs only?
  if ((a & 0x8000) == 0x0000) {
    a &= 0x7fff;
    if (a >= 0x2000)
      d = Pico_mcd->pcm_ram_b[Pico_mcd->pcm.bank][(a >> 1) & 0xfff];
    else if (a >= 0x20)
      d = pcd_pcm_read(a >> 1);

    return d;
  }

  return s68k_unmapped_read8(a);
}

static u32 PicoReadS68k16_pr(u32 a)
{
  u32 d = 0;

  // regs
  if ((a & 0xfe00) == 0x8000) {
    a &= 0x1fe;
    d = s68k_reg_read16(a);

    elprintf(EL_CDREGS, "s68k_regs r16: [%02x] %04x @%06x",
      a, d, SekPcS68k);
    return d;
  }

  // PCM
  if ((a & 0x8000) == 0x0000) {
    a &= 0x7fff;
    if (a >= 0x2000)
      d = Pico_mcd->pcm_ram_b[Pico_mcd->pcm.bank][(a >> 1) & 0xfff];
    else if (a >= 0x20)
      d = pcd_pcm_read(a >> 1);

    return d;
  }

  return s68k_unmapped_read16(a);
}

static void PicoWriteS68k8_pr(u32 a, u32 d)
{
  // regs
  if ((a & 0xfe00) == 0x8000) {
    a &= 0x1ff;
    elprintf(EL_CDREGS, "s68k_regs w8: [%02x] %02x @%06x", a, d, SekPcS68k);
    if (0x59 <= a && a < 0x68) // word regs
      s68k_reg_write16(a & ~1, (d << 8) | d);
    else
      s68k_reg_write8(a, d);
    return;
  }

  // PCM
  if ((a & 0x8000) == 0x0000) {
    a &= 0x7fff;
    if (a >= 0x2000)
      Pico_mcd->pcm_ram_b[Pico_mcd->pcm.bank][(a>>1)&0xfff] = d;
    else if (a < 0x12)
      pcd_pcm_write(a>>1, d);
    return;
  }

  s68k_unmapped_write8(a, d);
}

static void PicoWriteS68k16_pr(u32 a, u32 d)
{
  // regs
  if ((a & 0xfe00) == 0x8000) {
    a &= 0x1fe;
    elprintf(EL_CDREGS, "s68k_regs w16: [%02x] %04x @%06x", a, d, SekPcS68k);
    s68k_reg_write16(a, d);
    return;
  }

  // PCM
  if ((a & 0x8000) == 0x0000) {
    a &= 0x7fff;
    if (a >= 0x2000)
      Pico_mcd->pcm_ram_b[Pico_mcd->pcm.bank][(a>>1)&0xfff] = d;
    else if (a < 0x12)
      pcd_pcm_write(a>>1, d & 0xff);
    return;
  }

  s68k_unmapped_write16(a, d);
}

#endif

static const void *m68k_cell_read8[]   = { PicoReadM68k8_cell0, PicoReadM68k8_cell1 };
static const void *m68k_cell_read16[]  = { PicoReadM68k16_cell0, PicoReadM68k16_cell1 };
static const void *m68k_cell_write8[]  = { PicoWriteM68k8_cell0, PicoWriteM68k8_cell1 };
static const void *m68k_cell_write16[] = { PicoWriteM68k16_cell0, PicoWriteM68k16_cell1 };

static const void *s68k_dec_read8[]   = { PicoReadS68k8_dec0, PicoReadS68k8_dec1 };
static const void *s68k_dec_read16[]  = { PicoReadS68k16_dec0, PicoReadS68k16_dec1 };

static const void *s68k_dec_write8[2][4] = {
  { PicoWriteS68k8_dec_m0b0, PicoWriteS68k8_dec_m1b0, PicoWriteS68k8_dec_m2b0, PicoWriteS68k8_dec_m2b0 },
  { PicoWriteS68k8_dec_m0b1, PicoWriteS68k8_dec_m1b1, PicoWriteS68k8_dec_m2b1, PicoWriteS68k8_dec_m2b1 },
};

static const void *s68k_dec_write16[2][4] = {
  { PicoWriteS68k16_dec_m0b0, PicoWriteS68k16_dec_m1b0, PicoWriteS68k16_dec_m2b0, PicoWriteS68k16_dec_m2b0 },
  { PicoWriteS68k16_dec_m0b1, PicoWriteS68k16_dec_m1b1, PicoWriteS68k16_dec_m2b1, PicoWriteS68k16_dec_m2b1 },
};

// -----------------------------------------------------------------

static void remap_prg_window(u32 r1, u32 r3)
{
  // PRG RAM, mapped to main CPU if sub is not running
  if ((r1 & 3) != 1) {
    void *bank = Pico_mcd->prg_ram_b[(r3 >> 6) & 3];
    cpu68k_map_all_ram(BASE+0x020000, BASE+0x03ffff, bank, 0);
  } else {
    m68k_map_unmap(BASE+0x020000, BASE+0x03ffff);
  }
}

// if sub CPU accesses Word-RAM while it is assigned to the main CPU,
// GA doesn't assert DTACK, which means the CPU is blocked until the Word_RAM
// is reassigned to it (e.g. Mega Race).
// since DTACK isn't on the expansion port, main cpu accesses are not blocked.
// XXX is data read/written if main is accessing Word_RAM while not owning it?
static u32 s68k_wordram_main_read8(u32 a)
{
  Pico_mcd->m.state_flags |= PCD_ST_S68K_SLEEP;
  SekEndRunS68k(0);
  return Pico_mcd->word_ram2M[MEM_BE2(a) & 0x3ffff];
}

static u32 s68k_wordram_main_read16(u32 a)
{
  Pico_mcd->m.state_flags |= PCD_ST_S68K_SLEEP;
  SekEndRunS68k(0);
  return ((u16 *)Pico_mcd->word_ram2M)[(a >> 1) & 0x1ffff];
}

static void s68k_wordram_main_write8(u32 a, u32 d)
{
  Pico_mcd->m.state_flags |= PCD_ST_S68K_SLEEP;
  SekEndRunS68k(0);
  Pico_mcd->word_ram2M[MEM_BE2(a) & 0x3ffff] = d;
}

static void s68k_wordram_main_write16(u32 a, u32 d)
{
  Pico_mcd->m.state_flags |= PCD_ST_S68K_SLEEP;
  SekEndRunS68k(0);
  ((u16 *)Pico_mcd->word_ram2M)[(a >> 1) & 0x1ffff] = d;
}

static void remap_word_ram(u32 r3)
{
  void *bank;

  // WORD RAM
  if (!(r3 & 4)) {
    // 2M mode.
    bank = Pico_mcd->word_ram2M;
    if (r3 & 1) {
      cpu68k_map_all_ram(BASE+0x200000, BASE+0x23ffff, bank, 0);
      cpu68k_map_all_funcs(0x80000, 0xbffff,
          s68k_wordram_main_read8, s68k_wordram_main_read16,
          s68k_wordram_main_write8, s68k_wordram_main_write16, 1);
    } else {
      Pico_mcd->m.state_flags &= ~PCD_ST_S68K_SLEEP;
      cpu68k_map_all_ram(0x080000, 0x0bffff, bank, 1);
      m68k_map_unmap(BASE+0x200000, BASE+0x23ffff);
    }
    // TODO: handle 0x0c0000
  }
  else {
    int b0 = r3 & 1;
    int m = (r3 & 0x18) >> 3;
    Pico_mcd->m.state_flags &= ~PCD_ST_S68K_SLEEP;
    bank = Pico_mcd->word_ram1M[b0];
    cpu68k_map_all_ram(BASE+0x200000, BASE+0x21ffff, bank, 0);
    bank = Pico_mcd->word_ram1M[b0 ^ 1];
    cpu68k_map_all_ram(0x0c0000, 0x0effff, bank, 1);
    // "cell arrange" on m68k
    cpu68k_map_all_funcs(BASE+0x220000, BASE+0x23ffff,
        m68k_cell_read8[b0], m68k_cell_read16[b0],
        m68k_cell_write8[b0], m68k_cell_write16[b0], 0);
    // "decode format" on s68k
    cpu68k_map_all_funcs(0x80000, 0xbffff,
        s68k_dec_read8[b0^1], s68k_dec_read16[b0^1],
        s68k_dec_write8[b0^1][m], s68k_dec_write16[b0^1][m], 1);
  }
}

void pcd_state_loaded_mem(void)
{
  u32 r3 = Pico_mcd->s68k_regs[3];

  /* after load events */
  if (r3 & 4) // 1M mode?
    wram_2M_to_1M(Pico_mcd->word_ram2M);
  remap_word_ram(r3);
  remap_prg_window(Pico_mcd->m.busreq, r3);
  Pico_mcd->m.dmna_ret_2m &= 3;

  // restore hint vector
  *(u16 *)(Pico_mcd->bios + 0x72) = Pico_mcd->m.hint_vector;
}

#ifdef EMU_M68K
static void m68k_mem_setup_cd(void);
#endif

PICO_INTERNAL void PicoMemSetupCD(void)
{
  if (Pico_mcd == NULL) {
    static u8 bios_id[4] = "SEGA";
    PicoCreateMCD(NULL, 0);
    // BIOS faking for MSU-MD, checks for "SEGA" at 0x400100 to detect CD drive
    memcpy(Pico_mcd->bios+0x100, bios_id, 4);
  }

  pcd_base_address = (Pico.romsize ? 0x400000 : 0x000000);

  // setup default main68k map
  PicoMemSetup();

  // main68k map (BIOS or MSU mapped by PicoMemSetup()):
  cpu68k_map_set(m68k_read8_map,   BASE, BASE+0x01ffff, Pico_mcd->bios, 0);
  cpu68k_map_set(m68k_read16_map,  BASE, BASE+0x01ffff, Pico_mcd->bios, 0);
  if (pcd_base_address != 0) { // cartridge (for MSU/MD+)
    // MD+ on MEGASD plus mirror
    u32 base = 0x040000-(1<<M68K_MEM_SHIFT);
    cpu68k_map_set(m68k_write8_map,  base, 0x03ffff, msd_write8, 1);
    cpu68k_map_set(m68k_write16_map, base, 0x03ffff, msd_write16, 1);
    cpu68k_map_set(m68k_write8_map,  base+0x080000, 0x0bffff, msd_write8, 1);
    cpu68k_map_set(m68k_write16_map, base+0x080000, 0x0bffff, msd_write16, 1);
    msd_reset();
  } else { // no cartridge
    // RAM cart
    cpu68k_map_set(m68k_read8_map,   0x400000, 0x7fffff, PicoReadM68k8_ramc, 1);
    cpu68k_map_set(m68k_read16_map,  0x400000, 0x7fffff, PicoReadM68k16_ramc, 1);
    cpu68k_map_set(m68k_write8_map,  0x400000, 0x7fffff, PicoWriteM68k8_ramc, 1);
    cpu68k_map_set(m68k_write16_map, 0x400000, 0x7fffff, PicoWriteM68k16_ramc, 1);
  }

  // registers/IO:
  cpu68k_map_set(m68k_read8_map,   0xa10000, 0xa1ffff, PicoRead8_mcd_io, 1);
  cpu68k_map_set(m68k_read16_map,  0xa10000, 0xa1ffff, PicoRead16_mcd_io, 1);
  cpu68k_map_set(m68k_write8_map,  0xa10000, 0xa1ffff, PicoWrite8_mcd_io, 1);
  cpu68k_map_set(m68k_write16_map, 0xa10000, 0xa1ffff, PicoWrite16_mcd_io, 1);

  // sub68k map
  cpu68k_map_set(s68k_read8_map,   0x000000, 0xffffff, s68k_unmapped_read8, 3);
  cpu68k_map_set(s68k_read16_map,  0x000000, 0xffffff, s68k_unmapped_read16, 3);
  cpu68k_map_set(s68k_write8_map,  0x000000, 0xffffff, s68k_unmapped_write8, 3);
  cpu68k_map_set(s68k_write16_map, 0x000000, 0xffffff, s68k_unmapped_write16, 3);

  // PRG RAM
  cpu68k_map_set(s68k_read8_map,   0x000000, 0x07ffff, Pico_mcd->prg_ram, 2);
  cpu68k_map_set(s68k_read16_map,  0x000000, 0x07ffff, Pico_mcd->prg_ram, 2);
  cpu68k_map_set(s68k_write8_map,  0x000000, 0x07ffff, Pico_mcd->prg_ram, 2);
  cpu68k_map_set(s68k_write16_map, 0x000000, 0x07ffff, Pico_mcd->prg_ram, 2);
  cpu68k_map_set(s68k_write8_map,  0x000000, 0x01ffff, PicoWriteS68k8_prgwp, 3);
  cpu68k_map_set(s68k_write16_map, 0x000000, 0x01ffff, PicoWriteS68k16_prgwp, 3);

  // BRAM
  cpu68k_map_set(s68k_read8_map,   0xfe0000, 0xfeffff, PicoReadS68k8_bram, 3);
  cpu68k_map_set(s68k_read16_map,  0xfe0000, 0xfeffff, PicoReadS68k16_bram, 3);
  cpu68k_map_set(s68k_write8_map,  0xfe0000, 0xfeffff, PicoWriteS68k8_bram, 3);
  cpu68k_map_set(s68k_write16_map, 0xfe0000, 0xfeffff, PicoWriteS68k16_bram, 3);

  // PCM, regs
  cpu68k_map_set(s68k_read8_map,   0xff0000, 0xffffff, PicoReadS68k8_pr, 3);
  cpu68k_map_set(s68k_read16_map,  0xff0000, 0xffffff, PicoReadS68k16_pr, 3);
  cpu68k_map_set(s68k_write8_map,  0xff0000, 0xffffff, PicoWriteS68k8_pr, 3);
  cpu68k_map_set(s68k_write16_map, 0xff0000, 0xffffff, PicoWriteS68k16_pr, 3);

  // RAMs
  remap_prg_window(2,1);
  remap_word_ram(1);

#ifdef EMU_C68K
  // s68k
  PicoCpuCS68k.read8  = (void *)s68k_read8_map;
  PicoCpuCS68k.read16 = (void *)s68k_read16_map;
  PicoCpuCS68k.read32 = (void *)s68k_read16_map;
  PicoCpuCS68k.write8  = (void *)s68k_write8_map;
  PicoCpuCS68k.write16 = (void *)s68k_write16_map;
  PicoCpuCS68k.write32 = (void *)s68k_write16_map;
  PicoCpuCS68k.checkpc = NULL; /* unused */
  PicoCpuCS68k.fetch8  = NULL;
  PicoCpuCS68k.fetch16 = NULL;
  PicoCpuCS68k.fetch32 = NULL;
#endif
#ifdef EMU_F68K
  // s68k
  PicoCpuFS68k.read_byte  = (void *)s68k_read8;
  PicoCpuFS68k.read_word  = (void *)s68k_read16;
  PicoCpuFS68k.read_long  = (void *)s68k_read32;
  PicoCpuFS68k.write_byte = (void *)s68k_write8;
  PicoCpuFS68k.write_word = (void *)s68k_write16;
  PicoCpuFS68k.write_long = (void *)s68k_write32;
#endif
#ifdef EMU_M68K
  m68k_mem_setup_cd();
#endif
}


#ifdef EMU_M68K
u32  m68k_read8(u32 a);
u32  m68k_read16(u32 a);
u32  m68k_read32(u32 a);
void m68k_write8(u32 a, u8 d);
void m68k_write16(u32 a, u16 d);
void m68k_write32(u32 a, u32 d);

static unsigned int PicoReadCD8w (unsigned int a) {
	return m68ki_cpu_p == &PicoCpuMS68k ? s68k_read8(a) : m68k_read8(a);
}
static unsigned int PicoReadCD16w(unsigned int a) {
	return m68ki_cpu_p == &PicoCpuMS68k ? s68k_read16(a) : m68k_read16(a);
}
static unsigned int PicoReadCD32w(unsigned int a) {
	return m68ki_cpu_p == &PicoCpuMS68k ? s68k_read32(a) : m68k_read32(a);
}
static void PicoWriteCD8w (unsigned int a, unsigned char d) {
	if (m68ki_cpu_p == &PicoCpuMS68k) s68k_write8(a, d); else m68k_write8(a, d);
}
static void PicoWriteCD16w(unsigned int a, unsigned short d) {
	if (m68ki_cpu_p == &PicoCpuMS68k) s68k_write16(a, d); else m68k_write16(a, d);
}
static void PicoWriteCD32w(unsigned int a, unsigned int d) {
	if (m68ki_cpu_p == &PicoCpuMS68k) s68k_write32(a, d); else m68k_write32(a, d);
}

extern unsigned int (*pm68k_read_memory_8) (unsigned int address);
extern unsigned int (*pm68k_read_memory_16)(unsigned int address);
extern unsigned int (*pm68k_read_memory_32)(unsigned int address);
extern void (*pm68k_write_memory_8) (unsigned int address, unsigned char  value);
extern void (*pm68k_write_memory_16)(unsigned int address, unsigned short value);
extern void (*pm68k_write_memory_32)(unsigned int address, unsigned int   value);

static void m68k_mem_setup_cd(void)
{
  pm68k_read_memory_8  = PicoReadCD8w;
  pm68k_read_memory_16 = PicoReadCD16w;
  pm68k_read_memory_32 = PicoReadCD32w;
  pm68k_write_memory_8  = PicoWriteCD8w;
  pm68k_write_memory_16 = PicoWriteCD16w;
  pm68k_write_memory_32 = PicoWriteCD32w;
}
#endif // EMU_M68K

// vim:shiftwidth=2:ts=2:expandtab
