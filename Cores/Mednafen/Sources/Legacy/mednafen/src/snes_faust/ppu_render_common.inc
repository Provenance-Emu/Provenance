/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* ppu_common.inc:
**  Copyright (C) 2015-2019 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/


static INLINE void FetchSpriteData(signed line_y)
{
 unsigned SpriteIndex = 0;
 unsigned SpriteCount = 0;
 uint8 whtab[2][2];

 if(INIDisp & 0x80)
 {
  PPU.SpriteTileCount = 0;
  return;
 }

 if(OAMADDH & 0x80)
 {
  if((OAM_Addr & 0x3) == 0x3)
   SpriteIndex = ((OAM_Addr >> 2) + line_y) & 0x7F;
  else
   SpriteIndex = (OAM_Addr >> 2) & 0x7F;
 }

 {
  const auto* tp = PPU.Sprite_WHTab[(OBSEL >> 5) & 0x7];

  for(unsigned i = 0; i < 2; i++)
  {
   whtab[i][0] = tp[i][0];
   whtab[i][1] = tp[i][1];
  }
 }

 for(unsigned i = 0; i < 128; i++, SpriteIndex = (SpriteIndex + 1) & 0x7F)
 {
  const uint8* const oa = &OAM[SpriteIndex << 2];
  const uint8 hob = OAMHI[SpriteIndex >> 2] >> ((SpriteIndex & 0x3) << 1);
  const bool sizebit = hob & 0x2;
  const signed x = sign_x_to_s32(9, oa[0] | ((hob & 1) << 8));
  uint8 y_offset = line_y - oa[1];
  uint8 w = whtab[sizebit][0];
  uint8 h = whtab[sizebit][1];

  if(y_offset >= h)
   continue;

  //printf("Line %d, Sprite: %d:%d, %d:%d\n", line_y, x, y_offset, w, h);
  if(w <= sign_x_to_s32(9, -x))
   continue;

  if(SpriteCount == 32)
  {
   //printf("Sprite count over on %u\n", line_y);
   Status[0] |= 0x40;
   break;
  }

  //
  //
  //
  auto* l = &PPU.SpriteList[SpriteCount];   

  if(oa[3] & 0x80)
   y_offset ^= (h - 1) & ~w;

  l->x = x;
  l->y_offset = y_offset;
  l->tilebase = oa[2];
  l->paloffs = 0x80 + ((oa[3] & 0xE) << 3);
  l->prio = (oa[3] >> 4) & 0x3;
  l->w = w;
  l->h = h;
  l->hfxor = (oa[3] & 0x40) ? (w - 1) : 0;
  l->n = oa[3] & 0x01;	
  SpriteCount++;
 }

 uint16* chrbase[2];

 for(unsigned i = 0; i < 2; i++)
 {
  unsigned offs = ((OBSEL & 0x7) << 13);

  if(i)
   offs += ((OBSEL & 0x18) + 0x8) << 9;

  chrbase[i] = &VRAM[offs & 0x7000];
 }
 //
 PPU.SpriteTileCount = 0;
 for(int i = SpriteCount - 1; i >= 0; i--)
 {
  const auto* const l = &PPU.SpriteList[i];

  if(MDFN_UNLIKELY(l->x == -256))
  {
   for(int ht = 0; ht < l->w; ht += 8)
   {
    if(PPU.SpriteTileCount == 34)
    {
     //printf("Sprite tile overflow on %u\n", line_y);
     Status[0] |= 0x80;
     goto ExitTileLoop;
    }

    // TODO: initialize the other members if we ever make PPU.SpriteTileList temporarily allocated
    PPU.SpriteTileList[PPU.SpriteTileCount].tda = 0;
    PPU.SpriteTileList[PPU.SpriteTileCount].tdb = 0;
    //
    PPU.SpriteTileCount++;
   }
  }
  else
  {
   for(int ht = 0; ht < l->w; ht += 8)
   {
    int xo = l->x + ht;

    if(xo <= -8 || xo >= 256) //rof > (255 + 7))
     continue;

    if(PPU.SpriteTileCount == 34)
    {
     //printf("Sprite tile overflow on %u\n", line_y);
     Status[0] |= 0x80;
     goto ExitTileLoop;
    }
    auto* const t = &PPU.SpriteTileList[PPU.SpriteTileCount++];

    t->x = xo;
    t->prio_or = (l->prio + 1) * 0x3030 | ((l->paloffs & 0x40) >> 6) | 2;

    uint8 wt;

    unsigned rof = (ht ^ l->hfxor) >> 3;

    wt = ((l->tilebase & 0xF0) + (l->y_offset << 1)) & 0xF0;
    wt |= (l->tilebase + rof) & 0x0F;

    uint16* chr = chrbase[l->n] + (wt << 4) + (l->y_offset & 0x7);
    const uint16* tab = PPU.SpriteTileTab;
    uint32 bpa = chr[0];
    uint32 bpb = chr[8];
    uint32 hm = (tab[bpa & 0xF] << 0) + (tab[(bpa >> 4) & 0xF] << 16) + (tab[(bpa >> 8) & 0xF] << 1) + (tab[(bpa >> 12) & 0xF] << 17) + (tab[bpb & 0xF] << 2) + (tab[(bpb >> 4) & 0xF] << 18) + (tab[(bpb >> 8) & 0xF] << 3) + (tab[(bpb >> 12) & 0xF] << 19);
    uint32 paloffs;
    uint32 tda, tdb;

    paloffs = l->paloffs;
    paloffs |= paloffs << 8;
    tda = tdb = paloffs | (paloffs << 16);

#if 0
    if(!l->hfxor)
    {
     tda |= (hm >> 28) & (0xF <<  0);
     tda |= (hm >> 16) & (0xF <<  8);
     tda |= (hm >>  4) & (0xF << 16);
     tda |= (hm <<  8) & (0xF << 24);
     tdb |= (hm >> 12) & (0xF <<  0);	// >>12
     tdb |= (hm <<  0) & (0xF <<  8);	// >>8
     tdb |= (hm << 12) & (0xF << 16);	// >>4
     tdb |= (hm << 24) & (0xF << 24);	// >>0
    }
    else
    {
     tda |= (hm <<  0) & (0xF <<  0);
     tda |= (hm <<  4) & (0xF <<  8);
     tda |= (hm <<  8) & (0xF << 16);
     tda |= (hm << 12) & (0xF << 24);
     tdb |= (hm >> 16) & (0xF <<  0);
     tdb |= (hm >> 12) & (0xF <<  8);
     tdb |= (hm >>  8) & (0xF << 16);
     tdb |= (hm >>  4) & (0xF << 24);
    }
#else
    if(!l->hfxor)
    {
     tda |= ((hm >> 28) & 0xF) <<  0;
     tda |= ((hm >> 24) & 0xF) <<  8;
     tda |= ((hm >> 20) & 0xF) << 16;
     tda |= ((hm >> 16) & 0xF) << 24;
     tdb |= ((hm >> 12) & 0xF) <<  0;
     tdb |= ((hm >>  8) & 0xF) <<  8;
     tdb |= ((hm >>  4) & 0xF) << 16;
     tdb |= ((hm >>  0) & 0xF) << 24;
    }
    else
    {
     tda |= ((hm >>  0) & 0xF) <<  0;
     tda |= ((hm >>  4) & 0xF) <<  8;
     tda |= ((hm >>  8) & 0xF) << 16;
     tda |= ((hm >> 12) & 0xF) << 24;
     tdb |= ((hm >> 16) & 0xF) <<  0;
     tdb |= ((hm >> 20) & 0xF) <<  8;
     tdb |= ((hm >> 24) & 0xF) << 16;
     tdb |= ((hm >> 28) & 0xF) << 24;
    }
#endif
    t->tda = tda;
    t->tdb = tdb;
   }
  }
 }
 ExitTileLoop: ;
}

static INLINE void DrawSprites(void)
{
 unsigned prio_or_mask = 0xFFFF;

 memset(PPU.objbuf + 8, 0, sizeof(PPU.objbuf[0]) * 256);

 if(!(CGADSUB & 0x10))
  prio_or_mask &= ~0x0001;

 if(!(SSEnable & 0x10))
  prio_or_mask &= ~0xF000;

 if(!(MSEnable & 0x10))
  prio_or_mask &= ~0x00F0;

 for(unsigned i = 0; i < PPU.SpriteTileCount; i++)
 {
  auto* const t = &PPU.SpriteTileList[i];
  uint32 tda = t->tda;
  uint32 tdb = t->tdb;
  uint32* tb = PPU.objbuf + 8 + t->x;
  uint32 prio_or = t->prio_or & prio_or_mask;

  for(unsigned x = 0; x < 4; x++)
  {
   if(tda & 0xF)
    tb[x] = (CGRAM[(uint8)tda] << 16) | prio_or;

   if(tdb & 0xF)
    tb[4 + x] = (CGRAM[(uint8)tdb] << 16) | prio_or;

   tda >>= 8;
   tdb >>= 8;
  }
 }

 PPU.SpriteTileCount = 0;
}


static struct
{
 uint32 OutputLUT[384];
 union
 {
  uint32 bg[4][8 + 256 + 16];		// 8(x scroll), 16(tile overflow, mosaic)
  uint32 bghr[2][16 + 512 + 32];	// BG modes 5 and 6

  struct
  {
   uint32 main[256];
   uint32 dummy[8 + 16 + (8 + 256 + 16)];
   uint32 sub[256];
  };
 };
} linebuf;

#ifndef _MSC_VER
static_assert(linebuf.main == linebuf.bg[0], "linebuf structure malformed.");
static_assert(linebuf.main == linebuf.bghr[0], "linebuf structure malformed.");
static_assert(linebuf.sub == linebuf.bg[2], "linebuf structure malformed.");
static_assert(linebuf.sub == linebuf.bghr[1], "linebuf structure malformed.");
#endif

