/******************************************************************************/
/* Mednafen Sony PS1 Emulation Module                                         */
/******************************************************************************/
/* gpu_polygon.cpp:
**  Copyright (C) 2011-2017 Mednafen Team
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

#pragma GCC optimize ("no-unroll-loops,no-peel-loops")

#include "psx.h"
#include "gpu.h"

namespace MDFN_IEN_PSX
{
namespace PS_GPU_INTERNAL
{
#include "gpu_common.inc"

#define COORD_FBS 12
#define COORD_MF_INT(n) ((n) << COORD_FBS)
#define COORD_POST_PADDING	12

struct i_group
{
 uint32 u, v;
 uint32 r, g, b;
};

struct i_deltas
{
 uint32 du_dx, dv_dx;
 uint32 dr_dx, dg_dx, db_dx;

 uint32 du_dy, dv_dy;
 uint32 dr_dy, dg_dy, db_dy;
};

static INLINE int64 MakePolyXFP(uint32 x)
{
 return ((uint64)x << 32) + ((1ULL << 32) - (1 << 11));
}

static INLINE int64 MakePolyXFPStep(int32 dx, int32 dy)
{
 int64 ret;
 int64 dx_ex = (uint64)dx << 32;

 if(dx_ex < 0)
  dx_ex -= dy - 1;

 if(dx_ex > 0)
  dx_ex += dy - 1;

 ret = dx_ex / dy;

 return(ret);
}

static INLINE int32 GetPolyXFP_Int(int64 xfp)
{
 return(xfp >> 32);
}

#define CALCIS(x,y) (((B.x - A.x) * (C.y - B.y)) - ((C.x - B.x) * (B.y - A.y)))
template<bool goraud, bool textured>
static INLINE bool CalcIDeltas(i_deltas &idl, const tri_vertex &A, const tri_vertex &B, const tri_vertex &C)
{
 int32 denom = CALCIS(x, y);

 if(!denom)
  return(false);

 if(goraud)
 {
  idl.dr_dx = (uint32)(CALCIS(r, y) * (1 << COORD_FBS) / denom) << COORD_POST_PADDING;
  idl.dr_dy = (uint32)(CALCIS(x, r) * (1 << COORD_FBS) / denom) << COORD_POST_PADDING;

  idl.dg_dx = (uint32)(CALCIS(g, y) * (1 << COORD_FBS) / denom) << COORD_POST_PADDING;
  idl.dg_dy = (uint32)(CALCIS(x, g) * (1 << COORD_FBS) / denom) << COORD_POST_PADDING;

  idl.db_dx = (uint32)(CALCIS(b, y) * (1 << COORD_FBS) / denom) << COORD_POST_PADDING;
  idl.db_dy = (uint32)(CALCIS(x, b) * (1 << COORD_FBS) / denom) << COORD_POST_PADDING;
 }

 if(textured)
 {
  idl.du_dx = (uint32)(CALCIS(u, y) * (1 << COORD_FBS) / denom) << COORD_POST_PADDING;
  idl.du_dy = (uint32)(CALCIS(x, u) * (1 << COORD_FBS) / denom) << COORD_POST_PADDING;

  idl.dv_dx = (uint32)(CALCIS(v, y) * (1 << COORD_FBS) / denom) << COORD_POST_PADDING;
  idl.dv_dy = (uint32)(CALCIS(x, v) * (1 << COORD_FBS) / denom) << COORD_POST_PADDING;
 }

 return(true);
}
#undef CALCIS

template<bool goraud, bool textured>
static INLINE void AddIDeltas_DX(i_group &ig, const i_deltas &idl, uint32 count = 1)
{
 if(textured)
 {
  ig.u += idl.du_dx * count;
  ig.v += idl.dv_dx * count;
 }

 if(goraud)
 {
  ig.r += idl.dr_dx * count;
  ig.g += idl.dg_dx * count;
  ig.b += idl.db_dx * count;
 }
}

template<bool goraud, bool textured>
static INLINE void AddIDeltas_DY(i_group &ig, const i_deltas &idl, uint32 count = 1)
{
 if(textured)
 {
  ig.u += idl.du_dy * count;
  ig.v += idl.dv_dy * count;
 }

 if(goraud)
 {
  ig.r += idl.dr_dy * count;
  ig.g += idl.dg_dy * count;
  ig.b += idl.db_dy * count;
 }
}

template<bool goraud, bool textured, int BlendMode, bool TexMult, uint32 TexMode_TA, bool MaskEval_TA>
static INLINE void DrawSpan(int y, const int32 x_start, const int32 x_bound, i_group ig, const i_deltas &idl)
{
  if(LineSkipTest(y))
   return;

  int32 x_ig_adjust = x_start;
  int32 w = x_bound - x_start;
  int32 x = sign_x_to_s32(11, x_start);

  if(x < ClipX0)
  {
   int32 delta = ClipX0 - x;
   x_ig_adjust += delta;
   x += delta;
   w -= delta;
  }

  if((x + w) > (ClipX1 + 1))
   w = ClipX1 + 1 - x;

  if(w <= 0)
   return;

  //printf("%d %d %d %d\n", x, w, ClipX0, ClipX1);

  AddIDeltas_DX<goraud, textured>(ig, idl, x_ig_adjust);
  AddIDeltas_DY<goraud, textured>(ig, idl, y);

  if(goraud || textured)
   DrawTimeAvail -= w * 2;
  else if((BlendMode >= 0) || MaskEval_TA)
   DrawTimeAvail -= w + ((w + 1) >> 1);
  else
   DrawTimeAvail -= w;

  do
  {
   const uint32 r = ig.r >> (COORD_FBS + COORD_POST_PADDING);
   const uint32 g = ig.g >> (COORD_FBS + COORD_POST_PADDING);
   const uint32 b = ig.b >> (COORD_FBS + COORD_POST_PADDING);

   //assert(x >= ClipX0 && x <= ClipX1);

   if(textured)
   {
    uint16 fbw = GetTexel<TexMode_TA>(ig.u >> (COORD_FBS + COORD_POST_PADDING), ig.v >> (COORD_FBS + COORD_POST_PADDING));

    if(fbw)
    {
     if(TexMult)
     {
      uint32 dither_x = x & 3;
      uint32 dither_y = y & 3;

      if(!dtd)
      {
       dither_x = 3;
       dither_y = 2;
      }

      fbw = ModTexel(fbw, r, g, b, dither_x, dither_y);
     }
     PlotPixel<BlendMode, MaskEval_TA, true>(x, y, fbw);
    }
   }
   else
   {
    uint16 pix = 0x8000;

    if(goraud && dtd)
    {
     pix |= DitherLUT[y & 3][x & 3][r] << 0;
     pix |= DitherLUT[y & 3][x & 3][g] << 5;
     pix |= DitherLUT[y & 3][x & 3][b] << 10;
    }
    else
    {
     pix |= (r >> 3) << 0;
     pix |= (g >> 3) << 5;
     pix |= (b >> 3) << 10;
    }
    
    PlotPixel<BlendMode, MaskEval_TA, false>(x, y, pix);
   }

   x++;
   AddIDeltas_DX<goraud, textured>(ig, idl);
  } while(MDFN_LIKELY(--w > 0));
}

template<bool goraud, bool textured, int BlendMode, bool TexMult, uint32 TexMode_TA, bool MaskEval_TA>
static INLINE void DrawTriangle(tri_vertex *vertices)
{
 i_deltas idl;
 unsigned core_vertex;

 //
 // Calculate the "core" vertex based on the unsorted input vertices, and sort vertices by Y.
 //
 {
  unsigned cvtemp = 0;

  if(vertices[1].x <= vertices[0].x)
  {
   if(vertices[2].x <= vertices[1].x)
    cvtemp = (1 << 2);
   else
    cvtemp = (1 << 1);
  }
  else if(vertices[2].x < vertices[0].x)
   cvtemp = (1 << 2);
  else
   cvtemp = (1 << 0);

  if(vertices[2].y < vertices[1].y)
  {
   std::swap(vertices[2], vertices[1]);
   cvtemp = ((cvtemp >> 1) & 0x2) | ((cvtemp << 1) & 0x4) | (cvtemp & 0x1);
  }

  if(vertices[1].y < vertices[0].y)
  {
   std::swap(vertices[1], vertices[0]);
   cvtemp = ((cvtemp >> 1) & 0x1) | ((cvtemp << 1) & 0x2) | (cvtemp & 0x4);
  }

  if(vertices[2].y < vertices[1].y)
  {
   std::swap(vertices[2], vertices[1]);
   cvtemp = ((cvtemp >> 1) & 0x2) | ((cvtemp << 1) & 0x4) | (cvtemp & 0x1);
  }

  core_vertex = cvtemp >> 1;
 }

 //
 // 0-height, abort out.
 //
 if(vertices[0].y == vertices[2].y)
  return;

 if((vertices[2].y - vertices[0].y) >= 512)
 {
  //PSX_WARNING("[GPU] Triangle height too large: %d", (vertices[2].y - vertices[0].y));
  return;
 }

 if(abs(vertices[2].x - vertices[0].x) >= 1024 ||
    abs(vertices[2].x - vertices[1].x) >= 1024 ||
    abs(vertices[1].x - vertices[0].x) >= 1024)
 {
  //PSX_WARNING("[GPU] Triangle width too large: %d %d %d", abs(vertices[2].x - vertices[0].x), abs(vertices[2].x - vertices[1].x), abs(vertices[1].x - vertices[0].x));
  return;
 }

 if(!CalcIDeltas<goraud, textured>(idl, vertices[0], vertices[1], vertices[2]))
  return;

 // [0] should be top vertex, [2] should be bottom vertex, [1] should be off to the side vertex.
 //
 //
 int64 base_coord;
 int64 base_step;

 int64 bound_coord_us;
 int64 bound_coord_ls;

 bool right_facing;
 i_group ig;

 if(textured)
 {
  ig.u = (COORD_MF_INT(vertices[core_vertex].u) + (1 << (COORD_FBS - 1))) << COORD_POST_PADDING;
  ig.v = (COORD_MF_INT(vertices[core_vertex].v) + (1 << (COORD_FBS - 1))) << COORD_POST_PADDING;
 }

 ig.r = (COORD_MF_INT(vertices[core_vertex].r) + (1 << (COORD_FBS - 1))) << COORD_POST_PADDING;
 ig.g = (COORD_MF_INT(vertices[core_vertex].g) + (1 << (COORD_FBS - 1))) << COORD_POST_PADDING;
 ig.b = (COORD_MF_INT(vertices[core_vertex].b) + (1 << (COORD_FBS - 1))) << COORD_POST_PADDING;

 AddIDeltas_DX<goraud, textured>(ig, idl, -vertices[core_vertex].x);
 AddIDeltas_DY<goraud, textured>(ig, idl, -vertices[core_vertex].y);

 base_coord = MakePolyXFP(vertices[0].x);
 base_step = MakePolyXFPStep((vertices[2].x - vertices[0].x), (vertices[2].y - vertices[0].y));

 //
 //
 //

 if(vertices[1].y == vertices[0].y)
 {
  bound_coord_us = 0;
  right_facing = (bool)(vertices[1].x > vertices[0].x);
 }
 else
 {
  bound_coord_us = MakePolyXFPStep((vertices[1].x - vertices[0].x), (vertices[1].y - vertices[0].y));
  right_facing = (bool)(bound_coord_us > base_step);
 }

 if(vertices[2].y == vertices[1].y)
  bound_coord_ls = 0;
 else
  bound_coord_ls = MakePolyXFPStep((vertices[2].x - vertices[1].x), (vertices[2].y - vertices[1].y));

 //
 // Left side draw order
 //
 // core_vertex == 0
 //	Left(base): vertices[0] -> (?vertices[1]?) -> vertices[2]
 //
 // core_vertex == 1:
 // 	Left(base): vertices[1] -> vertices[2], vertices[1] -> vertices[0]
 //
 // core_vertex == 2:
 //	Left(base): vertices[2] -> (?vertices[1]?) -> vertices[0]
 //printf("%d %d\n", core_vertex, right_facing);
 struct
 {
  uint64 x_coord[2];
  uint64 x_step[2];

  int32 y_coord;
  int32 y_bound;

  bool dec_mode;
 } tripart[2];

#if 0
 switch(core_vertex)
 {
  case 0:
	tripart[0].dec_mode = tripart[1].dec_mode = false;

	tripart[0].y_coord = vertices[0].y;
	tripart[0].y_bound = vertices[1].y;
	if(vertices[0].y != vertices[1].y)
	{
	 tripart[0].x_coord[0] = MakePolyXFP(vertices[0].x);
	 tripart[0].x_step[0] = 

	 tripart[0].x_coord[1] = MakePolyXFP(vertices[0].x);
	 tripart[0].x_step[1] = 
	}
	break;

  case 1:
	break;

  case 2:
	break;
 }
#endif

 unsigned vo = 0;
 unsigned vp = 0;

 if(core_vertex)
  vo = 1;

 if(core_vertex == 2)
  vp = 3;

 {
  auto* tp = &tripart[vo];

  tp->y_coord = vertices[0 ^ vo].y;
  tp->y_bound = vertices[1 ^ vo].y;
  tp->x_coord[right_facing] = MakePolyXFP(vertices[0 ^ vo].x);
  tp->x_step[right_facing] = bound_coord_us;
  tp->x_coord[!right_facing] = base_coord + ((vertices[vo].y - vertices[0].y) * base_step);
  tp->x_step[!right_facing] = base_step;
  tp->dec_mode = vo;
 }

 {
  auto* tp = &tripart[vo ^ 1];

  tp->y_coord = vertices[1 ^ vp].y;
  tp->y_bound = vertices[2 ^ vp].y;
  tp->x_coord[right_facing] = MakePolyXFP(vertices[1 ^ vp].x);
  tp->x_step[right_facing] = bound_coord_ls;
  tp->x_coord[!right_facing] = base_coord + ((vertices[1 ^ vp].y - vertices[0].y) * base_step); //base_coord + ((vertices[1].y - vertices[0].y) * base_step);
  tp->x_step[!right_facing] = base_step;
  tp->dec_mode = vp;
 }

 for(unsigned i = 0; i < 2; i++) //2; i++)
 {
  int32 yi = tripart[i].y_coord;
  int32 yb = tripart[i].y_bound;

  uint64 lc = tripart[i].x_coord[0];
  uint64 ls = tripart[i].x_step[0];

  uint64 rc = tripart[i].x_coord[1];
  uint64 rs = tripart[i].x_step[1];

  if(tripart[i].dec_mode)
  {
   while(MDFN_LIKELY(yi > yb))
   {
    yi--;
    lc -= ls;
    rc -= rs;
    //
    //
    //
    int32 y = sign_x_to_s32(11, yi);

    if(y < ClipY0)
     break;

    if(y > ClipY1)
    {
     DrawTimeAvail -= 2;
     continue;
    }

    DrawSpan<goraud, textured, BlendMode, TexMult, TexMode_TA, MaskEval_TA>(yi, GetPolyXFP_Int(lc), GetPolyXFP_Int(rc), ig, idl);
   }
  }
  else
  {
   while(MDFN_LIKELY(yi < yb))
   {
    int32 y = sign_x_to_s32(11, yi);

    if(y > ClipY1)
     break;

    if(y < ClipY0)
    {
     DrawTimeAvail -= 2;
     goto skipit;
    }

    DrawSpan<goraud, textured, BlendMode, TexMult, TexMode_TA, MaskEval_TA>(yi, GetPolyXFP_Int(lc), GetPolyXFP_Int(rc), ig, idl);
    //
    //
    //
    skipit: ;
    yi++;
    lc += ls;
    rc += rs;
   }
  }
 }

#if 0
 printf("[GPU] Vertices: %d:%d(r=%d, g=%d, b=%d) -> %d:%d(r=%d, g=%d, b=%d) -> %d:%d(r=%d, g=%d, b=%d)\n\n\n", vertices[0].x, vertices[0].y,
	vertices[0].r, vertices[0].g, vertices[0].b,
	vertices[1].x, vertices[1].y,
	vertices[1].r, vertices[1].g, vertices[1].b,
	vertices[2].x, vertices[2].y,
	vertices[2].r, vertices[2].g, vertices[2].b);
#endif
}

template<int numvertices, bool goraud, bool textured, int BlendMode, bool TexMult, uint32 TexMode_TA, bool MaskEval_TA>
static void Command_DrawPolygon(const uint32 *cb)
{
 const unsigned cb0 = cb[0];
 tri_vertex vertices[3];
 unsigned sv = 0;
 //uint32 tpage = 0;

 // Base timing is approximate, and could be improved.
 if(numvertices == 4 && InCmd == PS_GPU::INCMD_QUAD)
  DrawTimeAvail -= (28 + 18);
 else
  DrawTimeAvail -= (64 + 18);

 if(goraud && textured)
  DrawTimeAvail -= 150 * 3;
 else if(goraud)
  DrawTimeAvail -= 96 * 3;
 else if(textured)
  DrawTimeAvail -= 60 * 3;

 if(numvertices == 4)
 {
  if(InCmd == PS_GPU::INCMD_QUAD)
  {
   memcpy(&vertices[0], &InQuad_F3Vertices[1], 2 * sizeof(tri_vertex));
   sv = 2;
  }
 }
 //else
 // memset(vertices, 0, sizeof(vertices));

 for(unsigned v = sv; v < 3; v++)
 {
  if(v == 0 || goraud)
  {
   uint32 raw_color = (*cb & 0xFFFFFF);

   vertices[v].r = raw_color & 0xFF;
   vertices[v].g = (raw_color >> 8) & 0xFF;
   vertices[v].b = (raw_color >> 16) & 0xFF;

   cb++;
  }
  else
  {
   vertices[v].r = vertices[0].r;
   vertices[v].g = vertices[0].g;
   vertices[v].b = vertices[0].b;
  }

  vertices[v].x = sign_x_to_s32(11, ((int16)(*cb & 0xFFFF))) + OffsX;
  vertices[v].y = sign_x_to_s32(11, ((int16)(*cb >> 16))) + OffsY;
  cb++;

  if(textured)
  {
   vertices[v].u = (*cb & 0xFF);
   vertices[v].v = (*cb >> 8) & 0xFF;

   if(v == 0)
   {
    Update_CLUT_Cache<TexMode_TA>((*cb >> 16) & 0xFFFF);
   }

   cb++;
  }
 }

 if(numvertices == 4)
 {
  if(InCmd == PS_GPU::INCMD_QUAD)
  {
   InCmd = PS_GPU::INCMD_NONE;
  }
  else
  {
   InCmd = PS_GPU::INCMD_QUAD;
   InCmd_CC = cb0 >> 24;
   memcpy(&InQuad_F3Vertices[0], &vertices[0], sizeof(tri_vertex) * 3);
  }
 }

 DrawTriangle<goraud, textured, BlendMode, TexMult, TexMode_TA, MaskEval_TA>(vertices);
}

#undef COORD_POST_PADDING
#undef COORD_FBS
#undef COORD_MF_INT

extern const CTEntry Commands_20_3F[0x20] =
{
 /* 0x20 */
 POLY_HELPER(0x20),
 POLY_HELPER(0x21),
 POLY_HELPER(0x22),
 POLY_HELPER(0x23),
 POLY_HELPER(0x24),
 POLY_HELPER(0x25),
 POLY_HELPER(0x26),
 POLY_HELPER(0x27),
 POLY_HELPER(0x28),
 POLY_HELPER(0x29),
 POLY_HELPER(0x2a),
 POLY_HELPER(0x2b),
 POLY_HELPER(0x2c),
 POLY_HELPER(0x2d),
 POLY_HELPER(0x2e),
 POLY_HELPER(0x2f),
 POLY_HELPER(0x30),
 POLY_HELPER(0x31),
 POLY_HELPER(0x32),
 POLY_HELPER(0x33),
 POLY_HELPER(0x34),
 POLY_HELPER(0x35),
 POLY_HELPER(0x36),
 POLY_HELPER(0x37),
 POLY_HELPER(0x38),
 POLY_HELPER(0x39),
 POLY_HELPER(0x3a),
 POLY_HELPER(0x3b),
 POLY_HELPER(0x3c),
 POLY_HELPER(0x3d),
 POLY_HELPER(0x3e),
 POLY_HELPER(0x3f)
};

}
}
