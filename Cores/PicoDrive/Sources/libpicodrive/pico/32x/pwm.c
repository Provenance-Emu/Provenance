/*
 * PicoDrive
 * (C) notaz, 2009,2010,2013
 * (C) irixxxx, 2019-2023
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */
#include "../pico_int.h"

static struct {
  int cycles;
  unsigned mult;
  int ptr;
  int irq_reload;
  int doing_fifo;
  int silent;
  int irq_timer;
  int irq_state;
  short current[2];
} pwm;

enum { PWM_IRQ_LOCKED, PWM_IRQ_STOPPED, PWM_IRQ_LOW, PWM_IRQ_HIGH };

void p32x_pwm_ctl_changed(void)
{
  int control = Pico32x.regs[0x30 / 2];
  int cycles = Pico32x.regs[0x32 / 2];
  int pwm_irq_opt = PicoIn.opt & POPT_PWM_IRQ_OPT;

  cycles = (cycles - 1) & 0x0fff;
  pwm.cycles = cycles;

  // supposedly we should stop FIFO when xMd is 0,
  // but mars test disagrees
  pwm.mult = 0;
  if ((control & 0x0f) != 0)
    pwm.mult = (0x10000<<8) / (cycles+1);

  pwm.irq_timer = (control & 0x0f00) >> 8;
  pwm.irq_timer = ((pwm.irq_timer - 1) & 0x0f) + 1;
  pwm.irq_reload = pwm.irq_timer;
  pwm.irq_state = pwm_irq_opt ? PWM_IRQ_STOPPED: PWM_IRQ_LOCKED;

  if (Pico32x.pwm_irq_cnt <= 0)
    Pico32x.pwm_irq_cnt = pwm.irq_reload;
}

static void do_pwm_irq(SH2 *sh2, unsigned int m68k_cycles)
{
  p32x_trigger_irq(NULL, m68k_cycles, P32XI_PWM);

  if (Pico32x.regs[0x30 / 2] & P32XP_RTP) {
    p32x_event_schedule(m68k_cycles, P32X_EVENT_PWM, pwm.cycles / 3 + 1);
    // note: might recurse
    p32x_dreq1_trigger();
  }
}

static int convert_sample(unsigned int v)
{
  if (v > pwm.cycles)
    v = pwm.cycles;
  return (v * pwm.mult >> 8) - 0x10000/2;
}

#define consume_fifo(sh2, m68k_cycles) { \
  int cycles_diff = ((m68k_cycles) * 3) - Pico32x.pwm_cycle_p; \
  if (cycles_diff >= pwm.cycles) \
    consume_fifo_do(sh2, m68k_cycles, cycles_diff); \
}

static void consume_fifo_do(SH2 *sh2, unsigned int m68k_cycles,
  int sh2_cycles_diff)
{
  struct Pico32xMem *mem = Pico32xMem;
  unsigned short *fifo_l = mem->pwm_fifo[0];
  unsigned short *fifo_r = mem->pwm_fifo[1];
  int sum = 0;

  if (pwm.cycles == 0 || pwm.doing_fifo)
    return;

  elprintf(EL_PWM, "pwm: %u: consume %d/%d, %d,%d ptr %d",
    m68k_cycles, sh2_cycles_diff, sh2_cycles_diff / pwm.cycles,
    Pico32x.pwm_p[0], Pico32x.pwm_p[1], pwm.ptr);

  // this is for recursion from dreq1 writes
  pwm.doing_fifo = 1;

  while (sh2_cycles_diff >= pwm.cycles)
  {
    sh2_cycles_diff -= pwm.cycles;

    if (Pico32x.pwm_p[0] > 0) {
      mem->pwm_index[0] = (mem->pwm_index[0]+1) % 4;
      Pico32x.pwm_p[0]--;
      pwm.current[0] = convert_sample(fifo_l[mem->pwm_index[0]]);
      sum |= (u16)pwm.current[0];
    }
    if (Pico32x.pwm_p[1] > 0) {
      mem->pwm_index[1] = (mem->pwm_index[1]+1) % 4;
      Pico32x.pwm_p[1]--;
      pwm.current[1] = convert_sample(fifo_r[mem->pwm_index[1]]);
      sum |= (u16)pwm.current[1];
    }

    mem->pwm[pwm.ptr * 2    ] = pwm.current[0];
    mem->pwm[pwm.ptr * 2 + 1] = pwm.current[1];
    pwm.ptr = (pwm.ptr + 1) & (PWM_BUFF_LEN - 1);

    if (--Pico32x.pwm_irq_cnt <= 0) {
      Pico32x.pwm_irq_cnt = pwm.irq_reload;
      do_pwm_irq(sh2, m68k_cycles);
    } else if (Pico32x.pwm_p[1] == 0 && pwm.irq_state >= PWM_IRQ_LOW) {
      // buffer underrun. Reduce reload rate if above programmed setting.
      if (pwm.irq_reload > pwm.irq_timer)
        pwm.irq_reload--;
      pwm.irq_state = PWM_IRQ_LOW;
    }
  }
  Pico32x.pwm_cycle_p = m68k_cycles * 3 - sh2_cycles_diff;
  pwm.doing_fifo = 0;
  if (sum != 0)
    pwm.silent = 0;
}

