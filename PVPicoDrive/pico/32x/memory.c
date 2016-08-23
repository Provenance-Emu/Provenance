/*
 * PicoDrive
 * (C) notaz, 2009,2010,2013
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 *
 * Register map:
 * a15100 F....... R.....EA  F.....AC N...VHMP 4000 // Fm Ren nrEs Aden Cart heN V H cMd Pwm
 * a15102 ........ ......SM  ?                 4002 // intS intM
 * a15104 ........ ......10  ........ hhhhhhhh 4004 // bk1 bk0 Hint
 * a15106 ........ F....SDR  UE...... .....SDR 4006 // Full 68S Dma Rv fUll[fb] Empt[fb]
 * a15108           (32bit DREQ src)           4008
 * a1510c           (32bit DREQ dst)           400c
 * a15110          llllllll llllll00           4010 // DREQ Len
 * a15112           (16bit FIFO reg)           4012
 * a15114 0                  (16bit VRES clr)  4014
 * a15116 0                  (16bit Vint clr)  4016
 * a15118 0                  (16bit Hint clr)  4018
 * a1511a .......? .......C  (16bit CMD clr)   401a // TV Cm
 * a1511c 0                  (16bit PWM clr)   401c
 * a1511e 0                  ?                 401e
 * a15120            (16 bytes comm)           2020
 * a15130                 (PWM)                2030
 *
 * SH2 addr lines:
 * iii. .cc. ..xx *   // Internal, Cs, x
 *
 * sh2 map, wait/bus cycles (from docs):
 *                             r    w
 * rom      0000000-0003fff    1    -
 * sys reg  0004000-00040ff    1    1
 * vdp reg  0004100-00041ff    5    5
 * vdp pal  0004200-00043ff    5    5
 * cart     2000000-23fffff     6-15
 * dram/fb  4000000-401ffff 5-12  1-3
 * fb ovr   4020000-403ffff
 * sdram    6000000-603ffff   12    2  (cycles)
 * d.a.    c0000000-?
 */
#include "../pico_int.h"
#include "../memory.h"
#include "../../cpu/sh2/compiler.h"

static const char str_mars[] = "MARS";

void *p32x_bios_g, *p32x_bios_m, *p32x_bios_s;
struct Pico32xMem *Pico32xMem;

static void bank_switch(int b);

// addressing byte in 16bit reg
#define REG8IN16(ptr, offs) ((u8 *)ptr)[(offs) ^ 1]

// poll detection
#define POLL_THRESHOLD 3

static struct {
  u32 addr, cycles;
  int cnt;
} m68k_poll;

static int m68k_poll_detect(u32 a, u32 cycles, u32 flags)
{
  int ret = 0;

  if (a - 2 <= m68k_poll.addr && m68k_poll.addr <= a + 2
    && cycles - m68k_poll.cycles <= 64 && !SekNotPolling)
  {
    if (m68k_poll.cnt++ > POLL_THRESHOLD) {
      if (!(Pico32x.emu_flags & flags)) {
        elprintf(EL_32X, "m68k poll addr %08x, cyc %u",
          a, cycles - m68k_poll.cycles);
        ret = 1;
      }
      Pico32x.emu_flags |= flags;
    }
  }
  else {
    m68k_poll.cnt = 0;
    m68k_poll.addr = a;
    SekNotPolling = 0;
  }
  m68k_poll.cycles = cycles;

  return ret;
}

void p32x_m68k_poll_event(u32 flags)
{
  if (Pico32x.emu_flags & flags) {
    elprintf(EL_32X, "m68k poll %02x -> %02x", Pico32x.emu_flags,
      Pico32x.emu_flags & ~flags);
    Pico32x.emu_flags &= ~flags;
    SekSetStop(0);
  }
  m68k_poll.addr = m68k_poll.cnt = 0;
}

static void sh2_poll_detect(SH2 *sh2, u32 a, u32 flags, int maxcnt)
{
  int cycles_left = sh2_cycles_left(sh2);

  if (a == sh2->poll_addr && sh2->poll_cycles - cycles_left <= 10) {
    if (sh2->poll_cnt++ > maxcnt) {
      if (!(sh2->state & flags))
        elprintf_sh2(sh2, EL_32X, "state: %02x->%02x",
          sh2->state, sh2->state | flags);

      sh2->state |= flags;
      sh2_end_run(sh2, 1);
      pevt_log_sh2(sh2, EVT_POLL_START);
      return;
    }
  }
  else
    sh2->poll_cnt = 0;
  sh2->poll_addr = a;
  sh2->poll_cycles = cycles_left;
}

void p32x_sh2_poll_event(SH2 *sh2, u32 flags, u32 m68k_cycles)
{
  if (sh2->state & flags) {
    elprintf_sh2(sh2, EL_32X, "state: %02x->%02x", sh2->state,
      sh2->state & ~flags);

    if (sh2->m68krcycles_done < m68k_cycles)
      sh2->m68krcycles_done = m68k_cycles;

    pevt_log_sh2_o(sh2, EVT_POLL_END);
  }

  sh2->state &= ~flags;
  sh2->poll_addr = sh2->poll_cycles = sh2->poll_cnt = 0;
}

static void sh2s_sync_on_read(SH2 *sh2)
{
  int cycles;
  if (sh2->poll_cnt != 0)
    return;

  cycles = sh2_cycles_done(sh2);
  if (cycles > 600)
    p32x_sync_other_sh2(sh2, sh2->m68krcycles_done + cycles / 3);
}

// SH2 faking
//#define FAKE_SH2
#ifdef FAKE_SH2
static int p32x_csum_faked;
static const u16 comm_fakevals[] = {
  0x4d5f, 0x4f4b, // M_OK
  0x535f, 0x4f4b, // S_OK
  0x4D41, 0x5346, // MASF - Brutal Unleashed
  0x5331, 0x4d31, // Darxide
  0x5332, 0x4d32,
  0x5333, 0x4d33,
  0x0000, 0x0000, // eq for doom
  0x0002, // Mortal Kombat
//  0, // pad
};

static u32 sh2_comm_faker(u32 a)
{
  static int f = 0;
  if (a == 0x28 && !p32x_csum_faked) {
    p32x_csum_faked = 1;
    return *(unsigned short *)(Pico.rom + 0x18e);
  }
  if (f >= sizeof(comm_fakevals) / sizeof(comm_fakevals[0]))
    f = 0;
  return comm_fakevals[f++];
}
#endif

// ------------------------------------------------------------------
// 68k regs

static u32 p32x_reg_read16(u32 a)
{
  a &= 0x3e;

#if 0
  if ((a & 0x30) == 0x20)
    return sh2_comm_faker(a);
#else
  if ((a & 0x30) == 0x20) {
    unsigned int cycles = SekCyclesDone();
    int comreg = 1 << (a & 0x0f) / 2;

    if (cycles - msh2.m68krcycles_done > 244
        || (Pico32x.comm_dirty_68k & comreg))
      p32x_sync_sh2s(cycles);

    if (Pico32x.comm_dirty_sh2 & comreg)
      Pico32x.comm_dirty_sh2 &= ~comreg;
    else if (m68k_poll_detect(a, cycles, P32XF_68KCPOLL)) {
      SekSetStop(1);
      SekEndRun(16);
    }
    goto out;
  }
#endif

  if (a == 2) { // INTM, INTS
    unsigned int cycles = SekCyclesDone();
    if (cycles - msh2.m68krcycles_done > 64)
      p32x_sync_sh2s(cycles);
    goto out;
  }

  if ((a & 0x30) == 0x30)
    return p32x_pwm_read16(a, NULL, SekCyclesDone());

out:
  return Pico32x.regs[a / 2];
}

static void dreq0_write(u16 *r, u32 d)
{
  if (!(r[6 / 2] & P32XS_68S)) {
    elprintf(EL_32X|EL_ANOMALY, "DREQ FIFO w16 without 68S?");
    return; // ignored - tested
  }
  if (Pico32x.dmac0_fifo_ptr < DMAC_FIFO_LEN) {
    Pico32x.dmac_fifo[Pico32x.dmac0_fifo_ptr++] = d;
    if (Pico32x.dmac0_fifo_ptr == DMAC_FIFO_LEN)
      r[6 / 2] |= P32XS_FULL;
    // tested: len register decrements and 68S clears
    // even if SH2s/DMAC aren't active..
    r[0x10 / 2]--;
    if (r[0x10 / 2] == 0)
      r[6 / 2] &= ~P32XS_68S;

    if ((Pico32x.dmac0_fifo_ptr & 3) == 0) {
      p32x_sync_sh2s(SekCyclesDone());
      p32x_dreq0_trigger();
    }
  }
  else
    elprintf(EL_32X|EL_ANOMALY, "DREQ FIFO overflow!");
}

