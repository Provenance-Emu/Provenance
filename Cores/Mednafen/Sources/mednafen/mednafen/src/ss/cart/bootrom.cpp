/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* bootrom.cpp - Bootable ROM cart emulation
**  Copyright (C) 2017-2023 Mednafen Team
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
#include "bootrom.h"
#include "backup.h"

#include <mednafen/hash/sha256.h>

namespace MDFN_IEN_SS
{

static uint16* ROM = nullptr;
static uint32 ROM_Mask[2];

static MDFN_HOT void CS0_ROM_Read(uint32 A, uint16* DB)
{
 const uint32 offs = (A - 0x02000000) & ROM_Mask[0];

 *DB = ne16_rbo_be<uint16>(ROM, offs);
}

static MDFN_HOT void CS1_ROM_Read(uint32 A, uint16* DB)
{
 const uint32 offs = 0x02000000 + ((A - 0x04000000) & ROM_Mask[1]);

 *DB = ne16_rbo_be<uint16>(ROM, offs);
}

static MDFN_COLD void Kill(void)
{
 if(ROM)
 {
  delete[] ROM;
  ROM = nullptr;
 }
}

void CART_BootROM_Init(CartInfo* c, Stream* str)
{
 try
 {
  const uint64 ss = str->size();
  const uint64 min_size = 1;
  const uint64 max_size = 0x3000000;

  if(ss < min_size)
   throw MDFN_Error(0, _("Bootable Saturn cart ROM image is smaller than the minimum of %llu bytes."), (unsigned long long)min_size);

  if(ss > max_size)
  throw MDFN_Error(0, _("Bootable Saturn cart ROM image is larger than the maximum of %llu bytes."), (unsigned long long)max_size);
  //
  //
  uint32 ROM_Size;

  if(ss > 0x2000000)
   ROM_Size = 0x2000000 + round_up_pow2((ss - 0x2000000 + 0xFFFF) &~ 0xFFFF);
  else
   ROM_Size = round_up_pow2((ss + 0xFFFF) &~ 0xFFFF);

  assert(ROM_Size >= ss);
  //
  //
  sha256_hasher h;
  sha256_digest dig;

  ROM = new uint16[ROM_Size / sizeof(uint16)];
  memset(ROM, 0x00, ROM_Size);
  str->read(ROM, ss);
  h.process(ROM, ss);
  dig = h.digest();
  memcpy(MDFNGameInfo->MD5, dig.data(), 16);

  for(unsigned i = 0; i < ROM_Size / sizeof(uint16); i++)
   ROM[i] = MDFN_de16msb<true>(&ROM[i]);

  SS_SetPhysMemMap (0x02000000, 0x03FFFFFF, ROM, std::min<uint32>(0x02000000, ROM_Size), false);
  c->CS01_SetRW8W16(0x02000000, 0x03FFFFFF, CS0_ROM_Read);

  c->Kill = Kill;

  ROM_Mask[0] = (round_up_pow2(ROM_Size) - 1) & 0x01FFFFFE;

  if(ROM_Size > 0x2000000)
  {
   ROM_Mask[1] = (round_up_pow2(ROM_Size - 0x2000000) - 1) & 0x00FFFFFE;

   SS_SetPhysMemMap (0x04000000, 0x04FFFFFF, ROM + (0x02000000 / sizeof(uint16)), ROM_Size - 0x02000000, false);
   c->CS01_SetRW8W16(0x04000000, 0x04FFFFFF, CS1_ROM_Read);
  }
  else
  {
   CART_Backup_Init(c);
   assert(c->Kill == Kill);
  }
 }
 catch(...)
 {
  Kill();
  throw;
 }
}

}
