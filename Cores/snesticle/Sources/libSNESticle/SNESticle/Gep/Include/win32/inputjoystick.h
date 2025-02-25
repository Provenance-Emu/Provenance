

#ifndef _INPUTJOYSTICK_H
#define _INPUTJOYSTICK_H

#include "inputdevice.h"

enum InputJoyButtonE
{
	INPUTJOY_BUTTON_UP,
	INPUTJOY_BUTTON_DOWN,
	INPUTJOY_BUTTON_LEFT,
	INPUTJOY_BUTTON_RIGHT,

	INPUTJOY_BUTTON_0,
	INPUTJOY_BUTTON_1,
	INPUTJOY_BUTTON_2,
	INPUTJOY_BUTTON_3,
	INPUTJOY_BUTTON_4,
	INPUTJOY_BUTTON_5,
	INPUTJOY_BUTTON_6,
	INPUTJOY_BUTTON_7,
	INPUTJOY_BUTTON_8,
	INPUTJOY_BUTTON_9,
	INPUTJOY_BUTTON_10,
	INPUTJOY_BUTTON_11,
	INPUTJOY_BUTTON_12,
	INPUTJOY_BUTTON_13,
	INPUTJOY_BUTTON_14,
	INPUTJOY_BUTTON_15,

	INPUTJOY_BUTTON_NUM,
};


class CInputJoystick : public CInputDevice
{
	Uint32 m_uJoyID;

public:
	Uint8 DigitizeAxis(InputAxisE eAxis, Float32 Min, Float32 Max);

	CInputJoystick(Uint32 uJoyID);
	virtual void Poll();
};

#endif
