/* Mednafen - Multi-system Emulator
 * 
 * Copyright notice for this file:
 *  Copyright (C) 2002,2003 Xodnizel
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

#include "../nes.h"
#include "../input.h"
#include <math.h>
#include "palette.h"
#include <mednafen/FileStream.h>

namespace MDFN_IEN_NES
{

static const MDFNPalStruct rp2c04_0001[64] = {
 #include "palettes/rp2c04-0001.h"
};

static const MDFNPalStruct rp2c04_0002[64] = {
 #include "palettes/rp2c04-0002.h"
};

static const MDFNPalStruct rp2c04_0003[64] = {
 #include "palettes/rp2c04-0003.h"
};

static const MDFNPalStruct rp2c04_0004[64] = {
 #include "palettes/rp2c04-0004.h"
};

static const MDFNPalStruct rp2c0x[64] = {
 #include "palettes/rp2c0x.h"
};

/* Default palette */
static const MDFNPalStruct default_palette[64] = {
 #include "palettes/default.h"
};


MDFNPalStruct ActiveNESPalette[0x200];

const CustomPalette_Spec NES_CPInfo[7 + 1] =
{
 { gettext_noop("NTSC NES/Famicom Palette"), NULL, { 64, 512, 0 } },
 { gettext_noop("PAL NES Palette"), "nes-pal", { 64, 512, 0 } },

 { gettext_noop("Arcade RP2C04-0001 Palette"), "rp2c04-0001", { 64, 0 } },
 { gettext_noop("Arcade RP2C04-0002 Palette"), "rp2c04-0002", { 64, 0 } },
 { gettext_noop("Arcade RP2C04-0003 Palette"), "rp2c04-0003", { 64, 0 } },
 { gettext_noop("Arcade RP2C04-0004 Palette"), "rp2c04-0004", { 64, 0 } },

 { gettext_noop("Arcade RP2C03/RP2C05 Palette"), "rp2c0x", { 64, 0 } },

 { NULL, NULL },
};

static const MDFNPalStruct *Palettes[7] =
{
     default_palette,
     default_palette,

     rp2c04_0001,
     rp2c04_0002,
     rp2c04_0003,
     rp2c04_0004,
     rp2c0x
};

void MDFN_InitPalette(const unsigned int which, const uint8* custom_palette, const unsigned cp_numentries)
{
#if 0
 static const double rtmul[8] = { 1.000000, 1.098460, 0.738724, 0.813256, 0.855748, 0.884351, 0.661166, 0.75 };
 static const double gtmul[8] = { 1.000000, 0.800111, 1.041284, 0.797887, 0.835279, 0.680845, 0.819155, 0.75 };
 static const double btmul[8] = { 1.000000, 0.836181, 0.722674, 0.657716, 1.188771, 0.961351, 0.897613, 0.75 };
#endif
 static const double rtmul[8] = { 1, 1.239,  .794, 1.019,  .905, 1.023, .741, .75 };
 static const double gtmul[8] = { 1,  .915, 1.086,  .98,  1.026,  .908, .987, .75 };
 static const double btmul[8] = { 1,  .743,  .882,  .653, 1.277,  .979, .101, .75 };
 const MDFNPalStruct *palette = Palettes[which];

 for(int x = 0; x < 0x200; x++)
 {
  unsigned emp = (which >= 2) ? 0 : (x >> 6);
  int r, g, b;

  if(custom_palette)
  {
   unsigned cpx = x % cp_numentries;

   if(cpx >= 64)
    emp = 0;

   r = custom_palette[cpx * 3 + 0];
   g = custom_palette[cpx * 3 + 1];
   b = custom_palette[cpx * 3 + 2];
  }
  else
  {
   r = palette[x & 0x3F].r;
   g = palette[x & 0x3F].g;
   b = palette[x & 0x3F].b;
  }

  r = (int)(r * rtmul[emp]);
  g = (int)(g * gtmul[emp]);
  b = (int)(b * btmul[emp]);


  if(r > 255) r = 255;
  if(g > 255) g = 255;
  if(b > 255) b = 255;

  ActiveNESPalette[x].r = r;
  ActiveNESPalette[x].g = g;
  ActiveNESPalette[x].b = b;
 }

 NESINPUT_PaletteChanged();
}

}
