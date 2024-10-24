

#include <stdio.h>
#include <string.h>
#include "types.h"
#include "snio.h"

#define SNIO_VERSION_5A22 (0x02)

Uint8 SnesIO::ReadSerialPad(Uint32 uPad)
{
	// read top-most joypad bit
	return (m_Regs.joyserial[uPad] >> 15) & 1;
}

void SnesIO::ShiftSerialPad(Uint32 uPad)
{
	// shift pad data
	m_Regs.joyserial[uPad] <<= 1;

	// if joystick connected
	if (m_Input.uPad[uPad]!=EMUSYS_DEVICE_DISCONNECTED)
	{
		// set connected status
		m_Regs.joyserial[uPad] |= 1;
	}
}

Uint8 SnesIO::ReadSerial0()
{
	Uint32 uData;

	uData  = ReadSerialPad(0) << 0;

	// confirmed:
	// if strobe is left on, then bitposition never shifts
	// all bits returned are button B
	if (!(m_Regs.joydata&1))
	{
		ShiftSerialPad(0);
	}

	return uData;
}

Uint8 SnesIO::ReadSerial1()
{
	Uint32 uData;

	// if joypads 2,3,4 are all disconnected then assume no multitap is installed
	if (
		m_Input.uPad[2]==EMUSYS_DEVICE_DISCONNECTED && 
		m_Input.uPad[3]==EMUSYS_DEVICE_DISCONNECTED && 
		m_Input.uPad[4]==EMUSYS_DEVICE_DISCONNECTED
		)
	{
		// no multitap!

		// read serial bit
		uData  = ReadSerialPad(1) << 0;

		// confirmed:
		// if strobe is left on, then bitposition never shifts
		// all bits returned are button B
		if (!(m_Regs.joydata&1))
		{
			ShiftSerialPad(1);
		}

	} else
	{
		// multitap

		// confirmed:
		// if stobe is left on, then bit is returned if multitap is connected
		if (m_Regs.joydata&1)
		{
			// signal presence of multitap
			uData = 0x02;
		}
		else
		{
			// multitap port enabled?
			if (m_Regs.wrio & 0x80)
			{
				// use controllers 2 and 3
				uData  = ReadSerialPad(1) << 0;
				uData |= ReadSerialPad(2) << 1; 

				ShiftSerialPad(1);
				ShiftSerialPad(2);
			} else
			{
				// use controllers 4 and 5
				uData  = ReadSerialPad(3) << 0;
				uData |= ReadSerialPad(4) << 1; 

				ShiftSerialPad(3);
				ShiftSerialPad(4);
			}
		}
	}

	// confirmed:
	// this port always returns with 1C bits on
	// havent tested with multitap yet though
	return uData | 0x1C;
}

void SnesIO::WriteSerial(Uint8 uData)
{
	// strobe?
	if ((uData&1) && !(m_Regs.joydata&1))
	{
		int iPad;

		// strobe!
		for (iPad=0; iPad < SNESIO_DEVICE_NUM; iPad++)
		{
			if (m_Input.uPad[iPad] != EMUSYS_DEVICE_DISCONNECTED)
			{
				// latch joypad position
				m_Regs.joyserial[iPad] = m_Input.uPad[iPad] & 0xFFF0;
			} else
			{
				// disconnected joypads return 0's
				m_Regs.joyserial[iPad] = 0;
			}
		}
	}

	m_Regs.joydata = uData;
}

// this function gets called about 3 scanlines after vblank, it performs reads from the serial
// port and loads them into each register
void SnesIO::UpdateJoyPads()
{

	// strobe joypads
	WriteSerial(0);
	WriteSerial(1);
	WriteSerial(0);

	m_Regs.joy1.w = m_Regs.joyserial[0];
	m_Regs.joy2.w = m_Regs.joyserial[1];

	// multitap enabled?
	if (m_Regs.wrio & 0x80)
	{
		// ??
		m_Regs.joy3.w = m_Regs.joyserial[1];
		m_Regs.joy4.w = m_Regs.joyserial[2];
	} else
	{
		// ??
		m_Regs.joy3.w = m_Regs.joyserial[3];
		m_Regs.joy4.w = m_Regs.joyserial[4];
	}

	// perform dummy reads
	for (int i=0; i<16; i++)
	{
		ReadSerial0();
		ReadSerial1();
	}
}


SnesIO::SnesIO()
{
	Reset();
}

void SnesIO::Reset()
{
	memset(this, 0, sizeof(*this));
	m_Regs.rdnmi  =  SNIO_VERSION_5A22;
}

void SnesIO::LatchInput(Emu::SysInputT  *pInput)
{
	if (pInput)
	{
		m_Input = *pInput;
	} else
	{
		// not connected
		m_Input.uPad[0] = EMUSYS_DEVICE_DISCONNECTED;
		m_Input.uPad[1] = EMUSYS_DEVICE_DISCONNECTED;
		m_Input.uPad[2] = EMUSYS_DEVICE_DISCONNECTED;
		m_Input.uPad[3] = EMUSYS_DEVICE_DISCONNECTED;
		m_Input.uPad[4] = EMUSYS_DEVICE_DISCONNECTED;
	}
}
