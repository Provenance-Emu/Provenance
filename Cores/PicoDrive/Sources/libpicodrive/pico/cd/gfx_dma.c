/*
 * PicoDrive
 * (C) notaz, 2007
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include "../pico_int.h"

#include "cell_map.c"

// check: Heart of the alien, jaguar xj 220
PICO_INTERNAL void DmaSlowCell(u32 source, u32 a, int len, unsigned char inc)
{
  unsigned char *base;
  u32 asrc, a2;
  u16 *r;

  base = Pico_mcd->word_ram1M[Pico_mcd->s68k_regs[3]&1];

  switch (Pico.video.type)
  {
    case 1: // vram
      r = PicoMem.vram;
      for(; len; len--)
      {
        asrc = cell_map(source >> 2) << 2;
        asrc |= source & 2;
        // if(a&1) d=(d<<8)|(d>>8); // ??
        VideoWriteVRAM(a, *(u16 *)(base + asrc));
	source += 2;
        // AutoIncrement
        a=(u16)(a+inc);
      }
      break;

    case 3: // cram
      Pico.m.dirtyPal = 1;
      r = PicoMem.cram;
      for(a2=a&0x7f; len; len--)
      {
        asrc = cell_map(source >> 2) << 2;
        asrc |= source & 2;
        r[a2>>1] = *(u16 *)(base + asrc);
	source += 2;
        // AutoIncrement
        a2+=inc;
        // good dest?
        if(a2 >= 0x80) break;
      }
      a=(a&0xff00)|a2;
      break;

    case 5: // vsram[a&0x003f]=d;
      r = PicoMem.vsram;
      for(a2=a&0x7f; len; len--)
      {
        asrc = cell_map(source >> 2) << 2;
        asrc |= source & 2;
        r[a2>>1] = *(u16 *)(base + asrc);
	source += 2;
        // AutoIncrement
        a2+=inc;
        // good dest?
        if(a2 >= 0x80) break;
      }
      a=(a&0xff00)|a2;
      break;
  }
  // remember addr
  Pico.video.addr=(u16)a;
}

