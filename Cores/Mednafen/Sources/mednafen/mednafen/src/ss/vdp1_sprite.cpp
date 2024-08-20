/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* vdp1_sprite.cpp - VDP1 Sprite Drawing Commands Emulation
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

#include "ss.h"
#include "vdp1_common.h"

//#pragma GCC optimize("Os,no-crossjumping")

namespace MDFN_IEN_SS
{

namespace VDP1
{

static int32 (*LineFuncTab[2][3][0x20][8 + 1])(bool* need_line_resume) =
{
 #define LINEFN_BC(die, bpp8, b, c)	\
	DrawLine<true, true, die, bpp8, c == 0x8, (bool)(b & 0x10), (b & 0x10) && (b & 0x08), (bool)(b & 0x04), (bool)(b & 0x02), (bool)(b & 0x01), (bool)(c & 0x4), (!bpp8) && (c & 0x2), (bool)(c & 0x1)>

 #define LINEFN_B(die, bpp8, b)									\
	{										\
	 LINEFN_BC(die, bpp8, b, 0x0), LINEFN_BC(die, bpp8, b, 0x1), LINEFN_BC(die, bpp8, b, 0x2), LINEFN_BC(die, bpp8, b, 0x3),	\
	 LINEFN_BC(die, bpp8, b, 0x4), LINEFN_BC(die, bpp8, b, 0x5), LINEFN_BC(die, bpp8, b, 0x6), LINEFN_BC(die, bpp8, b, 0x7), 	\
	 LINEFN_BC(die, bpp8, b, 0x8), 	/* msb on */						\
	}

 #define LINEFN_BPP8(die, bpp8)									\
 {												\
  LINEFN_B(die, bpp8, 0x00), LINEFN_B(die, bpp8, 0x01), LINEFN_B(die, bpp8, 0x02), LINEFN_B(die, bpp8, 0x03),	\
  LINEFN_B(die, bpp8, 0x04), LINEFN_B(die, bpp8, 0x05), LINEFN_B(die, bpp8, 0x06), LINEFN_B(die, bpp8, 0x07),	\
  LINEFN_B(die, bpp8, 0x08), LINEFN_B(die, bpp8, 0x09), LINEFN_B(die, bpp8, 0x0A), LINEFN_B(die, bpp8, 0x0B),	\
  LINEFN_B(die, bpp8, 0x0C), LINEFN_B(die, bpp8, 0x0D), LINEFN_B(die, bpp8, 0x0E), LINEFN_B(die, bpp8, 0x0F),	\
												\
  LINEFN_B(die, bpp8, 0x10), LINEFN_B(die, bpp8, 0x11), LINEFN_B(die, bpp8, 0x12), LINEFN_B(die, bpp8, 0x13),	\
  LINEFN_B(die, bpp8, 0x14), LINEFN_B(die, bpp8, 0x15), LINEFN_B(die, bpp8, 0x16), LINEFN_B(die, bpp8, 0x17),	\
  LINEFN_B(die, bpp8, 0x18), LINEFN_B(die, bpp8, 0x19), LINEFN_B(die, bpp8, 0x1A), LINEFN_B(die, bpp8, 0x1B),	\
  LINEFN_B(die, bpp8, 0x1C), LINEFN_B(die, bpp8, 0x1D), LINEFN_B(die, bpp8, 0x1E), LINEFN_B(die, bpp8, 0x1F),	\
 }

 {
  LINEFN_BPP8(false, 0),
  LINEFN_BPP8(false, 1),
  LINEFN_BPP8(false, 2),
 },
 {
  LINEFN_BPP8(true, 0),
  LINEFN_BPP8(true, 1),
  LINEFN_BPP8(true, 2),
 }


 #undef LINEFN_BPP8
 #undef LINEFN_B
 #undef LINEFN_BC
};

enum
{
 FORMAT_NORMAL = 0,
 FORMAT_SCALED,
 FORMAT_DISTORTED
};

template<bool gourauden>
static int32 SpriteResumeBase(const uint16* cmd_data)
{
 const uint16 mode = cmd_data[0x2];
 auto* fnptr = LineFuncTab[(bool)(FBCR & FBCR_DIE)][(TVMR & TVMR_8BPP) ? ((TVMR & TVMR_ROTATE) ? 2 : 1) : 0][(mode >> 6) & 0x1F][(mode & 0x8000) ? 8 : (mode & 0x7)];
 LineData.tffn = TexFetchTab[(mode >> 3) & 0x1F];
 //
 //
 //
 EdgeStepper e[2] = { PrimData.e[0], PrimData.e[1] };
 VileTex big_t = PrimData.big_t;
 const uint32 tex_base = PrimData.tex_base;
 int32 iter = PrimData.iter;
 int32 ret = 0;
 //
 //
 if(MDFN_UNLIKELY(PrimData.need_line_resume))
 {
  PrimData.need_line_resume = false;
  goto ResumeLine;
 }

 if(iter >= 0)
 {
  do
  {
   e[0].GetVertex<gourauden>(&LineData.p[0]);
   e[1].GetVertex<gourauden>(&LineData.p[1]);

   LineData.tex_base = tex_base + big_t.PreStep();
   //
   if(!SetupDrawLine(&ret, true, true, mode) || !iter)
   {
    //
    //printf("%d:%d -> %d:%d\n", lp[0].x, lp[0].y, lp[1].x, lp[1].y);
    ResumeLine:;
    ret += AdjustDrawTiming(fnptr(&PrimData.need_line_resume));
    if(MDFN_UNLIKELY(PrimData.need_line_resume))
     break;
   }

   e[0].Step<gourauden>();
   e[1].Step<gourauden>();
  } while(MDFN_LIKELY(--iter >= 0 && ret < VDP1_SuspendResumeThreshold));
 }
 //
 //
 PrimData.e[0] = e[0];
 PrimData.e[1] = e[1];
 PrimData.big_t = big_t;
 PrimData.iter = iter;

 return ret;
}

int32 RESUME_Sprite(const uint16* cmd_data)
{
 if(cmd_data[0x2] & 0x4) // gouraud
  return SpriteResumeBase<true>(cmd_data);
 else
  return SpriteResumeBase<false>(cmd_data);
}

template<unsigned format>
static INLINE int32 SpriteBase(const uint16* cmd_data)
{
 const unsigned dir = (cmd_data[0] >> 4) & 0x3;
 const uint16 mode = cmd_data[0x2];
 const unsigned cm = (mode >> 3) & 0x7;
 const uint16 color = cmd_data[0x3];
 const uint32 w = ((cmd_data[0x5] >> 8) & 0x3F) << 3;
 const uint32 h = cmd_data[0x5] & 0xFF;
 line_vertex p[4];
 int32 ret = 0;

 LineData.color = cmd_data[0x3];

 if(format == FORMAT_DISTORTED)
 {
  for(unsigned i = 0; i < 4; i++)
  {
   p[i].x = sign_x_to_s32(13, cmd_data[0x6 + (i << 1)]) + LocalX;
   p[i].y = sign_x_to_s32(13, cmd_data[0x7 + (i << 1)]) + LocalY;
  }
  //printf("Hrm: %d:%d %d:%d %d:%d %d:%d\n", p[0].x, p[0].y, p[1].x, p[1].y, p[2].x, p[2].y, p[3].x, p[3].y);
 }
 else if(format == FORMAT_NORMAL)
 {
  p[0].x = sign_x_to_s32(13, cmd_data[0x6]) + LocalX;
  p[0].y = sign_x_to_s32(13, cmd_data[0x7]) + LocalY;

  p[1].x = p[0].x + (std::max<uint32>(w, 1) - 1);
  p[1].y = p[0].y;

  p[2].x = p[1].x;
  p[2].y = p[0].y + (std::max<uint32>(h, 1) - 1);

  p[3].x = p[0].x;
  p[3].y = p[2].y;
 }
 else if(format == FORMAT_SCALED)
 {
  const unsigned zp = (cmd_data[0] >> 8) & 0xF;
  {
   int32 zp_x = sign_x_to_s32(13, cmd_data[0x6]);
   int32 zp_y = sign_x_to_s32(13, cmd_data[0x7]);
   int32 disp_w = sign_x_to_s32(13, cmd_data[0x8]);
   int32 disp_h = sign_x_to_s32(13, cmd_data[0x9]);
   int32 alt_x = sign_x_to_s32(13, cmd_data[0xA]);
   int32 alt_y = sign_x_to_s32(13, cmd_data[0xB]);

   for(unsigned i = 0; i < 4; i++)
   {
    p[i].x = zp_x;
    p[i].y = zp_y;
   }

   switch(zp >> 2)
   {
    case 0x0:
	p[2].y = alt_y;
	p[3].y = alt_y;
	break;

    case 0x1:
	p[2].y += disp_h;
	p[3].y += disp_h;
	break;

    case 0x2:
	p[0].y -= disp_h >> 1;
	p[1].y -= disp_h >> 1;
	p[2].y += (disp_h + 1) >> 1;
	p[3].y += (disp_h + 1) >> 1;
	break;

    case 0x3:
	p[0].y -= disp_h;
	p[1].y -= disp_h;
	break;
   }

   switch(zp & 0x3)
   {
    case 0x0:
	p[1].x = alt_x;
	p[2].x = alt_x;
	break;

    case 0x1:
	p[1].x += disp_w;
	p[2].x += disp_w;
	break;

    case 0x2:
	p[0].x -= disp_w >> 1;
	p[1].x += (disp_w + 1) >> 1;
	p[2].x += (disp_w + 1) >> 1;
	p[3].x -= disp_w >> 1;
	break;

    case 0x3:
	p[0].x -= disp_w;
	p[3].x -= disp_w;
	break;
   }

   for(unsigned i = 0; i < 4; i++)
   {
    p[i].x += LocalX;
    p[i].y += LocalY;
   }
  }
 }

 if(cmd_data[0x2] & 0x4) // gouraud
 {
  const uint16* gtb = &VRAM[cmd_data[0xE] << 2];

  ret += 4;
  for(unsigned i = 0; i < 4; i++)
   p[i].g = gtb[i];
 }
 //
 //
 //
 // TODO: move?
 {
  const bool h_inv = dir & 1;

  LineData.p[0 ^ h_inv].t = 0;
  LineData.p[1 ^ h_inv].t = w ? (w - 1) : 0;
 }

 switch(cm)
 {
  case 0: LineData.cb_or = color &~ 0xF;
	  break;

  case 1:
	  for(unsigned i = 0; i < 16; i++)
	   LineData.CLUT[i] = VRAM[((color &~ 0x3) << 2) | i];

	  ret += 16;
	  break;

  case 2: LineData.cb_or = color &~ 0x3F; break;
  case 3: LineData.cb_or = color &~ 0x7F; break;
  case 4: LineData.cb_or = color &~ 0xFF; break;
  case 5: break;
  case 6: break;
  case 7: break;
 }
 //
 //
 //
 int32 dmax;

 dmax = 		      abs(sign_x_to_s32(13, p[3].x - p[0].x));
 dmax = std::max<int32>(dmax, abs(sign_x_to_s32(13, p[3].y - p[0].y)));
 dmax = std::max<int32>(dmax, abs(sign_x_to_s32(13, p[2].x - p[1].x)));
 dmax = std::max<int32>(dmax, abs(sign_x_to_s32(13, p[2].y - p[1].y)));
 dmax &= 0xFFF;

 int32 tex_base = cmd_data[0x4] << 2;
 const bool gourauden = (bool)(cmd_data[0x2] & 0x4);
 if(cm == 5) // RGB
  tex_base &= ~0x7;

 PrimData.e[0].Setup(gourauden, p[0], p[3], dmax);
 PrimData.e[1].Setup(gourauden, p[1], p[2], dmax);
 PrimData.iter = dmax;
 PrimData.tex_base = tex_base;
 PrimData.need_line_resume = false;

 //printf("0x%04x %u %d:%d %d:%d %d:%d %d:%d ---- %d %d\n", mode, format, p[0].x, p[0].y, p[1].x, p[1].y, p[2].x, p[2].y, p[3].x, p[3].y, w >> spr_w_shift_tab[cm], h);
 {
  const bool v_inv = dir & 2;
  int32 tv[2];

  tv[0 ^ v_inv] = 0;
  tv[1 ^ v_inv] = h ? (h - 1) : 0;

  PrimData.big_t.Setup(dmax + 1, tv[0], tv[1], w >> spr_w_shift_tab[cm]);
 }

 return ret;
}

int32 CMD_DistortedSprite(const uint16* cmd_data)
{
 return SpriteBase<FORMAT_DISTORTED>(cmd_data);
}

int32 CMD_NormalSprite(const uint16* cmd_data)
{
 return SpriteBase<FORMAT_NORMAL>(cmd_data);
}

int32 CMD_ScaledSprite(const uint16* cmd_data)
{
 return SpriteBase<FORMAT_SCALED>(cmd_data);
}


}
}
