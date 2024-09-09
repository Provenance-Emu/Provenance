

#ifndef _NETCLIENT_H
#define _NETCLIENT_H

#include "netsocket.h"
#include "netplay.h"
#include "netqueue.h"

#define NETCLIENT_MAXPEERS 4

#define NETPLAY_STATUPDATEFRAMES (64)

typedef enum
{
	NETPLAY_STAT_SENTPACKETS,
	NETPLAY_STAT_RECVPACKETS,
	NETPLAY_STAT_SENTBYTES,
	NETPLAY_STAT_RECVBYTES,
	NETPLAY_STAT_INPUTQUEUE,
	NETPLAY_STAT_OUTPUTQUEUE,
	NETPLAY_STAT_INPUTSTALL,

	NETPLAY_STAT_NUM
} NetPlayStatE;

typedef struct NetClientPeer_t
{
	int					clientid;
	NetPlayStatusE		eStatus;
	NetPlayGameStateE   eGameState;
	char				Name[16];

	Int32				Stats[NETPLAY_STAT_NUM];
	Int32				TotalStats[NETPLAY_STAT_NUM];
	Int32				AveStats[NETPLAY_STAT_NUM];

	Int32				iThrottleReq;

	NetSocketAddrT		Addr;
	NetQueueT			OutputQueue;
	NetQueueT			InputQueue;
} NetClientPeerT;


struct NetClient_t;

typedef int (*NetClientCallbackT)(struct NetClient_t *pClient, NetPlayCallbackE eMsg, void *arg);

typedef struct NetClient_t
{
	int					clientid;
	NetPlayStatusE  	eStatus;
	NetPlayGameStateE   eGameState;
	char				Name[16];

	NetClientCallbackT  pCallback;

	Int32				iThrottle;

	char                ServerName[16];
    NetSocketT          Socket;     // tcp connection to server

	NetSocketT			UDPSocket;	// udp socket for connection to peers
	Uint32				uFrame;		// current frame

	Int32				nStatFrames;

	NetClientPeerT      Peers[NETCLIENT_MAXPEERS];
} NetClientT;

void NetClientNew(NetClientT *pClient);
void NetClientDelete(NetClientT *pClient);
void NetClientSetCallback(NetClientT *pClient, NetClientCallbackT pCallback);

int NetClientConnect(NetClientT *pClient, unsigned ipaddr, int port);
int NetClientDisconnect(NetClientT *pClient);

void NetClientSendText(NetClientT *pClient, char *pText);
void NetClientPingServer(NetClientT *pClient);
void NetClientSendLoadReq(NetClientT *pClient, Char *pGameName);
void NetClientSendLoadAck(NetClientT *pClient, NetPlayLoadAckE eLoadAck);

Bool NetClientProcess(NetClientT *pClient, Uint32 uInputSend, Int32 nInputRecv, Uint32 *pInputRecv);
Bool NetClientTransmit(NetClientT *pClient);
Bool NetClientEnqueueInput(NetClientT *pClient, Uint32 uInput);
Bool NetClientRecvInput(NetClientT *pClient, Int32 nInputs, Uint32 *pInputs);

#endif