// writable bits tested
static void p32x_reg_write8(u32 a, u32 d)
{
  u16 *r = Pico32x.regs;
  a &= 0x3f;

  // for things like bset on comm port
  m68k_poll.cnt = 0;

  switch (a) {
    case 0x00: // adapter ctl: FM writable
      REG8IN16(r, 0x00) = d & 0x80;
      return;
    case 0x01: // adapter ctl: RES and ADEN writable
      if ((d ^ r[0]) & d & P32XS_nRES)
        p32x_reset_sh2s();
      REG8IN16(r, 0x01) &= ~(P32XS_nRES|P32XS_ADEN);
      REG8IN16(r, 0x01) |= d & (P32XS_nRES|P32XS_ADEN);
      return;
    case 0x02: // ignored, always 0
      return;
    case 0x03: // irq ctl
      if ((d ^ r[0x02 / 2]) & 3) {
        int cycles = SekCyclesDone();
        p32x_sync_sh2s(cycles);
        r[0x02 / 2] = d & 3;
        p32x_update_cmd_irq(NULL, cycles);
      }
      return;
    case 0x04: // ignored, always 0
      return;
    case 0x05: // bank
      d &= 3;
      if (r[0x04 / 2] != d) {
        r[0x04 / 2] = d;
        bank_switch(d);
      }
      return;
    case 0x06: // ignored, always 0
      return;
    case 0x07: // DREQ ctl
      REG8IN16(r, 0x07) &= ~(P32XS_68S|P32XS_DMA|P32XS_RV);
      if (!(d & P32XS_68S)) {
        Pico32x.dmac0_fifo_ptr = 0;
        REG8IN16(r, 0x07) &= ~P32XS_FULL;
      }
      REG8IN16(r, 0x07) |= d & (P32XS_68S|P32XS_DMA|P32XS_RV);
      return;
    case 0x08: // ignored, always 0
      return;
    case 0x09: // DREQ src
      REG8IN16(r, 0x09) = d;
      return;
    case 0x0a:
      REG8IN16(r, 0x0a) = d;
      return;
    case 0x0b:
      REG8IN16(r, 0x0b) = d & 0xfe;
      return;
    case 0x0c: // ignored, always 0
      return;
    case 0x0d: // DREQ dest
    case 0x0e:
    case 0x0f:
    case 0x10: // DREQ len
      REG8IN16(r, a) = d;
      return;
    case 0x11:
      REG8IN16(r, a) = d & 0xfc;
      return;
    // DREQ FIFO - writes to odd addr go to fifo
    // do writes to even work? Reads return 0
    case 0x12:
      REG8IN16(r, a) = d;
      return;
    case 0x13:
      d = (REG8IN16(r, 0x12) << 8) | (d & 0xff);
      REG8IN16(r, 0x12) = 0;
      dreq0_write(r, d);
      return;
    case 0x14: // ignored, always 0
    case 0x15:
    case 0x16:
    case 0x17:
    case 0x18:
    case 0x19:
      return;
    case 0x1a: // what's this?
      elprintf(EL_32X|EL_ANOMALY, "mystery w8 %02x %02x", a, d);
      REG8IN16(r, a) = d & 0x01;
      return;
    case 0x1b: // TV
      REG8IN16(r, a) = d & 0x01;
      return;
    case 0x1c: // ignored, always 0
    case 0x1d:
    case 0x1e:
    case 0x1f:
    case 0x30:
      return;
    case 0x31: // PWM control
      REG8IN16(r, a) &= ~0x0f;
      REG8IN16(r, a) |= d & 0x0f;
      d = r[0x30 / 2];
      goto pwm_write;
    case 0x32: // PWM cycle
      REG8IN16(r, a) = d & 0x0f;
      d = r[0x32 / 2];
      goto pwm_write;
    case 0x33:
      REG8IN16(r, a) = d;
      d = r[0x32 / 2];
      goto pwm_write;
    // PWM pulse regs.. Only writes to odd address send a value
    // to FIFO; reads are 0 (except status bits)
    case 0x34:
    case 0x36:
    case 0x38:
      REG8IN16(r, a) = d;
      return;
    case 0x35:
    case 0x37:
    case 0x39:
      d = (REG8IN16(r, a ^ 1) << 8) | (d & 0xff);
      REG8IN16(r, a ^ 1) = 0;
      goto pwm_write;
    case 0x3a: // ignored, always 0
    case 0x3b:
    case 0x3c:
    case 0x3d:
    case 0x3e:
    case 0x3f:
      return;
    pwm_write:
      p32x_pwm_write16(a & ~1, d, NULL, SekCyclesDone());
      return;
  }

  if ((a & 0x30) == 0x20) {
    int cycles = SekCyclesDone();
    int comreg;
    
    if (REG8IN16(r, a) == d)
      return;

    comreg = 1 << (a & 0x0f) / 2;
    if (Pico32x.comm_dirty_68k & comreg)
      p32x_sync_sh2s(cycles);

    REG8IN16(r, a) = d;
    p32x_sh2_poll_event(&sh2s[0], SH2_STATE_CPOLL, cycles);
    p32x_sh2_poll_event(&sh2s[1], SH2_STATE_CPOLL, cycles);
    Pico32x.comm_dirty_68k |= comreg;

    if (cycles - (int)msh2.m68krcycles_done > 120)
      p32x_sync_sh2s(cycles);
    return;
  }
}

static void p32x_reg_write16(u32 a, u32 d)
{
  u16 *r = Pico32x.regs;
  a &= 0x3e;

  // for things like bset on comm port
  m68k_poll.cnt = 0;

  switch (a) {
    case 0x00: // adapter ctl
      if ((d ^ r[0]) & d & P32XS_nRES)
        p32x_reset_sh2s();
      r[0] &= ~(P32XS_FM|P32XS_nRES|P32XS_ADEN);
      r[0] |= d & (P32XS_FM|P32XS_nRES|P32XS_ADEN);
      return;
    case 0x08: // DREQ src
      r[a / 2] = d & 0xff;
      return;
    case 0x0a:
      r[a / 2] = d & ~1;
      return;
    case 0x0c: // DREQ dest
      r[a / 2] = d & 0xff;
      return;
    case 0x0e:
      r[a / 2] = d;
      return;
    case 0x10: // DREQ len
      r[a / 2] = d & ~3;
      return;
    case 0x12: // FIFO reg
      dreq0_write(r, d);
      return;
    case 0x1a: // TV + mystery bit
      r[a / 2] = d & 0x0101;
      return;
    case 0x30: // PWM control
      d = (r[a / 2] & ~0x0f) | (d & 0x0f);
      r[a / 2] = d;
      p32x_pwm_write16(a, d, NULL, SekCyclesDone());
      return;
  }

  // comm port
  if ((a & 0x30) == 0x20) {
    int cycles = SekCyclesDone();
    int comreg;
    
    if (r[a / 2] == d)
      return;

    comreg = 1 << (a & 0x0f) / 2;
    if (Pico32x.comm_dirty_68k & comreg)
      p32x_sync_sh2s(cycles);

    r[a / 2] = d;
    p32x_sh2_poll_event(&sh2s[0], SH2_STATE_CPOLL, cycles);
    p32x_sh2_poll_event(&sh2s[1], SH2_STATE_CPOLL, cycles);
    Pico32x.comm_dirty_68k |= comreg;

    if (cycles - (int)msh2.m68krcycles_done > 120)
      p32x_sync_sh2s(cycles);
    return;
  }
  // PWM
  else if ((a & 0x30) == 0x30) {
    p32x_pwm_write16(a, d, NULL, SekCyclesDone());
    return;
  }

  p32x_reg_write8(a + 1, d);
}

// ------------------------------------------------------------------
// VDP regs
static u32 p32x_vdp_read16(u32 a)
{
  u32 d;
  a &= 0x0e;

  d = Pico32x.vdp_regs[a / 2];
  if (a == 0x0a) {
    // tested: FEN seems to be randomly pulsing on hcnt 0x80-0xf0,
    // most often at 0xb1-0xb5, even during vblank,
    // what's the deal with that?
    // we'll just fake it along with hblank for now
    Pico32x.vdp_fbcr_fake++;
    if (Pico32x.vdp_fbcr_fake & 4)
      d |= P32XV_HBLK;
    if ((Pico32x.vdp_fbcr_fake & 7) == 0)
      d |= P32XV_nFEN;
  }
  return d;
}

static void p32x_vdp_write8(u32 a, u32 d)
{
  u16 *r = Pico32x.vdp_regs;
  a &= 0x0f;

  // TODO: verify what's writeable
  switch (a) {
    case 0x01:
      // priority inversion is handled in palette
      if ((r[0] ^ d) & P32XV_PRI)
        Pico32x.dirty_pal = 1;
      r[0] = (r[0] & P32XV_nPAL) | (d & 0xff);
      break;
    case 0x03: // shift (for pp mode)
      r[2 / 2] = d & 1;
      break;
    case 0x05: // fill len
      r[4 / 2] = d & 0xff;
      break;
    case 0x0b:
      d &= 1;
      Pico32x.pending_fb = d;
      // if we are blanking and FS bit is changing
      if (((r[0x0a/2] & P32XV_VBLK) || (r[0] & P32XV_Mx) == 0) && ((r[0x0a/2] ^ d) & P32XV_FS)) {
        r[0x0a/2] ^= P32XV_FS;
        Pico32xSwapDRAM(d ^ 1);
        elprintf(EL_32X, "VDP FS: %d", r[0x0a/2] & P32XV_FS);
      }
      break;
  }
}

