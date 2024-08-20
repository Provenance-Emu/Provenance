/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* vdp1_common.h:
**  Copyright (C) 2015-2020 Mednafen Team
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

#ifndef __MDFN_SS_VDP1_COMMON_H
#define __MDFN_SS_VDP1_COMMON_H

namespace MDFN_IEN_SS
{

namespace VDP1
{

enum : int { VDP1_SuspendResumeThreshold = 1000 };
static_assert(VDP1_SuspendResumeThreshold >= 1, "out of acceptable range");

int32 CMD_NormalSprite(const uint16*);
int32 CMD_ScaledSprite(const uint16*);
int32 CMD_DistortedSprite(const uint16*);
int32 RESUME_Sprite(const uint16*);

int32 CMD_Polygon(const uint16*);
int32 RESUME_Polygon(const uint16*);

int32 CMD_Polyline(const uint16*);
int32 CMD_Line(const uint16*);
int32 RESUME_Line(const uint16*);

MDFN_HIDE extern uint16 VRAM[0x40000];
MDFN_HIDE extern uint16 FB[2][0x20000];
MDFN_HIDE extern uint16* FBDrawWhichPtr;

MDFN_HIDE extern int32 SysClipX, SysClipY;
MDFN_HIDE extern int32 UserClipX0, UserClipY0, UserClipX1, UserClipY1;
MDFN_HIDE extern int32 LocalX, LocalY;

MDFN_HIDE extern uint32 (MDFN_FASTCALL *const TexFetchTab[0x20])(uint32 x);

enum { TVMR_8BPP   = 0x1 };
enum { TVMR_ROTATE = 0x2 };
enum { TVMR_HDTV   = 0x4 };
enum { TVMR_VBE    = 0x8 };
MDFN_HIDE extern uint8 TVMR;

enum { FBCR_FCT	   = 0x01 };	// Frame buffer change trigger
enum { FBCR_FCM	   = 0x02 };	// Frame buffer change mode
enum { FBCR_DIL	   = 0x04 };	// Double interlace draw line(0=even, 1=odd) (does it affect drawing to FB RAM or reading from FB RAM to VDP2?)
enum { FBCR_DIE	   = 0x08 };	// Double interlace enable
enum { FBCR_EOS	   = 0x10 };	// Even/Odd coordinate select(0=even, 1=odd, used with HSS)
MDFN_HIDE extern uint8 FBCR;

MDFN_HIDE extern uint8 spr_w_shift_tab[8];
MDFN_HIDE extern uint8 gouraud_lut[0x40];

struct GourauderTheTerrible
{
 void Setup(const unsigned length, const uint16 gstart, const uint16 gend)
 {
  g = gstart & 0x7FFF;
  intinc = 0;

  for(unsigned cc = 0; cc < 3; cc++)
  {
   const int dg = ((gend >> (cc * 5)) & 0x1F) - ((gstart >> (cc * 5)) & 0x1F);
   const unsigned abs_dg = abs(dg);

   ginc[cc] = (uint32)((dg >= 0) ? 1 : -1) << (cc * 5);

   if(length <= abs_dg)
   {
    error_inc[cc] = (abs_dg + 1) * 2;
    error_adj[cc] = (length * 2);
    error[cc] = abs_dg + 1 - (length * 2 + ((dg < 0) ? 1 : 0));

    while(error[cc] >= 0) { g += ginc[cc]; error[cc] -= error_adj[cc]; }
    while(error_inc[cc] >= error_adj[cc]) { intinc += ginc[cc]; error_inc[cc] -= error_adj[cc]; }
   }
   else
   {
    error_inc[cc] = abs_dg * 2;
    error_adj[cc] = ((length - 1) * 2);
    error[cc] = length - (length * 2 - ((dg < 0) ? 1 : 0));
    if(error[cc] >= 0) { g += ginc[cc]; error[cc] -= error_adj[cc]; }
    if(error_inc[cc] >= error_adj[cc]) { intinc += ginc[cc]; error_inc[cc] -= error_adj[cc]; }
   }
   error[cc] = ~error[cc];
  }
 }

 inline uint32 Current(void)
 {
  return g;
 }

 inline uint16 Apply(uint16 pix) const
 {
  uint16 ret = pix & 0x8000;

  ret |= gouraud_lut[((pix & (0x1F <<  0)) + (g & (0x1F <<  0))) >>  0] <<  0;
  ret |= gouraud_lut[((pix & (0x1F <<  5)) + (g & (0x1F <<  5))) >>  5] <<  5;
  ret |= gouraud_lut[((pix & (0x1F << 10)) + (g & (0x1F << 10))) >> 10] << 10;

  return ret;
 }

