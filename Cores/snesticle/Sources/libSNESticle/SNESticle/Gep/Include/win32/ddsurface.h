

#ifndef _DDSURFACE_H
#define _DDSURFACE_H

#include "surface.h"
#include "rendersurface.h"

class CDDSurface : public CRenderSurface
{
	struct IDirectDrawSurface	*m_pSurface;

public:
	CDDSurface();
	~CDDSurface();

	Bool Alloc(Uint32 uWidth, Uint32 uHeight, struct _DDPIXELFORMAT *pDDFormat);
	void Free();

	virtual void Lock();
	virtual void Unlock();

	struct IDirectDrawSurface	*GetDDSurface() {return m_pSurface;}
};

#endif
