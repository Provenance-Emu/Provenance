
#ifndef _PS2DMA_H
#define _PS2DMA_H

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */


typedef struct
{
    Uint16 qwc;
    Uint16 id;
    Uint32 addr;
    Uint32 pad[2];
} DmaTagT;


#define DMA_TAG_REFE 0x0000
#define DMA_TAG_CNT  0x1000
#define DMA_TAG_NEXT 0x2000
#define DMA_TAG_REF  0x3000
#define DMA_TAG_REFS 0x4000
#define DMA_TAG_CALL 0x5000
#define DMA_TAG_RET  0x6000
#define DMA_TAG_END  0x7000

#define D0_CHCR *((volatile Uint32 *)(0x10008000))
#define D0_MADR *((volatile Uint32 *)(0x10008010))
#define D0_QWC  *((volatile Uint32 *)(0x10008020))
#define D0_TADR *((volatile Uint32 *)(0x10008030))
#define D0_ASR0 *((volatile Uint32 *)(0x10008040))
#define D0_ASR1 *((volatile Uint32 *)(0x10008050))

#define D1_CHCR *((volatile Uint32 *)(0x10009000))
#define D1_MADR *((volatile Uint32 *)(0x10009010))
#define D1_QWC  *((volatile Uint32 *)(0x10009020))
#define D1_TADR *((volatile Uint32 *)(0x10009030))
#define D1_ASR0 *((volatile Uint32 *)(0x10009040))
#define D1_ASR1 *((volatile Uint32 *)(0x10009050))

#define D2_CHCR *((volatile Uint32 *)(0x1000A000))
#define D2_MADR *((volatile Uint32 *)(0x1000A010))
#define D2_QWC  *((volatile Uint32 *)(0x1000A020))
#define D2_TADR *((volatile Uint32 *)(0x1000A030))
#define D2_ASR0 *((volatile Uint32 *)(0x1000A040))
#define D2_ASR1 *((volatile Uint32 *)(0x1000A050))

#define D8_CHCR *((volatile Uint32 *)(0x1000D000))
#define D8_MADR *((volatile Uint32 *)(0x1000D010))
#define D8_QWC  *((volatile Uint32 *)(0x1000D020))
#define D8_SADR *((volatile Uint32 *)(0x1000D080))

#define D9_CHCR *((volatile Uint32 *)(0x1000D400))
#define D9_MADR *((volatile Uint32 *)(0x1000D410))
#define D9_QWC  *((volatile Uint32 *)(0x1000D420))
#define D9_TADR *((volatile Uint32 *)(0x1000D430))
#define D9_SADR *((volatile Uint32 *)(0x1000D480))


#define DCHCR_S_DIR  (0)
#define DCHCR_S_MOD  (2)
#define DCHCR_S_ASP  (4)
#define DCHCR_S_TTE  (6)
#define DCHCR_S_TIE  (7)
#define DCHCR_S_STR  (8)
#define DCHCR_S_TAG  (16)

#define DCHCR_M_DIR  (1<<DCHCR_S_DIR)
#define DCHCR_M_MOD  (3<<DCHCR_S_MOD)
#define DCHCR_M_ASP  (3<<DCHCR_S_ASP)
#define DCHCR_M_TTE  (1<<DCHCR_S_TTE)
#define DCHCR_M_TIE  (1<<DCHCR_S_TIE)
#define DCHCR_M_STR  (1<<DCHCR_S_STR)
#define DCHCR_M_TAG  (1<<DCHCR_S_TAG)

#define DCHCR_M_MOD_NORMAL      (0<<DCHCR_S_MOD)
#define DCHCR_M_MOD_CHAIN       (1<<DCHCR_S_MOD)
#define DCHCR_M_MOD_INTERLEAVE  (2<<DCHCR_S_MOD)


#define VIF0_STAT *((volatile Uint32 *)(0x10003800))
#define VIF1_STAT *((volatile Uint32 *)(0x10003C00))
#define GIF_STAT  *((volatile Uint32 *)(0x10003020))


void DmaExecSprToRam(Uint128 *pMem, Uint128 *pSpr, Uint32 nQwords);
void DmaSyncSprToRam();


void DmaExecRamToSpr(Uint128 *pMem, Uint128 *pSpr, Uint32 nQwords);
void DmaSyncRamToSpr();

void DmaExecVIF0(Uint128 *pMem,  Uint32 nQwords);
void DmaExecVIF0Chain(Uint128 *pTag);
void DmaSyncVIF0();

void DmaExecVIF1(Uint128 *pMem,  Uint32 nQwords);
void DmaExecVIF1Chain(Uint128 *pTag);
void DmaSyncVIF1();

void DmaExecGIF(Uint128 *pMem,  Uint32 nQwords);
void DmaExecGIFChain(Uint128 *pTag);
void DmaSyncGIF();


#ifdef __cplusplus
}
#endif /* __cplusplus */


#endif




