/*
 * SMS renderer
 * (C) notaz, 2009-2010
 * (C) irixxxx, 2020-2024
 *
 * currently supports VDP mode 4 (SMS and GG) and mode 3-0 (TMS)
 * modes numbered after the bit numbers used in Sega and TI documentation
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */
#include "pico_int.h"
#include <platform/common/upscale.h>

static void (*FinalizeLineSMS)(int line);
static int skip_next_line;
static int screen_offset, line_offset;
static u8 mode;

static unsigned int sprites_addr[32]; // bitmap address
static unsigned char sprites_c[32]; // TMS sprites color
static int sprites_x[32]; // x position
static int sprites; // count
static unsigned char sprites_map[2+256/8+2]; // collision detection map

unsigned int sprites_status;

/* sprite collision detection */
static int CollisionDetect(u8 *mb, u16 sx, unsigned int pack, int zoomed)
{
  static u8 morton[16] = { 0x00,0x03,0x0c,0x0f,0x30,0x33,0x3c,0x3f,
                           0xc0,0xc3,0xcc,0xcf,0xf0,0xf3,0xfc,0xff };
  u8 *mp = mb + (sx>>3);
  unsigned col, m;

  // check sprite map for collision and update map with current sprite
  if (!zoomed) { // 8 sprite pixels
    m = mp[0] | (mp[1]<<8);
    col = m & (pack<<(sx&7)); // collision if current sprite overlaps sprite map
    m |= pack<<(sx&7);
    mp[0] = m, mp[1] = m>>8;
  } else { // 16 sprite pixels in zoom mode
    pack = morton[pack&0x0f] | (morton[(pack>>4)&0x0f] << 8);
    m = mp[0] | (mp[1]<<8) | (mp[2]<<16);
    col = m & (pack<<(sx&7));
    m |= pack<<(sx&7);
    mp[0] = m, mp[1] = m>>8, mp[2] = m>>16;
  }

  // invisible overscan area, not tested for collision
  mb[0] = mb[33] = mb[34] = 0;
  return col;
}

/* Mode 4 - SMS Graphics */
/*=======================*/

static void TileBGM4(u16 sx, int pal)
{
  if (sx & 3) {
    u8 *pd = (u8 *)(Pico.est.HighCol + sx);
    pd[0] = pd[1] = pd[2] = pd[3] = pal;
    pd[4] = pd[5] = pd[6] = pd[7] = pal;
  } else {
    u32 *pd = (u32 *)(Pico.est.HighCol + sx);
    pd[0] = pd[1] = pal * 0x01010101;
  }
}

// 8 pixels are arranged in 4 bitplane bytes in a 32 bit word. To pull the
// 4 bitplanes together multiply with each bit distance (multiples of 1<<7)
#define PLANAR_PIXELBG(x,p) \
  t = (pack>>(7-p)) & 0x01010101; \
  t = (t*0x10204080) >> 28; \
  pd[x] = pal|t;

static void TileNormBGM4(u16 sx, unsigned int pack, int pal)
{
  u8 *pd = Pico.est.HighCol + sx;
  u32 t;

  PLANAR_PIXELBG(0, 0)
  PLANAR_PIXELBG(1, 1)
  PLANAR_PIXELBG(2, 2)
  PLANAR_PIXELBG(3, 3)
  PLANAR_PIXELBG(4, 4)
  PLANAR_PIXELBG(5, 5)
  PLANAR_PIXELBG(6, 6)
  PLANAR_PIXELBG(7, 7)
}

static void TileFlipBGM4(u16 sx, unsigned int pack, int pal)
{
  u8 *pd = Pico.est.HighCol + sx;
  u32 t;

  PLANAR_PIXELBG(0, 7)
  PLANAR_PIXELBG(1, 6)
  PLANAR_PIXELBG(2, 5)
  PLANAR_PIXELBG(3, 4)
  PLANAR_PIXELBG(4, 3)
  PLANAR_PIXELBG(5, 2)
  PLANAR_PIXELBG(6, 1)
  PLANAR_PIXELBG(7, 0)
}

// non-transparent sprite pixels apply if no higher prio pixel is already there
#define PLANAR_PIXELSP(x,p) \
  t = (pack>>(7-p)) & 0x01010101; \
  if (t && (pd[x] & 0x2f) <= 0x20) { \
    t = (t*0x10204080) >> 28; \
    pd[x] = pal|t; \
  }

static void TileNormSprM4(u16 sx, unsigned int pack, int pal)
{
  u8 *pd = Pico.est.HighCol + sx;
  u32 t;

  PLANAR_PIXELSP(0, 0)
  PLANAR_PIXELSP(1, 1)
  PLANAR_PIXELSP(2, 2)
  PLANAR_PIXELSP(3, 3)
  PLANAR_PIXELSP(4, 4)
  PLANAR_PIXELSP(5, 5)
  PLANAR_PIXELSP(6, 6)
  PLANAR_PIXELSP(7, 7)
}

