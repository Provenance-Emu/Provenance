

#include <stdlib.h>
#include <stdio.h>

#include "netsys.h"
#include "netprint.h"
#include "netsocket.h"

#define  NETSOCKET_THREAD_PRIORITY (30)


static void _NetSocketThread(NetSocketT *pSocket)
{
//    NetPrintf( "NetSocket: thread started (%d)\n", pSocket->socket );

    if (pSocket->pWriteFunc)
    {
        // call write callback
        pSocket->pWriteFunc(pSocket, pSocket->pUserData);
    }

    while(pSocket->status!=NETSOCKET_STATUS_DISCONNECTING)
    {
        if (pSocket->pReadFunc)
        {
            // call read callback
            pSocket->pReadFunc(pSocket, pSocket->pUserData);
        } else
        {
            break;
        }
    } 
    
    // call abort callback
    if (pSocket->pAbortFunc)
    {
        pSocket->pAbortFunc(pSocket, pSocket->pUserData);
    }
    

//    NetPrintf( "NetSocket: thread end %d\n" , pSocket->socket);
    // invalidate socket
    pSocket->socket = INVALID_SOCKET;

    // invalidate thread
    pSocket->threadid = NETSYS_THREAD_INVALID;

    pSocket->status = NETSOCKET_STATUS_INVALID;
}




void NetSocketNew(NetSocketT *pSocket, void *pUserData)
{
    pSocket->threadid   = NETSYS_THREAD_INVALID;
    pSocket->status     = NETSOCKET_STATUS_INVALID;
    pSocket->socket     = INVALID_SOCKET;
    pSocket->pUserData  = pUserData;
    pSocket->pReadFunc  = NULL;
    pSocket->pWriteFunc = NULL;
    pSocket->pAbortFunc = NULL;
}

void NetSocketDelete(NetSocketT *pSocket)
{
    NetSocketDisconnect(pSocket);
}

void NetSocketCopy(NetSocketT *pDest, NetSocketT *pSrc)
{
	pDest->status = pSrc->status;
	pDest->socket = pSrc->socket;
	pDest->PeerAddr = pSrc->PeerAddr;
}

void NetSocketSetFunc(NetSocketT *pSocket, NetSocketFuncT pReadFunc, NetSocketFuncT pWriteFunc, NetSocketFuncT pAbortFunc)
{
    pSocket->pReadFunc = pReadFunc;
    pSocket->pWriteFunc = pWriteFunc;
    pSocket->pAbortFunc = pAbortFunc;
}

int NetSocketAccept(NetSocketT *pListen, NetSocketT *pAccept)
{
    int clntLen;

	clntLen = sizeof(pAccept->PeerAddr);
	pAccept->socket = accept( pListen->socket, (struct sockaddr *)&pAccept->PeerAddr, &clntLen );
	if (pAccept->socket < 0)
	{
		NetPrintf("NetSocket: Failed to accept!\n");
		NetSocketDisconnect(pListen);
		return -3;
	}
	pAccept->status = NETSOCKET_STATUS_CONNECTED;
	return 0;
}

int NetSocketProcess(NetSocketT *pSocket)
{
	pSocket->threadid = NetSysThreadStart(_NetSocketThread, NETSOCKET_THREAD_PRIORITY, pSocket);
	if (pSocket->threadid <= 0)
	{
		NetPrintf("NetSocket: Failed to start socket thread!\n");
		closesocket(pSocket->socket);
		pSocket->status = NETSOCKET_STATUS_INVALID;
		return -4;
	}
	return 0;
}


int NetSocketListen(NetSocketT *pSocket, int port)
{
    struct sockaddr_in ListenAddr;
    int rc;

    // create socket
    pSocket->socket     = socket( AF_INET, SOCK_STREAM, IPPROTO_TCP );
    if (pSocket->socket < 0)
    {
        NetPrintf( "NetSocket: Failed to create socket\n" );
        return -1;
    } 

    memset( &ListenAddr, 0 , sizeof(ListenAddr));
    ListenAddr.sin_family = AF_INET;
    ListenAddr.sin_addr.s_addr = htonl(INADDR_ANY);
    ListenAddr.sin_port = htons(port);

    rc = bind( pSocket->socket, (struct sockaddr *) &ListenAddr, sizeof( ListenAddr) );
    if ( rc < 0 )
    {
      NetPrintf( "NetSocket: Socket failed to bind.\n" );
      closesocket(pSocket->socket);
      return -3;
    } 
//    NetPrintf( "NetSocket: bind returned %i port %d\n",rc, port );

    rc = listen( pSocket->socket, 2 );
    if ( rc < 0 )
    {
      NetPrintf( "NetSocket: listen failed.\n" );
      closesocket(pSocket->socket);
      return -4;
    }

//    NetPrintf(  "NetSocket: listen returned %i\n", rc );
    
	// create servering thread
    pSocket->status = NETSOCKET_STATUS_LISTENING;
 
    return NetSocketProcess(pSocket);
}


