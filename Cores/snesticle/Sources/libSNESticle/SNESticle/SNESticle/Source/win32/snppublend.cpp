

#include "types.h"
#include "prof.h"
#include "snmask.h"
#include "snppurender.h"



extern SnesChrLookupT _SnesPPU_PlaneLookup[2];

static CRenderSurface *_SNPPUBlend_pTarget=NULL;

//
//
//

void _Color8to32(Uint32 *pDest32, Uint8 *pSrc8, Uint32 *pPal32, Int32 nPixels, SNMaskT *pColorMask, SNMaskT *pHalfColorMask)
{
	Uint8 *pColorMask8 = pColorMask->uMask8;
	Uint8 *pHalfColorMask8 = pHalfColorMask->uMask8;
	SnesChrLookup64T *pLookup64 = (SnesChrLookup64T *)&_SnesPPU_PlaneLookup[1];

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


void _ColorAdd(Uint32 *pDest, Uint32 *pMain, Uint32 *pSub, Uint32 nPixels)
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

void _ColorSub(Uint32 *pDest, Uint32 *pMain, Uint32 *pSub, Uint32 nPixels)
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

static Uint32 _ConvertColor32(SnesColor16T uColor16, PixelFormatT *pFormat, Uint32 uIntensity, Uint32 uShift)
{
	Uint32 uColor32;
	Uint32 uR, uG, uB;

	//uIntensity = 15;

	uR = ((uColor16 >>  0) & 0x1F);
	uG = ((uColor16 >>  5) & 0x1F);
	uB = ((uColor16 >>  10) & 0x1F);

	if (uIntensity < 15)
	{
		uR = uR * uIntensity / 15;
		uG = uG * uIntensity / 15;
		uB = uB * uIntensity / 15;
	}

	// convert snes16->generic32
	uColor32 =  uR <<  (pFormat->uRedShift + uShift);
	uColor32|=  uG <<  (pFormat->uGreenShift + uShift);
	uColor32|=  uB <<  (pFormat->uBlueShift + uShift);
//    uColor32|= 0xFF000000;
	return uColor32;
}



void SNPPUBlendBegin(CRenderSurface *pTarget)
{
    _SNPPUBlend_pTarget = pTarget;
}

void SNPPUBlendEnd()
{
    _SNPPUBlend_pTarget = NULL;
}


void SNPPUBlendUpdatePalette(PaletteT *pPal, Uint16 *pCGRam, Uint32 uIntensity)
{
	if (_SNPPUBlend_pTarget)
	{
		PROF_ENTER("UpdatePalette");
		Int32 iEntry;
		PixelFormatT *pPixelFormat;

		pPixelFormat = _SNPPUBlend_pTarget->GetFormat();
		for (iEntry=0; iEntry < 256; iEntry++)
		{
			// set palette entry
			pPal[0].Color32[iEntry] = _ConvertColor32(pCGRam[iEntry], pPixelFormat, uIntensity, 3);
			pPal[1].Color32[iEntry] = _ConvertColor32(pCGRam[iEntry], pPixelFormat, uIntensity, 2);
			pPal[2].Color32[iEntry] = 0;
			pPal[3].Color32[iEntry] = 0;
		}
		PROF_LEAVE("UpdatePalette");
	}
}


void SNPPUBlendExec(Uint32 *pOut32, Uint8 *pMain8, Uint8 *pSub8, Uint32 *pPal32, Uint32 uFixedColor32, SNMaskT *pColorMask, Bool bAddSub)
{
    Uint32 uMain32[256];
    Uint32 uSub32[256];
    Uint32 uSaveColor;

	// if subscreen is transparent (no opaque bg or objs), then the output color is coldata register
	// if subscreen is masked by color window, then the output color is black
	// if add/sub is being performed on the pixel and 1/2mode is enabled, then 1/2 color result
	// the 1/2 is done even if the main or sub screen color window is masking it ?!
	uSaveColor = pPal32[0];
	pPal32[0] = uFixedColor32;
	PROF_ENTER("Color8to32");
	_Color8to32(uSub32, pSub8, pPal32, 256, &pColorMask[1], &pColorMask[2]);
	PROF_LEAVE("Color8to32");
	pPal32[0] = uSaveColor;

	// if mainscreen is transparent (no opaque bg or objs), then the output color is cgram[0]
	// if mainscreen is masked by color window, then the output color is black
	// if add/sub is being performed on the pixel and 1/2mode is enabled, then 1/2 color result
	// the 1/2 is done even if the main or sub screen color window is masking it ?!
	PROF_ENTER("Color8to32");
	_Color8to32(uMain32, pMain8, pPal32, 256, &pColorMask[0], &pColorMask[2]);
	PROF_LEAVE("Color8to32");

	PROF_ENTER("ColorAdd");
	if (bAddSub)
	{
		_ColorSub(pOut32, uMain32, uSub32, 256);
	} else
	{
		_ColorAdd(pOut32, uMain32, uSub32, 256);
	}
	PROF_LEAVE("ColorAdd");

}
