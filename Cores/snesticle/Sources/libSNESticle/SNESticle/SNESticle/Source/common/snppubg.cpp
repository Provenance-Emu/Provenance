

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "types.h"
#include "console.h"
#include "snppu.h"
#include "snppurender.h"
#include "rendersurface.h"
#include "snmask.h"
#include "snmaskop.h"
#include "prof.h"



static Uint32 _SnesPPU_ScrSizeOffset[4][4]=
{
	{0x0000, 0x0000, 0x0000, 0x0000},
	{0x0000, 0x0400, 0x0000, 0x0400},
	{0x0000, 0x0000, 0x0400, 0x0400},
	{0x0000, 0x0400, 0x0800, 0x0C00}
};

static Uint8 _SNPPUBg_Tile16Pos[4][4] = 
{
	{ 0,  1}, // normal
	{ 1,  0}, // flipx
	{16, 17}, // flipy
	{17, 16}, // flipxy
};

// BG Fetch 

static Uint32 _FetchOffset(Uint16 uAddr, Uint16 *pOffset, Int32 nTiles, SnesPPUScreenT **ppScreen)
{
	Uint16 *pScrData;
	Uint32 uOffsetOR = 0;

	PROF_ENTER("_FetchOffset");

	// get pointer to screen data
	pScrData  =  (Uint16 *)ppScreen[(uAddr >> 10) & 3];

	// store 0 in left offset
	pOffset[0] = 0;
	pOffset[1] = 0;
	pOffset +=2;
	nTiles--;

	while (nTiles > 0)
	{
		Uint16 uScrData;

		// fetch screen data
		uScrData = pScrData[uAddr & 0x03FF];
		uAddr++;

		// have we wrapped horizontally?
		if (!(uAddr&0x1F))
		{
			// wrap address
			uAddr-=(1<< 5);	// move back up
			uAddr^=(1<<10); // switch screens

			// get pointer to screen data
			pScrData  =  (Uint16 *)ppScreen[(uAddr >> 10) & 3];
		}

		uOffsetOR |= uScrData;

		// store offset
		pOffset[0] = uScrData;
		pOffset+=2;
		nTiles--;
	}

	PROF_LEAVE("_FetchOffset");

	return uOffsetOR;
}


static void _FetchBG8x8(Uint32 uAddr, SnesRenderTileT *pTile, Int32 nTiles, SnesPPUScreenT **ppScreen)
{
	//  each screen is 32x32
	// vram address is: ssyyyyyxxxxx
	//   ss = screen # 00,01,10,11
	//   yyyyy is tile vert row
	//   xxxxx is tile horiz column

	Uint16 *pScrData;

    PROF_ENTER("_FetchBG8x8");

	// get pointer to screen data
	pScrData  =  (Uint16 *)ppScreen[(uAddr >> 10) & 3];

	while (nTiles > 0)
	{
		Uint16 uScrData;

		// fetch screen data
		uScrData = pScrData[uAddr & 0x03FF];
		uAddr++;

		// have we wrapped horizontally?
		if (!(uAddr&0x1F))
		{
			// wrap address
			uAddr-=(1<< 5);	// move back up
			uAddr^=(1<<10); // switch screens

			// get pointer to screen data
			pScrData  =  (Uint16 *)ppScreen[(uAddr >> 10) & 3];
		}

		// screen data is of format: YX?cccNNNNNNNNNN
		pTile->uFlip = (uScrData >> 14) & 3;
		pTile->uPal  = (uScrData >> 10) & 0xF;
		pTile->uTile = (uScrData >>  0) & 0x3FF;
		pTile->uOffsetY = 0;
		pTile++;

		nTiles--;
	}

    PROF_LEAVE("_FetchBG8x8");
}


