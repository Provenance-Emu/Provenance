


#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "types.h"
#include "console.h"
#include "snppu.h"
#include "snppurender.h"
#include "rendersurface.h"
#include "snmask.h"
#include "prof.h"
//#include "ps2mem.h"

#define SNPPU_BGPLANE_SIZE 48
#define SNPPURENDER_CHR64 (TRUE)

static void _FetchMode7(Uint8 *pLine, SnesPPU *pPPU, Int32 iLine, SNMaskT *pPriority, SNMaskT *pOpaque);


#if  !SNPPURENDER_CHR64 

static Uint32 _SnesPPU_Tile2PalLookup[16]=
{
0x00000000 + 0x04040404 * 0,
0x00000000 + 0x04040404 * 1,
0x00000000 + 0x04040404 * 2,
0x00000000 + 0x04040404 * 3,
0x00000000 + 0x04040404 * 4,
0x00000000 + 0x04040404 * 5,
0x00000000 + 0x04040404 * 6,
0x00000000 + 0x04040404 * 7,
0x00000000 + 0x04040404 * 0,
0x00000000 + 0x04040404 * 1,
0x00000000 + 0x04040404 * 2,
0x00000000 + 0x04040404 * 3,
0x00000000 + 0x04040404 * 4,
0x00000000 + 0x04040404 * 5,
0x00000000 + 0x04040404 * 6,
0x00000000 + 0x04040404 * 7,
};



static Uint32 _SnesPPU_Tile4PalLookup[16]=
{
0x00000000 + 0x10101010 * 0,
0x00000000 + 0x10101010 * 1,
0x00000000 + 0x10101010 * 2,
0x00000000 + 0x10101010 * 3,
0x00000000 + 0x10101010 * 4,
0x00000000 + 0x10101010 * 5,
0x00000000 + 0x10101010 * 6,
0x00000000 + 0x10101010 * 7,
0x00000000 + 0x10101010 * 0,
0x00000000 + 0x10101010 * 1,
0x00000000 + 0x10101010 * 2,
0x00000000 + 0x10101010 * 3,
0x00000000 + 0x10101010 * 4,
0x00000000 + 0x10101010 * 5,
0x00000000 + 0x10101010 * 6,
0x00000000 + 0x10101010 * 7
};

#else

static Uint64 _SnesPPU_Tile2PalLookup64[4][16]=
{
	{
		0x00000000 + 0x0404040404040404 * 0,
		0x00000000 + 0x0404040404040404 * 1,
		0x00000000 + 0x0404040404040404 * 2,
		0x00000000 + 0x0404040404040404 * 3,
		0x00000000 + 0x0404040404040404 * 4,
		0x00000000 + 0x0404040404040404 * 5,
		0x00000000 + 0x0404040404040404 * 6,
		0x00000000 + 0x0404040404040404 * 7,
		0x00000000 + 0x0404040404040404 * 0,
		0x00000000 + 0x0404040404040404 * 1,
		0x00000000 + 0x0404040404040404 * 2,
		0x00000000 + 0x0404040404040404 * 3,
		0x00000000 + 0x0404040404040404 * 4,
		0x00000000 + 0x0404040404040404 * 5,
		0x00000000 + 0x0404040404040404 * 6,
		0x00000000 + 0x0404040404040404 * 7,
	},
	{
		0x2020202020202020 + 0x0404040404040404 * 0,
		0x2020202020202020 + 0x0404040404040404 * 1,
		0x2020202020202020 + 0x0404040404040404 * 2,
		0x2020202020202020 + 0x0404040404040404 * 3,
		0x2020202020202020 + 0x0404040404040404 * 4,
		0x2020202020202020 + 0x0404040404040404 * 5,
		0x2020202020202020 + 0x0404040404040404 * 6,
		0x2020202020202020 + 0x0404040404040404 * 7,
		0x2020202020202020 + 0x0404040404040404 * 0,
		0x2020202020202020 + 0x0404040404040404 * 1,
		0x2020202020202020 + 0x0404040404040404 * 2,
		0x2020202020202020 + 0x0404040404040404 * 3,
		0x2020202020202020 + 0x0404040404040404 * 4,
		0x2020202020202020 + 0x0404040404040404 * 5,
		0x2020202020202020 + 0x0404040404040404 * 6,
		0x2020202020202020 + 0x0404040404040404 * 7,
	},
	{
		0x4040404040404040 + 0x0404040404040404 * 0,
		0x4040404040404040 + 0x0404040404040404 * 1,
		0x4040404040404040 + 0x0404040404040404 * 2,
		0x4040404040404040 + 0x0404040404040404 * 3,
		0x4040404040404040 + 0x0404040404040404 * 4,
		0x4040404040404040 + 0x0404040404040404 * 5,
		0x4040404040404040 + 0x0404040404040404 * 6,
		0x4040404040404040 + 0x0404040404040404 * 7,
		0x4040404040404040 + 0x0404040404040404 * 0,
		0x4040404040404040 + 0x0404040404040404 * 1,
		0x4040404040404040 + 0x0404040404040404 * 2,
		0x4040404040404040 + 0x0404040404040404 * 3,
		0x4040404040404040 + 0x0404040404040404 * 4,
		0x4040404040404040 + 0x0404040404040404 * 5,
		0x4040404040404040 + 0x0404040404040404 * 6,
		0x4040404040404040 + 0x0404040404040404 * 7,
	},
	{
		0x6060606060606060 + 0x0404040404040404 * 0,
		0x6060606060606060 + 0x0404040404040404 * 1,
		0x6060606060606060 + 0x0404040404040404 * 2,
		0x6060606060606060 + 0x0404040404040404 * 3,
		0x6060606060606060 + 0x0404040404040404 * 4,
		0x6060606060606060 + 0x0404040404040404 * 5,
		0x6060606060606060 + 0x0404040404040404 * 6,
		0x6060606060606060 + 0x0404040404040404 * 7,
		0x6060606060606060 + 0x0404040404040404 * 0,
		0x6060606060606060 + 0x0404040404040404 * 1,
		0x6060606060606060 + 0x0404040404040404 * 2,
		0x6060606060606060 + 0x0404040404040404 * 3,
		0x6060606060606060 + 0x0404040404040404 * 4,
		0x6060606060606060 + 0x0404040404040404 * 5,
		0x6060606060606060 + 0x0404040404040404 * 6,
		0x6060606060606060 + 0x0404040404040404 * 7,
	},
};



static Uint64 _SnesPPU_Tile4PalLookup64[16]=
{
0x00000000 + 0x1010101010101010 * 0,
0x00000000 + 0x1010101010101010 * 1,
0x00000000 + 0x1010101010101010 * 2,
0x00000000 + 0x1010101010101010 * 3,
0x00000000 + 0x1010101010101010 * 4,
0x00000000 + 0x1010101010101010 * 5,
0x00000000 + 0x1010101010101010 * 6,
0x00000000 + 0x1010101010101010 * 7,
0x00000000 + 0x1010101010101010 * 0,
0x00000000 + 0x1010101010101010 * 1,
0x00000000 + 0x1010101010101010 * 2,
0x00000000 + 0x1010101010101010 * 3,
0x00000000 + 0x1010101010101010 * 4,
0x00000000 + 0x1010101010101010 * 5,
0x00000000 + 0x1010101010101010 * 6,
0x00000000 + 0x1010101010101010 * 7
};

#endif


static Uint32 _SnesPPU_Obj4PalLookup[8]=
{
	0x80808080 + 0x10101010 * 0,
	0x80808080 + 0x10101010 * 1,
	0x80808080 + 0x10101010 * 2,
	0x80808080 + 0x10101010 * 3,
	0x80808080 + 0x10101010 * 4,
	0x80808080 + 0x10101010 * 5,
	0x80808080 + 0x10101010 * 6,
	0x80808080 + 0x10101010 * 7
};




struct SNPPUBg8FlipT
{
	Uint32  uFlipXOR;
	Uint8   *pFlipLookup;
	SnesChrLookupT *pLookup;
	Uint32	pad;
};

static SNPPUBg8FlipT _FlipTable8[4]=
{
	{0, _SnesPPU_HFlipLookup[1], &_SnesPPU_PlaneLookup[0]},
	{0, _SnesPPU_HFlipLookup[0], &_SnesPPU_PlaneLookup[1]},
	{7, _SnesPPU_HFlipLookup[1], &_SnesPPU_PlaneLookup[0]},
	{7, _SnesPPU_HFlipLookup[0], &_SnesPPU_PlaneLookup[1]}
};

//////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////



static void _MosaicBG8(Uint8 *pLine, Int32 nPixels, Uint32 uMosaic)
{
	Int32 nMosaic;

	PROF_ENTER("MosiacBG8");

	switch (uMosaic)
	{
	case 2:
		while (nPixels > 0)
		{
			Uint8 uData0, uData1, uData2, uData3;
			uData0 = pLine[0];
			uData1 = pLine[2];
			uData2 = pLine[4];
			uData3 = pLine[6];
			pLine[1] = uData0;
			pLine[3] = uData1;
			pLine[5] = uData2;
			pLine[7] = uData3;
			pLine+=8;
			nPixels-=8;
		}
		break;


	default:
		while (nPixels > 0)
		{
			Uint8 uData;

			uData = pLine[0];
			nMosaic = uMosaic;

			while (nPixels > 0 && nMosaic > 0)
			{
				pLine[0] = uData;
				pLine++;
				nPixels--;
				nMosaic--;
			}
		}
		break;

	}

	PROF_LEAVE("MosiacBG8");
}


