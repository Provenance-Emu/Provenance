/******************************************************************************/
/* Mednafen Sony PS1 Emulation Module                                         */
/******************************************************************************/
/* gamepad.cpp:
**  Copyright (C) 2011-2016 Mednafen Team
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

#include "../psx.h"
#include "../frontio.h"
#include "gamepad.h"

namespace MDFN_IEN_PSX
{

class InputDevice_Gamepad final : public InputDevice
{
 public:

 InputDevice_Gamepad() MDFN_COLD;
 virtual ~InputDevice_Gamepad() override MDFN_COLD;

 virtual void Power(void) override MDFN_COLD;
 virtual void StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname_prefix) override;
 virtual void UpdateInput(const void *data) override;

 //
 //
 //
 virtual void SetDTR(bool new_dtr) override;
 virtual bool GetDSR(void) override;
 virtual bool Clock(bool TxD, int32 &dsr_pulse_delay) override;

 private:

 bool dtr;

 uint8 buttons[2];

 int32 command_phase;
 uint32 bitpos;
 uint8 receive_buffer;

 uint8 command;

 uint8 transmit_buffer[3];
 uint32 transmit_pos;
 uint32 transmit_count;
};

InputDevice_Gamepad::InputDevice_Gamepad()
{
 Power();
}

InputDevice_Gamepad::~InputDevice_Gamepad()
{

}

void InputDevice_Gamepad::Power(void)
{
 dtr = 0;

 buttons[0] = buttons[1] = 0;

 command_phase = 0;

 bitpos = 0;

 receive_buffer = 0;

 command = 0;

 memset(transmit_buffer, 0, sizeof(transmit_buffer));

 transmit_pos = 0;
 transmit_count = 0;
}

void InputDevice_Gamepad::StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname_prefix)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(dtr),

  SFVAR(buttons),

  SFVAR(command_phase),
  SFVAR(bitpos),
  SFVAR(receive_buffer),

  SFVAR(command),

  SFVAR(transmit_buffer),
  SFVAR(transmit_pos),
  SFVAR(transmit_count),

  SFEND
 };
 char section_name[32];
 trio_snprintf(section_name, sizeof(section_name), "%s_Gamepad", sname_prefix);

 if(!MDFNSS_StateAction(sm, load, data_only, StateRegs, section_name, true) && load)
  Power();
 else if(load)
 {
  if(((uint64)transmit_pos + transmit_count) > sizeof(transmit_buffer))
  {
   transmit_pos = 0;
   transmit_count = 0;
  }
 }
}


void InputDevice_Gamepad::UpdateInput(const void *data)
{
 uint8 *d8 = (uint8 *)data;

 buttons[0] = d8[0];
 buttons[1] = d8[1];
}


void InputDevice_Gamepad::SetDTR(bool new_dtr)
{
 if(!dtr && new_dtr)
 {
  command_phase = 0;
  bitpos = 0;
  transmit_pos = 0;
  transmit_count = 0;
 }
 else if(dtr && !new_dtr)
 {
  //if(bitpos || transmit_count)
  // printf("[PAD] Abort communication!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n");
 }

 dtr = new_dtr;
}

bool InputDevice_Gamepad::GetDSR(void)
{
 if(!dtr)
  return(0);

 if(!bitpos && transmit_count)
  return(1);

 return(0);
}

bool InputDevice_Gamepad::Clock(bool TxD, int32 &dsr_pulse_delay)
{
 bool ret = 1;

 dsr_pulse_delay = 0;

 if(!dtr)
  return(1);

 if(transmit_count)
  ret = (transmit_buffer[transmit_pos] >> bitpos) & 1;

 receive_buffer &= ~(1 << bitpos);
 receive_buffer |= TxD << bitpos;
 bitpos = (bitpos + 1) & 0x7;

 if(!bitpos)
 {
  //printf("[PAD] Receive: %02x -- command_phase=%d\n", receive_buffer, command_phase);

  if(transmit_count)
  {
   transmit_pos++;
   transmit_count--;
  }


  switch(command_phase)
  {
   case 0:
 	  if(receive_buffer != 0x01)
	    command_phase = -1;
	  else
	  {
	   transmit_buffer[0] = 0x41;
	   transmit_pos = 0;
	   transmit_count = 1;
	   command_phase++;
	  }
	  break;

   case 1:
	command = receive_buffer;
	command_phase++;

	transmit_buffer[0] = 0x5A;

	//if(command != 0x42)
	// fprintf(stderr, "Gamepad unhandled command: 0x%02x\n", command);
	//assert(command == 0x42);
	if(command == 0x42)
	{
	 //printf("PAD COmmand 0x42, sl=%u\n", GPU->GetScanlineNum());

	 transmit_buffer[1] = 0xFF ^ buttons[0];
	 transmit_buffer[2] = 0xFF ^ buttons[1];
         transmit_pos = 0;
         transmit_count = 3;
	}
	else
	{
	 command_phase = -1;
	 transmit_buffer[1] = 0;
	 transmit_buffer[2] = 0;
         transmit_pos = 0;
         transmit_count = 0;
	}
	break;

  }
 }

 if(!bitpos && transmit_count)
  dsr_pulse_delay = 0x40; //0x100;

 return(ret);
}

InputDevice *Device_Gamepad_Create(void)
{
 return new InputDevice_Gamepad();
}


IDIISG Device_Gamepad_IDII =
{
 IDIIS_Button("select", "SELECT", 4, NULL),
 IDIIS_Padding<1>(),
 IDIIS_Padding<1>(),
 IDIIS_Button("start", "START", 5, NULL),
 IDIIS_Button("up", "UP ↑", 0, "down"),
 IDIIS_Button("right", "RIGHT →", 3, "left"),
 IDIIS_Button("down", "DOWN ↓", 1, "up"),
 IDIIS_Button("left", "LEFT ←", 2, "right"),

 IDIIS_Button("l2", "L2 (rear left shoulder)", 11, NULL),
 IDIIS_Button("r2", "R2 (rear right shoulder)", 13, NULL),
 IDIIS_Button("l1", "L1 (front left shoulder)", 10, NULL),
 IDIIS_Button("r1", "R1 (front right shoulder)", 12, NULL),

 IDIIS_ButtonCR("triangle", "△ (upper)", 6, NULL),
 IDIIS_ButtonCR("circle", "○ (right)", 9, NULL),
 IDIIS_ButtonCR("cross", "x (lower)", 7, NULL),
 IDIIS_ButtonCR("square", "□ (left)", 8, NULL),
};

IDIISG Device_Dancepad_IDII =
{
 IDIIS_Button("select", "SELECT", 0, NULL),
 IDIIS_Padding<1>(),
 IDIIS_Padding<1>(),
 IDIIS_Button("start", "START", 1, NULL),

 IDIIS_Button("up", "UP ↑", 3, 	NULL),
 IDIIS_Button("right", "RIGHT →", 6, 	NULL),
 IDIIS_Button("down", "DOWN ↓", 8, 	NULL),
 IDIIS_Button("left", "LEFT ←", 5, 	NULL),

 IDIIS_Padding<1>(),
 IDIIS_Padding<1>(),
 IDIIS_Padding<1>(),
 IDIIS_Padding<1>(),

 IDIIS_Button("triangle", "△ (lower left)", 7, NULL),
 IDIIS_Button("circle", "○ (upper right)", 4, NULL),
 IDIIS_Button("cross", "x (upper left)", 2, NULL),
 IDIIS_Button("square", "□ (lower right)", 9, NULL),
};


}
