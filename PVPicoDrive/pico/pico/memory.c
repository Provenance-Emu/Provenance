/*
 * PicoDrive
 * (C) notaz, 2008
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */
#include "../pico_int.h"
#include "../memory.h"
#include "../sound/sn76496.h"

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

static u32 PicoRead8_pico(u32 a)
{
  u32 d = 0;

  if ((a & 0xffffe0) == 0x800000) // Pico I/O
  {
    switch (a & 0x1f)
    {
      case 0x01: d = PicoPicohw.r1; break;
      case 0x03:
        d  =  PicoPad[0]&0x1f; // d-pad
        d |= (PicoPad[0]&0x20) << 2; // pen push -> C
        d  = ~d;
        break;

      case 0x05: d = (PicoPicohw.pen_pos[0] >> 8);  break; // what is MS bit for? Games read it..
      case 0x07: d =  PicoPicohw.pen_pos[0] & 0xff; break;
      case 0x09: d = (PicoPicohw.pen_pos[1] >> 8);  break;
      case 0x0b: d =  PicoPicohw.pen_pos[1] & 0xff; break;
      case 0x0d: d = (1 << (PicoPicohw.page & 7)) - 1; break;
      case 0x12: d = PicoPicohw.fifo_bytes == 0 ? 0x80 : 0; break; // guess
      default:
        goto unhandled;
    }
    return d;
  }

unhandled:
  elprintf(EL_UIO, "m68k unmapped r8  [%06x] @%06x", a, SekPc);
  return d;
}

static u32 PicoRead16_pico(u32 a)
{
  u32 d = 0;

  if      (a == 0x800010)
    d = (PicoPicohw.fifo_bytes > 0x3f) ? 0 : (0x3f - PicoPicohw.fifo_bytes);
  else if (a == 0x800012)
    d = PicoPicohw.fifo_bytes == 0 ? 0x8000 : 0; // guess
  else
    elprintf(EL_UIO, "m68k unmapped r16 [%06x] @%06x", a, SekPc);

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
    int r12_old = PicoPicohw.r12;
    PicoPicohw.r12 = d;
    if (r12_old != d)
      PicoReratePico();
  }
  else
    elprintf(EL_UIO, "m68k unmapped w16 [%06x] %04x @%06x", a, d & 0xffff, SekPc);
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
}

