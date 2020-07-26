/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* Joystick_DX5.cpp:
**  Copyright (C) 2012-2018 Mednafen Team
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

#include "main.h"
#include "input.h"
#include "Joystick.h"
#include "Joystick_DX5.h"

#define DIRECTINPUT_VERSION 0x0500
#include <windows.h>
#include <windowsx.h>
#include <dinput.h>

#include <set>

struct di_axis_info
{
 int32 minimum, maximum;
 uint32 jd_logical_offset;
};

class Joystick_DX5 : public Joystick
{
 public:

 Joystick_DX5(LPDIRECTINPUT dii, DIDEVICEINSTANCE *ddi) MDFN_COLD;
 virtual ~Joystick_DX5() MDFN_COLD;
 virtual unsigned HatToAxisCompat(unsigned hat);
 virtual void SetRumble(uint8 weak_intensity, uint8 strong_intensity);

 void UpdateInternal(void);

 private:
 LPDIRECTINPUTDEVICE2 dev;
 DIDEVCAPS DevCaps;
 std::vector<di_axis_info> DIAxisInfo;
 int have_exclusive_access;
 void RequestExclusive(bool value);
};

#define REQUIRE_DI_CALL(code) { HRESULT hres = (code); if(hres != DI_OK) { throw MDFN_Error(0, "\"" #code "\"" "failed: %u", (unsigned)hres); } }

void Joystick_DX5::RequestExclusive(bool value)
{
 if(value != have_exclusive_access)
 {
  if(value && SUCCEEDED(dev->SetCooperativeLevel(GetDesktopWindow(), DISCL_BACKGROUND | DISCL_EXCLUSIVE)) && SUCCEEDED(dev->Acquire()))
   have_exclusive_access = true;
  else
  {
   have_exclusive_access = false;
   dev->SetCooperativeLevel(GetDesktopWindow(), DISCL_BACKGROUND | DISCL_NONEXCLUSIVE);
   dev->Acquire();
  }
 }
}

Joystick_DX5::Joystick_DX5(LPDIRECTINPUT dii, DIDEVICEINSTANCE *ddi) : dev(NULL), have_exclusive_access(-1)
{
 LPDIRECTINPUTDEVICE tmp_dev = NULL;

 try
 {
  REQUIRE_DI_CALL( dii->CreateDevice(ddi->guidInstance, &tmp_dev, NULL) );
  REQUIRE_DI_CALL( tmp_dev->QueryInterface(IID_IDirectInputDevice2, (LPVOID *)&dev) );
  REQUIRE_DI_CALL( dev->SetDataFormat(&c_dfDIJoystick2) );
  DevCaps.dwSize = sizeof(DevCaps);
  REQUIRE_DI_CALL( dev->GetCapabilities(&DevCaps) );

  for(unsigned rax = 0; rax < 8; rax++)
  {
   DIPROPRANGE diprg;
   HRESULT hres;

   diprg.diph.dwSize = sizeof(diprg);
   diprg.diph.dwHeaderSize = sizeof(diprg.diph);
   diprg.diph.dwObj = rax * sizeof(LONG);
   diprg.diph.dwHow = DIPH_BYOFFSET;

   // TODO: Handle DIPROPRANGE_NOMIN and DIPROPRANGE_NOMAX
   hres = dev->GetProperty(DIPROP_RANGE, &diprg.diph);
   if(hres == DI_OK)
   {
    if(diprg.lMin < diprg.lMax)
    {
     di_axis_info dai;

     dai.jd_logical_offset = rax;
     dai.minimum = diprg.lMin;
     dai.maximum = diprg.lMax;

     DIAxisInfo.push_back(dai);
    }
   }
   //else if(hres != DIERR_OBJECTNOTFOUND)
  }

  num_rel_axes = 0;
  num_axes = DIAxisInfo.size() + DevCaps.dwPOVs * 2;
  num_buttons = DevCaps.dwButtons;
  axis_state.resize(num_axes);
  rel_axis_state.resize(num_rel_axes);
  button_state.resize(num_buttons);
  // id, guidinstance, etc.

  //
  //
  //
#if 0
  {
   DIEFFECTINFO eff_inf;

   eff_inf.dwSize = sizeof(eff_inf);
   if(dev->GetEffectInfo(&eff_inf, GUID_Square) == DI_OK || dev->GetEffectInfo(&eff_inf, GUID_Sine) == DI_OK)
   {
    
   }
  }
#endif
  RequestExclusive(false);

  Calc09xID(DIAxisInfo.size(), 0, DevCaps.dwPOVs, DevCaps.dwButtons);
 
  MDFN_en32msb(&id[0], ddi->guidProduct.Data1);
  MDFN_en16msb(&id[4], ddi->guidProduct.Data2);
  MDFN_en16msb(&id[6], ddi->guidProduct.Data3);
  memcpy(&id[8], ddi->guidProduct.Data4, 8);

  name = ddi->tszProductName;
 }
 catch(...)
 {
  if(tmp_dev != NULL)
   tmp_dev->Release();

  if(dev != NULL)
   dev->Release();

  throw;
 }
}

