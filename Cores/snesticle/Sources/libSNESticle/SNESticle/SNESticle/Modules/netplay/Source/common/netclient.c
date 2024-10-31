

#include <stdlib.h>
#include <stdio.h>
#include "types.h"
#include "netsys.h"
#include "netprint.h"
#include "netclient.h"
#include "netpacket.h"

#define NETCLIENT_DEBUG_XMIT (FALSE)
#define NETCLIENT_DEBUG_ENQUEUE (FALSE)

static int _NetClientPeerThrottle(NetClientT *pClient, int peerid, NetPacketThrottleT *pPacket);
static int _NetClientPeerInputData(NetClientT *pClient, int peerid, NetPacketInputDataT *pPacket);


static int _NetClientDefaultCallback(NetClientT *pClient, NetPlayCallbackE eMsg, void *arg)
{
	return 0;
}


// control thread
void NetClientSetCallback(NetClientT *pClient, NetClientCallbackT pCallback)
{
	pClient->pCallback = pCallback;
}

// tcp thread
static int _NetClientSocketRead(NetSocketT *pSocket, NetClientT *pClient)
{
    char recvbuffer[NETPACKET_MAX_SIZE];
    NetPacketHdrT *pPacketHdr;
    
    // receive packet
    pPacketHdr = NetPacketRecv(pSocket, recvbuffer, sizeof(recvbuffer));
    
    if (pPacketHdr)
    {
        //NetPrintf("NetClient: recv packet %d %dbytes\n", pPacketHdr->ePacketType, pPacketHdr->uPacketLen);

        switch (pPacketHdr->ePacketType)
        {
        case NETPACKET_TYPE_SERVERHELLO:
            {
                NetPacketServerHelloT *pPacket = (NetPacketServerHelloT *)pPacketHdr;
                
                strcpy(pClient->ServerName, pPacket->Name);
				pClient->clientid = pPacket->clientid;
                NetPrintf("NetClient: Connected to '%s' as client%d!\n", pClient->ServerName, pClient->clientid);
				pClient->eStatus = NETPLAY_STATUS_CONNECTED;
          
				pClient->pCallback(pClient, NETPLAY_CALLBACK_CONNECTED, NULL);
//                NetClientPingServer(pClient);
            }
            break;

		case NETPACKET_TYPE_TEXT:
			{
				NetPacketTextT *pText = (NetPacketTextT *)pPacketHdr;
				//pClient->pCallback(pClient, NETCLIENT_CALLBACK_TEXTMSG, NULL);
				//	pClient->Peers[pText->clientid].Name, 
				NetPrintf("%d: %s\n", pText->clientid, pText->Str);
			}			
			break;
            
            
        case NETPACKET_TYPE_PEERINFO:
            {
                NetPacketPeerInfoT *pPeerInfo = (NetPacketPeerInfoT *)pPacketHdr;

				if (pPeerInfo->clientid >=0  && pPeerInfo->clientid < NETCLIENT_MAXPEERS)
				{
					NetClientPeerT *pPeer = &pClient->Peers[pPeerInfo->clientid];

					// update peer information
					pPeer->clientid = pPeerInfo->clientid;
					strcpy(pPeer->Name, pPeerInfo->Name);

					// clear peer
					memset(&pPeer->Addr, 0, sizeof(pPeer->Addr));
					
					// set address
					pPeer->Addr.sin_family = AF_INET;
					pPeer->Addr.sin_addr   = pPeerInfo->ipaddr;
					pPeer->Addr.sin_port   = pPeerInfo->UDPPort;
                  
                    // is it us?
                    if (pPeerInfo->clientid == pClient->clientid)
                    {
						NetSocketAddrT Addr;
                        // use loopback address for us
                        pPeer->Addr.sin_addr = htonl(INADDR_LOOPBACK);

						// use our own udp port
						NetSocketGetLocalAddr(&pClient->UDPSocket, &Addr);
						pPeer->Addr.sin_port = Addr.sin_port;
                    } else 
					// is it a client local to the server?
					if (pPeerInfo->ipaddr == htonl(INADDR_LOOPBACK))
					{
						// use server address
						pPeer->Addr.sin_addr = pClient->Socket.PeerAddr.sin_addr;
					} else
					// is it a relay address on the server?
					if (pPeerInfo->ipaddr == htonl(INADDR_ANY) && pPeerInfo->UDPPort!=0)
					{
						// use server address
						pPeer->Addr.sin_addr = pClient->Socket.PeerAddr.sin_addr;
					} 


					if (pPeer->eStatus != pPeerInfo->status)
					{
						NetPrintf("NetClient: peer client%d '%s' %s %d:%d.%d.%d.%d:%d!\n", 
							pPeer->clientid,
							pPeer->Name,
							pPeerInfo->status ? "Connected" : "Disconnected",
							pPeer->Addr.sin_family,
							(pPeer->Addr.sin_addr >> 0) & 0xFF,
							(pPeer->Addr.sin_addr >> 8) & 0xFF,
							(pPeer->Addr.sin_addr >>16) & 0xFF,
							(pPeer->Addr.sin_addr >>24) & 0xFF,
							htons(pPeer->Addr.sin_port)
							);
						pPeer->eStatus = pPeerInfo->status;
					}
				}
            }
            break;
            
		case NETPACKET_TYPE_LOADACK:
			{
				NetPacketLoadAckT *pLoadAck = (NetPacketLoadAckT *)pPacketHdr;

				switch (pLoadAck->result)
				{
				case NETPLAY_LOADACK_OK:   	// load success
					NetPrintf("NetClient: client%d loaded game!\n", pLoadAck->clientid);
					break;

				case NETPLAY_LOADACK_ERROR:
				case NETPLAY_LOADACK_NOTFOUND:
				case NETPLAY_LOADACK_CHECKSUM:
					NetPrintf("NetClient: client%d error loading game!\n", pLoadAck->clientid);
					break;
				}

			}
			break;

		case NETPACKET_TYPE_STARTGAME:
			{
				NetPacketStartGameT *pStartGame = (NetPacketStartGameT *)pPacketHdr;
				Int32 iPeer;
				Uint32 i;
                
                NetPrintf("recv startgame\n");

				// reset frame count
				pClient->uFrame = 0;

				// reset input/output queues
				for (iPeer=0; iPeer < NETCLIENT_MAXPEERS; iPeer++)
				{
					NetClientPeerT *pPeer = &pClient->Peers[iPeer];
					NetQueueReset(&pPeer->InputQueue, pStartGame->uSeqNum);
					NetQueueReset(&pPeer->OutputQueue, pStartGame->uSeqNum);

					memset(pPeer->Stats, 0, sizeof(pPeer->Stats));
					memset(pPeer->TotalStats, 0, sizeof(pPeer->TotalStats));
					memset(pPeer->AveStats, 0, sizeof(pPeer->AveStats));

					pPeer->iThrottleReq = 0;
				}

				pClient->eGameState = NETPLAY_GAMESTATE_PLAY;

				
				// add artifical latency
				for (i=0; i < pStartGame->uLatency; i++) 
				{
					// enqueue input into send queue for peer
					NetClientEnqueueInput(pClient, 0);
				}

				NetClientTransmit(pClient);
				

				pClient->pCallback(pClient, NETPLAY_CALLBACK_STARTGAME, NULL);
			}
			break;

		case NETPACKET_TYPE_LOADREQ:
			{
				NetPacketLoadReqT *pLoadReq = (NetPacketLoadReqT *)pPacketHdr;

                if (strlen(pLoadReq->GameName) > 0)
                {
				    NetPrintf("NetClient: Load request from client%d\n", pClient->clientid);
					pClient->eGameState = NETPLAY_GAMESTATE_LOADING;
					pClient->pCallback(pClient, NETPLAY_CALLBACK_LOADGAME, pLoadReq->GameName);
                } else
                {
				    NetPrintf("NetClient: Unload request from client%d\n", pClient->clientid);
					pClient->eGameState = NETPLAY_GAMESTATE_IDLE;
					pClient->pCallback(pClient, NETPLAY_CALLBACK_UNLOADGAME, NULL);
                }
			}
			break;



        case NETPACKET_TYPE_PING:
            {
                NetPacketPingT *pPing = (NetPacketPingT *)pPacketHdr;
                NetPacketPongT packet;
                
   //             NetPrintf("NetClient: Ping? %s\n", pClient->ServerName);
                // send pong
                packet.time = pPing->time;
                NetPacketSet(&packet.Hdr, NETPACKET_TYPE_PONG, sizeof(packet));
                NetPacketSend(pSocket, &packet.Hdr);
            }
            break;

        case NETPACKET_TYPE_PONG:
            {
                NetPacketPongT *pPong = (NetPacketPongT *)pPacketHdr;
                int pingtime;
                
                pingtime = NetSysGetSystemTime() - pPong->time;
                                           
                NetPrintf("NetClient: Pong! %s %d\n", pClient->ServerName, pingtime);
            }
            break;

        }
        
    }
    return 0;
}