static void p32x_vdp_write16(u32 a, u32 d, SH2 *sh2)
{
  a &= 0x0e;
  if (a == 6) { // fill start
    Pico32x.vdp_regs[6 / 2] = d;
    return;
  }
  if (a == 8) { // fill data
    u16 *dram = Pico32xMem->dram[(Pico32x.vdp_regs[0x0a/2] & P32XV_FS) ^ 1];
    int len = Pico32x.vdp_regs[4 / 2] + 1;
    int len1 = len;
    a = Pico32x.vdp_regs[6 / 2];
    while (len1--) {
      dram[a] = d;
      a = (a & 0xff00) | ((a + 1) & 0xff);
    }
    Pico32x.vdp_regs[0x06 / 2] = a;
    Pico32x.vdp_regs[0x08 / 2] = d;
    if (sh2 != NULL && len > 4) {
      Pico32x.vdp_regs[0x0a / 2] |= P32XV_nFEN;
      // supposedly takes 3 bus/6 sh2 cycles? or 3 sh2 cycles?
      p32x_event_schedule_sh2(sh2, P32X_EVENT_FILLEND, 3 + len);
    }
    return;
  }

  p32x_vdp_write8(a | 1, d);
}

// ------------------------------------------------------------------
// SH2 regs

static u32 p32x_sh2reg_read16(u32 a, SH2 *sh2)
{
  u16 *r = Pico32x.regs;
  a &= 0x3e;

  switch (a) {
    case 0x00: // adapter/irq ctl
      return (r[0] & P32XS_FM) | Pico32x.sh2_regs[0]
        | Pico32x.sh2irq_mask[sh2->is_slave];
    case 0x04: // H count (often as comm too)
      sh2_poll_detect(sh2, a, SH2_STATE_CPOLL, 3);
      sh2s_sync_on_read(sh2);
      return Pico32x.sh2_regs[4 / 2];
    case 0x06:
      return (r[a / 2] & ~P32XS_FULL) | 0x4000;
    case 0x08: // DREQ src
    case 0x0a:
    case 0x0c: // DREQ dst
    case 0x0e:
    case 0x10: // DREQ len
      return r[a / 2];
    case 0x12: // DREQ FIFO - does this work on hw?
      if (Pico32x.dmac0_fifo_ptr > 0) {
        Pico32x.dmac0_fifo_ptr--;
        r[a / 2] = Pico32x.dmac_fifo[0];
        memmove(&Pico32x.dmac_fifo[0], &Pico32x.dmac_fifo[1],
          Pico32x.dmac0_fifo_ptr * 2);
      }
      return r[a / 2];
    case 0x14:
    case 0x16:
    case 0x18:
    case 0x1a:
    case 0x1c:
      return 0; // ?
  }

  // comm port
  if ((a & 0x30) == 0x20) {
    int comreg = 1 << (a & 0x0f) / 2;
    if (Pico32x.comm_dirty_68k & comreg)
      Pico32x.comm_dirty_68k &= ~comreg;
    else
      sh2_poll_detect(sh2, a, SH2_STATE_CPOLL, 3);
    sh2s_sync_on_read(sh2);
    return r[a / 2];
  }
  if ((a & 0x30) == 0x30)
    return p32x_pwm_read16(a, sh2, sh2_cycles_done_m68k(sh2));

  elprintf_sh2(sh2, EL_32X|EL_ANOMALY, 
    "unhandled sysreg r16 [%02x] @%08x", a, sh2_pc(sh2));
  return 0;
}

static void p32x_sh2reg_write8(u32 a, u32 d, SH2 *sh2)
{
  u16 *r = Pico32x.regs;
  u32 old;

  a &= 0x3f;
  sh2->poll_addr = 0;

  switch (a) {
    case 0x00: // FM
      r[0] &= ~P32XS_FM;
      r[0] |= (d << 8) & P32XS_FM;
      return;
    case 0x01: // HEN/irq masks
      old = Pico32x.sh2irq_mask[sh2->is_slave];
      if ((d ^ old) & 1)
        p32x_pwm_sync_to_sh2(sh2);

      Pico32x.sh2irq_mask[sh2->is_slave] = d & 0x0f;
      Pico32x.sh2_regs[0] &= ~0x80;
      Pico32x.sh2_regs[0] |= d & 0x80;

      if ((d ^ old) & 1)
        p32x_pwm_schedule_sh2(sh2);
      if ((old ^ d) & 2)
        p32x_update_cmd_irq(sh2, 0);
      if ((old ^ d) & 4)
        p32x_schedule_hint(sh2, 0); 
      return;
    case 0x04: // ignored?
      return;
    case 0x05: // H count
      d &= 0xff;
      if (Pico32x.sh2_regs[4 / 2] != d) {
        Pico32x.sh2_regs[4 / 2] = d;
        p32x_sh2_poll_event(sh2->other_sh2, SH2_STATE_CPOLL,
          sh2_cycles_done_m68k(sh2));
        sh2_end_run(sh2, 4);
      }
      return;
    case 0x30:
      REG8IN16(r, a) = d & 0x0f;
      d = r[0x30 / 2];
      goto pwm_write;
    case 0x31: // PWM control
      REG8IN16(r, a) = d & 0x8f;
      d = r[0x30 / 2];
      goto pwm_write;
    case 0x32: // PWM cycle
      REG8IN16(r, a) = d & 0x0f;
      d = r[0x32 / 2];
      goto pwm_write;
    case 0x33:
      REG8IN16(r, a) = d;
      d = r[0x32 / 2];
      goto pwm_write;
    // PWM pulse regs.. Only writes to odd address send a value
    // to FIFO; reads are 0 (except status bits)
    case 0x34:
    case 0x36:
    case 0x38:
      REG8IN16(r, a) = d;
      return;
    case 0x35:
    case 0x37:
    case 0x39:
      d = (REG8IN16(r, a ^ 1) << 8) | (d & 0xff);
      REG8IN16(r, a ^ 1) = 0;
      goto pwm_write;
    case 0x3a: // ignored, always 0?
    case 0x3b:
    case 0x3c:
    case 0x3d:
    case 0x3e:
    case 0x3f:
      return;
    pwm_write:
      p32x_pwm_write16(a & ~1, d, sh2, 0);
      return;
  }

  if ((a & 0x30) == 0x20) {
    int comreg;
    if (REG8IN16(r, a) == d)
      return;

    REG8IN16(r, a) = d;
    p32x_m68k_poll_event(P32XF_68KCPOLL);
    p32x_sh2_poll_event(sh2->other_sh2, SH2_STATE_CPOLL,
      sh2_cycles_done_m68k(sh2));
    comreg = 1 << (a & 0x0f) / 2;
    Pico32x.comm_dirty_sh2 |= comreg;
    return;
  }

  elprintf(EL_32X|EL_ANOMALY,
    "unhandled sysreg w8  [%02x] %02x @%08x", a, d, sh2_pc(sh2));
}

static void p32x_sh2reg_write16(u32 a, u32 d, SH2 *sh2)
{
  a &= 0x3e;

  sh2->poll_addr = 0;

  // comm
  if ((a & 0x30) == 0x20) {
    int comreg;
    if (Pico32x.regs[a / 2] == d)
      return;

    Pico32x.regs[a / 2] = d;
    p32x_m68k_poll_event(P32XF_68KCPOLL);
    p32x_sh2_poll_event(sh2->other_sh2, SH2_STATE_CPOLL,
      sh2_cycles_done_m68k(sh2));
    comreg = 1 << (a & 0x0f) / 2;
    Pico32x.comm_dirty_sh2 |= comreg;
    return;
  }
  // PWM
  else if ((a & 0x30) == 0x30) {
    p32x_pwm_write16(a, d, sh2, sh2_cycles_done_m68k(sh2));
    return;
  }

  switch (a) {
    case 0: // FM
      Pico32x.regs[0] &= ~P32XS_FM;
      Pico32x.regs[0] |= d & P32XS_FM;
      break;
    case 0x14:
      Pico32x.sh2irqs &= ~P32XI_VRES;
      goto irls;
    case 0x16:
      Pico32x.sh2irqi[sh2->is_slave] &= ~P32XI_VINT;
      goto irls;
    case 0x18:
      Pico32x.sh2irqi[sh2->is_slave] &= ~P32XI_HINT;
      goto irls;
    case 0x1a:
      Pico32x.regs[2 / 2] &= ~(1 << sh2->is_slave);
      p32x_update_cmd_irq(sh2, 0);
      return;
    case 0x1c:
      p32x_pwm_sync_to_sh2(sh2);
      Pico32x.sh2irqi[sh2->is_slave] &= ~P32XI_PWM;
      p32x_pwm_schedule_sh2(sh2);
      goto irls;
  }

  p32x_sh2reg_write8(a | 1, d, sh2);
  return;

irls:
  p32x_update_irls(sh2, 0);
}

