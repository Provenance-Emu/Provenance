/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* ppu.cpp:
**  Copyright (C) 2015-2017 Mednafen Team
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

//
// FIXME: Hires/pseudo-hires color math and color window are all wonky.
//
// FIXME: Add mode 6 emulation
//
// FIXME: Correct handling of lower 3 bits of BGHOFS registers.
//
// FIXME: Interlaced support.
//
// FIXME: Handle PPU reads open bus.
//
// FIXME: VRAM mirrored or open bus?

#include "snes.h"
#include "ppu.h"
#include "input.h"

namespace MDFN_IEN_SNES_FAUST
{

static uint32 lastts;

static uint32 LineStartTS;
static unsigned HLatch, VLatch;
static unsigned HVLatchReadShift;


//
// Cheaty registers and state:
static uint16 HTime;
static uint16 VTime;

static uint8 NMITIMEEN;

static uint8 HVBJOY;
static uint8 NMIFlag;	// 0x00 or 0x80
static uint8 IRQFlag;	// 0x00 or 0x80
static uint8 JPReadCounter;
//
//

static bool PAL;
static bool VBlank;
static bool LinePhase;
static uint32 LineCounter;
/*static*/ uint32 scanline;
static uint32 LinesPerFrame;
static uint32 LineTarget;

static uint8 BusLatch[2];
static uint8 Status[2];	// $3E and $3F.

static uint16 VRAM[32768];

static uint8 ScreenMode;	// $33
static uint8 INIDisp;
static uint8 BGMode;
static uint8 Mosaic;
static uint8 MosaicYOffset;

static uint8 BGSC[4];

static uint8 BGNBA[2];

static uint8 BGOFSPrev;
static uint16 BGHOFS[4];
static uint16 BGVOFS[4];

static uint16 VRAM_Addr;
static uint16 VRAM_ReadBuffer;
static bool VMAIN_IncMode;
static unsigned VMAIN_AddrInc;
static unsigned VMAIN_AddrTransMaskA;
static unsigned VMAIN_AddrTransShiftB;
static unsigned VMAIN_AddrTransMaskC;

static uint8 M7Prev;
static uint8 M7SEL;
static int16 M7Matrix[4];
static int16 M7Center[2];
static int16 M7HOFS, M7VOFS;

static bool CGRAM_Toggle;
static uint8 CGRAM_Buffer;
static uint8 CGRAM_Addr;
static uint16 CGRAM[256];

static uint8 MSEnable;
static uint8 SSEnable;

static uint8 WMSettings[3];
static uint8 WMMainEnable, WMSubEnable;
static uint16 WMLogic;
static uint8 WindowPos[2][2];
static unsigned WindowPieces[5];	// Derived data, calculated at start of rendering for a scanline.

static uint8 CGWSEL;
static uint8 CGADSUB;
static uint16 FixedColor;

static uint8 OBSEL;
static uint8 OAMADDL, OAMADDH;
static uint8 OAM_Buffer;
static uint32 OAM_Addr;
static uint8 OAM[512];
static uint8 OAMHI[32];

static DEFWRITE(Write_ScreenMode)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 ScreenMode = V;
}

static DEFWRITE(Write_2100)
{
 CPUM.timestamp += MEMCYC_FAST;

 if((INIDisp ^ V) & 0x80 & ~V)
  OAM_Addr = (OAMADDL | ((OAMADDH & 0x1) << 8)) << 1;

 INIDisp = V;

 //printf("INIDisp = %02x --- scanline=%u\n", V, scanline);
}

static DEFWRITE(Write_OBSEL)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 OBSEL = V;
}

static DEFWRITE(Write_OAMADDL)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 OAMADDL = V;
 OAM_Addr = (OAMADDL | ((OAMADDH & 0x1) << 8)) << 1;
}

static DEFWRITE(Write_OAMADDH)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 OAMADDH = V;
 OAM_Addr = (OAMADDL | ((OAMADDH & 0x1) << 8)) << 1;
}

static DEFWRITE(Write_OAMDATA)
{
 CPUM.timestamp += MEMCYC_FAST;

 //fprintf(stderr, "OAMDATA Write: 0x%04x 0x%02x\n", OAM_Addr, V);
 //
 if(OAM_Addr & 0x200)
  OAMHI[OAM_Addr & 0x1F] = V;
 else if(OAM_Addr & 1)
 {
  OAM[(size_t)OAM_Addr - 1] = OAM_Buffer;
  OAM[(size_t)OAM_Addr + 0] = V;
 }

 if(!(OAM_Addr & 1))
  OAM_Buffer = V;

 OAM_Addr = (OAM_Addr + 1) & 0x3FF;
}

static DEFREAD(Read_OAMDATAREAD)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 uint8 ret;

 if(OAM_Addr & 0x200)
  ret = OAMHI[OAM_Addr & 0x1F];
 else
  ret = OAM[OAM_Addr];

 OAM_Addr = (OAM_Addr + 1) & 0x3FF;

 return ret;
}

static union
{
 struct
 {
  int16 x;
  uint8 y_offset;
  uint8 tilebase;
  uint8 paloffs;
  uint8 prio;
  uint8 w;
  uint8 h;
  uint8 hfxor;
  bool n;
 } SpriteList[32];

 uint32 objbuf[8 + 256 + 8];
};

static struct
{
 uint64 td;	// 4bpp->8bpp, |'d with palette offset + 128; 8-bits * 8
 int32 x;
 uint32 prio_or;
} SpriteTileList[34];
unsigned SpriteTileCount;