static void TileDoubleSprM4(int sx, unsigned int pack, int pal)
{
  u8 *pd = Pico.est.HighCol + sx;
  u32 t;

  PLANAR_PIXELSP(0, 0)
  PLANAR_PIXELSP(1, 0)
  PLANAR_PIXELSP(2, 1)
  PLANAR_PIXELSP(3, 1)
  PLANAR_PIXELSP(4, 2)
  PLANAR_PIXELSP(5, 2)
  PLANAR_PIXELSP(6, 3)
  PLANAR_PIXELSP(7, 3)
  PLANAR_PIXELSP(8, 4)
  PLANAR_PIXELSP(9, 4)
  PLANAR_PIXELSP(10, 5)
  PLANAR_PIXELSP(11, 5)
  PLANAR_PIXELSP(12, 6)
  PLANAR_PIXELSP(13, 6)
  PLANAR_PIXELSP(14, 7)
  PLANAR_PIXELSP(15, 7)
}

static void ParseSpritesM4(int scanline)
{
  struct PicoVideo *pv = &Pico.video;
  u8 *sat;
  int xoff = line_offset;
  int sprite_base, addr_mask;
  int zoomed = pv->reg[1] & 0x1; // zoomed sprites, e.g. Earthworm Jim
  unsigned int pack;
  int i, s, h, m;

  if (pv->reg[0] & 8)
    xoff -= 8;  // sprite shift
  if (Pico.m.hardware & PMS_HW_LCD)
    xoff -= 48; // GG LCD, adjust to center 160 px

  sat = (u8 *)PicoMem.vram + ((pv->reg[5] & 0x7e) << 7);
  if (pv->reg[1] & 2) {
    addr_mask = 0xfe; h = 16;
  } else {
    addr_mask = 0xff; h = 8;
  }
  if (zoomed) h *= 2;
  sprite_base = (pv->reg[6] & 4) << (13-2-1);

  m = pv->status & SR_C;
  memset(sprites_map, 0, sizeof(sprites_map));
  for (i = s = 0; i < 64; i++)
  {
    int y;
    y = sat[MEM_LE2(i)];
    if (y == 0xd0 && !((pv->reg[0] & 6) == 6 && (pv->reg[1] & 0x18)))
      break;
    if (y >= 0xe0)
      y -= 256;
    y &= ~zoomed; // zoomed sprites apparently only on even lines, see GG Tarzan
    if (y + h <= scanline || scanline < y)
      continue; // not on this line
    if (s >= 8) {
      if (scanline >= 0) sprites_status |= SR_SOVR;
      if (!(PicoIn.opt & POPT_DIS_SPRITE_LIM) || s >= 32)
        break;
    }

    if (xoff + sat[MEM_LE2(0x80 + i*2)] >= 0) {
      sprites_x[s] = xoff + sat[MEM_LE2(0x80 + i*2)];
      sprites_addr[s] = sprite_base + ((sat[MEM_LE2(0x80 + i*2 + 1)] & addr_mask) << (5-1)) +
        ((scanline - y) >> zoomed << (2-1));
      if (Pico.video.reg[1] & 0x40) {
        // collision detection. Do it here since off-screen lines aren't drawn
        pack = CPU_LE2(*(u32 *)(PicoMem.vram + sprites_addr[s]));
        // make sprite pixel map by merging the 4 bitplanes
        pack = ((pack | (pack>>16)) | ((pack | (pack>>16))>>8)) & 0xff;
        if (!m) m = CollisionDetect(sprites_map, sprites_x[s], pack, zoomed);
        // no collision detection in 1st column if it's masked
        if (pv->reg[0] & 0x20)
          sprites_map[1] = 0;
      }
      s++;
    }
  }
  if (m)
    sprites_status |= SR_C;
  sprites = s;
}

static void DrawSpritesM4(void)
{
  struct PicoVideo *pv = &Pico.video;
  unsigned int pack;
  int zoomed = pv->reg[1] & 0x1; // zoomed sprites, e.g. Earthworm Jim
  int s = sprites;

  // now draw all sprites backwards
  for (--s; s >= 0; s--) {
    pack = CPU_LE2(*(u32 *)(PicoMem.vram + sprites_addr[s]));
    if (zoomed) TileDoubleSprM4(sprites_x[s], pack, 0x10);
    else        TileNormSprM4(sprites_x[s], pack, 0x10);
  }
}

