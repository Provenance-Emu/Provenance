
#include "types.h"
#include "ps2dma.h"
#include "gs.h"

#define DMA_DEBUG (CODE_DEBUG || 1)

void DmaExecSprToRam(Uint128 *pMem, Uint128 *pSpr, Uint32 nQwords)
{
    D8_QWC  = nQwords;
    D8_MADR = (Uint32)pMem;
    D8_SADR = (Uint32)pSpr;
    D8_CHCR = DCHCR_M_STR;
    __asm__ __volatile__ ("sync.l");
}

void DmaSyncSprToRam()
{
    // sync
    while (D8_CHCR & DCHCR_M_STR) ;
}


void DmaExecRamToSpr(Uint128 *pMem, Uint128 *pSpr, Uint32 nQwords)
{
    D9_QWC  = nQwords;
    D9_MADR = (Uint32)pMem;
    D9_SADR = (Uint32)pSpr;
    D9_CHCR = DCHCR_M_STR;
    __asm__ __volatile__ ("sync.l");
}

void DmaSyncRamToSpr()
{
    // sync
    while (D9_CHCR & DCHCR_M_STR) ;
}


void DmaExecVIF0(Uint128 *pMem,  Uint32 nQwords)
{
    D0_QWC  = nQwords;
    D0_MADR = (Uint32)pMem;
    D0_CHCR = DCHCR_M_STR | DCHCR_M_DIR;
    __asm__ __volatile__ ("sync.l");
}

void DmaExecVIF0Chain(Uint128 *pTag)
{
    D0_QWC  = 0;
    D0_MADR = 0;
    D0_TADR = (Uint32)pTag;
    D0_CHCR = DCHCR_M_STR | DCHCR_M_DIR  | DCHCR_M_TTE | DCHCR_M_MOD_CHAIN;
    __asm__ __volatile__ ("sync.l");
}


void DmaSyncVIF0()
{
    // sync dma
    while (D0_CHCR & DCHCR_M_STR) ;

    // sync vif to ensure it is complete also
    while (VIF0_STAT & 3) ;
}




void DmaExecVIF1(Uint128 *pMem,  Uint32 nQwords)
{
    D1_QWC  = nQwords;
    D1_MADR = (Uint32)pMem;
    D1_CHCR = DCHCR_M_STR | DCHCR_M_DIR;
    __asm__ __volatile__ ("sync.l");
}

void DmaExecVIF1Chain(Uint128 *pTag)
{
    D1_QWC  = 0;
    D1_MADR = 0;
    D1_TADR = (Uint32)pTag;
    D1_CHCR = DCHCR_M_STR | DCHCR_M_DIR  | DCHCR_M_TTE | DCHCR_M_MOD_CHAIN;
    __asm__ __volatile__ ("sync.l");
}


void DmaSyncVIF1()
{
    // sync dma
    while (D1_CHCR & DCHCR_M_STR) ;

    // sync vif to ensure it is complete also
    while (VIF1_STAT & 3) ;
}



void DmaExecGIF(Uint128 *pMem,  Uint32 nQwords)
{
    D2_QWC  = nQwords;
    D2_MADR = (Uint32)pMem;
    D2_CHCR = DCHCR_M_STR | DCHCR_M_DIR;

    __asm__ __volatile__ ("sync.l");
}

void DmaExecGIFChain(Uint128 *pTag)
{
    D2_QWC  = 0;
    D2_MADR = 0;
    D2_TADR = (Uint32)pTag;
    D2_CHCR = DCHCR_M_STR | DCHCR_M_DIR |  DCHCR_M_MOD_CHAIN;
    __asm__ __volatile__ ("sync.l");
}


void DmaSyncGIF()
{
	int timeout=10*1000*1000;

    // sync dma
    while ((D2_CHCR & DCHCR_M_STR) && timeout > 0)
	{
		timeout--;
	}

	#if DMA_DEBUG 
	if (timeout < 0)
	{
		GS_BGCOLOUR = 0x0000FF;
	}
	#endif
}