static const struct
{
 uint8 w;
 uint8 h;
} Sprite_WHTab[8][2] =
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

static INLINE void FetchSpriteData(signed line_y)
{
 unsigned SpriteIndex = 0;
 unsigned SpriteCount = 0;
 uint8 whtab[2][2];

 if(INIDisp & 0x80)
 {
  SpriteTileCount = 0;
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
  const auto* tp = Sprite_WHTab[(OBSEL >> 5) & 0x7];

  for(unsigned i = 0; i < 2; i++)
  {
   whtab[i][0] = tp[i].w;
   whtab[i][1] = tp[i].h;
  }
 }

 for(unsigned i = 0; i < 128; i++, SpriteIndex = (SpriteIndex + 1) & 0x7F)
 {
  const uint8* const oa = &OAM[SpriteIndex << 2];
  const uint8 hob = OAMHI[SpriteIndex >> 2] >> ((SpriteIndex & 0x3) << 1);
  const bool sizebit = hob & 0x2;
  signed x = sign_x_to_s32(9, oa[0] | ((hob & 1) << 8));
  uint8 y_offset = line_y - oa[1];
  uint8 w = whtab[sizebit][0];
  uint8 h = whtab[sizebit][1];

  if(y_offset >= h)
   continue;

  //printf("Line %d, Sprite: %d:%d, %d:%d\n", line_y, x, y_offset, w, h);

  if(x <= -w)	// fixme: x == -256 special case
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
  auto* l = &SpriteList[SpriteCount];   

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

 SpriteTileCount = 0;
 for(int i = SpriteCount - 1; i >= 0; i--)
 {
  const auto* const l = &SpriteList[i];

  for(int ht = 0; ht < (l->w >> 3); ht++)
  {
   int xo = l->x + (ht << 3);

   if(xo <= -8 || xo >= 256) //rof > (255 + 7))
    continue;

   if(SpriteTileCount == 34)
   {
    //printf("Sprite tile overflow on %u\n", line_y);
    Status[0] |= 0x80;
    goto ExitTileLoop;
   }
   auto* const t = &SpriteTileList[SpriteTileCount++];

   t->x = xo;
   t->prio_or = (l->prio + 1) * 0x3030 | ((l->paloffs & 0x40) >> 6) | 2;

   uint8 wt;

   unsigned rof = ((ht << 3) ^ l->hfxor) >> 3;

   wt = ((l->tilebase & 0xF0) + (l->y_offset << 1)) & 0xF0;
   wt |= (l->tilebase + rof) & 0x0F;

   uint16* chr = chrbase[l->n] + (wt << 4) + (l->y_offset & 0x7);

   uint32 bp = chr[0] | (chr[8] << 16);
   for(unsigned x = 0; x < 8; x++)
   {
    uint32 pix;

    pix =  ((bp >>  7) & 0x01);
    pix |= ((bp >> 14) & 0x02);
    pix |= ((bp >> 21) & 0x04);
    pix |= ((bp >> 28) & 0x08);

    if(!l->hfxor)
    {
     t->td >>= 8;
     t->td |= (uint64)(pix | l->paloffs) << 56;
    }
    else
    {
     t->td <<= 8;
     t->td |= pix | l->paloffs;
    }
    bp <<= 1;
   }
  }
 }
 ExitTileLoop: ;
}

static INLINE void DrawSprites(void)
{
 unsigned prio_or_mask = 0xFFFF;

 memset(objbuf + 8, 0, sizeof(objbuf[0]) * 256);

 if(!(CGADSUB & 0x10))
  prio_or_mask &= ~0x0001;

 if(!(SSEnable & 0x10))
  prio_or_mask &= ~0xF000;

 if(!(MSEnable & 0x10))
  prio_or_mask &= ~0x00F0;

 for(unsigned i = 0; i < SpriteTileCount; i++)
 {
  auto* const t = &SpriteTileList[i];
  uint64 td = t->td;
  uint32* tb = objbuf + 8 + t->x;
  uint32 prio_or = t->prio_or & prio_or_mask;

  for(unsigned x = 0; x < 8; x++)
  {
   if(td & 0xF)
   {
    tb[x] = (CGRAM[(uint8)td] << 16) | prio_or;
   }
   td >>= 8;
  }
 }

 SpriteTileCount = 0;
}


static DEFWRITE(Write_2105)
{
 CPUM.timestamp += MEMCYC_FAST;

 BGMode = V;
}

static DEFWRITE(Write_2106)
{
 CPUM.timestamp += MEMCYC_FAST;

 if((Mosaic ^ V) & 0xF0)
  MosaicYOffset = 0;

 Mosaic = V;
}

static DEFWRITE(Write_BGSC)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 BGSC[(size_t)(uint8)A - 0x07] = V;
}

static DEFWRITE(Write_BGNBA)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 BGNBA[(size_t)(uint8)A - 0x0B] = V;
}

template<bool bg0>
static DEFWRITE(Write_BGHOFS)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 uint16* const t = &BGHOFS[((size_t)(uint8)A >> 1) - (0x0D >> 1)];
 *t = BGOFSPrev | ((V & 0x3) << 8);
 BGOFSPrev = V;

 if(bg0)
 {
  M7HOFS = sign_13_to_s16(M7Prev | ((V & 0x1F) << 8));
  M7Prev = V;
 }
}