// cells_dx, tilex_ty merged to reduce register pressure
static void DrawStripM4(const u16 *nametab, int cells_dx, int tilex_ty)
{
  int oldcode = -1;
  int addr = 0, pal = 0;

  // Draw tiles across screen:
  for (; cells_dx >= 0; cells_dx += 8, tilex_ty++, cells_dx -= 0x10000)
  {
    unsigned int pack;
    unsigned code;

    code = nametab[tilex_ty & 0x1f];

    if (code != oldcode) {
      oldcode = code;
      // Get tile address/2:
      addr = (code & 0x1ff) << 4;
      addr += tilex_ty >> 16;
      if (code & 0x0400)
        addr ^= 0xe; // Y-flip

      pal = (code>>7) & 0x30;  // prio | palette select
    }

    pack = CPU_LE2(*(u32 *)(PicoMem.vram + addr)); // Get 4 bitplanes / 8 pixels
    if (pack == 0)          TileBGM4(cells_dx, pal);
    else if (code & 0x0200) TileFlipBGM4(cells_dx, pack, pal);
    else                    TileNormBGM4(cells_dx, pack, pal);
  }
}

static void DrawDisplayM4(int scanline)
{
  struct PicoVideo *pv = &Pico.video;
  u16 *nametab, *nametab2;
  int line, tilex, dx, ty, cells;
  int cellskip = 0; // XXX
  int maxcells = 32;

  // Find the line in the name table
  line = pv->reg[9] + scanline; // vscroll + scanline

  // Find name table:
  nametab = PicoMem.vram;
  if ((pv->reg[0] & 6) == 6 && (pv->reg[1] & 0x18)) {
    // 224/240 line mode
    line &= 0xff;
    nametab += ((pv->reg[2] & 0x0c) << (10-1)) + (0x700 >> 1);
  } else {
    while (line >= 224) line -= 224;
    nametab += (pv->reg[2] & 0x0e) << (10-1);
    // old SMS only, masks line:7 with reg[2]:0 for address calculation
    //if ((pv->reg[2] & 0x01) == 0) line &= 0x7f;
  }
  nametab2 = nametab + ((scanline>>3) << (6-1));
  nametab  = nametab + ((line>>3)     << (6-1));

  dx = pv->reg[8]; // hscroll
  if (scanline < 16 && (pv->reg[0] & 0x40))
    dx = 0; // hscroll disabled for top 2 rows (e.g. Fantasy Zone II)

  tilex = (32 - (dx >> 3) + cellskip) & 0x1f;
  ty = (line & 7) << 1; // Y-Offset into tile
  cells = maxcells - cellskip - 1;

  dx = (dx & 7);
  dx += cellskip << 3;
  dx += line_offset;

  // tiles
  if (!(pv->debug_p & PVD_KILL_B)) {
    if (Pico.m.hardware & PMS_HW_LCD) {
      // on GG render only the center 160 px, but mind hscroll
      DrawStripM4(nametab , (dx-8) | ((cells-11)<< 16),(tilex+5) | (ty  << 16));
    } else if (pv->reg[0] & 0x80) {
      // vscroll disabled for rightmost 8 columns (e.g. Gauntlet)
      int dx2 = dx + (cells-8)*8, tilex2 = tilex + (cells-8), ty2 = scanline&7;
      DrawStripM4(nametab,   dx    | ((cells-8) << 16), tilex    | (ty  << 16));
      DrawStripM4(nametab2,  dx2   |        (8  << 16), tilex2   | (ty2 << 17));
    } else
      DrawStripM4(nametab ,  dx    | ( cells    << 16), tilex    | (ty  << 16));
  }

  // sprites
  if (!(pv->debug_p & PVD_KILL_S_LO))
    DrawSpritesM4();

  if ((pv->reg[0] & 0x20) && !(Pico.m.hardware & PMS_HW_LCD)) {
    // first column masked with background, caculate offset to start of line
    dx = line_offset / 4;
    ty = ((pv->reg[7]&0x0f)|0x10) * 0x01010101;
    ((u32 *)Pico.est.HighCol)[dx] = ((u32 *)Pico.est.HighCol)[dx+1] = ty;
  }
}


/* TMS Modes */
/*===========*/

/* Background */

#define TMS_PIXELBG(x,p) \
  t = (pack>>(7-p)) & 0x01; \
  t = (pal >> (t << 2)) & 0x0f; \
  if (t) \
    pd[x] = t;

static void TileNormBgM1(u16 sx, unsigned int pack, int pal) /* Text */
{
  u8 *pd = Pico.est.HighCol + sx;
  unsigned int t;

  TMS_PIXELBG(0, 0)
  TMS_PIXELBG(1, 1)
  TMS_PIXELBG(2, 2)
  TMS_PIXELBG(3, 3)
  TMS_PIXELBG(4, 4)
  TMS_PIXELBG(5, 5)
}

