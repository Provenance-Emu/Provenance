

#ifndef _SNDSP_H
#define _SNDSP_H

class ISNDSP
{
public:
	virtual void Reset()=0;
	virtual void WriteData(Uint32 uAddr, Uint8 uData)=0;
	virtual Uint8 ReadData(Uint32 uAddr)=0;
	virtual Uint8 ReadStatus(Uint32 uAddr)=0;
};

#endif
