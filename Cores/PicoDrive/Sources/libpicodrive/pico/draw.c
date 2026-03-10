/*
 * line renderer
 * (c) Copyright Dave, 2004
 * (C) notaz, 2006-2010
 * (C) irixxxx, 2019-2024
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */
/*
 * The renderer has 4 modes now:
 * - normal
 * - shadow/hilight (s/h)
 * - "sonic mode" for midline palette changes (8bit mode only)
 * - accurate sprites (AS) [+ s/h]
 *
 * s/h uses upper bits for both priority and shadow/hilight flags.
 * "sonic mode" is autodetected, shadow/hilight is enabled by emulated game.
 * AS is enabled by user and takes priority over "sonic mode".
 *
 * since renderer always draws line in 8bit mode, there are 2 spare bits:
 * b \ mode: s/h                    sonic
 * 00        normal                 pal index
 * 01        hilight                pal index
 * 10        shadow                 pal index
 * 11        hilight|shadow=normal  pal index
 *
 * sprite s/h can only be correctly done after the plane rendering s/h state is
 * known since the s/h result changes if there's at least one high prio plane.
 * sprite op rendering is deferred until this is known, and hilight is used as
 * mark since it can't occur before sprite ops:
 * x1        op marker              pal index
 *
 * low prio s/h rendering:
 * - plane and non-op sprite pixels have shadow
 * - s/h sprite op pixel rendering is marked with hilight (deferred)
 * high prio s/h rendering:
 * - plane and non-op sprite pixels are normal
 * - all s/h sprite op pixels (either marked or high prio) are rendered
 *
 * not handled properly:
 * - high prio s/h sprite op overlapping low prio sprite shows sprite, not A,B,G
 * - in debug sprite-masked, transparent high-prio sprite px don't remove shadow
 */

#include "pico_int.h"
#include <platform/common/upscale.h>

#define FORCE	// layer forcing via debug register?

int (*PicoScanBegin)(unsigned int num) = NULL;
int (*PicoScanEnd)  (unsigned int num) = NULL;

static unsigned char DefHighCol[8+320+8];
unsigned char *HighColBase = DefHighCol;
int HighColIncrement;

static u16 DefOutBuff[320*2] ALIGNED(4);
void *DrawLineDestBase = DefOutBuff;
int DrawLineDestIncrement;

static u32 HighCacheA[42*2+1]; // caches for high layers
static u32 HighCacheB[42*2+1];
static s32 HighPreSpr[128*2*2]; // slightly preprocessed sprites (2 banks a 128)
static int HighPreSprBank;

u32 VdpSATCache[2*128];  // VDP sprite cache (1st 32 sprite attr bits)

// NB don't change any defines without checking their usage in ASM

#if defined(USE_BGR555)
#define PXCONV(t)   ((t & 0x000e000e)<< 1) | ((t & 0x00e000e0)<<2) | ((t & 0x0e000e00)<<3)
#define PXMASKL     0x04210421  // 0x0c630c63, LSB for all colours
#define PXMASKH     0x39ce39ce  // 0x3def3def, all but MSB for all colours
#elif defined(USE_BGR565)
#define PXCONV(t)   ((t & 0x000e000e)<< 1) | ((t & 0x00e000e0)<<3) | ((t & 0x0e000e00)<<4)
#define PXMASKL     0x08610861  // 0x18e318e3
#define PXMASKH     0x738e738e  // 0x7bef7bef
#else // RGB565
#define PXCONV(t)   ((t & 0x000e000e)<<12) | ((t & 0x00e000e0)<<3) | ((t & 0x0e000e00)>>7)
#define PXMASKL     0x08610861  // 0x18e318e3
#define PXMASKH     0x738e738e  // 0x7bef7bef
#endif

#define LF_PLANE   (1 << 0) // must be = 1
#define LF_SH      (1 << 1) // must be = 2
//#define LF_FORCE   (1 << 2)
#define LF_LINE    (1 << 3) // layer covers line
#define LF_LPRIO   (1 << 8) // line has low prio tiles

#define LF_PLANE_A 0
#define LF_PLANE_B 1

#define SPRL_HAVE_HI     0x80 // have hi priority sprites
#define SPRL_HAVE_LO     0x40 // *lo*
#define SPRL_MAY_HAVE_OP 0x20 // may have operator sprites on the line
#define SPRL_LO_ABOVE_HI 0x10 // low priority sprites may be on top of hi
#define SPRL_HAVE_X      0x08 // have sprites with x != 0
#define SPRL_TILE_OVFL   0x04 // tile limit exceeded on previous line
#define SPRL_HAVE_MASK0  0x02 // have sprite with x == 0 in 1st slot
#define SPRL_MASKED      0x01 // lo prio masking by sprite with x == 0 active

// sprite cache. stores results of sprite parsing for each display line:
// [visible_sprites_count, sprl_flags, tile_count, sprites_processed, sprite_idx[sprite_count], last_width]
unsigned char HighLnSpr[240][4+MAX_LINE_SPRITES+1];

int rendstatus_old;
int rendlines;

static int skip_next_line=0;

struct TileStrip
{
  int nametab; // Position in VRAM of name table (for this tile line)
  int line;    // Line number in pixels 0x000-0x3ff within the virtual tilemap
  int hscroll; // Horizontal scroll value in pixels for the line
  int xmask;   // X-Mask (0x1f - 0x7f) for horizontal wraparound in the tilemap
  u32 *hc;     // cache for high tile codes and their positions
  int cells;   // cells (tiles) to draw (32 col mode doesn't need to update whole 320)
};

// stuff available in asm:
#ifdef _ASM_DRAW_C
void DrawWindow(int tstart, int tend, int prio, int sh,
                struct PicoEState *est);
void DrawAllSprites(unsigned char *sprited, int prio, int sh,
                    struct PicoEState *est);
void DrawTilesFromCache(u32 *hc, int sh, int rlim,
                    struct PicoEState *est);
void DrawSpritesSHi(unsigned char *sprited, struct PicoEState *est);
void DrawLayer(int plane_sh, u32 *hcache, int cellskip, int maxcells,
               struct PicoEState *est);
void *blockcpy(void *dst, const void *src, size_t n);
void blockcpy_or(void *dst, void *src, size_t n, int pat);
#else
// utility
void blockcpy_or(void *dst, void *src, size_t n, int pat)
{
  unsigned char *pd = dst, *ps = src;
  if (dst > src) {
    for (pd += n, ps += n; n; n--)
      *--pd = (unsigned char) (*--ps | pat);
  } else
    for (; n; n--)
      *pd++ = (unsigned char) (*ps++ | pat);
}
#define blockcpy memmove
#endif

#define TileNormMaker_(pix_func,ret)                         \
{                                                            \
  unsigned char t;                                           \
                                                             \
  t = (pack&0x0000f000)>>12; pix_func(0);                    \
  t = (pack&0x00000f00)>> 8; pix_func(1);                    \
  t = (pack&0x000000f0)>> 4; pix_func(2);                    \
  t = (pack&0x0000000f)    ; pix_func(3);                    \
  t = (pack&0xf0000000)>>28; pix_func(4);                    \
  t = (pack&0x0f000000)>>24; pix_func(5);                    \
  t = (pack&0x00f00000)>>20; pix_func(6);                    \
  t = (pack&0x000f0000)>>16; pix_func(7);                    \
  return ret;                                                \
}

#define TileFlipMaker_(pix_func,ret)                         \
{                                                            \
  unsigned char t;                                           \
                                                             \
  t = (pack&0x000f0000)>>16; pix_func(0);                    \
  t = (pack&0x00f00000)>>20; pix_func(1);                    \
  t = (pack&0x0f000000)>>24; pix_func(2);                    \
  t = (pack&0xf0000000)>>28; pix_func(3);                    \
  t = (pack&0x0000000f)    ; pix_func(4);                    \
  t = (pack&0x000000f0)>> 4; pix_func(5);                    \
  t = (pack&0x00000f00)>> 8; pix_func(6);                    \
  t = (pack&0x0000f000)>>12; pix_func(7);                    \
  return ret;                                                \
}

#define TileNormMaker(funcname, pix_func) \
static void funcname(unsigned char *pd, unsigned int pack, unsigned char pal) \
TileNormMaker_(pix_func,)

#define TileFlipMaker(funcname, pix_func) \
static void funcname(unsigned char *pd, unsigned int pack, unsigned char pal) \
TileFlipMaker_(pix_func,)

#define TileNormMakerAS(funcname, pix_func) \
static unsigned funcname(unsigned m, unsigned char *pd, unsigned int pack, unsigned char pal) \
TileNormMaker_(pix_func,m)

#define TileFlipMakerAS(funcname, pix_func) \
static unsigned funcname(unsigned m, unsigned char *pd, unsigned int pack, unsigned char pal) \
TileFlipMaker_(pix_func,m)

// draw layer or non-s/h sprite pixels (no operator colors)
#define pix_just_write(x) \
  if (likely(t)) pd[x]=pal|t

TileNormMaker(TileNorm, pix_just_write)
TileFlipMaker(TileFlip, pix_just_write)

#ifndef _ASM_DRAW_C

// draw low prio sprite non-s/h pixels in s/h mode
#define pix_nonsh(x) \
  if (likely(t)) { \
    pd[x]=pal|t; \
    if (unlikely(t==0xe)) pd[x]&=~0x80; /* disable shadow for color 14 (hw bug?) */ \
  }

TileNormMaker(TileNormNonSH, pix_nonsh)
TileFlipMaker(TileFlipNonSH, pix_nonsh)

// draw sprite pixels, process operator colors
#define pix_sh(x) \
  if (likely(t)) \
    pd[x]=(likely(t<0xe) ? pal|t : pd[x]|((t-1)<<6))

TileNormMaker(TileNormSH, pix_sh)
TileFlipMaker(TileFlipSH, pix_sh)

// draw sprite pixels, mark but don't process operator colors
#define pix_sh_markop(x) \
  if (likely(t)) \
    pd[x]=(likely(t<0xe) ? pal|t : pd[x]|0x40)

TileNormMaker(TileNormSH_markop, pix_sh_markop)
TileFlipMaker(TileFlipSH_markop, pix_sh_markop)

#endif

// draw low prio sprite operator pixels if visible (i.e. marked)
#define pix_sh_onlyop(x) \
  if (unlikely(t>=0xe && (pd[x]&0x40))) \
    pd[x]=(pd[x]&~0x40)|((t-1)<<6)

#ifndef _ASM_DRAW_C

TileNormMaker(TileNormSH_onlyop_lp, pix_sh_onlyop)
TileFlipMaker(TileFlipSH_onlyop_lp, pix_sh_onlyop)

#endif

// AS: sprite mask bits in m shifted to bits 8-15, see DrawSpritesHiAS

