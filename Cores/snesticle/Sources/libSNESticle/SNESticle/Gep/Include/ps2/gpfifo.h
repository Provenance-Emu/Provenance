
#ifndef _GPFIFO_H
#define _GPFIFO_H


void GPFifoFlush();
void GPFifoPause();
void GPFifoResume();

void GPFifoSync();
Uint64 *GPFifoOpen(Uint32 nMinQwords);
void GPFifoClose(Uint64 *pPtr);
void GPFifoInit(Uint128 *pMem, Int32 nBytes);
void GPFifoShutdown();
void GPFifoRect(unsigned x1, unsigned y1, unsigned c1, unsigned x2, unsigned y2, unsigned c2, unsigned z, unsigned abe);
void GPFifoEnableZBuf(void);
void GPFifoDisableZBuf(void);
void GPFifoTexRect(u32 x1, u32 y1, u32 u1, u32 v1, u32 x2, u32 y2, u32 u2, u32 v2, u32 z, u32 colour, unsigned abe);
void GPFifoSetTex(u32 tbp, u32 tbw, u32 texwidthlog2, u32 texheightlog2, u32 tpsm, u32 cbp, u32 cbw, u32 cpsm, int filter);
void GPFifoUploadTexture(int TBP, int TBW, int xofs, int yofs, int pxlfmt, void *tex, int wpxls, int hpxls);

#endif


