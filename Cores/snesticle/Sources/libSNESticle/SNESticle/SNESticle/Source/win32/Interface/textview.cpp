
#include "types.h"
#include "textview.h"
#include "textoutput.h"
#include "console.h"
#include "resource.h"

static Char _TextView_ClassName[]="GepTextView";
static Char _TextView_AppName[]="GepTextView";


CTextView::CTextView()
{
	m_hFont = NULL;
	SetFont("Fixedsys", 12);
	m_iLine = 0;
	m_nMaxLines = 0;

	Create(_TextView_ClassName, _TextView_AppName, WS_OVERLAPPEDWINDOW | WS_VSCROLL, MAKEINTRESOURCE(IDR_MEMMENU));
}

CTextView::~CTextView()
{

}


void CTextView::OnSize(Uint32 uWidth, Uint32 uHeight)
{
	RECT rect;

	GetClientRect(GetWnd(),&rect);

	// calculate # of visible lines
	m_nLines = (rect.bottom - rect.top + m_TextMetrics.tmHeight - 1) / m_TextMetrics.tmHeight;

	SetScrollRange();
}

void CTextView::SetFont(Char *pFaceName, Uint32 uPointSize)
{
	LOGFONT LogFont;
	HDC hDC;

	if (m_hFont!=NULL)
	{
		DeleteObject(m_hFont);
	}

	hDC=GetDC(GetWnd());

	// create font
	ZeroMemory(&LogFont, sizeof(LogFont));
	strcpy(LogFont.lfFaceName, pFaceName);
	LogFont.lfHeight= -MulDiv(uPointSize, GetDeviceCaps(hDC, LOGPIXELSY), 72);
	m_hFont=CreateFontIndirect(&LogFont);
	SelectObject(hDC, m_hFont);
	GetTextMetrics(hDC, &m_TextMetrics);

	ReleaseDC(GetWnd(), hDC);
}

void CTextView::SetScrollRange()
{
	SCROLLINFO info;

	info.cbSize = sizeof(info);
	info.fMask = SIF_RANGE | SIF_PAGE | SIF_POS;
	info.nMin  = 0;
	info.nMax  = m_nMaxLines - 1; // - m_nLines;
	info.nPage = m_nLines;
	info.nPos  = m_iLine;

	SetScrollInfo(GetWnd(), SB_VERT, &info, true);
}

void CTextView::OnVScroll(Int32 nScrollCode, Int32 nPos)
{
	Int32 iLine = m_iLine;

	switch (nScrollCode)
	{
	case SB_PAGEUP:
		iLine-=m_nLines;
		break;
	case SB_PAGEDOWN:
		iLine+=m_nLines;
		break;

	case SB_LINEUP:
		iLine--;
		break;
	case SB_LINEDOWN:
		iLine++; 
		break;

	case SB_THUMBTRACK:
		iLine = nPos;
		break;
	}

	if (iLine < 0) iLine = 0;
	if (iLine > (m_nMaxLines - m_nLines)) iLine = (m_nMaxLines - m_nLines);

	SetScrollPos(GetWnd(), SB_VERT, iLine, TRUE);
	m_iLine = iLine;

	OnPaint();
}

void CTextView::OnKeyDown(Uint32 uScanCode, Uint32 uVirtKey)
{
	switch (uVirtKey)
	{
	case VK_UP:
		OnVScroll(SB_LINEUP, 0);
		break;
	case VK_DOWN:
		OnVScroll(SB_LINEDOWN, 0);
		break;
	case VK_PRIOR:
		OnVScroll(SB_PAGEUP, 0);
		break;
	case VK_NEXT:
		OnVScroll(SB_PAGEDOWN, 0);
		break;
	case VK_HOME:
		OnVScroll(SB_THUMBTRACK, 0);
		break;
	case VK_END:
		OnVScroll(SB_THUMBTRACK, m_nMaxLines);
		break;

	}
}