int NetSocketBindUDP(NetSocketT *pSocket, int port)
{
	struct sockaddr_in ListenAddr;
	int rc;

	// create socket
	pSocket->socket     = socket( AF_INET, SOCK_DGRAM, IPPROTO_UDP );
	if (pSocket->socket < 0)
	{
		NetPrintf( "NetSocket: Failed to create socket\n" );
		return -1;
	} 

	memset( &ListenAddr, 0 , sizeof(ListenAddr));
	ListenAddr.sin_family = AF_INET;
	ListenAddr.sin_addr.s_addr = htonl(INADDR_ANY);
	ListenAddr.sin_port = htons(port);

	rc = bind( pSocket->socket, (struct sockaddr *) &ListenAddr, sizeof( ListenAddr) );
	if ( rc < 0 )
	{
		NetPrintf( "NetSocket: Socket failed to bind.\n" );
		closesocket(pSocket->socket);
		return -3;
	} 
//	NetPrintf( "NetSocket: bind returned %i port %d\n",rc, port );

	// create servering thread
	pSocket->status = NETSOCKET_STATUS_LISTENING;

	return NetSocketProcess(pSocket);
}


static void _NetSocketConnect(NetSocketT *pSocket)
{
    int rc;

    // connect
/*
    NetPrintf("NetSocket: Connecting... %X:%d (%d)..\n", 
        pSocket->PeerAddr.sin_addr, 
        htons(pSocket->PeerAddr.sin_port),
         pSocket->socket);
         */
    
    rc = connect(pSocket->socket, (struct sockaddr *)&pSocket->PeerAddr, sizeof(pSocket->PeerAddr));
    if (pSocket->status==NETSOCKET_STATUS_DISCONNECTING)
    {
        NetPrintf("NetSocket: Connect aborted\n");
        pSocket->status = NETSOCKET_STATUS_INVALID;

        if (pSocket->pAbortFunc)
        {
            // call abort callback
            pSocket->pAbortFunc(pSocket, pSocket->pUserData);
        }
        return;
    }

    
    if (rc < 0)
    {
        closesocket(pSocket->socket);
        NetPrintf("NetSocket: Connect failed (%d)\n", rc);
        pSocket->status = NETSOCKET_STATUS_INVALID;

        if (pSocket->pAbortFunc)
        {
            // call abort callback
            pSocket->pAbortFunc(pSocket, pSocket->pUserData);
        }
        return;
    }


    pSocket->status = NETSOCKET_STATUS_CONNECTED;

/*
    NetPrintf("NetSocket: Connected! %d.%d.%d.%d:%d (%d)..\n", 
        pSocket->PeerAddr.sin_addr[0], 
        pSocket->PeerAddr.sin_addr[1], 
        pSocket->PeerAddr.sin_addr[2], 
        pSocket->PeerAddr.sin_addr[3], 
        htons(pSocket->PeerAddr.sin_port),
         pSocket->socket);
  */
    // call processing thread    
    _NetSocketThread(pSocket);
}



int NetSocketConnect(NetSocketT *pSocket, unsigned ipaddr, int port)
{
    struct sockaddr_in *addr;
    
    addr = (struct sockaddr_in *)&pSocket->PeerAddr;

    if (pSocket->status != NETSOCKET_STATUS_INVALID)
    {
        NetPrintf( "NetSocket: Already connected/ing...\n" );
        return -1;
    }

    pSocket->status = NETSOCKET_STATUS_CONNECTING;

    // create socket
    pSocket->socket     = socket( AF_INET, SOCK_STREAM, IPPROTO_TCP );
    if (pSocket->socket < 0)
    {
        NetPrintf( "NetSocket: Failed to create socket\n" );
        return -1;
    } 

    // set address    
    memset( addr, 0 , sizeof(*addr));
//    addr->sin_len    = sizeof(*addr);
    addr->sin_family = AF_INET;
    addr->sin_addr.s_addr   = ipaddr;
    addr->sin_port   = htons(port);
    
    // create connection thread
    pSocket->threadid = NetSysThreadStart(_NetSocketConnect,  NETSOCKET_THREAD_PRIORITY, pSocket);
    if (pSocket->threadid <= 0)
    {
		NetPrintf("NetSocket: Failed to start socket thread!\n");
        closesocket(pSocket->socket);
        pSocket->status = NETSOCKET_STATUS_INVALID;
        return -5;
	}
    
    // connecting started
    return 0;
}