static int p32x_pwm_schedule_(SH2 *sh2, unsigned int m68k_now)
{
  unsigned int pwm_now = m68k_now * 3;
  int cycles_diff_sh2;

  if (pwm.cycles == 0)
    return 0;

  cycles_diff_sh2 = pwm_now - Pico32x.pwm_cycle_p;
  if (cycles_diff_sh2 >= pwm.cycles)
    consume_fifo_do(sh2, m68k_now, cycles_diff_sh2);

  if (!((Pico32x.sh2irq_mask[0] | Pico32x.sh2irq_mask[1]) & 1))
    return 0; // masked by everyone

  cycles_diff_sh2 = pwm_now - Pico32x.pwm_cycle_p;
  return (Pico32x.pwm_irq_cnt * pwm.cycles
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

unsigned int p32x_pwm_read16(u32 a, SH2 *sh2, unsigned int m68k_cycles)
{
  unsigned int d = 0;

  consume_fifo(sh2, m68k_cycles);

  a &= 0x0e;
  switch (a/2) {
    case 0/2: // control
    case 2/2: // cycle
      d = Pico32x.regs[(0x30 + a) / 2];
      break;

    case 4/2: // L ch
      if (Pico32x.pwm_p[0] == 3)
        d |= P32XP_FULL;
      else if (Pico32x.pwm_p[0] == 0)
        d |= P32XP_EMPTY;
      break;

    case 6/2: // R ch
    case 8/2: // MONO
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

void p32x_pwm_write16(u32 a, unsigned int d, SH2 *sh2, unsigned int m68k_cycles)
{
  unsigned short *fifo;
  int idx;

  elprintf(EL_PWM, "pwm: %u: w16 %02x %04x (p %d %d)",
    m68k_cycles, a & 0x0e, d, Pico32x.pwm_p[0], Pico32x.pwm_p[1]);

  consume_fifo(sh2, m68k_cycles);

  a &= 0x0e;
  switch (a/2) {
    case 0/2: // control
      // avoiding pops..
      if ((Pico32x.regs[0x30 / 2] & 0x0f) == 0)
        Pico32xMem->pwm_fifo[0][0] = Pico32xMem->pwm_fifo[1][0] = 0;
      Pico32x.regs[0x30 / 2] = d;
      p32x_pwm_ctl_changed();
      Pico32x.pwm_irq_cnt = pwm.irq_reload; // ?
      break;
    case 2/2: // cycle
      Pico32x.regs[0x32 / 2] = d & 0x0fff;
      p32x_pwm_ctl_changed();
      break;
    case 8/2: // MONO
    case 6/2: // R ch
      fifo = Pico32xMem->pwm_fifo[1];
      idx = Pico32xMem->pwm_index[1];
      if (Pico32x.pwm_p[1] < 3) {
        if (Pico32x.pwm_p[1] == 2 && pwm.irq_state >= PWM_IRQ_STOPPED) {
          // buffer full. If there was no buffer underrun after last fill,
          // try increasing reload rate to reduce IRQs
          if (pwm.irq_reload < 3 && pwm.irq_state == PWM_IRQ_HIGH)
            pwm.irq_reload ++;
          pwm.irq_state = PWM_IRQ_HIGH;
        }
        Pico32x.pwm_p[1]++;
      } else {
        // buffer overflow. Some roms always fill the complete buffer even if
        // reload rate is set below max. Lock reload rate to programmed setting.
        pwm.irq_reload = pwm.irq_timer;
        pwm.irq_state = PWM_IRQ_LOCKED;
        idx = (idx+1) % 4;
        Pico32xMem->pwm_index[1] = idx;
      }
      fifo[(idx+Pico32x.pwm_p[1]) % 4] = (d - 1) & 0x0fff;
      if (a != 8) break; // fallthrough if MONO
    case 4/2: // L ch
      fifo = Pico32xMem->pwm_fifo[0];
      idx = Pico32xMem->pwm_index[0];
      if (Pico32x.pwm_p[0] < 3)
        Pico32x.pwm_p[0]++;
      else {
        idx = (idx+1) % 4;
        Pico32xMem->pwm_index[0] = idx;
      }
      fifo[(idx+Pico32x.pwm_p[0]) % 4] = (d - 1) & 0x0fff;
      break;
  }
}

void p32x_pwm_update(s32 *buf32, int length, int stereo)
{
  short *pwmb;
  int step;
  int p = 0;
  int xmd;

  consume_fifo(NULL, SekCyclesDone());

  xmd = Pico32x.regs[0x30 / 2] & 0x0f;
  if (xmd == 0 || xmd == 0x06 || xmd == 0x09 || xmd == 0x0f)
    goto out; // invalid?
  if (pwm.silent)
    return;

  step = (pwm.ptr << 16) / length;
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

  elprintf(EL_PWM, "pwm_update: pwm.ptr %d, len %d, step %04x, done %d",
    pwm.ptr, length, step, (pwmb - Pico32xMem->pwm) / 2);

out:
  pwm.ptr = 0;
  pwm.silent = pwm.current[0] == 0 && pwm.current[1] == 0;
}

void p32x_pwm_state_loaded(void)
{
  int cycles_diff_sh2;

  p32x_pwm_ctl_changed();

  // for old savestates
  cycles_diff_sh2 = Pico.t.m68c_cnt * 3 - Pico32x.pwm_cycle_p;
  if (cycles_diff_sh2 >= pwm.cycles || cycles_diff_sh2 < 0) {
    Pico32x.pwm_irq_cnt = pwm.irq_reload;
    Pico32x.pwm_cycle_p = Pico.t.m68c_cnt * 3;
    p32x_pwm_schedule(Pico.t.m68c_cnt);
  }
}

// vim:shiftwidth=2:ts=2:expandtab
