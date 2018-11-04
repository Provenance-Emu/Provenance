/*  Copyright 2006,2013 Theo Berkau

    This file is part of Yabause.

    Yabause is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Yabause is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Yabause; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

/*! \file perdx.c
    \brief Direct X peripheral interface.
*/

#include <windows.h>
#ifdef __MINGW32__
#undef HAVE_XINPUT
#endif
#define COBJMACROS
#ifdef HAVE_XINPUT
#include <wbemidl.h>
#include <wbemcli.h>
#include <oleauto.h>
#include <xinput.h>
#endif
#include "debug.h"
#include "peripheral.h"
#include "perdx.h"
#include "vdp1.h"
#include "vdp2.h"
#include "yui.h"
#include "movie.h"
#include "error.h"

enum {
   EMUTYPE_NONE=0,
   EMUTYPE_STANDARDPAD,
   EMUTYPE_ANALOGPAD,
   EMUTYPE_STUNNER,
   EMUTYPE_MOUSE,
   EMUTYPE_KEYBOARD
};

#define DX_PADOFFSET 24
#define DX_STICKOFFSET 8
#define DX_MAKEKEY(p, s, a) ( ((p) << DX_PADOFFSET) | ((s) << DX_STICKOFFSET) | (a) )
#define DX_PerAxisValue(p, s, a, v) PerAxisValue(DX_MAKEKEY(p, s, a), (v))
#define DX_PerKeyUp(p, s, a) PerKeyUp(DX_MAKEKEY(p, s, a) )
#define DX_PerKeyDown(p, s, a) PerKeyDown(DX_MAKEKEY(p, s, a) )

int Check_Skip_Key();

PerInterface_struct PERDIRECTX = {
PERCORE_DIRECTX,
"DirectX Input Interface",
PERDXInit,
PERDXDeInit,
PERDXHandleEvents,
PERDXScan,
TRUE,
PERDXFlush,
};

LPDIRECTINPUT8 lpDI8 = NULL;
struct
{
	BOOL is_xinput_device;
	int user_index;
	LPDIRECTINPUTDEVICE8 lpDIDevice; 
} dev_list[256]; // I hope that's enough

u32 num_devices=0;

static unsigned int PERCORE_INITIALIZED = 0;

const char *mouse_names[] = {
"A",
"B",
"C",
"Start",
NULL
};

#define PAD_DIR_AXISLEFT        0
#define PAD_DIR_AXISRIGHT       1
#define PAD_DIR_AXISUP          2
#define PAD_DIR_AXISDOWN        3
#define PAD_DIR_POVUP           0
#define PAD_DIR_POVRIGHT        1
#define PAD_DIR_POVDOWN         2
#define PAD_DIR_POVLEFT         3

HWND DXGetWindow ();

#ifdef HAVE_XINPUT
#define SAFE_RELEASE(p)      { if(p) { (p)->lpVtbl->Release((p)); (p)=NULL; } }
#define SAFE_DELETE(p)  { if(p) { free (p);     (p)=NULL; } }

typedef struct 
{
	DWORD dwVidPid;
	struct XINPUT_DEVICE_NODE* pNext;
} XINPUT_DEVICE_NODE;

XINPUT_DEVICE_NODE *g_pXInputDeviceList = NULL;
BOOL bCleanupCOM=FALSE;

//////////////////////////////////////////////////////////////////////////////

