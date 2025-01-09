
#include <string.h>
#include "types.h"
#include "inputdevice.h"

CInputDevice::CInputDevice()
{
	m_nButtons= 0;
	m_nAxes   = 0;
	m_eStatus = INPUT_STATUS_READY;

	ResetState();
}

void CInputDevice::ResetState()
{
	memset(m_bButtons, 0, sizeof(m_bButtons));
	memset(m_Axes, 0, sizeof(m_Axes));
}

Uint32 CInputDevice::GetBits()
{
	Uint32 Bits = 0;
	Int32 iButton,nButtons;

	nButtons = m_nButtons;
	if (nButtons > 32) nButtons=32;

	// iterate through buttons
	for (iButton=0; iButton < nButtons; iButton++)
	{
		// OR in bit
		Bits |= m_bButtons[iButton] << iButton;
	}

	return Bits;
}


void CInputDevice::Poll()
{

}








//
//
//

CInputMap::CInputMap()
{
	m_nButtonMap = 0;
}

void CInputMap::SetMapping(Int32 nMap, Uint8 *pMap)
{
	Int32 iMap;
	m_nButtonMap = nMap;
	for (iMap=0; iMap < nMap; iMap++)
	{
		m_ButtonMap[iMap] = pMap[iMap];
	}
}

void CInputMap::SetDevice(IInputDevice *pDevice)
{
	m_pDevice = pDevice;
}

void CInputMap::Poll()
{
	Int32 iButton;
	Int32 iAxis;

	if (m_pDevice)
	{
		m_eStatus = m_pDevice->GetStatus();

		// copy axes
		m_nAxes = m_pDevice->GetNumAxes();
		for (iAxis=0; iAxis < m_nAxes; iAxis++)
		{
			m_Axes[iAxis] = m_pDevice->GetAxisState((InputAxisE)iAxis);
		}

		// remap buttons
		m_nButtons = m_nButtonMap;
		for (iButton=0; iButton < m_nButtons; iButton++)
		{
			// remap button
			m_bButtons[iButton] = m_pDevice->GetButtonState(m_ButtonMap[iButton]);
		}
	} 
	else
	{
		m_nAxes = 0;
		m_nButtons=0;
		m_eStatus = INPUT_STATUS_BADDEVICE;
	}
}











