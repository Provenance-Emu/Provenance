#include <stdlib.h>
#include <string.h>
#include <kernel.h>
#include <libpad.h>
#include "types.h"
#include "font.h"
#include "poly.h"
#include "uiMenu.h"


void CMenuScreen::SetEntries(char **ppStrings)
{
	m_nItems = 0;

	while (*ppStrings && m_nItems < 32)
	{
		m_pEntries[m_nItems++] = *ppStrings;
		ppStrings++;
	}
}

CMenuScreen::CMenuScreen()
{
	m_iSelect = 0;
	m_nItems  = 0;
	memset(m_strText, 0, sizeof(m_strText));
	m_strTitle[0] = 0;
///	SetEntries(_TestStr);
//	SetText(0, "crapppy");
}

void CMenuScreen::SetTitle(char *pTitle)
{
	strcpy(m_strTitle, pTitle);
}

void CMenuScreen::SetText(int iText, char *pStr)
{
	strcpy(m_strText[iText], pStr);
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

void CMenuScreen::Draw()
{
	Int32 iLine;
	Int32 vx=128, vy = 40;

	FontSelect(0);
	FontColor4f(0.0, 0.8f, 0.8f, 1.0f);
//    FontPrintf(vx, vy, "%s", "Testing!");

	vx -= 80;

	_MenuHeader(vy, m_strTitle);
	vy+=FontGetHeight() * 2;

	FontColor4f(1.0, 1.0f, 1.0f, 1.0f);

	for (iLine=0; iLine < m_nItems; iLine++)
	{
		Char *pStr = m_pEntries[iLine]; 
		Int32 iWidth;;

		iWidth = FontGetStrWidth(pStr);
		
		if (pStr)
		{
//			FontPuts(vx - iWidth / 2, vy, pStr);
			FontPuts(vx, vy, pStr);

			if (iLine == m_iSelect)
			{
				PolyColor4f(0.0f, 1.0f, 0.0f, 0.5f); 
				PolyRect(vx-1, vy-1, iWidth + 2, FontGetHeight() + 2);
			}
		}

		vy += FontGetHeight() + 2;
	}

	vy+=FontGetHeight();

	_MenuHeader(vy, "");
	vy+=FontGetHeight() * 2;

	for (int i=0; i < 4; i++)
	{
		FontColor4f(0.8, 0.8f, 0.8f, 1.0f);
//		FontPuts(vx, vy, m_strText[i]);
		_MenuPrintAlignCenter(128, vy,  m_strText[i]);
		vy+=FontGetHeight() + 2;
	}
}

void CMenuScreen::Process()
{
}

void CMenuScreen::Input(Uint32 buttons, Uint32 trigger)
{
	if (trigger & PAD_UP)
	{
		m_iSelect--;
	}

	if (trigger & PAD_DOWN)
	{
		m_iSelect++;
	}

	if (m_iSelect < 0) m_iSelect = 0;
 	if (m_iSelect > (m_nItems - 1)) m_iSelect = (m_nItems - 1);

	if (trigger & (PAD_CROSS | PAD_START))
	{
		SendMessage(1, m_iSelect, m_pUserData);
	}

}




