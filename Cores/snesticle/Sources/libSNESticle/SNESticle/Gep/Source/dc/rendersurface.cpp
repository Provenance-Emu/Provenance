
#include <dc/sq.h>
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
/*
	Uint16 *pDest16 = (Uint16 *)pDest;

	while (nPixels > 0)
	{
		// translate pixel
		*pDest16++ = pClut->Color32[*pSrc++];
		*pDest16++ = pClut->Color32[*pSrc++];
		*pDest16++ = pClut->Color32[*pSrc++];
		*pDest16++ = pClut->Color32[*pSrc++];

		nPixels-=4;
	}
	*/

/*
	Uint32 *pDest32 = (Uint32 *)pDest;
		    
	while (nPixels > 0)
	{
		// translate pixel
		*pDest32++ = pClut->Color32[pSrc[0]] | (pClut->Color32[pSrc[1]] << 16);
		*pDest32++ = pClut->Color32[pSrc[2]] | (pClut->Color32[pSrc[3]] << 16);
		*pDest32++ = pClut->Color32[pSrc[4]] | (pClut->Color32[pSrc[5]] << 16);
		*pDest32++ = pClut->Color32[pSrc[6]] | (pClut->Color32[pSrc[7]] << 16);
 
		pSrc+=8;
		nPixels-=8;
	}
	*/



#if 0
	// point to store queue
	Uint32 *pDest32 = (unsigned int *)(void *)(0xe0000000 | (((unsigned long)pDest) & 0x03ffffc0));
	Int8 *pSrci = (Int8 *)pSrc;

	/* Set store queue memory area as desired */
	QACR0 = ((((unsigned int)pDest)>>26)<<2)&0x1c;
	QACR1 = ((((unsigned int)pDest)>>26)<<2)&0x1c;
		    
	while (nPixels > 0)
	{
		// translate pixel
		pDest32[0] = pClut->Color32[pSrci[0]] | (pClut->Color32[pSrci[1]] << 16);
		pDest32[1] = pClut->Color32[pSrci[2]] | (pClut->Color32[pSrci[3]] << 16);
		pDest32[2] = pClut->Color32[pSrci[4]] | (pClut->Color32[pSrci[5]] << 16);
		pDest32[3] = pClut->Color32[pSrci[6]] | (pClut->Color32[pSrci[7]] << 16);
		pSrci+=8;

		pDest32[4] = pClut->Color32[pSrci[0]] | (pClut->Color32[pSrci[1]] << 16);
		pDest32[5] = pClut->Color32[pSrci[2]] | (pClut->Color32[pSrci[3]] << 16);
		pDest32[6] = pClut->Color32[pSrci[4]] | (pClut->Color32[pSrci[5]] << 16);
		pDest32[7] = pClut->Color32[pSrci[6]] | (pClut->Color32[pSrci[7]] << 16);
		pSrci+=8;
 
		asm("pref @%0" : : "r" (pDest32));

		pDest32+=8;
		nPixels-=16;
	}
#endif



	// point to store queue
	Uint32 *pDest32 = (unsigned int *)(void *)(0xe0000000 | (((unsigned long)pDest) & 0x03ffffc0));
	//Int8 *pSrci = (Int8 *)pSrc;
	Uint8 *pSrci = (Uint8 *)pSrc;

	/* Set store queue memory area as desired */
	QACR0 = ((((unsigned int)pDest)>>26)<<2)&0x1c;
	QACR1 = ((((unsigned int)pDest)>>26)<<2)&0x1c;
		    
	while (nPixels > 0)
	{
		Uint32 a,b,c,d;
		// translate pixel
		a = pClut->Color32[pSrci[0]] | (pClut->Color32[pSrci[1]] << 16);
		b =	pClut->Color32[pSrci[2]] | (pClut->Color32[pSrci[3]] << 16);
		c =	pClut->Color32[pSrci[4]] | (pClut->Color32[pSrci[5]] << 16);
		d =	pClut->Color32[pSrci[6]] | (pClut->Color32[pSrci[7]] << 16);
		pDest32[0] = a;
		pDest32[1] = b;
		pDest32[2] = c;
		pDest32[3] = d;
		pSrci+=8;

		a = pClut->Color32[pSrci[0]] | (pClut->Color32[pSrci[1]] << 16);
		b = pClut->Color32[pSrci[2]] | (pClut->Color32[pSrci[3]] << 16);
		c = pClut->Color32[pSrci[4]] | (pClut->Color32[pSrci[5]] << 16);
		d = pClut->Color32[pSrci[6]] | (pClut->Color32[pSrci[7]] << 16);
		pDest32[4] = a;
		pDest32[5] = b;
		pDest32[6] = c;
		pDest32[7] = d;
		pSrci+=8;
 
		asm("pref @%0" : : "r" (pDest32));

		pDest32+=8;
		nPixels-=16;
	}

	/* Wait for both store queues to complete */
//	pDest32 = (unsigned int *)0xe0000000;
//	pDest32[0] = pDest32[8] = 0;
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

void CRenderSurface::RenderLine(Int32 iLine, Uint8 *pLine, Int32 nPixels, Int32 Offset)
{
	Uint8	*pOut;
	pOut = GetLinePtr(iLine - m_iLineOffset);

	if (pOut)
	{
		switch (m_Format.uBitDepth)
		{
		case 8:
			_RenderLine8(pOut + Offset, pLine, nPixels, &m_Clut);
			break;
		case 16:
			_RenderLine16(pOut + Offset * 2, pLine, nPixels, &m_Clut);
			break;
		case 24:
			_RenderLine24(pOut + Offset * 3, pLine, nPixels, &m_Clut);
			break;
		case 32:
			_RenderLine32(pOut + Offset * 4, pLine, nPixels, &m_Clut);
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



