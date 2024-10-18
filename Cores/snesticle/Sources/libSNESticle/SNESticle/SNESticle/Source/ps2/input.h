
#ifndef _INPUT_H
#define _INPUT_H

#include "inputdevice.h"

#define INPUT_MAXPADS (5)

enum InputDeviceE
{
	INPUT_DEVICE_NULL,
	INPUT_DEVICE_MOUSE,
	INPUT_DEVICE_KEYBOARD0,
	INPUT_DEVICE_KEYBOARD1,
	INPUT_DEVICE_KEYBOARD2,
	INPUT_DEVICE_KEYBOARD3,
	INPUT_DEVICE_JOYSTICK0,
	INPUT_DEVICE_JOYSTICK1,
	INPUT_DEVICE_JOYSTICK2,
	INPUT_DEVICE_JOYSTICK3,

	INPUT_DEVICE_NUM
};


void InputInit(Bool bXLib);
void InputShutdown();

void InputPoll();
void InputSetMapping(InputDeviceE eDevice, Int32 nMap, Uint8 *pMap);

CInputDevice *InputGetDevice(InputDeviceE eDevice);

Uint32 InputGetPadData(Uint32 uPad);
Bool   InputIsPadConnected(Uint32 uPad);

#endif
