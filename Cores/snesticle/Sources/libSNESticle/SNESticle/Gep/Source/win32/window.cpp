

#include <windows.h>
#include "assert.h"
#include "types.h"
#include "console.h"
#include "winmain.h"
#include "window.h"
#include "commctrl.h"

static HWND _Win_hWnd;

LRESULT CALLBACK WinWndProc (HWND hWnd, UINT iMsg, WPARAM wParam, LPARAM lParam)
{
	CGepWin *pWin;

	pWin = (CGepWin *)GetWindowLong(hWnd, 0);

	if (pWin)
	{
		return pWin->OnMessage(iMsg, wParam, lParam);
	}
	return DefWindowProc(hWnd, iMsg, wParam, lParam);
}

LRESULT CGepWin::OnMessage(UINT iMsg, WPARAM wParam, LPARAM lParam)
{
	//ConPrint("%02X\n", iMsg);
	switch (iMsg)
	{
	case WM_ENTERMENULOOP:
		SetActive(FALSE);
		break;

	case WM_EXITMENULOOP:
		SetActive(TRUE);
		break;

	case WM_SIZE:
		OnSize(LOWORD(lParam), HIWORD(lParam));

		if (m_hWndStatus)
		{
			// resize status bar
			SendMessage(m_hWndStatus, iMsg, wParam, lParam);
		}
		break;

	case WM_LBUTTONUP:
		{
			Int32 x,y;
			x = LOWORD(lParam) / 2;
			y =	HIWORD(lParam) / 2;
			//ConDebug("mouse %03d,%03d cycles=%d\n", x, y, x / 8 * 32);
		}
		break;

	case WM_VSCROLL:
	//		OnVScroll(LOWORD(wParam), HIWORD(wParam));
		{
			Int32 iPos;
			iPos = GetScrollPos(GetWnd(), SB_VERT);
			OnVScroll(LOWORD(wParam), iPos);
		}
		break;

	case WM_KEYUP:
	case WM_SYSKEYUP:
		if (!(lParam & 0x40000000))
		{
			Uint32 ScanCode;
			Uint32 VirtKey;

			ScanCode=((lParam>>16) & 0xFF);
			VirtKey =LOWORD(wParam);
			
			OnKeyUp(ScanCode, VirtKey);
		}
		break;

	case WM_KEYDOWN:
	case WM_SYSKEYDOWN:
		{
			Uint32 ScanCode;
			Uint32 VirtKey;

			ScanCode=((lParam>>16) & 0xFF);
			VirtKey =LOWORD(wParam);
			
			OnKeyDown(ScanCode, VirtKey);
		}
		break;

	case WM_INITMENU:
		break;

	case WM_ACTIVATE:
		switch (LOWORD(wParam))
		{
		case WA_ACTIVE:
		case WA_CLICKACTIVE:
			SetActive(TRUE);
			break;
		case WA_INACTIVE:
			SetActive(FALSE);
			break;
		}
		return 0;

	case WM_PAINT:
		{
			//ConPrint("Paint");
			OnPaint();
//			ValidateRect(GetWnd(), NULL);
		}
		break;

	case WM_COMMAND:
		OnMenuCommand(LOWORD(wParam));
		break;

	case WM_DESTROY :
		OnDestroy();
		break;
	}

	return DefWindowProc(GetWnd(), iMsg, wParam, lParam) ;
}




Bool CGepWin::RegisterClass(HINSTANCE hInstance, Char *pClassName, LPCSTR pMenuName)
{
	WNDCLASS  WndClass;

 //   WndClass.cbSize        = sizeof (WndClass) ;
	WndClass.style         = 0;
	WndClass.lpfnWndProc   = WinWndProc;
	WndClass.cbClsExtra    = 0 ;
	WndClass.cbWndExtra    = sizeof(void *);
	WndClass.hInstance     = hInstance ;
	WndClass.hIcon         = NULL; //LoadIcon (hInstance, MAKEINTRESOURCE(IDI_ICON1)) ;
	WndClass.hCursor       = LoadCursor (NULL, IDC_ARROW) ;
	WndClass.hbrBackground = NULL; //(HBRUSH)GetStockObject(BLACK_BRUSH);
	WndClass.lpszMenuName  = pMenuName;
	WndClass.lpszClassName = pClassName;
	if (!::RegisterClass (&WndClass))
	{
		return FALSE;
	}

	return TRUE;
}

