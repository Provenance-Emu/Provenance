/* Mednafen - Multi-system Emulator
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

template<int BlendMode, bool MaskEval_TA, bool textured>
INLINE void PS_GPU::PlotPixel(uint32 x, uint32 y, uint16 fore_pix)
{
 y &= 511;	// More Y precision bits than GPU RAM installed in (non-arcade, at least) Playstation hardware.

 if(BlendMode >= 0 && (fore_pix & 0x8000))
 {
  uint16 bg_pix = GPURAM[y][x];	// Don't use bg_pix for mask evaluation, it's modified in blending code paths.
  uint16 pix; // = fore_pix & 0x8000;

/*
 static const int32 tab[4][2] =
 {
  { 2,  2 },
  { 4,  4 },
  { 4, -4 },
  { 4,  1 }
 };
*/
  // Efficient 15bpp pixel math algorithms from blargg
  switch(BlendMode)
  {
   case 0:
	bg_pix |= 0x8000;
	pix = ((fore_pix + bg_pix) - ((fore_pix ^ bg_pix) & 0x0421)) >> 1;
	break;
	  
   case 1:
       {
	bg_pix &= ~0x8000;

	uint32 sum = fore_pix + bg_pix;
	uint32 carry = (sum - ((fore_pix ^ bg_pix) & 0x8421)) & 0x8420;

	pix = (sum - carry) | (carry - (carry >> 5));
       }
       break;

   case 2:
       {
	bg_pix |= 0x8000;
        fore_pix &= ~0x8000;

	uint32 diff = bg_pix - fore_pix + 0x108420;
	uint32 borrow = (diff - ((bg_pix ^ fore_pix) & 0x108420)) & 0x108420;

	pix = (diff - borrow) & (borrow - (borrow >> 5));
       }
       break;

   case 3:
       {
	bg_pix &= ~0x8000;
	fore_pix = ((fore_pix >> 2) & 0x1CE7) | 0x8000;

	uint32 sum = fore_pix + bg_pix;
	uint32 carry = (sum - ((fore_pix ^ bg_pix) & 0x8421)) & 0x8420;

	pix = (sum - carry) | (carry - (carry >> 5));
       }
       break;
  }

  if(!MaskEval_TA || !(GPURAM[y][x] & 0x8000))
   GPURAM[y][x] = (textured ? pix : (pix & 0x7FFF)) | MaskSetOR;
 }
 else
 {
  if(!MaskEval_TA || !(GPURAM[y][x] & 0x8000))
   GPURAM[y][x] = (textured ? fore_pix : (fore_pix & 0x7FFF)) | MaskSetOR;
 }
}

INLINE uint16 PS_GPU::ModTexel(uint16 texel, int32 r, int32 g, int32 b, const int32 dither_x, const int32 dither_y)
{
 uint16 ret = texel & 0x8000;

 ret |= DitherLUT[dither_y][dither_x][(((texel & 0x1F) * r) >> (5 - 1))] << 0;
 ret |= DitherLUT[dither_y][dither_x][(((texel & 0x3E0) * g) >> (10 - 1))] << 5;
 ret |= DitherLUT[dither_y][dither_x][(((texel & 0x7C00) * b) >> (15 - 1))] << 10;

 return(ret);
}

template<uint32 TexMode_TA>
INLINE void PS_GPU::Update_CLUT_Cache(uint16 raw_clut)
{
 if(TexMode_TA < 2)
 {
  const uint32 new_ccvb = ((raw_clut & 0x7FFF) | (TexMode_TA << 16));	// Confirmed upper bit of raw_clut is ignored(at least on SCPH-5501's GPU).

  if(CLUT_Cache_VB != new_ccvb)
  {
   uint16* const gpulp = GPURAM[(raw_clut >> 6) & 0x1FF];
   const uint32 cxo = (raw_clut & 0x3F) << 4;
   const uint32 count = (TexMode_TA ? 256 : 16);

   DrawTimeAvail -= count;

   for(unsigned i = 0; i < count; i++)
   {
    CLUT_Cache[i] = gpulp[(cxo + i) & 0x3FF];
   }

   CLUT_Cache_VB = new_ccvb;
  }
 }
}