template<bool size16, bool mode4 = false>
static MDFN_HOT MDFN_FASTCALL void GetOPTStrip(const unsigned n)
{
 unsigned VOFS = BGVOFS[n];
 unsigned HOFS = BGHOFS[n];
 unsigned tm_w_mask = ((BGSC[n] & 0x1) << 10);
 unsigned tm_h_shift = ((BGSC[n] & 0x2) ? ((BGSC[n] & 0x1) ? 3 : 2) : 24);

 uint32 tmbase = (BGSC[n] & 0xFC) << 8;
 uint32 tmoffs;
 uint32 tmxor;
 bool tile_num_offs = false;

 if(size16)
 {
  tile_num_offs = (HOFS & 0x8);
  HOFS >>= 1;
  VOFS >>= 1;
 }

 tmoffs = (HOFS >> 3) & 0x1F;
 tmoffs += (HOFS << 2) & tm_w_mask;
 tmoffs += ((VOFS << 2) & 0x3E0) | ((VOFS & 0x100) << tm_h_shift);

 {
  unsigned VOFS_Next = BGVOFS[n] + 8;
  unsigned tmoffs_next;

  if(size16)
   VOFS_Next >>= 1;

  tmoffs_next = (HOFS >> 3) & 0x1F;
  tmoffs_next += (HOFS << 2) & tm_w_mask;
  tmoffs_next += ((VOFS_Next << 2) & 0x3E0) | ((VOFS_Next & 0x100) << tm_h_shift);

  tmxor = tmoffs ^ tmoffs_next;
 }

 for(unsigned i = 0; i < 33; i++)
 {
  uint32 tmp = VRAM[(tmbase + tmoffs) & 0x7FFF];

  if(mode4)
  {
   tmp <<= (tmp & 0x8000) >> 11;
  }
  else
  {
   tmp |= (VRAM[(tmbase + (tmoffs ^ tmxor)) & 0x7FFF] << 16);
  }
  linebuf.bg[2][i] = tmp;

  if(!size16 || tile_num_offs)
  {
   tmoffs++;

   if(!(tmoffs & 0x1F))
   {
    tmoffs -= 0x20;
    tmoffs ^= tm_w_mask;
   }
  }

  if(size16)
   tile_num_offs = !tile_num_offs;
 }
}

static INLINE unsigned DirColCvt(unsigned inpix, unsigned palbase = 0)
{
 unsigned ret;

 ret =  ((inpix & 0x07) << 2);
 ret |= ((inpix & 0x38) << 4);
 ret |= ((inpix & 0xC0) << 7);

 ret |= (palbase & 0x8) << 9;
 ret |= (palbase & 0x4) << 4;
 ret |= (palbase & 0x1) << 1;

 return ret;
}

template<bool size16, unsigned bpp, bool palbase_n = false, bool opt = false, bool hires = false, bool dircolor = false>
static MDFN_HOT MDFN_FASTCALL void DrawBG(const unsigned n, const unsigned y, uint32 prio_or)
{
 alignas(4) uint16 tab[16];
 const bool MosaicOn = Mosaic & (1U << n);
 unsigned VOFS = y - (MosaicOn ? MosaicYOffset : 0);
 unsigned HOFS = BGHOFS[n];
 unsigned tm_w_mask = ((BGSC[n] & 0x1) << 10);
 unsigned tm_h_shift = ((BGSC[n] & 0x2) ? ((BGSC[n] & 0x1) ? 3 : 2) : 24);

 if(bpp == 4 || bpp == 2)
 {
  memcpy(tab, PPU.SpriteTileTab, sizeof(tab));
 }

 //if(scanline == 100 && n == 0)
 // MDFN_DispMessage("%d %d --- BGHOFS0=%u BGHOFS1=%u\n", hires, size16, BGHOFS[0], BGHOFS[1]);

 if(hires && (ScreenMode & 0x01))
 {
  VOFS <<= 1;

  if(!MosaicOn)
   VOFS += Status[1] >> 7;
 }

 VOFS += BGVOFS[n];
 //
 unsigned tile_y_offs = (VOFS & 0x7);
 //
 //
 //
 if(hires)
  HOFS <<= 1;

 uint32* target;

 // Make sure we go with [8] and not [7], or else we'll potentially have an invalid bounds pointer
 // in the pixel blitting loop further down in this function.
 if(hires)
  target = &linebuf.bghr[n][8];
 else
  target = &linebuf.bg[n][8];

 target -= HOFS & 0x7;

 //printf("%02x %04x\n", BGSC[n], BGVOFS[n]);

 uint32 chrbase = ((BGNBA[n >> 1] >> ((n & 1) * 4)) & 0xF) << 12;
 uint32 tmbase = (BGSC[n] & 0xFC) << 8;
 uint32 tmoffs;
 uint32 tile_num_offs = 0;

 if(hires || size16)
 {
  tile_num_offs |= ((HOFS & 0x8) >> 3);
  HOFS >>= 1;
 }

 if(size16)
 {
  tile_num_offs |= ((VOFS & 0x8) << 1);
  VOFS >>= 1;
 }

 tmoffs = (HOFS >> 3) & 0x1F;
 tmoffs += (HOFS << 2) & tm_w_mask;
 tmoffs += ((VOFS << 2) & 0x3E0) | ((VOFS & 0x100) << tm_h_shift);

 for(unsigned i = 0; i < ((hires ? 64 : 32) + 1); i++)
 {
  const uint32 nte = VRAM[(tmbase + tmoffs) & 0x7FFF];
  const uint32 v_flip_xor = ((int16)nte >> 16) & 0x7;
  const bool h_flip = nte & 0x4000;
  const uint32 eff_prio_or = ((nte & 0x2000) ? (prio_or >> 16) : (prio_or >> 0)) & 0xFFFF;
  const uint32 pal_base = ((nte & 0x1C00) >> 10);
  uint32 tno_flipped = 0;
  uint32 tile_num;

  if(size16 || hires)
   tno_flipped = tile_num_offs ^ h_flip;

  if(size16)
   tno_flipped ^= (v_flip_xor << 2) & 0x10;

  tile_num = (nte + tno_flipped) & 0x3FF;

  //printf("%3d, %3d, %04x, %04x --- %04x\n", y, i, tmbase, (tmbase + tmoffs) & 0x7FFF, nte);

  const uint16* const vchr = &VRAM[(chrbase + (tile_y_offs ^ v_flip_xor) + (tile_num * (bpp / 2) * 8) + 0) & 0x7FFF];
  const uint16* const cgr = CGRAM + (bpp == 8 ? 0 : ((pal_base << bpp) + (palbase_n ? (n << 5) : 0)));
  //
  const size_t subtarg_inc = h_flip ? 1 : -1;
  const uint32* subtarg_bound = target + (h_flip ? 8 : -1);
  uint32* subtarg = target + (h_flip ? 0 : 7);

  static_assert(bpp == 2 || bpp == 4 || bpp == 8, "wrong bpp");
  if(bpp == 2)
  {
   uint32 tmp[4] =
	{ (uint32)cgr[0] << 16,
	 ((uint32)cgr[1] << 16) | eff_prio_or,
	 ((uint32)cgr[2] << 16) | eff_prio_or,
	 ((uint32)cgr[3] << 16) | eff_prio_or };
   uint32 bp = vchr[0];
   uint32 hm = (tab[bp & 0xF] << 0) + (tab[(bp >> 4) & 0xF] << 16) + (tab[(bp >> 8) & 0xF] << 1) + (tab[(bp >> 12) & 0xF] << 17);

#if 0
   if(h_flip)
   {
    target[0] = tmp[((bp     ) & 0x01) | ((bp >>  7) & 0x02)];
    target[1] = tmp[((bp >> 1) & 0x01) | ((bp >>  8) & 0x02)];
    target[2] = tmp[((bp >> 2) & 0x01) | ((bp >>  9) & 0x02)];
    target[3] = tmp[((bp >> 3) & 0x01) | ((bp >> 10) & 0x02)];
    target[4] = tmp[((bp >> 4) & 0x01) | ((bp >> 11) & 0x02)];
    target[5] = tmp[((bp >> 5) & 0x01) | ((bp >> 12) & 0x02)];
    target[6] = tmp[((bp >> 6) & 0x01) | ((bp >> 13) & 0x02)];
    target[7] = tmp[((bp >> 7) & 0x01) | ((bp >> 14) & 0x02)];
   }
   else
   {
    target[0] = tmp[((bp >> 7) & 0x01) | ((bp >> 14) & 0x02)];
    target[1] = tmp[((bp >> 6) & 0x01) | ((bp >> 13) & 0x02)];
    target[2] = tmp[((bp >> 5) & 0x01) | ((bp >> 12) & 0x02)];
    target[3] = tmp[((bp >> 4) & 0x01) | ((bp >> 11) & 0x02)];
    target[4] = tmp[((bp >> 3) & 0x01) | ((bp >> 10) & 0x02)];
    target[5] = tmp[((bp >> 2) & 0x01) | ((bp >>  9) & 0x02)];
    target[6] = tmp[((bp >> 1) & 0x01) | ((bp >>  8) & 0x02)];
    target[7] = tmp[((bp     ) & 0x01) | ((bp >>  7) & 0x02)];
   }
#else
   if(h_flip)
   {
    target[0] = tmp[(hm >> 0) & 0x3];
    target[1] = tmp[(hm >> 4) & 0x3];
    target[2] = tmp[(hm >> 8) & 0x3];
    target[3] = tmp[(hm >> 12) & 0x3];
    target[4] = tmp[(hm >> 16) & 0x3];
    target[5] = tmp[(hm >> 20) & 0x3];
    target[6] = tmp[(hm >> 24) & 0x3];
    target[7] = tmp[(hm >> 28) & 0x3];
   }
   else
   {
    target[0] = tmp[(hm >> 28) & 0x3];
    target[1] = tmp[(hm >> 24) & 0x3];
    target[2] = tmp[(hm >> 20) & 0x3];
    target[3] = tmp[(hm >> 16) & 0x3];
    target[4] = tmp[(hm >> 12) & 0x3];
    target[5] = tmp[(hm >>  8) & 0x3];
    target[6] = tmp[(hm >>  4) & 0x3];
    target[7] = tmp[(hm >>  0) & 0x3];
   }
#endif
  }
  else if(bpp == 4)
  {
   uint32 bpa = vchr[0];
   uint32 bpb = vchr[8];
   uint32 hm = (tab[bpa & 0xF] << 0) + (tab[(bpa >> 4) & 0xF] << 16) + (tab[(bpa >> 8) & 0xF] << 1) + (tab[(bpa >> 12) & 0xF] << 17) + (tab[bpb & 0xF] << 2) + (tab[(bpb >> 4) & 0xF] << 18) + (tab[(bpb >> 8) & 0xF] << 3) + (tab[(bpb >> 12) & 0xF] << 19);
   size_t pix;

   pix = (hm >> 0) & 0xF; subtarg[0]           = (cgr[pix] << 16) | (pix ? eff_prio_or : 0);
   pix = (hm >> 4) & 0xF; subtarg[subtarg_inc] = (cgr[pix] << 16) | (pix ? eff_prio_or : 0);
   subtarg += subtarg_inc << 1;
   pix = (hm >>  8) & 0xF; subtarg[0]           = (cgr[pix] << 16) | (pix ? eff_prio_or : 0);
   pix = (hm >> 12) & 0xF; subtarg[subtarg_inc] = (cgr[pix] << 16) | (pix ? eff_prio_or : 0);
   subtarg += subtarg_inc << 1;
   pix = (hm >> 16) & 0xF; subtarg[0]           = (cgr[pix] << 16) | (pix ? eff_prio_or : 0);
   pix = (hm >> 20) & 0xF; subtarg[subtarg_inc] = (cgr[pix] << 16) | (pix ? eff_prio_or : 0);
   subtarg += subtarg_inc << 1;
   pix = (hm >> 24) & 0xF; subtarg[0]           = (cgr[pix] << 16) | (pix ? eff_prio_or : 0);
   pix = (hm >> 28) & 0xF; subtarg[subtarg_inc] = (cgr[pix] << 16) | (pix ? eff_prio_or : 0);
   subtarg += subtarg_inc << 1;
#if 0
   uint32 bp = vchr[0] | ((uint32)vchr[8] << 16);
   uint32 bp2;
   size_t pix;
   for(; MDFN_LIKELY(subtarg != subtarg_bound); subtarg += subtarg_inc << 1, bp >>= 2)
   {
    bp2 = bp & 0x01010101; pix = (uint8)((bp2     ) | (bp2 >> 7) | (bp2 >> 14) | (bp2 >> 21)); subtarg[0]           = (cgr[pix] << 16) | (pix ? eff_prio_or : 0);
    bp2 = bp & 0x02020202; pix = (uint8)((bp2 >> 1) | (bp2 >> 8) | (bp2 >> 15) | (bp2 >> 22)); subtarg[subtarg_inc] = (cgr[pix] << 16) | (pix ? eff_prio_or : 0);
   }
#endif
  }
  else if(bpp == 8)
  {
   uint64 bp = vchr[0] | ((uint32)vchr[8] << 16) | ((uint64)vchr[16] << 32) | ((uint64)vchr[24] << 48);
   for(; MDFN_LIKELY(subtarg != subtarg_bound); subtarg += subtarg_inc, bp >>= 1)
   {
    const uint64 bp2 = bp & 0x0101010101010101ULL;
    const size_t pix = (uint8)(bp2 | (bp2 >> 7) | (bp2 >> 14) | (bp2 >> 21) | (bp2 >> 28) | (bp2 >> 35) | (bp2 >> 42) | (bp2 >> 49));
    *subtarg = ((dircolor ? DirColCvt(pix, pal_base) : cgr[pix]) << 16) | (pix ? eff_prio_or : 0);
   }
  }

  if(!(size16 || hires) || (tile_num_offs & 1))
  {
   tmoffs++;

   if(!(tmoffs & 0x1F))
   {
    tmoffs -= 0x20;
    tmoffs ^= tm_w_mask;
   }
  }

  if(size16 || hires)
   tile_num_offs ^= 1;

  if(opt)
  {
   unsigned hvo = linebuf.bg[2][i];

   HOFS = BGHOFS[n];
   if(hvo & (0x2000 << n))
   {
    HOFS = (uint16)hvo;
   }

   if(hires)
    HOFS <<= 1;

   HOFS += ((i + 1) << 3);

   VOFS = BGVOFS[n];

   if(hvo & (0x20000000 << n))
    VOFS = (uint16)(hvo >> 16);
   VOFS += (y - ((Mosaic & (1U << n)) ? MosaicYOffset : 0));

   tile_y_offs = (VOFS & 0x7);

   tile_num_offs = 0;

   if(hires || size16)
   {
    tile_num_offs |= ((HOFS & 0x8) >> 3);
    HOFS >>= 1;
   }

   if(size16)
   {
    tile_num_offs |= ((VOFS & 0x8) << 1);
    VOFS >>= 1;
   }
   tmoffs = (HOFS >> 3) & 0x1F;
   tmoffs += (HOFS << 2) & tm_w_mask;
   tmoffs += ((VOFS << 2) & 0x3E0) | ((VOFS & 0x100) << tm_h_shift);
  }

  target += 8;
 }
}

