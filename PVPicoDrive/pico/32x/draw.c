/*
 * PicoDrive
 * (C) notaz, 2009,2010
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */
#include "../pico_int.h"

int (*PicoScan32xBegin)(unsigned int num);
int (*PicoScan32xEnd)(unsigned int num);
int Pico32xDrawMode;

static void convert_pal555(int invert_prio)
{
  unsigned int *ps = (void *)Pico32xMem->pal;
  unsigned int *pd = (void *)Pico32xMem->pal_native;
  unsigned int m1 = 0x001f001f;
  unsigned int m2 = 0x03e003e0;
  unsigned int m3 = 0xfc00fc00;
  unsigned int inv = 0;
  int i;

  if (invert_prio)
    inv = 0x00200020;

  // place prio to LS green bit
  for (i = 0x100/2; i > 0; i--, ps++, pd++) {
    unsigned int t = *ps;
    *pd = (((t & m1) << 11) | ((t & m2) << 1) | ((t & m3) >> 10)) ^ inv;
  }

  Pico32x.dirty_pal = 0;
}

// direct color mode
#define do_line_dc(pd, p32x, pmd, inv, pmd_draw_code)             \
{                                                                 \
  const unsigned int m1 = 0x001f;                                 \
  const unsigned int m2 = 0x03e0;                                 \
  const unsigned int m3 = 0x7c00;                                 \
  int i;                                                          \
                                                                  \
  for (i = 320; i > 0; i--, pd++, p32x++, pmd++) {                \
    unsigned short t = *p32x;                                     \
    if ((*pmd & 0x3f) != mdbg && !((t ^ inv) & 0x8000)) {         \
      pmd_draw_code;                                              \
      continue;                                                   \
    }                                                             \
                                                                  \
    *pd = ((t & m1) << 11) | ((t & m2) << 1) | ((t & m3) >> 10);  \
  }                                                               \
}

// packed pixel mode
#define do_line_pp(pd, p32x, pmd, pmd_draw_code)                  \
{                                                                 \
  unsigned short t;                                               \
  int i;                                                          \
  for (i = 320; i > 0; i--, pd++, p32x++, pmd++) {                \
    t = pal[*(unsigned char *)((long)p32x ^ 1)];                  \
    if ((t & 0x20) || (*pmd & 0x3f) == mdbg)                      \
      *pd = t;                                                    \
    else                                                          \
      pmd_draw_code;                                              \
  }                                                               \
} 

// run length mode
#define do_line_rl(pd, p32x, pmd, pmd_draw_code)                  \
{                                                                 \
  unsigned short len, t;                                          \
  int i;                                                          \
  for (i = 320; i > 0; p32x++) {                                  \
    t = pal[*p32x & 0xff];                                        \
    for (len = (*p32x >> 8) + 1; len > 0 && i > 0; len--, i--, pd++, pmd++) { \
      if ((*pmd & 0x3f) == mdbg || (t & 0x20))                    \
        *pd = t;                                                  \
      else                                                        \
        pmd_draw_code;                                            \
    }                                                             \
  }                                                               \
}

// this is almost never used (Wiz and menu bg gen only)
void FinalizeLine32xRGB555(int sh, int line)
{
  unsigned short *pd = DrawLineDest;
  unsigned short *pal = Pico32xMem->pal_native;
  unsigned char  *pmd = HighCol + 8;
  unsigned short *dram, *p32x;
  unsigned char   mdbg;

  FinalizeLine555(sh, line);

  if ((Pico32x.vdp_regs[0] & P32XV_Mx) == 0 || // 32x blanking
      // XXX: how is 32col mode hadled by real hardware?
      !(Pico.video.reg[12] & 1) || // 32col mode
      !(PicoDrawMask & PDRAW_32X_ON))
  {
    return;
  }

  dram = (void *)Pico32xMem->dram[Pico32x.vdp_regs[0x0a/2] & P32XV_FS];
  p32x = dram + dram[line];
  mdbg = Pico.video.reg[7] & 0x3f;

  if ((Pico32x.vdp_regs[0] & P32XV_Mx) == 2) { // Direct Color Mode
    int inv_bit = (Pico32x.vdp_regs[0] & P32XV_PRI) ? 0x8000 : 0;
    do_line_dc(pd, p32x, pmd, inv_bit,);
    return;
  }

  if (Pico32x.dirty_pal)
    convert_pal555(Pico32x.vdp_regs[0] & P32XV_PRI);

  if ((Pico32x.vdp_regs[0] & P32XV_Mx) == 1) { // Packed Pixel Mode
    unsigned char *p32xb = (void *)p32x;
    if (Pico32x.vdp_regs[2 / 2] & P32XV_SFT)
      p32xb++;
    do_line_pp(pd, p32xb, pmd,);
  }
  else { // Run Length Mode
    do_line_rl(pd, p32x, pmd,);
  }
}

