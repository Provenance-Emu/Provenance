/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2014  JustBurn

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <windows.h>
#define DIRECTINPUT_VERSION 0x0800
#include <dinput.h>

#include "Joystick_DInput.h"
#include "Joystick.h"

static Joystick_HasFF = 0;
static HWND Joystick_nWnd = NULL;
static int Joystick_DInput_NumDevices = 0;
static LPDIRECTINPUT8 pDI = NULL;
static LPDIRECTINPUTDEVICE8 pDIDev = NULL;
static LPDIRECTINPUTEFFECT pDIEffect = NULL;
static DIDEVCAPS gDIDC;
static GUID guidEffect;
static int RumbleState = 0;
static struct {
	int valid;
	char name[256];
	GUID guid;
} Joystick_DInput_Device[8];

BOOL FAR PASCAL Joystick_DInput_EnumDevicesCallback(LPCDIDEVICEINSTANCE lpddi, LPVOID pvRef)
{
	if (Joystick_DInput_NumDevices < 8) {
		strcpy_s(Joystick_DInput_Device[Joystick_DInput_NumDevices].name, 256, lpddi->tszProductName);
		Joystick_DInput_Device[Joystick_DInput_NumDevices].guid = lpddi->guidInstance;
		Joystick_DInput_Device[Joystick_DInput_NumDevices].valid = 1;
		Joystick_DInput_NumDevices++;
	}
	return DIENUM_CONTINUE;
}

BOOL FAR PASCAL Joystick_DInput_EnumAxesCallback(LPCDIDEVICEOBJECTINSTANCE lpddoi, LPVOID pvRef)
{
	DIPROPRANGE diprg; 
	diprg.diph.dwSize       = sizeof(DIPROPRANGE); 
	diprg.diph.dwHeaderSize = sizeof(DIPROPHEADER); 
	diprg.diph.dwHow        = DIPH_BYID; 
	diprg.diph.dwObj        = lpddoi->dwType; 
	diprg.lMin              = -32767;
	diprg.lMax              = +32767;
	if FAILED(IDirectInputDevice8_SetProperty(pDIDev, DIPROP_RANGE, &diprg.diph)) return DIENUM_STOP;
	return DIENUM_CONTINUE;
}

BOOL FAR PASCAL Joystick_DInput_EnumEffectsProc(LPCDIEFFECTINFO pdei, LPVOID pvRef)
{
	guidEffect = pdei->guid;
	Joystick_HasFF = 1;
	return DIENUM_STOP;
}

// -----

int Joystick_DInput_Init(HINSTANCE hInst, HWND hWnd)
{
	// Clear structure
	ZeroMemory(Joystick_DInput_Device, sizeof(Joystick_DInput_Device));
	Joystick_DInput_NumDevices = 0;

	// Initialize DirectInput
	if FAILED(DirectInput8Create(hInst, DIRECTINPUT_VERSION, &IID_IDirectInput8, (void**)&pDI, NULL)) {
		MessageBox(0, "DirectInput8Create Failed", "Joystick", MB_OK | MB_ICONERROR);
		Joystick_DInput_Terminate();
		return 0;
	}

	// Enumerate joystick devices
	IDirectInput8_EnumDevices(pDI, DI8DEVCLASS_GAMECTRL, Joystick_DInput_EnumDevicesCallback, NULL, DIEDFL_ATTACHEDONLY);
	Joystick_nWnd = hWnd;

	return 1;
}

void Joystick_DInput_Terminate(void)
{
	Joystick_DInput_JoystickClose();
	if (pDI) {
		IDirectInput8_Release(pDI);
		pDI = NULL;
	}
	Joystick_DInput_NumDevices = 0;
}

int Joystick_DInput_NumJoysticks()
{
	return Joystick_DInput_NumDevices;
}

char *Joystick_DInput_JoystickName(int index)
{
	if ((index < 0) || (index >= Joystick_DInput_NumDevices)) return "None";
	return Joystick_DInput_Device[index].name;
}

