
#include <stdlib.h>
#include "types.h"
#include "prof.h"
#include "snmask.h"
#include "rendersurface.h"
#include "snppurender.h"
#include "snppublend_c.h"
#include "snppucolor.h"


extern SnesChrLookupT _SnesPPU_PlaneLookup[2];


static Uint32 _ConvertColor16to32(SnesColor16T uColor16, PixelFormatT *pFormat, Uint32 uIntensity, Uint32 uShift)
{
	Uint32 uColor32;
	Uint32 uR, uG, uB;
	Uint32 uA = 0;

	//uIntensity = 15;

	// lookup color
	uColor32 = SNPPUColorConvert15to32(uColor16);

	uR = ((uColor32 >>  0) & 0xFF);
	uG = ((uColor32 >>  8) & 0xFF);
	uB = ((uColor32 >>  16) & 0xFF);

	if (uIntensity < 15)
	{
		uR = uR * uIntensity / 15;
		uG = uG * uIntensity / 15;
		uB = uB * uIntensity / 15;
	}

	// convert snes16->generic32
	if (uShift==2)
	{
		uR>>=1;
		uG>>=1;
		uB>>=1;
	}
	uColor32 =  uR <<  (pFormat->uRedShift);
	uColor32|=  uG <<  (pFormat->uGreenShift);
	uColor32|=  uB <<  (pFormat->uBlueShift);
	uColor32|=  uA <<  (pFormat->uAlphaShift);
	return uColor32;
}





//
//
//

static void _Color8to32(Uint32 *pDest32, Uint8 *pSrc8, Uint32 *pPal32, Int32 nPixels, SNMaskT *pColorMask, SNMaskT *pHalfColorMask)
{
	Uint8 *pColorMask8 = pColorMask->uMask8;
	Uint8 *pHalfColorMask8 = pHalfColorMask->uMask8;
//	SnesChrLookup64T *pLookup64 = (SnesChrLookup64T *)&_SnesPPU_PlaneLookup[1];

	while (nPixels > 0)
	{
		Uint32 uSrc0, uSrc1, uSrc2, uSrc3;
		Uint32 uPixel0, uPixel1, uPixel2, uPixel3;
		Uint8 uMask, uAddSub;

		uMask = pColorMask8[0];
		uAddSub = pHalfColorMask8[0];

		uSrc0  = pSrc8[0] | ((uMask&1)<<9) | ((uAddSub&1)<<8);
		uSrc1  = pSrc8[1] | ((uMask&2)<<8) | ((uAddSub&2)<<7);
		uSrc2  = pSrc8[2] | ((uMask&4)<<7) | ((uAddSub&4)<<6);
		uSrc3  = pSrc8[3] | ((uMask&8)<<6) | ((uAddSub&8)<<5);

		uPixel0 = pPal32[uSrc0];
		uPixel1 = pPal32[uSrc1];
		uPixel2 = pPal32[uSrc2];
		uPixel3 = pPal32[uSrc3];

		pDest32[0] = uPixel0;
		pDest32[1] = uPixel1;
		pDest32[2] = uPixel2;
		pDest32[3] = uPixel3;

		uSrc0  = pSrc8[4] | ((uMask&0x10)<<5)| ((uAddSub&0x10)<<4);
		uSrc1  = pSrc8[5] | ((uMask&0x20)<<4)| ((uAddSub&0x20)<<3);
		uSrc2  = pSrc8[6] | ((uMask&0x40)<<3)| ((uAddSub&0x40)<<2);
		uSrc3  = pSrc8[7] | ((uMask&0x80)<<2)| ((uAddSub&0x80)<<1);

		uPixel0 = pPal32[uSrc0];
		uPixel1 = pPal32[uSrc1];
		uPixel2 = pPal32[uSrc2];
		uPixel3 = pPal32[uSrc3];

		pDest32[4] = uPixel0;
		pDest32[5] = uPixel1;
		pDest32[6] = uPixel2;
		pDest32[7] = uPixel3;

		pSrc8+=8;
		pDest32+=8;
		nPixels-=8;
		pColorMask8++;
		pHalfColorMask8++;
	}
}


static void _ColorAdd(Uint32 *pDest, Uint32 *pMain, Uint32 *pSub, Uint32 nPixels)
{
	Uint8 *pDest8, *pMain8, *pSub8;

	pDest8 = (Uint8 *)pDest;
	pMain8 = (Uint8 *)pMain;
	pSub8  = (Uint8 *)pSub;
	nPixels*=4;

	while (nPixels > 0)
	{
		Uint32 x;

		x = pMain8[0] + pSub8[0];
		if (x>0xFF) x=0xFF;
		pDest8[0] = x;

		pMain8++;
		pSub8++;
		pDest8++;
		nPixels--;
	}
}

static void _ColorSub(Uint32 *pDest, Uint32 *pMain, Uint32 *pSub, Uint32 nPixels)
{
	Uint8 *pDest8, *pMain8, *pSub8;

	pDest8 = (Uint8 *)pDest;
	pMain8 = (Uint8 *)pMain;
	pSub8  = (Uint8 *)pSub;
	nPixels*=4;

	while (nPixels > 0)
	{
		Int32 x;

		x = pMain8[0] - pSub8[0];
		if (x<0x0) x=0;
		pDest8[0] = x;

		pMain8++;
		pSub8++;
		pDest8++;
		nPixels--;
	}
}




