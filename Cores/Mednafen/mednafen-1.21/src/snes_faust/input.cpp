/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* input.cpp:
**  Copyright (C) 2015-2017 Mednafen Team
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

#include "snes.h"
#include "input.h"

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

InputDevice::InputDevice()
{

}

InputDevice::~InputDevice()
{

}

void InputDevice::Power(void)
{


}

void InputDevice::UpdatePhysicalState(const uint8* data)
{


}

uint8 InputDevice::Read(bool IOB)
{
 return 0;
}

void InputDevice::SetLatch(bool state)
{


}

void InputDevice::StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname_prefix)
{


}

class InputDevice_MTap final : public InputDevice
{
 public:
 InputDevice_MTap() MDFN_COLD;
 virtual ~InputDevice_MTap() override MDFN_COLD;

 virtual void Power(void) override MDFN_COLD;

 virtual uint8 MDFN_FASTCALL Read(bool IOB) override MDFN_HOT;
 virtual void MDFN_FASTCALL SetLatch(bool state) override MDFN_HOT;

 virtual void StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname_prefix) override;

 void SetSubDevice(const unsigned mport, InputDevice* device);

 private:
 InputDevice* MPorts[4];
 bool pls;
};

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

class InputDevice_Gamepad final : public InputDevice
{
 public:

 InputDevice_Gamepad() MDFN_COLD;
 virtual ~InputDevice_Gamepad() override MDFN_COLD;

 virtual void Power(void) override MDFN_COLD;

 virtual void MDFN_FASTCALL UpdatePhysicalState(const uint8* data) override;

 virtual uint8 MDFN_FASTCALL Read(bool IOB) override MDFN_HOT;
 virtual void MDFN_FASTCALL SetLatch(bool state) override MDFN_HOT;

 virtual void StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname_prefix) override;

 private:
 uint16 buttons;
 uint32 latched;

 bool pls;
};

InputDevice_Gamepad::InputDevice_Gamepad()
{
 pls = false;
 buttons = 0;
}

InputDevice_Gamepad::~InputDevice_Gamepad()
{

}

void InputDevice_Gamepad::StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname_prefix)
{
 SFORMAT StateRegs[] = 
 {
  SFVAR(buttons),
  SFVAR(latched),
  SFVAR(pls),
  SFEND
 };

 char sname[64] = "GP_";

 strncpy(sname + 3, sname_prefix, sizeof(sname) - 3);
 sname[sizeof(sname) - 1] = 0;

 //printf("%s\n", sname);

 if(!MDFNSS_StateAction(sm, load, data_only, StateRegs, sname, true) && load)
  Power();
 else if(load)
 {

 }
}


void InputDevice_Gamepad::Power(void)
{
 latched = ~0U;
}

void InputDevice_Gamepad::UpdatePhysicalState(const uint8* data)
{
 buttons = MDFN_de16lsb(data);
 if(pls)
  latched = buttons | 0xFFFF0000;
}

uint8 InputDevice_Gamepad::Read(bool IOB)
{
 uint8 ret = latched & 1;

 if(!pls)
  latched = (int32)latched >> 1;

 return ret;
}

void InputDevice_Gamepad::SetLatch(bool state)
{
 if(pls && !state)
  latched = buttons | 0xFFFF0000;

 pls = state;
}

//
//
//
//
//
static struct
{
 InputDevice_Gamepad gamepad;
} PossibleDevices[8];

static InputDevice NoneDevice;

static InputDevice_MTap PossibleMTaps[2];
static bool MTapEnabled[2];

// Mednafen virtual
static InputDevice* Devices[8];
static uint8* DeviceData[8];

// SNES physical
static InputDevice* Ports[2];

static uint8 WRIO;

static bool JoyLS;
static uint8 JoyARData[8];

static DEFREAD(Read_JoyARData)
{
 CPUM.timestamp += MEMCYC_FAST;

 //printf("Read: %08x\n", A);

 return JoyARData[A & 0x7];
}

static DEFREAD(Read_4016)
{
 CPUM.timestamp += MEMCYC_XSLOW;

 uint8 ret = CPUM.mdr & 0xFC;

 ret |= Ports[0]->Read(WRIO & (0x40 << 0));

 //printf("Read 4016: %02x\n", ret);
 return ret;
}

static DEFWRITE(Write_4016)
{
 CPUM.timestamp += MEMCYC_XSLOW;

 JoyLS = V & 1;
 for(unsigned sport = 0; sport < 2; sport++)
  Ports[sport]->SetLatch(JoyLS);

 //printf("Write 4016: %02x\n", V);
}

static DEFREAD(Read_4017)
{
 CPUM.timestamp += MEMCYC_XSLOW;
 uint8 ret = (CPUM.mdr & 0xE0) | 0x1C;

 ret |= Ports[1]->Read(WRIO & (0x40 << 1));

 //printf("Read 4017: %02x\n", ret);
 return ret;
}

static DEFWRITE(Write_WRIO)
{
 CPUM.timestamp += MEMCYC_FAST;

 WRIO = V;
}

static DEFREAD(Read_4213)
{
 CPUM.timestamp += MEMCYC_FAST;

 return WRIO;
}


void INPUT_AutoRead(void)
{
 for(unsigned sport = 0; sport < 2; sport++)
 {
  Ports[sport]->SetLatch(true);
  Ports[sport]->SetLatch(false);

  unsigned ard[2] = { 0 };

  for(unsigned b = 0; b < 16; b++)
  {
   uint8 rv = Ports[sport]->Read(WRIO & (0x40 << sport));

   ard[0] = (ard[0] << 1) | ((rv >> 0) & 1);
   ard[1] = (ard[1] << 1) | ((rv >> 1) & 1);
  }

  for(unsigned ai = 0; ai < 2; ai++)
   MDFN_en16lsb(&JoyARData[sport * 2 + ai * 4], ard[ai]);
 }
 JoyLS = false;
}

