// double buffered GIF path-3 graphics fifo 

#include <tamtypes.h>
#include <kernel.h>
#include "types.h"
#include "gs.h"
#include "gslist.h"
#include "ps2dma.h"
#include "gpfifo.h"

static Uint128 *_GPFifo_pLists[2];
static Uint32  _GPFifo_nListQwords;
static Uint32  _GPFifo_iCurList;
static Bool    _GPFifo_bDumpList = FALSE;

static void _GPFifoDumpList()
{
    Uint32 *pStart, *pEnd;
    
    pStart = (Uint32 *)GSListGetStart();
    pEnd   = (Uint32 *)GSListGetPtr();
    
    printf("GPFifo: List %08X -> %08X\n", (Uint32)pStart, (Uint32)pEnd);
    
    while (pStart < pEnd)
    {
        printf("%08X: %08X %08X %08X %08X\n", 
            (Uint32)pStart, 
            pStart[0],
            pStart[1],
            pStart[2],
            pStart[3]
            );
            
        pStart+=4;            
    }
}
//
//
//

void GPFifoFlush()
{
    GPFifoPause();
    GPFifoResume();
}

void GPFifoPause()
{
    // close current dma cnt
    GSDmaCntClose();
    
    // add end tag
    GSDmaEnd();

    if (_GPFifo_bDumpList)
    {
        _GPFifoDumpList();
    }
    
    // end list
    GSListEnd();

    // flush cache
    FlushCache(0);
    
    // wait for previous dma to finish
    DmaSyncGIF();
    
    // transfer current list
    DmaExecGIFChain(_GPFifo_pLists[_GPFifo_iCurList]);
    
    // swap lists
    _GPFifo_iCurList ^=1;
}

void GPFifoResume()
{
    // start new list
    GSListBegin(_GPFifo_pLists[_GPFifo_iCurList], _GPFifo_nListQwords, (GSListFlushFuncT)GPFifoFlush);

    // open a dma cnt
    GSDmaCntOpen();
}

void GPFifoSync()
{
    // wait for previous dma to finish
    DmaSyncGIF();
}


Uint64 *GPFifoOpen(Uint32 nMinQwords)
{
    if (GSListSpace(nMinQwords))
    {
        return (Uint64 *)GSListGetPtr();
    } else
    {
        return NULL;
    }
}

void GPFifoClose(Uint64 *pPtr)
{
    GSListSetPtr((Uint128 *)pPtr);
}


void GPFifoInit(Uint128 *pMem, Int32 nBytes)
{
    assert( !(((Uint32)pMem)&0xF) );
    
    // calculate size of each list
    _GPFifo_nListQwords = (nBytes / sizeof(Uint128)) / 2;

    // set address of each list    
    _GPFifo_pLists[0] = pMem;
    _GPFifo_pLists[1] = pMem + _GPFifo_nListQwords;

    _GPFifo_iCurList = 0;
    
	GPFifoResume();
    
    printf("GPFifo: Init %08X %08X (%d qwords)\n", 
        (Uint32)_GPFifo_pLists[0],
        (Uint32)_GPFifo_pLists[1],
        _GPFifo_nListQwords
        );
}

void GPFifoShutdown()
{
//    GPFifoSync();

    printf("GPFifo: Shutdown\n" );
}


