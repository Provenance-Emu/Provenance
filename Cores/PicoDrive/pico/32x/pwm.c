/*
 * PicoDrive
 * (C) notaz, 2009,2010,2013
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */
#include "../pico_int.h"

static int pwm_cycles;
static int pwm_mult;
static int pwm_ptr;
static int pwm_irq_reload;
static int pwm_doing_fifo;
static int pwm_silent;

void p32x_pwm_ctl_changed(void)
{
  int control = Pico32x.regs[0x30 / 2];
  int cycles = Pico32x.regs[0x32 / 2];

  cycles = (cycles - 1) & 0x0fff;
  pwm_cycles = cycles;

  // supposedly we should stop FIFO when xMd is 0,
  // but mars test disagrees
  pwm_mult = 0;
  if ((control & 0x0f) != 0)
    pwm_mult = 0x10000 / cycles;

  pwm_irq_reload = (control & 0x0f00) >> 8;
  pwm_irq_reload = ((pwm_irq_reload - 1) & 0x0f) + 1;

  if (Pico32x.pwm_irq_cnt == 0)
    Pico32x.pwm_irq_cnt = pwm_irq_reload;
}

static void do_pwm_irq(SH2 *sh2, unsigned int m68k_cycles)
{
  p32x_trigger_irq(sh2, m68k_cycles, P32XI_PWM);

  if (Pico32x.regs[0x30 / 2] & P32XP_RTP) {
    p32x_event_schedule(m68k_cycles, P32X_EVENT_PWM, pwm_cycles / 3 + 1);
    // note: might recurse
    p32x_dreq1_trigger();
  }
}

static int convert_sample(unsigned int v)
{
  if (v == 0)
    return 0;
  if (v > pwm_cycles)
    v = pwm_cycles;
  return ((int)v - pwm_cycles / 2) * pwm_mult;
}

#define consume_fifo(sh2, m68k_cycles) { \
  int cycles_diff = ((m68k_cycles) * 3) - Pico32x.pwm_cycle_p; \
  if (cycles_diff >= pwm_cycles) \
    consume_fifo_do(sh2, m68k_cycles, cycles_diff); \
}

static void consume_fifo_do(SH2 *sh2, unsigned int m68k_cycles,
  int sh2_cycles_diff)
{
  struct Pico32xMem *mem = Pico32xMem;
  unsigned short *fifo_l = mem->pwm_fifo[0];
  unsigned short *fifo_r = mem->pwm_fifo[1];
  int sum = 0;

  if (pwm_cycles == 0 || pwm_doing_fifo)
    return;

  elprintf(EL_PWM, "pwm: %u: consume %d/%d, %d,%d ptr %d",
    m68k_cycles, sh2_cycles_diff, sh2_cycles_diff / pwm_cycles,
    Pico32x.pwm_p[0], Pico32x.pwm_p[1], pwm_ptr);

  // this is for recursion from dreq1 writes
  pwm_doing_fifo = 1;

  for (; sh2_cycles_diff >= pwm_cycles; sh2_cycles_diff -= pwm_cycles)
  {
    if (Pico32x.pwm_p[0] > 0) {
      fifo_l[0] = fifo_l[1];
      fifo_l[1] = fifo_l[2];
      fifo_l[2] = fifo_l[3];
      Pico32x.pwm_p[0]--;
      mem->pwm_current[0] = convert_sample(fifo_l[0]);
      sum += mem->pwm_current[0];
    }
    if (Pico32x.pwm_p[1] > 0) {
      fifo_r[0] = fifo_r[1];
      fifo_r[1] = fifo_r[2];
      fifo_r[2] = fifo_r[3];
      Pico32x.pwm_p[1]--;
      mem->pwm_current[1] = convert_sample(fifo_r[0]);
      sum += mem->pwm_current[1];
    }

    mem->pwm[pwm_ptr * 2    ] = mem->pwm_current[0];
    mem->pwm[pwm_ptr * 2 + 1] = mem->pwm_current[1];
    pwm_ptr = (pwm_ptr + 1) & (PWM_BUFF_LEN - 1);

    if (--Pico32x.pwm_irq_cnt == 0) {
      Pico32x.pwm_irq_cnt = pwm_irq_reload;
      do_pwm_irq(sh2, m68k_cycles);
    }
  }
  Pico32x.pwm_cycle_p = m68k_cycles * 3 - sh2_cycles_diff;
  pwm_doing_fifo = 0;
  if (sum != 0)
    pwm_silent = 0;
}

