/*
 * debug stuff
 * (C) notaz, 2006-2009
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include "pico_int.h"
#include "sound/ym2612.h"
#include "debug.h"

#define bit(r, x) ((r>>x)&1)
#define MVP dstrp+=strlen(dstrp)
void z80_debug(char *dstr);

static char dstr[1024*8];

char *PDebugMain(void)
{
  struct PicoVideo *pv=&Pico.video;
  unsigned char *reg=pv->reg, r;
  extern int HighPreSpr[];
  int i, sprites_lo, sprites_hi;
  char *dstrp;

  sprites_lo = sprites_hi = 0;
  for (i = 0; HighPreSpr[i] != 0; i+=2)
    if (HighPreSpr[i+1] & 0x8000)
         sprites_hi++;
    else sprites_lo++;

  dstrp = dstr;
  sprintf(dstrp, "mode set 1: %02x       spr lo: %2i, spr hi: %2i\n", (r=reg[0]), sprites_lo, sprites_hi); MVP;
  sprintf(dstrp, "display_disable: %i, M3: %i, palette: %i, ?, hints: %i\n", bit(r,0), bit(r,1), bit(r,2), bit(r,4)); MVP;
  sprintf(dstrp, "mode set 2: %02x                            hcnt: %i\n", (r=reg[1]), pv->reg[10]); MVP;
  sprintf(dstrp, "SMS/gen: %i, pal: %i, dma: %i, vints: %i, disp: %i, TMS: %i\n",bit(r,2),bit(r,3),bit(r,4),bit(r,5),bit(r,6),bit(r,7)); MVP;
  sprintf(dstrp, "mode set 3: %02x\n", (r=reg[0xB])); MVP;
  sprintf(dstrp, "LSCR: %i, HSCR: %i, 2cell vscroll: %i, IE2: %i\n", bit(r,0), bit(r,1), bit(r,2), bit(r,3)); MVP;
  sprintf(dstrp, "mode set 4: %02x\n", (r=reg[0xC])); MVP;
  sprintf(dstrp, "interlace: %i%i, cells: %i, shadow: %i\n", bit(r,2), bit(r,1), (r&0x80) ? 40 : 32, bit(r,3)); MVP;
  sprintf(dstrp, "scroll size: w: %i, h: %i  SRAM: %i; eeprom: %i (%i)\n", reg[0x10]&3, (reg[0x10]&0x30)>>4,
    !!(SRam.flags & SRF_ENABLED), !!(SRam.flags & SRF_EEPROM), SRam.eeprom_type); MVP;
  sprintf(dstrp, "sram range: %06x-%06x, reg: %02x\n", SRam.start, SRam.end, Pico.m.sram_reg); MVP;
  sprintf(dstrp, "pend int: v:%i, h:%i, vdp status: %04x\n", bit(pv->pending_ints,5), bit(pv->pending_ints,4), pv->status); MVP;
  sprintf(dstrp, "pal: %i, hw: %02x, frame#: %i, cycles: %i\n", Pico.m.pal, Pico.m.hardware, Pico.m.frame_count, SekCyclesDone()); MVP;
  sprintf(dstrp, "M68k: PC: %06x, SR: %04x, irql: %i\n", SekPc, SekSr, SekIrqLevel); MVP;
  for (r = 0; r < 8; r++) {
    sprintf(dstrp, "d%i=%08x, a%i=%08x\n", r, SekDar(r), r, SekDar(r+8)); MVP;
  }
  sprintf(dstrp, "z80Run: %i, z80_reset: %i, z80_bnk: %06x\n", Pico.m.z80Run, Pico.m.z80_reset, Pico.m.z80_bank68k<<15); MVP;
  z80_debug(dstrp); MVP;
  if (strlen(dstr) > sizeof(dstr))
    elprintf(EL_STATUS, "warning: debug buffer overflow (%i/%i)\n", strlen(dstr), sizeof(dstr));

  return dstr;
}

char *PDebug32x(void)
{
#ifndef NO_32X
  char *dstrp = dstr;
  unsigned short *r;
  int i;

  r = Pico32x.regs;
  sprintf(dstrp, "regs:\n"); MVP;
  for (i = 0; i < 0x40/2; i += 8) {
    sprintf(dstrp, "%02x: %04x %04x %04x %04x %04x %04x %04x %04x\n",
      i*2, r[i+0], r[i+1], r[i+2], r[i+3], r[i+4], r[i+5], r[i+6], r[i+7]); MVP;
  }
  r = Pico32x.sh2_regs;
  sprintf(dstrp, "SH: %04x %04x %04x      IRQs: %02x  eflags: %02x\n",
    r[0], r[1], r[2], Pico32x.sh2irqs, Pico32x.emu_flags); MVP;

  i = 0;
  r = Pico32x.vdp_regs;
  sprintf(dstrp, "VDP regs:\n"); MVP;
  sprintf(dstrp, "%02x: %04x %04x %04x %04x %04x %04x %04x %04x\n",
    i*2, r[i+0], r[i+1], r[i+2], r[i+3], r[i+4], r[i+5], r[i+6], r[i+7]); MVP;

  sprintf(dstrp, "                   mSH2              sSH2\n"); MVP;
  sprintf(dstrp, "PC,SR %08x,     %03x %08x,     %03x\n", sh2_pc(&msh2), sh2_sr(0), sh2_pc(&ssh2), sh2_sr(1)); MVP;
  for (i = 0; i < 16/2; i++) {
    sprintf(dstrp, "R%d,%2d %08x,%08x %08x,%08x\n", i, i + 8,
      sh2_reg(0,i), sh2_reg(0,i+8), sh2_reg(1,i), sh2_reg(1,i+8)); MVP;
  }
  sprintf(dstrp, "gb,vb %08x,%08x %08x,%08x\n", sh2_gbr(0), sh2_vbr(0), sh2_gbr(1), sh2_vbr(1)); MVP;
  sprintf(dstrp, "IRQs/mask:        %02x/%02x             %02x/%02x\n",
    Pico32x.sh2irqi[0], Pico32x.sh2irq_mask[0], Pico32x.sh2irqi[1], Pico32x.sh2irq_mask[1]); MVP;
#else
  dstr[0] = 0;
#endif

  return dstr;
}

char *PDebugSpriteList(void)
{
  struct PicoVideo *pvid=&Pico.video;
  int table=0,u,link=0;
  int max_sprites = 80;
  char *dstrp;

  if (!(pvid->reg[12]&1))
    max_sprites = 64;

  dstr[0] = 0;
  dstrp = dstr;

  table=pvid->reg[5]&0x7f;
  if (pvid->reg[12]&1) table&=0x7e; // Lowest bit 0 in 40-cell mode
  table<<=8; // Get sprite table address/2

  for (u=0; u < max_sprites; u++)
  {
    unsigned int *sprite;
    int code, code2, sx, sy, height;

    sprite=(unsigned int *)(Pico.vram+((table+(link<<2))&0x7ffc)); // Find sprite

    // get sprite info
    code = sprite[0];

    // check if it is on this line
    sy = (code&0x1ff)-0x80;
    height = ((code>>24)&3)+1;

    // masking sprite?
    code2 = sprite[1];
    sx = ((code2>>16)&0x1ff)-0x80;

    sprintf(dstrp, "#%02i x:%4i y:%4i %ix%i %s\n", u, sx, sy, ((code>>26)&3)+1, height,
      (code2&0x8000)?"hi":"lo");
    MVP;

    link=(code>>16)&0x7f;
    if(!link) break; // End of sprites
  }

  return dstr;
}

#define GREEN1  0x0700
#ifdef USE_BGR555
 #define YELLOW1 0x071c
 #define BLUE1   0xf000
 #define RED1    0x001e
#else
 #define YELLOW1 0xe700
 #define BLUE1   0x001e
 #define RED1    0xf000
#endif

static void set16(unsigned short *p, unsigned short d, int cnt)
{
  while (cnt-- > 0)
    *p++ = d;
}

void PDebugShowSpriteStats(unsigned short *screen, int stride)
{
  int lines, i, u, step;
  unsigned short *dest;
  unsigned char *p;

  step = (320-4*4-1) / MAX_LINE_SPRITES;
  lines = 240;
  if (!Pico.m.pal || !(Pico.video.reg[1]&8))
    lines = 224, screen += stride*8;

  for (i = 0; i < lines; i++)
  {
    dest = screen + stride*i;
    p = &HighLnSpr[i][0];

    // sprite graphs
    for (u = 0; u < (p[0] & 0x7f); u++) {
      set16(dest, (p[3+u] & 0x80) ? YELLOW1 : GREEN1, step);
      dest += step;
    }

    // flags
    dest = screen + stride*i + 320-4*4;
    if (p[1] & 0x40) set16(dest+4*0, GREEN1,  4);
    if (p[1] & 0x80) set16(dest+4*1, YELLOW1, 4);
    if (p[1] & 0x20) set16(dest+4*2, BLUE1,   4);
    if (p[1] & 0x10) set16(dest+4*3, RED1,    4);
  }

  // draw grid
  for (i = step*5; i <= 320-4*4-1; i += step*5) {
    for (u = 0; u < lines; u++)
      screen[i + u*stride] = 0x182;
  }
}

void PDebugShowPalette(unsigned short *screen, int stride)
{
  int x, y;

  Pico.m.dirtyPal = 1;
  if (PicoAHW & PAHW_SMS)
    PicoDoHighPal555M4();
  else
    PicoDoHighPal555(1);
  Pico.m.dirtyPal = 1;

  screen += 16*stride+8;
  for (y = 0; y < 8*4; y++)
    for (x = 0; x < 8*16; x++)
      screen[x + y*stride] = HighPal[x/8 + (y/8)*16];

  screen += 160;
  for (y = 0; y < 8*4; y++)
    for (x = 0; x < 8*16; x++)
      screen[x + y*stride] = HighPal[(x/8 + (y/8)*16) | 0x40];

  screen += stride*48;
  for (y = 0; y < 8*4; y++)
    for (x = 0; x < 8*16; x++)
      screen[x + y*stride] = HighPal[(x/8 + (y/8)*16) | 0x80];
}

#if defined(DRAW2_OVERRIDE_LINE_WIDTH)
#define DRAW2_LINE_WIDTH DRAW2_OVERRIDE_LINE_WIDTH
#else
#define DRAW2_LINE_WIDTH 328
#endif

void PDebugShowSprite(unsigned short *screen, int stride, int which)
{
  struct PicoVideo *pvid=&Pico.video;
  int table=0,u,link=0,*sprite=0,*fsprite,oldsprite[2];
  int x,y,max_sprites = 80, oldcol, oldreg;

  if (!(pvid->reg[12]&1))
    max_sprites = 64;

  table=pvid->reg[5]&0x7f;
  if (pvid->reg[12]&1) table&=0x7e; // Lowest bit 0 in 40-cell mode
  table<<=8; // Get sprite table address/2

  for (u=0; u < max_sprites && u <= which; u++)
  {
    sprite=(int *)(Pico.vram+((table+(link<<2))&0x7ffc)); // Find sprite

    link=(sprite[0]>>16)&0x7f;
    if (!link) break; // End of sprites
  }
  if (u >= max_sprites) return;

  fsprite = (int *)(Pico.vram+(table&0x7ffc));
  oldsprite[0] = fsprite[0];
  oldsprite[1] = fsprite[1];
  fsprite[0] = (sprite[0] & ~0x007f01ff) | 0x000080;
  fsprite[1] = (sprite[1] & ~0x01ff8000) | 0x800000;
  oldreg = pvid->reg[7];
  oldcol = Pico.cram[0];
  pvid->reg[7] = 0;
  Pico.cram[0] = 0;
  PicoDrawMask = PDRAW_SPRITES_LOW_ON;

  PicoFrameFull();
  for (y = 0; y < 8*4; y++)
  {
    unsigned char *ps = PicoDraw2FB + DRAW2_LINE_WIDTH*y + 8;
    for (x = 0; x < 8*4; x++)
      if (ps[x]) screen[x] = HighPal[ps[x]], ps[x] = 0;
    screen += stride;
  }

  fsprite[0] = oldsprite[0];
  fsprite[1] = oldsprite[1];
  pvid->reg[7] = oldreg;
  Pico.cram[0] = oldcol;
  PicoDrawMask = -1;
}

#define dump_ram(ram,fname) \
{ \
  unsigned short *sram = (unsigned short *) ram; \
  FILE *f; \
  int i; \
\
  for (i = 0; i < sizeof(ram)/2; i++) \
    sram[i] = (sram[i]<<8) | (sram[i]>>8); \
  f = fopen(fname, "wb"); \
  if (f) { \
    fwrite(ram, 1, sizeof(ram), f); \
    fclose(f); \
  } \
  for (i = 0; i < sizeof(ram)/2; i++) \
    sram[i] = (sram[i]<<8) | (sram[i]>>8); \
}

#define dump_ram_noswab(ram,fname) \
{ \
  FILE *f; \
  f = fopen(fname, "wb"); \
  if (f) { \
    fwrite(ram, 1, sizeof(ram), f); \
    fclose(f); \
  } \
}

void PDebugDumpMem(void)
{
  dump_ram_noswab(Pico.zram, "dumps/zram.bin");
  dump_ram(Pico.cram, "dumps/cram.bin");

  if (PicoAHW & PAHW_SMS)
  {
    dump_ram_noswab(Pico.vramb, "dumps/vram.bin");
  }
  else
  {
    dump_ram(Pico.ram,  "dumps/ram.bin");
    dump_ram(Pico.vram, "dumps/vram.bin");
    dump_ram(Pico.vsram,"dumps/vsram.bin");
  }

  if (PicoAHW & PAHW_MCD)
  {
    dump_ram(Pico_mcd->prg_ram, "dumps/prg_ram.bin");
    if (Pico_mcd->s68k_regs[3]&4) // 1M mode?
      wram_1M_to_2M(Pico_mcd->word_ram2M);
    dump_ram(Pico_mcd->word_ram2M, "dumps/word_ram_2M.bin");
    wram_2M_to_1M(Pico_mcd->word_ram2M);
    dump_ram(Pico_mcd->word_ram1M[0], "dumps/word_ram_1M_0.bin");
    dump_ram(Pico_mcd->word_ram1M[1], "dumps/word_ram_1M_1.bin");
    if (!(Pico_mcd->s68k_regs[3]&4)) // 2M mode?
      wram_2M_to_1M(Pico_mcd->word_ram2M);
    dump_ram_noswab(Pico_mcd->pcm_ram,"dumps/pcm_ram.bin");
    dump_ram_noswab(Pico_mcd->bram,   "dumps/bram.bin");
  }

#ifndef NO_32X
  if (PicoAHW & PAHW_32X)
  {
    dump_ram(Pico32xMem->sdram, "dumps/sdram.bin");
    dump_ram(Pico32xMem->dram[0], "dumps/dram0.bin");
    dump_ram(Pico32xMem->dram[1], "dumps/dram1.bin");
    dump_ram(Pico32xMem->pal, "dumps/pal32x.bin");
    dump_ram(msh2.data_array, "dumps/data_array0.bin");
    dump_ram(ssh2.data_array, "dumps/data_array1.bin");
  }
#endif
}

void PDebugZ80Frame(void)
{
  int lines, line_sample;

  if (PicoAHW & PAHW_SMS)
    return;

  if (Pico.m.pal) {
    lines = 312;
    line_sample = 68;
  } else {
    lines = 262;
    line_sample = 93;
  }

  z80_resetCycles();
  emustatus &= ~1;

  if (Pico.m.z80Run && !Pico.m.z80_reset && (PicoOpt&POPT_EN_Z80))
    PicoSyncZ80(line_sample*488);
  if (ym2612.dacen && PsndDacLine <= line_sample)
    PsndDoDAC(line_sample);
  if (PsndOut)
    PsndGetSamples(line_sample);

  if (Pico.m.z80Run && !Pico.m.z80_reset && (PicoOpt&POPT_EN_Z80)) {
    PicoSyncZ80(224*488);
    z80_int();
  }
  if (ym2612.dacen && PsndDacLine <= 224)
    PsndDoDAC(224);
  if (PsndOut)
    PsndGetSamples(224);

  // sync z80
  if (Pico.m.z80Run && !Pico.m.z80_reset && (PicoOpt&POPT_EN_Z80))
    PicoSyncZ80(Pico.m.pal ? 151809 : 127671); // cycles adjusted for converter
  if (PsndOut && ym2612.dacen && PsndDacLine <= lines-1)
    PsndDoDAC(lines-1);

  timers_cycle();
}

void PDebugCPUStep(void)
{
  if (PicoAHW & PAHW_SMS)
    z80_run_nr(1);
  else
    SekStepM68k();
}

#ifdef EVT_LOG
static struct evt_t {
  unsigned int cycles;
  short cpu;
  short evt;
} *evts;
static int first_frame;
static int evt_alloc;
static int evt_cnt;

void pevt_log(unsigned int cycles, enum evt_cpu c, enum evt e)
{
  if (first_frame == 0)
    first_frame = Pico.m.frame_count;
  if (evt_alloc == evt_cnt) {
    evt_alloc = evt_alloc * 2 + 16 * 1024;
    evts = realloc(evts, evt_alloc * sizeof(evts[0]));
  }
  evts[evt_cnt].cycles = cycles;
  evts[evt_cnt].cpu = c;
  evts[evt_cnt].evt = e;
  evt_cnt++;
}

static int evt_cmp(const void *p1, const void *p2)
{
  const struct evt_t *e1 = p1, *e2 = p2;
  int ret = (int)(e1->cycles - e2->cycles);
  if (ret)
    return ret;
  if (e1->evt == EVT_RUN_END || e1->evt == EVT_POLL_END)
    return -1;
  if (e1->evt == EVT_RUN_START || e1->evt == EVT_POLL_START)
    return 1;
  if (e2->evt == EVT_RUN_END || e2->evt == EVT_POLL_END)
    return 1;
  if (e1->evt == EVT_RUN_START || e1->evt == EVT_POLL_START)
    return -1;
  return 0;
}

void pevt_dump(void)
{
  static const char *evt_names[EVT_CNT] = {
    "x", "x", "+run", "-run", "+poll", "-poll",
  };
  char evt_print[EVT_CPU_CNT][EVT_CNT] = {{0,}};
  unsigned int start_cycles[EVT_CPU_CNT] = {0,};
  unsigned int run_cycles[EVT_CPU_CNT] = {0,};
  unsigned int frame_cycles[EVT_CPU_CNT] = {0,};
  unsigned int frame_resched[EVT_CPU_CNT] = {0,};
  unsigned int cycles = 0;
  int frame = first_frame - 1;
  int line = 0;
  int cpu_mask = 0;
  int dirty = 0;
  int i;

  qsort(evts, evt_cnt, sizeof(evts[0]), evt_cmp);

  for (i = 0; i < evt_cnt; i++) {
    int c = evts[i].cpu, e = evts[i].evt;
    int ei, ci;

    if (cycles != evts[i].cycles || (cpu_mask & (1 << c))
        || e == EVT_FRAME_START || e == EVT_NEXT_LINE)
    {
      if (dirty) {
        printf("%u:%03u:%u ", frame, line, cycles);
        for (ci = 0; ci < EVT_CPU_CNT; ci++) {
          int found = 0;
          for (ei = 0; ei < EVT_CNT; ei++) {
            if (evt_print[ci][ei]) {
              if (ei == EVT_RUN_END) {
                printf("%8s%4d", evt_names[ei], run_cycles[ci]);
                run_cycles[ci] = 0;
              }
              else
                printf("%8s    ", evt_names[ei]);
              found = 1;
            }
          }
          if (!found)
            printf("%12s", "");
        }
        printf("\n");
        memset(evt_print, 0, sizeof(evt_print));
        cpu_mask = 0;
        dirty = 0;
      }
      cycles = evts[i].cycles;
    }

    switch (e) {
    case EVT_FRAME_START:
      frame++;
      line = 0;
      printf("%u:%03u:%u ", frame, line, cycles);
      for (ci = 0; ci < EVT_CPU_CNT; ci++) {
        printf("%12u", frame_cycles[ci]);
        frame_cycles[ci] = 0;
      }
      printf("\n");
      printf("%u:%03u:%u ", frame, line, cycles);
      for (ci = 0; ci < EVT_CPU_CNT; ci++) {
        printf("%12u", frame_resched[ci]);
        frame_resched[ci] = 0;
      }
      printf("\n");
      break;
    case EVT_NEXT_LINE:
      line++;
      printf("%u:%03u:%u\n", frame, line, cycles);
      break;
    case EVT_RUN_START:
      start_cycles[c] = cycles;
      goto default_;
    case EVT_RUN_END:
      run_cycles[c] += cycles - start_cycles[c];
      frame_cycles[c] += cycles - start_cycles[c];
      frame_resched[c]++;
      goto default_;
    default_:
    default:
      evt_print[c][e] = 1;
      cpu_mask |= 1 << c;
      dirty = 1;
      break;
    }
  }
}
#endif

#if defined(CPU_CMP_R) || defined(CPU_CMP_W) || defined(DRC_CMP)
static FILE *tl_f;

void tl_write(const void *ptr, size_t size)
{
  if (tl_f == NULL)
    tl_f = fopen("tracelog", "wb");

  fwrite(ptr, 1, size, tl_f);
}

void tl_write_uint(unsigned char ctl, unsigned int v)
{
  tl_write(&ctl, sizeof(ctl));
  tl_write(&v, sizeof(v));
}

int tl_read(void *ptr, size_t size)
{
  if (tl_f == NULL)
    tl_f = fopen("tracelog", "rb");

  return fread(ptr, 1, size, tl_f);
}

int tl_read_uint(void *ptr)
{
  return tl_read(ptr, 4);
}
#endif

// vim:shiftwidth=2:ts=2:expandtab
