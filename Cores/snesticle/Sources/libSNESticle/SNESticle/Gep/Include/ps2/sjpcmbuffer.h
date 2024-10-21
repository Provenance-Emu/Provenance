
#ifndef _SJPCMBUFFER_H
#define _SJPCMBUFFER_H


#include "mixbuffer.h"


#define SJPCMMIXBUFFER_MAXENQUEUE (800*5)

class SJPCMMixBuffer : public CMixBuffer
{
    Int16   m_OutData[2][SJPCMMIXBUFFER_MAXENQUEUE] _ALIGN(16);
    Int32   m_nOutSamples;

    Int32   m_iPrevSample[2];
    Uint32  m_uSampleRate;
    Bool    m_bAsync;

	Uint32	m_uLastOutput;

    Int32   ConvertSamples2to3(Int16 *pOut, Int16 *pIn, Int32 nSamples, Int32 *pPrevSample);
    Int32   ConvertSamplesStereo_32000(Int16 *pLeftSamples, Int16 *pRightSamples, Int16 *pOutLeft, Int16 *pOutRight, Int32 nInSamples);


public:
    SJPCMMixBuffer(Uint32 uSampleRate = 48000, Bool bAsync = FALSE);

    void SetSampleRate(Uint32 uSampleRate) {m_uSampleRate = uSampleRate;}
	Uint32 GetLastOutput() {return m_uLastOutput;}

    virtual void GetFormat(Uint32 *puSampleRate, Uint32 *pnSampleBits, Uint32 *pnChannels);
    virtual Int32 GetOutputSamples();
    virtual void OutputSamplesStereo(Int16 *pLeftSamples, Int16 *pRightSamples, Int32 nSamples);
    virtual void OutputSamplesMono(Int16 *pSamples, Int32 nSamples);
    virtual void Flush();
};



#endif

