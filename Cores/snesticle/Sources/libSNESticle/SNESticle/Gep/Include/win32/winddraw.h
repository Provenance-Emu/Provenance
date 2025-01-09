
#ifndef _WINDDRAW_H
#define _WINDDRAW_H

#include <ddraw.h>

typedef LPDIRECTDRAW2 DDrawObjectT;

DDrawObjectT DDrawGetObject();
Bool DDrawInit();
void DDrawShutdown();

Bool DDrawSetFullScreen(Uint32 ScrX, Uint32 ScrY, Uint32 BitDepth, Uint32 Flags);
Bool DDrawSetWindowed(HWND hWnd, Uint32 Flags);
void DDrawBltFrame(RECT *pDestRect, class CDDSurface *pSurface);
void DDrawWaitVBlank();
struct _DDPIXELFORMAT *DDrawGetPixelFormat();

#endif