static INLINE int16 funny(int16 val)
{
 int16 ret = val & 0x3FF;

 if(val & 0x2000)
  ret |= ~0x3FF;

 return ret;
}

static INLINE int M7Mul(int16 matval, int16 ov)
{
 return (matval * ov) &~ 0x3F;
}

// Mode 7, scary cake time!
template<bool extbg, bool dircolor>
static MDFN_HOT MDFN_FASTCALL void DrawMODE7(unsigned line_y, uint16 prio_or, uint32 prio_or_bg1 = 0)
{
 const bool h_flip = M7SEL & 0x01;
 const bool v_flip = M7SEL & 0x02;
 const bool size = M7SEL & 0x80;
 const bool empty_fill = M7SEL & 0x40;

 unsigned x, y;
 unsigned xinc, yinc;

 line_y -= ((Mosaic & 0x1) ? MosaicYOffset : 0);

 if(v_flip)
  line_y ^= 0xFF;

 int16 hoca = funny(M7HOFS - M7Center[0]);
 int16 voca = funny(M7VOFS - M7Center[1]);

 x = M7Mul(M7Matrix[0], hoca) + M7Mul(M7Matrix[1], line_y) + M7Mul(M7Matrix[1], voca) + (M7Center[0] << 8);
 y = M7Mul(M7Matrix[2], hoca) + M7Mul(M7Matrix[3], line_y) + M7Mul(M7Matrix[3], voca) + (M7Center[1] << 8);

 xinc = M7Matrix[0];
 yinc = M7Matrix[2];

 if(h_flip)
 {
  x += 255 * xinc;
  y += 255 * yinc;

  xinc = -xinc;
  yinc = -yinc;
 }

 for(unsigned i = 0; i < 256; i++)
 {
  unsigned pix;
  unsigned xi = x >> 8;
  unsigned yi = y >> 8;
  uint8 tilenum, tiledata;

  tilenum = VRAM[(((yi & 0x3FF) >> 3) << 7) | ((xi & 0x3FF) >> 3)];
  tiledata = VRAM[(tilenum << 6) + ((yi & 0x7) << 3) + (xi & 0x7)] >> 8;

  if(size && ((xi | yi) &~ 0x3FF))
  {
   tiledata = 0;
   if(empty_fill)
    tiledata = VRAM[((yi & 0x7) << 3) + (xi & 0x7)] >> 8;
  }

  pix = tiledata;

  (linebuf.bg[0] + 8)[i] = ((dircolor ? DirColCvt(pix) : CGRAM[pix]) << 16) | (pix ? prio_or : 0);
  if(extbg)
   (linebuf.bg[1] + 8)[i] = ((dircolor ? DirColCvt(pix & 0x7F) : CGRAM[pix & 0x7F]) << 16) | ((pix & 0x7F) ? (uint16)(prio_or_bg1 >> ((pix & 0x80) >> 3)) : 0);

  x += xinc;
  y += yinc;
 }
}


