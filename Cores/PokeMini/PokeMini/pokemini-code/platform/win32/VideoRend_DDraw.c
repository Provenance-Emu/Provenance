/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2012  JustBurn

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <windows.h>
#include <stdio.h>
#include "VideoRend.h"

#ifdef NO_DIRECTDRAW

int VideoRend_DDraw_WasInit(void) { return 0; }
int VideoRend_DDraw_Init(HWND hWnd, int width, int height, int fullscreen) { return 0; }
void VideoRend_DDraw_Terminate(void) {}
void VideoRend_DDraw_ResizeWin(int width, int height) {}
void VideoRend_DDraw_GetPitch(int *bytpitch, int *pixpitch) {}
void VideoRend_DDraw_ClearVideo(void) {}
int VideoRend_DDraw_Lock(void **videobuffer) { return 0; }
void VideoRend_DDraw_Unlock(void) {}
void VideoRend_DDraw_Flip(HWND hWnd) {}
void VideoRend_DDraw_Paint(HWND hWnd) {}

#else

#include <ddraw.h>

// Local variables
static int RendFrame = 0, RendWasInit = 0;
static int RendImgBpp = 0;
static int RendImgWidth = 0, RendImgHeight = 0;
static int RendWinWidth = 0, RendWinHeight = 0;
LPDIRECTDRAW7 DD = NULL;
LPDIRECTDRAWSURFACE7 DDP = NULL;
LPDIRECTDRAWSURFACE7 DDB = NULL;
LPDIRECTDRAWCLIPPER DDC = NULL;	// DirectDraw classes
DDSURFACEDESC2 ddsd;			// Fast access to surface description

// Prototypes
int VideoRend_DDraw_WasInit(void);
int VideoRend_DDraw_Init(HWND hWnd, int width, int height, int fullscreen);
void VideoRend_DDraw_Terminate(void);
void VideoRend_DDraw_ResizeWin(int width, int height);
void VideoRend_DDraw_GetPitch(int *bytpitch, int *pixpitch);
void VideoRend_DDraw_ClearVideo(void);
int VideoRend_DDraw_Lock(void **videobuffer);
void VideoRend_DDraw_Unlock(void);
void VideoRend_DDraw_Flip(HWND hWnd);
void VideoRend_DDraw_Paint(HWND hWnd);

// Video was initialized?
int VideoRend_DDraw_WasInit(void)
{
	return RendWasInit;
}

// Video initialize, return bpp
int VideoRend_DDraw_Init(HWND hWnd, int width, int height, int fullscreen)
{
	DDPIXELFORMAT ddpf;
	char errormsg[256];
	RECT fsRect;

	// Create DirectDraw
	if FAILED(DirectDrawCreateEx(NULL, (VOID**)&DD, &IID_IDirectDraw7, NULL)) {
		MessageBox(0, "DirectDrawCreateEx() Failed", "DirectDraw", MB_ICONERROR);
		VideoRend_DDraw_Terminate();
		return 0;
	}

	// Get exclusive, fullscreen mode
	if FAILED(IDirectDraw7_SetCooperativeLevel(DD, hWnd, DDSCL_NORMAL)) {
		MessageBox(0, "Failed DirectDraw->SetCooperativeLevel", "DirectDraw", MB_ICONERROR);
		VideoRend_DDraw_Terminate();
		return 0;
	}

	// Create the primary surface
	ZeroMemory(&ddsd, sizeof(ddsd));
	ddsd.dwSize = sizeof(ddsd);
	ddsd.dwFlags = DDSD_CAPS;
	ddsd.ddsCaps.dwCaps = DDSCAPS_PRIMARYSURFACE; 
	if FAILED(IDirectDraw7_CreateSurface(DD, &ddsd, &DDP, NULL)) {
		MessageBox(0, "CreateSurface Failed", "DirectDraw", MB_ICONERROR);
		VideoRend_DDraw_Terminate();
		return 0;
	}

	// Create clipping (avoid graphics going outside window)
	if FAILED(IDirectDraw7_CreateClipper(DD, 0, &DDC, NULL)) {
		MessageBox(0, "CreateClipper Failed", "DirectDraw", MB_ICONERROR);
		VideoRend_DDraw_Terminate();
		return 0;
	}
	if FAILED(IDirectDrawClipper_SetHWnd(DDC, 0, hWnd)) {
		MessageBox(0, "Clipper SetHWnd Failed", "DirectDraw", MB_ICONERROR);
		VideoRend_DDraw_Terminate();
		return 0;
	}
	if FAILED(IDirectDrawSurface7_SetClipper(DDP, DDC)) {
		MessageBox(0, "SetClipper Failed", "DirectDraw", MB_ICONERROR);
		VideoRend_DDraw_Terminate();
		return 0;
	}

	// Create the back surface
	ZeroMemory(&ddsd, sizeof(ddsd));
	ddsd.dwSize = sizeof(ddsd);
	ddsd.dwFlags = DDSD_CAPS | DDSD_WIDTH | DDSD_HEIGHT;
	ddsd.ddsCaps.dwCaps = DDSCAPS_VIDEOMEMORY;
	ddsd.dwWidth = width;
	ddsd.dwHeight = height;
	if FAILED(IDirectDraw7_CreateSurface(DD, &ddsd, &DDB, NULL)) {
		MessageBox(0, "CreateSurface2 Failed", "DirectDraw", MB_ICONERROR);
		VideoRend_DDraw_Terminate();
		return 0;
	}

	// Fullscreen
	if (fullscreen) {
		GetWindowRect(GetDesktopWindow(), &fsRect);
		MoveWindow(hWnd, 0, 0, fsRect.right, fsRect.bottom, 0);
	}

	// Detect BPP of the back buffer
	ZeroMemory(&ddpf, sizeof(ddpf));
	ddpf.dwSize = sizeof(ddpf);
	IDirectDrawSurface7_GetPixelFormat(DDB, &ddpf);
	if (ddpf.dwRGBBitCount == 16) {
		// 16-Bits
		RendImgWidth = width;
		RendImgHeight = height;
		RendWasInit = 1;
		RendImgBpp = 16;
		VideoRend_DDraw_ClearVideo();
		return 16;
	} else if (ddpf.dwRGBBitCount == 32) {
		// 32-Bits
		RendImgWidth = width;
		RendImgHeight = height;
		RendWasInit = 1;
		RendImgBpp = 32;
		VideoRend_DDraw_ClearVideo();
		return 32;
	} else {
		// Unsupported
		sprintf_s(errormsg, 256, "Unsupported bits-per-pixels: %d Bits\nMust be 16 or 32.", ddpf.dwRGBBitCount);
		MessageBox(0, errormsg, "DirectX", MB_ICONERROR);
		VideoRend_DDraw_Terminate();
		return 0;
	}
}