/*

    This function is called when the client has established
    a tcp connection to the server

*/
// tcp thread
static int _NetClientSocketConnect(NetSocketT *pSocket, NetClientT *pClient)
{
    NetPacketClientHelloT packet;
	NetSocketAddrT Addr;

    //
    // send hello packet, identifying self to server
	//

	// send version number
    packet.Version  = NETPLAY_VERSION;   

	// send client name
    strcpy(packet.Name, pClient->Name);

	// send our udp port
	NetSocketGetLocalAddr(&pClient->UDPSocket, &Addr);
	packet.UDPPort =Addr.sin_port;

    NetPacketSet(&packet.Hdr, NETPACKET_TYPE_CLIENTHELLO, sizeof(packet));
    NetPacketSend(pSocket, &packet.Hdr);
    
    return 0;
}

// tcp thread
static int _NetClientSocketDisconnect(NetSocketT *pSocket, NetClientT *pClient)
{
	Int32 iPeer;

    if (pClient->eStatus == NETPLAY_STATUS_CONNECTING)
    {
        NetPrintf("NetClient: Could not connect to server\n");
    } else
    if (pClient->eStatus == NETPLAY_STATUS_CONNECTED)
    {
        NetPrintf("NetClient: Disconnected from server\n");
    }
	NetSocketDisconnect(&pClient->UDPSocket);

	// reset peer status
	pClient->eStatus = NETPLAY_STATUS_IDLE;
	pClient->eGameState = NETPLAY_GAMESTATE_IDLE;
	for (iPeer=0; iPeer < NETCLIENT_MAXPEERS; iPeer++)
	{
		pClient->Peers[iPeer].eStatus    = NETPLAY_STATUS_IDLE;
		pClient->Peers[iPeer].eGameState = NETPLAY_GAMESTATE_IDLE;
	}

	pClient->clientid   = -1;
	pClient->pCallback(pClient, NETPLAY_CALLBACK_DISCONNECTED, NULL);

	return 0;
}

