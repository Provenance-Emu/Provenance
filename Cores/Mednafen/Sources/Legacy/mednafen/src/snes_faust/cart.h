/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* cart.h:
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

#ifndef __MDFN_SNES_FAUST_CART_H
#define __MDFN_SNES_FAUST_CART_H

namespace MDFN_IEN_SNES_FAUST
{
//
//
//
 bool CART_Init(Stream* fp, uint8 id[16], const int32 cx4_ocmultiplier, const int32 superfx_ocmultiplier, const bool superfx_enable_icache) MDFN_COLD;
 void CART_Kill(void) MDFN_COLD;
 void CART_Reset(bool powering_up) MDFN_COLD;
 void CART_StateAction(StateMem* sm, const unsigned load, const bool data_only);

 void CART_AdjustTS(const int32 delta) MDFN_COLD;
 snes_event_handler CART_GetEventHandler(void) MDFN_COLD;

 bool CART_LoadNV(void) MDFN_COLD;
 void CART_SaveNV(void);
//
//
//
 uint8 CART_PeekRAM(uint32 addr) MDFN_COLD;
 void CART_PokeRAM(uint32 addr, uint8 val) MDFN_COLD;
 uint32 CART_GetRAMSize(void) MDFN_COLD;
 uint8* CART_GetRAMPointer(void) MDFN_COLD;
//
//
//
}

#endif