static void _MosaicBGPlanar(Uint8 *pLine, Int32 nTotalPixels, Uint32 uMosaic)
{
	Int32 nMosaic;
	Int32 nPixels=0;

	PROF_ENTER("MosiacBGPlanar");

	switch (uMosaic)
	{
	case 2:
		while (nTotalPixels > 0)
		{
			Uint8 uData;
			uData = pLine[0];
			uData &= 0x55;
			uData|= uData << 1;
			pLine[0] = uData;
			nTotalPixels -= 8;
			pLine++;
		}
		break;

	default:
		while (nPixels < nTotalPixels)
		{
			Uint8 uData;

			uData = (pLine[nPixels/8]>>(nPixels&7)) & 1;
			nMosaic = uMosaic;

			if (uData)
			{
				while (nPixels < nTotalPixels && nMosaic > 0)
				{
					pLine[nPixels/8] |= 1<<(nPixels&7);
					nPixels++;
					nMosaic--;
				}
			} else
			{
				while (nPixels < nTotalPixels && nMosaic > 0)
				{
					pLine[nPixels/8] &= ~(1<<(nPixels&7));
					nPixels++;
					nMosaic--;
				}
			}
		}
	}
	PROF_LEAVE("MosiacBGPlanar");
}




// render 8


void _ClearLine8(Uint8 *pLine8, Uint8 *pLineP, Int32 nPixels, Uint8 uColor, Uint32 uBGMask)
{
	while (nPixels > 0)
	{
		pLine8[0] = uColor;
		pLineP[0] = uBGMask;

		pLine8++;
		pLineP++;
		nPixels--;
	}

}

void _ClearLine8(Uint8 *pLine8, Int32 nPixels, Uint8 uColor)
{
	while (nPixels > 0)
	{
		pLine8[0] = uColor;

		pLine8++;
		nPixels--;
	}

}

#if !SNPPURENDER_CHR64

static void _FetchCHR2(Uint16 *pVram, Uint32 uBaseAddr, SnesRenderTileT *pTiles, Int32 nTiles, Uint32 uScrollY, Uint8 *pDest, Uint8 *pMask)
{
	SNPPUBg8FlipT *pFlip;

	PROF_ENTER("_FetchCHR2");
	while (nTiles > 0)
	{
		SnesPPUTile2T *pTile2;
		Uint32 uTileAddr;
		Uint32 uPlane0, uPlane1;
		Uint32 uTile0, uTile1;
		Uint32 uMask;
		SnesChrLookupT *pLookup;
		Uint8 *pHFlip;

		pFlip = &_FlipTable8[pTiles->uFlip];

		// calculate tile address
		uTileAddr = (uBaseAddr + pTiles->uTile * 8) & 0x7FFF;

		// get pointer to tile data (y flipped)
		pTile2 = (SnesPPUTile2T *)(pVram + uTileAddr + (uScrollY ^ pFlip->uFlipXOR));

		// get tile plane bits
		uPlane0 = pTile2->uPlane01[0][0];
		uPlane1 = pTile2->uPlane01[0][1];

		pLookup = pFlip->pLookup;
		pHFlip  = pFlip->pFlipLookup;

		uMask = uPlane0 | uPlane1;
		uMask = pHFlip[uMask];

		pMask[ 0] = uMask;
		pMask[SNPPU_BGPLANE_SIZE] = (pTiles->uPal & 8) ? uMask : 0;
		pMask++;

		// get palette bits
		uTile0  = 
		uTile1  = _SnesPPU_Tile2PalLookup[pTiles->uPal];

		// decode tile
		uTile0 |= (*pLookup)[uPlane0][0] << 0;
		uTile1 |= (*pLookup)[uPlane0][1] << 0;

		uTile0 |= (*pLookup)[uPlane1][0] << 1;
		uTile1 |= (*pLookup)[uPlane1][1] << 1;

		// store tile data
		((Uint32 *)pDest)[0] = uTile0;
		((Uint32 *)pDest)[1] = uTile1;

		pDest+=8;
		pTiles++;
		nTiles--;
	}
	PROF_LEAVE("_FetchCHR2");

}







static void _FetchCHR4(Uint16 *pVram, Uint32 uBaseAddr, SnesRenderTileT *pTiles, Int32 nTiles, Uint32 uScrollY, Uint8 *pDest, Uint8 *pMask)
{
	SNPPUBg8FlipT *pFlip;

	PROF_ENTER("_FetchCHR4");

	while (nTiles > 0)
	{
		SnesPPUTile4T *pTile4;
		Uint32 uTileAddr;
		Uint32 uPlane0, uPlane1, uPlane2, uPlane3;
		Uint32 uTile0, uTile1;
		Uint32 uMask;
		SnesChrLookupT *pLookup;
		Uint8 *pHFlip;

		pFlip = &_FlipTable8[pTiles->uFlip];

		// calculate tile address
		uTileAddr = (uBaseAddr + pTiles->uTile * 16) & 0x7FFF;

		// get pointer to tile data (y flipped)
		pTile4 = (SnesPPUTile4T *)(pVram + uTileAddr + (uScrollY ^ pFlip->uFlipXOR));

		// get tile plane bits
		uPlane0 = pTile4->uPlane01[0][0];
		uPlane1 = pTile4->uPlane01[0][1];
		uPlane2 = pTile4->uPlane23[0][0];
		uPlane3 = pTile4->uPlane23[0][1];

		pLookup = pFlip->pLookup;
		pHFlip  = pFlip->pFlipLookup;


		// create mask
		uMask = uPlane0 | uPlane1 | uPlane2 | uPlane3;
		uMask = pHFlip[uMask];

		pMask[ 0] = uMask;
		pMask[SNPPU_BGPLANE_SIZE] = (pTiles->uPal & 8) ? uMask : 0;
		pMask++;

		// get palette bits
		uTile0  = 
		uTile1  = _SnesPPU_Tile4PalLookup[pTiles->uPal];

		// decode tile
		uTile0 |= (*pLookup)[uPlane0][0] << 0;
		uTile1 |= (*pLookup)[uPlane0][1] << 0;

		uTile0 |= (*pLookup)[uPlane1][0] << 1;
		uTile1 |= (*pLookup)[uPlane1][1] << 1;

		uTile0 |= (*pLookup)[uPlane2][0] << 2;
		uTile1 |= (*pLookup)[uPlane2][1] << 2;

		uTile0 |= (*pLookup)[uPlane3][0] << 3;
		uTile1 |= (*pLookup)[uPlane3][1] << 3;

		// store tile data
		((Uint32 *)pDest)[0] = uTile0;
		((Uint32 *)pDest)[1] = uTile1;

		pDest+=8;
		pTiles++;
		nTiles--;
	}
	PROF_LEAVE("_FetchCHR4");
}




static void _FetchCHR(Uint8 *pLine, SnesPPU *pPPU, SnesBGInfoT *pBGInfo, struct SnesRenderTileT *pTiles, Int32 nTiles, Int32 iLine,Uint8 *pMask)
{
	Uint32 uScrollY;

	if (pBGInfo->uMosaic > 0)
	{
		iLine /= pBGInfo->uMosaic + 1;
		iLine *= pBGInfo->uMosaic + 1;
	}

	uScrollY = pBGInfo->uScrollY + iLine;
	switch (pBGInfo->uBitDepth)
	{
	case 2:
		// fetch chr (2-bit)
		_FetchCHR2(pPPU->GetVramPtr(0), pBGInfo->uChrAddr, pTiles, nTiles, uScrollY & 7, pLine, pMask);
		break;
	case 4:
		// fetch chr (4-bit)
		_FetchCHR4(pPPU->GetVramPtr(0), pBGInfo->uChrAddr, pTiles, nTiles, uScrollY & 7, pLine, pMask);
		break;
	}

	if (pBGInfo->uMosaic > 0)
	{
		_MosaicBG8(pLine + (pBGInfo->uScrollX & 7), 256, pBGInfo->uMosaic + 1);
	}

}


#else


//
//
//


static void _FetchCHR2_64(const Uint16 *pVram, Uint32 uBaseAddr, const SnesRenderTileT *pTiles, Int32 nTiles, Uint32 uScrollY, Uint8 *pDest, Uint8 *pMask, Uint64 *pPalLookup)
{
	SNPPUBg8FlipT *pFlip;

	PROF_ENTER("_FetchCHR2_64");
	while (nTiles > 0)
	{
		SnesPPUTile2T *pTile2;
		Uint32 uTileAddr;
		Uint32 uPlane0, uPlane1;
		Uint64 uTile0;
		Uint32 uMask;
		SnesChrLookup64T *pLookup;
		Uint8 *pHFlip;

		pFlip = &_FlipTable8[pTiles->uFlip];

		// calculate tile address
		uTileAddr = (uBaseAddr + pTiles->uTile * 8) & 0x7FFF;

		// get pointer to tile data (y flipped)
		pTile2 = (SnesPPUTile2T *)(pVram + uTileAddr + ((uScrollY+pTiles->uOffsetY) ^ pFlip->uFlipXOR));

		// get tile plane bits
		uPlane0 = pTile2->uPlane01[0][0];
		uPlane1 = pTile2->uPlane01[0][1];

		pLookup = (SnesChrLookup64T *)pFlip->pLookup;
		pHFlip  = pFlip->pFlipLookup;

		uMask = uPlane0 | uPlane1;
		uMask = pHFlip[uMask];

		// get palette bits
		uTile0  =  pPalLookup[pTiles->uPal];

		// decode tile
		uTile0 |= (*pLookup)[uPlane0] << 0;
		uTile0 |= (*pLookup)[uPlane1] << 1;

		pMask[ 0] = uMask;
		pMask[SNPPU_BGPLANE_SIZE] = (pTiles->uPal & 8) ? uMask : 0;
		pMask++;

		// store tile data
		((Uint64 *)pDest)[0] = uTile0;

		pDest+=8;
		pTiles++;
		nTiles--;
	}
	PROF_LEAVE("_FetchCHR2_64");

}