// udp thread
static int _NetClientSocketReadUDP(NetSocketT *pSocket, NetClientT *pClient)
{
	char buffer[1024];
	NetPacketHdrT *pPacketHdr;
	NetSocketAddrT Addr;
	Int32 iPeer;

	pPacketHdr = NetPacketRecvUDP(pSocket, buffer, sizeof(buffer), &Addr);
	if (pPacketHdr==NULL)
	{
		return -1;
	}

	if (pClient->eStatus == NETPLAY_STATUS_CONNECTED && pClient->eGameState == NETPLAY_GAMESTATE_PLAY)
	{
		// determine which peer sent it
		for (iPeer=0; iPeer < NETCLIENT_MAXPEERS; iPeer++)
		{
			if (pClient->Peers[iPeer].eStatus == NETPLAY_STATUS_CONNECTED)
			{
				if (NetSocketAddrIsEqual(&Addr, &pClient->Peers[iPeer].Addr))
				{
					// update peer stats
					pClient->Peers[iPeer].Stats[NETPLAY_STAT_RECVPACKETS]++;
					pClient->Peers[iPeer].Stats[NETPLAY_STAT_RECVBYTES]+= pPacketHdr->uPacketLen;

					// send udp data to peer
					switch (pPacketHdr->ePacketType)
					{
					case NETPACKET_TYPE_INPUTDATA:
						_NetClientPeerInputData(pClient, iPeer, (NetPacketInputDataT *)pPacketHdr);
						break;
					case NETPACKET_TYPE_THROTTLE:
						_NetClientPeerThrottle(pClient, iPeer, (NetPacketThrottleT *)pPacketHdr);
						break;
					default:
						NetPrintf("NetClient: UDP unknown packet %d\n", pPacketHdr->ePacketType);
						break;
					}
					return 0;
				}
			}
		}

		// unknown peer?
		NetPrintf("NetClient: UDP Data from unknown peer!\n");
	}
	return 0;
}


