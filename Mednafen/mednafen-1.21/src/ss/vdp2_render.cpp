/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* vdp2_render.cpp - VDP2 Rendering
**  Copyright (C) 2016-2017 Mednafen Team
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

// TODO: 31KHz monitor mode.
// When implementing GetRegister(), remember RPRCTL and window x start and end registers can
//  change outside of direct register writes
// Ignore T4-T7 in hires and 31KHz monitor mode.

#include "ss.h"
#include <mednafen/mednafen.h>
#include <mednafen/Time.h>
#include "vdp2_common.h"
#include "vdp2_render.h"

#include <atomic>

namespace MDFN_IEN_SS
{

//uint8 vdp2rend_prepad_bss

static EmulateSpecStruct* espec = NULL;
static bool PAL;
static bool CorrectAspect;
static bool ShowHOverscan;
static bool DoHBlend;
static int LineVisFirst, LineVisLast;
static uint32 NextOutLine;
static bool Clock28M;
static unsigned VisibleLines;
static VDP2Rend_LIB LIB[256];
static uint16 VRAM[262144];
static uint16 CRAM[2048];

static uint8 HRes, VRes;
static bool BorderMode;
static uint8 InterlaceMode;
enum { IM_NONE, IM_ILLEGAL, IM_SINGLE, IM_DOUBLE };

static bool CRKTE;
static uint8 CRAM_Mode;
enum
{
 CRAM_MODE_RGB555_1024	= 0,
 CRAM_MODE_RGB555_2048	= 1,
 CRAM_MODE_RGB888_1024	= 2,
 CRAM_MODE_ILLEGAL	= 3
};
static uint8 VRAM_Mode;
static uint8 RDBS_Mode;

static uint8 VCPRegs[4][8];
static const uint16 DummyTileNT[8 * 8 * 4 / sizeof(uint16)] = { 0 };

static uint32 UserLayerEnableMask;
//
//
//
static uint16 BGON;
static uint16 MZCTL;
static uint8 MosaicVCount;

static uint8 SFSEL;
static uint16 SFCODE;

static uint16 CHCTLA;
static uint16 CHCTLB;

static uint16 BMPNA;
static uint8 BMPNB;

static uint16 PNCN[4];
static uint16 PNCNR;

static uint16 PLSZ;
static uint16 MPOFN;
static uint16 MPOFR;

static uint8 MapRegs[4][4];
static uint8 RotMapRegs[2][16];
//
static uint16 XScrollI[4], YScrollI[4];
static uint8 XScrollF[2], YScrollF[2];

static uint16 ZMCTL;
static uint16 SCRCTL;
static uint32 LineScrollAddr[2];
static uint32 VCScrollAddr;
static uint32 VCLast[2];

static uint16 XCoordInc[2], YCoordInc[2];
static uint32 YCoordAccum[2];
static uint32 MosEff_YCoordAccum[2];

static uint32 CurXScrollIF[2];
static uint32 CurYScrollIF[2];
static uint16 CurXCoordInc[2];
static uint32 CurLSA[2];

static uint16 NBG23_YCounter[2];
static uint16 MosEff_NBG23_YCounter[2];
//
static uint8 RPMD;
static uint8 KTCTL[2];
static uint16 OVPNR[2];
//
static uint32 BKTA;
static uint32 CurBackTabAddr;
static uint16 CurBackColor;

static uint32 LCTA;
static uint32 CurLCTabAddr;
static uint16 CurLCColor;

static uint8 LineColorEn;

static uint16 SFPRMD;
static uint16 CCCTL;
static uint16 SFCCMD;
//
static uint8 NBGPrioNum[4];
static uint8 RBG0PrioNum;

static uint8 NBGCCRatio[4];
static uint8 RBG0CCRatio;
static uint8 LineColorCCRatio;
static uint8 BackCCRatio;

//
static struct
{
 uint16 XStart, XEnd;
 uint32 LineWinAddr;
 bool LineWinEn;
 //
 bool YMet;
 uint16 CurXStart, CurXEnd;
 uint32 CurLineWinAddr;
} Window[2];

static uint8 WinControl[8];
enum
{
 WINLAYER_NBG0 = 0,
 WINLAYER_NBG1 = 1,
 WINLAYER_NBG2 = 2,
 WINLAYER_NBG3 = 3,
 WINLAYER_RBG0 = 4,
 WINLAYER_SPRITE = 5,
 WINLAYER_ROTPARAM = 6,
 WINLAYER_CC = 7,
};

static std::array<unsigned, 5> WinPieces;
//
static uint8 SpriteCCCond;
static uint8 SpriteCCNum;
static uint8 SPCTL_Low;

static uint16 SDCTL;

static uint8 SpritePrioNum[8];
static uint8 SpriteCCRatio[8];

static uint8 SpriteCCLUT[8];	// Temp optimization data
static uint8 SpriteCC3Mask; 	// Temp optimization data

//
static uint8 CRAMAddrOffs_NBG[4];
static uint8 CRAMAddrOffs_RBG0;
static uint8 CRAMAddrOffs_Sprite;
//
static uint8 ColorOffsEn;
static uint8 ColorOffsSel;

//enum
//{
// COLOFFS_ENSEL_NBG0 = 0,
// COLOFFS_ENSEL_NBG1 = 0,
//};

static int32 ColorOffs[2][3];	// [A,B] [R << 0, G << 8, B << 16]

template<bool IsRot>
struct TileFetcher
{
 unsigned CRAOffs;

 bool BMSCC;
 bool BMSPR;
 unsigned BMPalNo;
 unsigned BMSize;

 unsigned PlaneSize;
 unsigned PlaneOver;
 uint16 PlaneOverChar;
 bool PNDSize;
 bool CharSize;
 bool AuxMode;
 unsigned Supp;

 //
 //
 //
 unsigned BMOffset;
 unsigned BMWShift;
 unsigned BMWMask;
 unsigned BMHMask;

 uint32 adj_map_regs[IsRot ? 16 : 4];
 uint32 doxm, doym;

 bool nt_ok[4];
 bool cg_ok[4];

 // n=0...3, NBG0...3
 // n=4, RBG0
 // n=5, RBG1
 INLINE void Start(const unsigned n, const bool bmen, const unsigned map_offset, const uint8* map_regs)
 {
  BMOffset = map_offset << 16;
  BMWShift = ((BMSize & 2) ? 10 : 9);
  BMWMask = (1U << BMWShift) - 8;
  BMHMask = (BMSize & 1) ? 0x1FF : 0xFF;

  const unsigned psshift = (13 - PNDSize - (CharSize << 1));

  for(unsigned i = 0; i < (IsRot ? 16 : 4); i++)
  {
   adj_map_regs[i] = ((map_offset << 6) + (map_regs[i] &~ PlaneSize)) << psshift;
  }

  if(IsRot)
  {
   if(bmen)
   {
    doxm = ~(BMWMask + 7);
    doym = ~BMHMask;
   }
   else
   {
    doxm = ~((1U << ((9 + (bool)(PlaneSize & 0x1)) + (IsRot ? 2 : 1))) - 1);
    doym = ~((1U << ((9 + (bool)(PlaneSize & 0x2)) + (IsRot ? 2 : 1))) - 1);
   }

   if(PlaneOver == 0)
    doxm = doym = 0;
   else if(PlaneOver == 3)
    doxm = doym = ~511;
  }

  // Kludgeyness:
  for(unsigned bank = 0; bank < 4; bank++)
  {
   const unsigned esb = bank & (2 | ((VRAM_Mode >> (bank >> 1)) & 1));
   const uint8 rdbs = (RDBS_Mode >> (esb << 1)) & 0x3;

   if(IsRot)
   {
    if(!(BGON & 0x20) || n == 4)
    {
     nt_ok[bank] = (rdbs == RDBS_NAME) && (bank < 2 || !(BGON & 0x20));
     cg_ok[bank] = (rdbs == RDBS_CHAR) && (bank < 2 || !(BGON & 0x20));
    }
    else
    {
     nt_ok[bank] = (bank == 3);
     cg_ok[bank] = (bank == 2);
    }
   }
   else
   {
    nt_ok[bank] = false;
    cg_ok[bank] = false;

    if(!(BGON & 0x30) || rdbs == RDBS_UNUSED)
    {
     for(unsigned ac = 0; ac < ((HRes & 0x6) ? 4 : 8); ac++)
     {
      if(VCPRegs[esb][ac] == (VCP_NBG0_CG + n))
       cg_ok[bank] = true;

      if(VCPRegs[esb][ac] == (VCP_NBG0_NT + n))
       nt_ok[bank] = true;
     }
    }
   }
  }

  #if 1
  pcco = 0;
  spr = false;
  scc = false;
  tile_vrb = nullptr;
  cellx_xor = 0;
  #endif
 }

 //
 //
 //
 uint32 pcco;
 bool spr;
 bool scc;
 const uint16* tile_vrb;
 uint32 cellx_xor;

 template<unsigned TA_bpp>
 INLINE bool Fetch(const bool bmen, const uint32 ix, const uint32 iy)
 {
  size_t cg_addr;
  uint32 palno;
  bool is_outside = false;

  if(IsRot)
   is_outside = (ix & doxm) | (iy & doym);

  if(bmen)
  {
   palno = BMPalNo;
   spr = BMSPR;
   scc = BMSCC;
   cellx_xor = (ix &~ 0x7);
   cg_addr = (BMOffset + ((((ix & BMWMask) + ((iy & BMHMask) << BMWShift)) * TA_bpp) >> 4)) & 0x3FFFF;
  }
  else
  {
   bool vflip, hflip;
   uint16 charno;
   uint32 mapidx, planeidx, planeoffs, pageoffs;
   const uint16* pnd;
   uint32 celly;
   size_t nt_addr;

   if(IsRot)
    mapidx = ((ix >> (9 + (bool)(PlaneSize & 0x1))) & 0x3) | ((iy >> (9 + (bool)(PlaneSize & 0x2) - 2)) & 0xC);
   else
    mapidx = ((ix >> (9 + (bool)(PlaneSize & 0x1))) & 0x1) | ((iy >> (9 + (bool)(PlaneSize & 0x2) - 1)) & 0x2);

   planeidx = ((ix >> 9) & PlaneSize & 0x1) | ((iy >> (9 - 1)) & PlaneSize & 0x2);
   planeoffs = planeidx << (13 - PNDSize - (CharSize << 1));
   pageoffs = ((((ix >> 3) & 0x3F) >> CharSize) + ((((iy >> 3) & 0x3F) >> CharSize) << (6 - CharSize))) << (1 - PNDSize);
   nt_addr = (adj_map_regs[mapidx] + planeoffs + pageoffs) & 0x3FFFF;

   pnd = &VRAM[nt_addr];
   if(!nt_ok[nt_addr >> 16])
    pnd = DummyTileNT;

   if(IsRot && is_outside && PlaneOver == 1)
   {
    pnd = &PlaneOverChar;
    goto OverCharCase;
   }

   if(!PNDSize)
   {
    uint16 tmp = pnd[0];

    palno = tmp & 0x7F;
    vflip = (bool)(tmp & 0x8000);
    hflip = (bool)(tmp & 0x4000);
    spr = (bool)(tmp & 0x2000);
    scc = (bool)(tmp & 0x1000);
    charno = pnd[1] & 0x7FFF;
   }
   else
   {
    OverCharCase:;
    uint16 tmp = pnd[0];

    if(TA_bpp >= 8)
     palno = ((tmp >> 12) & 0x7) << 4;
    else
     palno = ((tmp >> 12) & 0xF) | (((Supp >> 5) & 0x7) << 4);
    spr = (bool)(Supp & 0x200);
    scc = (bool)(Supp & 0x100);

    if(!AuxMode)
    {
     vflip = (bool)(tmp & 0x800);
     hflip = (bool)(tmp & 0x400);

     if(CharSize)
      charno = ((tmp & 0x3FF) << 2) + ((Supp & 0x1C) << 10) + (Supp & 0x3);
     else
      charno = (tmp & 0x3FF) + ((Supp & 0x1F) << 10);
    }
    else
    {
     hflip = vflip = false;

     if(CharSize)
      charno = ((tmp & 0xFFF) << 2) + ((Supp & 0x10) << 10) + (Supp & 0x3);
     else
      charno = (tmp & 0xFFF) + ((Supp & 0x1C) << 10);
    }
   }

   if(CharSize)
   {
    uint32 cidx = (((ix >> 3) ^ hflip) & 0x1) + (((iy >> 2) ^ (vflip << 1)) & 0x2);
    charno = (charno + cidx * (TA_bpp >> 2)) & 0x7FFF;
   }

   cellx_xor = (ix &~ 0x7) | (hflip ? 0x7 : 0x0);
   celly = (iy & 0x7) ^ (vflip ? 0x7 : 0);
   cg_addr = ((charno << 4) + ((celly * TA_bpp) >> 1)) & 0x3FFFF;
  }
  tile_vrb = &VRAM[cg_addr];

  if(!cg_ok[cg_addr >> 16])
  {
   //printf("Goop: %08zx, %d %02x, %016llx %016llx %016llx %016llx\n", cg_addr, TA_bpp, VRAM_Mode, MDFN_de64lsb(VCPRegs[0]), MDFN_de64lsb(VCPRegs[1]), MDFN_de64lsb(VCPRegs[2]), MDFN_de64lsb(VCPRegs[3]));
   tile_vrb = DummyTileNT;
  }

  //
  //
  //
  pcco = ((palno << 4) &~ ((1U << (TA_bpp & 0x1F)) - 1)) + CRAOffs;

  return IsRot && is_outside && (PlaneOver & 2);
 }
};

struct RotVars
{
 int32 Xsp, Ysp;// .10
 int32 Xp, Yp;	// .10
 int32 dX, dY;	// .10

 int32 kx, ky;	// .16

 bool use_coeff;
 uint32 base_coeff;

 TileFetcher<true> tf;
};

static struct
{
 uint64 spr[704];
 uint64 rbg0[704];
 union
 {
  uint64 nbg[4][8 + 704 + 8];
  struct
  {
   uint8 dummy[sizeof(nbg) / 2];
   uint16 vcscr[2][88 + 1 + 1];	// + 1 for fine x scroll != 0, + 1 for pointer shenanigans in FetchVCScroll
  };
  struct
  {
   uint8 rotdummy[sizeof(nbg) / 4];
   uint8 rotabsel[352];	// Also used as a scratch buffer in T_DrawRBG() to handle mosaic-related junk.
   RotVars rotv[2];
   uint32 rotcoeff[352];
  };
 };
 alignas(16) uint8 lc[704];
} LB;

// ColorOffsEn, etc. ?...hmm, discrepancy with ColorCalcEn and LineColorEn...
enum
{
 LAYER_NBG0 = 0,
 //LAYER_RBG1 = 0,
 LAYER_NBG1 = 1,
 //LAYER_EXBG = 1,
 LAYER_NBG2 = 2,
 LAYER_NBG3 = 3,