static int p32x_pwm_schedule_(SH2 *sh2, unsigned int m68k_now)
{
  unsigned int sh2_now = m68k_now * 3;
  int cycles_diff_sh2;

  if (pwm_cycles == 0)
    return 0;

  cycles_diff_sh2 = sh2_now - Pico32x.pwm_cycle_p;
  if (cycles_diff_sh2 >= pwm_cycles)
    consume_fifo_do(sh2, m68k_now, cycles_diff_sh2);

  if (!((Pico32x.sh2irq_mask[0] | Pico32x.sh2irq_mask[1]) & 1))
    return 0; // masked by everyone

  cycles_diff_sh2 = sh2_now - Pico32x.pwm_cycle_p;
  return (Pico32x.pwm_irq_cnt * pwm_cycles
           - cycles_diff_sh2) / 3 + 1;
}

void p32x_pwm_schedule(unsigned int m68k_now)
{
  int after = p32x_pwm_schedule_(NULL, m68k_now);
  if (after != 0)
    p32x_event_schedule(m68k_now, P32X_EVENT_PWM, after);
}

void p32x_pwm_schedule_sh2(SH2 *sh2)
{
  int after = p32x_pwm_schedule_(sh2, sh2_cycles_done_m68k(sh2));
  if (after != 0)
    p32x_event_schedule_sh2(sh2, P32X_EVENT_PWM, after);
}

void p32x_pwm_sync_to_sh2(SH2 *sh2)
{
  int m68k_cycles = sh2_cycles_done_m68k(sh2);
  consume_fifo(sh2, m68k_cycles);
}

void p32x_pwm_irq_event(unsigned int m68k_now)
{
  p32x_pwm_schedule(m68k_now);
}

unsigned int p32x_pwm_read16(unsigned int a, SH2 *sh2,
  unsigned int m68k_cycles)
{
  unsigned int d = 0;

  consume_fifo(sh2, m68k_cycles);

  a &= 0x0e;
  switch (a) {
    case 0: // control
    case 2: // cycle
      d = Pico32x.regs[(0x30 + a) / 2];
      break;

    case 4: // L ch
      if (Pico32x.pwm_p[0] == 3)
        d |= P32XP_FULL;
      else if (Pico32x.pwm_p[0] == 0)
        d |= P32XP_EMPTY;
      break;

    case 6: // R ch
    case 8: // MONO
      if (Pico32x.pwm_p[1] == 3)
        d |= P32XP_FULL;
      else if (Pico32x.pwm_p[1] == 0)
        d |= P32XP_EMPTY;
      break;
  }

  elprintf(EL_PWM, "pwm: %u: r16 %02x %04x (p %d %d)",
    m68k_cycles, a, d, Pico32x.pwm_p[0], Pico32x.pwm_p[1]);
  return d;
}