void NetClientSendUDP(NetClientT *pClient, int peerid, NetPacketHdrT *pPacketHdr)
{
	if (peerid == -1)
	{
		// broadcast to all peers
		Int32 iPeer;
		for (iPeer=0; iPeer < NETCLIENT_MAXPEERS; iPeer++)
		{
			if (pClient->Peers[iPeer].eStatus == NETPLAY_STATUS_CONNECTED)
			{
				// update stats
				pClient->Peers[iPeer].Stats[NETPLAY_STAT_SENTPACKETS]++;
				pClient->Peers[iPeer].Stats[NETPLAY_STAT_SENTBYTES]+= pPacketHdr->uPacketLen;

				// send udp data to peer
				NetSocketSendTo(&pClient->UDPSocket, (char *)pPacketHdr, pPacketHdr->uPacketLen, &pClient->Peers[iPeer].Addr ,0);
			}
		}
	} else
	{
		// send to peer
		if (pClient->Peers[peerid].eStatus == NETPLAY_STATUS_CONNECTED)
		{
			// update stats
			pClient->Peers[peerid].Stats[NETPLAY_STAT_SENTPACKETS]++;
			pClient->Peers[peerid].Stats[NETPLAY_STAT_SENTBYTES]+= pPacketHdr->uPacketLen;

			// send udp data to peer
			NetSocketSendTo(&pClient->UDPSocket, (char *)pPacketHdr, pPacketHdr->uPacketLen, &pClient->Peers[peerid].Addr ,0);
		}
	}
}

// control thread
Bool NetClientIsInputReady(NetClientT *pClient)
{
	Int32 iPeer;
	Bool bResult = TRUE;

	// iterate through all active peers
	for (iPeer=0; iPeer < NETCLIENT_MAXPEERS; iPeer++)
	{
		NetClientPeerT *pPeer = &pClient->Peers[iPeer];
		if (pPeer->eStatus == NETPLAY_STATUS_CONNECTED) // && pPeer->eGameState==NETPLAY_GAMESTATE_PLAY)
		{
			Int32 nPeerInput;

			nPeerInput = NetQueueGetCount(&pPeer->InputQueue);

			// keep track of minimum input available
			pPeer->Stats[NETPLAY_STAT_INPUTQUEUE]+= nPeerInput;

			// is input available from this peer?
			if (nPeerInput == 0)
			{
				pPeer->Stats[NETPLAY_STAT_INPUTSTALL]++;

				// input not available
				bResult = FALSE;
			}
		}
	}
	return bResult;
}


// control thread
Bool NetClientCheckOutputLimit(NetClientT *pClient, Int32 nCount)
{
	Int32 iPeer;

	// iterate through all active peers
	for (iPeer=0; iPeer < NETCLIENT_MAXPEERS; iPeer++)
	{
		NetClientPeerT *pPeer = &pClient->Peers[iPeer];
		if (pPeer->eStatus == NETPLAY_STATUS_CONNECTED) // && pPeer->eGameState==NETPLAY_GAMESTATE_PLAY)
		{
			Int32 nPeerOutput;

			nPeerOutput = NetQueueGetCount(&pPeer->OutputQueue);

			pPeer->Stats[NETPLAY_STAT_OUTPUTQUEUE]+= nPeerOutput;

			// is output queue for peer full?
			if (nPeerOutput >= nCount)
			{
				// output queue full
				return FALSE;
			}
		}
	}
	return TRUE;
}


//
// Encodes data stream
//


static Uint32 _NetClientCalcRunLength(Uint32 *pData, Int32 nData)
{
	Uint32 uLength=0;
	Uint32 uRunData;

	if (nData==0) return 0;

	// fetch data run to compare against
	uRunData = *pData;

	// calculate run length
	do
	{
		pData++;
		nData--;
		uLength++;
	}	while (nData > 0 && *pData == uRunData);

	return uLength;
}

static Uint32 _NetClientEncodeData(Uint32 *pEncode, Uint32 *pData, Int32 nData, Uint32 nMaxEncode)
{
	Uint32 nEncode = 0;

	while (nData > 0 && nEncode < nMaxEncode)
	{
		Uint32 uLength;

		uLength = _NetClientCalcRunLength(pData, nData);

		// write length/data
		*pEncode++ = uLength;
		*pEncode++ = *pData;
		nEncode+=2;

		// advance data pointer
		pData+=uLength;
		nData-=uLength;
	}

	return nEncode;
}

