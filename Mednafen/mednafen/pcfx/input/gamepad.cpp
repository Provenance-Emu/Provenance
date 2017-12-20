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

#include "../pcfx.h"
#include "../input.h"
#include "gamepad.h"

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

static const char* ModeSwitchPositions[] =
{
 "A",
 "B",
};

const IDIISG PCFX_GamepadIDII =
{
 { "i", "I", 11, IDIT_BUTTON, NULL },
 { "ii", "II", 10, IDIT_BUTTON, NULL },
 { "iii", "III", 9, IDIT_BUTTON, NULL },
 { "iv", "IV", 6, IDIT_BUTTON, NULL },
 { "v", "V", 7, IDIT_BUTTON, NULL },
 { "vi", "VI", 8, IDIT_BUTTON, NULL },
 { "select", "SELECT", 4, IDIT_BUTTON, NULL },
 { "run", "RUN", 5, IDIT_BUTTON, NULL },
 { "up", "UP ↑", 0, IDIT_BUTTON, "down" },
 { "right", "RIGHT →", 3, IDIT_BUTTON, "left" },
 { "down", "DOWN ↓", 1, IDIT_BUTTON, "up" },
 { "left", "LEFT ←", 2, IDIT_BUTTON, "right" },

 IDIIS_Switch("mode1", "MODE 1", 12, ModeSwitchPositions, sizeof(ModeSwitchPositions) / sizeof(ModeSwitchPositions[0])),
 { NULL, "empty", 0, IDIT_BUTTON },
 IDIIS_Switch("mode2", "MODE 2", 13, ModeSwitchPositions, sizeof(ModeSwitchPositions) / sizeof(ModeSwitchPositions[0])),
};

PCFX_Input_Device *PCFXINPUT_MakeGamepad(void)
{
 return(new PCFX_Input_Gamepad());
}
