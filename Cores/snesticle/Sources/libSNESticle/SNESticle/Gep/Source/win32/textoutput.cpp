
#include <windows.h>
#include <stdlib.h>
#include <stdio.h>
#include "types.h"
#include "textoutput.h"	



void CTextOutput::SetLineHeight(Uint32 uHeight)
{
	if (uHeight!=0)
	{
		m_uLineHeight = uHeight;
	}
	else
	{
		m_uLineHeight = m_TextMetric[0].tmHeight;
	}
}


void CTextOutput::SetCharWidth(Uint32 uWidth)
{
	if (uWidth!=0)
	{
		m_uCharWidth = uWidth;
	}
	else
	{
		m_uCharWidth = m_TextMetric[0].tmAveCharWidth;
	}
}

Int32 CTextOutput::GetNumLines()
{
	Int32 Height;
	Height = m_ClientRect.bottom - m_ClientRect.top;

	return (Height + m_uLineHeight - 1) / m_uLineHeight;
}

void CTextOutput::BeginLine(Int32 LineY)
{
	// set top and bottom of line
	m_Rect.top    = LineY * m_uLineHeight;
	m_Rect.bottom = m_Rect.top + m_uLineHeight;

	// start at left of line
	m_Rect.left   = m_ClientRect.left;
	m_Rect.right  = m_ClientRect.left;
}

void CTextOutput::EndLine()
{
	// clear to end of line
	m_Rect.left  = m_Rect.right;
	m_Rect.right = m_ClientRect.right;
	ExtTextOut(m_hDC, m_Rect.left, m_Rect.top, ETO_OPAQUE, &m_Rect, "", 0, NULL);
}

void CTextOutput::SetOffset(Int32 vx, Int32 vy)
{
	m_OffsetX = vx;
	m_OffsetY = vy;
}

void CTextOutput::Print(Float32 fCharWidth, Char *pStr, Int32 nChars)
{
	m_Rect.left  = m_Rect.right;

	if (fCharWidth == 0.0f)
	{
		SIZE Extent;
		GetTextExtentPoint32(m_hDC, pStr, nChars, &Extent);
		m_Rect.right+= Extent.cx;
	}
	else
	{
		m_Rect.right+= (Int32) (fCharWidth * (Float32)m_uCharWidth);
	}
	ExtTextOut(m_hDC, m_Rect.left + m_OffsetX, m_Rect.top + m_OffsetY, ETO_OPAQUE, &m_Rect, pStr, nChars, NULL);
}

void CTextOutput::ClearScreen()
{
	ExtTextOut(m_hDC, 0, 0, ETO_OPAQUE, &m_ClientRect, NULL, 0, NULL);
}

void CTextOutput::Printf(Float32 fCharWidth, Char *pFormat, ...)
{
	va_list argptr;
	Char str[256];
	Int32 nChars;

	va_start(argptr, pFormat);
	nChars = vsprintf(str,pFormat,argptr);
	va_end(argptr);

	Print(fCharWidth, str, nChars);
}

void CTextOutput::Print(Float32 fCharWidth, Char *pStr)
{
	Print(fCharWidth, pStr, strlen(pStr));
}

void CTextOutput::Space(Float32 fCharWidth)
{
	Print(fCharWidth, "", 0);
}

CTextOutput::CTextOutput()
{
	Int32 iFont;
	m_hWnd = NULL;
	m_hDC  = NULL;
	for (iFont=0; iFont < TEXTOUTPUT_MAXFONTS; iFont++)
	{
		m_hFont[iFont]=NULL;
	}

	SetCharWidth(1);	
	SetLineHeight(1);
}

void CTextOutput::SetTextColor(Uint32 TextColor)
{
	::SetTextColor(m_hDC, TextColor);
}

void CTextOutput::SetBGColor(Uint32 BGColor)
{
	::SetBkColor(m_hDC, BGColor);
}


void CTextOutput::SetFont(Int32 iFont, HFONT hFont)
{
	m_hFont[iFont] = hFont;
	SelectObject(m_hDC, m_hFont[iFont]);
	GetTextMetrics(m_hDC, &m_TextMetric[iFont]);
}

void CTextOutput::SelectFont(Int32 iFont)
{
	SelectObject(m_hDC, m_hFont[iFont]);
}


void CTextOutput::BeginScreen(HWND hWnd)
{
	m_hWnd = hWnd;
	m_hDC =::GetDC(m_hWnd);
	GetClientRect(hWnd, &m_ClientRect);

	SetOffset(0,0);
}

void CTextOutput::EndScreen()
{
	ReleaseDC(m_hWnd, m_hDC);
}


