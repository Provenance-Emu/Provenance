/******************************************************************************/
/* Mednafen NEC PC-FX Emulation Module                                        */
/******************************************************************************/
/* gamepad.cpp:
**  Copyright (C) 2006-2016 Mednafen Team
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

#include "../pcfx.h"
#include "../input.h"
#include "gamepad.h"

namespace MDFN_IEN_PCFX
{

class PCFX_Input_Gamepad : public PCFX_Input_Device
{
 public:
 PCFX_Input_Gamepad()
 {
  buttons = 0;
 }

 virtual ~PCFX_Input_Gamepad() override
 {

 }

 virtual uint32 ReadTransferTime(void) override
 {
  return(1536);
 }

 virtual uint32 WriteTransferTime(void) override
 {
  return(1536);
 }

 virtual uint32 Read(void) override
 {
  return(buttons | (FX_SIG_PAD << 28));
 }

 virtual void Write(uint32 data) override
 {

 }


 virtual void Power(void) override
 {
  buttons = 0;
 }

 virtual void TransformInput(uint8* data, const bool DisableSR) override
 {
  if(DisableSR)
  {
   uint16 tmp = MDFN_de16lsb(data);

   if((tmp & 0xC0) == 0xC0)
    tmp &= ~0xC0;

   MDFN_en16lsb(data, tmp);
  }
 }

 virtual void Frame(const void *data) override
 {
  buttons = MDFN_de16lsb((uint8 *)data);
 }

 virtual void StateAction(StateMem *sm, const unsigned load, const bool data_only, const char *section_name) override
 {
  SFORMAT StateRegs[] =
  {
   SFVAR(buttons),
   SFEND
  };

  if(!MDFNSS_StateAction(sm, load, data_only, StateRegs, section_name, true) && load)
   Power();
 }

 private:

 uint16 buttons;
};

static const IDIIS_SwitchPos ModeSwitchPositions[] =
{
 { "a", "A" },
 { "b", "B" },
};

const IDIISG PCFX_GamepadIDII =
{
 IDIIS_Button("i", "I", 11),
 IDIIS_Button("ii", "II", 10),
 IDIIS_Button("iii", "III", 9),
 IDIIS_Button("iv", "IV", 6),
 IDIIS_Button("v", "V", 7),
 IDIIS_Button("vi", "VI", 8),
 IDIIS_Button("select", "SELECT", 4),
 IDIIS_Button("run", "RUN", 5),
 IDIIS_Button("up", "UP ↑", 0, "down"),
 IDIIS_Button("right", "RIGHT →", 3, "left"),
 IDIIS_Button("down", "DOWN ↓", 1, "up"),
 IDIIS_Button("left", "LEFT ←", 2, "right"),

 IDIIS_Switch("mode1", "MODE 1", 12, ModeSwitchPositions),
 IDIIS_Padding<1>(),
 IDIIS_Switch("mode2", "MODE 2", 13, ModeSwitchPositions),
};

PCFX_Input_Device *PCFXINPUT_MakeGamepad(void)
{
 return(new PCFX_Input_Gamepad());
}

}
