
#include <dsound.h>
#include "types.h"
#include "console.h"
#include "dsbuffer.h"
#include "mixer.h"
#include "windsound.h"
/*
DWORD DSBuffer::sThreadProc(LPVOID pParm)
{
	DSBuffer *pBuffer = (DSBuffer *)pParm;
	return pBuffer->ThreadProcess();
}

Uint32 DSBuffer::ThreadProcess()
{
	Uint32 uEvent;
	Bool bDone = FALSE;

	while (!bDone)
	{
		uEvent = WaitForMultipleObjects(m_nEvents, m_hEvents, FALSE, INFINITE);
		uEvent-= WAIT_OBJECT_0;

		if (uEvent < m_nBlocks)
		{
			Uint32 uWriteOffset;
			void *pData0, *pData1;
			DWORD nData0, nData1;

			// get write offset
			if (uEvent == 0)
			{
				uWriteOffset = m_dsbNotify[m_nEvents - 2].dwOffset;
			} else
			{
				uWriteOffset = m_dsbNotify[uEvent - 1].dwOffset;
			}

//			ConPrint("thread %d %d\n", uEvent, uWriteOffset / m_wfx.nBlockAlign);
//			m_pMixBuf->GetCurrentPosition(&uPlayPos, &uWritePos);

			// clear sound buffer
			ZeroMemory(m_pBuffer, m_nBlockBytes);
			if (m_pMixer)
			{
				m_pMixer->Mix(m_pBuffer, m_nBlockSamples, m_wfx.nSamplesPerSec);
			} 

			// lock mixing buffer
			if (m_pMixBuf->Lock(uWriteOffset, m_nBlockBytes,
					&pData0, &nData0, &pData1, &nData1, 0)==DS_OK)
			{
				// copy data into mixing buffer
				memcpy(pData0, m_pBuffer, nData0);
				if (pData1)
				{
					memcpy(pData1, ((Uint8 *)m_pBuffer) + nData0, nData1);
				}

				// unlock buffer
				m_pMixBuf->Unlock(pData0, nData0, pData1, nData1);
			}
		}
		else
		{
			bDone = TRUE;
		}
	}

//	ConPrint("thread end\n");
	return 0;
}
*/
Bool DSBuffer::Alloc(Uint32 uSampleRate, Uint32 nSampleBits, Uint32 nChannels, Uint32 nSamples)
{
	DSBUFFERDESC dsbdesc;
	LPDIRECTSOUND pDSound = DSoundGetObject();

	// set wave format
	memset(&m_wfx, 0, sizeof(m_wfx)); 
	m_wfx.wFormatTag		= WAVE_FORMAT_PCM; 
	m_wfx.nChannels	     	= nChannels; 
	m_wfx.nSamplesPerSec	= uSampleRate; 
	m_wfx.wBitsPerSample	= nSampleBits; 
	m_wfx.nBlockAlign		= m_wfx.wBitsPerSample / 8 * m_wfx.nChannels;
	m_wfx.nAvgBytesPerSec   = m_wfx.nSamplesPerSec * m_wfx.nBlockAlign;

	m_nSamples       = nSamples;
	m_nBytes         = nSamples * m_wfx.nBlockAlign;

	// create mixing buffer
	memset(&dsbdesc, 0, sizeof(dsbdesc)); 
	dsbdesc.dwSize = sizeof(dsbdesc); 
	dsbdesc.dwFlags = 
		DSBCAPS_GETCURRENTPOSITION2   // Always a good idea
		//| DSBCAPS_GLOBALFOCUS         // Allows background playing
		; 
	dsbdesc.dwBufferBytes = m_nBytes;  
	dsbdesc.lpwfxFormat	  = &m_wfx; 

	if (pDSound->CreateSoundBuffer(&dsbdesc, &m_pMixBuf, NULL) != DS_OK)
	{
		return FALSE;
	}



	void *pData0, *pData1;
	DWORD nData0, nData1;

	// lock mixing buffer
	if (m_pMixBuf->Lock(0, m_nBytes, &pData0, &nData0, &pData1, &nData1, 0)==DS_OK)
	{
		// silence buffer
		memset(pData0, 0, nData0);
		memset(pData1, 0, nData1);

		// unlock buffer
		m_pMixBuf->Unlock(pData0, nData0, pData1, nData1);
	}


	// play mixing buffer
	m_pMixBuf->Play(0, 0, DSBPLAY_LOOPING);
	m_uOutputPos = 0;

	ConPrint("DirectSound Mixer: %dhz %d-bit %s (%d samples)\n",	m_wfx.nSamplesPerSec, m_wfx.wBitsPerSample, m_wfx.nChannels == 2 ? "stereo" : "mono", m_nSamples);
	return TRUE;
}

