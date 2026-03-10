/*
 * PicoDrive
 * (C) notaz, 2008
 * (C) irixxxx, 2024
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */
#include "../pico_int.h"
#include "../memory.h"
#include <platform/common/input_pico.h>
#include <sys/time.h>

/*
void dump(u16 w)
{
  static FILE *f[0x10] = { NULL, };
  char fname[32];
  int num = PicoPicohw.r12 & 0xf;

  w = (w << 8) | (w >> 8);
  sprintf(fname, "ldump%i.bin", num);
  if (f[num] == NULL)
    f[num] = fopen(fname, "wb");
  fwrite(&w, 1, 2, f[num]);
  //fclose(f);
}
*/

u64 get_ticks(void)
{
    struct timeval tv;
    u64 ret;

    gettimeofday(&tv, NULL);

    ret = (unsigned)tv.tv_sec * 1000;
    /* approximate /= 1000 */
    ret += ((unsigned)tv.tv_usec * 4195) >> 22;

    return ret;
}

static u32 PicoRead16_pico(u32 a)
{
  u32 d = 0;

  switch (a & 0x1e)
  {
    case 0x00: d = PicoPicohw.r1; break;
    case 0x02: d  =  PicoIn.pad[0]&0x1f; // d-pad
               d |= (PicoIn.pad[0]&0x20) << 2; // pen push -> C
               d  = ~d;
               break;
    case 0x04: d = (PicoPicohw.pen_pos[0] >> 8);  break;
    case 0x06: d =  PicoPicohw.pen_pos[0] & 0xff; break;
    case 0x08: d = (PicoPicohw.pen_pos[1] >> 8);  break;
    case 0x0a: d =  PicoPicohw.pen_pos[1] & 0xff; break;
    case 0x0c: d = (1 << (PicoPicohw.page & 7)) - 1;
               if (PicoPicohw.page == 7) d = 0x2a; // 0b00101010
               break;
    case 0x10: d = (PicoPicohw.fifo_bytes > 0x3f) ? 0 : (0x3f - PicoPicohw.fifo_bytes); break;
    case 0x12: d = (PicoPicohw.fifo_bytes | !PicoPicoPCMBusyN()) ? 0 : 0x8000;
               d |= PicoPicohw.r12 & 0x7fff;
               break;
    default:   elprintf(EL_UIO, "m68k unmapped r16 [%06x] @%06x", a, SekPc); break;
  }
  return d;
}

static u32 PicoRead8_pico(u32 a)
{
  u32 d = 0;

  if ((a & 0xffffe0) == 0x800000) // Pico I/O
  {
    d = PicoRead16_pico(a);
    if (!(a & 1)) d >>= 8;
    return d & 0xff;
  }

  elprintf(EL_UIO, "m68k unmapped r8  [%06x] @%06x", a, SekPc);
  return d;
}

static void PicoWrite8_pico(u32 a, u32 d)
{
  switch (a & ~0x800000) {
    case 0x19: case 0x1b: case 0x1d: case 0x1f: break; // 'S' 'E' 'G' 'A'
    default:
      elprintf(EL_UIO, "m68k unmapped w8  [%06x]   %02x @%06x", a, d & 0xff, SekPc);
      break;
  }
}

static void PicoWrite16_pico(u32 a, u32 d)
{
  //if (a == 0x800010) dump(d);
  if (a == 0x800010)
  {
    PicoPicohw.fifo_bytes += 2;

    if (PicoPicohw.xpcm_ptr < PicoPicohw.xpcm_buffer + XPCM_BUFFER_SIZE) {
      *PicoPicohw.xpcm_ptr++ = d >> 8;
      *PicoPicohw.xpcm_ptr++ = d;
    }
    else if (PicoPicohw.xpcm_ptr == PicoPicohw.xpcm_buffer + XPCM_BUFFER_SIZE) {
      elprintf(EL_ANOMALY|EL_PICOHW, "xpcm_buffer overflow!");
      PicoPicohw.xpcm_ptr++;
    }
  }
  else if (a == 0x800012) {
    PicoPicohw.r12 = d;

    PicoPicoPCMGain(8 - (d & 0x0007)); // volume
    PicoPicoPCMFilter((d & 0x00c0) >> 6); // low pass filter
    PicoPicoPCMIrqEn(d & 0x4000); // PCM IRQ enable

    if (d & 0x8000) { // PCM reset if 1 is written (dalmatians)?
      PsndDoPCM(cycles_68k_to_z80(SekCyclesDone() - Pico.t.m68c_frame_start));
      PicoPicoPCMResetN(0);
      PicoPicohw.xpcm_ptr = PicoPicohw.xpcm_buffer;
      PicoPicohw.fifo_bytes = 0;
      PicoPicoPCMResetN(1);
    }
    // TODO: other bits used in software: 0x3f00.
  }
  else
    elprintf(EL_UIO, "m68k unmapped w16 [%06x] %04x @%06x", a, d & 0xffff, SekPc);
}

