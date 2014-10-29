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

#include "main.h"
#include "input.h"
#include "Joystick.h"
#include "Joystick_XInput.h"

#include <windows.h>
#include <windowsx.h>
#include <xinput.h>

#include <math.h>
#include <algorithm>

struct XInputFuncPointers
{
 void WINAPI (*p_XInputEnable)(BOOL);
 DWORD WINAPI (*p_XInputSetState)(DWORD, XINPUT_VIBRATION*);
 DWORD WINAPI (*p_XInputGetState)(DWORD, XINPUT_STATE*);	// Pointer to XInputGetState or XInputGetStateEx(if available).
 DWORD WINAPI (*p_XInputGetCapabilities)(DWORD, DWORD, XINPUT_CAPABILITIES*);
};

class Joystick_XInput : public Joystick
{
 public:

 Joystick_XInput(unsigned index, const XINPUT_CAPABILITIES &caps_in, const XInputFuncPointers* xfps_in);
 ~Joystick_XInput();

 virtual void SetRumble(uint8 weak_intensity, uint8 strong_intensity);
 virtual bool IsAxisButton(unsigned axis);
 void UpdateInternal(void);

 private:
 const unsigned joy_index;
 const XINPUT_CAPABILITIES caps;
 const XInputFuncPointers *xfps;
};

Joystick_XInput::Joystick_XInput(unsigned index, const XINPUT_CAPABILITIES &caps_in, const XInputFuncPointers* xfps_in) : joy_index(index), caps(caps_in), xfps(xfps_in)
{
 num_buttons = sizeof(((XINPUT_GAMEPAD*)0)->wButtons) * 8;
 num_axes = 6;
 num_rel_axes = 0;

 button_state.resize(num_buttons);
 axis_state.resize(num_axes);

 id = (caps.Type << 24) | (caps.SubType << 16);	// Don't include the XInput index in the id, it'll just cause problems, especially when multiple different subtypes of controllers are connected. | (index << 8);

 snprintf(name, sizeof(name), "XInput Unknown Controller");
 if(caps.Type == XINPUT_DEVTYPE_GAMEPAD)
 {
  switch(caps.SubType)
  {
   default: break;
   case XINPUT_DEVSUBTYPE_GAMEPAD: snprintf(name, sizeof(name), "XInput Gamepad"); break;
   case XINPUT_DEVSUBTYPE_WHEEL: snprintf(name, sizeof(name), "XInput Wheel"); break;
   case XINPUT_DEVSUBTYPE_ARCADE_STICK: snprintf(name, sizeof(name), "XInput Arcade Stick"); break;
#ifdef XINPUT_DEVSUBTYPE_FLIGHT_STICK
   case XINPUT_DEVSUBTYPE_FLIGHT_STICK: snprintf(name, sizeof(name), "XInput Flight Stick"); break;
#endif
   case XINPUT_DEVSUBTYPE_DANCE_PAD: snprintf(name, sizeof(name), "XInput Dance Pad"); break;

#ifdef XINPUT_DEVSUBTYPE_GUITAR_ALTERNATE
   case XINPUT_DEVSUBTYPE_GUITAR_ALTERNATE:
#endif
#ifdef XINPUT_DEVSUBTYPE_GUITAR_BASS
   case XINPUT_DEVSUBTYPE_GUITAR_BASS:
#endif
   case XINPUT_DEVSUBTYPE_GUITAR: snprintf(name, sizeof(name), "XInput Guitar"); break;

   case XINPUT_DEVSUBTYPE_DRUM_KIT: snprintf(name, sizeof(name), "XInput Drum Kit"); break;
#ifdef XINPUT_DEVSUBTYPE_ARCADE_PAD
   case XINPUT_DEVSUBTYPE_ARCADE_PAD: snprintf(name, sizeof(name), "XInput Arcade Pad"); break;
#endif
  }
 }
}


Joystick_XInput::~Joystick_XInput()
{

}

bool Joystick_XInput::IsAxisButton(unsigned axis)
{
 if(axis >= 4)
  return(true);

 return(false);
}

void Joystick_XInput::UpdateInternal(void)
{
 XINPUT_STATE joy_state;
 memset(&joy_state, 0, sizeof(XINPUT_STATE));

 xfps->p_XInputGetState(joy_index, &joy_state);

 for(unsigned b = 0; b < num_buttons; b++)
  button_state[b] = (joy_state.Gamepad.wButtons >> b) & 1;

 axis_state[0] = std::max<int>(-32767, joy_state.Gamepad.sThumbLX);
 axis_state[1] = std::max<int>(-32767, joy_state.Gamepad.sThumbLY);
 axis_state[2] = std::max<int>(-32767, joy_state.Gamepad.sThumbRX);
 axis_state[3] = std::max<int>(-32767, joy_state.Gamepad.sThumbRY);

 axis_state[4] = (((unsigned)joy_state.Gamepad.bLeftTrigger * 32767) + 127) / 255;
 axis_state[5] = (((unsigned)joy_state.Gamepad.bRightTrigger * 32767) + 127) / 255;
}