// draw high prio sprite pixels (AS)
#define pix_as(x) \
  if (likely(t && (m & (1<<(x+8))))) \
    m &= ~(1<<(x+8)), pd[x] = pal|t

TileNormMakerAS(TileNormAS, pix_as)
TileFlipMakerAS(TileFlipAS, pix_as)

// draw high prio sprite pixels, process operator colors (AS)
// NB sprite+planes: h+s->n, h+[nh]->h, s+[nhs]->s, hence mask h before op
#define pix_sh_as(x) \
  if (likely(t && (m & (1<<(x+8))))) { \
    m &= ~(1<<(x+8)); \
    pd[x]=(likely(t<0xe) ? pal|t : (pd[x]&~0x40)|((t-1)<<6)); \
  }

TileNormMakerAS(TileNormSH_AS, pix_sh_as)
TileFlipMakerAS(TileFlipSH_AS, pix_sh_as)

// draw only sprite operator pixels (AS)
#define pix_sh_as_onlyop(x) \
  if (likely(t && (m & (1<<(x+8))))) { \
    m &= ~(1<<(x+8)); \
    pix_sh_onlyop(x); \
  }

TileNormMakerAS(TileNormSH_AS_onlyop_lp, pix_sh_as_onlyop)
TileFlipMakerAS(TileFlipSH_AS_onlyop_lp, pix_sh_as_onlyop)

// mark low prio sprite pixels (AS)
#define pix_sh_as_onlymark(x) \
  if (likely(t)) m &= ~(1<<(x+8))

TileNormMakerAS(TileNormAS_onlymark, pix_sh_as_onlymark)
TileFlipMakerAS(TileFlipAS_onlymark, pix_sh_as_onlymark)

#ifdef FORCE
// NB s/h already resolved by non-forced drawing
// forced both layer draw (through debug reg)
#define pix_and(x) \
  pd[x] &= pal|t

TileNormMaker(TileNorm_and, pix_and)
TileFlipMaker(TileFlip_and, pix_and)

// forced sprite draw (through debug reg)
#define pix_sh_as_and(x) \
  if (likely(m & (1<<(x+8)))) { \
    m &= ~(1<<(x+8)); \
    /* if (!t) pd[x] |= 0x40; as per titan hw notes? */ \
    pd[x] &= pal|t; \
  }

TileNormMakerAS(TileNormSH_AS_and, pix_sh_as_and)
TileFlipMakerAS(TileFlipSH_AS_and, pix_sh_as_and)
#endif

// --------------------------------------------

#define DrawTile(mask,yshift,ymask,hpcode,cache) {			\
  if (code!=oldcode) {							\
    oldcode = code;							\
									\
    pack = 0;								\
    if (code != blank) {						\
      /* Get tile address/2: */						\
      u32 addr = ((code<<yshift)&0x7ff0) + ty;				\
      if (code & 0x1000) addr ^= ymask<<1; /* Y-flip */			\
									\
      pal = ((code>>9)&0x30) | sh; /* shadow */				\
      pack = CPU_LE2(*(u32 *)(PicoMem.vram + addr));			\
      if (!pack)							\
        blank = code;							\
    }									\
  }									\
  if (cache && (code & 0x8000)) { /* (un-forced) high priority tile */	\
    if (sh | (pack&mask)) {						\
      code = hpcode | (dx<<16);						\
      if (code & 0x1000) code ^= ymask<<(26+1); /* Y-flip */		\
      *hc++ = code; *hc++ = pack&mask; /* cache it */			\
    }									\
  } else {								\
    if (cache) lflags |= LF_LPRIO;					\
    if (pack&mask) {							\
      if (code & 0x0800) TileFlip(pd + dx, pack&mask, pal);		\
      else               TileNorm(pd + dx, pack&mask, pal);		\
    }									\
  }									\
}

#define DrawStripMaker(funcname,yshift,ymask,hpcode,drawtile,cache)	\
void funcname(struct TileStrip *ts, int lflags, int cellskip)		\
{									\
  unsigned char *pd = Pico.est.HighCol;					\
  u32 *hc = ts->hc;							\
  int tilex, dx, ty, cells;						\
  u32 code, oldcode = -1, blank = -1; /* The tile we know is blank */	\
  u32 pal = 0, pack = 0, sh, mask = ~0;					\
									\
  /* Draw tiles across screen: */					\
  sh = (lflags & LF_SH) << 6; /* shadow */				\
  tilex=((-ts->hscroll)>>3)+cellskip;					\
  ty=(ts->line&ymask)<<1; /* Y-Offset into tile */			\
  dx=((ts->hscroll-1)&7)+1;						\
  cells = ts->cells - cellskip;						\
  dx+=cellskip<<3;							\
									\
/*  int force = (plane_sh&LF_FORCE) << 13; */				\
  if (dx & 7) {								\
    code = PicoMem.vram[ts->nametab + (tilex & ts->xmask)];		\
/*    code &= ~force; *//* forced always draw everything */		\
									\
    mask = 0xffffffff<<((dx&7)*4);					\
    if (code & 0x0800) mask = 0xffffffff>>((dx&7)*4);			\
    mask = (~mask << 16) | (~mask >> 16);				\
									\
    drawtile(mask,yshift,ymask,hpcode | (ty<<26) | (1<<25),cache);	\
    dx += 8, tilex++, cells--;						\
  }									\
									\
  for (; cells > 0; dx+=8, tilex++, cells--)				\
  {									\
    code = PicoMem.vram[ts->nametab + (tilex & ts->xmask)];		\
/*    code &= ~force; *//* forced always draw everything */		\
									\
    if (code != blank || ((code & 0x8000) && sh))			\
      drawtile(~0,yshift,ymask,hpcode | (ty<<26),cache);		\
  }									\
									\
  if (dx & 7) {								\
    code = PicoMem.vram[ts->nametab + (tilex & ts->xmask)];		\
/*    code &= ~force; *//* forced always draw everything */		\
									\
    if (code != blank || ((code & 0x8000) && sh)) {			\
      mask = 0xffffffff<<((dx&7)*4);					\
      if (code & 0x0800) mask = 0xffffffff>>((dx&7)*4);			\
      mask = (mask << 16) | (mask >> 16);				\
									\
      drawtile(mask,yshift,ymask,hpcode | (ty<<26) | (1<<25),cache);	\
    }									\
  }									\
									\
  /* terminate the cache list */					\
  if (cache) *hc = 0;							\
									\
  /* if oldcode wasn't changed, it means all layer is hi priority */	\
  if (cache && (lflags & (LF_LINE|LF_LPRIO)) == LF_LINE) Pico.est.rendstatus |= PDRAW_PLANE_HI_PRIO; \
}

#ifndef _ASM_DRAW_C
static DrawStripMaker(DrawStrip, 4, 0x7, code, DrawTile, 1);

static
#endif
       DrawStripMaker(DrawStripInterlace, 5, 0xf, (code&0xfc00) | ((code&0x3ff)<<1), DrawTile, 1);

// this is messy
#define DrawStripVSRamMaker(funcname,yshift,ymask,hpcode,drawtile,cache) \
void funcname(struct TileStrip *ts, int lflags, int cellskip)		\
{									\
  unsigned char *pd = Pico.est.HighCol;					\
  u32 *hc = ts->hc;							\
  int tilex, dx, ty = 0, cell = 0, nametabadd = 0;			\
  u32 code, oldcode = -1, blank = -1; /* The tile we know is blank */	\
  u32 pal = 0, pack = 0, sh, plane, mask;				\
  int scan = Pico.est.DrawScanline<<(yshift-4);				\
									\
  /* Draw tiles across screen: */					\
  sh = (lflags & LF_SH) << 6; /* shadow */				\
  plane = (lflags & LF_PLANE); /* plane to draw */			\
  tilex=(-ts->hscroll)>>3;						\
  dx=((ts->hscroll-1)&7)+1;						\
  if (ts->hscroll & 0x0f) {						\
    int adj = ((ts->hscroll ^ dx) >> 3) & 1;				\
    cell -= adj + 1;							\
    ts->cells -= adj;							\
    PicoMem.vsram[0x3e] = PicoMem.vsram[0x3f] = lflags >> 16;		\
  }									\
  cell+=cellskip;							\
  tilex+=cellskip;							\
  dx+=cellskip<<3;							\
									\
/*  int force = (lflags&LF_FORCE) << 13; */				\
  if ((cell&1)==1 || (dx&7)) {						\
    int line,vscroll;							\
    vscroll = PicoMem.vsram[plane + (cell&0x3e)];			\
									\
    /* Find the line in the name table */				\
    line=(vscroll+scan)&(u16)ts->line;    /* ts->line is really ymask, */ \
    nametabadd=(line>>(yshift-1))<<(ts->line>>24); /* and shift[width] */ \
    ty=((line<<(yshift-4))&ymask)<<1; /* Y-Offset into tile */		\
  }									\
  if (dx & 7) {								\
    code = PicoMem.vram[ts->nametab + nametabadd + (tilex & ts->xmask)]; \
    code |= ty<<26; /* add ty since that can change pixel row for every 2nd tile */ \
/*    code &= ~force; *//* forced always draw everything */		\
									\
    mask = 0xffffffff<<((dx&7)*4);					\
    if (code & 0x0800) mask = 0xffffffff>>((dx&7)*4);			\
    mask = (~mask << 16) | (~mask >> 16);				\
									\
    drawtile(mask,yshift,ymask,hpcode | (1<<25),cache);			\
									\
    dx += 8, tilex++, cell++;						\
  }									\
  for (; cell < ts->cells; dx+=8,tilex++,cell++)			\
  {									\
    if ((cell&1)==0)							\
    {									\
      int line,vscroll;							\
      vscroll = PicoMem.vsram[plane + (cell&0x3e)];			\
									\
      /* Find the line in the name table */				\
      line=(vscroll+scan)&(u16)ts->line;    /* ts->line is really ymask, */ \
      nametabadd=(line>>(yshift-1))<<(ts->line>>24); /* and shift[width] */ \
      ty=((line<<(yshift-4))&ymask)<<1; /* Y-Offset into tile */	\
    }									\
									\
    code = PicoMem.vram[ts->nametab + nametabadd + (tilex & ts->xmask)]; \
    code |= ty<<26; /* add ty since that can change pixel row for every 2nd tile */ \
/*    code &= ~force; *//* forced always draw everything */		\
									\
    if (code != blank || ((code & 0x8000) && sh))			\
      drawtile(~0,yshift,ymask,hpcode,cache);				\
  }									\
  if (dx & 7) {								\
    if ((cell&1)==0)							\
    {									\
      int line,vscroll;							\
      vscroll = PicoMem.vsram[plane + (cell&0x3e)];			\
									\
      /* Find the line in the name table */				\
      line=(vscroll+scan)&(u16)ts->line;    /* ts->line is really ymask, */ \
      nametabadd=(line>>(yshift-1))<<(ts->line>>24); /* and shift[width] */ \
      ty=((line<<(yshift-4))&ymask)<<1; /* Y-Offset into tile */	\
    }									\
									\
    code = PicoMem.vram[ts->nametab + nametabadd + (tilex & ts->xmask)]; \
    code |= ty<<26; /* add ty since that can change pixel row for every 2nd tile */ \
/*    code &= ~force; *//* forced always draw everything */		\
									\
    if (code != blank || ((code & 0x8000) && sh)) {			\
      mask = 0xffffffff<<((dx&7)*4);					\
      if (code & 0x0800) mask = 0xffffffff>>((dx&7)*4);			\
      mask = (mask << 16) | (mask >> 16);				\
									\
      drawtile(mask,yshift,ymask,hpcode | (1<<25),cache);		\
    }									\
  }									\
									\
  /* terminate the cache list */					\
  if (cache) *hc = 0;							\
									\
  if (cache && (lflags & (LF_LINE|LF_LPRIO)) == LF_LINE) Pico.est.rendstatus |= PDRAW_PLANE_HI_PRIO; \
}

