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

template<bool textured, int BlendMode, bool TexMult, uint32 TexMode_TA, bool MaskEval_TA, bool FlipX, bool FlipY>
void PS_GPU::DrawSprite(int32 x_arg, int32 y_arg, int32 w, int32 h, uint8 u_arg, uint8 v_arg, uint32 color)
{
 const int32 r = color & 0xFF;
 const int32 g = (color >> 8) & 0xFF;
 const int32 b = (color >> 16) & 0xFF;
 const uint16 fill_color = 0x8000 | ((r >> 3) << 0) | ((g >> 3) << 5) | ((b >> 3) << 10);

 int32 x_start, x_bound;
 int32 y_start, y_bound;
 uint8 u, v;
 int v_inc = 1, u_inc = 1;

 //printf("[GPU] Sprite: x=%d, y=%d, w=%d, h=%d\n", x_arg, y_arg, w, h);

 x_start = x_arg;
 x_bound = x_arg + w;

 y_start = y_arg;
 y_bound = y_arg + h;

 if(textured)
 {
  u = u_arg;
  v = v_arg;

  //if(FlipX || FlipY || (u & 1) || (v & 1) || ((TexMode_TA == 0) && ((u & 3) || (v & 3))))
  // fprintf(stderr, "Flippy: %d %d 0x%02x 0x%02x\n", FlipX, FlipY, u, v);

  if(FlipX)
  {
   u_inc = -1;
   u |= 1;
  }
  // FIXME: Something weird happens when lower bit of u is set and we're not doing horizontal flip, but I'm not sure what it is exactly(needs testing)
  // It may only happen to the first pixel, so look for that case too during testing.
  //else
  // u = (u + 1) & ~1;

  if(FlipY)
  {
   v_inc = -1;
  }
 }

 if(x_start < ClipX0)
 {
  if(textured)
   u += (ClipX0 - x_start) * u_inc;

  x_start = ClipX0;
 }

 if(y_start < ClipY0)
 {
  if(textured)
   v += (ClipY0 - y_start) * v_inc;

  y_start = ClipY0;
 }

 if(x_bound > (ClipX1 + 1))
  x_bound = ClipX1 + 1;

 if(y_bound > (ClipY1 + 1))
  y_bound = ClipY1 + 1;

 //HeightMode && !dfe && ((y & 1) == ((DisplayFB_YStart + !field_atvs) & 1)) && !DisplayOff
 //printf("%d:%d, %d, %d ---- heightmode=%d displayfb_ystart=%d field_atvs=%d displayoff=%d\n", w, h, scanline, dfe, HeightMode, DisplayFB_YStart, field_atvs, DisplayOff);

 for(int32 y = y_start; MDFN_LIKELY(y < y_bound); y++)
 {
  uint8 u_r;

  if(textured)
   u_r = u;

  if(!LineSkipTest(y))
  {
   if(MDFN_LIKELY(x_bound > x_start))
   {
    //
    // TODO: From tests on a PS1, even a 0-width sprite takes up time to "draw" proportional to its height.
    //
    int32 suck_time = /*8 +*/ (x_bound - x_start);

    if((BlendMode >= 0) || MaskEval_TA)
     suck_time += (((x_bound + 1) & ~1) - (x_start & ~1)) >> 1;

    DrawTimeAvail -= suck_time;
   }

   for(int32 x = x_start; MDFN_LIKELY(x < x_bound); x++)
   {
    if(textured)
    {
     uint16 fbw = GetTexel<TexMode_TA>(u_r, v);

     if(fbw)
     {
      if(TexMult)
      {
       fbw = ModTexel(fbw, r, g, b, 3, 2);
      }
      PlotPixel<BlendMode, MaskEval_TA, true>(x, y, fbw);
     }
    }
    else
     PlotPixel<BlendMode, MaskEval_TA, false>(x, y, fill_color);

    if(textured)
     u_r += u_inc;
   }
  }
  if(textured)
   v += v_inc;
 }
}