static void _FetchBG16x16(Uint32 uAddr, SnesRenderTileT *pTile, Int32 nTiles, SnesPPUScreenT **ppScreen, Uint32 uFlipXOR)
{
	//  each screen is 32x32
	// vram address is: ssyyyyyxxxxx
	//   ss = screen # 00,01,10,11
	//   yyyyy is tile vert row
	//   xxxxx is tile horiz column

	Uint16 *pScrData;

	PROF_ENTER("_FetchBG16x16");

	// get pointer to screen data
	pScrData  =  (Uint16 *)ppScreen[(uAddr >> 10) & 3];

	while (nTiles > 0)
	{
		Uint16 uScrData;
		Uint32 uTile16;
		Uint32 uFlip;
		Uint32 uPal;
		Uint8 *pOffset;

		// fetch screen data
		uScrData = pScrData[uAddr & 0x03FF];
		uAddr++;

		// have we wrapped horizontally?
		if (!(uAddr&0x1F))
		{
			// wrap address
			uAddr-=(1<< 5);	// move back up
			uAddr^=(1<<10); // switch screens

			// get pointer to screen data
			pScrData  =  (Uint16 *)ppScreen[(uAddr >> 10) & 3];
		}

		// extract tile 
		// screen data is of format: YX?cccNNNNNNNNNN
		uTile16 = ((uScrData >>  0) & 0x3FF);
		uFlip	= (uScrData >> 14) & 3;
		uPal	= (uScrData >> 10) & 0xF;

		pOffset = _SNPPUBg_Tile16Pos[uFlip ^ uFlipXOR];

		// write first 8x8 tile
		pTile->uTile = uTile16 + pOffset[0];
		pTile->uFlip = uFlip;
		pTile->uPal  = uPal;
		pTile->uOffsetY = 0;
		pTile++;
		nTiles--;

		if (!(uFlipXOR&1))
		{
			// write second 8x8 tile
			pTile->uTile = uTile16 + pOffset[1];
			pTile->uFlip = uFlip;
			pTile->uPal  = uPal;
			pTile->uOffsetY = 0;
			pTile++;
			nTiles--;
		}

		// remove x-flip
		uFlipXOR&=~1;
	}

	PROF_LEAVE("_FetchBG16x16");
}



static void _FetchBG8x8Offset(Uint32 uScrollX, Uint32 uScrollY, Int32 iLine, SnesRenderTileT *pTile, Int32 nTiles, SnesPPUScreenT **ppScreen, Uint16 *pOffset, Uint32 uOffsetMask)
{
	//  each screen is 32x32
	// vram address is: ssyyyyyxxxxx
	//   ss = screen # 00,01,10,11
	//   yyyyy is tile vert row
	//   xxxxx is tile horiz column

	Uint16 *pScrData;
	Uint32 uAddr;
	Uint32 uTileX, uTileY;
	Uint32 uX = 0;

	PROF_ENTER("_FetchBG8x8Offset");

	while (nTiles > 0)
	{
		Uint16 uScrData;
		Uint32 uTileScrollX, uTileScrollY;

		if (pOffset[0] & uOffsetMask)
		{
			uTileScrollX = pOffset[0] & 0x7FF;
		} else
		{
			uTileScrollX = uScrollX;
		}

		if (pOffset[1] & uOffsetMask)
		{
			uTileScrollY = pOffset[1] & 0x7FF;
		} else
		{
			uTileScrollY = uScrollY;
		}

		uTileScrollX += uX;
		uTileScrollY += iLine;

		// calculate tile x/y
		uTileX = (uTileScrollX >> 3) & 63;
		uTileY = (uTileScrollY >> 3) & 63;

		// calculate vram tile address (ssyyyyyxxxxx)
		uAddr = (uTileX & 0x1F) << 0 ;
		uAddr|= (uTileY & 0x1F) << 5 ;
		uAddr|= (uTileX >>   5) << 10;
		uAddr|= (uTileY >>   5) << 11;

		// get pointer to screen data
		pScrData  =  (Uint16 *)ppScreen[(uAddr >> 10) & 3];

		// fetch screen data
		uScrData = pScrData[uAddr & 0x03FF];

		// screen data is of format: YX?cccNNNNNNNNNN
		pTile->uFlip = (uScrData >> 14) & 3;
		pTile->uPal  = (uScrData >> 10) & 0xF;
		pTile->uTile = (uScrData >>  0) & 0x3FF;
		pTile->uOffsetY = uTileScrollY & 7;
		pTile++;
		nTiles--;

		uX+=8;
		pOffset+=2;
	}

	PROF_LEAVE("_FetchBG8x8Offset");
}

