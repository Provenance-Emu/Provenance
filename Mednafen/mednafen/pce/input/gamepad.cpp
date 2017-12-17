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

#include "../pce.h"
#include "../input.h"
#include "gamepad.h"

namespace MDFN_IEN_PCE
{

class PCE_Input_Gamepad : public PCE_Input_Device
{
 public:
 PCE_Input_Gamepad();
 virtual void TransformInput(uint8* data, const bool DisableSR) override;
 virtual void Power(int32 timestamp) override;
 virtual void Write(int32 timestamp, bool old_SEL, bool new_SEL, bool old_CLR, bool new_CLR) override;
 virtual uint8 Read(int32 timestamp) override;
 virtual void Update(const void *data) override;
 virtual int StateAction(StateMem *sm, int load, int data_only, const char *section_name) override;


 private:
 bool SEL, CLR;
 uint16 buttons;
 bool AVPad6Which;
};


PCE_Input_Gamepad::PCE_Input_Gamepad()
{
 Power(0); // FIXME?
}

void PCE_Input_Gamepad::Power(int32 timestamp)
{
 SEL = 0;
 CLR = 0;
 buttons = 0;
 AVPad6Which = 0;
}

void PCE_Input_Gamepad::TransformInput(uint8* data, const bool DisableSR)
{
 if(DisableSR)
 {
  uint16 tmp = MDFN_de16lsb(data);

  if((tmp & 0xC) == 0xC)
   tmp &= ~0xC;

  MDFN_en16lsb(data, tmp);
 }
}

void PCE_Input_Gamepad::Update(const void *data)
{
 buttons = MDFN_de16lsb((uint8 *)data);
}

uint8 PCE_Input_Gamepad::Read(int32 timestamp)
{
 uint8 ret = 0xF;

 if(AVPad6Which && (buttons & 0x1000))
 {
  if(SEL)
   ret ^= 0xF;
  else
   ret ^= (buttons >> 8) & 0x0F;
 }
 else
 {
  if(SEL)
   ret ^= (buttons >> 4) & 0x0F;
  else
   ret ^= buttons & 0x0F;
 }

 //if(CLR)
 // ret = 0;

 return(ret);
}

void PCE_Input_Gamepad::Write(int32 timestamp, bool old_SEL, bool new_SEL, bool old_CLR, bool new_CLR)
{
 SEL = new_SEL;
 CLR = new_CLR;

 //if(old_SEL && new_SEL && old_CLR && !new_CLR)
 if(!old_SEL && new_SEL)
  AVPad6Which = !AVPad6Which;
}

int PCE_Input_Gamepad::StateAction(StateMem *sm, int load, int data_only, const char *section_name)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(SEL),
  SFVAR(CLR),
  SFVAR(buttons),
  SFVAR(AVPad6Which),
  SFEND
 };
 int ret =  MDFNSS_StateAction(sm, load, data_only, StateRegs, section_name);

 return(ret);
}

static const char* ModeSwitchPositions[] =
{
 gettext_noop("2-button"),
 gettext_noop("6-button"),
};

const IDIISG PCE_GamepadIDII =
{
 { "i", "I", 12, IDIT_BUTTON_CAN_RAPID, NULL },
 { "ii", "II", 11, IDIT_BUTTON_CAN_RAPID, NULL },
 { "select", "SELECT", 4, IDIT_BUTTON, NULL },
 { "run", "RUN", 5, IDIT_BUTTON, NULL },
 { "up", "UP ↑", 0, IDIT_BUTTON, "down" },
 { "right", "RIGHT →", 3, IDIT_BUTTON, "left" },
 { "down", "DOWN ↓", 1, IDIT_BUTTON, "up" },
 { "left", "LEFT ←", 2, IDIT_BUTTON, "right" },
 { "iii", "III", 10, IDIT_BUTTON, NULL },
 { "iv", "IV", 7, IDIT_BUTTON, NULL },
 { "v", "V", 8, IDIT_BUTTON, NULL },
 { "vi", "VI", 9, IDIT_BUTTON, NULL },
 IDIIS_Switch("mode_select", "Mode", 6, ModeSwitchPositions, sizeof(ModeSwitchPositions) / sizeof(ModeSwitchPositions[0])),
};

PCE_Input_Device *PCEINPUT_MakeGamepad(void)
{
 return new PCE_Input_Gamepad();
}

};
