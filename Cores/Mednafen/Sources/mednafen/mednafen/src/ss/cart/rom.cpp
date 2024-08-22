/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* rom.cpp - ROM cart emulation
**  Copyright (C) 2016-2017 Mednafen Team
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

#include "common.h"
#include "rom.h"

namespace MDFN_IEN_SS
{

static uint16 ROM[0x100000];

static MDFN_HOT void ROM_Read(uint32 A, uint16* DB)
{
 // TODO: Check mirroring.
 //printf("ROM: %08x\n", A);
 *DB = *(uint16*)((uint8*)ROM + (A & 0x1FFFFE));
}

void CART_ROM_Init(CartInfo* c, Stream* str)
{
 str->read(ROM, 0x200000);

 for(unsigned i = 0; i < 0x100000; i++)
 {
  ROM[i] = MDFN_de16msb<true>(&ROM[i]);
 }

 SS_SetPhysMemMap (0x02000000, 0x03FFFFFF, ROM, 0x200000, false);
 c->CS01_SetRW8W16(0x02000000, 0x03FFFFFF, ROM_Read);
}

}
