/******************************************************************************/
/* Mednafen Sony PS1 Emulation Module                                         */
/******************************************************************************/
/* masmem.h:
**  Copyright (C) 2012-2016 Mednafen Team
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

#ifndef __MDFN_PSX_MASMEM_H
#define __MDFN_PSX_MASMEM_H

// address must not be >= size specified by template parameter, and address must be a multiple of the byte-size of the
// unit(1,2,4) being read(except for Read/WriteU24, which only needs to be byte-aligned).
//

template<unsigned size, bool big_endian> //, unsigned pre_padding_count, unsigned post_padding_count>
struct MultiAccessSizeMem
{
 //uint8 pre_padding[pre_padding_count ? pre_padding_count : 1];

 union
 {
  uint8 data8[size];
  uint64 alignment_dummy[1];
 };

 //uint8 post_padding[post_padding_count ? post_padding_count : 1];

 template<typename T>
 INLINE T Read(uint32 address)
 {
  return MDFN_deXsb<big_endian, T, true>(data8 + address);
 }

 template<typename T>
 INLINE void Write(uint32 address, T value)
 {
  MDFN_enXsb<big_endian, T, true>(data8 + address, value);
 }

 INLINE uint8 ReadU8(uint32 address)
 {
  return Read<uint8>(address);
 }

 INLINE uint16 ReadU16(uint32 address)
 {
  return Read<uint16>(address);
 }

 INLINE uint32 ReadU32(uint32 address)
 {
  return Read<uint32>(address);
 }

 INLINE uint32 ReadU24(uint32 address)
 {
  uint32 ret;

  if(!big_endian)
  {
   ret = ReadU8(address) << 0;
   ret |= ReadU8(address + 1) << 8;
   ret |= ReadU8(address + 2) << 16;
  }
  else
  {
   ret = ReadU8(address) << 16;
   ret |= ReadU8(address + 1) << 8;
   ret |= ReadU8(address + 2) << 0;
  }
  return(ret);
 }


 INLINE void WriteU8(uint32 address, uint8 value)
 {
  Write<uint8>(address, value);
 }

 INLINE void WriteU16(uint32 address, uint16 value)
 {
  Write<uint16>(address, value);
 }

 INLINE void WriteU32(uint32 address, uint32 value)
 {
  Write<uint32>(address, value);
 }

 INLINE void WriteU24(uint32 address, uint32 value)
 {
  if(!big_endian)
  {
   WriteU8(address + 0, value >> 0);
   WriteU8(address + 1, value >> 8);
   WriteU8(address + 2, value >> 16);
  }
  else
  {
   WriteU8(address + 0, value >> 16);
   WriteU8(address + 1, value >> 8);
   WriteU8(address + 2, value >> 0);
  }
 }
};

#endif