template<bool bg0>
static DEFWRITE(Write_BGVOFS)
{
 CPUM.timestamp += MEMCYC_FAST;

 //
 BGVOFS[((size_t)(uint8)A >> 1) - (0x0E >> 1)] = BGOFSPrev | ((V & 0x3) << 8);
 BGOFSPrev = V;

 if(bg0)
 {
  M7VOFS = sign_13_to_s16(M7Prev | ((V & 0x1F) << 8));
  M7Prev = V;
 }
}

static MDFN_HOT uint16 GetVAddr(void)
{
 return (VRAM_Addr & VMAIN_AddrTransMaskA) | ((VRAM_Addr >> VMAIN_AddrTransShiftB) & 0x7) | ((VRAM_Addr << 3) & VMAIN_AddrTransMaskC);
}

static DEFWRITE(Write_2115)
{
 static const uint8 inctab[4] = { 1, 32, 128, 128 };
 static const uint32 ttab[4][3] =
 {
  { 0x7FFF, 0, 0 },
  { 0x7F00, 5, 0x0F8 },
  { 0x7E00, 6, 0x1F8 },
  { 0x7C00, 7, 0x3F8 },
 };
 CPUM.timestamp += MEMCYC_FAST;


 VMAIN_IncMode = V & 0x80;
 VMAIN_AddrInc = inctab[V & 0x3];

 VMAIN_AddrTransMaskA = ttab[(V >> 2) & 0x3][0];
 VMAIN_AddrTransShiftB = ttab[(V >> 2) & 0x3][1];
 VMAIN_AddrTransMaskC = ttab[(V >> 2) & 0x3][2];
}

static DEFWRITE(Write_2116)
{
 CPUM.timestamp += MEMCYC_FAST;

 VRAM_Addr &= 0xFF00;
 VRAM_Addr |= V << 0;

 VRAM_ReadBuffer = VRAM[GetVAddr()];
}

static DEFWRITE(Write_2117)
{
 CPUM.timestamp += MEMCYC_FAST;

 VRAM_Addr &= 0x00FF;
 VRAM_Addr |= V << 8;

 VRAM_ReadBuffer = VRAM[GetVAddr()];
}

static DEFWRITE(Write_2118)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 const unsigned va = GetVAddr();

 //if(va >= 0x2000 && va < 0x3000)
 // fprintf(stderr, "Low: %04x %04x, %02x\n", va, VRAM_Addr, V);

 VRAM[va] &= 0xFF00;
 VRAM[va] |= V << 0;

 if(!VMAIN_IncMode)
  VRAM_Addr += VMAIN_AddrInc;
}

static DEFWRITE(Write_2119)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 const unsigned va = GetVAddr();

 //if(va >= 0x2000 && va < 0x3000)
 // fprintf(stderr, "High: %04x %04x, %02x\n", va, VRAM_Addr, V);

 VRAM[va] &= 0x00FF;
 VRAM[va] |= V << 8;

 if(VMAIN_IncMode)
  VRAM_Addr += VMAIN_AddrInc;
}

static DEFREAD(Read_2139)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 uint8 ret = VRAM_ReadBuffer;

 if(!VMAIN_IncMode)
 {
  VRAM_ReadBuffer = VRAM[GetVAddr()];
  VRAM_Addr += VMAIN_AddrInc;
 }

 return ret;
}

static DEFREAD(Read_213A)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 uint8 ret = VRAM_ReadBuffer >> 8;

 if(VMAIN_IncMode)
 {
  VRAM_ReadBuffer = VRAM[GetVAddr()];
  VRAM_Addr += VMAIN_AddrInc;
 }

 return ret;
}

static DEFWRITE(Write_211A)
{
 CPUM.timestamp += MEMCYC_FAST;
 //

 M7SEL = V & 0xC3;
}

static DEFWRITE(Write_M7Matrix)		// $1b-$1e
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 M7Matrix[(size_t)(uint8)A - 0x1B] = M7Prev | (V << 8);
 M7Prev = V;
}

template<unsigned shift>
static DEFREAD(Read_M7Multiplier)
{
 CPUM.timestamp += MEMCYC_FAST;
 //

 uint32 result = (int16)M7Matrix[0] * (int8)(M7Matrix[1] >> 8);
 return result >> shift;
}

static DEFWRITE(Write_M7Center)
{
 CPUM.timestamp += MEMCYC_FAST;
 //

 M7Center[(size_t)(uint8)A - 0x1F] = sign_13_to_s16(M7Prev | ((V & 0x1F) << 8));
 M7Prev = V;
}

static DEFWRITE(Write_CGADD)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 CGRAM_Addr = V;
 CGRAM_Toggle = false;
}

static DEFWRITE(Write_CGDATA)
{
 CPUM.timestamp += MEMCYC_FAST;

 //
 if(CGRAM_Toggle)
 {
  CGRAM[CGRAM_Addr] = ((V & 0x7F) << 8) | CGRAM_Buffer;
  CGRAM_Addr++;
 }
 else
  CGRAM_Buffer = V;

 CGRAM_Toggle = !CGRAM_Toggle;
}

static DEFREAD(Read_CGDATAREAD)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 uint8 ret;

 if(CGRAM_Toggle)
 {
  ret = CGRAM[CGRAM_Addr] >> 8;
  CGRAM_Addr++;
 }
 else
  ret = CGRAM[CGRAM_Addr] >> 0;

 CGRAM_Toggle = !CGRAM_Toggle;

 return ret;
}