// Y mosaic is handled in DrawBG
#pragma GCC push_options
#pragma GCC optimize("no-unroll-loops,no-peel-loops,no-crossjumping")
template<bool hires = false>
static MDFN_HOT MDFN_FASTCALL NO_INLINE void DoXMosaic(unsigned layernum, uint32* MDFN_RESTRICT buf)
{
 if(!(Mosaic & (1U << layernum)))
  return;

 if(!hires && !(Mosaic & 0xF0))
  return;

 if(hires)
 {
  const unsigned sub_max = Mosaic >> 4;

  for(unsigned x = 0; x < 512;)
  {
   uint32 b = buf[x];
   for(int sub = sub_max; sub >= 0; sub--, x += 2)
   {
    buf[x + 0] = b;
    buf[x + 1] = b;
   }
  }
 }
 else switch(Mosaic >> 4)
 {
  case 0x1: for(unsigned x = 0; x < 256; x += 0x2) { uint32 b = buf[x]; buf[x + 1] = b; } break;
  case 0x2: for(unsigned x = 0; x < 256; x += 0x3) { uint32 b = buf[x]; buf[x + 1] = b; buf[x + 2] = b; } break;
  case 0x3: for(unsigned x = 0; x < 256; x += 0x4) { uint32 b = buf[x]; buf[x + 1] = b; buf[x + 2] = b; buf[x + 3] = b; } break;
  case 0x4: for(unsigned x = 0; x < 256; x += 0x5) { uint32 b = buf[x]; buf[x + 1] = b; buf[x + 2] = b; buf[x + 3] = b; buf[x + 4] = b; } break;
  case 0x5: for(unsigned x = 0; x < 256; x += 0x6) { uint32 b = buf[x]; buf[x + 1] = b; buf[x + 2] = b; buf[x + 3] = b; buf[x + 4] = b; buf[x + 5] = b; } break;
  case 0x6: for(unsigned x = 0; x < 256; x += 0x7) { uint32 b = buf[x]; buf[x + 1] = b; buf[x + 2] = b; buf[x + 3] = b; buf[x + 4] = b; buf[x + 5] = b; buf[x + 6] = b; } break;
  case 0x7: for(unsigned x = 0; x < 256; x += 0x8) { uint32 b = buf[x]; buf[x + 1] = b; buf[x + 2] = b; buf[x + 3] = b; buf[x + 4] = b; buf[x + 5] = b; buf[x + 6] = b; buf[x + 7] = b; } break;
  case 0x8: for(unsigned x = 0; x < 256; x += 0x9) { uint32 b = buf[x]; buf[x + 1] = b; buf[x + 2] = b; buf[x + 3] = b; buf[x + 4] = b; buf[x + 5] = b; buf[x + 6] = b; buf[x + 7] = b; buf[x + 8] = b; } break;
  case 0x9: for(unsigned x = 0; x < 256; x += 0xA) { uint32 b = buf[x]; buf[x + 1] = b; buf[x + 2] = b; buf[x + 3] = b; buf[x + 4] = b; buf[x + 5] = b; buf[x + 6] = b; buf[x + 7] = b; buf[x + 8] = b; buf[x + 9] = b; } break;
  case 0xA: for(unsigned x = 0; x < 256; x += 0xB) { uint32 b = buf[x]; buf[x + 1] = b; buf[x + 2] = b; buf[x + 3] = b; buf[x + 4] = b; buf[x + 5] = b; buf[x + 6] = b; buf[x + 7] = b; buf[x + 8] = b; buf[x + 9] = b; buf[x + 10] = b; } break;
  case 0xB: for(unsigned x = 0; x < 256; x += 0xC) { uint32 b = buf[x]; buf[x + 1] = b; buf[x + 2] = b; buf[x + 3] = b; buf[x + 4] = b; buf[x + 5] = b; buf[x + 6] = b; buf[x + 7] = b; buf[x + 8] = b; buf[x + 9] = b; buf[x + 10] = b; buf[x + 11] = b; } break;
  case 0xC: for(unsigned x = 0; x < 256; x += 0xD) { uint32 b = buf[x]; buf[x + 1] = b; buf[x + 2] = b; buf[x + 3] = b; buf[x + 4] = b; buf[x + 5] = b; buf[x + 6] = b; buf[x + 7] = b; buf[x + 8] = b; buf[x + 9] = b; buf[x + 10] = b; buf[x + 11] = b; buf[x + 12] = b; } break;
  case 0xD: for(unsigned x = 0; x < 256; x += 0xE) { uint32 b = buf[x]; buf[x + 1] = b; buf[x + 2] = b; buf[x + 3] = b; buf[x + 4] = b; buf[x + 5] = b; buf[x + 6] = b; buf[x + 7] = b; buf[x + 8] = b; buf[x + 9] = b; buf[x + 10] = b; buf[x + 11] = b; buf[x + 12] = b; buf[x + 13] = b; } break;
  case 0xE: for(unsigned x = 0; x < 256; x += 0xF) { uint32 b = buf[x]; buf[x + 1] = b; buf[x + 2] = b; buf[x + 3] = b; buf[x + 4] = b; buf[x + 5] = b; buf[x + 6] = b; buf[x + 7] = b; buf[x + 8] = b; buf[x + 9] = b; buf[x + 10] = b; buf[x + 11] = b; buf[x + 12] = b; buf[x + 13] = b; buf[x + 14] = b; } break;
  case 0xF: for(unsigned x = 0; x < 256; x += 0x10) { uint32 b = buf[x]; buf[x + 1] = b; buf[x + 2] = b; buf[x + 3] = b; buf[x + 4] = b; buf[x + 5] = b; buf[x + 6] = b; buf[x + 7] = b; buf[x + 8] = b; buf[x + 9] = b; buf[x + 10] = b; buf[x + 11] = b; buf[x + 12] = b; buf[x + 13] = b; buf[x + 14] = b; buf[x + 15] = b;} break;
 }
}
#pragma GCC pop_options

static INLINE void CalcWindowPieces(void)
{
 WindowPieces[0] = WindowPos[0][0];
 WindowPieces[1] = WindowPos[0][1] + 1;

 if(WindowPieces[0] > WindowPieces[1])
  WindowPieces[0] = WindowPieces[1] = 0;

 WindowPieces[2] = WindowPos[1][0];
 WindowPieces[3] = WindowPos[1][1] + 1;

 if(WindowPieces[2] > WindowPieces[3])
  WindowPieces[2] = WindowPieces[3] = 0;

 if(WindowPieces[0] > WindowPieces[2])
  std::swap(WindowPieces[0], WindowPieces[2]);

 if(WindowPieces[1] > WindowPieces[3])
  std::swap(WindowPieces[1], WindowPieces[3]);

 if(WindowPieces[1] > WindowPieces[2])
  std::swap(WindowPieces[1], WindowPieces[2]);

 WindowPieces[4] = 0x100;
}

template<bool cwin = false, bool hires = false>
static MDFN_HOT MDFN_FASTCALL void DoWindow(unsigned layernum, uint32* MDFN_RESTRICT buf)
{
 const unsigned mask_settings = (WMSettings[layernum >> 1] >> ((layernum & 1) << 2)) & 0xF;
 const unsigned mask_logic = (WMLogic >> (layernum * 2)) & 0x3;
 uint32 masker[2];	// out, in
 bool W0Enabled, W1Enabled;
 bool W0Invert, W1Invert;

 static_assert(!cwin || !hires, "DoWindow() template arg error.");

 //if(mask_settings)
 // printf("Layer: %u, mask_settings = 0x%02x\n", layernum, mask_settings);

 // mask_settings
 // d0 = window1 inversion
 // d1 = window1 enable
 // d2 = window2 inversion
 // d3 = window2 enable

 W0Invert = mask_settings & 0x01;
 W0Enabled = mask_settings & 0x02;

 W1Invert = mask_settings & 0x04;
 W1Enabled = mask_settings & 0x08;

 if(!W0Enabled && !W1Enabled && !cwin)
  return;

 masker[0] = ~0U;
 masker[1] = ~0U;

 if(cwin)
 {
  assert(layernum == 5);

  //puts("Color Window");

  // ~1, not ~3 (otherwise will break half-color math testing stuff).
  switch((CGWSEL >> 4) & 0x3)
  {
   case 0: break;
   case 1: masker[0] &= ~1; break;
   case 2: masker[1] &= ~1; break;
   case 3: masker[0] &= ~1; masker[1] &= ~1; break;
  }

  switch((CGWSEL >> 6) & 0x3)
  {
   case 0: break;
   case 1: masker[0] &= 9; break;
   case 2: masker[1] &= 9; break;
   case 3: masker[0] &= 9; masker[1] &= 9; break;
  }

  if(!masker[0])
  {
   SNES_DBG("[PPU] Color Window Masker 0 == 0?!\n");
   //masker[0] = ~0U;
  }

  if(!masker[1])
  {
   SNES_DBG("[PPU] Color Window Masker 1 == 0?!\n");
   //masker[1] = ~0U;
  }
 }
 else
 {
  if(WMMainEnable & (1U << layernum))
  {
   masker[1] &= ~0x00FF;
  }

  if(WMSubEnable & (1U << layernum))
  {
   masker[1] &= ~0xFF00;
  }

  if(!((WMMainEnable | WMSubEnable) & (1U << layernum)))
   return;
 }

#if 0
 if(scanline == 100 || scanline == 140 || scanline == 50)
 {
  printf("Scanline=%3u, Layer %u window: masker[0]=0x%08x, masker[1]=0x%08x, W0Enabled=%d, W1Enabled=%d, W0Invert=%d, W1Invert=%d, mask_logic=0x%02x, Window0 %u...%u, Window1 %u...%u --- CGWSEL=0x%02x, CGADSUB=0x%02x, MSEnable=0x%02x, SSEnable=0x%02x, BGMode=0x%02x, WMMainEnable=0x%02x, WMSubEnable=0x%02x, WMSettings=0x%02x 0x%02x 0x%02x\n",
	scanline,
	layernum, 
	masker[0], masker[1],
	W0Enabled, W1Enabled,
	W0Invert, W1Invert,
	mask_logic,
	WindowPos[0][0], WindowPos[0][1],	
	WindowPos[1][0], WindowPos[1][1],
	CGWSEL,
        CGADSUB,
	MSEnable,
	SSEnable,
	BGMode,
	WMMainEnable,
	WMSubEnable,
	WMSettings[0],
	WMSettings[1],
	WMSettings[2]);
 }
#endif

#if 0
 if(cwin && scanline == 100)
 {
  printf("Color window: masker[0]=0x%08x, masker[1]=0x%08x, W0Enabled=%d, W1Enabled=%d, W0Invert=%d, W1Invert=%d, mask_logic=0x%02x, Window0 %u...%u, Window1 %u...%u\n", masker[0], masker[1],
	W0Enabled, W1Enabled,
	W0Invert, W1Invert,
	mask_logic,
	WindowPos[0][0], WindowPos[0][1],	
	WindowPos[1][0], WindowPos[1][1]);
 }
#endif

 {
  unsigned i = 0;

  for(unsigned piece = 0; piece < 5; piece++)
  {
   bool wir[2];
   bool w = false;

   wir[0] = (i >= WindowPos[0][0] && i <= WindowPos[0][1]) ^ W0Invert;
   wir[1] = (i >= WindowPos[1][0] && i <= WindowPos[1][1]) ^ W1Invert;

   if(W0Enabled && W1Enabled)
   {
    switch(mask_logic)
    {
     case 0: w = wir[0] | wir[1]; break;
     case 1: w = wir[0] & wir[1]; break;
     case 2: w = wir[0] ^ wir[1]; break;
     case 3: w = !(wir[0] ^ wir[1]); break;
    }
   }
   else if(W0Enabled)
    w = wir[0];
   else if(W1Enabled)
    w = wir[1];

   //if(scanline == 100)
   //{
   // printf(" Apply mask 0x%08x to %u ... %u --- wir[0]=%u, wir[1]=%u, w=%u\n", masker[w], i, WindowPieces[piece], wir[0], wir[1], w);
   //}

   for(uint32 eff_mask = masker[w]; MDFN_LIKELY(i < WindowPieces[piece]); i++)
   {
    if(hires)
    {
     (buf + 0)[i << 1] &= eff_mask;
     (buf + 1)[i << 1] &= eff_mask;
    }
    else
     buf[i] &= eff_mask;
   }
  }
 }
}


