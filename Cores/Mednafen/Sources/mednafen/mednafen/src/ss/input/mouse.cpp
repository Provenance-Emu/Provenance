/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* mouse.cpp:
**  Copyright (C) 2016-2017 Mednafen Team
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
#include "mouse.h"

namespace MDFN_IEN_SS
{

IODevice_Mouse::IODevice_Mouse() : buttons(0)
{

}

IODevice_Mouse::~IODevice_Mouse()
{

}

void IODevice_Mouse::Power(void)
{
 phase = -1;
 tl = true;
 data_out = 0x00;
 accum_xdelta = 0;
 accum_ydelta = 0;
}

void IODevice_Mouse::UpdateInput(const uint8* data, const int32 time_elapsed)
{
 accum_xdelta += (int16)MDFN_de16lsb(&data[0]);
 accum_ydelta -= (int16)MDFN_de16lsb(&data[2]);
 buttons = data[4] & 0xF;
}

void IODevice_Mouse::StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname_prefix)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(buttons),
  SFVAR(accum_xdelta),
  SFVAR(accum_ydelta),

  SFVAR(buffer),
  SFVAR(data_out),
  SFVAR(tl),

  SFVAR(phase),
  SFEND
 };
 char section_name[64];
 trio_snprintf(section_name, sizeof(section_name), "%s_Mouse", sname_prefix);

 if(!MDFNSS_StateAction(sm, load, data_only, StateRegs, section_name, true) && load)
  Power();
 else if(load)
 {
  if(phase < 0)
   phase = -1;
  else
   phase &= 0xF;
 }
}

uint8 IODevice_Mouse::UpdateBus(const sscpu_timestamp_t timestamp, const uint8 smpc_out, const uint8 smpc_out_asserted)
{
 uint8 tmp;

 if(smpc_out & 0x40)
 {
  if(smpc_out & 0x20)
  {
   if(!tl)
    accum_xdelta = accum_ydelta = 0;

   phase = -1;
   tl = true;
   data_out = 0x00;
  }
  else
  {
   if(tl)
    tl = false;
  }
 }
 else
 {
  if(phase < 0)
  {
   uint8 flags = 0;

   if(accum_xdelta < 0)
    flags |= 0x1;
 
   if(accum_ydelta < 0)
    flags |= 0x2;

   if(accum_xdelta > 255 || accum_xdelta < -256)
   {
    flags |= 0x4;
    accum_xdelta = (accum_xdelta < 0) ? -256 : 255;
   }

   if(accum_ydelta > 255 || accum_ydelta < -256)
   {
    flags |= 0x8;
    accum_ydelta = (accum_ydelta < 0) ? -256 : 255;
   }

   buffer[0] = 0xB;
   buffer[1] = 0xF;
   buffer[2] = 0xF;
   buffer[3] = flags;
   buffer[4] = buttons;
   buffer[5] = (accum_xdelta >> 4) & 0xF;
   buffer[6] = (accum_xdelta >> 0) & 0xF;
   buffer[7] = (accum_ydelta >> 4) & 0xF;
   buffer[8] = (accum_ydelta >> 0) & 0xF;

   for(int i = 9; i < 16; i++)
    buffer[i] = buffer[8];

   phase++;
  }

  if((bool)(smpc_out & 0x20) != tl)
  {
   phase = (phase + 1) & 0xF;
   tl = !tl;

   if(phase == 8)
    accum_xdelta = accum_ydelta = 0;
  }
  data_out = buffer[phase];
 }

 tmp = (tl << 4) | data_out;

 return (smpc_out & (smpc_out_asserted | 0xE0)) | (tmp &~ smpc_out_asserted);
}

IDIISG IODevice_Mouse_IDII =
{
 IDIIS_AxisRel("motion", "Motion",/**/ "left", "Left",/**/ "right", "Right", 0),
 IDIIS_AxisRel("motion", "Motion",/**/ "up", "Up",/**/ "down", "Down", 1),

 IDIIS_Button("left", "Left Button", 2),
 IDIIS_Button("right", "Right Button", 4),
 IDIIS_Button("middle", "Middle Button", 3),
 IDIIS_Button("start", "Start", 5),
};


}
