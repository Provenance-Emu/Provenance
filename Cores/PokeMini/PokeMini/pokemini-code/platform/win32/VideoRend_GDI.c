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
#include "VideoRend.h"

// Local variables
static int RendFrame = 0, RendWasInit = 0;
static int RendImgWidth = 0, RendImgHeight = 0;
static int RendWinWidth = 0, RendWinHeight = 0;
static HBITMAP RendBitmap[2] = {NULL, NULL};
static HDC RendHDC[2] = {NULL, NULL};
static void *RendVideoBuff[2] = {NULL, NULL};

// Prototypes
int VideoRend_GDI_WasInit(void);
int VideoRend_GDI_Init(HWND hWnd, int width, int height, int fullscreen);
void VideoRend_GDI_Terminate(void);
void VideoRend_GDI_ResizeWin(int width, int height);
void VideoRend_GDI_GetPitch(int *bytpitch, int *pixpitch);
void VideoRend_GDI_ClearVideo(void);
int VideoRend_GDI_Lock(void **videobuffer);
void VideoRend_GDI_Unlock(void);
void VideoRend_GDI_Flip(HWND hWnd);
void VideoRend_GDI_Paint(HWND hWnd);

// Video was initialized?
int VideoRend_GDI_WasInit(void)
{
	return RendWasInit;
}

// Video initialize
int VideoRend_GDI_Init(HWND hWnd, int width, int height, int fullscreen)
{
	BITMAPINFO BitmapInfo;
	RECT fsRect;

	// Bitmap Structure
	BitmapInfo.bmiHeader.biSize = sizeof(BitmapInfo.bmiHeader);
	BitmapInfo.bmiHeader.biWidth = width;
	BitmapInfo.bmiHeader.biHeight = -height;
	BitmapInfo.bmiHeader.biPlanes = 1;
	BitmapInfo.bmiHeader.biBitCount = 32;
	BitmapInfo.bmiHeader.biCompression = BI_RGB;
	BitmapInfo.bmiHeader.biSizeImage = 0;
	BitmapInfo.bmiHeader.biXPelsPerMeter = 96;
	BitmapInfo.bmiHeader.biYPelsPerMeter = 96;
	BitmapInfo.bmiHeader.biClrUsed = 0;
	BitmapInfo.bmiHeader.biClrImportant = 0;
	RendHDC[0] = CreateCompatibleDC(NULL);
	RendHDC[1] = CreateCompatibleDC(NULL);
	if (!RendHDC[0] || !RendHDC[1]) {
		MessageBox(0, "Can't create compatible DC", "GDI Video", MB_OK | MB_ICONERROR);
		VideoRend_GDI_Terminate();
		return 0;
	}

	// Create DIB Bitmap
	RendImgWidth = width;
	RendImgHeight = height;
	RendBitmap[0] = CreateDIBSection(RendHDC[0], &BitmapInfo, DIB_RGB_COLORS, (void **)&RendVideoBuff[0], NULL, 0);
	RendBitmap[1] = CreateDIBSection(RendHDC[1], &BitmapInfo, DIB_RGB_COLORS, (void **)&RendVideoBuff[1], NULL, 0);
	if (!RendBitmap[0] || !RendBitmap[1]) {
		MessageBox(0, "Can't create bitmap", "GDI Video", MB_OK | MB_ICONERROR);
		VideoRend_GDI_Terminate();
		return 0;
	}

	// Assign DIB Bitmap into the device
	GdiFlush();
	SelectObject(RendHDC[0], RendBitmap[0]);
	SelectObject(RendHDC[1], RendBitmap[1]);

	// Fullscreen
	if (fullscreen) {
		GetWindowRect(GetDesktopWindow(), &fsRect);
		MoveWindow(hWnd, 0, 0, fsRect.right, fsRect.bottom, 0);
	}

	// Clear the image
	RendFrame = 0;
	RendWasInit = 1;
	VideoRend_GDI_ClearVideo();
	VideoRend_GDI_Flip(hWnd);
	VideoRend_GDI_ClearVideo();

	return 32;
}

// Video terminate
void VideoRend_GDI_Terminate(void)
{
	if (RendBitmap[0]) DeleteObject(RendBitmap[0]);
	if (RendBitmap[1]) DeleteObject(RendBitmap[1]);
	if (RendHDC[0]) DeleteDC(RendHDC[0]);
	if (RendHDC[1]) DeleteDC(RendHDC[1]);
	RendWasInit = 0;
}

// Window resize
void VideoRend_GDI_ResizeWin(int width, int height)
{
	RendWinWidth = width;
	RendWinHeight = height;
}

// Get pitch in bytes and pixels
void VideoRend_GDI_GetPitch(int *bytpitch, int *pixpitch)
{
	*bytpitch = RendImgWidth * 4;
	*pixpitch = RendImgWidth;
}

// Clear video, do not call inside locked buffer
void VideoRend_GDI_ClearVideo(void)
{
	if (!RendWasInit) return;
	ZeroMemory(RendVideoBuff[RendFrame], RendImgWidth * RendImgHeight * 4);
}

// Lock video buffer, return true on success
int VideoRend_GDI_Lock(void **videobuffer)
{
	if (!RendWasInit) return 0;
	*videobuffer = RendVideoBuff[RendFrame];
	return 1;
}

// Unlock video buffer
void VideoRend_GDI_Unlock(void)
{
}

// Flip and render to window
void VideoRend_GDI_Flip(HWND hWnd)
{
	HDC hdc;
	if (!RendWasInit) return;

	RendFrame ^= 1;
	hdc = GetDC(hWnd);
	StretchBlt(hdc, 0, 0, RendWinWidth, RendWinHeight, RendHDC[RendFrame^1], 0, 0, RendImgWidth, RendImgHeight, SRCCOPY);
	ReleaseDC(hWnd, hdc);
}

// Window requesting painting
void VideoRend_GDI_Paint(HWND hWnd)
{
	PAINTSTRUCT ps;
	HDC hdc;
	if (!RendWasInit) return;

	hdc = BeginPaint(hWnd, &ps);
	StretchBlt(hdc, 0, 0, RendWinWidth, RendWinHeight, RendHDC[RendFrame^1], 0, 0, RendImgWidth, RendImgHeight, SRCCOPY);
	EndPaint(hWnd, &ps);
}

// Video render driver
const TVideoRend VideoRend_GDI = {
	VideoRend_GDI_WasInit,
	VideoRend_GDI_Init,
	VideoRend_GDI_Terminate,
	VideoRend_GDI_ResizeWin,
	VideoRend_GDI_GetPitch,
	VideoRend_GDI_ClearVideo,
	VideoRend_GDI_Lock,
	VideoRend_GDI_Unlock,
	VideoRend_GDI_Flip,
	VideoRend_GDI_Paint
};