void Joystick_XInput::SetRumble(uint8 weak_intensity, uint8 strong_intensity)
{
 XINPUT_VIBRATION vib;

 memset(&vib, 0, sizeof(XINPUT_VIBRATION));
 vib.wLeftMotorSpeed = (((unsigned int)strong_intensity * 65535) + 127) / 255;
 vib.wRightMotorSpeed = (((unsigned int)weak_intensity * 65535) + 127) / 255;
 xfps->p_XInputSetState(joy_index, &vib);
}

class JoystickDriver_XInput : public JoystickDriver
{
 public:

 JoystickDriver_XInput();
 virtual ~JoystickDriver_XInput();

 virtual unsigned NumJoysticks();                       // Cached internally on JoystickDriver instantiation.
 virtual Joystick *GetJoystick(unsigned index);
 virtual void UpdateJoysticks(void);

 private:
 Joystick_XInput *joys[XUSER_MAX_COUNT];
 unsigned joy_count;


 HMODULE dll_handle;
 XInputFuncPointers xfps;
};

template<typename T>
bool GetXIPA(HMODULE dll_handle, T& pf, const char *name)
{
 pf = (T)GetProcAddress(dll_handle, name);
 return(pf != NULL);
}

JoystickDriver_XInput::JoystickDriver_XInput() : joy_count(0), dll_handle(NULL)
{
 if((dll_handle = LoadLibrary("xinput1_3.dll")) == NULL)
 {
  if((dll_handle = LoadLibrary("xinput1_4.dll")) == NULL)
  {
   if((dll_handle = LoadLibrary("xinput9_1_0.dll")) == NULL)
   {
    return;
   }
  }
 }

 // 9.1.0 supposedly lacks XInputEnable()
 xfps.p_XInputEnable = NULL;
 GetXIPA(dll_handle, xfps.p_XInputEnable, "XInputEnable");

 if(!GetXIPA(dll_handle, xfps.p_XInputSetState, "XInputSetState") ||
    (!GetXIPA(dll_handle, xfps.p_XInputGetState, (const char *)100/*"XInputGetStateEx"*/) && !GetXIPA(dll_handle, xfps.p_XInputGetState, "XInputGetState")) ||
    !GetXIPA(dll_handle, xfps.p_XInputGetCapabilities, "XInputGetCapabilities"))
 {
  FreeLibrary(dll_handle);
  return;
 }

 if(xfps.p_XInputEnable)
  xfps.p_XInputEnable(TRUE);

 for(unsigned i = 0; i < XUSER_MAX_COUNT; i++)
 {
  joys[i] = NULL;
  try
  {
   XINPUT_CAPABILITIES caps;

   if(xfps.p_XInputGetCapabilities(i, XINPUT_FLAG_GAMEPAD, &caps) == ERROR_SUCCESS)
   {
    joys[joy_count] = new Joystick_XInput(i, caps, &xfps);
    joy_count++; // joys[joy_count++] would not be exception-safe.
   }
  }
  catch(std::exception &e)
  {
   MDFND_PrintError(e.what());
  }
 }
}

JoystickDriver_XInput::~JoystickDriver_XInput()
{
 if(xfps.p_XInputEnable)
  xfps.p_XInputEnable(FALSE);

 for(unsigned i = 0; i < joy_count; i++)
 {
  if(joys[i])
  {
   delete joys[i];
   joys[i] = NULL;
  }
 }

 joy_count = 0;
 if(dll_handle != NULL)
 {
  FreeLibrary(dll_handle);
  dll_handle = NULL;
 }
}

unsigned JoystickDriver_XInput::NumJoysticks(void)
{
 return joy_count;
}

Joystick *JoystickDriver_XInput::GetJoystick(unsigned index)
{
 return joys[index];
}

void JoystickDriver_XInput::UpdateJoysticks(void)
{
 for(unsigned i = 0; i < joy_count; i++)
  joys[i]->UpdateInternal();
}

JoystickDriver *JoystickDriver_XInput_New(void)
{
 JoystickDriver_XInput* jdxi = new JoystickDriver_XInput();

 if(!jdxi->NumJoysticks())
 {
  delete jdxi;
  jdxi = NULL;
 }

 return(jdxi);
}
