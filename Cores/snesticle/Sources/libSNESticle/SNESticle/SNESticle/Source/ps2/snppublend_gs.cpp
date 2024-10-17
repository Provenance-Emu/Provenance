

#include <stdlib.h>
#include "types.h"
#include "prof.h"
#include "snmask.h"
#include "rendersurface.h"
#include "snppurender.h"
#include "snppublend_gs.h"
#include "snppucolor.h"

#include <tamtypes.h>
extern "C" {

#include <kernel.h>
#include "ps2dma.h"
#include "gpfifo.h"
#include "gs.h"
#include "gslist.h"
#include "ps2mem.h"
}

#define SNPPUBLEND_PAL32 (TRUE)

extern SnesChrLookupT _SnesPPU_PlaneLookup[2];

static Uint32 _SNPPUBlend_AttribMainPal[8] _ALIGN(16) =
{                   // HSM
    0x00000000,     // 000
    0x80000000,     // 001
    0x00000000,     // 010
    0x80000000,     // 011
    0x00000000,     // 100
    0x40000000,     // 101
    0x00000000,     // 110
    0x40000000,     // 111
};


static Uint32 _SNPPUBlend_AttribSubPal[8] _ALIGN(16) =
{                   // HSM
    0x00000000,     // 000
    0x00000000,     // 001
    0x80000000,     // 010
    0x80000000,     // 011
    0x00000000,     // 100
    0x00000000,     // 101
    0x40000000,     // 110
    0x40000000,     // 111
};



static void _PlanarTo3(Uint8 *pDest, SNMaskT *pSrc0, SNMaskT *pSrc1, SNMaskT *pSrc2)
{
	Uint32 nBytes = 256 / 8;
	SnesChrLookup64T *pLookup64 = (SnesChrLookup64T *)&_SnesPPU_PlaneLookup[1];
	Uint64 *pDest64 = (Uint64 *)pDest;


	while (nBytes > 0)
	{
		Uint64 uData;

		uData  = (*pLookup64)[pSrc0->uMask8[0]] << 0;	
		uData |= (*pLookup64)[pSrc1->uMask8[0]] << 1;	
		uData |= (*pLookup64)[pSrc2->uMask8[0]] << 2;	


		pSrc0  = (SNMaskT *) (((Uint8 *)pSrc0) + 1);
		pSrc1  = (SNMaskT *) (((Uint8 *)pSrc1) + 1);
		pSrc2  = (SNMaskT *) (((Uint8 *)pSrc2) + 1);

		pDest64[0] = uData;
		pDest64+=1;

		nBytes--;
	}

}

#if SNPPUBLEND_PAL32

void SNPPUBlendGS::UpdatePaletteEntry(SNPPUBlendInfoT *pInfo, Uint32 uAddr, Uint32 uData, Uint32 uIntensity)
{
    PaletteT *pPal = pInfo->Pal;

	uData = SNPPUColorConvert15to32(uData & 0x7FFF);

	if (uAddr > 0)
	{
		uData |= 0x80000000;
	} 

	// swap 8 and 0x10 of addr
	uAddr = (uAddr & ~0x18) | ((uAddr & 0x10) >> 1) | ((uAddr & 0x08) << 1);

	pPal->Color32[uAddr] = uData;
}

void SNPPUBlendGS::UpdatePalette(SNPPUBlendInfoT *pInfo, Uint16 *pCGRam, Uint32 uIntensity)
{
	Int32 iEntry;
    PaletteT *pPal = pInfo->Pal;

	PROF_ENTER("SNPPUBlendUpdatePalette");

	pPal->Color32[0] = SNPPUColorConvert15to32(pCGRam[0]);
	for (iEntry=1; iEntry < 256; iEntry++)
	{
		Uint32 uAddr = iEntry;

		uAddr = (uAddr & ~0x18) | ((uAddr & 0x10) >> 1) | ((uAddr & 0x08) << 1);

		// set palette entry (with alpha set)
		pPal->Color32[uAddr] = SNPPUColorConvert15to32(pCGRam[iEntry]) | 0x80000000;
	}

	PROF_LEAVE("SNPPUBlendUpdatePalette");
}

#else

