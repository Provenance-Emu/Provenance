
#include "types.h"
#include "snmask.h"
 
#define SNMASKOP_AND(_a,_b)  ((_a) & (_b))
#define SNMASKOP_ANDN(_a,_b)  ((_a) & ~(_b))
#define SNMASKOP_OR(_a,_b)   ((_a) | (_b))
#define SNMASKOP_XOR(_a,_b)  ((_a) ^ (_b))
#define SNMASKOP_XNOR(_a,_b) ~((_a) ^ (_b))
#define SNMASKOP_NOT(_a,_b)  (~(_a))
#define SNMASKOP_COPY(_a,_b)  (_a)
#define SNMASKOP_SET(_a,_b)  (0xFFFFFFFFFFFFFFFF)
#define SNMASKOP_CLR(_a,_b)  (0x0000000000000000)


#define SNMASK_EXECOP_8(_pDest, _pSrcA, _pSrcB, _MASKOP) \
   _pDest->uMask64[0] = _MASKOP(_pSrcA->uMask64[0], _pSrcB->uMask64[0]); \
   _pDest->uMask64[1] = _MASKOP(_pSrcA->uMask64[1], _pSrcB->uMask64[1]); \
   _pDest->uMask64[2] = _MASKOP(_pSrcA->uMask64[2], _pSrcB->uMask64[2]); \
   _pDest->uMask64[3] = _MASKOP(_pSrcA->uMask64[3], _pSrcB->uMask64[3]); \


#define SNMASK_EXECOP2_8(_pDest, _pSrcA, _pSrcB, _MASKOP) \
	Uint64 a0,a1,a2,a3,b0,b1,b2,b3; \
	a0 = _pSrcA->uMask64[0];			\
	b0 = _pSrcB->uMask64[0];			\
	a1 = _pSrcA->uMask64[1];			\
	b1 = _pSrcB->uMask64[1];			\
	a2 = _pSrcA->uMask64[2];			\
	b2 = _pSrcB->uMask64[2];			\
	a3 = _pSrcA->uMask64[3];			\
	b3 = _pSrcB->uMask64[3];			\
   _pDest->uMask64[0] = _MASKOP(a0, b0); \
   _pDest->uMask64[1] = _MASKOP(a1, b1); \
   _pDest->uMask64[2] = _MASKOP(a2, b2); \
   _pDest->uMask64[3] = _MASKOP(a3, b3); 


void SNMaskClear(SNMaskT *pDest)
{
	// 0
	SNMASK_EXECOP_8(pDest, 0, 0, SNMASKOP_CLR);
}

void SNMaskSet(SNMaskT *pDest)
{
	// 1
	SNMASK_EXECOP_8(pDest, 0, 0, SNMASKOP_SET);
}

void SNMaskCopy(SNMaskT *pDest, SNMaskT *pSrc)
{
	// 0
	SNMASK_EXECOP_8(pDest, pSrc, 0, SNMASKOP_COPY);
}


void SNMaskNOT(SNMaskT *pDest, SNMaskT *pSrc)
{
	// 0  1
	// 1  0
	SNMASK_EXECOP_8(pDest, pSrc, 0, SNMASKOP_NOT);
}

void SNMaskAND(SNMaskT *pDest, SNMaskT *pSrcA, SNMaskT *pSrcB)
{
	// 00 0
	// 01 0
	// 10 0
	// 11 1
	SNMASK_EXECOP2_8(pDest, pSrcA, pSrcB, SNMASKOP_AND);
}

void SNMaskANDN(SNMaskT *pDest, SNMaskT *pSrcA, SNMaskT *pSrcB)
{
	// 00 0
	// 01 0
	// 10 1
	// 11 0
	SNMASK_EXECOP2_8(pDest, pSrcA, pSrcB, SNMASKOP_ANDN);
}


void SNMaskOR(SNMaskT *pDest, SNMaskT *pSrcA, SNMaskT *pSrcB)
{
	// 00 0
	// 01 1
	// 10 1
	// 11 1
	SNMASK_EXECOP2_8(pDest, pSrcA, pSrcB, SNMASKOP_OR);
}

void SNMaskXOR(SNMaskT *pDest, SNMaskT *pSrcA, SNMaskT *pSrcB)
{
	// 00 0
	// 01 1
	// 10 1
	// 11 0
	SNMASK_EXECOP2_8(pDest, pSrcA, pSrcB, SNMASKOP_XOR);
}

void SNMaskXNOR(SNMaskT *pDest, SNMaskT *pSrcA, SNMaskT *pSrcB)
{
	// 00 1
	// 01 0
	// 10 0
	// 11 1
	SNMASK_EXECOP2_8(pDest, pSrcA, pSrcB, SNMASKOP_XNOR);
}

void SNMaskBool(SNMaskT *pDest, SNMaskT *pSrc, bool bVal)
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

void SNMaskSHL(SNMaskT *pDestMask, Uint8 *pSrcMask, Int32 nBits)
{
	Int32 nInvBits;
    Uint64 uSrc0, uSrc1, uSrc2, uSrc3, uSrc4;
    Uint64 uDest0, uDest1, uDest2, uDest3;
	Uint64 *pSrc = (Uint64 *)pSrcMask;

	if (nBits==0)
	{
		SNMaskCopy(pDestMask, (SNMaskT *)pSrc);
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



void SNMaskSHR(SNMaskT *pDestMask, Uint8 *pSrcMask, Int32 nBits)
{
	Int32 nInvBits;
    Uint64 uSrc0, uSrc1, uSrc2, uSrc3;
    Uint64 uDest0, uDest1, uDest2, uDest3;
	Uint64 *pSrc = (Uint64 *)pSrcMask;

	if (nBits==0)
	{
		SNMaskCopy(pDestMask, (SNMaskT *)pSrc);
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




