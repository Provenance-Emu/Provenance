/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* mouse.cpp:
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

//
// The (non-linear) delta-scaling effects of SNES mouse sensitivity
// settings 1 and 2 are not emulated here, and probably won't be.
// Games are inconsistent about what settings they use, and many(most?)
// don't seem to have a way to change the setting in-game.
//
// There would also be the issue of having to fiddle with Mednafen's own mouse
// sensitivity(linear scaling) setting to a pedantic degree to get the
// acceleration curve to feel accurate(or subjectively good).
//
// If some sort of acceleration is ever implemented here, remember to derive
// the mouse delta scaling coefficient from the average(or otherwise
// lowpass-filtered) raw delta values from over 100ms or so.  This will smooth
// out irregularities caused by the video and mouse input update from the OS and
// physical hardware being done asynchronously(with coarse timing granularity
// caused by vsync and USB/whatever polling interval) to the emulation thread.
//

#include "common.h"
#include "mouse.h"

namespace MDFN_IEN_SNES_FAUST
{

InputDevice_Mouse::InputDevice_Mouse()
{
 pls = false;
 buttons = 0;
}

InputDevice_Mouse::~InputDevice_Mouse()
{

}

void InputDevice_Mouse::StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname_prefix)
{
 SFORMAT StateRegs[] = 
 {
  SFVAR(accum_xdelta),
  SFVAR(accum_ydelta),

  SFVAR(latched),
  SFVAR(sensitivity),
  SFVAR(buttons),

  SFVAR(pls),

  SFEND
 };

 char sname[64] = "MO_";

 strncpy(sname + 3, sname_prefix, sizeof(sname) - 3);
 sname[sizeof(sname) - 1] = 0;

 if(!MDFNSS_StateAction(sm, load, data_only, StateRegs, sname, true) && load)
  Power();
 else if(load)
 {
  sensitivity %= 3;
 }
}


void InputDevice_Mouse::Power(void)
{
 latched = ~0U;
 accum_xdelta = 0;
 accum_ydelta = 0;
 sensitivity = 0;
}

void InputDevice_Mouse::UpdatePhysicalState(const uint8* data)
{
 accum_xdelta += (int16)MDFN_de16lsb(&data[0]);
 accum_ydelta += (int16)MDFN_de16lsb(&data[2]);

 buttons = data[4] & 0x3;
 //printf("Butt: %02x %02x % 3d % 3d\n", buttons, sensitivity, accum_xdelta, accum_ydelta);
}

uint8 InputDevice_Mouse::Read(bool IOB)
{
 uint8 ret = (int32)latched < 0;

 if(!pls)
  latched = (latched << 1) | 1;
 else
  sensitivity = (sensitivity + 1 + (sensitivity == 0x2)) & 0x3;

 return ret;
}

void InputDevice_Mouse::SetLatch(bool state)
{
 if(pls && !state)
 {
  const bool x_dir = (accum_xdelta < 0);
  const bool y_dir = (accum_ydelta < 0);
  unsigned x = abs(accum_xdelta);
  unsigned y = abs(accum_ydelta);

  x = std::min<unsigned>(0x7F, x);
  y = std::min<unsigned>(0x7F, y);

  latched = 0;

  latched |= x << 0;
  latched |= x_dir << 7;

  latched |= y << 8;
  latched |= y_dir << 15;

  latched |= 0x1 << 16;

  latched |= sensitivity << 20;

  latched |= buttons << 22;
  //
  //
  accum_xdelta = 0;
  accum_ydelta = 0;
 }

 pls = state;
}

MDFN_HIDE extern const IDIISG MouseIDII =
{
 IDIIS_AxisRel("motion", "Motion",/**/ "left", "Left",/**/ "right", "Right", 0),
 IDIIS_AxisRel("motion", "Motion",/**/ "up", "Up",/**/ "down", "Down", 1),

 IDIIS_Button("left", "Left Button", 2),
 IDIIS_Button("right", "Right Button", 3),
};


}
