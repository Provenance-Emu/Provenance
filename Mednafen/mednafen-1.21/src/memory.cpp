/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* memory.cpp:
**  Copyright (C) 2014-2017 Mednafen Team
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

#include "mednafen.h"
#include "memory.h"

void MDFN_FastMemXOR(void* dest, const void* src, size_t count)
{
 const unsigned alch = ((uintptr_t)dest | (uintptr_t)src);

 uint8* pd = (uint8*)dest;
 const uint8* sd = (const uint8*)src;

 if((alch & 0x7) == 0)
 {
  while(MDFN_LIKELY(count >= 32))
  {
   MDFN_ennsb<uint64, true>(&pd[0], MDFN_densb<uint64, true>(&pd[0]) ^ MDFN_densb<uint64, true>(&sd[0]));
   MDFN_ennsb<uint64, true>(&pd[8], MDFN_densb<uint64, true>(&pd[8]) ^ MDFN_densb<uint64, true>(&sd[8]));
   MDFN_ennsb<uint64, true>(&pd[16], MDFN_densb<uint64, true>(&pd[16]) ^ MDFN_densb<uint64, true>(&sd[16]));
   MDFN_ennsb<uint64, true>(&pd[24], MDFN_densb<uint64, true>(&pd[24]) ^ MDFN_densb<uint64, true>(&sd[24]));

   pd += 32;
   sd += 32;
   count -= 32;
  }
 }

 for(size_t i = 0; MDFN_LIKELY(i < count); i++)
  pd[i] ^= sd[i];
}