// ------------------------------------------------------------------
// 32x 68k handlers

// after ADEN
static u32 PicoRead8_32x_on(u32 a)
{
  u32 d = 0;
  if ((a & 0xffc0) == 0x5100) { // a15100
    d = p32x_reg_read16(a);
    goto out_16to8;
  }

  if ((a & 0xfc00) != 0x5000) {
    if (PicoAHW & PAHW_MCD)
      return PicoRead8_mcd_io(a);
    else
      return PicoRead8_io(a);
  }

  if ((a & 0xfff0) == 0x5180) { // a15180
    d = p32x_vdp_read16(a);
    goto out_16to8;
  }

  if ((a & 0xfe00) == 0x5200) { // a15200
    d = Pico32xMem->pal[(a & 0x1ff) / 2];
    goto out_16to8;
  }

  if ((a & 0xfffc) == 0x30ec) { // a130ec
    d = str_mars[a & 3];
    goto out;
  }

  elprintf(EL_UIO, "m68k unmapped r8  [%06x] @%06x", a, SekPc);
  return d;

out_16to8:
  if (a & 1)
    d &= 0xff;
  else
    d >>= 8;

out:
  elprintf(EL_32X, "m68k 32x r8  [%06x]   %02x @%06x", a, d, SekPc);
  return d;
}

static u32 PicoRead16_32x_on(u32 a)
{
  u32 d = 0;
  if ((a & 0xffc0) == 0x5100) { // a15100
    d = p32x_reg_read16(a);
    goto out;
  }

  if ((a & 0xfc00) != 0x5000) {
    if (PicoAHW & PAHW_MCD)
      return PicoRead16_mcd_io(a);
    else
      return PicoRead16_io(a);
  }

  if ((a & 0xfff0) == 0x5180) { // a15180
    d = p32x_vdp_read16(a);
    goto out;
  }

  if ((a & 0xfe00) == 0x5200) { // a15200
    d = Pico32xMem->pal[(a & 0x1ff) / 2];
    goto out;
  }

  if ((a & 0xfffc) == 0x30ec) { // a130ec
    d = !(a & 2) ? ('M'<<8)|'A' : ('R'<<8)|'S';
    goto out;
  }

  elprintf(EL_UIO, "m68k unmapped r16 [%06x] @%06x", a, SekPc);
  return d;

out:
  elprintf(EL_32X, "m68k 32x r16 [%06x] %04x @%06x", a, d, SekPc);
  return d;
}

static void PicoWrite8_32x_on(u32 a, u32 d)
{
  if ((a & 0xfc00) == 0x5000)
    elprintf(EL_32X, "m68k 32x w8  [%06x]   %02x @%06x", a, d & 0xff, SekPc);

  if ((a & 0xffc0) == 0x5100) { // a15100
    p32x_reg_write8(a, d);
    return;
  }

  if ((a & 0xfc00) != 0x5000) {
    if (PicoAHW & PAHW_MCD)
      PicoWrite8_mcd_io(a, d);
    else
      PicoWrite8_io(a, d);
    if (a == 0xa130f1)
      bank_switch(Pico32x.regs[4 / 2]);
    return;
  }

  if (!(Pico32x.regs[0] & P32XS_FM)) {
    if ((a & 0xfff0) == 0x5180) { // a15180
      p32x_vdp_write8(a, d);
      return;
    }

    // TODO: verify
    if ((a & 0xfe00) == 0x5200) { // a15200
      elprintf(EL_32X|EL_ANOMALY, "m68k 32x PAL w8  [%06x]   %02x @%06x", a, d & 0xff, SekPc);
      ((u8 *)Pico32xMem->pal)[(a & 0x1ff) ^ 1] = d;
      Pico32x.dirty_pal = 1;
      return;
    }
  }

  elprintf(EL_UIO, "m68k unmapped w8  [%06x]   %02x @%06x", a, d & 0xff, SekPc);
}

static void PicoWrite16_32x_on(u32 a, u32 d)
{
  if ((a & 0xfc00) == 0x5000)
    elprintf(EL_32X, "m68k 32x w16 [%06x] %04x @%06x", a, d & 0xffff, SekPc);

  if ((a & 0xffc0) == 0x5100) { // a15100
    p32x_reg_write16(a, d);
    return;
  }

  if ((a & 0xfc00) != 0x5000) {
    if (PicoAHW & PAHW_MCD)
      PicoWrite16_mcd_io(a, d);
    else
      PicoWrite16_io(a, d);
    if (a == 0xa130f0)
      bank_switch(Pico32x.regs[4 / 2]);
    return;
  }

  if (!(Pico32x.regs[0] & P32XS_FM)) {
    if ((a & 0xfff0) == 0x5180) { // a15180
      p32x_vdp_write16(a, d, NULL); // FIXME?
      return;
    }

    if ((a & 0xfe00) == 0x5200) { // a15200
      Pico32xMem->pal[(a & 0x1ff) / 2] = d;
      Pico32x.dirty_pal = 1;
      return;
    }
  }

  elprintf(EL_UIO, "m68k unmapped w16 [%06x] %04x @%06x", a, d & 0xffff, SekPc);
}

// before ADEN
u32 PicoRead8_32x(u32 a)
{
  u32 d = 0;
  if ((a & 0xffc0) == 0x5100) { // a15100
    // regs are always readable
    d = ((u8 *)Pico32x.regs)[(a & 0x3f) ^ 1];
    goto out;
  }

  if ((a & 0xfffc) == 0x30ec) { // a130ec
    d = str_mars[a & 3];
    goto out;
  }

  elprintf(EL_UIO, "m68k unmapped r8  [%06x] @%06x", a, SekPc);
  return d;

out:
  elprintf(EL_32X, "m68k 32x r8  [%06x]   %02x @%06x", a, d, SekPc);
  return d;
}

u32 PicoRead16_32x(u32 a)
{
  u32 d = 0;
  if ((a & 0xffc0) == 0x5100) { // a15100
    d = Pico32x.regs[(a & 0x3f) / 2];
    goto out;
  }

  if ((a & 0xfffc) == 0x30ec) { // a130ec
    d = !(a & 2) ? ('M'<<8)|'A' : ('R'<<8)|'S';
    goto out;
  }

  elprintf(EL_UIO, "m68k unmapped r16 [%06x] @%06x", a, SekPc);
  return d;

out:
  elprintf(EL_32X, "m68k 32x r16 [%06x] %04x @%06x", a, d, SekPc);
  return d;
}

void PicoWrite8_32x(u32 a, u32 d)
{
  if ((a & 0xffc0) == 0x5100) { // a15100
    u16 *r = Pico32x.regs;

    elprintf(EL_32X, "m68k 32x w8  [%06x]   %02x @%06x", a, d & 0xff, SekPc);
    a &= 0x3f;
    if (a == 1) {
      if ((d ^ r[0]) & d & P32XS_ADEN) {
        Pico32xStartup();
        r[0] &= ~P32XS_nRES; // causes reset if specified by this write
        r[0] |= P32XS_ADEN;
        p32x_reg_write8(a, d); // forward for reset processing
      }
      return;
    }

    // allow only COMM for now
    if ((a & 0x30) == 0x20) {
      u8 *r8 = (u8 *)r;
      r8[a ^ 1] = d;
    }
    return;
  }

  elprintf(EL_UIO, "m68k unmapped w8  [%06x]   %02x @%06x", a, d & 0xff, SekPc);
}

void PicoWrite16_32x(u32 a, u32 d)
{
  if ((a & 0xffc0) == 0x5100) { // a15100
    u16 *r = Pico32x.regs;

    elprintf(EL_UIO, "m68k 32x w16 [%06x] %04x @%06x", a, d & 0xffff, SekPc);
    a &= 0x3e;
    if (a == 0) {
      if ((d ^ r[0]) & d & P32XS_ADEN) {
        Pico32xStartup();
        r[0] &= ~P32XS_nRES; // causes reset if specified by this write
        r[0] |= P32XS_ADEN;
        p32x_reg_write16(a, d); // forward for reset processing
      }
      return;
    }

    // allow only COMM for now
    if ((a & 0x30) == 0x20)
      r[a / 2] = d;
    return;
  }

  elprintf(EL_UIO, "m68k unmapped w16 [%06x] %04x @%06x", a, d & 0xffff, SekPc);
}

/* quirk: in both normal and overwrite areas only nonzero values go through */
#define sh2_write8_dramN(n) \
  if ((d & 0xff) != 0) { \
    u8 *dram = (u8 *)Pico32xMem->dram[n]; \
    dram[(a & 0x1ffff) ^ 1] = d; \
  }

static void m68k_write8_dram0_ow(u32 a, u32 d)
{
  sh2_write8_dramN(0);
}