static void _ClearLine32(Uint32 *pPixels, Int32 nPixels, Uint32 uColor, Uint32 uBGMask)
{
	while (nPixels > 0)
	{
		pPixels[0] = uColor;

		pPixels++;
		nPixels--;
	}

}


void SNPPUBlendC::Begin(CRenderSurface *pTarget)
{
    m_pTarget = pTarget;
}

void SNPPUBlendC::End()
{
    m_pTarget = NULL;
}


void SNPPUBlendC::UpdatePalette(SNPPUBlendInfoT *pInfo, Uint16 *pCGRam, Uint32 uIntensity)
{
	if (m_pTarget)
	{
		PROF_ENTER("UpdatePalette");
		Int32 iEntry;
		PixelFormatT *pPixelFormat;
        PaletteT *pPal = pInfo->Pal;

		uIntensity = 0xF;

		pPixelFormat = m_pTarget->GetFormat();
		for (iEntry=0; iEntry < 256; iEntry++)
		{
			// set palette entry
			pPal[0].Color32[iEntry] = 0;
			pPal[1].Color32[iEntry] = 0;
			pPal[2].Color32[iEntry] = _ConvertColor16to32(pCGRam[iEntry], pPixelFormat, uIntensity, 3);
			pPal[3].Color32[iEntry] = _ConvertColor16to32(pCGRam[iEntry], pPixelFormat, uIntensity, 2);
		}
		PROF_LEAVE("UpdatePalette");
	}
}

void SNPPUBlendC::UpdatePaletteEntry(SNPPUBlendInfoT *pInfo, Uint32 uAddr, Uint32 uData, Uint32 uIntensity)
{
	if (m_pTarget)
	{
		PROF_ENTER("UpdatePalette");
		PixelFormatT *pPixelFormat;
		PaletteT *pPal = pInfo->Pal;

		uIntensity = 0xF;

		pPixelFormat = m_pTarget->GetFormat();
		// set palette entry
		pPal[0].Color32[uAddr] = 0;
		pPal[1].Color32[uAddr] = 0;
		pPal[2].Color32[uAddr] = _ConvertColor16to32(uData, pPixelFormat, uIntensity, 3);
		pPal[3].Color32[uAddr] = _ConvertColor16to32(uData, pPixelFormat, uIntensity, 2);
		PROF_LEAVE("UpdatePalette");
	}
}



void SNPPUBlendC::Exec(SNPPUBlendInfoT *pInfo, Int32 iLine, Uint32 uFixedColor16, SNMaskT *pColorMask, Bool bAddSub, Uint32 uIntensity)
{
    Uint32 uSaveColor;
    PaletteT *pPalMain = &pInfo->Pal[2];

	// if subscreen is transparent (no opaque bg or objs), then the output color is coldata register
	// if subscreen is masked by color window, then the output color is black
	// if add/sub is being performed on the pixel and 1/2mode is enabled, then 1/2 color result
	// the 1/2 is done even if the main or sub screen color window is masking it ?!
	uSaveColor = pPalMain->Color32[0];
	pPalMain->Color32[0] = _ConvertColor16to32(uFixedColor16, m_pTarget->GetFormat(), uIntensity, 3);
	PROF_ENTER("Color8to32");
	_Color8to32(pInfo->uSub32, pInfo->uSub8, pInfo->Pal[0].Color32, 256, &pColorMask[1], &pColorMask[2]);
	PROF_LEAVE("Color8to32");
	pPalMain->Color32[0] = uSaveColor;

	// if mainscreen is transparent (no opaque bg or objs), then the output color is cgram[0]
	// if mainscreen is masked by color window, then the output color is black
	// if add/sub is being performed on the pixel and 1/2mode is enabled, then 1/2 color result
	// the 1/2 is done even if the main or sub screen color window is masking it ?!
	PROF_ENTER("Color8to32");
	_Color8to32(pInfo->uMain32, pInfo->uMain8, pInfo->Pal[0].Color32, 256, &pColorMask[0], &pColorMask[2]);
	PROF_LEAVE("Color8to32");

	PROF_ENTER("ColorAdd");
	if (bAddSub)
	{
		_ColorSub(pInfo->uLine32, pInfo->uMain32, pInfo->uSub32, 256);
	} else
	{
		_ColorAdd(pInfo->uLine32, pInfo->uMain32, pInfo->uSub32, 256);
	}
	PROF_LEAVE("ColorAdd");

	// submit line to surface
	PROF_ENTER("SubmitLine");
	m_pTarget->RenderLine32(iLine, pInfo->uLine32, 256);
	PROF_LEAVE("SubmitLine");

}



void SNPPUBlendC::Clear(SNPPUBlendInfoT *pInfo, Int32 iLine)
{
	_ClearLine32(pInfo->uLine32, 256, 0x0000000, 0);

	// submit line to surface
	PROF_ENTER("SubmitLine");
	m_pTarget->RenderLine32(iLine, pInfo->uLine32, 256);
	PROF_LEAVE("SubmitLine");
}