int Joystick_DInput_JoystickOpen(int index)
{
	DWORD dwAxes[2] = {DIJOFS_X, DIJOFS_Y};
	LONG lDirection[2] = {10000, 10000};
	DICONSTANTFORCE diConstantForce;
	DIEFFECT diEffect;

	if ((index < 0) || (index >= Joystick_DInput_NumDevices)) return 0;
	if (!Joystick_DInput_Device[index].valid) return 0;

	if FAILED(IDirectInput8_CreateDevice(pDI, &Joystick_DInput_Device[index].guid, &pDIDev, NULL)) {
		return 0;
	}
	if FAILED(IDirectInputDevice8_SetDataFormat(pDIDev, &c_dfDIJoystick2)) {
		Joystick_DInput_JoystickClose();
		return 0;
	}
	if FAILED(IDirectInputDevice8_SetCooperativeLevel(pDIDev, Joystick_nWnd, DISCL_EXCLUSIVE | DISCL_FOREGROUND)) {
		Joystick_DInput_JoystickClose();
		return 0;
	}
	gDIDC.dwSize = sizeof(DIDEVCAPS);
	if FAILED(IDirectInputDevice8_GetCapabilities(pDIDev, &gDIDC)) {
		Joystick_DInput_JoystickClose();
		return 0;
	}
	if FAILED(IDirectInputDevice8_EnumObjects(pDIDev, Joystick_DInput_EnumAxesCallback, (VOID*)Joystick_nWnd, DIDFT_AXIS)) {
		Joystick_DInput_JoystickClose();
		return 0;
	}

	// Force-Feedback
	Joystick_HasFF = 0;
	IDirectInputDevice8_EnumEffects(pDIDev, Joystick_DInput_EnumEffectsProc, NULL, DIEFT_CONSTANTFORCE);
	if (Joystick_HasFF) {
		// FF Constant Force
		ZeroMemory(&diConstantForce, sizeof(DICONSTANTFORCE));
		diConstantForce.lMagnitude = DI_FFNOMINALMAX;

		// FF Effect
		ZeroMemory(&diEffect, sizeof(DIEFFECT));
		diEffect.dwSize = sizeof(DIEFFECT); 
		diEffect.dwFlags = DIEFF_CARTESIAN | DIEFF_OBJECTOFFSETS; 
		diEffect.dwDuration = INFINITE;
		diEffect.dwSamplePeriod = 0;
		diEffect.dwGain = DI_FFNOMINALMAX;
		diEffect.dwTriggerButton = DIEB_NOTRIGGER;
		diEffect.dwTriggerRepeatInterval = 0;
		diEffect.cAxes = 2; 
		diEffect.rgdwAxes = dwAxes;
		diEffect.rglDirection = lDirection;
		diEffect.lpEnvelope = NULL;
		diEffect.cbTypeSpecificParams = sizeof(diConstantForce);
		diEffect.lpvTypeSpecificParams = &diConstantForce;

		if FAILED(IDirectInputDevice8_CreateEffect(pDIDev, &guidEffect, &diEffect, &pDIEffect, NULL)) {
			Joystick_DInput_JoystickClose();
			return 0;
		}
	}

	return 1;
}

void Joystick_DInput_JoystickClose()
{
	if (pDIEffect) {
		IDirectInputEffect_Release(pDIEffect);
		pDIEffect = NULL;
	}
	if (pDIDev) {
		IDirectInputDevice8_Release(pDIDev);
		pDIDev = NULL;
	}
}

void Joystick_DInput_StopRumble()
{
	if (RumbleState) {
		IDirectInputEffect_Stop(pDIEffect); 
		RumbleState = 0;
	}
}

int Joystick_DInput_Process(int rumbling)
{
	DIJOYSTATE2 js;
	static BYTE JoyButtons[32];
	static rumblelvl = 0;
	int i, deg, hats;

	if (!pDIDev) return 0;

	// Poll and get device state
	if FAILED(IDirectInputDevice8_Poll(pDIDev)) {
		while(IDirectInputDevice8_Acquire(pDIDev) == DIERR_INPUTLOST) Sleep(3);
	}
	if FAILED(IDirectInputDevice8_GetDeviceState(pDIDev, sizeof(DIJOYSTATE2), &js)) {
        return 0;
	}

	// Process axis, hats and buttons
	if (gDIDC.dwAxes >= 2) {
		JoystickAxisEvent(0, js.lX);
		JoystickAxisEvent(1, js.lY);
	}
	for (i=0; i<(int)gDIDC.dwPOVs; i++) {
		if (js.rgdwPOV[i] == -1) hats = 0;
		else {
			deg = (js.rgdwPOV[i] + 2250) % 36000;
			if (deg >= 31500) hats = JHAT_UP | JHAT_LEFT;
			else if (deg >= 27000) hats = JHAT_LEFT;
			else if (deg >= 22500) hats = JHAT_DOWN | JHAT_LEFT;
			else if (deg >= 18000) hats = JHAT_DOWN;
			else if (deg >= 13500) hats = JHAT_DOWN | JHAT_RIGHT;
			else if (deg >=  9000) hats = JHAT_RIGHT;
			else if (deg >=  4500) hats = JHAT_UP | JHAT_RIGHT;
			else if (deg >=     0) hats = JHAT_UP;
		}
		JoystickHatsEvent(hats);
	}
	for (i=0; i<32; i++) {
		if (js.rgbButtons[i] ^ JoyButtons[i]) {
			JoystickButtonsEvent(i, js.rgbButtons[i]);
		}
	}

	// Process force-feedback
	if (Joystick_HasFF) {
		if (rumblelvl && !RumbleState) {
			IDirectInputEffect_Start(pDIEffect, 1, 0);
			RumbleState = 1;
		} else if (!rumblelvl && RumbleState) {
			IDirectInputEffect_Stop(pDIEffect); 
			RumbleState = 0;
		}
		if (rumbling && (rumblelvl < 16)) rumblelvl += 4;
	}
	if (rumblelvl) rumblelvl--;

	// Transfer buttons states
	CopyMemory(JoyButtons, js.rgbButtons, sizeof(JoyButtons));
	return 1;
}
