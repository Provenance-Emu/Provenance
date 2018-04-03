/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* gamepad.h:
**  Copyright (C) 2015-2017 Mednafen Team
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

#ifndef __MDFN_SS_INPUT_GAMEPAD_H
#define __MDFN_SS_INPUT_GAMEPAD_H

namespace MDFN_IEN_SS
{

class IODevice_Gamepad final : public IODevice
{
 public:
 IODevice_Gamepad() MDFN_COLD;
 virtual ~IODevice_Gamepad() override MDFN_COLD;

 virtual void Power(void) override MDFN_COLD;
 virtual void UpdateInput(const uint8* data, const int32 time_elapsed) override;
 virtual void StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname_prefix) override;

 virtual uint8 UpdateBus(const sscpu_timestamp_t timestamp, const uint8 smpc_out, const uint8 smpc_out_asserted) override;

 private:
 uint16 buttons;
};


extern IDIISG IODevice_Gamepad_IDII;

}

#endif