template<unsigned bpp, bool palbase_n = false, bool opt = false, bool hires = false>
static INLINE void DoBGLayer(unsigned n, uint32 bgprio)
{
 if(bpp == 8 && (CGWSEL & 0x01))
 {
  if(BGMode & (0x10 << n))
   DrawBG<true,  bpp, palbase_n, opt, hires, true>(n, scanline, bgprio);
  else
   DrawBG<false, bpp, palbase_n, opt, hires, true>(n, scanline, bgprio);
 }
 else
 {
  if(BGMode & (0x10 << n))
   DrawBG<true,  bpp, palbase_n, opt, hires, false>(n, scanline, bgprio);
  else
   DrawBG<false, bpp, palbase_n, opt, hires, false>(n, scanline, bgprio);
 }

 if(hires)
 {
  DoXMosaic<true>(n, &linebuf.bghr[n][8]);
  DoWindow<false, true>(n, &linebuf.bghr[n][8]);
 }
 else
 {
  DoXMosaic(n, &linebuf.bg[n][8]);
  DoWindow(n, &linebuf.bg[n][8]);
 }
}

template<bool half, bool subtract>
static MDFN_HOT MDFN_FASTCALL uint32 CMath(uint32 tmp, uint32 other_color)
{
 if(half)
 {
  if(subtract)
  {
   uint32 diff = tmp - other_color + 0x8420;
   uint32 borrow = (diff - ((tmp ^ other_color) & 0x8420)) & 0x8420;

   tmp = (((diff - borrow) & (borrow - (borrow >> 5))) & 0x7BDE) >> 1;
  }
  else
  {
   tmp = ((tmp + other_color) - ((tmp ^ other_color) & 0x0421)) >> 1;
  }
 }
 else
 {
  if(subtract)
  {
   uint32 diff = tmp - other_color + 0x8420;
   uint32 borrow = (diff - ((tmp ^ other_color) & 0x8420)) & 0x8420;

   tmp = (diff - borrow) & (borrow - (borrow >> 5));
  }
  else
  {
   uint32 sum = tmp + other_color;
   uint32 carry = (sum - ((tmp ^ other_color) & 0x421)) & 0x8420;

   tmp = (sum - carry) | (carry - (carry >> 5));
  }
 }

 return tmp;
}

static INLINE uint32 ConvertRGB555(uint32 tmp)
{
 return linebuf.OutputLUT[(uint8)tmp] | (linebuf.OutputLUT + 256)[(tmp >> 8) & 0x7F];
}

template<bool any_hires, unsigned cmath_mode, bool hires_cmath_add_subscreen = false, typename T>
static MDFN_HOT MDFN_FASTCALL NO_INLINE void MixMainSubSubSubMarine(T* MDFN_RESTRICT target)
{
 //if(scanline == 100)
 // fprintf(stderr, "CGWSEL=0x%02x, CGADSUB=0x%02x, WOBJSEL=0x%02x, WMLogic=0x%02x\n", CGWSEL, CGADSUB, WMSettings[2], WMLogic);

 if(any_hires)
 {
  // FIXME: hires color math.
  for(unsigned i = 0; i < 256; i++)
  {
   uint32 main = linebuf.main[i];
   uint32 sub = linebuf.sub[i];
   unsigned main_color = main >> 16;
   unsigned sub_color = sub >> 16;

   if(main & 1)
   {
    if(hires_cmath_add_subscreen) //CGWSEL & 0x2)
    {
     if(sub & 0x8)	// Is subscreen backdrop?  Then no half-math when (CGWSEL & 0x2)
     {
      main_color = CMath<false, (bool)(cmath_mode & 2)>(main_color, FixedColor);
      sub_color  = CMath<false, (bool)(cmath_mode & 2)>(sub_color,  FixedColor);
     }
     else
     {
      if((cmath_mode & 1) && (main & 2))	// If half math enabled, and main wasn't clipped to 0 by color window, then half math.
      {
       main_color = CMath<true,  (bool)(cmath_mode & 2)>(main_color, sub_color);
       sub_color  = CMath<true,  (bool)(cmath_mode & 2)>(sub_color,  main_color);
      }
      else
      {
       main_color = CMath<false, (bool)(cmath_mode & 2)>(main_color, sub_color);
       sub_color  = CMath<false, (bool)(cmath_mode & 2)>(sub_color,  main_color);
      }
     }
    }
    else
    {
     main_color = CMath<(bool)(cmath_mode & 1), (bool)(cmath_mode & 2)>(main_color, FixedColor);
     sub_color  = CMath<(bool)(cmath_mode & 1), (bool)(cmath_mode & 2)>(sub_color,  FixedColor);
    }
   }
   else if(!(main & 0x2))
    sub_color = 0; //rand();

   target[(i << 1) + 0] = ConvertRGB555(sub_color);
   target[(i << 1) + 1] = ConvertRGB555(main_color);
  }
 }
 else
 {
  for(unsigned i = 0; i < 256; i++)
  {
   uint32 main = linebuf.main[i];
   uint32 sub = linebuf.sub[i];
   uint32 tmp = main >> 16;

   if(main & 1)
   {
    uint16 other_color = sub >> 16;

    //assert(main != sub);

    if((cmath_mode & 1) && (main & sub & 2))	// Halving mathing
     tmp = CMath<true, (bool)(cmath_mode & 2)>(tmp, other_color);
    else
     tmp = CMath<false, (bool)(cmath_mode & 2)>(tmp, other_color);
   }

   target[i] = ConvertRGB555(tmp);
  }
 }
}

template<bool any_hires, bool rgb565, typename T>
static INLINE void ApplyBrightness(T* MDFN_RESTRICT target, uint32 bright)
{
  if(sizeof(T) == 2)
  {
   //
   // Note: Losing the lower green bit before multiplication in RGB565 mode is intentional.
   //
   const uint32 brightmul = (bright * 64 * 2 + 15) / (15 * 2);

   #ifdef HAVE_SSE2_INTRINSICS
   {
    __m128i rmask = _mm_set1_epi16(rgb565 ? 0xF800 : 0x7C00);
    __m128i gmask = _mm_set1_epi16(rgb565 ? 0x07E0 : 0x03E0);
    __m128i bmask = _mm_set1_epi16(0x001F);
    __m128i mul = _mm_set1_epi16(brightmul);

    for(unsigned i = 0; MDFN_LIKELY(i < (256 << any_hires)); i += 8)
    {
     __m128i pix = _mm_load_si128((__m128i *)&target[i]);
     __m128i r, g, b;

     b = _mm_and_si128(pix, bmask);
     g = _mm_and_si128(pix, gmask);
     r = _mm_and_si128(pix, rmask);

     b = _mm_mullo_epi16(b, mul);
     g = _mm_srli_epi16(g, rgb565 ? 6 : 5);
     r = _mm_srli_epi16(r, 6);

     g = _mm_mullo_epi16(g, mul);
     b = _mm_srli_epi16(b, 6);
     r = _mm_mullo_epi16(r, mul);

     if(!rgb565)
      g = _mm_srli_epi16(g, 1);
     b = _mm_and_si128(b, bmask);
     r = _mm_and_si128(r, rmask);

     g = _mm_and_si128(g, gmask);
     //
     //
     _mm_store_si128((__m128i *)&target[i], _mm_add_epi16(g, _mm_add_epi16(r, b)));
    }
   }
   #elif defined(HAVE_MMX_INTRINSICS)
   {
    __m64 rmask = _mm_set1_pi16(rgb565 ? 0xF800 : 0x7C00);
    __m64 gmask = _mm_set1_pi16(rgb565 ? 0x07E0 : 0x03E0);
    __m64 bmask = _mm_set1_pi16(0x001F);
    __m64 mul = _mm_set1_pi16(brightmul);

    for(unsigned i = 0; MDFN_LIKELY(i < (256 << any_hires)); i += 4)
    {
     __m64 pix;
     __m64 r, g, b;

     memcpy(&pix, &target[i], sizeof(__m64));

     b = _mm_and_si64(pix, bmask);
     g = _mm_and_si64(pix, gmask);
     r = _mm_and_si64(pix, rmask);

     b = _mm_mullo_pi16(b, mul);
     g = _mm_srli_pi16(g, rgb565 ? 6 : 5);
     r = _mm_srli_pi16(r, 6);

     g = _mm_mullo_pi16(g, mul);
     b = _mm_srli_pi16(b, 6);
     r = _mm_mullo_pi16(r, mul);

     if(!rgb565)
      g = _mm_srli_pi16(g, 1);
     b = _mm_and_si64(b, bmask);
     r = _mm_and_si64(r, rmask);

     g = _mm_and_si64(g, gmask);
     //
     //
     pix = _mm_add_pi16(g, _mm_add_pi16(r, b));
     memcpy(&target[i], &pix, sizeof(__m64));
    }
    _mm_empty();
   }
   #elif defined(HAVE_NEON_INTRINSICS)
   {
    register uint16x8_t rmask = vmovq_n_u16(rgb565 ? 0xF800 : 0x7C00);
    register uint16x8_t gmask = vmovq_n_u16(rgb565 ? 0x07E0 : 0x03E0);
    register uint16x8_t bmask = vmovq_n_u16(0x001F);
    register uint16x8_t mul = vmovq_n_u16(brightmul);

  //#pragma GCC unroll 0
    for(unsigned i = 0; MDFN_LIKELY(i < (256 << any_hires)); i += 8)
    {
     register uint16x8_t pix = vld1q_u16((uint16*)&target[i]);
     register uint16x8_t r, g, b;

     b = vandq_u16(pix, bmask);
     g = vandq_u16(pix, gmask);
     r = vandq_u16(pix, rmask);

     b = vmulq_u16(b, mul);
     g = vshrq_n_u16(g, rgb565 ? 6 : 5);
     r = vshrq_n_u16(r, 6);

     g = vmulq_u16(g, mul);
     b = vshrq_n_u16(b, 6);
     r = vmulq_u16(r, mul);

     if(!rgb565)
      g = vshrq_n_u16(g, 1);
     b = vandq_u16(b, bmask);
     r = vandq_u16(r, rmask);

     g = vandq_u16(g, gmask);
     //
     //
     vst1q_u16((uint16*)&target[i], vorrq_u16(g, vorrq_u16(r, b)));
    }
   }
   #else
   {
    for(unsigned i = 0; MDFN_LIKELY(i < (256 << any_hires)); i += 2)
    {
     uint32 pix = MDFN_densb<uint32, true>(&target[i]);

     if(rgb565)
      pix = ((((pix & 0x001F001F) * brightmul) >> 6) & 0x001F001F) +
	    ((((pix & 0xF800F800) >> 6) * brightmul) & 0xF800F800) +
	    ((((pix & 0x07C007C0) >> 6) * brightmul) & 0x07E007E0);
     else
      pix = ((((pix & 0x001F001F) * brightmul) >> 6) & 0x001F001F) +
	    ((((pix & 0x7C007C00) >> 6) * brightmul) & 0x7C007C00) +
	    (((((pix & 0x03E003E0) >> 5) * brightmul) >> 1) & 0x03E003E0);

     MDFN_ennsb<uint32, true>(&target[i], pix);
    }
   }
   #endif
  }
  else // else to if(sizeof(T) == 2)
  {
   const uint32 brightmul = bright * 17;

   for(unsigned i = 0; i < (256 << any_hires); i++)
   {
    const uint32 pix = target[i];

    target[i] = ((((pix & 0xFF00FF) * brightmul) >> 8) & 0xFF00FF) | ((((pix >> 8) & 0xFF00FF) * brightmul) & 0xFF00FF00);
   }
  }
}