HRESULT SetupForIsXInputDevice()
{
	IWbemLocator *pIWbemLocator = NULL;
	IEnumWbemClassObject *pEnumDevices = NULL;
	IWbemClassObject *pDevices[20] = {0};
	IWbemServices *pIWbemServices = NULL;
	BSTR bstrNamespace = NULL;
	BSTR bstrDeviceID = NULL;
	BSTR bstrClassName = NULL;
	DWORD uReturned = 0;
	BOOL bIsXinputDevice = FALSE;
	UINT iDevice = 0;
	VARIANT var;
	HRESULT hr;

	hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
	bCleanupCOM = SUCCEEDED(hr);
	
	// Create WMI
	hr = CoCreateInstance( &CLSID_WbemContext,
		NULL,
		CLSCTX_INPROC_SERVER,
		&IID_IWbemContext,
		(LPVOID*) &pIWbemLocator);
	if( FAILED(hr) || pIWbemLocator == NULL )
		goto bail;

	bstrNamespace = SysAllocString( L"\\\\.\\root\\cimv2" );if( bstrNamespace == NULL ) goto bail;
	bstrClassName = SysAllocString( L"Win32_PNPEntity" );   if( bstrClassName == NULL ) goto bail;
	bstrDeviceID  = SysAllocString( L"DeviceID" );          if( bstrDeviceID == NULL )  goto bail;

	// Connect to WMI 	
	hr = IWbemLocator_ConnectServer(pIWbemLocator, bstrNamespace, NULL, NULL, NULL, 
		0L, NULL, NULL, &pIWbemServices );

	if( FAILED(hr) || pIWbemServices == NULL )
		goto bail;

	// Switch security level to IMPERSONATE
	CoSetProxyBlanket( (IUnknown *)pIWbemServices, RPC_C_AUTHN_WINNT, RPC_C_AUTHZ_NONE, NULL, 
		RPC_C_AUTHN_LEVEL_CALL, RPC_C_IMP_LEVEL_IMPERSONATE, NULL, EOAC_NONE );                    

	hr = IWbemServices_CreateInstanceEnum( pIWbemServices, bstrClassName, 0, NULL, &pEnumDevices ); 
	if( FAILED(hr) || pEnumDevices == NULL )
		goto bail;

	// Loop over all devices
	for(;;)
	{
		// Get 20 at a time		
		hr = IEnumWbemClassObject_Next( pEnumDevices, 10000, 20, pDevices, &uReturned );
		if( FAILED(hr) || 
			uReturned == 0 )
			break;

		for( iDevice=0; iDevice<uReturned; iDevice++ )
		{
			// For each device, get its device ID
			hr = IWbemClassObject_Get( pDevices[iDevice], bstrDeviceID, 0L, &var, NULL, NULL );
			if( SUCCEEDED( hr ) && var.vt == VT_BSTR && var.bstrVal != NULL )
			{
				// Check if the device ID contains "IG_".  If it does, then it's an XInput device
				// This information can not be found from DirectInput 
				if( wcsstr( var.bstrVal, L"IG_" ) )
				{
					// If it does, then get the VID/PID from var.bstrVal
					DWORD dwPid = 0, dwVid = 0;
					WCHAR* strVid;
					WCHAR* strPid;
					DWORD dwVidPid;
					XINPUT_DEVICE_NODE* pNewNode;

					strVid = wcsstr( var.bstrVal, L"VID_" );
					if( strVid && swscanf( strVid, L"VID_%4X", &dwVid ) != 1 )
						dwVid = 0;
					strPid = wcsstr( var.bstrVal, L"PID_" );
					if( strPid && swscanf( strPid, L"PID_%4X", &dwPid ) != 1 )
						dwPid = 0;

					dwVidPid = MAKELONG( dwVid, dwPid );

					// Add the VID/PID to a linked list
					pNewNode = malloc(sizeof(XINPUT_DEVICE_NODE));
					if( pNewNode )
					{
						pNewNode->dwVidPid = dwVidPid;
						pNewNode->pNext = (struct XINPUT_DEVICE_NODE *)g_pXInputDeviceList;
						g_pXInputDeviceList = pNewNode;
					}
				}
			}
			SAFE_RELEASE( pDevices[iDevice] );
		}
	}

bail:
	if(bstrNamespace)
		SysFreeString(bstrNamespace);
	if(bstrDeviceID)
		SysFreeString(bstrDeviceID);
	if(bstrClassName)
		SysFreeString(bstrClassName);
	for( iDevice=0; iDevice<20; iDevice++ )
		SAFE_RELEASE( pDevices[iDevice] );
	SAFE_RELEASE( pEnumDevices );
	SAFE_RELEASE( pIWbemLocator );
	SAFE_RELEASE( pIWbemServices );

	return hr;
}