static Uint32 _NetClientDecodeData(Uint32 *pDecode, Uint32 *pEncode, Int32 nEncode)
{
	Uint32 *pDecodeStart = pDecode;

	while (nEncode > 0)
	{
		Int32 nLength;
		Uint32 uRunData;

		nLength  = *pEncode++;
		uRunData = *pEncode++;
		nEncode-=2;

		while (nLength > 0)
		{
			*pDecode++ = uRunData;
			nLength--;
		}
	}
	return (Uint32)(pDecode - pDecodeStart);
}

static void _NetClientPeerTransmit(NetClientT *pClient, Int32 peerid)
{
	NetClientPeerT *pPeer = &pClient->Peers[peerid];
	NetQueueElementT Elements[64];
	Uint32 uStart, uEnd;
	Int32 nElements;

	// transmit contents of outputqueue
	uStart = pPeer->OutputQueue.uHead;
	uEnd   = pPeer->OutputQueue.uTail;

	// fetch range of elements
	nElements = NetQueueFetchRange(&pPeer->OutputQueue, uStart, uEnd, Elements, 64);
	if (nElements > 0)
	{
		NetPacketInputDataT Packet;
		Uint32 nEncode;
		Uint32 nMaxEncode = sizeof(Packet.EncodeData) / sizeof(Uint32);

		// make packet
		Packet.uAckPos   = pPeer->InputQueue.uTail;	// send ack 
		Packet.uStartPos = uStart;					// send start position

		// encode input stream
		nEncode = _NetClientEncodeData(Packet.EncodeData, Elements, nElements, nMaxEncode);

		// setup packet header
		NetPacketSet(&Packet.Hdr, NETPACKET_TYPE_INPUTDATA, (nEncode + 3 ) * 4);

#if NETCLIENT_DEBUG_XMIT
		NetPrintf("NetUDP: xmit %d->%d to peer %d (%d bytes)\n",  uStart, uEnd - 1, peerid, Packet.Hdr.uPacketLen);
#endif

		// send packet
		NetClientSendUDP(pClient, peerid, &Packet.Hdr);
	}
}

static int _NetClientPeerThrottle(NetClientT *pClient, int peerid, NetPacketThrottleT *pPacket)
{
	// set throttling request value for peer
	pClient->Peers[peerid].iThrottleReq = pPacket->iThrottle;
	return 0;
}


static int _NetClientPeerInputData(NetClientT *pClient, int peerid, NetPacketInputDataT *pPacket)
{
	NetClientPeerT *pPeer = &pClient->Peers[peerid];
	NetQueueElementT Elements[256];
	NetQueueElementT *pElement;
	Uint32 uStart;
	Uint32 nDecode;

	if (pPacket->uAckPos <= pPeer->OutputQueue.uTail)
	{
		// set position of last ack'd packet
		pPeer->OutputQueue.uHead = pPacket->uAckPos;
	} else
	{
		// received ack for data we haven't sent yet!
	}

	uStart = pPacket->uStartPos;
	if (uStart > pPeer->InputQueue.uTail)
	{
		// we missed a packet!
	}

	// decode data
	nDecode = _NetClientDecodeData(Elements, pPacket->EncodeData, (pPacket->Hdr.uPacketLen / sizeof(Uint32)) - 3);

#if NETCLIENT_DEBUG_XMIT
	NetPrintf("NetUDP: recv %d->%d from peer %d (%d bytes)\n", uStart, uStart + nDecode - 1, peerid, pPacket->Hdr.uPacketLen);
#endif

	// enqueue elements
	pElement = Elements;
	while (nDecode > 0)
	{
		if (NetQueueEnqueueAt(&pPeer->InputQueue, uStart, pElement))
		{
#if NETCLIENT_DEBUG_ENQUEUE
			if (*pElement!=0)
			NetPrintf("NetPeer%d: enqueue %d %X\n", peerid, uStart, (Uint32)*pElement);
#endif
		} 

		uStart++;
		nDecode--;
		pElement++;
	}
	return 0;
}