static void _FetchCHR4_64(const Uint16 *pVram, Uint32 uBaseAddr, const SnesRenderTileT *pTiles, Int32 nTiles, Uint32 uScrollY, Uint8 *pDest, Uint8 *pMask)
{
	const SNPPUBg8FlipT *pFlip;

	PROF_ENTER("_FetchCHR4_64");

	while (nTiles > 0)
	{
		const SnesPPUTile4T *pTile4;
		Uint32 uTileAddr;
		Uint32 uPlane0, uPlane1, uPlane2, uPlane3;
		Uint64 uTile0;
		Uint32 uMask;
		const SnesChrLookup64T *pLookup;
		Uint8 *pHFlip;

		pFlip = &_FlipTable8[pTiles->uFlip];

		// calculate tile address
		uTileAddr = (uBaseAddr + pTiles->uTile * 16) & 0x7FFF;

		// get pointer to tile data (y flipped)
		pTile4 = (SnesPPUTile4T *)(pVram + uTileAddr + ((uScrollY+pTiles->uOffsetY) ^ pFlip->uFlipXOR));

		// get tile plane bits
		uPlane0 = pTile4->uPlane01[0][0];
		uPlane1 = pTile4->uPlane01[0][1];
		uPlane2 = pTile4->uPlane23[0][0];
		uPlane3 = pTile4->uPlane23[0][1];

		pLookup = (SnesChrLookup64T *)pFlip->pLookup;
		pHFlip  = pFlip->pFlipLookup;


		// create mask
		uMask = uPlane0 | uPlane1 | uPlane2 | uPlane3;
		uMask = pHFlip[uMask];


		// get palette bits
		uTile0  = _SnesPPU_Tile4PalLookup64[pTiles->uPal];

		// decode tile
		uTile0 |= (*pLookup)[uPlane0] << 0;
		uTile0 |= (*pLookup)[uPlane1] << 1;
		uTile0 |= (*pLookup)[uPlane2] << 2;
		uTile0 |= (*pLookup)[uPlane3] << 3;

		// store mask
		pMask[ 0] = uMask;
		pMask[SNPPU_BGPLANE_SIZE] = (pTiles->uPal & 8) ? uMask : 0;
		pMask++;

		// store tile data
		((Uint64 *)pDest)[0] = uTile0;

		pDest+=8;
		pTiles++;
		nTiles--;
	}
	PROF_LEAVE("_FetchCHR4_64");
}


static void _FetchCHR8_64(const Uint16 *pVram, Uint32 uBaseAddr, const SnesRenderTileT *pTiles, Int32 nTiles, Uint32 uScrollY, Uint8 *pDest, Uint8 *pMask)
{
	SNPPUBg8FlipT *pFlip;

	PROF_ENTER("_FetchCHR8_64");

	while (nTiles > 0)
	{
		SnesPPUTile8T *pTile8;
		Uint32 uTileAddr;
		Uint32 uPlane0, uPlane1, uPlane2, uPlane3;
		Uint32 uPlane4, uPlane5, uPlane6, uPlane7;
		Uint64 uTile0;
		Uint32 uMask;
		SnesChrLookup64T *pLookup;
		Uint8 *pHFlip;

		pFlip = &_FlipTable8[pTiles->uFlip];

		// calculate tile address
		uTileAddr = (uBaseAddr + pTiles->uTile * 32) & 0x7FFF;

		// get pointer to tile data (y flipped)
		pTile8 = (SnesPPUTile8T *)(pVram + uTileAddr + ((uScrollY+pTiles->uOffsetY) ^ pFlip->uFlipXOR));

		// get tile plane bits
		uPlane0 = pTile8->uPlane01[0][0];
		uPlane1 = pTile8->uPlane01[0][1];
		uPlane2 = pTile8->uPlane23[0][0];
		uPlane3 = pTile8->uPlane23[0][1];
		uPlane4 = pTile8->uPlane45[0][0];
		uPlane5 = pTile8->uPlane45[0][1];
		uPlane6 = pTile8->uPlane67[0][0];
		uPlane7 = pTile8->uPlane67[0][1];

		pLookup = (SnesChrLookup64T *)pFlip->pLookup;
		pHFlip  = pFlip->pFlipLookup;

		// create mask
		uMask = uPlane0 | uPlane1 | uPlane2 | uPlane3 | uPlane4 | uPlane5 | uPlane6 | uPlane7;
		uMask = pHFlip[uMask];

		// decode tile
		uTile0  = (*pLookup)[uPlane0] << 0;
		uTile0 |= (*pLookup)[uPlane1] << 1;
		uTile0 |= (*pLookup)[uPlane2] << 2;
		uTile0 |= (*pLookup)[uPlane3] << 3;
		uTile0 |= (*pLookup)[uPlane4] << 4;
		uTile0 |= (*pLookup)[uPlane5] << 5;
		uTile0 |= (*pLookup)[uPlane6] << 6;
		uTile0 |= (*pLookup)[uPlane7] << 7;

		pMask[ 0] = uMask;
		pMask[SNPPU_BGPLANE_SIZE] = (pTiles->uPal & 8) ? uMask : 0;
		pMask++;

		// store tile data
		((Uint64 *)pDest)[0] = uTile0;

		pDest+=8;
		pTiles++;
		nTiles--;
	}
	PROF_LEAVE("_FetchCHR8_64");
}






static void _FetchCHR_64(Uint8 *pLine, SnesPPU *pPPU, SnesBGInfoT *pBGInfo, struct SnesRenderTileT *pTiles, Int32 nTiles, Int32 iLine,Uint8 *pMask, Bool bOffset)
{
	Uint32 uScrollY = 0;

	if (pBGInfo->uMosaic > 0)
	{
		iLine /= pBGInfo->uMosaic + 1;
		iLine *= pBGInfo->uMosaic + 1;
	}

	if (!bOffset)
	{
		uScrollY = pBGInfo->uScrollY + iLine;
	}

	switch (pBGInfo->uBitDepth)
	{
	case 2:
		// fetch chr (2-bit)
		_FetchCHR2_64(pPPU->GetVramPtr(0), pBGInfo->uChrAddr, pTiles, nTiles, uScrollY & 7, pLine, pMask, _SnesPPU_Tile2PalLookup64[pBGInfo->uPalBase]);
		break;
	case 4:
		// fetch chr (4-bit)
		_FetchCHR4_64(pPPU->GetVramPtr(0), pBGInfo->uChrAddr, pTiles, nTiles, uScrollY & 7, pLine, pMask);
		break;
	case 8:
		// fetch chr (8-bit)
		_FetchCHR8_64(pPPU->GetVramPtr(0), pBGInfo->uChrAddr, pTiles, nTiles, uScrollY & 7, pLine, pMask);
		break;
	}

	if (pBGInfo->uMosaic > 0)
	{
		_MosaicBG8(pLine + (pBGInfo->uScrollX & 7), 256, pBGInfo->uMosaic + 1);
	}
}

#endif

//#endif


#if CODE_PLATFORM == CODE_PS2



static void _RenderBGData_O(Uint8 *pLine8, Uint8 *pSrc8, SNMaskT *pBGMask, Uint32 uScrollX, Int32 nTiles)
{
	Uint16 *pMaskData;
	SnesChrLookup64T *pLookup64 = (SnesChrLookup64T *)&_SnesPPU_PlaneLookup[1];

	pSrc8    += (uScrollX & 7);
	pMaskData = (Uint16 *)pBGMask->uMask8;

	__asm__ (
		"mtsab      %0,0     \n"
		: : "r" (pSrc8)
		);    

	while (nTiles > 0)
	{
		Uint32 uMask;

		// fetch mask half-worde for 16 pixels
		uMask = *pMaskData;
		pMaskData++;

		// write 0 to output
		__asm__ (
			"sq        $0,0x00(%0)     \n"
			: : "r" (pLine8)
			);    

		if (uMask)
		{
			Uint128 uSrc0, uSrc1;

			__asm__ (
				"lq        %0,0x00(%2)     \n"
				"lq        %1,0x10(%2)     \n"
				"qfsrv     %0,%1,%0       \n"
				: "=r" (uSrc0),"=r" (uSrc1)
				: "r" (pSrc8)
				);    

			if (uMask!=0xFFFF)
			{
				Uint64 uMask0,uMask1;

				uMask0 = (*pLookup64)[uMask & 0xFF];
				uMask1 = (*pLookup64)[uMask >> 8];

				__asm__ (
					"pcpyld     %0,%1,%0        \n" // combine mask0, mask1
					"pceqb      %0,%0,$0        \n"
					"por        %2,%2,%0        \n" // uSrc0   |= uMask0;
					"pxor       %2,%2,%0        \n" // uSrc0   ^= uMask0;
					: "+r" (uMask0), "+r" (uMask1), "+r" (uSrc0)
					);    
			}

			((Uint128 *)pLine8)[0] = uSrc0; 
		}

		pSrc8+=16;
		pLine8+=16;
		nTiles-=2;
	}
}

