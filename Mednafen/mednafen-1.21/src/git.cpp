/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* git.cpp:
**  Copyright (C) 2014-2016 Mednafen Team
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

#include <mednafen/mednafen.h>

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

   case IDIT_PADDING:
	bit_size = idii.BitSize;
	break;

   case IDIT_BUTTON:
   case IDIT_BUTTON_CAN_RAPID:
	bit_size = 1;

#if 0
	if(idii.Button.ExcludeName)
	{
	 bool found = false;

	 //printf("%s\n", idii.Button.ExcludeName);

	 for(auto& idii_sub : *this)
	 {
	  if(&idii == &idii_sub || !idii_sub.SettingName)
	   continue;

	  if(!strcmp(idii.Button.ExcludeName, idii_sub.SettingName))
	  {
	   found = true;
	   break;
	  }
 	 }
	 if(!found)
	  abort();
	}
	else if(strstr(idii.SettingName, "up") || strstr(idii.SettingName, "down") || strstr(idii.SettingName, "left") || strstr(idii.SettingName, "right"))
	{
	 printf("Suspicious: %s, %s\n", idii.SettingName, idii.Name);
	}
#endif
	break;

   case IDIT_RESET_BUTTON:
	bit_size = 1;
	break;

   case IDIT_SWITCH:
	bit_size = ceil(log2(idii.Switch.NumPos));
	break;

   case IDIT_STATUS:
	bit_size = ceil(log2(idii.Status.NumStates));
	break;

   case IDIT_POINTER_X:
   case IDIT_POINTER_Y:
	bit_size = 16;
	bit_align = 8;
	break;

   case IDIT_AXIS_REL:
	bit_size = 16;
	bit_align = 8;
	break;

   case IDIT_BYTE_SPECIAL:
	bit_size = 8;
	bit_align = 8;
	break;

   case IDIT_AXIS:
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

const std::vector<CheatFormatStruct> CheatFormatInfo_Empty;

const CheatInfoStruct CheatInfo_Empty =
{
 NULL,
 NULL,

 NULL,
 NULL,

 CheatFormatInfo_Empty
};

