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

#include <mednafen/mednafen.h>

#include <math.h>

const IDIISG IDII_Empty;

IDIISG::IDIISG()
{
 InputByteSize = 0;
}

IDIISG::IDIISG(std::initializer_list<InputDeviceInputInfoStruct> l) : std::vector<InputDeviceInputInfoStruct>(l)
{
 size_t bit_offset = 0;

 for(auto& idii : *this)
 {
  size_t bit_size = 0;
  size_t bit_align = 1;

  switch(idii.Type)
  {
   default:
	abort();
	break;

   case IDIT_BUTTON:
   case IDIT_BUTTON_CAN_RAPID:
	bit_size = 1;
	break;

   case IDIT_SWITCH:
	bit_size = ceil(log2(idii.SwitchNumPos));
	break;

   case IDIT_STATUS:
	bit_size = ceil(log2(idii.StatusNumStates));
	break;

   case IDIT_X_AXIS:
   case IDIT_Y_AXIS:
	bit_size = 16;
	bit_align = 8;
	break;

   case IDIT_X_AXIS_REL:
   case IDIT_Y_AXIS_REL:
	bit_size = 32;
	bit_align = 8;
	break;

   case IDIT_BYTE_SPECIAL:
	bit_size = 8;
	bit_align = 8;
	break;

   case IDIT_BUTTON_ANALOG:
	bit_size = 16;
	bit_align = 8;
	break;

   case IDIT_RUMBLE:
	bit_size = 16;
	bit_align = 8;
	break;

  }

  bit_offset = (bit_offset + (bit_align - 1)) &~ (bit_align - 1);

 // printf("%s, %zu(%zu)\n", idii.SettingName, bit_offset, bit_offset / 8);

  idii.BitSize = bit_size;
  idii.BitOffset = bit_offset;

  assert(idii.BitSize == bit_size);
  assert(idii.BitOffset == bit_offset);

  bit_offset += bit_size;
 }

 InputByteSize = (bit_offset + 7) / 8;
}