static void TileNormBgM2(u16 sx, int pal) /* Multicolor */
{
  u8 *pd = Pico.est.HighCol + sx;
  unsigned int pack = 0xf0;
  unsigned int t;

  TMS_PIXELBG(0, 0)
  TMS_PIXELBG(1, 1)
  TMS_PIXELBG(2, 2)
  TMS_PIXELBG(3, 3)
  TMS_PIXELBG(4, 4)
  TMS_PIXELBG(5, 5)
  TMS_PIXELBG(6, 6)
  TMS_PIXELBG(7, 7)
}

static void TileNormBgMg(u16 sx, unsigned int pack, int pal) /* Graphics */
{
  u8 *pd = Pico.est.HighCol + sx;
  unsigned int t;

  TMS_PIXELBG(0, 0)
  TMS_PIXELBG(1, 1)
  TMS_PIXELBG(2, 2)
  TMS_PIXELBG(3, 3)
  TMS_PIXELBG(4, 4)
  TMS_PIXELBG(5, 5)
  TMS_PIXELBG(6, 6)
  TMS_PIXELBG(7, 7)
}

/* Sprites */

#define TMS_PIXELSP(x,p) \
  t = (pack>>(7-p)) & 0x01; \
  if (t) \
    pd[x] = pal;

static void TileNormSprTMS(u16 sx, unsigned int pack, int pal)
{
  u8 *pd = Pico.est.HighCol + sx;
  unsigned int t;

  TMS_PIXELSP(0, 0)
  TMS_PIXELSP(1, 1)
  TMS_PIXELSP(2, 2)
  TMS_PIXELSP(3, 3)
  TMS_PIXELSP(4, 4)
  TMS_PIXELSP(5, 5)
  TMS_PIXELSP(6, 6)
  TMS_PIXELSP(7, 7)
}

static void TileDoubleSprTMS(u16 sx, unsigned int pack, int pal)
{
  u8 *pd = Pico.est.HighCol + sx;
  unsigned int t;

  TMS_PIXELSP(0, 0)
  TMS_PIXELSP(1, 0)
  TMS_PIXELSP(2, 1)
  TMS_PIXELSP(3, 1)
  TMS_PIXELSP(4, 2)
  TMS_PIXELSP(5, 2)
  TMS_PIXELSP(6, 3)
  TMS_PIXELSP(7, 3)
  TMS_PIXELSP(8, 4)
  TMS_PIXELSP(9, 4)
  TMS_PIXELSP(10, 5)
  TMS_PIXELSP(11, 5)
  TMS_PIXELSP(12, 6)
  TMS_PIXELSP(13, 6)
  TMS_PIXELSP(14, 7)
  TMS_PIXELSP(15, 7)
}

static void ParseSpritesTMS(int scanline)
{
  struct PicoVideo *pv = &Pico.video;
  unsigned int pack;
  u8 *sat;
  int xoff;
  int sprite_base, addr_mask;
  int zoomed = pv->reg[1] & 0x1; // zoomed sprites
  int i, s, h, m;

  xoff = line_offset;

  sat = (u8 *)PicoMem.vramb + ((pv->reg[5] & 0x7f) << 7);
  if (pv->reg[1] & 2) {
    addr_mask = 0xfc; h = 16;
  } else {
    addr_mask = 0xff; h = 8;
  }
  if (zoomed) h *= 2;
  sprite_base = (pv->reg[6] & 0x7) << 11;

  m = pv->status & SR_C;
  memset(sprites_map, 0, sizeof(sprites_map));
  /* find sprites on this scanline */
  for (i = s = 0; i < 32; i++)
  {
    int x, y;
    y = sat[MEM_LE2(4*i)];
    if (y == 0xd0)
      break;
    if (y >= 0xe0)
      y -= 256;
    y &= ~zoomed;
    if (y + h <= scanline || scanline < y)
      continue; // not on this line
    if (s >= 4) {
      if (scanline >= 0) sprites_status |= SR_SOVR | i;
      if (!(PicoIn.opt & POPT_DIS_SPRITE_LIM) || s >= 32)
        break;
    }
    x = sat[MEM_LE2(4*i+1)] + xoff;
    if (sat[MEM_LE2(4*i+3)] & 0x80)
      x -= 32;

    sprites_c[s] = sat[MEM_LE2(4*i+3)] & 0x0f;
    sprites_x[s] = x;
    sprites_addr[s] = sprite_base + ((sat[MEM_LE2(4*i + 2)] & addr_mask) << 3) +
      ((scanline - y) >> zoomed);
    if (Pico.video.reg[1] & 0x40) {
      // collision detection. Do it here since off-screen lines aren't drawn
      if (sprites_c[s] && x > 0) {
        pack = PicoMem.vramb[MEM_LE2(sprites_addr[s])];
        if (!m) m = CollisionDetect(sprites_map, x, pack, zoomed);
      }
      x += (zoomed ? 16:8);
      if (sprites_c[s] && (pv->reg[1] & 0x2) && x > 0 && x < 8+256) {
        pack = PicoMem.vramb[MEM_LE2(sprites_addr[s]+0x10)];
        if (!m) m = CollisionDetect(sprites_map, x, pack, zoomed);
      }
    }
    s++;
  }
  if (m)
    sprites_status |= SR_C;
  sprites = s;
}

