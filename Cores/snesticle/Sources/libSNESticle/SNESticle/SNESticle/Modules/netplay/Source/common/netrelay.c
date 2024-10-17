
#include "types.h"
#include "netsocket.h"
#include "netrelay.h"
#include "netprint.h"

#define NETRELAY_MAX (8)

static NetRelayT _NetRelay_Relays[NETRELAY_MAX];


static NetRelayT *_NetRelayGetByAddr(NetSocketAddrT *pAddr)
{
	Int32 iRelay;
	for (iRelay=0; iRelay < NETRELAY_MAX; iRelay++)
	{
		if (NetSocketAddrIsEqual(pAddr, &_NetRelay_Relays[iRelay].RelayAddr))
		{
			return &_NetRelay_Relays[iRelay];
		}
	}
	return NULL;
}

static int _NetRelayRead(NetSocketT *pSocket, NetRelayT *pRelayDest)
{
	char buffer[2048];
	NetSocketAddrT Addr;
	int recvlen;
	NetRelayT *pRelaySrc;

	recvlen = NetSocketRecvFrom(pSocket, buffer, sizeof(buffer), &Addr, 0);
	if (recvlen <= 0)
	{
		// socket died?
		return -1;
	}

	// determine which other relay sent it
	pRelaySrc = _NetRelayGetByAddr(&Addr);
	if (pRelaySrc)
	{
		// send packet to relay dest making it look like it came from relay source
		NetSocketSendTo(&pRelaySrc->Socket, buffer, recvlen, &pRelayDest->RelayAddr, 0);
	} else
	{
		NetPrintf("NetRelay: packet from unknown source\n");
	}

	return 0;
}

void NetRelaySend(NetSocketT *pSocket, NetSocketAddrT *pDestAddr, char *pBuffer, int nBytes)
{

}


static void _NetRelayNew(NetRelayT *pRelay, NetSocketAddrT *pRelayAddr)
{
	pRelay->RelayAddr = *pRelayAddr;

	NetSocketNew(&pRelay->Socket, (void *)pRelay);
	NetSocketSetFunc(&pRelay->Socket, (NetSocketFuncT)_NetRelayRead, NULL, NULL);
	NetSocketBindUDP(&pRelay->Socket, 0);
	NetSocketGetLocalAddr(&pRelay->Socket, &pRelay->LocalAddr);
	pRelay->bActive = TRUE;

	NetPrintf("NetRelay: %08X:%04d -> %08X:%04d \n", 
			pRelay->LocalAddr.sin_addr, htons(pRelay->LocalAddr.sin_port),
			pRelay->RelayAddr.sin_addr, htons(pRelay->RelayAddr.sin_port)
			);
			
}

static void _NetRelayDelete(NetRelayT *pRelay)
{
	if (pRelay->bActive)
	{
		NetSocketDelete(&pRelay->Socket);
		pRelay->bActive = FALSE;
	}
}

NetRelayT *NetRelayAlloc(NetSocketAddrT *pRelayAddr)
{
	Int32 iRelay;
	// find a free relay
	for (iRelay=0; iRelay < NETRELAY_MAX; iRelay++)
	{
		if (!_NetRelay_Relays[iRelay].bActive)
		{
			_NetRelayNew(&_NetRelay_Relays[iRelay], pRelayAddr);
			return &_NetRelay_Relays[iRelay];
		}
	}
	return NULL;
}


void NetRelayFree(NetRelayT *pRelay)
{
	_NetRelayDelete(pRelay);
}


