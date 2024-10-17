

#ifndef _INPUTDEVICE_H
#define _INPUTDEVICE_H

enum InputStatusE
{
	INPUT_STATUS_READY,
	INPUT_STATUS_UNPLUGGED,
	INPUT_STATUS_BADDEVICE,

	INPUT_STATUS_NUM
};

enum InputAxisE
{
	INPUT_AXIS_X,
	INPUT_AXIS_Y,

	INPUT_AXIS_NUM
};

#define INPUT_BUTTON_NUM		128

#define INPUT_BUTTONSTATE_UP    0
#define INPUT_BUTTONSTATE_DOWN  1


class IInputDevice
{
public:

	virtual void	ResetState()=0;
	virtual InputStatusE GetStatus()=0;

	virtual Uint32  GetNumButtons()=0;
	virtual Uint8   GetButtonState(Int32 iButton)=0;

	virtual Uint32  GetNumAxes()=0;
	virtual Int32   GetAxisState(InputAxisE eAxis)=0;

	virtual Uint32	GetBits()=0;

	virtual void Poll()=0;
};


class CInputDevice : public IInputDevice
{
protected:
	InputStatusE	m_eStatus;

	Int32			m_nAxes;
	Int32			m_Axes[INPUT_AXIS_NUM];

	Int32			m_nButtons;
	Uint8			m_bButtons[INPUT_BUTTON_NUM];

public:
	CInputDevice();
	void	ResetState();

	Uint32  GetNumButtons() {return m_nButtons;}
	Uint8   GetButtonState(Int32 iButton) {return (iButton < m_nButtons) ? m_bButtons[iButton] : INPUT_BUTTONSTATE_UP;}

	Uint32  GetNumAxes() {return m_nAxes;}
	Int32   GetAxisState(InputAxisE eAxis) {return (eAxis < m_nAxes) ? m_Axes[eAxis]: 0;}

	Uint32	GetBits();

	InputStatusE GetStatus() {return m_eStatus;}

	virtual void Poll();
};


class CInputMap : public CInputDevice
{
	IInputDevice *m_pDevice;

	Int32		m_nButtonMap;
	Uint8		m_ButtonMap[INPUT_BUTTON_NUM];

public:

	CInputMap();

	void	SetDevice(IInputDevice *pDevice);
	void	SetMapping(Int32 nMap, Uint8 *pMap);

	virtual void Poll();
};

#endif
