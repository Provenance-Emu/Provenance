
#ifndef _TEXTOUTPUT_H
#define _TEXTOUTPUT_H

#define TEXTOUTPUT_MAXFONTS 4
class CTextOutput
{
	HWND		m_hWnd;
	HFONT		m_hFont[TEXTOUTPUT_MAXFONTS];
	TEXTMETRIC	m_TextMetric[TEXTOUTPUT_MAXFONTS];
	RECT		m_ClientRect;
	HDC			m_hDC;

	Uint32		m_uCharWidth;
	Uint32		m_uLineHeight;
	Int32		m_OffsetX, m_OffsetY;

	RECT		m_Rect;

public:
	CTextOutput();

	HDC	GetDC() {return m_hDC;}
	RECT *GetRect() {return &m_Rect;}

	void SetFont(Int32 iFont, HFONT hFont);
	void SetLineHeight(Uint32 uHeight);
	void SetCharWidth(Uint32 uWidth);
	void SetOffset(Int32 vx, Int32 vy);
	
	void BeginScreen(HWND hWnd);
	void EndScreen();
	void ClearScreen();

	void BeginLine(Int32 iLine); 
	void EndLine();

	Int32 GetNumLines();

	void SelectFont(Int32 iFont);
	void SetTextColor(Uint32 TextColor);
	void SetBGColor(Uint32 BGColor);
	void Space(Float32 CharWidth);
	void Print(Float32 CharWidth, Char *pStr, Int32 nChars);
	void Printf(Float32 fCharWidth, Char *pFormat, ...);
	void Print(Float32 fCharWidth, Char *pStr);
};


#endif
