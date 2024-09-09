
#ifndef _NETPLAY_RPC_H
#define _NETPLAY_RPC_H

#include "types.h"
#include "netplay.h"

#define	NETPLAY_RPC_IRX		    0x0DD1BBB
#define	NETPLAY_RPC_EE		    0x0DD1BBC

#define NETPLAY_RPC_INIT		        0x01
#define NETPLAY_RPC_QUIT		        0x02
#define NETPLAY_RPC_PUTS		        0x03
#define	NETPLAY_RPC_SERVERSTART	        0x06
#define	NETPLAY_RPC_SERVERSTOP	        0x07
#define	NETPLAY_RPC_CLIENTCONNECT	    0x08
#define	NETPLAY_RPC_CLIENTDISCONNECT    0x09
#define	NETPLAY_RPC_GETSTATUS	        0x0A
#define	NETPLAY_RPC_CLIENTSENDLOADREQ   0x0B
#define	NETPLAY_RPC_CLIENTSENDLOADACK   0x0C
#define	NETPLAY_RPC_CLIENTINPUT         0x0F
#define	NETPLAY_RPC_SERVERPINGALL       0x10

#define NETPLAY_RPC_NUMPEERS (4)

typedef struct
{
    Uint32              uFrame;
    NetPlayGameStateE   eGameState;
    Uint32              InputSend;
    Uint32              InputRecv[NETPLAY_RPC_NUMPEERS];
    int                 InputSize[NETPLAY_RPC_NUMPEERS];
    int                 OutputSize[NETPLAY_RPC_NUMPEERS];
} NetPlayRPCInputT;


typedef struct
{
    NetPlayStatusE      eStatus;
    NetPlayGameStateE   eGameState;
    Uint32              ipaddr;
    Uint32              udpport;
    int                 InputSize;
    int                 OutputSize;
} NetPlayRPCPeerStatusT;

typedef struct 
{
    NetPlayStatusE          eServerStatus;
    NetPlayStatusE          eClientStatus;
    NetPlayGameStateE       eGameState;
    NetPlayRPCPeerStatusT   peer[NETPLAY_RPC_NUMPEERS];
} NetPlayRPCStatusT;


#endif
