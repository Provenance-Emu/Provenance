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
#include <d3d9.h>
#include <stdio.h>
#include "VideoRend.h"

// Local variables
static int RendFrame = 0, RendWasInit = 0;
static int RendImgBpp = 0;
static int RendImgWidth = 0, RendImgHeight = 0;
static int RendWinWidth = 0, RendWinHeight = 0;
static D3DPRESENT_PARAMETERS d3dpp;
static LPDIRECT3D9 pD3D = NULL;
static LPDIRECT3DDEVICE9 pD3DDevice = NULL;
static LPDIRECT3DSURFACE9 pD3DSurface = NULL;

// Prototypes
int VideoRend_D3D_WasInit(void);
int VideoRend_D3D_Init(HWND hWnd, int width, int height, int fullscreen);
void VideoRend_D3D_Terminate(void);
void VideoRend_D3D_ResizeWin(int width, int height);
void VideoRend_D3D_GetPitch(int *bytpitch, int *pixpitch);
void VideoRend_D3D_ClearVideo(void);
int VideoRend_D3D_Lock(void **videobuffer);
void VideoRend_D3D_Unlock(void);
void VideoRend_D3D_Flip(HWND hWnd);
void VideoRend_D3D_Paint(HWND hWnd);

// Video was initialized?
int VideoRend_D3D_WasInit(void)
{
	return RendWasInit;
}

// Video initialize, return bpp
int VideoRend_D3D_Init(HWND hWnd, int width, int height, int fullscreen)
{
	D3DDISPLAYMODE d3ddm;
	RECT fsRect;

	// Create Direct3D object
	if ((pD3D = Direct3DCreate9(D3D_SDK_VERSION)) == NULL) {
		MessageBox(0, "Direct3DCreate9() Failed", "Direct3D", MB_ICONERROR);
		VideoRend_D3D_Terminate();
		return 0;
	}

	// Create Direct3D device
	ZeroMemory(&d3dpp, sizeof(d3dpp));
	d3dpp.Windowed = TRUE;
	d3dpp.hDeviceWindow = hWnd;
	d3dpp.SwapEffect = D3DSWAPEFFECT_DISCARD;
	d3dpp.BackBufferWidth = width;
	d3dpp.BackBufferHeight = height;
	d3dpp.BackBufferFormat = D3DFMT_UNKNOWN;
	d3dpp.Flags = D3DPRESENTFLAG_LOCKABLE_BACKBUFFER;
	d3dpp.PresentationInterval = D3DPRESENT_INTERVAL_IMMEDIATE;
	if FAILED(IDirect3D9_CreateDevice(pD3D, D3DADAPTER_DEFAULT, D3DDEVTYPE_HAL, hWnd,
		D3DCREATE_SOFTWARE_VERTEXPROCESSING | D3DCREATE_MULTITHREADED, &d3dpp, &pD3DDevice))
	{
		MessageBox(0, "CreateDevice Failed", "Direct3D", MB_ICONERROR);
		VideoRend_D3D_Terminate();
		return 0;
	}

	// Get BPP format
	IDirect3DDevice9_GetDisplayMode(pD3DDevice, 0, &d3ddm);
	switch (d3ddm.Format) {
		case D3DFMT_A8R8G8B8:
		case D3DFMT_X8R8G8B8:
			RendImgBpp = 32;
			break;
		case D3DFMT_A1R5G5B5:
		case D3DFMT_X1R5G5B5:
			// TODO BGR15 mode
			VideoRend_D3D_Terminate();
			return 0;
		case D3DFMT_R5G6B5:
			RendImgBpp = 16;
			break;
	}

	// Get backbuffer
	if FAILED(IDirect3DDevice9_GetBackBuffer(pD3DDevice, 0, 0, D3DBACKBUFFER_TYPE_MONO, &pD3DSurface)) {
		MessageBox(0, "Get Back-Buffer Failed", "Direct3D", MB_ICONERROR);
		VideoRend_D3D_Terminate();
		return 0;
	}

	// Disable Z-Buffer, Culling and Lighting
	IDirect3DDevice9_SetRenderState(pD3DDevice, D3DRS_ZENABLE, FALSE);
	IDirect3DDevice9_SetRenderState(pD3DDevice, D3DRS_CULLMODE, D3DCULL_NONE);
	IDirect3DDevice9_SetRenderState(pD3DDevice, D3DRS_LIGHTING, FALSE);

	// Fullscreen
	if (fullscreen) {
		GetWindowRect(GetDesktopWindow(), &fsRect);
		MoveWindow(hWnd, 0, 0, fsRect.right, fsRect.bottom, 0);
	}

	// Clear video and set specs
	RendImgWidth = width;
	RendImgHeight = height;
	RendWasInit = 1;
	VideoRend_D3D_ClearVideo();
	return RendImgBpp;
}

