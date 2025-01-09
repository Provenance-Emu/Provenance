                      
#include "types.h"
#include "snmask.h"
#include "snmaskop.h"
 

void SNMaskLeft(SNMaskT *pMask, Int32 iPos)
{
    Int32 nWords;
    Uint32 uMask;
	Uint32 *pDest = pMask->uMask32;
    
    SNMaskClear(pMask);
    if (iPos <= 0) return;
    if (iPos > 256) iPos = 256;
    
    nWords = (iPos-1) >> 5;
	iPos  &= 31;
    
    // write full masks
    while (nWords > 0)
    {
        pDest[0] = 0xFFFFFFFF;
        pDest++;
        nWords--;
    } 

    // write partial mask    
    uMask    = 0xFFFFFFFF >> (32 - iPos);
	pDest[0] = uMask;
}


void SNMaskRight(SNMaskT *pMask, Int32 iPos)
{
    Int32 nWords;
    Uint32 uMask;
	Uint32 *pDest = pMask->uMask32;
    
    SNMaskSet(pMask);
    if (iPos <= 0) return;
    if (iPos > 256) iPos = 256;
    
    nWords = iPos >> 5;
	iPos  &= 31;
    
    // write full masks
    while (nWords > 0)
    {
        pDest[0] = 0;
        pDest++;
        nWords--;
    } 

    // write partial mask    
    uMask    = 0xFFFFFFFF << (iPos);
	pDest[0] = uMask;
}

void SNMaskSHL(SNMaskT *pDestMask,  const Uint8 *pSrcMask, Int32 nBits)
{
	Int32 nInvBits;
    Uint64 uSrc0, uSrc1, uSrc2, uSrc3, uSrc4;
    Uint64 uDest0, uDest1, uDest2, uDest3;
	Uint64 *pSrc = (Uint64 *)pSrcMask;

	if (nBits==0)
	{
		SNMaskCopy(pDestMask, ( const SNMaskT *)pSrc);
		return;
	}

	nInvBits = 64 - nBits;

    uSrc0 = pSrc[0];
    uSrc1 = pSrc[1];
    uSrc2 = pSrc[2];
    uSrc3 = pSrc[3];
    uSrc4 = pSrc[4];

    uDest0 = (uSrc0 >> nBits) | (uSrc1 << nInvBits);
    uDest1 = (uSrc1 >> nBits) | (uSrc2 << nInvBits);
    uDest2 = (uSrc2 >> nBits) | (uSrc3 << nInvBits);
    uDest3 = (uSrc3 >> nBits) | (uSrc4 << nInvBits);

    pDestMask->uMask64[0] = uDest0;
    pDestMask->uMask64[1] = uDest1;
    pDestMask->uMask64[2] = uDest2;
    pDestMask->uMask64[3] = uDest3;
}



void SNMaskSHR(SNMaskT *pDestMask,  const Uint8 *pSrcMask, Int32 nBits)
{
	Int32 nInvBits;
    Uint64 uSrc0, uSrc1, uSrc2, uSrc3;
    Uint64 uDest0, uDest1, uDest2, uDest3;
	Uint64 *pSrc = (Uint64 *)pSrcMask;

	if (nBits==0)
	{
		SNMaskCopy(pDestMask, ( const SNMaskT *)pSrc);
		return;
	}

	nInvBits = 64 - nBits;

    uSrc0 = pSrc[0];
    uSrc1 = pSrc[1];
    uSrc2 = pSrc[2];
    uSrc3 = pSrc[3];

    uDest0 = (uSrc0 << nBits);
    uDest1 = (uSrc1 << nBits) | (uSrc0 >> nInvBits);
    uDest2 = (uSrc2 << nBits) | (uSrc1 >> nInvBits);
    uDest3 = (uSrc3 << nBits) | (uSrc2 >> nInvBits);

    pDestMask->uMask64[0] = uDest0;
    pDestMask->uMask64[1] = uDest1;
    pDestMask->uMask64[2] = uDest2;
    pDestMask->uMask64[3] = uDest3;
}


void SNMaskRange(SNMaskT *pMask, Uint32 uLeft, Uint32 uRight, bool bInvert)
{
	SNMaskT LeftMask;
	SNMaskT RightMask;

	if (bInvert)
	{
		if (uLeft==uRight)
		{
			SNMaskClear(pMask);
		} else
		{
			SNMaskLeft(&LeftMask, uLeft);
			SNMaskRight(&RightMask, uRight + 1);
			SNMaskOR(pMask, &LeftMask, &RightMask);
		}
	}
	else
	{
	//	note:	if "left position setting value > right position value"
	//	~~~~~	is assumed, there will be no range of the window.
		if (uLeft>uRight)
		{
			SNMaskClear(pMask);
		} else
		{
			SNMaskRight(&LeftMask, uLeft);
			SNMaskLeft(&RightMask, uRight+1);
			SNMaskAND(pMask, &LeftMask, &RightMask);
		}
	}
}