template<bool any_hires, bool rgb565, typename T>
static INLINE void MixMainSub(T* MDFN_RESTRICT target)
{
 if(any_hires && MDFN_UNLIKELY(CGWSEL & 0x2))
 {
  switch((CGADSUB >> 6) & 0x3)
  {
   case 0: MixMainSubSubSubMarine<any_hires, 0, true>(target); break;
   case 1: MixMainSubSubSubMarine<any_hires, 1, true>(target); break;
   case 2: MixMainSubSubSubMarine<any_hires, 2, true>(target); break;
   case 3: MixMainSubSubSubMarine<any_hires, 3, true>(target); break;
  }
 }
 else 
 {
  switch((CGADSUB >> 6) & 0x3)
  {
   case 0: MixMainSubSubSubMarine<any_hires, 0>(target); break;
   case 1: MixMainSubSubSubMarine<any_hires, 1>(target); break;
   case 2: MixMainSubSubSubMarine<any_hires, 2>(target); break;
   case 3: MixMainSubSubSubMarine<any_hires, 3>(target); break;
  }
 }

 if((INIDisp & 0xF) != 0xF)
  ApplyBrightness<any_hires, rgb565>(target, INIDisp & 0xF);
}

#ifdef ARCH_X86
template<unsigned w, bool sub_unique>
static INLINE void PrioHelper(uint32& main, uint32& sub, uint32 np, uint32 nps = 0)
{
 if(sub_unique)
 {
  asm("cmpb %%cl, %%al\n\t"  "cmovb %%ecx, %%eax\n\t" : "=a"(main), "=b"(sub) : "a"(main), "b"(sub), "c"(np) : "cc");
  asm("cmpb %%dh, %%bh\n\t"  "cmovb %%edx, %%ebx\n\t" : "=a"(main), "=b"(sub) : "a"(main), "b"(sub), "d"(nps) : "cc");
 }
 else
 {
  if(w & 1)
  {
   asm("cmpb %%dl, %%al\n\t"  "cmovb %%edx, %%eax\n\t" : "=a"(main), "=b"(sub) : "a"(main), "b"(sub), "d"(np) : "cc");
   asm("cmpb %%dh, %%bh\n\t"  "cmovb %%edx, %%ebx\n\t" : "=a"(main), "=b"(sub) : "a"(main), "b"(sub), "d"(np) : "cc");
  }
  else
  {
   asm("cmpb %%cl, %%al\n\t"  "cmovb %%ecx, %%eax\n\t" : "=a"(main), "=b"(sub) : "a"(main), "b"(sub), "c"(np) : "cc");
   asm("cmpb %%ch, %%bh\n\t"  "cmovb %%ecx, %%ebx\n\t" : "=a"(main), "=b"(sub) : "a"(main), "b"(sub), "c"(np) : "cc");
  }
 }
}
#else
template<unsigned w, bool sub_unique>
static INLINE void PrioHelper(uint32& main, uint32& sub, uint32 np, uint32 nps = 0)
{
 if((uint8)np > (uint8)main)
  main = np;

 if(sub_unique)
 {
  if((uint16)nps > (uint16)sub)
   sub = nps;
 }
 else
 {
  if((uint16)np > (uint16)sub)
   sub = np;
 }
}
#endif

// hrop =  1 for modes 5 and 6 hires
// hrop = -1 for pseudo-hires
template<bool mix_bg0, bool mix_bg1, bool mix_bg2, bool mix_bg3, int hrop>
static MDFN_HOT void MixLayersSub(void)
{
 uint32 main_back, sub_back;

 static_assert(hrop != 1 || (mix_bg0 && mix_bg1 && !mix_bg2 && !mix_bg3), "hrop mix_bg* mismatch.");

 main_back = (CGRAM[0] << 16) | ((CGADSUB >> 5) & 1) | 2 | 0x808;

 //
 // Doing the subscreen FixedColor color math optimization doesn't really work out in hires mode...
 //
 if(hrop)
  sub_back = CGRAM[0] << 16;
 else
 {
  sub_back = (FixedColor << 16);

  // If only color mathing with FixedColor and not subscreen per-se, set half-math-allow bit(0x2), and force the priority to be above
  // any other layers that might otherwise unintentionally get mixed in.
  if(!(CGWSEL & 0x2))
   sub_back |= 0xF002;
 }

 sub_back |= 0x808;

 for(unsigned i = 0; i < 256; i++)
 {
  uint32 main = main_back, sub = sub_back;

  PrioHelper<0, false>(main, sub, (PPU.objbuf + 8)[i]);

  if(mix_bg0)
  {
   if(hrop == 1)
    PrioHelper<1, true>(main, sub, (linebuf.bghr[0] + 8 + 1)[i * 2], (linebuf.bghr[0] + 8 + 0)[i * 2]);
   else
    PrioHelper<1, false>(main, sub, (linebuf.bg[0] + 8)[i]);
  }
 
  if(mix_bg1)
  {
   if(hrop == 1)
    PrioHelper<2, true>(main, sub, (linebuf.bghr[1] + 8 + 1)[i * 2], (linebuf.bghr[1] + 8 + 0)[i * 2]);
   else
    PrioHelper<2, false>(main, sub, (linebuf.bg[1] + 8)[i]);
  }

  if(mix_bg2)
   PrioHelper<3, false>(main, sub, (linebuf.bg[2] + 8)[i]);

  if(mix_bg3)
   PrioHelper<4, false>(main, sub, (linebuf.bg[3] + 8)[i]);

  linebuf.main[i] = main;
  linebuf.sub[i] = sub;
 }
}

template<bool mix_bg0, bool mix_bg1, bool mix_bg2, bool mix_bg3, bool hires = false>
static INLINE void MixLayers(void)
{
 if(MDFN_UNLIKELY(hires))
  MixLayersSub<mix_bg0, mix_bg1, mix_bg2, mix_bg3,  hires>();
 else if(MDFN_UNLIKELY(ScreenMode & 0x08))
  MixLayersSub<mix_bg0, mix_bg1, mix_bg2, mix_bg3, -1>();
 else
  MixLayersSub<mix_bg0, mix_bg1, mix_bg2, mix_bg3, 0>();
}

static INLINE void GetBGPrioWCMBits(uint32* bgprio, unsigned count)
{
 for(unsigned i = 0; i < count; i++)
 {
  bgprio[i] |= (((CGADSUB >> i) & 1) * 0x00010001) | 0x00020002;

  if((SSEnable & (1U << i)))
   bgprio[i] |= (bgprio[i] & 0x00F000F0) << 8;

  if(!(MSEnable & (1U << i)))
   bgprio[i] &= ~0x00F000F0;
 }
}

