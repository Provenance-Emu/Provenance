/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* input_device.h:
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

#ifndef __MDFN_SNES_FAUST_INPUT_DEVICE_H
#define __MDFN_SNES_FAUST_INPUT_DEVICE_H

namespace MDFN_IEN_SNES_FAUST
{

class InputDevice
{
 public:

 InputDevice() MDFN_COLD;
 virtual ~InputDevice() MDFN_COLD;

 virtual void Power(void) MDFN_COLD;

 virtual void MDFN_FASTCALL UpdatePhysicalState(const uint8* data);

 virtual uint8 MDFN_FASTCALL Read(bool IOB) MDFN_HOT;
 virtual void MDFN_FASTCALL SetLatch(bool state) MDFN_HOT;

 virtual void StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname_prefix);
};

}

#endif