#define MD_LAYER_CODE \
  *dst = palmd[*pmd]

#define PICOSCAN_PRE \
  PicoScan32xBegin(l + (lines_sft_offs & 0xff)); \
  dst = DrawLineDest; \

#define PICOSCAN_POST \
  PicoScan32xEnd(l + (lines_sft_offs & 0xff)); \

#define make_do_loop(name, pre_code, post_code, md_code)        \
/* Direct Color Mode */                                         \
static void do_loop_dc##name(unsigned short *dst,               \
    unsigned short *dram, int lines_sft_offs, int mdbg)         \
{                                                               \
  int inv_bit = (Pico32x.vdp_regs[0] & P32XV_PRI) ? 0x8000 : 0; \
  unsigned char  *pmd = PicoDraw2FB +                           \
                          328 * (lines_sft_offs & 0xff) + 8;    \
  unsigned short *palmd = HighPal;                              \
  unsigned short *p32x;                                         \
  int lines = lines_sft_offs >> 16;                             \
  int l;                                                        \
  (void)palmd;                                                  \
  for (l = 0; l < lines; l++, pmd += 8) {                       \
    pre_code;                                                   \
    p32x = dram + dram[l];                                      \
    do_line_dc(dst, p32x, pmd, inv_bit, md_code);               \
    post_code;                                                  \
  }                                                             \
}                                                               \
                                                                \
/* Packed Pixel Mode */                                         \
static void do_loop_pp##name(unsigned short *dst,               \
    unsigned short *dram, int lines_sft_offs, int mdbg)         \
{                                                               \
  unsigned short *pal = Pico32xMem->pal_native;                 \
  unsigned char  *pmd = PicoDraw2FB +                           \
                          328 * (lines_sft_offs & 0xff) + 8;    \
  unsigned short *palmd = HighPal;                              \
  unsigned char  *p32x;                                         \
  int lines = lines_sft_offs >> 16;                             \
  int l;                                                        \
  (void)palmd;                                                  \
  for (l = 0; l < lines; l++, pmd += 8) {                       \
    pre_code;                                                   \
    p32x = (void *)(dram + dram[l]);                            \
    p32x += (lines_sft_offs >> 8) & 1;                          \
    do_line_pp(dst, p32x, pmd, md_code);                        \
    post_code;                                                  \
  }                                                             \
}                                                               \
                                                                \
/* Run Length Mode */                                           \
static void do_loop_rl##name(unsigned short *dst,               \
    unsigned short *dram, int lines_sft_offs, int mdbg)         \
{                                                               \
  unsigned short *pal = Pico32xMem->pal_native;                 \
  unsigned char  *pmd = PicoDraw2FB +                           \
                          328 * (lines_sft_offs & 0xff) + 8;    \
  unsigned short *palmd = HighPal;                              \
  unsigned short *p32x;                                         \
  int lines = lines_sft_offs >> 16;                             \
  int l;                                                        \
  (void)palmd;                                                  \
  for (l = 0; l < lines; l++, pmd += 8) {                       \
    pre_code;                                                   \
    p32x = dram + dram[l];                                      \
    do_line_rl(dst, p32x, pmd, md_code);                        \
    post_code;                                                  \
  }                                                             \
}

#ifdef _ASM_32X_DRAW
#undef make_do_loop
#define make_do_loop(name, pre_code, post_code, md_code) \
extern void do_loop_dc##name(unsigned short *dst,        \
    unsigned short *dram, int lines_offs, int mdbg);     \
extern void do_loop_pp##name(unsigned short *dst,        \
    unsigned short *dram, int lines_offs, int mdbg);     \
extern void do_loop_rl##name(unsigned short *dst,        \
    unsigned short *dram, int lines_offs, int mdbg);
#endif

make_do_loop(,,,)
make_do_loop(_md, , , MD_LAYER_CODE)
make_do_loop(_scan, PICOSCAN_PRE, PICOSCAN_POST, )
make_do_loop(_scan_md, PICOSCAN_PRE, PICOSCAN_POST, MD_LAYER_CODE)

typedef void (*do_loop_func)(unsigned short *dst, unsigned short *dram, int lines, int mdbg);
enum { DO_LOOP, DO_LOOP_MD, DO_LOOP_SCAN, DO_LOOP_MD_SCAN };

