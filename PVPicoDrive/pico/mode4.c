/*
 * mode4/SMS renderer
 * (C) notaz, 2009-2010
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */
/*
 * TODO:
 * - TMS9918 modes?
 * - gg mode?
 * - column scroll (reg 0 bit7)
 * - 224/240 line modes
 * - doubled sprites
 */
#include "pico_int.h"

static void (*FinalizeLineM4)(int line);
static int skip_next_line;
static int screen_offset;

#define PLANAR_PIXEL(x,p) \
  t = pack & (0x80808080 >> p); \
  if (t) { \
    t = ((t >> (7-p)) | (t >> (14-p)) | (t >> (21-p)) | (t >> (28-p))) & 0x0f; \
    pd[x] = pal|t; \
  }

static int TileNormM4(int sx, int addr, int pal)
{
  unsigned char *pd = HighCol + sx;
  unsigned int pack, t;

  pack = *(unsigned int *)(Pico.vram + addr); /* Get 4 bitplanes / 8 pixels */
  if (pack)
  {
    PLANAR_PIXEL(0, 0)
    PLANAR_PIXEL(1, 1)
    PLANAR_PIXEL(2, 2)
    PLANAR_PIXEL(3, 3)
    PLANAR_PIXEL(4, 4)
    PLANAR_PIXEL(5, 5)
    PLANAR_PIXEL(6, 6)
    PLANAR_PIXEL(7, 7)
    return 0;
  }

  return 1; /* Tile blank */
}

static int TileFlipM4(int sx,int addr,int pal)
{
  unsigned char *pd = HighCol + sx;
  unsigned int pack, t;

  pack = *(unsigned int *)(Pico.vram + addr); /* Get 4 bitplanes / 8 pixels */
  if (pack)
  {
    PLANAR_PIXEL(0, 7)
    PLANAR_PIXEL(1, 6)
    PLANAR_PIXEL(2, 5)
    PLANAR_PIXEL(3, 4)
    PLANAR_PIXEL(4, 3)
    PLANAR_PIXEL(5, 2)
    PLANAR_PIXEL(6, 1)
    PLANAR_PIXEL(7, 0)
    return 0;
  }

  return 1; /* Tile blank */
}

static void draw_sprites(int scanline)
{
  struct PicoVideo *pv = &Pico.video;
  unsigned int sprites_addr[8];
  unsigned int sprites_x[8];
  unsigned char *sat;
  int xoff = 8; // relative to HighCol, which is (screen - 8)
  int sprite_base, addr_mask;
  int i, s, h;

  if (pv->reg[0] & 8)
    xoff = 0;

  sat = (unsigned char *)Pico.vram + ((pv->reg[5] & 0x7e) << 7);
  if (pv->reg[1] & 2) {
    addr_mask = 0xfe; h = 16;
  } else {
    addr_mask = 0xff; h = 8;
  }
  sprite_base = (pv->reg[6] & 4) << (13-2-1);

  for (i = s = 0; i < 64 && s < 8; i++)
  {
    int y;
    y = sat[i] + 1;
    if (y == 0xd1)
      break;
    if (y + h <= scanline || scanline < y)
      continue; // not on this line

    sprites_x[s] = xoff + sat[0x80 + i*2];
    sprites_addr[s] = sprite_base + ((sat[0x80 + i*2 + 1] & addr_mask) << (5-1)) +
      ((scanline - y) << (2-1));
    s++;
  }

  // now draw all sprites backwards
  for (--s; s >= 0; s--)
    TileNormM4(sprites_x[s], sprites_addr[s], 0x10);
}

// tilex_ty_prio merged to reduce register pressure
static void draw_strip(const unsigned short *nametab, int dx, int cells, int tilex_ty_prio)
{
  int oldcode = -1, blank = -1; // The tile we know is blank
  int addr = 0, pal = 0;

  // Draw tiles across screen:
  for (; cells > 0; dx += 8, tilex_ty_prio++, cells--)
  {
    int code, zero;

    code = nametab[tilex_ty_prio & 0x1f];
    if (code == blank)
      continue;
    if ((code ^ tilex_ty_prio) & 0x1000) // priority differs?
      continue;

    if (code != oldcode) {
      oldcode = code;
      // Get tile address/2:
      addr = (code & 0x1ff) << 4;
      addr += tilex_ty_prio >> 16;
      if (code & 0x0400)
        addr ^= 0xe; // Y-flip

      pal = (code>>7) & 0x10;
    }

    if (code&0x0200) zero = TileFlipM4(dx, addr, pal);
    else             zero = TileNormM4(dx, addr, pal);

    if (zero)
      blank = code; // We know this tile is blank now
  }
}