static Uint32 SNPPUColorConvert15to32(SnesColor16T uColor16)
{
	Uint32 uColor32;
	Uint32 uR, uG, uB;

	uR = ((uColor16 >>  0) & 0x1F);
	uG = ((uColor16 >>  5) & 0x1F);
	uB = ((uColor16 >>  10) & 0x1F);

	// convert snes16->generic32
	uColor32 =  uR <<  (0  + 3);
	uColor32|=  uG <<  (8  + 3);
	uColor32|=  uB <<  (16 + 3);
	return uColor32;
}


void SNPPUBlendGS::UpdatePaletteEntry(SNPPUBlendInfoT *pInfo, Uint32 uAddr, Uint32 uData, Uint32 uIntensity)
{
    PaletteT *pPal = pInfo->Pal;
	if (uAddr > 0)
	{
		uData |= 0x8000;
	} 
	pPal->Color16[uAddr] = uData;
}

void SNPPUBlendGS::UpdatePalette(SNPPUBlendInfoT *pInfo, Uint16 *pCGRam, Uint32 uIntensity)
{
	Int32 iEntry;
    PaletteT *pPal = pInfo->Pal;

	PROF_ENTER("SNPPUBlendUpdatePalette");


	pPal->Color16[0] = pCGRam[0];
	for (iEntry=1; iEntry < 256; iEntry++)
	{
		// set palette entry (with alpha set)
		pPal->Color16[iEntry] = pCGRam[iEntry] | 0x8000;
	}

	PROF_LEAVE("SNPPUBlendUpdatePalette");
}



#endif


static void _GPFifoUploadTexture(int TBP, int TBW, int xofs, int yofs, int pxlfmt, void *tex, int wpxls, int hpxls)
{
    int numq;

    numq = wpxls * hpxls;
    switch (pxlfmt)
    {
    case 0x00: numq = (numq >> 2) + ((numq & 0x03) != 0 ? 1 : 0); break;
    case 0x02: numq = (numq >> 3) + ((numq & 0x07) != 0 ? 1 : 0); break;
    case 0x13: numq = (numq >> 4) + ((numq & 0x0f) != 0 ? 1 : 0); break;
    case 0x14: numq = (numq >> 5) + ((numq & 0x1f) != 0 ? 1 : 0); break;
    default:   numq = 0;
    }

    GSGifTagOpenAD();

    GSGifRegAD(GS_REG_BITBLTBUF,GS_SET_BITBLTBUF( 0, (TBW/64), pxlfmt,  (TBP/256), (TBW/64), pxlfmt));
    GSGifRegAD(GS_REG_TRXPOS,GS_SET_TRXPOS(0,0,xofs,yofs,0));
    GSGifRegAD(GS_REG_TRXREG,GS_SET_TRXREG(wpxls, hpxls));
    GSGifRegAD(GS_REG_TRXDIR,GS_SET_TRXDIR(0));
    
    GSGifTagCloseAD();
    
    // image gif tag
    GSGifTagImage(numq);

    // close last dma cnt
    GSDmaCntClose();

    // dma image data
    GSDmaRef((Uint128 *)tex, numq);


    // start new dma cnt
    GSDmaCntOpen();
}


static void _SNPPURenderTexLine(Int32 iDestLine, Int32 iSrcLine, Uint32 RGBA, int abe)
{
    int x1,x2,y1,y2;
    int u1,u2,v1,v2;

    x1  =   0 << 4;
    x2  = 256 << 4;
    y1  = (iDestLine + 0) << 4;
    y2  = (iDestLine + 1) << 4;

    u1  =   0 << 4;
    u2  = 256 << 4;
    v1  = (iSrcLine + 0) << 4;
    v2  = (iSrcLine + 1) << 4;

    x1+=0x8000;
    y1+=0x8000;
    x2+=0x8000;
    y2+=0x8000;
    
    GSGifTagOpen(GIF_SET_TAG(1, 1, 0, 0, 1, 6), 0xF535310);
    
	GSGifReg(GS_SET_PRIM(0x06, 0, 1, 0, abe, 0, 1, 0, 0));
	GSGifReg(RGBA);
	GSGifReg(GS_SET_UV(u1, v1));
	GSGifReg(GS_SET_XYZ(x1,y1,0));
	GSGifReg(GS_SET_UV(u2, v2));
	GSGifReg(GS_SET_XYZ(x2,y2,0));
    
    GSGifTagClose();

}


