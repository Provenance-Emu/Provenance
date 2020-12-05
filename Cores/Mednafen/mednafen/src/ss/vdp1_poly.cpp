/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* vdp1_poly.cpp - VDP1 Polygon Drawing Commands Emulation
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

namespace MDFN_IEN_SS
{

namespace VDP1
{

static int32 (*LineFuncTab[2][3][0x20][8 + 1])(void) =
{
 #define LINEFN_BC(die, bpp8, b, c)	\
	DrawLine<true, die, bpp8, c == 0x8, (bool)(b & 0x10), (b & 0x10) && (b & 0x08), (bool)(b & 0x04), false/*b & 0x02*/, (bool)(b & 0x01), false, (bool)(c & 0x4), (bool)(c & 0x2), (bool)(c & 0x1)>

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

template<bool gourauden>
static INLINE int32 CMD_PolygonG_T(const uint16* cmd_data)
{
 const uint16 mode = cmd_data[0x2];
 line_vertex p[4];
 int32 ret = 0;
 //
 //
 bool SPD_Opaque = true;	// Abusing the SPD bit passed to the line draw function to denote non-transparency when == 1, transparent when == 0.

 LineSetup.tex_base = 0;
 LineSetup.color = cmd_data[0x3];
 LineSetup.PCD = mode & 0x800;

 if(((mode >> 3) & 0x7) < 0x6)
  SPD_Opaque = (int32)(TexFetchTab[(mode >> 3) & 0x1F](0xFFFFFFFF)) >= 0;
 //
 //
 //
 auto* fnptr = LineFuncTab[(bool)(FBCR & FBCR_DIE)][(TVMR & TVMR_8BPP) ? ((TVMR & TVMR_ROTATE) ? 2 : 1) : 0][((mode >> 6) & 0x1E) | SPD_Opaque /*(mode >> 6) & 0x1F*/][(mode & 0x8000) ? 8 : (mode & 0x7)];

 CheckUndefClipping();

 for(unsigned i = 0; i < 4; i++)
 {
  p[i].x = sign_x_to_s32(13, cmd_data[0x6 + (i << 1)]) + LocalX;
  p[i].y = sign_x_to_s32(13, cmd_data[0x7 + (i << 1)]) + LocalY;
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
 const int32 dmax = std::max<int32>(std::max<int32>(abs(p[3].x - p[0].x), abs(p[3].y - p[0].y)),
				    std::max<int32>(abs(p[2].x - p[1].x), abs(p[2].y - p[1].y)));
 EdgeStepper<gourauden> e[2];

 e[0].Setup(p[0], p[3], dmax);
 e[1].Setup(p[1], p[2], dmax);

 for(int32 i = 0; i <= dmax; i++)
 {
  e[0].GetVertex(&LineSetup.p[0]);
  e[1].GetVertex(&LineSetup.p[1]);
  //
  //printf("%d:%d -> %d:%d\n", lp[0].x, lp[0].y, lp[1].x, lp[1].y);
  ret += fnptr();
  //
  e[0].Step();
  e[1].Step();
 }

 return ret;
}

int32 CMD_Polygon(const uint16* cmd_data)
{
 if(cmd_data[0x2] & 0x4) // gouraud
  return CMD_PolygonG_T<true>(cmd_data);
 else
  return CMD_PolygonG_T<false>(cmd_data);
}


}
}