template<uint8 raw_size, bool textured, int BlendMode, bool TexMult, uint32 TexMode_TA, bool MaskEval_TA>
INLINE void PS_GPU::Command_DrawSprite(const uint32 *cb)
{
 int32 x, y;
 int32 w, h;
 uint8 u = 0, v = 0;
 uint32 color = 0;

 DrawTimeAvail -= 16;	// FIXME, correct time.

 color = *cb & 0x00FFFFFF;
 cb++;

 x = sign_x_to_s32(11, (*cb & 0xFFFF));
 y = sign_x_to_s32(11, (*cb >> 16));
 cb++;

 if(textured)
 {
  u = *cb & 0xFF;
  v = (*cb >> 8) & 0xFF;
  Update_CLUT_Cache<TexMode_TA>((*cb >> 16) & 0xFFFF);
  cb++;
 }

 switch(raw_size)
 {
  default:
  case 0:
	w = (*cb & 0x3FF);
	h = (*cb >> 16) & 0x1FF;
	cb++;
	break;

  case 1:
	w = 1;
	h = 1;
	break;

  case 2:
	w = 8;
	h = 8;
	break;

  case 3:
	w = 16;
	h = 16;
	break;
 }

 //printf("SPRITE: %d %d %d -- %d %d\n", raw_size, x, y, w, h);

 x = sign_x_to_s32(11, x + OffsX);
 y = sign_x_to_s32(11, y + OffsY);

 switch(SpriteFlip & 0x3000)
 {
  case 0x0000:
	if(!TexMult || color == 0x808080)
  	 DrawSprite<textured, BlendMode, false, TexMode_TA, MaskEval_TA, false, false>(x, y, w, h, u, v, color);
	else
	 DrawSprite<textured, BlendMode, true, TexMode_TA, MaskEval_TA, false, false>(x, y, w, h, u, v, color);
	break;

  case 0x1000:
	if(!TexMult || color == 0x808080)
  	 DrawSprite<textured, BlendMode, false, TexMode_TA, MaskEval_TA, true, false>(x, y, w, h, u, v, color);
	else
	 DrawSprite<textured, BlendMode, true, TexMode_TA, MaskEval_TA, true, false>(x, y, w, h, u, v, color);
	break;

  case 0x2000:
	if(!TexMult || color == 0x808080)
  	 DrawSprite<textured, BlendMode, false, TexMode_TA, MaskEval_TA, false, true>(x, y, w, h, u, v, color);
	else
	 DrawSprite<textured, BlendMode, true, TexMode_TA, MaskEval_TA, false, true>(x, y, w, h, u, v, color);
	break;

  case 0x3000:
	if(!TexMult || color == 0x808080)
  	 DrawSprite<textured, BlendMode, false, TexMode_TA, MaskEval_TA, true, true>(x, y, w, h, u, v, color);
	else
	 DrawSprite<textured, BlendMode, true, TexMode_TA, MaskEval_TA, true, true>(x, y, w, h, u, v, color);
	break;
 }
}

//
// C-style function wrappers so our command table isn't so ginormous(in memory usage).
//
template<uint8 raw_size, bool textured, int BlendMode, bool TexMult, uint32 TexMode_TA, bool MaskEval_TA>
static void G_Command_DrawSprite(PS_GPU* g, const uint32 *cb)
{
 g->Command_DrawSprite<raw_size, textured, BlendMode, TexMult, TexMode_TA, MaskEval_TA>(cb);
}

const CTEntry PS_GPU::Commands_60_7F[0x20] =
{
 SPR_HELPER(0x60),
 SPR_HELPER(0x61),
 SPR_HELPER(0x62),
 SPR_HELPER(0x63),
 SPR_HELPER(0x64),
 SPR_HELPER(0x65),
 SPR_HELPER(0x66),
 SPR_HELPER(0x67),
 SPR_HELPER(0x68),
 SPR_HELPER(0x69),
 SPR_HELPER(0x6a),
 SPR_HELPER(0x6b),
 SPR_HELPER(0x6c),
 SPR_HELPER(0x6d),
 SPR_HELPER(0x6e),
 SPR_HELPER(0x6f),
 SPR_HELPER(0x70),
 SPR_HELPER(0x71),
 SPR_HELPER(0x72),
 SPR_HELPER(0x73),
 SPR_HELPER(0x74),
 SPR_HELPER(0x75),
 SPR_HELPER(0x76),
 SPR_HELPER(0x77),
 SPR_HELPER(0x78),
 SPR_HELPER(0x79),
 SPR_HELPER(0x7a),
 SPR_HELPER(0x7b),
 SPR_HELPER(0x7c),
 SPR_HELPER(0x7d),
 SPR_HELPER(0x7e),
 SPR_HELPER(0x7f)
};

}