 inline void Step(void)
 {
  g += intinc;

  for(unsigned cc = 0; cc < 3; cc++)
  {
   error[cc] -= error_inc[cc];
   {
    const uint32 mask = (int32)error[cc] >> 31;
    g += ginc[cc] & mask;
    error[cc] += error_adj[cc] & mask;
   }
  }
 }

 uint32 g;
 uint32 intinc;
 int32 ginc[3];
 int32 error[3];
 int32 error_inc[3];
 int32 error_adj[3];
};

struct VileTex
{
 INLINE bool Setup(const unsigned length, const int32 tstart, const int32 tend, const int32 sf = 1, const int32 tfudge = 0)
 {
  int dt = tend - tstart;
  unsigned abs_dt = abs(dt);

  t = (tstart * sf) | tfudge;

  tinc = (dt >= 0) ? sf : -sf;

  if(length <= abs_dt)
  {
   error_inc = (abs_dt + 1) * 2;
   error_adj = (length * 2);
   error = abs_dt + 1 - (length * 2 + ((dt < 0) ? 1 : 0));
  }
  else
  {
   error_inc = abs_dt * 2;
   error_adj = ((length - 1) * 2);
   error = length - (length * 2 - ((dt < 0) ? 1 : 0));
  }

  return false;
 }

 //
 //
 //
 INLINE bool IncPending(void) { return error >= 0; }
 INLINE int32 DoPendingInc(void) { t += tinc; error -= error_adj; return t; }
 INLINE void AddError(void) { error += error_inc; }
 //
 //
 //

 INLINE int32 PreStep(void)
 {
  while(error >= 0)
  {
   t += tinc;
   error -= error_adj;
  }
  error += error_inc;

  return t;
 }

 INLINE int32 Current(void)
 {
  return t;
 }

 int32 t;
 int32 tinc;
 int32 error;
 int32 error_inc;
 int32 error_adj;
};

//
//
//
template<bool die, unsigned bpp8, bool MSBOn, bool UserClipEn, bool UserClipMode, bool MeshEn, bool GouraudEn, bool HalfFGEn, bool HalfBGEn>
static INLINE int32 PlotPixel(int32 x, int32 y, uint16 pix, bool transparent, GourauderTheTerrible* g)
{
 //printf("%d %d %d %d %d %d %d\n", bpp8, die, MeshEn, MSBOn, GouraudEn, HalfFGEn, HalfBGEn);
 static_assert(!MSBOn || (!HalfFGEn && !HalfBGEn), "Table error; sub-optimal template arguments.");
 int32 ret = 0;
 uint16* fbyptr;

 if(die)
 {
  fbyptr = &FBDrawWhichPtr[((y >> 1) & 0xFF) << 9];
  transparent |= ((y & 1) != (bool)(FBCR & FBCR_DIL));
 }
 else
 {
  fbyptr = &FBDrawWhichPtr[(y & 0xFF) << 9];
 }

 if(MeshEn)
  transparent |= (x ^ y) & 1;

 if(bpp8)
 {
  if(MSBOn)
  {
   pix = (fbyptr[((x >> 1) & 0x1FF)] | 0x8000) >> (((x & 1) ^ 1) << 3);
   ret += 5;
  }
  else if(HalfBGEn)
   ret += 5;

  if(!transparent)
  {
   if(bpp8 == 2)	// BPP8 + rotated
    ne16_wbo_be<uint8>(fbyptr, (x & 0x1FF) | ((y & 0x100) << 1), pix);
   else
    ne16_wbo_be<uint8>(fbyptr, x & 0x3FF, pix);
  }
  ret++;
 }
 else
 {
  uint16* const p = &fbyptr[x & 0x1FF];

  if(MSBOn)
  {
   pix = *p | 0x8000;
   ret += 5;
  }
  else
  {
   if(HalfBGEn)
   {
    uint16 bg_pix = *p;
    ret += 5;

    if(bg_pix & 0x8000)
    {
     if(HalfFGEn)
     {
      if(GouraudEn)
       pix = g->Apply(pix);

      pix = ((pix + bg_pix) - ((pix ^ bg_pix) & 0x8421)) >> 1;
     }
     else
     {
      if(GouraudEn)
       pix = 0;
      else
       pix = ((bg_pix & 0x7BDE) >> 1) | (bg_pix & 0x8000); 
     }
    }
    else
    {
     if(HalfFGEn)
     {
      if(GouraudEn)
       pix = g->Apply(pix);
      else
       pix = pix;
     }
     else
     {
      if(GouraudEn)
       pix = 0;
      else
       pix = bg_pix;
     }
    }
   }
   else
   {
    if(GouraudEn)
     pix = g->Apply(pix);

    if(HalfFGEn)
     pix = ((pix & 0x7BDE) >> 1) | (pix & 0x8000);
   }
  }

  if(!transparent)
   *p = pix;

  ret++;
 }

 return ret;
}
//
//
struct line_vertex
{
 int32 x, y;
 uint16 g;
 int32 t;
};

struct EdgeStepper
{
 void Setup(const bool gourauden, const line_vertex& p0, const line_vertex& p1, const int32 dmax);