CGepWin::CGepWin()
{
	m_hWnd = NULL;
	m_hWndStatus = NULL;
	m_uStatusHeight = 0;
}

CGepWin::~CGepWin()
{

}

void CGepWin::Create(Char *pClassName, Char *pAppName, Uint32 uStyle, LPCSTR pMenuName)
{
	HINSTANCE hInstance = WinMainGetInstance();

	// register class
	RegisterClass(hInstance, pClassName, pMenuName);

	//create window for app
	m_hWnd = CreateWindowEx(
		0, //WS_EX_TOPMOST,
		pClassName, 
		pAppName,
		uStyle,
		CW_USEDEFAULT,
		CW_USEDEFAULT,
		CW_USEDEFAULT,
		CW_USEDEFAULT,
		NULL,
		NULL,
		hInstance, NULL );

	SetWindowLong(m_hWnd, 0, (LONG)this);
}

void CGepWin::Destroy()
{
	if (m_hWnd)
	{
		DestroyWindow(m_hWnd);
	}
}

void CGepWin::ShowWindow(int iCmdShow)
{
	::ShowWindow(m_hWnd, iCmdShow);
	UpdateWindow (m_hWnd) ;
	SetFocus(m_hWnd);
}

void CGepWin::SetTitle(Char *pTitle)
{
	SetWindowText(m_hWnd, pTitle);
}

void CGepWin::SetSize(Int32 Width, Int32 Height)
{
	RECT rect;

	if (m_hWndStatus)
	{
		RECT rectstatus;
		GetWindowRect(m_hWndStatus, &rectstatus);

		m_uStatusHeight = rectstatus.bottom - rectstatus.top - 1;
	}
	else
	{
		m_uStatusHeight = 0;
	}

	rect.left   = 0;
	rect.top    = 0;
	rect.right  = Width;
	rect.bottom = Height + m_uStatusHeight;

	AdjustWindowRectEx(&rect, GetWindowLong(m_hWnd, GWL_STYLE), TRUE, GetWindowLong(m_hWnd, GWL_EXSTYLE));
	SetWindowPos(m_hWnd, HWND_TOP, 0, 0, rect.right - rect.left, rect.bottom - rect.top, SWP_NOMOVE | SWP_NOOWNERZORDER);
}




void CGepWin::CreateStatusBar()
{
   m_hWndStatus = 
	   CreateWindowEx(
      0,
      STATUSCLASSNAME,
      "test",
      WS_CHILD | WS_VISIBLE | WS_CLIPSIBLINGS | WS_BORDER,
      10,20,300,20,
      GetWnd(),
      NULL,
      WinMainGetInstance(),
      0);
   ::ShowWindow(m_hWndStatus, SW_SHOW);
   UpdateWindow(m_hWndStatus);
}

void CGepWin::DestroyStatusBar()
{
	if (m_hWndStatus)
	{
		DestroyWindow(m_hWndStatus);
		m_hWndStatus = NULL;
	}
}

void CGepWin::SetStatusText(Int32 iPart, Char *pStr)
{
	if (m_hWndStatus)
	{
		SetWindowText(m_hWndStatus, pStr);
	}
}


void CGepWin::SetActive(Bool bActive)
{
	m_bActive = bActive;
}

void CGepWin::OnPaint()
{

}

void CGepWin::OnDestroy()
{

}

void CGepWin::OnSize(Uint32 uWidth, Uint32 uHeight)
{
}

void CGepWin::OnMenuCommand(Uint32 uCmd)
{
}

void CGepWin::OnVScroll(Int32 nScrollCode, Int32 nPos)
{
}

void CGepWin::Process()
{

}


void CGepWin::OnKeyDown(Uint32 uScanCode, Uint32 uVirtKey)
{
}

void CGepWin::OnKeyUp(Uint32 uScanCode, Uint32 uVirtKey)
{
}




