/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* extram.cpp - Extended RAM(1MiB and 4MiB) cart emulation
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
#include "extram.h"

namespace MDFN_IEN_SS
{
static uint16 ExtRAM[0x200000];
static size_t ExtRAM_Mask;
static uint8 Cart_ID;

template<typename T, bool IsWrite>
static MDFN_HOT void ExtRAM_RW_DB(uint32 A, uint16* DB)
{
 const uint32 mask = (sizeof(T) == 2) ? 0xFFFF : (0xFF << (((A & 1) ^ 1) << 3));
 uint16* const ptr = (uint16*)((uint8*)ExtRAM + (A & ExtRAM_Mask));

 //printf("Barf %zu %d: %08x\n", sizeof(T), IsWrite, A);

 if(IsWrite)
  *ptr = (*ptr & ~mask) | (*DB & mask);
 else
  *DB = *ptr;
}

static MDFN_HOT void CartID_Read_DB(uint32 A, uint16* DB)
{
 if((A & ~1) == 0x04FFFFFE)
  *DB = Cart_ID;
}

static MDFN_COLD void Reset(bool powering_up)
{
 if(powering_up)
  memset(ExtRAM, 0, sizeof(ExtRAM));	// TODO: Test.
}

static MDFN_COLD void StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 const size_t pcount = (Cart_ID == 0x5C) ? 0x100000 : 0x040000;

 SFORMAT StateRegs[] =
 {
  SFPTR16N(&ExtRAM[0x000000], pcount, "LO"),
  SFPTR16N(&ExtRAM[0x100000], pcount, "HI"),
  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "CART_EXTRAM");
}

void CART_ExtRAM_Init(CartInfo* c, bool R4MiB)
{
 if(R4MiB)
 {
  Cart_ID = 0x5C;
  ExtRAM_Mask = 0x3FFFFE;
 }
 else
 {
  Cart_ID = 0x5A;
  ExtRAM_Mask = 0x27FFFE;
 }

 SS_SetPhysMemMap(0x02400000, 0x025FFFFF, ExtRAM + (0x000000 / sizeof(uint16)), (R4MiB ? 0x200000 : 0x080000), true);
 SS_SetPhysMemMap(0x02600000, 0x027FFFFF, ExtRAM + (0x200000 / sizeof(uint16)), (R4MiB ? 0x200000 : 0x080000), true);

 c->CS01_SetRW8W16(0x02400000, 0x027FFFFF,
	ExtRAM_RW_DB<uint16, false>,
	ExtRAM_RW_DB<uint8, true>,
	ExtRAM_RW_DB<uint16, true>);

 c->CS01_SetRW8W16(/*0x04FFFFFE*/0x04F00000, 0x04FFFFFF, CartID_Read_DB);

 c->Reset = Reset;
 c->StateAction = StateAction;
}

}
