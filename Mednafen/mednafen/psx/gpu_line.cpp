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

#include "psx.h"
#include "gpu.h"

namespace MDFN_IEN_PSX
{
#include "gpu_common.inc"

struct line_fxp_coord
{
 uint64 x, y;
 uint32 r, g, b;
};

struct line_fxp_step
{
 int64 dx_dk, dy_dk;
 int32 dr_dk, dg_dk, db_dk;
};

enum { Line_XY_FractBits = 32 };
enum { Line_RGB_FractBits = 12 };

template<bool goraud>
static INLINE void LinePointToFXPCoord(const line_point &point, const line_fxp_step &step, line_fxp_coord &coord)
{
 coord.x = ((uint64)point.x << Line_XY_FractBits) | (1ULL << (Line_XY_FractBits - 1));
 coord.y = ((uint64)point.y << Line_XY_FractBits) | (1ULL << (Line_XY_FractBits - 1));

 coord.x -= 1024;

 if(step.dy_dk < 0)
  coord.y -= 1024;

 if(goraud)
 {
  coord.r = (point.r << Line_RGB_FractBits) | (1 << (Line_RGB_FractBits - 1));
  coord.g = (point.g << Line_RGB_FractBits) | (1 << (Line_RGB_FractBits - 1));
  coord.b = (point.b << Line_RGB_FractBits) | (1 << (Line_RGB_FractBits - 1));
 }
}

static INLINE int64 LineDivide(int64 delta, int32 dk)
{
 delta = (uint64)delta << Line_XY_FractBits;

 if(delta < 0)
  delta -= dk - 1;
 if(delta > 0)
  delta += dk - 1;

 return(delta / dk);
}

template<bool goraud>
static INLINE void LinePointsToFXPStep(const line_point &point0, const line_point &point1, const int32 dk, line_fxp_step &step)
{
 if(!dk)
 {
  step.dx_dk = 0;
  step.dy_dk = 0;

  if(goraud)
  {
   step.dr_dk = 0;
   step.dg_dk = 0;
   step.db_dk = 0;
  }
  return;
 }

 step.dx_dk = LineDivide(point1.x - point0.x, dk);
 step.dy_dk = LineDivide(point1.y - point0.y, dk);

 if(goraud)
 {
  step.dr_dk = (int32)((uint32)(point1.r - point0.r) << Line_RGB_FractBits) / dk;
  step.dg_dk = (int32)((uint32)(point1.g - point0.g) << Line_RGB_FractBits) / dk;
  step.db_dk = (int32)((uint32)(point1.b - point0.b) << Line_RGB_FractBits) / dk;
 }
}

template<bool goraud>
static INLINE void AddLineStep(line_fxp_coord &point, const line_fxp_step &step)
{
 point.x += step.dx_dk;
 point.y += step.dy_dk;
 
 if(goraud)
 {
  point.r += step.dr_dk;
  point.g += step.dg_dk;
  point.b += step.db_dk;
 }
}

template<bool goraud, int BlendMode, bool MaskEval_TA>
void PS_GPU::DrawLine(line_point *points)
{
 int32 i_dx;
 int32 i_dy;
 int32 k;
 line_fxp_coord cur_point;
 line_fxp_step step;

 i_dx = abs(points[1].x - points[0].x);
 i_dy = abs(points[1].y - points[0].y);
 k = (i_dx > i_dy) ? i_dx : i_dy;

 if(i_dx >= 1024)
  return;

 if(i_dy >= 512)
  return;

 if(points[0].x >= points[1].x && k)
 {
  line_point tmp = points[1];

  points[1] = points[0];
  points[0] = tmp;  
 }

 DrawTimeAvail -= k * 2;

 //
 //
 //

 LinePointsToFXPStep<goraud>(points[0], points[1], k, step);
 LinePointToFXPCoord<goraud>(points[0], step, cur_point);
 
 //
 //
 //
 for(int32 i = 0; i <= k; i++)	// <= is not a typo.
 {
  // Sign extension is not necessary here for x and y, due to the maximum values that ClipX1 and ClipY1 can contain.
  const int32 x = (cur_point.x >> Line_XY_FractBits) & 2047;
  const int32 y = (cur_point.y >> Line_XY_FractBits) & 2047;
  uint16 pix = 0x8000;

  if(!LineSkipTest(y))
  {
   uint8 r, g, b;

   if(goraud)
   {
    r = cur_point.r >> Line_RGB_FractBits;
    g = cur_point.g >> Line_RGB_FractBits;
    b = cur_point.b >> Line_RGB_FractBits;
   }
   else
   {
    r = points[0].r;
    g = points[0].g;
    b = points[0].b;
   }

   if(dtd)
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

   // FIXME: There has to be a faster way than checking for being inside the drawing area for each pixel.
   if(x >= ClipX0 && x <= ClipX1 && y >= ClipY0 && y <= ClipY1)
    PlotPixel<BlendMode, MaskEval_TA, false>(x, y, pix);
  }

  AddLineStep<goraud>(cur_point, step);
 }
}

template<bool polyline, bool goraud, int BlendMode, bool MaskEval_TA>
INLINE void PS_GPU::Command_DrawLine(const uint32 *cb)
{
 const uint8 cc = cb[0] >> 24; // For pline handling later.
 line_point points[2];

 DrawTimeAvail -= 16;	// FIXME, correct time.

 if(polyline && InCmd == INCMD_PLINE)
 {
  //printf("PLINE N\n");
  points[0] = InPLine_PrevPoint;
 }
 else
 {
  points[0].r = (*cb >> 0) & 0xFF;
  points[0].g = (*cb >> 8) & 0xFF;
  points[0].b = (*cb >> 16) & 0xFF;
  cb++;

  points[0].x = sign_x_to_s32(11, ((*cb >> 0) & 0xFFFF)) + OffsX;
  points[0].y = sign_x_to_s32(11, ((*cb >> 16) & 0xFFFF)) + OffsY;
  cb++;
 }

 if(goraud)
 {
  points[1].r = (*cb >> 0) & 0xFF;
  points[1].g = (*cb >> 8) & 0xFF;
  points[1].b = (*cb >> 16) & 0xFF;
  cb++;
 }
 else
 {
  points[1].r = points[0].r;
  points[1].g = points[0].g;
  points[1].b = points[0].b;
 }

 points[1].x = sign_x_to_s32(11, ((*cb >> 0) & 0xFFFF)) + OffsX;
 points[1].y = sign_x_to_s32(11, ((*cb >> 16) & 0xFFFF)) + OffsY;
 cb++;

 if(polyline)
 {
  InPLine_PrevPoint = points[1];

  if(InCmd != INCMD_PLINE)
  {
   InCmd = INCMD_PLINE;
   InCmd_CC = cc;
  }
 }

 DrawLine<goraud, BlendMode, MaskEval_TA>(points);
}

//
// C-style function wrappers so our command table isn't so ginormous(in memory usage).
//
template<bool polyline, bool goraud, int BlendMode, bool MaskEval_TA>
static void G_Command_DrawLine(PS_GPU* g, const uint32 *cb)
{
 g->Command_DrawLine<polyline, goraud, BlendMode, MaskEval_TA>(cb);
}

const CTEntry PS_GPU::Commands_40_5F[0x20] =
{
 LINE_HELPER(0x40),
 LINE_HELPER(0x41),
 LINE_HELPER(0x42),
 LINE_HELPER(0x43),
 LINE_HELPER(0x44),
 LINE_HELPER(0x45),
 LINE_HELPER(0x46),
 LINE_HELPER(0x47),
 LINE_HELPER(0x48),
 LINE_HELPER(0x49),
 LINE_HELPER(0x4a),
 LINE_HELPER(0x4b),
 LINE_HELPER(0x4c),
 LINE_HELPER(0x4d),
 LINE_HELPER(0x4e),
 LINE_HELPER(0x4f),
 LINE_HELPER(0x50),
 LINE_HELPER(0x51),
 LINE_HELPER(0x52),
 LINE_HELPER(0x53),
 LINE_HELPER(0x54),
 LINE_HELPER(0x55),
 LINE_HELPER(0x56),
 LINE_HELPER(0x57),
 LINE_HELPER(0x58),
 LINE_HELPER(0x59),
 LINE_HELPER(0x5a),
 LINE_HELPER(0x5b),
 LINE_HELPER(0x5c),
 LINE_HELPER(0x5d),
 LINE_HELPER(0x5e),
 LINE_HELPER(0x5f)
};

}