void DSBuffer::Free()
{
	if (m_pMixBuf)
	{
		m_pMixBuf->Stop();
		Sleep(10);
		m_pMixBuf->Release();
		m_pMixBuf = NULL;
	}

	m_nBytes=0;
}


Int32 DSBuffer::GetOutputSamples()
{
	DWORD uPlayPos;

	// get play position
	// write behind play position
	m_pMixBuf->GetCurrentPosition(&uPlayPos,NULL);

	// see if wrap occurred
	if (m_uOutputPos <= uPlayPos)
	{
		return (uPlayPos - m_uOutputPos) / m_wfx.nBlockAlign;
	} else
	{
		// wrapped
		return (uPlayPos + m_nBytes- m_uOutputPos) / m_wfx.nBlockAlign;
	}

}

void DSBuffer::GetFormat(Uint32 *puSampleRate, Uint32 *pnSampleBits, Uint32 *pnChannels)
{
	*puSampleRate = m_wfx.nSamplesPerSec;
	*pnSampleBits = m_wfx.wBitsPerSample;
	*pnChannels   = m_wfx.nChannels;
}

void DSBuffer::OutputSampleData(Uint8 *pSampleData, Uint32 nBytes)
{
	void *pData0, *pData1;
	DWORD nData0, nData1;

	// cant write more data than in buffer
	if (nBytes > m_nBytes) 
	{
		assert(0);
		nBytes = m_nBytes;
	}

	// lock mixing buffer
	if (m_pMixBuf->Lock(m_uOutputPos, nBytes, &pData0, &nData0, &pData1, &nData1, 0)==DS_OK)
	{
		// copy data into mixing buffer
		memcpy(pData0, pSampleData, nData0);
		if (pData1)
		{
			memcpy(pData1, pSampleData + nData0, nData1);
		}

		// unlock buffer
		m_pMixBuf->Unlock(pData0, nData0, pData1, nData1);
	}

	//  advance output pointer
	m_uOutputPos += nBytes;
	while (m_uOutputPos >= m_nBytes)
	{
		// wrap output pointer
		m_uOutputPos -= m_nBytes;
	}
}

void DSBuffer::OutputSamplesMono(Int16 *pSamples, Int32 nSamples)
{
	OutputSampleData((Uint8 *)pSamples, nSamples  * m_wfx.nBlockAlign);
}

void DSBuffer::InterleaveStereo(Int16 *pOut, Int16 *pLeft, Int16 *pRight, Int32 nSamples)
{
	while (nSamples > 0)
	{
		pOut[0] = pLeft[0];
		pOut[1] = pRight[0];
		pOut+=2;
		pLeft++;
		pRight++;
		nSamples--;
	}
}

void DSBuffer::OutputSamplesStereo(Int16 *pLeftSamples, Int16 *pRightSamples, Int32 nSamples)
{
	Int16 Buffer[2048 * 2];
	while (nSamples > 0)
	{
		Int32 nBlockSamples = nSamples;
		if (nBlockSamples > 2048) nBlockSamples = 2048;
		InterleaveStereo(Buffer, pLeftSamples, pRightSamples, nBlockSamples);
		OutputSampleData((Uint8 *)Buffer, nBlockSamples  * m_wfx.nBlockAlign);
		nSamples-=nBlockSamples;
	}
}


DSBuffer::DSBuffer(Uint32 uSampleRate, Uint32 nSampleBits, Uint32 nChannels, Uint32 nSamples)
{
	Alloc(uSampleRate, nSampleBits, nChannels, nSamples);
}

DSBuffer::~DSBuffer()
{
	Free();
}