static u32 PicoRead8_pico_kb(u32 a)
{
  u32 d = 0;
  if (!(PicoIn.opt & POPT_EN_KBD)) {
    elprintf(EL_PICOHW, "kb: r @%06X %04X = %04X\n", SekPc, a, d);
    return d;
  }

  PicoPicohw.kb.has_read = 1;

  u32 key_shift = (PicoIn.kbd & 0xff00) >> 8;
  u32 key = (PicoIn.kbd & 0x00ff);

  // The Shift key requires 2 key up events to be registered:
  // SHIFT_UP_HELD_DOWN to allow the game to register the key down event
  // for the next held down key(s), and SHIFT_UP when the Shift key
  // is no longer held down.
  //
  // For the second key up event, we need to
  // override the parsed key code with PEVB_KBD_SHIFT,
  // otherwise it will be zero and the game won't clear its Shift key state.
  u32 key_code = (key_shift
      && !key
      && PicoPicohw.kb.key_state != PKEY_UP
      && PicoPicohw.kb.shift_state != PSHIFT_UP_HELD_DOWN)
    ? key_shift
    : PicoPicohw.kb.shift_state == PSHIFT_UP ? PEVB_KBD_LSHIFT : key;
  u32 key_code_7654 = (key_code & 0xf0) >> 4;
  u32 key_code_3210 = (key_code & 0x0f);
  switch(PicoPicohw.kb.i) {
    case 0x0: d = 1; // m5id
      break;
    case 0x1: d = 3; // m6id
      break;
    case 0x2: d = 4; // data size
      break;
    case 0x3: d = 0; // pad1 rldu
      break;
    case 0x4: d = 0; // pad2 sacb
      break;
    case 0x5: d = 0; // pad3 rxyz
      break;
    case 0x6: d = 0; // l&kbtype
      break;
    case 0x7: // cap/num/scr
      if (PicoPicohw.kb.active) {
        if (key == PEVB_KBD_CAPSLOCK && PicoPicohw.kb.has_caps_lock == 1) {
          PicoPicohw.kb.caps_lock = PicoPicohw.kb.caps_lock == 4 ? 0 : 4;
          PicoPicohw.kb.has_caps_lock = 0;
        }
        d = PicoPicohw.kb.caps_lock;
      }
      break;
    case 0x8:
      d = 6;
      if (PicoPicohw.kb.active) {
        if (key) {
          PicoPicohw.kb.key_state = PKEY_DOWN;
        }
        if (!key) {
          PicoPicohw.kb.key_state = !PicoPicohw.kb.key_state ? 0 : (PicoPicohw.kb.key_state + 1) % (PKEY_UP + 1);
          PicoPicohw.kb.start_time_keydown = 0;
        }
        if (key_shift && !key) {
          if (PicoPicohw.kb.shift_state < PSHIFT_RELEASED_HELD_DOWN) {
            PicoPicohw.kb.shift_state++;
          }
          PicoPicohw.kb.start_time_keydown = 0;
        }
        if (!key_shift) {
          PicoPicohw.kb.shift_state = !PicoPicohw.kb.shift_state ? 0 : (PicoPicohw.kb.shift_state + 1) % (PSHIFT_UP + 1);
        }

        if (PicoPicohw.kb.key_state == PKEY_DOWN || PicoPicohw.kb.shift_state == PSHIFT_DOWN) {
          if (PicoPicohw.kb.start_time_keydown == 0) {
            d |= 8; // Send key down a.k.a. make
            PicoPicohw.kb.time_keydown = 0;
            PicoPicohw.kb.start_time_keydown = get_ticks();
           if (PicoPicohw.kb.key_state == PKEY_DOWN)
              elprintf(EL_PICOHW, "PicoPicohw.kb.key_state: PKEY DOWN\n");
           else
              elprintf(EL_PICOHW, "PicoPicohw.kb.key_state: PSHIFT DOWN\n");
          }
          // Simulate key repeat while held down a.k.a. typematic
          PicoPicohw.kb.time_keydown = get_ticks() - PicoPicohw.kb.start_time_keydown;
          if (PicoPicohw.kb.time_keydown > 350
                  // Modifier keys don't have typematic
                  && key_code != PEVB_KBD_CAPSLOCK
                  && key_code != PEVB_KBD_LSHIFT) {
            d |= 8; // Send key down a.k.a. make
           if (PicoPicohw.kb.key_state == PKEY_DOWN)
              elprintf(EL_PICOHW, "PicoPicohw.kb.key_state: PKEY DOWN\n");
           else
              elprintf(EL_PICOHW, "PicoPicohw.kb.key_state: PSHIFT DOWN\n");
          }
          // Must register key up while typematic not active (expected by Kibodeu Piko)
          if ((d & 8) == 0) {
            d |= 1; // Send key up a.k.a. break
          }
        }
        if (PicoPicohw.kb.key_state == PKEY_UP
            || PicoPicohw.kb.shift_state == PSHIFT_UP_HELD_DOWN
            || PicoPicohw.kb.shift_state == PSHIFT_UP) {
          d |= 1; // Send key up a.k.a. break
          PicoPicohw.kb.start_time_keydown = 0;
           if (PicoPicohw.kb.key_state == PKEY_UP)
              elprintf(EL_PICOHW, "PicoPicohw.kb.key_state: PKEY UP\n");
           else
              elprintf(EL_PICOHW, "PicoPicohw.kb.key_state: PSHIFT UP\n");
        }
      }
      break;
    case 0x9: d = key_code_7654; // data 7654
      break;
    case 0xa: d = key_code_3210; // data 3210
      break;
    case 0xb: d = 0; // ?
      break;
    case 0xc: d = 0; // ?
      break;
    default:
      d = 0;
      break;
  }

  if (PicoPicohw.kb.neg) {
      d |= 0xfffffff0;
  }

  elprintf(EL_PICOHW, "kb: r @%06X %04X = %04X\n", SekPc, a, d);
  return d;
}

