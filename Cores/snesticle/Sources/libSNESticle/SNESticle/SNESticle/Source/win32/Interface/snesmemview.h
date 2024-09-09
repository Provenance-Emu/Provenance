

#ifndef _NESMEMVIEW_H
#define _NESMEMVIEW_H

#include "memview.h"

class SnesSystem;
class SnesRom;

enum SnesMemViewE
{
	SNESMEMVIEW_NONE,
	SNESMEMVIEW_CPU,
	SNESMEMVIEW_PPU,
	SNESMEMVIEW_ROM,
	SNESMEMVIEW_SPC,

	SNESMEMVIEW_NUM
};

class CSnesMemView : public CMemView
{
	SnesMemViewE		m_eView;
	SnesSystem		*m_pSnes;
	SnesRom			*m_pRom;

protected:
	void OnMenuCommand(Uint32 uCmd);

public:
	CSnesMemView();

	void SetView(SnesSystem *pSnes, SnesRom *pRom, SnesMemViewE eView);

	Uint8 ReadByte(Uint32 uAddr);
	Uint32 GetAddrSize();
};






#endif
