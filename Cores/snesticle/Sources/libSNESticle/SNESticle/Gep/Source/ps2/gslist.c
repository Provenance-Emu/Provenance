

#include <stdio.h>  
#include "types.h"
#include "ps2dma.h"
#include "gslist.h"
#include "ps2mem.h"

#define GSAssert(_x) assert(_x)

typedef struct
{
    Uint128  *pPtr;     // current position in dma list

    Uint128  *pBegin;   // start address of dma list being built (NULL if none)
    Uint128  *pEnd;     // end of list being built (if we overflow this, then there is a problem)
    
    DmaTagT  *pDmaCnt;      // pointer to last dma CNT tag (NULL if none)
    GSGifTagT *pGifTag;     // pointer to last gif tag
    Uint64    *pGifData;    // pointer to 64-bit gifdata stream

    GSListFlushFuncT pFlushFunc;
} GSListT;


static GSListT _GSList_List;


Int32 GSListSpace(Uint32 nMinQwords)
{
    GSListT *pList = &_GSList_List;

    // ensure that enough space exists in list
    if (GSListGetSpace() < nMinQwords)
    {
        if (pList->pFlushFunc)
        {
            // call flush function
            pList->pFlushFunc();
        }

        if (GSListGetSpace() < nMinQwords)
        {
            printf("GPFifoOverflow: %d %d\n", GSListGetSpace(), nMinQwords);
            assert(0);
            return 0;
        }
    }
    
    return 1;
}


void GSListBegin(Uint128 *pMem, Uint32 nQwords, GSListFlushFuncT pFlushFunc)
{
    GSListT *pList = &_GSList_List;
    
    GSAssert(!pList->pPtr);
    
    // start building list
    pList->pPtr         = pMem;
    pList->pBegin       = pMem;
    pList->pEnd         = pMem + nQwords;
    pList->pFlushFunc   = pFlushFunc;

	pList->pDmaCnt  	= NULL;
	pList->pGifTag  	= NULL;
	pList->pGifData  	= NULL;
}

Int32 GSListEnd()
{
    GSListT *pList = &_GSList_List;
    Int32 nQwords = 0;

    GSAssert(pList->pPtr);
    GSAssert(!pList->pDmaCnt);
    GSAssert(!pList->pGifTag);

    // calculate number of qwords written
    nQwords = pList->pEnd - pList->pBegin;
    
    pList->pPtr   = NULL;
    pList->pBegin = NULL;
    pList->pEnd   = NULL;
    pList->pFlushFunc   = NULL;

    return nQwords;
}

Uint128 *GSListGetPtr()
{
    GSListT *pList = &_GSList_List;
    return pList->pPtr;
}

Uint128 *GSListGetUncachedPtr()
{
    GSListT *pList = &_GSList_List;
    return (Uint128 *)PS2MEM_UNCACHED(pList->pPtr);
}


Uint128 *GSListGetStart()
{
    GSListT *pList = &_GSList_List;
    return pList->pBegin;
}

void GSListSetPtr(Uint128 *pPtr)
{
    GSListT *pList = &_GSList_List;
    GSAssert(pPtr < pList->pEnd);
    pList->pPtr = pPtr;
}

Int32 GSListGetSpace()
{
    GSListT *pList = &_GSList_List;
    return (Int32)(pList->pEnd - pList->pPtr);
}

Int32 GSListGetSize()
{
    GSListT *pList = &_GSList_List;
    return (Int32)(pList->pPtr - pList->pBegin);
}

void GSDmaCntOpen()
{
    GSListT *pList = &_GSList_List;
    DmaTagT *pTag;

    GSAssert(!pList->pDmaCnt);
    
    pTag = (DmaTagT *)pList->pPtr++;
    
    // set dma cnt tag
    pTag->addr   = 0;
    pTag->qwc    = 0;
    pTag->id     = DMA_TAG_CNT;
    pTag->pad[0] = 0;
    pTag->pad[1] = 0;
    
    // set current dma tag
    pList->pDmaCnt = pTag;
}

void GSDmaCntClose()
{
    GSListT *pList = &_GSList_List;
    DmaTagT *pTag = pList->pDmaCnt;
    Int32 nQwords;

    GSAssert(pTag);
    
    // calculate number of qwords written so far
    nQwords = pList->pPtr -  ((Uint128 *)pTag) - 1; 
 
    // set qword count of dma tag
    pTag->qwc = nQwords;
    
    // no active dma tag
    pList->pDmaCnt = NULL;
}