#ifndef _ASM_DRAW_C
static DrawStripVSRamMaker(DrawStripVSRam, 4, 0x7, code, DrawTile, 1);

static
#endif
       DrawStripVSRamMaker(DrawStripVSRamInterlace, 5, 0xf, (code&0xfc00) | ((code&0x3ff)<<1), DrawTile, 1);

// --------------------------------------------

#define DrawLayerMaker(funcname,drawstrip,drawstripinterlace,drawstripvsram,drawstripvsraminterlace) \
void funcname(int plane_sh, u32 *hcache, int cellskip, int maxcells, struct PicoEState *est) \
{									\
  struct PicoVideo *pvid=&est->Pico->video;				\
  const char shift[4]={5,6,5,7}; /* 32,64 or 128 sized tilemaps (2 is invalid) */ \
  struct TileStrip ts;							\
  int width, height, ymask;						\
  int vscroll, htab;							\
									\
  ts.hc=hcache;								\
  ts.cells=maxcells;							\
									\
  /* Work out the TileStrip to draw */					\
									\
  /* Work out the name table size: 32 64 or 128 tiles (0-3) */		\
  width=pvid->reg[16];							\
  height=(width>>4)&3; width&=3;					\
									\
  ts.xmask=(1<<shift[width])-1; /* X Mask in tiles (0x1f-0x7f) */	\
  ymask=(height<<8)|0xff;       /* Y Mask in pixels */			\
  switch (width) {							\
    case 1: ymask &= 0x1ff; break;					\
    case 2: ymask =  0x007; break;					\
    case 3: ymask =  0x0ff; break;					\
  }									\
									\
  /* Find name table: */						\
  if (plane_sh&LF_PLANE) ts.nametab=(pvid->reg[4]&0x07)<<12; /* B */	\
  else                   ts.nametab=(pvid->reg[2]&0x38)<< 9; /* A */	\
									\
  htab=pvid->reg[13]<<9; /* Horizontal scroll table address */		\
  switch (pvid->reg[11]&3) {						\
    case 1: htab += (est->DrawScanline<<1) &  0x0f; break;		\
    case 2: htab += (est->DrawScanline<<1) & ~0x0f; break; /* Offset by tile */ \
    case 3: htab += (est->DrawScanline<<1);         break; /* Offset by line */ \
  }									\
  htab+=plane_sh&LF_PLANE; /* A or B */					\
									\
  /* Get horizontal scroll value, will be masked later */		\
  ts.hscroll = PicoMem.vram[htab & 0x7fff];				\
									\
  if (likely(!(pvid->reg[11]&4))) {					\
    vscroll = PicoMem.vsram[plane_sh&LF_PLANE]; /* Get vertical scroll value */ \
									\
    if(likely((pvid->reg[12]&6) != 6)) {				\
      /* Find the line in the name table */				\
      ts.line=(vscroll+est->DrawScanline)&ymask;			\
      ts.nametab+=(ts.line>>3)<<shift[width];				\
									\
      drawstrip(&ts, plane_sh, cellskip);				\
    } else {								\
      /* interlace mode 2 */						\
									\
      /* Find the line in the name table */				\
      ts.line=(vscroll+(est->DrawScanline<<1))&((ymask<<1)|1);		\
      ts.nametab+=(ts.line>>4)<<shift[width];				\
									\
      drawstripinterlace(&ts, plane_sh, cellskip);			\
    }									\
  } else {								\
    /* shit, we have 2-cell column based vscroll */			\
    /* luckily this doesn't happen too often */				\
									\
    /* vscroll value for leftmost cells in case of hscroll not on 16px boundary */ \
    /* NB it's unclear what exactly the hw is doing. Continue reading where it */ \
    /* stopped last seems to work best (H40: 0x50 (wrap->0x00), H32 0x40). */ \
    plane_sh |= PicoMem.vsram[(pvid->reg[12]&1?0x00:0x20) + (plane_sh&LF_PLANE)] << 16; \
									\
    if (likely((pvid->reg[12]&6) != 6)) {				\
      ts.line=ymask|(shift[width]<<24); /* save some stuff instead of line */ \
      drawstripvsram(&ts, plane_sh, cellskip);				\
    } else {								\
      ts.line=(ymask<<1)|1|(shift[width]<<24); /* save some stuff instead of line */ \
      drawstripvsraminterlace(&ts, plane_sh, cellskip);			\
    }									\
  }									\
}

#ifndef _ASM_DRAW_C
static DrawLayerMaker(DrawLayer,DrawStrip,DrawStripInterlace,DrawStripVSRam,DrawStripVSRamInterlace);

// --------------------------------------------

// tstart & tend are tile pair numbers
static void DrawWindow(int tstart, int tend, int prio, int sh,
                       struct PicoEState *est)
{
  unsigned char *pd = est->HighCol;
  struct PicoVideo *pvid = &est->Pico->video;
  int tilex,ty,nametab,code,oldcode=-1,blank=-1; // The tile we know is blank
  int yshift,ymask;
  u32 pack;
  u32 *hc=NULL, lflags=0; // referenced in DrawTile

  yshift = 4, ymask = 0x7;
  if(likely((pvid->reg[12]&6) == 6))
    yshift = 5, ymask = 0xf;
  ty=((est->DrawScanline<<(yshift-4))&ymask)<<1; // Y-Offset into tile

  // Find name table line:
  if (pvid->reg[12]&1)
  {
    nametab=(pvid->reg[3]&0x3c)<<9; // 40-cell mode
    nametab+=(est->DrawScanline>>(yshift-1))<<6;
  }
  else
  {
    nametab=(pvid->reg[3]&0x3e)<<9; // 32-cell mode
    nametab+=(est->DrawScanline>>(yshift-1))<<5;
  }

  if (prio && !(est->rendstatus & PDRAW_WND_DIFF_PRIO)) {
    // all tiles processed in low prio pass
    return;
  }

  tilex=tstart<<1;
  tend<<=1;

  // Draw tiles across screen:
  if (!sh)
  {
    for (; tilex < tend; tilex++)
    {
      int dx, pal;

      code = PicoMem.vram[nametab + tilex];
      if ((code>>15) != prio) {
        est->rendstatus |= PDRAW_WND_DIFF_PRIO;
        continue;
      }
      if (code==blank) continue;

      dx = 8 + (tilex << 3);

      DrawTile(~0,yshift,ymask,code,0);
    }
  }
  else
  {
    for (; tilex < tend; tilex++)
    {
      int dx, pal;

      code = PicoMem.vram[nametab + tilex];
      if((code>>15) != prio) {
        est->rendstatus |= PDRAW_WND_DIFF_PRIO;
        continue;
      }

      pal=((code>>9)&0x30);

      if (prio) {
        int *zb = (int *)(est->HighCol+8+(tilex<<3));
        *zb++ &= 0x7f7f7f7f;
        *zb   &= 0x7f7f7f7f;
      } else {
        pal |= 0x80;
      }
      if(code==blank) continue;
      dx = 8 + (tilex << 3);

      DrawTile(~0,yshift,ymask,code,0);
    }
  }
}

// --------------------------------------------

static void DrawTilesFromCache(u32 *hc, int sh, int rlim, struct PicoEState *est)
{
  unsigned char *pd = est->HighCol;
  u32 code, dx, pack;
  int pal, hs;

  // *ts->hc++ = code | (dx<<16) | (ty<<26); // cache it

  if (sh && (est->rendstatus & (PDRAW_SHHI_DONE|PDRAW_PLANE_HI_PRIO)))
  {
    if (!(est->rendstatus & PDRAW_SHHI_DONE)) {
      // as some layer has covered whole line with hi priority tiles,
      // we can process whole line and then act as if sh/hi mode was off,
      // but leave lo pri op sprite markers alone
      int *zb = (int *)(Pico.est.HighCol+8);
      int c = 320 / 4;
      while (c--)
      {
        *zb++ &= 0x7f7f7f7f;
      }
      Pico.est.rendstatus |= PDRAW_SHHI_DONE;
    }
    sh = 0;
  }

  if (!sh)
  {
    while ((code=*hc++)) {
      pack = *hc++;
      dx = (code >> 16) & 0x1ff;
      pal = ((code >> 9) & 0x30);

      if (code & 0x0800) TileFlip(pd + dx, pack, pal);
      else               TileNorm(pd + dx, pack, pal);
    }
  }
  else
  {
    while ((code=*hc++)) {
      unsigned char *zb;

      pack = *hc++;
      dx = (code >> 16) & 0x1ff;
      pal = ((code >> 9) & 0x30);

      zb = est->HighCol+dx;
      if (likely(~code & (1<<25))) {
        *zb++ &= 0x7f; *zb++ &= 0x7f; *zb++ &= 0x7f; *zb++ &= 0x7f;
        *zb++ &= 0x7f; *zb++ &= 0x7f; *zb++ &= 0x7f; *zb++ &= 0x7f;
      } else {
        hs = dx & 7;
        if (*hc == 0) // last tile?
          switch (8-hs) { case 7: *zb++ &= 0x7f;
            case 6: *zb++ &= 0x7f; case 5: *zb++ &= 0x7f; case 4: *zb++ &= 0x7f;
            case 3: *zb++ &= 0x7f; case 2: *zb++ &= 0x7f; case 1: *zb++ &= 0x7f;
          }
        else { // first tile
          zb += 8-hs;
          switch (hs) { case 7: *zb++ &= 0x7f;
            case 6: *zb++ &= 0x7f; case 5: *zb++ &= 0x7f; case 4: *zb++ &= 0x7f;
            case 3: *zb++ &= 0x7f; case 2: *zb++ &= 0x7f; case 1: *zb++ &= 0x7f;
          }
        }
      }

      if (pack) {
        if (code & 0x0800) TileFlip(pd + dx, pack, pal);
        else               TileNorm(pd + dx, pack, pal);
      }
    }
  }
}