/* Draw sprites into a scanline, max 4 */
static void DrawSpritesTMS(void)
{
  struct PicoVideo *pv = &Pico.video;
  unsigned int pack;
  int zoomed = pv->reg[1] & 0x1; // zoomed sprites
  int s = sprites;

  // now draw all sprites backwards
  for (--s; s >= 0; s--) {
    int x, c, w = (zoomed ? 16: 8);
    x = sprites_x[s];
    c = sprites_c[s];
    // c may be 0 (transparent): sprite invisible
    if (c && x > 0) {
      pack = PicoMem.vramb[MEM_LE2(sprites_addr[s])];
      if (zoomed) TileDoubleSprTMS(x, pack, c);
      else        TileNormSprTMS(x, pack, c);
    }
    if (c && (pv->reg[1] & 0x2) && (x+=w) > 0 && x < 8+256) {
      pack = PicoMem.vramb[MEM_LE2(sprites_addr[s]+0x10)];
      if (zoomed) TileDoubleSprTMS(x, pack, c);
      else        TileNormSprTMS(x, pack, c);
    }
  }
}


/* Mode 1 - Text */
/*===============*/

/* Draw the background into a scanline; cells, dx, tilex, ty merged to reduce registers */
static void DrawStripM1(const u8 *nametab, const u8 *pattab, int cells_dx, int tilex_ty)
{
  // Draw tiles across screen:
  for (; cells_dx >= 0; cells_dx += 6, tilex_ty++, cells_dx -= 0x10000)
  {
    unsigned int pack, pal;
    unsigned code;

    code = nametab[tilex_ty & 0x3f];
    pal  = Pico.video.reg[7];
    pack = pattab[code << 3];
    TileNormBgM1(cells_dx, pack, pal);
  }
}

/* Draw a scanline */
static void DrawDisplayM1(int scanline)
{
  struct PicoVideo *pv = &Pico.video;
  u8 *nametab, *pattab;
  int tilex, dx, cells;
  int cellskip = 0; // XXX
  int maxcells = 40;
  unsigned mask = pv->reg[0] & 0x2 ? 0x2000 : 0x3800; // M3: 2 bits table select

  // name, color, pattern table:
  nametab = PicoMem.vramb + ((pv->reg[2]<<10) & 0x3c00);
  pattab  = PicoMem.vramb + ((pv->reg[4]<<11) & mask);
  pattab += ((scanline>>6) << 11) & ~mask; // table select bits for M3

  nametab += ((scanline>>3) * maxcells);
  pattab  += (scanline & 0x7);

  tilex = cellskip & 0x1f;
  cells = maxcells - cellskip - 1;
  dx = 8 + (cellskip << 3) + line_offset;

  // tiles
  if (!(pv->debug_p & PVD_KILL_B))
    DrawStripM1(nametab, pattab, dx | (cells << 16), tilex | (scanline << 16));
}


/* Mode 2 - Multicolor */
/*=====================*/

/* Draw the background into a scanline; cells, dx, tilex, ty merged to reduce registers */
static void DrawStripM2(const u8 *nametab, const u8 *pattab, int cells_dx, int tilex_ty)
{
  // Draw tiles across screen:
  for (; cells_dx >= 0; cells_dx += 8, tilex_ty++, cells_dx -= 0x10000)
  {
    unsigned int pal;
    unsigned code;

    code = nametab[tilex_ty & 0x1f];
    pal  = pattab[code << 3];
    TileNormBgM2(cells_dx, pal);
  }
}

/* Draw a scanline */
static void DrawDisplayM2(int scanline)
{
  struct PicoVideo *pv = &Pico.video;
  u8 *nametab, *pattab;
  int tilex, dx, cells;
  int cellskip = 0; // XXX
  int maxcells = 32;
  unsigned mask = pv->reg[0] & 0x2 ? 0x2000 : 0x3800; // M3: 2 bits table select

  // name, color, pattern table:
  nametab = PicoMem.vramb + ((pv->reg[2]<<10) & 0x3c00);
  pattab  = PicoMem.vramb + ((pv->reg[4]<<11) & mask);
  pattab += ((scanline>>6) << 11) & ~mask; // table select bits for M3

  nametab += (scanline>>3) << 5;
  pattab  += (scanline>>2) & 0x7;

  tilex = cellskip & 0x1f;
  cells = maxcells - cellskip - 1;
  dx = (cellskip << 3) + line_offset;

  // tiles
  if (!(pv->debug_p & PVD_KILL_B))
    DrawStripM2(nametab, pattab, dx | (cells << 16), tilex | (scanline << 16));

  // sprites
  if (!(pv->debug_p & PVD_KILL_S_LO))
    DrawSpritesTMS();
}


