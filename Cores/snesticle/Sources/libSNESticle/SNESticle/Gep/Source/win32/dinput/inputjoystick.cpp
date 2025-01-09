
#include <windows.h>
#include "types.h"
#include "inputjoystick.h"

CInputJoystick::CInputJoystick(Uint32 uJoyID)
{
	m_uJoyID   = uJoyID;
	m_nAxes    = 2;
	m_nButtons = INPUTJOY_BUTTON_NUM;
}

Uint8 CInputJoystick::DigitizeAxis(InputAxisE eAxis, Float32 fMin, Float32 fMax)
{
	Int32 iMin, iMax;

	iMin = (Int32)(fMin * 32768.0f);
	iMax = (Int32)(fMax * 32768.0f);
	return (m_Axes[eAxis]>=iMin && m_Axes[eAxis]<=iMax) ? 1 : 0;
}

void CInputJoystick::Poll()
{
	JOYINFOEX info;
	MMRESULT result;

	if (m_eStatus == INPUT_STATUS_BADDEVICE)
	{
		return;
	}

	// read joystick position
	result = joyGetPosEx(m_uJoyID, &info);
	switch (result)
	{
	case JOYERR_NOERROR:
		Int32 iButton;
		Uint32 ButtonBits;

		// get axes
		m_Axes[INPUT_AXIS_X] = info.dwXpos - 0x8000;
		m_Axes[INPUT_AXIS_Y] = info.dwYpos - 0x8000;

		// digitize axes
		m_bButtons[INPUTJOY_BUTTON_LEFT]  = DigitizeAxis(INPUT_AXIS_X, -1.0f, -0.5f);
		m_bButtons[INPUTJOY_BUTTON_RIGHT] = DigitizeAxis(INPUT_AXIS_X,  0.5f,  1.0f);
		m_bButtons[INPUTJOY_BUTTON_UP]    = DigitizeAxis(INPUT_AXIS_Y, -1.0f, -0.5f);
		m_bButtons[INPUTJOY_BUTTON_DOWN]  = DigitizeAxis(INPUT_AXIS_Y,  0.5f,  1.0f);

		// get buttons
		ButtonBits = info.dwButtons;
		for (iButton=INPUTJOY_BUTTON_0; iButton < INPUTJOY_BUTTON_NUM; iButton++)
		{
			m_bButtons[iButton] = (ButtonBits & 1);
			ButtonBits>>=1;
		}

		m_eStatus = INPUT_STATUS_READY;
		break;

	case MMSYSERR_NODRIVER:
		m_eStatus = INPUT_STATUS_BADDEVICE;
		break;

	case MMSYSERR_INVALPARAM:
		m_eStatus = INPUT_STATUS_BADDEVICE;
		break;

	case MMSYSERR_BADDEVICEID:
		m_eStatus = INPUT_STATUS_BADDEVICE;
		break;

	case JOYERR_PARMS:
		m_eStatus = INPUT_STATUS_BADDEVICE;
		break;

	case JOYERR_NOCANDO:
		m_eStatus = INPUT_STATUS_BADDEVICE;
		break;

	case JOYERR_UNPLUGGED:
		m_eStatus = INPUT_STATUS_UNPLUGGED;
		break;

	default:
		m_eStatus = INPUT_STATUS_UNPLUGGED;
		break;
	}
}