// --------------------------------------------

// Index + 0  :    hhhhvvvv ab--hhvv yyyyyyyy yyyyyyyy // a: offscreen h, b: offs. v, h: horiz. size
// Index + 4  :    xxxxxxxx xxxxxxxx pccvhnnn nnnnnnnn // x: x coord + 8

static void DrawSprite(s32 *sprite, int sh, int w)
{
  void (*fTileFunc)(unsigned char *pd, unsigned int pack, unsigned char pal);
  unsigned char *pd = Pico.est.HighCol;
  int width=0,height=0;
  int row=0;
  s32 code=0;
  int pal;
  int tile=0,delta=0;
  int sx, sy;

  // parse the sprite data
  sy=sprite[0];
  code=sprite[1];
  sx=code>>16; // X
  width=sy>>28;
  height=(sy>>24)&7; // Width and height in tiles
  sy=(s16)sy; // Y

  row=Pico.est.DrawScanline-sy; // Row of the sprite we are on

  if (code&0x1000) row=(height<<3)-1-row; // Flip Y

  tile=code + (row>>3); // Tile number increases going down
  delta=height; // Delta to increase tile by going right
  if (code&0x0800) { tile+=delta*(width-1); delta=-delta; } // Flip X

  tile &= 0x7ff; tile<<=4; tile+=(row&7)<<1; // Tile address
  delta<<=4; // Delta of address

  pal=(code>>9)&0x30;
  pal|=sh<<7; // shadow

  if (sh && (code&0x6000) == 0x6000) {
    if(code&0x0800) fTileFunc=TileFlipSH_markop;
    else            fTileFunc=TileNormSH_markop;
  } else if (sh) {
    if(code&0x0800) fTileFunc=TileFlipNonSH;
    else            fTileFunc=TileNormNonSH;
  } else {
    if(code&0x0800) fTileFunc=TileFlip;
    else            fTileFunc=TileNorm;
  }

  if (w) width = w; // tile limit
  for (; width; width--,sx+=8,tile+=delta)
  {
    unsigned int pack;

    if(sx<=0)   continue;
    if(sx>=328) break; // Offscreen

    pack = CPU_LE2(*(u32 *)(PicoMem.vram + (tile & 0x7fff)));
    fTileFunc(pd + sx, pack, pal);
  }
}
#endif

static void DrawSpriteInterlace(u32 *sprite)
{
  unsigned char *pd = Pico.est.HighCol;
  int width=0,height=0;
  int row=0,code=0;
  int pal;
  int tile=0,delta=0;
  int sx, sy;

  // parse the sprite data
  sy=CPU_LE2(sprite[0]);
  height=sy>>24;
  sy=(sy&0x3ff)-0x100; // Y
  width=(height>>2)&3; height&=3;
  width++; height++; // Width and height in tiles

  row=(Pico.est.DrawScanline<<1)-sy; // Row of the sprite we are on

  code=CPU_LE2(sprite[1]);
  sx=((code>>16)&0x1ff)-0x78; // X

  if (code&0x1000) row^=(16<<height)-1; // Flip Y

  tile=code&0x3ff; // Tile number
  tile+=row>>4; // Tile number increases going down
  delta=height; // Delta to increase tile by going right
  if (code&0x0800) { tile+=delta*(width-1); delta=-delta; } // Flip X

  tile<<=5; tile+=(row&15)<<1; // Tile address

  delta<<=5; // Delta of address
  pal=((code>>9)&0x30); // Get palette pointer

  for (; width; width--,sx+=8,tile+=delta)
  {
    unsigned int pack;

    if(sx<=0)   continue;
    if(sx>=328) break; // Offscreen

    pack = CPU_LE2(*(u32 *)(PicoMem.vram + (tile & 0x7fff)));
    if (code & 0x0800) TileFlip(pd + sx, pack, pal);
    else               TileNorm(pd + sx, pack, pal);
  }
}


static NOINLINE void DrawAllSpritesInterlace(int pri, int sh)
{
  struct PicoVideo *pvid=&Pico.video;
  int i,u,table,link=0,sline=Pico.est.DrawScanline<<1;
  u32 *sprites[80]; // Sprite index
  int max_sprites = pvid->reg[12]&1 ? 80 : 64;

  table=pvid->reg[5]&0x7f;
  if (pvid->reg[12]&1) table&=0x7e; // Lowest bit 0 in 40-cell mode
  table<<=8; // Get sprite table address/2

  for (i = u = 0; u < max_sprites && link < max_sprites; u++)
  {
    u32 *sprite;
    int code, sx, sy, height;

    sprite=(u32 *)(PicoMem.vram+((table+(link<<2))&0x7ffc)); // Find sprite

    // get sprite info
    code = CPU_LE2(sprite[0]);
    sx = CPU_LE2(sprite[1]);
    if(((sx>>15)&1) != pri) goto nextsprite; // wrong priority sprite

    // check if it is on this line
    sy = (code&0x3ff)-0x100;
    height = (((code>>24)&3)+1)<<4;
    if((sline < sy) | (sline >= sy+height)) goto nextsprite; // no

    // check if sprite is not hidden offscreen
    sx = (sx>>16)&0x1ff;
    sx -= 0x78; // Get X coordinate + 8
    if((sx <= -8*3) | (sx >= 328)) goto nextsprite;

    // sprite is good, save it's pointer
    sprites[i++]=sprite;

    nextsprite:
    // Find next sprite
    link=(code>>16)&0x7f;
    if(!link) break; // End of sprites
  }

  // Go through sprites backwards:
  for (i-- ;i>=0; i--)
    DrawSpriteInterlace(sprites[i]);
}


#ifndef _ASM_DRAW_C
/*
 * s/h drawing: lo_layers|40, lo_sprites|40 && mark_op,
 *        hi_layers&=~40, hi_sprites
 *
 * Index + 0  :    hhhhvvvv ----hhvv yyyyyyyy yyyyyyyy // v, h: vert./horiz. size
 * Index + 4  :    xxxxxxxx xxxxxxxx pccvhnnn nnnnnnnn // x: x coord + 8
 */
static void DrawSpritesSHi(unsigned char *sprited, const struct PicoEState *est)
{
  static void (*tilefuncs[2][2][2])(unsigned char *, unsigned, unsigned char) = {
    { {NULL,                 NULL},                 {TileNorm,   TileFlip} },
    { {TileNormSH_onlyop_lp, TileFlipSH_onlyop_lp}, {TileNormSH, TileFlipSH} }
  }; // [sh?][hi?][flip?]
  void (*fTileFunc)(unsigned char *pd, unsigned int pack, unsigned char pal);
  unsigned char *pd = Pico.est.HighCol;
  unsigned char *p;
  int cnt, w;

  cnt = sprited[0] & 0x7f;
  if (cnt == 0) return;

  p = &sprited[4];
  if ((sprited[1] & (SPRL_TILE_OVFL|SPRL_HAVE_MASK0)) == (SPRL_TILE_OVFL|SPRL_HAVE_MASK0))
    return; // masking effective due to tile overflow

  // Go through sprites backwards:
  w = p[cnt]; // possibly clipped width of last sprite
  for (cnt--; cnt >= 0; cnt--, w = 0)
  {
    s32 *sprite, code;
    int pal, tile, sx, sy;
    int offs, delta, width, height, row;

    offs = (p[cnt] & 0x7f) * 2;
    sprite = est->HighPreSpr + offs;
    code = sprite[1];
    pal = (code>>9)&0x30;

    fTileFunc = tilefuncs[pal == 0x30][!!(code & 0x8000)][!!(code & 0x800)];
    if (fTileFunc == NULL) continue; // non-operator low sprite, already drawn

    // parse remaining sprite data
    sy=sprite[0];
    sx=code>>16; // X
    width=sy>>28;
    height=(sy>>24)&7; // Width and height in tiles
    sy=(s16)sy; // Y

    row=est->DrawScanline-sy; // Row of the sprite we are on

    if (code&0x1000) row=(height<<3)-1-row; // Flip Y

    tile=code + (row>>3); // Tile number increases going down
    delta=height; // Delta to increase tile by going right
    if (code&0x0800) { tile+=delta*(width-1); delta=-delta; } // Flip X

    tile &= 0x7ff; tile<<=4; tile+=(row&7)<<1; // Tile address
    delta<<=4; // Delta of address

    if (w) width = w; // tile limit
    for (; width; width--,sx+=8,tile+=delta)
    {
      unsigned int pack;

      if(sx<=0)   continue;
      if(sx>=328) break; // Offscreen

      pack = CPU_LE2(*(u32 *)(PicoMem.vram + (tile & 0x7fff)));
      fTileFunc(pd + sx, pack, pal);
    }
  }
}
#endif // !_ASM_DRAW_C

static void DrawSpritesHiAS(unsigned char *sprited, int sh)
{
  static unsigned (*tilefuncs[2][2][2])(unsigned, unsigned char *, unsigned, unsigned char) = {
    { {TileNormAS_onlymark,     TileFlipAS_onlymark},     {TileNormAS,    TileFlipAS} },
    { {TileNormSH_AS_onlyop_lp, TileFlipSH_AS_onlyop_lp}, {TileNormSH_AS, TileFlipSH_AS} }
  }; // [sh?][hi?][flip?]
  unsigned (*fTileFunc)(unsigned m, unsigned char *pd, unsigned int pack, unsigned char pal);
  unsigned char *pd = Pico.est.HighCol;
  unsigned char mb[sizeof(DefHighCol)/8];
  unsigned char *p, *mp;
  unsigned m;
  int entry, cnt;

  cnt = sprited[0] & 0x7f;
  if (cnt == 0) return;

  memset(mb, 0xff, sizeof(mb));
  p = &sprited[4];
  if ((sprited[1] & (SPRL_TILE_OVFL|SPRL_HAVE_MASK0)) == (SPRL_TILE_OVFL|SPRL_HAVE_MASK0))
    return; // masking effective due to tile overflow

  // Go through sprites:
  for (entry = 0; entry < cnt; entry++)
  {
    s32 *sprite, code;
    int pal, tile, sx, sy;
    int offs, delta, width, height, row;

    offs = (p[entry] & 0x7f) * 2;
    sprite = Pico.est.HighPreSpr + offs;
    code = sprite[1];
    pal = (code>>9)&0x30;

    fTileFunc = tilefuncs[(sh && pal == 0x30)][!!(code&0x8000)][!!(code&0x800)];

    // parse remaining sprite data
    sy=sprite[0];
    sx=code>>16; // X
    width=sy>>28;
    height=(sy>>24)&7; // Width and height in tiles
    sy=(s16)sy; // Y

    row=Pico.est.DrawScanline-sy; // Row of the sprite we are on

    if (code&0x1000) row=(height<<3)-1-row; // Flip Y

    tile=code + (row>>3); // Tile number increases going down
    delta=height; // Delta to increase tile by going right
    if (code&0x0800) { tile+=delta*(width-1); delta=-delta; } // Flip X

    tile &= 0x7ff; tile<<=4; tile+=(row&7)<<1; // Tile address
    delta<<=4; // Delta of address

    if (entry+1 == cnt) width = p[entry+1]; // last sprite width limited?
    while (sx <= 0 && width) width--, sx+=8, tile+=delta; // Offscreen
    mp = mb+(sx>>3);
    for (m = *mp; width; width--, sx+=8, tile+=delta, *mp++ = m, m >>= 8)
    {
      unsigned int pack;

      if(sx>=328) break; // Offscreen

      pack = CPU_LE2(*(u32 *)(PicoMem.vram + (tile & 0x7fff)));

      m |= mp[1] << 8; // next mask byte
      // shift mask bits to bits 8-15 for easier load/store handling
      m = fTileFunc(m << (8-(sx&0x7)), pd + sx, pack, pal) >> (8-(sx&0x7));
    } 
    *mp = m; // write last mask byte
  }
}

