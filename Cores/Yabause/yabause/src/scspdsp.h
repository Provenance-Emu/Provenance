/*  Copyright 2015 Theo Berkau

    This file is part of Yabause.

    Yabause is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Yabause is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Yabause; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

#ifndef SCSPDSP_H
#define SCSPDSP_H

#include "core.h"

typedef struct
{
   u16 coef[64];
   u16 madrs[32];
   u64 mpro[128];
   s32 temp[128];
   s32 mems[32];
   s32 mixs[16];
   s16 efreg[16];
   s16 exts[2];

   u32 mdec_ct;
   s32 inputs;
   s32 b;
   s32 x;
   s16 y;
   s32 acc;
   s32 shifted;
   s32 y_reg;
   u16 frc_reg;
   u16 adrs_reg;

   u32 mrd_value;

   int rbl;
   int rbp;
}ScspDsp;

//dsp instruction format

//bits 63-48
//|  ?  |                   tra                   | twt |                   twa                   |
//|  F  |  E  |  D  |  C  |  B  |  A  |  9  |  8  |  7  |  6  |  5  |  4  |  3  |  2  |  1  |  0  |

//bits 47-32
//|xsel |    ysel   |  ?  |                ira                | iwt |             iwa             |
//|  F  |  E  |  D  |  C  |  B  |  A  |  9  |  8  |  7  |  6  |  5  |  4  |  3  |  2  |  1  |  0  |

//bits 31-16
//|table| mwt | mrd | ewt |          ewa          |adrl |frcl |   shift   | yrl |negb |zero |bsel |
//|  F  |  E  |  D  |  C  |  B  |  A  |  9  |  8  |  7  |  6  |  5  |  4  |  3  |  2  |  1  |  0  |

//bits 15-0
//|nofl |                coef               |     ?     |            masa             |adreb|nxadr|
//|  F  |  E  |  D  |  C  |  B  |  A  |  9  |  8  |  7  |  6  |  5  |  4  |  3  |  2  |  1  |  0  |

#ifdef WORDS_BIGENDIAN
union ScspDspInstruction {
   struct {
      u64 unknown : 1;
      u64 tra : 7;
      u64 twt : 1;
      u64 twa : 7;

      u64 xsel : 1;
      u64 ysel : 2;
      u64 unknown2 : 1;
      u64 ira : 6;
      u64 iwt : 1;
      u64 iwa : 5;

      u64 table : 1;
      u64 mwt : 1;
      u64 mrd : 1;
      u64 ewt : 1;
      u64 ewa : 4;
      u64 adrl : 1;
      u64 frcl : 1;
      u64 shift : 2;
      u64 yrl : 1;
      u64 negb : 1;
      u64 zero : 1;
      u64 bsel : 1;

      u64 nofl : 1;
      u64 coef : 6;
      u64 unknown3 : 2;
      u64 masa : 5;
      u64 adreb : 1;
      u64 nxadr : 1;
   } part;
   u32 all;
};
#else
union ScspDspInstruction {
   struct {
      u64 nxadr : 1;
      u64 adreb : 1;
      u64 masa : 5;
      u64 unknown3 : 2;
      u64 coef : 6;
      u64 nofl : 1;
      u64 bsel : 1;
      u64 zero : 1;
      u64 negb : 1;
      u64 yrl : 1;
      u64 shift : 2;
      u64 frcl : 1;
      u64 adrl : 1;
      u64 ewa : 4;
      u64 ewt : 1;
      u64 mrd : 1;
      u64 mwt : 1;
      u64 table : 1;
      u64 iwa : 5;
      u64 iwt : 1;
      u64 ira : 6;
      u64 unknown2 : 1;
      u64 ysel : 2;
      u64 xsel : 1;
      u64 twa : 7;
      u64 twt : 1;
      u64 tra : 7;
      u64 unknown : 1;
   } part;
   u64 all;
};
#endif

void ScspDspDisasm(u8 addr, char *outstring);
void ScspDspExec(ScspDsp* dsp, int addr, u8 * sound_ram);

extern ScspDsp scsp_dsp;

#endif
