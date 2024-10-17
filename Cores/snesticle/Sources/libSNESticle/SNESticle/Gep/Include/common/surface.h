
#ifndef _SURFACE_H
#define _SURFACE_H

#include "palette.h"
#include "pixelformat.h"

#define SURFACE_MAXPALETTES 16

class CSurface
{
protected:
	Uint8			*m_pMem;
	Uint8			*m_pData;
	Uint32			m_uWidth;
	Uint32			m_uHeight;
	Uint32			m_uPitch;
	Int32			m_iLineOffset;

	PixelFormatT	m_Format;		// pixel format for surface

public:
	CSurface();
	virtual ~CSurface();

	virtual void Lock();
	virtual void Unlock();

	Uint32		 GetWidth() {return m_uWidth;}
	Uint32		 GetHeight() {return m_uHeight;}
	PixelFormatT *GetFormat() {return &m_Format;}

	void	SetLineOffset(Int32 iLineOffset) {m_iLineOffset = iLineOffset;}
	Int32   GetLineOffset() {return m_iLineOffset;}

	Uint8	*GetLinePtr(Int32 iLine);
	void	ClearLine(Int32 iLine);
	void	Clear();	

    void    Set(Uint8 *pData, Uint32 uWidth, Uint32 uHeight, Uint32 uPitch, PixelFormatT *pFormat);
    void    Alloc(Uint32 uWidth, Uint32 uHeight, PixelFormatT *pFormat);
    void    Free();
};

typedef CSurface CMemSurface;

#endif


