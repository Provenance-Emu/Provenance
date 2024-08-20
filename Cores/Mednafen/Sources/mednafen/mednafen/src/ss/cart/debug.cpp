/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* debug.cpp - Mednafen debug cart emulation
**  Copyright (C) 2017-2018 Mednafen Team
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
#include "debug.h"

namespace MDFN_IEN_SS
{

static uint16* ROM = nullptr;

template<typename T, bool IsWrite>
static void Debug_RW_DB(uint32 A, uint16* DB)
{
 //
 // printf-related debugging
 //
 if((A &~ 0x3) == 0x02100000)
 {
  if(IsWrite)
  {
   if(A == 0x02100001)
   {
#ifdef MDFN_ENABLE_DEV_BUILD
    fputc(*DB, stderr);
    fflush(stderr);
#endif
   }
  }
  else
   *DB = 0;

  return;
 }
}

static void Debug_ROM_Read(uint32 A, uint16* DB)
{
 *DB = ne16_rbo_be<uint16>(ROM, A & 0xFFFFE);
 // printf("%08x %04x\n", A, *DB);
}

static MDFN_COLD void Kill(void)
{
 if(ROM)
 {
  delete[] ROM;
  ROM = nullptr;
 }
}

void CART_Debug_Init(CartInfo* c, Stream* str)
{
 std::unique_ptr<uint16[]> new_ROM(new uint16[0x100000 / sizeof(uint16)]);

 memset(new_ROM.get(), 0x00, 0x100000);
 str->read(new_ROM.get(), 0x100000, false);
 for(unsigned i = 0; i < 0x100000 / sizeof(uint16); i++)
  new_ROM[i] = MDFN_de16msb<true>(&new_ROM[i]);

 SS_SetPhysMemMap (0x02000000, 0x020FFFFF, new_ROM.get(), 0x100000, false);
 c->CS01_SetRW8W16(0x02000000, 0x020FFFFF, Debug_ROM_Read);
 c->CS01_SetRW8W16(0x02100000, /*0x02100001*/ 0x021FFFFF,
	Debug_RW_DB<uint16, false>,
	Debug_RW_DB<uint8, true>,
	Debug_RW_DB<uint16, true>);

 c->Kill = Kill;
 //
 //
 ROM = new_ROM.release();
}

}
