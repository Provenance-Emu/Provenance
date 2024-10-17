
#ifndef _NETRELAY_H
#define _NETRELAY_H


// a NetRelay represents a UDP socket bound to a port
// any packet sent to this socket will be sent to the relay address
// any packet received from the relay address will be sent from this socket

typedef struct 
{
	Bool			bActive;
	NetSocketT		Socket;
	NetSocketAddrT	LocalAddr;
	NetSocketAddrT	RelayAddr;
} NetRelayT;

NetRelayT *NetRelayAlloc(NetSocketAddrT *pRelayAddr);
void NetRelayFree(NetRelayT *pRelay);

#endif