//////////////////////////////////////////////////////////////////////////////

void CleanupForIsXInputDevice()
{
	// Cleanup linked list
	XINPUT_DEVICE_NODE* pNode = g_pXInputDeviceList;
	while( pNode )
	{
		XINPUT_DEVICE_NODE* pDelete = pNode;
		pNode = (XINPUT_DEVICE_NODE *)pNode->pNext;
		SAFE_DELETE( pDelete );
	}

	if( bCleanupCOM )
		CoUninitialize();
}

//////////////////////////////////////////////////////////////////////////////

BOOL IsXInputDevice( const GUID* guidProduct )
{
	// Check each xinput device to see if this device's vid/pid matches
	XINPUT_DEVICE_NODE* pNode = g_pXInputDeviceList;
	while( pNode )
	{
		if( pNode->dwVidPid == guidProduct->Data1 )
			return TRUE;
		pNode = (XINPUT_DEVICE_NODE*)pNode->pNext;
	}

   return FALSE;
}
#endif

//////////////////////////////////////////////////////////////////////////////

BOOL CALLBACK EnumPeripheralsCallback (LPCDIDEVICEINSTANCE lpddi, LPVOID pvRef)
{
   if (GET_DIDEVICE_TYPE(lpddi->dwDevType) == DI8DEVTYPE_GAMEPAD ||
       GET_DIDEVICE_TYPE(lpddi->dwDevType) == DI8DEVTYPE_JOYSTICK)
   {     
#ifdef HAVE_XINPUT
		if (IsXInputDevice(&lpddi->guidProduct))
		{
			dev_list[num_devices].lpDIDevice = NULL;
			dev_list[num_devices].is_xinput_device = TRUE;
			dev_list[num_devices].user_index=((int *)pvRef)[0];
			((int *)pvRef)[0]++;
			num_devices++;
		}
		else
#endif
		{
			dev_list[num_devices].is_xinput_device = FALSE;
			if (SUCCEEDED(IDirectInput8_CreateDevice(lpDI8, &lpddi->guidInstance, &dev_list[num_devices].lpDIDevice,
				NULL) ))
			   num_devices++;
		}
	}

	return DIENUM_CONTINUE;
}

//////////////////////////////////////////////////////////////////////////////

int PERDXInit(void)
{
	char tempstr[512];
	HRESULT ret;
	int user_index=0;
	u32 i;

	if (PERCORE_INITIALIZED)
		return 0;

	if (FAILED((ret = DirectInput8Create(GetModuleHandle(NULL), DIRECTINPUT_VERSION,
		&IID_IDirectInput8, (LPVOID *)&lpDI8, NULL)) ))
	{
		sprintf(tempstr, "Input. DirectInput8Create error: %s - %s", DXGetErrorString8(ret), DXGetErrorDescription8(ret));
		YabSetError(YAB_ERR_CANNOTINIT, tempstr);
		return -1;
	}

#ifdef HAVE_XINPUT
	SetupForIsXInputDevice();
#endif
	num_devices = 0;
	IDirectInput8_EnumDevices(lpDI8, DI8DEVCLASS_ALL, EnumPeripheralsCallback,
							&user_index, DIEDFL_ATTACHEDONLY);

#ifdef HAVE_XINPUT
	CleanupForIsXInputDevice();
#endif

	for (i = 0; i < num_devices; i++)
	{
		if (!dev_list[i].is_xinput_device)
		{
			if( FAILED( ret = IDirectInputDevice8_SetDataFormat(dev_list[i].lpDIDevice, &c_dfDIJoystick2 ) ) )
				return -1;

			// Set the cooperative level to let DInput know how this device should
			// interact with the system and with other DInput applications.
			if( FAILED( ret = IDirectInputDevice8_SetCooperativeLevel( dev_list[i].lpDIDevice, DXGetWindow(), 
				DISCL_NONEXCLUSIVE | DISCL_BACKGROUND
				/* DISCL_EXCLUSIVE |
				DISCL_FOREGROUND */ ) ) )
				return -1;
		}
	}
	PerPortReset();
	//LoadDefaultPort1A();
	PERCORE_INITIALIZED = 1;
	return 0;
}

