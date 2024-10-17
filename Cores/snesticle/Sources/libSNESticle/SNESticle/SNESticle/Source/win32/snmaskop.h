

#ifndef _SNMASKOP_H
#define _SNMASKOP_H

void SNMaskRange(SNMaskT *pMask, Uint32 uLeft, Uint32 uRight, bool bInvert);
void SNMaskRight(SNMaskT *pMask, Int32 iPos);
void SNMaskLeft(SNMaskT *pMask, Int32 iPos);

void SNMaskSHR(SNMaskT *pDestMask, const Uint8 *pSrcMask, Int32 nBits);
void SNMaskSHL(SNMaskT *pDestMask, const Uint8 *pSrcMask, Int32 nBits);

void SNMaskClear(SNMaskT *pDest);
void SNMaskSet(SNMaskT *pDest);
void SNMaskCopy(SNMaskT *pDest, const SNMaskT *pSrc);

void SNMaskNOT(SNMaskT *pDest, const SNMaskT *pSrc);
void SNMaskAND(SNMaskT *pDest, const SNMaskT *pSrcA, const SNMaskT *pSrcB);
void SNMaskANDN(SNMaskT *pDest, const SNMaskT *pSrcA, const SNMaskT *pSrcB);
void SNMaskOR(SNMaskT *pDest, const SNMaskT *pSrcA, const SNMaskT *pSrcB);
void SNMaskXOR(SNMaskT *pDest, const SNMaskT *pSrcA, const SNMaskT *pSrcB);
void SNMaskXNOR(SNMaskT *pDest, const SNMaskT *pSrcA, const SNMaskT *pSrcB);

void SNMaskBool(SNMaskT *pDest, const SNMaskT *pSrc, bool bVal);


#endif
