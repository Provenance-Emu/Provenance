

#ifndef _TEXTVIEW_H
#define _TEXTVIEW_H

#include "window.h"

class CTextView : public CGepWin
{
protected:
	HFONT		m_hFont;
	TEXTMETRIC  m_TextMetrics;
	Int32		m_nLines;			// visibile lines
	Int32		m_nMaxLines;
	Int32		m_iLine;

protected:
	virtual void OnVScroll(Int32 nScrollCode, Int32 nPos);
	virtual void OnSize(Uint32 uWidth, Uint32 uHeight);
	virtual void OnKeyDown(Uint32 uScanCode, Uint32 uVirtKey);

public:
	CTextView();
	~CTextView();

	virtual void SetScrollRange();
	void SetFont(Char *pFaceName, Uint32 uPointSize);
};



#endif


