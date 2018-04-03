/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* vdp1_common.h:
**  Copyright (C) 2015-2016 Mednafen Team
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

int32 CMD_NormalSprite(const uint16*);
int32 CMD_ScaledSprite(const uint16*);
int32 CMD_DistortedSprite(const uint16*);

int32 CMD_Polygon(const uint16*);
int32 CMD_Polyline(const uint16*);
int32 CMD_Line(const uint16*);

extern uint16 VRAM[0x40000];
extern uint16 FB[2][0x20000];
extern bool FBDrawWhich;

extern int32 SysClipX, SysClipY;
extern int32 UserClipX0, UserClipY0, UserClipX1, UserClipY1;
extern int32 LocalX, LocalY;

extern uint32 (MDFN_FASTCALL *const TexFetchTab[0x20])(uint32 x);

enum { TVMR_8BPP   = 0x1 };
enum { TVMR_ROTATE = 0x2 };
enum { TVMR_HDTV   = 0x4 };
enum { TVMR_VBE    = 0x8 };
extern uint8 TVMR;

enum { FBCR_FCT	   = 0x01 };	// Frame buffer change trigger
enum { FBCR_FCM	   = 0x02 };	// Frame buffer change mode
enum { FBCR_DIL	   = 0x04 };	// Double interlace draw line(0=even, 1=odd) (does it affect drawing to FB RAM or reading from FB RAM to VDP2?)
enum { FBCR_DIE	   = 0x08 };	// Double interlace enable
enum { FBCR_EOS	   = 0x10 };	// Even/Odd coordinate select(0=even, 1=odd, used with HSS)
extern uint8 FBCR;

