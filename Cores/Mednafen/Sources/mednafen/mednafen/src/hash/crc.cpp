/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* crc.cpp:
**  Copyright (C) 2018 Mednafen Team
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

#include <mednafen/types.h>
#include "crc.h"

namespace Mednafen
{

uint16 crc16_ccitt(const void* data, const size_t len)
{
 static const uint16 tab[16] = { 0x0000, 0x1021, 0x2042, 0x3063, 0x4084, 0x50a5, 0x60c6, 0x70e7, 0x8108, 0x9129, 0xa14a, 0xb16b, 0xc18c, 0xd1ad, 0xe1ce, 0xf1ef };
 uint8* p = (uint8*)data;
 uint16 r = 0;

#if 0
 for(unsigned i = 0; i < 16; i++)
 {
  r = i << 12;
  for(unsigned b = 4; b; b--)
   r = (r << 1) ^ (((int16)r >> 15) & 0x1021);
  printf("0x%04x, ", r);
 }
 exit(0);
#endif

 for(size_t i = 0; MDFN_LIKELY(i < len); i++)
 {
  r ^= p[i] << 8;
  r = (r << 4) ^ tab[r >> 12];
  r = (r << 4) ^ tab[r >> 12];
  //r = (r << 4) ^ ((r >> 12) * 0x1021);
  //r = (r << 4) ^ ((r >> 12) * 0x1021);
 }

 return r;
}

}
