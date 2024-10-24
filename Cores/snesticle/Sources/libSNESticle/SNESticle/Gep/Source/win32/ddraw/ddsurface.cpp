
#include <ddraw.h>
#include "types.h"
#include "winddraw.h"
#include "ddsurface.h"
#include "console.h"

static void _DecomposeMask(Uint32 uMask, Uint8 &uShift, Uint8 &nBits)
{
	Uint32 uBit = 1;

	// get shift amount
	uShift=0;
	while ( !(uMask&uBit) && uBit)
	{
		uShift++;
		uBit<<=1;
	}
	uShift&=31;
	
	// get nBits
	nBits=0;
	while ( (uMask&uBit) && uBit)
	{
		nBits++;
		uBit<<=1;
	}
}

static void _ConvertPixelFormat(PixelFormatT *pFormat, DDPIXELFORMAT *pDDFormat)
{
	pFormat->eFormat     = PIXELFORMAT_CUSTOM;
	pFormat->bColorIndex = (pDDFormat->dwFlags & DDPF_PALETTEINDEXEDTO8) ? TRUE : FALSE;
	pFormat->uBitDepth   = (Uint8)pDDFormat->dwRGBBitCount;

	_DecomposeMask(pDDFormat->dwRBitMask, pFormat->uRedShift,   pFormat->uRedBits);
	_DecomposeMask(pDDFormat->dwGBitMask, pFormat->uGreenShift, pFormat->uGreenBits);
	_DecomposeMask(pDDFormat->dwBBitMask, pFormat->uBlueShift,  pFormat->uBlueBits);
	_DecomposeMask(0,                     pFormat->uAlphaShift, pFormat->uAlphaBits);
}


CDDSurface::CDDSurface()
{
	m_pSurface = NULL;
}

CDDSurface::~CDDSurface()
{
	Free();
}


void CDDSurface::Lock()
{
	if (m_pSurface)
	{
		DDSURFACEDESC ddsd;
		HRESULT err;
		ddsd.dwSize = sizeof(ddsd);

		if (m_pSurface->IsLost())
		{
			ConPrint("Surface restored\n");
			m_pSurface->Restore();
		}

		err = m_pSurface->Lock(NULL, &ddsd, DDLOCK_WAIT | DDLOCK_WRITEONLY | DDLOCK_SURFACEMEMORYPTR, NULL);
		if (err == DD_OK)
		{
			// surface is locked
			m_uHeight  = ddsd.dwHeight;
			m_uWidth   = ddsd.dwWidth;
			m_uPitch   = ddsd.lPitch;
			m_pData    = (Uint8 *)ddsd.lpSurface;
		}
	}
}

void CDDSurface::Unlock()
{
	if (m_pSurface)
	{
		m_pSurface->Unlock(m_pData);
	}
	m_pData   = NULL;
	m_uWidth  = 0;
	m_uHeight = 0;
	m_uPitch  = 0;
}


Bool CDDSurface::Alloc(Uint32 uWidth, Uint32 uHeight, DDPIXELFORMAT *pDDFormat)
{
	DDrawObjectT pDDO = DDrawGetObject();
	HRESULT err;
	DDSURFACEDESC ddsd;

	Free();

	memset(&ddsd, 0, sizeof(ddsd));
	ddsd.dwSize			= sizeof(ddsd);
	ddsd.dwFlags		= DDSD_CAPS | DDSD_HEIGHT | DDSD_WIDTH;
	ddsd.dwWidth		= uWidth;
	ddsd.dwHeight		= uHeight;
	ddsd.ddsCaps.dwCaps = DDSCAPS_OFFSCREENPLAIN| DDSCAPS_SYSTEMMEMORY;
//	ddsd.ddsCaps.dwCaps = DDSCAPS_OFFSCREENPLAIN| DDSCAPS_VIDEOMEMORY; 

	if (pDDFormat)
	{
		ddsd.dwFlags |= DDSD_PIXELFORMAT;
		ddsd.ddpfPixelFormat =*pDDFormat;
	}

	// create surface
	err = pDDO->CreateSurface(&ddsd, &m_pSurface, NULL);
	if (err!=DD_OK)
	{
		return FALSE;
	}

	if (m_pSurface)
	{
		DDBLTFX ddbltfx;
		DDSCAPS caps;

		memset(&ddbltfx, 0, sizeof(ddbltfx));
		ddbltfx.dwSize = sizeof(ddbltfx);
		ddbltfx.dwFillColor=0xFFFFFFF;
		m_pSurface->Blt(NULL, NULL, NULL, DDBLT_COLORFILL, &ddbltfx);

		m_pSurface->GetCaps(&caps);
//		if (caps.dwCaps & DDSCAPS_VIDEOMEMORY)	ConPrint("VIDMEM\n");
//		if (caps.dwCaps & DDSCAPS_SYSTEMMEMORY)	ConPrint("SYSMEM\n");

		// get pixel format
		m_pSurface->GetPixelFormat(&ddsd.ddpfPixelFormat);

		// convert pixel format
		_ConvertPixelFormat(&m_Format, &ddsd.ddpfPixelFormat);
	}

	return TRUE;
}

void CDDSurface::Free()
{
	if (m_pSurface)
	{
		m_pSurface->Release();
		m_pSurface = NULL;
	}
}













