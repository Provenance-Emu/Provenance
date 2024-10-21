
#include "types.h"
#include "netsocket.h"
#include "netpacket.h"
#include "netprint.h"


static char *_NetPacket_Name[NETPACKET_TYPE_NUM]=
{
    "none",         // NETPACKET_TYPE_NONE,
    "serverhello",  // NETPACKET_TYPE_SERVERHELLO,
    "clienthello",  // NETPACKET_TYPE_CLIENTHELLO,
    "goodbye",      // NETPACKET_TYPE_GOODBYE,
    "text",         // NETPACKET_TYPE_TEXT,
    "ping",         // NETPACKET_TYPE_PING,
    "pong",         // NETPACKET_TYPE_PONG,
};


char *NetPacketGetName(NetPacketTypeE ePacketType)
{
    if (ePacketType < NETPACKET_TYPE_NUM)
    {
        return _NetPacket_Name[ePacketType];
    } else
    {
        return "unknown";
    }
}


void NetPacketSet(NetPacketHdrT *pPacketHdr, NetPacketTypeE ePacketType, Uint32 uPacketLen)
{
    pPacketHdr->Tag         = NETPACKET_TAG;
    pPacketHdr->ePacketType = ePacketType;
    pPacketHdr->uPacketLen  = uPacketLen;
}


int NetPacketSend(NetSocketT *pSocket, NetPacketHdrT *pPacketHdr)
{
    return NetSocketSend(pSocket, (char *)pPacketHdr, pPacketHdr->uPacketLen, 0);
}


NetPacketHdrT *NetPacketRecv(NetSocketT *pSocket, char *pBuffer, int BufferLen)
{
    int recvlen;
    NetPacketHdrT *pPacketHdr;
	int packetlen;

    pPacketHdr = (NetPacketHdrT *)pBuffer;

//    NetPrintf("NetPacket: Recving hdr %d\n", pSocket->socket);
    // receive packet header
    recvlen = NetSocketRecvBytes(pSocket, (char *)pPacketHdr, sizeof(NetPacketHdrT), 0);
    if (recvlen <= 0)
    {
         NetPrintf("NetPacket: socket died %d %d\n", pSocket->socket, recvlen);
        // socket died
        return NULL;
    }

	// get length of packet data
	packetlen = pPacketHdr->uPacketLen - sizeof(NetPacketHdrT);

    // assert valid packet
    if (pPacketHdr->Tag!=NETPACKET_TAG || pPacketHdr->uPacketLen>NETPACKET_MAX_SIZE || packetlen < 0)
    {
         NetPrintf("NetPacket: bad packet\n");
        // bad packet?!
        NetSocketDisconnect(pSocket);
        return NULL;
    }

//	NetPrintf("NetPacket: Recving data %d %d\n", pSocket->socket, packetlen);
	if (packetlen > 0)
	{
		// read rest of packet
		recvlen = NetSocketRecvBytes(pSocket, pBuffer + sizeof(NetPacketHdrT), packetlen,0);
		if (recvlen <= 0)
		{
			// socket died
             NetPrintf("NetPacket: socket died2 %d %d\n", pSocket->socket, recvlen);
			return NULL;
		}
	}

  //   NetPrintf("NetPacket: Recv-ed %d\n", pPacketHdr->ePacketType);
    
    return pPacketHdr;

}


NetPacketHdrT *NetPacketRecvUDP(NetSocketT *pSocket, char *pBuffer, int BufferLen, NetSocketAddrT *pAddr)
{
	int recvlen;
	NetPacketHdrT *pPacketHdr;

	// receive packet 
	recvlen = NetSocketRecvFrom(pSocket, pBuffer, BufferLen, pAddr, 0);
	if (recvlen <= 0)
	{
		//NetPrintf("NetPacket: socket died %d\n", pSocket->socket);
		// socket died
		return NULL;
	}

	pPacketHdr = (NetPacketHdrT *)pBuffer;

	// assert valid packet
	if (pPacketHdr->Tag!=NETPACKET_TAG || pPacketHdr->uPacketLen!=recvlen)
	{
		NetPrintf("NetPacket: bad packet\n");
		return NULL;
	}

	//   NetPrintf("NetPacket: Recv-ed %d\n", pPacketHdr->ePacketType);
	return pPacketHdr;
}


