/******************************************************************************/
/* Mednafen NEC PC-FX Emulation Module                                        */
/******************************************************************************/
/* pcfx.h:
**  Copyright (C) 2006-2016 Mednafen Team
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

#ifndef __PCFX_PCFX_H
#define __PCFX_PCFX_H

#include <mednafen/mednafen.h>
#include <mednafen/state.h>
#include <mednafen/general.h>
#include <mednafen/hw_cpu/v810/v810_cpu.h>
#include <mednafen/hw_video/huc6270/vdc.h>

namespace MDFN_IEN_PCFX
{

#define PCFX_MASTER_CLOCK	21477272.72

#if 0
 #define FXDBG(format, ...) MDFN_DebugPrint(format, ## __VA_ARGS__)
#else
 #define FXDBG(format, ...) ((void)0)
#endif

extern V810 PCFX_V810;

uint8 MDFN_FASTCALL mem_peekbyte(const v810_timestamp_t timestamp, const uint32 A);
uint16 MDFN_FASTCALL mem_peekhword(const v810_timestamp_t timestamp, const uint32 A);

int32 MDFN_FASTCALL pcfx_event_handler(const v810_timestamp_t timestamp);

void ForceEventUpdates(const uint32 timestamp);

extern VDC *fx_vdc_chips[2];

#define REGSETHW(_reg, _data, _msh) { _reg &= 0xFFFF << (_msh ? 0 : 16); _reg |= _data << (_msh ? 16 : 0); }
#define REGGETHW(_reg, _msh) ((_reg >> (_msh ? 16 : 0)) & 0xFFFF)

enum
{
 PCFX_EVENT_PAD = 0,
 PCFX_EVENT_TIMER,
 PCFX_EVENT_KING,
 PCFX_EVENT_ADPCM
};

#define PCFX_EVENT_NONONO       0x7fffffff

void PCFX_SetEvent(const int type, const v810_timestamp_t next_timestamp);

}

#endif