static void _FetchBG8x8Offset2(Uint32 uScrollX, Uint32 uScrollY, Int32 iLine, SnesRenderTileT *pTile, Int32 nTiles, SnesPPUScreenT **ppScreen, Uint16 *pOffset, Uint32 uOffsetMask)
{
	//  each screen is 32x32
	// vram address is: ssyyyyyxxxxx
	//   ss = screen # 00,01,10,11
	//   yyyyy is tile vert row
	//   xxxxx is tile horiz column

	Uint16 *pScrData;
	Uint32 uAddr;
	Uint32 uTileX, uTileY;
	Uint32 uX = 0;

	PROF_ENTER("_FetchBG8x8Offset2");

	while (nTiles > 0)
	{
		Uint16 uScrData;
		Uint32 uTileScrollX, uTileScrollY;

		uTileScrollX = uScrollX;
		uTileScrollY = uScrollY;

		if (pOffset[0] & uOffsetMask)
		{
			if (pOffset[0] & 0x8000)
			{
				uTileScrollY = pOffset[0] & 0x7FF;
			} else
			{
				uTileScrollX = pOffset[0] & 0x7FF;
			}
		} 

		uTileScrollX += uX;
		uTileScrollY += iLine;

		// calculate tile x/y
		uTileX = (uTileScrollX >> 3) & 63;
		uTileY = (uTileScrollY >> 3) & 63;

		// calculate vram tile address (ssyyyyyxxxxx)
		uAddr = (uTileX & 0x1F) << 0 ;
		uAddr|= (uTileY & 0x1F) << 5 ;
		uAddr|= (uTileX >>   5) << 10;
		uAddr|= (uTileY >>   5) << 11;

		// get pointer to screen data
		pScrData  =  (Uint16 *)ppScreen[(uAddr >> 10) & 3];

		// fetch screen data
		uScrData = pScrData[uAddr & 0x03FF];

		// screen data is of format: YX?cccNNNNNNNNNN
		pTile->uFlip = (uScrData >> 14) & 3;
		pTile->uPal  = (uScrData >> 10) & 0xF;
		pTile->uTile = (uScrData >>  0) & 0x3FF;
		pTile->uOffsetY = uTileScrollY & 7;
		pTile++;
		nTiles--;

		uX+=8;
		pOffset+=2;
	}

	PROF_LEAVE("_FetchBG8x8Offset2");
}



static void _GetScreenPtrs(SnesPPUScreenT **ppScreen, SnesPPU *pPPU, Uint32 uScrAddr, Uint32 uScrSize)
{
	// get pointers to screens
	ppScreen[0] = (SnesPPUScreenT *)pPPU->GetVramPtr(uScrAddr + _SnesPPU_ScrSizeOffset[uScrSize][0]);
	ppScreen[1] = (SnesPPUScreenT *)pPPU->GetVramPtr(uScrAddr + _SnesPPU_ScrSizeOffset[uScrSize][1]);
	ppScreen[2] = (SnesPPUScreenT *)pPPU->GetVramPtr(uScrAddr + _SnesPPU_ScrSizeOffset[uScrSize][2]);
	ppScreen[3] = (SnesPPUScreenT *)pPPU->GetVramPtr(uScrAddr + _SnesPPU_ScrSizeOffset[uScrSize][3]);
}