void p32x_pwm_write16(unsigned int a, unsigned int d,
  SH2 *sh2, unsigned int m68k_cycles)
{
  elprintf(EL_PWM, "pwm: %u: w16 %02x %04x (p %d %d)",
    m68k_cycles, a & 0x0e, d, Pico32x.pwm_p[0], Pico32x.pwm_p[1]);

  consume_fifo(sh2, m68k_cycles);

  a &= 0x0e;
  if (a == 0) { // control
    // avoiding pops..
    if ((Pico32x.regs[0x30 / 2] & 0x0f) == 0)
      Pico32xMem->pwm_fifo[0][0] = Pico32xMem->pwm_fifo[1][0] = 0;
    Pico32x.regs[0x30 / 2] = d;
    p32x_pwm_ctl_changed();
    Pico32x.pwm_irq_cnt = pwm_irq_reload; // ?
  }
  else if (a == 2) { // cycle
    Pico32x.regs[0x32 / 2] = d & 0x0fff;
    p32x_pwm_ctl_changed();
  }
  else if (a <= 8) {
    d = (d - 1) & 0x0fff;

    if (a == 4 || a == 8) { // L ch or MONO
      unsigned short *fifo = Pico32xMem->pwm_fifo[0];
      if (Pico32x.pwm_p[0] < 3)
        Pico32x.pwm_p[0]++;
      else {
        fifo[1] = fifo[2];
        fifo[2] = fifo[3];
      }
      fifo[Pico32x.pwm_p[0]] = d;
    }
    if (a == 6 || a == 8) { // R ch or MONO
      unsigned short *fifo = Pico32xMem->pwm_fifo[1];
      if (Pico32x.pwm_p[1] < 3)
        Pico32x.pwm_p[1]++;
      else {
        fifo[1] = fifo[2];
        fifo[2] = fifo[3];
      }
      fifo[Pico32x.pwm_p[1]] = d;
    }
  }
}

void p32x_pwm_update(int *buf32, int length, int stereo)
{
  short *pwmb;
  int step;
  int p = 0;
  int xmd;

  consume_fifo(NULL, SekCyclesDone());

  xmd = Pico32x.regs[0x30 / 2] & 0x0f;
  if (xmd == 0 || xmd == 0x06 || xmd == 0x09 || xmd == 0x0f)
    goto out; // invalid?
  if (pwm_silent)
    return;

  step = (pwm_ptr << 16) / length;
  pwmb = Pico32xMem->pwm;

  if (stereo)
  {
    if (xmd == 0x05) {
      // normal
      while (length-- > 0) {
        *buf32++ += pwmb[0];
        *buf32++ += pwmb[1];

        p += step;
        pwmb += (p >> 16) * 2;
        p &= 0xffff;
      }
    }
    else if (xmd == 0x0a) {
      // channel swap
      while (length-- > 0) {
        *buf32++ += pwmb[1];
        *buf32++ += pwmb[0];

        p += step;
        pwmb += (p >> 16) * 2;
        p &= 0xffff;
      }
    }
    else {
      // mono - LMD, RMD specify dst
      if (xmd & 0x06) // src is R
        pwmb++;
      if (xmd & 0x0c) // dst is R
        buf32++;
      while (length-- > 0) {
        *buf32 += *pwmb;

        p += step;
        pwmb += (p >> 16) * 2;
        p &= 0xffff;
        buf32 += 2;
      }
    }
  }
  else
  {
    // mostly unused
    while (length-- > 0) {
      *buf32++ += pwmb[0];

      p += step;
      pwmb += (p >> 16) * 2;
      p &= 0xffff;
    }
  }

  elprintf(EL_PWM, "pwm_update: pwm_ptr %d, len %d, step %04x, done %d",
    pwm_ptr, length, step, (pwmb - Pico32xMem->pwm) / 2);

out:
  pwm_ptr = 0;
  pwm_silent = Pico32xMem->pwm_current[0] == 0
    && Pico32xMem->pwm_current[1] == 0;
}

void p32x_pwm_state_loaded(void)
{
  int cycles_diff_sh2;

  p32x_pwm_ctl_changed();

  // for old savestates
  cycles_diff_sh2 = SekCycleCnt * 3 - Pico32x.pwm_cycle_p;
  if (cycles_diff_sh2 >= pwm_cycles || cycles_diff_sh2 < 0) {
    Pico32x.pwm_irq_cnt = pwm_irq_reload;
    Pico32x.pwm_cycle_p = SekCycleCnt * 3;
    p32x_pwm_schedule(SekCycleCnt);
  }
}

// vim:shiftwidth=2:ts=2:expandtab