static INLINE void DrawBGAndMixToMS(void)
{
 if((BGMode & 0x7) == 1)
 {
  uint32 bgprio[3] = { 0x00B00080, 0x00A00070, 0x00500020 + ((uint32)(BGMode & 0x8) << 20) };

  GetBGPrioWCMBits(bgprio, sizeof(bgprio) / sizeof(bgprio[0]));
  
  DoBGLayer<4>(0, bgprio[0]);
  DoBGLayer<4>(1, bgprio[1]);
  DoBGLayer<2>(2, bgprio[2]);

  MixLayers<true, true, true, false>();
 }
 else if((BGMode & 0x7) == 0)
 {
  uint32 bgprio[4] = { 0x00B00080, 0x00A00070, 0x00500020, 0x00400010};

  GetBGPrioWCMBits(bgprio, sizeof(bgprio) / sizeof(bgprio[0]));

  for(unsigned i = 0; i < 4; i++)
   DoBGLayer<2, true>(i, bgprio[i]);

  MixLayers<true, true, true, true>();
 }
 else if((BGMode & 0x3) == 2)
 {
  uint32 bgprio[2] = { 0x00A00040, 0x00800020 };

  GetBGPrioWCMBits(bgprio, sizeof(bgprio) / sizeof(bgprio[0]));

  if(BGMode & (0x10 << 2))
   GetOPTStrip<true>(2);
  else
   GetOPTStrip<false>(2);

  DoBGLayer<4, false, true>(0, bgprio[0]);
  DoBGLayer<4, false, true>(1, bgprio[1]);

  MixLayers<true, true, false, false>();
 }
 else if((BGMode & 0x7) == 3)
 {
  uint32 bgprio[2] = { 0x00A00040, 0x00800020 };

  GetBGPrioWCMBits(bgprio, sizeof(bgprio) / sizeof(bgprio[0]));

  DoBGLayer<8>(0, bgprio[0]);
  DoBGLayer<4>(1, bgprio[1]);

  MixLayers<true, true, false, false>();
 }
 else if((BGMode & 0x7) == 4)
 {
  uint32 bgprio[2] = { 0x00A00040, 0x00800020 };

  GetBGPrioWCMBits(bgprio, sizeof(bgprio) / sizeof(bgprio[0]));

  if(BGMode & (0x10 << 2))
   GetOPTStrip<true,  true>(2);
  else
   GetOPTStrip<false, true>(2);

  DoBGLayer<8, false, true>(0, bgprio[0]);
  DoBGLayer<2, false, true>(1, bgprio[1]);

  MixLayers<true, true, false, false>();
 }

 else if((BGMode & 0x7) == 5)
 {
  uint32 bgprio[2] = { 0x00A00040, 0x00800020 };

  GetBGPrioWCMBits(bgprio, sizeof(bgprio) / sizeof(bgprio[0]));

  DoBGLayer<4, false, false, true>(0, bgprio[0]);
  DoBGLayer<2, false, false, true>(1, bgprio[1]);

  MixLayers<true, true, false, false, true>();
 }
 else if((BGMode & 0x7) == 7)
 {
  if(MDFN_UNLIKELY(ScreenMode & 0x40))	// "EXTBG"
  {
   uint32 bgprio[2] = { 0x0040, 0x00800020 };

   GetBGPrioWCMBits(bgprio, sizeof(bgprio) / sizeof(bgprio[0]));

   if(CGWSEL & 1)
    DrawMODE7<true, true>(scanline, bgprio[0], bgprio[1]);
   else
    DrawMODE7<true, false>(scanline, bgprio[0], bgprio[1]);
   DoXMosaic(0, &linebuf.bg[0][8]);
   DoWindow(0, &linebuf.bg[0][8]);
   DoXMosaic(1, &linebuf.bg[1][8]);
   DoWindow(1, &linebuf.bg[1][8]);
   MixLayers<true, true, false, false>();
  }
  else
  {
   uint32 bgprio[1] = { 0x0040 };

   GetBGPrioWCMBits(bgprio, sizeof(bgprio) / sizeof(bgprio[0]));

   if(CGWSEL & 1)
    DrawMODE7<false, true>(scanline, bgprio[0]);
   else
    DrawMODE7<false, false>(scanline, bgprio[0]);
   DoXMosaic(0, &linebuf.bg[0][8]);
   DoWindow(0, &linebuf.bg[0][8]);
   MixLayers<true, false, false, false>();
  }
 }
 else
  SNES_DBG("[PPU] BGMODE: %02x\n", BGMode);
}

template<bool rgb565, typename T>
static INLINE uint32 Blend32(uint32 a, uint32 b)
{
 if(sizeof(T) == 2)
 {
  const uint32 mask = (1U << 0) | (1U << 5) | (1U << (rgb565 ? 11 : 10));

  a = (((a + b) - ((a ^ b) & mask))) >> 1;
  return a;
 }
 else
 {
  #ifdef HAVE_NATIVE64BIT
  a = ((((uint64)a + b) - ((a ^ b) & 0x01010101))) >> 1;
  #else
  a = ((((a & 0x00FF00FF) + (b & 0x00FF00FF)) >> 1) & 0x00FF00FF) | (((((a & 0xFF00FF00) >> 1) + ((b & 0xFF00FF00) >> 1))) & 0xFF00FF00);
  #endif
 }
 return a;
}

template<bool rgb565, typename T, unsigned Mode>
static MDFN_HOT uint32 T_DoHFilter(void* const t_in, const uint32 w, const bool hires)
{
 T* const t = (T*)t_in;
 //assert(w == 512 || w == 256);
 if(w == 512)
 {
  if(!hires && Mode == PPU_HFILTER_PHR256BLEND)
  {
   for(uint32 i = 0; i < 256; i++)
   {
    t[i] = Blend32<rgb565, T>(t[(i << 1) + 0], t[(i << 1) + 1]);
   }
   return 256;
  }
  else if(!hires && Mode == PPU_HFILTER_PHR256BLEND_512)
  {
   for(uint32 i = 0; i < 512; i += 2)
   {
    const uint32 pix = Blend32<rgb565, T>(t[i + 0], t[i + 1]);

    t[i + 0] = pix;
    t[i + 1] = pix;
   }
   return 512;
  }
  else if(Mode == PPU_HFILTER_512_BLEND)
  {
   uint32 prev = t[0];
   for(uint32 i = 0; i < 512; i++)
   {
    const uint32 pix = Blend32<rgb565, T>(t[i], prev);

    prev = t[i];

    t[i] = pix;
   }
   return 512;
  }
  else
   return 512;
 }
 else
 {
  if(Mode == PPU_HFILTER_PHR256BLEND_512 || Mode == PPU_HFILTER_512)
  {
   for(int32 i = 255; i >= 0; i--)
   {
    const uint32 pix = t[i];

    t[(i << 1) + 0] = pix;
    t[(i << 1) + 1] = pix;
   }
   return 512;
  }
  else if(Mode == PPU_HFILTER_512_BLEND)
  {
   for(uint32 i = 255; i > 0; i--)
   {
    t[(i << 1) + 0] = Blend32<rgb565, T>(t[i], t[i - 1]);
    t[(i << 1) + 1] = t[i];
   }
   t[1] = t[0];
   return 512;
  }
  else
   return 256;
 }
}

template<bool rgb565, typename T>
static NO_INLINE MDFN_HOT void RenderLine(void)
{
 if(MDFN_UNLIKELY(LineTarget > 239))	// Sanity check(239 isn't shown, too...)
  LineTarget = 239;

 const int32 out_line = (LineTarget << es->InterlaceOn) + (es->InterlaceOn & es->InterlaceField);
 T* const out_target = es->surface->pix<T>() + out_line * es->surface->pitchinpix;
 const uint32 w = ((BGMode & 0x7) == 0x5 || (BGMode & 0x7) == 0x6 || (ScreenMode & 0x08)) ? 512 : 256;

 es->LineWidths[out_line] = w;
 //
 LineTarget++;
 //

 if(MDFN_UNLIKELY(INIDisp & 0x80))
 {
  for(unsigned i = 0; i < w; i++)
   out_target[i] = 0;
 }
 else
 {
  if(scanline == 1)
   MosaicYOffset = 0;
  else
  {
   MosaicYOffset++;
   if(MosaicYOffset > (Mosaic >> 4))
    MosaicYOffset = 0;
  }

  CalcWindowPieces();
  //
  //
  //
  DrawSprites();
  DoWindow(4, &PPU.objbuf[8]);

  DrawBGAndMixToMS();
  DoWindow<true>(5, linebuf.main);

  if(MDFN_UNLIKELY(w == 512))
  {
   // Nope, won't work right!
   //DoWindow<true>(5, linebuf.sub); // For color window masking to black.  Probably should find a more efficient/logical way to do this...
   MixMainSub<true, rgb565>(out_target);
  }
  else
  {
   MixMainSub<false, rgb565>(out_target);
  }
 }

 if(MDFN_UNLIKELY(DoHFilter))
 {
  const uint32 hfw = DoHFilter(out_target, w, (BGMode & 0x7) == 0x5 || (BGMode & 0x7) == 0x6);

  es->LineWidths[out_line] = hfw;

  if(HFilter_Auto512)
  {
   if(MDFN_UNLIKELY(hfw > HFilter_PrevW))
   {
    DoHFilter = T_DoHFilter<rgb565, T, PPU_HFILTER_PHR256BLEND_512>;
    HFilter_Auto512 = false;

    //printf("DERP: %u %d\n", LineTarget - 1, es->DisplayRect.y);
    for(uint32 lt = es->DisplayRect.y >> es->InterlaceOn; lt < (LineTarget - 1); lt++)
    {
     const int32 ol = (lt << es->InterlaceOn) + (es->InterlaceOn & es->InterlaceField);
     T* const ot = es->surface->pix<T>() + ol * es->surface->pitchinpix;

     es->LineWidths[ol] = DoHFilter(ot, es->LineWidths[ol], false);
    }
   }
   HFilter_PrevW = hfw;
  }
 }
}

template<typename T>
static MDFN_HOT void T_RenderZero(uint32 bound)
{
 while(LineTarget < bound)
 {
  const int32 out_line = (LineTarget << es->InterlaceOn) + (es->InterlaceOn & es->InterlaceField);

  if(MDFN_LIKELY(out_line >= es->DisplayRect.y && out_line < (es->DisplayRect.y + es->DisplayRect.h)))
  {
   T* const out_target = es->surface->pix<T>() + out_line * es->surface->pitchinpix;

   if(MDFN_UNLIKELY(DoHFilter))
   {
    const unsigned w = HFilter_Out512 ? 512 : 256;

    //printf("BORP: %d\n", LineTarget);

    es->LineWidths[out_line] = w;

    for(unsigned i = 0; i < w; i++)
     out_target[i] = 0;
   }
   else
   {
    es->LineWidths[out_line] = 2;
    out_target[0] = 0;
    out_target[1] = 0;
   }
  }

  LineTarget++;
 }
}

