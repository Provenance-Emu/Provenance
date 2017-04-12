
#include "snes.h"
#include "input.h"

namespace MDFN_IEN_SNES_FAUST
{

class InputDevice
{
 public:

 InputDevice();
 virtual ~InputDevice();

 virtual void Power(void);

 virtual void UpdatePhysicalState(const uint8* data);

 virtual uint8 Read(void);
 virtual void SetLatch(bool state);
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

uint8 InputDevice::Read(void)
{
 return 0;
}

void InputDevice::SetLatch(bool state)
{


}

class InputDevice_Gamepad final : public InputDevice
{
 public:

 InputDevice_Gamepad();
 virtual ~InputDevice_Gamepad();

 virtual void Power(void);

 virtual void UpdatePhysicalState(const uint8* data);

 virtual uint8 Read(void);
 virtual void SetLatch(bool state);

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

void InputDevice_Gamepad::Power(void)
{
 latched = ~0U;
}

void InputDevice_Gamepad::UpdatePhysicalState(const uint8* data)
{
 buttons = MDFN_de16lsb(data);
}

uint8 InputDevice_Gamepad::Read(void)
{
 uint8 ret = latched & 1;

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
 InputDevice none;
 InputDevice_Gamepad gamepad;
} PossibleDevices[2];

static InputDevice* Devices[2];
static uint8* DeviceData[2];
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

 ret |= Devices[0]->Read();

 //printf("Read 4016: %02x\n", ret);
 return ret;
}

static DEFWRITE(Write_4016)
{
 CPUM.timestamp += MEMCYC_XSLOW;

 JoyLS = V & 1;
 for(unsigned port = 0; port < 2; port++)
  Devices[port]->SetLatch(JoyLS);

 //printf("Write 4016: %02x\n", V);
}

static DEFREAD(Read_4017)
{
 CPUM.timestamp += MEMCYC_XSLOW;
 uint8 ret = (CPUM.mdr & 0xE0) | 0x1C;

 ret |= Devices[1]->Read();

 //printf("Read 4017: %02x\n", ret);
 return ret;
}

void INPUT_AutoRead(void)
{
 for(unsigned port = 0; port < 2; port++)
 {
  Devices[port]->SetLatch(true);
  Devices[port]->SetLatch(false);

  unsigned ard[2] = { 0 };

  for(unsigned b = 0; b < 16; b++)
  {
   uint8 rv = Devices[port]->Read();

   ard[0] = (ard[0] << 1) | ((rv >> 0) & 1);
   ard[1] = (ard[1] << 1) | ((rv >> 1) & 1);
  }

  for(unsigned ai = 0; ai < 2; ai++)
   MDFN_en16lsb(&JoyARData[port * 2 + ai * 4], ard[ai]);
 }
 JoyLS = false;
}

void INPUT_Init(void)
{
 for(unsigned bank = 0x00; bank < 0x100; bank++)
 {
  if(bank <= 0x3F || (bank >= 0x80 && bank <= 0xBF))
  {
   Set_A_Handlers((bank << 16) | 0x4016, Read_4016, Write_4016);
   Set_A_Handlers((bank << 16) | 0x4017, Read_4017, OBWrite_XSLOW);

   Set_A_Handlers((bank << 16) | 0x4218, (bank << 16) | 0x421F, Read_JoyARData, OBWrite_FAST);
  }
 }

 for(unsigned port = 0; port < 2; port++)
 {
  DeviceData[port] = NULL;
  Devices[port] = &PossibleDevices[port].none;
  Devices[port]->Power();
 }
}

void INPUT_Kill(void)
{


}

void INPUT_Reset(bool powering_up)
{
 if(powering_up)
 {
  for(unsigned port = 0; port < 2; port++)
   Devices[port]->Power();
 }

 JoyLS = false;
 for(unsigned port = 0; port < 2; port++)
  Devices[port]->SetLatch(JoyLS);
}

void INPUT_Set(unsigned port, const char* type, uint8* ptr)
{
 InputDevice* nd = &PossibleDevices[port].none;

 DeviceData[port] = ptr;

 if(!strcmp(type, "gamepad"))
  nd = &PossibleDevices[port].gamepad;
 else if(strcmp(type, "none"))
  abort();

 if(Devices[port] != nd)
 {
  Devices[port] = nd;
  Devices[port]->Power();
 }
}

void INPUT_StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFARRAY(JoyARData, 8),
  SFVAR(JoyLS),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "INPUT");

 // FIXME/TODO:
 //for(unsigned port = 0; port < 2; port++)
 // Devices[port]->StateAction(sm, load, data_only);
}

void INPUT_UpdatePhysicalState(void)
{
 for(unsigned port = 0; port < 2; port++)
  Devices[port]->UpdatePhysicalState(DeviceData[port]);
}

static const IDIISG GamepadIDII =
{
 { "b", "B (center, lower)", 7, IDIT_BUTTON_CAN_RAPID, NULL },
 { "y", "Y (left)", 6, IDIT_BUTTON_CAN_RAPID, NULL },
 { "select", "SELECT", 4, IDIT_BUTTON, NULL },
 { "start", "START", 5, IDIT_BUTTON, NULL },
 { "up", "UP ↑", 0, IDIT_BUTTON, "down" },
 { "down", "DOWN ↓", 1, IDIT_BUTTON, "up" },
 { "left", "LEFT ←", 2, IDIT_BUTTON, "right" },
 { "right", "RIGHT →", 3, IDIT_BUTTON, "left" },
 { "a", "A (right)", 9, IDIT_BUTTON_CAN_RAPID, NULL },
 { "x", "X (center, upper)", 8, IDIT_BUTTON_CAN_RAPID, NULL },
 { "l", "Left Shoulder", 10, IDIT_BUTTON, NULL },
 { "r", "Right Shoulder", 11, IDIT_BUTTON, NULL },
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
 { "port1", "Port 1", InputDeviceInfo, "gamepad" },
 { "port2", "Port 2", InputDeviceInfo, "gamepad" }
};

}
