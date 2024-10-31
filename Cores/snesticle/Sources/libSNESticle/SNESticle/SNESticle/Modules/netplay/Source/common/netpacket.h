
#ifndef _NETPACKET_H
#define _NETPACKET_H

#include "types.h"

#define NETPACKET_NAME_SIZE (16)
#define NETPACKET_MAX_SIZE (512)

#define NETPACKET_TAG 0xCC

typedef enum
{
    NETPACKET_TYPE_NONE,
    NETPACKET_TYPE_SERVERHELLO,
    NETPACKET_TYPE_CLIENTHELLO,
    NETPACKET_TYPE_GOODBYE,
    NETPACKET_TYPE_TEXT,
    NETPACKET_TYPE_PING,
    NETPACKET_TYPE_PONG,
    NETPACKET_TYPE_PEERINFO,
	NETPACKET_TYPE_LOADREQ,
	NETPACKET_TYPE_LOADACK,
	NETPACKET_TYPE_STARTGAME,
	NETPACKET_TYPE_INPUTDATA,
	NETPACKET_TYPE_THROTTLE,

	NETPACKET_TYPE_NUM
} NetPacketTypeE;

typedef struct
{
    Uint8   Tag;
    Uint8   ePacketType;
    Uint16  uPacketLen;
} NetPacketHdrT;

typedef struct
{
    NetPacketHdrT   Hdr;
    int             time;
} NetPacketPingT;

typedef struct
{
    NetPacketHdrT   Hdr;
    int             time;
} NetPacketPongT;

typedef struct
{
    NetPacketHdrT   Hdr;
    Uint32          Version;
    Uint32          clientid;       // assigned client id from server
    char            Name[NETPACKET_NAME_SIZE];
} NetPacketServerHelloT;

typedef struct
{
    NetPacketHdrT   Hdr;
    Uint32          Version;
    char            Name[NETPACKET_NAME_SIZE];
	int				UDPPort;
} NetPacketClientHelloT;

typedef struct
{
    NetPacketHdrT   Hdr;
} NetPacketGoodbyeT;

typedef struct
{
    NetPacketHdrT   Hdr;
    Int32           clientid;
    char            Str[128];
} NetPacketTextT;

typedef struct
{
    NetPacketHdrT   Hdr;
	int				clientid;
    char            GameName[128];
} NetPacketLoadReqT;

typedef struct
{
    NetPacketHdrT   Hdr;
	int				clientid;
	int				result;
    unsigned        checksum;
    unsigned        filelength;
} NetPacketLoadAckT;


typedef struct
{
    NetPacketHdrT   Hdr;
	Uint32			uLatency;		// default latency
	Uint32			uSeqNum;		// starting sequence number for game
} NetPacketStartGameT;

typedef struct
{
    NetPacketHdrT   Hdr;
    Int32           status;
    Int32           clientid;
    char            Name[NETPACKET_NAME_SIZE];
	Uint32			ipaddr;
	int				UDPPort;
} NetPacketPeerInfoT;


typedef struct
{
	NetPacketHdrT   Hdr;
	Uint32			uAckPos;
	Uint32			uStartPos;
	Uint32			EncodeData[128];
} NetPacketInputDataT;

typedef struct
{
	NetPacketHdrT   Hdr;
	Int32			iThrottle;
} NetPacketThrottleT;


void NetPacketSet(NetPacketHdrT *pPacketHdr, NetPacketTypeE ePacketType, Uint32 uPacketLen);
int NetPacketSend(NetSocketT *pSocket, NetPacketHdrT *pPacketHdr);
NetPacketHdrT *NetPacketRecv(NetSocketT *pSocket, char *pBuffer, int BufferLen);
NetPacketHdrT *NetPacketRecvUDP(NetSocketT *pSocket, char *pBuffer, int BufferLen, NetSocketAddrT *pAddr);


#endif