Uint32 SnesPPURender::FetchBG(SnesBGInfoT *pBGInfo, struct SnesRenderTileT *pTiles, Int32 nTiles, Int32 iLine, Uint32 &uOldVramAddr)
{
	Uint32 uScrollX, uScrollY;
	Uint32 uTileX, uTileY;
	Uint32 uVramAddr = 0;
	Uint32 uFlipXOR;
	SnesPPUScreenT *pScreen[4];
	Uint32 uResult = 0;

	if (!pBGInfo->uBitDepth) 
	{
		// no fetching
		return uResult;
	}

	if (pBGInfo->uMosaic > 0)
	{
		iLine /= pBGInfo->uMosaic + 1;
		iLine *= pBGInfo->uMosaic + 1;
	}

	uScrollX = pBGInfo->uScrollX;
	uScrollY = pBGInfo->uScrollY + iLine;

	// determine if fine scrollX has changed
	if (((uOldVramAddr>>16)&7)!=(uScrollX&7))
	{
		// force palette fetch
		uResult |= SNPPU_BGFLAGS_FETCHPAL;
	}

	// determine if fine scrollY has changed
	if (((uOldVramAddr>>24)&7)!=(uScrollY&7))
	{
		// force chr fetch
		uResult |= SNPPU_BGFLAGS_FETCHCHR;
	}

	// perform BG line caching
	switch(pBGInfo->uChrSize)
	{
	case 0:
		// fetch tiles (8x8)
		// calculate tile x/y
		uTileX = (uScrollX >> 3) & 63;
		uTileY = (uScrollY >> 3) & 63;

		// calculate vram tile address (ssyyyyyxxxxx)
		uVramAddr = (uTileX & 0x1F) << 0 ;
		uVramAddr|= (uTileY & 0x1F) << 5 ;
		uVramAddr|= (uTileX >>   5) << 10;
		uVramAddr|= (uTileY >>   5) << 11;

		if (uVramAddr != (uOldVramAddr&0xFFFF))
		{
			// get pointers to screens
			_GetScreenPtrs(pScreen, m_pPPU, pBGInfo->uScrAddr, pBGInfo->uScrSize);

			_FetchBG8x8(uVramAddr, pTiles, nTiles, pScreen);

			// force chr+pal fetch
			uResult |= SNPPU_BGFLAGS_FETCHCHR | SNPPU_BGFLAGS_FETCHPAL;
		}
		break;
	case 1:
		// fetch tiles (16x16)
		// calculate tile x/y
		uTileX = (uScrollX >> 4) & 63;
		uTileY = (uScrollY >> 4) & 63;

		// calculate tile flip
		uFlipXOR = 0;
		if (uScrollX & 8) uFlipXOR|=1;
		if (uScrollY & 8) uFlipXOR|=2;

		// calculate vram tile address (ssyyyyyxxxxx)
		uVramAddr = (uTileX & 0x1F) << 0 ;
		uVramAddr|= (uTileY & 0x1F) << 5 ;
		uVramAddr|= (uTileX >>   5) << 10;
		uVramAddr|= (uTileY >>   5) << 11;
		uVramAddr|= uFlipXOR << 12;

		if (uVramAddr != (uOldVramAddr&0xFFFF))
		{
			// get pointers to screens
			_GetScreenPtrs(pScreen, m_pPPU, pBGInfo->uScrAddr, pBGInfo->uScrSize);

			_FetchBG16x16(uVramAddr & 0xFFF, pTiles, nTiles, pScreen, uFlipXOR);

			// force chr+pal fetch
			uResult |= SNPPU_BGFLAGS_FETCHCHR | SNPPU_BGFLAGS_FETCHPAL;
		}
		break;

	default:
		assert(0);
		break;

	}

	uVramAddr|= (uScrollX&7)<<16;
	uVramAddr|= (uScrollY&7)<<24;

	// set vram addr
	uOldVramAddr = uVramAddr;

    return uResult;
}



Uint32 SnesPPURender::FetchBGOffset(SnesBGInfoT *pBGInfo, struct SnesRenderTileT *pTiles, Int32 nTiles, Int32 iLine, Uint16 *pOffset, Uint32 uOffsetMask, Bool bVOffset)
{
	SnesPPUScreenT *pScreen[4];

	if (!pBGInfo->uBitDepth) 
	{
		// no fetching
		return 0;
	}

	// perform BG line caching
	switch(pBGInfo->uChrSize)
	{
	case 0:
		// get pointers to screens
		_GetScreenPtrs(pScreen, m_pPPU, pBGInfo->uScrAddr, pBGInfo->uScrSize);

		if (bVOffset)
		{
			_FetchBG8x8Offset2(pBGInfo->uScrollX, pBGInfo->uScrollY, iLine, pTiles, nTiles, pScreen, pOffset, uOffsetMask);
		} else
		{
			_FetchBG8x8Offset(pBGInfo->uScrollX, pBGInfo->uScrollY, iLine, pTiles, nTiles, pScreen, pOffset, uOffsetMask);		
		}
		break;
	case 1:
		break;

	default:
		assert(0);
		break;

	}

	return SNPPU_BGFLAGS_FETCHCHR | SNPPU_BGFLAGS_FETCHPAL | SNPPU_BGFLAGS_OFFSET;
}


