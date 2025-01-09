


#ifndef _NETSOCKET_H
#define _NETSOCKET_H

#include "llnetsocket.h"
#include "netsys.h"

struct NetSocket_t;

typedef int (*NetSocketFuncT)(struct NetSocket_t *pSocket, void *pUserData);


typedef enum
{
    NETSOCKET_STATUS_INVALID,
    NETSOCKET_STATUS_LISTENING,
    NETSOCKET_STATUS_CONNECTING,
    NETSOCKET_STATUS_CONNECTED,
    NETSOCKET_STATUS_DISCONNECTING,
}  NetSocketStatusE;

typedef enum
{
	NETSOCKET_ERROR_NONE = 0 ,
	NETSOCKET_ERROR_THREAD = -100,
	NETSOCKET_ERROR_ACCEPT,
	NETSOCKET_ERROR_BIND,
	NETSOCKET_ERROR_SELECT,
	NETSOCKET_ERROR_SOCKET,

} NetSocketErrorE;

typedef struct NetSocket_t
{
    int             status;
    SOCKET          socket;
    NetSysThreadT   threadid;

    void            *pUserData;
    NetSocketFuncT  pReadFunc;
    NetSocketFuncT  pWriteFunc;
    NetSocketFuncT  pAbortFunc;

    NetSocketAddrT  PeerAddr;
} NetSocketT;

void NetSocketNew(NetSocketT *pSocket, void *pUserData);
void NetSocketDelete(NetSocketT *pSocket);
void NetSocketCopy(NetSocketT *pDest, NetSocketT *pSrc);

int NetSocketListen(NetSocketT *pSocket, int port);
int NetSocketConnect(NetSocketT *pSocket, unsigned ipaddr, int port);
int NetSocketAccept(NetSocketT *pListen, NetSocketT *pAccept);
int NetSocketProcess(NetSocketT *pSocket);
void NetSocketDisconnect(NetSocketT *pSocket);
void NetSocketSetFunc(NetSocketT *pSocket, NetSocketFuncT pReadFunc, NetSocketFuncT pWriteFunc, NetSocketFuncT pAbortFunc);

int NetSocketBindUDP(NetSocketT *pSocket, int port);

int NetSocketRecv(NetSocketT *pSocket, char *pBuffer, int nBytes, int flags);
int NetSocketSend(NetSocketT *pSocket, char *pBuffer, int nBytes, int flags);
int NetSocketRecvFrom(NetSocketT *pSocket, char *pBuffer, int nBytes, NetSocketAddrT *pAddr, int flags);
int NetSocketSendTo(NetSocketT *pSocket, char *pBuffer, int nBytes, NetSocketAddrT *pAddr, int flags);
int NetSocketRecvBytes(NetSocketT *pSocket, char *pBuffer, int nBytes, int flags);

void NetSocketGetLocalAddr(NetSocketT *pSocket, NetSocketAddrT *pAddr);
void NetSocketGetRemoteAddr(NetSocketT *pSocket, NetSocketAddrT *pAddr);

int NetSocketGetSocket(NetSocketT *pSocket);
NetSocketStatusE NetSocketGetStatus(NetSocketT *pSocket);

int NetSocketAddrGetPort(NetSocketAddrT *pAddr);
unsigned int NetSocketIpAddr(int a, int b, int c, int d);
int NetSocketAddrIsEqual(NetSocketAddrT *pAddrA, NetSocketAddrT *pAddrB);

#endif
