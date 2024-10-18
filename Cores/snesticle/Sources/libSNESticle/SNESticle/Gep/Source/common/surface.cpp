
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "types.h"
#include "surface.h"



//
//
//


CSurface::CSurface()
{
	m_pMem = NULL;
	m_pData  = NULL;
	m_uWidth = 0;
	m_uHeight= 0;
	m_uPitch = 0;
	m_iLineOffset = 0;

	memset(&m_Format, 0, sizeof(m_Format));
}

CSurface::~CSurface()
{
	Free();
}

void CSurface::Lock()
{

}


void CSurface::Unlock()
{

}



Uint8 *CSurface::GetLinePtr(Int32 iLine)
{
	if (iLine >= 0 && iLine < (Int32)m_uHeight)
	{
		// get pointer to output
		return m_pData + (iLine * m_uPitch);
	}
	else
	{
		return NULL;
	}
}


void CSurface::ClearLine(Int32 iLine)
{
	Uint8 *pLine;
	pLine = GetLinePtr(iLine);
	if (pLine)
	{
		memset(pLine, 0, m_uWidth * m_Format.uBitDepth / 8);
	}
}

void CSurface::Clear()
{
	Int32 iLine,nLines;

	Lock();

	iLine  = 0;
	nLines = m_uHeight;
	while (nLines > 0)
	{
		ClearLine(iLine);
		iLine++;
		nLines--;
	}

	Unlock();
}


/*

static void _ConvertPixels(Uint8 *pDest, PixelFormatT *pDestFormat, Uint8 *pSrc, PixelFormatT *pSrcFormat, Int32 nPixels)
{
	Uint32 nSrcBytes, nDestBytes;

	nSrcBytes  = pSrcFormat->uBitDepth / 8;
	nDestBytes = pDestFormat->uBitDepth / 8;

	while (nPixels > 0)
	{
		


		nPixels--;
		pSrc  += nSrcBytes;
		pDest += nDestBytes;
	}
}

void CSurface::CopyTo(CSurface *pDest)
{
	CSurface *pSrc = this;
	Int32 iLine, nLines;
	Int32 nPixels;

	// get # of lines to copy
	nLines = pSrc->m_Height;
	if (pSrc->nLines > pDest->m_Height) nLines = pDest->m_Height;

	// get # pixels per line
	nPixels = pSrc->m_Width;
	if (nPixels > pDest->m_Width) nPixels = pDest->m_Pixels;

	pSrc->Lock();
	pDest->Lock();
	for (iLine=0; iLine < nLines; iLine++)
	{
		_ConvertPixels(pDest->GetLine(iLine), &pDest->m_Format, pSrc->GetLine(iLine), &pSrc->m_Format, nPixels);
	}
	pDest->Unlock();
	pSrc->Unlock();
}

*/



void CSurface::Set(Uint8 *pData, Uint32 uWidth, Uint32 uHeight, Uint32 uPitch, PixelFormatT *pFormat)
{
	Free();

	// get pixel format
	if (pFormat)
	{
		// set pixel format
		m_Format = *pFormat;

		// set surface dimensions
		m_uWidth  = uWidth;
		m_uHeight = uHeight;
		m_uPitch  = uPitch;

		// set surface
		m_pData  = pData;
	}
}

void CSurface::Alloc(Uint32 uWidth, Uint32 uHeight, PixelFormatT *pFormat)
{
	Free();

	// get pixel format
	if (pFormat)
	{
		// set pixel format
		m_Format = *pFormat;

		// set surface dimensions
		m_uWidth  = uWidth;
		m_uHeight = uHeight;
		m_uPitch  = uWidth * m_Format.uBitDepth / 8;

		// allocate surface
		m_pMem   = (Uint8 *)malloc(m_uHeight * m_uPitch + 1);

		m_pData  = (Uint8 *)m_pMem;
	}
}

void CSurface::Free()
{
	if (m_pMem)
	{
		free(m_pMem);
		m_pMem   = NULL;
		memset(&m_Format, 0, sizeof(m_Format));
	}

	m_uWidth  = 0;
	m_uHeight = 0;
	m_uPitch  = 0;
	m_pData  = NULL;
}

