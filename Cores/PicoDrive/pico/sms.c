/*
 * SMS emulation
 * (C) notaz, 2009-2010
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */
/*
 * TODO:
 * - start in a state as if BIOS ran
 * - RAM support in mapper
 * - region support
 * - H counter
 */
#include "pico_int.h"
#include "memory.h"
#include "sound/sn76496.h"

static unsigned char vdp_data_read(void)
{
  struct PicoVideo *pv = &Pico.video;
  unsigned char d;

  d = PicoMem.vramb[pv->addr];
  pv->addr = (pv->addr + 1) & 0x3fff;
  pv->pending = 0;
  return d;
}

static unsigned char vdp_ctl_read(void)
{
  struct PicoVideo *pv = &Pico.video;
  unsigned char d;

  z80_int_assert(0);
  d = pv->status | (pv->pending_ints << 7);
  pv->pending = pv->pending_ints = 0;
  pv->status = 0;

  elprintf(EL_SR, "VDP sr: %02x", d);
  return d;
}

static void vdp_data_write(unsigned char d)
{
  struct PicoVideo *pv = &Pico.video;

  if (pv->type == 3) {
    PicoMem.cram[pv->addr & 0x1f] = d;
    Pico.m.dirtyPal = 1;
  } else {
    PicoMem.vramb[pv->addr] = d;
  }
  pv->addr = (pv->addr + 1) & 0x3fff;

  pv->pending = 0;
}

static NOINLINE void vdp_reg_write(struct PicoVideo *pv, u8 a, u8 d)
{
  int l;

  pv->reg[a] = d;
  switch (a) {
  case 0:
    l = pv->pending_ints & (d >> 3) & 2;
    elprintf(EL_INTS, "hint %d", l);
    z80_int_assert(l);
    break;
  case 1:
    l = pv->pending_ints & (d >> 5) & 1;
    elprintf(EL_INTS, "vint %d", l);
    z80_int_assert(l);
    break;
  }
}

static void vdp_ctl_write(u8 d)
{
  struct PicoVideo *pv = &Pico.video;

  if (pv->pending) {
    if ((d >> 6) == 2) {
      elprintf(EL_IO, "  VDP r%02x=%02x", d & 0x0f, pv->addr & 0xff);
      if (pv->reg[d & 0x0f] != (u8)pv->addr)
        vdp_reg_write(pv, d & 0x0f, pv->addr);
    }
    pv->type = d >> 6;
    pv->addr &= 0x00ff;
    pv->addr |= (d & 0x3f) << 8;
  } else {
    pv->addr &= 0x3f00;
    pv->addr |= d;
  }
  pv->pending ^= 1;
}

static unsigned char z80_sms_in(unsigned short a)
{
  unsigned char d = 0;

  elprintf(EL_IO, "z80 port %04x read", a);
  a &= 0xc1;
  switch (a)
  {
    case 0x00:
    case 0x01:
      d = 0xff;
      break;

    case 0x40: /* V counter */
      d = Pico.video.v_counter;
      elprintf(EL_HVCNT, "V counter read: %02x", d);
      break;

    case 0x41: /* H counter */
      d = Pico.m.rotate++;
      elprintf(EL_HVCNT, "H counter read: %02x", d);
      break;

    case 0x80:
      d = vdp_data_read();
      break;

    case 0x81:
      d = vdp_ctl_read();
      break;

    case 0xc0: /* I/O port A and B */
      d = ~((PicoIn.pad[0] & 0x3f) | (PicoIn.pad[1] << 6));
      break;

    case 0xc1: /* I/O port B and miscellaneous */
      d = (Pico.ms.io_ctl & 0x80) | ((Pico.ms.io_ctl << 1) & 0x40) | 0x30;
      d |= ~(PicoIn.pad[1] >> 2) & 0x0f;
      break;
  }

  elprintf(EL_IO, "ret = %02x", d);
  return d;
}

static void z80_sms_out(unsigned short a, unsigned char d)
{
  elprintf(EL_IO, "z80 port %04x write %02x", a, d);
  a &= 0xc1;
  switch (a)
  {
    case 0x01:
      Pico.ms.io_ctl = d;
      break;

    case 0x40:
    case 0x41:
      if ((d & 0x90) == 0x90 && Pico.snd.psg_line < Pico.m.scanline)
        PsndDoPSG(Pico.m.scanline);
      SN76496Write(d);
      break;

    case 0x80:
      vdp_data_write(d);
      break;

    case 0x81:
      vdp_ctl_write(d);
      break;
  }
}

static int bank_mask;

static void write_bank(unsigned short a, unsigned char d)
{
  elprintf(EL_Z80BNK, "bank %04x %02x @ %04x", a, d, z80_pc());
  switch (a & 0x0f)
  {
    case 0x0c:
      elprintf(EL_STATUS|EL_ANOMALY, "%02x written to control reg!", d);
      break;
    case 0x0d:
      if (d != 0)
        elprintf(EL_STATUS|EL_ANOMALY, "bank0 changed to %d!", d);
      break;
    case 0x0e:
      d &= bank_mask;
      z80_map_set(z80_read_map, 0x4000, 0x7fff, Pico.rom + (d << 14), 0);
#ifdef _USE_CZ80
      Cz80_Set_Fetch(&CZ80, 0x4000, 0x7fff, (FPTR)Pico.rom + (d << 14));
#endif
      break;
    case 0x0f:
      d &= bank_mask;
      z80_map_set(z80_read_map, 0x8000, 0xbfff, Pico.rom + (d << 14), 0);
#ifdef _USE_CZ80
      Cz80_Set_Fetch(&CZ80, 0x8000, 0xbfff, (FPTR)Pico.rom + (d << 14));
#endif
      break;
  }
  Pico.ms.carthw[a & 0x0f] = d;
}