static void m68k_write8_dram1_ow(u32 a, u32 d)
{
  sh2_write8_dramN(1);
}

#define sh2_write16_dramN(n) \
  u16 *pd = &Pico32xMem->dram[n][(a & 0x1ffff) / 2]; \
  if (!(a & 0x20000)) { \
    *pd = d; \
    return; \
  } \
  /* overwrite */ \
  if (!(d & 0xff00)) d |= *pd & 0xff00; \
  if (!(d & 0x00ff)) d |= *pd & 0x00ff; \
  *pd = d;

static void m68k_write16_dram0_ow(u32 a, u32 d)
{
  sh2_write16_dramN(0);
}

static void m68k_write16_dram1_ow(u32 a, u32 d)
{
  sh2_write16_dramN(1);
}

// -----------------------------------------------------------------

// hint vector is writeable
static void PicoWrite8_hint(u32 a, u32 d)
{
  if ((a & 0xfffc) == 0x0070) {
    Pico32xMem->m68k_rom[a ^ 1] = d;
    return;
  }

  elprintf(EL_UIO, "m68k unmapped w8  [%06x]   %02x @%06x",
    a, d & 0xff, SekPc);
}

static void PicoWrite16_hint(u32 a, u32 d)
{
  if ((a & 0xfffc) == 0x0070) {
    ((u16 *)Pico32xMem->m68k_rom)[a/2] = d;
    return;
  }

  elprintf(EL_UIO, "m68k unmapped w16 [%06x] %04x @%06x",
    a, d & 0xffff, SekPc);
}

// normally not writable, but somebody could make a RAM cart
static void PicoWrite8_cart(u32 a, u32 d)
{
  elprintf(EL_UIO, "m68k w8  [%06x]   %02x @%06x", a, d & 0xff, SekPc);

  a &= 0xfffff;
  m68k_write8(a, d);
}

static void PicoWrite16_cart(u32 a, u32 d)
{
  elprintf(EL_UIO, "m68k w16 [%06x] %04x @%06x", a, d & 0xffff, SekPc);

  a &= 0xfffff;
  m68k_write16(a, d);
}

// same with bank, but save ram is sometimes here
static u32 PicoRead8_bank(u32 a)
{
  a = (Pico32x.regs[4 / 2] << 20) | (a & 0xfffff);
  return m68k_read8(a);
}

static u32 PicoRead16_bank(u32 a)
{
  a = (Pico32x.regs[4 / 2] << 20) | (a & 0xfffff);
  return m68k_read16(a);
}

static void PicoWrite8_bank(u32 a, u32 d)
{
  if (!(Pico.m.sram_reg & SRR_MAPPED))
    elprintf(EL_UIO, "m68k w8  [%06x]   %02x @%06x",
      a, d & 0xff, SekPc);

  a = (Pico32x.regs[4 / 2] << 20) | (a & 0xfffff);
  m68k_write8(a, d);
}

static void PicoWrite16_bank(u32 a, u32 d)
{
  if (!(Pico.m.sram_reg & SRR_MAPPED))
    elprintf(EL_UIO, "m68k w16 [%06x] %04x @%06x",
      a, d & 0xffff, SekPc);

  a = (Pico32x.regs[4 / 2] << 20) | (a & 0xfffff);
  m68k_write16(a, d);
}

static void bank_map_handler(void)
{
  cpu68k_map_set(m68k_read8_map,   0x900000, 0x9fffff, PicoRead8_bank, 1);
  cpu68k_map_set(m68k_read16_map,  0x900000, 0x9fffff, PicoRead16_bank, 1);
}

static void bank_switch(int b)
{
  unsigned int rs, bank;

  if (Pico.m.ncart_in)
    return;

  bank = b << 20;
  if ((Pico.m.sram_reg & SRR_MAPPED) && bank == SRam.start) {
    bank_map_handler();
    return;
  }

  if (bank >= Pico.romsize) {
    elprintf(EL_32X|EL_ANOMALY, "missing bank @ %06x", bank);
    bank_map_handler();
    return;
  }

  // 32X ROM (unbanked, XXX: consider mirroring?)
  rs = (Pico.romsize + M68K_BANK_MASK) & ~M68K_BANK_MASK;
  rs -= bank;
  if (rs > 0x100000)
    rs = 0x100000;
  cpu68k_map_set(m68k_read8_map,   0x900000, 0x900000 + rs - 1, Pico.rom + bank, 0);
  cpu68k_map_set(m68k_read16_map,  0x900000, 0x900000 + rs - 1, Pico.rom + bank, 0);

  elprintf(EL_32X, "bank %06x-%06x -> %06x", 0x900000, 0x900000 + rs - 1, bank);

#ifdef EMU_F68K
  // setup FAME fetchmap
  for (rs = 0x90; rs < 0xa0; rs++)
    PicoCpuFM68k.Fetch[rs] = (unsigned long)Pico.rom + bank - 0x900000;
#endif
}

// -----------------------------------------------------------------
//                              SH2  
// -----------------------------------------------------------------

// read8
static u32 sh2_read8_unmapped(u32 a, SH2 *sh2)
{
  elprintf_sh2(sh2, EL_32X, "unmapped r8  [%08x]       %02x @%06x",
    a, 0, sh2_pc(sh2));
  return 0;
}

static u32 sh2_read8_cs0(u32 a, SH2 *sh2)
{
  u32 d = 0;

  sh2_burn_cycles(sh2, 1*2);

  // 0x3ffc0 is veridied
  if ((a & 0x3ffc0) == 0x4000) {
    d = p32x_sh2reg_read16(a, sh2);
    goto out_16to8;
  }

  if ((a & 0x3fff0) == 0x4100) {
    d = p32x_vdp_read16(a);
    sh2_poll_detect(sh2, a, SH2_STATE_VPOLL, 7);
    goto out_16to8;
  }

  // TODO: mirroring?
  if (!sh2->is_slave && a < sizeof(Pico32xMem->sh2_rom_m))
    return Pico32xMem->sh2_rom_m.b[a ^ 1];
  if (sh2->is_slave  && a < sizeof(Pico32xMem->sh2_rom_s))
    return Pico32xMem->sh2_rom_s.b[a ^ 1];

  if ((a & 0x3fe00) == 0x4200) {
    d = Pico32xMem->pal[(a & 0x1ff) / 2];
    goto out_16to8;
  }

  return sh2_read8_unmapped(a, sh2);

out_16to8:
  if (a & 1)
    d &= 0xff;
  else
    d >>= 8;

  elprintf_sh2(sh2, EL_32X, "r8  [%08x]       %02x @%06x",
    a, d, sh2_pc(sh2));
  return d;
}

static u32 sh2_read8_da(u32 a, SH2 *sh2)
{
  return sh2->data_array[(a & 0xfff) ^ 1];
}

// read16
static u32 sh2_read16_unmapped(u32 a, SH2 *sh2)
{
  elprintf_sh2(sh2, EL_32X, "unmapped r16 [%08x]     %04x @%06x",
    a, 0, sh2_pc(sh2));
  return 0;
}

static u32 sh2_read16_cs0(u32 a, SH2 *sh2)
{
  u32 d = 0;

  sh2_burn_cycles(sh2, 1*2);

  if ((a & 0x3ffc0) == 0x4000) {
    d = p32x_sh2reg_read16(a, sh2);
    if (!(EL_LOGMASK & EL_PWM) && (a & 0x30) == 0x30) // hide PWM
      return d;
    goto out;
  }

  if ((a & 0x3fff0) == 0x4100) {
    d = p32x_vdp_read16(a);
    sh2_poll_detect(sh2, a, SH2_STATE_VPOLL, 7);
    goto out;
  }

  if (!sh2->is_slave && a < sizeof(Pico32xMem->sh2_rom_m))
    return Pico32xMem->sh2_rom_m.w[a / 2];
  if (sh2->is_slave  && a < sizeof(Pico32xMem->sh2_rom_s))
    return Pico32xMem->sh2_rom_s.w[a / 2];

  if ((a & 0x3fe00) == 0x4200) {
    d = Pico32xMem->pal[(a & 0x1ff) / 2];
    goto out;
  }

  return sh2_read16_unmapped(a, sh2);

out:
  elprintf_sh2(sh2, EL_32X, "r16 [%08x]     %04x @%06x",
    a, d, sh2_pc(sh2));
  return d;
}

static u32 sh2_read16_da(u32 a, SH2 *sh2)
{
  return ((u16 *)sh2->data_array)[(a & 0xfff) / 2];
}

// writes
static void REGPARM(3) sh2_write_ignore(u32 a, u32 d, SH2 *sh2)
{
}

// write8
static void REGPARM(3) sh2_write8_unmapped(u32 a, u32 d, SH2 *sh2)
{
  elprintf_sh2(sh2, EL_32X, "unmapped w8  [%08x]       %02x @%06x",
    a, d & 0xff, sh2_pc(sh2));
}