#ifdef FORCE
// NB lots of duplicate code, all for the sake of a small performance gain.

// Forced tile drawing, without any masking and blank handling
#define DrawTileForced(mask,yshift,ymask,hpcode,cache) {		\
    if (code!=oldcode) {						\
      oldcode = code;							\
									\
      /* Get tile address/2: */						\
      u32 addr = ((code<<yshift)&0x7ff0) + ty;				\
      if (code & 0x1000) addr ^= ymask<<1; /* Y-flip */			\
									\
      pal = ((code>>9)&0x30);						\
      pal |= 0xc0; /* leave s/h bits untouched in pixel "and" */	\
									\
      pack = CPU_LE2(*(u32 *)(PicoMem.vram + addr));			\
    }									\
    if (code & 0x0800) TileFlip_and(pd + dx, pack, pal);		\
    else               TileNorm_and(pd + dx, pack, pal);		\
}

static DrawStripMaker(DrawStripForced, 4, 0x7, 0, DrawTileForced, 0);

static DrawStripMaker(DrawStripInterlaceForced, 5, 0xf, 0, DrawTileForced, 0);

static DrawStripVSRamMaker(DrawStripVSRamForced, 4, 0x7, 0, DrawTileForced, 0);

static DrawStripVSRamMaker(DrawStripVSRamInterlaceForced, 5, 0xf, 0, DrawTileForced, 0);

static DrawLayerMaker(DrawLayerForced,DrawStripForced,DrawStripInterlaceForced,DrawStripVSRamForced,DrawStripVSRamInterlaceForced);

static void DrawSpritesForced(unsigned char *sprited)
{
  unsigned (*fTileFunc)(unsigned m, unsigned char *pd, unsigned int pack, unsigned char pal);
  unsigned char *pd = Pico.est.HighCol;
  unsigned char mb[sizeof(DefHighCol)/8];
  unsigned char *p, *mp;
  unsigned m;
  int entry, cnt;

  cnt = sprited[0] & 0x7f;
  if (cnt == 0) { memset(pd, 0, sizeof(DefHighCol)); return; }

  memset(mb, 0xff, sizeof(mb));
  p = &sprited[4];
  if ((sprited[1] & (SPRL_TILE_OVFL|SPRL_HAVE_MASK0)) == (SPRL_TILE_OVFL|SPRL_HAVE_MASK0))
    return; // masking effective due to tile overflow

  // Go through sprites:
  for (entry = 0; entry < cnt; entry++)
  {
    s32 *sprite, code;
    int pal, tile, sx, sy;
    int offs, delta, width, height, row;

    offs = (p[entry] & 0x7f) * 2;
    sprite = Pico.est.HighPreSpr + offs;
    code = sprite[1];
    pal = (code>>9)&0x30;
    pal |= 0xc0; // leave s/h bits untouched in pixel "and"

    if (code&0x800) fTileFunc = TileFlipSH_AS_and;
    else            fTileFunc = TileNormSH_AS_and;

    // parse remaining sprite data
    sy=sprite[0];
    sx=code>>16; // X
    width=sy>>28;
    height=(sy>>24)&7; // Width and height in tiles
    sy=(s16)sy; // Y

    row=Pico.est.DrawScanline-sy; // Row of the sprite we are on

    if (code&0x1000) row=(height<<3)-1-row; // Flip Y

    tile=code + (row>>3); // Tile number increases going down
    delta=height; // Delta to increase tile by going right
    if (code&0x0800) { tile+=delta*(width-1); delta=-delta; } // Flip X

    tile &= 0x7ff; tile<<=4; tile+=(row&7)<<1; // Tile address
    delta<<=4; // Delta of address

    if (entry+1 == cnt) width = p[entry+1]; // last sprite width limited?
    while (sx <= 0 && width) width--, sx+=8, tile+=delta; // Offscreen
    mp = mb+(sx>>3);
    for (m = *mp; width; width--, sx+=8, tile+=delta, *mp++ = m, m >>= 8)
    {
      u32 pack;

      if(sx>=328) break; // Offscreen

      pack = CPU_LE2(*(u32 *)(PicoMem.vram + (tile & 0x7fff)));

      m |= mp[1] << 8; // next mask byte
      // shift mask bits to bits 8-15 for easier load/store handling
      m = fTileFunc(m << (8-(sx&0x7)), pd + sx, pack, pal) >> (8-(sx&0x7));
    } 
    *mp = m; // write last mask byte
  }

  // anything not covered by a sprite is off 
  // TODO Titan hw notes say that transparent pixels remove shadow. Is this also
  // the case in areas where no sprites are displayed?
  for (cnt = 1; cnt < sizeof(mb)-1; cnt++)
    if (mb[cnt] == 0xff) {
      *(u32 *)(pd+8*cnt+0) = 0;
      *(u32 *)(pd+8*cnt+4) = 0;
    } else if (mb[cnt])
      for (m = 0; m < 8; m++)
        if (mb[cnt] & (1<<m))
          pd[8*cnt+m] = 0;
}
#endif


// sprite info in SAT:
// Index + 0  :    ----hhvv -lllllll -------y yyyyyyyy
// Index + 4  :    -------x xxxxxxxx pccvhnnn nnnnnnnn
// sprite info in HighPreSpr:
// Index + 0  :    hhhhvvvv -lllllll yyyyyyyy yyyyyyyy // v/h size, link, y
// Index + 4  :    xxxxxxxx xxxxxxxx pccvhnnn nnnnnnnn // x+8, prio, palette, flip, tile

// Sprite parsing 1 line in advance: determine sprites on line by Y pos
static NOINLINE void ParseSprites(int max_lines, int limit)
{
  const struct PicoEState *est=&Pico.est;
  const struct PicoVideo *pvid=&est->Pico->video;
  int u,link=0,sh;
  int table=0;
  s32 *pd = HighPreSpr + HighPreSprBank*2;
  int max_sprites = 80, max_width = 328;
  int max_line_sprites = 20; // 20 sprites, 40 tiles

  // SAT scanning is one line ahead, but don't overshoot. Technically, SAT
  // parsing for line 0 is on the last line of the previous frame.
  int first_line = est->DrawScanline + !!est->DrawScanline;
  if (max_lines > rendlines-1)
    max_lines = rendlines-1;

  // look-ahead SAT parsing for next line and sprite pixel fetching for current
  // line are limited if display was disabled during HBLANK before current line
  if (limit) limit = 16; // max sprites/pixels processed

  if (!(pvid->reg[12]&1))
    max_sprites = 64, max_line_sprites = 16, max_width = 264;
  if (*est->PicoOpt & POPT_DIS_SPRITE_LIM)
    max_line_sprites = MAX_LINE_SPRITES;

  sh = pvid->reg[0xC]&8; // shadow/hilight?

  table=pvid->reg[5]&0x7f;
  if (pvid->reg[12]&1) table&=0x7e; // Lowest bit 0 in 40-cell mode
  table<<=8; // Get sprite table address/2

  for (u = first_line; u <= max_lines; u++)
    *((int *)&HighLnSpr[u][0]) = 0;

  for (u = 0; u < max_sprites && link < max_sprites; u++)
  {
    u32 *sprite;
    int code, code2, sx, sy, hv, height, width;

    sprite=(u32 *)(PicoMem.vram+((table+(link<<2))&0x7ffc)); // Find sprite

    // parse sprite info. the 1st half comes from the VDPs internal cache,
    // the 2nd half is read from VRAM
    code = CPU_LE2(VdpSATCache[2*link]); // normally same as sprite[0]
    sy = (code&0x1ff)-0x80;
    hv = (code>>24)&0xf;
    height = (hv&3)+1;
    width  = (hv>>2)+1;

    code2 = CPU_LE2(sprite[1]);
    sx = (code2>>16)&0x1ff;
    sx -= 0x78; // Get X coordinate + 8

    if (sy <= max_lines && sy + (height<<3) >= first_line) // sprite onscreen (y)?
    {
      int entry, y, w, sx_min, onscr_x, maybe_op = 0;
      // omit look-ahead line if sprite parsing limit reached
      int last_line = (limit && u >= 2*limit ? max_lines-1 : max_lines);

      sx_min = 8-(width<<3);
      onscr_x = sx_min < sx && sx < max_width;
      if (sh && (code2 & 0x6000) == 0x6000)
        maybe_op = SPRL_MAY_HAVE_OP;

      entry = (((pd - HighPreSpr) / 2) & 0x7f) | ((code2>>8)&0x80);
      y = (sy >= first_line) ? sy : first_line;
      for (; y < sy + (height<<3) && y <= last_line; y++)
      {
        unsigned char *p = &HighLnSpr[y][0];
        int cnt = p[0] & 0x7f;
        if (p[1] & SPRL_MASKED) continue;               // masked?

        if (p[3] >= max_line_sprites) continue;         // sprite limit?
        p[3] ++;

        w = width;
        if (p[2] + width > max_line_sprites*2) {        // tile limit?
          if (y+1 < 240) HighLnSpr[y+1][1] |= SPRL_TILE_OVFL;
          if (p[2] >= max_line_sprites*2) continue;
          w = max_line_sprites*2 - p[2];
        }
        p[2] += w;

        if (sx == -0x78) {
          if (p[1] & (SPRL_HAVE_X|SPRL_TILE_OVFL))
            p[1] |= SPRL_MASKED; // masked, no more sprites for this line
          if (!(p[1] & SPRL_HAVE_X) && cnt == 0)
            p[1] |= SPRL_HAVE_MASK0; // 1st sprite is masking
        } else
          p[1] |= SPRL_HAVE_X;

        if (!onscr_x) continue; // offscreen x

        // sprite is (partly) visible, store info for renderer
        p[1] |= (entry & 0x80) ? SPRL_HAVE_HI : SPRL_HAVE_LO;
        p[1] |= maybe_op; // there might be op sprites on this line
        if (cnt > 0 && (code2 & 0x8000) && !(p[4+cnt-1]&0x80))
          p[1] |= SPRL_LO_ABOVE_HI;

        p[4+cnt] = entry;
        p[5+cnt] = w; // width clipped by tile limit for sprite renderer
        p[0] = (cnt + 1) | HighPreSprBank;
      }
    }

    *pd++ = (width<<28)|(height<<24)|(link<<16)|((u16)sy);
    *pd++ = (sx<<16)|((u16)code2);

    // Find next sprite
    link=(code>>16)&0x7f;
    if (!link) break; // End of sprites
  }
  *pd = 0;

  // fetching sprite pixels isn't done while display is disabled during HBLANK
  if (limit) {
    int w = 0;
    unsigned char *sprited = &HighLnSpr[max_lines-1][0]; // current render line

    for (u = 0; u < (sprited[0] & 0x7f); u++) {
      s32 *sp = HighPreSpr + (sprited[4+u] & 0x7f) * 2 + HighPreSprBank*2;
      int sw = sp[0] >> 28;
      if (w + sw > limit) {
        sprited[0] = u | HighPreSprBank;
        sprited[4+u] = limit-w;
        break;
      }
      w += sw;
    }
  }

#if 0
  for (u = first_line; u <= max_lines; u++)
  {
    int y;
    printf("c%03i b%d: f %x c %2i/%2i w %2i: ", u, !!HighPreSprBank, HighLnSpr[u][1],
           HighLnSpr[u][0] & 0x7f, HighLnSpr[u][3], HighLnSpr[u][2]);
    for (y = 0; y < (HighLnSpr[u][0] & 0x7f); y++) {
      s32 *sp = HighPreSpr + (HighLnSpr[u][y+4]&0x7f) * 2 + HighPreSprBank*2;
      printf(" %i(%x/%x)", HighLnSpr[u][y+4],sp[0],sp[1]);
    }
    printf("\n");
  }
#endif

  HighPreSprBank ^= 0x80;
}