static void xwrite(unsigned int a, unsigned char d)
{
  elprintf(EL_IO, "z80 write [%04x] %02x", a, d);
  if (a >= 0xc000)
    PicoMem.zram[a & 0x1fff] = d;
  if (a >= 0xfff8)
    write_bank(a, d);
}

void PicoResetMS(void)
{
  z80_reset();
  PsndReset(); // pal must be known here
}

void PicoPowerMS(void)
{
  int s, tmp;

  memset(&PicoMem,0,sizeof(PicoMem));
  memset(&Pico.video,0,sizeof(Pico.video));
  memset(&Pico.m,0,sizeof(Pico.m));
  Pico.m.pal = 0;

  // calculate a mask for bank writes.
  // ROM loader has aligned the size for us, so this is safe.
  s = 0; tmp = Pico.romsize;
  while ((tmp >>= 1) != 0)
    s++;
  if (Pico.romsize > (1 << s))
    s++;
  tmp = 1 << s;
  bank_mask = (tmp - 1) >> 14;

  Pico.ms.carthw[0x0e] = 1;
  Pico.ms.carthw[0x0f] = 2;

  PicoReset();
}

void PicoMemSetupMS(void)
{
  z80_map_set(z80_read_map, 0x0000, 0xbfff, Pico.rom, 0);
  z80_map_set(z80_read_map, 0xc000, 0xdfff, PicoMem.zram, 0);
  z80_map_set(z80_read_map, 0xe000, 0xffff, PicoMem.zram, 0);

  z80_map_set(z80_write_map, 0x0000, 0xbfff, xwrite, 1);
  z80_map_set(z80_write_map, 0xc000, 0xdfff, PicoMem.zram, 0);
  z80_map_set(z80_write_map, 0xe000, 0xffff, xwrite, 1);
 
#ifdef _USE_DRZ80
  drZ80.z80_in = z80_sms_in;
  drZ80.z80_out = z80_sms_out;
#endif
#ifdef _USE_CZ80
  Cz80_Set_Fetch(&CZ80, 0x0000, 0xbfff, (FPTR)Pico.rom);
  Cz80_Set_Fetch(&CZ80, 0xc000, 0xdfff, (FPTR)PicoMem.zram);
  Cz80_Set_Fetch(&CZ80, 0xe000, 0xffff, (FPTR)PicoMem.zram);
  Cz80_Set_INPort(&CZ80, z80_sms_in);
  Cz80_Set_OUTPort(&CZ80, z80_sms_out);
#endif
}

void PicoStateLoadedMS(void)
{
  write_bank(0xfffe, Pico.ms.carthw[0x0e]);
  write_bank(0xffff, Pico.ms.carthw[0x0f]);
}

void PicoFrameMS(void)
{
  struct PicoVideo *pv = &Pico.video;
  int is_pal = Pico.m.pal;
  int lines = is_pal ? 313 : 262;
  int cycles_line = is_pal ? 58020 : 58293; /* (226.6 : 227.7) * 256 */
  int cycles_done = 0, cycles_aim = 0;
  int skip = PicoIn.skipFrame;
  int lines_vis = 192;
  int hint; // Hint counter
  int nmi;
  int y;

  PsndStartFrame();

  nmi = (PicoIn.pad[0] >> 7) & 1;
  if (!Pico.ms.nmi_state && nmi)
    z80_nmi();
  Pico.ms.nmi_state = nmi;

  PicoFrameStartMode4();
  hint = pv->reg[0x0a];

  for (y = 0; y < lines; y++)
  {
    pv->v_counter = Pico.m.scanline = y;
    if (y > 218)
      pv->v_counter = y - 6;

    if (y < lines_vis && !skip)
      PicoLineMode4(y);

    if (y <= lines_vis)
    {
      if (--hint < 0)
      {
        hint = pv->reg[0x0a];
        pv->pending_ints |= 2;
        if (pv->reg[0] & 0x10) {
          elprintf(EL_INTS, "hint");
          z80_int_assert(1);
        }
      }
    }
    else if (y == lines_vis + 1) {
      pv->pending_ints |= 1;
      if (pv->reg[1] & 0x20) {
        elprintf(EL_INTS, "vint");
        z80_int_assert(1);
      }
    }

    // 224 because of how it's done for MD...
    if (y == 224 && PicoIn.sndOut)
      PsndGetSamplesMS();

    cycles_aim += cycles_line;
    cycles_done += z80_run((cycles_aim - cycles_done) >> 8) << 8;
  }

  if (PicoIn.sndOut && Pico.snd.psg_line < lines)
    PsndDoPSG(lines - 1);
}

void PicoFrameDrawOnlyMS(void)
{
  int lines_vis = 192;
  int y;

  PicoFrameStartMode4();

  for (y = 0; y < lines_vis; y++)
    PicoLineMode4(y);
}

// vim:ts=2:sw=2:expandtab
