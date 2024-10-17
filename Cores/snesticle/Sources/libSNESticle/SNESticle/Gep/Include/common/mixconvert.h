

#ifndef _MIXCONVERT_H
#define _MIXCONVERT_H

#include "mixbuffer.h"

class CMixConvert : public CMixBuffer
{
	Uint32		m_nSampleRate;
	Uint32		m_nSampleBits;
	Uint32		m_nChannels;

	CMixBuffer *m_pOutput;
	Uint32		m_nOutSampleRate;
	Uint32		m_nOutSamples;

	Int32		m_iPhase[2];
	Int32		m_iPrevSample[2];

public:
	CMixConvert();
	virtual void	GetFormat(Uint32 *puSampleRate, Uint32 *pnSampleBits, Uint32 *pnChannels);
	virtual Int32	GetOutputSamples();
	virtual void	OutputSamplesMono(Int16 *pSamples, Int32 nSamples);
	virtual void	OutputSamplesStereo(Int16 *pLeftSamples, Int16 *pRightSamples, Int32 nSamples);

	void	SetSampleRate(Uint32 nSampleRate);
	void	SetOutput(CMixBuffer *pOutput);
};



#endif