static void REGPARM(3) sh2_write8_cs0(u32 a, u32 d, SH2 *sh2)
{
  elprintf_sh2(sh2, EL_32X, "w8  [%08x]       %02x @%06x",
    a, d & 0xff, sh2_pc(sh2));

  if (Pico32x.regs[0] & P32XS_FM) {
    if ((a & 0x3fff0) == 0x4100) {
      sh2->poll_addr = 0;
      p32x_vdp_write8(a, d);
      return;
    }
  }

  if ((a & 0x3ffc0) == 0x4000) {
    p32x_sh2reg_write8(a, d, sh2);
    return;
  }

  sh2_write8_unmapped(a, d, sh2);
}

static void REGPARM(3) sh2_write8_dram0(u32 a, u32 d, SH2 *sh2)
{
  sh2_write8_dramN(0);
}

static void REGPARM(3) sh2_write8_dram1(u32 a, u32 d, SH2 *sh2)
{
  sh2_write8_dramN(1);
}

static void REGPARM(3) sh2_write8_sdram(u32 a, u32 d, SH2 *sh2)
{
  u32 a1 = a & 0x3ffff;
#ifdef DRC_SH2
  int t = Pico32xMem->drcblk_ram[a1 >> SH2_DRCBLK_RAM_SHIFT];
  if (t)
    sh2_drc_wcheck_ram(a, t, sh2->is_slave);
#endif
  Pico32xMem->sdram[a1 ^ 1] = d;
}

static void REGPARM(3) sh2_write8_sdram_wt(u32 a, u32 d, SH2 *sh2)
{
  // xmen sync hack..
  if (a < 0x26000200)
    sh2_end_run(sh2, 32);

  sh2_write8_sdram(a, d, sh2);
}

static void REGPARM(3) sh2_write8_da(u32 a, u32 d, SH2 *sh2)
{
  u32 a1 = a & 0xfff;
#ifdef DRC_SH2
  int id = sh2->is_slave;
  int t = Pico32xMem->drcblk_da[id][a1 >> SH2_DRCBLK_DA_SHIFT];
  if (t)
    sh2_drc_wcheck_da(a, t, id);
#endif
  sh2->data_array[a1 ^ 1] = d;
}

// write16
static void REGPARM(3) sh2_write16_unmapped(u32 a, u32 d, SH2 *sh2)
{
  elprintf_sh2(sh2, EL_32X, "unmapped w16 [%08x]     %04x @%06x",
    a, d & 0xffff, sh2_pc(sh2));
}

static void REGPARM(3) sh2_write16_cs0(u32 a, u32 d, SH2 *sh2)
{
  if (((EL_LOGMASK & EL_PWM) || (a & 0x30) != 0x30)) // hide PWM
    elprintf_sh2(sh2, EL_32X, "w16 [%08x]     %04x @%06x",
      a, d & 0xffff, sh2_pc(sh2));

  if (Pico32x.regs[0] & P32XS_FM) {
    if ((a & 0x3fff0) == 0x4100) {
      sh2->poll_addr = 0;
      p32x_vdp_write16(a, d, sh2);
      return;
    }

    if ((a & 0x3fe00) == 0x4200) {
      Pico32xMem->pal[(a & 0x1ff) / 2] = d;
      Pico32x.dirty_pal = 1;
      return;
    }
  }

  if ((a & 0x3ffc0) == 0x4000) {
    p32x_sh2reg_write16(a, d, sh2);
    return;
  }

  sh2_write16_unmapped(a, d, sh2);
}

static void REGPARM(3) sh2_write16_dram0(u32 a, u32 d, SH2 *sh2)
{
  sh2_write16_dramN(0);
}

static void REGPARM(3) sh2_write16_dram1(u32 a, u32 d, SH2 *sh2)
{
  sh2_write16_dramN(1);
}

static void REGPARM(3) sh2_write16_sdram(u32 a, u32 d, SH2 *sh2)
{
  u32 a1 = a & 0x3ffff;
#ifdef DRC_SH2
  int t = Pico32xMem->drcblk_ram[a1 >> SH2_DRCBLK_RAM_SHIFT];
  if (t)
    sh2_drc_wcheck_ram(a, t, sh2->is_slave);
#endif
  ((u16 *)Pico32xMem->sdram)[a1 / 2] = d;
}

static void REGPARM(3) sh2_write16_da(u32 a, u32 d, SH2 *sh2)
{
  u32 a1 = a & 0xfff;
#ifdef DRC_SH2
  int id = sh2->is_slave;
  int t = Pico32xMem->drcblk_da[id][a1 >> SH2_DRCBLK_DA_SHIFT];
  if (t)
    sh2_drc_wcheck_da(a, t, id);
#endif
  ((u16 *)sh2->data_array)[a1 / 2] = d;
}


typedef u32 (sh2_read_handler)(u32 a, SH2 *sh2);
typedef void REGPARM(3) (sh2_write_handler)(u32 a, u32 d, SH2 *sh2);

#define SH2MAP_ADDR2OFFS_R(a) \
  ((u32)(a) >> SH2_READ_SHIFT)

#define SH2MAP_ADDR2OFFS_W(a) \
  ((u32)(a) >> SH2_WRITE_SHIFT)

u32 REGPARM(2) p32x_sh2_read8(u32 a, SH2 *sh2)
{
  const sh2_memmap *sh2_map = sh2->read8_map;
  uptr p;

  sh2_map += SH2MAP_ADDR2OFFS_R(a);
  p = sh2_map->addr;
  if (map_flag_set(p))
    return ((sh2_read_handler *)(p << 1))(a, sh2);
  else
    return *(u8 *)((p << 1) + ((a & sh2_map->mask) ^ 1));
}

u32 REGPARM(2) p32x_sh2_read16(u32 a, SH2 *sh2)
{
  const sh2_memmap *sh2_map = sh2->read16_map;
  uptr p;

  sh2_map += SH2MAP_ADDR2OFFS_R(a);
  p = sh2_map->addr;
  if (map_flag_set(p))
    return ((sh2_read_handler *)(p << 1))(a, sh2);
  else
    return *(u16 *)((p << 1) + ((a & sh2_map->mask) & ~1));
}

u32 REGPARM(2) p32x_sh2_read32(u32 a, SH2 *sh2)
{
  const sh2_memmap *sh2_map = sh2->read16_map;
  sh2_read_handler *handler;
  u32 offs;
  uptr p;

  offs = SH2MAP_ADDR2OFFS_R(a);
  sh2_map += offs;
  p = sh2_map->addr;
  if (!map_flag_set(p)) {
    // XXX: maybe 32bit access instead with ror?
    u16 *pd = (u16 *)((p << 1) + ((a & sh2_map->mask) & ~1));
    return (pd[0] << 16) | pd[1];
  }

  if (offs == SH2MAP_ADDR2OFFS_R(0xffffc000))
    return sh2_peripheral_read32(a, sh2);

  handler = (sh2_read_handler *)(p << 1);
  return (handler(a, sh2) << 16) | handler(a + 2, sh2);
}

void REGPARM(3) p32x_sh2_write8(u32 a, u32 d, SH2 *sh2)
{
  const void **sh2_wmap = sh2->write8_tab;
  sh2_write_handler *wh;

  wh = sh2_wmap[SH2MAP_ADDR2OFFS_W(a)];
  wh(a, d, sh2);
}

void REGPARM(3) p32x_sh2_write16(u32 a, u32 d, SH2 *sh2)
{
  const void **sh2_wmap = sh2->write16_tab;
  sh2_write_handler *wh;

  wh = sh2_wmap[SH2MAP_ADDR2OFFS_W(a)];
  wh(a, d, sh2);
}

void REGPARM(3) p32x_sh2_write32(u32 a, u32 d, SH2 *sh2)
{
  const void **sh2_wmap = sh2->write16_tab;
  sh2_write_handler *wh;
  u32 offs;

  offs = SH2MAP_ADDR2OFFS_W(a);

  if (offs == SH2MAP_ADDR2OFFS_W(0xffffc000)) {
    sh2_peripheral_write32(a, d, sh2);
    return;
  }

  wh = sh2_wmap[offs];
  wh(a, d >> 16, sh2);
  wh(a + 2, d, sh2);
}

// -----------------------------------------------------------------

static void z80_md_bank_write_32x(unsigned int a, unsigned char d)
{
  unsigned int addr68k;

  addr68k = Pico.m.z80_bank68k << 15;
  addr68k += a & 0x7fff;
  if ((addr68k & 0xfff000) == 0xa15000)
    Pico32x.emu_flags |= P32XF_Z80_32X_IO;

  elprintf(EL_Z80BNK, "z80->68k w8 [%06x] %02x", addr68k, d);
  m68k_write8(addr68k, d);
}

// -----------------------------------------------------------------