/* Mode 3 - Graphics II */
/*======================*/

/* Draw the background into a scanline; cells, dx, tilex, ty merged to reduce registers */
static void DrawStripM3(const u8 *nametab, const u8 *coltab, const u8 *pattab, int cells_dx, int tilex_ty)
{
  // Draw tiles across screen:
  for (; cells_dx >= 0; cells_dx += 8, tilex_ty++, cells_dx -= 0x10000)
  {
    unsigned int pack, pal;
    unsigned code;

    code = nametab[tilex_ty & 0x1f] << 3;
    pal  = coltab[code];
    pack = pattab[code];
    TileNormBgMg(cells_dx, pack, pal);
  }
}

/* Draw a scanline */
static void DrawDisplayM3(int scanline)
{
  struct PicoVideo *pv = &Pico.video;
  u8 *nametab, *coltab, *pattab;
  int tilex, dx, cells;
  int cellskip = 0; // XXX
  int maxcells = 32;

  // name, color, pattern table:
  nametab = PicoMem.vramb + ((pv->reg[2]<<10) & 0x3c00);
  coltab  = PicoMem.vramb + ((pv->reg[3]<< 6) & 0x2000);
  pattab  = PicoMem.vramb + ((pv->reg[4]<<11) & 0x2000);

  nametab += ((scanline>>3) << 5);
  coltab  += ((scanline>>6) <<11) + (scanline & 0x7);
  pattab  += ((scanline>>6) <<11) + (scanline & 0x7);

  tilex = cellskip & 0x1f;
  cells = maxcells - cellskip - 1;
  dx = (cellskip << 3) + line_offset;

  // tiles
  if (!(pv->debug_p & PVD_KILL_B))
    DrawStripM3(nametab, coltab, pattab, dx | (cells << 16), tilex | (scanline << 16));

  // sprites
  if (!(pv->debug_p & PVD_KILL_S_LO))
    DrawSpritesTMS();
}


/* Mode 0 - Graphics I */
/*=====================*/

/* Draw the background into a scanline; cells, dx, tilex, ty merged to reduce registers */
static void DrawStripM0(const u8 *nametab, const u8 *coltab, const u8 *pattab, int cells_dx, int tilex_ty)
{
  // Draw tiles across screen:
  for (; cells_dx >= 0; cells_dx += 8, tilex_ty++, cells_dx -= 0x10000)
  {
    unsigned int pack, pal;
    unsigned code;

    code = nametab[tilex_ty & 0x1f];
    pal  = coltab[code >> 3];
    pack = pattab[code << 3];
    TileNormBgMg(cells_dx, pack, pal);
  }
}

/* Draw a scanline */
static void DrawDisplayM0(int scanline)
{
  struct PicoVideo *pv = &Pico.video;
  u8 *nametab, *coltab, *pattab;
  int tilex, dx, cells;
  int cellskip = 0; // XXX
  int maxcells = 32;

  // name, color, pattern table:
  nametab = PicoMem.vramb + ((pv->reg[2]<<10) & 0x3c00);
  coltab  = PicoMem.vramb + ((pv->reg[3]<< 6) & 0x3fc0);
  pattab  = PicoMem.vramb + ((pv->reg[4]<<11) & 0x3800);

  nametab += (scanline>>3) << 5;
  pattab  += (scanline & 0x7);

  tilex = cellskip & 0x1f;
  cells = maxcells - cellskip - 1;
  dx = (cellskip << 3) + line_offset;

  // tiles
  if (!(pv->debug_p & PVD_KILL_B))
    DrawStripM0(nametab, coltab, pattab, dx | (cells << 16), tilex | (scanline << 16));

  // sprites
  if (!(pv->debug_p & PVD_KILL_S_LO))
    DrawSpritesTMS();
}


/* Common/global */
/*===============*/

static void FinalizeLineRGB555SMS(int line);
static void FinalizeLine8bitSMS(int line);