Bool NetClientEnqueueInput(NetClientT *pClient, Uint32 uInput)
{
	if (pClient->eStatus == NETPLAY_STATUS_CONNECTED && pClient->eGameState == NETPLAY_GAMESTATE_PLAY)
	{
		// determine if output queues for any peer have overflowed
		if (NetClientCheckOutputLimit(pClient, 128))
		{
			NetQueueElementT Element;
			Int32 iPeer;

			Element = uInput;
	
			for (iPeer=0; iPeer < NETCLIENT_MAXPEERS; iPeer++)
			{
				if (pClient->Peers[iPeer].eStatus == NETPLAY_STATUS_CONNECTED)
				{
					// enqueue input into send queue for peer
					NetQueueEnqueue(&pClient->Peers[iPeer].OutputQueue, &Element);
				}
			}
			return TRUE;
		}
	}
	return FALSE;
}




Bool NetClientTransmit(NetClientT *pClient)
{
	if (pClient->eStatus == NETPLAY_STATUS_CONNECTED && pClient->eGameState == NETPLAY_GAMESTATE_PLAY)
	{
		// determine if output queues for any peer have overflowed
		if (NetClientCheckOutputLimit(pClient, 128))
		{
			Int32 iPeer;
			for (iPeer=0; iPeer < NETCLIENT_MAXPEERS; iPeer++)
			{
				if (pClient->Peers[iPeer].eStatus == NETPLAY_STATUS_CONNECTED)
				{
					_NetClientPeerTransmit(pClient, iPeer);
				}
			}
			return TRUE;
		}
	}
	return FALSE;
}


static void _NetClientUpdateStats(NetClientT *pClient)
{
	Int32 iPeer;

	for (iPeer=0; iPeer < NETCLIENT_MAXPEERS; iPeer++)
	{
		NetClientPeerT *pPeer = &pClient->Peers[iPeer];
		Int32 iStat;

		for (iStat=0; iStat < NETPLAY_STAT_NUM; iStat++)
		{
			// update stats
			pPeer->AveStats[iStat]    = pPeer->Stats[iStat];
			pPeer->TotalStats[iStat] += pPeer->Stats[iStat];
			pPeer->Stats[iStat]       = 0;
		}
	}

}

static void _NetClientSendThrottleReq(NetClientT *pClient)
{
	Int32 iPeer;

	for (iPeer=0; iPeer < NETCLIENT_MAXPEERS; iPeer++)
	{
		NetClientPeerT *pPeer = &pClient->Peers[iPeer];

		if (pPeer->eStatus == NETPLAY_STATUS_CONNECTED)
		{
			NetPacketThrottleT throttle;
			Int32 nAveInput;
			Int32 nStalls;

			nStalls   = pPeer->AveStats[NETPLAY_STAT_INPUTSTALL];
			nAveInput = pPeer->AveStats[NETPLAY_STAT_INPUTQUEUE] / NETPLAY_STATUPDATEFRAMES;

			NetPacketSet(&throttle.Hdr, NETPACKET_TYPE_THROTTLE, sizeof(throttle));
			throttle.iThrottle = 0;
            
            if (pPeer->AveStats[NETPLAY_STAT_INPUTQUEUE] > 0)
            {
                // are we running smooth?
                if (nStalls == 0)
                {
			        if (nAveInput > 1)
			        {
				        // we have received too much data from this peer
                        // they ought to decrease their latency
                        // request throttle down exponentially
			  	        throttle.iThrottle = (1 - nAveInput) / 2;
			        }
                } else
                {
			        if (nAveInput < 1)
			        {
				        // we arent receiving enough data from this peer
                        // we need to tell them to increase their latency, but i'm not sure how much
				        throttle.iThrottle = 1;
			        }
                } 

			    // send throttle request packet to client
			    NetClientSendUDP(pClient, iPeer, &throttle.Hdr);
                
            } 
            else
            {
                // we haven't received anything from this peer
                // they may be in pause or have disconnected/crashed
                // dont bother them with throttle requests
            }

		}
	}

}

static void _NetClientUpdateThrottle(NetClientT *pClient)
{
	Int32 iPeer;

	// default to throttling back
	pClient->iThrottle = -5;

	for (iPeer=0; iPeer < NETCLIENT_MAXPEERS; iPeer++)
	{
		NetClientPeerT *pPeer = &pClient->Peers[iPeer];

		if (pPeer->eStatus == NETPLAY_STATUS_CONNECTED)
		{
			if (pPeer->iThrottleReq > pClient->iThrottle)
			{
				// set throttling based on most conservative throttling request
				pClient->iThrottle = pPeer->iThrottleReq;
			}
		}
	}

}