extern uint8 spr_w_shift_tab[8];
extern uint8 gouraud_lut[0x40];

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
template<bool die, unsigned bpp8, bool MSBOn, bool UserClipEn, bool UserClipMode, bool MeshEn, bool HalfFGEn, bool HalfBGEn>
static INLINE int32 PlotPixel(int32 x, int32 y, uint16 pix, bool transparent, GourauderTheTerrible* g)
{
 static_assert(!MSBOn || (!HalfFGEn && !HalfBGEn), "Table error; sub-optimal template arguments.");
 int32 ret = 0;
 uint16* fbyptr;

 if(die)
 {
  fbyptr = &FB[FBDrawWhich][((y >> 1) & 0xFF) << 9];
  transparent |= ((y & 1) != (bool)(FBCR & FBCR_DIL));
 }
 else
 {
  fbyptr = &FB[FBDrawWhich][(y & 0xFF) << 9];
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
      if(g)
       pix = g->Apply(pix);

      pix = ((pix + bg_pix) - ((pix ^ bg_pix) & 0x8421)) >> 1;
     }
     else
     {
      if(g)
       pix = 0;
      else
       pix = ((bg_pix & 0x7BDE) >> 1) | (bg_pix & 0x8000); 
     }
    }
    else
    {
     if(HalfFGEn)
     {
      if(g)
       pix = g->Apply(pix);
      else
       pix = pix;
     }
     else
     {
      if(g)
       pix = 0;
      else
       pix = bg_pix;
     }
    }
   }
   else
   {
    if(g)
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


static INLINE void CheckUndefClipping(void)
{
 if(SysClipX < UserClipX1 || SysClipY < UserClipY1 || UserClipX0 > UserClipX1 || UserClipY0 > UserClipY1)
 {
  //SS_DBG(SS_DBG_WARNING, "[VDP1] Illegal clipping windows; Sys=%u:%u -- User=%u:%u - %u:%u\n", SysClipX, SysClipY, UserClipX0, UserClipY0, UserClipX1, UserClipY1);
 }
}


//
//
struct line_vertex
{
 int32 x, y;
 uint16 g;
 int32 t;
};

struct line_data
{
 line_vertex p[2];
 bool PCD;
 bool HSS;
 uint16 color;
 int32 ec_count;
 uint32 (MDFN_FASTCALL *tffn)(uint32);
 uint16 CLUT[0x10];
 uint32 cb_or;
 uint32 tex_base;
};

extern line_data LineSetup;

template<bool AA, bool die, unsigned bpp8, bool MSBOn, bool UserClipEn, bool UserClipMode, bool MeshEn, bool ECD, bool SPD, bool Textured, bool GouraudEn, bool HalfFGEn, bool HalfBGEn>
static int32 DrawLine(void)
{
 const uint16 color = LineSetup.color;
 line_vertex p0 = LineSetup.p[0];
 line_vertex p1 = LineSetup.p[1];
 int32 ret = 0;

 if(!LineSetup.PCD)
 {
  // TODO:
  //	Plain clipping treats system clip X as an unsigned 10-bit quantity...
  //	Pre-clipping treats system clip X as a signed 13-bit quantity...
  //
  bool clipped = false;
  bool swapped = false;

  ret += 4;

  if(UserClipEn)
  {
   if(UserClipMode)
   {
    // not correct: clipped |= (p0.x >= UserClipX0) & (p1.x <= UserClipX1) & (p0.y >= UserClipY0) & (p1.y <= UserClipY1);
    clipped |= (p0.x < 0) & (p1.x < 0);
    clipped |= (p0.x > SysClipX) & (p1.x > SysClipX);
    clipped |= (p0.y < 0) & (p1.y < 0);
    clipped |= (p0.y > SysClipY) & (p1.y > SysClipY);

    swapped = (p0.y == p1.y) & ((p0.x < 0) | (p0.x > SysClipX));
   }
   else
   {
    // Ignore system clipping WRT pre-clip for UserClipEn == 1 && UserClipMode == 0
    clipped |= (p0.x < UserClipX0) & (p1.x < UserClipX0);
    clipped |= (p0.x > UserClipX1) & (p1.x > UserClipX1);
    clipped |= (p0.y < UserClipY0) & (p1.y < UserClipY0);
    clipped |= (p0.y > UserClipY1) & (p1.y > UserClipY1);

    swapped = (p0.y == p1.y) & ((p0.x < UserClipX0) | (p0.x > UserClipX1));
   }
  }
  else
  {
   clipped |= (p0.x < 0) & (p1.x < 0);
   clipped |= (p0.x > SysClipX) & (p1.x > SysClipX);
   clipped |= (p0.y < 0) & (p1.y < 0);
   clipped |= (p0.y > SysClipY) & (p1.y > SysClipY);

   swapped = (p0.y == p1.y) & ((p0.x < 0) | (p0.x > SysClipX));
  }

  if(clipped)
   return ret;

  if(swapped)
   std::swap(p0, p1);
 }

 ret += 8;

 //
 //
 const int32 dx = p1.x - p0.x;
 const int32 dy = p1.y - p0.y;
 const int32 abs_dx = abs(dx);
 const int32 abs_dy = abs(dy);
 const int32 max_adx_ady = std::max<int32>(abs_dx, abs_dy);
 int32 x_inc = (dx >= 0) ? 1 : -1;
 int32 y_inc = (dy >= 0) ? 1 : -1;
 int32 x = p0.x;
 int32 y = p0.y;
 bool drawn_ac = true;	// Drawn all-clipped
 uint32 texel;
 GourauderTheTerrible g;
 VileTex t;

 if(GouraudEn)
  g.Setup(max_adx_ady + 1, p0.g, p1.g);

 if(Textured)
 {
  LineSetup.ec_count = 2;	// Call before tffn()

  if(MDFN_UNLIKELY(max_adx_ady < abs(p1.t - p0.t) && LineSetup.HSS))
  {
   LineSetup.ec_count = 0x7FFFFFFF;
   t.Setup(max_adx_ady + 1, p0.t >> 1, p1.t >> 1, 2, (bool)(FBCR & FBCR_EOS));
  }
  else
   t.Setup(max_adx_ady + 1, p0.t, p1.t);

  texel = LineSetup.tffn(t.Current());
 }

 #define PSTART							\
	bool transparent;					\
	uint16 pix;						\
								\
	if(Textured)						\
	{							\
	 /*ret++;*/							\
	 while(t.IncPending())					\
	 {							\
	  int32 tx = t.DoPendingInc();				\
								\
	  /*ret += (bool)t.IncPending();*/				\
								\
	  texel = LineSetup.tffn(tx);				\
								\
	  if(!ECD && MDFN_UNLIKELY(LineSetup.ec_count <= 0))	\
	   return ret;						\
	 }							\
	 t.AddError();						\
								\
	 transparent = (SPD && ECD) ? false : (texel >> 31);	\
	 pix = texel;		\
	}			\
	else			\
	{			\
	 pix = color;		\
	 transparent = !SPD;	\
	}

 /* hmm, possible problem with AA and drawn_ac...*/
 #define PBODY(px, py)											\
	{												\
	 bool clipped = ((uint32)px > (uint32)SysClipX) | ((uint32)py > (uint32)SysClipY);		\
													\
	 if(UserClipEn && !UserClipMode)								\
	  clipped |= (px < UserClipX0) | (px > UserClipX1) | (py < UserClipY0) | (py > UserClipY1);	\
													\
	 if(MDFN_UNLIKELY((clipped ^ drawn_ac) & clipped))						\
	  return ret;											\
													\
	 drawn_ac &= clipped;										\
													\
	 if(UserClipEn && UserClipMode)									\
	  clipped |= (px >= UserClipX0) & (px <= UserClipX1) & (py >= UserClipY0) & (py <= UserClipY1);	\
													\
	 ret += PlotPixel<die, bpp8, MSBOn, UserClipEn, UserClipMode, MeshEn, HalfFGEn, HalfBGEn>(px, py, pix, transparent | clipped, (GouraudEn ? &g : NULL));	\
	}

 #define PEND						\
	{						\
	 if(GouraudEn)					\
	  g.Step();					\
        }


 if(abs_dy > abs_dx)
 {
  int32 error_inc = 2 * abs_dx;
  int32 error_adj = -(2 * abs_dy);
  int32 error = abs_dy - (2 * abs_dy + (dy >= 0 || AA));

  y -= y_inc;

  do
  {
   PSTART;

   y += y_inc;
   if(error >= 0)
   {
    if(AA)
    {
     int32 aa_x = x, aa_y = y;

     if(y_inc < 0)
     {
      aa_x += (x_inc >> 31);
      aa_y -= (x_inc >> 31);
     }
     else
     {
      aa_x -= (~x_inc >> 31);
      aa_y += (~x_inc >> 31);
     }

     PBODY(aa_x, aa_y);
    }

    error += error_adj;
    x += x_inc;
   }
   error += error_inc;

   PBODY(x, y);

   PEND;
  } while(MDFN_LIKELY(y != p1.y));
 }
 else
 {
  int32 error_inc = 2 * abs_dy;
  int32 error_adj = -(2 * abs_dx);
  int32 error = abs_dx - (2 * abs_dx + (dx >= 0 || AA));

  x -= x_inc;

  do
  {
   PSTART;

   x += x_inc;
   if(error >= 0)
   {
    if(AA)
    {
     int32 aa_x = x, aa_y = y;

     if(x_inc < 0)
     {
      aa_x -= (~y_inc >> 31);
      aa_y -= (~y_inc >> 31);
     }
     else
     {
      aa_x += (y_inc >> 31);
      aa_y += (y_inc >> 31);
     }

     PBODY(aa_x, aa_y);
    }

    error += error_adj;
    y += y_inc;
   }
   error += error_inc;

   PBODY(x, y);

   PEND;
  } while(MDFN_LIKELY(x != p1.x));
 }

 return ret;
}

template<bool gourauden>
struct EdgeStepper
{
 INLINE void Setup(const line_vertex& p0, const line_vertex& p1, const int32 dmax)
 {
  int32 dx = p1.x - p0.x;
  int32 dy = p1.y - p0.y;
  int32 abs_dx = abs(dx);
  int32 abs_dy = abs(dy);
  int32 max_adxdy = std::max<int32>(abs_dx, abs_dy);

  x = p0.x;
  x_inc = (dx >= 0) ? 1 : -1;
  x_error = ~(max_adxdy - (2 * max_adxdy + (dy >= 0)));
  x_error_inc = 2 * abs_dx;
  x_error_adj = 2 * max_adxdy;

  y = p0.y;
  y_inc = (dy >= 0) ? 1 : -1;
  y_error = ~(max_adxdy - (2 * max_adxdy + (dx >= 0)));
  y_error_inc = 2 * abs_dy;
  y_error_adj = 2 * max_adxdy;

  d_error = -dmax;
  d_error_inc = 2 *max_adxdy;
  d_error_adj = 2 * dmax;

  if(gourauden)
   g.Setup(max_adxdy + 1, p0.g, p1.g);
 }

 INLINE void GetVertex(line_vertex* p)
 {
  p->x = x;
  p->y = y;

  if(gourauden)
   p->g = g.Current();
 }

 INLINE void Step(void)
 {
  uint32 mask;

  d_error += d_error_inc;
  if(d_error >= 0)
  {
   d_error -= d_error_adj;

   x_error -= x_error_inc;
   mask = (int32)x_error >> 31;
   x += x_inc & mask;
   x_error += x_error_adj & mask;

   y_error -= y_error_inc;
   mask = (int32)y_error >> 31;
   y += y_inc & mask;
   y_error += y_error_adj & mask;

   if(gourauden)
    g.Step();
  }
 }

 int32 d_error, d_error_inc, d_error_adj;

 int32 x, x_inc;
 int32 x_error, x_error_inc, x_error_adj;

 int32 y, y_inc;
 int32 y_error, y_error_inc, y_error_adj;

 GourauderTheTerrible g;
};

//
//
}

}


#endif
