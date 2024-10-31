
#ifndef _VRAM_H
#define _VRAM_H

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */


typedef struct VramBlock_t
{
	Uint16 uAddr;
	Uint16 uSize;
} VramBlockT;

void VramInit();
void VramShutdown();

VramBlockT *VramAlloc(Uint16 uSize, Uint32 uAlignment);
void VramFree(VramBlockT *pBlock);

Uint32 VramCalcTextureSize(Uint32 uWidth, Uint32 uHeight, Uint32 eFormat);

#ifdef __cplusplus
}
#endif /* __cplusplus */


#endif

