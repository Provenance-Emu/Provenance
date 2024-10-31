
#ifndef _WINMAIN_H
#define _WINMAIN_H

#include <windows.h>
#include "types.h"


HINSTANCE WinMainGetInstance();
void WinMainWaitMessage();
void WinMainSetWin(class CGepWin *pWin);
class CGepWin *WinMainGetWin();
void WinMainSetAccelerator(HACCEL hAccel);

#endif


