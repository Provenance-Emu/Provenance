/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* SimpleBitset.h:
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

#ifndef __MDFN_SIMPLE_BITSET_H
#define __MDFN_SIMPLE_BITSET_H

namespace Mednafen
{

template<size_t length>
struct SimpleBitset
{
 SimpleBitset()
 {
  reset();
 }

 SimpleBitset(const SimpleBitset<length>& rhs)
 {
  memcpy(data, rhs.data, sizeof(data));
 }

 void operator=(const SimpleBitset<length>& rhs)
 {
  memcpy(data, rhs.data, sizeof(data));
 }

 INLINE bool operator[](const size_t index) const
 {
  return (data[index >> 5] >> (index & 0x1F)) & 1;
 }

 INLINE bool operator==(const SimpleBitset<length>& rhs) const
 {
  return !memcmp(data, rhs.data, sizeof(data));
 }

 INLINE bool operator!=(const SimpleBitset<length>& rhs) const
 {
  return memcmp(data, rhs.data, sizeof(data));
 }

 INLINE void set(size_t index, bool value)
 {
  if(value)
   data[index >> 5] |= 1U << (index & 0x1F);
  else
   data[index >> 5] &= ~(1U << (index & 0x1F));
 }

 void set_multi_wrap(size_t index, bool value, unsigned count)
 {
  while(count)
  {
   const unsigned sub_count = std::min<unsigned>(count, 32);

   if(MDFN_UNLIKELY((index + sub_count + 32) >= length))
   {
    size_t c = sub_count;

    while(c--)
    {
     while(MDFN_UNLIKELY(index >= length))
      index -= length;

     set(index, value);
     index++;
    }
   }
   else
   {
    const uint64 mask = ((((uint64)1 << (sub_count - 1)) - 1) << 1) + 1;
    const size_t di = index >> 5;
    unsigned shift = index & 0x1F;

    uint64 tmp = data[di] | ((uint64)data[di + 1] << 32);

    tmp &= ~(mask << shift);
    tmp |= (value ? mask : 0) << shift;

    data[di] = tmp;
    data[di + 1] = tmp >> 32; 

    index += sub_count;
   }

   count -= sub_count;
  }
 }

 void reset(void)
 {
  memset(data, 0, sizeof(data));
 }

 //
 // Underlying data array may be accessed freely, so the bitpacking order and related semantics must stay the same.
 //
 enum : size_t { data_count = ((length + 31) >> 5) };
 uint32 data[data_count];
};

}
#endif
