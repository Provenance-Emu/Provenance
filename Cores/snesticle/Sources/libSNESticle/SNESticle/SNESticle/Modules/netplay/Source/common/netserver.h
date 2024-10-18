
#ifndef _NETSERVER_H
#define _NETSERVER_H

#include "netsocket.h"
#include "netplay.h"
#include "netpacket.h"
#include "netrelay.h"

#define NETSERVER_MAXCLIENTS 4

struct NetServer_t;

typedef struct
{
    int                 clientid;
	NetPlayGameStateE   eGameState;
    NetSocketT          Socket;
    char                Name[16];
    struct NetServer_t *pServer;
	int					UDPPort;
	NetRelayT			*pRelay;
} NetServerClientT;


typedef struct NetServer_t
{
	NetPlayStatusE      eStatus;
	NetPlayGameStateE   eGameState;
    char                Name[16];       // server name
	Uint32				uStartLatency;
	Uint32				uSeqNum;
	Bool				bRelay;
    NetSocketT          Socket;
    NetServerClientT    clients[NETSERVER_MAXCLIENTS];
} NetServerT;


void NetServerNew(NetServerT *pServer);
void NetServerDelete(NetServerT *pServer);
int NetServerStop(NetServerT *pServer);
int NetServerStart(NetServerT *pServer, int port);

void NetServerBroadcast(NetServerT *pServer, NetPacketHdrT *pPacketHdr);

void NetServerDumpStatus(NetServerT *pServer);
void NetServerSendText(NetServerT *pServer, char *pText);

#endif
