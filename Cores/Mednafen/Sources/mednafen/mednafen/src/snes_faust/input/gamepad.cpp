/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* gamepad.cpp:
**  Copyright (C) 2015-2022 Mednafen Team
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
#include "gamepad.h"

namespace MDFN_IEN_SNES_FAUST
{

InputDevice_Gamepad::InputDevice_Gamepad()
{
 pls = false;
 buttons = 0;
}

InputDevice_Gamepad::~InputDevice_Gamepad()
{

}

void InputDevice_Gamepad::StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname_prefix)
{
 SFORMAT StateRegs[] = 
 {
  SFVAR(buttons),
  SFVAR(latched),
  SFVAR(pls),
  SFEND
 };

 char sname[64] = "GP_";

 strncpy(sname + 3, sname_prefix, sizeof(sname) - 3);
 sname[sizeof(sname) - 1] = 0;

 //printf("%s\n", sname);

 if(!MDFNSS_StateAction(sm, load, data_only, StateRegs, sname, true) && load)
  Power();
 else if(load)
 {

 }
}


void InputDevice_Gamepad::Power(void)
{
 latched = ~0U;
}

void InputDevice_Gamepad::UpdatePhysicalState(const uint8* data)
{
 buttons = MDFN_de16lsb(data);
 if(pls)
  latched = buttons | 0xFFFF0000;
}

uint8 InputDevice_Gamepad::Read(bool IOB)
{
 uint8 ret = latched & 1;

 if(!pls)
  latched = (int32)latched >> 1;

 return ret;
}

void InputDevice_Gamepad::SetLatch(bool state)
{
 if(pls && !state)
  latched = buttons | 0xFFFF0000;

 pls = state;
}

MDFN_HIDE extern const IDIISG GamepadIDII =
{
 IDIIS_ButtonCR("b", "B (center, lower)", 7, NULL),
 IDIIS_ButtonCR("y", "Y (left)", 6, NULL),
 IDIIS_Button("select", "SELECT", 4, NULL),
 IDIIS_Button("start", "START", 5, NULL),
 IDIIS_Button("up", "UP ↑", 0, "down"),
 IDIIS_Button("down", "DOWN ↓", 1, "up"),
 IDIIS_Button("left", "LEFT ←", 2, "right"),
 IDIIS_Button("right", "RIGHT →", 3, "left"),
 IDIIS_ButtonCR("a", "A (right)", 9, NULL),
 IDIIS_ButtonCR("x", "X (center, upper)", 8, NULL),
 IDIIS_Button("l", "Left Shoulder", 10, NULL),
 IDIIS_Button("r", "Right Shoulder", 11, NULL),
};


}
