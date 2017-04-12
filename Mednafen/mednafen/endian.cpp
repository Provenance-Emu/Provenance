/* Mednafen - Multi-system Emulator
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "mednafen.h"
#include "endian.h"

void Endian_A16_Swap(void *src, uint32 nelements)
{
 uint32 i;
 uint8 *nsrc = (uint8 *)src;

 for(i = 0; i < nelements; i++)
 {
  uint8 tmp = nsrc[i * 2];

  nsrc[i * 2] = nsrc[i * 2 + 1];
  nsrc[i * 2 + 1] = tmp;
 }
}

void Endian_A32_Swap(void *src, uint32 nelements)
{
 uint32 i;
 uint8 *nsrc = (uint8 *)src;

 for(i = 0; i < nelements; i++)
 {
  uint8 tmp1 = nsrc[i * 4];
  uint8 tmp2 = nsrc[i * 4 + 1];

  nsrc[i * 4] = nsrc[i * 4 + 3];
  nsrc[i * 4 + 1] = nsrc[i * 4 + 2];

  nsrc[i * 4 + 2] = tmp2;
  nsrc[i * 4 + 3] = tmp1;
 }
}

void Endian_A64_Swap(void *src, uint32 nelements)
{
 uint32 i;
 uint8 *nsrc = (uint8 *)src;

 for(i = 0; i < nelements; i++)
 {
  uint8 *base = &nsrc[i * 8];

  for(int z = 0; z < 4; z++)
  {
   uint8 tmp = base[z];

   base[z] = base[7 - z];
   base[7 - z] = tmp;
  }
 }
}

void Endian_A16_NE_LE(void *src, uint32 nelements)
{
 #ifdef MSB_FIRST
 Endian_A16_Swap(src, nelements);
 #endif
}

void Endian_A32_NE_LE(void *src, uint32 nelements)
{
 #ifdef MSB_FIRST
 Endian_A32_Swap(src, nelements);
 #endif
}

void Endian_A64_NE_LE(void *src, uint32 nelements)
{
 #ifdef MSB_FIRST
 Endian_A64_Swap(src, nelements);
 #endif
}

//
//
//
void Endian_A16_NE_BE(void *src, uint32 nelements)
{
 #ifdef LSB_FIRST
 Endian_A16_Swap(src, nelements);
 #endif
}

void Endian_A32_NE_BE(void *src, uint32 nelements)
{
 #ifdef LSB_FIRST
 Endian_A32_Swap(src, nelements);
 #endif
}

void Endian_A64_NE_BE(void *src, uint32 nelements)
{
 #ifdef LSB_FIRST
 Endian_A64_Swap(src, nelements);
 #endif
}

static void FlipByteOrder(uint8 *src, uint32 count)
{
 uint8 *start=src;
 uint8 *end=src+count-1;

 if((count&1) || !count)        return;         /* This shouldn't happen. */

 count >>= 1;

 while(count--)
 {
  uint8 tmp;

  tmp=*end;
  *end=*start;
  *start=tmp;
  end--;
  start++;
 }
}

void Endian_V_NE_LE(void *src, uint32 bytesize)
{
 #ifdef MSB_FIRST
 FlipByteOrder((uint8 *)src, bytesize);
 #endif
}

void Endian_V_NE_BE(void *src, uint32 bytesize)
{
 #ifdef LSB_FIRST
 FlipByteOrder((uint8 *)src, bytesize);
 #endif
}