static void _SNPPURenderLine(Int32 iDestLine, int abe)
{
    int x1,x2,y1,y2;

    x1  =   0 << 4;
    x2  = 256 << 4;
    y1  = (iDestLine + 0) << 4;
    y2  = (iDestLine + 1) << 4;

    x1+=0x8000;
    x2+=0x8000;
    y1+=0x8000;
    y2+=0x8000;
  
    GSGifTagOpen(GIF_SET_TAG(1, 1, 0, 0, 1, 4), 0xF550);
    
	GSGifReg(GS_SET_PRIM(0x06, 0, 0, 0, abe, 0, 1, 0, 0));
	GSGifReg(GS_SET_XYZ(x1,y1,0));
	GSGifReg(GS_SET_XYZ(x2,y2,0));
	GSGifReg(0);
    
    GSGifTagClose();
}
  


void SNPPUBlendGS::Begin(CRenderSurface *pTarget)
{
    m_pTarget = pTarget;
	if (!m_pTarget)
	{
		return;
	}

    // these are constants!
    _GPFifoUploadTexture(
         m_DmaList.uAttribMainPal * 0x100, 
         64, 0, 0, 
         GS_PSMCT32, 
         _SNPPUBlend_AttribMainPal, 
         16, 
         16);

    _GPFifoUploadTexture(
         m_DmaList.uAttribSubPal * 0x100, 
         64, 0, 0, 
         GS_PSMCT32, 
         _SNPPUBlend_AttribSubPal, 
         16, 
         16);


    GSGifTagOpenAD();

	GSGifRegAD(GS_REG_TEXCLUT,256/64);

	GSGifRegAD(GS_REG_TEXA,GS_SET_TEXA(0x00,0,0x80));

    // clamp_1
	GSGifRegAD(GS_REG_CLAMP_1,GS_SET_CLAMP(0, 0, 0, 0, 0, 0));

    // tex1_1
    GSGifRegAD(GS_REG_TEX1_1, 0x000);

    GSGifTagCloseAD();


    GPFifoPause();
}

void SNPPUBlendGS::End()
{
	if (!m_pTarget)
	{
		return;
	}

    // wait for previous dma to finish
    DmaSyncGIF();

    GPFifoResume();

    GSGifTagOpenAD();
    // reset frame register
	GSGifRegAD(GS_REG_FRAME_1, GS_GetFrameReg());
	GSGifRegAD(GS_REG_XYOFFSET_1, GS_GetOffsetReg());
    GSGifTagCloseAD();

    m_pTarget = NULL;
}