#if 0
 TexWindowX_AND = ~(tww << 3);
 TexWindowX_ADD = ((twx & tww) << 3;

 TexWindowY_AND = ~(twh << 3);
 TexWindowY_OR = (twy & twh) << 3;

     uint32 u = (u_arg & TexWindowX_AND)  TexWindowX_OR;
     uint32 v = (v_arg & TexWindowY_AND) | TexWindowY_OR;
     uint32 fbtex_x = TexPageX + (u >> (2 - TexMode_TA));
     uint32 fbtex_y = TexPageY + v;
     uint16 fbw = GPURAM[fbtex_y][fbtex_x & 1023];

     if(TexMode_TA != 2)
     {
      if(TexMode_TA == 0)
       fbw = (fbw >> ((u & 3) * 4)) & 0xF;
      else
       fbw = (fbw >> ((u & 1) * 8)) & 0xFF;
 
      fbw = CLUT_Cache[fbw];
     }
#endif

INLINE void PS_GPU::RecalcTexWindowStuff(void)
{
 SUCV.TWX_AND = ~(tww << 3);
 SUCV.TWX_ADD = ((twx & tww) << 3) + (TexPageX << (2 - std::min<uint32>(2, TexMode)));

 SUCV.TWY_AND = ~(twh << 3);
 SUCV.TWY_ADD = ((twy & twh) << 3) + TexPageY;
}

template<uint32 TexMode_TA>
INLINE uint16 PS_GPU::GetTexel(uint32 u_arg, uint32 v_arg)
{
     static_assert(TexMode_TA <= 2, "TexMode_TA must be <= 2");

     uint32 u_ext = ((u_arg & SUCV.TWX_AND) + SUCV.TWX_ADD);
     uint32 fbtex_x = ((u_ext >> (2 - TexMode_TA))) & 1023;
     uint32 fbtex_y = (v_arg & SUCV.TWY_AND) + SUCV.TWY_ADD;
     uint32 gro = fbtex_y * 1024U + fbtex_x;

     decltype(&TexCache[0]) c;

     switch(TexMode_TA)
     {
      case 0: c = &TexCache[((gro >> 2) & 0x3) | ((gro >> 8) & 0xFC)]; break;	// 64x64
      case 1: c = &TexCache[((gro >> 2) & 0x7) | ((gro >> 7) & 0xF8)]; break;	// 64x32 (NOT 32x64!)
      case 2: c = &TexCache[((gro >> 2) & 0x7) | ((gro >> 7) & 0xF8)]; break;	// 32x32
     }

     if(MDFN_UNLIKELY(c->Tag != (gro &~ 0x3)))
     {
      // SCPH-1001 old revision GPU is like(for sprites at least): (20 + 4)
      // SCPH-5501 new revision GPU is like(for sprites at least): (12 + 4)
      //
      // We'll be conservative and just go with 4 for now, until we can run some tests with triangles too.
      //
      DrawTimeAvail -= 4;
      c->Data[0] = (&GPURAM[0][0])[gro &~ 0x3];
      c->Data[1] = (&GPURAM[0][1])[gro &~ 0x3];
      c->Data[2] = (&GPURAM[0][2])[gro &~ 0x3];
      c->Data[3] = (&GPURAM[0][3])[gro &~ 0x3];
      c->Tag = (gro &~ 0x3);
     }

     uint16 fbw = c->Data[gro & 0x3];

     if(TexMode_TA != 2)
     {
      if(TexMode_TA == 0)
       fbw = (fbw >> ((u_ext & 3) * 4)) & 0xF;
      else
       fbw = (fbw >> ((u_ext & 1) * 8)) & 0xFF;
 
      fbw = CLUT_Cache[fbw];
     }

     return(fbw);
}

INLINE bool PS_GPU::LineSkipTest(unsigned y)
{
 //DisplayFB_XStart >= OffsX && DisplayFB_YStart >= OffsY &&
 // ((y & 1) == (DisplayFB_CurLineYReadout & 1))

 if((DisplayMode & 0x24) != 0x24)
  return false;

 if(!dfe && ((y & 1) == ((DisplayFB_YStart + field_ram_readout) & 1))/* && !DisplayOff*/) //&& (y >> 1) >= DisplayFB_YStart && (y >> 1) < (DisplayFB_YStart + (VertEnd - VertStart)))
  return true;

 return false;
}


//
// Command table generation macros follow:
//

//#define BM_HELPER(fg) { fg(0), fg(1), fg(2), fg(3) }

#define POLY_HELPER_SUB(bm, cv, tm, mam)	\
	 G_Command_DrawPolygon<3 + ((cv & 0x8) >> 3), ((cv & 0x10) >> 4), ((cv & 0x4) >> 2), ((cv & 0x2) >> 1) ? bm : -1, ((cv & 1) ^ 1) & ((cv & 0x4) >> 2), tm, mam >

#define POLY_HELPER_FG(bm, cv)						\
	 {								\
		POLY_HELPER_SUB(bm, cv, ((cv & 0x4) ? 0 : 0), 0),	\
		POLY_HELPER_SUB(bm, cv, ((cv & 0x4) ? 1 : 0), 0),	\
		POLY_HELPER_SUB(bm, cv, ((cv & 0x4) ? 2 : 0), 0),	\
		POLY_HELPER_SUB(bm, cv, ((cv & 0x4) ? 2 : 0), 0),	\
		POLY_HELPER_SUB(bm, cv, ((cv & 0x4) ? 0 : 0), 1),	\
		POLY_HELPER_SUB(bm, cv, ((cv & 0x4) ? 1 : 0), 1),	\
		POLY_HELPER_SUB(bm, cv, ((cv & 0x4) ? 2 : 0), 1),	\
		POLY_HELPER_SUB(bm, cv, ((cv & 0x4) ? 2 : 0), 1),	\
	 }

#define POLY_HELPER(cv)														\
	{ 															\
	 { POLY_HELPER_FG(0, cv), POLY_HELPER_FG(1, cv), POLY_HELPER_FG(2, cv), POLY_HELPER_FG(3, cv) },			\
	 1 + (3 /*+ ((cv & 0x8) >> 3)*/) * ( 1 + ((cv & 0x4) >> 2) + ((cv & 0x10) >> 4) ) - ((cv & 0x10) >> 4),			\
	 1,															\
 	 false															\
	}

//
//

#define SPR_HELPER_SUB(bm, cv, tm, mam) G_Command_DrawSprite<(cv >> 3) & 0x3,	((cv & 0x4) >> 2), ((cv & 0x2) >> 1) ? bm : -1, ((cv & 1) ^ 1) & ((cv & 0x4) >> 2), tm, mam>

#define SPR_HELPER_FG(bm, cv)						\
	 {								\
		SPR_HELPER_SUB(bm, cv, ((cv & 0x4) ? 0 : 0), 0),	\
		SPR_HELPER_SUB(bm, cv, ((cv & 0x4) ? 1 : 0), 0),	\
		SPR_HELPER_SUB(bm, cv, ((cv & 0x4) ? 2 : 0), 0),	\
		SPR_HELPER_SUB(bm, cv, ((cv & 0x4) ? 2 : 0), 0),	\
		SPR_HELPER_SUB(bm, cv, ((cv & 0x4) ? 0 : 0), 1),	\
		SPR_HELPER_SUB(bm, cv, ((cv & 0x4) ? 1 : 0), 1),	\
		SPR_HELPER_SUB(bm, cv, ((cv & 0x4) ? 2 : 0), 1),	\
		SPR_HELPER_SUB(bm, cv, ((cv & 0x4) ? 2 : 0), 1),	\
	 }


#define SPR_HELPER(cv)												\
	{													\
	 { SPR_HELPER_FG(0, cv), SPR_HELPER_FG(1, cv), SPR_HELPER_FG(2, cv), SPR_HELPER_FG(3, cv) },		\
	 2 + ((cv & 0x4) >> 2) + ((cv & 0x18) ? 0 : 1),								\
	 2 | ((cv & 0x4) >> 2) | ((cv & 0x18) ? 0 : 1),		/* |, not +, for this */			\
	 false													\
	}

//
//

#define LINE_HELPER_SUB(bm, cv, mam) G_Command_DrawLine<((cv & 0x08) >> 3), ((cv & 0x10) >> 4), ((cv & 0x2) >> 1) ? bm : -1, mam>

#define LINE_HELPER_FG(bm, cv)											\
	 {													\
		LINE_HELPER_SUB(bm, cv, 0),									\
		LINE_HELPER_SUB(bm, cv, 0),									\
		LINE_HELPER_SUB(bm, cv, 0),									\
		LINE_HELPER_SUB(bm, cv, 0),									\
		LINE_HELPER_SUB(bm, cv, 1),									\
		LINE_HELPER_SUB(bm, cv, 1),									\
		LINE_HELPER_SUB(bm, cv, 1),									\
		LINE_HELPER_SUB(bm, cv, 1)									\
	 }

#define LINE_HELPER(cv)												\
	{ 													\
	 { LINE_HELPER_FG(0, cv), LINE_HELPER_FG(1, cv), LINE_HELPER_FG(2, cv), LINE_HELPER_FG(3, cv) },	\
	 3 + ((cv & 0x10) >> 4),										\
	 1,													\
	 false													\
	}

//
//


#define OTHER_HELPER_FG(bm, arg_ptr) { arg_ptr, arg_ptr, arg_ptr, arg_ptr, arg_ptr, arg_ptr, arg_ptr, arg_ptr }
#define OTHER_HELPER(arg_cs, arg_fbcs, arg_ss, arg_ptr) { { OTHER_HELPER_FG(0, arg_ptr), OTHER_HELPER_FG(1, arg_ptr), OTHER_HELPER_FG(2, arg_ptr), OTHER_HELPER_FG(3, arg_ptr) }, arg_cs, arg_fbcs, arg_ss }
#define OTHER_HELPER_X2(arg_cs, arg_fbcs, arg_ss, arg_ptr)	OTHER_HELPER(arg_cs, arg_fbcs, arg_ss, arg_ptr), OTHER_HELPER(arg_cs, arg_fbcs, arg_ss, arg_ptr)
#define OTHER_HELPER_X4(arg_cs, arg_fbcs, arg_ss, arg_ptr)	OTHER_HELPER_X2(arg_cs, arg_fbcs, arg_ss, arg_ptr), OTHER_HELPER_X2(arg_cs, arg_fbcs, arg_ss, arg_ptr)
#define OTHER_HELPER_X8(arg_cs, arg_fbcs, arg_ss, arg_ptr)	OTHER_HELPER_X4(arg_cs, arg_fbcs, arg_ss, arg_ptr), OTHER_HELPER_X4(arg_cs, arg_fbcs, arg_ss, arg_ptr)
#define OTHER_HELPER_X16(arg_cs, arg_fbcs, arg_ss, arg_ptr)	OTHER_HELPER_X8(arg_cs, arg_fbcs, arg_ss, arg_ptr), OTHER_HELPER_X8(arg_cs, arg_fbcs, arg_ss, arg_ptr)
#define OTHER_HELPER_X32(arg_cs, arg_fbcs, arg_ss, arg_ptr)	OTHER_HELPER_X16(arg_cs, arg_fbcs, arg_ss, arg_ptr), OTHER_HELPER_X16(arg_cs, arg_fbcs, arg_ss, arg_ptr)

#define NULLCMD_FG(bm) { NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL } 
#define NULLCMD() { { NULLCMD_FG(0), NULLCMD_FG(1), NULLCMD_FG(2), NULLCMD_FG(3) }, 1, 1, true }

