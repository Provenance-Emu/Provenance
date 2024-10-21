

#include "types.h"
#include "disasmview.h"
#include "textoutput.h"
#include "console.h"
#include "resource.h"

CDisasmView::CDisasmView()
{
//	SetBytesPerLine(8);
}

CDisasmView::~CDisasmView()
{

}

void CDisasmView::SetScrollRange()
{
	m_nMaxLines = GetAddrSize();

	CTextView::SetScrollRange();
}

void CDisasmView::OnPaint()
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
		Uint32 uAddr = m_iLine;
		Uint32 uMaxAddr = GetAddrSize();
		nScreenLines = TextOut.GetNumLines();
		for (LineY=0; LineY < nScreenLines; LineY++)
		{
			TextOut.BeginLine(LineY);

			if (uAddr < uMaxAddr)
			{
				Char Str[64];
				TextOut.SetTextColor(0x00FF00);
				TextOut.Printf(0.0f, "%04X: ", uAddr);

				TextOut.SetTextColor(0xFFFFFF);
			//	uAddr += Disasm(uAddr, Str);
				Disasm(uAddr, Str);
				uAddr++;
				TextOut.Printf(0.0f, Str);
			}
		
			TextOut.EndLine();
		}
	}

	TextOut.EndScreen();

	ValidateRect(GetWnd(), NULL);
}


Int32 CDisasmView::Disasm(Uint32 uAddr, Char *pStr)
{
	strcpy(pStr, "TEST");
	return 1;
}

Uint32 CDisasmView::GetAddrSize()
{
	return 0;
}