static void _SNPPUBlendBuildList(SNPPUDmaListT *pList, SNPPUBlendInfoT *pInfo, Uint32 uOutAddr)
{
    PaletteT *pPal = pInfo->Pal;

    // begin dma list
    GSListBegin(pList->Data, sizeof(pList->Data) / sizeof(Uint128), NULL);

    GSDmaCntOpen();

	#if SNPPUBLEND_PAL32
	// upload as 16x16 psmct32 for use as csm1
    _GPFifoUploadTexture(
         pList->uPalAddr * 0x100, 
         1, 0, 0, 
         GS_PSMCT32, 
         (void *)(((Uint32)pPal) | 0x80000000), 
         16, 
         16);
	#else
	// upload as 256x1 psmct16 for use as csm2
    _GPFifoUploadTexture(
         pList->uPalAddr * 0x100, 
         256, 0, 0, 
         GS_PSMCT16, 
         (void *)(((Uint32)pPal) | 0x80000000), 
         256, 
         1);
	#endif


    _GPFifoUploadTexture(
         pList->uInputAddr * 0x100, 
         256, 0, 0, 
         GS_PSMT8, 
         (void *)(((Uint32)pInfo->uMain8) | 0x80000000), 
         256, 
         1);

    _GPFifoUploadTexture(
         pList->uInputAddr * 0x100, 
         256, 0, 1, 
         GS_PSMT8, 
         (void *)(((Uint32)pInfo->uSub8) | 0x80000000), 
         256, 
         1);

    _GPFifoUploadTexture(
         pList->uInputAddr * 0x100, 
         256, 0, 2, 
         GS_PSMT8, 
         (void *)(((Uint32)pInfo->uAttrib8) | 0x80000000), 
         256, 
         1);



    GSGifTagOpenAD();

    // texflush
    GSGifRegAD(GS_REG_TEXFLUSH,0);

    // setup frame register to point to our temporary texture
	GSGifRegAD(GS_REG_FRAME_1, GS_SET_FRAME((pList->uTempAddr/0x20),256/64,GS_PSMCT32,0 ));

	GSGifRegAD(GS_REG_XYOFFSET_1, GS_SET_XYOFFSET(0x8000, 0x8000));

    GSGifTagCloseAD();


    // setup src texture

    GSGifTagOpenAD();
	#if SNPPUBLEND_PAL32
	// use clut psmct32 csm1
	GSGifRegAD(GS_REG_TEX0_1,GS_SET_TEX0(pList->uInputAddr, 256/64, GS_PSMT8, 8, 3,    1, 0, pList->uPalAddr, GS_PSMCT32, 0, 0, 1));
	#else
	// use clut psmct16 csm2
	GSGifRegAD(GS_REG_TEX0_1,GS_SET_TEX0(pList->uInputAddr, 256/64, GS_PSMT8, 8, 3,    1, 0, pList->uPalAddr, GS_PSMCT16, 1, 0, 1));
	#endif
    GSGifRegAD(GS_REG_ALPHA_1,GS_SET_ALPHA(0,1,0,1, 0x80));

    pList->pFixedColor = (Uint64 *)GSListGetUncachedPtr();
    GSGifRegAD(GS_REG_RGBAQ, 0);
    GSGifTagCloseAD();

    // render fixed color32 -> temp32[1]
    _SNPPURenderLine(1, 0);

    // render main8 -> temp32[0]
    _SNPPURenderTexLine(0, 0, 0x80808080, 0);

    // render sub8 -> temp32[1] (alpha=0 means use fixed color)
    _SNPPURenderTexLine(1, 1, 0x80808080, 1);


    //
    // render attribs
    //



    GSGifTagOpenAD();

	// tex0_1
	GSGifRegAD(GS_REG_TEX0_1,GS_SET_TEX0(pList->uInputAddr, 256/64, GS_PSMT8, 8, 3,    1, 0, pList->uAttribMainPal, GS_PSMCT32, 0, 0, 1));


    // alpha_1: A = Cs, B = Cd, C = As, D = Cd
    // (a - b) * c + d
    GSGifRegAD(GS_REG_ALPHA_1,GS_SET_ALPHA(1,2,0,2, 0x20));
    
    GSGifTagCloseAD();

    // render attrib main8 -> temp32 line 0
    _SNPPURenderTexLine(0, 2, 0x80808080, 1);

       

    GSGifTagOpenAD();

	// tex0_1
	GSGifRegAD(GS_REG_TEX0_1,GS_SET_TEX0(pList->uInputAddr, 256/64, GS_PSMT8, 8, 3,    1, 0, pList->uAttribSubPal, GS_PSMCT32, 0, 0, 1));


    // alpha_1: A = Cs, B = Cd, C = As, D = Cd
    // (a - b) * c + d
    GSGifRegAD(GS_REG_ALPHA_1,GS_SET_ALPHA(1,2,0,2, 0x80));
    
    GSGifTagCloseAD();


    // render attrib sub8 -> temp32 line 0
    _SNPPURenderTexLine(1, 2, 0x80808080, 1);


    // texflush
    GSGifTagOpenAD();
    GSGifRegAD(GS_REG_TEXFLUSH,0);

    // setup frame register to point to our output texture
	GSGifRegAD(GS_REG_FRAME_1, GS_SET_FRAME((uOutAddr/0x20),256/64,GS_PSMCT32,0 ));

	// tex0_1
	GSGifRegAD(GS_REG_TEX0_1,GS_SET_TEX0(pList->uTempAddr, 256/64, GS_PSMCT32, 8, 3,    1, 0, 0, 0, 0, 0, 0));

    // alpha_1: A = Cs, B = Cd, C = As, D = Cd
    // (a - b) * c + d
    pList->pAddSub = (Uint64 *)GSListGetUncachedPtr();
    GSGifRegAD(GS_REG_ALPHA_1,GS_SET_ALPHA(0,2,2,1, 0x80));

    pList->pXYOffset = (Uint64 *)GSListGetUncachedPtr();
	GSGifRegAD(GS_REG_XYOFFSET_1, 0);
    
    GSGifTagCloseAD();

    // render out32 = main32 * attrib
    _SNPPURenderTexLine(0, 0, 0x80808080, 0);

    // render out32 += sub32 * attrib
    _SNPPURenderTexLine(0, 1, 0x80808080, 1);

    GSGifTagOpenAD();
    GSGifRegAD(GS_REG_ALPHA_1,GS_SET_ALPHA(1,2,0,2, 0x80 ));
    pList->pIntensity = (Uint64 *)GSListGetUncachedPtr();
    GSGifRegAD(GS_REG_RGBAQ, 0);
    GSGifTagCloseAD();

    // render out32 *= intensity
    _SNPPURenderLine(0, 1);

    // close current dma cnt
    GSDmaCntClose();
    
    // add end tag
    GSDmaEnd();

    GSListEnd();
}






