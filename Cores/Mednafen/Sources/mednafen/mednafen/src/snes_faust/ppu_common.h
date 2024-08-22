/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* ppu_common.h:
**  Copyright (C) 2015-2022 Mednafen Team
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

snes_event_handler PPU_GetEventHandler(void) MDFN_COLD;
snes_event_handler PPU_GetLineIRQEventHandler(void) MDFN_COLD;
void PPU_SetGetVideoParams(MDFNGI* gi, const unsigned caspect, const unsigned hfilter, const unsigned sls, const unsigned sle) MDFN_COLD;
void PPU_Kill(void) MDFN_COLD;
void PPU_Reset(bool powering_up) MDFN_COLD;
void PPU_ResetTS(void);

void PPU_StateAction(StateMem* sm, const unsigned load, const bool data_only);

void PPU_StartFrame(EmulateSpecStruct* espec);
//
//
//
uint16 PPU_PeekVRAM(uint32 addr) MDFN_COLD;
uint16 PPU_PeekCGRAM(uint32 addr) MDFN_COLD;
uint8 PPU_PeekOAM(uint32 addr) MDFN_COLD;
uint8 PPU_PeekOAMHI(uint32 addr) MDFN_COLD;
uint32 PPU_GetRegister(const unsigned id, char* const special, const uint32 special_len) MDFN_COLD;

void PPU_PokeVRAM(uint32 addr, uint16 val) MDFN_COLD;
void PPU_PokeCGRAM(uint32 addr, uint16 val) MDFN_COLD;
void PPU_PokeOAM(uint32 addr, uint8 val) MDFN_COLD;
void PPU_PokeOAMHI(uint32 addr, uint8 val) MDFN_COLD;
void PPU_SetRegister(const unsigned id, const uint32 value) MDFN_COLD;