static DEFWRITE(Write_MSEnable)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 MSEnable = V & 0x1F;
}

static DEFWRITE(Write_SSEnable)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 SSEnable = V & 0x1F;
}

static DEFWRITE(Write_WMMainEnable)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 WMMainEnable = V;
}

static DEFWRITE(Write_WMSubEnable)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 WMSubEnable = V;
}

template<bool msb>
static DEFWRITE(Write_WMLogic)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 if(msb)
  WMLogic = (WMLogic & 0x00FF) | ((V & 0xF) << 8);
 else
  WMLogic = (WMLogic & 0xFF00) | (V << 0);
}

static DEFWRITE(Write_WMSettings)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 WMSettings[(size_t)(uint8)A - 0x23] = V;
}


static DEFWRITE(Write_WindowPos)	// $26-$29
{
 CPUM.timestamp += MEMCYC_FAST;
 //

 ((uint8*)WindowPos)[(size_t)(uint8)A - 0x26] = V;

 //printf("%04x %02x\n", A, V);
}


static DEFWRITE(Write_CGWSEL)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 CGWSEL = V;
}

static DEFWRITE(Write_CGADSUB)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 CGADSUB = V;
}

static DEFWRITE(Write_COLDATA)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 unsigned cc = V & 0x1F;

 if(V & 0x20)
  FixedColor = (FixedColor &~ (0x1F <<  0)) | (cc <<  0);

 if(V & 0x40)
  FixedColor = (FixedColor &~ (0x1F <<  5)) | (cc <<  5);

 if(V & 0x80)
  FixedColor = (FixedColor &~ (0x1F << 10)) | (cc << 10);
}

static DEFREAD(Read_HVLatchTrigger)
{
 CPUM.timestamp += MEMCYC_FAST;
 //

 //printf("Read HVLatchTrigger\n");

 if(1)
 {
  // Maximum horribleness.
  //PPU_Update(CPUM.timestamp);

  HLatch = (uint32)(CPUM.timestamp - LineStartTS) >> 2;
  VLatch = scanline;

  if(HLatch >= 340)
  {
   if(HLatch == 340)
    HLatch = 339;
   else
   {
    HLatch -= 341;
    VLatch = (VLatch + 1) % LinesPerFrame;	// FIXME
   }
  }

  //printf("VL: %d, HL: %d\n", VLatch, HLatch);

  Status[1] |= 0x40;
 }

 return 0;	// FIXME: open bus
}

static DEFREAD(Read_HLatch)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 uint8 ret = HLatch >> HVLatchReadShift; // FIXME: open bus

 HVLatchReadShift ^= 8;

 return ret;
}

static DEFREAD(Read_VLatch)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 uint8 ret = VLatch >> HVLatchReadShift; // FIXME: open bus

 HVLatchReadShift ^= 8;

 return ret;
}

static DEFREAD(Read_Status0)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 uint8 ret = Status[0];

 return ret;
}

static DEFREAD(Read_Status1)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 uint8 ret = Status[1];

 if(1)
  Status[1] &= ~0x40;

 HVLatchReadShift = 0;

 return ret;
}

//
//
//
//
//
//
//
static EmulateSpecStruct* es;

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

static_assert(linebuf.main == linebuf.bg[0] && linebuf.main == linebuf.bghr[0] &&
	      linebuf.sub == linebuf.bg[2] && linebuf.sub == linebuf.bghr[1], "linebuf structure malformed.");