 LAYER_RBG0 = 4,
 LAYER_BACK = 5, // Line color?
 LAYER_SPRITE = 6,
};

//
//
//
static uint32 ColorCache[2048];
static void CacheCRE(const unsigned cri)
{
 if(CRAM_Mode & CRAM_MODE_RGB888_1024)
 {
  (ColorCache + 0x000)[cri >> 1] = (ColorCache + 0x400)[cri >> 1] = (((CRAM + 0x000)[(cri >> 1) & 0x3FF] & 0x80FF) << 16) | ((CRAM + 0x400)[(cri >> 1) & 0x3FF] << 0);
 }
 else
 {
  const uint16 t = CRAM[cri & ((CRAM_Mode == CRAM_MODE_RGB555_1024) ? 0x3FF : 0x7FF)];
  const uint32 col = ((t << 3) & 0xF8) | ((t << 6) & 0xF800) | ((t << 9) & 0xF80000) | ((t << 16) & 0x80000000);

  if(CRAM_Mode == CRAM_MODE_RGB555_1024)
   (ColorCache + 0x000)[cri & 0x3FF] = (ColorCache + 0x400)[cri & 0x3FF] = col;
  else
   ColorCache[cri] = col;
 }
}

static void RecalcColorCache(void)
{
 if(CRAM_Mode & CRAM_MODE_RGB888_1024)
 {
  for(unsigned i = 0; i < 2048; i += 2)
   CacheCRE(i);
 }
 else
 {
  const unsigned count = (CRAM_Mode == CRAM_MODE_RGB555_2048) ? 2048 : 1024;

  for(unsigned i = 0; i < count; i++)
   CacheCRE(i);
 }
}

//
// Register writes seem to always be 16-bit
//
static INLINE void RegsWrite(uint32 A, uint16 V)
{
 A &= 0x1FE;

 switch(A)
 {
  default:
	break;

  case 0x00:
	//DisplayOn = (V >> 15) & 0x1;
	BorderMode = (V >> 8) & 0x1;
	InterlaceMode = (V >> 6) & 0x3;
	VRes = (V >> 4) & 0x3;
	HRes = (V >> 0) & 0x7;
	break;

  case 0x02:
	//ExLatchEnable = (V >> 9) & 0x1;
	//ExSyncEnable = (V >> 8) & 0x1;

	//DispAreaSelect = (V >> 1) & 0x1;
	//ExBGEnable = (V >> 0) & 0x1;
	break;

  case 0x0E:
	{
	 const unsigned old_CRAM_Mode = CRAM_Mode;

	 CRKTE = (V >> 15) & 0x1;
	 CRAM_Mode = (V >> 12) & 0x3;;
	 VRAM_Mode = (V >> 8) & 0x3;
	 RDBS_Mode = V & 0xFF;

	 if(old_CRAM_Mode != CRAM_Mode)
	  RecalcColorCache();
	}
	break;
  //
  case 0x10:
  case 0x12:
  case 0x14:
  case 0x16:
  case 0x18:
  case 0x1A:
  case 0x1C:
  case 0x1E:
	{
	 uint8* const b = &VCPRegs[(A >> 2) & 3][(A & 0x2) << 1];
	 b[0] = (V >> 12) & 0xF;
	 b[1] = (V >>  8) & 0xF;
	 b[2] = (V >>  4) & 0xF;
	 b[3] = (V >>  0) & 0xF;
	}
	break;
  //
  case 0x20:
	BGON = V & 0x1F3F;
	break;

  case 0x22:
	MZCTL = V & 0xFF1F;
	break;

  case 0x24:
	SFSEL = V & 0x1F;
	break;

  case 0x26:
	SFCODE = V;
	break;

  case 0x28:
	CHCTLA = V & 0x3F7F;
	break;

  case 0x2A:
	CHCTLB = V & 0x7733;
	break;

  case 0x2C:
	BMPNA = V & 0x3737;
	break;

  case 0x2E:
	BMPNB = V & 0x37;
	break;

  //
  case 0x30:
  case 0x32:
  case 0x34:
  case 0x36:
	PNCN[(A & 0x6) >> 1] = V & 0xC3FF;
	break;

  case 0x38:
	PNCNR = V & 0xC3FF;
	break;

  //
  case 0x3A:
	PLSZ = V;	// Plane size
	break;

  case 0x3C:
	MPOFN = V & 0x7777;	// Map offset NBG
	break;

  case 0x3E:
	MPOFR = V & 0x0077;	// Map offset RBG
	break;
  //
  case 0x40:
  case 0x42:
  case 0x44:
  case 0x46:
  case 0x48:
  case 0x4A:
  case 0x4C:
  case 0x4E:
	MapRegs[(A & 0xC) >> 2][(A & 0x2) + 0] = (V >> 0) & 0x3F;
	MapRegs[(A & 0xC) >> 2][(A & 0x2) + 1] = (V >> 8) & 0x3F;
	break;

  case 0x50: case 0x52: case 0x54: case 0x56: case 0x58: case 0x5A: case 0x5C: case 0x5E:
  case 0x60: case 0x62: case 0x64: case 0x66: case 0x68: case 0x6A: case 0x6C: case 0x6E:
	RotMapRegs[(bool)(A & 0x20)][(A & 0xE) + 0] = (V >> 0) & 0x3F;
	RotMapRegs[(bool)(A & 0x20)][(A & 0xE) + 1] = (V >> 8) & 0x3F;
	break;
  //
  case 0x70:
  case 0x80:
	XScrollI[A >> 7] = V & 0x7FF;
	break;

  case 0x72:
  case 0x82:
	XScrollF[A >> 7] = (V >> 8) & 0xFF;
	break;

  case 0x74:
  case 0x84:
	YScrollI[A >> 7] = V & 0x7FF;
	break;

  case 0x76:
  case 0x86:
	YScrollF[A >> 7] = (V >> 8) & 0xFF;
	break;

  case 0x78:
  case 0x88:
	XCoordInc[A >> 7] = (XCoordInc[A >> 7] & 0xFF) | ((V & 0x7) << 8);
	break;

  case 0x7A:
  case 0x8A:
	XCoordInc[A >> 7] = (XCoordInc[A >> 7] & 0x700) | ((V >> 8) & 0xFF);
	break;

  case 0x7C:
  case 0x8C:
	YCoordInc[A >> 7] = (YCoordInc[A >> 7] & 0xFF) | ((V & 0x7) << 8);
	break;

  case 0x7E:
  case 0x8E:
	YCoordInc[A >> 7] = (YCoordInc[A >> 7] & 0x700) | ((V >> 8) & 0xFF);
	break;

  case 0x90:
  case 0x94:
	XScrollI[2 + (bool)(A & 0x4)] = V & 0x7FF;
	break;

  case 0x92:
  case 0x96:
	{
	 const unsigned which = (bool)(A & 0x4);

	 NBG23_YCounter[which] = YScrollI[2 + which] = V & 0x7FF;
	}
	break;

  case 0x98:
	ZMCTL = V & 0x0303;
	break;

  case 0x9A:
	SCRCTL = V & 0x3F3F;
	break;

  case 0x9C:
	VCScrollAddr = (VCScrollAddr & 0xFFFF) | ((V & 0x7) << 16);
	break;

  case 0x9E:
	VCScrollAddr = (VCScrollAddr & 0x70000) | (V & 0xFFFE);
	break;

  case 0xA0:
	LineScrollAddr[0] = (LineScrollAddr[0] & 0xFFFF) | ((V & 0x7) << 16);
	break;

  case 0xA2:
	LineScrollAddr[0] = (LineScrollAddr[0] & 0x70000) | (V & 0xFFFE);
	break;

  case 0xA4:
	LineScrollAddr[1] = (LineScrollAddr[1] & 0xFFFF) | ((V & 0x7) << 16);
	break;

  case 0xA6:
	LineScrollAddr[1] = (LineScrollAddr[1] & 0x70000) | (V & 0xFFFE);
	break;

  //
  case 0xA8:
	LCTA = (LCTA & 0xFFFF) | ((V & 0x8007) << 16);
	break;

  case 0xAA:
	LCTA = (LCTA & ~0xFFFF) | V;
	break;

  case 0xAC:
	BKTA = (BKTA & 0xFFFF) | ((V & 0x8007) << 16);
	break;

  case 0xAE:
	BKTA = (BKTA & ~0xFFFF) | V;
	break;
  //
  case 0xB0:
	RPMD = V & 0x3;
	break;

  case 0xB4:
	KTCTL[0] = (V >> 0) & 0x1F;
	KTCTL[1] = (V >> 8) & 0x1F;
	break;

  case 0xB8:
	OVPNR[0] = V;
	break;

  case 0xBA:
	OVPNR[1] = V;
	break;

  //
  case 0xC0: Window[0].XStart = V & 0x3FF; break;
  case 0xC4: Window[0].XEnd = V & 0x3FF; break;

  case 0xC8: Window[1].XStart = V & 0x3FF; break;
  case 0xCC: Window[1].XEnd = V & 0x3FF; break;

  case 0xD0:
  case 0xD2:
  case 0xD4:
	WinControl[(A & 0x6) + 0] = (V >> 0) & 0xBF;
	WinControl[(A & 0x6) + 1] = (V >> 8) & 0xBF;
	break;

  case 0xD6:
	WinControl[(A & 0x6) + 0] = (V >> 0) & 0x8F;	// Rot
	WinControl[(A & 0x6) + 1] = (V >> 8) & 0xBF;	// CC
	break;

  case 0xD8:
  case 0xDC:
	{
	 const unsigned w = (A & 0x4) >> 2;

	 Window[w].LineWinEn = (bool)(V & 0x8000);
	 Window[w].LineWinAddr = (Window[w].LineWinAddr & 0xFFFF) | ((V & 0x7) << 16);
	}
	break;

  case 0xDA:
  case 0xDE:
	{
	 const unsigned w = (A & 0x4) >> 2;

	 Window[w].LineWinAddr = (Window[w].LineWinAddr & 0x70000) | (V & 0xFFFE);
	}
	break;

  //
  case 0xE0:
	SpriteCCCond = (V >> 12) & 0x3;
	SpriteCCNum = (V >> 8) & 0x7;
	SPCTL_Low = V & 0x3F;
	break;	

  case 0xE2:
	SDCTL = V & 0x13F;
	break;

  case 0xE4:
	CRAMAddrOffs_NBG[0] = (V >>  0) & 0x7;
	CRAMAddrOffs_NBG[1] = (V >>  4) & 0x7;
	CRAMAddrOffs_NBG[2] = (V >>  8) & 0x7;
	CRAMAddrOffs_NBG[3] = (V >> 12) & 0x7;
	break;

  case 0xE6:
	CRAMAddrOffs_RBG0 = (V >> 0) & 0x7;
	CRAMAddrOffs_Sprite = (V >> 4) & 0x7;
	break;

  case 0xE8:
	LineColorEn = V & 0x3F;
	break;

  case 0xEA:
	SFPRMD = V & 0x3FF;
	break;

  case 0xEC:
	CCCTL = V & 0xF77F;
	break;

  case 0xEE:
	SFCCMD = V & 0x3FF;
	break;

  case 0xF0:
  case 0xF2:
  case 0xF4:
  case 0xF6:
	SpritePrioNum[(A & 0x6) + 0] = ((V >> 0) & 0x7);
	SpritePrioNum[(A & 0x6) + 1] = ((V >> 8) & 0x7);
	break;

  case 0xF8:
	NBGPrioNum[0] = (V >> 0) & 0x7;
	NBGPrioNum[1] = (V >> 8) & 0x7;
	break;

  case 0xFA:
	NBGPrioNum[2] = (V >> 0) & 0x7;
	NBGPrioNum[3] = (V >> 8) & 0x7;
	break;

  case 0xFC:
	RBG0PrioNum = (V >> 0) & 0x7;
	break;

  case 0x100:
  case 0x102:
  case 0x104:
  case 0x106:
	SpriteCCRatio[(A & 0x6) + 0] = (V >> 0) & 0x1F;
	SpriteCCRatio[(A & 0x6) + 1] = (V >> 8) & 0x1F;
	break;

  case 0x108:
  case 0x10A:
	NBGCCRatio[(A & 0x2) + 0] = (V >> 0) & 0x1F;
	NBGCCRatio[(A & 0x2) + 1] = (V >> 8) & 0x1F;
	break;

  case 0x10C:
	RBG0CCRatio = V & 0x1F;
	break;

  case 0x10E:
	LineColorCCRatio = (V >> 0) & 0x1F;
	BackCCRatio = (V >> 8) & 0x1F;
	break;

  case 0x110:
	ColorOffsEn = V & 0x7F;
	break;

  case 0x112:
	ColorOffsSel = V & 0x7F;
	break;

  case 0x114: // A Red
  case 0x116: // A Green
  case 0x118: // A Blue
  case 0x11A: // B Red
  case 0x11C: // B Green
  case 0x11E: // B Blue
	{
	 const unsigned ab = (A >= 0x11A);
	 const unsigned wcc = ((A - 0x114) >> 1) % 3;

	 ColorOffs[ab][wcc] = (uint32)sign_x_to_s32(9, V) << (wcc << 3);
	}
	break;
 }
}

template<typename T>
static INLINE void MemW(uint32 A, const uint16 DB)
{
 A &= 0x1FFFFF;

 //
 // VRAM
 //
 if(A < 0x100000)
 {
  const size_t vri = (A & 0x7FFFF) >> 1;
  const unsigned mask = (sizeof(T) == 2) ? 0xFFFF : (0xFF00 >> ((A & 1) << 3));

  VRAM[vri] = (VRAM[vri] &~ mask) | (DB & mask);

  return;
 }

 //
 // CRAM
 //
 if(A < 0x180000)
 {
  const unsigned cri = (A & 0xFFF) >> 1;

  switch(CRAM_Mode)
  {
    case CRAM_MODE_RGB555_1024:
	(CRAM + 0x000)[cri & 0x3FF] = DB;
	(CRAM + 0x400)[cri & 0x3FF] = DB;
	CacheCRE(cri);
	break;

    case CRAM_MODE_RGB555_2048:
	CRAM[cri] = DB;
	CacheCRE(cri);
	break;

    case CRAM_MODE_RGB888_1024:
    case CRAM_MODE_ILLEGAL:
    default:
	CRAM[((cri >> 1) & 0x3FF) | ((cri & 1) << 10)] = DB;
	CacheCRE(cri);
	break;
  }

  return;
 }

 //
 // Registers
 //
 if(A < 0x1C0000)
 {
  RegsWrite(A, DB);

  return;
 }
}


static void Reset(bool powering_up)
{
 if(powering_up)
 {
  memset(VRAM, 0, sizeof(VRAM));
  memset(CRAM, 0, sizeof(CRAM));
 }
 //
 //
 CRKTE = false;
 CRAM_Mode = 0;
 VRAM_Mode = 0;
 RDBS_Mode = 0;
 HRes = 0;
 VRes = 0;
 BorderMode = false;
 InterlaceMode = 0;
 //
 memset(VCPRegs, 0, sizeof(VCPRegs));
 //
 BGON = 0;
 MZCTL = 0;
 MosaicVCount = 0;

 SFSEL = 0;
 SFCODE = 0;

 CHCTLA = 0;
 CHCTLB = 0;

 BMPNA = 0;
 BMPNB = 0;

 for(unsigned n = 0; n < 4; n++)
  PNCN[n] = 0;

 PNCNR = 0;

 PLSZ = 0;
 MPOFN = 0;
 MPOFR = 0;

 for(unsigned n = 0; n < 4; n++)
 {
  for(unsigned i = 0; i < 4; i++)
   MapRegs[n][i] = 0;
 }

 for(unsigned rn = 0; rn < 2; rn++)
 {
  for(unsigned i = 0; i < 16; i++)
   RotMapRegs[rn][i] = 0;
 }

 //
 for(unsigned n = 0; n < 4; n++)
 {
  XScrollI[n] = 0;
  YScrollI[n] = 0;

  if(n < 2)
  {
   XScrollF[n] = 0;
   YScrollF[n] = 0;

   XCoordInc[n] = 0;
   YCoordInc[n] = 0;
   YCoordAccum[n] = 0;
   MosEff_YCoordAccum[n] = 0;
  }
  else
  {
   NBG23_YCounter[n & 1] = 0;
   MosEff_NBG23_YCounter[n & 1] = 0;
  }
 }

 ZMCTL = 0;
 SCRCTL = 0;
 LineScrollAddr[0] = 0;
 LineScrollAddr[1] = 0;
 VCScrollAddr = 0;
 VCLast[0] = VCLast[1] = 0;

 for(unsigned n = 0; n < 2; n++)
 {
  CurXScrollIF[n] = 0;
  CurYScrollIF[n] = 0;
  CurLSA[n] = 0;
  CurXCoordInc[n] = 0;
 }

 for(unsigned n = 0; n < 4; n++)
  NBGPrioNum[n] = 0;

 RBG0PrioNum = 0;

 for(unsigned n = 0; n < 4; n++)
  NBGCCRatio[n] = 0;

 RBG0CCRatio = 0;
 LineColorCCRatio = 0;
 BackCCRatio = 0;

 for(unsigned w = 0; w < 2; w++)
 {
  Window[w].XStart = 0;
  Window[w].XEnd = 0;
  Window[w].LineWinAddr = 0;
  Window[w].LineWinEn = false;

  Window[w].YMet = false;
  Window[w].CurXStart = 0;
  Window[w].CurXEnd = 0;
  Window[w].CurLineWinAddr = 0;
 }

 for(unsigned i = 0; i < 8; i++)
  WinControl[i] = 0;

 //
 RPMD = 0;
 for(unsigned i = 0; i < 2; i++)
 {
  KTCTL[i] = 0;
  OVPNR[i] = 0;
 }
 //
 BKTA = 0;
 CurBackTabAddr = 0;
 CurBackColor = 0;

 LCTA = 0;
 CurLCTabAddr = 0;
 CurLCColor = 0;

 LineColorEn = 0;

 SFPRMD = 0;
 SFCCMD = 0;

 CCCTL = 0;
 //
 SpriteCCCond = 0;
 SpriteCCNum = 0;
 SPCTL_Low = 0;

 SDCTL = 0;
 //
 for(auto& spn : SpritePrioNum)
  spn = 0;
 //
 for(auto& scr : SpriteCCRatio)
  scr = 0;
 //
 for(auto& ao : CRAMAddrOffs_NBG)
  ao = 0;

 CRAMAddrOffs_RBG0 = 0;

 CRAMAddrOffs_Sprite = 0;
 //
 ColorOffsEn = 0;
 ColorOffsSel = 0;

 for(auto& co : ColorOffs)
  for(auto& coe : co)
   coe = 0;
}

// Prio(3 bits), color calc(1 bit), layer num(3 bits), 1 bit for palette/rgb format, 1 bit for line color enable, 1 bit for color offs enable, 1 bit for color offs select
//    1 bit for line color screen enable?, 1 bit allow sprite shadow, 1 bit do sprite shadow
// Prio, color calc, layer num

enum
{
 PIX_ISRGB_SHIFT = 0,	// original format, 0 = paletted, 1 = RGB
 PIX_LCE_SHIFT = 1,	// Line color enable
 PIX_COE_SHIFT = 2,	// Color offs enable
 PIX_COSEL_SHIFT = 3,	// Color offset select(which color offset registers to use)
 PIX_CCE_SHIFT = 4,	// Color calc enable

 //
 // Sprite shadow nonsense
 // Keep these in this order at these bit positions
 PIX_SHADEN_SHIFT = 5,	//
 PIX_DOSHAD_SHIFT = 6,
 PIX_SELFSHAD_SHIFT = 7,
 PIX_SHADHALVTEST8_VAL = 0x60,
 //
 //
 //
 //

 // 8 ... 15
 PIX_PRIO_TEST_SHIFT = 8,
 PIX_PRIO_SHIFT = PIX_PRIO_TEST_SHIFT + 3,

 //
 PIX_GRAD_SHIFT = 16,
 PIX_LAYER_CCE_SHIFT = 17,	// For extended color calculation

 // 24...31
 PIX_CCRATIO_SHIFT = 24,

 // 32 ... 55
 PIX_RGB_SHIFT = 32,

 //
 PIX_SWBIT_SHIFT = 56,