void PicoFrameStartSMS(void)
{
  struct PicoEState *est = &Pico.est;
  int lines = 192, columns = 256, loffs, coffs;

  skip_next_line = 0;
  loffs = screen_offset = 24; // 192 lines is really 224 with top/bottom bars
  est->rendstatus = PDRAW_32_COLS;

  // if mode changes make palette dirty since some modes switch to a fixed one
  if (mode != ((Pico.video.reg[0]&0x06) | (Pico.video.reg[1]&0x18))) {
    mode = (Pico.video.reg[0]&0x06) | (Pico.video.reg[1]&0x18);
    Pico.m.dirtyPal = 1;
  }

  Pico.m.hardware &= ~PMS_HW_TMS;
  if (PicoIn.tmsPalette || (PicoIn.AHW & (PAHW_SG|PAHW_SC)))
    Pico.m.hardware |= PMS_HW_TMS;

  // Copy LCD enable flag for easier handling
  Pico.m.hardware &= ~PMS_HW_LCD;
  if ((PicoIn.opt & POPT_EN_GG_LCD) && (PicoIn.AHW & PAHW_GG)) {
    Pico.m.hardware |= PMS_HW_LCD;

    // GG LCD always has 160x144 regardless of settings
    screen_offset = 24; // nonetheless the vdp timing has 224 lines
    loffs = 48;
    lines = 144;
    columns = 160;
  } else {
    if ((mode & 4) && (Pico.video.reg[0] & 0x20)) {
      // SMS mode 4 with 1st column blanked
      est->rendstatus |= PDRAW_SMS_BLANK_1;
      columns = 248;
    }

    switch (mode) {
    // SMS2 only 224/240 line modes, e.g. Micro Machines
    case 0x06|0x08:
        est->rendstatus |= PDRAW_30_ROWS;
        loffs = screen_offset = 0;
        lines = 240;
        break;
    case 0x06|0x10:
        loffs = screen_offset = 8;
        lines = 224;
        break;
    }
  }

  line_offset = 8; // FinalizeLine requires HighCol+8
  // ugh... nonetheless has offset in 8-bit fast mode if 1st col blanked!
  coffs = (FinalizeLineSMS == NULL && columns == 248 ? 8 : 0);
  if (FinalizeLineSMS != NULL && (PicoIn.opt & POPT_EN_SOFTSCALE)) {
    // softscaling always generates 320px, but no scaling in 8bit fast
    est->rendstatus |= PDRAW_SOFTSCALE;
    coffs = 0;
    columns = 320;
  } else if (!(PicoIn.opt & POPT_DIS_32C_BORDER)) {
    est->rendstatus |= PDRAW_BORDER_32;
    line_offset -= coffs;
    coffs = (320-columns) / 2;
    if (FinalizeLineSMS == NULL)
      line_offset += coffs; // ... else centering done in FinalizeLine
  }

  if (est->rendstatus != rendstatus_old || lines != rendlines) {
    // mode_change() might reset rendstatus_old by calling SetOutFormat
    int rendstatus = est->rendstatus;
    emu_video_mode_change(loffs, lines, coffs, columns);
    rendstatus_old = rendstatus;
    rendlines = lines;
    sprites = 0;
  }

  est->HighCol = HighColBase + screen_offset * HighColIncrement;
  est->DrawLineDest = (char *)DrawLineDestBase + screen_offset * DrawLineDestIncrement;

  if (FinalizeLineSMS == FinalizeLine8bitSMS) {
    Pico.m.dirtyPal = (Pico.m.dirtyPal || est->SonicPalCount ? 2 : 0);
    memcpy(est->SonicPal, PicoMem.cram, 0x40*2);
  }
  est->SonicPalCount = 0;
}

void PicoParseSATSMS(int line)
{
  if (Pico.video.reg[0] & 0x04) ParseSpritesM4(line);
  else                          ParseSpritesTMS(line);
}

void PicoLineSMS(int line)
{
  int skip = skip_next_line;
  unsigned bgcolor;

  // GG LCD, render only visible part of screen
  if ((Pico.m.hardware & PMS_HW_LCD) && (line < 24 || line >= 24+144))
    goto norender;

  if (PicoScanBegin != NULL && skip == 0)
    skip = PicoScanBegin(line + screen_offset);

  if (skip) {
    skip_next_line = skip - 1;
    return;
  }

  // Draw screen:
  bgcolor = (Pico.video.reg[7] & 0x0f) | ((Pico.video.reg[0] & 0x04) << 2);
  BackFill(bgcolor, 0, &Pico.est); // bgcolor is from 2nd palette in mode 4
  if (Pico.video.reg[1] & 0x40) {
    if      (Pico.video.reg[0] & 0x04) DrawDisplayM4(line); // also M4+M3
    else if (Pico.video.reg[1] & 0x08) DrawDisplayM2(line); // also M2+M3
    else if (Pico.video.reg[1] & 0x10) DrawDisplayM1(line); // also M1+M3
    else if (Pico.video.reg[0] & 0x02) DrawDisplayM3(line);
    else                               DrawDisplayM0(line);
  }

  if (FinalizeLineSMS != NULL)
    FinalizeLineSMS(line);

  if (PicoScanEnd != NULL)
    skip_next_line = PicoScanEnd(line + screen_offset);

norender:
  Pico.est.HighCol += HighColIncrement;
  Pico.est.DrawLineDest = (char *)Pico.est.DrawLineDest + DrawLineDestIncrement;
}

