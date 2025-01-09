
#include "types.h"
#include "snmask.h"
 
#define SNMASKOP_AND(_a,_b)  ((_a) & (_b))
#define SNMASKOP_ANDN(_a,_b)  ((_a) & ~(_b))
#define SNMASKOP_OR(_a,_b)   ((_a) | (_b))
#define SNMASKOP_XOR(_a,_b)  ((_a) ^ (_b))
#define SNMASKOP_XNOR(_a,_b) ~((_a) ^ (_b))
#define SNMASKOP_NOT(_a,_b)  (~(_a))
#define SNMASKOP_COPY(_a,_b)  (_a)
#define SNMASKOP_SET(_a,_b)  (0xFFFFFFFF)
#define SNMASKOP_CLR(_a,_b)  (0x00000000)


#define SNMASK_EXECOP_8(_pDest, _pSrcA, _pSrcB, _MASKOP) \
   _pDest->uMask32[0] = _MASKOP(_pSrcA->uMask32[0], _pSrcB->uMask32[0]); \
   _pDest->uMask32[1] = _MASKOP(_pSrcA->uMask32[1], _pSrcB->uMask32[1]); \
   _pDest->uMask32[2] = _MASKOP(_pSrcA->uMask32[2], _pSrcB->uMask32[2]); \
   _pDest->uMask32[3] = _MASKOP(_pSrcA->uMask32[3], _pSrcB->uMask32[3]); \
   _pDest->uMask32[4] = _MASKOP(_pSrcA->uMask32[4], _pSrcB->uMask32[4]); \
   _pDest->uMask32[5] = _MASKOP(_pSrcA->uMask32[5], _pSrcB->uMask32[5]); \
   _pDest->uMask32[6] = _MASKOP(_pSrcA->uMask32[6], _pSrcB->uMask32[6]); \
   _pDest->uMask32[7] = _MASKOP(_pSrcA->uMask32[7], _pSrcB->uMask32[7]); 

#define SNMASK_EXECOP2_8(_pDest, _pSrcA, _pSrcB, _MASKOP) \
	Uint32 a0,a1,b0,b1; \
	a0 = _pSrcA->uMask32[0];			\
	b0 = _pSrcB->uMask32[0];			\
	a1 = _pSrcA->uMask32[1];			\
	b1 = _pSrcB->uMask32[1];			\
   _pDest->uMask32[0] = _MASKOP(a0, b0); \
   _pDest->uMask32[1] = _MASKOP(a1, b1); \
	a0 = _pSrcA->uMask32[2];			\
	b0 = _pSrcB->uMask32[2];			\
	a1 = _pSrcA->uMask32[3];			\
	b1 = _pSrcB->uMask32[3];			\
   _pDest->uMask32[2] = _MASKOP(a0, b0); \
   _pDest->uMask32[3] = _MASKOP(a1, b1); \
	a0 = _pSrcA->uMask32[4];			\
	b0 = _pSrcB->uMask32[4];			\
	a1 = _pSrcA->uMask32[5];			\
	b1 = _pSrcB->uMask32[5];			\
   _pDest->uMask32[4] = _MASKOP(a0, b0); \
   _pDest->uMask32[5] = _MASKOP(a1, b1); \
	a0 = _pSrcA->uMask32[6];			\
	b0 = _pSrcB->uMask32[6];			\
	a1 = _pSrcA->uMask32[7];			\
	b1 = _pSrcB->uMask32[7];			\
   _pDest->uMask32[6] = _MASKOP(a0, b0); \
   _pDest->uMask32[7] = _MASKOP(a1, b1); 


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

void SNMaskCopy(SNMaskT *pDest, const SNMaskT *pSrc)
{
	// 0
	SNMASK_EXECOP_8(pDest, pSrc, 0, SNMASKOP_COPY);
}


void SNMaskNOT(SNMaskT *pDest, const SNMaskT *pSrc)
{
	// 0  1
	// 1  0
	SNMASK_EXECOP_8(pDest, pSrc, 0, SNMASKOP_NOT);
}

void SNMaskAND(SNMaskT *pDest, const SNMaskT *pSrcA, const SNMaskT *pSrcB)
{
	// 00 0
	// 01 0
	// 10 0
	// 11 1
	SNMASK_EXECOP2_8(pDest, pSrcA, pSrcB, SNMASKOP_AND);
}

void SNMaskANDN(SNMaskT *pDest, const SNMaskT *pSrcA, const SNMaskT *pSrcB)
{
	// 00 0
	// 01 0
	// 10 1
	// 11 0
	SNMASK_EXECOP2_8(pDest, pSrcA, pSrcB, SNMASKOP_ANDN);
}


void SNMaskOR(SNMaskT *pDest, const SNMaskT *pSrcA, const SNMaskT *pSrcB)
{
	// 00 0
	// 01 1
	// 10 1
	// 11 1
	SNMASK_EXECOP2_8(pDest, pSrcA, pSrcB, SNMASKOP_OR);
}

void SNMaskXOR(SNMaskT *pDest, const SNMaskT *pSrcA, const SNMaskT *pSrcB)
{
	// 00 0
	// 01 1
	// 10 1
	// 11 0
	SNMASK_EXECOP2_8(pDest, pSrcA, pSrcB, SNMASKOP_XOR);
}

void SNMaskXNOR(SNMaskT *pDest, const SNMaskT *pSrcA, const SNMaskT *pSrcB)
{
	// 00 1
	// 01 0
	// 10 0
	// 11 1
	SNMASK_EXECOP2_8(pDest, pSrcA, pSrcB, SNMASKOP_XNOR);
}

void SNMaskBool(SNMaskT *pDest, const SNMaskT *pSrc, bool bVal)
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

void SNMaskSHL(SNMaskT *pDestMask, const Uint8 *pSrcMask, Int32 nBits)
{
	Int32 nInvBits;
	Uint32 *pDest = pDestMask->uMask32;
	Uint32 *pSrc = (Uint32 *)pSrcMask;
	Int32 nWords = 8;

	if (nBits==0)
	{
		SNMaskCopy(pDestMask, (SNMaskT *)pSrc);
		return;
	}

	nInvBits = 32 - nBits;
	while (nWords > 0)
	{
		Uint32 uSrc0, uSrc1;

		uSrc0 = pSrc[0];
		uSrc1 = pSrc[1];

		uSrc0 >>= nBits;
		uSrc1 <<= nInvBits;

		pDest[0] = uSrc0 | uSrc1;

		pSrc++;
		pDest++;
		nWords--;
	}
}



void SNMaskSHR(SNMaskT *pDestMask, const Uint8 *pSrcMask, Int32 nBits)
{
	Int32 nInvBits;
	Uint32 *pDest = pDestMask->uMask32;
	Uint32 *pSrc = (Uint32 *)pSrcMask;
	Int32 nWords = 8;

	if (nBits==0)
	{
		SNMaskCopy(pDestMask, (SNMaskT *)pSrc);
		return;
	}

	// special case first word (shift in zeros)
	pDest[0] = pSrc[0] << nBits;
	pDest++;
	nWords--;

	nInvBits = 32 - nBits;
	while (nWords > 0)
	{
		Uint32 uSrc0, uSrc1;

		uSrc0 = pSrc[0];
		uSrc1 = pSrc[1];

		uSrc0 >>= nInvBits;
		uSrc1 <<= nBits;

		pDest[0] = uSrc0 | uSrc1;

		pSrc++;
		pDest++;
		nWords--;
	}
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
			SNMaskRight(&RightMask, uRight+1);
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