static void _RenderBGData(Uint8 *pLine8, Uint8 *pSrc8, SNMaskT *pBGMask, Uint32 uScrollX, Int32 nTiles)
{
	Uint16 *pMaskData;
	SnesChrLookup64T *pLookup64 = (SnesChrLookup64T *)&_SnesPPU_PlaneLookup[1];

	pSrc8    += (uScrollX & 7);
	pMaskData = (Uint16 *)pBGMask->uMask8;

    __asm__ (
    	"mtsab      %0,0     \n"
    	: : "r" (pSrc8)
     );    

	while (nTiles > 0)
	{
		Uint32 uMask;

		// fetch mask half-worde for 16 pixels
		uMask = *pMaskData;
        pMaskData++;

		if (uMask)
		{
			Uint128 uSrc0, uSrc1;

    	    __asm__ (
    	        "lq        %0,0x00(%2)     \n"
    	        "lq        %1,0x10(%2)     \n"
    	        "qfsrv     %0,%1,%0       \n"
    	        : "=r" (uSrc0),"=r" (uSrc1)
    	        : "r" (pSrc8)
    	     );    

			if (uMask!=0xFFFF)
			{
                Uint64 uMask0,uMask1;
                Uint128 uDest0;

                uMask0 = (*pLookup64)[uMask & 0xFF];
                uMask1 = (*pLookup64)[uMask >> 8];

    	        __asm__ (
        	        "lq         %3,0x00(%4)     \n" // load uDest0
                    "pcpyld     %0,%1,%0        \n" // combine mask0, mask1
                    "pceqb      %0,%0,$0        \n"
                    "pand       %3,%3,%0        \n" // uDest0  &= uMask0;
                    "por        %2,%2,%0        \n" // uSrc0   |= uMask0;
                    "pxor       %2,%2,%0        \n" // uSrc0   ^= uMask0;
                    "por        %2,%2,%3        \n" // uSrc0   |= uDest0;

    	            : "+r" (uMask0), "+r" (uMask1), "+r" (uSrc0), "=r" (uDest0)
                    : "r" (pLine8)
    	         );    

			}

			((Uint128 *)pLine8)[0] = uSrc0; 
		}

		pSrc8+=16;
		pLine8+=16;
		nTiles-=2;
	}
}


#else

#define RENDERBGPIXEL(_y,_x)\
	if (uMask&(1<<(_x))) pLine8[_x] = (_y) >> (_x*8); 

static void _RenderBGData(Uint8 *pLine8, Uint8 *pSrc8, SNMaskT *pBGMask, Uint32 uScrollX, Int32 nTiles)
{
	Uint8 *pMaskData;
	Uint32 uShift, uInvShift;

	//memcpy(pLine8, pSrc8 + (uScrollX &7), 256);

	pSrc8    += (uScrollX & 4);
	uShift    = (uScrollX & 3) << 3;
	uInvShift = 32 - uShift;

	pMaskData = pBGMask->uMask8;
	if (uShift == 0)
	{
		while (nTiles > 0)
		{
			Uint32 uMask;

			// fetch mask byte
			uMask = *pMaskData++;

			if (uMask)
			{
				Uint32 t0,t2;
				t0 = ((Uint32 *)pSrc8)[0];
				t2 = ((Uint32 *)pSrc8)[1];
				pSrc8+=8;

				if (uMask==0xFF)
				{
					((Uint32 *)pLine8)[0] = t0; 
					((Uint32 *)pLine8)[1] = t2; 
					pLine8+=8;
				} else
				{
					if (uMask&(1<<0)) pLine8[0] = t0 >> (0*8); 
					if (uMask&(1<<1)) pLine8[1] = t0 >> (1*8); 
					if (uMask&(1<<2)) pLine8[2] = t0 >> (2*8); 
					if (uMask&(1<<3)) pLine8[3] = t0 >> (3*8); 
					if (uMask&(1<<4)) pLine8[4] = t2 >> (0*8); 
					if (uMask&(1<<5)) pLine8[5] = t2 >> (1*8); 
					if (uMask&(1<<6)) pLine8[6] = t2 >> (2*8); 
					if (uMask&(1<<7)) pLine8[7] = t2 >> (3*8); 
					pLine8+=8;
				}
			}  else
			{
				pSrc8+=8;
				pLine8+=8;
			}

			nTiles--;
		}
	} else
	{

		while (nTiles > 0)
		{
			Uint32 uMask;
			Uint32 t0,t1,t2,t3;

			// fetch mask byte
			uMask = *pMaskData++;

			if (uMask)
			{
				t0 = ((Uint32 *)pSrc8)[0];
				t1 = 
				t2 = ((Uint32 *)pSrc8)[1];
				t3 = ((Uint32 *)pSrc8)[2];
				pSrc8+=8;

				t0 >>= uShift;
				t1 <<= uInvShift;
				t0|=t1;

				t2 >>= uShift;
				t3 <<= uInvShift;
				t2|=t3;

				if (uMask==0xFF)
				{
					((Uint32 *)pLine8)[0] = t0; 
					((Uint32 *)pLine8)[1] = t2; pLine8+=8;
				} else
				{
					if (uMask&(1<<0)) pLine8[0] = t0 >> (0*8); 
					if (uMask&(1<<1)) pLine8[1] = t0 >> (1*8); 
					if (uMask&(1<<2)) pLine8[2] = t0 >> (2*8); 
					if (uMask&(1<<3)) pLine8[3] = t0 >> (3*8); 
					if (uMask&(1<<4)) pLine8[4] = t2 >> (0*8); 
					if (uMask&(1<<5)) pLine8[5] = t2 >> (1*8); 
					if (uMask&(1<<6)) pLine8[6] = t2 >> (2*8); 
					if (uMask&(1<<7)) pLine8[7] = t2 >> (3*8); 
					pLine8+=8;
				}
			}  else
			{
				pSrc8+=8;
				pLine8+=8;
			}

			nTiles--;
		}
	}
}


static void _RenderBGData_O(Uint8 *pLine8, Uint8 *pSrc8, SNMaskT *pBGMask, Uint32 uScrollX, Int32 nTiles)
{
	memset(pLine8, 0, 256);
	_RenderBGData(pLine8, pSrc8, pBGMask, uScrollX, nTiles);
}


#endif