/* Palette for TMS9918 mode, see https://www.smspower.org/Development/Palette */
// RGB values: #000000 #000000 #21c842 #5edc78 #5455ed #7d76fc #d4524d #42ebf5
//             #fc5554 #ff7978 #d4c154 #e6ce80 #21b03b #c95bba #cccccc #ffffff
static u16 tmspal[] = {
  // SMS palette
  0x0000, 0x0000, 0x00a0, 0x00f0, 0x0a00, 0x0f00, 0x0005, 0x0ff0,
  0x000a, 0x000f, 0x00aa, 0x00ff, 0x0050, 0x0f0f, 0x0aaa, 0x0fff,
  // TMS palette
  0x0000, 0x0000, 0x04c2, 0x07d6, 0x0e55, 0x0f77, 0x055c, 0x0ee4,
  0x055f, 0x077f, 0x05bc, 0x08ce, 0x03a2, 0x0b5c, 0x0ccc, 0x0fff,
  // SMS palette, closer to the TMS one
  0x0000, 0x0000, 0x05f0, 0x05f5, 0x0a50, 0x0f55, 0x055a, 0x0ff0,
  0x055f, 0x0aaf, 0x05aa, 0x05af, 0x00a0, 0x0f5f, 0x0aaa, 0x0fff,
};

void PicoDoHighPal555SMS(void)
{
  u32 *spal = (void *)Pico.est.SonicPal;
  u32 *dpal = (void *)Pico.est.HighPal;
  unsigned int cnt = Pico.est.SonicPalCount+1;
  unsigned int t;
  int i, j;
 
  if (FinalizeLineSMS == FinalizeLineRGB555SMS || Pico.m.dirtyPal == 2)
    Pico.m.dirtyPal = 0;

  // use hardware palette if not in 8bit accurate mode
  if (FinalizeLineSMS != FinalizeLine8bitSMS)
    spal = (void *)PicoMem.cram;

  /* SMS 6 bit cram data was already converted to MD/GG format by vdp write,
   * hence GG/SMS/TMS can all be handled the same here */
  for (j = cnt; j > 0; j--) {
    if (!(Pico.video.reg[0] & 0x4)) // fixed palette in TMS modes
      spal = (u32 *)tmspal + (Pico.m.hardware & PMS_HW_TMS ? 16/2:0);
    for (i = 0x20/2; i > 0; i--, spal++, dpal++) { 
      t = *spal;
#if defined(USE_BGR555)
      t = ((t & 0x000f000f)<<1) | ((t & 0x00f000f0)<<2) | ((t & 0x0f000f00)<<3);
      t |= (t >> 4) & 0x04210421;
#elif defined(USE_BGR565)
      t = ((t & 0x000f000f)<<1) | ((t & 0x00f000f0)<<3) | ((t & 0x0f000f00)<<4);
      t |= (t >> 4) & 0x08610861;
#else
      t = ((t & 0x000f000f)<<12)| ((t & 0x00f000f0)<<3) | ((t & 0x0f000f00)>>7);
      t |= (t >> 4) & 0x08610861;
#endif
      *dpal = t;
    }
    memcpy(dpal, dpal-0x20/2, 0x20*2); // for prio bit
    spal += 0x20/2, dpal += 0x20/2;
  }
  Pico.est.HighPal[0xe0] = 0;
}

static void FinalizeLineRGB555SMS(int line)
{
  if (Pico.m.dirtyPal)
    PicoDoHighPal555SMS();

  // standard FinalizeLine can finish it for us,
  // with features like scaling and such
  FinalizeLine555(0, line, &Pico.est);
}

static void FinalizeLine8bitSMS(int line)
{
  FinalizeLine8bit(0, line, &Pico.est);
}

void PicoDrawSetOutputSMS(pdso_t which)
{
  switch (which)
  {
    case PDF_8BIT:   FinalizeLineSMS = FinalizeLine8bitSMS; break;
    case PDF_RGB555: FinalizeLineSMS = FinalizeLineRGB555SMS; break;
    default:         FinalizeLineSMS = NULL; // no multiple palettes, no scaling
                     PicoDrawSetInternalBuf(Pico.est.Draw2FB, 328); break;
  }
  rendstatus_old = -1;
  mode = -1;
}

// vim:shiftwidth=2:ts=2:expandtab
