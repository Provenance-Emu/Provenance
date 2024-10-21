
#include <stdlib.h>
#include <string.h>
#include <kernel.h>
#include <libpad.h>
#include "types.h"
#include "fileio.h"
#include "font.h"
#include "poly.h"
#include "uiNetwork.h"
extern "C" {
#include "ps2ip.h"
#include "netplay_ee.h"
};
#define MAINLOOP_NETPORT (6113)


CNetworkScreen::CNetworkScreen()
{
	m_NetworkOption = 0;
	m_iDigitIP=-1;
	m_NetLatency=5;
	m_bInitIP = FALSE;
	memset(m_NetworkIP, 0, sizeof(m_NetworkIP));
}

void CNetworkScreen::Process()
{
}


void CNetworkScreen::Input(Uint32 buttons, Uint32 trigger)
{
    if (m_iDigitIP!=-1)
    {
        if (trigger & PAD_LEFT)
        {
            m_iDigitIP--;
            if (m_iDigitIP < 0) m_iDigitIP = 11;
        }

        if (trigger & PAD_RIGHT)
        {
            m_iDigitIP++;
            if (m_iDigitIP > 11) m_iDigitIP = 0;
        }

        if (trigger & PAD_UP)
        {
            m_NetworkIP[m_iDigitIP] ++;
            if (m_NetworkIP[m_iDigitIP] >9) m_NetworkIP[m_iDigitIP] = 0;
        }

        if (trigger & PAD_DOWN)
        {
            m_NetworkIP[m_iDigitIP] --;
            if (m_NetworkIP[m_iDigitIP] <0) m_NetworkIP[m_iDigitIP] = 9;
        }


        if (trigger & PAD_TRIANGLE)
        {
            m_iDigitIP = -1;
            m_NetworkOption = 1;
        }

        if (trigger & PAD_CROSS)
        {
            Uint32 ipaddr;
            ipaddr = GetEditIP();
			SendMessage(1,ipaddr,0);
            m_NetworkOption = 1;
            m_iDigitIP = -1;
        }


    } else
    {
        if (trigger & PAD_SQUARE)
        {
            m_NetLatency--;
            if (m_NetLatency<1)  m_NetLatency = 1;
        }

        if (trigger & PAD_TRIANGLE)
        {
            m_NetLatency++;
        }
        if (trigger & PAD_UP)
        {
            m_NetworkOption--;
            if (m_NetworkOption < 0) m_NetworkOption = 0;
        }

        if (trigger & PAD_DOWN)
        {
            m_NetworkOption++;
            if (m_NetworkOption >= 1) m_NetworkOption = 1;
        }

	    if (trigger & (PAD_CROSS | PAD_START))
	    {
            switch (m_NetworkOption)
            {
                case 0:
					SendMessage(2,m_NetLatency,0);

                break;
                case 1:
					if (SendMessage(3,0,0))
					{
	                    m_NetworkOption = -1;
	                    m_iDigitIP = 0;
					}
                break;
            }

        }


    }


}






void CNetworkScreen::SetEditIP(Uint32 ip)
{
    m_NetworkIP[0] = (((ip >>  0) &0xFF)/ 100) % 10;
    m_NetworkIP[1] = (((ip >>  0) &0xFF)/  10) % 10;
    m_NetworkIP[2] = (((ip >>  0) &0xFF)/   1) % 10;

    m_NetworkIP[3] = (((ip >>  8) &0xFF)/ 100) % 10;
    m_NetworkIP[4] = (((ip >>  8) &0xFF)/  10) % 10;
    m_NetworkIP[5] = (((ip >>  8) &0xFF)/   1) % 10;

    m_NetworkIP[6] = (((ip >> 16) &0xFF)/ 100) % 10;
    m_NetworkIP[7] = (((ip >> 16) &0xFF)/  10) % 10;
    m_NetworkIP[8] = (((ip >> 16) &0xFF)/   1) % 10;

    m_NetworkIP[9] = (((ip >> 24) &0xFF)/ 100) % 10;
    m_NetworkIP[10] = (((ip >> 24)&0xFF) /  10) % 10;
    m_NetworkIP[11] = (((ip >> 24)&0xFF) /   1) % 10;
}

Uint32 CNetworkScreen::GetEditIP()
{
    Uint32 ip=0;

    ip+= (m_NetworkIP[0]  * 100) << 0;
    ip+= (m_NetworkIP[1]  *  10) << 0;
    ip+= (m_NetworkIP[2]  *   1) << 0;

    ip+= (m_NetworkIP[3]  * 100) << 8;
    ip+= (m_NetworkIP[4]  *  10) << 8;
    ip+= (m_NetworkIP[5]  *   1) << 8;

    ip+= (m_NetworkIP[6]  * 100) <<16;
    ip+= (m_NetworkIP[7]  *  10) <<16;
    ip+= (m_NetworkIP[8]  *   1) <<16;

    ip+= (m_NetworkIP[9]  * 100) <<24;
    ip+= (m_NetworkIP[10] *  10) <<24;
    ip+= (m_NetworkIP[11] *   1) <<24;
    return ip;
}