void PPU_StartFrame(EmulateSpecStruct* espec)
{
 es = espec;

 es->LineWidths[0] = 0;
 es->DisplayRect.x = 0;
 es->DisplayRect.y = PAL ? 0 : 8;
 es->DisplayRect.w = 256;
 es->DisplayRect.h = PAL ? 239 : 224;

 if(es->VideoFormatChanged)
 {
  const auto& f = es->surface->format;

  for(int rc = 0; rc < 0x8000; rc++)
  {
   const uint8 a = rc;
   const uint8 b = rc >> 8;

   (linebuf.OutputLUT +   0)[a] = ((a & 0x1F) << (3 + f.Rshift)) | ((a >> 5) << (3 + f.Gshift));
   (linebuf.OutputLUT + 256)[b] = ((b & 0x3) << (6 + f.Gshift)) | (((b >> 2) & 0x1F) << (3 + f.Bshift));
  }
 }
}

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
 unsigned VOFS = BGVOFS[n] + (y - ((Mosaic & (1U << n)) ? MosaicYOffset : 0));
 unsigned HOFS = BGHOFS[n];
 unsigned tm_w_mask = ((BGSC[n] & 0x1) << 10);
 unsigned tm_h_shift = ((BGSC[n] & 0x2) ? ((BGSC[n] & 0x1) ? 3 : 2) : 24);
 unsigned tile_y_offs = (VOFS & 0x7);

 //if(scanline == 100 && n == 0)
 // MDFN_DispMessage("%d %d --- BGHOFS0=%u BGHOFS1=%u\n", hires, size16, BGHOFS[0], BGHOFS[1]);

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
  }
  else if(bpp == 4)
  {
   uint32 bp = vchr[0] | ((uint32)vchr[8] << 16);
   uint32 bp2;
   size_t pix;
   for(; MDFN_LIKELY(subtarg != subtarg_bound); subtarg += subtarg_inc << 1, bp >>= 2)
   {
    bp2 = bp & 0x01010101; pix = (uint8)((bp2     ) | (bp2 >> 7) | (bp2 >> 14) | (bp2 >> 21)); subtarg[0]           = (cgr[pix] << 16) | (pix ? eff_prio_or : 0);
    bp2 = bp & 0x02020202; pix = (uint8)((bp2 >> 1) | (bp2 >> 8) | (bp2 >> 15) | (bp2 >> 22)); subtarg[subtarg_inc] = (cgr[pix] << 16) | (pix ? eff_prio_or : 0);
   }
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
static MDFN_HOT MDFN_FASTCALL NO_INLINE void DoXMosaic(unsigned layernum, uint32* __restrict__ buf)
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
static MDFN_HOT MDFN_FASTCALL void DoWindow(unsigned layernum, uint32* __restrict__ buf)
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

template<bool any_hires, unsigned cmath_mode, bool hires_cmath_add_subscreen = false>
static MDFN_HOT MDFN_FASTCALL NO_INLINE void MixMainSubSubSubMarine(uint32* __restrict__ target)
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

template<bool any_hires>
static INLINE void MixMainSub(uint32* __restrict__ target)
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
 {
  const uint32 brightmul = (INIDisp & 0xF) * 17;
  for(unsigned i = 0; i < (256 << any_hires); i++)
  {
   const uint32 pix = target[i];

   target[i] = ((((pix & 0xFF00FF) * brightmul) >> 8) & 0xFF00FF) | ((((pix >> 8) & 0xFF00FF) * brightmul) & 0xFF00FF00);
  }
 }
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

  PrioHelper<0, false>(main, sub, (objbuf + 8)[i]);

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

static MDFN_HOT void RenderLine(void)
{
 if(MDFN_UNLIKELY(LineTarget > 239))	// Sanity check(239 isn't shown, too...)
  LineTarget = 239;

 uint32* const out_target = es->surface->pixels + (LineTarget * es->surface->pitchinpix);
 int32* const out_lw = &es->LineWidths[LineTarget];

 //
 LineTarget++;
 //

 if(INIDisp & 0x80)
 {
  *out_lw = 2;

  for(unsigned i = 0; i < 2; i++)
   out_target[i] = 0;

  return;
 }

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
 DoWindow(4, &objbuf[8]);

 DrawBGAndMixToMS();
 DoWindow<true>(5, linebuf.main);

 if(MDFN_UNLIKELY((BGMode & 0x7) == 0x5 || (BGMode & 0x7) == 0x6 || (ScreenMode & 0x08)))
 {
  // Nope, won't work right!
  //DoWindow<true>(5, linebuf.sub); // For color window masking to black.  Probably should find a more efficient/logical way to do this...

  MixMainSub<true>(out_target);
  *out_lw = 512;
 }
 else
 {
  MixMainSub<false>(out_target);
  *out_lw = 256;
 }
}

//
//
//
//
//
//
//
//
static DEFWRITE(Write_NMITIMEEN)	// $4200
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 NMITIMEEN = V;

 if(!(NMITIMEEN & 0x30))
  IRQFlag = 0x00;

 CPU_SetNMI(NMIFlag & NMITIMEEN & 0x80);
 CPU_SetIRQ(IRQFlag);

 SNES_DBG("[SNES] Write NMITIMEEN: 0x%02x --- scanline=%u, LineCounter=%u, LinePhase=%u\n", V, scanline, LineCounter, LinePhase);
}

static DEFWRITE(Write_HTIME)	// $4207 and $4208
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 const unsigned shift = (~A & 1) << 3;
 unsigned New_HTime = HTime;

 New_HTime &= 0xFF00 >> shift;
 New_HTime |= V << shift;
 New_HTime &= 0x1FF;

 if(New_HTime != HTime)
  SNES_DBG("[SNES] HTIME Changed: new=0x%04x(old=0x%04x) --- scanline=%u, LineCounter=%u, LinePhase=%u\n", New_HTime, HTime, scanline, LineCounter, LinePhase);

 HTime = New_HTime;
}

static DEFWRITE(Write_VTIME)	// $4209 and $420A
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 const unsigned shift = (~A & 1) << 3;
 unsigned New_VTime = VTime;

 New_VTime &= 0xFF00 >> shift;
 New_VTime |= V << shift;
 New_VTime &= 0x1FF;

 if(New_VTime != VTime)
 {
  SNES_DBG("[SNES] VTIME Changed: new=0x%04x(old=0x%04x) --- HTIME=0x%04x, scanline=%u, LineCounter=%u, LinePhase=%u -- %u\n", New_VTime, VTime, HTime, scanline, LineCounter, LinePhase, (CPUM.timestamp - LineStartTS));

#if 0
  // Kludge for F-1 Grand Prix
  if(!LinePhase && LineCounter >= 1088) //(CPUM.timestamp - LineStartTS) < 10)
  {
   if(!(NMITIMEEN & 0x10) || HTime == 0)
   {
    if(((NMITIMEEN & 0x20) && scanline == New_VTime) || ((NMITIMEEN & 0x30) == 0x10))
    {
     printf("Kludge IRQ: %d\n", scanline);
     IRQFlag = 0x80;
     CPU_SetIRQ(IRQFlag);
    }
   }
  }
#endif
 }

 VTime = New_VTime;
}

static DEFREAD(Read_4210)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 uint8 ret = NMIFlag | 0x01;

 NMIFlag = 0x00;
 CPU_SetNMI(false);

 return ret;
}

