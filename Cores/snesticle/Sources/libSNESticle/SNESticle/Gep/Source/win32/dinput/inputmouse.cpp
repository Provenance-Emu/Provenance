
#include <windows.h>
#include "types.h"
#include "inputmouse.h"

CInputMouse::CInputMouse()
{
	m_nAxes    = 2;
	m_nButtons = 3;
}

void CInputMouse::Poll()
{
	m_eStatus = INPUT_STATUS_READY;
}


