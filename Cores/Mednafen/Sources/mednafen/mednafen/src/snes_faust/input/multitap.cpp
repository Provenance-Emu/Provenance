/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* multitap.cpp:
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
#include "multitap.h"

namespace MDFN_IEN_SNES_FAUST
{

void InputDevice_MTap::Power(void)
{
 for(unsigned mport = 0; mport < 4; mport++)
  MPorts[mport]->Power();
}

void InputDevice_MTap::StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname_prefix)
{
 SFORMAT StateRegs[] = 
 {
  SFVAR(pls),
  SFEND
 };

 char sname[64] = "MT_";

 strncpy(sname + 3, sname_prefix, sizeof(sname) - 3);
 sname[sizeof(sname) - 1] = 0;

 if(!MDFNSS_StateAction(sm, load, data_only, StateRegs, sname, true) && load)
  Power();
 else
 {
  for(unsigned mport = 0; mport < 4; mport++)
  {
   sname[2] = '0' + mport;
   MPorts[mport]->StateAction(sm, load, data_only, sname);
  }

  if(load)
  {

  }
 }
}

InputDevice_MTap::InputDevice_MTap()
{
 for(unsigned mport = 0; mport < 4; mport++)
  MPorts[mport] = nullptr;

 pls = false;
}

InputDevice_MTap::~InputDevice_MTap()
{

}

uint8 InputDevice_MTap::Read(bool IOB)
{
 uint8 ret;

 ret = ((MPorts[(!IOB << 1) + 0]->Read(false) & 0x1) << 0) | ((MPorts[(!IOB << 1) + 1]->Read(false) & 0x1) << 1);

 if(pls)
  ret = 0x2;

 return ret;
}

void InputDevice_MTap::SetLatch(bool state)
{
 for(unsigned mport = 0; mport < 4; mport++)
  MPorts[mport]->SetLatch(state);

 pls = state;
}

void InputDevice_MTap::SetSubDevice(const unsigned mport, InputDevice* device)
{
 MPorts[mport] = device;
}

}
