
#ifndef _RENDERSURFACE_H
#define _RENDERSURFACE_H

#include "surface.h"

class CRenderSurface : public CSurface
{
	PaletteT		m_Palette[SURFACE_MAXPALETTES];	// global palette for this pixel format

	PaletteT		m_Clut;			
	Int32			m_iPalette;

public:
	CRenderSurface();
	
	void	RenderLine(Int32 iLine, Uint8 *pLine, Int32 nPixels, Int32 Offset = 0);
	void	RenderLine32(Int32 iLine, Uint32 *pLine, Int32 nPixels);

	PaletteT *GetClut() {return &m_Clut;}

	void	ResetClut();
	void	SetClutEntries(Uint8 *pEntries, Int32 iEntry, Int32 nEntries);

	PaletteT	*GetPalette(Int32 iPalette) {return &m_Palette[iPalette];}
	void	SetPalette(Int32 iPalette) {m_iPalette = iPalette;}
	void	SetPaletteEntries(Int32 iPalette, Color32T *pEntries, Int32 nEntries);
};

#endif