#ifndef _ASM_DRAW_C
static void DrawAllSprites(unsigned char *sprited, int prio, int sh,
                           struct PicoEState *est)
{
  unsigned char *p;
  int cnt, w;

  cnt = sprited[0] & 0x7f;
  if (cnt == 0) return;

  p = &sprited[4];
  if ((sprited[1] & (SPRL_TILE_OVFL|SPRL_HAVE_MASK0)) == (SPRL_TILE_OVFL|SPRL_HAVE_MASK0))
    return; // masking effective due to tile overflow

  // Go through sprites backwards:
  w = p[cnt]; // possibly clipped width of last sprite
  for (cnt--; cnt >= 0; cnt--, w = 0)
  {
    s32 *sp = est->HighPreSpr + (p[cnt]&0x7f) * 2;
    if ((p[cnt] >> 7) != prio) continue;
    DrawSprite(sp, sh, w);
  }
}


// --------------------------------------------

void BackFill(int bgc, int sh, struct PicoEState *est)
{
  u32 back = bgc;

  // Start with a blank scanline (background colour):
  back|=sh<<7; // shadow
  back|=back<<8;
  back|=back<<16;

  memset32((int *)(est->HighCol+8), back, 320/4);
}
#endif

// --------------------------------------------

static u16 *BgcDMAbase;
static u32 BgcDMAsrc, BgcDMAmask;
static int BgcDMAlen, BgcDMAoffs;

#ifndef _ASM_DRAW_C
static
#endif
// handle DMA to background color
void BgcDMA(struct PicoEState *est)
{
  u16 *pd=est->DrawLineDest;
  int len = (est->Pico->video.reg[12]&1) ? 320 : 256;
  // TODO for now handles the line as all background.
  int xl = (len == 320 ? 38 : 33); // DMA slots during HSYNC
  int upscale = (est->rendstatus & PDRAW_SOFTSCALE) && len < 320;
  u16 *q = upscale ? DefOutBuff : pd;
  int i, l = len;
  u16 t;

  if ((est->rendstatus & PDRAW_BORDER_32) && !upscale)
    q += (320-len) / 2;

  BgcDMAlen -= ((l-BgcDMAoffs)>>1)+xl;
  if (BgcDMAlen <= 0) {
    // partial line
    l += 2*BgcDMAlen;
    est->rendstatus &= ~PDRAW_BGC_DMA;
  }

  for (i = BgcDMAoffs; i < l; i += 2) {
    // TODO use ps to overwrite only real bg pixels
    t = BgcDMAbase[BgcDMAsrc++ & BgcDMAmask];
    q[i] = q[i+1] = PXCONV(t);
  }
  BgcDMAsrc += xl; // HSYNC DMA
  BgcDMAoffs = 0;

  t = PXCONV(PicoMem.cram[Pico.video.reg[7] & 0x3f]);
  while (i < len) q[i++] = t; // fill partial line with BG

  if (upscale) {
    switch (PicoIn.filter) {
    case 3: h_upscale_bl4_4_5(pd, 320, q, 256, len, f_nop); break;
    case 2: h_upscale_bl2_4_5(pd, 320, q, 256, len, f_nop); break;
    case 1: h_upscale_snn_4_5(pd, 320, q, 256, len, f_nop); break;
    default: h_upscale_nn_4_5(pd, 320, q, 256, len, f_nop); break;
    }
  }
}

// --------------------------------------------

static void PicoDoHighPal555_8bit(int sh, int line, struct PicoEState *est)
{
  unsigned int *spal, *dpal;
  unsigned int cnt = (sh ? 1 : est->SonicPalCount+1);
  unsigned int t, i;

  // reset dirty only if there are no outstanding changes
  if (est->Pico->m.dirtyPal == 2)
    est->Pico->m.dirtyPal = 0;

  // In Sonic render mode palettes were backuped in SonicPal
  spal = (void *)est->SonicPal;
  dpal = (void *)est->HighPal;

  // additional palettes stored after in-frame changes
  for (i = 0; i < cnt * 0x40 / 2; i++) {
    t = spal[i];
    // treat it like it was 4-bit per channel, since in s/h mode it somewhat is that.
    // otherwise intensity difference between this and s/h will be wrong
    t = PXCONV(t);
    t |= (t >> 4) & PXMASKL;
    dpal[i] = t;
  }

  // norm: xxx0, sh: 0xxx, hi: 0xxx + 7
  if (sh)
  {
    // shadowed pixels
    for (i = 0; i < 0x40 / 2; i++) {
      dpal[0xc0/2 + i] = dpal[i];
      dpal[0x80/2 + i] = (dpal[i] >> 1) & PXMASKH;
    }
    // hilighted pixels
    for (i = 0; i < 0x40 / 2; i++) {
      t = ((dpal[i] >> 1) & PXMASKH) + PXMASKH;
      t |= (t >> 4) & PXMASKL;
      dpal[0x40/2 + i] = t;
    }
  }
}

#ifndef _ASM_DRAW_C
void PicoDoHighPal555(int sh, int line, struct PicoEState *est)
{
  unsigned int *spal, *dpal;
  unsigned int t, i;

  est->Pico->m.dirtyPal = 0;

  spal = (void *)PicoMem.cram;
  dpal = (void *)est->HighPal;

  for (i = 0; i < 0x40 / 2; i++) {
    t = spal[i];
    // treat it like it was 4-bit per channel, since in s/h mode it somewhat is that.
    // otherwise intensity difference between this and s/h will be wrong
    t = PXCONV(t);
    t |= (t >> 4) & PXMASKL;
    dpal[i] = dpal[0xc0/2 + i] = t;
  }

  // norm: xxx0, sh: 0xxx, hi: 0xxx + 7
  if (sh)
  {
    // shadowed pixels
    for (i = 0; i < 0x40 / 2; i++)
      dpal[0x80/2 + i] = (dpal[i] >> 1) & PXMASKH;
    // hilighted pixels
    for (i = 0; i < 0x40 / 2; i++) {
      t = ((dpal[i] >> 1) & PXMASKH) + PXMASKH;
      t |= (t >> 4) & PXMASKL;
      dpal[0x40/2 + i] = t;
    }
  }
}

void FinalizeLine555(int sh, int line, struct PicoEState *est)
{
  unsigned short *pd=est->DrawLineDest;
  unsigned char  *ps=est->HighCol+8;
  unsigned short *pal=est->HighPal;
  int len;

  if (DrawLineDestIncrement == 0)
    return;

  if (est->rendstatus & PDRAW_BGC_DMA)
    return BgcDMA(est);

  PicoDrawUpdateHighPal();

  len = 256;
  if (!(PicoIn.AHW & PAHW_8BIT) && (est->Pico->video.reg[12]&1))
    len = 320;
  else if ((PicoIn.AHW & PAHW_GG) && (est->Pico->m.hardware & PMS_HW_LCD))
    len = 160;
  else if ((PicoIn.AHW & PAHW_SMS) && (est->Pico->video.reg[0] & 0x20))
    len -= 8, ps += 8;

  if ((est->rendstatus & PDRAW_SOFTSCALE) && len < 320) {
    if (len >= 240 && len <= 256) {
      pd += (256-len)>>1;
      switch (PicoIn.filter) {
      case 3: h_upscale_bl4_4_5(pd, 320, ps, 256, len, f_pal); break;
      case 2: h_upscale_bl2_4_5(pd, 320, ps, 256, len, f_pal); break;
      case 1: h_upscale_snn_4_5(pd, 320, ps, 256, len, f_pal); break;
      default: h_upscale_nn_4_5(pd, 320, ps, 256, len, f_pal); break;
      }
      if (est->rendstatus & PDRAW_32X_SCALE) { // 32X needs scaled CLUT data
        unsigned char *psc = ps - 256, *pdc = psc;
        rh_upscale_nn_4_5(pdc, 320, psc, 256, 256, f_nop);
      }
    } else if (len == 160)
      switch (PicoIn.filter) {
      case 3:
      case 2: h_upscale_bl2_1_2(pd, 320, ps, 160, len, f_pal); break;
      default: h_upscale_nn_1_2(pd, 320, ps, 160, len, f_pal); break;
      }
  } else {
    if ((est->rendstatus & PDRAW_BORDER_32) && len < 320)
      pd += (320-len) / 2;
#if 1
    h_copy(pd, 320, ps, 320, len, f_pal);
#else
    extern void amips_clut(unsigned short *dst, unsigned char *src, unsigned short *pal, int count);
    extern void amips_clut_6bit(unsigned short *dst, unsigned char *src, unsigned short *pal, int count);
    if (!sh)
         amips_clut_6bit(pd, ps, pal, len);
    else amips_clut(pd, ps, pal, len);
#endif
  }
}
#endif

