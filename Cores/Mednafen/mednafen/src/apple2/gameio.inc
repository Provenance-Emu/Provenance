/******************************************************************************/
/* Mednafen Apple II Emulation Module                                         */
/******************************************************************************/
/* gameio.inc:
**  Copyright (C) 2018 Mednafen Team
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
// TODO: alter AxisCounterFinishTS when axis position changes before expiration
//

namespace GameIO
{

enum
{
 DEVID_NONE = 0,
 DEVID_PADDLE = 1,
 DEVID_JOYSTICK = 2,
 DEVID_GAMEPAD = 3,
 DEVID_ATARI = 4
};

static unsigned InputTypes[2];
static uint8* InputData[2];

static uint8 ButtonStates[3];
static uint32 AxisStates[4];

static int32 AxisCounterFinishTS[4];

static int32 ResistanceLUT[4];

template<unsigned w>
static DEFREAD(ReadGameButton)
{
 if(!InHLPeek)
  CPUTick1();
 //
 DB = (DB & 0x7F) | ((ButtonStates[w] << ((SoftSwitch >> 4) & 3)) & 0x80);
}

template<unsigned w>
static DEFREAD(ReadGameAxis)
{
 if(!InHLPeek)
  CPUTick1();
 //
 DB = (DB & 0x7F) | ((timestamp < AxisCounterFinishTS[w]) ? 0x80 : 0x00);
}

static DEFRW(RWGameTimerReset)
{
 if(!InHLPeek)
 {
  for(unsigned i = 0; i < 4; i++)
  {
   if(AxisCounterFinishTS[i] == 0x7FFFFFFF || timestamp >= AxisCounterFinishTS[i])
    AxisCounterFinishTS[i] = (AxisStates[i] == 0x7FFFFFFF) ? 0x7FFFFFFF : (timestamp + AxisStates[i]);
  }
  //
  CPUTick1();
 }
}

static void EndTimePeriod(void)
{
 for(unsigned i = 0; i < 4; i++)
 {
  if(AxisCounterFinishTS[i] != 0x7FFFFFFF)
   AxisCounterFinishTS[i] = std::max<int32>(0, AxisCounterFinishTS[i] - timestamp);
 }
}

static void Init(uint32* resistance)
{
 for(unsigned i = 0; i < 4; i++)
 {
  // Don't use floating-point math here.
  ResistanceLUT[i] = ((resistance[i] + 100) * 63 + 200) / 400;
  //printf("%d %d\n", i, ResistanceLUT[i]);
 }

 for(unsigned A_or = 0; A_or <= 8; A_or += 8)
 {
  SetReadHandler(0xC061 | A_or, ReadGameButton<0>);
  SetReadHandler(0xC062 | A_or, ReadGameButton<1>);
  SetReadHandler(0xC063 | A_or, ReadGameButton<2>);

  SetReadHandler(0xC064 | A_or, ReadGameAxis<0>);
  SetReadHandler(0xC065 | A_or, ReadGameAxis<1>);
  SetReadHandler(0xC066 | A_or, ReadGameAxis<2>);
  SetReadHandler(0xC067 | A_or, ReadGameAxis<3>);
 }

 for(unsigned A = 0xC070; A < 0xC080; A++)
  SetRWHandlers(A, RWGameTimerReset, RWGameTimerReset);
}

static void Power(void)
{
 for(unsigned i = 0; i < 4; i++)
  AxisCounterFinishTS[i] = timestamp;
}

static void Kill(void)
{

}

static void SetInput(unsigned port, const char* type, uint8* ptr)
{
 assert(port < 2);

 unsigned devid = DEVID_NONE;

 if(!strcmp(type, "none"))
  devid = DEVID_NONE;
 else if(!strcmp(type, "paddle"))
  devid = DEVID_PADDLE;
 else if(!strcmp(type, "joystick"))
  devid = DEVID_JOYSTICK;
 else if(!strcmp(type, "gamepad"))
  devid = DEVID_GAMEPAD;
 else if(!strcmp(type, "atari"))
  devid = DEVID_ATARI;
 else
  abort();

 InputTypes[port] = devid;
 InputData[port] = ptr;
}

static void UpdateInput(void)
{
 if(InputTypes[0] == DEVID_ATARI)
 {
  for(unsigned axis = 0; axis < 4; axis++)
  {
   AxisStates[axis] = 0x7FFFFFFF;
   AxisCounterFinishTS[axis] = 0x7FFFFFFF;
  }

  for(unsigned button = 0; button < 3; button++)
   ButtonStates[button] = 0xFF;

  for(unsigned port = 0; port < ((InputTypes[1] == DEVID_ATARI) ? 2 : 1); port++)
  {
   // Button
   ButtonStates[0] &= ~(((InputData[port][0] & 0x01) ? 0xA0 : 0x00) >> port);

   // Left
   ButtonStates[1] &= ~(((InputData[port][0] & 0x02) ? 0x80 : 0x00) >> port);

   // Up
   ButtonStates[1] &= ~(((InputData[port][0] & 0x04) ? 0x20 : 0x00) >> port);

   // Right
   ButtonStates[2] &= ~(((InputData[port][0] & 0x08) ? 0x80 : 0x00) >> port);

   // Down
   ButtonStates[2] &= ~(((InputData[port][0] & 0x10) ? 0x20 : 0x00) >> port);
  }
  //printf("%02x %02x %02x\n", ButtonStates[0], ButtonStates[1], ButtonStates[2]);
 }
 else
 {
  uint8 button_tmp[32] = { 0, 0, 0 };
  uint32 axis_tmp[32] = { 0 };
  unsigned button_offs = 0;
  unsigned axis_offs = 0;

  for(unsigned axis = 0; axis < 4; axis++)
   axis_tmp[axis] = 0x7FFFFFFF;

  for(unsigned port = 0; port < 2; port++)
  {
   if(InputTypes[port] == DEVID_NONE)
   {
    break;
   }
   else if(InputTypes[port] == DEVID_PADDLE && InputTypes[0] == DEVID_PADDLE)
   {
    axis_tmp[axis_offs++] = 57 + MDFN_de16lsb(&InputData[port][0]) * 23550 / 0x8000;
    button_tmp[button_offs++] |= (InputData[port][2] & 0x01) ? 0xFF : 0x00;
   }
   else if(InputTypes[port] == DEVID_JOYSTICK)
   {
    const unsigned resistance = (InputData[port][4] >> 2) % 4;

    for(unsigned axis = 0; axis < 2; axis++)
     axis_tmp[axis_offs++] = 57 + (int64)MDFN_de16lsb(&InputData[port][axis * 2]) * ResistanceLUT[resistance] / 0x8000;

    button_tmp[button_offs++] |= (InputData[port][4] & 0x01) ? 0xFF : 0x00;
    button_tmp[button_offs++] |= (InputData[port][4] & 0x02) ? 0xFF : 0x00;
   }
   else if(InputTypes[port] == DEVID_GAMEPAD)
   {
    const unsigned resistance = (InputData[port][0] >> 6) % 4;

    for(unsigned axis = 0; axis < 2; axis++)
     axis_tmp[axis_offs++] = 57 + (int64)(((InputData[port][0] & (1 << (axis * 2))) ? 0 : 0x8000) + ((InputData[port][0] & (2 << (axis * 2))) ? 0x7FFF : 0)) * ResistanceLUT[resistance] / 0x8000;

    button_tmp[button_offs++] |= (InputData[port][0] & 0x10) ? 0xFF : 0x00;
    button_tmp[button_offs++] |= (InputData[port][0] & 0x20) ? 0xFF : 0x00;
   }

  }

  for(unsigned button = 0; button < 3; button++)
   ButtonStates[button] = button_tmp[button];

  for(unsigned axis = 0; axis < 4; axis++)
  {
   AxisStates[axis] = axis_tmp[axis];

   if(AxisStates[axis] == 0x7FFFFFFF)
    AxisCounterFinishTS[axis] = 0x7FFFFFFF;
  }
 }
}

void StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(ButtonStates),
  SFVAR(AxisStates),

  SFVAR(AxisCounterFinishTS),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "GAMEIO");

 if(load)
 {

 }
}


static IDIISG IODevice_GIO_Paddle_IDII =
{
 IDIIS_Axis(	"dial", "Dial",
		"left", "LEFT ←",
		"right", "RIGHT →", 0),

 IDIIS_Button("button", "Button", 1),
};

static const IDIIS_SwitchPos ResistanceSwitchPositions[] =
{
 { "1", gettext_noop("1 of 4") },
 { "2", gettext_noop("2 of 4") },
 { "3", gettext_noop("3 of 4") },
 { "4", gettext_noop("4 of 4") },
};

static IDIISG IODevice_GIO_Joystick_IDII =
{
 IDIIS_Axis(	"stick", "Stick",
		"left", "LEFT ←",
		"right", "RIGHT →", 1, false, true),

 IDIIS_Axis(	"stick", "Stick",
                "up", "UP ↑",
                "down", "DOWN ↓", 0, false, true),

 IDIIS_Button("button1", "Button 1", 2),
 IDIIS_Button("button2", "Button 2", 3),

 IDIIS_Switch<4, 1>("resistance_select", "Resistance", 4, ResistanceSwitchPositions)
};

static IDIISG IODevice_GIO_Gamepad_IDII =
{
 IDIIS_Button("left", "LEFT ←", 2, "right"),
 IDIIS_Button("right", "RIGHT →", 3, "left"),
 IDIIS_Button("up", "UP ↑", 0, "down"),
 IDIIS_Button("down", "DOWN ↓", 1, "up"),

 IDIIS_Button("button1", "Button 1", 4),
 IDIIS_Button("button2", "Button 2", 5),

 IDIIS_Switch<4, 1>("resistance_select", "Resistance", 6, ResistanceSwitchPositions)
};

static IDIISG IODevice_GIO_Atari_IDII =
{
 IDIIS_Button("button", "Button", 4),
 IDIIS_Button("left", "LEFT ←", 2, "right"),
 IDIIS_Button("up", "UP ↑", 0, "down"),
 IDIIS_Button("right", "RIGHT →", 3, "left"),
 IDIIS_Button("down", "DOWN ↓", 1, "up"),
};

static const InputDeviceInfoStruct IDIS_Paddle =
{
 "paddle",
 gettext_noop("Paddle"),
 gettext_noop("1-axis, 1-button rotary dial paddle.  Only usable on virtual port 2 if it's also selected on virtual port 1."),
 IODevice_GIO_Paddle_IDII,
};

static const InputDeviceInfoStruct IDIS_Joystick =
{
 "joystick",
 gettext_noop("Joystick"),
 gettext_noop("2-axis, 2-button joystick, with 4-state resistance switch."),
 IODevice_GIO_Joystick_IDII,
};

static const InputDeviceInfoStruct IDIS_Gamepad =
{
 "gamepad",
 gettext_noop("Gamepad"),
 gettext_noop("Gamepad with D-pad and 2 buttons.  Seen by emulated software as a 2-axis, 2-button analog joystick(albeit with only axis extremes), but provides more configuration options for the user."),
 IODevice_GIO_Gamepad_IDII,
};

static const InputDeviceInfoStruct IDIS_Atari =
{
 "atari",
 gettext_noop("Atari Joystick"),
 gettext_noop("Atari joyport digital joystick.  Only usable on virtual port 2 if it's also selected on virtual port 1.  Limited compatibility with software."),
 IODevice_GIO_Atari_IDII,
};

static const std::vector<InputDeviceInfoStruct> InputDeviceInfoGIOVPort1 =
{
 // 0
 {
  "none",
  gettext_noop("None(all game I/O devices disabled)"),
  gettext_noop("Will disable all game I/O devices if selected."),
  IDII_Empty
 },

 IDIS_Paddle,
 IDIS_Joystick,
 IDIS_Gamepad,
 IDIS_Atari,
};

static const std::vector<InputDeviceInfoStruct> InputDeviceInfoGIOVPort2 =
{
 IDIS_Paddle,
 IDIS_Atari,
};

}
