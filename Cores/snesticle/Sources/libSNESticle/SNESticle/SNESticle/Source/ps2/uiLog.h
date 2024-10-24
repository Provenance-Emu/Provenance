
#ifndef _UILOG_H
#define _UILOG_H

#include "uiScreen.h"

#define UILOG_NUMMESSAGES (64)
#define UILOG_MESSAGECHARS (64)

class CLogScreen : public CScreen
{
	char	m_Messages[UILOG_NUMMESSAGES][UILOG_MESSAGECHARS];
	Int32	m_nMessages;

	Int32	m_iScroll;
	Int32	m_nDisplayLines; // number of visible lines

public:
	CLogScreen();

	void AddMessage(char *pStr);
	void Draw();
	void Process();
	void Input(Uint32 Buttons, Uint32 Trigger);
};


#endif
