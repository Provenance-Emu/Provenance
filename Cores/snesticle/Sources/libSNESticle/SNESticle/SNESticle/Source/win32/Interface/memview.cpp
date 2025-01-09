
#include "types.h"
#include "memview.h"
#include "textoutput.h"
#include "console.h"
#include "resource.h"

CMemView::CMemView()
{
	SetBytesPerLine(16);
}

CMemView::~CMemView()
{

}

void CMemView::SetScrollRange()
{
	m_nMaxLines = GetAddrSize() / m_nBytesPerLine;

	CTextView::SetScrollRange();
}

void CMemView::OnPaint()
{
	CTextOutput TextOut;
	Int32 LineY;
	Int32 nScreenLines;


	TextOut.BeginScreen(GetWnd());

	TextOut.SetFont(0, m_hFont);
	TextOut.SelectFont(0);
	TextOut.SetCharWidth(0);
	TextOut.SetLineHeight(0);

	TextOut.SetBGColor(0x0000000);

	{
		Uint32 uAddr = m_iLine * m_nBytesPerLine;
		Uint32 uMaxAddr = GetAddrSize();
		nScreenLines = TextOut.GetNumLines();
		for (LineY=0; LineY < nScreenLines; LineY++)
		{
			Uint32 iByte;
			Char ByteStr[64];

			TextOut.BeginLine(LineY);

			if (uAddr < uMaxAddr)
			{
				TextOut.SetTextColor(0x00FF00);
				TextOut.Printf(0.0f, "%06X: ", uAddr);

				TextOut.SetTextColor(0xFFFFFF);

				for (iByte=0; iByte < m_nBytesPerLine; iByte++)
				{
					Uint8 uByte;

					if (iByte == 8)
					{
						TextOut.Space(1.5f);
					}

					uByte = ReadByte(uAddr);


					if (uAddr < uMaxAddr)
					{
						TextOut.Printf(2.5f, "%02X", uByte);
						ByteStr[iByte] = isprint(uByte) ? uByte : '.';
					}
					else
					{
						TextOut.Printf(2.5f, "  ");
						ByteStr[iByte] = ' ';
					}

					uAddr++;
				}
				ByteStr[iByte] = '\0';

				TextOut.SetTextColor(0xC0C0C0);
				TextOut.Space(1.5f);
				TextOut.Print(0.0f, ByteStr);
			}
		
			TextOut.EndLine();
		}
	}

	TextOut.EndScreen();

	ValidateRect(GetWnd(), NULL);
}


Uint8 CMemView::ReadByte(Uint32 uAddr)
{
	return 0;
}

Uint32 CMemView::GetAddrSize()
{
	return 0;
}



