
#include <stdlib.h>
#include <string.h>
#include "types.h"
#include "rendersurface.h"


//
// render surface
//

static void _RenderLine8(Uint8 *pDest, Uint8 *pSrc, Int32 nPixels, PaletteT *pClut)
{
	while (nPixels > 0)
	{
		// translate pixel
		((Uint8 *)pDest)[0] = (Uint8)pClut->Color32[*pSrc];

		pDest++;
		pSrc++;
		nPixels--;
	}
}

static void _RenderLine16(Uint8 *pDest, Uint8 *pSrc, Int32 nPixels, PaletteT *pClut)
{
	while (nPixels > 0)
	{
		// translate pixel
		((Uint16 *)pDest)[0] = (Uint16)pClut->Color32[*pSrc];

		pDest+=2;
		pSrc++;
		nPixels--;
	}
}

static void _RenderLine24(Uint8 *pDest, Uint8 *pSrc, Int32 nPixels, PaletteT *pClut)
{
	while (nPixels > 0)
	{
		// translate pixel
		((Uint32 *)pDest)[0] = (Uint32)pClut->Color32[*pSrc];

		pDest+=3;
		pSrc++;
		nPixels--;
	}
}


static void _RenderLine32(Uint8 *pDest, Uint8 *pSrc, Int32 nPixels, PaletteT *pClut)
{
	while (nPixels > 0)
	{
		// translate pixel
		((Uint32 *)pDest)[0] = (Uint32)pClut->Color32[*pSrc];

		pDest+=4;
		pSrc++;
		nPixels--;
	}
}

void CRenderSurface::RenderLine(Int32 iLine, Uint8 *pLine, Int32 nPixels,Int32 Offset)
{
	Uint8	*pOut;
	pOut = GetLinePtr(iLine - m_iLineOffset);

	/*
	for (int i=0; i<nPixels; i++)
	{
		pLine[i] = i >> 2;
	}
	*/

	if (pOut)
	{
		switch (m_Format.uBitDepth)
		{
		case 8:
			_RenderLine8(pOut, pLine, nPixels, &m_Clut);
			break;
		case 16:
			_RenderLine16(pOut, pLine, nPixels, &m_Clut);
			break;
		case 24:
			_RenderLine24(pOut, pLine, nPixels, &m_Clut);
			break;
		case 32:
			_RenderLine32(pOut, pLine, nPixels, &m_Clut);
			break;
		}
	}
}



void CRenderSurface::RenderLine32(Int32 iLine, Uint32 *pLine, Int32 nPixels)
{
	Uint32	*pOut;
	pOut = (Uint32 *) GetLinePtr(iLine - m_iLineOffset);
	if (pOut)
	{
		switch (m_Format.uBitDepth)
		{
		case 8:
		case 16:
		case 24:
			// downconversion is unsupported
			break;
		case 32:
			while (nPixels > 0)
			{
				pOut[0] = pLine[0];
				pOut++;
				pLine++;
				nPixels--;
			}
			break;
		}
	}
}





CRenderSurface::CRenderSurface()
{
	ResetClut();
	m_iPalette = 0;
}


void CRenderSurface::ResetClut()
{
	memset(&m_Clut, 0, sizeof(m_Clut));
}

void CRenderSurface::SetClutEntries(Uint8 *pEntries, Int32 iEntry, Int32 nEntries)
{
	if (m_iPalette < SURFACE_MAXPALETTES)
	{
		if (m_Format.bColorIndex)
		{
			while (nEntries > 0)
			{
				// set lookup value
				m_Clut.Color32[iEntry] = *pEntries;

				pEntries++;
				iEntry++;
				nEntries--;
			}
		}
		else
		{
			PaletteT *pPalette = &m_Palette[m_iPalette];

			while (nEntries > 0)
			{
				// lookup value
				m_Clut.Color32[iEntry] = pPalette->Color32[*pEntries];

				pEntries++;
				iEntry++;
				nEntries--;
			}
		}
	}
}



static inline Uint32 _ComponentShift(Uint32 c, Uint32 nBits, Uint32 nShift)
{
	return (c >> (8 - nBits)) << nShift;
}


static inline Uint32 _ComponentUnshift(Uint32 data, Uint32 nBits, Uint32 nShift)
{
	return (data >> nShift) & ((1<<nBits)-1);
}

static void _ConvertPalette(PaletteT *pDest, Color32T *pSrc, Int32 nEntries, PixelFormatT *pFormat)
{
	Int32 iEntry;
	for (iEntry=0; iEntry < nEntries; iEntry++)
	{
		Uint32 RGBA;

		RGBA = _ComponentShift(pSrc[iEntry].r, pFormat->uRedBits,   pFormat->uRedShift);
		RGBA|= _ComponentShift(pSrc[iEntry].g, pFormat->uGreenBits, pFormat->uGreenShift);
		RGBA|= _ComponentShift(pSrc[iEntry].b, pFormat->uBlueBits,  pFormat->uBlueShift);
		RGBA|= _ComponentShift(pSrc[iEntry].a, pFormat->uAlphaBits, pFormat->uAlphaShift);

		// set color
		pDest->Color32[iEntry] = RGBA;
	}
}



void CRenderSurface::SetPaletteEntries(Int32 iPalette, Color32T *pEntries, Int32 nEntries)
{
	if (iPalette < SURFACE_MAXPALETTES)
	{
		// build palette based on pixel format
		_ConvertPalette(&m_Palette[iPalette], pEntries, nEntries, &m_Format);
	}
}