void FinalizeLine8bit(int sh, int line, struct PicoEState *est)
{
  unsigned char *pd = est->DrawLineDest;
  unsigned char *ps = est->HighCol+8;
  int len;
  static int dirty_line;

  // a hack for mid-frame palette changes
  if (est->Pico->m.dirtyPal == 1)
  {
    // store a maximum of 3 additional palettes in SonicPal
    if (est->SonicPalCount < 3 &&
        (!(est->rendstatus & PDRAW_SONIC_MODE) || (line - dirty_line >= 4))) {
      est->SonicPalCount ++;
      dirty_line = line;
      est->rendstatus |= PDRAW_SONIC_MODE;
    }
    blockcpy(est->SonicPal+est->SonicPalCount*0x40, PicoMem.cram, 0x40*2);
    est->Pico->m.dirtyPal = 2;
  }

  len = 256;
  if (!(PicoIn.AHW & PAHW_8BIT) && (est->Pico->video.reg[12]&1))
    len = 320;
  else if ((PicoIn.AHW & PAHW_GG) && (est->Pico->m.hardware & PMS_HW_LCD))
    len = 160;
  else if ((PicoIn.AHW & PAHW_SMS) && (est->Pico->video.reg[0] & 0x20))
    len -= 8, ps += 8;

  if (DrawLineDestIncrement == 0)
    pd = est->HighCol+8;

  if ((est->rendstatus  & PDRAW_SOFTSCALE) && len < 320) {
    unsigned char pal = 0;

    if (!sh && (est->rendstatus & PDRAW_SONIC_MODE))
      pal = est->SonicPalCount*0x40;
    // Smoothing can't be used with CLUT, hence it's always Nearest Neighbour.
    if (len >= 240)
      // use reverse version since src and dest ptr may be the same.
      rh_upscale_nn_4_5(pd, 320, ps, 256, len, f_or);
    else
      rh_upscale_nn_1_2(pd, 320, ps, 256, len, f_or);
  } else {
    if ((est->rendstatus & PDRAW_BORDER_32) && len < 320)
      pd += (320-len) / 2;
    if (!sh && (est->rendstatus & PDRAW_SONIC_MODE))
      // select active backup palette
      blockcpy_or(pd, ps, len, est->SonicPalCount*0x40);
    else if (pd != ps)
      blockcpy(pd, ps, len);
  }
}

static void (*FinalizeLine)(int sh, int line, struct PicoEState *est);

// --------------------------------------------

static int DrawDisplay(int sh)
{
  struct PicoEState *est=&Pico.est;
  unsigned char *sprited = &HighLnSpr[est->DrawScanline][0];
  struct PicoVideo *pvid=&est->Pico->video;
  int win=0, edge=0, hvwind=0, lflags;
  int maxw, maxcells;

  est->rendstatus &= ~(PDRAW_SHHI_DONE|PDRAW_PLANE_HI_PRIO|PDRAW_WND_DIFF_PRIO);
  est->HighPreSpr = HighPreSpr + (sprited[0]&0x80)*2;

  if (pvid->reg[12]&1) {
    maxw = 320; maxcells = 40;
  } else {
    maxw = 256; maxcells = 32;
  }

  // Find out if the window is on this line:
  win=pvid->reg[0x12];
  edge=(win&0x1f)<<3;

  if (win&0x80) { if (est->DrawScanline>=edge) hvwind=1; }
  else          { if (est->DrawScanline< edge) hvwind=1; }

  if (!hvwind) // we might have a vertical window here
  {
    win=pvid->reg[0x11];
    edge=win&0x1f;
    if (win&0x80) {
      if (!edge) hvwind=1;
      else if(edge < (maxcells>>1)) hvwind=2;
    } else {
      if (!edge);
      else if(edge < (maxcells>>1)) hvwind=2;
      else hvwind=1;
    }
  }

  /* - layer B low - */
  if (!(pvid->debug_p & PVD_KILL_B)) {
    lflags = LF_PLANE_B | (sh<<1);
    DrawLayer(lflags | LF_LINE, HighCacheB, 0, maxcells, est);
  }
  /* - layer A low - */
  lflags = LF_PLANE_A | (sh<<1);
  if (pvid->debug_p & PVD_KILL_A)
    ;
  else if (hvwind == 1)
    DrawWindow(0, maxcells>>1, 0, sh, est);
  else if (hvwind == 2) {
    DrawLayer(lflags, HighCacheA, (win&0x80) ?    0 : edge<<1, (win&0x80) ?     edge<<1 : maxcells, est);
    DrawWindow(                   (win&0x80) ? edge :       0, (win&0x80) ? maxcells>>1 : edge, 0, sh, est);
  }
  else
    DrawLayer(lflags | LF_LINE, HighCacheA, 0, maxcells, est);
  /* - sprites low - */
  if (pvid->debug_p & PVD_KILL_S_LO)
    ;
  else if (est->rendstatus & PDRAW_INTERLACE)
    DrawAllSpritesInterlace(0, sh);
  else if (sprited[1] & SPRL_HAVE_LO)
    DrawAllSprites(sprited, 0, sh, est);

  /* - layer B hi - */
  if (!(pvid->debug_p & PVD_KILL_B) && HighCacheB[0])
    DrawTilesFromCache(HighCacheB, sh, maxw, est);
  /* - layer A hi - */
  if (pvid->debug_p & PVD_KILL_A)
    ;
  else if (hvwind == 1)
    DrawWindow(0, maxcells>>1, 1, sh, est);
  else if (hvwind == 2) {
    if (HighCacheA[0])
      DrawTilesFromCache(HighCacheA, sh, (win&0x80) ? edge<<4 : maxw, est);
    DrawWindow((win&0x80) ? edge : 0, (win&0x80) ? maxcells>>1 : edge, 1, sh, est);
  } else
    if (HighCacheA[0])
      DrawTilesFromCache(HighCacheA, sh, maxw, est);
  /* - sprites hi - */
  if (pvid->debug_p & PVD_KILL_S_HI)
    ;
  else if (est->rendstatus & PDRAW_INTERLACE)
    DrawAllSpritesInterlace(1, sh);
  // have sprites without layer pri bit ontop of sprites with that bit
  else if ((sprited[1] & SPRL_LO_ABOVE_HI) && (*est->PicoOpt & POPT_ACC_SPRITES))
    DrawSpritesHiAS(sprited, sh);
  else if (sh && (sprited[1] & SPRL_MAY_HAVE_OP))
    DrawSpritesSHi(sprited, est);
  else if (sprited[1] & SPRL_HAVE_HI)
    DrawAllSprites(sprited, 1, 0, est);

#ifdef FORCE
  if (pvid->debug_p & PVD_FORCE_B) {
    lflags = LF_PLANE_B | (sh<<1);
    DrawLayerForced(lflags, NULL, 0, maxcells, est);
  } else if (pvid->debug_p & PVD_FORCE_A) {
    // TODO what happens in windowed mode? 
    lflags = LF_PLANE_A | (sh<<1);
    DrawLayerForced(lflags, NULL, 0, maxcells, est);
  } else if (pvid->debug_p & PVD_FORCE_S)
    DrawSpritesForced(sprited);
#endif

#if 0
  {
    int *c, a, b;
    for (a = 0, c = HighCacheA; *c; c+=2, a++);
    for (b = 0, c = HighCacheB; *c; c+=2, b++);
    printf("%i:%03i: a=%i, b=%i\n", Pico.m.frame_count,
           est->DrawScanline, a, b);
  }
#endif

  return 0;
}

// MUST be called every frame
PICO_INTERNAL void PicoFrameStart(void)
{
  struct PicoEState *est = &Pico.est;
  int loffs = 8, lines = 224, coffs = 0, columns = 320;
  int sprep = est->rendstatus & PDRAW_DIRTY_SPRITES;
  int skipped = est->rendstatus & PDRAW_SKIP_FRAME;
  int sync = est->rendstatus & (PDRAW_SYNC_NEEDED | PDRAW_SYNC_NEXT);

  // prepare to do this frame
  est->rendstatus = 0;

  if (PicoIn.AHW & PAHW_32X) // H32 upscaling, before mixing in 32X layer
    est->rendstatus = (*est->PicoOpt & POPT_ALT_RENDERER) ?
                PDRAW_BORDER_32 : PDRAW_32X_SCALE|PDRAW_SOFTSCALE;
  else if (!(PicoIn.opt & POPT_DIS_32C_BORDER))
    est->rendstatus |= PDRAW_BORDER_32;

  if ((PicoIn.opt & POPT_EN_SOFTSCALE) && !(*est->PicoOpt & POPT_ALT_RENDERER))
    est->rendstatus |= PDRAW_SOFTSCALE;

  if ((est->Pico->video.reg[12] & 6) == 6)
    est->rendstatus |= PDRAW_INTERLACE; // interlace mode
  if (!(est->Pico->video.reg[12] & 1)) {
    est->rendstatus |= PDRAW_32_COLS;
    if (!(est->rendstatus & PDRAW_SOFTSCALE)) {
      columns = 256;
      coffs = 32;
    }
  }
  if (est->Pico->video.reg[1] & 8) {
    est->rendstatus |= PDRAW_30_ROWS;
    lines = 240;
    loffs = 0;
  }
  if (!(est->rendstatus & PDRAW_BORDER_32))
    coffs = 0;

  if (est->rendstatus != rendstatus_old || lines != rendlines) {
    rendlines = lines;
    // mode_change() might reset rendstatus_old by calling SetOutFormat
    int rendstatus = est->rendstatus;
    emu_video_mode_change(loffs, lines, coffs, columns);
    rendstatus_old = rendstatus;
    // mode_change() might clear buffers, redraw needed
    est->rendstatus |= PDRAW_SYNC_NEEDED;
  }

  if (sync | skipped)
    est->rendstatus |= PDRAW_SYNC_NEEDED;
  if (PicoIn.skipFrame) // preserve this until something is rendered at last
    est->rendstatus |= PDRAW_SKIP_FRAME;
  if (sprep | skipped)
    est->rendstatus |= PDRAW_PARSE_SPRITES;

  est->HighCol = HighColBase + loffs * HighColIncrement;
  est->DrawLineDest = (char *)DrawLineDestBase + loffs * DrawLineDestIncrement;
  est->DrawScanline = 0;
  skip_next_line = 0;

  if (FinalizeLine == FinalizeLine8bit) {
    // make a backup of the current palette in case Sonic mode is detected later
    est->Pico->m.dirtyPal = (est->Pico->m.dirtyPal || est->SonicPalCount ? 2 : 0);
    blockcpy(est->SonicPal, PicoMem.cram, 0x40*2);
  }
  est->SonicPalCount = 0;
}