void GSDmaRef(Uint128 *pRefAddr, Uint32 nQwords)
{
    GSListT *pList = &_GSList_List;
    DmaTagT *pTag;

    GSAssert(!pList->pDmaCnt);
    
    pTag = (DmaTagT *)pList->pPtr++;
    
    // set dma ref tag
    pTag->addr   = (Uint32)pRefAddr;
    pTag->qwc    = nQwords;
    pTag->id     = DMA_TAG_REF;
    pTag->pad[0] = 0;
    pTag->pad[1] = 0;
}


void GSDmaEnd()
{
    GSListT *pList = &_GSList_List;
    DmaTagT *pTag;

    GSAssert(!pList->pDmaCnt);
    
    pTag = (DmaTagT *)pList->pPtr++;
    
    // set dma emd tag
    pTag->addr   = 0;
    pTag->qwc    = 0;
    pTag->id     = DMA_TAG_END;
    pTag->pad[0] = 0;
    pTag->pad[1] = 0;
}



void GSGifTagImage(Uint32 nQwords)
{
    GSListT *pList = &_GSList_List;
    GSGifTagT *pGifTag;
    
    GSAssert(!pList->pGifTag);
    GSAssert(nQwords < 0x8000);
    
    pGifTag = (GSGifTagT *)pList->pPtr++;
    
    // set giftag image here
    pGifTag->nloop = nQwords;
    pGifTag->tag0  = 0;
    pGifTag->tag1  = 2 << (58-32); // image mode
    pGifTag->regs  = 0;
}



void GSGifTagOpenAD()
{
    GSListT *pList = &_GSList_List;
    GSGifTagT *pGifTag;
    
    GSAssert(!pList->pGifTag);
    
    pGifTag = (GSGifTagT *)pList->pPtr++;
    
    // set giftag A-D here
    pGifTag->nloop = 0;
    pGifTag->tag0  = 0;
    pGifTag->tag1  = 0x10000000;
    pGifTag->regs  = 0xE;
    
    // set active giftag
    pList->pGifTag = pGifTag;
}

void GSGifTagCloseAD()
{
    GSListT *pList = &_GSList_List;
    GSGifTagT *pGifTag = pList->pGifTag;
    Int32 nLoop;

    GSAssert(pList->pGifTag);

    // determine nloop (number of register written)
    nLoop = pList->pPtr - ((Uint128 *)pGifTag) - 1;
    
    // close giftag here (with eop)
    pGifTag->nloop = nLoop | 0x8000;
    
    // no active giftag
    pList->pGifTag = NULL;
}

void GSGifRegAD(Uint32 uAddr, Uint64 uData)
{
    GSListT *pList = &_GSList_List;
    Uint64 *pReg;

    GSAssert(pList->pGifTag);
    
    pReg = (Uint64 *)pList->pPtr++;
    
    pReg[0] = uData;
    pReg[1] = uAddr;
}





void GSGifTagOpen(Uint64 GifTag, Uint64 GifRegs)
{
    GSListT *pList = &_GSList_List;
    GSGifTagT *pGifTag;
    
    GSAssert(!pList->pGifTag);
    
    pGifTag = (GSGifTagT *)pList->pPtr++;
    
    // set giftag
    ((Uint64 *)pGifTag)[0] = GifTag;
    ((Uint64 *)pGifTag)[1] = GifRegs;
    
    // set active giftag
    pList->pGifTag  = pGifTag;
    pList->pGifData = (Uint64 *)pList->pPtr;
}

void GSGifReg(Uint64 uData)
{
    GSListT *pList = &_GSList_List;

    GSAssert(pList->pGifData);
    
    pList->pGifData[0] = uData;
    pList->pGifData++;
}

void GSGifTagCloseNLoop(Int32 nLoop)
{
    GSListT *pList = &_GSList_List;
    GSGifTagT *pGifTag = pList->pGifTag;

    GSAssert(pList->pGifTag);
    GSAssert(pList->pGifData);
    
    // round to next qword
    if (((Uint32)pList->pGifData) & 0x7)
    {
        *pList->pGifData++ = 0;
    }
    
    // update pointer
    pList->pPtr = (Uint128 *)pList->pGifData;

    // close giftag here (with eop)
    pGifTag->nloop = nLoop | 0x8000;
    
    // no active giftag
    pList->pGifTag  = NULL;
    pList->pGifData = NULL;
}


void GSGifTagClose(void)
{
    GSListT *pList = &_GSList_List;

    GSAssert(pList->pGifTag);
    GSAssert(pList->pGifData);
    
    // round to next qword
    if (((Uint32)pList->pGifData) & 0x7)
    {
        *pList->pGifData++ = 0;
    }
    
    // update pointer
    pList->pPtr = (Uint128 *)pList->pGifData;

    // no active giftag
    pList->pGifTag  = NULL;
    pList->pGifData = NULL;
}


