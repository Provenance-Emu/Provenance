
#include <windows.h>
#include "types.h"
#include "console.h"
#include "window.h"
#include "mainloop.h"
#include "commctrl.h"

static HINSTANCE _WinMain_hInstance; //instance of running process
static CGepWin *_WinMain_pWin = NULL;
static HACCEL _WinMain_hAccel = NULL;

HINSTANCE WinMainGetInstance()
{
	return _WinMain_hInstance;
}

void WinMainSetAccelerator(HACCEL hAccel)
{
	_WinMain_hAccel = hAccel;
}

static Bool _WinMainPumpMessages(HWND hWnd, HACCEL hAccel)
{
	MSG  Msg;

	//process messages
	while (PeekMessage( &Msg, NULL, 0, 0,PM_REMOVE))
	{
		if (Msg.message == WM_QUIT)
		{
			return FALSE; 
		}

		if (!hAccel || !TranslateAccelerator(hWnd,hAccel,&Msg))
		{
			TranslateMessage(&Msg);
		}

		DispatchMessage(&Msg);
	}
	return TRUE;
}

void WinMainWaitMessage()
{
	WaitMessage();
}

void WinMainSetWin(CGepWin *pWin)
{
	_WinMain_pWin = pWin;
}



CGepWin *WinMainGetWin()
{
	return _WinMain_pWin;
}

int WINAPI WinMain (HINSTANCE hInstance, HINSTANCE hPrevInstance, PSTR szCmdLine, int iCmdShow)
{
	INITCOMMONCONTROLSEX cc;
	_WinMain_hInstance = hInstance;

	cc.dwSize = sizeof(cc);
	cc.dwICC  = ICC_WIN95_CLASSES;
	Bool bRet = InitCommonControlsEx(&cc);

	ConInit();
//	AllocConsole();

	if (MainLoopInit())
	{
		if (_WinMain_pWin)
		{
			_WinMain_pWin->ShowWindow(iCmdShow);

			while (_WinMainPumpMessages(_WinMain_pWin->GetWnd(), _WinMain_hAccel))
			{
				if (_WinMain_pWin->IsActive())
				{
					// do stuff here
					MainLoopProcess();
				}
				else
				{
					WaitMessage();
				}
			}
		}

		MainLoopShutdown();
	}

	ConShutdown();
	return 0;
}