static u32 PicoRead16_pico_kb(u32 a)
{
  u32 d = PicoPicohw.kb.mem;

  elprintf(EL_PICOHW, "kb: r16 @%06X %04X = %04X\n", SekPc, a, d);
  return d;
}

static void PicoWrite8_pico_kb(u32 a, u32 d)
{
  elprintf(EL_PICOHW, "kb: w @%06X %04X = %04X\n", SekPc, a, d);

  switch(d) {
    case 0x0:
      PicoPicohw.kb.neg = 0;
      PicoPicohw.kb.i++;
      break;
    case 0x20:
      PicoPicohw.kb.neg = 1;
      if (PicoPicohw.kb.has_read == 1) {
        PicoPicohw.kb.i++;
      }
      break;
    case 0x40:
      break;
    case 0x60:
      PicoPicohw.kb.mode = !PicoPicohw.kb.mode;
      PicoPicohw.kb.i = 0;
      PicoPicohw.kb.has_read = 0;
      break;
    default:
      break;
  }

  PicoPicohw.kb.mem = (PicoPicohw.kb.mem & 0xff00) | d;
}

static void PicoWrite16_pico_kb(u32 a, u32 d)
{
  elprintf(EL_PICOHW, "kb: w16 @%06X %04X = %04X\n", SekPc, a, d);

  PicoPicohw.kb.mem = d;
}

PICO_INTERNAL void PicoMemSetupPico(void)
{
  PicoMemSetup();

  // no MD IO or Z80 on Pico
  m68k_map_unmap(0x400000, 0xbfffff);

  // map Pico I/O
  cpu68k_map_set(m68k_read8_map,   0x800000, 0x80ffff, PicoRead8_pico, 1);
  cpu68k_map_set(m68k_read16_map,  0x800000, 0x80ffff, PicoRead16_pico, 1);
  cpu68k_map_set(m68k_write8_map,  0x800000, 0x80ffff, PicoWrite8_pico, 1);
  cpu68k_map_set(m68k_write16_map, 0x800000, 0x80ffff, PicoWrite16_pico, 1);

  m68k_map_unmap(0x200000, 0x20ffff);

  // map Pico PS/2 Peripheral I/O
  cpu68k_map_set(m68k_read8_map,   0x200000, 0x20ffff, PicoRead8_pico_kb, 1);
  cpu68k_map_set(m68k_read16_map,  0x200000, 0x20ffff, PicoRead16_pico_kb, 1);
  cpu68k_map_set(m68k_write8_map,  0x200000, 0x20ffff, PicoWrite8_pico_kb, 1);
  cpu68k_map_set(m68k_write16_map, 0x200000, 0x20ffff, PicoWrite16_pico_kb, 1);
}
