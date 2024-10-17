/******************************************************************************/
/* Mednafen Apple II Emulation Module                                         */
/******************************************************************************/
/* apple2.h:
**  Copyright (C) 2018-2023 Mednafen Team
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

#ifndef __MDFN_APPLE2_APPLE2_H
#define __MDFN_APPLE2_APPLE2_H

#include <mednafen/mednafen.h>

#ifdef MDFN_ENABLE_DEV_BUILD
 #include <trio/trio.h>
#endif

using namespace Mednafen;

namespace MDFN_IEN_APPLE2
{
#define APPLE2_MASTER_CLOCK 14318181.81818
//
//
#define DEFRW(x) void MDFN_FASTCALL MDFN_HOT x (uint16 A)
#define DEFREAD(x) DEFRW(x)
#define DEFWRITE(x) DEFRW(x)

typedef MDFN_FASTCALL void (*readfunc_t)(uint16);
typedef MDFN_FASTCALL void (*writefunc_t)(uint16);

void SetReadHandler(uint16 A, readfunc_t rf);
void SetWriteHandler(uint16 A, writefunc_t wf);
void SetRWHandlers(uint16 A, readfunc_t rf, writefunc_t wf);

MDFN_HOT void CPUTick1(void);


enum
{
 SOFTSWITCH_TEXT_MODE  = 0x01,	// When on, ignore mix mode, page 2, and hires mode bits in video handling.
 SOFTSWITCH_MIX_MODE   = 0x02,
 SOFTSWITCH_PAGE2      = 0x04,	// Page 1 if off, Page 2 if on.
 SOFTSWITCH_HIRES_MODE = 0x08,

 SOFTSWITCH_AN0        = 0x10,
 SOFTSWITCH_AN1        = 0x20,
 SOFTSWITCH_AN2        = 0x40,
 SOFTSWITCH_AN3        = 0x80,
 //
 // IIe:
 //
 SOFTSWITCH_80STORE    = 0x0100,
 SOFTSWITCH_RAMRD      = 0x0200,
 SOFTSWITCH_RAMWRT     = 0x0400,
 SOFTSWITCH_INTCXROM   = 0x0800,
 SOFTSWITCH_ALTZP      = 0x1000,
 SOFTSWITCH_SLOTC3ROM  = 0x2000,
 SOFTSWITCH_80COL      = 0x4000,
 SOFTSWITCH_ALTCHARSET = 0x8000,
 // IIe misc:
 SOFTSWITCH_VERTBLANK  = 0x010000,
 SOFTSWITCH_INTC8ROM   = 0x020000,   
};


struct A2Globals
{
 uint8* RAM;
 uint32 RAMSize;

 uint32 RAMMask[2];

 // C050-C05F, xxx0 for off(0), xxx1 for on(1)
 // IIe: Also, C000-C00F
 uint32 SoftSwitch;

 int32 timestamp;

 uint8 V7RGBMode;

 bool EnableFullAuxRAM;
 bool RAMPresent[0xC];	// 4KiB * 12 = 48KiB

 uint8 DB;

 bool FrameDone, FramePartialDone;
};
MDFN_HIDE extern A2Globals A2G;

static auto& DB = A2G.DB;
static auto& timestamp = A2G.timestamp;

//
//
//
enum
{
 APPLE2_DBG_ERROR	=	(1U << 0),
 APPLE2_DBG_WARNING	=	(1U << 1),
 APPLE2_DBG_UNK_READ	=	(1U << 2),
 APPLE2_DBG_UNK_WRITE	=	(1U << 3),
 APPLE2_DBG_UNINITIALIZED_READ= (1U << 4),

 APPLE2_DBG_DISK2	=	(1U << 16),
 APPLE2_DBG_BIOS	=	(1U << 24),
 APPLE2_DBG_DOS		=	(1U << 25),
 APPLE2_DBG_PRODOS	=	(1U << 26),
};

static INLINE void APPLE2_DBG_Dummy(const char* format, ...) { }

#ifdef MDFN_ENABLE_DEV_BUILD
 MDFN_HIDE extern uint32 apple2_dbg_mask;
 MDFN_HIDE extern bool InHLPeek;
 MDFN_HIDE extern bool junkread;
 #define APPLE2_DBG(which, ...) ((MDFN_UNLIKELY(apple2_dbg_mask & (which))) ? (void)trio_printf(__VA_ARGS__) : APPLE2_DBG_Dummy(__VA_ARGS__))
#else
 enum : uint32 { apple2_dbg_mask = 0 };
 enum : bool { InHLPeek = false };
 enum : bool { junkread = false };
 #define APPLE2_DBG(which, ...) (APPLE2_DBG_Dummy(__VA_ARGS__))
#endif

}

#endif