 // Reminder that highest bit can be == 1 when RGB data is pulled from ColorCache
 //SPECIAL_CCALC_SHIFT = 63
};

static INLINE void GetCWV(const uint8 ctrl, const bool* const xmet, bool* cwv)
{
 const bool logic = (ctrl >> 7) & 1;	// 0 = OR, 1 = AND
 const bool w_enable[2] = { (bool)(ctrl & 0x02), (bool)(ctrl & 0x08) };
 const bool w_area[2] = { (bool)(ctrl & 0x01), (bool)(ctrl & 0x04) };
 const bool sw_enable = ctrl & 0x20;
 const bool sw_area = ctrl & 0x10;

 for(unsigned swinput = 0; swinput < 2; swinput++)
 {
  bool wval[2];
  bool swval;

  wval[0] = (w_enable[0] ? ((xmet[0] & Window[0].YMet) ^ w_area[0]) : logic);
  wval[1] = (w_enable[1] ? ((xmet[1] & Window[1].YMet) ^ w_area[1]) : logic);

  swval = sw_enable ? (swinput ^ sw_area) : logic;

  if(logic)
   cwv[swinput] = wval[0] & wval[1] & swval;
  else
   cwv[swinput] = wval[0] | wval[1] | swval;
 }
}

static void GetWinRotAB(void)
{
 unsigned x = 0;

 for(unsigned piece = 0; piece < WinPieces.size(); piece++)
 {
  bool xmet[2];

  xmet[0] = ((x >= Window[0].CurXStart) & (x <= Window[0].CurXEnd));
  xmet[1] = ((x >= Window[1].CurXStart) & (x <= Window[1].CurXEnd));
  //
  //
  //
  bool cwv[2];

  GetCWV(WinControl[WINLAYER_ROTPARAM], xmet, cwv);

  if(HRes & 0x2)
  {
   for(; MDFN_LIKELY(x < WinPieces[piece]); x += 2)
    LB.rotabsel[x >> 1] = cwv[(LB.spr[x] >> PIX_SWBIT_SHIFT) & 1];
  }
  else
  {
   for(; MDFN_LIKELY(x < WinPieces[piece]); x++)
    LB.rotabsel[x] = cwv[(LB.spr[x] >> PIX_SWBIT_SHIFT) & 1];
  }
 }
}

static void ApplyWin(const unsigned wlayer, uint64* buf)
{
 unsigned x = 0;

 //printf("%d %d %d %d %d --- %d %d\n", WinPieces[0], WinPieces[1], WinPieces[2], WinPieces[3], WinPieces[4], Window[0].CurXStart, Window[0].CurXEnd);

 for(unsigned piece = 0; piece < WinPieces.size(); piece++)
 {
  bool xmet[2];

  xmet[0] = ((x >= Window[0].CurXStart) & (x <= Window[0].CurXEnd));
  xmet[1] = ((x >= Window[1].CurXStart) & (x <= Window[1].CurXEnd));

  //
  //
  //
  bool cwv[2];
  bool cc_cwv[2];

  GetCWV(WinControl[wlayer], xmet, cwv);
  GetCWV(WinControl[WINLAYER_CC], xmet, cc_cwv);

  if(!((cwv[0] ^ cwv[1]) | (cc_cwv[0] ^ cc_cwv[1])))	// Fast path(no sprite window, or sprite window wouldn't have an effect in this piece).
  {
   if(cwv[0])
   {
    for(; MDFN_LIKELY(x < WinPieces[piece]); x++)
     buf[x] &= ~(uint64)0xFFFFFFFF;
   }
   else if(cc_cwv[0])
   {
    for(; MDFN_LIKELY(x < WinPieces[piece]); x++)
     buf[x] &= ~(uint64)(1U << PIX_CCE_SHIFT);
   }
   x = WinPieces[piece];
  }
  else
  {
   uint64 masks[2];

   for(unsigned i = 0; i < 2; i++)
   {
    uint64 m = ~(uint64)0;

    if(cwv[i])
     m = ~(uint64)0xFFFFFFFF;

    if(cc_cwv[i])
     m &= ~(uint64)(1U << PIX_CCE_SHIFT);

    masks[i] = m;
   }

   for(; MDFN_LIKELY(x < WinPieces[piece]); x++)
   {
    buf[x] &= masks[(LB.spr[x] >> PIX_SWBIT_SHIFT) & 1];
   }
  }
 }
}

#pragma GCC push_options
#pragma GCC optimize("no-unroll-loops,no-peel-loops,no-crossjumping")
static NO_INLINE void ApplyHMosaic(const unsigned layer, uint64* buf, const unsigned w)
{
 if(!(MZCTL & (1U << layer)))
  return;

 const unsigned moz_horiz_param = ((MZCTL >> 8) & 0xF);
 const unsigned moz_wmax = w - moz_horiz_param;
 unsigned x = 0;

 switch(moz_horiz_param)
 {
  case 0x0: x = moz_wmax; break;
  case 0x1: for(; x < moz_wmax; x += 0x2) { auto b = buf[x]; buf[x + 1] = b; } break;
  case 0x2: for(; x < moz_wmax; x += 0x3) { auto b = buf[x]; buf[x + 1] = b; buf[x + 2] = b; } break;
  case 0x3: for(; x < moz_wmax; x += 0x4) { auto b = buf[x]; buf[x + 1] = b; buf[x + 2] = b; buf[x + 3] = b; } break;
  case 0x4: for(; x < moz_wmax; x += 0x5) { auto b = buf[x]; buf[x + 1] = b; buf[x + 2] = b; buf[x + 3] = b; buf[x + 4] = b; } break;
  case 0x5: for(; x < moz_wmax; x += 0x6) { auto b = buf[x]; buf[x + 1] = b; buf[x + 2] = b; buf[x + 3] = b; buf[x + 4] = b; buf[x + 5] = b; } break;
  case 0x6: for(; x < moz_wmax; x += 0x7) { auto b = buf[x]; buf[x + 1] = b; buf[x + 2] = b; buf[x + 3] = b; buf[x + 4] = b; buf[x + 5] = b; buf[x + 6] = b; } break;
  case 0x7: for(; x < moz_wmax; x += 0x8) { auto b = buf[x]; buf[x + 1] = b; buf[x + 2] = b; buf[x + 3] = b; buf[x + 4] = b; buf[x + 5] = b; buf[x + 6] = b; buf[x + 7] = b; } break;
  case 0x8: for(; x < moz_wmax; x += 0x9) { auto b = buf[x]; buf[x + 1] = b; buf[x + 2] = b; buf[x + 3] = b; buf[x + 4] = b; buf[x + 5] = b; buf[x + 6] = b; buf[x + 7] = b; buf[x + 8] = b; } break;
  case 0x9: for(; x < moz_wmax; x += 0xA) { auto b = buf[x]; buf[x + 1] = b; buf[x + 2] = b; buf[x + 3] = b; buf[x + 4] = b; buf[x + 5] = b; buf[x + 6] = b; buf[x + 7] = b; buf[x + 8] = b; buf[x + 9] = b; } break;
  case 0xA: for(; x < moz_wmax; x += 0xB) { auto b = buf[x]; buf[x + 1] = b; buf[x + 2] = b; buf[x + 3] = b; buf[x + 4] = b; buf[x + 5] = b; buf[x + 6] = b; buf[x + 7] = b; buf[x + 8] = b; buf[x + 9] = b; buf[x + 10] = b; } break;
  case 0xB: for(; x < moz_wmax; x += 0xC) { auto b = buf[x]; buf[x + 1] = b; buf[x + 2] = b; buf[x + 3] = b; buf[x + 4] = b; buf[x + 5] = b; buf[x + 6] = b; buf[x + 7] = b; buf[x + 8] = b; buf[x + 9] = b; buf[x + 10] = b; buf[x + 11] = b; } break;
  case 0xC: for(; x < moz_wmax; x += 0xD) { auto b = buf[x]; buf[x + 1] = b; buf[x + 2] = b; buf[x + 3] = b; buf[x + 4] = b; buf[x + 5] = b; buf[x + 6] = b; buf[x + 7] = b; buf[x + 8] = b; buf[x + 9] = b; buf[x + 10] = b; buf[x + 11] = b; buf[x + 12] = b; } break;
  case 0xD: for(; x < moz_wmax; x += 0xE) { auto b = buf[x]; buf[x + 1] = b; buf[x + 2] = b; buf[x + 3] = b; buf[x + 4] = b; buf[x + 5] = b; buf[x + 6] = b; buf[x + 7] = b; buf[x + 8] = b; buf[x + 9] = b; buf[x + 10] = b; buf[x + 11] = b; buf[x + 12] = b; buf[x + 13] = b; } break;
  case 0xE: for(; x < moz_wmax; x += 0xF) { auto b = buf[x]; buf[x + 1] = b; buf[x + 2] = b; buf[x + 3] = b; buf[x + 4] = b; buf[x + 5] = b; buf[x + 6] = b; buf[x + 7] = b; buf[x + 8] = b; buf[x + 9] = b; buf[x + 10] = b; buf[x + 11] = b; buf[x + 12] = b; buf[x + 13] = b; buf[x + 14] = b; } break;
  case 0xF: for(; x < moz_wmax; x += 0x10) { auto b = buf[x]; buf[x + 1] = b; buf[x + 2] = b; buf[x + 3] = b; buf[x + 4] = b; buf[x + 5] = b; buf[x + 6] = b; buf[x + 7] = b; buf[x + 8] = b; buf[x + 9] = b; buf[x + 10] = b; buf[x + 11] = b; buf[x + 12] = b; buf[x + 13] = b; buf[x + 14] = b; buf[x + 15] = b;} break;
 }
 assert(x <= w);

 for(auto b = buf[x]; x < w; x++)
  buf[x] = b;
}
#pragma GCC pop_options

//
// NBG0(HRES=0x1):
//   Cycle 0: OK
//   Cycle 1: OK
//
//   Cycle 2:
//	[Entry 0] [Entry 0] [Entry 1] [Entry 2]
//   Cycle 3 ... 7:
//	[Entry 44] [Entry 44] [Entry 0] [Entry 1]
//

static void FetchVCScroll(const unsigned w)
{
 const bool vcon[2] = { (bool)(SCRCTL & BGON & !(MZCTL & 0x1)), (bool)((SCRCTL >> 8) & (BGON >> 1) & !(MZCTL & 0x2) & 0x1) };
 const unsigned max_cyc = (HRes & 0x6) ? 4 : 8;
 const unsigned tc = (w >> 3) + 1;
 uint32 tmp[2] = { VCLast[0], VCLast[1] };
 uint32 vcaddr = VCScrollAddr & 0x3FFFE;
 uint32 base[2];
 unsigned inc[8];
 uint8 VRMVCPCache[4][8];

 for(unsigned bank = 0; bank < 4; bank++)
 {
  //unsigned brm[4];
  //brm[bank] = bank & (2 | ((VRAM_Mode >> (bank >> 1)) & 1));
  const unsigned esb = bank & (2 | ((VRAM_Mode >> (bank >> 1)) & 1));
  memcpy(VRMVCPCache[bank], VCPRegs[esb], 8);
 }

 for(unsigned n = 0; n < 2; n++)
  base[n] = CurYScrollIF[n] + YCoordAccum[n];

 for(unsigned cyc = 0; cyc < max_cyc; cyc++)
 {
  unsigned do_inc = 0;

  for(unsigned bank = 0; bank < 4; bank++)
  {
   const unsigned act = VRMVCPCache[bank][cyc];

   do_inc |= vcon[0] & (act == VCP_NBG0_VCS);
   do_inc |= vcon[1] & (act == VCP_NBG1_VCS);
  }

  inc[cyc] = do_inc << 1;
 }

 for(unsigned tile = 0; MDFN_LIKELY(tile < tc); tile++)
 {
  for(unsigned cyc = 0; cyc < max_cyc; cyc++)
  {
   const unsigned act = VRMVCPCache[vcaddr >> 16][cyc];

   // NBG0
   if(vcon[0])
   {
    if(cyc == 3)
     LB.vcscr[0][tile] = ((base[0] + tmp[0]) >> 8);

    if(cyc == 3)
     tmp[0] = VCLast[0];

    if(act == VCP_NBG0_VCS)
    {
     VCLast[0] = (VRAM[vcaddr + 0] << 8) | (VRAM[vcaddr + 1] >> 8);
     if(cyc <= (1 + !tile))
      tmp[0] = VCLast[0];
    }
   }

   // NBG1
   if(vcon[1])
   {
    if(cyc == 4)
     LB.vcscr[1][tile] = ((base[1] + tmp[1]) >> 8);

    if(cyc == 4)
     tmp[1] = VCLast[1];

    if(act == VCP_NBG1_VCS)
    {
     VCLast[1] = (VRAM[vcaddr + 0] << 8) | (VRAM[vcaddr + 1] >> 8);
     if(cyc <= 2) //(2 + !tile)) // TODO: Check
      tmp[1] = VCLast[1];
    }
   }

   vcaddr = (vcaddr + inc[cyc]) & 0x3FFFE;
  }
 }
}

template<unsigned TA_PrioMode, unsigned TA_CCMode>
static INLINE void MakeSFCodeLUT(const unsigned layer, int16* const sfcode_lut)
{
 const uint8 code = SFCODE >> (((SFSEL >> layer) & 1) << 3);

 for(unsigned i = 0; i < 8; i++)
 {
  uint16 tmp = 0xFFFF;

  if(!((code >> i) & 1))
  {
   if(TA_PrioMode & 2)
    tmp &= ~(1U << PIX_PRIO_SHIFT);

   if(TA_CCMode == 2)
    tmp &= ~(1U << PIX_CCE_SHIFT);
  }

  sfcode_lut[i] = tmp;
 }
}

static INLINE uint32 rgb15_to_rgb24(uint16 src)
{
 return ((((src << 3) & 0xF8) | ((src << 6) & 0xF800) | ((src << 9) & 0xF80000) | ((src << 16) & 0x80000000)));;
}

template<bool TA_bmen, unsigned TA_bpp, bool TA_isrgb, bool TA_igntp, unsigned TA_PrioMode, unsigned TA_CCMode, typename T>
static INLINE uint64 MakeNBGRBGPix(T& tf, const uint32 pix_base_or, const int16* sfcode_lut, const uint32 ix, const uint32 iy)
{
 uint32 cellx = (ix ^ tf.cellx_xor);
 const uint16* vrb = &tf.tile_vrb[((cellx * TA_bpp) >> 4)];
 //
 //
 //
 uint32 pbor = pix_base_or;
 uint32 rgb24;
 bool opaque;

 if(TA_CCMode == 1 || (TA_CCMode == 2 && !TA_isrgb))
  pbor |= (tf.scc << PIX_CCE_SHIFT);

 if(TA_PrioMode == 1 || (TA_PrioMode == 2 && !TA_isrgb))
  pbor |= (tf.spr << PIX_PRIO_SHIFT);

 if(TA_isrgb)
 {
  if(TA_bpp == 32)
  {
   uint32 tmp = (vrb[0] << 16) | vrb[1];

   rgb24 = tmp & 0xFFFFFF;
   opaque = (bool)(tmp & 0x80000000);
  }
  else
  {
   uint32 tmp = vrb[0];

   rgb24 = rgb15_to_rgb24(tmp & 0x7FFF);
   opaque = (bool)(tmp & 0x8000);
  }

  if(TA_CCMode == 3)
   pbor |= (1 << PIX_CCE_SHIFT);
 }
 else
 {
  uint32 dcc;
  uint32 tmp = vrb[0]; //charno ^ (charno << 8); //vrb[0];

  if(TA_bpp == 16)
   dcc = tmp & 0x7FF;
  else if(TA_bpp == 8)
   dcc = (tmp >> (((cellx & 1) ^ 1) << 3)) & 0xFF;
  else
   dcc = (tmp >> (((cellx & 3) ^ 3) << 2)) & 0x0F;

  opaque = (bool)dcc;

  rgb24 = ColorCache[(tf.pcco + dcc) & 2047];

  if(TA_CCMode == 3)
   pbor |= ((int32)rgb24 >> 31) & (1 << PIX_CCE_SHIFT);
  //
  if(TA_PrioMode == 2 || TA_CCMode == 2)
   pbor &= *(const int16*)((const uint8*)sfcode_lut + (dcc & 0xE));
 }

 if(!TA_igntp && !opaque)
  pbor = 0;

 return pbor | ((uint64)rgb24 << PIX_RGB_SHIFT);
}

template<bool TA_bmen, unsigned TA_bpp, bool TA_isrgb, bool TA_igntp, unsigned TA_PrioMode, unsigned TA_CCMode>
static void T_DrawNBG(const unsigned n, uint64* bgbuf, const unsigned w, const uint32 pix_base_or)
{
 assert(n < 2);
 //
 //
 const bool VCSEn = ((SCRCTL >> (n << 3)) & 0x1) && !(MZCTL & (1U << n));
 //
 TileFetcher<false> tf;
 uint32 xcinc;
 uint32 xc;
 uint32 iy;
 int16 sfcode_lut[8];

 tf.CRAOffs = CRAMAddrOffs_NBG[n] << 8;
 //
 tf.BMSCC = ((BMPNA >> (4 + (n << 3))) & 1);
 tf.BMSPR = ((BMPNA >> (5 + (n << 3))) & 1);
 tf.BMPalNo = ((BMPNA >> (0 + (n << 3))) & 0x7) << 4;
 tf.BMSize = ((CHCTLA >> (2 + (n << 3))) & 0x3);
 //
 tf.PlaneSize = (PLSZ >> (n << 1)) & 0x3;
 tf.PNDSize = (PNCN[n] >> 15) & 1;	// 0 = 2 words, 1 = 1 word
 tf.CharSize = ((CHCTLA >> (0 + (n << 3))) & 1);
 tf.AuxMode = (PNCN[n] >> 14) & 1;
 tf.Supp = (PNCN[n] & 0x3FF); // Supplement bits when PNDSize == 1
 //
 tf.Start(n, TA_bmen, (MPOFN >> (n << 2)) & 0x7, MapRegs[n]);

 MakeSFCodeLUT<TA_PrioMode, TA_CCMode>(n, sfcode_lut);

 xc = CurXScrollIF[n];
 iy = (CurYScrollIF[n] + MosEff_YCoordAccum[n]) >> 8;
 xcinc = CurXCoordInc[n];

 //if(line == 64)
 // printf("Mega %d: planesize=0x%1x charsize=%d pndsize=%d(auxmode=%d,supp=0x%04x) bpp=%d/%d ccmode=0x%04x SFSEL=0x%04x SFCODE=0x%04x SFCCMD=0x%04x\n", n, PlaneSize, CharSize, PNDSize, AuxMode, Supp, TA_bpp, TA_isrgb, TA_CCMode, SFSEL, SFCODE, SFCCMD);

 //printf("Mega %d %02x %d --- %04x %04x -- %04x --- lsa=0x%06x vcsa=0x%06x --- imode=0x%01x\n", TA_bpp, BMSize, w, xcinc, ycinc, SCRCTL, LineScrollAddr[n], VCScrollAddr, InterlaceMode);

 // Map: 2x2 planes
 // Plane: 1x1, 2x1, or 2x2 pages
 // Page: 64x64 cells
 // Character: 1x1, 2x2 cells
 // Cell: 8x8 dots
 uint32 prev_ix = ~0U;

 if(((ZMCTL >> (n << 3)) & 0x3) && VCSEn)
 {
  for(unsigned i = 0; MDFN_LIKELY(i < w); i++)
  {
   const uint32 ix = xc >> 8;
   iy = LB.vcscr[n][i >> 3];
   tf.Fetch<TA_bpp>(TA_bmen, ix, iy);
   //
   //
   //
   bgbuf[i] = MakeNBGRBGPix<TA_bmen, TA_bpp, TA_isrgb, TA_igntp, TA_PrioMode, TA_CCMode>(tf, pix_base_or, sfcode_lut, ix, iy);
   xc += xcinc;
  }
 }
 else
 {
  for(unsigned i = 0; MDFN_LIKELY(i < w); i++)
  {
   const uint32 ix = xc >> 8;

   if((ix >> 3) != prev_ix)
   {
    prev_ix = ix >> 3;
    //
    if(VCSEn)
     iy = LB.vcscr[n][(i + 7) >> 3];

    tf.Fetch<TA_bpp>(TA_bmen, ix, iy);
   }
   //
   //
   //
   bgbuf[i] = MakeNBGRBGPix<TA_bmen, TA_bpp, TA_isrgb, TA_igntp, TA_PrioMode, TA_CCMode>(tf, pix_base_or, sfcode_lut, ix, iy);
   xc += xcinc;
  }
 }
}

static void (*DrawNBG[2 /*bitmap enable*/][5/*col mode*/][2/*igntp*/][3/*priomode*/][4/*ccmode*/])(const unsigned n, uint64* bgbuf, const unsigned w, const uint32 pix_base_or) =
{
 {
  {  {  { T_DrawNBG<0, 4, 0, 0, 0, 0>, T_DrawNBG<0, 4, 0, 0, 0, 1>, T_DrawNBG<0, 4, 0, 0, 0, 2>, T_DrawNBG<0, 4, 0, 0, 0, 3>,  },  { T_DrawNBG<0, 4, 0, 0, 1, 0>, T_DrawNBG<0, 4, 0, 0, 1, 1>, T_DrawNBG<0, 4, 0, 0, 1, 2>, T_DrawNBG<0, 4, 0, 0, 1, 3>,  },  { T_DrawNBG<0, 4, 0, 0, 2, 0>, T_DrawNBG<0, 4, 0, 0, 2, 1>, T_DrawNBG<0, 4, 0, 0, 2, 2>, T_DrawNBG<0, 4, 0, 0, 2, 3>,  },  },  {  { T_DrawNBG<0, 4, 0, 1, 0, 0>, T_DrawNBG<0, 4, 0, 1, 0, 1>, T_DrawNBG<0, 4, 0, 1, 0, 2>, T_DrawNBG<0, 4, 0, 1, 0, 3>,  },  { T_DrawNBG<0, 4, 0, 1, 1, 0>, T_DrawNBG<0, 4, 0, 1, 1, 1>, T_DrawNBG<0, 4, 0, 1, 1, 2>, T_DrawNBG<0, 4, 0, 1, 1, 3>,  },  { T_DrawNBG<0, 4, 0, 1, 2, 0>, T_DrawNBG<0, 4, 0, 1, 2, 1>, T_DrawNBG<0, 4, 0, 1, 2, 2>, T_DrawNBG<0, 4, 0, 1, 2, 3>,  },  },  },
  {  {  { T_DrawNBG<0, 8, 0, 0, 0, 0>, T_DrawNBG<0, 8, 0, 0, 0, 1>, T_DrawNBG<0, 8, 0, 0, 0, 2>, T_DrawNBG<0, 8, 0, 0, 0, 3>,  },  { T_DrawNBG<0, 8, 0, 0, 1, 0>, T_DrawNBG<0, 8, 0, 0, 1, 1>, T_DrawNBG<0, 8, 0, 0, 1, 2>, T_DrawNBG<0, 8, 0, 0, 1, 3>,  },  { T_DrawNBG<0, 8, 0, 0, 2, 0>, T_DrawNBG<0, 8, 0, 0, 2, 1>, T_DrawNBG<0, 8, 0, 0, 2, 2>, T_DrawNBG<0, 8, 0, 0, 2, 3>,  },  },  {  { T_DrawNBG<0, 8, 0, 1, 0, 0>, T_DrawNBG<0, 8, 0, 1, 0, 1>, T_DrawNBG<0, 8, 0, 1, 0, 2>, T_DrawNBG<0, 8, 0, 1, 0, 3>,  },  { T_DrawNBG<0, 8, 0, 1, 1, 0>, T_DrawNBG<0, 8, 0, 1, 1, 1>, T_DrawNBG<0, 8, 0, 1, 1, 2>, T_DrawNBG<0, 8, 0, 1, 1, 3>,  },  { T_DrawNBG<0, 8, 0, 1, 2, 0>, T_DrawNBG<0, 8, 0, 1, 2, 1>, T_DrawNBG<0, 8, 0, 1, 2, 2>, T_DrawNBG<0, 8, 0, 1, 2, 3>,  },  },  },
  {  {  { T_DrawNBG<0, 16, 0, 0, 0, 0>, T_DrawNBG<0, 16, 0, 0, 0, 1>, T_DrawNBG<0, 16, 0, 0, 0, 2>, T_DrawNBG<0, 16, 0, 0, 0, 3>,  },  { T_DrawNBG<0, 16, 0, 0, 1, 0>, T_DrawNBG<0, 16, 0, 0, 1, 1>, T_DrawNBG<0, 16, 0, 0, 1, 2>, T_DrawNBG<0, 16, 0, 0, 1, 3>,  },  { T_DrawNBG<0, 16, 0, 0, 2, 0>, T_DrawNBG<0, 16, 0, 0, 2, 1>, T_DrawNBG<0, 16, 0, 0, 2, 2>, T_DrawNBG<0, 16, 0, 0, 2, 3>,  },  },  {  { T_DrawNBG<0, 16, 0, 1, 0, 0>, T_DrawNBG<0, 16, 0, 1, 0, 1>, T_DrawNBG<0, 16, 0, 1, 0, 2>, T_DrawNBG<0, 16, 0, 1, 0, 3>,  },  { T_DrawNBG<0, 16, 0, 1, 1, 0>, T_DrawNBG<0, 16, 0, 1, 1, 1>, T_DrawNBG<0, 16, 0, 1, 1, 2>, T_DrawNBG<0, 16, 0, 1, 1, 3>,  },  { T_DrawNBG<0, 16, 0, 1, 2, 0>, T_DrawNBG<0, 16, 0, 1, 2, 1>, T_DrawNBG<0, 16, 0, 1, 2, 2>, T_DrawNBG<0, 16, 0, 1, 2, 3>,  },  },  },
  {  {  { T_DrawNBG<0, 16, 1, 0, 0, 0>, T_DrawNBG<0, 16, 1, 0, 0, 1>, T_DrawNBG<0, 16, 1, 0, 0, 2>, T_DrawNBG<0, 16, 1, 0, 0, 3>,  },  { T_DrawNBG<0, 16, 1, 0, 1, 0>, T_DrawNBG<0, 16, 1, 0, 1, 1>, T_DrawNBG<0, 16, 1, 0, 1, 2>, T_DrawNBG<0, 16, 1, 0, 1, 3>,  },  { T_DrawNBG<0, 16, 1, 0, 2, 0>, T_DrawNBG<0, 16, 1, 0, 2, 1>, T_DrawNBG<0, 16, 1, 0, 2, 2>, T_DrawNBG<0, 16, 1, 0, 2, 3>,  },  },  {  { T_DrawNBG<0, 16, 1, 1, 0, 0>, T_DrawNBG<0, 16, 1, 1, 0, 1>, T_DrawNBG<0, 16, 1, 1, 0, 2>, T_DrawNBG<0, 16, 1, 1, 0, 3>,  },  { T_DrawNBG<0, 16, 1, 1, 1, 0>, T_DrawNBG<0, 16, 1, 1, 1, 1>, T_DrawNBG<0, 16, 1, 1, 1, 2>, T_DrawNBG<0, 16, 1, 1, 1, 3>,  },  { T_DrawNBG<0, 16, 1, 1, 2, 0>, T_DrawNBG<0, 16, 1, 1, 2, 1>, T_DrawNBG<0, 16, 1, 1, 2, 2>, T_DrawNBG<0, 16, 1, 1, 2, 3>,  },  },  },
  {  {  { T_DrawNBG<0, 32, 1, 0, 0, 0>, T_DrawNBG<0, 32, 1, 0, 0, 1>, T_DrawNBG<0, 32, 1, 0, 0, 2>, T_DrawNBG<0, 32, 1, 0, 0, 3>,  },  { T_DrawNBG<0, 32, 1, 0, 1, 0>, T_DrawNBG<0, 32, 1, 0, 1, 1>, T_DrawNBG<0, 32, 1, 0, 1, 2>, T_DrawNBG<0, 32, 1, 0, 1, 3>,  },  { T_DrawNBG<0, 32, 1, 0, 2, 0>, T_DrawNBG<0, 32, 1, 0, 2, 1>, T_DrawNBG<0, 32, 1, 0, 2, 2>, T_DrawNBG<0, 32, 1, 0, 2, 3>,  },  },  {  { T_DrawNBG<0, 32, 1, 1, 0, 0>, T_DrawNBG<0, 32, 1, 1, 0, 1>, T_DrawNBG<0, 32, 1, 1, 0, 2>, T_DrawNBG<0, 32, 1, 1, 0, 3>,  },  { T_DrawNBG<0, 32, 1, 1, 1, 0>, T_DrawNBG<0, 32, 1, 1, 1, 1>, T_DrawNBG<0, 32, 1, 1, 1, 2>, T_DrawNBG<0, 32, 1, 1, 1, 3>,  },  { T_DrawNBG<0, 32, 1, 1, 2, 0>, T_DrawNBG<0, 32, 1, 1, 2, 1>, T_DrawNBG<0, 32, 1, 1, 2, 2>, T_DrawNBG<0, 32, 1, 1, 2, 3>,  },  },  },
 },
 {
  {  {  { T_DrawNBG<1, 4, 0, 0, 0, 0>, T_DrawNBG<1, 4, 0, 0, 0, 1>, T_DrawNBG<1, 4, 0, 0, 0, 2>, T_DrawNBG<1, 4, 0, 0, 0, 3>,  },  { T_DrawNBG<1, 4, 0, 0, 1, 0>, T_DrawNBG<1, 4, 0, 0, 1, 1>, T_DrawNBG<1, 4, 0, 0, 1, 2>, T_DrawNBG<1, 4, 0, 0, 1, 3>,  },  { T_DrawNBG<1, 4, 0, 0, 2, 0>, T_DrawNBG<1, 4, 0, 0, 2, 1>, T_DrawNBG<1, 4, 0, 0, 2, 2>, T_DrawNBG<1, 4, 0, 0, 2, 3>,  },  },  {  { T_DrawNBG<1, 4, 0, 1, 0, 0>, T_DrawNBG<1, 4, 0, 1, 0, 1>, T_DrawNBG<1, 4, 0, 1, 0, 2>, T_DrawNBG<1, 4, 0, 1, 0, 3>,  },  { T_DrawNBG<1, 4, 0, 1, 1, 0>, T_DrawNBG<1, 4, 0, 1, 1, 1>, T_DrawNBG<1, 4, 0, 1, 1, 2>, T_DrawNBG<1, 4, 0, 1, 1, 3>,  },  { T_DrawNBG<1, 4, 0, 1, 2, 0>, T_DrawNBG<1, 4, 0, 1, 2, 1>, T_DrawNBG<1, 4, 0, 1, 2, 2>, T_DrawNBG<1, 4, 0, 1, 2, 3>,  },  },  },
  {  {  { T_DrawNBG<1, 8, 0, 0, 0, 0>, T_DrawNBG<1, 8, 0, 0, 0, 1>, T_DrawNBG<1, 8, 0, 0, 0, 2>, T_DrawNBG<1, 8, 0, 0, 0, 3>,  },  { T_DrawNBG<1, 8, 0, 0, 1, 0>, T_DrawNBG<1, 8, 0, 0, 1, 1>, T_DrawNBG<1, 8, 0, 0, 1, 2>, T_DrawNBG<1, 8, 0, 0, 1, 3>,  },  { T_DrawNBG<1, 8, 0, 0, 2, 0>, T_DrawNBG<1, 8, 0, 0, 2, 1>, T_DrawNBG<1, 8, 0, 0, 2, 2>, T_DrawNBG<1, 8, 0, 0, 2, 3>,  },  },  {  { T_DrawNBG<1, 8, 0, 1, 0, 0>, T_DrawNBG<1, 8, 0, 1, 0, 1>, T_DrawNBG<1, 8, 0, 1, 0, 2>, T_DrawNBG<1, 8, 0, 1, 0, 3>,  },  { T_DrawNBG<1, 8, 0, 1, 1, 0>, T_DrawNBG<1, 8, 0, 1, 1, 1>, T_DrawNBG<1, 8, 0, 1, 1, 2>, T_DrawNBG<1, 8, 0, 1, 1, 3>,  },  { T_DrawNBG<1, 8, 0, 1, 2, 0>, T_DrawNBG<1, 8, 0, 1, 2, 1>, T_DrawNBG<1, 8, 0, 1, 2, 2>, T_DrawNBG<1, 8, 0, 1, 2, 3>,  },  },  },
  {  {  { T_DrawNBG<1, 16, 0, 0, 0, 0>, T_DrawNBG<1, 16, 0, 0, 0, 1>, T_DrawNBG<1, 16, 0, 0, 0, 2>, T_DrawNBG<1, 16, 0, 0, 0, 3>,  },  { T_DrawNBG<1, 16, 0, 0, 1, 0>, T_DrawNBG<1, 16, 0, 0, 1, 1>, T_DrawNBG<1, 16, 0, 0, 1, 2>, T_DrawNBG<1, 16, 0, 0, 1, 3>,  },  { T_DrawNBG<1, 16, 0, 0, 2, 0>, T_DrawNBG<1, 16, 0, 0, 2, 1>, T_DrawNBG<1, 16, 0, 0, 2, 2>, T_DrawNBG<1, 16, 0, 0, 2, 3>,  },  },  {  { T_DrawNBG<1, 16, 0, 1, 0, 0>, T_DrawNBG<1, 16, 0, 1, 0, 1>, T_DrawNBG<1, 16, 0, 1, 0, 2>, T_DrawNBG<1, 16, 0, 1, 0, 3>,  },  { T_DrawNBG<1, 16, 0, 1, 1, 0>, T_DrawNBG<1, 16, 0, 1, 1, 1>, T_DrawNBG<1, 16, 0, 1, 1, 2>, T_DrawNBG<1, 16, 0, 1, 1, 3>,  },  { T_DrawNBG<1, 16, 0, 1, 2, 0>, T_DrawNBG<1, 16, 0, 1, 2, 1>, T_DrawNBG<1, 16, 0, 1, 2, 2>, T_DrawNBG<1, 16, 0, 1, 2, 3>,  },  },  },
  {  {  { T_DrawNBG<1, 16, 1, 0, 0, 0>, T_DrawNBG<1, 16, 1, 0, 0, 1>, T_DrawNBG<1, 16, 1, 0, 0, 2>, T_DrawNBG<1, 16, 1, 0, 0, 3>,  },  { T_DrawNBG<1, 16, 1, 0, 1, 0>, T_DrawNBG<1, 16, 1, 0, 1, 1>, T_DrawNBG<1, 16, 1, 0, 1, 2>, T_DrawNBG<1, 16, 1, 0, 1, 3>,  },  { T_DrawNBG<1, 16, 1, 0, 2, 0>, T_DrawNBG<1, 16, 1, 0, 2, 1>, T_DrawNBG<1, 16, 1, 0, 2, 2>, T_DrawNBG<1, 16, 1, 0, 2, 3>,  },  },  {  { T_DrawNBG<1, 16, 1, 1, 0, 0>, T_DrawNBG<1, 16, 1, 1, 0, 1>, T_DrawNBG<1, 16, 1, 1, 0, 2>, T_DrawNBG<1, 16, 1, 1, 0, 3>,  },  { T_DrawNBG<1, 16, 1, 1, 1, 0>, T_DrawNBG<1, 16, 1, 1, 1, 1>, T_DrawNBG<1, 16, 1, 1, 1, 2>, T_DrawNBG<1, 16, 1, 1, 1, 3>,  },  { T_DrawNBG<1, 16, 1, 1, 2, 0>, T_DrawNBG<1, 16, 1, 1, 2, 1>, T_DrawNBG<1, 16, 1, 1, 2, 2>, T_DrawNBG<1, 16, 1, 1, 2, 3>,  },  },  },
  {  {  { T_DrawNBG<1, 32, 1, 0, 0, 0>, T_DrawNBG<1, 32, 1, 0, 0, 1>, T_DrawNBG<1, 32, 1, 0, 0, 2>, T_DrawNBG<1, 32, 1, 0, 0, 3>,  },  { T_DrawNBG<1, 32, 1, 0, 1, 0>, T_DrawNBG<1, 32, 1, 0, 1, 1>, T_DrawNBG<1, 32, 1, 0, 1, 2>, T_DrawNBG<1, 32, 1, 0, 1, 3>,  },  { T_DrawNBG<1, 32, 1, 0, 2, 0>, T_DrawNBG<1, 32, 1, 0, 2, 1>, T_DrawNBG<1, 32, 1, 0, 2, 2>, T_DrawNBG<1, 32, 1, 0, 2, 3>,  },  },  {  { T_DrawNBG<1, 32, 1, 1, 0, 0>, T_DrawNBG<1, 32, 1, 1, 0, 1>, T_DrawNBG<1, 32, 1, 1, 0, 2>, T_DrawNBG<1, 32, 1, 1, 0, 3>,  },  { T_DrawNBG<1, 32, 1, 1, 1, 0>, T_DrawNBG<1, 32, 1, 1, 1, 1>, T_DrawNBG<1, 32, 1, 1, 1, 2>, T_DrawNBG<1, 32, 1, 1, 1, 3>,  },  { T_DrawNBG<1, 32, 1, 1, 2, 0>, T_DrawNBG<1, 32, 1, 1, 2, 1>, T_DrawNBG<1, 32, 1, 1, 2, 2>, T_DrawNBG<1, 32, 1, 1, 2, 3>,  },  },  },
 }
};

template<bool TA_igntp, unsigned TA_PrioMode, unsigned TA_CCMode>
static INLINE uint64 MakeNBG23Pix(uint32 dcc, uint32 pbor, const int16* sfcode_lut, uint32 colcacheoffs)
{
 uint32 rgb24;

 rgb24 = ColorCache[(colcacheoffs + dcc) & 2047];

 if(TA_CCMode == 3)
  pbor |= ((int32)rgb24 >> 31) & (1 << PIX_CCE_SHIFT);

 if(TA_PrioMode == 2 || TA_CCMode == 2)
  pbor &= *(const int16*)((const uint8*)sfcode_lut + (dcc & 0xE));

 if(!TA_igntp && !dcc)
  pbor = 0;

 return pbor + ((uint64)rgb24 << PIX_RGB_SHIFT);
}

//
// CCMode will be forced to 0 in the effective instantiation if corresponding NBG CCE bit in CCCTL is 0.
//
template<unsigned TA_bpp, bool TA_igntp, unsigned TA_PrioMode, unsigned TA_CCMode>
static void T_DrawNBG23(const unsigned n, uint64* bgbuf, const unsigned w, const uint32 pix_base_or)
{
 assert(n >= 2);
 TileFetcher<false> tf;
 int16 sfcode_lut[8];
 unsigned tc = 1 + (w >> 3);
 const unsigned xscr = XScrollI[n];
 const unsigned yscr = MosEff_NBG23_YCounter[n & 1];
 unsigned tx;

 tf.CRAOffs = CRAMAddrOffs_NBG[n] << 8;
 //
 tf.PlaneSize = (PLSZ >> (n << 1)) & 0x3;
 tf.PNDSize = (PNCN[n] >> 15) & 1;	// 0 = 2 words, 1 = 1 word
 tf.CharSize = ((CHCTLB >> (0 + ((n & 1) << 2))) & 1);
 tf.AuxMode = (PNCN[n] >> 14) & 1;
 tf.Supp = (PNCN[n] & 0x3FF); // Supplement bits when PNDSize == 1
 //
 tf.Start(n, false, (MPOFN >> (n << 2)) & 0x7, MapRegs[n]);

 MakeSFCodeLUT<TA_PrioMode, TA_CCMode>(n, sfcode_lut);

 bgbuf -= xscr & 0x7;
 tx = xscr >> 3;

 //
 // Layer offset kludges
 //
 // Note: When/If adding new kludges, check that the NT and CG fetches for the layer each occur only in one bank, to safely handle other cases may require something more complex.
 // printf("(TA_bpp == %d && n == %d && VRAM_Mode == 0x%01x && (HRes & 0x6) == 0x%01x && MDFN_de64lsb(VCPRegs[0]) == 0x%016llxULL && MDFN_de64lsb(VCPRegs[1]) == 0x%016llxULL && MDFN_de64lsb(VCPRegs[2]) == 0x%016llxULL && MDFN_de64lsb(VCPRegs[3]) == 0x%016llxULL) || \n", TA_bpp, n, VRAM_Mode, HRes & 0x6, (unsigned long long)MDFN_de64lsb(VCPRegs[0]), (unsigned long long)MDFN_de64lsb(VCPRegs[1]), (unsigned long long)MDFN_de64lsb(VCPRegs[2]), (unsigned long long)MDFN_de64lsb(VCPRegs[3]));
 if(MDFN_UNLIKELY(
  /* Akumajou Dracula X */ (TA_bpp == 4 && n == 3 && VRAM_Mode == 0x2 && (HRes & 0x6) == 0x0 && MDFN_de64lsb(VCPRegs[0]) == 0x0f0f070406060505ULL && MDFN_de64lsb(VCPRegs[1]) == 0x0f0f0f0f0f0f0f0fULL && MDFN_de64lsb(VCPRegs[2]) == 0x0f0f03000f0f0201ULL && MDFN_de64lsb(VCPRegs[3]) == 0x0f0f0f0f0f0f0f0fULL) ||
  /* Daytona USA CCE    */ (TA_bpp == 4 && n == 2 && VRAM_Mode == 0x3 && (HRes & 0x6) == 0x0 && MDFN_de64lsb(VCPRegs[0]) == 0x0f0f0f0f00000404ULL && MDFN_de64lsb(VCPRegs[1]) == 0x0f0f0f060f0f0f0fULL && MDFN_de64lsb(VCPRegs[2]) == 0x0f0f0f0f0505070fULL && MDFN_de64lsb(VCPRegs[3]) == 0x0f0f03020f010f00ULL) ||
  0))
 {
  for(unsigned i = 0; i < 8; i++)
   *bgbuf++ = 0;
  tc--;
 }

 while(MDFN_LIKELY(tc--))
 {
  uint32 pbor = pix_base_or;

  tf.Fetch<TA_bpp>(false, tx << 3, yscr);

  if(TA_CCMode == 1 || TA_CCMode == 2)
   pbor |= (tf.scc << PIX_CCE_SHIFT);

  if(TA_PrioMode == 1 || TA_PrioMode == 2)
   pbor |= (tf.spr << PIX_PRIO_SHIFT);
  //
  //
  auto* const mbp = MakeNBG23Pix<TA_igntp, TA_PrioMode, TA_CCMode>;

  if(TA_bpp == 8)
  {
   if(tf.cellx_xor & 0x7)
   {
    bgbuf[7] = mbp((uint8)(tf.tile_vrb[0] >>  8), /**/pbor, sfcode_lut, tf.pcco);
    bgbuf[6] = mbp((uint8)(tf.tile_vrb[0] >>  0), /**/pbor, sfcode_lut, tf.pcco);
    bgbuf[5] = mbp((uint8)(tf.tile_vrb[1] >>  8), /**/pbor, sfcode_lut, tf.pcco);
    bgbuf[4] = mbp((uint8)(tf.tile_vrb[1] >>  0), /**/pbor, sfcode_lut, tf.pcco);
    bgbuf[3] = mbp((uint8)(tf.tile_vrb[2] >>  8), /**/pbor, sfcode_lut, tf.pcco);
    bgbuf[2] = mbp((uint8)(tf.tile_vrb[2] >>  0), /**/pbor, sfcode_lut, tf.pcco);
    bgbuf[1] = mbp((uint8)(tf.tile_vrb[3] >>  8), /**/pbor, sfcode_lut, tf.pcco);
    bgbuf[0] = mbp((uint8)(tf.tile_vrb[3] >>  0), /**/pbor, sfcode_lut, tf.pcco);
   }
   else
   {
    bgbuf[0] = mbp((uint8)(tf.tile_vrb[0] >>  8), /**/pbor, sfcode_lut, tf.pcco);
    bgbuf[1] = mbp((uint8)(tf.tile_vrb[0] >>  0), /**/pbor, sfcode_lut, tf.pcco);
    bgbuf[2] = mbp((uint8)(tf.tile_vrb[1] >>  8), /**/pbor, sfcode_lut, tf.pcco);
    bgbuf[3] = mbp((uint8)(tf.tile_vrb[1] >>  0), /**/pbor, sfcode_lut, tf.pcco);
    bgbuf[4] = mbp((uint8)(tf.tile_vrb[2] >>  8), /**/pbor, sfcode_lut, tf.pcco);
    bgbuf[5] = mbp((uint8)(tf.tile_vrb[2] >>  0), /**/pbor, sfcode_lut, tf.pcco);
    bgbuf[6] = mbp((uint8)(tf.tile_vrb[3] >>  8), /**/pbor, sfcode_lut, tf.pcco);
    bgbuf[7] = mbp((uint8)(tf.tile_vrb[3] >>  0), /**/pbor, sfcode_lut, tf.pcco);
   }
  }
  else
  {
   if(tf.cellx_xor & 0x7)
   {
    bgbuf[7] = mbp((tf.tile_vrb[0] >>  12),       /**/pbor, sfcode_lut, tf.pcco);
    bgbuf[6] = mbp((tf.tile_vrb[0] >>   8) & 0xF, /**/pbor, sfcode_lut, tf.pcco);
    bgbuf[5] = mbp((tf.tile_vrb[0] >>   4) & 0xF, /**/pbor, sfcode_lut, tf.pcco);
    bgbuf[4] = mbp((tf.tile_vrb[0] >>   0) & 0xF, /**/pbor, sfcode_lut, tf.pcco);
    bgbuf[3] = mbp((tf.tile_vrb[1] >>  12),       /**/pbor, sfcode_lut, tf.pcco);
    bgbuf[2] = mbp((tf.tile_vrb[1] >>   8) & 0xF, /**/pbor, sfcode_lut, tf.pcco);
    bgbuf[1] = mbp((tf.tile_vrb[1] >>   4) & 0xF, /**/pbor, sfcode_lut, tf.pcco);
    bgbuf[0] = mbp((tf.tile_vrb[1] >>   0) & 0xF, /**/pbor, sfcode_lut, tf.pcco);
   }
   else
   {
    bgbuf[0] = mbp((tf.tile_vrb[0] >>  12),       /**/pbor, sfcode_lut, tf.pcco);
    bgbuf[1] = mbp((tf.tile_vrb[0] >>   8) & 0xF, /**/pbor, sfcode_lut, tf.pcco);
    bgbuf[2] = mbp((tf.tile_vrb[0] >>   4) & 0xF, /**/pbor, sfcode_lut, tf.pcco);
    bgbuf[3] = mbp((tf.tile_vrb[0] >>   0) & 0xF, /**/pbor, sfcode_lut, tf.pcco);
    bgbuf[4] = mbp((tf.tile_vrb[1] >>  12),       /**/pbor, sfcode_lut, tf.pcco);
    bgbuf[5] = mbp((tf.tile_vrb[1] >>   8) & 0xF, /**/pbor, sfcode_lut, tf.pcco);
    bgbuf[6] = mbp((tf.tile_vrb[1] >>   4) & 0xF, /**/pbor, sfcode_lut, tf.pcco);
    bgbuf[7] = mbp((tf.tile_vrb[1] >>   0) & 0xF, /**/pbor, sfcode_lut, tf.pcco);
   }
  }

  //
  //
  //
  tx++;
  bgbuf += 8;
 }
}

static void (*DrawNBG23[2/*col mode*/][2/*igntp*/][3/*priomode*/][4/*ccmode*/])(const unsigned n, uint64* bgbuf, const unsigned w, const uint32 pix_base_or) =
{
 {
  {    { T_DrawNBG23<4, 0, 0, 0>, T_DrawNBG23<4, 0, 0, 1>, T_DrawNBG23<4, 0, 0, 2>, T_DrawNBG23<4, 0, 0, 3>, },    { T_DrawNBG23<4, 0, 1, 0>, T_DrawNBG23<4, 0, 1, 1>, T_DrawNBG23<4, 0, 1, 2>, T_DrawNBG23<4, 0, 1, 3>, },    { T_DrawNBG23<4, 0, 2, 0>, T_DrawNBG23<4, 0, 2, 1>, T_DrawNBG23<4, 0, 2, 2>, T_DrawNBG23<4, 0, 2, 3>, }, },
  {    { T_DrawNBG23<4, 1, 0, 0>, T_DrawNBG23<4, 1, 0, 1>, T_DrawNBG23<4, 1, 0, 2>, T_DrawNBG23<4, 1, 0, 3>, },    { T_DrawNBG23<4, 1, 1, 0>, T_DrawNBG23<4, 1, 1, 1>, T_DrawNBG23<4, 1, 1, 2>, T_DrawNBG23<4, 1, 1, 3>, },    { T_DrawNBG23<4, 1, 2, 0>, T_DrawNBG23<4, 1, 2, 1>, T_DrawNBG23<4, 1, 2, 2>, T_DrawNBG23<4, 1, 2, 3>, }, },
 },
 {
  {    { T_DrawNBG23<8, 0, 0, 0>, T_DrawNBG23<8, 0, 0, 1>, T_DrawNBG23<8, 0, 0, 2>, T_DrawNBG23<8, 0, 0, 3>, },    { T_DrawNBG23<8, 0, 1, 0>, T_DrawNBG23<8, 0, 1, 1>, T_DrawNBG23<8, 0, 1, 2>, T_DrawNBG23<8, 0, 1, 3>, },    { T_DrawNBG23<8, 0, 2, 0>, T_DrawNBG23<8, 0, 2, 1>, T_DrawNBG23<8, 0, 2, 2>, T_DrawNBG23<8, 0, 2, 3>, }, },
  {    { T_DrawNBG23<8, 1, 0, 0>, T_DrawNBG23<8, 1, 0, 1>, T_DrawNBG23<8, 1, 0, 2>, T_DrawNBG23<8, 1, 0, 3>, },    { T_DrawNBG23<8, 1, 1, 0>, T_DrawNBG23<8, 1, 1, 1>, T_DrawNBG23<8, 1, 1, 2>, T_DrawNBG23<8, 1, 1, 3>, },    { T_DrawNBG23<8, 1, 2, 0>, T_DrawNBG23<8, 1, 2, 1>, T_DrawNBG23<8, 1, 2, 2>, T_DrawNBG23<8, 1, 2, 3>, }, },
 },
};

static INLINE uint32 GetCoeffAddr(const unsigned i, uint32 offset)
{
 const uint32 src_mask = (CRKTE ? 0x3FF : 0x3FFFF);

 offset >>= 10;
 offset <<= !(KTCTL[i] & 0x2);
 offset &= src_mask;

 return offset;
}

static INLINE uint32 ReadCoeff(const unsigned i, const uint32 addr)
{
 const uint16* src = (CRKTE ? &CRAM[0x400] : VRAM);
 uint32 coeff;

 if(KTCTL[i] & 0x2)
 {
  const uint16 tmp = src[addr];
  coeff = (sign_x_to_s32(21, tmp << 6) & 0x00FFFFFF) | ((tmp & 0x8000) << 16);
  //printf("%d Coeff %08x, %04x -- %08x\n", i, offset, tmp, coeff);
 }
 else
 {
  const uint16* ea = &src[addr];
  coeff = (ea[0] << 16) | ea[1];
 }

 return coeff;
}

// Coefficient table reading can (temporarily) override kx, ky, and/or Xp
//
// When RBG1 is enabled, line color screen uses rotation parameter A coefficient table
//
// RBG1 always uses MSB of coefficient data as transparent bit.
//
// RBG1 requires RPMD == 0, or else bad things happen?

template<typename T>
static void SetupRotVars(const T* rs, const unsigned rbg_w)
{
 const uint8 EffRPMD = ((BGON & 0x20) ? 0 : RPMD);

 if(EffRPMD < 2)
 {
  for(unsigned x = 0; MDFN_LIKELY(x < rbg_w); x++)
   LB.rotabsel[x] = RPMD;
 }
 else if(EffRPMD == 3)
  GetWinRotAB();

 //
 //
 //

 for(unsigned i = 0; i < 2; i++)
 {
  auto& r = LB.rotv[i];

  r.Xsp = rs[i].Xsp;
  r.Ysp = rs[i].Ysp;
  r.Xp = rs[i].Xp;
  r.Yp = rs[i].Yp;
  r.dX = rs[i].dX;
  r.dY = rs[i].dY;
  r.kx = rs[i].kx;
  r.ky = rs[i].ky;

  LB.rotv[i].tf.BMSCC = ((BMPNB >> 4) & 1);
  LB.rotv[i].tf.BMSPR = ((BMPNB >> 5) & 1);
  LB.rotv[i].tf.BMPalNo = ((BMPNB >> 0) & 0x7) << 4;
  LB.rotv[i].tf.BMSize = ((CHCTLB >> 10) & 0x1);

  //
  //
  //
  //
  //
  //
  if((BGON & 0x20) && i)
  {
   LB.rotv[1].tf.CRAOffs = CRAMAddrOffs_NBG[0] << 8;
   LB.rotv[1].tf.PNDSize = (PNCN[0] >> 15) & 1;
   LB.rotv[1].tf.CharSize = ((CHCTLA >> 0) & 1);
   LB.rotv[1].tf.AuxMode = (PNCN[0] >> 14) & 1;
   LB.rotv[1].tf.Supp = (PNCN[0] & 0x3FF);
  }
  else
  {
   LB.rotv[i].tf.CRAOffs = CRAMAddrOffs_RBG0 << 8;
   LB.rotv[i].tf.PNDSize = (PNCNR >> 15) & 1;
   LB.rotv[i].tf.CharSize = ((CHCTLB >> 8) & 1);
   LB.rotv[i].tf.AuxMode = (PNCNR >> 14) & 1;
   LB.rotv[i].tf.Supp = (PNCNR & 0x3FF);
  }
  LB.rotv[i].tf.PlaneSize = (PLSZ >> ( 8 + (i << 2))) & 0x3;
  LB.rotv[i].tf.PlaneOver = (PLSZ >> (10 + (i << 2))) & 0x3;
  LB.rotv[i].tf.PlaneOverChar = OVPNR[i];
  LB.rotv[i].tf.Start(4 + i, !i && ((CHCTLB >> 9) & 1), (MPOFR >> (i << 2)) & 0x7, RotMapRegs[i]);
 }

 //
 //
 //
 {
  bool bank_tab[4];

  for(unsigned i = 0; i < 4; i++)
   bank_tab[i] = ((RDBS_Mode >> (i << 1)) & 0x3) == RDBS_COEFF;
  //
  if(!(VRAM_Mode & 0x1))
   bank_tab[1] = bank_tab[0];

  if(!(VRAM_Mode & 0x2))
   bank_tab[3] = bank_tab[2];

  if(BGON & 0x20)
   bank_tab[2] = bank_tab[3] = false;
  //
  if(CRKTE)
   bank_tab[0] = bank_tab[1] = bank_tab[2] = bank_tab[3] = true;
  //
  //
  LB.rotv[0].use_coeff = (bool)(KTCTL[0] & 0x1);
  LB.rotv[1].use_coeff = (bool)(KTCTL[1] & 0x1);

  uint32 coeff[2];

  for(unsigned i = 0; i < 2; i++)
   LB.rotv[i].base_coeff = coeff[i] = ReadCoeff(i, GetCoeffAddr(i, rs[i].KAstAccum));

  //if(grumpus == 120)
  // printf("BankTab: %d %d %d %d, UC: %d %d, Coeff: @0x%05x=0x%08x @0x%05x=0x%08x, DKAx: %f %f\n", bank_tab[0], bank_tab[1], bank_tab[2], bank_tab[3], LB.rotv[0].use_coeff, LB.rotv[1].use_coeff, GetCoeffAddr(0, rs[0].KAstAccum), coeff[0], GetCoeffAddr(1, rs[1].KAstAccum), coeff[1], rs[0].DKAx / 1024.0, rs[1].DKAx / 1024.0);

  for(unsigned x = 0; MDFN_LIKELY(x < rbg_w); x++)
  {
   const unsigned i = ((EffRPMD == 2) ? 0 : LB.rotabsel[x]);
   const uint32 addr = GetCoeffAddr(i, rs[i].KAstAccum + (x * rs[i].DKAx));

   if(bank_tab[addr >> 16])
    coeff[i] = ReadCoeff(i, addr);

   if(KTCTL[i] & 0x10)
    LB.lc[x] = (coeff[i] >> 24) & 0x7F;

   if(EffRPMD == 2)
   {
    uint32 tmp = coeff[0];

    LB.rotabsel[x] = tmp >> 31;

    if((int32)tmp < 0)
     tmp = coeff[1];

    LB.rotcoeff[x] = tmp;
   }
   else
    LB.rotcoeff[x] = coeff[i];
  }
 }
}

// const bool TA_bmen = ((rn == 1) ? false : ((CHCTLB >> 9) & 1));
template<bool TA_bmen, unsigned TA_bpp, bool TA_isrgb, bool TA_igntp, unsigned TA_PrioMode, unsigned TA_CCMode>
static void T_DrawRBG(const bool rn, uint64* bgbuf, const unsigned w, const uint32 pix_base_or)
{
 // Full color format selection for both RBG0 and RBG1
 // Bitmap only allowed for RBG0
 // RBG0 can use rot param A and B, RBG1 is fixed to rot param B
 // RBG1 shares setting bitfields with NBG0
 // 16 planes instead of 4 like with NBG*
 // Mosaic only has effect in the horizontal direction?
 //
 int16 sfcode_lut[8];

 MakeSFCodeLUT<TA_PrioMode, TA_CCMode>((rn ? 0 : 4), sfcode_lut);

 for(unsigned i = 0; MDFN_LIKELY(i < w); i++)
 {
  const unsigned ab = LB.rotabsel[i];
  auto& r = LB.rotv[ab];
  auto& tf = r.tf;
  uint32 Xp = r.Xp;
  int32 kx = r.kx;
  int32 ky = r.ky;
  bool rot_tp = false;

  if(r.use_coeff)
  {
   const uint32 coeff = (rn ? r.base_coeff : LB.rotcoeff[i]);

   rot_tp = ((int32)coeff < 0);

   const uint32 sext = sign_x_to_s32(24, coeff);
 
   switch((KTCTL[ab] >> 2) & 0x3)
   {
    case 0: kx = ky = sext; break;
    case 1: kx = sext; break;
    case 2: ky = sext; break;
    case 3: Xp = sext << 2; break;
   }
  }

  const uint32 ix = (  Xp + (uint32)(((int64)kx * (int32)(r.Xsp + (r.dX * i))) >> 16)) >> 10;
  const uint32 iy = (r.Yp + (uint32)(((int64)ky * (int32)(r.Ysp + (r.dY * i))) >> 16)) >> 10;

  rot_tp |= tf.Fetch<TA_bpp>(TA_bmen, ix, iy);

  LB.rotabsel[i] = rot_tp;
  //
  //
  //
  bgbuf[i] = MakeNBGRBGPix<TA_bmen, TA_bpp, TA_isrgb, TA_igntp, TA_PrioMode, TA_CCMode>(tf, pix_base_or, sfcode_lut, ix, iy);
 }
}

//template<unsigned TA_bpp, bool TA_isrgb, bool TA_igntp, unsigned TA_PrioMode, unsigned TA_CCMode>
static void (*DrawRBG[2 /*bitmap enable*/][5/*col mode*/][2/*igntp*/][3/*priomode*/][4/*ccmode*/])(const bool rn, uint64* bgbuf, const unsigned w, const uint32 pix_base_or) =
{
 {
  {  {  { T_DrawRBG<0, 4, 0, 0, 0, 0>, T_DrawRBG<0, 4, 0, 0, 0, 1>, T_DrawRBG<0, 4, 0, 0, 0, 2>, T_DrawRBG<0, 4, 0, 0, 0, 3>,  },  { T_DrawRBG<0, 4, 0, 0, 1, 0>, T_DrawRBG<0, 4, 0, 0, 1, 1>, T_DrawRBG<0, 4, 0, 0, 1, 2>, T_DrawRBG<0, 4, 0, 0, 1, 3>,  },  { T_DrawRBG<0, 4, 0, 0, 2, 0>, T_DrawRBG<0, 4, 0, 0, 2, 1>, T_DrawRBG<0, 4, 0, 0, 2, 2>, T_DrawRBG<0, 4, 0, 0, 2, 3>,  },  },  {  { T_DrawRBG<0, 4, 0, 1, 0, 0>, T_DrawRBG<0, 4, 0, 1, 0, 1>, T_DrawRBG<0, 4, 0, 1, 0, 2>, T_DrawRBG<0, 4, 0, 1, 0, 3>,  },  { T_DrawRBG<0, 4, 0, 1, 1, 0>, T_DrawRBG<0, 4, 0, 1, 1, 1>, T_DrawRBG<0, 4, 0, 1, 1, 2>, T_DrawRBG<0, 4, 0, 1, 1, 3>,  },  { T_DrawRBG<0, 4, 0, 1, 2, 0>, T_DrawRBG<0, 4, 0, 1, 2, 1>, T_DrawRBG<0, 4, 0, 1, 2, 2>, T_DrawRBG<0, 4, 0, 1, 2, 3>,  },  },  },
  {  {  { T_DrawRBG<0, 8, 0, 0, 0, 0>, T_DrawRBG<0, 8, 0, 0, 0, 1>, T_DrawRBG<0, 8, 0, 0, 0, 2>, T_DrawRBG<0, 8, 0, 0, 0, 3>,  },  { T_DrawRBG<0, 8, 0, 0, 1, 0>, T_DrawRBG<0, 8, 0, 0, 1, 1>, T_DrawRBG<0, 8, 0, 0, 1, 2>, T_DrawRBG<0, 8, 0, 0, 1, 3>,  },  { T_DrawRBG<0, 8, 0, 0, 2, 0>, T_DrawRBG<0, 8, 0, 0, 2, 1>, T_DrawRBG<0, 8, 0, 0, 2, 2>, T_DrawRBG<0, 8, 0, 0, 2, 3>,  },  },  {  { T_DrawRBG<0, 8, 0, 1, 0, 0>, T_DrawRBG<0, 8, 0, 1, 0, 1>, T_DrawRBG<0, 8, 0, 1, 0, 2>, T_DrawRBG<0, 8, 0, 1, 0, 3>,  },  { T_DrawRBG<0, 8, 0, 1, 1, 0>, T_DrawRBG<0, 8, 0, 1, 1, 1>, T_DrawRBG<0, 8, 0, 1, 1, 2>, T_DrawRBG<0, 8, 0, 1, 1, 3>,  },  { T_DrawRBG<0, 8, 0, 1, 2, 0>, T_DrawRBG<0, 8, 0, 1, 2, 1>, T_DrawRBG<0, 8, 0, 1, 2, 2>, T_DrawRBG<0, 8, 0, 1, 2, 3>,  },  },  },
  {  {  { T_DrawRBG<0, 16, 0, 0, 0, 0>, T_DrawRBG<0, 16, 0, 0, 0, 1>, T_DrawRBG<0, 16, 0, 0, 0, 2>, T_DrawRBG<0, 16, 0, 0, 0, 3>,  },  { T_DrawRBG<0, 16, 0, 0, 1, 0>, T_DrawRBG<0, 16, 0, 0, 1, 1>, T_DrawRBG<0, 16, 0, 0, 1, 2>, T_DrawRBG<0, 16, 0, 0, 1, 3>,  },  { T_DrawRBG<0, 16, 0, 0, 2, 0>, T_DrawRBG<0, 16, 0, 0, 2, 1>, T_DrawRBG<0, 16, 0, 0, 2, 2>, T_DrawRBG<0, 16, 0, 0, 2, 3>,  },  },  {  { T_DrawRBG<0, 16, 0, 1, 0, 0>, T_DrawRBG<0, 16, 0, 1, 0, 1>, T_DrawRBG<0, 16, 0, 1, 0, 2>, T_DrawRBG<0, 16, 0, 1, 0, 3>,  },  { T_DrawRBG<0, 16, 0, 1, 1, 0>, T_DrawRBG<0, 16, 0, 1, 1, 1>, T_DrawRBG<0, 16, 0, 1, 1, 2>, T_DrawRBG<0, 16, 0, 1, 1, 3>,  },  { T_DrawRBG<0, 16, 0, 1, 2, 0>, T_DrawRBG<0, 16, 0, 1, 2, 1>, T_DrawRBG<0, 16, 0, 1, 2, 2>, T_DrawRBG<0, 16, 0, 1, 2, 3>,  },  },  },
  {  {  { T_DrawRBG<0, 16, 1, 0, 0, 0>, T_DrawRBG<0, 16, 1, 0, 0, 1>, T_DrawRBG<0, 16, 1, 0, 0, 2>, T_DrawRBG<0, 16, 1, 0, 0, 3>,  },  { T_DrawRBG<0, 16, 1, 0, 1, 0>, T_DrawRBG<0, 16, 1, 0, 1, 1>, T_DrawRBG<0, 16, 1, 0, 1, 2>, T_DrawRBG<0, 16, 1, 0, 1, 3>,  },  { T_DrawRBG<0, 16, 1, 0, 2, 0>, T_DrawRBG<0, 16, 1, 0, 2, 1>, T_DrawRBG<0, 16, 1, 0, 2, 2>, T_DrawRBG<0, 16, 1, 0, 2, 3>,  },  },  {  { T_DrawRBG<0, 16, 1, 1, 0, 0>, T_DrawRBG<0, 16, 1, 1, 0, 1>, T_DrawRBG<0, 16, 1, 1, 0, 2>, T_DrawRBG<0, 16, 1, 1, 0, 3>,  },  { T_DrawRBG<0, 16, 1, 1, 1, 0>, T_DrawRBG<0, 16, 1, 1, 1, 1>, T_DrawRBG<0, 16, 1, 1, 1, 2>, T_DrawRBG<0, 16, 1, 1, 1, 3>,  },  { T_DrawRBG<0, 16, 1, 1, 2, 0>, T_DrawRBG<0, 16, 1, 1, 2, 1>, T_DrawRBG<0, 16, 1, 1, 2, 2>, T_DrawRBG<0, 16, 1, 1, 2, 3>,  },  },  },
  {  {  { T_DrawRBG<0, 32, 1, 0, 0, 0>, T_DrawRBG<0, 32, 1, 0, 0, 1>, T_DrawRBG<0, 32, 1, 0, 0, 2>, T_DrawRBG<0, 32, 1, 0, 0, 3>,  },  { T_DrawRBG<0, 32, 1, 0, 1, 0>, T_DrawRBG<0, 32, 1, 0, 1, 1>, T_DrawRBG<0, 32, 1, 0, 1, 2>, T_DrawRBG<0, 32, 1, 0, 1, 3>,  },  { T_DrawRBG<0, 32, 1, 0, 2, 0>, T_DrawRBG<0, 32, 1, 0, 2, 1>, T_DrawRBG<0, 32, 1, 0, 2, 2>, T_DrawRBG<0, 32, 1, 0, 2, 3>,  },  },  {  { T_DrawRBG<0, 32, 1, 1, 0, 0>, T_DrawRBG<0, 32, 1, 1, 0, 1>, T_DrawRBG<0, 32, 1, 1, 0, 2>, T_DrawRBG<0, 32, 1, 1, 0, 3>,  },  { T_DrawRBG<0, 32, 1, 1, 1, 0>, T_DrawRBG<0, 32, 1, 1, 1, 1>, T_DrawRBG<0, 32, 1, 1, 1, 2>, T_DrawRBG<0, 32, 1, 1, 1, 3>,  },  { T_DrawRBG<0, 32, 1, 1, 2, 0>, T_DrawRBG<0, 32, 1, 1, 2, 1>, T_DrawRBG<0, 32, 1, 1, 2, 2>, T_DrawRBG<0, 32, 1, 1, 2, 3>,  },  },  },
 },
 {
  {  {  { T_DrawRBG<1, 4, 0, 0, 0, 0>, T_DrawRBG<1, 4, 0, 0, 0, 1>, T_DrawRBG<1, 4, 0, 0, 0, 2>, T_DrawRBG<1, 4, 0, 0, 0, 3>,  },  { T_DrawRBG<1, 4, 0, 0, 1, 0>, T_DrawRBG<1, 4, 0, 0, 1, 1>, T_DrawRBG<1, 4, 0, 0, 1, 2>, T_DrawRBG<1, 4, 0, 0, 1, 3>,  },  { T_DrawRBG<1, 4, 0, 0, 2, 0>, T_DrawRBG<1, 4, 0, 0, 2, 1>, T_DrawRBG<1, 4, 0, 0, 2, 2>, T_DrawRBG<1, 4, 0, 0, 2, 3>,  },  },  {  { T_DrawRBG<1, 4, 0, 1, 0, 0>, T_DrawRBG<1, 4, 0, 1, 0, 1>, T_DrawRBG<1, 4, 0, 1, 0, 2>, T_DrawRBG<1, 4, 0, 1, 0, 3>,  },  { T_DrawRBG<1, 4, 0, 1, 1, 0>, T_DrawRBG<1, 4, 0, 1, 1, 1>, T_DrawRBG<1, 4, 0, 1, 1, 2>, T_DrawRBG<1, 4, 0, 1, 1, 3>,  },  { T_DrawRBG<1, 4, 0, 1, 2, 0>, T_DrawRBG<1, 4, 0, 1, 2, 1>, T_DrawRBG<1, 4, 0, 1, 2, 2>, T_DrawRBG<1, 4, 0, 1, 2, 3>,  },  },  },
  {  {  { T_DrawRBG<1, 8, 0, 0, 0, 0>, T_DrawRBG<1, 8, 0, 0, 0, 1>, T_DrawRBG<1, 8, 0, 0, 0, 2>, T_DrawRBG<1, 8, 0, 0, 0, 3>,  },  { T_DrawRBG<1, 8, 0, 0, 1, 0>, T_DrawRBG<1, 8, 0, 0, 1, 1>, T_DrawRBG<1, 8, 0, 0, 1, 2>, T_DrawRBG<1, 8, 0, 0, 1, 3>,  },  { T_DrawRBG<1, 8, 0, 0, 2, 0>, T_DrawRBG<1, 8, 0, 0, 2, 1>, T_DrawRBG<1, 8, 0, 0, 2, 2>, T_DrawRBG<1, 8, 0, 0, 2, 3>,  },  },  {  { T_DrawRBG<1, 8, 0, 1, 0, 0>, T_DrawRBG<1, 8, 0, 1, 0, 1>, T_DrawRBG<1, 8, 0, 1, 0, 2>, T_DrawRBG<1, 8, 0, 1, 0, 3>,  },  { T_DrawRBG<1, 8, 0, 1, 1, 0>, T_DrawRBG<1, 8, 0, 1, 1, 1>, T_DrawRBG<1, 8, 0, 1, 1, 2>, T_DrawRBG<1, 8, 0, 1, 1, 3>,  },  { T_DrawRBG<1, 8, 0, 1, 2, 0>, T_DrawRBG<1, 8, 0, 1, 2, 1>, T_DrawRBG<1, 8, 0, 1, 2, 2>, T_DrawRBG<1, 8, 0, 1, 2, 3>,  },  },  },
  {  {  { T_DrawRBG<1, 16, 0, 0, 0, 0>, T_DrawRBG<1, 16, 0, 0, 0, 1>, T_DrawRBG<1, 16, 0, 0, 0, 2>, T_DrawRBG<1, 16, 0, 0, 0, 3>,  },  { T_DrawRBG<1, 16, 0, 0, 1, 0>, T_DrawRBG<1, 16, 0, 0, 1, 1>, T_DrawRBG<1, 16, 0, 0, 1, 2>, T_DrawRBG<1, 16, 0, 0, 1, 3>,  },  { T_DrawRBG<1, 16, 0, 0, 2, 0>, T_DrawRBG<1, 16, 0, 0, 2, 1>, T_DrawRBG<1, 16, 0, 0, 2, 2>, T_DrawRBG<1, 16, 0, 0, 2, 3>,  },  },  {  { T_DrawRBG<1, 16, 0, 1, 0, 0>, T_DrawRBG<1, 16, 0, 1, 0, 1>, T_DrawRBG<1, 16, 0, 1, 0, 2>, T_DrawRBG<1, 16, 0, 1, 0, 3>,  },  { T_DrawRBG<1, 16, 0, 1, 1, 0>, T_DrawRBG<1, 16, 0, 1, 1, 1>, T_DrawRBG<1, 16, 0, 1, 1, 2>, T_DrawRBG<1, 16, 0, 1, 1, 3>,  },  { T_DrawRBG<1, 16, 0, 1, 2, 0>, T_DrawRBG<1, 16, 0, 1, 2, 1>, T_DrawRBG<1, 16, 0, 1, 2, 2>, T_DrawRBG<1, 16, 0, 1, 2, 3>,  },  },  },
  {  {  { T_DrawRBG<1, 16, 1, 0, 0, 0>, T_DrawRBG<1, 16, 1, 0, 0, 1>, T_DrawRBG<1, 16, 1, 0, 0, 2>, T_DrawRBG<1, 16, 1, 0, 0, 3>,  },  { T_DrawRBG<1, 16, 1, 0, 1, 0>, T_DrawRBG<1, 16, 1, 0, 1, 1>, T_DrawRBG<1, 16, 1, 0, 1, 2>, T_DrawRBG<1, 16, 1, 0, 1, 3>,  },  { T_DrawRBG<1, 16, 1, 0, 2, 0>, T_DrawRBG<1, 16, 1, 0, 2, 1>, T_DrawRBG<1, 16, 1, 0, 2, 2>, T_DrawRBG<1, 16, 1, 0, 2, 3>,  },  },  {  { T_DrawRBG<1, 16, 1, 1, 0, 0>, T_DrawRBG<1, 16, 1, 1, 0, 1>, T_DrawRBG<1, 16, 1, 1, 0, 2>, T_DrawRBG<1, 16, 1, 1, 0, 3>,  },  { T_DrawRBG<1, 16, 1, 1, 1, 0>, T_DrawRBG<1, 16, 1, 1, 1, 1>, T_DrawRBG<1, 16, 1, 1, 1, 2>, T_DrawRBG<1, 16, 1, 1, 1, 3>,  },  { T_DrawRBG<1, 16, 1, 1, 2, 0>, T_DrawRBG<1, 16, 1, 1, 2, 1>, T_DrawRBG<1, 16, 1, 1, 2, 2>, T_DrawRBG<1, 16, 1, 1, 2, 3>,  },  },  },
  {  {  { T_DrawRBG<1, 32, 1, 0, 0, 0>, T_DrawRBG<1, 32, 1, 0, 0, 1>, T_DrawRBG<1, 32, 1, 0, 0, 2>, T_DrawRBG<1, 32, 1, 0, 0, 3>,  },  { T_DrawRBG<1, 32, 1, 0, 1, 0>, T_DrawRBG<1, 32, 1, 0, 1, 1>, T_DrawRBG<1, 32, 1, 0, 1, 2>, T_DrawRBG<1, 32, 1, 0, 1, 3>,  },  { T_DrawRBG<1, 32, 1, 0, 2, 0>, T_DrawRBG<1, 32, 1, 0, 2, 1>, T_DrawRBG<1, 32, 1, 0, 2, 2>, T_DrawRBG<1, 32, 1, 0, 2, 3>,  },  },  {  { T_DrawRBG<1, 32, 1, 1, 0, 0>, T_DrawRBG<1, 32, 1, 1, 0, 1>, T_DrawRBG<1, 32, 1, 1, 0, 2>, T_DrawRBG<1, 32, 1, 1, 0, 3>,  },  { T_DrawRBG<1, 32, 1, 1, 1, 0>, T_DrawRBG<1, 32, 1, 1, 1, 1>, T_DrawRBG<1, 32, 1, 1, 1, 2>, T_DrawRBG<1, 32, 1, 1, 1, 3>,  },  { T_DrawRBG<1, 32, 1, 1, 2, 0>, T_DrawRBG<1, 32, 1, 1, 2, 1>, T_DrawRBG<1, 32, 1, 1, 2, 2>, T_DrawRBG<1, 32, 1, 1, 2, 3>,  },  },  },
 }
};

template<typename T>
static INLINE void Doubleize(T* ptr, const int orig_len)
{
 for(int i = orig_len - 1; MDFN_LIKELY(i >= 0); i--)
 {
  auto tmp = *(ptr + i);

  *(ptr + (i << 1) + 0) = tmp;
  *(ptr + (i << 1) + 1) = tmp;
 }
}

static void RBGPP(const unsigned layer, uint64* buf, const unsigned rbg_w)
{
 ApplyHMosaic(layer, buf, rbg_w);

 for(unsigned i = 0; i < rbg_w; i++)
 {
  uint64 tmp = buf[i];

  if(LB.rotabsel[i])
   tmp &= ~(uint64)0xFFFFFFFF;

  buf[i] = tmp;
 }

 if(HRes & 0x2)
  Doubleize(buf, rbg_w);

 ApplyWin(layer, buf);
}

// Call before DrawSpriteData()
static INLINE void MakeSpriteCCLUT(void)
{
 const bool cce = ((CCCTL >> 6) & 1);

 for(unsigned pr = 0; pr < 8; pr++)
 {
  bool mask = false;

  switch(SpriteCCCond)
  {
   case 0: mask = (SpritePrioNum[pr] <= SpriteCCNum); break;
   case 1: mask = (SpritePrioNum[pr] == SpriteCCNum); break;
   case 2: mask = (SpritePrioNum[pr] >= SpriteCCNum); break;
  }
  SpriteCCLUT[pr] = (cce & mask) << PIX_CCE_SHIFT;
 }

 SpriteCC3Mask = 0;
 if(SpriteCCCond == 3 && cce)
  SpriteCC3Mask = 1U << PIX_CCE_SHIFT;
}

template<bool TA_HiRes, bool TA_TPShadSel, unsigned TA_SPCTL_Low>
static void T_DrawSpriteData(const uint16* vdp1sb, const bool vdp1_hires8, unsigned w)
{
 const unsigned SpriteType = (TA_SPCTL_Low & 0xF);
 const bool SpriteWinEn = (TA_SPCTL_Low & 0x10);
 const bool SpriteColorMode = (TA_SPCTL_Low & 0x20);
 //
 const size_t cao = CRAMAddrOffs_Sprite << 8;
 uint32 spix_base_or = 0;

 spix_base_or |= ((ColorOffsEn >> 6) & 1) << PIX_COE_SHIFT;
 spix_base_or |= ((ColorOffsSel >> 6) & 1) << PIX_COSEL_SHIFT;
 spix_base_or |= ((LineColorEn >> 5/*5 here, not 6*/) & 1) << PIX_LCE_SHIFT;
 spix_base_or |= (((CCCTL >> 12) & 0x7) == 0x0) << PIX_GRAD_SHIFT;
 spix_base_or |= ((CCCTL >> 6) & 1) << PIX_LAYER_CCE_SHIFT;

 for(unsigned i = 0; MDFN_LIKELY(i < w); i++)
 {
  unsigned src;
  unsigned pr = 0, cc = 0;
  bool tp = false;
  uint64 spix;

  src = vdp1sb[i >> TA_HiRes];

  if(vdp1_hires8)
  {
   if(TA_HiRes)
    src = 0xFF00 | (src >> (((i & 1) ^ 1) << 3));
   else
    src = 0xFF00 | (src >> 8);
  }

  if(SpriteColorMode && (src & 0x8000))
  {
   spix = (uint64)rgb15_to_rgb24(src) << PIX_RGB_SHIFT;
   spix |= 1U << PIX_ISRGB_SHIFT;
   spix |= SpriteCC3Mask;

   if(SpriteType & 0x8)
    tp = !(src & 0xFF);
   else if(SpriteWinEn)
   {
    if(SpriteType >= 0x2 && SpriteType <= 0x7)
     tp = !(src & 0x7FFF);
   }
  }
  else
  {
   bool nshad = false;
   bool sd = false;
   unsigned dc;

   if(SpriteType & 0x8)
    src &= 0xFF;

   tp = !src;

   switch(SpriteType)
   {
     case 0x0:
	pr = (src >> 14) & 0x3;
	cc = (src >> 11) & 0x7;
	dc = src & 0x7FF;
	nshad = (dc == 0x7FE);
	break;

     case 0x1:
	pr = (src >> 13) & 0x7;
	cc = (src >> 11) & 0x3;
	dc = src & 0x7FF;
	nshad = (dc == 0x7FE);
	break;

     case 0x2:
	sd = (src >> 15) & 0x1;
	pr = (src >> 14) & 0x1;
	cc = (src >> 11) & 0x7;
	dc = src & 0x7FF;
	nshad = (dc == 0x7FE);
	break;

     case 0x3:
	sd = (src >> 15) & 0x1;
	pr = (src >> 13) & 0x3;
	cc = (src >> 11) & 0x3;
	dc = src & 0x7FF;
	nshad = (dc == 0x7FE);
	break;

     case 0x4:
	sd = (src >> 15) & 0x1;
	pr = (src >> 13) & 0x3;
	cc = (src >> 10) & 0x7;
	dc = src & 0x3FF;
	nshad = (dc == 0x3FE);
	break;

     case 0x5:
	sd = (src >> 15) & 0x1;
	pr = (src >> 12) & 0x7;
	cc = (src >> 11) & 0x1;
	dc = src & 0x7FF;
	nshad = (dc == 0x7FE);
	break;

     case 0x6:
	sd = (src >> 15) & 0x1;
	pr = (src >> 12) & 0x7;
	cc = (src >> 10) & 0x3;
	dc = src & 0x3FF;
	nshad = (dc == 0x3FE);
	break;

     case 0x7:
	sd = (src >> 15) & 0x1;
	pr = (src >> 12) & 0x7;
	cc = (src >>  9) & 0x7;
	dc = src & 0x1FF;
	nshad = (dc == 0x1FE);
	break;
     //
     //
     //
     case 0x8:
	pr = (src >> 7) & 0x1;
	dc = src & 0x7F;
	nshad = (dc == 0x7E);
	break;

     case 0x9:
	pr = (src >> 7) & 0x1;
	cc = (src >> 6) & 0x1;
	dc = src & 0x3F;
	nshad = (dc == 0x3E);
	break;

     case 0xA:
	pr = (src >> 6) & 0x3;
	dc = src & 0x3F;
	nshad = (dc == 0x3E);
	break;

     case 0xB:
	cc = (src >> 6) & 0x3;
	dc = src & 0x3F;
	nshad = (dc == 0x3E);
	break;
     //
     case 0xC:
	pr = (src >> 7) & 0x1;
	dc = src & 0xFF;
	nshad = (dc == 0xFE);
	break;

     case 0xD:
	pr = (src >> 7) & 0x1;
	cc = (src >> 6) & 0x1;
	dc = src & 0xFF;
	nshad = (dc == 0xFE);
	break;

     case 0xE:
	pr = (src >> 6) & 0x3;
	dc = src & 0xFF;
	nshad = (dc == 0xFE);
	break;

     case 0xF:
	cc = (src >> 6) & 0x3;
	dc = src & 0xFF;
	nshad = (dc == 0xFE);
	break;
   }
   //
   //
   //
   uint32 rgb24 = ColorCache[(cao + dc) & 0x7FF];

   spix = (uint64)rgb24 << PIX_RGB_SHIFT;

   spix |= ((int32)rgb24 >> 31) & SpriteCC3Mask;

   if(SpriteWinEn)	// Sprite window enable
    spix |= ((uint64)sd << PIX_SWBIT_SHIFT);

   if(nshad)
    spix |= 1 << PIX_DOSHAD_SHIFT;
   else
   {
    if(SpriteWinEn)
    {
     if(SpriteType >= 0x2 && SpriteType <= 0x7)
      tp = !(src & 0x7FFF);
    }
    else if(sd)
    {
     if(src & 0x7FFF)
      spix |= 1 << PIX_SELFSHAD_SHIFT;
     else if(TA_TPShadSel)
      spix |= 1 << PIX_DOSHAD_SHIFT;
     else
      tp = true;
    }
   }
  }

  spix |= spix_base_or;
  spix |= (tp ? 0 : SpritePrioNum[pr]) << PIX_PRIO_SHIFT;
  spix |= SpriteCCRatio[cc] << PIX_CCRATIO_SHIFT;
  spix |= SpriteCCLUT[pr];

  LB.spr[i] = spix;
 }
}

static void (*DrawSpriteData[2][2][0x40])(const uint16* vdp1sb, const bool vdp1_hires8, unsigned w) =
{
 {
  { T_DrawSpriteData<0, 0, 0x00>, T_DrawSpriteData<0, 0, 0x01>, T_DrawSpriteData<0, 0, 0x02>, T_DrawSpriteData<0, 0, 0x03>, T_DrawSpriteData<0, 0, 0x04>, T_DrawSpriteData<0, 0, 0x05>, T_DrawSpriteData<0, 0, 0x06>, T_DrawSpriteData<0, 0, 0x07>, T_DrawSpriteData<0, 0, 0x08>, T_DrawSpriteData<0, 0, 0x09>, T_DrawSpriteData<0, 0, 0x0a>, T_DrawSpriteData<0, 0, 0x0b>, T_DrawSpriteData<0, 0, 0x0c>, T_DrawSpriteData<0, 0, 0x0d>, T_DrawSpriteData<0, 0, 0x0e>, T_DrawSpriteData<0, 0, 0x0f>, T_DrawSpriteData<0, 0, 0x10>, T_DrawSpriteData<0, 0, 0x11>, T_DrawSpriteData<0, 0, 0x12>, T_DrawSpriteData<0, 0, 0x13>, T_DrawSpriteData<0, 0, 0x14>, T_DrawSpriteData<0, 0, 0x15>, T_DrawSpriteData<0, 0, 0x16>, T_DrawSpriteData<0, 0, 0x17>, T_DrawSpriteData<0, 0, 0x18>, T_DrawSpriteData<0, 0, 0x19>, T_DrawSpriteData<0, 0, 0x1a>, T_DrawSpriteData<0, 0, 0x1b>, T_DrawSpriteData<0, 0, 0x1c>, T_DrawSpriteData<0, 0, 0x1d>, T_DrawSpriteData<0, 0, 0x1e>, T_DrawSpriteData<0, 0, 0x1f>, T_DrawSpriteData<0, 0, 0x20>, T_DrawSpriteData<0, 0, 0x21>, T_DrawSpriteData<0, 0, 0x22>, T_DrawSpriteData<0, 0, 0x23>, T_DrawSpriteData<0, 0, 0x24>, T_DrawSpriteData<0, 0, 0x25>, T_DrawSpriteData<0, 0, 0x26>, T_DrawSpriteData<0, 0, 0x27>, T_DrawSpriteData<0, 0, 0x28>, T_DrawSpriteData<0, 0, 0x29>, T_DrawSpriteData<0, 0, 0x2a>, T_DrawSpriteData<0, 0, 0x2b>, T_DrawSpriteData<0, 0, 0x2c>, T_DrawSpriteData<0, 0, 0x2d>, T_DrawSpriteData<0, 0, 0x2e>, T_DrawSpriteData<0, 0, 0x2f>, T_DrawSpriteData<0, 0, 0x30>, T_DrawSpriteData<0, 0, 0x31>, T_DrawSpriteData<0, 0, 0x32>, T_DrawSpriteData<0, 0, 0x33>, T_DrawSpriteData<0, 0, 0x34>, T_DrawSpriteData<0, 0, 0x35>, T_DrawSpriteData<0, 0, 0x36>, T_DrawSpriteData<0, 0, 0x37>, T_DrawSpriteData<0, 0, 0x38>, T_DrawSpriteData<0, 0, 0x39>, T_DrawSpriteData<0, 0, 0x3a>, T_DrawSpriteData<0, 0, 0x3b>, T_DrawSpriteData<0, 0, 0x3c>, T_DrawSpriteData<0, 0, 0x3d>, T_DrawSpriteData<0, 0, 0x3e>, T_DrawSpriteData<0, 0, 0x3f> },
  { T_DrawSpriteData<0, 1, 0x00>, T_DrawSpriteData<0, 1, 0x01>, T_DrawSpriteData<0, 1, 0x02>, T_DrawSpriteData<0, 1, 0x03>, T_DrawSpriteData<0, 1, 0x04>, T_DrawSpriteData<0, 1, 0x05>, T_DrawSpriteData<0, 1, 0x06>, T_DrawSpriteData<0, 1, 0x07>, T_DrawSpriteData<0, 1, 0x08>, T_DrawSpriteData<0, 1, 0x09>, T_DrawSpriteData<0, 1, 0x0a>, T_DrawSpriteData<0, 1, 0x0b>, T_DrawSpriteData<0, 1, 0x0c>, T_DrawSpriteData<0, 1, 0x0d>, T_DrawSpriteData<0, 1, 0x0e>, T_DrawSpriteData<0, 1, 0x0f>, T_DrawSpriteData<0, 1, 0x10>, T_DrawSpriteData<0, 1, 0x11>, T_DrawSpriteData<0, 1, 0x12>, T_DrawSpriteData<0, 1, 0x13>, T_DrawSpriteData<0, 1, 0x14>, T_DrawSpriteData<0, 1, 0x15>, T_DrawSpriteData<0, 1, 0x16>, T_DrawSpriteData<0, 1, 0x17>, T_DrawSpriteData<0, 1, 0x18>, T_DrawSpriteData<0, 1, 0x19>, T_DrawSpriteData<0, 1, 0x1a>, T_DrawSpriteData<0, 1, 0x1b>, T_DrawSpriteData<0, 1, 0x1c>, T_DrawSpriteData<0, 1, 0x1d>, T_DrawSpriteData<0, 1, 0x1e>, T_DrawSpriteData<0, 1, 0x1f>, T_DrawSpriteData<0, 1, 0x20>, T_DrawSpriteData<0, 1, 0x21>, T_DrawSpriteData<0, 1, 0x22>, T_DrawSpriteData<0, 1, 0x23>, T_DrawSpriteData<0, 1, 0x24>, T_DrawSpriteData<0, 1, 0x25>, T_DrawSpriteData<0, 1, 0x26>, T_DrawSpriteData<0, 1, 0x27>, T_DrawSpriteData<0, 1, 0x28>, T_DrawSpriteData<0, 1, 0x29>, T_DrawSpriteData<0, 1, 0x2a>, T_DrawSpriteData<0, 1, 0x2b>, T_DrawSpriteData<0, 1, 0x2c>, T_DrawSpriteData<0, 1, 0x2d>, T_DrawSpriteData<0, 1, 0x2e>, T_DrawSpriteData<0, 1, 0x2f>, T_DrawSpriteData<0, 1, 0x30>, T_DrawSpriteData<0, 1, 0x31>, T_DrawSpriteData<0, 1, 0x32>, T_DrawSpriteData<0, 1, 0x33>, T_DrawSpriteData<0, 1, 0x34>, T_DrawSpriteData<0, 1, 0x35>, T_DrawSpriteData<0, 1, 0x36>, T_DrawSpriteData<0, 1, 0x37>, T_DrawSpriteData<0, 1, 0x38>, T_DrawSpriteData<0, 1, 0x39>, T_DrawSpriteData<0, 1, 0x3a>, T_DrawSpriteData<0, 1, 0x3b>, T_DrawSpriteData<0, 1, 0x3c>, T_DrawSpriteData<0, 1, 0x3d>, T_DrawSpriteData<0, 1, 0x3e>, T_DrawSpriteData<0, 1, 0x3f> },
 },
 {
  { T_DrawSpriteData<1, 0, 0x00>, T_DrawSpriteData<1, 0, 0x01>, T_DrawSpriteData<1, 0, 0x02>, T_DrawSpriteData<1, 0, 0x03>, T_DrawSpriteData<1, 0, 0x04>, T_DrawSpriteData<1, 0, 0x05>, T_DrawSpriteData<1, 0, 0x06>, T_DrawSpriteData<1, 0, 0x07>, T_DrawSpriteData<1, 0, 0x08>, T_DrawSpriteData<1, 0, 0x09>, T_DrawSpriteData<1, 0, 0x0a>, T_DrawSpriteData<1, 0, 0x0b>, T_DrawSpriteData<1, 0, 0x0c>, T_DrawSpriteData<1, 0, 0x0d>, T_DrawSpriteData<1, 0, 0x0e>, T_DrawSpriteData<1, 0, 0x0f>, T_DrawSpriteData<1, 0, 0x10>, T_DrawSpriteData<1, 0, 0x11>, T_DrawSpriteData<1, 0, 0x12>, T_DrawSpriteData<1, 0, 0x13>, T_DrawSpriteData<1, 0, 0x14>, T_DrawSpriteData<1, 0, 0x15>, T_DrawSpriteData<1, 0, 0x16>, T_DrawSpriteData<1, 0, 0x17>, T_DrawSpriteData<1, 0, 0x18>, T_DrawSpriteData<1, 0, 0x19>, T_DrawSpriteData<1, 0, 0x1a>, T_DrawSpriteData<1, 0, 0x1b>, T_DrawSpriteData<1, 0, 0x1c>, T_DrawSpriteData<1, 0, 0x1d>, T_DrawSpriteData<1, 0, 0x1e>, T_DrawSpriteData<1, 0, 0x1f>, T_DrawSpriteData<1, 0, 0x20>, T_DrawSpriteData<1, 0, 0x21>, T_DrawSpriteData<1, 0, 0x22>, T_DrawSpriteData<1, 0, 0x23>, T_DrawSpriteData<1, 0, 0x24>, T_DrawSpriteData<1, 0, 0x25>, T_DrawSpriteData<1, 0, 0x26>, T_DrawSpriteData<1, 0, 0x27>, T_DrawSpriteData<1, 0, 0x28>, T_DrawSpriteData<1, 0, 0x29>, T_DrawSpriteData<1, 0, 0x2a>, T_DrawSpriteData<1, 0, 0x2b>, T_DrawSpriteData<1, 0, 0x2c>, T_DrawSpriteData<1, 0, 0x2d>, T_DrawSpriteData<1, 0, 0x2e>, T_DrawSpriteData<1, 0, 0x2f>, T_DrawSpriteData<1, 0, 0x30>, T_DrawSpriteData<1, 0, 0x31>, T_DrawSpriteData<1, 0, 0x32>, T_DrawSpriteData<1, 0, 0x33>, T_DrawSpriteData<1, 0, 0x34>, T_DrawSpriteData<1, 0, 0x35>, T_DrawSpriteData<1, 0, 0x36>, T_DrawSpriteData<1, 0, 0x37>, T_DrawSpriteData<1, 0, 0x38>, T_DrawSpriteData<1, 0, 0x39>, T_DrawSpriteData<1, 0, 0x3a>, T_DrawSpriteData<1, 0, 0x3b>, T_DrawSpriteData<1, 0, 0x3c>, T_DrawSpriteData<1, 0, 0x3d>, T_DrawSpriteData<1, 0, 0x3e>, T_DrawSpriteData<1, 0, 0x3f> },
  { T_DrawSpriteData<1, 1, 0x00>, T_DrawSpriteData<1, 1, 0x01>, T_DrawSpriteData<1, 1, 0x02>, T_DrawSpriteData<1, 1, 0x03>, T_DrawSpriteData<1, 1, 0x04>, T_DrawSpriteData<1, 1, 0x05>, T_DrawSpriteData<1, 1, 0x06>, T_DrawSpriteData<1, 1, 0x07>, T_DrawSpriteData<1, 1, 0x08>, T_DrawSpriteData<1, 1, 0x09>, T_DrawSpriteData<1, 1, 0x0a>, T_DrawSpriteData<1, 1, 0x0b>, T_DrawSpriteData<1, 1, 0x0c>, T_DrawSpriteData<1, 1, 0x0d>, T_DrawSpriteData<1, 1, 0x0e>, T_DrawSpriteData<1, 1, 0x0f>, T_DrawSpriteData<1, 1, 0x10>, T_DrawSpriteData<1, 1, 0x11>, T_DrawSpriteData<1, 1, 0x12>, T_DrawSpriteData<1, 1, 0x13>, T_DrawSpriteData<1, 1, 0x14>, T_DrawSpriteData<1, 1, 0x15>, T_DrawSpriteData<1, 1, 0x16>, T_DrawSpriteData<1, 1, 0x17>, T_DrawSpriteData<1, 1, 0x18>, T_DrawSpriteData<1, 1, 0x19>, T_DrawSpriteData<1, 1, 0x1a>, T_DrawSpriteData<1, 1, 0x1b>, T_DrawSpriteData<1, 1, 0x1c>, T_DrawSpriteData<1, 1, 0x1d>, T_DrawSpriteData<1, 1, 0x1e>, T_DrawSpriteData<1, 1, 0x1f>, T_DrawSpriteData<1, 1, 0x20>, T_DrawSpriteData<1, 1, 0x21>, T_DrawSpriteData<1, 1, 0x22>, T_DrawSpriteData<1, 1, 0x23>, T_DrawSpriteData<1, 1, 0x24>, T_DrawSpriteData<1, 1, 0x25>, T_DrawSpriteData<1, 1, 0x26>, T_DrawSpriteData<1, 1, 0x27>, T_DrawSpriteData<1, 1, 0x28>, T_DrawSpriteData<1, 1, 0x29>, T_DrawSpriteData<1, 1, 0x2a>, T_DrawSpriteData<1, 1, 0x2b>, T_DrawSpriteData<1, 1, 0x2c>, T_DrawSpriteData<1, 1, 0x2d>, T_DrawSpriteData<1, 1, 0x2e>, T_DrawSpriteData<1, 1, 0x2f>, T_DrawSpriteData<1, 1, 0x30>, T_DrawSpriteData<1, 1, 0x31>, T_DrawSpriteData<1, 1, 0x32>, T_DrawSpriteData<1, 1, 0x33>, T_DrawSpriteData<1, 1, 0x34>, T_DrawSpriteData<1, 1, 0x35>, T_DrawSpriteData<1, 1, 0x36>, T_DrawSpriteData<1, 1, 0x37>, T_DrawSpriteData<1, 1, 0x38>, T_DrawSpriteData<1, 1, 0x39>, T_DrawSpriteData<1, 1, 0x3a>, T_DrawSpriteData<1, 1, 0x3b>, T_DrawSpriteData<1, 1, 0x3c>, T_DrawSpriteData<1, 1, 0x3d>, T_DrawSpriteData<1, 1, 0x3e>, T_DrawSpriteData<1, 1, 0x3f> },
 }
};

// Don't change these constants without also updating the template variable
// setup for the call into MixIt(and the contents of MixIt itself...).
enum
{
 MIXIT_SPECIAL_NONE = 0x0,
 MIXIT_SPECIAL_GRAD = 0x1,
 MIXIT_SPECIAL_EXCC_CRAM0 = 0x2,
 MIXIT_SPECIAL_EXCC_CRAM12 = 0x3,
 MIXIT_SPECIAL_EXCC_LINE_CRAM0 = 0x4,
 MIXIT_SPECIAL_EXCC_LINE_CRAM12 = 0x5
};

template<bool TA_rbg1en, unsigned TA_Special, bool TA_CCRTMD, bool TA_CCMD>
static void T_MixIt(uint32* target, const unsigned vdp2_line, const unsigned w, const uint32 back_rgb24, const uint64* blursrc)
{
 //printf("MixIt: %d, %d, %d, %d\n", TA_rbg1en, TA_Special, TA_CCRTMD, TA_CCMD);
 const uint32* lclut = &ColorCache[CurLCColor &~ 0x7F];
 uint32 blurprev[2];

 if(TA_Special == MIXIT_SPECIAL_GRAD)
  blurprev[0] = blurprev[1] = *blursrc >> PIX_RGB_SHIFT;

 uint32 line_pix_l;
 {
  line_pix_l = 0U << PIX_ISRGB_SHIFT;
  line_pix_l |= LineColorCCRatio << PIX_CCRATIO_SHIFT;
  line_pix_l |= ((CCCTL >> 5) & 1) << PIX_CCE_SHIFT;
  line_pix_l |= ((CCCTL >> 5) & 1) << PIX_LAYER_CCE_SHIFT;
 }

 //
 //
 uint64 back_pix;
 {
  back_pix = (uint64)back_rgb24 << PIX_RGB_SHIFT;
  back_pix |= 1U << PIX_ISRGB_SHIFT;
  back_pix |= ((ColorOffsEn >> 5) & 1) << PIX_COE_SHIFT;
  back_pix |= ((ColorOffsSel >> 5) & 1) << PIX_COSEL_SHIFT;
  back_pix |= ((SDCTL >> 5) & 1) << PIX_SHADEN_SHIFT;
  back_pix |= BackCCRatio << PIX_CCRATIO_SHIFT;
 }

 for(uint32 i = 0; MDFN_LIKELY(i < w); i++)
 {
  uint64 pix = back_pix;
  uint32 blurcake;

  //
  // Listed from lowest priority to greatest priority when prio levels are equal(back pixel has prio level of 0,
  // and should display on "top" of any other layers).
  //
  uint64 tmp_pix[8] =
  {
   (TA_rbg1en ? 0 : (LB.nbg[3] + 8)[i]),
   (TA_rbg1en ? 0 : (LB.nbg[2] + 8)[i]),
   (TA_rbg1en ? 0 : (LB.nbg[1] + 8)[i]),
   (LB.nbg[0] + 8)[i],
   LB.rbg0[i],
   LB.spr[i],
   0/*null pixel*/,
   back_pix
  };
  uint64 pt;
  unsigned st;

  pt  = 0x01ULL << (uint8)(tmp_pix[0] >> PIX_PRIO_TEST_SHIFT);
  pt |= 0x02ULL << (uint8)(tmp_pix[1] >> PIX_PRIO_TEST_SHIFT);
  pt |= 0x04ULL << (uint8)(tmp_pix[2] >> PIX_PRIO_TEST_SHIFT);
  pt |= 0x08ULL << (uint8)(tmp_pix[3] >> PIX_PRIO_TEST_SHIFT);
  pt |= 0x10ULL << (uint8)(tmp_pix[4] >> PIX_PRIO_TEST_SHIFT);
  pt |= 0x20ULL << (uint8)(tmp_pix[5] >> PIX_PRIO_TEST_SHIFT);
  pt |= 0xC0ULL; // Back pixel(0x80) and null pixel(0x40)

  st = 63 ^ MDFN_lzcount64_0UD(pt);
  pt ^= 1ULL << st;
  pt |= 0x40;	// Restore the null!
  pix = tmp_pix[st & 0x7];

  if(pix & (1U << PIX_DOSHAD_SHIFT))
  {
   st = 63 ^ MDFN_lzcount64_0UD(pt);
   pt ^= 1ULL << st;
   pt |= 0x40;	// Restore the null!
   pix = tmp_pix[st & 0x7];
   pix |= (1U << PIX_DOSHAD_SHIFT);
  }

  if(TA_Special == MIXIT_SPECIAL_GRAD)
  {
   const uint32 blurpie = blursrc[i] >> PIX_RGB_SHIFT;

   blurcake = ((blurprev[0] + blurprev[1]) - ((blurprev[0] ^ blurprev[1]) & 0x01010101)) >> 1;
   blurcake = ((blurcake + blurpie) - ((blurcake ^ blurpie) & 0x01010101)) >> 1;
   blurprev[0] = blurprev[1];
   blurprev[1] = blurpie;
  }

  //
  // Color calculation
  //
  if(pix & (1U << PIX_CCE_SHIFT))
  {
   uint64 pix2, pix3;

   st = 63 ^ MDFN_lzcount64_0UD(pt);
   pt ^= 1ULL << st;
   pt |= 0x40;	// Restore the null!
   pix2 = tmp_pix[st & 0x7];

   st = 63 ^ MDFN_lzcount64_0UD(pt);
   pt ^= 1ULL << st;
   pt |= 0x40;	// Restore the null!
   pix3 = tmp_pix[st & 0x7];

   if(TA_Special == MIXIT_SPECIAL_GRAD)
   {
    if((pix | pix2) & (1U << PIX_GRAD_SHIFT))
     pix2 = (uint32)pix2 | ((uint64)blurcake << PIX_RGB_SHIFT);	// Be sure to preserve the color calc ratio, at least.
   }
   else if(pix & (1U << PIX_LCE_SHIFT))
   {
    //
    // Line color
    //
    const uint64 pix4 = pix3;
    const uint32 line_pix_rgb = lclut[LB.lc[i]];
    pix3 = pix2;
    pix2 = line_pix_l | ((uint64)line_pix_rgb << PIX_RGB_SHIFT);

    if(TA_Special == MIXIT_SPECIAL_EXCC_LINE_CRAM0)
    {
     uint32 sec_rgb = line_pix_rgb;
     uint32 third_rgb = (pix3 >> PIX_RGB_SHIFT);

     if(pix3 & (1U << PIX_LAYER_CCE_SHIFT))
      third_rgb = (third_rgb >> 1) & 0x7F7F7F;

     sec_rgb = ((sec_rgb + third_rgb) - ((sec_rgb ^ third_rgb) & 0x01010101)) >> 1;
     pix2 = (uint32)pix2 | ((uint64)sec_rgb << PIX_RGB_SHIFT);
    }
    else if(TA_Special == MIXIT_SPECIAL_EXCC_LINE_CRAM12)
    {
     uint32 sec_rgb = line_pix_rgb;
     uint32 third_rgb = (pix3 >> PIX_RGB_SHIFT);

     if(pix3 & (1U << PIX_ISRGB_SHIFT))
     {
      if((pix3 & (1U << PIX_LAYER_CCE_SHIFT)) && (pix4 & (1U << PIX_ISRGB_SHIFT)))
      {
       const uint32 fourth_rgb = (pix4 >> PIX_RGB_SHIFT);
       third_rgb = ((third_rgb + fourth_rgb) - ((third_rgb ^ fourth_rgb) & 0x01010101)) >> 1;
      }

      sec_rgb = ((sec_rgb + third_rgb) - ((sec_rgb ^ third_rgb) & 0x01010101)) >> 1;
      pix2 = (uint32)pix2 | ((uint64)sec_rgb << PIX_RGB_SHIFT);
     }
    }
   }
   else
   {
    if(TA_Special == MIXIT_SPECIAL_EXCC_CRAM0 || TA_Special == MIXIT_SPECIAL_EXCC_CRAM12 || TA_Special == MIXIT_SPECIAL_EXCC_LINE_CRAM0 || TA_Special == MIXIT_SPECIAL_EXCC_LINE_CRAM12)
    {
     if(pix2 & (1U << PIX_LAYER_CCE_SHIFT))
     {
      if(TA_Special == MIXIT_SPECIAL_EXCC_CRAM0 || TA_Special == MIXIT_SPECIAL_EXCC_LINE_CRAM0 || (pix3 & (1U << PIX_ISRGB_SHIFT)))
      {
       uint32 sec_rgb = pix2 >> PIX_RGB_SHIFT;
       const uint32 third_rgb = (pix3 >> PIX_RGB_SHIFT);

       sec_rgb = ((sec_rgb + third_rgb) - ((sec_rgb ^ third_rgb) & 0x01010101)) >> 1;
       pix2 = (uint32)pix2 | ((uint64)sec_rgb << PIX_RGB_SHIFT);
      }
     }
    }
   }

   uint32 fore_rgb = pix >> PIX_RGB_SHIFT;
   uint32 sec_rgb = pix2 >> PIX_RGB_SHIFT;
   uint32 new_rgb;

   if(TA_CCMD)	// Ignore ratio, add as-is.
   {
    new_rgb =  std::min<unsigned>(0x0000FF, (fore_rgb & 0x0000FF) + (sec_rgb & 0x0000FF));
    new_rgb |= std::min<unsigned>(0x00FF00, (fore_rgb & 0x00FF00) + (sec_rgb & 0x00FF00));
    new_rgb |= std::min<unsigned>(0xFF0000, (fore_rgb & 0xFF0000) + (sec_rgb & 0xFF0000));
   }
   else
   {
    unsigned fore_ratio = ((uint32)(TA_CCRTMD ? pix2 : pix) >> PIX_CCRATIO_SHIFT) ^ 0x1F;
    unsigned sec_ratio = 0x20 - fore_ratio;

    new_rgb =  ((((fore_rgb & 0x0000FF) * fore_ratio) + ((sec_rgb & 0x0000FF) * sec_ratio)) >> 5);
    new_rgb |= ((((fore_rgb & 0x00FF00) * fore_ratio) + ((sec_rgb & 0x00FF00) * sec_ratio)) >> 5) & 0x00FF00;
    new_rgb |= ((((fore_rgb & 0xFF0000) * fore_ratio) + ((sec_rgb & 0xFF0000) * sec_ratio)) >> 5) & 0xFF0000;
   }
   pix = ((uint64)new_rgb << 32) | (uint32)pix;
  }

  //
  // Color offset
  //
  if(pix & (1U << PIX_COE_SHIFT))
  {
   const unsigned sel = (pix >> PIX_COSEL_SHIFT) & 1;
   const uint32 rgb_tmp = pix >> PIX_RGB_SHIFT;
   int32 rt, gt, bt;

   rt = ColorOffs[sel][0] + (rgb_tmp & 0x000000FF);
   if(rt < 0) rt = 0;
   if(rt & 0x00000100) rt = 0x000000FF;

   gt = ColorOffs[sel][1] + (rgb_tmp & 0x0000FF00);
   if(gt < 0) gt = 0;
   if(gt & 0x00010000) gt = 0x0000FF00;

   bt = ColorOffs[sel][2] + (rgb_tmp & 0x00FF0000);
   if(bt < 0) bt = 0;
   if(bt & 0x01000000) bt = 0x00FF0000;

   pix = (uint32)pix | ((uint64)(uint32)(rt | gt | bt) << PIX_RGB_SHIFT);
  }

  //
  // Sprite shadow
  //
  if((uint8)pix >= PIX_SHADHALVTEST8_VAL)
   pix = (uint32)pix | ((pix >> 1) & 0x7F7F7F00000000ULL);

  target[i] = pix >> PIX_RGB_SHIFT;
 }
}

//template<bool TA_rbg1en, unsigned TA_Special, bool TA_CCRTMD, bool TA_CCMD>
static void (*MixIt[2][6][2][2])(uint32* target, const unsigned vdp2_line, const unsigned w, const uint32 back_rgb24, const uint64* blursrc) =
{
 {  {  { T_MixIt<0, 0, 0, 0>, T_MixIt<0, 0, 0, 1>,  },  { T_MixIt<0, 0, 1, 0>, T_MixIt<0, 0, 1, 1>,  },  },  {  { T_MixIt<0, 1, 0, 0>, T_MixIt<0, 1, 0, 1>,  },  { T_MixIt<0, 1, 1, 0>, T_MixIt<0, 1, 1, 1>,  },  },  {  { T_MixIt<0, 2, 0, 0>, T_MixIt<0, 2, 0, 1>,  },  { T_MixIt<0, 2, 1, 0>, T_MixIt<0, 2, 1, 1>,  },  },  {  { T_MixIt<0, 3, 0, 0>, T_MixIt<0, 3, 0, 1>,  },  { T_MixIt<0, 3, 1, 0>, T_MixIt<0, 3, 1, 1>,  },  },  {  { T_MixIt<0, 4, 0, 0>, T_MixIt<0, 4, 0, 1>,  },  { T_MixIt<0, 4, 1, 0>, T_MixIt<0, 4, 1, 1>,  },  },  {  { T_MixIt<0, 5, 0, 0>, T_MixIt<0, 5, 0, 1>,  },  { T_MixIt<0, 5, 1, 0>, T_MixIt<0, 5, 1, 1>,  },  },  },
 {  {  { T_MixIt<1, 0, 0, 0>, T_MixIt<1, 0, 0, 1>,  },  { T_MixIt<1, 0, 1, 0>, T_MixIt<1, 0, 1, 1>,  },  },  {  { T_MixIt<1, 1, 0, 0>, T_MixIt<1, 1, 0, 1>,  },  { T_MixIt<1, 1, 1, 0>, T_MixIt<1, 1, 1, 1>,  },  },  {  { T_MixIt<1, 2, 0, 0>, T_MixIt<1, 2, 0, 1>,  },  { T_MixIt<1, 2, 1, 0>, T_MixIt<1, 2, 1, 1>,  },  },  {  { T_MixIt<1, 3, 0, 0>, T_MixIt<1, 3, 0, 1>,  },  { T_MixIt<1, 3, 1, 0>, T_MixIt<1, 3, 1, 1>,  },  },  {  { T_MixIt<1, 4, 0, 0>, T_MixIt<1, 4, 0, 1>,  },  { T_MixIt<1, 4, 1, 0>, T_MixIt<1, 4, 1, 1>,  },  },  {  { T_MixIt<1, 5, 0, 0>, T_MixIt<1, 5, 0, 1>,  },  { T_MixIt<1, 5, 1, 0>, T_MixIt<1, 5, 1, 1>,  },  },  },
};

static int32 ApplyHBlend(uint32* const target, int32 w)
{
 #define BHALF(m, n) ((((uint64)(m) + (n)) - (((m) ^ (n)) & 0x01010101)) >> 1)

 assert(w >= 4);

#if 1
 if(!(HRes & 0x2))
 {
  target[(w - 1) * 2 + 1] = target[w - 1];
  target[(w - 1) * 2 + 0] = BHALF(BHALF(target[w - 2], target[w - 1]), target[w - 1]);

  for(int32 x = w - 2; x > 0; x--)
  {
   uint32 ptxm1 = target[x - 1];
   uint32 ptx = target[x];
   uint32 ptxp1 = target[x + 1];
   uint32 ptxm1_ptx = BHALF(ptxm1, ptx);
   uint32 ptx_ptxp1 = BHALF(ptx, ptxp1);

   target[x * 2 + 0] = BHALF(ptxm1_ptx, ptx);
   target[x * 2 + 1] = BHALF(ptx_ptxp1, ptx);
  }

  target[1] = BHALF(BHALF(target[0], target[1]), target[0]);
  target[0] = target[0];

  return w << 1;
 }
 else
#else
 if(!(HRes & 0x2))
 {
  for(int32 x = w - 1; x >= 0; x--)
   target[x * 2 + 0] = target[x * 2 + 1] = target[x];

  w <<= 1;
 }
#endif
 {
  uint32 a = target[0];
  for(int32 x = 0; x < w - 1; x++)
  {
   uint32 b = target[x];
   uint32 c = target[x + 1];
   uint32 ac = BHALF(a, c);
   uint32 bac = BHALF(b, ac);

   target[x] = bac;
   a = b;
  }
  return w;
 }
 #undef BHALF
}

static void ReorderRGB(uint32* target, const unsigned w, const unsigned Rshift, const unsigned Gshift, const unsigned Bshift)
{
 assert(!(w & 1));
 uint32* const bound = target + w;

 while(MDFN_LIKELY(target != bound))
 {
  const uint32 tmp0 = target[0];
  const uint32 tmp1 = target[1];

  target[0] = ((uint8)(tmp0 >>  0) << Rshift) |
	      ((uint8)(tmp0 >>  8) << Gshift) |
	      ((uint8)(tmp0 >> 16) << Bshift);

  target[1] = ((uint8)(tmp1 >>  0) << Rshift) |
	      ((uint8)(tmp1 >>  8) << Gshift) |
	      ((uint8)(tmp1 >> 16) << Bshift);

  target += 2;
 }
}

static NO_INLINE void DrawLine(const uint16 out_line, const uint16 vdp2_line, const bool field)
{
 uint32* target;
 const int32 tvdw = ((!CorrectAspect || Clock28M) ? 352 : 330) << ((HRes & 0x2) >> 1);
 const unsigned rbg_w = ((HRes & 0x1) ? 352 : 320);
 const unsigned w = ((HRes & 0x1) ? 352 : 320) << ((HRes & 0x2) >> 1);
 const int32 tvxo = std::max<int32>(0, (int32)(tvdw - w) >> 1);
 uint32 back_rgb24;
 uint32 border_ncf;

 target = espec->surface->pixels + out_line * espec->surface->pitchinpix;
 espec->LineWidths[out_line] = tvdw;

 if(!ShowHOverscan)
 {
  const int32 ntdw = tvdw * 1024 / 1056;
  const int32 tadj = std::max<int32>(0, espec->DisplayRect.x - ((tvdw - ntdw) >> 1));

  //if(out_line == 100)
  // printf("tvdw=%d, ntdw=%d, tadj=%d --- tvdw+tadj=%d\n", tvdw, ntdw, tadj, tvdw + tadj);

  assert((tvdw + tadj) <= 704);

  target += tadj;
  espec->LineWidths[out_line] = ntdw;
 }

 //
 // FIXME: Timing
 //
 if(vdp2_line == 0)
 {
  CurBackTabAddr = (BKTA & 0x7FFFF) + ((BKTA & 0x80000000) && InterlaceMode == IM_DOUBLE && field);
  CurLCTabAddr = (LCTA & 0x7FFFF) + ((LCTA & 0x80000000) && InterlaceMode == IM_DOUBLE && field);

  for(unsigned n = 0; n < 2; n++)
  {
   YCoordAccum[n] = (InterlaceMode == IM_DOUBLE && field) ? YCoordInc[n] : 0;

   CurLSA[n] = LineScrollAddr[n];

   if(InterlaceMode == IM_DOUBLE && field)
   {
    const uint8 sc = (SCRCTL >> (n << 3));

    CurLSA[n] += ((bool)(sc & 0x2) + (bool)(sc & 0x4) + (bool)(sc & 0x8)) << 1;
   }
   //
   //
   NBG23_YCounter[n & 1] = YScrollI[2 + n];
  }

  for(unsigned d = 0; d < 2; d++)
  {
   Window[d].CurLineWinAddr = Window[d].LineWinAddr;

   if(InterlaceMode == IM_DOUBLE && field)
    Window[d].CurLineWinAddr += 2;
  }

  MosaicVCount = 0;
 }

 if(vdp2_line != 0xFFFF)
 {
  CurBackColor = VRAM[CurBackTabAddr & 0x3FFFF] & 0x7FFF;

  if(BKTA & 0x80000000)
   CurBackTabAddr += 1 << (InterlaceMode == IM_DOUBLE);
  //
  CurLCColor = VRAM[CurLCTabAddr & 0x3FFFF] & 0x07FF;
  if(LCTA & 0x80000000)
   CurLCTabAddr += 1 << (InterlaceMode == IM_DOUBLE);
 }

 back_rgb24 = rgb15_to_rgb24(CurBackColor);

 if(BorderMode)
  border_ncf = espec->surface->MakeColor((uint8)(back_rgb24 >> 0), (uint8)(back_rgb24 >> 8), (uint8)(back_rgb24 >> 16));
 else
  border_ncf = espec->surface->MakeColor(0, 0, 0);

 if(vdp2_line == 0xFFFF)
 {
  for(int32 i = 0; i < tvdw; i++)
   target[i] = border_ncf;
 }
 else
 {
  //
  // Line scroll
  //
  unsigned ls_comp_line = vdp2_line;

  for(unsigned n = 0; n < 2; n++)
  {
   const uint8 sc = (SCRCTL >> (n << 3));
   const uint8 lss = ((sc >> 4) & 0x3);

   if((ls_comp_line & ((1 << lss) - 1)) == 0)
   {
    if(sc & 0x2)	// X
    {
     CurXScrollIF[n] = (VRAM[CurLSA[n] & 0x3FFFF] & 0x7FF) << 8;
     CurLSA[n]++;
     CurXScrollIF[n] |= VRAM[CurLSA[n] & 0x3FFFF] >> 8;
     CurLSA[n]++;

     CurXScrollIF[n] += (XScrollI[n] << 8) + XScrollF[n];
    }

    if(sc & 0x4) // Y
    {
     YCoordAccum[n] = 0;	// Don't (InterlaceMode == IM_DOUBLE && field)
     //
     CurYScrollIF[n] = (VRAM[CurLSA[n] & 0x3FFFF] & 0x7FF) << 8;
     CurLSA[n]++;
     CurYScrollIF[n] |= VRAM[CurLSA[n] & 0x3FFFF] >> 8;
     CurLSA[n]++;

     CurYScrollIF[n] += (YScrollI[n] << 8) + YScrollF[n];
     //printf("%d %d %08x: %08x \n", vdp2_line, n, CurLSA[n], CurYScrollIF[n]);
    }
 
    if(sc & 0x8) // X zoom
    {
     CurXCoordInc[n] = (VRAM[CurLSA[n] & 0x3FFFF] & 0x7) << 8;
     CurLSA[n]++;
     CurXCoordInc[n] |= VRAM[CurLSA[n] & 0x3FFFF] >> 8;
     CurLSA[n]++;
    }

    if(InterlaceMode == IM_DOUBLE)
     CurLSA[n] += ((bool)(sc & 0x2) + (bool)(sc & 0x4) + (bool)(sc & 0x8)) << 1;
   }

   if(!(sc & 0x2))
    CurXScrollIF[n] = (XScrollI[n] << 8) + XScrollF[n];

   if(!(sc & 0x4))
    CurYScrollIF[n] = (YScrollI[n] << 8) + YScrollF[n];

   if(!(sc & 0x8))
    CurXCoordInc[n] = XCoordInc[n];
  }

  //
  // Line Window
  //
  {
   for(unsigned d = 0; d < 2; d++)
   {
    if(Window[d].LineWinEn)
    {
     const uint16* vrt = &VRAM[Window[d].CurLineWinAddr & 0x3FFFE];

     Window[d].XStart = vrt[0] & 0x3FF;
     Window[d].XEnd = vrt[1] & 0x3FF;

     //printf("LWin %d, %d(%08x): %04x %04x\n", vdp2_line, d, Window[d].CurLineWinAddr & 0x3FFFE, vrt[0], vrt[1]);
    }
    //
    //
    //
    int32 xs = Window[d].XStart, xe = Window[d].XEnd;

    // FIXME: Kludge, until we can figure out what's going on.
    if(xs >= 0x380)
     xs = 0;

    // FIXME: Kludge, until we can figure out what's going on.
    if(xe >= 0x380)
    {
     xs = 2;
     xe = 0;
    }

    if(!(HRes & 0x2))
    {
     xs >>= 1;
     xe >>= 1;
    }
    Window[d].CurXStart = xs;
    Window[d].CurXEnd = xe;

    Window[d].CurLineWinAddr += 2 << (InterlaceMode == IM_DOUBLE);

    Window[d].YMet = LIB[vdp2_line].win_ymet[d];
    //
    //
    //
   }

   //
   //
   //
   WinPieces[0] = Window[0].CurXStart;
   WinPieces[1] = Window[0].CurXEnd + 1;
   WinPieces[2] = Window[1].CurXStart;
   WinPieces[3] = Window[1].CurXEnd + 1;
   WinPieces[4] = w;

   for(unsigned piece = 0; piece < WinPieces.size(); piece++)
    WinPieces[piece] = std::min<unsigned>(w, WinPieces[piece]);	// Almost forgot to do this...

   std::sort(WinPieces.begin(), WinPieces.end());
  }

  //
  //
  //
  if(vdp2_line == 64)
  {
   //printf("%d:%d, %d:%d (%d) --- %d:%d, %d:%d (%d)\n", Window[0].XStart, Window[0].YStart, Window[0].XEnd, Window[0].YEnd, Window[0].LineWinEn, Window[1].XStart, Window[1].YStart, Window[1].XEnd, Window[1].YEnd, Window[1].LineWinEn);
   //printf("SPCTL_Low: %02x, SDCTL: %03x, SpriteCCCond: %01x, CCNum: %01x -- %01x %01x %01x %01x %01x %01x %01x %01x \n", SPCTL_Low, SDCTL, SpriteCCCond, SpriteCCNum, SpriteCCRatio[0], SpriteCCRatio[1], SpriteCCRatio[2], SpriteCCRatio[3], SpriteCCRatio[4], SpriteCCRatio[5], SpriteCCRatio[6], SpriteCCRatio[7]);
   //printf("WinControl[WINLAYER_CC]=%02x\n", WinControl[WINLAYER_CC]);
  }

  //
  // Process sprite data before NBG0-3 and RBG0-1, but defer applying the window until after NBG and RBG are handled(so the sprite window
  // bit in the sprite linebuffer data isn't trashed prematurely).
  //
  if(MDFN_LIKELY(UserLayerEnableMask & (1U << 6)))
  {
   MakeSpriteCCLUT();
   DrawSpriteData[(HRes & 0x2) >> 0x1][(SDCTL >> 8) & 0x1][SPCTL_Low](LIB[vdp2_line].vdp1_line, LIB[vdp2_line].vdp1_hires8, w);
  }
  else
   MDFN_FastArraySet(LB.spr, 0, w);
  //
  //
  //
  //
  //
  //
  //
  if(BGON & 0x30)
  {
   MDFN_FastArraySet(LB.lc, CurLCColor & 0x7F, rbg_w);
   SetupRotVars(LIB[vdp2_line].rv, rbg_w);
   if(HRes & 0x2)
    Doubleize(LB.lc, rbg_w);

   // RBG0
   if(MDFN_LIKELY(UserLayerEnableMask & 0x10))
   {
    const bool igntp = (BGON >> 12) & 1;
    const bool bmen = (CHCTLB >> 9) & 1;
    const unsigned colornum = std::min<unsigned>(4, (CHCTLB >> 12) & 0x7);	// TODO: Test 5 ... 7
    const unsigned priomode = (SFPRMD >> 8) & 0x3;
    const unsigned ccmode = (CCCTL & 0x10) ? ((SFCCMD >> 8) & 0x3) : 0;
    const uint32 prio = RBG0PrioNum;
    uint32 pix_base_or;

    pix_base_or = ((colornum >= 3) << PIX_ISRGB_SHIFT);
    pix_base_or |= ((ColorOffsEn >> 4) & 1) << PIX_COE_SHIFT;
    pix_base_or |= ((ColorOffsSel >> 4) & 1) << PIX_COSEL_SHIFT;
    pix_base_or |= ((LineColorEn >> 4) & 1) << PIX_LCE_SHIFT;
    pix_base_or |= RBG0CCRatio << PIX_CCRATIO_SHIFT;
    pix_base_or |= (((CCCTL >> 12) & 0x7) == 0x1) << PIX_GRAD_SHIFT;
    pix_base_or |= ((CCCTL >> 4) & 1) << PIX_LAYER_CCE_SHIFT;
    pix_base_or |= ((SDCTL >> 4) & 1) << PIX_SHADEN_SHIFT;

    if(ccmode == 0)
     pix_base_or |= ((CCCTL >> 4) & 1) << PIX_CCE_SHIFT;

    if(priomode >= 1)
     pix_base_or |= ((prio &~ 1) << PIX_PRIO_SHIFT);
    else
     pix_base_or |= (prio << PIX_PRIO_SHIFT);

    DrawRBG[bmen][colornum][igntp][priomode % 3][ccmode](0, LB.rbg0, rbg_w, pix_base_or);
    RBGPP(4, LB.rbg0, rbg_w);
   }
   else
    MDFN_FastArraySet(LB.rbg0, 0, w);

   // RBG1
   if(BGON & UserLayerEnableMask & 0x20)
   {
    const bool igntp = (BGON >> 8) & 1;
    const unsigned colornum = std::min<unsigned>(4, (CHCTLA >> 4) & 0x7);	// TODO: Test 5 ... 7
    const unsigned priomode = (SFPRMD >> 0) & 0x3;
    const unsigned ccmode = (CCCTL & 0x01) ? ((SFCCMD >> 0) & 0x3) : 0;
    const uint32 prio = NBGPrioNum[0];
    uint32 pix_base_or;

    pix_base_or = (false << PIX_ISRGB_SHIFT);
    pix_base_or |= ((ColorOffsEn >> 0) & 1) << PIX_COE_SHIFT;
    pix_base_or |= ((ColorOffsSel >> 0) & 1) << PIX_COSEL_SHIFT;
    pix_base_or |= ((LineColorEn >> 0) & 1) << PIX_LCE_SHIFT;
    pix_base_or |= NBGCCRatio[0] << PIX_CCRATIO_SHIFT;
    pix_base_or |= (((CCCTL >> 12) & 0x7) == 0x2) << PIX_GRAD_SHIFT;
    pix_base_or |= ((CCCTL >> 0) & 1) << PIX_LAYER_CCE_SHIFT;
    pix_base_or |= ((SDCTL >> 0) & 1) << PIX_SHADEN_SHIFT;

    if(ccmode == 0)
     pix_base_or |= ((CCCTL >> 0) & 1) << PIX_CCE_SHIFT;

    if(priomode >= 1)
     pix_base_or |= ((prio &~ 1) << PIX_PRIO_SHIFT);
    else
     pix_base_or |= (prio << PIX_PRIO_SHIFT);

    MDFN_FastArraySet(LB.rotabsel, 1, rbg_w);
    DrawRBG[false][colornum][igntp][priomode % 3][ccmode](1, LB.nbg[0] + 8, rbg_w, pix_base_or);
    RBGPP(0, LB.nbg[0] + 8, rbg_w);
   }
   else if(BGON & 0x20)
    MDFN_FastArraySet(LB.nbg[0] + 8, 0, w);
  }
  else
  {
   MDFN_FastArraySet(LB.lc, CurLCColor & 0x7F, w);
   MDFN_FastArraySet(LB.rbg0, 0, w);
  }
  //
  //
  //
  for(unsigned n = 0; n < 4; n++)
  {
   if(!MosaicVCount || !(MZCTL & (1U << n)))
   {
    if(n < 2)
    {
     MosEff_YCoordAccum[n] = YCoordAccum[n];	// Don't + (InterlaceMode == IM_DOUBLE && field)
    }
    else
    {
     MosEff_NBG23_YCounter[n & 1] = NBG23_YCounter[n & 1] + (InterlaceMode == IM_DOUBLE && field);
    }
   }
  }

  if(SCRCTL & 0x0101)
   FetchVCScroll(w);	// Call after handling line scroll, and before DrawNBG() stuff

  if(!(BGON & 0x20))
  {
   for(unsigned n = 0; n < 4; n++)
   {
    if(((BGON >> n) & 1) && MDFN_LIKELY((UserLayerEnableMask >> n) & 1))
    {
     const bool igntp = (BGON >> (n + 8)) & 1;
     bool bmen = false;
     unsigned colornum;
     unsigned priomode;
     unsigned ccmode;

     if(n < 2)
     {
      const unsigned nshift = (n & 1) << 3;

      bmen = (CHCTLA >> (1 + nshift)) & 1;
      colornum = (CHCTLA >> (4 + nshift)) & (n ? 0x3 : 0x7);
     }
     else	// n >= 2
     {
      const unsigned nshift = (n & 1) << 2;

      colornum = (CHCTLB >> (1 + nshift)) & 1;
     }

     if(colornum > 4) // TODO: test 5 ... 7
      colornum = 4;

     priomode = (SFPRMD >> (n << 1)) & 0x3;
     ccmode = (SFCCMD >> (n << 1)) & 0x3;
     if(!((CCCTL >> n) & 1))
      ccmode = 0;
     //
     //
     const uint32 prio = NBGPrioNum[n];
     uint32 pix_base_or;

     pix_base_or = ((colornum >= 3) << PIX_ISRGB_SHIFT);
     pix_base_or |= ((ColorOffsEn >> n) & 1) << PIX_COE_SHIFT;
     pix_base_or |= ((ColorOffsSel >> n) & 1) << PIX_COSEL_SHIFT;
     pix_base_or |= ((LineColorEn >> n) & 1) << PIX_LCE_SHIFT;
     pix_base_or |= NBGCCRatio[n] << PIX_CCRATIO_SHIFT;
     pix_base_or |= (((CCCTL >> 12) & 0x7) == (3 + n - !n)) << PIX_GRAD_SHIFT;
     pix_base_or |= ((CCCTL >> n) & 1) << PIX_LAYER_CCE_SHIFT;
     pix_base_or |= ((SDCTL >> n) & 1) << PIX_SHADEN_SHIFT;

     if(ccmode == 0)
      pix_base_or |= ((CCCTL >> n) & 1) << PIX_CCE_SHIFT;

     if(priomode >= 1)
      pix_base_or |= ((prio &~ 1) << PIX_PRIO_SHIFT);
     else
      pix_base_or |= (prio << PIX_PRIO_SHIFT);

     if(n < 2)
      DrawNBG[bmen][colornum][igntp][priomode % 3][ccmode](n, LB.nbg[n] + 8, w, pix_base_or);
     else
      DrawNBG23[colornum][igntp][priomode % 3][ccmode](n, LB.nbg[n] + 8, w, pix_base_or);

     ApplyHMosaic(n, LB.nbg[n] + 8, w);
     ApplyWin(n, LB.nbg[n] + 8);
    }
    else
     MDFN_FastArraySet(LB.nbg[n] + 8, 0, w);
   }
  }

  //
  //
  //
  //
  //
  // Apply window to sprite linebuffer after BG layers have windows applied.
  ApplyWin(WINLAYER_SPRITE, LB.spr);

  //
  for(int32 i = 0; i < tvxo; i++)
   target[i] = border_ncf;

  for(int32 i = tvxo + w; i < tvdw; i++)
   target[i] = border_ncf;

  {
   const bool rbg1en = (bool)(BGON & 0x20);
   unsigned special = MIXIT_SPECIAL_NONE;
   const bool CCRTMD = (bool)(CCCTL & 0x0200);
   const bool CCMD = (bool)(CCCTL & 0x0100);
   static const uint64* blurremap[8] = { LB.spr, LB.rbg0, LB.nbg[0] + 8, /*Dummy:*/LB.spr,
					 LB.nbg[1] + 8, LB.nbg[2] + 8, LB.nbg[3] + 8, /*Dummy:*/LB.spr
				       };
   const uint64* blursrc = blurremap[(CCCTL >> 12) & 0x7];

   if(!(HRes & 0x6))
   {
    if(CCCTL & 0x8000)
    {
     if(CRAM_Mode == 0)
      special = MIXIT_SPECIAL_GRAD;
    }
    else if(CCCTL & 0x0400)
    {
     special = 0x2;
     special += (bool)CRAM_Mode;
     special += (CCCTL >> 4) & 0x2;
    }
   }
   MixIt[rbg1en][special][CCRTMD][CCMD](target + tvxo, vdp2_line, w, back_rgb24, blursrc);
   ReorderRGB(target + tvxo, w, espec->surface->format.Rshift, espec->surface->format.Gshift, espec->surface->format.Bshift);
  }

  //
  //
  //
  // FIXME: Timing
  //
  for(unsigned n = 0; n < 2; n++)
  {
   YCoordAccum[n] += YCoordInc[n] << (InterlaceMode == IM_DOUBLE);
   NBG23_YCounter[n & 1] += 1 << (InterlaceMode == IM_DOUBLE);
  }

  if(MosaicVCount >= ((MZCTL >> 12) & 0xF))
   MosaicVCount = 0;
  else
   MosaicVCount++;
 }

 //
 //
 //
 if(DoHBlend)
 {
  espec->LineWidths[out_line] = ApplyHBlend(espec->surface->pixels + out_line * espec->surface->pitchinpix + espec->DisplayRect.x, espec->LineWidths[out_line]);

  // Kind of late, but meh. ;p
  assert((espec->DisplayRect.x + espec->LineWidths[out_line]) <= 704);
 }
}

//
//
//
static MDFN_Thread* RThread = NULL;

enum
{
 COMMAND_WRITE8 = 0,
 COMMAND_WRITE16,