static INLINE void RenderZero(uint32 bound)
{
 if(es->surface->format.opp == 2)
  T_RenderZero<uint16>(bound);
 else
  T_RenderZero<uint32>(bound);
}

static INLINE void RenderCommon_ResetLineTarget(const bool pal, const bool ilaceon, const bool field)
{
 if(ilaceon)
 {
  if(!es->InterlaceOn)
  {
   es->DisplayRect.y <<= 1;
   es->DisplayRect.h <<= 1;
  }

  es->InterlaceOn = true;
  es->InterlaceField = field;
 }
 es->LineWidths[0] = 0;

 LineTarget = 0;

 if(pal)
  RenderZero((ScreenMode & 0x04) ? 0 : 8);
 else
  LineTarget = (ScreenMode & 0x04) ? 0 : 8;
}

static INLINE void RenderCommon_RenderLine(void)
{
 if(es->surface->format.opp == 2)
 {
  if(es->surface->format.Gprec == 6)
   RenderLine<true, uint16>();
  else
   RenderLine<false, uint16>();
 }
 else
  RenderLine<false, uint32>();
}


static INLINE void RenderCommon_StartFrame(EmulateSpecStruct* espec, const unsigned hfilter)
{
 es = espec;
 //
 //
 //
 const auto& f = es->surface->format;

 if(MDFN_UNLIKELY(es->VideoFormatChanged))
 {
  for(int rc = 0; rc < 0x8000; rc++)
  {
   const uint8 a = rc;
   const uint8 b = rc >> 8;

   if(f.opp == 2)
   {
    if(f.Gprec == 6)
    {
     (linebuf.OutputLUT +   0)[a] = ((a & 0x1F) << f.Rshift) | ((a >> 5) << (1 + f.Gshift));
     (linebuf.OutputLUT + 256)[b] = (((b >> 1) & 0x1) << f.Gshift) | ((b & 0x3) << (4 + f.Gshift)) | (((b >> 2) & 0x1F) << f.Bshift);
    }
    else
    {
     (linebuf.OutputLUT +   0)[a] = ((a & 0x1F) << f.Rshift) | ((a >> 5) << f.Gshift);
     (linebuf.OutputLUT + 256)[b] = ((b & 0x3) << (3 + f.Gshift)) | (((b >> 2) & 0x1F) << f.Bshift);
    }
   }
   else
   {
    // FEDCBA98 76543210
    // -BBBBBGG GGGRRRRR
    (linebuf.OutputLUT +   0)[a] = ((a & 0x1F) << (3 + f.Rshift)) | (((a & 0x1F) >> 2) << f.Rshift) | ((a >> 5) << (3 + f.Gshift)) | ((a >> 7) << f.Gshift);
    (linebuf.OutputLUT + 256)[b] = ((b & 0x3) << (6 + f.Gshift)) | ((b & 0x3) << (1 + f.Gshift)) | (((b >> 2) & 0x1F) << (3 + f.Bshift)) | (((b >> 4) & 0x7) << f.Bshift);
/*
    {
     int ccr = (rc >>  0) & 0x1F;
     int ccg = (rc >>  5) & 0x1F;
     int ccb = (rc >> 10) & 0x1F;
     const uint32 olr = linebuf.OutputLUT[0 + a] + linebuf.OutputLUT[256 + b];
     //const uint32 mcr = espec->surface->format.MakeColor((ccr * 0xFF * 2 + 0x1F) / (0x1F * 2), (ccg * 0xFF * 2 + 0x1F) / (0x1F * 2), (ccb * 0xFF * 2 + 0x1F) / (0x1F * 2));
     const uint32 mcr = espec->surface->format.MakeColor((ccr << 3) + (ccr >> 2), (ccg << 3) + (ccg >> 2), (ccb << 3) + (ccb >> 2));

     assert(olr == mcr);
     //printf("0x%02x 0x%02x 0x%02x: 0x%04x 0x%04x\n", ccr, ccg, ccb, olr, mcr);
    }
*/
   }
  }
 }

 HFilter_PrevW = 256;
 HFilter_Auto512 = false;
 HFilter_Out512 = false;

 #define HFILTH(n) { DoHFilter = (f.opp == 2) ? ((f.Gprec == 6) ? T_DoHFilter<true, uint16, n> : T_DoHFilter<false, uint16, n> ) : T_DoHFilter<false, uint32, n>; }

 switch(hfilter)
 {
  default:
	assert(0);
	break;

  case PPU_HFILTER_NONE:
	DoHFilter = NULL;
	break;

  case PPU_HFILTER_512:
	HFilter_Out512 = true;
	HFILTH(PPU_HFILTER_512);
	break;

  case PPU_HFILTER_PHR256BLEND_AUTO512:
	HFilter_Auto512 = true;
	// Fallthrough
  case PPU_HFILTER_PHR256BLEND:
	HFILTH(PPU_HFILTER_PHR256BLEND);
	break;

  case PPU_HFILTER_PHR256BLEND_512:
	HFilter_Out512 = true;
	HFILTH(PPU_HFILTER_PHR256BLEND_512);
	break;

  case PPU_HFILTER_512_BLEND:
	HFilter_Out512 = true;
	HFILTH(PPU_HFILTER_512_BLEND);
	break;
 }
 #undef HFILTH
}


static INLINE void RenderCommon_Reset(bool powering_up)
{
 PPU.SpriteTileCount = 0;
}

static INLINE void RenderCommon_Init(void)
{
 assert(linebuf.main == linebuf.bg[0]);
 assert(linebuf.main == linebuf.bghr[0]);
 assert(linebuf.sub == linebuf.bg[2]);
 assert(linebuf.sub == linebuf.bghr[1]);
 //
 //
 //
 DoHFilter = NULL;
 es = NULL;
 //
 //
 //
 for(unsigned i = 0; i < 16; i++)
 {
  PPU.SpriteTileTab[i] = (i & 0x1) | ((i & 0x2) << 3) | ((i & 0x4) << 6) | ((i & 0x8) << 9);
 }
 static const uint8 Sprite_WHTab_Init[8][2][2] =
 {
  { {  8,  8 }, { 16, 16 } },
  { {  8,  8 }, { 32, 32 } },
  { {  8,  8 }, { 64, 64 } },

  { { 16, 16 }, { 32, 32 } },
  { { 16, 16 }, { 64, 64 } },

  { { 32, 32 }, { 64, 64 } },

  { { 16, 32 }, { 32, 64 } },
  { { 16, 32 }, { 32, 32 } },
 };

 memcpy(PPU.Sprite_WHTab, Sprite_WHTab_Init, sizeof(PPU.Sprite_WHTab));
 //
 static const uint8 inctab_init[4] = { 1, 32, 128, 128 };
 static const uint32 ttab_init[4][3] =
 {
  { 0x7FFF, 0, 0 },
  { 0x7F00, 5, 0x0F8 },
  { 0x7E00, 6, 0x1F8 },
  { 0x7C00, 7, 0x3F8 },
 };

 memcpy(PPU.inctab, inctab_init, sizeof(PPU.inctab));
 memcpy(PPU.ttab, ttab_init, sizeof(PPU.ttab));

 static_assert(sizeof(PPU.Sprite_WHTab) == sizeof(Sprite_WHTab_Init) && sizeof(inctab_init) == sizeof(PPU.inctab) && sizeof(ttab_init) == sizeof(PPU.ttab), "size mismatch");
 //
 //
 //
#ifdef SNES_DBG_ENABLE
 {
  sha256_hasher h;
  sha256_digest d;
  const sha256_digest d_expected = "0299f757a85a1aad6cbe1ad2b0eda925d8df667cd04e646af8917f65cbf24537"_sha256;
  alignas(16) uint16 buf16_rgb555[256];
  alignas(16) uint16 buf16_rgb565[256];

  for(unsigned i = 0; i < 256; i++)
  {
   unsigned r = 0, g = 0, b = 0;

   if(i < 0x20)
    r = i & 0x1F;
   else if(i < 0x40)
    g = i & 0x1F;
   else if(i < 0x60)
    b = i & 0x1F;
   else if(i < 0x80)
    r = g = b = i & 0x1F;
   else
   {
    r = g = b = i & 0x1F;
    if(i < 0xA0)
     r ^= 0x1F;
    else if(i < 0xC0)
     g ^= 0x1F;
    else if(i < 0xE0)
     b ^= 0x1F;
    else
    {
     r ^= 0x10;
     b ^= 0x10;
    }
   }
   buf16_rgb555[i] = (r << 10) | (g << 5) | b;
   buf16_rgb565[i] = (r << 11) | (g << 6) | ((g >> 4) << 5) | b;

   //printf("%3u: 0x%02x 0x%02x 0x%02x --- 0x%04x 0x%04x\n", i, r, g, b, buf16_rgb555[i], buf16_rgb565[i]);
  }

  for(unsigned bright = 0; bright < 15; bright++)
  {
   ApplyBrightness<false, false>(buf16_rgb555, bright);
   ApplyBrightness<false, true>(buf16_rgb565, bright);

   for(unsigned i = 0; i < 256; i++)
   {
    h.process_scalar<uint16>(buf16_rgb555[i]);
    h.process_scalar<uint16>(buf16_rgb565[i]);
   }
  }
  //
  d = h.digest();
  assert(d == d_expected);
  //
/*
  for(unsigned i = 0; i < 32; i++)
   printf("%02x", d[i]);
  printf("\n");
  abort();
*/
 }
#endif
}