Uint32 SnesPPURender::FetchOffset(SnesBGInfoT *pBGInfo, Uint16 *pOffset, Int32 iLine, Uint32 &uOldVramAddr, Bool bVOffset)
{
	Uint32 uScrollX, uScrollY;
	Uint32 uTileX, uTileY;
	Uint32 uVramAddr = 0;
	SnesPPUScreenT *pScreen[4];
	Uint32 uOffsetOR = 0;

	uScrollX = pBGInfo->uScrollX;
	uScrollY = pBGInfo->uScrollY; // + iLine;

	// fetch tiles (8x8)
	// calculate tile x/y
	uTileX = (uScrollX >> 3) & 63;
	uTileY = (uScrollY >> 3) & 63;

	// calculate vram tile address (ssyyyyyxxxxx)
	uVramAddr = (uTileX & 0x1F) << 0 ;
	uVramAddr|= (uTileY & 0x1F) << 5 ;
	uVramAddr|= (uTileX >>   5) << 10;
	uVramAddr|= (uTileY >>   5) << 11;

	switch (pBGInfo->uScrSize)
	{
	case 0:
	case 1:
		if (uVramAddr != uOldVramAddr)
		{
			// get pointers to screens
			_GetScreenPtrs(pScreen, m_pPPU, pBGInfo->uScrAddr, pBGInfo->uScrSize);

			// fetch h-offsets
			uOffsetOR = _FetchOffset(uVramAddr, pOffset, 32, pScreen);

			if (bVOffset)
			{
				// fetch v-offsets
				uOffsetOR |= _FetchOffset(uVramAddr + 32, pOffset + 1, 32, pScreen);
			}

			uOldVramAddr = uVramAddr;

			pOffset[64] = uOffsetOR;
		} else
		{
			uOffsetOR = pOffset[64];
		}
		break;
		// 16x16 offsets ?
//		break;
	}

	return  uOffsetOR;
}













void _SetBGMask(SNMaskT *pMask, SNMaskT *pWindow, Uint8 uWSel, Uint8 uWLog)
{
	SNMaskT *pWindow1=NULL;
	SNMaskT *pWindow2 = NULL;

	// get pointers to windows
	if (uWSel & 2)
		pWindow1 = (uWSel & 1) ? &pWindow[2] : &pWindow[0];
	if (uWSel & 8)
		pWindow2 = (uWSel & 4) ? &pWindow[3] : &pWindow[1];

	if (pWindow1)
	{
		if (pWindow2)
		{
			// logically combine windows
			switch (uWLog & 3)
			{
			case 0: // OR
				SNMaskOR(pMask, pWindow1, pWindow2);
				break;
			case 1: // AND
				SNMaskAND(pMask, pWindow1, pWindow2);
				break;
			case 2: // XOR
				SNMaskXOR(pMask, pWindow1, pWindow2);
				break;
			case 3: // XNOR
				SNMaskXNOR(pMask, pWindow1, pWindow2);
				break;
			}
		} else
		{
			// use window 1
			SNMaskCopy(pMask, pWindow1);
		}

	} else
	{
		if (pWindow2)
		{
			// use window 1
			SNMaskCopy(pMask, pWindow2);
		} else
		{
			// use no windows
			SNMaskClear(pMask);
		}
	}

//	SNMaskClear(pMask);

}