static const do_loop_func do_loop_dc_f[] = { do_loop_dc, do_loop_dc_md, do_loop_dc_scan, do_loop_dc_scan_md };
static const do_loop_func do_loop_pp_f[] = { do_loop_pp, do_loop_pp_md, do_loop_pp_scan, do_loop_pp_scan_md };
static const do_loop_func do_loop_rl_f[] = { do_loop_rl, do_loop_rl_md, do_loop_rl_scan, do_loop_rl_scan_md };

void PicoDraw32xLayer(int offs, int lines, int md_bg)
{
  int have_scan = PicoScan32xBegin != NULL && PicoScan32xEnd != NULL;
  const do_loop_func *do_loop;
  unsigned short *dram;
  int lines_sft_offs;
  int which_func;

  DrawLineDest = (char *)DrawLineDestBase + offs * DrawLineDestIncrement;
  dram = Pico32xMem->dram[Pico32x.vdp_regs[0x0a/2] & P32XV_FS];

  if (Pico32xDrawMode == PDM32X_BOTH) {
    if (Pico.m.dirtyPal)
      PicoDrawUpdateHighPal();
  }

  if ((Pico32x.vdp_regs[0] & P32XV_Mx) == 2)
  {
    // Direct Color Mode
    do_loop = do_loop_dc_f;
    goto do_it;
  }

  if (Pico32x.dirty_pal)
    convert_pal555(Pico32x.vdp_regs[0] & P32XV_PRI);

  if ((Pico32x.vdp_regs[0] & P32XV_Mx) == 1)
  {
    // Packed Pixel Mode
    do_loop = do_loop_pp_f;
  }
  else
  {
    // Run Length Mode
    do_loop = do_loop_rl_f;
  }

do_it:
  if (Pico32xDrawMode == PDM32X_BOTH)
    which_func = have_scan ? DO_LOOP_MD_SCAN : DO_LOOP_MD;
  else
    which_func = have_scan ? DO_LOOP_SCAN : DO_LOOP;
  lines_sft_offs = (lines << 16) | offs;
  if (Pico32x.vdp_regs[2 / 2] & P32XV_SFT)
    lines_sft_offs |= 1 << 8;

  do_loop[which_func](DrawLineDest, dram, lines_sft_offs, md_bg);
}

// mostly unused, games tend to keep 32X layer on
void PicoDraw32xLayerMdOnly(int offs, int lines)
{
  int have_scan = PicoScan32xBegin != NULL && PicoScan32xEnd != NULL;
  unsigned short *dst = (void *)((char *)DrawLineDestBase + offs * DrawLineDestIncrement);
  unsigned char  *pmd = PicoDraw2FB + 328 * offs + 8;
  unsigned short *pal = HighPal;
  int poffs = 0, plen = 320;
  int l, p;

  if (!(Pico.video.reg[12] & 1)) {
    // 32col mode
    poffs = 32;
    plen = 256;
  }

  if (Pico.m.dirtyPal)
    PicoDrawUpdateHighPal();

  dst += poffs;
  for (l = 0; l < lines; l++) {
    if (have_scan) {
      PicoScan32xBegin(l + offs);
      dst = DrawLineDest + poffs;
    }
    for (p = 0; p < plen; p += 4) {
      dst[p + 0] = pal[*pmd++];
      dst[p + 1] = pal[*pmd++];
      dst[p + 2] = pal[*pmd++];
      dst[p + 3] = pal[*pmd++];
    }
    dst = (void *)((char *)dst + DrawLineDestIncrement);
    pmd += 328 - plen;
    if (have_scan)
      PicoScan32xEnd(l + offs);
  }
}

void PicoDrawSetOutFormat32x(pdso_t which, int use_32x_line_mode)
{
#ifdef _ASM_32X_DRAW
  extern void *Pico32xNativePal;
  Pico32xNativePal = Pico32xMem->pal_native;
#endif

  if (which == PDF_RGB555 && use_32x_line_mode) {
    // we'll draw via FinalizeLine32xRGB555 (rare)
    PicoDrawSetInternalBuf(NULL, 0);
    Pico32xDrawMode = PDM32X_OFF;
    return;
  }

  // use the same layout as alt renderer
  PicoDrawSetInternalBuf(PicoDraw2FB, 328);
  Pico32xDrawMode = (which == PDF_RGB555) ? PDM32X_32X_ONLY : PDM32X_BOTH;
}

// vim:shiftwidth=2:ts=2:expandtab