#if !SNMASKOP_INLINE

 void SNMaskClear(SNMaskT *pDest)
{
    __asm__ __volatile__ (
    	"sq        $0,0x00(%0)     \n"
    	"sq        $0,0x10(%0)     \n"
    	: 
    	: "r" (pDest)
     );    
}

 void SNMaskSet(SNMaskT *pDest)
{
    __asm__ __volatile__ (
        "pnor      $8,$0,$0        \n"
    	"sq        $8,0x00(%0)     \n"
    	"sq        $8,0x10(%0)     \n"
    	: 
    	: "r" (pDest)
        : "$8"
     );    

}


 void SNMaskCopy(SNMaskT *pDest,  const SNMaskT *pSrc)
{
	// 0
    __asm__ __volatile__ (
        "lq        $8,0x00(%1)        \n"
        "lq        $9,0x10(%1)        \n"
    	"sq        $8,0x00(%0)     \n"
    	"sq        $9,0x10(%0)     \n"
    	: 
    	: "r" (pDest), "r" (pSrc)
        : "$8", "$9"
     );    
}


 void SNMaskNOT(SNMaskT *pDest,  const SNMaskT *pSrc)
{
	// 0  1
	// 1  0
	// 0
    __asm__ __volatile__ (
        "lq        $8,0x00(%1)        \n"
        "lq        $9,0x10(%1)        \n"
        "pnor      $8,$8,$0         \n"
        "pnor      $9,$9,$0         \n"
    	"sq        $8,0x00(%0)     \n"
    	"sq        $9,0x10(%0)     \n"
    	: 
    	: "r" (pDest), "r" (pSrc)
        : "$8", "$9"
     );    
}

 void SNMaskAND(SNMaskT *pDest,  const SNMaskT *pSrcA,  const SNMaskT *pSrcB)
{
	// 00 0
	// 01 0
	// 10 0
	// 11 1
    __asm__ __volatile__ (
        "lq         $8,0x00(%1)        \n"
        "lq         $9,0x10(%1)        \n"
        "lq        $10,0x00(%2)        \n"
        "lq        $11,0x10(%2)        \n"
        "pand      $8,$8,$10         \n"
        "pand      $9,$9,$11         \n"
    	"sq        $8,0x00(%0)     \n"
    	"sq        $9,0x10(%0)     \n"
    	: 
    	: "r" (pDest), "r" (pSrcA), "r" (pSrcB)
        : "$8", "$9", "$10", "$11"
     );    
}

 void SNMaskANDN(SNMaskT *pDest,  const SNMaskT *pSrcA,  const SNMaskT *pSrcB)
{
	// 00 0
	// 01 0
	// 10 1
	// 11 0
    __asm__ __volatile__ (
        "lq         $8,0x00(%1)        \n"
        "lq        $10,0x00(%2)        \n"
        "lq         $9,0x10(%1)        \n"
        "por       $8,$8,$10         \n"
        "lq        $11,0x10(%2)        \n"
        "pxor      $8,$8,$10         \n"
        "por       $9,$9,$11         \n"
    	"sq        $8,0x00(%0)     \n"
        "pxor      $9,$9,$11         \n"
    	"sq        $9,0x10(%0)     \n"
    	: 
    	: "r" (pDest), "r" (pSrcA), "r" (pSrcB)
        : "$8", "$9", "$10", "$11"
     );    
}


 void SNMaskOR(SNMaskT *pDest,  const SNMaskT *pSrcA,  const SNMaskT *pSrcB)
{
	// 00 0
	// 01 1
	// 10 1
	// 11 1
    __asm__ __volatile__ (
        "lq         $8,0x00(%1)        \n"
        "lq         $9,0x10(%1)        \n"
        "lq        $10,0x00(%2)        \n"
        "lq        $11,0x10(%2)        \n"
        "por      $8,$8,$10         \n"
        "por       $9,$9,$11         \n"
    	"sq        $8,0x00(%0)     \n"
    	"sq        $9,0x10(%0)     \n"
    	: 
    	: "r" (pDest), "r" (pSrcA), "r" (pSrcB)
        : "$8", "$9", "$10", "$11"
     );    
}

 void SNMaskXOR(SNMaskT *pDest,  const SNMaskT *pSrcA,  const SNMaskT *pSrcB)
{
	// 00 0
	// 01 1
	// 10 1
	// 11 0
    __asm__ __volatile__ (
        "lq         $8,0x00(%1)        \n"
        "lq         $9,0x10(%1)        \n"
        "lq        $10,0x00(%2)        \n"
        "lq        $11,0x10(%2)        \n"
        "pxor      $8,$8,$10         \n"
        "pxor       $9,$9,$11         \n"
    	"sq        $8,0x00(%0)     \n"
    	"sq        $9,0x10(%0)     \n"
    	: 
    	: "r" (pDest), "r" (pSrcA), "r" (pSrcB)
        : "$8", "$9", "$10", "$11"
     );    
}

 void SNMaskXNOR(SNMaskT *pDest,  const SNMaskT *pSrcA,  const SNMaskT *pSrcB)
{
	// 00 1
	// 01 0
	// 10 0
	// 11 1
    __asm__ __volatile__ (
        "lq         $8,0x00(%1)        \n"
        "lq         $9,0x10(%1)        \n"
        "lq        $10,0x00(%2)        \n"
        "lq        $11,0x10(%2)        \n"
        "pxor       $8,$8,$10         \n"
        "pxor       $9,$9,$11         \n"
        "pnor      $8,$8,$0         \n"
        "pnor      $9,$9,$0         \n"
    	"sq        $8,0x00(%0)     \n"
    	"sq        $9,0x10(%0)     \n"
    	: 
    	: "r" (pDest), "r" (pSrcA), "r" (pSrcB)
        : "$8", "$9", "$10", "$11"
     );    
}

 void SNMaskBool(SNMaskT *pDest,  const SNMaskT *pSrc, bool bVal)
{
	// if bVal==true, then set bits of src in dest
	// if bVal==false, then clear bits of src in dest
	if (bVal)
	{
		SNMaskOR(pDest, pDest, pSrc);
	} else
	{
		SNMaskANDN(pDest, pDest, pSrc);
	}
}

#endif