//////////////////////////////////////////////////////////////////////////////

void PERDXDeInit(void)
{
	u32 i;

	for (i = 0; i < num_devices; i++)
	{
		if (dev_list[i].lpDIDevice)
		{
			IDirectInputDevice8_Unacquire(dev_list[i].lpDIDevice);
			IDirectInputDevice8_Release(dev_list[i].lpDIDevice);
			dev_list[i].lpDIDevice = NULL;
		}
	}

	if (lpDI8)
	{
		IDirectInput8_Release(lpDI8);
		lpDI8 = NULL;
	}
	PERCORE_INITIALIZED = 0;
}

//////////////////////////////////////////////////////////////////////////////

void PollAxisAsButton(u32 pad, int min_id, int max_id, int deadzone, int val)
{
	if ( val < -deadzone )
	{
		DX_PerKeyUp( pad, 0, max_id );
		DX_PerKeyDown( pad, 0, min_id );
	}
	else if ( val > deadzone )
	{
		DX_PerKeyUp( pad, 0, min_id );
		DX_PerKeyDown( pad, 0, max_id );
	}
	else
	{
		DX_PerKeyUp( pad, 0, min_id );
		DX_PerKeyUp( pad, 0, max_id );
	}
}

//////////////////////////////////////////////////////////////////////////////

#ifdef HAVE_XINPUT
void PollXInputButtons(u32 pad, XINPUT_STATE *state)
{
	int i;
	
	// Check buttons
	for ( i = 0; i < 16; i++ )
	{
		WORD mask = 1 << i;

		if ( (state->Gamepad.wButtons & mask) == mask )
			DX_PerKeyDown( pad, 0, DIJOFS_BUTTON(i) );
		else
			DX_PerKeyUp( pad, 0, DIJOFS_BUTTON(i) );
	}
}
#endif

//////////////////////////////////////////////////////////////////////////////

