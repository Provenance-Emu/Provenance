
#include <windows.h>
#include "types.h"
#include "inputkeyboard.h"


CInputKeyboard::CInputKeyboard()
{
	m_nAxes    = 0;
	m_nButtons = INPUT_BUTTON_NUM;
}

void CInputKeyboard::Poll()
{
	BYTE key[256];

	if (GetKeyboardState(key))
	{
		Int32 iKey;
		for (iKey=0; iKey < m_nButtons; iKey++)
		{
			m_bButtons[iKey] = (key[iKey] & 0x80) ? INPUT_BUTTONSTATE_DOWN : INPUT_BUTTONSTATE_UP;
		}

		m_eStatus = INPUT_STATUS_READY;
	}
	else
	{
		m_eStatus = INPUT_STATUS_BADDEVICE;
	}
}