static void _RenderBG8(Uint8 *pLine8, SNMaskT *pLine, SNMaskT *pBGPlane, SNMaskT *pWindow, Uint32 uBitDepth, SNMaskT *pAddSubMask, Uint8 bAddSubMask, SNMaskT *pBGPri, SNMaskT *pExtraMask, Uint32 uPriority, Bool &bRendered, Uint32 uScrollX)
{
	if (uBitDepth!=0)
	{
		SNMaskT BGMask;		// bits of BG to render
		SNMaskT BGPri;      // bits of BG with high priority

		if (!pBGPri) pBGPri = &BGPri;

		// BGMask = mask & ~window
		// BGMask are the opaque pixels of the background that are not within the clip window
		if (pWindow)
		{
			SNMaskANDN(&BGMask, &pBGPlane[SNPPU_BGPLANE_OPAQUE], pWindow);
		} else
		{
			SNMaskCopy(&BGMask, &pBGPlane[SNPPU_BGPLANE_OPAQUE]);
		}

		if (pExtraMask)
		{
			// hide bg pixels
			SNMaskANDN(&BGMask, &BGMask, pExtraMask);
		}

		// BGPri  = mask  & ~window & bghipriority
		// these are the high priority pixels that need to be rendered
		// they overwrite the lo and hi priority pixels that have already been rendered
		SNMaskAND(pBGPri, &BGMask, &pBGPlane[SNPPU_BGPLANE_PRI]);

		switch (uPriority)
		{
		case 0:
			// lo = 00
			// hi = 01
			SNMaskBool(&pLine[SNPPU_BGPLANE_LAYER0], pBGPri, true);
			break;
		case 1:
			// lo = 00 (masked behind bg3hi unless bg2hi)
			SNMaskANDN(&BGMask, &BGMask, &pLine[SNPPU_BGPLANE_LAYER0]);
			SNMaskOR(&BGMask, &BGMask, pBGPri);

			// lo = 00
			// hi = 01
			SNMaskBool(&pLine[SNPPU_BGPLANE_LAYER0], pBGPri, true);
			break;
		case 2:
			// lo = 10
			SNMaskBool(&pLine[SNPPU_BGPLANE_LAYER0], &BGMask, false);
			SNMaskBool(&pLine[SNPPU_BGPLANE_LAYER1], &BGMask, true);
			// hi = 11
			SNMaskBool(&pLine[SNPPU_BGPLANE_LAYER0], pBGPri, true);
			break;
		case 3:
			{
				SNMaskT temp;
				// temp = bg2hi
				SNMaskAND(&temp, &pLine[SNPPU_BGPLANE_LAYER0], &pLine[SNPPU_BGPLANE_LAYER1]);
				// lo = 00 (masked behind bg2hi unless bg1hi)
				SNMaskANDN(&BGMask, &BGMask, &temp);
				SNMaskOR(&BGMask, &BGMask, pBGPri);
			}

			// lo = 10
			SNMaskBool(&pLine[SNPPU_BGPLANE_LAYER1], &BGMask, true);
			// hi = 11
			SNMaskBool(&pLine[SNPPU_BGPLANE_LAYER0], &BGMask, false);
			SNMaskBool(&pLine[SNPPU_BGPLANE_LAYER0], pBGPri, true);
			break;

		case 4:
			// lo = 00
			// hi = 10
			SNMaskClear(&pLine[SNPPU_BGPLANE_LAYER0]);
			SNMaskCopy(&pLine[SNPPU_BGPLANE_LAYER1], pBGPri);
			break;

		case 5:
			// lo = 01 
			SNMaskANDN(&BGMask, &BGMask, &pLine[SNPPU_BGPLANE_LAYER1]);
			SNMaskOR(&BGMask, &BGMask, pBGPri);

			SNMaskBool(&pLine[SNPPU_BGPLANE_LAYER0], &BGMask, true);

			// hi = 11
			SNMaskBool(&pLine[SNPPU_BGPLANE_LAYER1], &BGMask, false);
			SNMaskBool(&pLine[SNPPU_BGPLANE_LAYER1], pBGPri, true);
			break;

		case 7:
			// lo = 10
			//SNMaskSet(&pLine[SNPPU_BGPLANE_LAYER0]);
			//SNMaskClear(&pLine[SNPPU_BGPLANE_LAYER1]);
			//SNMaskClear(&pLine[SNPPU_BGPLANE_LAYER0]);
			//SNMaskCopy(&pLine[SNPPU_BGPLANE_LAYER1], pBGPri);
//			SNMaskCopy(&pLine[SNPPU_BGPLANE_LAYER0], &BGMask);

	// contra 3 = happy
			SNMaskClear(&pLine[SNPPU_BGPLANE_LAYER0]);
			SNMaskCopy(&pLine[SNPPU_BGPLANE_LAYER1], pBGPri);
	// bgpri = 0 sadv
//			SNMaskCopy(&pLine[SNPPU_BGPLANE_LAYER0], &BGMask);
//			SNMaskClear(&pLine[SNPPU_BGPLANE_LAYER1]);
			break;
		}

		if (pAddSubMask)
		{
			// set or reset bits of AddSubMask based on pixels that were rendered
			SNMaskBool(pAddSubMask, &BGMask, bAddSubMask ? true : false);
		}


		if (!bRendered)
		{
			// render it
			PROF_ENTER("_RenderBGData_O");
			_RenderBGData_O(pLine8, (Uint8 *)pBGPlane, &BGMask, uScrollX, 32);
			PROF_LEAVE("_RenderBGData_O");
			bRendered = TRUE;
		} else
		{
			// render it
			PROF_ENTER("_RenderBGData");
			_RenderBGData(pLine8, (Uint8 *)pBGPlane, &BGMask, uScrollX, 32);
			PROF_LEAVE("_RenderBGData");
		}

	}
}



static Int32 _FetchOBJ(SnesRenderObjT *pObjBase, Uint8 *pObjList, Int32 nObjList, SnesRenderObj8T *pObjLine, Int32 MaxObj8Line, Int32 iLine, Uint32 uBaseAddr, Uint32 uNameSelect, Uint16 *pVram)
{
	Int32 nObjLine = 0;

	while (--nObjList >= 0)
	{
		SnesRenderObjT *pObj;
		Int32 ObjX, ObjY;
		Uint32 uSize;
		Int32 iDeltaX;

        // get pointer to obj
		pObj = pObjBase + pObjList[nObjList];

		uSize = pObj->uSize;

		// get obj position
		ObjX = pObj->uPosX;
		ObjX<<=32-9;
		ObjX>>=32-9;
		ObjY = iLine - pObj->uPosY;
		ObjY^= pObj->uVXOR;
		ObjY&= pObj->uSize - 1;

		SnesPPUTile4T *pTile4;
		Uint32 uTileAddr;
		Uint32 uPlane0, uPlane1, uPlane2, uPlane3;
		Uint32 uTile0, uTile1;
		SnesChrLookupT *pLookup;
		Uint8 *pHFlip;
		Uint32 uTile;

		if (pObj->bHFlip)
		{
			pLookup = &_SnesPPU_PlaneLookup[1];
			pHFlip  = _SnesPPU_HFlipLookup[0];

			ObjX += uSize - 8;
			iDeltaX = -8;
		} else
		{
			pLookup = &_SnesPPU_PlaneLookup[0];
			pHFlip  = _SnesPPU_HFlipLookup[1];
			iDeltaX = 8;
		}

		uTile = pObj->uTile;
		uTile+= (ObjY>>3) << 4;

		// calculate tile address
		uTileAddr = uBaseAddr + uTile * 16;
		if (uTile & 0x100)
		{
			// apply name select
			uTileAddr += uNameSelect;
		}

		// get pointer to tile data (y flipped)
		pTile4 = (SnesPPUTile4T *)(pVram + (uTileAddr & 0x7FFF) + (ObjY & 7));

		while (uSize > 0)
		{
			if (ObjX >= -8 && ObjX < 256)
			{
				// get palette bits
				uTile0  = 
					uTile1  = _SnesPPU_Obj4PalLookup[pObj->uPal];

				// get tile plane bits
				uPlane0 = pTile4->uPlane01[0][0];
				uPlane1 = pTile4->uPlane01[0][1];
				uPlane2 = pTile4->uPlane23[0][0];
				uPlane3 = pTile4->uPlane23[0][1];

				// decode tile
				uTile0 |= (*pLookup)[uPlane0][0] << 0;
				uTile1 |= (*pLookup)[uPlane0][1] << 0;

				uTile0 |= (*pLookup)[uPlane1][0] << 1;
				uTile1 |= (*pLookup)[uPlane1][1] << 1;

				uTile0 |= (*pLookup)[uPlane2][0] << 2;
				uTile1 |= (*pLookup)[uPlane2][1] << 2;

				uTile0 |= (*pLookup)[uPlane3][0] << 3;
				uTile1 |= (*pLookup)[uPlane3][1] << 3;

				// store tile data
				((Uint32 *)pObjLine->uData)[0] = uTile0;
				((Uint32 *)pObjLine->uData)[1] = uTile1;
				pObjLine->uData[SNPPU_BGPLANE_OPAQUE] = pHFlip[uPlane0 | uPlane1 | uPlane2 | uPlane3];

				// store objline
				pObjLine->uPri  = pObj->uPri;
				pObjLine->uPal  = pObj->uPal;
				pObjLine->iPosX = ObjX;
				pObjLine++;
				nObjLine++;
				if (nObjLine >= MaxObj8Line) return nObjLine;
			}

			ObjX += iDeltaX;
			uSize -= 8;

			pTile4++;
		}

		// next obj
//		pObjList++;
//		nObjList--;
	}

	return nObjLine;
}

#define OBJPIXEL(_x)	\
	if (uMask0 & (0x1<<_x)) {pDest8[_x] = pObj->uData[_x]; }

