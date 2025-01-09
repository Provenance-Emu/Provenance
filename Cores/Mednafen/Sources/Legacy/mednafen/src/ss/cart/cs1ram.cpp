/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* cs1ram.cpp - CS1 RAM(16MiB) cart emulation
**  Copyright (C) 2017 Mednafen Team
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
#include "cs1ram.h"

namespace MDFN_IEN_SS
{
static uint16* CS1RAM = nullptr;

template<typename T, bool IsWrite>
static MDFN_HOT void CS1RAM_RW_DB(uint32 A, uint16* DB)
{
 const uint32 mask = (sizeof(T) == 2) ? 0xFFFF : (0xFF << (((A & 1) ^ 1) << 3));
 uint16* const ptr = (uint16*)((uint8*)CS1RAM + (A & 0x00FFFFFE));

 if(IsWrite)
  *ptr = (*ptr & ~mask) | (*DB & mask);
 else
  *DB = *ptr;
}

static MDFN_COLD void Reset(bool powering_up)
{
 if(powering_up)
  memset(CS1RAM, 0, 0x1000000);
}

static MDFN_COLD void Kill(void)
{
 if(CS1RAM)
 {
  delete[] CS1RAM;
  CS1RAM = nullptr;
 }
}

static MDFN_COLD void StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFPTR16N(CS1RAM, 0x800000, "RAM"),
  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "CART_CS1RAM");
}

void CART_CS1RAM_Init(CartInfo* c)
{
 CS1RAM = new uint16[0x1000000 / sizeof(uint16)];

 SS_SetPhysMemMap   (0x04000000, 0x04FFFFFF, CS1RAM, 0x1000000, true);
 c->CS01_SetRW8W16(0x04000000, 0x04FFFFFF, 
	CS1RAM_RW_DB<uint16, false>,
	CS1RAM_RW_DB<uint8, true>,
	CS1RAM_RW_DB<uint16, true>);

 c->Reset = Reset;
 c->Kill = Kill;
 c->StateAction = StateAction;
}

}
