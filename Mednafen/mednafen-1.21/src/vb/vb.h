/******************************************************************************/
/* Mednafen Virtual Boy Emulation Module                                      */
/******************************************************************************/
/* vb.h:
**  Copyright (C) 2010-2016 Mednafen Team
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

#ifndef __VB_VB_H
#define __VB_VB_H

#include <mednafen/mednafen.h>
#include <mednafen/hw_cpu/v810/v810_cpu.h>
#include <trio/trio.h>

namespace MDFN_IEN_VB
{

enum
{
 VB3DMODE_ANAGLYPH = 0,
 VB3DMODE_CSCOPE = 1,
 VB3DMODE_SIDEBYSIDE = 2,
 VB3DMODE_OVERUNDER = 3,
 VB3DMODE_VLI,
 VB3DMODE_HLI
};

#define VB_MASTER_CLOCK       20000000.0



enum
{
 VB_EVENT_VIP = 0,
 VB_EVENT_TIMER,
 VB_EVENT_INPUT,
// VB_EVENT_COMM
};

#define VB_EVENT_NONONO       0x7fffffff

void VB_SetEvent(const int type, const v810_timestamp_t next_timestamp);


#define VBIRQ_SOURCE_INPUT      0
#define VBIRQ_SOURCE_TIMER      1
#define VBIRQ_SOURCE_EXPANSION  2
#define VBIRQ_SOURCE_COMM       3
#define VBIRQ_SOURCE_VIP        4

void VBIRQ_Assert(int source, bool assert);

void VB_ExitLoop(void);

void ForceEventUpdates(const v810_timestamp_t timestamp);


uint8 MDFN_FASTCALL MemRead8(v810_timestamp_t &timestamp, uint32 A);
uint16 MDFN_FASTCALL MemRead16(v810_timestamp_t &timestamp, uint32 A);

void MDFN_FASTCALL MemWrite8(v810_timestamp_t &timestamp, uint32 A, uint8 V);
void MDFN_FASTCALL MemWrite16(v810_timestamp_t &timestamp, uint32 A, uint16 V);



extern int32 VB_InDebugPeek;
}

#endif
