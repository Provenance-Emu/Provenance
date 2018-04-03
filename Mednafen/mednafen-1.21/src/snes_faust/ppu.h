/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* ppu.h:
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

#ifndef __MDFN_SNES_FAUST_PPU_H
#define __MDFN_SNES_FAUST_PPU_H

namespace MDFN_IEN_SNES_FAUST
{

void PPU_Init(const bool IsPAL) MDFN_COLD;
void PPU_SetGetVideoParams(MDFNGI* gi, const bool caspect) MDFN_COLD;
void PPU_Kill(void) MDFN_COLD;
void PPU_Reset(bool powering_up) MDFN_COLD;
void PPU_ResetTS(void);

void PPU_StateAction(StateMem* sm, const unsigned load, const bool data_only);

void PPU_StartFrame(EmulateSpecStruct* espec);

uint32 PPU_Update(uint32 timestamp) MDFN_HOT;

}

#endif
