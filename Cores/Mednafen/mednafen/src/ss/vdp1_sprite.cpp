/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* vdp1_sprite.cpp - VDP1 Sprite Drawing Commands Emulation
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

#include "ss.h"
#include "vdp1_common.h"

//#pragma GCC optimize("Os,no-crossjumping")

namespace MDFN_IEN_SS
{

namespace VDP1
{

static int32 (*LineFuncTab[2][3][0x20][8 + 1])(void) =
{
 #define LINEFN_BC(die, bpp8, b, c)	\
	DrawLine<true, die, bpp8, c == 0x8, (bool)(b & 0x10), (b & 0x10) && (b & 0x08), (bool)(b & 0x04), (bool)(b & 0x02), (bool)(b & 0x01), true, (bool)(c & 0x4), (!bpp8) && (c & 0x2), (bool)(c & 0x1)>

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

/*
 Timing notes:
	Timing is somewhat complex, and looks like the drawing of the lines of distorted sprites may be terminated
	early in some conditions relating to clipping.

	Drawing a 256x1 texture with a 255x1 rectangular distorted sprite takes about twice as much time(even with blending enabled, which is weird...) as drawing
	it with a 256x1 or 257x1 rectangular distorted sprite.
*/
enum
{
 FORMAT_NORMAL,
 FORMAT_SCALED,
 FORMAT_DISTORTED
};

template<unsigned format, bool gourauden>
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
 auto* fnptr = LineFuncTab[(bool)(FBCR & FBCR_DIE)][(TVMR & TVMR_8BPP) ? ((TVMR & TVMR_ROTATE) ? 2 : 1) : 0][(mode >> 6) & 0x1F][(mode & 0x8000) ? 8 : (mode & 0x7)];

 LineSetup.color = cmd_data[0x3];
 LineSetup.PCD = mode & 0x0800;
 LineSetup.HSS = mode & 0x1000;

 CheckUndefClipping();

 // FIXME: precision is probably not totally right.
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

 if(gourauden)
 {
  const uint16* gtb = &VRAM[cmd_data[0xE] << 2];

  ret += 4;
  for(unsigned i = 0; i < 4; i++)
   p[i].g = gtb[i];
 }
 //
 //
 //
 VileTex big_t;
 int32 tex_base;

 LineSetup.tffn = TexFetchTab[(mode >> 3) & 0x1F];

 {
  const bool h_inv = dir & 1;

  LineSetup.p[0 ^ h_inv].t = 0;
  LineSetup.p[1 ^ h_inv].t = w ? (w - 1) : 0;
 }

 switch(cm)
 {
  case 0: LineSetup.cb_or = color &~ 0xF;
	  break;

  case 1:
	  for(unsigned i = 0; i < 16; i++)
	   LineSetup.CLUT[i] = VRAM[((color &~ 0x3) << 2) | i];

	  ret += 16;
	  break;

  case 2: LineSetup.cb_or = color &~ 0x3F; break;
  case 3: LineSetup.cb_or = color &~ 0x7F; break;
  case 4: LineSetup.cb_or = color &~ 0xFF; break;
  case 5: break;
  case 6: break;
  case 7: break;
 }
 //
 //
 //
 const int32 dmax = std::max<int32>(std::max<int32>(abs(p[3].x - p[0].x), abs(p[3].y - p[0].y)),
				    std::max<int32>(abs(p[2].x - p[1].x), abs(p[2].y - p[1].y)));
 EdgeStepper<gourauden> e[2];

 e[0].Setup(p[0], p[3], dmax);
 e[1].Setup(p[1], p[2], dmax);

 tex_base = cmd_data[0x4] << 2;
 if(cm == 5) // RGB
  tex_base &= ~0x7;

 {
  const bool v_inv = dir & 2;
  int32 tv[2];

  tv[0 ^ v_inv] = 0;
  tv[1 ^ v_inv] = h ? (h - 1) : 0;

  big_t.Setup(dmax + 1, tv[0], tv[1], w >> spr_w_shift_tab[cm]);
 }

 for(int32 i = 0; i <= dmax; i++)
 {
  e[0].GetVertex(&LineSetup.p[0]);
  e[1].GetVertex(&LineSetup.p[1]);

  LineSetup.tex_base = tex_base + big_t.PreStep();
  //
  //printf("%d:%d -> %d:%d\n", lp[0].x, lp[0].y, lp[1].x, lp[1].y);
  ret += fnptr();
  //
  e[0].Step();
  e[1].Step();
 }

 return ret;
}

int32 CMD_DistortedSprite(const uint16* cmd_data)
{
 if(cmd_data[0x2] & 0x4) // gouraud
  return SpriteBase<FORMAT_DISTORTED, true>(cmd_data);
 else
  return SpriteBase<FORMAT_DISTORTED, false>(cmd_data);
}


int32 CMD_NormalSprite(const uint16* cmd_data)
{
 if(cmd_data[0x2] & 0x4) // gouraud
  return SpriteBase<FORMAT_NORMAL, true>(cmd_data);
 else
  return SpriteBase<FORMAT_NORMAL, false>(cmd_data);
}

int32 CMD_ScaledSprite(const uint16* cmd_data)
{
 if(cmd_data[0x2] & 0x4) // gouraud
  return SpriteBase<FORMAT_SCALED, true>(cmd_data);
 else
  return SpriteBase<FORMAT_SCALED, false>(cmd_data);
}


}
}