void SnesPPURender::DecodeBGInfo(SnesBGInfoT *pBGInfo)
{
	const SnesPPURegsT *pRegs = m_pPPU->GetRegs();

	pBGInfo[0].uScrollX = pRegs->bg1hofs.w & 0x7FF;
	pBGInfo[0].uScrollY = pRegs->bg1vofs.w & 0x7FF;
	pBGInfo[0].uScrAddr = (pRegs->bg1sc >> 2) << 10;
	pBGInfo[0].uScrSize =  pRegs->bg1sc & 3;
	pBGInfo[0].uChrAddr =  ((pRegs->bg12nba >> 0) & 0xF) << 12;
	pBGInfo[0].uChrSize =  (pRegs->bgmode >> 4) & 1;
	pBGInfo[0].uMosaic  = (pRegs->mosaic&1) ? (pRegs->mosaic>>4) : 0;

	pBGInfo[1].uScrollX = pRegs->bg2hofs.w & 0x7FF;
	pBGInfo[1].uScrollY = pRegs->bg2vofs.w & 0x7FF;
	pBGInfo[1].uScrAddr = (pRegs->bg2sc >> 2) << 10;
	pBGInfo[1].uScrSize =  pRegs->bg2sc & 3;
	pBGInfo[1].uChrAddr =  ((pRegs->bg12nba >> 4) & 0xF) << 12;
	pBGInfo[1].uChrSize =  (pRegs->bgmode >> 5) & 1;
	pBGInfo[1].uMosaic  = (pRegs->mosaic&2) ? (pRegs->mosaic>>4) : 0;

	pBGInfo[2].uScrollX = pRegs->bg3hofs.w & 0x7FF;
	pBGInfo[2].uScrollY = pRegs->bg3vofs.w & 0x7FF;
	pBGInfo[2].uScrAddr = (pRegs->bg3sc >> 2) << 10;
	pBGInfo[2].uScrSize =  pRegs->bg3sc & 3;
	pBGInfo[2].uChrAddr =  ((pRegs->bg34nba >> 0) & 0xF) << 12;
	pBGInfo[2].uChrSize =  (pRegs->bgmode >> 6) & 1;
	pBGInfo[2].uMosaic  = (pRegs->mosaic&4) ? (pRegs->mosaic>>4) : 0;

	pBGInfo[3].uScrollX = pRegs->bg4hofs.w & 0x7FF;
	pBGInfo[3].uScrollY = pRegs->bg4vofs.w & 0x7FF;
	pBGInfo[3].uScrAddr = (pRegs->bg4sc >> 2) << 10;
	pBGInfo[3].uScrSize =  pRegs->bg4sc & 3;
	pBGInfo[3].uChrAddr =  ((pRegs->bg34nba >> 4) & 0xF) << 12;
	pBGInfo[3].uChrSize =  (pRegs->bgmode >> 7) & 1;
	pBGInfo[3].uMosaic  = (pRegs->mosaic&8) ? (pRegs->mosaic>>4) : 0;

	switch (pRegs->bgmode & 7)
	{
	case 0:
		pBGInfo[0].uBitDepth= 2;
		pBGInfo[1].uBitDepth= 2;
		pBGInfo[2].uBitDepth= 2;
		pBGInfo[3].uBitDepth= 2;
		pBGInfo[0].uPalBase = 0x0;
		pBGInfo[1].uPalBase = 0x1;
		pBGInfo[2].uPalBase = 0x2;
		pBGInfo[3].uPalBase = 0x3;
		pBGInfo[0].Priority  =  3;
		pBGInfo[1].Priority  =  2;
		pBGInfo[2].Priority  =  1;
		pBGInfo[3].Priority  =  0;
		break;

	case 1:
		pBGInfo[0].uBitDepth= 4;
		pBGInfo[1].uBitDepth= 4;
		pBGInfo[2].uBitDepth= 2;
		pBGInfo[3].uBitDepth= 0;
		pBGInfo[0].uPalBase = 0x00;
		pBGInfo[1].uPalBase = 0x00;
		pBGInfo[2].uPalBase = 0x00;
		pBGInfo[3].uPalBase = 0x00;
		pBGInfo[0].Priority  =  3;
		pBGInfo[1].Priority  =  2;
		pBGInfo[2].Priority  =  1;
		pBGInfo[3].Priority  =  0;
		break;

	case 3:
		pBGInfo[0].uBitDepth= 8;
		pBGInfo[1].uBitDepth= 4;
		pBGInfo[2].uBitDepth= 0;
		pBGInfo[3].uBitDepth= 0;
        pBGInfo[0].Priority  =  5;
		pBGInfo[1].Priority  =  4;
		break;

	// these have offset per tile!
	case 2:
        pBGInfo[0].uBitDepth= 4;
		pBGInfo[1].uBitDepth= 4;
		pBGInfo[2].uBitDepth= 0;
		pBGInfo[3].uBitDepth= 0;
		pBGInfo[0].Priority  =  5;
		pBGInfo[1].Priority  =  4;
		break;
		// these have offset per tile!
	case 4:
		pBGInfo[0].uBitDepth= 8;
		pBGInfo[1].uBitDepth= 2;
		pBGInfo[2].uBitDepth= 0;
		pBGInfo[3].uBitDepth= 0;
		pBGInfo[0].Priority  =  5;
		pBGInfo[1].Priority  =  4;
		break;

	case 5: // hi-res
		pBGInfo[0].uBitDepth= 4;
		pBGInfo[1].uBitDepth= 2;
		pBGInfo[2].uBitDepth= 0;
		pBGInfo[3].uBitDepth= 0;
		pBGInfo[0].Priority  =  5;
		pBGInfo[1].Priority  =  4;
		break;

	case 6: // hi-res
		pBGInfo[0].uBitDepth= 8;
		pBGInfo[1].uBitDepth= 0;
		pBGInfo[0].Priority  =  5;
		pBGInfo[1].Priority  =  4;
		break;

	case 7:
		pBGInfo[0].uBitDepth= 8;
		pBGInfo[1].uBitDepth= 0;
		pBGInfo[2].uBitDepth= 0;
		pBGInfo[3].uBitDepth= 0;
		pBGInfo[0].uScrollX = 0;
		pBGInfo[0].uScrollY = 0;
		
		pBGInfo[0].Priority  =  
		pBGInfo[1].Priority  =  
		pBGInfo[2].Priority  =  
		pBGInfo[3].Priority  =  7;
		
		break;

	default:
		pBGInfo[0].uBitDepth= 0;
		pBGInfo[1].uBitDepth= 0;
		pBGInfo[2].uBitDepth= 0;
		pBGInfo[3].uBitDepth= 0;
		break;
	}
}