Joystick_DX5::~Joystick_DX5()
{
 if(dev != NULL)
 {
  dev->Unacquire();
  dev->Release();
  dev = NULL;
 }
}

unsigned Joystick_DX5::HatToAxisCompat(unsigned hat)
{
 return(DIAxisInfo.size() + (hat * 2));
}

// TODO: RequestExclusive(false) when SetRumble() hasn't been called for several seconds.
void Joystick_DX5::UpdateInternal(void)
{
 DIJOYSTATE2 js;
 HRESULT hres;

 if(DevCaps.dwFlags & (DIDC_POLLEDDEVICE | DIDC_POLLEDDATAFORMAT))
 {
  do { /* */ hres = dev->Poll(); /* */ } while((hres == DIERR_INPUTLOST) && ((hres = dev->Acquire()) == DI_OK));
  if(hres != DI_OK)
   return;
 }

 do { /* */ hres = dev->GetDeviceState(sizeof(js), &js); /* */ } while((hres == DIERR_INPUTLOST) && ((hres = dev->Acquire()) == DI_OK));
 if(hres != DI_OK)
  return;

 for(unsigned button = 0; button < DevCaps.dwButtons; button++)
 {
  button_state[button] = (bool)(js.rgbButtons[button] & 0x80);
 }

 for(unsigned axis = 0; axis < DIAxisInfo.size(); axis++)
 {
  int64 rv = (&js.lX)[DIAxisInfo[axis].jd_logical_offset];

  rv = (((rv - DIAxisInfo[axis].minimum) * 32767 * 2) / (DIAxisInfo[axis].maximum - DIAxisInfo[axis].minimum)) - 32767;
  if(rv < -32767)
   rv = -32767;

  if(rv > 32767)
   rv = 32767;
  axis_state[axis] = rv;
 }

 for(unsigned hat = 0; hat < DevCaps.dwPOVs; hat++)
 {
  DWORD hat_val = js.rgdwPOV[hat];

  //if((uint16)hat_val == 0xFFFF)	// Reportedly some drivers report 0xFFFF instead of 0xFFFFFFFF? (comment from byuu)
  if(hat_val >= 36000)
  {
   axis_state[(DIAxisInfo.size() + hat * 2) + 0] = 0;
   axis_state[(DIAxisInfo.size() + hat * 2) + 1] = 0;
  }
  else
  {
   int32 x, y;

   //axis_state[(DIAxisInfo.size() + hat * 2) + 0] = 32767 * sin((double)M_PI * 2 * hat_val / 36000);	// x
   //axis_state[(DIAxisInfo.size() + hat * 2) + 1] = 32767 * -cos((double)M_PI * 2 * hat_val / 36000);	// y
   unsigned octant = (hat_val / 4500) & 0x7;
   signed octant_doff = hat_val % 4500;

   switch(octant)
   {
    case 0: x = octant_doff * 32767 / 4500; y = -32767; break;
    case 1: x = 32767; y = (-4500 + octant_doff) * 32767 / 4500; break;

    case 2: x = 32767; y = octant_doff * 32767 / 4500; break;
    case 3: x = (4500 - octant_doff) * 32767 / 4500; y = 32767; break;

    case 4: x = (-octant_doff) * 32767 / 4500; y = 32767; break;
    case 5: x = -32767; y = (4500 - octant_doff) * 32767 / 4500; break;
    
    case 6: x = -32767; y = (-octant_doff) * 32767 / 4500; break;
    case 7: x = (-4500 + octant_doff) * 32767 / 4500; y = -32767; break;
   }

   axis_state[(DIAxisInfo.size() + hat * 2) + 0] = x;
   axis_state[(DIAxisInfo.size() + hat * 2) + 1] = y;
  }
 }
}