void PollKeys(void)
{
	u32 i, j;
	DWORD size=8;
	HRESULT hr;

	for (i = 0; i < num_devices; i++)
	{
		LPDIRECTINPUTDEVICE8 curdevice;
		DIJOYSTATE2 js;

#ifdef HAVE_XINPUT
		if (dev_list[i].is_xinput_device)
		{
			XINPUT_STATE state;
			ZeroMemory( &state, sizeof(XINPUT_STATE) );
			if (XInputGetState(dev_list[i].user_index, &state) != ERROR_DEVICE_NOT_CONNECTED)
				continue;

			// Handle axis			
			DX_PerAxisValue(i, XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE, XI_THUMBLX, (u8)((state.Gamepad.sThumbLX) >> 8));
			DX_PerAxisValue(i, XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE, XI_THUMBLY, (u8)((state.Gamepad.sThumbLY) >> 8));
			DX_PerAxisValue(i, XINPUT_GAMEPAD_RIGHT_THUMB_DEADZONE, XI_THUMBRX, (u8)((state.Gamepad.sThumbRX) >> 8));
			DX_PerAxisValue(i, XINPUT_GAMEPAD_RIGHT_THUMB_DEADZONE, XI_THUMBRY, (u8)((state.Gamepad.sThumbRY) >> 8));
			DX_PerAxisValue(i, XINPUT_GAMEPAD_TRIGGER_THRESHOLD, XI_TRIGGERL, state.Gamepad.bLeftTrigger);
			DX_PerAxisValue(i, XINPUT_GAMEPAD_TRIGGER_THRESHOLD, XI_TRIGGERR, state.Gamepad.bRightTrigger);
			
			// Left Stick
			PollAxisAsButton(i, XI_THUMBL+PAD_DIR_AXISLEFT, XI_THUMBL+PAD_DIR_AXISRIGHT,
								XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE, state.Gamepad.sThumbLX);
			PollAxisAsButton(i, XI_THUMBL+PAD_DIR_AXISUP, XI_THUMBL+PAD_DIR_AXISDOWN,
								XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE, state.Gamepad.sThumbLY);

			// Right Stick
			PollAxisAsButton(i, XI_THUMBR+PAD_DIR_AXISLEFT, XI_THUMBR+PAD_DIR_AXISRIGHT,
								XINPUT_GAMEPAD_RIGHT_THUMB_DEADZONE, state.Gamepad.sThumbRX);
			PollAxisAsButton(i, XI_THUMBR+PAD_DIR_AXISUP, XI_THUMBR+PAD_DIR_AXISDOWN,
								XINPUT_GAMEPAD_RIGHT_THUMB_DEADZONE, state.Gamepad.sThumbRY);

			PollXInputButtons(i, &state);
			continue;
		}
		else if (dev_list[i].lpDIDevice == NULL)
			continue;
#else
		if (dev_list[i].lpDIDevice == NULL)
			continue;
#endif

		curdevice=dev_list[i].lpDIDevice;

		// Poll the device to read the current state
		hr = IDirectInputDevice8_Poll(curdevice);
		if( FAILED( hr ) )
		{
			hr = IDirectInputDevice8_Acquire(curdevice);
			while( hr == DIERR_INPUTLOST)
				hr = IDirectInputDevice8_Acquire(curdevice);

			continue;
		}

		// Get the input's device state
		if( FAILED( hr = IDirectInputDevice8_GetDeviceState( curdevice, sizeof( DIJOYSTATE2 ), &js ) ) )
			continue;


		// Handle axis			
		DX_PerAxisValue(i, 0x3FFF, XI_THUMBLX, (u8)((js.lX) >> 8));
		DX_PerAxisValue(i, 0x3FFF, XI_THUMBLY, (u8)((js.lY) >> 8));
		DX_PerAxisValue(i, 0x3FFF, XI_THUMBRX, (u8)((js.lRx) >> 8));
		DX_PerAxisValue(i, 0x3FFF, XI_THUMBRY, (u8)((js.lRy) >> 8));

		// Left Stick
		PollAxisAsButton(i, XI_THUMBL+PAD_DIR_AXISLEFT, XI_THUMBL+PAD_DIR_AXISRIGHT,
							0x3FFF, js.lX-0x7FFF);
		PollAxisAsButton(i, XI_THUMBL+PAD_DIR_AXISUP, XI_THUMBL+PAD_DIR_AXISDOWN,
							0x3FFF, js.lY-0x7FFF);

		// Right Stick
		PollAxisAsButton(i, XI_THUMBR+PAD_DIR_AXISLEFT, XI_THUMBR+PAD_DIR_AXISRIGHT,
							0x3FFF, js.lRx-0x7FFF);
		PollAxisAsButton(i, XI_THUMBR+PAD_DIR_AXISUP, XI_THUMBR+PAD_DIR_AXISDOWN,
							0x3FFF, js.lRy-0x7FFF);

		for (j = 0; j < 4; j++)
		{			
			if (LOWORD(js.rgdwPOV[j]) == 0xFFFF)
			{
				DX_PerKeyUp(i, 0, DIJOFS_POV(j)+PAD_DIR_POVUP);
				DX_PerKeyUp(i, 0, DIJOFS_POV(j)+PAD_DIR_POVRIGHT);
				DX_PerKeyUp(i, 0, DIJOFS_POV(j)+PAD_DIR_POVDOWN);
				DX_PerKeyUp(i, 0, DIJOFS_POV(j)+PAD_DIR_POVLEFT);
			}
			// POV Up
			else if (js.rgdwPOV[j] < 4500)
			{
				DX_PerKeyDown(i, 0, DIJOFS_POV(j)+PAD_DIR_POVUP);
				DX_PerKeyUp(i, 0, DIJOFS_POV(j)+PAD_DIR_POVRIGHT);
				DX_PerKeyUp(i, 0, DIJOFS_POV(j)+PAD_DIR_POVLEFT);
			}
			// POV Up-right
			else if (js.rgdwPOV[j] < 9000)
			{
				DX_PerKeyDown(i, 0, DIJOFS_POV(j)+PAD_DIR_POVUP);
				DX_PerKeyDown(i, 0, DIJOFS_POV(j)+PAD_DIR_POVRIGHT);
			}
			// POV Right
			else if (js.rgdwPOV[j] < 13500)
			{
				DX_PerKeyDown(i, 0, DIJOFS_POV(j)+PAD_DIR_POVRIGHT);
				DX_PerKeyUp(i, 0, DIJOFS_POV(j)+PAD_DIR_POVDOWN);
				DX_PerKeyUp(i, 0, DIJOFS_POV(j)+PAD_DIR_POVUP);
			}
			// POV Right-down
			else if (js.rgdwPOV[j] < 18000)
			{
				DX_PerKeyDown(i, 0, DIJOFS_POV(j)+PAD_DIR_POVRIGHT);
				DX_PerKeyDown(i, 0, DIJOFS_POV(j)+PAD_DIR_POVDOWN);
			}
			// POV Down
			else if (js.rgdwPOV[j] < 22500)
			{
				DX_PerKeyDown(i, 0, DIJOFS_POV(j)+PAD_DIR_POVDOWN);
				DX_PerKeyUp(i, 0, DIJOFS_POV(j)+PAD_DIR_POVLEFT);
				DX_PerKeyUp(i, 0, DIJOFS_POV(j)+PAD_DIR_POVRIGHT);
			}
			// POV Down-left
			else if (js.rgdwPOV[j] < 27000)
			{
				DX_PerKeyDown(i, 0, DIJOFS_POV(j)+PAD_DIR_POVDOWN);
				DX_PerKeyDown(i, 0, DIJOFS_POV(j)+PAD_DIR_POVLEFT);
			}
			// POV Left
			else if (js.rgdwPOV[j] < 31500)
			{
				DX_PerKeyDown(i, 0, DIJOFS_POV(j)+PAD_DIR_POVLEFT);
				DX_PerKeyUp(i, 0, DIJOFS_POV(j)+PAD_DIR_POVUP);
				DX_PerKeyUp(i, 0, DIJOFS_POV(j)+PAD_DIR_POVDOWN);
			}
			// POV Left-up
			else if (js.rgdwPOV[j] < 36000)
			{
				DX_PerKeyDown(i, 0, DIJOFS_POV(j)+PAD_DIR_POVLEFT);
				DX_PerKeyDown(i, 0, DIJOFS_POV(j)+PAD_DIR_POVUP);
			}
		}

		for (j = 0; j < 32; j++)
		{
			if (js.rgbButtons[j] & 0x80)
				DX_PerKeyDown(i,0,DIJOFS_BUTTON(j));
			else
				DX_PerKeyUp(i,0,DIJOFS_BUTTON(j));
		}
	}
}

