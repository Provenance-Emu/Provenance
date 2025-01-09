
#ifndef _SNPPUBLEND_C_H
#define _SNPPUBLEND_C_H


#include "snppublend.h"

class SNPPUBlendC : public ISNPPUBlend
{
public:
    virtual void Begin(class CRenderSurface *pTarget);
    virtual void Exec(SNPPUBlendInfoT *pInfo, Int32 iLine, Uint32 uFixedColor32, SNMaskT *pColorMask, Bool bAddSub, Uint32 uIntensity);
    virtual void Clear(SNPPUBlendInfoT *pInfo, Int32 iLine);
    virtual void End();
    virtual void UpdatePalette(SNPPUBlendInfoT *pInfo, Uint16 *pCGRam, Uint32 uIntensity);
    virtual void UpdatePaletteEntry(SNPPUBlendInfoT *pInfo, Uint32 uAddr, Uint32 uData, Uint32 uIntensity);
};



#endif
