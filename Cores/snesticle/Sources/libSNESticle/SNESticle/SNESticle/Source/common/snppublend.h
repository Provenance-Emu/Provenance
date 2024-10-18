


#ifndef _SNPPUBLEND_H
#define _SNPPUBLEND_H

#include "palette.h"

#if CODE_PLATFORM == CODE_PS2

struct SNPPUBlendInfoT
{
    PaletteT    Pal[1] _ALIGN(16);
	Uint8	    uMain8[256] _ALIGN(64);
	Uint8	    uSub8[256] _ALIGN(16);
	Uint8	    uAttrib8[256] _ALIGN(64);
};
#else
struct SNPPUBlendInfoT
{
    PaletteT    Pal[4] _ALIGN(16);
    Uint32      uMain32[256] _ALIGN(16);
    Uint32      uSub32[256] _ALIGN(16);
    Uint32      uLine32[256] _ALIGN(16);

	Uint8	    uMain8[256] _ALIGN(64);
	Uint8	    uSub8[256] _ALIGN(16);
	Uint8	    uAttrib8[256] _ALIGN(64);
};


#endif

class ISNPPUBlend
{
protected:
    CRenderSurface *m_pTarget;

public:
    virtual void Begin(class CRenderSurface *pTarget)=0;
    virtual void Exec(SNPPUBlendInfoT *pInfo, Int32 iLine, Uint32 uFixedColor32, SNMaskT *pColorMask, Bool bAddSub, Uint32 uIntensity)=0;
    virtual void Clear(SNPPUBlendInfoT *pInfo, Int32 iLine)=0;
    virtual void End()=0;
    virtual void UpdatePalette(SNPPUBlendInfoT *pInfo, Uint16 *pCGRam, Uint32 uIntensity)=0;
    virtual void UpdatePaletteEntry(SNPPUBlendInfoT *pInfo, Uint32 uAddr, Uint32 uData, Uint32 uIntensity)=0;
};


#endif

