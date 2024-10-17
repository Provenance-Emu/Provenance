/******************************************************************************/
/* Mednafen Sony PS1 Emulation Module                                         */
/******************************************************************************/
/* dualanalog.cpp:
**  Copyright (C) 2012-2016 Mednafen Team
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
#include "dualanalog.h"

namespace MDFN_IEN_PSX
{

class InputDevice_DualAnalog final : public InputDevice
{
 public:

 InputDevice_DualAnalog(bool joystick_mode_) MDFN_COLD;
 virtual ~InputDevice_DualAnalog() override MDFN_COLD;

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

 bool joystick_mode;
 bool dtr;

 uint8 buttons[2];
 uint8 axes[2][2];

 int32 command_phase;
 uint32 bitpos;
 uint8 receive_buffer;

 uint8 command;

 uint8 transmit_buffer[8];
 uint32 transmit_pos;
 uint32 transmit_count;
};

InputDevice_DualAnalog::InputDevice_DualAnalog(bool joystick_mode_) : joystick_mode(joystick_mode_)
{
 Power();
}

InputDevice_DualAnalog::~InputDevice_DualAnalog()
{

}

void InputDevice_DualAnalog::Power(void)
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

void InputDevice_DualAnalog::StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname_prefix)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(dtr),

  SFVAR(buttons),
  SFVARN(axes, "&axes[0][0]"),

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
 trio_snprintf(section_name, sizeof(section_name), "%s_DualAnalog", sname_prefix);

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


void InputDevice_DualAnalog::UpdateInput(const void *data)
{
 uint8 *d8 = (uint8 *)data;

 buttons[0] = d8[0];
 buttons[1] = d8[1];

 for(int stick = 0; stick < 2; stick++)
 {
  for(int axis = 0; axis < 2; axis++)
  {
   axes[stick][axis] = MDFN_de16lsb(&d8[2] + stick * 4 + axis * 2) >> 8;
  }
 }

 //printf("%d %d %d %d\n", axes[0][0], axes[0][1], axes[1][0], axes[1][1]);
}


void InputDevice_DualAnalog::SetDTR(bool new_dtr)
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

bool InputDevice_DualAnalog::GetDSR(void)
{
 if(!dtr)
  return(0);

 if(!bitpos && transmit_count)
  return(1);

 return(0);
}

bool InputDevice_DualAnalog::Clock(bool TxD, int32 &dsr_pulse_delay)
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
	   transmit_buffer[0] = joystick_mode ? 0x53 : 0x73;
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

	if(command == 0x42)
	{
	 transmit_buffer[1] = 0xFF ^ buttons[0];
	 transmit_buffer[2] = 0xFF ^ buttons[1];
	 transmit_buffer[3] = axes[0][0];
	 transmit_buffer[4] = axes[0][1];
	 transmit_buffer[5] = axes[1][0];
	 transmit_buffer[6] = axes[1][1];
         transmit_pos = 0;
         transmit_count = 7;
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
   case 2:
	//if(receive_buffer)
	// printf("%d: %02x\n", 7 - transmit_count, receive_buffer);
	break;
  }
 }

 if(!bitpos && transmit_count)
  dsr_pulse_delay = 0x40; //0x100;

 return(ret);
}

InputDevice *Device_DualAnalog_Create(bool joystick_mode)
{
 return new InputDevice_DualAnalog(joystick_mode);
}


IDIISG Device_DualAnalog_IDII =
{
 IDIIS_Button("select", "SELECT", 4),
 IDIIS_Button("l3", "Left Stick, Button(L3)", 16),
 IDIIS_Button("r3", "Right stick, Button(R3)", 19),
 IDIIS_Button("start", "START", 5),
 IDIIS_Button("up", "D-Pad UP ↑", 0, "down"),
 IDIIS_Button("right", "D-Pad RIGHT →", 3, "left"),
 IDIIS_Button("down", "D-Pad DOWN ↓", 1, "up"),
 IDIIS_Button("left", "D-Pad LEFT ←", 2, "right"),

 IDIIS_Button("l2", "L2 (rear left shoulder)", 11),
 IDIIS_Button("r2", "R2 (rear right shoulder)", 13),
 IDIIS_Button("l1", "L1 (front left shoulder)", 10),
 IDIIS_Button("r1", "R1 (front right shoulder)", 12),

 IDIIS_ButtonCR("triangle", "△ (upper)", 6),
 IDIIS_ButtonCR("circle", "○ (right)", 9),
 IDIIS_ButtonCR("cross", "x (lower)", 7),
 IDIIS_ButtonCR("square", "□ (left)", 8),

 IDIIS_Axis(	"rstick", "Right Stick",
		"left", "LEFT ←",
		"right", "RIGHT →", 18, false, true),

 IDIIS_Axis(	"rstick", "Right Stick",
		"up", "UP ↑",
		"down", "DOWN ↓", 17, false, true),

 IDIIS_Axis(	"lstick", "Left Stick",
		"left", "LEFT ←",
		"right", "RIGHT →", 15, false, true),

 IDIIS_Axis(	"lstick", "Left Stick",
		"up", "UP ↑",
		"down", "DOWN ↓", 14, false, true),
};

// Not sure if all these buttons are named correctly!
IDIISG Device_AnalogJoy_IDII =
{
 IDIIS_Button("select", "SELECT", 8),
 IDIIS_Padding<2>(),
 IDIIS_Button("start", "START", 9),

 IDIIS_Button("up", "Thumbstick UP ↑", 14, "down"),
 IDIIS_Button("right", "Thumbstick RIGHT →", 17, "left"),
 IDIIS_Button("down", "Thumbstick DOWN ↓", 15, "up"),
 IDIIS_Button("left", "Thumbstick LEFT ←", 16, "right"),

 IDIIS_Button("l2", "Left stick, Trigger", 2),
 IDIIS_Button("r2", "Left stick, Pinky", 3),
 IDIIS_Button("l1", "Left stick, L-thumb", 0),
 IDIIS_Button("r1", "Left stick, R-thumb", 1),

 IDIIS_Button("triangle", "Right stick, Pinky", 13),
 IDIIS_Button("circle", "Right stick, R-thumb", 11),
 IDIIS_Button("cross",  "Right stick, L-thumb", 10),
 IDIIS_Button("square", "Right stick, Trigger", 12),

 IDIIS_Axis(	"rstick", "Right Stick,",
		"left", "LEFT ←",
		"right", "RIGHT →", 19, false, true),

 IDIIS_Axis(	"rstick", "Right Stick,",
		"up", "FORE ↑",
		"down", "BACK ↓", 18, false, true),

 IDIIS_Axis(	"lstick", "Left Stick,",
		"left", "LEFT ←",
		"right", "RIGHT →", 5, false, true),

 IDIIS_Axis(	"lstick", "Left Stick,",
		"up", "FORE ↑",
		"down", "BACK ↓", 4, false, true),
};


}