void NetSocketDisconnect(NetSocketT *pSocket)
{
//    if (pSocket->status != NETSOCKET_STATUS_INVALID && pSocket->status != NETSOCKET_STATUS_DISCONNECTING && pSocket->status != NETSOCKET_STATUS_CONNECTING)
	if (pSocket->status == NETSOCKET_STATUS_LISTENING || pSocket->status == NETSOCKET_STATUS_CONNECTED)
    {
        pSocket->status = NETSOCKET_STATUS_DISCONNECTING;
//        NetPrintf("NetSocket: Disconnecting %i\n", pSocket->socket);
        closesocket(pSocket->socket);
    }
}

NetSocketStatusE NetSocketGetStatus(NetSocketT *pSocket)
{
    return pSocket->status;
}

int NetSocketRecv(NetSocketT *pSocket, char *pBuffer, int nBytes, int flags)
{
	int recvlen;

    recvlen = recv(pSocket->socket, pBuffer, nBytes, flags);
    if (recvlen <= 0)
    {
        NetSocketDisconnect(pSocket);
        return 0;
    }
    
    return recvlen;
}


int NetSocketRecvFrom(NetSocketT *pSocket, char *pBuffer, int nBytes, NetSocketAddrT *pAddr, int flags)
{
	int recvlen;
	int fromlen = sizeof(*pAddr);

	recvlen = recvfrom(pSocket->socket, pBuffer, nBytes, flags, (struct sockaddr *)pAddr, &fromlen);
	if (recvlen <= 0)
	{
		NetSocketDisconnect(pSocket);
		return 0;
	}

	return recvlen;
}

int NetSocketSend(NetSocketT *pSocket, char *pBuffer, int nBytes, int flags)
{
    return send(pSocket->socket, pBuffer, nBytes, flags);
}

int NetSocketSendTo(NetSocketT *pSocket, char *pBuffer, int nBytes, NetSocketAddrT *pAddr, int flags)
{
	int result;
	result = sendto(pSocket->socket, pBuffer, nBytes, flags, (struct sockaddr *)pAddr, sizeof(*pAddr));
	//NetPrintf("send udp %d:%08X:%d %d %d\n", pAddr->sin_family, pAddr->sin_addr, pAddr->sin_port, result, WSAGetLastError()); 
	return result;
}



int NetSocketRecvBytes(NetSocketT *pSocket, char *pBuffer, int nBytes, int flags)
{
    int nBytesRead = 0;
    
    while (nBytes > 0)
    {
        int RecvBytes;
        
        RecvBytes = NetSocketRecv(pSocket, pBuffer, nBytes, flags);
        if (RecvBytes <= 0)
        {
            return 0;
        }
        
        nBytes-=RecvBytes;
        nBytesRead+=RecvBytes;
    }
    
//    printf("NetSocket: RecvBytes %d\n", nBytesRead);
    

    return nBytesRead;
}


void NetSocketGetLocalAddr(NetSocketT *pSocket, NetSocketAddrT *pAddr)
{
	int namelen = sizeof(*pAddr);
	getsockname(pSocket->socket, (struct sockaddr *)pAddr, &namelen);
}

void NetSocketGetRemoteAddr(NetSocketT *pSocket, NetSocketAddrT *pAddr)
{
	int namelen = sizeof(*pAddr);
	getpeername(pSocket->socket, (struct sockaddr *)pAddr, &namelen);
}



int NetSocketAddrGetPort(NetSocketAddrT *pAddr)
{
    return htons(pAddr->sin_port);
}

unsigned int NetSocketIpAddr(int a, int b, int c, int d)
{
	return ((a&0xFF)<<0) | ((b&0xFF)<<8) | ((c&0xFF)<<16) | ((d&0xFF)<<24);
}


int NetSocketAddrIsEqual(NetSocketAddrT *pAddrA, NetSocketAddrT *pAddrB)
{
	return (pAddrA->sin_addr == pAddrB->sin_addr) && (pAddrA->sin_port==pAddrB->sin_port);
}