static void _RenderOBJ8(Uint8 *pLine8, SNMaskT *pLine,  const SnesRenderObj8T *pObjLine, Int32 nObjLine,  const SNMaskT *pWindow, SNMaskT *pMask, SNMaskT *pAddSubMask, Bool bAddSubMask)
{
	Uint32 ObjMask[8 + 8];
	SNMaskT *pObjMask;	

	if (nObjLine <= 0 ) return;

	PROF_ENTER("_RenderOBJPlanar");

	// create objmask used for clipping
	ObjMask[ 0] = 0xFFFFFFFF;
	ObjMask[ 1] = 0xFFFFFFFF;
	ObjMask[ 2] = 0xFFFFFFFF;
	ObjMask[ 3] = 0xFFFFFFFF;
	ObjMask[12] = 0xFFFFFFFF;
	ObjMask[13] = 0xFFFFFFFF;
	ObjMask[14] = 0xFFFFFFFF;
	ObjMask[15] = 0xFFFFFFFF;

	// get pointer to objmask
	pObjMask = (SNMaskT *)&ObjMask[4];

	// OBJMask = mask & ~window
	// OBJmask are the pixels that are masked by the window
	if (pWindow)
	{
		SNMaskCopy(pObjMask, pWindow);
	} else
	{
		SNMaskClear(pObjMask);
	}

	if (pMask)
	{
		// mask visible obj pixels
		SNMaskOR(pObjMask, pObjMask, pMask);
	}

	while (--nObjLine >= 0)
	{
		const SnesRenderObj8T *pObj;
		Int32 iPosX;

		pObj = pObjLine + nObjLine;

		iPosX = pObj->iPosX;

		// clip OBJ
		if (iPosX > -8 && iPosX < 256 && pObj->uData[SNPPU_BGPLANE_OPAQUE]!=0)
//		if (pObj->uData[SNPPU_BGPLANE_OPAQUE]!=0)
		{
			SNMaskT *pDest;
			Uint8 *pDest8;
			Uint32 uShift, uInvShift;
			Uint32 uMask0, uMask1;
			Uint32 uObjMask0, uObjMask1;

			pDest8    = pLine8 + iPosX;
			pDest    = (SNMaskT *)&pLine->uMask32[iPosX >> 5];
			pObjMask = (SNMaskT *)&ObjMask[4 + (iPosX >> 5)];

			uShift    = iPosX & 0x1F;
			uInvShift = 32 - uShift;

			// get opacity bits from obj
			if (!uShift)
			{
				uMask0  = pObj->uData[SNPPU_BGPLANE_OPAQUE];
				uMask1  = 0;
			} else
			{
				uMask0  = 
				uMask1  = pObj->uData[SNPPU_BGPLANE_OPAQUE];
				uMask0 <<= uShift;
				uMask1 >>= uInvShift;
			}

			// get objmask window
			uObjMask0 = pObjMask->uMask32[0];
			uObjMask1 = pObjMask->uMask32[1];

			// prevent future lower priority obj from rendering, even if this obj is behind a bg!!
			pObjMask->uMask32[0] |= uMask0;
			pObjMask->uMask32[1] |= uMask1;

			
			// mask obj behind bg
			switch (pObj->uPri)
			{
			case 0:		// masked behind layer 1+2+3
				uObjMask0 |= pDest[SNPPU_BGPLANE_LAYER0].uMask32[0] | pDest[SNPPU_BGPLANE_LAYER1].uMask32[0];
				uObjMask1 |= pDest[SNPPU_BGPLANE_LAYER0].uMask32[1] | pDest[SNPPU_BGPLANE_LAYER1].uMask32[1];
				break;
			case 1:		// masked behind layer 2+3
				uObjMask0 |= pDest[SNPPU_BGPLANE_LAYER1].uMask32[0];
				uObjMask1 |= pDest[SNPPU_BGPLANE_LAYER1].uMask32[1];
				break;
			case 2:		// masked behind layer 3 only
				uObjMask0 |= pDest[SNPPU_BGPLANE_LAYER0].uMask32[0] & pDest[SNPPU_BGPLANE_LAYER1].uMask32[0];
				uObjMask1 |= pDest[SNPPU_BGPLANE_LAYER0].uMask32[1] & pDest[SNPPU_BGPLANE_LAYER1].uMask32[1];
				break;
			case 3:		// in front of all layers
				break;
			}
			
			// mask obj
			uMask0 &= ~uObjMask0;
			uMask1 &= ~uObjMask1;

			// prevent future lower priority obj from rendering if an obj pixel has been rendered
			//pObjMask->uMask32[0] |= uMask0;
			//pObjMask->uMask32[1] |= uMask1;

			if ((bAddSubMask&1) && ((pObj->uPal|bAddSubMask)&0x4))
			{
				pAddSubMask->uMask32[(iPosX >> 5) + 0] |= uMask0;
				pAddSubMask->uMask32[(iPosX >> 5) + 1] |= uMask1;
			} else
			{
				pAddSubMask->uMask32[(iPosX >> 5) + 0] &= ~uMask0;
				pAddSubMask->uMask32[(iPosX >> 5) + 1] &= ~uMask1;
			}

			uMask0>>=uShift;
			uMask1<<=uInvShift;
			uMask0|=uMask1;

			OBJPIXEL(0);
			OBJPIXEL(1);
			OBJPIXEL(2);
			OBJPIXEL(3);
			OBJPIXEL(4);
			OBJPIXEL(5);
			OBJPIXEL(6);
			OBJPIXEL(7);
		}
	}

	PROF_LEAVE("_RenderOBJPlanar");
}





static void _ClearLinePlanar(SNMaskT *pPlanes, Int32 nPlanes)
{
	Int32 iPlane;
	for (iPlane=0; iPlane < nPlanes; iPlane++)
	{
		SNMaskClear(&pPlanes[iPlane]);
	}
}