static MDFN_COLD void MapDevices(void)
{
 for(unsigned sport = 0, vport = 0; sport < 2; sport++)
 {
  if(MTapEnabled[sport])
  {
   Ports[sport] = &PossibleMTaps[sport];

   for(unsigned mport = 0; mport < 4; mport++)
    PossibleMTaps[sport].SetSubDevice(mport, Devices[vport++]);
  }
  else
   Ports[sport] = Devices[vport++];
 }
}

void INPUT_Init(void)
{
 for(unsigned bank = 0x00; bank < 0x100; bank++)
 {
  if(bank <= 0x3F || (bank >= 0x80 && bank <= 0xBF))
  {
   Set_A_Handlers((bank << 16) | 0x4016, Read_4016, Write_4016);
   Set_A_Handlers((bank << 16) | 0x4017, Read_4017, OBWrite_XSLOW);

   Set_A_Handlers((bank << 16) | 0x4201, OBRead_FAST, Write_WRIO);

   Set_A_Handlers((bank << 16) | 0x4213, Read_4213, OBWrite_FAST);

   Set_A_Handlers((bank << 16) | 0x4218, (bank << 16) | 0x421F, Read_JoyARData, OBWrite_FAST);
  }
 }

 for(unsigned vport = 0; vport < 8; vport++)
 {
  DeviceData[vport] = nullptr;
  Devices[vport] = &NoneDevice;
 }

 for(unsigned sport = 0; sport < 2; sport++)
  for(unsigned mport = 0; mport < 4; mport++)
   PossibleMTaps[sport].SetSubDevice(mport, &NoneDevice);

 MTapEnabled[0] = MTapEnabled[1] = false;
 MapDevices();
}

void INPUT_SetMultitap(const bool (&enabled)[2])
{
 for(unsigned sport = 0; sport < 2; sport++)
 {
  if(enabled[sport] != MTapEnabled[sport])
  {
   PossibleMTaps[sport].SetLatch(JoyLS);
   PossibleMTaps[sport].Power();
   MTapEnabled[sport] = enabled[sport];
  }
 }

 MapDevices();
}

void INPUT_Kill(void)
{


}

void INPUT_Reset(bool powering_up)
{
 JoyLS = false;
 for(unsigned sport = 0; sport < 2; sport++)
  Ports[sport]->SetLatch(JoyLS);

 if(powering_up)
 {
  WRIO = 0xFF;

  for(unsigned sport = 0; sport < 2; sport++)
   Ports[sport]->Power();
 }
}

void INPUT_Set(unsigned vport, const char* type, uint8* ptr)
{
 InputDevice* nd = &NoneDevice;

 DeviceData[vport] = ptr;

 if(!strcmp(type, "gamepad"))
  nd = &PossibleDevices[vport].gamepad;
 else if(strcmp(type, "none"))
  abort();

 if(Devices[vport] != nd)
 {
  Devices[vport] = nd;
  Devices[vport]->SetLatch(JoyLS);
  Devices[vport]->Power();
 }

 MapDevices();
}

void INPUT_StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(JoyARData),
  SFVAR(JoyLS),

  SFVAR(WRIO),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "INPUT");

 for(unsigned sport = 0; sport < 2; sport++)
 {
  char sprefix[32] = "PORTn";

  sprefix[4] = '0' + sport;

  Ports[sport]->StateAction(sm, load, data_only, sprefix);
 }
}

void INPUT_UpdatePhysicalState(void)
{
 for(unsigned vport = 0; vport < 8; vport++)
  Devices[vport]->UpdatePhysicalState(DeviceData[vport]);
}

static const IDIISG GamepadIDII =
{
 IDIIS_ButtonCR("b", "B (center, lower)", 7, NULL),
 IDIIS_ButtonCR("y", "Y (left)", 6, NULL),
 IDIIS_Button("select", "SELECT", 4, NULL),
 IDIIS_Button("start", "START", 5, NULL),
 IDIIS_Button("up", "UP ↑", 0, "down"),
 IDIIS_Button("down", "DOWN ↓", 1, "up"),
 IDIIS_Button("left", "LEFT ←", 2, "right"),
 IDIIS_Button("right", "RIGHT →", 3, "left"),
 IDIIS_ButtonCR("a", "A (right)", 9, NULL),
 IDIIS_ButtonCR("x", "X (center, upper)", 8, NULL),
 IDIIS_Button("l", "Left Shoulder", 10, NULL),
 IDIIS_Button("r", "Right Shoulder", 11, NULL),
};

static const std::vector<InputDeviceInfoStruct> InputDeviceInfo =
{
 // None
 { 
  "none",
  "none",
  NULL,
  IDII_Empty
 },

 // Gamepad
 {
  "gamepad",
  "Gamepad",
  NULL,
  GamepadIDII
 },
};

const std::vector<InputPortInfoStruct> INPUT_PortInfo =
{
 { "port1", "Virtual Port 1", InputDeviceInfo, "gamepad" },
 { "port2", "Virtual Port 2", InputDeviceInfo, "gamepad" },
 { "port3", "Virtual Port 3", InputDeviceInfo, "gamepad" },
 { "port4", "Virtual Port 4", InputDeviceInfo, "gamepad" },
 { "port5", "Virtual Port 5", InputDeviceInfo, "gamepad" },
 { "port6", "Virtual Port 6", InputDeviceInfo, "gamepad" },
 { "port7", "Virtual Port 7", InputDeviceInfo, "gamepad" },
 { "port8", "Virtual Port 8", InputDeviceInfo, "gamepad" }
};

}
