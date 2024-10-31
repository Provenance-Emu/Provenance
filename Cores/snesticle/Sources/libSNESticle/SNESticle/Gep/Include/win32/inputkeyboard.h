

#ifndef _INPUTKEYBOARD_H
#define _INPUTKEYBOARD_H

#include "inputdevice.h"

class CInputKeyboard : public CInputDevice
{
public:
	CInputKeyboard();
	virtual void Poll();
};

#endif
