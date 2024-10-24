

#ifndef _SNMASKOP_H
#define _SNMASKOP_H


#define SNMASKOP_INLINE (TRUE)
#define SNMASKOP_ASSEMBLY (TRUE)

void SNMaskRange(SNMaskT *pMask, Uint32 uLeft, Uint32 uRight, bool bInvert);
void SNMaskRight(SNMaskT *pMask, Int32 iPos);
void SNMaskLeft(SNMaskT *pMask, Int32 iPos);

void SNMaskSHR(SNMaskT *pDestMask, const Uint8 *pSrcMask, Int32 nBits);
void SNMaskSHL(SNMaskT *pDestMask, const Uint8 *pSrcMask, Int32 nBits);

#if !SNMASKOP_INLINE

void SNMaskClear(SNMaskT *pDest);
void SNMaskSet(SNMaskT *pDest);
void SNMaskCopy(SNMaskT *pDest,  const SNMaskT *pSrc);

void SNMaskNOT(SNMaskT *pDest,  const SNMaskT *pSrc);
void SNMaskAND(SNMaskT *pDest,  const SNMaskT *pSrcA,  const SNMaskT *pSrcB);
void SNMaskANDN(SNMaskT *pDest,  const SNMaskT *pSrcA,  const SNMaskT *pSrcB);
void SNMaskOR(SNMaskT *pDest,  const SNMaskT *pSrcA,  const SNMaskT *pSrcB);
void SNMaskXOR(SNMaskT *pDest,  const SNMaskT *pSrcA,  const SNMaskT *pSrcB);
void SNMaskXNOR(SNMaskT *pDest,  const SNMaskT *pSrcA,  const SNMaskT *pSrcB);

void SNMaskBool(SNMaskT *pDest, const SNMaskT *pSrc, bool bVal);

#elif !SNMASKOP_ASSEMBLY

static inline void SNMaskClear(SNMaskT *pDest)
{
    __asm__ __volatile__ (
    	"sq        $0,0x00(%0)     \n"
    	"sq        $0,0x10(%0)     \n"
    	: 
    	: "r" (pDest)
     );    
}

static inline void SNMaskSet(SNMaskT *pDest)
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


static inline void SNMaskCopy(SNMaskT *pDest,  const SNMaskT *pSrc)
{
	Uint128 a,b;

	a = pSrc->uMask128[0];
	b = pSrc->uMask128[1];

	pDest->uMask128[0] = a;
	pDest->uMask128[1] = b;
}


static inline void SNMaskNOT(SNMaskT *pDest,  const SNMaskT *pSrc)
{
	// 0  1
	// 1  0
	// 0

	Uint128 a,b;

	a = pSrc->uMask128[0];
	b = pSrc->uMask128[1];

	a = ~a;
	b = ~b;

	pDest->uMask128[0] = a;
	pDest->uMask128[1] = b;
}

static inline void SNMaskAND(SNMaskT *pDest,  const SNMaskT *pSrcA,  const SNMaskT *pSrcB)
{
	// 00 0
	// 01 0
	// 10 0
	// 11 1
	Uint128 a0,a1,b0,b1;
	Uint128 c0,c1;

	a0 = pSrcA->uMask128[0];
	a1 = pSrcA->uMask128[1];

	b0 = pSrcB->uMask128[0];
	b1 = pSrcB->uMask128[1];

	c0 = a0 & b0;
	c1 = a1 & b1;

	pDest->uMask128[0] = c0;
	pDest->uMask128[1] = c1;
}

static inline void SNMaskANDN(SNMaskT *pDest,  const SNMaskT *pSrcA,  const SNMaskT *pSrcB)
{
	// 00 0
	// 01 0
	// 10 1
	// 11 0

	Uint128 a0,a1,b0,b1;
	Uint128 c0,c1;

	a0 = pSrcA->uMask128[0];
	a1 = pSrcA->uMask128[1];

	b0 = pSrcB->uMask128[0];
	b1 = pSrcB->uMask128[1];

	c0 = (a0 | b0) ^ b0;
	c1 = (a1 | b1) ^ b1;

	pDest->uMask128[0] = c0;
	pDest->uMask128[1] = c1;
}


static inline void SNMaskOR(SNMaskT *pDest,  const SNMaskT *pSrcA,  const SNMaskT *pSrcB)
{
	// 00 0
	// 01 1
	// 10 1
	// 11 1
	Uint128 a0,a1,b0,b1;
	Uint128 c0,c1;

	a0 = pSrcA->uMask128[0];
	a1 = pSrcA->uMask128[1];

	b0 = pSrcB->uMask128[0];
	b1 = pSrcB->uMask128[1];

	c0 = (a0 | b0);
	c1 = (a1 | b1);

	pDest->uMask128[0] = c0;
	pDest->uMask128[1] = c1;
}

static inline void SNMaskXOR(SNMaskT *pDest,  const SNMaskT *pSrcA,  const SNMaskT *pSrcB)
{
	// 00 0
	// 01 1
	// 10 1
	// 11 0
	Uint128 a0,a1,b0,b1;
	Uint128 c0,c1;

	a0 = pSrcA->uMask128[0];
	a1 = pSrcA->uMask128[1];

	b0 = pSrcB->uMask128[0];
	b1 = pSrcB->uMask128[1];

	c0 = (a0 ^ b0);
	c1 = (a1 ^ b1);

	pDest->uMask128[0] = c0;
	pDest->uMask128[1] = c1;
}

static inline void SNMaskXNOR(SNMaskT *pDest,  const SNMaskT *pSrcA,  const SNMaskT *pSrcB)
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

static inline void SNMaskBool(SNMaskT *pDest,  const SNMaskT *pSrc, bool bVal)
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

#else

static inline void SNMaskClear(SNMaskT *pDest)
{
    __asm__ __volatile__ (
    	"sq        $0,0x00(%0)     \n"
    	"sq        $0,0x10(%0)     \n"
    	: 
    	: "r" (pDest)
     );    
}

static inline void SNMaskSet(SNMaskT *pDest)
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


static inline void SNMaskCopy(SNMaskT *pDest,  const SNMaskT *pSrc)
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


static inline void SNMaskNOT(SNMaskT *pDest,  const SNMaskT *pSrc)
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

static inline void SNMaskAND(SNMaskT *pDest,  const SNMaskT *pSrcA,  const SNMaskT *pSrcB)
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

static inline void SNMaskANDN(SNMaskT *pDest,  const SNMaskT *pSrcA,  const SNMaskT *pSrcB)
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


static inline void SNMaskOR(SNMaskT *pDest,  const SNMaskT *pSrcA,  const SNMaskT *pSrcB)
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

static inline void SNMaskXOR(SNMaskT *pDest,  const SNMaskT *pSrcA,  const SNMaskT *pSrcB)
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

static inline void SNMaskXNOR(SNMaskT *pDest,  const SNMaskT *pSrcA,  const SNMaskT *pSrcB)
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

static inline void SNMaskBool(SNMaskT *pDest,  const SNMaskT *pSrc, bool bVal)
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

#endif