void SnesPPURender::RenderLine8(Int32 iLine, SnesRender8pInfoT *pRenderInfo)
{
	SNMaskT BG3Pri;
	Bool bBG3Pri;
	SnesBGInfoT	BGInfo[4];
	SnesRenderObj8T ObjLine[SNPPU_MAXOBJCHR];
	Int32 nObjLine;
	const SnesPPURegsT *pRegs = m_pPPU->GetRegs();
	Uint8 tm = pRegs->tm & _tm;
	Uint8 tmw = pRegs->tmw & _tmw;
	Uint32 cgadsub =  (pRegs->cgadsub & 0x3F);
	Uint8 ts = (pRegs->ts & _ts);
	Uint8 tsw = pRegs->tsw & _tsw;
	Bool bRendered;

	SNMaskT *pMain = pRenderInfo->Main;
	SNMaskT *pSub = pRenderInfo->Sub;
	SNMaskT *pBGWindow = pRenderInfo->BGWindow; 
    SNMaskT *pMainAddSubMask = &pRenderInfo->MainAddSubMask; 
	SNMaskT *pSubAddSubMask = &pRenderInfo->SubAddSubMask; 
    Uint8  *pMain8 = pRenderInfo->BlendInfo.uMain8;
    Uint8  *pSub8 = pRenderInfo->BlendInfo.uSub8;

	PROF_ENTER("DecodeBGInfo");
	DecodeBGInfo(BGInfo);
	PROF_LEAVE("DecodeBGInfo");

	// fetch obj chr for visible objs
	PROF_ENTER("FetchOBJ");
	nObjLine = _FetchOBJ(m_Objs, m_ObjLine[iLine], m_nObjLine[iLine], ObjLine, SNPPU_MAXOBJCHR, iLine, (pRegs->obsel & 3) << 13, ((pRegs->obsel>>3) & 3) << 12, m_pPPU->GetVramPtr(0));
	PROF_LEAVE("FetchOBJ");

	if ((pRegs->bgmode&7)!=7)
	{
		Int32 iBG;
		Uint8 uBGFlags[4];
		Uint16 *pOffset = NULL;
		Uint32 uOffsetOR = 0;

		if ((pRegs->bgmode&7)==2 || (pRegs->bgmode&7)==4)
		{
			pOffset = pRenderInfo->BGOffset;

			// fetch offsets
			uOffsetOR  = FetchOffset(&BGInfo[2], pOffset, iLine, pRenderInfo->uBGVramAddr[2], (pRegs->bgmode&7)==2 ? TRUE : FALSE);
		}

		for (iBG=0; iBG <= 3; iBG++)
		{
			// is offset enabled for this BG layer?
			if (uOffsetOR & (0x2000 << iBG))
			{
				// fetch BGline with offset
				PROF_ENTER("FetchBGOffset");
				uBGFlags[iBG] = FetchBGOffset(&BGInfo[iBG], pRenderInfo->Tiles[iBG], 33, iLine, pOffset, (0x2000 << iBG), ((pRegs->bgmode&7)==4 ? TRUE : FALSE));
				PROF_LEAVE("FetchBGOffset");

				// invalidate cache
				pRenderInfo->uBGVramAddr[iBG] = 0xFFFFFFFF;
			} else
			{
				// fetch line without offset
				PROF_ENTER("FetchBG");
				uBGFlags[iBG] = FetchBG(&BGInfo[iBG], pRenderInfo->Tiles[iBG], 33, iLine, pRenderInfo->uBGVramAddr[iBG]);
				PROF_LEAVE("FetchBG");
			}
		}

		PROF_ENTER("BGCHR");
		for (iBG=0; iBG <= 3; iBG++)
		{
			if (uBGFlags[iBG] & SNPPU_BGFLAGS_FETCHCHR)
			{
				Uint8 TempMask[2][SNPPU_BGPLANE_SIZE];

				// fetch bg tile data 
				#if SNPPURENDER_CHR64
				_FetchCHR_64((Uint8 *)pRenderInfo->BGPlanes[iBG], m_pPPU, &BGInfo[iBG], pRenderInfo->Tiles[iBG], 33, iLine, TempMask[0], (uBGFlags[iBG]&SNPPU_BGFLAGS_OFFSET));
				#else
				_FetchCHR((Uint8 *)pRenderInfo->BGPlanes[iBG], m_pPPU, &BGInfo[iBG], pRenderInfo->Tiles[iBG], 33, iLine, TempMask[0], (uBGFlags[iBG]&SNPPU_BGFLAGS_OFFSET));
				#endif

				// shift mask based on h-scroll of BG
				SNMaskSHL(&pRenderInfo->BGPlanes[iBG][SNPPU_BGPLANE_OPAQUE], TempMask[0], (BGInfo[iBG].uScrollX & 7));
				SNMaskSHL(&pRenderInfo->BGPlanes[iBG][SNPPU_BGPLANE_PRI], TempMask[1], (BGInfo[iBG].uScrollX & 7));

				if (BGInfo[iBG].uMosaic > 0)
				{
					_MosaicBGPlanar((Uint8 *)&pRenderInfo->BGPlanes[iBG][SNPPU_BGPLANE_OPAQUE], 256, BGInfo[iBG].uMosaic + 1);
					_MosaicBGPlanar((Uint8 *)&pRenderInfo->BGPlanes[iBG][SNPPU_BGPLANE_PRI], 256, BGInfo[iBG].uMosaic + 1);
				}
			}
		}
		PROF_LEAVE("BGCHR");
	} else
	{
		// mode 7
		PROF_ENTER("BGMODE7");
		_FetchMode7((Uint8 *)pRenderInfo->BGPlanes[0], m_pPPU, iLine, &pRenderInfo->BGPlanes[0][SNPPU_BGPLANE_PRI], &pRenderInfo->BGPlanes[0][SNPPU_BGPLANE_OPAQUE]);
		PROF_LEAVE("BGMODE7");

		// only draw BG 1
		if (tm & 0x3)
		{
			tm&=~0xF;
			tm|=SNESPPU_MASK_BG1;
		}

		if (ts & 0x3)
		{
			ts&=~0xF;
			ts|=SNESPPU_MASK_BG1;
		}
	}

	PROF_ENTER("RenderBG");

	if (cgadsub & 0x20)
	{
		SNMaskSet(pMainAddSubMask);
	} else
	{
		SNMaskClear(pMainAddSubMask);
	}

	bBG3Pri = (pRegs->bgmode&8) && (tm & SNESPPU_MASK_BG3) && ((pRegs->bgmode&7)==1);

	// clear main screen 
	SNMaskClear(&pMain[SNPPU_BGPLANE_PLANE7]);
	SNMaskClear(&pMain[SNPPU_BGPLANE_LAYER0]);
	SNMaskClear(&pMain[SNPPU_BGPLANE_LAYER1]);
	bRendered=FALSE;

	// render bg layers to main screen
	if (tm & SNESPPU_MASK_BG4)
		_RenderBG8(pMain8, pMain, pRenderInfo->BGPlanes[3], (tmw&SNESPPU_MASK_BG4) ? &pBGWindow[3] : NULL, BGInfo[3].uBitDepth,  pMainAddSubMask, cgadsub & SNESPPU_MASK_BG4, NULL, NULL, BGInfo[3].Priority, bRendered, BGInfo[3].uScrollX );
	if (tm & SNESPPU_MASK_BG3)
		_RenderBG8(pMain8, pMain, pRenderInfo->BGPlanes[2], (tmw&SNESPPU_MASK_BG3) ? &pBGWindow[2] : NULL, BGInfo[2].uBitDepth,  pMainAddSubMask, cgadsub & SNESPPU_MASK_BG3, &BG3Pri, NULL, BGInfo[2].Priority, bRendered, BGInfo[2].uScrollX);
	if (tm & SNESPPU_MASK_BG2)
		_RenderBG8(pMain8, pMain, pRenderInfo->BGPlanes[1], (tmw&SNESPPU_MASK_BG2) ? &pBGWindow[1] : NULL, BGInfo[1].uBitDepth,  pMainAddSubMask, cgadsub & SNESPPU_MASK_BG2, NULL, bBG3Pri ? &BG3Pri : NULL, BGInfo[1].Priority, bRendered, BGInfo[1].uScrollX);
	if (tm & SNESPPU_MASK_BG1)
		_RenderBG8(pMain8, pMain, pRenderInfo->BGPlanes[0], (tmw&SNESPPU_MASK_BG1) ? &pBGWindow[0] : NULL, BGInfo[0].uBitDepth,  pMainAddSubMask, cgadsub & SNESPPU_MASK_BG1, NULL, bBG3Pri ? &BG3Pri : NULL, BGInfo[0].Priority, bRendered, BGInfo[0].uScrollX);
	if (!bRendered)
		_ClearLinePlanar((SNMaskT *)pMain8, 8);
	if (tm & SNESPPU_MASK_OBJ)
	{
		_RenderOBJ8(pMain8, pMain, ObjLine, nObjLine,  (tmw&SNESPPU_MASK_OBJ) ? &pBGWindow[4] : NULL, bBG3Pri ? &BG3Pri : NULL, 
			pMainAddSubMask, (cgadsub & 0x10) ? 1 : 0);
	}

	if (pRegs->cgwsel & 0x02)
	{
		// coloradd/sub subscreen
		SNMaskClear(pSubAddSubMask);		// the bg of the subscreen is not 1/2'd
	} else
	{
		// coloradd/sub fixed color only
		ts = 0;
		SNMaskSet(pSubAddSubMask);           //all pixels are 1/2!
	}

	// do fancy BG3 priority stuff?
	bBG3Pri = (pRegs->bgmode&8) && (ts & SNESPPU_MASK_BG3) && ((pRegs->bgmode&7)==1);;

	// clear Sub screen 
	SNMaskClear(&pSub[SNPPU_BGPLANE_PLANE7]);
	SNMaskClear(&pSub[SNPPU_BGPLANE_LAYER0]);
	SNMaskClear(&pSub[SNPPU_BGPLANE_LAYER1]);
	bRendered = FALSE;

	// render bg layers to sub screen
	if (ts & SNESPPU_MASK_BG4)
		_RenderBG8(pSub8, pSub, pRenderInfo->BGPlanes[3], (tsw&SNESPPU_MASK_BG4) ? &pBGWindow[3] : NULL, BGInfo[3].uBitDepth, pSubAddSubMask, 1, NULL, NULL, BGInfo[3].Priority, bRendered, BGInfo[3].uScrollX);
	if (ts & SNESPPU_MASK_BG3)
		_RenderBG8(pSub8, pSub, pRenderInfo->BGPlanes[2], (tsw&SNESPPU_MASK_BG3) ? &pBGWindow[2] : NULL, BGInfo[2].uBitDepth, pSubAddSubMask, 1, &BG3Pri, NULL, BGInfo[2].Priority, bRendered, BGInfo[2].uScrollX);
	if (ts & SNESPPU_MASK_BG2)
		_RenderBG8(pSub8, pSub, pRenderInfo->BGPlanes[1], (tsw&SNESPPU_MASK_BG2) ? &pBGWindow[1] : NULL, BGInfo[1].uBitDepth, pSubAddSubMask, 1, NULL, bBG3Pri ? &BG3Pri : NULL, BGInfo[1].Priority, bRendered, BGInfo[1].uScrollX);
	if (ts & SNESPPU_MASK_BG1)
		_RenderBG8(pSub8, pSub, pRenderInfo->BGPlanes[0], (tsw&SNESPPU_MASK_BG1) ? &pBGWindow[0] : NULL, BGInfo[0].uBitDepth, pSubAddSubMask, 1, NULL, bBG3Pri ? &BG3Pri : NULL, BGInfo[0].Priority, bRendered, BGInfo[0].uScrollX);
	if (!bRendered)
		_ClearLinePlanar((SNMaskT *)pSub8, 8);
	if (ts & SNESPPU_MASK_OBJ)
	{
		_RenderOBJ8(pSub8, pSub, ObjLine, nObjLine,  (tsw&SNESPPU_MASK_OBJ) ? &pBGWindow[4] : NULL, bBG3Pri ? &BG3Pri : NULL, 
			pSubAddSubMask, 4|1);
	}

	PROF_LEAVE("RenderBG");
}


void RenderLine8Mode7(Int32 iLine,  SnesRender8pInfoT *pRenderInfo)
{

}










static void _FetchMode7_Repeat(Uint8 *pLine, Int32 nPixels, Uint8 *pVram, Int32 x, Int32 y, Int32 dx, Int32 dy)
{
	Int32 x2,y2;
	Uint32 uTileAddr;
	Uint32 uChrAddr;
	Uint8 uChrData;

	while (nPixels >0)
	{
		// do matrix multiply
		x2 = x >> 8;
		y2 = y >> 8;

		// increment x/y
		x+=dx;
		y+=dy;

		// wrap 
		x2&=0x3FF;
		y2&=0x3FF;

		// get tile address
		uTileAddr = ((y2>>3)<<7) | (x2>>3);
		uTileAddr &= 0x3FFF;

		// fetch chr address
		uChrAddr = pVram[uTileAddr * 2 + 0];

		// offset into pixel of tile
		uChrAddr <<=6;
		uChrAddr += (x2 & 7);
		uChrAddr += (y2 & 7) << 3;

		// fetch chr data
		uChrData = pVram[uChrAddr * 2 + 1];

		nPixels--;
		pLine[0] = uChrData;
		pLine++;
	}
}

static void _FetchMode7_Clamp(Uint8 *pLine, Int32 nPixels, Uint8 *pVram, Int32 x, Int32 y, Int32 dx, Int32 dy)
{
	Int32 x2,y2;
	Uint32 uTileAddr;
	Uint32 uChrAddr;
	Uint8 uChrData;

	while (nPixels >0)
	{
		// do matrix multiply
		x2 = x >> 8;
		y2 = y >> 8;

		// increment x/y
		x+=dx;
		y+=dy;

		// get tile address
		uTileAddr = ((y2>>3)<<7) | (x2>>3);
		uTileAddr &= 0x3FFF;

		// fetch chr address
		uChrAddr = pVram[uTileAddr * 2 + 0];

		if ((x2|y2) >> 10)	uChrAddr = 0;

		// offset into pixel of tile
		uChrAddr <<=6;
		uChrAddr += (x2 & 7);
		uChrAddr += (y2 & 7) << 3;

		// fetch chr data
		uChrData = pVram[uChrAddr * 2 + 1];

		nPixels--;
		pLine[0] = uChrData;
		pLine++;
	}
}

