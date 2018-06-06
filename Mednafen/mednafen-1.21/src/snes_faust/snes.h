/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* snes.h:
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

#ifndef __MDFN_SNESFAST_SNES_H
#define __MDFN_SNESFAST_SNES_H

#pragma GCC optimize ("unroll-loops")

#include <mednafen/mednafen.h>

#define DEFREAD(x) uint8 MDFN_FASTCALL MDFN_HOT x (uint32 A)
#define DEFWRITE(x) void MDFN_FASTCALL MDFN_HOT x (uint32 A, uint8 V)

#define MEMCYC_FAST   6
#define MEMCYC_SLOW   8
#define MEMCYC_XSLOW 12

#if 0
 #define SNES_DBG(s, ...) printf(s, ## __VA_ARGS__)
#else
 static INLINE void SNES_DBG(const char* format, ...) { }
#endif

#include "cpu.h"

namespace MDFN_IEN_SNES_FAUST
{
extern bool MemSelect;

DEFREAD(OBRead_XSLOW);
DEFREAD(OBRead_SLOW);
DEFREAD(OBRead_FAST);
DEFREAD(OBRead_VAR);

DEFWRITE(OBWrite_XSLOW);
DEFWRITE(OBWrite_SLOW);
DEFWRITE(OBWrite_FAST);
DEFWRITE(OBWrite_VAR);

//
// Caution: B bus read/write handlers should ignore the upper 24 bits of the passed-in address
// variable.
//
void Set_B_Handlers(uint8 A1, uint8 A2, readfunc read_handler, writefunc write_handler) MDFN_COLD;
static INLINE void Set_B_Handlers(uint8 A1, readfunc read_handler, writefunc write_handler)
{
 Set_B_Handlers(A1, A1, read_handler, write_handler);
}

void Set_A_Handlers(uint32 A1, uint32 A2, readfunc read_handler, writefunc write_handler) MDFN_COLD;
static INLINE void Set_A_Handlers(uint32 A1, readfunc read_handler, writefunc write_handler)
{
 Set_A_Handlers(A1, A1, read_handler, write_handler);
}

void DMA_InitHDMA(void) MDFN_HOT;
void DMA_RunHDMA(void) MDFN_HOT;

void ForceEventUpdates(const uint32 timestamp);

enum
{
 SNES_EVENT__SYNFIRST = 0,
 SNES_EVENT_PPU,
 SNES_EVENT_DMA_DUMMY,
 SNES_EVENT__SYNLAST,
 SNES_EVENT__COUNT,
};

#define SNES_EVENT_MAXTS       		0x20000000
void SNES_SetEventNT(const int type, const uint32 next_timestamp) MDFN_HOT;


}

#endif