void SnesPPURender::DecodeWindows(SNMaskT *pWindow, SNMaskT *pBGWindow)
{
    const SnesPPURegsT *pRegs = m_pPPU->GetRegs();

	PROF_ENTER("DecodeWindows");

	// create windows & inverted windows
	// confirmed:
	// window range is INCLUSIVE 
	//    40->41 is two pixels wide
	//    40->40 is one pixel wide
	//    40->39 is 0 pixels wide
	SNMaskRange(&pWindow[0], pRegs->wh0,  pRegs->wh1, false);
	SNMaskRange(&pWindow[1], pRegs->wh2,  pRegs->wh3, false);
	SNMaskNOT(&pWindow[2], &pWindow[0]);
	SNMaskNOT(&pWindow[3], &pWindow[1]);

	// create windows for each BG Layer & color window
	_SetBGMask(&pBGWindow[SNPPU_BGWINDOW_BG1],   pWindow, (pRegs->w12sel >> 0) & 0xF, (pRegs->wbglog >> 0) & 3);
	_SetBGMask(&pBGWindow[SNPPU_BGWINDOW_BG2],   pWindow, (pRegs->w12sel >> 4) & 0xF, (pRegs->wbglog >> 2) & 3);
	_SetBGMask(&pBGWindow[SNPPU_BGWINDOW_BG3],   pWindow, (pRegs->w34sel >> 0) & 0xF, (pRegs->wbglog >> 4) & 3);
	_SetBGMask(&pBGWindow[SNPPU_BGWINDOW_BG4],   pWindow, (pRegs->w34sel >> 4) & 0xF, (pRegs->wbglog >> 6) & 3);
	_SetBGMask(&pBGWindow[SNPPU_BGWINDOW_OBJ],   pWindow, (pRegs->wobjsel>> 0) & 0xF, (pRegs->wobjlog>> 0) & 3);
	_SetBGMask(&pBGWindow[SNPPU_BGWINDOW_COLOR], pWindow, (pRegs->wobjsel>> 4) & 0xF, (pRegs->wobjlog>> 2) & 3);

	PROF_LEAVE("DecodeWindows");
}