 template<bool gourauden>
 INLINE void GetVertex(line_vertex* p)
 {
  p->x = x;
  p->y = y;

  if(gourauden)
   p->g = g.Current();
 }

 template<bool gourauden>
 INLINE void Step(void)
 {
  d_error += d_error_inc;
  if((int32)d_error >= d_error_cmp)
  {
   d_error += d_error_adj;

   x_error += x_error_inc;
   {
    const uint32 x_mask = -((int32)x_error >= x_error_cmp);
    x += x_inc & x_mask;
    x_error += x_error_adj & x_mask;
   }

   y_error += y_error_inc;
   {
    const uint32 y_mask = -((int32)y_error >= y_error_cmp);
    y += y_inc & y_mask;
    y_error += y_error_adj & y_mask;
   }

   if(gourauden)
    g.Step();
  }
 }

 uint32 d_error, d_error_inc, d_error_adj;
 int32 d_error_cmp;

 uint32 x, x_inc;
 uint32 x_error, x_error_inc, x_error_adj;
 int32 x_error_cmp;

 uint32 y, y_inc;
 uint32 y_error, y_error_inc, y_error_adj;
 int32 y_error_cmp;

 GourauderTheTerrible g;
};

struct line_inner_data
{
 uint32 xy;
 uint32 error;
 bool drawn_ac;

 uint32 texel; // must be 32-bit
 VileTex t;
 GourauderTheTerrible g;
 //
 //
 //
 int32 x_inc;
 int32 y_inc;
 uint32 aa_xy_inc;
 uint32 term_xy;

 int32 error_cmp;
 uint32 error_inc;
 uint32 error_adj;

 uint16 color;

 bool abs_dy_gt_abs_dx;
};

struct line_data
{
 line_vertex p[2];
 //
 uint16 color;
 int32 ec_count;
 uint32 (MDFN_FASTCALL *tffn)(uint32);
 uint16 CLUT[0x10];
 uint32 cb_or;
 uint32 tex_base;
};

MDFN_HIDE extern line_data LineData;

MDFN_HIDE extern line_inner_data LineInnerData;

struct prim_data
{
 EdgeStepper e[2];
 VileTex big_t;
 uint32 tex_base;
 int32 iter;
 bool need_line_resume;
};

MDFN_HIDE extern prim_data PrimData;

// Not sure the exact nature of this overhead, probably the combined effects of FBRAM and VRAM refresh, and something else.
// 8bpp mode timing is best-caseish, performance is different between horizontal and vertical lines.
//
// Must always return 0 if 'cycles' argument is zero.
static INLINE int32 AdjustDrawTiming(const int32 cycles)
{
 MDFN_HIDE extern uint32 DTACounter;
 uint32 extra_cycles;

 DTACounter += cycles * ((TVMR & TVMR_8BPP) ? 24 : 48);
 extra_cycles = DTACounter >> 8;
 DTACounter &= 0xFF;

 return cycles + extra_cycles;
}

bool SetupDrawLine(int32* const cycle_counter, const bool AA, const bool Textured, const uint16 mode);

#define PSTART							\
	bool transparent;					\
	uint16 pix;						\
								\
	if(Textured)						\
	{							\
	 /*ret++;*/						\
	 while(lid.t.IncPending())				\
	 {							\
	  int32 tx = lid.t.DoPendingInc();			\
								\
	  /*ret += (bool)t.IncPending();*/			\
								\
	  lid.texel = LineData.tffn(tx);			\
								\
	  if(!ECD && MDFN_UNLIKELY(LineData.ec_count <= 0))	\
	   return ret;						\
	 }							\
	 lid.t.AddError();					\
								\
	 transparent = (SPD && ECD) ? false : (lid.texel >> 31);\
	 pix = lid.texel;	\
	}			\
	else			\
	{			\
	 pix = lid.color;	\
	 transparent = !SPD;	\
	}