static const u16 msh2_code[] = {
  // trap instructions
  0xaffe, // 200 bra <self>
  0x0009, // 202 nop
  // have to wait a bit until m68k initial program finishes clearing stuff
  // to avoid races with game SH2 code, like in Tempo
  0xd406, // 204 mov.l   @(_m_ok,pc), r4
  0xc400, // 206 mov.b   @(h'0,gbr),r0
  0xc801, // 208 tst     #1, r0
  0x8b0f, // 20a bf      cd_start
  0xd105, // 20c mov.l   @(_cnt,pc), r1
  0xd206, // 20e mov.l   @(_start,pc), r2
  0x71ff, // 210 add     #-1, r1
  0x4115, // 212 cmp/pl  r1
  0x89fc, // 214 bt      -2
  0x6043, // 216 mov     r4, r0
  0xc208, // 218 mov.l   r0, @(h'20,gbr)
  0x6822, // 21a mov.l   @r2, r8
  0x482b, // 21c jmp     @r8
  0x0009, // 21e nop
  ('M'<<8)|'_', ('O'<<8)|'K', // 220 _m_ok
  0x0001, 0x0000,             // 224 _cnt
  0x2200, 0x03e0, // master start pointer in ROM
  // cd_start:
  0xd20d, // 22c mov.l   @(__cd_,pc), r2
  0xc608, // 22e mov.l   @(h'20,gbr), r0
  0x3200, // 230 cmp/eq  r0, r2
  0x8bfc, // 232 bf      #-2
  0xe000, // 234 mov     #0, r0
  0xcf80, // 236 or.b    #0x80,@(r0,gbr)
  0xd80b, // 238 mov.l   @(_start_cd,pc), r8 // 24000018
  0xd30c, // 23a mov.l   @(_max_len,pc), r3
  0x5b84, // 23c mov.l   @(h'10,r8), r11     // master vbr
  0x5a82, // 23e mov.l   @(8,r8), r10        // entry
  0x5081, // 240 mov.l   @(4,r8), r0         // len
  0x5980, // 242 mov.l   @(0,r8), r9         // dst
  0x3036, // 244 cmp/hi  r3,r0
  0x8b00, // 246 bf      #1
  0x6033, // 248 mov     r3,r0
  0x7820, // 24a add     #0x20, r8
  // ipl_copy:
  0x6286, // 24c mov.l   @r8+, r2
  0x2922, // 24e mov.l   r2, @r9
  0x7904, // 250 add     #4, r9
  0x70fc, // 252 add     #-4, r0
  0x8800, // 254 cmp/eq  #0, r0
  0x8bf9, // 256 bf      #-5
  //
  0x4b2e, // 258 ldc     r11, vbr
  0x6043, // 25a mov     r4, r0              // M_OK
  0xc208, // 25c mov.l   r0, @(h'20,gbr)
  0x4a2b, // 25e jmp     @r10
  0x0009, // 260 nop
  0x0009, // 262 nop          //     pad
  ('_'<<8)|'C', ('D'<<8)|'_', // 264 __cd_
  0x2400, 0x0018,             // 268 _start_cd
  0x0001, 0xffe0,             // 26c _max_len
};

static const u16 ssh2_code[] = {
  0xaffe, // 200 bra <self>
  0x0009, // 202 nop
  // code to wait for master, in case authentic master BIOS is used
  0xd106, // 204 mov.l   @(_m_ok,pc), r1
  0xd208, // 206 mov.l   @(_start,pc), r2
  0xc608, // 208 mov.l   @(h'20,gbr), r0
  0x3100, // 20a cmp/eq  r0, r1
  0x8bfc, // 20c bf      #-2
  0xc400, // 20e mov.b   @(h'0,gbr),r0
  0xc801, // 210 tst     #1, r0
  0xd004, // 212 mov.l   @(_s_ok,pc), r0
  0x8b0a, // 214 bf      cd_start
  0xc209, // 216 mov.l   r0, @(h'24,gbr)
  0x6822, // 218 mov.l   @r2, r8
  0x482b, // 21a jmp     @r8
  0x0009, // 21c nop
  0x0009, // 21e nop
  ('M'<<8)|'_', ('O'<<8)|'K', // 220
  ('S'<<8)|'_', ('O'<<8)|'K', // 224
  0x2200, 0x03e4,  // slave start pointer in ROM
  // cd_start:
  0xd803, // 22c mov.l   @(_start_cd,pc), r8 // 24000018
  0x5b85, // 22e mov.l   @(h'14,r8), r11     // slave vbr
  0x5a83, // 230 mov.l   @(h'0c,r8), r10     // entry
  0x4b2e, // 232 ldc     r11, vbr
  0xc209, // 234 mov.l   r0, @(h'24,gbr)     // write S_OK
  0x4a2b, // 236 jmp     @r10
  0x0009, // 238 nop
  0x0009, // 23a nop
  0x2400, 0x0018, // 23c _start_cd
};

#define HWSWAP(x) (((u16)(x) << 16) | ((x) >> 16))
static void get_bios(void)
{
  u16 *ps;
  u32 *pl;
  int i;

  // M68K ROM
  if (p32x_bios_g != NULL) {
    elprintf(EL_STATUS|EL_32X, "32x: using supplied 68k BIOS");
    Byteswap(Pico32xMem->m68k_rom, p32x_bios_g, sizeof(Pico32xMem->m68k_rom));
  }
  else {
    // generate 68k ROM
    ps = (u16 *)Pico32xMem->m68k_rom;
    pl = (u32 *)ps;
    for (i = 1; i < 0xc0/4; i++)
      pl[i] = HWSWAP(0x880200 + (i - 1) * 6);

    // fill with nops
    for (i = 0xc0/2; i < 0x100/2; i++)
      ps[i] = 0x4e71;

#if 0
    ps[0xc0/2] = 0x46fc;
    ps[0xc2/2] = 0x2700; // move #0x2700,sr
    ps[0xfe/2] = 0x60fe; // jump to self
#else
    ps[0xfe/2] = 0x4e75; // rts
#endif
  }
  // fill remaining m68k_rom page with game ROM
  memcpy(Pico32xMem->m68k_rom_bank + sizeof(Pico32xMem->m68k_rom),
    Pico.rom + sizeof(Pico32xMem->m68k_rom),
    sizeof(Pico32xMem->m68k_rom_bank) - sizeof(Pico32xMem->m68k_rom));

  // MSH2
  if (p32x_bios_m != NULL) {
    elprintf(EL_STATUS|EL_32X, "32x: using supplied master SH2 BIOS");
    Byteswap(&Pico32xMem->sh2_rom_m, p32x_bios_m, sizeof(Pico32xMem->sh2_rom_m));
  }
  else {
    pl = (u32 *)&Pico32xMem->sh2_rom_m;

    // fill exception vector table to our trap address
    for (i = 0; i < 128; i++)
      pl[i] = HWSWAP(0x200);

    // start
    pl[0] = pl[2] = HWSWAP(0x204);
    // reset SP
    pl[1] = pl[3] = HWSWAP(0x6040000);

    // startup code
    memcpy(&Pico32xMem->sh2_rom_m.b[0x200], msh2_code, sizeof(msh2_code));
  }

  // SSH2
  if (p32x_bios_s != NULL) {
    elprintf(EL_STATUS|EL_32X, "32x: using supplied slave SH2 BIOS");
    Byteswap(&Pico32xMem->sh2_rom_s, p32x_bios_s, sizeof(Pico32xMem->sh2_rom_s));
  }
  else {
    pl = (u32 *)&Pico32xMem->sh2_rom_s;

    // fill exception vector table to our trap address
    for (i = 0; i < 128; i++)
      pl[i] = HWSWAP(0x200);

    // start
    pl[0] = pl[2] = HWSWAP(0x204);
    // reset SP
    pl[1] = pl[3] = HWSWAP(0x603f800);

    // startup code
    memcpy(&Pico32xMem->sh2_rom_s.b[0x200], ssh2_code, sizeof(ssh2_code));
  }
}

#define MAP_MEMORY(m) ((uptr)(m) >> 1)
#define MAP_HANDLER(h) ( ((uptr)(h) >> 1) | ((uptr)1 << (sizeof(uptr) * 8 - 1)) )

static sh2_memmap sh2_read8_map[0x80], sh2_read16_map[0x80];
// for writes we are using handlers only
static sh2_write_handler *sh2_write8_map[0x80], *sh2_write16_map[0x80];

void Pico32xSwapDRAM(int b)
{
  cpu68k_map_set(m68k_read8_map,   0x840000, 0x85ffff, Pico32xMem->dram[b], 0);
  cpu68k_map_set(m68k_read16_map,  0x840000, 0x85ffff, Pico32xMem->dram[b], 0);
  cpu68k_map_set(m68k_read8_map,   0x860000, 0x87ffff, Pico32xMem->dram[b], 0);
  cpu68k_map_set(m68k_read16_map,  0x860000, 0x87ffff, Pico32xMem->dram[b], 0);
  cpu68k_map_set(m68k_write8_map,  0x840000, 0x87ffff,
                 b ? m68k_write8_dram1_ow : m68k_write8_dram0_ow, 1);
  cpu68k_map_set(m68k_write16_map, 0x840000, 0x87ffff,
                 b ? m68k_write16_dram1_ow : m68k_write16_dram0_ow, 1);

  // SH2
  sh2_read8_map[0x04/2].addr  = sh2_read8_map[0x24/2].addr  =
  sh2_read16_map[0x04/2].addr = sh2_read16_map[0x24/2].addr = MAP_MEMORY(Pico32xMem->dram[b]);

  sh2_write8_map[0x04/2]  = sh2_write8_map[0x24/2]  = b ? sh2_write8_dram1 : sh2_write8_dram0;
  sh2_write16_map[0x04/2] = sh2_write16_map[0x24/2] = b ? sh2_write16_dram1 : sh2_write16_dram0;
}