static void _FetchMode7_Black(Uint8 *pLine, Int32 nPixels, Uint8 *pVram, Int32 x, Int32 y, Int32 dx, Int32 dy)
{
	Int32 x2,y2;
	Uint32 uTileAddr;
	Uint32 uChrAddr;
	Uint8 uChrData;

	while (nPixels >0)
	{
		// do matrix multiply
		x2 = x >> 8;
		y2 = y >> 8;

		// increment x/y
		x+=dx;
		y+=dy;

		// get tile address
		uTileAddr = ((y2>>3)<<7) | (x2>>3);
		uTileAddr &= 0x3FFF;

		// fetch chr address
		uChrAddr = pVram[uTileAddr * 2 + 0];

		// offset into pixel of tile
		uChrAddr <<=6;
		uChrAddr += (x2 & 7);
		uChrAddr += (y2 & 7) << 3;

		// fetch chr data
		uChrData = pVram[uChrAddr * 2 + 1];

		if ((x2|y2) >> 10)	uChrData = 0;

		nPixels--;
		pLine[0] = uChrData;
		pLine++;
	}
}

#if 0
static void _FetchMode7Priority(Uint8 *pPriority, Uint8 *pLine, Int32 nPixels)
{
	Uint8 uPriority =0;

	while (nPixels > 0)
	{
		Uint8 uData;
		uData = pLine[0];

		uPriority >>= 1;
		uPriority  |= uData & 0x80;

		if (!(nPixels & 7))
		{
			*pPriority++ = uPriority;
			uPriority = 0;
		}

		pLine[0] = uData & 0x7F;

		pLine++;
		nPixels--;
	}
}
#else

static void _FetchMode7Priority(Uint8 *pPriority, Uint8 *pLine, Int32 nPixels)
{
	Uint64 uMask64;
	Uint64 *pLine64 = (Uint64 *)pLine;

	uMask64 = 0x8080808080808080;

	while (nPixels > 0)
	{
		Uint64 uData64;
		Uint64 uPriority = 0;
		Uint64 uPri64;

		// fetch 8 pixels
		uData64 = pLine64[0];

		// get priority bits
		uPri64 = uData64 & uMask64;

		uPriority|= (uPri64 >> ( 0x00 + 7)) << 0;
		uPriority|= (uPri64 >> ( 0x08 + 7)) << 1;
		uPriority|= (uPri64 >> ( 0x10 + 7)) << 2;
		uPriority|= (uPri64 >> ( 0x18 + 7)) << 3;
		uPriority|= (uPri64 >> ( 0x20 + 7)) << 4;
		uPriority|= (uPri64 >> ( 0x28 + 7)) << 5;
		uPriority|= (uPri64 >> ( 0x30 + 7)) << 6;
		uPriority|= (uPri64 >> ( 0x38 + 7)) << 7;

		// remove priority bits
		uData64 |= uMask64;
		uData64 ^= uMask64;

		// store priority
		pPriority[0] = (Uint8)uPriority;
		pPriority++;

		// store line data
		pLine64[0] = uData64;
		pLine64++;

		nPixels-=8;
	}
}

#endif

#if CODE_PLATFORM == CODE_PS2
static void _FetchMode7Opaque(Uint8 *pMask, Uint8 *pLine, Int32 nPixels)
{
	Uint64 uMask64;
	Uint64 *pLine64 = (Uint64 *)pLine;
	Uint64 uZero;
	Uint64 uOne;

	uMask64 = 0x8080808080808080;
	uZero	= 0x0000000000000000;
	uOne    = 0xFFFFFFFFFFFFFFFF;

	while (nPixels > 0)
	{
		Uint64 uData64;
		Uint64 uOpaque = 0;

		// fetch 8 pixels
		uData64 = pLine64[0];
		pLine64++;

		__asm__ (
			"pceqb      %0,%0,$0        \n"   // %0 = FF or 00
			: "+r" (uData64)
			);    

		if (uData64==uZero)
		{
			pMask[0] = 0xFF;
			pMask++;
		} else
		if (uData64==uOne)
		{
			pMask[0] = 0x00;
			pMask++;
		} else
		{
			// get priority bits
			uData64 = uData64 & uMask64;

			uOpaque|= (uData64 >> ( 0x00 + 7)) << 0;
			uOpaque|= (uData64 >> ( 0x08 + 7)) << 1;
			uOpaque|= (uData64 >> ( 0x10 + 7)) << 2;
			uOpaque|= (uData64 >> ( 0x18 + 7)) << 3;
			uOpaque|= (uData64 >> ( 0x20 + 7)) << 4;
			uOpaque|= (uData64 >> ( 0x28 + 7)) << 5;
			uOpaque|= (uData64 >> ( 0x30 + 7)) << 6;
			uOpaque|= (uData64 >> ( 0x38 + 7)) << 7;

			// store priority
			pMask[0] = (Uint8)(uOpaque^0xFF);
			pMask++;
		}
		nPixels-=8;
	}
}
#else

static void _FetchMode7Opaque(Uint8 *pMask, Uint8 *pLine, Int32 nPixels)
{
	Uint64 *pLine64 = (Uint64 *)pLine;

	while (nPixels > 0)
	{
		Uint64 uData64;
		Uint64 uOpaque = 0;

		// fetch 8 pixels
		uData64 = pLine64[0];
		pLine64++;

		// on a mips processor this produces several movn instructions
		uOpaque|= ((uData64 >> 0x00) & 0xFF) ? 1 : 0;
		uOpaque|= ((uData64 >> 0x08) & 0xFF) ? 2 : 0;
		uOpaque|= ((uData64 >> 0x10) & 0xFF) ? 4 : 0;
		uOpaque|= ((uData64 >> 0x18) & 0xFF) ? 8 : 0;
		uOpaque|= ((uData64 >> 0x20) & 0xFF) ? 16 : 0;
		uOpaque|= ((uData64 >> 0x28) & 0xFF) ? 32 : 0;
		uOpaque|= ((uData64 >> 0x30) & 0xFF) ? 64 : 0;
		uOpaque|= ((uData64 >> 0x38) & 0xFF) ? 128 : 0;


		// store priority
		pMask[0] = (Uint8)uOpaque;
		pMask++;
		nPixels-=8;
	}
}
#endif

static void _FetchMode7(Uint8 *pLine, SnesPPU *pPPU, Int32 iLine, SNMaskT *pPriority, SNMaskT *pOpaque)
{
	const SnesPPURegsT *pRegs = pPPU->GetRegs();
	Int32 nPixels;
	Int32 x1, y1,x,y;
	Int32 m7a,m7b,m7c,m7d,m7x,m7y;
	Uint8 *pVram;
	nPixels=256;

	pVram = (Uint8 *)pPPU->GetVramPtr(0);

	// get x/y scroll position
	x1 = pRegs->bg1hofs.w;
	y1 = pRegs->bg1vofs.w;

	// sign extend to 13-bit
	x1<<= 32- 13; x1>>= 32- 13;
	y1<<= 32- 13; y1>>= 32- 13;

	// advance scrolly to current line
	y1 += iLine;

	// fetch matrix parameters
	m7a = (Int16)pRegs->m7a.w;
	m7b = (Int16)pRegs->m7b.w;
	m7c = (Int16)pRegs->m7c.w;
	m7d = (Int16)pRegs->m7d.w;
	m7x = pRegs->m7x.w;
	m7y = pRegs->m7y.w;

	// sign extend to 13-bit
	m7x<<= 32- 13; m7x>>= 32- 13;
	m7y<<= 32- 13; m7y>>= 32- 13;

	// do matrix multiply for left pixel of line
	x = (x1 - m7x) * m7a + (y1 - m7y) * m7b + (m7x << 8);
	y = (x1 - m7x) * m7c + (y1 - m7y) * m7d + (m7y << 8);


	if (pRegs->m7sel & 0x1)
	{
		x +=  256 * m7a;  // translate to right of screen
		y +=  256 * m7c;
		m7a = -m7a;
		m7c = -m7c;
	}
	
	if (pRegs->m7sel & 0x2)
	{
		x +=  262 * m7b;  // translate to bottom of screen
		y +=  262 * m7d;
		m7b = -m7b;
		m7d = -m7d;
	} 

	switch (pRegs->m7sel>>6)
	{
	case 0: // screen repetition if outside of screen area
		_FetchMode7_Repeat(pLine, 256, pVram, x, y, m7a, m7c);
		break;
	case 3: // character 0x00 repetition if outside of screen area
		_FetchMode7_Clamp(pLine, 256, pVram, x, y, m7a, m7c);
		break;
	default:
	case 2: // outside of the screen area is the back drop screen in single color
		_FetchMode7_Black(pLine, 256, pVram, x, y, m7a, m7c);
		break;
	}

	if (pPriority)
	{
		if (pRegs->setini & 0x40)
		{
			PROF_ENTER("_FetchMode7Priority");
			_FetchMode7Priority(pPriority->uMask8, pLine, 256);
			PROF_LEAVE("_FetchMode7Priority");
		} else
		{
//			SNMaskClear(pPriority);
			SNMaskSet(pPriority);

		}
	}

	// no transparency?
	_FetchMode7Opaque(pOpaque->uMask8, pLine, 256);
}

