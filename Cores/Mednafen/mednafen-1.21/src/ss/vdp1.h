/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* vdp1.h:
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

#ifndef __MDFN_SS_VDP1_H
#define __MDFN_SS_VDP1_H

#include <mednafen/state.h>

namespace MDFN_IEN_SS
{

namespace VDP1
{

void Init(void) MDFN_COLD;
void Kill(void) MDFN_COLD;
void StateAction(StateMem* sm, const unsigned load, const bool data_only);

void Reset(bool powering_up) MDFN_COLD;

sscpu_timestamp_t Update(sscpu_timestamp_t timestamp);
void AdjustTS(const int32 delta);

void Write8_DB(uint32 A, uint16 DB) MDFN_HOT;
void Write16_DB(uint32 A, uint16 DB) MDFN_HOT;
uint16 Read16_DB(uint32 A) MDFN_HOT;

void SetHBVB(const sscpu_timestamp_t event_timestamp, const bool new_hb_status, const bool new_vb_status);

bool GetLine(const int line, uint16* buf, unsigned w, uint32 rot_x, uint32 rot_y, uint32 rot_xinc, uint32 rot_yinc);

//
//
//

INLINE uint8 PeekVRAM(const uint32 addr)
{
 extern uint16 VRAM[0x40000];

 return ne16_rbo_be<uint8>(VRAM, addr & 0x7FFFF);
}

INLINE void PokeVRAM(const uint32 addr, const uint8 val)
{
 extern uint16 VRAM[0x40000];

 ne16_wbo_be<uint8>(VRAM, addr & 0x7FFFF, val);
}

INLINE uint8 PeekFB(const bool which, const uint32 addr)
{
 extern uint16 FB[2][0x20000];

 return ne16_rbo_be<uint8>(FB[which], addr & 0x3FFFF);
}

INLINE void PokeFB(const bool which, const uint32 addr, const uint8 val)
{
 extern uint16 FB[2][0x20000];

 ne16_wbo_be<uint8>(FB[which], addr & 0x3FFFF, val);
}

void MakeDump(const std::string& path) MDFN_COLD;
}

}


#endif
