/* FCE Ultra - NES/Famicom Emulator
*
* Copyright notice for this file:
*  Copyright (C) 2002 Xodnizel
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
* Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
*/

#include "common.h"
#include "dinput.h"

#include "input.h"
#include "keyboard.h"

static HRESULT  ddrval; //mbg merge 7/17/06 made static
static int background = 0;
static LPDIRECTINPUTDEVICE7 lpdid=0;

void KeyboardClose(void)
{
	if(lpdid) IDirectInputDevice7_Unacquire(lpdid);
	lpdid=0;
}

static unsigned int keys[256] = {0,}; // with repeat
static unsigned int keys_nr[256] = {0,}; // non-repeating
static unsigned int keys_jd[256] = {0,}; // just-down
static unsigned int keys_jd_lock[256] = {0,}; // just-down released lock
int autoHoldKey = 0, autoHoldClearKey = 0;
int ctr=0;
void KeyboardUpdateState(void)
{
	unsigned char tk[256];

	ddrval=IDirectInputDevice7_GetDeviceState(lpdid,256,tk);
	if (tk[0]) tk[0] = 0;	//adelikat: HACK.  If a keyboard key is recognized as this, the effect is that all non assigned hotkeys are run.  This prevents the key from being used, but also prevent "hotkey explosion".  Also, they essentially couldn't use it anyway since FCEUX doesn't know it is a shift key, and it can't be assigned in the hotkeys
	// HACK because DirectInput is totally wacky about recognizing the PAUSE/BREAK key
	if(GetAsyncKeyState(VK_PAUSE)) // normally this should have & 0x8000, but apparently this key is too special for that to work
		tk[0xC5] = 0x80;

	switch(ddrval)
	{
	case DI_OK: //memcpy(keys,tk,256);break;
		break;

		//mbg 10/8/2008
		//previously only these two cases were handled. this made dwedit's laptop volume keys freak out.
		//we're trying this instead
	default:
	//case DIERR_INPUTLOST:
	//case DIERR_NOTACQUIRED:
		memset(tk,0,256);
		IDirectInputDevice7_Acquire(lpdid);
		break;
	}

	//process keys
	extern int soundoptions;
#define SO_OLDUP      32

	extern int soundo;
	extern int32 fps_scale;
	int notAlternateThrottle = !(soundoptions&SO_OLDUP) && soundo && ((NoWaiting&1)?(256*16):fps_scale) >= 64;
#define KEY_REPEAT_INITIAL_DELAY ((!notAlternateThrottle) ? (16) : (64)) // must be >= 0 and <= 255
#define KEY_REPEAT_REPEATING_DELAY (6) // must be >= 1 and <= 255
#define KEY_JUST_DOWN_DURATION (1) // must be >= 1 and <= 255	// AnS: changed to 1 to disallow unwanted hits of e.g. F1 after pressing Shift+F1 and quickly releasing Shift

	for(int i = 0 ; i < 256 ; i++)
		if(tk[i])
			if(keys_nr[i] < 255)
				keys_nr[i]++; // activate key, and count up for repeat
			else
				keys_nr[i] = 255 - KEY_REPEAT_REPEATING_DELAY; // oscillate for repeat
		else
			keys_nr[i] = 0; // deactivate key

	memcpy(keys,keys_nr,sizeof(keys));

	// key-down detection
	for(int i = 0 ; i < 256 ; i++)
		if(!keys_nr[i])
		{
			keys_jd[i] = 0;
			keys_jd_lock[i] = 0;
		}
		else if(keys_jd_lock[i])
		{}
		else if(keys_jd[i]
		/*&& (i != 0x2A && i != 0x36 && i != 0x1D && i != 0x38)*/)
		{
			if(++keys_jd[i] > KEY_JUST_DOWN_DURATION)
			{
				keys_jd[i] = 0;
				keys_jd_lock[i] = 1;
			}
		}
		else
			keys_jd[i] = 1;

		// key repeat
		for(int i = 0 ; i < 256 ; i++)
			if((int)keys[i] >= KEY_REPEAT_INITIAL_DELAY && !(keys[i]%KEY_REPEAT_REPEATING_DELAY))
				keys[i] = 0;

	extern uint8 autoHoldOn, autoHoldReset;
	autoHoldOn = autoHoldKey && keys[autoHoldKey] != 0;
	autoHoldReset = autoHoldClearKey && keys[autoHoldClearKey] != 0;
}

