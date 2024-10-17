/******************************************************************************/
/* Mednafen Sony PS1 Emulation Module                                         */
/******************************************************************************/
/* psx.h:
**  Copyright (C) 2011-2023 Mednafen Team
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

#ifndef __MDFN_PSX_PSX_H
#define __MDFN_PSX_PSX_H

#include <mednafen/mednafen.h>
#include <mednafen/general.h>

using namespace Mednafen;

#include <trio/trio.h>

#include "masmem.h"

//
// Comment out these 2 defines for extra speeeeed.
//
#define PSX_DBGPRINT_ENABLE    1
#define PSX_EVENT_SYSTEM_CHECKS 1

//
// It's highly unlikely the user will want these if they're intentionally compiling without the debugger.
#ifndef WANT_DEBUGGER
 #undef PSX_DBGPRINT_ENABLE
 #undef PSX_EVENT_SYSTEM_CHECKS
#endif
//
//
//

namespace MDFN_IEN_PSX
{
 enum
 {
  PSX_DBG_ERROR 	= (1U <<  0),	// Emulator-level error.
  PSX_DBG_INFO		= (1U <<  1),	// Emulator-level info.
  PSX_DBG_WARNING	= (1U <<  2),	// Warning about game doing questionable things/hitting stuff that might not be emulated correctly.
  PSX_DBG_BIOS_PRINT	= (1U <<  3),	// BIOS printf/putchar/puts output.

  PSX_DBG_CPU		= (1U <<  8),
  PSX_DBG_GTE		= (1U <<  9),
  PSX_DBG_IRQ		= (1U << 10),
  PSX_DBG_TIMER		= (1U << 11),
  PSX_DBG_DMA		= (1U << 12),
  PSX_DBG_SIO		= (1U << 13),
  PSX_DBG_FIO		= (1U << 14),
  PSX_DBG_CDC		= (1U << 15),
  PSX_DBG_MDEC		= (1U << 16),
  PSX_DBG_SPU		= (1U << 17),
  PSX_DBG_GPU		= (1U << 18),

  PSX_DBG_MEMCARD	= (1U << 24),
 };

#if PSX_DBGPRINT_ENABLE
 void PSX_DBG(uint32 which, const char *format, ...) noexcept MDFN_COLD MDFN_FORMATSTR(gnu_printf, 2, 3);

 void PSX_DBG_BIOS_PUTC(uint8 c) noexcept;
 void PSX_DBG_BIOS_PUTS(uint32 p) noexcept;
#else
 static INLINE void PSX_DBG(uint32 which, const char* format, ...) { }

 static INLINE void PSX_DBG_BIOS_PUTC(uint8 c) { }
 static INLINE void PSX_DBG_BIOS_PUTS(uint32 p) { }
#endif

 typedef int32 pscpu_timestamp_t;

 bool MDFN_FASTCALL PSX_EventHandler(const pscpu_timestamp_t timestamp);

 void MDFN_FASTCALL PSX_MemWrite8(pscpu_timestamp_t timestamp, uint32 A, uint32 V);
 void MDFN_FASTCALL PSX_MemWrite16(pscpu_timestamp_t timestamp, uint32 A, uint32 V);
 void MDFN_FASTCALL PSX_MemWrite24(pscpu_timestamp_t timestamp, uint32 A, uint32 V);
 void MDFN_FASTCALL PSX_MemWrite32(pscpu_timestamp_t timestamp, uint32 A, uint32 V);

 uint8 MDFN_FASTCALL PSX_MemRead8(pscpu_timestamp_t &timestamp, uint32 A);
 uint16 MDFN_FASTCALL PSX_MemRead16(pscpu_timestamp_t &timestamp, uint32 A);
 uint32 MDFN_FASTCALL PSX_MemRead24(pscpu_timestamp_t &timestamp, uint32 A);
 uint32 MDFN_FASTCALL PSX_MemRead32(pscpu_timestamp_t &timestamp, uint32 A);

 uint8 PSX_MemPeek8(uint32 A);
 uint16 PSX_MemPeek16(uint32 A);
 uint32 PSX_MemPeek32(uint32 A);

 // Should write to WO-locations if possible
 void PSX_MemPoke8(uint32 A, uint8 V);
 void PSX_MemPoke16(uint32 A, uint16 V);
 void PSX_MemPoke32(uint32 A, uint32 V);

 void PSX_RequestMLExit(void);
 void ForceEventUpdates(const pscpu_timestamp_t timestamp);

 enum
 {
  PSX_EVENT__SYNFIRST = 0,
  PSX_EVENT_GPU,
  PSX_EVENT_CDC,
  //PSX_EVENT_SPU,
  PSX_EVENT_TIMER,
  PSX_EVENT_DMA,
  PSX_EVENT_FIO,
  PSX_EVENT__SYNLAST,
  PSX_EVENT__COUNT,
 };

 #define PSX_EVENT_MAXTS       		0x20000000
 void PSX_SetEventNT(const int type, const pscpu_timestamp_t next_timestamp);

 void PSX_SetDMACycleSteal(unsigned stealage);

 void PSX_GPULineHook(const pscpu_timestamp_t timestamp, const pscpu_timestamp_t line_timestamp, bool vsync, uint32 *pixels, const MDFN_PixelFormat* const format, const unsigned width, const unsigned pix_clock_offset, const unsigned pix_clock, const unsigned pix_clock_divider);

 uint32 PSX_GetRandU32(uint32 mina, uint32 maxa);
}


#include "dis.h"
#include "cpu.h"
#include "irq.h"
#include "gpu.h"
#include "dma.h"
//#include "sio.h"
#include "debug.h"

namespace MDFN_IEN_PSX
{
 class PS_CDC;
 class PS_SPU;

 MDFN_HIDE extern PS_CPU *CPU;
 MDFN_HIDE extern PS_CDC *CDC;
 MDFN_HIDE extern PS_SPU *SPU;
 MDFN_HIDE extern MultiAccessSizeMem<2048 * 1024, false> MainRAM;
}


#endif
