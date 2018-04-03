/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* ss.h:
**  Copyright (C) 2015-2017 Mednafen Team
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

#ifndef __MDFN_SS_SS_H
#define __MDFN_SS_SS_H

#include <mednafen/types.h>

#include <trio/trio.h>

namespace MDFN_IEN_SS
{
 enum
 {
  SS_DBG_ERROR     = (1U << 0),
  SS_DBG_WARNING   = (1U << 1),

  SS_DBG_M68K 	   = (1U << 2),

  SS_DBG_SH2  	   = (1U << 4),
  SS_DBG_SH2_REGW  = (1U << 5),
  SS_DBG_SH2_CACHE = (1U << 6),

  SS_DBG_SCU  	   = (1U << 8),
  SS_DBG_SCU_REGW  = (1U << 9),
  SS_DBG_SCU_INT   = (1U << 10),
  SS_DBG_SCU_DSP   = (1U << 11),

  SS_DBG_SMPC 	   = (1U << 12),
  SS_DBG_SMPC_REGW = (1U << 13),

  SS_DBG_CDB  	   = (1U << 16),
  SS_DBG_CDB_REGW  = (1U << 17),

  SS_DBG_VDP1 	   = (1U << 20),
  SS_DBG_VDP1_REGW = (1U << 21),
  SS_DBG_VDP1_VRAMW= (1U << 22),
  SS_DBG_VDP1_FBW  = (1U << 23),

  SS_DBG_VDP2 	   = (1U << 24),
  SS_DBG_VDP2_REGW = (1U << 25),

  SS_DBG_SCSP 	   = (1U << 28),
  SS_DBG_SCSP_REGW = (1U << 29),
 };
#ifdef MDFN_SS_DEV_BUILD
 extern uint32 ss_dbg_mask;
#else
 enum { ss_dbg_mask = 0 };
#endif

 static INLINE void SS_DBG_Dummy(const char* format, ...) { }
 #define SS_DBG(which, ...) ((MDFN_UNLIKELY(ss_dbg_mask & (which))) ? (void)trio_printf(__VA_ARGS__) : SS_DBG_Dummy(__VA_ARGS__))
 #define SS_DBGTI(which, ...) ((MDFN_UNLIKELY(ss_dbg_mask & (which))) ? ((void)trio_printf(__VA_ARGS__), (void)trio_printf(" @Line=0x%03x, HPos=0x%03x, memts=%d\n", VDP2::PeekLine(), VDP2::PeekHPos(), SH7095_mem_timestamp)) : SS_DBG_Dummy(__VA_ARGS__))

 template<unsigned which>
 static void SS_DBG_Wrap(const char* format, ...) noexcept
 {
  if(ss_dbg_mask & which)
  {
   va_list ap;

   va_start(ap, format);

   trio_vprintf(format, ap);

   va_end(ap);
  }
 }

 typedef int32 sscpu_timestamp_t;

 class SH7095;

 extern SH7095 CPU[2];	// for smpc.cpp

 extern int32 SH7095_mem_timestamp;

 void SS_RequestMLExit(void);
 void ForceEventUpdates(const sscpu_timestamp_t timestamp);

 enum
 {
  SS_EVENT__SYNFIRST = 0,

  SS_EVENT_SH2_M_DMA,
  SS_EVENT_SH2_S_DMA,

  SS_EVENT_SCU_DMA,
  SS_EVENT_SCU_DSP,

  SS_EVENT_SMPC,

  SS_EVENT_VDP1,
  SS_EVENT_VDP2,

  SS_EVENT_CDB,

  SS_EVENT_SOUND,

  SS_EVENT_CART,

  SS_EVENT_MIDSYNC,

  SS_EVENT__SYNLAST,
  SS_EVENT__COUNT,
 };

 typedef sscpu_timestamp_t (*ss_event_handler)(const sscpu_timestamp_t timestamp);

 struct event_list_entry
 {
  sscpu_timestamp_t event_time;
  event_list_entry *prev;
  event_list_entry *next;
  ss_event_handler event_handler;
 };

 extern event_list_entry events[SS_EVENT__COUNT];

 #define SS_EVENT_DISABLED_TS			0x40000000
 void SS_SetEventNT(event_list_entry* e, const sscpu_timestamp_t next_timestamp);

 // Call from init code, or power/reset code, as appropriate.
 // (length is in units of bytes, not 16-bit units)
 //
 // is_writeable is mostly for cheat stuff.
 void SS_SetPhysMemMap(uint32 Astart, uint32 Aend, uint16* ptr, uint32 length, bool is_writeable = false);

 void SS_Reset(bool powering_up) MDFN_COLD;
}

#endif