// Video terminate
void VideoRend_DDraw_Terminate(void)
{
	if (DDB) {
		IDirectDrawSurface7_Release(DDB);
		DDB = NULL;
	}
	if (DDC) {
		IDirectDrawClipper_Release(DDC);
		DDC = NULL;
	}
	if (DDP) {
		IDirectDrawSurface7_Release(DDP);
		DDP = NULL;
	}
	if (DD) {
		IDirectDraw7_Release(DD);
		DD = NULL;
	}
	RendWasInit = 0;
}

// Window resize
void VideoRend_DDraw_ResizeWin(int width, int height)
{
	RendWinWidth = width;
	RendWinHeight = height;
}

// Get pitch in bytes and pixels
void VideoRend_DDraw_GetPitch(int *bytpitch, int *pixpitch)
{
	if (!RendWasInit) return;
	*bytpitch = ddsd.lPitch;
	*pixpitch = ddsd.lPitch * 8 / RendImgBpp;
}

// Clear video, do not call inside locked buffer
void VideoRend_DDraw_ClearVideo(void)
{
	if (!RendWasInit) return;
	if FAILED(IDirectDrawSurface7_Lock(DDB, NULL, &ddsd, DDLOCK_WAIT, NULL)) {
		IDirectDrawSurface7_Restore(DDB);
		return;
	}
	ZeroMemory(ddsd.lpSurface, ddsd.lPitch * ddsd.dwHeight);
	IDirectDrawSurface7_Unlock(DDB, NULL);
}

// Lock video buffer, return true on success
int VideoRend_DDraw_Lock(void **videobuffer)
{
	if (!RendWasInit) return 0;
	if FAILED(IDirectDrawSurface7_Lock(DDB, NULL, &ddsd, DDLOCK_WAIT, NULL)) {
		IDirectDrawSurface7_Restore(DDB);
		return 0;
	}
	*videobuffer = ddsd.lpSurface;
	return 1;
}

// Unlock video buffer
void VideoRend_DDraw_Unlock(void)
{
	if (!RendWasInit) return;
	IDirectDrawSurface7_Unlock(DDB, NULL);
}

// Flip and render to window
void VideoRend_DDraw_Flip(HWND hWnd)
{
	POINT pointD = {0, 0};
	RECT rSrc = {0, 0, RendImgWidth, RendImgHeight};
	RECT rDst = {0, 0, RendWinWidth, RendWinHeight};
	if (!RendWasInit) return;
	ClientToScreen(hWnd, &pointD);
	OffsetRect(&rDst, pointD.x, pointD.y);
	IDirectDrawSurface7_Blt(DDP, &rDst, DDB, &rSrc, DDBLT_WAIT, NULL);
}

// Window requesting painting
void VideoRend_DDraw_Paint(HWND hWnd)
{
	if (!RendWasInit) return;
	VideoRend_DDraw_Flip(hWnd);
	ValidateRect(hWnd, NULL);
}

#endif

// Video render driver
const TVideoRend VideoRend_DDraw = {
	VideoRend_DDraw_WasInit,
	VideoRend_DDraw_Init,
	VideoRend_DDraw_Terminate,
	VideoRend_DDraw_ResizeWin,
	VideoRend_DDraw_GetPitch,
	VideoRend_DDraw_ClearVideo,
	VideoRend_DDraw_Lock,
	VideoRend_DDraw_Unlock,
	VideoRend_DDraw_Flip,
	VideoRend_DDraw_Paint
};
