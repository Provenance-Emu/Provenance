/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* ar4mp.cpp - Action Replay 4M Plus cart emulation
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

/*
 Unfinished, and looks like the firmware needs CPU UBC emulation.
*/

#include "common.h"
#include "ar4mp.h"

namespace MDFN_IEN_SS
{

static bool FLASH_Dirty;

static uint16* FLASH = nullptr; //[0x20000];
static uint16* ExtRAM = nullptr; //[0x200000];

template<typename T, bool IsWrite>
static MDFN_HOT void ExtRAM_RW_DB(uint32 A, uint16* DB)
{
 const uint32 mask = (sizeof(T) == 2) ? 0xFFFF : (0xFF << (((A & 1) ^ 1) << 3));
 uint16* const ptr = (uint16*)((uint8*)ExtRAM + (A & 0x3FFFFE));

 //printf("Barf %zu %d: %08x\n", sizeof(T), IsWrite, A);

 if(IsWrite)
  *ptr = (*ptr & ~mask) | (*DB & mask);
 else
  *DB = *ptr;
}

static MDFN_HOT void FLASH_Read(uint32 A, uint16* DB)
{
 if(MDFN_UNLIKELY(A & 0x080000))
  *DB = 0xFFFF;
 else
  *DB = *(uint16*)((uint8*)FLASH + (A & 0x3FFFE));
}

static MDFN_HOT void CV_Read(uint32 A, uint16* DB)
{
 *DB = 0xFFFF ^ ((A >> 20) & ((A >> 18) | (A >> 19) | ((A >> 21) ^ (A >> 22))) & 0x2);
}

static MDFN_HOT void RAMID_Read(uint32 A, uint16* DB)
{
 *DB = 0xFF5C;
}

static MDFN_COLD void Reset(bool powering_up)
{
 if(powering_up)
  memset(ExtRAM, 0, 0x400000);	// TODO: Test.
}

static MDFN_COLD bool GetClearNVDirty(void)
{
 bool ret = FLASH_Dirty;

 FLASH_Dirty = false;

 return ret;
}

static MDFN_COLD void GetNVInfo(const char** ext, void** nv_ptr, bool* nv16, uint64* nv_size)
{
 *ext = "arp";
 *nv_ptr = FLASH;
 *nv16 = true;
 *nv_size = 0x40000;
}

static MDFN_COLD void StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFPTR16(FLASH, 0x20000),
  SFPTR16(ExtRAM, 0x200000),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "CART_AR4MP");

 if(load)
 {
  FLASH_Dirty = true;
 }
}

static MDFN_COLD void Kill(void)
{
 if(FLASH)
 {
  delete[] FLASH;
  FLASH = nullptr;
 }

 if(ExtRAM)
 {
  delete[] ExtRAM;
  ExtRAM = nullptr;
 }
}

void CART_AR4MP_Init(CartInfo* c, Stream* str)
{
 std::unique_ptr<uint16[]> new_FLASH(new uint16[0x20000]);
 std::unique_ptr<uint16[]> new_ExtRAM(new uint16[0x200000]);

 FLASH = new_FLASH.get();
 ExtRAM = new_ExtRAM.get();
 //
 //
 str->read(FLASH, 0x40000);

 for(unsigned i = 0; i < 0x20000; i++)
 {
  FLASH[i] = MDFN_de16msb<true>(&FLASH[i]);
 }

 SS_SetPhysMemMap (0x02000000, 0x020FFFFF, FLASH, 0x40000, false);
 c->CS01_SetRW8W16(0x02000000, 0x020FFFFF, FLASH_Read);
 c->CS01_SetRW8W16(0x03000000, 0x03FFFFFF, CV_Read);
 c->CS01_SetRW8W16(0x04000000, 0x04FFFFFF, RAMID_Read);

 SS_SetPhysMemMap (0x02400000, 0x027FFFFF, ExtRAM, 0x400000, true);
 c->CS01_SetRW8W16(0x02400000, 0x027FFFFF,
	ExtRAM_RW_DB<uint16, false>,
	ExtRAM_RW_DB<uint8, true>,
	ExtRAM_RW_DB<uint16, true>);


 FLASH_Dirty = false;
 c->GetClearNVDirty = GetClearNVDirty;
 c->GetNVInfo = GetNVInfo;

 c->StateAction = StateAction;
 c->Reset = Reset;
 c->Kill = Kill;
 //
 //
 new_FLASH.release();
 new_ExtRAM.release();
}

}