void Joystick_DX5::SetRumble(uint8 weak_intensity, uint8 strong_intensity)
{
 //if((weak_intensity || strong_intensity) && rumble_supported)
 // RequestExclusive(true);
}

class JoystickDriver_DX5 : public JoystickDriver
{
 public:

 JoystickDriver_DX5(bool exclude_xinput);
 virtual ~JoystickDriver_DX5();

 virtual unsigned NumJoysticks();                       // Cached internally on JoystickDriver instantiation.
 virtual Joystick *GetJoystick(unsigned index);
 virtual void UpdateJoysticks(void);

 private:
 std::vector<Joystick_DX5 *> joys;
 LPDIRECTINPUT dii;
};


static INLINE std::set<uint32> GetXInputVidPid(void)
{
 HMODULE us32 = NULL;
 UINT WINAPI (*p_GetRawInputDeviceList)(PRAWINPUTDEVICELIST, PUINT, UINT) = NULL;
 UINT WINAPI (*p_GetRawInputDeviceInfo)(HANDLE, UINT, LPVOID, PUINT) = NULL;
 std::set<uint32> exclude_vps;

 if((us32 = LoadLibrary("user32.dll")) == NULL)
  return exclude_vps;

 p_GetRawInputDeviceList = (UINT WINAPI (*)(PRAWINPUTDEVICELIST, PUINT, UINT))GetProcAddress(us32, "GetRawInputDeviceList");
 p_GetRawInputDeviceInfo = (UINT WINAPI (*)(HANDLE, UINT, LPVOID, PUINT))GetProcAddress(us32, "GetRawInputDeviceInfoA");

 if(p_GetRawInputDeviceList && p_GetRawInputDeviceInfo)
 {
  std::vector<RAWINPUTDEVICELIST> ridl;
  unsigned int alloc_num_devices = 0;
  unsigned int num_devices = 0;

  p_GetRawInputDeviceList(NULL, &alloc_num_devices, sizeof(RAWINPUTDEVICELIST));
  ridl.resize(alloc_num_devices);

  if((num_devices = p_GetRawInputDeviceList(&ridl[0], &alloc_num_devices, sizeof(RAWINPUTDEVICELIST))) > 0)
  {
   for(unsigned i = 0; i < num_devices; i++)
   {
    if(ridl[i].dwType != RIM_TYPEHID)
     continue;

    RID_DEVICE_INFO devinfo;
    std::vector<char> devname;
    unsigned int sizepar;

    memset(&devinfo, 0, sizeof(devinfo));
    devinfo.cbSize = sizeof(RID_DEVICE_INFO);
    sizepar = sizeof(RID_DEVICE_INFO);
    if(p_GetRawInputDeviceInfo(ridl[i].hDevice, RIDI_DEVICEINFO, &devinfo, &sizepar) != sizeof(RID_DEVICE_INFO))
     continue;
    
    sizepar = 0;
    p_GetRawInputDeviceInfo(ridl[i].hDevice, RIDI_DEVICENAME, NULL, &sizepar);
    devname.resize(sizepar + 1);
    p_GetRawInputDeviceInfo(ridl[i].hDevice, RIDI_DEVICENAME, &devname[0], &sizepar);

    //printf("MOOCOW: %s\n", devname);
    if(!strncmp(&devname[0], "IG_", 3) || strstr(&devname[0], "&IG_") != NULL)
    {
     exclude_vps.insert(MAKELONG(devinfo.hid.dwVendorId, devinfo.hid.dwProductId));
    }
   }
  }
 }

 FreeLibrary(us32);

 return exclude_vps;
}


