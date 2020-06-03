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

#include "pce.h"
#include "input.h"
#include "huc.h"

namespace PCE_Fast
{

static int InputTypes[5];
static uint8 *data_ptr[5];

static bool AVPad6Which[5]; // Lower(8 buttons) or higher(4 buttons).

uint16 pce_jp_data[5];

static int64 mouse_last_meow[5];

static int32 mouse_x[5], mouse_y[5];
static uint16 mouse_rel[5];

uint8 pce_mouse_button[5];
uint8 mouse_index[5];

static uint8 sel;
static uint8 read_index = 0;

static bool DisableSR;

static void SyncSettings(void);

void PCEINPUT_SettingChanged(const char *name)
{
 SyncSettings();
}

void PCEINPUT_Init(void)
{
 SyncSettings();
}

void PCEINPUT_SetInput(unsigned port, const char *type, uint8 *ptr)
{
 assert(port < 5);

 if(!strcmp(type, "gamepad"))
  InputTypes[port] = 1;
 else if(!strcmp(type, "mouse"))
  InputTypes[port] = 2;
 else
  InputTypes[port] = 0;
 data_ptr[port] = (uint8 *)ptr;
}

void INPUT_TransformInput(void)
{
 for(int x = 0; x < 5; x++)
 {
  if(InputTypes[x] == 1)
  {
   if(DisableSR)
   {
    uint16 tmp = MDFN_de16lsb(data_ptr[x]);

    if((tmp & 0xC) == 0xC)
     tmp &= ~0xC;

    MDFN_en16lsb(data_ptr[x], tmp);
   }
  }
 }
}

void INPUT_Frame(void)
{
 for(int x = 0; x < 5; x++)
 {
  if(InputTypes[x] == 1)
  {
   uint16 new_data = data_ptr[x][0] | (data_ptr[x][1] << 8);
   pce_jp_data[x] = new_data;
  }
  else if(InputTypes[x] == 2)
  {
   mouse_x[x] += (int16)MDFN_de16lsb(data_ptr[x] + 0);
   mouse_y[x] += (int16)MDFN_de16lsb(data_ptr[x] + 2);
   pce_mouse_button[x] = *(uint8 *)(data_ptr[x] + 4);
  }
 }
}

void INPUT_FixTS(void)
{
 for(int x = 0; x < 5; x++)
 {
  if(InputTypes[x] == 2)
   mouse_last_meow[x] -= HuCPU.timestamp;
 }
}

static INLINE bool CheckLM(int n)
{
   if((int64)HuCPU.timestamp - mouse_last_meow[n] > 10000)
   {
    mouse_last_meow[n] = HuCPU.timestamp;

    int32 rel_x = (int32)((0-mouse_x[n]));
    int32 rel_y = (int32)((0-mouse_y[n]));

    if(rel_x < -127) rel_x = -127;
    if(rel_x > 127) rel_x = 127;
    if(rel_y < -127) rel_y = -127;
    if(rel_y > 127) rel_y = 127;

    mouse_rel[n] = ((rel_x & 0xF0) >> 4) | ((rel_x & 0x0F) << 4);
    mouse_rel[n] |= (((rel_y & 0xF0) >> 4) | ((rel_y & 0x0F) << 4)) << 8;

    mouse_x[n] += (int32)(rel_x);
    mouse_y[n] += (int32)(rel_y);

    return(1);
   }
  return(0);
}

uint8 INPUT_Read(unsigned int A)
{
 uint8 ret = 0xF;
 int tmp_ri = read_index;

 if(tmp_ri > 4)
  ret ^= 0xF;
 else
 {
  if(!InputTypes[tmp_ri])
   ret ^= 0xF;
  else if(InputTypes[tmp_ri] == 2) // Mouse
  {   
   if(sel & 1)
   {
    CheckLM(tmp_ri);
    ret ^= 0xF;
    ret ^= mouse_rel[tmp_ri] & 0xF;

    mouse_rel[tmp_ri] >>= 4;
   }
   else
   {
    ret ^= pce_mouse_button[tmp_ri] & 0xF;
   }
  }
  else
  {
   if(InputTypes[tmp_ri] == 1) // Gamepad
   {
    if(AVPad6Which[tmp_ri] && (pce_jp_data[tmp_ri] & 0x1000))
    {
     if(sel & 1)
      ret ^= 0x0F;
     else
      ret ^= (pce_jp_data[tmp_ri] >> 8) & 0x0F;
    }
    else
    {
     if(sel & 1)
      ret ^= (pce_jp_data[tmp_ri] >> 4) & 0x0F;
     else
      ret ^= pce_jp_data[tmp_ri] & 0x0F;
    }
    if(!(sel & 1))
     AVPad6Which[tmp_ri] = !AVPad6Which[tmp_ri];
   }
  }
 }

 if(!PCE_IsCD)
  ret |= 0x80; // Set when CDROM is not attached

 //ret |= 0x40; // PC Engine if set, TG16 if clear.  Let's leave it clear, PC Engine games don't seem to mind if it's clear, but TG16 games barf if it's set.

 ret |= 0x30; // Always-set?

 return(ret);
}

void INPUT_Write(unsigned int A, uint8 V)
{
 if((V & 1) && !(sel & 2) && (V & 2))
 {
  read_index = 0;
 }
 else if((V & 1) && !(sel & 1))
 {
  if(read_index < 255)
   read_index++;
 }
 sel = V & 3;
}

void INPUT_StateAction(StateMem *sm, int load, int data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(AVPad6Which),
  
  SFVARN(mouse_last_meow[0], "mlm_0"),
  SFVARN(mouse_last_meow[1], "mlm_1"),
  SFVARN(mouse_last_meow[2], "mlm_2"),
  SFVARN(mouse_last_meow[3], "mlm_3"),
  SFVARN(mouse_last_meow[4], "mlm_4"),

  SFVAR(mouse_x),
  SFVAR(mouse_y),
  SFVAR(mouse_rel),
  SFVAR(pce_mouse_button),
  SFVAR(mouse_index),

  SFVAR(pce_jp_data),
  SFVAR(sel),
  SFVAR(read_index),
  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "JOY");
}