// Video terminate
void VideoRend_D3D_Terminate(void)
{
	if (pD3DSurface) {
		IDirect3DSurface9_Release(pD3DSurface);
		pD3DSurface = NULL;
	}
	if (pD3DDevice) {
		IDirect3DDevice9_Release(pD3DDevice);
		pD3DDevice = NULL;
	}
	if (pD3D) {
		IDirect3D9_Release(pD3D);
		pD3D = NULL;
	}
	RendWasInit = 0;
}

// Window resize
void VideoRend_D3D_ResizeWin(int width, int height)
{
	RendWinWidth = width;
	RendWinHeight = height;
}

// Get pitch in bytes and pixels
void VideoRend_D3D_GetPitch(int *bytpitch, int *pixpitch)
{
	D3DLOCKED_RECT pLockedRect;
	if (!RendWasInit) return;
	IDirect3DSurface9_LockRect(pD3DSurface, &pLockedRect, NULL, 0);
	IDirect3DSurface9_UnlockRect(pD3DSurface);
	*bytpitch = pLockedRect.Pitch;
	if (RendImgBpp == 32) *pixpitch = pLockedRect.Pitch >> 2;
	else *pixpitch = pLockedRect.Pitch >> 1;
}

// Clear video, do not call inside locked buffer
void VideoRend_D3D_ClearVideo(void)
{
	if (!RendWasInit) return;
	IDirect3DDevice9_Clear(pD3DDevice, 0, NULL, D3DCLEAR_TARGET, D3DCOLOR_XRGB(0, 0, 0), 1.0f, 0);
}

// Lock video buffer, return true on success
int VideoRend_D3D_Lock(void **videobuffer)
{
	D3DLOCKED_RECT pLockedRect;
	if (!RendWasInit) return 0;
	if FAILED(IDirect3DSurface9_LockRect(pD3DSurface, &pLockedRect, NULL, 0)) return 0;
	*videobuffer = (void *)pLockedRect.pBits;
	return 1;
}

// Unlock video buffer
void VideoRend_D3D_Unlock(void)
{
	if (!RendWasInit) return;
	IDirect3DSurface9_UnlockRect(pD3DSurface);
}

// Flip and render to window
void VideoRend_D3D_Flip(HWND hWnd)
{
	POINT pointD = {0, 0};
	RECT rDst = {0, 0, RendWinWidth, RendWinHeight};
	HRESULT hr;
	if (!RendWasInit) return;
	hr = IDirect3DDevice9_TestCooperativeLevel(pD3DDevice);
	if (hr == D3DERR_DEVICENOTRESET) {
		hr = IDirect3DDevice9_Reset(pD3DDevice, &d3dpp);
	}
	if (hr == D3D_OK) {
		IDirect3DDevice9_Present(pD3DDevice, NULL, &rDst, NULL, NULL);
	}
}

// Window requesting painting
void VideoRend_D3D_Paint(HWND hWnd)
{
	VideoRend_D3D_Flip(hWnd);
	ValidateRect(hWnd, NULL);
}

// Video render driver
const TVideoRend VideoRend_D3D = {
	VideoRend_D3D_WasInit,
	VideoRend_D3D_Init,
	VideoRend_D3D_Terminate,
	VideoRend_D3D_ResizeWin,
	VideoRend_D3D_GetPitch,
	VideoRend_D3D_ClearVideo,
	VideoRend_D3D_Lock,
	VideoRend_D3D_Unlock,
	VideoRend_D3D_Flip,
	VideoRend_D3D_Paint
};