//////////////////////////////////////////////////////////////////////////////

int PERDXHandleEvents(void)
{
	PollKeys();

	if (YabauseExec() != 0)
		return -1;

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

u32 ScanXInputAxis(int pad, LONG axis, LONG deadzone, SHORT stick, int min_id, int max_id)
{
	if (axis < -deadzone)
		return DX_MAKEKEY(pad, stick, min_id);
	else if (axis > deadzone)
		return DX_MAKEKEY(pad, stick, max_id);
	else
		return 0;
}

//////////////////////////////////////////////////////////////////////////////

u32 ScanXInputTrigger(int pad, BYTE value, BYTE deadzone, SHORT stick, int id)
{
	if (value > deadzone)
		return DX_MAKEKEY(pad, stick, id);
	else
		return 0;
}

//////////////////////////////////////////////////////////////////////////////

u32 PERDXScan(u32 flags) 
{
	int i, j;
	HRESULT hr;

	for (i = 0; i < num_devices; i++)
	{
		LPDIRECTINPUTDEVICE8 curdevice;
		DIJOYSTATE2 js;
		u32 scan;
		
#ifdef HAVE_XINPUT
		if (dev_list[i].is_xinput_device)
		{
			XINPUT_STATE state;
			ZeroMemory( &state, sizeof(XINPUT_STATE) );
			if (XInputGetState(dev_list[i].user_index, &state) != ERROR_DEVICE_NOT_CONNECTED)
				continue;

			// Handle axis		
			if (flags & PERSF_AXIS)
			{
				// L Thumb
				if ((scan = ScanXInputAxis(i, state.Gamepad.sThumbLX,
													XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE, XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE,
													XI_THUMBLX, XI_THUMBLX)) != 0)
					return scan;
				if ((scan = ScanXInputAxis(i, state.Gamepad.sThumbLY,
													XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE, XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE,
													XI_THUMBLY, XI_THUMBLY)) != 0)
					return scan;

				// R Thumb
				if ((scan = ScanXInputAxis(i, state.Gamepad.sThumbRX,
													XINPUT_GAMEPAD_RIGHT_THUMB_DEADZONE, XINPUT_GAMEPAD_RIGHT_THUMB_DEADZONE,
													XI_THUMBRX, XI_THUMBRX)) != 0)
					return scan;
				if ((scan = ScanXInputAxis(i, state.Gamepad.sThumbRY,
													XINPUT_GAMEPAD_RIGHT_THUMB_DEADZONE, XINPUT_GAMEPAD_RIGHT_THUMB_DEADZONE,
													XI_THUMBRY, XI_THUMBRY)) != 0)
					return scan;

				// L Trigger
				if ((scan = ScanXInputTrigger(i, state.Gamepad.bLeftTrigger, XINPUT_GAMEPAD_TRIGGER_THRESHOLD, 
													XINPUT_GAMEPAD_TRIGGER_THRESHOLD, XI_TRIGGERL)) != 0)
					return scan;

				// R Trigger
				if ((scan = ScanXInputTrigger(i, state.Gamepad.bRightTrigger, XINPUT_GAMEPAD_TRIGGER_THRESHOLD, 
					XINPUT_GAMEPAD_TRIGGER_THRESHOLD, XI_TRIGGERR)) != 0)
					return scan;
			}

			if (flags & PERSF_HAT)
			{
				// L Thumb
				if ((scan = ScanXInputAxis(i, state.Gamepad.sThumbLX,
													XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE, 0,
													XI_THUMBL+PAD_DIR_AXISLEFT, XI_THUMBL+PAD_DIR_AXISRIGHT)) != 0)
					return scan;
				if ((scan = ScanXInputAxis(i, state.Gamepad.sThumbLY,
													XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE, 0,
													XI_THUMBL+PAD_DIR_AXISUP, XI_THUMBL+PAD_DIR_AXISDOWN)) != 0)
					return scan;

				// R Thumb
				if ((scan = ScanXInputAxis(i, state.Gamepad.sThumbRX,
													XINPUT_GAMEPAD_RIGHT_THUMB_DEADZONE, 0,
													XI_THUMBR+PAD_DIR_AXISLEFT, XI_THUMBR+PAD_DIR_AXISRIGHT)) != 0)
					return scan;
				if ((scan = ScanXInputAxis(i, state.Gamepad.sThumbRY,
													XINPUT_GAMEPAD_RIGHT_THUMB_DEADZONE, 0,
													XI_THUMBR+PAD_DIR_AXISUP, XI_THUMBR+PAD_DIR_AXISDOWN)) != 0)
					return scan;

				if (state.Gamepad.wButtons & 0xF)
				{
					// Return lowest bit
					for (j = 0; j < 16; j++)
					{
						if (state.Gamepad.wButtons & (1 << j))
							return DX_MAKEKEY(i, 0, DIJOFS_BUTTON(j));
					}
				}
			}

			if (flags & PERSF_BUTTON)
			{
				if (state.Gamepad.wButtons & 0xF3F0)
				{
					// Return lowest bit
					for (j = 0; j < 16; j++)
					{
						if (state.Gamepad.wButtons & (1 << j))
							return DX_MAKEKEY(i, 0, DIJOFS_BUTTON(j));
					}
				}
			}

			continue;
		}
		else if (dev_list[i].lpDIDevice == NULL)
			continue;
#else
		if (dev_list[i].lpDIDevice == NULL)
			continue;
#endif

		curdevice=dev_list[i].lpDIDevice;

		// Poll the device to read the current state
		hr = IDirectInputDevice8_Poll(curdevice);
		if( FAILED( hr ) )
		{
			hr = IDirectInputDevice8_Acquire(curdevice);
			while( hr == DIERR_INPUTLOST)
				hr = IDirectInputDevice8_Acquire(curdevice);

			continue;
		}

		// Get the input's device state
		if( FAILED( hr = IDirectInputDevice8_GetDeviceState( curdevice, sizeof( DIJOYSTATE2 ), &js ) ) )
			continue;
		
		if (flags & PERSF_AXIS)
		{
			// Left Stick
			if ((scan = ScanXInputAxis(i, js.lX-0x7FFF, 0x3FFF, 0x3FFF, XI_THUMBLX, XI_THUMBLX)) != 0)
				return scan;
			if ((scan = ScanXInputAxis(i, js.lY-0x7FFF, 0x3FFF, 0x3FFF, XI_THUMBLY, XI_THUMBLY)) != 0)
				return scan;

			// Right Stick
			if ((scan = ScanXInputAxis(i, js.lRx-0x7FFF, 0x3FFF, 0x3FFF, XI_THUMBRX, XI_THUMBRX)) != 0)
				return scan;
			if ((scan = ScanXInputAxis(i, js.lRy-0x7FFF, 0x3FFF, 0x3FFF, XI_THUMBRY, XI_THUMBRY)) != 0)
				return scan;
		}

		if (flags & PERSF_HAT)
		{
			// L Thumb
			if ((scan = ScanXInputAxis(i, js.lX-0x7FFF, 0x3FFF, 0,
											XI_THUMBL+PAD_DIR_AXISLEFT, XI_THUMBL+PAD_DIR_AXISRIGHT)) != 0)
				return scan;
			if ((scan = ScanXInputAxis(i, js.lY-0x7FFF, 0x3FFF, 0,
											XI_THUMBL+PAD_DIR_AXISUP, XI_THUMBL+PAD_DIR_AXISDOWN)) != 0)
				return scan;

			// R Thumb
			if ((scan = ScanXInputAxis(i, js.lRx-0x7FFF, 0x3FFF, 0,
											XI_THUMBR+PAD_DIR_AXISLEFT, XI_THUMBR+PAD_DIR_AXISRIGHT)) != 0)
				return scan;
			if ((scan = ScanXInputAxis(i, js.lRy-0x7FFF, 0x3FFF, 0,
											XI_THUMBR+PAD_DIR_AXISUP, XI_THUMBR+PAD_DIR_AXISDOWN)) != 0)
				return scan;

			for (j = 0; j < 4; j++)
			{
				// POV Up
				if (js.rgdwPOV[j] < 4500)
					return DX_MAKEKEY(i,0,DIJOFS_POV(j)+PAD_DIR_POVUP);
				// POV Right
				else if (js.rgdwPOV[j] < 13500)
					return DX_MAKEKEY(i,0,DIJOFS_POV(j)+PAD_DIR_POVRIGHT);
				// POV Down
				else if (js.rgdwPOV[j] < 22500)
					return DX_MAKEKEY(i,0,DIJOFS_POV(j)+PAD_DIR_POVDOWN);
				// POV Left
				else if (js.rgdwPOV[j] < 31500)
					return DX_MAKEKEY(i,0,DIJOFS_POV(j)+PAD_DIR_POVLEFT);
			}
		}

		if (flags & PERSF_BUTTON)
		{
			for (j = 0; j < 32; j++)
			{
				if (js.rgbButtons[j] & 0x80)
					return DX_MAKEKEY(i,0,DIJOFS_BUTTON(j));
			}
		}
   }

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

void PERDXFlush(void)
{
}

//////////////////////////////////////////////////////////////////////////////