#if 1


static void _SNPPUBlendSetParm(SNPPUDmaListT *pList, Int32 iLine, Uint32 uFixedColor16, Bool bAddSub, Uint32 uIntensity)
{
    *pList->pFixedColor = SNPPUColorConvert15to32(uFixedColor16);
    *pList->pXYOffset   = GS_SET_XYOFFSET(0x8000, 0x8000 - (iLine<<4)  );
    *pList->pIntensity  = (uIntensity * 0x80 / 15) << 24;
    if (!bAddSub)
    {
        // add
        *pList->pAddSub     = GS_SET_ALPHA(1,2,2,0, 0x80);
    } else
    {
        // sub
        *pList->pAddSub     = GS_SET_ALPHA(1,0,2,2, 0x80);
    }
    __asm__ __volatile__ ("sync.l");
}



#include "gs.h"

SNPPUBlendGS::SNPPUBlendGS(Uint32 uVramAddr, Uint32 uOutAddr)
{
    SNPPUDmaListT *pList = &m_DmaList;

    m_pDmaBlendInfo = NULL;

    pList->uPalAddr        = uVramAddr + 0x000;
    pList->uInputAddr      = uVramAddr + 0x080 ;
    pList->uAttribMainPal  = uVramAddr + 0x180 ;
    pList->uAttribSubPal   = uVramAddr + 0x184 ;
    pList->uTempAddr       = uVramAddr + 0x200 ;

	pList->uOutAddr = uOutAddr;
}

void SNPPUBlendGS::Exec(SNPPUBlendInfoT *pInfo, Int32 iLine, Uint32 uFixedColor32, SNMaskT *pColorMask, Bool bAddSub, Uint32 uIntensity)
{
	if (!m_pTarget)
	{
		return;
	}

    if (m_pDmaBlendInfo != pInfo)
    {
        // build dma list for this blend info
        _SNPPUBlendBuildList(&m_DmaList, pInfo, m_DmaList.uOutAddr);

        // flush cache
        FlushCache(0);

        m_pDmaBlendInfo = pInfo;
    }

    if (pColorMask)
    {
        PROF_ENTER("SNPPUBlendPlanarTo3");
        _PlanarTo3(pInfo->uAttrib8, &pColorMask[0],&pColorMask[1],&pColorMask[2]);
        PROF_LEAVE("SNPPUBlendPlanarTo3");
    }

    // wait for previous dma to finish
    PROF_ENTER("SNPPUGS");
    DmaSyncGIF();
    PROF_LEAVE("SNPPUGS");

    PROF_ENTER("SNPPUBlendExec");

    // set parameters of dma-list
    _SNPPUBlendSetParm(&m_DmaList, iLine, uFixedColor32, bAddSub, uIntensity);

    PROF_LEAVE("SNPPUBlendExec");

    // transfer render ilst
    DmaExecGIFChain(m_DmaList.Data);

}




void SNPPUBlendGS::Clear(SNPPUBlendInfoT *pInfo, Int32 iLine)
{
    // render clear line
    Exec(pInfo, iLine, 0, NULL, 0, 0);
}








#endif

















