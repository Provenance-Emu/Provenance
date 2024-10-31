
#ifndef _UINETWORK_H
#define _UINETWORK_H

#include "uiScreen.h"

class CNetworkScreen : public CScreen
{
	int		 m_NetworkOption;
	int 	m_iDigitIP;
	Int8 	m_NetworkIP[12];
	int 	m_NetLatency;
	int		m_Port;
	Bool	m_bInitIP;

public:
	CNetworkScreen();

	void Draw();
	void Process();
	void Input(Uint32 Buttons, Uint32 Trigger);

	void SetPort(int port) {m_Port = port;}
	void SetEditIP(Uint32 ip);
	Uint32 GetEditIP();
};

#endif

