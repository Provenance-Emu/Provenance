
#include <windows.h>
#include "types.h"
#include "winconsole.h"
#include "winmain.h"
#include "resource.h"
#include "textoutput.h"
#include "linebuffer.h"

static Char _WinConsole_ClassName[]="GEPConsole";

LRESULT CALLBACK _WinConsoleWndProc (HWND hWnd, UINT iMsg, WPARAM wParam, LPARAM lParam)
{
	CWinConsole *pWinConsole;

	pWinConsole = (CWinConsole *)GetWindowLong(hWnd, 0);

	switch (iMsg)
	{
		/*
	case WM_KEYUP:
	case WM_SYSKEYUP:
		if (!(lParam & 0x40000000))
		{
			Uint32 ScanCode;
			Uint32 VirtKey;

			ScanCode=((lParam>>16) & 0xFF);
			VirtKey =LOWORD(wParam);
			
			pWinConsole->WinKeyUp(ScanCode, VirtKey);
		}
		break;
		*/

	case WM_KEYDOWN:
	case WM_SYSKEYDOWN:
		{
			Uint32 ScanCode;
			Uint32 VirtKey;

			ScanCode=((lParam>>16) & 0xFF);
			VirtKey =LOWORD(wParam);
			
			pWinConsole->KeyDown(ScanCode, VirtKey);
		}
		break;

	case WM_SIZE:
		{
			Uint32 Width, Height;

			Width = LOWORD(lParam);
			Height = HIWORD(lParam);

			pWinConsole->OnSize(Width, Height);
		}
		break;

	case WM_COMMAND:
		//WinMenuCommand(LOWORD(wParam));
		break;

	case WM_PAINT:
		{
			PAINTSTRUCT ps;
			HDC hDC;

			hDC = BeginPaint(hWnd, &ps);
			pWinConsole->Draw();
			EndPaint(hWnd, &ps);
		}
		break;

	case WM_CLOSE:
		break;

	case WM_DESTROY:
		break;

	default:
		return DefWindowProc(hWnd, iMsg, wParam, lParam) ;
	
	}

	return 0;
}


CWinConsole::CWinConsole()
{
	WNDCLASS  WndClass;
	HINSTANCE hInstance;

	m_hWnd = NULL;
	m_hFont = NULL;
	m_pBuffer =  NULL;
	m_pOutNode = NULL;

	hInstance = WinMainGetInstance();

	// register class
 //   WndClass.cbSize        = sizeof (WndClass) ;
	WndClass.style         =  CS_HREDRAW | CS_VREDRAW;
	WndClass.lpfnWndProc   = _WinConsoleWndProc;
	WndClass.cbClsExtra    = 0;
	WndClass.cbWndExtra    = 4;
	WndClass.hInstance     = hInstance;
	WndClass.hIcon         = LoadIcon (hInstance, MAKEINTRESOURCE(IDI_ICON1)) ;
	WndClass.hCursor       = LoadCursor (NULL, IDC_ARROW) ;
	WndClass.hbrBackground = NULL;
	WndClass.lpszMenuName  = NULL;
	WndClass.lpszClassName = _WinConsole_ClassName;
	RegisterClass(&WndClass);

	//create window
	m_hWnd = CreateWindowEx(
		0, //WS_EX_TOPMOST,
		_WinConsole_ClassName, 
		"Console",
		WS_OVERLAPPEDWINDOW,
		CW_USEDEFAULT,
		CW_USEDEFAULT,
		CW_USEDEFAULT,
		CW_USEDEFAULT,
		NULL,
		NULL,
		hInstance, NULL );

	// set pointer to this class
	SetWindowLong(m_hWnd, 0, (LONG) this);

	SetFont("Fixedsys", 12);

	ShowWindow(m_hWnd,SW_SHOW);
	UpdateWindow(m_hWnd);
}


CWinConsole::~CWinConsole()
{
	if (m_hWnd)
	{
		DestroyWindow(m_hWnd);
	}
}


void CWinConsole::OnSize(Uint32 Width, Uint32 Height)
{
	TEXTMETRIC	tm;
	HDC		hDC;

	hDC = GetDC(m_hWnd);
	SelectObject(hDC, m_hFont);
	GetTextMetrics(hDC, &tm);

	if (Height % tm.tmHeight)
	{
		Uint32 nLines;

		nLines = (Height + tm.tmHeight - 1) / tm.tmHeight;

		Height = nLines * tm.tmHeight;

//		ClientToScreen

		SetWindowPos(m_hWnd, HWND_TOP, 0, 0, Width, Height, SWP_NOZORDER | SWP_NOMOVE | SWP_NOOWNERZORDER | SWP_DRAWFRAME);
	}

	ReleaseDC(m_hWnd, hDC);
}

void CWinConsole::Draw()
{
	CTextOutput TextOut;
	Int32 LineY;
	Int32 nScreenLines;

	TextOut.BeginScreen(m_hWnd);

	TextOut.SetFont(0, m_hFont);
	TextOut.SelectFont(0);

	TextOut.SetBGColor(0x0000000);
	TextOut.SetTextColor(0xFFFFFF);

	if (m_pBuffer)
	{
		Int32 iLine;
		nScreenLines = TextOut.GetNumLines();
		iLine = m_pBuffer->GetEndLine() - nScreenLines;
		for (LineY=0; LineY < nScreenLines; LineY++)
		{
			Char *pLine;
			TextOut.BeginLine(LineY);
			pLine = m_pBuffer->GetLine(iLine);
			if (pLine)
			{
				TextOut.Print(0.0f, pLine);
			}
		
			TextOut.EndLine();
			iLine ++;
		}
	}
	else
	{
		TextOut.ClearScreen();
	}

	TextOut.EndScreen();
}


void CWinConsole::KeyDown(Uint32 ScanCode, Uint32 VirtKey)
{

}



void CWinConsole::SetBuffer(CLineBuffer *pBuffer)
{
	m_pBuffer = pBuffer;
	InvalidateRect(m_hWnd, NULL, FALSE);
	UpdateWindow(m_hWnd);
}

void CWinConsole::SetOutput(CMsgNode *pOutNode)
{
	m_pOutNode = pOutNode;
}




void CWinConsole::SetFont(Char *pFaceName, Int32 PointSize)
{
	LOGFONT LogFont;
	HDC hDC;

	if (m_hFont!=NULL)
	{
		DeleteObject(m_hFont);
	}

	hDC=GetDC(m_hWnd);

	// create font
	ZeroMemory(&LogFont, sizeof(LogFont));
	strcpy(LogFont.lfFaceName, pFaceName);
	LogFont.lfHeight= -MulDiv(PointSize, GetDeviceCaps(hDC, LOGPIXELSY), 72);
	m_hFont=CreateFontIndirect(&LogFont);

	ReleaseDC(m_hWnd, hDC);
}


