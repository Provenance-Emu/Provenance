

#ifndef _DSBUFFER_H
#define _DSBUFFER_H

#include "mixbuffer.h"

class DSBuffer : public CMixBuffer
{
	WAVEFORMATEX		m_wfx;
	LPDIRECTSOUNDBUFFER  m_pMixBuf;

	Uint32				 m_nSamples;	// number of samples in buffer
	Uint32				 m_nBytes;		// number of bytes in buffer
	Uint32				 m_uOutputPos;  // output position (bytes)

	Bool Alloc(Uint32 uSampleRate, Uint32 nSampleBits, Uint32 nChannels, Uint32 nSamples);
	void Free();
	static void InterleaveStereo(Int16 *pOut, Int16 *pLeft, Int16 *pRight, Int32 nSamples);


public:
	DSBuffer(Uint32 uSampleRate, Uint32 nSampleBits, Uint32 nChannels, Uint32 nSamples);
	~DSBuffer();

	void OutputSampleData(Uint8 *pSampleData, Uint32 nBytes);

	virtual Int32	GetOutputSamples();
	virtual void	OutputSamplesMono(Int16 *pSamples, Int32 nSamples);
	virtual void	OutputSamplesStereo(Int16 *pLeftSamples, Int16 *pRightSamples, Int32 nSamples);
	virtual void	GetFormat(Uint32 *puSampleRate, Uint32 *pnSampleBits, Uint32 *pnChannels);
};

#endif