struct enum_device_list
{
 enum_device_list() : valid_count(0) { ddi.resize(max_count); }
 static const unsigned max_count = 256;
 std::vector<DIDEVICEINSTANCE> ddi;
 unsigned valid_count;
};

static BOOL CALLBACK GLOB_EnumJoysticksProc(LPCDIDEVICEINSTANCE ddi, LPVOID private_data) __attribute__((force_align_arg_pointer));
static BOOL CALLBACK GLOB_EnumJoysticksProc(LPCDIDEVICEINSTANCE ddi, LPVOID private_data)
{
 enum_device_list *edl = (enum_device_list*)private_data;

 //printf("%08x\n", (unsigned int)ddi->guidInstance.Data1);

 if((ddi->dwDevType & 0xFF) != DIDEVTYPE_JOYSTICK)
  return DIENUM_CONTINUE;

 if(edl->valid_count < edl->max_count)
 {
  memcpy(&edl->ddi[edl->valid_count], ddi, sizeof(DIDEVICEINSTANCE));
  edl->valid_count++;
 }

 return DIENUM_CONTINUE;
}

JoystickDriver_DX5::JoystickDriver_DX5(bool exclude_xinput) : dii(NULL)
{
 enum_device_list edl;
 std::set<uint32> exclude_vps;

 try
 {
  REQUIRE_DI_CALL( DirectInputCreate(GetModuleHandle(NULL), DIRECTINPUT_VERSION, &dii, NULL) );
  REQUIRE_DI_CALL( dii->EnumDevices(DIDEVTYPE_JOYSTICK, GLOB_EnumJoysticksProc, &edl, DIEDFL_ATTACHEDONLY) );

  if(exclude_xinput)
  {
   exclude_vps = GetXInputVidPid();
  }

  for(unsigned i = 0; i < edl.valid_count; i++)
  {
   Joystick_DX5 *jdx5 = NULL;

   if(edl.ddi[i].guidProduct.Data1 && exclude_vps.count(edl.ddi[i].guidProduct.Data1))
    continue;

   try
   {
    jdx5 = new Joystick_DX5(dii, &edl.ddi[i]);
    joys.push_back(jdx5);
   }
   catch(std::exception &e)
   {
    MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
    if(jdx5 != NULL)
    {
     delete jdx5;
     jdx5 = NULL;
    }
   }
  }
 }
 catch(std::exception &e)
 {
  MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
 }
}

JoystickDriver_DX5::~JoystickDriver_DX5()
{
 for(unsigned int n = 0; n < joys.size(); n++)
 {
  delete joys[n];
 }

 if(dii != NULL)
 {
  dii->Release();
  dii = NULL;
 }
}

unsigned JoystickDriver_DX5::NumJoysticks(void)
{
 return joys.size();
}

Joystick *JoystickDriver_DX5::GetJoystick(unsigned index)
{
 return joys[index];
}

void JoystickDriver_DX5::UpdateJoysticks(void)
{
 for(unsigned int n = 0; n < joys.size(); n++)
 {
  joys[n]->UpdateInternal();
 }
}

JoystickDriver *JoystickDriver_DX5_New(bool exclude_xinput)
{
 return new JoystickDriver_DX5(exclude_xinput);
}

