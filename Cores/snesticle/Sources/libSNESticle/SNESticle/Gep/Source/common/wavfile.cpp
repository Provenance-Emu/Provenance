

#include <stdio.h>
#include <string.h>
#include "types.h"
#include "wavfile.h"

CWavFile::CWavFile()
{
	m_pFile = NULL;
}

CWavFile::~CWavFile()
{
	if (IsOpen())
	{
		Close();
	}
}

void CWavFile::OutputSampleData(Uint8 *pData, Uint32 nBytes)
{
	if (!IsOpen()) return;

	fwrite(pData, nBytes, 1, m_pFile);
	m_uOutputPos += nBytes;
}

void CWavFile::OutputSamplesMono(Int16 *pSamples, Int32 nSamples)
{
	if (m_Header.Format.nChannels == 1)
	{
		OutputSampleData((Uint8 *)pSamples, nSamples  * sizeof(Int16));
	}
}

void CWavFile::InterleaveStereo(Int16 *pOut, Int16 *pLeft, Int16 *pRight, Int32 nSamples)
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

void CWavFile::OutputSamplesStereo(Int16 *pLeftSamples, Int16 *pRightSamples, Int32 nSamples)
{
	if (m_Header.Format.nChannels == 2)
	{
		Int16 Buffer[2048 * 2];
		while (nSamples > 0)
		{
			Int32 nBlockSamples = nSamples;
			if (nBlockSamples > 2048) nBlockSamples = 2048;
			InterleaveStereo(Buffer, pLeftSamples, pRightSamples, nBlockSamples);
			OutputSampleData((Uint8 *)Buffer, nBlockSamples  * sizeof(Int16) * 2);
			nSamples-=nBlockSamples;
		}
	}
}

void CWavFile::Close()
{
	if (m_pFile)
	{
		// update header lengths
		m_Header.uFileLength = m_uOutputPos + sizeof(m_Header);
		m_Header.uDataLength = m_uOutputPos;

		// rewrite header at beginning of file
		fseek(m_pFile, SEEK_SET, 0);
		fwrite(&m_Header, sizeof(WavFileHeaderT), 1, m_pFile);
		fclose(m_pFile);

		m_pFile = NULL;
	}
}


Int32 CWavFile::Open(Char *pFileName, Uint32 uSampleRate, Uint32 nSampleBits, Uint32 nChannels)
{
	WavFileHeaderT *pHeader = &m_Header;

	if (IsOpen())
	{
		return -2;
	}

	m_pFile = fopen(pFileName, "wb");
	if (!m_pFile)
	{
		return -1;
	}

	// create wave header
	memset(pHeader, 0, sizeof(*pHeader));
	memcpy(&pHeader->idRIFF, "RIFF",  sizeof(pHeader->idRIFF));

	// create wave chunk
	memcpy(&pHeader->idWAVE, "WAVE",  sizeof(pHeader->idWAVE));

	// create format chunk
	memcpy(&pHeader->idFMT0, "fmt ", sizeof(pHeader->idFMT0));
	pHeader->uFormatLength = sizeof(WavFormatT);
	pHeader->Format.wFormatTag = 1;
	pHeader->Format.nChannels = nChannels;
	pHeader->Format.nSamplesPerSec = uSampleRate;
	pHeader->Format.nBitsPerSample = nSampleBits;
	pHeader->Format.nBlockAlign  = nChannels * nSampleBits / 8;
	pHeader->Format.nAvgBytesPerSec = uSampleRate * pHeader->Format.nBlockAlign;

	// create data chunk
	memcpy(&pHeader->idDATA, "data",  sizeof(pHeader->idDATA));

	// write wave header
	fwrite(pHeader, sizeof(WavFileHeaderT), 1, m_pFile);

	m_uOutputPos = 0;
	return 0;
}



Int32 CWavFile::GetOutputSamples()
{
	return m_Header.Format.nSamplesPerSec / 60;
}

void CWavFile::GetFormat(Uint32 *puSampleRate, Uint32 *pnSampleBits, Uint32 *pnChannels)
{
	*puSampleRate = m_Header.Format.nSamplesPerSec;
	*pnSampleBits = m_Header.Format.nBitsPerSample;
	*pnChannels   = m_Header.Format.nChannels;
}