static DEFREAD(Read_4211)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 uint8 ret = IRQFlag;

 //printf("Read: %04x\n", A);

 IRQFlag = 0x00;
 CPU_SetIRQ(false);

 return ret;
}

static DEFREAD(Read_4212)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 return HVBJOY;
}

static DEFREAD(Read_4213)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 SNES_DBG("[PPU] Read 4213\n");

 return 0;
}
//
//
//
//
//
//
//
//
//
static INLINE void RenderZero(uint32 bound)
{
 while(LineTarget < bound)
 {
  uint32* const out_target = es->surface->pixels + (LineTarget * es->surface->pitchinpix);

  es->LineWidths[LineTarget] = 2;
  out_target[0] = 0;
  out_target[1] = 0;

  LineTarget++;
 }
}

uint32 PPU_Update(uint32 timestamp)
{
 if(timestamp < lastts)
 {
  SNES_DBG("[PPU] timestamp goof: timestamp=%u, lastts=%u\n", timestamp, lastts);
  assert(timestamp >= lastts);
 }

 LineCounter -= (timestamp - lastts);

 if(LineCounter <= 0)
 {
  LinePhase = !LinePhase;

  if(LinePhase)	// HBlank begin
  {
   //
   //
   HVBJOY |= 0x40;
   //
   //

   if(!VBlank)
   {
    FetchSpriteData(scanline);
    DMA_RunHDMA();
   }

   //
   LineCounter += 67 * 4;
  }
  else	// HBlank end
  {
   scanline = (scanline + 1) % LinesPerFrame;
   //
   LineStartTS = timestamp;
   
   //
   //
   // CPUM.timestamp += 40;
   HVBJOY &= ~0x40;

   // FIXME, HORRIBLE(and stuff)
   if(!(NMITIMEEN & 0x10) || HTime < 340)
   {
    if(((NMITIMEEN & 0x20) && scanline == VTime) || ((NMITIMEEN & 0x30) == 0x10))
    {
     SNES_DBG("[SNES] IRQ: %d\n", scanline);
     IRQFlag = 0x80;
     CPU_SetIRQ(IRQFlag);
    }
   }
   if(JPReadCounter > 0)
   {
    if(JPReadCounter == 3)
     INPUT_AutoRead();

    JPReadCounter--;
    if(!JPReadCounter)
     HVBJOY &= ~0x01;
   }

   //
   //

   if(VBlank && scanline == 0)	// VBlank end
   {
    VBlank = false;
    Status[0] &= ~0xC0;	// Reset Time Over and Range Over flags.

    //
    //
    //
    HVBJOY &= ~0x80;
    NMIFlag = 0x00;
    CPU_SetNMI(false);

    DMA_InitHDMA();
    //
    //
    //

    //
    //
    //
    LineTarget = 0;
    RenderZero((ScreenMode & 0x04) ? 0 : 8);
    //printf("%02x, %d\n", ScreenMode, es->DisplayRect.y);
   }
   else if(!VBlank && scanline >= ((ScreenMode & 0x04) ? 0xF0 : 0xE1))
   {
    VBlank = true;

    RenderZero(239);
    //
    //
    //
    CPUM.running_mask = 0;

    HVBJOY |= 0x80;
    NMIFlag = 0x80;

    CPU_SetNMI(NMIFlag & NMITIMEEN & 0x80);

    if(NMITIMEEN & 0x01)
    {
     JPReadCounter = 3;
     HVBJOY |= 0x01;
    }
    //
    //
    //
    if(!(INIDisp & 0x80))
     OAM_Addr = (OAMADDL | ((OAMADDH & 0x1) << 8)) << 1;
   }

   if(MDFN_LIKELY(!VBlank))
   {
    if(scanline > 0 && !es->skip)
     RenderLine();
   }

   //
   LineCounter += 274 * 4;
  }
 }

 lastts = timestamp;

 return timestamp + LineCounter;
}

void PPU_ResetTS(void)
{
 LineStartTS -= lastts;
 lastts = 0;
}

