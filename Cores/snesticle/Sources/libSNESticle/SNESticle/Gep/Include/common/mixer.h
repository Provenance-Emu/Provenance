



#ifndef _MIXER_H
#define _MIXER_H


class CMixer
{

public:
	virtual Bool Mix(Int16 *pSamples, Int32 nSamples, Uint32 uSampleRate) {return FALSE;}
};





#endif
