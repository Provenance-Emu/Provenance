


#ifndef _NESDISASMVIEW_H
#define _NESDISASMVIEW_H

#include "disasmview.h"

class NesMachine;

class CNesDisasmView : public CDisasmView
{
	NesMachine		*m_pNes;

protected:
	void OnMenuCommand(Uint32 uCmd);

public:
	CNesDisasmView();

	void SetView(NesMachine *pNes);

	virtual Int32 Disasm(Uint32 uAddr, Char *pStr);
	virtual Uint32 GetAddrSize();
};

#endif