Bool NetClientProcess(NetClientT *pClient, Uint32 uInputSend, Int32 nInputRecv, Uint32 *pInputRecv)
{
	Bool bResult = FALSE;

	if (pClient->eStatus == NETPLAY_STATUS_CONNECTED && pClient->eGameState == NETPLAY_GAMESTATE_PLAY)
	{
		bResult = NetClientRecvInput(pClient, nInputRecv, pInputRecv);
		if (bResult)
		{
			if (pClient->iThrottle >= 0)
			{
				// enqueue input only if input was available
				NetClientEnqueueInput(pClient, uInputSend);
			} else
			{
				// skip enqueue to reduce latency
				pClient->iThrottle++;
			}

			// increment frame count
			pClient->uFrame++;
		} 

		while (pClient->iThrottle > 0)
		{
			// pad output to increase latency
			NetClientEnqueueInput(pClient, uInputSend);
			pClient->iThrottle--;
		}


		// retransmit data to all peers
		NetClientTransmit(pClient);

		// possibly update stats
		if (pClient->nStatFrames >= NETPLAY_STATUPDATEFRAMES)
		{
			// update client stats
			_NetClientUpdateStats(pClient);

			// send throttling messages
			_NetClientSendThrottleReq(pClient);

			// throttle our own input
			_NetClientUpdateThrottle(pClient);

			pClient->nStatFrames = 0;
		}
		pClient->nStatFrames++;
	}

	return bResult;
}



Bool NetClientRecvInput(NetClientT *pClient, Int32 nInputs, Uint32 *pInputs)
{
	if (nInputs < NETCLIENT_MAXPEERS) return FALSE;

	if (pClient->eStatus == NETPLAY_STATUS_CONNECTED && pClient->eGameState == NETPLAY_GAMESTATE_PLAY)
	{
		if (NetClientIsInputReady(pClient))
		{
			Int32 iPeer;
			NetQueueElementT Element;
            
			// iterate through all peers
			for (iPeer=0; iPeer < NETCLIENT_MAXPEERS; iPeer++)
			{
				NetClientPeerT *pPeer = &pClient->Peers[iPeer];
				if (pPeer->eStatus == NETPLAY_STATUS_CONNECTED)
				{
					// dequeue input from peer
					NetQueueDequeue(&pPeer->InputQueue, &Element);

					// store element
					pInputs[iPeer] = Element;
				} else
				{
					// peer not active
					pInputs[iPeer] = 0xFFFFFFFF;
				}
			}

			return TRUE;
		}
	}
	return FALSE;
}

//
//
//

// control thread
void NetClientNew(NetClientT *pClient)
{
	Int32 iPeer;
    
    // default clear-all
    memset(pClient, 0, sizeof(*pClient));
    
	strcpy(pClient->Name, "client");
	strcpy(pClient->ServerName, "");
	NetClientSetCallback(pClient, _NetClientDefaultCallback);

    NetSocketNew(&pClient->Socket, pClient);
    NetSocketNew(&pClient->UDPSocket, pClient);
    NetSocketSetFunc(&pClient->Socket, (void *)_NetClientSocketRead, (void *)_NetClientSocketConnect, (void *)_NetClientSocketDisconnect);
	NetSocketSetFunc(&pClient->UDPSocket,  (void *)_NetClientSocketReadUDP, NULL, NULL);


	// reset peer status
	pClient->eStatus = NETPLAY_STATUS_IDLE;
	pClient->eGameState = NETPLAY_GAMESTATE_IDLE;
	for (iPeer=0; iPeer < NETCLIENT_MAXPEERS; iPeer++)
	{
		memset(&pClient->Peers[iPeer],0, sizeof(NetClientPeerT));
		pClient->Peers[iPeer].eStatus = NETPLAY_STATUS_IDLE;
		pClient->Peers[iPeer].eGameState = NETPLAY_GAMESTATE_IDLE;
		NetQueueNew(&pClient->Peers[iPeer].InputQueue);
		NetQueueNew(&pClient->Peers[iPeer].OutputQueue);
	}

}

