
#include <stdlib.h>
#include <string.h>
#include "types.h"
#include "memsurface.h"

//
// mem surface
//


CMemSurface::CMemSurface()
{
	m_pMem = NULL;

}

CMemSurface::~CMemSurface()
{
	Free();
}

void CMemSurface::Set(Uint8 *pData, Uint32 uWidth, Uint32 uHeight, Uint32 uPitch, PixelFormatT *pFormat)
{
	Free();

	// get pixel format
	if (pFormat)
	{
		// set pixel format
		m_Format = *pFormat;

		// set surface dimensions
		m_uWidth  = uWidth;
		m_uHeight = uHeight;
		m_uPitch  = uPitch;

		// set surface
		m_pData  = pData;
	}
}


void CMemSurface::Alloc(Uint32 uWidth, Uint32 uHeight, PixelFormatT *pFormat)
{
	Free();

	// get pixel format
	if (pFormat)
	{
		// set pixel format
		m_Format = *pFormat;

		// set surface dimensions
		m_uWidth  = uWidth;
		m_uHeight = uHeight;
		m_uPitch  = uWidth * m_Format.uBitDepth / 8;

		// allocate surface
		m_pMem   = (Uint8 *)malloc(m_uHeight * m_uPitch + 1);

		m_pData  = (Uint8 *)m_pMem;
	}
}

void CMemSurface::Free()
{
	if (m_pMem)
	{
		free(m_pMem);
		m_pMem   = NULL;
		memset(&m_Format, 0, sizeof(m_Format));
	}

	m_uWidth  = 0;
	m_uHeight = 0;
	m_uPitch  = 0;
	m_pData  = NULL;
}