static const IDIIS_SwitchPos ModeSwitchPositions[] =
{
 { "2", gettext_noop("2-button"), gettext_noop("Basic 2-button controller mode, compatible with practically all games.") },
 { "6", gettext_noop("6-button"), gettext_noop("6-button controller mode, only for compatible games(incompatible games will behave in a quite loopy manner).") },
};

static const IDIISG GamepadIDII =
{
 IDIIS_ButtonCR("i", "I", 12),
 IDIIS_ButtonCR("ii", "II", 11),
 IDIIS_Button("select", "SELECT", 4),
 IDIIS_Button("run", "RUN", 5),
 IDIIS_Button("up", "UP ↑", 0, "down"),
 IDIIS_Button("right", "RIGHT →", 3, "left"),
 IDIIS_Button("down", "DOWN ↓", 1, "up"),
 IDIIS_Button("left", "LEFT ←", 2, "right"),
 IDIIS_Button("iii", "III", 10),
 IDIIS_Button("iv", "IV", 7),
 IDIIS_Button("v", "V", 8),
 IDIIS_Button("vi", "VI", 9),
 IDIIS_Switch("mode_select", "Mode", 6, ModeSwitchPositions),
};

static const IDIISG MouseIDII =
{
 IDIIS_AxisRel("motion", "Motion",/**/ "left", "Left",/**/ "right", "Right", 0),
 IDIIS_AxisRel("motion", "Motion",/**/ "up", "Up",/**/ "down", "Down", 1),
 IDIIS_Button("right", "Right Button", 5),
 IDIIS_Button("left", "Left Button", 4),
 IDIIS_Button("select", "SELECT", 2),
 IDIIS_Button("run", "RUN", 3),
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

 // Mouse
 {
  "mouse",
  "Mouse",
  NULL,
  MouseIDII
 },

};

const std::vector<InputPortInfoStruct> PCEPortInfo =
{
 { "port1", "Port 1", InputDeviceInfo, "gamepad" },
 { "port2", "Port 2", InputDeviceInfo, "gamepad" },
 { "port3", "Port 3", InputDeviceInfo, "gamepad" },
 { "port4", "Port 4", InputDeviceInfo, "gamepad" },
 { "port5", "Port 5", InputDeviceInfo, "gamepad" },
};

static void SyncSettings(void)
{
 MDFNGameInfo->mouse_sensitivity = MDFN_GetSettingF("pce_fast.mouse_sensitivity");
 DisableSR = MDFN_GetSettingB("pce_fast.disable_softreset");
}

};