// control thread
void NetClientDelete(NetClientT *pClient)
{
	Int32 iPeer;
    NetSocketDelete(&pClient->Socket);
    NetSocketDelete(&pClient->UDPSocket);

	pClient->eStatus = NETPLAY_STATUS_IDLE;
	pClient->eGameState = NETPLAY_GAMESTATE_IDLE;
	for (iPeer=0; iPeer < NETCLIENT_MAXPEERS; iPeer++)
	{
		pClient->Peers[iPeer].eStatus = NETPLAY_STATUS_IDLE;
		pClient->Peers[iPeer].eGameState = NETPLAY_GAMESTATE_IDLE;
		NetQueueDelete(&pClient->Peers[iPeer].InputQueue);
		NetQueueDelete(&pClient->Peers[iPeer].OutputQueue);
	}
}

// control thread
int NetClientConnect(NetClientT *pClient, unsigned ipaddr, int port)
{
	if (pClient->eStatus == NETPLAY_STATUS_IDLE)
	{
		// reset peer status
		Int32 iPeer;

		pClient->eStatus    = NETPLAY_STATUS_CONNECTING;
		pClient->eGameState = NETPLAY_GAMESTATE_IDLE;
        pClient->clientid   = -1;

		for (iPeer=0; iPeer < NETCLIENT_MAXPEERS; iPeer++)
		{
			pClient->Peers[iPeer].eStatus = NETPLAY_STATUS_IDLE;
		}

		NetPrintf("NetClient: Connecting to %d.%d.%d.%d:%d\n",
			(ipaddr >> 0) & 0xFF,
			(ipaddr >> 8) & 0xFF,
			(ipaddr >>16) & 0xFF,
			(ipaddr >>24) & 0xFF,
			port
			);

		// create udp socket for peer connections
		if (NetSocketBindUDP(&pClient->UDPSocket, 0)!=0)
		{
			return -2;
		}

		// connect to server
		NetSocketConnect(&pClient->Socket, ipaddr, port);

	}
    return -1;
}

// control thread
int NetClientDisconnect(NetClientT *pClient)
{
	if (pClient->eStatus == NETPLAY_STATUS_CONNECTED)
//	if (pClient->eStatus != NETPLAY_STATUS_IDLE)
	{
		// begin disconnection
		NetSocketDisconnect(&pClient->Socket);
		NetSocketDisconnect(&pClient->UDPSocket);
	}
    return 0;
}

// control thread
void NetClientSendText(NetClientT *pClient, char *pText)
{
	NetPacketTextT packet;

	packet.clientid = pClient->clientid;
	strcpy(packet.Str, pText);
	NetPacketSet(&packet.Hdr, NETPACKET_TYPE_TEXT, sizeof(packet));
	NetPacketSend(&pClient->Socket, &packet.Hdr);
}


// control thread
void NetClientPingServer(NetClientT *pClient)
{
	NetPacketPingT packet;

	NetPrintf("NetClient: Pinging %s\n", pClient->ServerName);
	// send pong
	packet.time = NetSysGetSystemTime();
	NetPacketSet(&packet.Hdr, NETPACKET_TYPE_PING, sizeof(packet));
	NetPacketSend(&pClient->Socket, &packet.Hdr);
}

// control thread
void NetClientSendLoadReq(NetClientT *pClient, Char *pGameName)
{
	NetPacketLoadReqT loadreq;

	loadreq.clientid = pClient->clientid;
	if (pGameName)
	{
		strcpy(loadreq.GameName, pGameName);
	} else
	{
		strcpy(loadreq.GameName, "");
	}

	NetPacketSet(&loadreq.Hdr, NETPACKET_TYPE_LOADREQ, sizeof(loadreq));
	NetPacketSend(&pClient->Socket, &loadreq.Hdr);
//    NetPrintf("NetClient: sending loadreq '%s'\n", pGameName);
}

// control thread
void NetClientSendLoadAck(NetClientT *pClient, NetPlayLoadAckE eLoadAck)
{
	NetPacketLoadAckT loadack;

	loadack.clientid = pClient->clientid;
    loadack.result   = eLoadAck;

	NetPacketSet(&loadack.Hdr, NETPACKET_TYPE_LOADACK, sizeof(loadack));
	NetPacketSend(&pClient->Socket, &loadack.Hdr);
//    NetPrintf("NetClient: sending loadack '%s'\n", pGameName);
}