void PPU_Init(const bool IsPAL)
{
 PAL = IsPAL;
 LinesPerFrame = IsPAL ? 312 : 262;

 Set_B_Handlers(0x00, OBRead_FAST, Write_2100);

 Set_B_Handlers(0x01, OBRead_FAST, Write_OBSEL);
 Set_B_Handlers(0x02, OBRead_FAST, Write_OAMADDL);
 Set_B_Handlers(0x03, OBRead_FAST, Write_OAMADDH);
 Set_B_Handlers(0x04, OBRead_FAST, Write_OAMDATA);

 Set_B_Handlers(0x05, OBRead_FAST, Write_2105);
 Set_B_Handlers(0x06, OBRead_FAST, Write_2106);

 Set_B_Handlers(0x07, 0x0A, OBRead_FAST, Write_BGSC);

 Set_B_Handlers(0x0B, 0x0C, OBRead_FAST, Write_BGNBA);

 Set_B_Handlers(0x0D, OBRead_FAST, Write_BGHOFS<true>);
 Set_B_Handlers(0x0F, OBRead_FAST, Write_BGHOFS<false>);
 Set_B_Handlers(0x11, OBRead_FAST, Write_BGHOFS<false>);
 Set_B_Handlers(0x13, OBRead_FAST, Write_BGHOFS<false>);

 Set_B_Handlers(0x0E, OBRead_FAST, Write_BGVOFS<true>);
 Set_B_Handlers(0x10, OBRead_FAST, Write_BGVOFS<false>);
 Set_B_Handlers(0x12, OBRead_FAST, Write_BGVOFS<false>);
 Set_B_Handlers(0x14, OBRead_FAST, Write_BGVOFS<false>);

 Set_B_Handlers(0x15, OBRead_FAST, Write_2115);
 Set_B_Handlers(0x16, OBRead_FAST, Write_2116);
 Set_B_Handlers(0x17, OBRead_FAST, Write_2117);
 Set_B_Handlers(0x18, OBRead_FAST, Write_2118);
 Set_B_Handlers(0x19, OBRead_FAST, Write_2119);

 Set_B_Handlers(0x1A, OBRead_FAST, Write_211A);
 Set_B_Handlers(0x1B, 0x1E, OBRead_FAST, Write_M7Matrix);

 Set_B_Handlers(0x1F, 0x20, OBRead_FAST, Write_M7Center);

 Set_B_Handlers(0x21, OBRead_FAST, Write_CGADD);
 Set_B_Handlers(0x22, OBRead_FAST, Write_CGDATA);

 Set_B_Handlers(0x23, 0x25, OBRead_FAST, Write_WMSettings);

 Set_B_Handlers(0x26, 0x29, OBRead_FAST, Write_WindowPos);
 Set_B_Handlers(0x2A, OBRead_FAST, Write_WMLogic<false>);
 Set_B_Handlers(0x2B, OBRead_FAST, Write_WMLogic<true>);

 Set_B_Handlers(0x2C, OBRead_FAST, Write_MSEnable);
 Set_B_Handlers(0x2D, OBRead_FAST, Write_SSEnable);

 Set_B_Handlers(0x2E, OBRead_FAST, Write_WMMainEnable);
 Set_B_Handlers(0x2F, OBRead_FAST, Write_WMSubEnable);

 Set_B_Handlers(0x30, OBRead_FAST, Write_CGWSEL);
 Set_B_Handlers(0x31, OBRead_FAST, Write_CGADSUB);

 Set_B_Handlers(0x32, OBRead_FAST, Write_COLDATA);

 Set_B_Handlers(0x33, OBRead_FAST, Write_ScreenMode);

 Set_B_Handlers(0x34, Read_M7Multiplier< 0>, OBWrite_FAST);
 Set_B_Handlers(0x35, Read_M7Multiplier< 8>, OBWrite_FAST);
 Set_B_Handlers(0x36, Read_M7Multiplier<16>, OBWrite_FAST);

 Set_B_Handlers(0x37, Read_HVLatchTrigger, OBWrite_FAST);

 Set_B_Handlers(0x38, Read_OAMDATAREAD, OBWrite_FAST);

 Set_B_Handlers(0x39, Read_2139, OBWrite_FAST);
 Set_B_Handlers(0x3A, Read_213A, OBWrite_FAST);

 Set_B_Handlers(0x3B, Read_CGDATAREAD, OBWrite_FAST);

 Set_B_Handlers(0x3C, Read_HLatch, OBWrite_FAST);
 Set_B_Handlers(0x3D, Read_VLatch, OBWrite_FAST);

 Set_B_Handlers(0x3E, Read_Status0, OBWrite_FAST);
 Set_B_Handlers(0x3F, Read_Status1, OBWrite_FAST);

 Status[0] = 1;
 Status[1] = (IsPAL << 4) | 2;

 //
 //
 //
 for(unsigned bank = 0x00; bank < 0x100; bank++)
 {
  if(bank <= 0x3F || (bank >= 0x80 && bank <= 0xBF))
  {
   Set_A_Handlers((bank << 16) | 0x4200, OBRead_FAST, Write_NMITIMEEN);
   Set_A_Handlers((bank << 16) | 0x4207, (bank << 16) | 0x4208, OBRead_FAST, Write_HTIME);
   Set_A_Handlers((bank << 16) | 0x4209, (bank << 16) | 0x420A, OBRead_FAST, Write_VTIME);

   Set_A_Handlers((bank << 16) | 0x4210, Read_4210, OBWrite_FAST);
   Set_A_Handlers((bank << 16) | 0x4211, Read_4211, OBWrite_FAST);
   Set_A_Handlers((bank << 16) | 0x4212, Read_4212, OBWrite_FAST);
   Set_A_Handlers((bank << 16) | 0x4213, Read_4213, OBWrite_FAST);
  }
 }
}

void PPU_SetGetVideoParams(MDFNGI* gi, const bool caspect)
{
 gi->fb_width = 512;
 gi->fb_height = 480;	// Don't change to less than 480

 if(PAL)
 {
  gi->nominal_width = caspect ? 354 : 256;
  gi->nominal_height = 239;

  gi->fps = 838977920;
 }
 else
 {
  gi->nominal_width = caspect ? 292 : 256;
  gi->nominal_height = 224;  

  gi->fps = 1008307711;
 }

 gi->lcm_width = 512;
 gi->lcm_height = gi->nominal_height * 2;
}

void PPU_Kill(void)
{


}