static void DrawBlankedLine(int line, int offs, int sh, int bgc)
{
  struct PicoEState *est = &Pico.est;
  int skip = skip_next_line;

  if (PicoScanBegin != NULL && skip == 0)
    skip = PicoScanBegin(line + offs);

  if (skip) {
    skip_next_line = skip - 1;
    return;
  }

  BackFill(bgc, sh, est);

  if (FinalizeLine != NULL)
    FinalizeLine(sh, line, est);

  if (PicoScanEnd != NULL)
    skip_next_line = PicoScanEnd(line + offs);

  est->HighCol += HighColIncrement;
  est->DrawLineDest = (char *)est->DrawLineDest + DrawLineDestIncrement;
}

static void PicoLine(int line, int offs, int sh, int bgc, int off, int on)
{
  struct PicoEState *est = &Pico.est;
  int skip = skip_next_line;

  est->DrawScanline = line;
  if (PicoScanBegin != NULL && skip == 0)
    skip = PicoScanBegin(line + offs);

  if (skip) {
    skip_next_line = skip - 1;
    return;
  }

  if (est->Pico->video.debug_p & (PVD_FORCE_A | PVD_FORCE_B | PVD_FORCE_S))
    bgc = 0x3f;

  // Draw screen:
  BackFill(bgc, sh, est);
  if (est->Pico->video.reg[1]&0x40) {
    int width = (est->Pico->video.reg[12]&1) ? 320 : 256;
    DrawDisplay(sh);
    // partial line blanking (display on or off inside the line)
    if (unlikely(off|on)) {
      if (off > 0)
        memset(est->HighCol+8 + off, bgc, width-off);
      if (on > 0)
        memset(est->HighCol+8, bgc, on);
    }
  }

  if (FinalizeLine != NULL)
    FinalizeLine(sh, line, est);

  if (PicoScanEnd != NULL)
    skip_next_line = PicoScanEnd(line + offs);

  est->HighCol += HighColIncrement;
  est->DrawLineDest = (char *)est->DrawLineDest + DrawLineDestIncrement;
}

void PicoDrawSync(int to, int off, int on)
{
  struct PicoEState *est = &Pico.est;
  int line, offs;
  int sh = (est->Pico->video.reg[0xC] & 8) >> 3; // shadow/hilight?
  int bgc = est->Pico->video.reg[7] & 0x3f;

  pprof_start(draw);

  offs = (240-rendlines) >> 1;
  if (to >= rendlines)
    to = rendlines-1;

  if (est->DrawScanline <= to &&
                (est->rendstatus & (PDRAW_DIRTY_SPRITES|PDRAW_PARSE_SPRITES)))
    ParseSprites(to + 1, on);
  else if (!(est->rendstatus & PDRAW_SYNC_NEEDED)) {
    // nothing has changed in VDP/VRAM and buffer is the same -> no sync needed
    int count = to+1 - est->DrawScanline;
    est->HighCol += count*HighColIncrement;
    est->DrawLineDest = (char *)est->DrawLineDest + count*DrawLineDestIncrement;
    est->DrawScanline = to+1;
    return;
  }

  for (line = est->DrawScanline; line < to; line++)
    PicoLine(line, offs, sh, bgc, 0, 0);

  // last line
  if (line <= to)
  {
    int width2 = (est->Pico->video.reg[12]&1) ? 160 : 128;

    if (unlikely(on|off) && (off >= width2 ||
          // hack for timing inaccuracy, if on/off near borders
          (off && off <= 24) || (on < width2 && on >= width2-24)))
      DrawBlankedLine(line, offs, sh, bgc);
    else {
      if (on > width2) on = 0; // on, before start of line?
      PicoLine(line, offs, sh, bgc, 2*off, 2*on);
    }
    line++;
  }
  est->DrawScanline = line;

  pprof_end(draw);
}

void PicoDrawRefreshSprites(void)
{
  struct PicoEState *est = &Pico.est;
  unsigned char *sprited = &HighLnSpr[est->DrawScanline][0];
  int i;

  if (est->DrawScanline == 0 || est->DrawScanline >= rendlines) return;

  // compute sprite row. The VDP does this by subtracting the sprite y pos from
  // the current line and treating the lower 5 bits as the row number. Y pos
  // is reread from SAT cache, which may have changed by now (Overdrive 2).
  for (i = 0; i < (sprited[0] & 0x7f); i++) {
    int num = sprited[4+i] & 0x7f;
    s32 *sp = HighPreSpr + 2*num + (sprited[0] & 0x80)*2;
    int link = (sp[0]>>16) & 0x7f;
    int sy = (CPU_LE2(VdpSATCache[2*link]) & 0x1ff) - 0x80;
    if (sy != (s16)sp[0]) {
      // Y info in SAT cache has really changed
      sy = est->DrawScanline - ((est->DrawScanline - sy) & 0x1f);
      sp[0] = (sp[0] & 0xffff0000) | (u16)sy;
    }
  }
}

void PicoDrawBgcDMA(u16 *base, u32 source, u32 mask, int dlen, int sl)
{
  struct PicoEState *est = &Pico.est;
  int len = (est->Pico->video.reg[12]&1) ? 320 : 256;
  int xl = (est->Pico->video.reg[12]&1) ? 38 : 33; // DMA slots during HSYNC

  BgcDMAbase = base;
  BgcDMAsrc = source;
  BgcDMAmask = mask;
  BgcDMAlen = dlen;
  BgcDMAoffs = 0;

  // handle slot offset in 1st line
  if (sl-12 > 0)
    BgcDMAoffs = 2*(sl-12);
  else if (sl < 0) { // DMA starts before active display
    BgcDMAsrc += 2*-sl;
    BgcDMAlen -= 2*-sl;
  }

  // skip 1st line if it had been drawn already
  if (Pico.est.DrawScanline > Pico.m.scanline) {
    len -= BgcDMAoffs;
    BgcDMAsrc += (len>>1)+xl;
    BgcDMAlen -= (len>>1)+xl;
    BgcDMAoffs = 0;
  }
  if (BgcDMAlen > 0)
    est->rendstatus |= PDRAW_BGC_DMA;
}

// also works for fast renderer
void PicoDrawUpdateHighPal(void)
{
  struct PicoEState *est = &Pico.est;
  if (est->Pico->m.dirtyPal) {
    int sh = (est->Pico->video.reg[0xC] & 8) >> 3; // shadow/hilight?
    if ((*est->PicoOpt & POPT_ALT_RENDERER) | (est->rendstatus & PDRAW_SONIC_MODE))
      sh = 0; // no s/h support

    if (PicoIn.AHW & PAHW_SMS)
      PicoDoHighPal555SMS();
    else if (FinalizeLine == FinalizeLine8bit)
      PicoDoHighPal555_8bit(sh, 0, est);
    else
      PicoDoHighPal555(sh, 0, est);

    // cover for sprite priority bits if not in s/h or sonic mode
    if (!sh && !(est->rendstatus & PDRAW_SONIC_MODE)) {
      blockcpy(est->HighPal+0x40, est->HighPal, 0x40*2);
      blockcpy(est->HighPal+0x80, est->HighPal, 0x80*2);
    }
    est->HighPal[0xe0] = 0x0000; // black and white, reserved for OSD
    est->HighPal[0xf0] = 0xffff;
  }
}

void PicoDrawSetOutFormat(pdso_t which, int use_32x_line_mode)
{
  PicoDrawSetInternalBuf(NULL, 0);
  PicoDrawSetOutBufMD(NULL, 0);
  PicoDraw2SetOutBuf(NULL, 0);
  switch (which)
  {
    case PDF_8BIT:
      FinalizeLine = FinalizeLine8bit;
      break;

    case PDF_RGB555:
      if ((PicoIn.AHW & PAHW_32X) && use_32x_line_mode)
        FinalizeLine = FinalizeLine32xRGB555;
      else
        FinalizeLine = FinalizeLine555;
      break;

    default:
      FinalizeLine = NULL;
      break;
  }
  if (PicoIn.AHW & PAHW_32X)
    PicoDrawSetOutFormat32x(which, use_32x_line_mode);
  PicoDrawSetOutputSMS(which);
  rendstatus_old = -1;
  Pico.m.dirtyPal = 1;
}

void PicoDrawSetOutBufMD(void *dest, int increment)
{
  if (FinalizeLine == FinalizeLine8bit && increment >= 328) {
    // kludge for no-copy mode, using ALT_RENDERER layout
    PicoDrawSetInternalBuf(dest, increment);
  } else if (FinalizeLine == NULL) {
    PicoDrawSetInternalBuf(dest, increment); // needed for SMS
    PicoDraw2SetOutBuf(dest, increment);
  } else if (dest != NULL) {
    if (dest != DrawLineDestBase)
      Pico.est.rendstatus |= PDRAW_SYNC_NEEDED;
    DrawLineDestBase = dest;
    DrawLineDestIncrement = increment;
    Pico.est.DrawLineDest = (char *)DrawLineDestBase + Pico.est.DrawScanline * increment;
  } else {
    DrawLineDestBase = DefOutBuff;
    DrawLineDestIncrement = 0;
    Pico.est.DrawLineDest = DefOutBuff;
  }
}

// note: may be called on the middle of frame
void PicoDrawSetOutBuf(void *dest, int increment)
{
  if (PicoIn.AHW & PAHW_32X)
    PicoDrawSetOutBuf32X(dest, increment);
  else
    PicoDrawSetOutBufMD(dest, increment);
}

void PicoDrawSetInternalBuf(void *dest, int increment)
{
  if (dest != NULL) {
    if (dest != HighColBase)
      Pico.est.rendstatus |= PDRAW_SYNC_NEEDED;
    HighColBase = dest;
    HighColIncrement = increment;
    Pico.est.HighCol = HighColBase + Pico.est.DrawScanline * increment;
  }
  else {
    HighColBase = DefHighCol;
    HighColIncrement = 0;
    Pico.est.HighCol = DefHighCol;
  }
}

void PicoDrawSetCallbacks(int (*begin)(unsigned int num), int (*end)(unsigned int num))
{
  PicoScanBegin = NULL;
  PicoScanEnd = NULL;
  PicoScan32xBegin = NULL;
  PicoScan32xEnd = NULL;

  if ((PicoIn.AHW & PAHW_32X) && FinalizeLine != FinalizeLine32xRGB555) {
    PicoScan32xBegin = begin;
    PicoScan32xEnd = end;
  }
  else {
    PicoScanBegin = begin;
    PicoScanEnd = end;
  }
}

void PicoDrawInit(void)
{
  Pico.est.DrawLineDest = DefOutBuff;
  Pico.est.HighCol = HighColBase;
  rendstatus_old = -1;
}

// vim:ts=2:sw=2:expandtab