 /* hmm, possible problem with AA and drawn_ac...*/
 #define PBODY(pxy)											\
	{												\
	 const uint32 px = (uint16)(pxy);								\
	 const uint32 py = (pxy) >> 16;									\
	 bool clipped;											\
													\
	 if(UserClipEn && !UserClipMode)								\
	  clipped = ((uclipo1 - pxy) | (pxy - uclipo0)) & 0x80008000; 					\
	 else												\
	  clipped = (clipo - pxy) & 0x80008000;								\
													\
	 if(MDFN_UNLIKELY((clipped ^ lid.drawn_ac) & clipped))						\
	  return ret;											\
													\
	 lid.drawn_ac &= clipped;									\
													\
	 if(UserClipEn)											\
	 {												\
	  if(!UserClipMode)										\
	   clipped |= (clipo - pxy) & 0x80008000;							\
	  else												\
	   clipped |= !(((uclipo1 - pxy) | (pxy - uclipo0)) & 0x80008000); 				\
	 }												\
													\
	 ret += PlotPixel<die, bpp8, MSBOn, UserClipEn, UserClipMode, MeshEn, GouraudEn, HalfFGEn, HalfBGEn>(px, py, pix, transparent | clipped, (GouraudEn ? &lid.g : NULL));	\
	}

 #define PEND								\
	{								\
	 if(GouraudEn)							\
	  lid.g.Step();							\
									\
	 if(MDFN_UNLIKELY(ret >= VDP1_SuspendResumeThreshold) && lid.xy != lid.term_xy)		\
	 {								\
	  LineInnerData.xy = lid.xy;					\
	  LineInnerData.error = lid.error;				\
	  LineInnerData.drawn_ac = lid.drawn_ac;			\
									\
	  if(Textured)							\
	  {								\
	   LineInnerData.texel = lid.texel;				\
	   LineInnerData.t = lid.t;					\
	  }								\
									\
	  if(GouraudEn)							\
	   LineInnerData.g = lid.g;					\
									\
	  *need_line_resume = true;					\
	  return ret;							\
	 }								\
	}

template<bool AA, bool Textured, bool die, unsigned bpp8, bool MSBOn, bool UserClipEn, bool UserClipMode, bool MeshEn, bool ECD, bool SPD, bool GouraudEn, bool HalfFGEn, bool HalfBGEn>
static int32 DrawLine(bool* need_line_resume)
{
 //printf("Textured=%d, AA=%d, UserClipEn=%d, UserClipMode=%d, ECD=%d, SPD=%d, GouraudEn=%d\n", Textured, AA, UserClipEn, UserClipMode, ECD, SPD, GouraudEn);
 const uint32 clipo = ((SysClipY & 0x3FF) << 16) | (SysClipX & 0x3FF);
 const uint32 uclipo0 = ((UserClipY0 & 0x3FF) << 16) | (UserClipX0 & 0x3FF);
 const uint32 uclipo1 = ((UserClipY1 & 0x3FF) << 16) | (UserClipX1 & 0x3FF);
 line_inner_data lid = LineInnerData;
 int32 ret = 0;

 if(lid.abs_dy_gt_abs_dx)
 //if(abs_dy > abs_dx)
 {
  do
  {
   PSTART;

   lid.xy = (lid.xy + lid.y_inc) & 0x07FF07FF;
   lid.error += lid.error_inc;
   if((int32)lid.error >= lid.error_cmp)
   {
    lid.error += lid.error_adj;

    if(AA)
    {
     const uint32 aa_xy = (lid.xy + lid.aa_xy_inc) & 0x07FF07FF;

     PBODY(aa_xy);
    }

    lid.xy = (lid.xy + lid.x_inc) & 0x07FF07FF;
   }

   PBODY(lid.xy);

   PEND;
  } while(MDFN_LIKELY(lid.xy != lid.term_xy));
 }
 else
 {
  do
  {
   PSTART;

   lid.xy = (lid.xy + lid.x_inc) & 0x07FF07FF;
   lid.error += lid.error_inc;
   if((int32)lid.error >= lid.error_cmp)
   {
    lid.error += lid.error_adj;

    if(AA)
    {
     const uint32 aa_xy = (lid.xy + lid.aa_xy_inc) & 0x07FF07FF;

     PBODY(aa_xy);
    }

    lid.xy = (lid.xy + lid.y_inc) & 0x07FF07FF;
   }

   PBODY(lid.xy);

   PEND;
  } while(MDFN_LIKELY(lid.xy != lid.term_xy));
 }

 return ret;
}

//
//
}

}


#endif
