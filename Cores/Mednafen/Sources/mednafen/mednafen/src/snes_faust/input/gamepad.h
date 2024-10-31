/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* gamepad.h:
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

#ifndef __MDFN_SNES_FAUST_INPUT_GAMEPAD_H
#define __MDFN_SNES_FAUST_INPUT_GAMEPAD_H

namespace MDFN_IEN_SNES_FAUST
{

class InputDevice_Gamepad final : public InputDevice
{
 public:

 InputDevice_Gamepad() MDFN_COLD;
 virtual ~InputDevice_Gamepad() override MDFN_COLD;

 virtual void Power(void) override MDFN_COLD;

 virtual void MDFN_FASTCALL UpdatePhysicalState(const uint8* data) override;

 virtual uint8 MDFN_FASTCALL Read(bool IOB) override MDFN_HOT;
 virtual void MDFN_FASTCALL SetLatch(bool state) override MDFN_HOT;

 virtual void StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname_prefix) override;

 private:
 uint16 buttons;
 uint32 latched;

 bool pls;
};

MDFN_HIDE extern const IDIISG GamepadIDII;

}

#endif
