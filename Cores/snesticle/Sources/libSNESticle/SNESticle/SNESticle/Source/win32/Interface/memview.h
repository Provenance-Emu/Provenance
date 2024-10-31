
#ifndef _MEMVIEW_H
#define _MEMVIEW_H

#include "textview.h"

class CMemView : public CTextView
{
protected:
	Uint32		m_nBytesPerLine;	// bytes per line

protected:
	void OnPaint();

public:
	CMemView();
	~CMemView();
	virtual void SetScrollRange();

	void SetBytesPerLine(Uint32 nBytesPerLine) 
	{
		m_nBytesPerLine = nBytesPerLine;
	}

	virtual Uint8 ReadByte(Uint32 uAddr);
	virtual Uint32 GetAddrSize();
};



#endif


