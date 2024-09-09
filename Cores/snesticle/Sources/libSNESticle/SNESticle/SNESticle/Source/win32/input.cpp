
#include "types.h"
#include "input.h"
#include "inputdevice.h"
#include "inputkeyboard.h"
#include "inputmouse.h"
#include "inputjoystick.h"


// physical devices
static CInputDevice		_Input_Null;
static CInputMouse		_Input_Mouse;
static CInputKeyboard	_Input_Keyboard;
static CInputJoystick	_Input_Joystick0(0);
static CInputJoystick	_Input_Joystick1(1);
static CInputJoystick	_Input_Joystick2(2);
static CInputJoystick	_Input_Joystick3(3);

// logical devices
static CInputMap		_Input_Device[INPUT_DEVICE_NUM];

CInputDevice *InputGetDevice(InputDeviceE eDevice)
{
	return &_Input_Device[eDevice];
}


void InputSetMapping(InputDeviceE eDevice, Int32 nMap, Uint8 *pMap)
{
	_Input_Device[eDevice].SetMapping(nMap, pMap);
}

void InputInit()
{
	// set devices
	_Input_Device[INPUT_DEVICE_NULL].SetDevice(&_Input_Null);
	_Input_Device[INPUT_DEVICE_MOUSE].SetDevice(&_Input_Mouse);
	_Input_Device[INPUT_DEVICE_KEYBOARD0].SetDevice(&_Input_Keyboard);
	_Input_Device[INPUT_DEVICE_KEYBOARD1].SetDevice(&_Input_Keyboard);
	_Input_Device[INPUT_DEVICE_KEYBOARD2].SetDevice(&_Input_Keyboard);
	_Input_Device[INPUT_DEVICE_KEYBOARD3].SetDevice(&_Input_Keyboard);
	_Input_Device[INPUT_DEVICE_JOYSTICK0].SetDevice(&_Input_Joystick0);
	_Input_Device[INPUT_DEVICE_JOYSTICK1].SetDevice(&_Input_Joystick1);
	_Input_Device[INPUT_DEVICE_JOYSTICK2].SetDevice(&_Input_Joystick2);
	_Input_Device[INPUT_DEVICE_JOYSTICK3].SetDevice(&_Input_Joystick3);
}

void InputShutdown()
{

}


void InputPoll()
{
	Int32 iDevice;

	// poll physical devices
	_Input_Mouse.Poll();
	_Input_Keyboard.Poll();
	_Input_Joystick0.Poll();
	_Input_Joystick1.Poll();
	_Input_Joystick2.Poll();
	_Input_Joystick3.Poll();

	// poll logical devices
	for (iDevice=0; iDevice < INPUT_DEVICE_NUM; iDevice++)
	{
		_Input_Device[iDevice].Poll();
	}

}

Uint8 InputGetKey(Uint32 uKey)
{
	return _Input_Keyboard.GetButtonState(uKey);
}



