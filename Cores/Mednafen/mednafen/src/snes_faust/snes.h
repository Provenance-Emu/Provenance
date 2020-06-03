/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* snes.h:
**  Copyright (C) 2015-2019 Mednafen Team
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

#ifndef __MDFN_SNES_FAUST_SNES_H
#define __MDFN_SNES_FAUST_SNES_H

#pragma GCC optimize ("unroll-loops")

#include <mednafen/mednafen.h>

using namespace Mednafen;

#define DEFREAD(x) uint8 MDFN_FASTCALL MDFN_HOT x (uint32 A)
#define DEFWRITE(x) void MDFN_FASTCALL MDFN_HOT x (uint32 A, uint8 V)

#define DEFREAD_NOHOT(x) uint8 MDFN_FASTCALL x (uint32 A)
#define DEFWRITE_NOHOT(x) void MDFN_FASTCALL x (uint32 A, uint8 V)

#define MEMCYC_FAST   6
#define MEMCYC_SLOW   8
#define MEMCYC_XSLOW 12

#if defined(WANT_DEBUGGER) && defined(MDFN_ENABLE_DEV_BUILD)
 #define SNES_DBG_ENABLE 1
 #define SNES_DBG(s, ...) printf(s, ## __VA_ARGS__)
#else
 static INLINE void SNES_DBG(const char* format, ...) { }
#endif

#include "cpu.h"
#include "debug.h"

namespace MDFN_IEN_SNES_FAUST
{

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

// For S-DD1 write handler chaining
DEFWRITE(DMA_Write_43x0);
DEFWRITE(DMA_Write_43x2);
DEFWRITE(DMA_Write_43x3);
DEFWRITE(DMA_Write_43x4);
DEFWRITE(DMA_Write_43x5);
DEFWRITE(DMA_Write_43x6);
//

typedef uint32 (*snes_event_handler)(const uint32 timestamp);

struct event_list_entry
{
 uint32 event_time;
 event_list_entry *prev;
 event_list_entry *next;
 snes_event_handler event_handler;
};

enum
{
 SNES_EVENT__SYNFIRST = 0,
 SNES_EVENT_PPU,
 SNES_EVENT_PPU_LINEIRQ,
 SNES_EVENT_DMA_DUMMY,
 SNES_EVENT_CART,
 SNES_EVENT_MSU1,
 SNES_EVENT__SYNLAST,
 SNES_EVENT__COUNT,
};

#define SNES_EVENT_MAXTS       		0x20000000

MDFN_HIDE extern event_list_entry events[SNES_EVENT__COUNT];

void ForceEventUpdates(const uint32 timestamp);

void SNES_SetEventNT(const int type, const uint32 next_timestamp) MDFN_HOT;
//
//
//
enum
{
 DMA_GSREG_DMAENABLE,
 DMA_GSREG_HDMAENABLE,
 DMA_GSREG_HDMAENABLEM,

 DMA_GSREG_CHN_CONTROL,
 DMA_GSREG_CHN_BBUSADDR,
 DMA_GSREG_CHN_ABUSADDR,
 DMA_GSREG_CHN_ABUSBANK,
 DMA_GSREG_CHN_INDIRBANK,
 DMA_GSREG_CHN_COUNT_INDIRADDR,
 DMA_GSREG_CHN_TABLEADDR,
 DMA_GSREG_CHN_LINECOUNTER,
 DMA_GSREG_CHN_UNKNOWN,
 DMA_GSREG_CHN_OFFSET,
 DMA_GSREG_CHN_DOTRANSFER,
};

uint32 DMA_GetRegister(const unsigned id, char* const special, const uint32 special_len) MDFN_COLD;
void DMA_SetRegister(const unsigned id, const uint32 value) MDFN_COLD;

enum
{
 SNES_GSREG_MEMSEL,
 SNES_GSREG_TS
};
uint32 SNES_GetRegister(const unsigned int id, char* special, const uint32 special_len) MDFN_COLD;
void SNES_SetRegister(const unsigned int id, uint32 value) MDFN_COLD;

uint8 PeekWRAM(uint32 addr) MDFN_COLD;
void PokeWRAM(uint32 addr, uint8 val) MDFN_COLD;
}

#endif