static void DrawDisplayM4(int scanline)
{
  struct PicoVideo *pv = &Pico.video;
  unsigned short *nametab;
  int line, tilex, dx, ty, cells;
  int cellskip = 0; // XXX
  int maxcells = 32;

  // Find the line in the name table
  line = pv->reg[9] + scanline; // vscroll + scanline
  if (line >= 224)
    line -= 224;

  // Find name table:
  nametab = Pico.vram;
  nametab += (pv->reg[2] & 0x0e) << (10-1);
  nametab += (line>>3) << (6-1);

  dx = pv->reg[8]; // hscroll
  if (scanline < 16 && (pv->reg[0] & 0x40))
    dx = 0; // hscroll disabled for top 2 rows

  tilex = ((-dx >> 3) + cellskip) & 0x1f;
  ty = (line & 7) << 1; // Y-Offset into tile
  cells = maxcells - cellskip;

  dx = ((dx - 1) & 7) + 1;
  if (dx != 8)
    cells++; // have hscroll, need to draw 1 cell more
  dx += cellskip << 3;

  // low priority tiles
  if (PicoDrawMask & PDRAW_LAYERB_ON)
    draw_strip(nametab, dx, cells, tilex | 0x0000 | (ty << 16));

  // sprites
  if (PicoDrawMask & PDRAW_SPRITES_LOW_ON)
    draw_sprites(scanline);

  // high priority tiles (use virtual layer switch just for fun)
  if (PicoDrawMask & PDRAW_LAYERA_ON)
    draw_strip(nametab, dx, cells, tilex | 0x1000 | (ty << 16));

  if (pv->reg[0] & 0x20)
    // first column masked
    ((int *)HighCol)[2] = ((int *)HighCol)[3] = 0xe0e0e0e0;
}

void PicoFrameStartMode4(void)
{
  int lines = 192;
  skip_next_line = 0;
  screen_offset = 24;
  rendstatus = PDRAW_32_COLS;

  if ((Pico.video.reg[0] & 6) == 6 && (Pico.video.reg[1] & 0x18)) {
    if (Pico.video.reg[1] & 0x08) {
      screen_offset = 0;
      lines = 240;
    }
    else {
      screen_offset = 8;
      lines = 224;
    }
  }

  if (rendstatus != rendstatus_old || lines != rendlines) {
    emu_video_mode_change(screen_offset, lines, 1);
    rendstatus_old = rendstatus;
    rendlines = lines;
  }

  DrawLineDest = (char *)DrawLineDestBase + screen_offset * DrawLineDestIncrement;
}

void PicoLineMode4(int line)
{
  if (skip_next_line > 0) {
    skip_next_line--;
    return;
  }

  if (PicoScanBegin != NULL)
    skip_next_line = PicoScanBegin(line + screen_offset);

  // Draw screen:
  BackFill(Pico.video.reg[7] & 0x0f, 0);
  if (Pico.video.reg[1] & 0x40)
    DrawDisplayM4(line);

  if (FinalizeLineM4 != NULL)
    FinalizeLineM4(line);

  if (PicoScanEnd != NULL)
    skip_next_line = PicoScanEnd(line + screen_offset);

  DrawLineDest = (char *)DrawLineDest + DrawLineDestIncrement;
}

void PicoDoHighPal555M4(void)
{
  unsigned int *spal=(void *)Pico.cram;
  unsigned int *dpal=(void *)HighPal;
  unsigned int t;
  int i;

  Pico.m.dirtyPal = 0;

  /* cram is always stored as shorts, even though real hardware probably uses bytes */
  for (i = 0x20/2; i > 0; i--, spal++, dpal++) {
    t = *spal;
#ifdef USE_BGR555
    t = ((t & 0x00030003)<< 3) | ((t & 0x000c000c)<<7) | ((t & 0x00300030)<<10);
#else
    t = ((t & 0x00030003)<<14) | ((t & 0x000c000c)<<7) | ((t & 0x00300030)>>1);
#endif
    t |= t >> 2;
    t |= (t >> 4) & 0x08610861;
    *dpal = t;
  }
  HighPal[0xe0] = 0;
}

static void FinalizeLineRGB555M4(int line)
{
  if (Pico.m.dirtyPal)
    PicoDoHighPal555M4();

  // standard FinalizeLine can finish it for us,
  // with features like scaling and such
  FinalizeLine555(0, line);
}

static void FinalizeLine8bitM4(int line)
{
  unsigned char *pd = DrawLineDest;

  if (!(PicoOpt & POPT_DIS_32C_BORDER))
    pd += 32;

  memcpy32((int *)pd, (int *)(HighCol+8), 256/4);
}

void PicoDrawSetOutputMode4(pdso_t which)
{
  switch (which)
  {
    case PDF_8BIT:   FinalizeLineM4 = FinalizeLine8bitM4; break;
    case PDF_RGB555: FinalizeLineM4 = FinalizeLineRGB555M4; break;
    default:         FinalizeLineM4 = NULL; break;
  }
}