void PPU_Reset(bool powering_up)
{
 HLatch = 0;
 VLatch = 0;
 HVLatchReadShift = 0;

 BusLatch[0] = 0x00;
 BusLatch[1] = 0x00;

 Status[0] &= ~0xC0;
 Status[1] &= ~0xC0;

 // FIXME?
 scanline = 0;
 LinePhase = 0;
 LineCounter = 1;

 VBlank = false;

 if(powering_up)
  memset(VRAM, 0x00, sizeof(VRAM));

 ScreenMode = 0x00;
 INIDisp = 0x00;
 BGMode = 0x00;
 Mosaic = 0x00;
 MosaicYOffset = 0x00;

 memset(BGSC, 0x00, sizeof(BGSC));
 memset(BGNBA, 0x00, sizeof(BGNBA));

 BGOFSPrev = 0x00;
 memset(BGHOFS, 0x00, sizeof(BGHOFS));
 memset(BGVOFS, 0x00, sizeof(BGVOFS));

 VRAM_Addr = 0x0000;
 VRAM_ReadBuffer = 0x0000;

 VMAIN_IncMode = 0x00;
 VMAIN_AddrInc = 0;
 VMAIN_AddrTransMaskA = 0x7FFF;
 VMAIN_AddrTransShiftB = 0;
 VMAIN_AddrTransMaskC = 0x0000;


 M7Prev = 0x00;
 M7SEL = 0x00;
 memset(M7Matrix, 0x00, sizeof(M7Matrix));
 memset(M7Center, 0x00, sizeof(M7Center));
 M7HOFS = 0x0000;
 M7VOFS = 0x0000;

 CGRAM_Toggle = false;
 CGRAM_Buffer = 0x00;
 CGRAM_Addr = 0x00;
 if(powering_up)
  memset(CGRAM, 0x00, sizeof(CGRAM));

 MSEnable = 0x00;
 SSEnable = 0x00;

 memset(WMSettings, 0x00, sizeof(WMSettings));
 WMMainEnable = 0x00;
 WMSubEnable = 0x00;
 WMLogic = 0x0000;
 memset(WindowPos, 0x00, sizeof(WindowPos));

 CGWSEL = 0x00;
 CGADSUB = 0x00;
 FixedColor = 0x0000;

 OBSEL = 0x00;
 OAMADDL = 0x00;
 OAMADDH = 0x00;

 OAM_Buffer = 0x00;
 OAM_Addr = 0;
 if(powering_up)
 {
  memset(OAM, 0x00, sizeof(OAM));
  memset(OAMHI, 0x00, sizeof(OAMHI));
 }

 //
 //
 //
 if(powering_up)
 {
  HTime = 0x1FF;
  VTime = 0x1FF;
 }

 NMIFlag = 0x00;
 IRQFlag = 0x00;
 NMITIMEEN = 0;
 CPU_SetNMI(false);
 CPU_SetIRQ(false);
}

void PPU_StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(LineStartTS),
  SFVAR(HLatch),
  SFVAR(VLatch),
  SFVAR(HVLatchReadShift),

  SFVAR(NMITIMEEN),

  SFVAR(HTime),
  SFVAR(VTime),

  SFVAR(HVBJOY),
  SFVAR(NMIFlag),
  SFVAR(IRQFlag),
  SFVAR(JPReadCounter),

  SFVAR(VBlank),
  SFVAR(LineCounter),
  SFVAR(LinePhase),
  SFVAR(scanline),

  SFVAR(BusLatch),
  SFVAR(Status),

  SFVAR(VRAM),

  SFVAR(ScreenMode),
  SFVAR(INIDisp),
  SFVAR(BGMode),
  SFVAR(Mosaic),
  SFVAR(MosaicYOffset),

  SFVAR(BGSC),

  SFVAR(BGNBA),

  SFVAR(BGOFSPrev),
  SFVAR(BGHOFS),
  SFVAR(BGVOFS),

  SFVAR(VRAM_Addr),
  SFVAR(VRAM_ReadBuffer),
  SFVAR(VMAIN_IncMode),
  SFVAR(VMAIN_AddrInc),
  SFVAR(VMAIN_AddrTransMaskA),
  SFVAR(VMAIN_AddrTransShiftB),
  SFVAR(VMAIN_AddrTransMaskC),

  SFVAR(M7Prev),
  SFVAR(M7SEL),
  SFVAR(M7Matrix),
  SFVAR(M7Center),
  SFVAR(M7HOFS),
  SFVAR(M7VOFS),

  SFVAR(CGRAM_Toggle),
  SFVAR(CGRAM_Buffer),
  SFVAR(CGRAM_Addr),
  SFVAR(CGRAM),

  SFVAR(MSEnable),
  SFVAR(SSEnable),

  SFVAR(WMSettings),
  SFVAR(WMMainEnable),
  SFVAR(WMSubEnable),
  SFVAR(WMLogic),
  SFVARN(WindowPos, "&WindowPos[0][0]"),

  SFVAR(CGWSEL),
  SFVAR(CGADSUB),
  SFVAR(FixedColor),

  SFVAR(OBSEL),
  SFVAR(OAMADDL),
  SFVAR(OAMADDH),
  SFVAR(OAM_Buffer),
  SFVAR(OAM_Addr),
  SFVAR(OAM),
  SFVAR(OAMHI),

  SFEND
 };

 // TODO: Might want to save sprite fetch state when we add a debugger(for save states in step mode, which may occur outside of vblank).

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "PPU");

 if(load)
 {
  OAM_Addr &= 0x3FF;
  VMAIN_AddrTransMaskA &= 0x7FFF;
  VMAIN_AddrTransMaskC &= 0x7FFF;
 }
}

}