void PicoMemSetup32x(void)
{
  unsigned int rs;
  int i;

  Pico32xMem = plat_mmap(0x06000000, sizeof(*Pico32xMem), 0, 0);
  if (Pico32xMem == NULL) {
    elprintf(EL_STATUS, "OOM");
    return;
  }

  get_bios();

  // cartridge area becomes unmapped
  // XXX: we take the easy way and don't unmap ROM,
  // so that we can avoid handling the RV bit.
  // m68k_map_unmap(0x000000, 0x3fffff);

  if (!Pico.m.ncart_in) {
    // MD ROM area
    rs = sizeof(Pico32xMem->m68k_rom_bank);
    cpu68k_map_set(m68k_read8_map,   0x000000, rs - 1, Pico32xMem->m68k_rom_bank, 0);
    cpu68k_map_set(m68k_read16_map,  0x000000, rs - 1, Pico32xMem->m68k_rom_bank, 0);
    cpu68k_map_set(m68k_write8_map,  0x000000, rs - 1, PicoWrite8_hint, 1); // TODO verify
    cpu68k_map_set(m68k_write16_map, 0x000000, rs - 1, PicoWrite16_hint, 1);

    // 32X ROM (unbanked, XXX: consider mirroring?)
    rs = (Pico.romsize + M68K_BANK_MASK) & ~M68K_BANK_MASK;
    if (rs > 0x80000)
      rs = 0x80000;
    cpu68k_map_set(m68k_read8_map,   0x880000, 0x880000 + rs - 1, Pico.rom, 0);
    cpu68k_map_set(m68k_read16_map,  0x880000, 0x880000 + rs - 1, Pico.rom, 0);
    cpu68k_map_set(m68k_write8_map,  0x880000, 0x880000 + rs - 1, PicoWrite8_cart, 1);
    cpu68k_map_set(m68k_write16_map, 0x880000, 0x880000 + rs - 1, PicoWrite16_cart, 1);
#ifdef EMU_F68K
    // setup FAME fetchmap
    PicoCpuFM68k.Fetch[0] = (unsigned long)Pico32xMem->m68k_rom;
    for (rs = 0x88; rs < 0x90; rs++)
      PicoCpuFM68k.Fetch[rs] = (unsigned long)Pico.rom - 0x880000;
#endif

    // 32X ROM (banked)
    bank_switch(0);
    cpu68k_map_set(m68k_write8_map,  0x900000, 0x9fffff, PicoWrite8_bank, 1);
    cpu68k_map_set(m68k_write16_map, 0x900000, 0x9fffff, PicoWrite16_bank, 1);
  }

  // SYS regs
  cpu68k_map_set(m68k_read8_map,   0xa10000, 0xa1ffff, PicoRead8_32x_on, 1);
  cpu68k_map_set(m68k_read16_map,  0xa10000, 0xa1ffff, PicoRead16_32x_on, 1);
  cpu68k_map_set(m68k_write8_map,  0xa10000, 0xa1ffff, PicoWrite8_32x_on, 1);
  cpu68k_map_set(m68k_write16_map, 0xa10000, 0xa1ffff, PicoWrite16_32x_on, 1);

  // SH2 maps: A31,A30,A29,CS1,CS0
  // all unmapped by default
  for (i = 0; i < ARRAY_SIZE(sh2_read8_map); i++) {
    sh2_read8_map[i].addr   = MAP_HANDLER(sh2_read8_unmapped);
    sh2_read16_map[i].addr  = MAP_HANDLER(sh2_read16_unmapped);
  }

  for (i = 0; i < ARRAY_SIZE(sh2_write8_map); i++) {
    sh2_write8_map[i]       = sh2_write8_unmapped;
    sh2_write16_map[i]      = sh2_write16_unmapped;
  }

  // "purge area"
  for (i = 0x40; i <= 0x5f; i++) {
    sh2_write8_map[i >> 1]  =
    sh2_write16_map[i >> 1] = sh2_write_ignore;
  }

  // CS0
  sh2_read8_map[0x00/2].addr  = sh2_read8_map[0x20/2].addr  = MAP_HANDLER(sh2_read8_cs0);
  sh2_read16_map[0x00/2].addr = sh2_read16_map[0x20/2].addr = MAP_HANDLER(sh2_read16_cs0);
  sh2_write8_map[0x00/2]  = sh2_write8_map[0x20/2]  = sh2_write8_cs0;
  sh2_write16_map[0x00/2] = sh2_write16_map[0x20/2] = sh2_write16_cs0;
  // CS1 - ROM
  sh2_read8_map[0x02/2].addr  = sh2_read8_map[0x22/2].addr  =
  sh2_read16_map[0x02/2].addr = sh2_read16_map[0x22/2].addr = MAP_MEMORY(Pico.rom);
  sh2_read8_map[0x02/2].mask  = sh2_read8_map[0x22/2].mask  =
  sh2_read16_map[0x02/2].mask = sh2_read16_map[0x22/2].mask = 0x3fffff; // FIXME
  // CS2 - DRAM - done by Pico32xSwapDRAM()
  sh2_read8_map[0x04/2].mask  = sh2_read8_map[0x24/2].mask  =
  sh2_read16_map[0x04/2].mask = sh2_read16_map[0x24/2].mask = 0x01ffff;
  // CS3 - SDRAM
  sh2_read8_map[0x06/2].addr   = sh2_read8_map[0x26/2].addr   =
  sh2_read16_map[0x06/2].addr  = sh2_read16_map[0x26/2].addr  = MAP_MEMORY(Pico32xMem->sdram);
  sh2_write8_map[0x06/2]       = sh2_write8_sdram;
  sh2_write8_map[0x26/2]       = sh2_write8_sdram_wt;
  sh2_write16_map[0x06/2]      = sh2_write16_map[0x26/2]      = sh2_write16_sdram;
  sh2_read8_map[0x06/2].mask   = sh2_read8_map[0x26/2].mask   =
  sh2_read16_map[0x06/2].mask  = sh2_read16_map[0x26/2].mask  = 0x03ffff;
  // SH2 data array
  sh2_read8_map[0xc0/2].addr  = MAP_HANDLER(sh2_read8_da);
  sh2_read16_map[0xc0/2].addr = MAP_HANDLER(sh2_read16_da);
  sh2_write8_map[0xc0/2]      = sh2_write8_da;
  sh2_write16_map[0xc0/2]     = sh2_write16_da;
  // SH2 IO
  sh2_read8_map[0xff/2].addr  = MAP_HANDLER(sh2_peripheral_read8);
  sh2_read16_map[0xff/2].addr = MAP_HANDLER(sh2_peripheral_read16);
  sh2_write8_map[0xff/2]      = sh2_peripheral_write8;
  sh2_write16_map[0xff/2]     = sh2_peripheral_write16;

  // map DRAM area, both 68k and SH2
  Pico32xSwapDRAM(1);

  msh2.read8_map   = ssh2.read8_map   = sh2_read8_map;
  msh2.read16_map  = ssh2.read16_map  = sh2_read16_map;
  msh2.write8_tab  = ssh2.write8_tab  = (const void **)(void *)sh2_write8_map;
  msh2.write16_tab = ssh2.write16_tab = (const void **)(void *)sh2_write16_map;

  sh2_drc_mem_setup(&msh2);
  sh2_drc_mem_setup(&ssh2);

  // z80 hack
  z80_map_set(z80_write_map, 0x8000, 0xffff, z80_md_bank_write_32x, 1);
}

void Pico32xMemStateLoaded(void)
{
  bank_switch(Pico32x.regs[4 / 2]);
  Pico32xSwapDRAM((Pico32x.vdp_regs[0x0a / 2] & P32XV_FS) ^ P32XV_FS);
  memset(Pico32xMem->pwm, 0, sizeof(Pico32xMem->pwm));
  Pico32x.dirty_pal = 1;

  Pico32x.emu_flags &= ~(P32XF_68KCPOLL | P32XF_68KVPOLL);
  memset(&m68k_poll, 0, sizeof(m68k_poll));
  msh2.state = 0;
  msh2.poll_addr = msh2.poll_cycles = msh2.poll_cnt = 0;
  ssh2.state = 0;
  ssh2.poll_addr = ssh2.poll_cycles = ssh2.poll_cnt = 0;

  sh2_drc_flush_all();
}

// vim:shiftwidth=2:ts=2:expandtab
