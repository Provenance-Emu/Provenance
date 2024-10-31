
#ifndef _INPUTMOUSE_H
#define _INPUTMOUSE_H

#include "inputdevice.h"

class CInputMouse : public CInputDevice
{
public:
	CInputMouse();
	virtual void Poll();
};

#endif
