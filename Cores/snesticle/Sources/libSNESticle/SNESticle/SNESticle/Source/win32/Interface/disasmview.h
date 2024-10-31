
#ifndef _DISASMVIEW_H
#define _DISASMVIEW_H

#include "textview.h"

class CDisasmView : public CTextView
{
protected:

protected:
	void OnPaint();

public:
	CDisasmView();
	~CDisasmView();
	virtual void SetScrollRange();

	virtual Int32 Disasm(Uint32 uAddr, Char *pStr);
	virtual Uint32 GetAddrSize();
};



#endif

