#include <stdlib.h>
#include <string.h>
#include <kernel.h>
#include <libpad.h>
#include "types.h"
#include "font.h"
#include "poly.h"
#include "uiLog.h"


CLogScreen::CLogScreen()
{
	m_nMessages = 0;
	m_iScroll = 0;
	m_nDisplayLines = 16;
	/*
	AddMessage("Test");
	AddMessage("Test2");
	AddMessage("Boo");
	AddMessage("Crap");
	*/
}

void CLogScreen::AddMessage(char *pStr)
{
	if (m_nMessages < UILOG_NUMMESSAGES)
	{
		strcpy(m_Messages[m_nMessages], pStr);
		m_nMessages++;
		m_iScroll = m_nMessages - m_nDisplayLines;
	}
}

static void _MenuPrintAlignCenter(int x, int y, char *str, Bool bHighlight = FALSE)
{                
    x-= FontGetStrWidth(str) / 2;
    FontPuts(x, y, str);

    if (bHighlight)
    {
		PolyColor4f(0.0f, 1.0f, 0.0f, 0.5f); 
		PolyRect(x-1, y-1, FontGetStrWidth(str) + 2, FontGetHeight() + 2);
    }
}

static void _MenuHeader(int vy, char *str)
{
    PolyColor4f(0.0f, 0.2f, 0.2f, 0.5f); 
	PolyRect(32, vy, 256-64, 9);
	FontColor4f(0.0, 0.8f, 0.8f, 1.0f);
    _MenuPrintAlignCenter(128, vy, str);
}

void CLogScreen::Draw()
{
	Int32 iMsg;
	Int32 nLines;
	Int32 vx=128, vy = 20;

	FontSelect(0);
	FontColor4f(0.0, 0.8f, 0.8f, 1.0f);

	vx = 10;
	_MenuHeader(vy, "Message Log");
	vy+=FontGetHeight() * 2;

	FontColor4f(0.5, 0.5f, 0.5f, 1.0f);

	if (m_iScroll >= (m_nMessages - m_nDisplayLines))
		m_iScroll = (m_nMessages - m_nDisplayLines);
	if (m_iScroll < 0) m_iScroll = 0;
		

	nLines = m_nDisplayLines;
	iMsg = m_iScroll;
	while (nLines > 0)
	{
		if (iMsg >= 0 && iMsg < m_nMessages)
		{
			Char *pStr = m_Messages[iMsg]; 
			if (pStr)
			{
				FontPuts(vx, vy, pStr);
			}
		}

		vy += FontGetHeight() + 2;
		iMsg++;
		nLines--;
	}

	_MenuHeader(vy, "");
}

void CLogScreen::Process()
{
}

void CLogScreen::Input(Uint32 buttons, Uint32 trigger)
{
    if (trigger & PAD_UP)
	{
		m_iScroll--;
	}

    if (trigger & PAD_DOWN)
	{
		m_iScroll++;
	}
}




