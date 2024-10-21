#include "GLideN64_Windows.h"

HWND		hWnd;
HWND		hStatusBar;
HWND		hToolBar;
HINSTANCE	hInstance;

BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD dwReason, LPVOID /*lpvReserved*/)
{
	hInstance = hinstDLL;

	return TRUE;
}
