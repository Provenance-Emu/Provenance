
#define INITGUID
#include <windows.h>
#include "types.h"
#include "winddraw.h"
#include "window.h"
#include "console.h"
#include "ddsurface.h"

#define DDRAW_RELEASE(__pObj) if (__pObj) {(__pObj)->Release(); (__pObj)=NULL;}

// direct draw objects
static DDrawObjectT			_DDraw_pObject=NULL;	// direct draw 2.0 object

// direct draw surfaces
static LPDIRECTDRAWSURFACE _DDraw_pPrimary;
static LPDIRECTDRAWSURFACE _DDraw_pBackBuffer;

// clipper for primary surface
static LPDIRECTDRAWCLIPPER _DDraw_pClipper;

static DDPIXELFORMAT _DDraw_PixelFormat;

DDrawObjectT DDrawGetObject()
{
	return _DDraw_pObject;
}


Bool DDrawInit()
{
	LPDIRECTDRAW pDDO1;	// direct draw 1.0 object

	//create ddraw object
	if (DirectDrawCreate(NULL,&pDDO1,NULL)==DD_OK)
	{
		if (pDDO1->QueryInterface(IID_IDirectDraw2, (LPVOID *) &_DDraw_pObject)==DD_OK)
		{
			pDDO1->Release();
			return TRUE;
		}
		pDDO1->Release();
	}

	return FALSE;	
}

void DDrawShutdown()
{
	if (_DDraw_pObject)
	{
		_DDraw_pObject->Release();
		_DDraw_pObject = NULL;
	}
}

Bool DDrawSetFullScreen(Uint32 ScrX, Uint32 ScrY, Uint32 BitDepth, Uint32 Flags)
{
	return FALSE;
}

Bool DDrawSetWindowed(HWND hWnd, Uint32 Flags)
{
	DDrawObjectT pDDO = DDrawGetObject();
	HRESULT	err;
	DDSURFACEDESC   ddsd;
	
	// set cooperative mode 
	if ((err=pDDO->SetCooperativeLevel( hWnd,DDSCL_NORMAL | DDSCL_ALLOWREBOOT))!=DD_OK)
	{
		ConError("Unable to set DirectDraw cooperative level");
		return FALSE;
	}

	// get primary surface
	memset(&ddsd,0,sizeof(ddsd));
	ddsd.dwSize = sizeof ( ddsd );
	ddsd.dwFlags = DDSD_CAPS;
	ddsd.ddsCaps.dwCaps = DDSCAPS_PRIMARYSURFACE;
	if ((err=pDDO->CreateSurface( &ddsd,&_DDraw_pPrimary, NULL ))!=DD_OK)
	{
		ConError("Unable to create ddraw primary surface"); 
		return FALSE;
	}

	// create clipper
	pDDO->CreateClipper(0,&_DDraw_pClipper,NULL);
	_DDraw_pClipper->SetHWnd(0,hWnd); //clip to our window
	if (_DDraw_pPrimary->SetClipper(_DDraw_pClipper)!=DD_OK)
	{
		ConError("Unable to set clipper"); 
		return FALSE;
	}

	// get pixel format of primary
	_DDraw_PixelFormat.dwSize = sizeof(_DDraw_PixelFormat);
	if (_DDraw_pPrimary->GetPixelFormat(&_DDraw_PixelFormat)!=DD_OK)
	{
		ConError("Unable to get pixel format"); 
		return FALSE;
	}

	return TRUE;
}

void DDrawWaitVBlank()
{
	_DDraw_pObject->WaitForVerticalBlank(DDWAITVB_BLOCKBEGIN, NULL);
}

void DDrawBltFrame(RECT *pDestRect, CDDSurface *pSurface)
{
	LPDIRECTDRAWSURFACE pSrc;
	LPDIRECTDRAWSURFACE pDest;

	pSrc  =	pSurface->GetDDSurface();
	pDest = _DDraw_pPrimary;

	if (pSrc && pDest)
	{
		// blit
		pDest->Blt(pDestRect, pSrc, NULL, DDBLT_WAIT, NULL);
	}
}

struct _DDPIXELFORMAT *DDrawGetPixelFormat()
{
	return &_DDraw_PixelFormat;
}
	