 COMMAND_DRAW_LINE,

 COMMAND_SET_LEM,

 COMMAND_SET_BUSYWAIT,

 COMMAND_RESET,
 COMMAND_EXIT
};

struct WQ_Entry
{
 uint16 Command;
 uint16 Arg16;
 uint32 Arg32;
};

static std::array<WQ_Entry, 0x80000> WQ;
static size_t WQ_ReadPos, WQ_WritePos;
static std::atomic_int_least32_t WQ_InCount;
static std::atomic_int_least32_t DrawCounter;
static bool DoBusyWait;
static MDFN_Sem* WakeupSem;
static bool DoWakeupIfNecessary;

static INLINE void WWQ(uint16 command, uint32 arg32 = 0, uint16 arg16 = 0)
{
 while(MDFN_UNLIKELY(WQ_InCount.load(std::memory_order_acquire) == WQ.size()))
  Time::SleepMS(1);

 WQ_Entry* wqe = &WQ[WQ_WritePos];

 wqe->Command = command;
 wqe->Arg16 = arg16;
 wqe->Arg32 = arg32;

 WQ_WritePos = (WQ_WritePos + 1) % WQ.size();
 WQ_InCount.fetch_add(1, std::memory_order_release);
}

static int RThreadEntry(void* data)
{
 bool Running = true;

 while(MDFN_LIKELY(Running))
 {
  while(MDFN_UNLIKELY(WQ_InCount.load(std::memory_order_acquire) == 0))
  {
   if(!DoBusyWait)
    MDFND_WaitSemTimeout(WakeupSem, 1);
   else
   {
    for(int i = 1000; i; i--)
    {
     #ifdef _MSC_VER
     __nop();
     #else
     asm volatile("nop\n\t");
     #endif
    }
   }
  }
  //
  //
  //
  WQ_Entry* wqe = &WQ[WQ_ReadPos];

  switch(wqe->Command)
  {
   case COMMAND_WRITE8:
	MemW<uint8>(wqe->Arg32, wqe->Arg16);
	break;

   case COMMAND_WRITE16:
	MemW<uint16>(wqe->Arg32, wqe->Arg16);
	break;

   case COMMAND_DRAW_LINE:
	//for(unsigned i = 0; i < 2; i++)
	DrawLine((uint16)wqe->Arg32, wqe->Arg32 >> 16, wqe->Arg16);
	//
	DrawCounter.fetch_sub(1, std::memory_order_release);
	break;

   case COMMAND_RESET:
	Reset(wqe->Arg32);
	break;

   case COMMAND_SET_LEM:
	UserLayerEnableMask = wqe->Arg32;
	break;

   case COMMAND_SET_BUSYWAIT:
	DoBusyWait = wqe->Arg32;
	break;

   case COMMAND_EXIT:
	Running = false;
	break;
  }
  //
  //
  //
  WQ_ReadPos = (WQ_ReadPos + 1) % WQ.size();
  WQ_InCount.fetch_sub(1, std::memory_order_release);
 }

 return 0;
}


//
//
//
//
//
void VDP2REND_Init(const bool IsPAL)
{
 PAL = IsPAL;
 VisibleLines = PAL ? 288 : 240;
 //
 UserLayerEnableMask = ~0U;

 //
 WQ_ReadPos = 0;
 WQ_WritePos = 0;
 WQ_InCount.store(0, std::memory_order_release); 
 DrawCounter.store(0, std::memory_order_release);

 WakeupSem = MDFND_CreateSem();
 RThread = MDFND_CreateThread(RThreadEntry, NULL);
}

// Needed for ss.correct_aspect == 0
void VDP2REND_GetGunXTranslation(const bool clock28m, float* scale, float* offs)
{
 *scale = 1.0;
 *offs = 0.0;

 if(!CorrectAspect && !clock28m)
 {
  *scale = 65.0 / 61.0;
  *offs = -(21472 - (21472.0 / 65 * 61)) * 0.5;
 }
}

void VDP2REND_SetGetVideoParams(MDFNGI* gi, const bool caspect, const int sls, const int sle, const bool show_h_overscan, const bool dohblend)
{
 CorrectAspect = caspect;
 ShowHOverscan = show_h_overscan;
 DoHBlend = dohblend;
 LineVisFirst = sls;
 LineVisLast = sle;
 //
 //
 //
 gi->fb_width = 704;

 if(PAL)
 {
  gi->nominal_width = (ShowHOverscan ? 365 : 354);
  gi->fb_height = 576;
 }
 else
 {
  gi->nominal_width = (ShowHOverscan ? 302 : 292);
  gi->fb_height = 480;
 }
 gi->nominal_height = LineVisLast + 1 - LineVisFirst;

 gi->lcm_width = (ShowHOverscan? 10560 : 10240);
 gi->lcm_height = (LineVisLast + 1 - LineVisFirst) * 2;

 gi->mouse_scale_x = (float)(ShowHOverscan? 21472 : 20821);
 gi->mouse_offs_x = (float)(ShowHOverscan? 0 : 651) / 2;
 gi->mouse_scale_y = gi->nominal_height;
 gi->mouse_offs_y = LineVisFirst;
 //
 //
 //
 if(!CorrectAspect)
 {
  gi->nominal_width = (ShowHOverscan ? 352 : 341);
  gi->lcm_width = gi->nominal_width * 2;

  gi->mouse_scale_x = (float)(ShowHOverscan? 21472 : 20821);
  gi->mouse_offs_x = (float)(ShowHOverscan? 0 : 651) / 2;
 }
}

void VDP2REND_Kill(void)
{
 if(RThread != NULL)
 {
  WWQ(COMMAND_EXIT);
  MDFND_WaitThread(RThread, NULL);
 }

 if(WakeupSem != NULL)
 {
  MDFND_DestroySem(WakeupSem);
  WakeupSem = NULL;
 }
}

void VDP2REND_StartFrame(EmulateSpecStruct* espec_arg, const bool clock28m, const int SurfInterlaceField)
{
 NextOutLine = 0;
 Clock28M = clock28m;

 espec = espec_arg;

 if(SurfInterlaceField >= 0)
 {
  espec->LineWidths[0] = 0;
  espec->InterlaceOn = true;
  espec->InterlaceField = SurfInterlaceField;
 }
 else
  espec->InterlaceOn = false;

 espec->DisplayRect.x = (ShowHOverscan ? 0 : 10);
 espec->DisplayRect.y = LineVisFirst << espec->InterlaceOn;
 espec->DisplayRect.w = 0;
 espec->DisplayRect.h = (LineVisLast + 1 - LineVisFirst) << espec->InterlaceOn;
}

void VDP2REND_EndFrame(void)
{
 while(MDFN_UNLIKELY(DrawCounter.load(std::memory_order_acquire) != 0))
 {
  //fprintf(stderr, "SLEEEEP\n");
  //Time::SleepMS(1);
 }

 WWQ(COMMAND_SET_BUSYWAIT, false);

 if(NextOutLine < VisibleLines)
 {
  //printf("OutLineCounter(%d) < VisibleLines(%d)\n", OutLineCounter, VisibleLines);
  do
  {
   uint16 out_line = NextOutLine;
   uint32* target;

   if(espec->InterlaceOn)
    out_line = (out_line << 1) | espec->InterlaceField;

   target = espec->surface->pixels + out_line * espec->surface->pitchinpix;
   target[0] = target[1] = target[2] = target[3] = espec->surface->MakeColor(0, 0, 0);
   espec->LineWidths[out_line] = 4;
  } while(++NextOutLine < VisibleLines);
 }

 espec = NULL;
}

VDP2Rend_LIB* VDP2REND_GetLIB(unsigned line)
{
 assert(line < (PAL ? 256 : 240)); // NO: VisibleLines);

 return &LIB[line];
}

void VDP2REND_DrawLine(const int vdp2_line, const uint32 crt_line, const bool field)
{
 const unsigned bwthresh = VisibleLines - 48;

 if(MDFN_LIKELY(crt_line < VisibleLines))
 {
  uint16 out_line = crt_line;

  if(espec->InterlaceOn)
   out_line = (out_line << 1) | espec->InterlaceField;

  auto wdcq = DrawCounter.fetch_add(1, std::memory_order_release);
  WWQ(COMMAND_DRAW_LINE, ((uint16)vdp2_line << 16) | out_line, field);
  //
  //
  if(crt_line == bwthresh)
  {
   WWQ(COMMAND_SET_BUSYWAIT, true);
   MDFND_PostSem(WakeupSem);
  }
  else if(crt_line < bwthresh)
  {
   if(wdcq == 0)
    DoWakeupIfNecessary = true;
   else if((wdcq + 1) >= 64 && DoWakeupIfNecessary)
   {
    //printf("Post Wakeup: %3d --- crt_line=%3d\n", wdcq + 1, crt_line);
    MDFND_PostSem(WakeupSem);
    DoWakeupIfNecessary = false;
   }
  }

  NextOutLine = crt_line + 1;
 }
}

void VDP2REND_Reset(bool powering_up)
{
 WWQ(COMMAND_RESET, powering_up);
}

void VDP2REND_SetLayerEnableMask(uint64 mask)
{
 WWQ(COMMAND_SET_LEM, mask);
}

void VDP2REND_Write8_DB(uint32 A, uint16 DB)
{
 //if(DrawCounter.load(std::memory_order_acquire) != 0)
  WWQ(COMMAND_WRITE8, A, DB);
 //else
 // MemW<uint8>(A, DB);
}

void VDP2REND_Write16_DB(uint32 A, uint16 DB)
{
 //if(DrawCounter.load(std::memory_order_acquire) != 0)
  WWQ(COMMAND_WRITE16, A, DB);
 //else
 // MemW<uint16>(A, DB);
}

void VDP2REND_StateAction(StateMem* sm, const unsigned load, const bool data_only, uint16 (&rr)[0x100], uint16 (&cr)[2048], uint16 (&vr)[262144])
{
 while(MDFN_UNLIKELY(WQ_InCount.load(std::memory_order_acquire) != 0))
  Time::SleepMS(1);
 //
 //
 //
 SFORMAT StateRegs[] =
 {
  SFVAR(Clock28M),	// DUBIOUS

  SFVAR(MosaicVCount),

  SFVAR(VCLast),

  SFVAR(YCoordAccum),
  SFVAR(MosEff_YCoordAccum),

  SFVAR(CurXScrollIF),
  SFVAR(CurYScrollIF),
  SFVAR(CurXCoordInc),
  SFVAR(CurLSA),

  SFVAR(NBG23_YCounter),
  SFVAR(MosEff_NBG23_YCounter),

  SFVAR(CurBackTabAddr),
  SFVAR(CurBackColor),

  SFVAR(CurLCTabAddr),
  SFVAR(CurLCColor),

  // XStart and XEnd can be modified by line window processing.
  SFVAR(Window->XStart, 2, sizeof(*Window), Window),
  SFVAR(Window->XEnd, 2, sizeof(*Window), Window),
  SFVAR(Window->CurXStart, 2, sizeof(*Window), Window),
  SFVAR(Window->CurXEnd, 2, sizeof(*Window), Window),
  SFVAR(Window->CurLineWinAddr, 2, sizeof(*Window), Window),

  SFEND
 };

 // Calls to RegsWrite() should go before MDFNSS_StateAction(), and before memcpy() to VRAM and CRAM.
 if(load)
 {
  for(unsigned i = 0; i < 0x100; i++)
  {
   RegsWrite(i << 1, rr[i]);
  }
 }

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "VDP2REND");

 if(load)
 {
  memcpy(VRAM, vr, sizeof(VRAM));
  memcpy(CRAM, cr, sizeof(CRAM));

  RecalcColorCache();
 }
}

}