unsigned int *GetKeyboard(void)
{
	return(keys);
}
unsigned int *GetKeyboard_nr(void)
{
	return(keys_nr);
}
unsigned int *GetKeyboard_jd(void)
{
	return(keys_jd);
}

int KeyboardInitialize(void)
{
	if(lpdid)
		return(1);

	//mbg merge 7/17/06 changed:
	ddrval=IDirectInput7_CreateDeviceEx(lpDI, GUID_SysKeyboard,IID_IDirectInputDevice7, (LPVOID *)&lpdid,0);
	//ddrval=IDirectInput7_CreateDeviceEx(lpDI, &GUID_SysKeyboard,&IID_IDirectInputDevice7, (LPVOID *)&lpdid,0);
	if(ddrval != DI_OK)
	{
		FCEUD_PrintError("DirectInput: Error creating keyboard device.");
		return 0;
	}

	ddrval=IDirectInputDevice7_SetCooperativeLevel(lpdid, hAppWnd,(background?DISCL_BACKGROUND:DISCL_FOREGROUND)|DISCL_NONEXCLUSIVE);
	if(ddrval != DI_OK)
	{
		FCEUD_PrintError("DirectInput: Error setting keyboard cooperative level.");
		return 0;
	}

	ddrval=IDirectInputDevice7_SetDataFormat(lpdid,&c_dfDIKeyboard);
	if(ddrval != DI_OK)
	{
		FCEUD_PrintError("DirectInput: Error setting keyboard data format.");
		return 0;
	}

	////--set to buffered mode
	//DIPROPDWORD dipdw;
	//dipdw.diph.dwSize = sizeof(DIPROPDWORD);
	//dipdw.diph.dwHeaderSize = sizeof(DIPROPHEADER);
	//dipdw.diph.dwObj = 0;
	//dipdw.diph.dwHow = DIPH_DEVICE;
	//dipdw.dwData = 64;

	//ddrval = IDirectInputDevice7_SetProperty(lpdid,DIPROP_BUFFERSIZE, &dipdw.diph);
	////--------

	ddrval=IDirectInputDevice7_Acquire(lpdid);
	/* Not really a fatal error. */
	//if(ddrval != DI_OK)
	//{
	// FCEUD_PrintError("DirectInput: Error acquiring keyboard.");
	// return 0;
	//}
	return 1;
}

static bool curr = false;


static void UpdateBackgroundAccess(bool on)
{
	if(curr == on) return;

	curr = on;
	if(!lpdid)
		return;

	ddrval=IDirectInputDevice7_Unacquire(lpdid);

	if(on)
		ddrval=IDirectInputDevice7_SetCooperativeLevel(lpdid, hAppWnd,DISCL_BACKGROUND|DISCL_NONEXCLUSIVE);
	else
		ddrval=IDirectInputDevice7_SetCooperativeLevel(lpdid, hAppWnd,DISCL_FOREGROUND|DISCL_NONEXCLUSIVE);
	if(ddrval != DI_OK)
	{
		FCEUD_PrintError("DirectInput: Error setting keyboard cooperative level.");
		return;
	}

	ddrval=IDirectInputDevice7_Acquire(lpdid);
	return;
}

void KeyboardSetBackgroundAccessBit(int bit)
{
	background |= (1<<bit);
	UpdateBackgroundAccess(background != 0);
}
void KeyboardClearBackgroundAccessBit(int bit)
{
	background &= ~(1<<bit);
	UpdateBackgroundAccess(background != 0);
}

void KeyboardSetBackgroundAccess(bool on)
{
	if(on)
		KeyboardSetBackgroundAccessBit(KEYBACKACCESS_OLDSTYLE);
	else
		KeyboardClearBackgroundAccessBit(KEYBACKACCESS_OLDSTYLE);
}
