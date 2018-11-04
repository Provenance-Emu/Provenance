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
 * - remaining status flags (OVR/COL)
 * - RAM support in mapper
 * - region support
 * - SN76496 DAC-like usage
 * - H counter
 */
#include "pico_int.h"
#include "memory.h"
#include "sound/sn76496.h"

static unsigned char vdp_data_read(void)
{
  struct PicoVideo *pv = &Pico.video;
  unsigned char d;

  d = Pico.vramb[pv->addr];
  pv->addr = (pv->addr + 1) & 0x3fff;
  pv->pending = 0;
  return d;
}

static unsigned char vdp_ctl_read(void)
{
  unsigned char d = Pico.video.pending_ints << 7;
  Pico.video.pending = 0;
  Pico.video.pending_ints = 0;

  elprintf(EL_SR, "VDP sr: %02x", d);
  return d;
}

static void vdp_data_write(unsigned char d)
{
  struct PicoVideo *pv = &Pico.video;

  if (pv->type == 3) {
    Pico.cram[pv->addr & 0x1f] = d;
    Pico.m.dirtyPal = 1;
  } else {
    Pico.vramb[pv->addr] = d;
  }
  pv->addr = (pv->addr + 1) & 0x3fff;

  pv->pending = 0;
}

static void vdp_ctl_write(unsigned char d)
{
  struct PicoVideo *pv = &Pico.video;

  if (pv->pending) {
    if ((d >> 6) == 2) {
      pv->reg[d & 0x0f] = pv->addr;
      elprintf(EL_IO, "  VDP r%02x=%02x", d & 0x0f, pv->addr & 0xff);
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
      d = ~((PicoPad[0] & 0x3f) | (PicoPad[1] << 6));
      break;

    case 0xc1: /* I/O port B and miscellaneous */
      d = (Pico.ms.io_ctl & 0x80) | ((Pico.ms.io_ctl << 1) & 0x40) | 0x30;
      d |= ~(PicoPad[1] >> 2) & 0x0f;
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
      if (PicoOpt & POPT_EN_PSG)
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
    Pico.zram[a & 0x1fff] = d;
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

  memset(&Pico.ram,0,(unsigned char *)&Pico.rom - Pico.ram);
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
  z80_map_set(z80_read_map, 0xc000, 0xdfff, Pico.zram, 0);
  z80_map_set(z80_read_map, 0xe000, 0xffff, Pico.zram, 0);

  z80_map_set(z80_write_map, 0x0000, 0xbfff, xwrite, 1);
  z80_map_set(z80_write_map, 0xc000, 0xdfff, Pico.zram, 0);
  z80_map_set(z80_write_map, 0xe000, 0xffff, xwrite, 1);
 
#ifdef _USE_DRZ80
  drZ80.z80_in = z80_sms_in;
  drZ80.z80_out = z80_sms_out;
#endif
#ifdef _USE_CZ80
  Cz80_Set_Fetch(&CZ80, 0x0000, 0xbfff, (FPTR)Pico.rom);
  Cz80_Set_Fetch(&CZ80, 0xc000, 0xdfff, (FPTR)Pico.zram);
  Cz80_Set_Fetch(&CZ80, 0xe000, 0xffff, (FPTR)Pico.zram);
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
  int skip = PicoSkipFrame;
  int lines_vis = 192;
  int hint; // Hint counter
  int nmi;
  int y;

  nmi = (PicoPad[0] >> 7) & 1;
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
          z80_int();
        }
      }
    }
    else if (y == lines_vis + 1) {
      pv->pending_ints |= 1;
      if (pv->reg[1] & 0x20) {
        elprintf(EL_INTS, "vint");
        z80_int();
      }
    }

    cycles_aim += cycles_line;
    cycles_done += z80_run((cycles_aim - cycles_done) >> 8) << 8;
  }

  if (PsndOut)
    PsndGetSamplesMS();
}

void PicoFrameDrawOnlyMS(void)
{
  int lines_vis = 192;
  int y;

  PicoFrameStartMode4();

  for (y = 0; y < lines_vis; y++)
    PicoLineMode4(y);
}

