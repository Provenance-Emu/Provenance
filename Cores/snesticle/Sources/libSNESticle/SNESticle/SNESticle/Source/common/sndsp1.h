

#ifndef _SNDSP1_H
#define _SNDSP1_H

#include "sndsp.h"

class SNDSP1 : public ISNDSP
{
	Uint8	m_bIdle;
	Uint8	m_uCmd;		// current command

	Uint8	m_uInAddr;
	Uint8	m_uInSize;
	Uint16	m_InData[32];

	Uint8	m_uOutAddr;
	Uint8	m_uOutSize;
	Uint16	m_OutData[32];

public:
	SNDSP1();

	void Reset();
	void WriteData(Uint32 uAddr, Uint8 uData);
	Uint8 ReadData(Uint32 uAddr);
	Uint8 ReadStatus(Uint32 uAddr);

	static SNDSP1 *GetInstance();
};

#endif