void _MenuPrintIP(int x, int y, unsigned ipaddr)
{
    FontPrintf(x,y,"%3d.%3d.%3d.%3d", 
            (ipaddr >> 0) & 0xFF,
            (ipaddr >> 8) & 0xFF,
            (ipaddr >>16) & 0xFF,
            (ipaddr >>24) & 0xFF
                    );
}

void _MenuPrintIPPort(int x, int y, unsigned ipaddr, unsigned port)
{
    FontPrintf(x,y,"%3d.%3d.%3d.%3d:%d", 
            (ipaddr >> 0) & 0xFF,
            (ipaddr >> 8) & 0xFF,
            (ipaddr >>16) & 0xFF,
            (ipaddr >>24) & 0xFF,
            htons(port)
                    );
}

void _MenuPrintAlignLeft(int x, int y, char *str, Bool bHighlight = FALSE)
{    
    FontPuts(x , y, str);
    if (bHighlight)
    {
		PolyColor4f(0.0f, 1.0f, 0.0f, 0.5f); 
		PolyRect(x-1, y-1, FontGetStrWidth(str) + 2, FontGetHeight() + 2);
    }
}

void _MenuPrintAlignRight(int x, int y, char *str, Bool bHighlight = FALSE)
{    
    x-= FontGetStrWidth(str);
    FontPuts(x , y, str);
    if (bHighlight)
    {
		PolyColor4f(0.0f, 1.0f, 0.0f, 0.5f); 
		PolyRect(x-1, y-1, FontGetStrWidth(str) + 2, FontGetHeight() + 2);
    }
}

void _MenuPrintAlignCenter(int x, int y, char *str, Bool bHighlight = FALSE)
{                
    x-= FontGetStrWidth(str) / 2;
    FontPuts(x, y, str);

    if (bHighlight)
    {
		PolyColor4f(0.0f, 1.0f, 0.0f, 0.5f); 
		PolyRect(x-1, y-1, FontGetStrWidth(str) + 2, FontGetHeight() + 2);
    }
}


static char *m_DHCPStr[]=
{
    "disabled",   //  DHCP_DISABLED 0
    "requesting", //  DHCP_REQUESTING 1
    "init",       //  DHCP_INIT 2
    "rebooting",  //  DHCP_REBOOTING 3
    "rebinding",  //  DHCP_REBINDING 4
    "renewing",   //  DHCP_RENEWING 5
    "selecting",  //  DHCP_SELECTING 6
    "informing",  //  DHCP_INFORMING 7
    "checking",   //  DHCP_CHECKING 8
    "permanent",  //  DHCP_PERMANENT 9
    "bound",      //  DHCP_BOUND 10
    "releasing",  //  DHCP_RELEASING 11 
    "backingoff", //  DHCP_BACKING_OFF 12
    "off",        //  DHCP_OFF 13
};


static char *m_NetplayClientStatusStr[]=
{
    "not connected",
    "connecting",
    "connected"
};

static char *m_NetplayServerStatusStr[]=
{
    "idle",
    "connecting",
    "listening"
};

void _MenuHeader(int vy, char *str)
{
    PolyColor4f(0.0f, 0.2f, 0.2f, 0.5f); 
	PolyRect(32, vy, 256-64, 9);
	FontColor4f(0.0, 0.8f, 0.8f, 1.0f);
    _MenuPrintAlignCenter(128, vy, str);
}


void _MenuDrawEditIP(int x, int y, Int8 *pIP, int iDigit)
{
    char *pFormat = "abc.def.ghi.jkl";
    char str[2];

    str[1] = 0;

    while (*pFormat)
    {
        int idrawdigit;
        str[0] = *pFormat;
        if (*pFormat=='.')
        {
            _MenuPrintAlignLeft(x,y,str, 0);
        } else
        {
            idrawdigit = *pFormat - 'a';
            str[0] = pIP[idrawdigit] + '0';

            _MenuPrintAlignLeft(x,y,str, idrawdigit == iDigit);
        }
        pFormat++;
        x+=6;
    }
}


