

#ifndef _WAVFILE_H
#define _WAVFILE_H

#include <stdio.h>

#include "mixbuffer.h"

struct WavFormatT
{
	Int16   wFormatTag;
	Int16	nChannels;			// 1 = mono
	Uint32	nSamplesPerSec;		// sampling rate
	Uint32	nAvgBytesPerSec;	// nChannels * nSamplesPerSec * (nBitsPerSample/8)
	Uint16  nBlockAlign;		// nChannels * (nBitsPerSample / 8)
	Uint16	nBitsPerSample;
};

struct WavFileHeaderT
{
	Uint8		idRIFF[4];          // "RIFF"
	Uint32		uFileLength;

	Uint8		idWAVE[4];          // "WAVE"

	Uint8		idFMT0[4];           // "fmt\0"
	Uint32		uFormatLength;		// wave format length (bytes)
	WavFormatT	Format;				// wave format

	Uint8		idDATA[4];          // "data"
	Uint32		uDataLength;        // data length (Bytes)
};

class CWavFile : public CMixBuffer
{
	FILE			*m_pFile;
	WavFileHeaderT	 m_Header;
	Uint32			 m_uOutputPos;  // output position (bytes)

	static void InterleaveStereo(Int16 *pOut, Int16 *pLeft, Int16 *pRight, Int32 nSamples);
	void OutputSampleData(Uint8 *pSampleData, Uint32 nBytes);

public:
	CWavFile();
	virtual ~CWavFile();

	Int32 Open(Char *pFileName, Uint32 uSampleRate, Uint32 nSampleBits, Uint32 nChannels);
	void Close();
	Bool IsOpen() {return m_pFile ? TRUE : FALSE;}

	virtual Int32	GetOutputSamples();
	virtual void	OutputSamplesMono(Int16 *pSamples, Int32 nSamples);
	virtual void	OutputSamplesStereo(Int16 *pLeftSamples, Int16 *pRightSamples, Int32 nSamples);
	virtual void	GetFormat(Uint32 *puSampleRate, Uint32 *pnSampleBits, Uint32 *pnChannels);
};

#endif
