
#ifndef _GSLIST_H
#define _GSLIST_H

typedef struct
{
    Uint16 nloop;
    Uint16 tag0;
    Uint32 tag1;
    Uint64 regs;
} GSGifTagT;


typedef int (*GSListFlushFuncT)(void);


void  GSListBegin(Uint128 *pList, Uint32 nQwords, GSListFlushFuncT pFunc);
Int32 GSListEnd();

Int32 GSListSpace(Uint32 nMinQwords);


void GSListSetPtr(Uint128 *pPtr);
Uint128 *GSListGetPtr();
Uint128 *GSListGetUncachedPtr();
Uint128 *GSListGetStart();
Int32 GSListGetSize();
Int32 GSListGetSpace();

void GSDmaCntOpen();
void GSDmaCntClose();
void GSDmaRef(Uint128 *pRefAddr, Uint32 nQwords);
void GSDmaEnd();
void GSDmaCall(Uint128 *pTag);
void GSDmaRet();

// image gif tag
void GSGifTagImage(Uint32 nQwords);

// gif tag packed A-D pairs
void GSGifTagOpenAD();
void GSGifRegAD(Uint32 uAddr, Uint64 uData);
void GSGifTagCloseAD();

// gif tag 
void GSGifTagOpen(Uint64 GifTag, Uint64 GifRegs);
void GSGifReg(Uint64 uData);
void GSGifTagClose(void);
void GSGifTagCloseNLoop(Int32 nLoop);


#endif