void CNetworkScreen::Draw()
{
    t_ip_info configinfo;
    t_ip_info *config = NULL;
    memset(&configinfo, 0, sizeof(configinfo));
    if (ps2ip_getconfig("sm1",&configinfo))
	{
		config = &configinfo;
	}

	// set edit ip to our ip for easy editing
	if (!m_bInitIP)
	{
		if (config && config->ipaddr.s_addr!=0)
		{
			SetEditIP(config->ipaddr.s_addr);
			m_bInitIP = TRUE;
		}
	}

    {
//        Char str[32];
        Int32 vx, vy;
        

        NetPlayRPCStatusT status;
        NetPlayGetStatus(&status);

	    FontSelect(2);

        vx = 105;
        vy=15;

        _MenuHeader(vy, "Network Config");
        vy+=12;


	    FontColor4f(1.0, 0.0f, 0.0f, 1.0f);
        
		if (config)
        {
        	FontColor4f(0.5, 0.5f, 0.5f, 1.0f);
        	FontSelect(2);
            _MenuPrintAlignRight(vx, vy + 0, "MAC:");
            _MenuPrintAlignRight(vx, vy + 10, "DHCP:");
            _MenuPrintAlignRight(vx, vy + 20, "Local IP:");
            _MenuPrintAlignRight(vx, vy + 30, "Netmask:");
            _MenuPrintAlignRight(vx, vy + 40, "Gateway:");


        	FontColor4f(1.0, 1.0f, 1.0f, 1.0f);
            FontPuts(vx + 10,vy + 10, m_DHCPStr[config->dhcp_status]);

        	FontSelect(1);
            FontPrintf(vx + 10,vy + 00, "%02X:%02X:%02X:%02X:%02X:%02X",
                config->hw_addr[0],
                config->hw_addr[1],
                config->hw_addr[2],
                config->hw_addr[3],
                config->hw_addr[4],
                config->hw_addr[5]
            );
            _MenuPrintIP(vx + 10,vy + 20, config->ipaddr.s_addr);
            _MenuPrintIP(vx + 10,vy + 30, config->netmask.s_addr);
            _MenuPrintIP(vx + 10,vy + 40, config->gw.s_addr);
        	FontSelect(2);

        }
        vy+=55;


        _MenuHeader(vy, "Network Status");
        vy+=10;

        FontColor4f(0.5, 0.5f, 0.5f, 1.0f);
        FontSelect(2);
        _MenuPrintAlignRight(vx, vy + 0, "Server:");

        FontColor4f(1.0, 1.0f, 1.0f, 1.0f);
        FontPuts(vx + 10,vy + 0, m_NetplayServerStatusStr[status.eServerStatus]);
        vy+=10;


        FontColor4f(0.5, 0.5f, 0.5f, 1.0f);
        FontSelect(2);
        _MenuPrintAlignRight(vx, vy + 0, "Client:");
        FontColor4f(1.0, 1.0f, 1.0f, 1.0f);
        FontPuts(vx + 10,vy + 0, m_NetplayClientStatusStr[status.eClientStatus]);
        vy+=10;


/*
        FontColor4f(0.5, 0.5f, 0.5f, 1.0f);
        FontSelect(2);
        _MenuPrintAlignRight(vx, vy + 0, "ServerIP:");
        FontColor4f(1.0, 1.0f, 1.0f, 1.0f);
        FontSelect(1);
        _MenuPrintIP(vx + 10,vy, config.ipaddr.s_addr);
        vy+=10;
  */

        _MenuHeader(vy, "Network Players");
        vy+=12;

        int iPeer;

        FontSelect(1);
        for (iPeer=0; iPeer < 4; iPeer++)
        {
            if (status.peer[iPeer].eStatus==NETPLAY_STATUS_CONNECTED)
            {
                FontColor4f(1.0f, 1.0f, 1.0f, 1.0f);
            } else
            {
                FontColor4f(0.25f, 0.25f, 0.25f, 1.0f);
            }


//            FontPrintf(10,vy,"%d %08X %04X", iPeer, status.peer[iPeer].ipaddr, status.peer[iPeer].udpport);
            FontPrintf(70,vy,"%d:", iPeer);
            _MenuPrintIPPort(90, vy, status.peer[iPeer].ipaddr, status.peer[iPeer].udpport);

            vy+=10;
        }


/*        _MenuPrintAlignRight(vx, vy + 0, "GameState:");
        FontColor4f(1.0, 1.0f, 1.0f, 1.0f);
        FontPuts(vx + 10,vy + 0, m_NetGameStateStr[status.eGameSTate]);
        vy+=10;
        */


//        vy+=25;


        FontSelect(0);
        _MenuHeader(vy, "Network Menu");
        vy+=12;

        FontColor4f(1.0, 1.0f, 1.0f, 1.0f);
//        FontPrintf(80, vy + 0, "Host Game");
        char *str = (char *)((status.eServerStatus==NETPLAY_STATUS_IDLE) ? "Host game" : "Stop server");
        _MenuPrintAlignCenter(128, vy + 0, str, m_NetworkOption==0);
        vy+=10;                                          

        str = (char *)((status.eClientStatus==NETPLAY_STATUS_IDLE) ? "Connect to game" : "Disconnect");
        _MenuPrintAlignCenter(128, vy + 0, str, m_NetworkOption==1);
//        _MenuPrintAlignRight(vx, vy + 0, "Connect to:", m_NetworkOption==1);

//        _MenuPrintIP(vx+10,vy, config.ipaddr.s_addr);
        vy+=10;
       
        FontPrintf(20,vy, "%d", m_NetLatency);



        _MenuDrawEditIP(86, vy, m_NetworkIP, m_iDigitIP);

//        _MenuPrintAlignRight(vx - 10, vy + 0, "Connect:");
//        _MenuPrintIP(vx, vy, 0x12345678);

/*
        sprintf(str, "%d %d", status.eStatus, status.eGameState );
	    FontPuts(18, 222, str);
        */
        
    }

/*
	FontSelect(2);
	FontColor4f(0.5, 0.5f, 0.5f, 1.0f);
	FontPuts(10, 220, "Select=Load game");
  */
}




