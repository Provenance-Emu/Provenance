
#include <stdlib.h>
#include "types.h"
#include "mixconvert.h"
#include "mixconvert.h"

CMixConvert::CMixConvert()
{
	m_pOutput = NULL;
	m_nOutSampleRate = 0;
	m_iPrevSample[0] = 0;
	m_iPrevSample[1] = 0;
	m_iPhase[0] = 0;
	m_iPhase[1] = 0;
}
void CMixConvert::SetOutput(CMixBuffer *pOutput)
{
	m_pOutput = pOutput;
	m_pOutput->GetFormat(&m_nOutSampleRate, &m_nSampleBits, &m_nChannels);
}

void CMixConvert::SetSampleRate(Uint32 nSampleRate)
{
	m_nSampleRate = nSampleRate;
}

void CMixConvert::GetFormat(Uint32 *puSampleRate, Uint32 *pnSampleBits, Uint32 *pnChannels)
{
	*puSampleRate = m_nSampleRate;
	*pnSampleBits = m_nSampleBits;
	*pnChannels   = m_nChannels;
}

Int32 CMixConvert::GetOutputSamples()
{
	Int32 nInSamples;

	if (!m_pOutput) return 0;

	// get number of samples desired by output
	m_nOutSamples = m_pOutput->GetOutputSamples();

	// calculate number of samples needed to be input (fractional bit lost ?!)
	nInSamples = m_nOutSamples * m_nSampleRate / m_nOutSampleRate;

	return nInSamples;
}

void CMixConvert::OutputSamplesMono(Int16 *pSamples, Int32 nSamples)
{
}

static Int32 Filter(Int16 *pOut, Int16 *pIn, Int32 nSamples, Int32 iPhase, Int32 iPhaseInc, Int32 *pPrevSample)
{
	Int32 iSample0, iSample1;

	iSample0 = *pPrevSample;
	iSample1 = *pIn;

	while (nSamples > 0)
	{
		Int32 iSample;

		// filter sample
		iSample = iSample0;
		iSample +=  (((iSample1 - iSample0) * iPhase) >> 16);

		iPhase+=iPhaseInc;

		if (iPhase >> 16)
		{
			iSample0=iSample1;
			iSample1 = *pIn;	// fetch next sample
			pIn++;
			iPhase &= 0xFFFF;
		}

		// write sample
		pOut[0] = iSample0;
		pOut++;
		nSamples--;
	}

	*pPrevSample = iSample0;
	return iPhase;
}

#define MIXCONVERT_MAXSAMPLES 800 * 8

void CMixConvert::OutputSamplesStereo(Int16 *pLeftSamples, Int16 *pRightSamples, Int32 nSamples)
{
	static Int16 Buffer[2][MIXCONVERT_MAXSAMPLES];
	Int32 iPhaseInc;
	Int32 nOutSamples;

	if (!m_pOutput) return;

	nOutSamples = nSamples * m_nOutSampleRate / m_nSampleRate;

	// determine phase increment
	iPhaseInc = (m_nSampleRate << 16) / m_nOutSampleRate;

	m_iPhase[0] &= 0xFFFF;
	m_iPhase[1] &= 0xFFFF;

	// convert nSamples -> nOutSamples
	while (nOutSamples > 0)
	{
		Int32 nOutBlockSamples = nOutSamples;
		if (nOutBlockSamples > MIXCONVERT_MAXSAMPLES) nOutBlockSamples = MIXCONVERT_MAXSAMPLES;

		// refilter samples
		m_iPhase[0] = Filter(Buffer[0], pLeftSamples,  nOutBlockSamples, m_iPhase[0], iPhaseInc, &m_iPrevSample[0]);
		m_iPhase[1] = Filter(Buffer[1], pRightSamples, nOutBlockSamples, m_iPhase[1], iPhaseInc, &m_iPrevSample[1]);

		// output samples
		m_pOutput->OutputSamplesStereo(Buffer[0], Buffer[1], nOutBlockSamples);

		nOutSamples-=nOutBlockSamples;
	}
}


