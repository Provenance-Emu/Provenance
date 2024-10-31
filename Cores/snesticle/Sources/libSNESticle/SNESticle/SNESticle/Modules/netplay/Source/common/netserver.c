
#include <stdlib.h>
#include "types.h"
#include "netsys.h"
#include "netprint.h"
#include "netserver.h"
#include "netpacket.h"

#define NETSERVER_RELAY (WIN32 && TRUE)

int NetServerClientIsConnected(NetServerT *pServer, int clientid)
{
    return  (NetSocketGetStatus(&pServer->clients[clientid].Socket) == NETSOCKET_STATUS_CONNECTED);
}


void NetServerSendPeerInfo(NetServerT *pServer)
{
    Int32 iClient;
    for (iClient=0; iClient < NETSERVER_MAXCLIENTS; iClient++)
    {
        NetPacketPeerInfoT peerinfo;
        NetServerClientT *pClient = &pServer->clients[iClient];;
    
        memset(&peerinfo, 0, sizeof(peerinfo));
		peerinfo.clientid = pClient->clientid;
        
        if (NetSocketGetStatus(&pClient->Socket) == NETSOCKET_STATUS_CONNECTED)
        {
            peerinfo.status = NETPLAY_STATUS_CONNECTED;
            strcpy(peerinfo.Name, pClient->Name);

			// send peer address
			peerinfo.ipaddr  = pClient->Socket.PeerAddr.sin_addr;
			peerinfo.UDPPort = pClient->UDPPort;

			#if NETSERVER_RELAY
			if (pClient->pRelay)
			{
				// use relay address instead
				peerinfo.ipaddr  = pClient->pRelay->LocalAddr.sin_addr;
				peerinfo.UDPPort = pClient->pRelay->LocalAddr.sin_port;
			} 
			#endif
        } else
		{
			peerinfo.status = NETPLAY_STATUS_IDLE;
		}
        
        // send to all clients
		NetPacketSet(&peerinfo.Hdr, NETPACKET_TYPE_PEERINFO, sizeof(peerinfo));
        NetServerBroadcast(pServer, &peerinfo.Hdr);
    }
}

int NetServerGetNumClients(NetServerT *pServer)
{
    Int32 iClient;
	Int32 nClients = 0;
    // send packet to all clients that are connected
    for (iClient=0; iClient < NETSERVER_MAXCLIENTS; iClient++)
	{
		if (NetSocketGetStatus(&pServer->clients[iClient].Socket) == NETSOCKET_STATUS_CONNECTED)
		{
			nClients++;
		}
	}
	return nClients;
}


void NetServerBroadcast(NetServerT *pServer, NetPacketHdrT *pPacketHdr)
{
    Int32 iClient;
    // send packet to all clients that are connected
    for (iClient=0; iClient < NETSERVER_MAXCLIENTS; iClient++)
    {
        if (NetSocketGetStatus(&pServer->clients[iClient].Socket) == NETSOCKET_STATUS_CONNECTED)
        {
            NetPacketSend(&pServer->clients[iClient].Socket, pPacketHdr);
        }
    }
}

static void _NetServerSetGameState(NetServerT *pServer, NetPlayGameStateE eGameState)
{
	Int32  iClient;
	pServer->eGameState = eGameState;
	for (iClient=0; iClient < NETSERVER_MAXCLIENTS; iClient++)
	{
		pServer->clients[iClient].eGameState = eGameState;
	}
}

void NetServerLoadGame(NetServerT *pServer, int clientid, char *pGameName)
{
	if (pServer->eGameState != NETPLAY_GAMESTATE_LOADING)
	{
		NetPacketLoadReqT loadreq;
		
		// loading attempt
		loadreq.clientid = clientid;
		strcpy(loadreq.GameName, pGameName);
		
		NetPacketSet(&loadreq.Hdr, NETPACKET_TYPE_LOADREQ, sizeof(loadreq));
		NetServerBroadcast(pServer, &loadreq.Hdr);
		NetPrintf("NetServer: client%d load request '%s'\n", clientid, loadreq.GameName);

		// set clients to be loading         
        _NetServerSetGameState(pServer, NETPLAY_GAMESTATE_LOADING);
	}
}


void NetServerUnloadGame(NetServerT *pServer, int clientid)
{
	if (pServer->eGameState != NETPLAY_GAMESTATE_IDLE)
	{
		NetPacketLoadReqT loadreq;

		// loading attempt
		loadreq.clientid = clientid;
		strcpy(loadreq.GameName, "");

		NetPacketSet(&loadreq.Hdr, NETPACKET_TYPE_LOADREQ, sizeof(loadreq));
		NetServerBroadcast(pServer, &loadreq.Hdr);

		// set clients to be idle
        _NetServerSetGameState(pServer, NETPLAY_GAMESTATE_IDLE);
	}
}


static void _NetServerStartGame(NetServerT *pServer)
{
	if (pServer->eGameState == NETPLAY_GAMESTATE_LOADED)
	{
		NetPacketStartGameT startgame;

		// signal start game
		startgame.uLatency = pServer->uStartLatency;
		startgame.uSeqNum  = pServer->uSeqNum;

		NetPacketSet(&startgame.Hdr, NETPACKET_TYPE_STARTGAME, sizeof(startgame));
		NetServerBroadcast(pServer, &startgame.Hdr);

		NetPrintf("NetServer: sending starting game...\n");

		// set clients to be idle
        _NetServerSetGameState(pServer, NETPLAY_GAMESTATE_PLAY);
	}
}






//
//
//

static int _NetServerClientRead( NetSocketT *pSocket, NetServerClientT *pClient )
{
	NetServerT *pServer = pClient->pServer;
	char recvbuffer[NETPACKET_MAX_SIZE];
    NetPacketHdrT *pPacketHdr;
    
    // receive packet
    pPacketHdr = NetPacketRecv(pSocket, recvbuffer, sizeof(recvbuffer));
    
    if (pPacketHdr)
    {
//        NetPrintf("NetServer: recv packet %d %dbytes\n", pPacketHdr->ePacketType, pPacketHdr->uPacketLen);

        switch (pPacketHdr->ePacketType)
        {
        case NETPACKET_TYPE_CLIENTHELLO:
            {
                NetPacketClientHelloT *pPacket = (NetPacketClientHelloT *)pPacketHdr;
                NetPacketServerHelloT packet;

				if (pPacket->Version != NETPLAY_VERSION)
				{
					// bad version
					NetPrintf("NetServer: client bad version %X, disconnecting\n", pPacket->Version);
					NetSocketDisconnect(&pClient->Socket);
					return 0;
				}
                
				pClient->eGameState = NETPLAY_GAMESTATE_IDLE;
				pClient->UDPPort    = pPacket->UDPPort;
				strcpy(pClient->Name, pPacket->Name);
				NetPrintf("NetServer: client%d '%s' connected! UDP=%d\n", pClient->clientid, pClient->Name, htons(pClient->UDPPort));

				// create relay
				#if NETSERVER_RELAY
				if (pServer->bRelay)
				{
					NetSocketAddrT RelayAddr;
					RelayAddr = pClient->Socket.PeerAddr;
					RelayAddr.sin_port = pClient->UDPPort;
					pClient->pRelay = NetRelayAlloc(&RelayAddr);
				}
				#endif

                // respond with a server hello
                packet.Version  = NETPLAY_VERSION;   
                packet.clientid = pClient->clientid;
                strcpy(packet.Name, pServer->Name);

                NetPacketSet(&packet.Hdr, NETPACKET_TYPE_SERVERHELLO, sizeof(packet));
                NetPacketSend(pSocket, &packet.Hdr);
                
                NetServerSendPeerInfo(pClient->pServer);
            }
            break;
		case NETPACKET_TYPE_TEXT:
			{
				// broadcast message to all clients
				NetServerBroadcast(pServer, pPacketHdr);
			}
			break;



		case NETPACKET_TYPE_LOADREQ:
			{
				NetPacketLoadReqT *pLoadReq = (NetPacketLoadReqT *)pPacketHdr;

				if (pServer->eGameState != NETPLAY_GAMESTATE_LOADING)
				{
					if (strlen(pLoadReq->GameName) > 0)
					{
						NetServerLoadGame(pServer, pClient->clientid, pLoadReq->GameName);
					} else
					{
						NetServerUnloadGame(pServer, pClient->clientid);
					}
				}
			}
			break;


		case NETPACKET_TYPE_LOADACK:
			{
				NetPacketLoadAckT *pLoadAck = (NetPacketLoadAckT *)pPacketHdr;

				switch (pLoadAck->result)
				{
                case NETPLAY_LOADACK_OK:
					if (pClient->eGameState == NETPLAY_GAMESTATE_LOADING)
                    {
						int iClient;
						Bool bAllLoaded = TRUE;

						NetPrintf("NetServer: Load ack from client %d\n", pClient->clientid);

						// rebroadcast loaded message
						NetServerBroadcast(pServer, pPacketHdr);

						// determine if everyone has loaded their games now
                        pClient->eGameState = NETPLAY_GAMESTATE_LOADED;
						for (iClient=0; iClient < NETSERVER_MAXCLIENTS; iClient++)
						{
							if (NetServerClientIsConnected(pServer, iClient))
							{
								if (pServer->clients[iClient].eGameState != NETPLAY_GAMESTATE_LOADED)
								{
									bAllLoaded = FALSE;
								}
							}
						}

						if (bAllLoaded)
						{
							pServer->eGameState = NETPLAY_GAMESTATE_LOADED;
							_NetServerStartGame(pServer);
						}
                    }
                    break;

				case NETPLAY_LOADACK_ERROR:
				case NETPLAY_LOADACK_CHECKSUM:
					if (pClient->eGameState == NETPLAY_GAMESTATE_LOADING)
					{
						// rebroadcast error message
						NetServerBroadcast(pServer, pPacketHdr);

						NetPrintf("NetServer: Load error from client %d\n", pClient->clientid);
						NetServerUnloadGame(pServer, pClient->clientid);
					}
					break;
				}

			}
			break;

        case NETPACKET_TYPE_PING:
            {
                NetPacketPingT *pPing = (NetPacketPingT *)pPacketHdr;
                NetPacketPongT packet;
                
//                NetPrintf("NetServer: Ping? %s\n", pClient->Name);
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
                
                NetPrintf("NetServer: Pong! %s %d\n", pClient->Name, pingtime);
            }
            break;

        }
        
    }

    
    return 0;
}

static int _NetServerClientConnect( NetSocketT *pSocket, NetServerClientT *pClient )
{
    // client has established a tcp connection with server but
    // no communication has taken place yet. The server is waiting
    // for a client-hello packet to be received
    return 0;
}

static int _NetServerClientAbort( NetSocketT *pSocket, NetServerClientT *pClient )
{
	NetServerT *pServer = pClient->pServer;

	// tcp connection between server-client has been broken or terminated
	// notify all other clients about new client status
	NetServerSendPeerInfo(pClient->pServer);
	pClient->eGameState = NETPLAY_GAMESTATE_IDLE;

	#if NETSERVER_RELAY
	if (pClient->pRelay)
	{
		NetRelayFree(pClient->pRelay);
		pClient->pRelay = NULL;
	}
	#endif

	NetPrintf("NetServer: client%d disconnected!\n", pClient->clientid);

	if (NetServerGetNumClients(pServer) == 0)
	{
		NetPrintf("NetServer: Idle\n");
		pServer->eGameState = NETPLAY_GAMESTATE_IDLE;
	}
	return 0;
}

static void _NetServerClientDisconnect(NetServerClientT *pClient)
{
    if (NetSocketGetStatus(&pClient->Socket) != NETSOCKET_STATUS_INVALID)
    {
        // this will call abort function for client
        NetSocketDisconnect(&pClient->Socket);
    }
}


//
//
//

static int _NetServerAccept(NetSocketT *pSocket, NetServerT *pServer)
{
	NetSocketT Accept;
    int iClient;

	if (NetSocketAccept( pSocket, &Accept) == 0)
	{
		if (pServer->eGameState == NETPLAY_GAMESTATE_IDLE)
		{
			// only can accept connections when idle
			for (iClient=0; iClient < NETSERVER_MAXCLIENTS; iClient++)
			{
				NetServerClientT *pClient = &pServer->clients[iClient];
		        
				if (!NetServerClientIsConnected(pServer, iClient))
				{
					NetSocketCopy(&pClient->Socket, &Accept);
					NetSocketProcess(&pClient->Socket);
		            
					NetPrintf("NetServer: Accepted from %d.%d.%d.%d:%d\n", 
						(pClient->Socket.PeerAddr.sin_addr >> 0) & 0xFF,
						(pClient->Socket.PeerAddr.sin_addr >> 8) & 0xFF,
						(pClient->Socket.PeerAddr.sin_addr >>16) & 0xFF,
						(pClient->Socket.PeerAddr.sin_addr >>24) & 0xFF,
						NetSocketAddrGetPort(&pClient->Socket.PeerAddr)
					);
					return 0;
				}
			}
		}

		// disconnect socket
		NetSocketDisconnect(&Accept);
	}

    return -1;
}


static int _NetServerStart(NetSocketT *pSocket, NetServerT *pServer)
{
    pServer->eStatus = NETPLAY_STATUS_CONNECTED;
    return 0;
}

static int _NetServerStop(NetSocketT *pSocket, NetServerT *pServer)
{
    pServer->eStatus = NETPLAY_STATUS_IDLE;
    return 0;
}



void NetServerSendText(NetServerT *pServer, char *pText)
{
	NetPacketTextT packet;

	packet.clientid = -1;
	strcpy(packet.Str, pText);
	NetPacketSet(&packet.Hdr, NETPACKET_TYPE_TEXT, sizeof(packet));
	NetServerBroadcast(pServer, &packet.Hdr);
}

void NetServerNew(NetServerT *pServer)
{
    int iClient;

    // default clear-all
    memset(pServer, 0, sizeof(*pServer));

	pServer->bRelay		   = FALSE;
	pServer->uSeqNum       = 0;
	pServer->uStartLatency = 30;
    
    pServer->eGameState = NETPLAY_GAMESTATE_IDLE;
    strcpy(pServer->Name, "server");

    NetSocketNew(&pServer->Socket, pServer);
    NetSocketSetFunc(&pServer->Socket, (void *)_NetServerAccept, (void *)_NetServerStart, (void *)_NetServerStop);
    
    for (iClient=0; iClient < NETSERVER_MAXCLIENTS; iClient++)
    {
		NetServerClientT *pClient = &pServer->clients[iClient];

        pClient->eGameState = NETPLAY_GAMESTATE_IDLE;
        pClient->clientid = iClient;
        pClient->pServer = pServer;
		pClient->pRelay  = NULL;
        NetSocketNew(&pClient->Socket, &pServer->clients[iClient]);
        NetSocketSetFunc(&pClient->Socket, (void *)_NetServerClientRead, (void *)_NetServerClientConnect, (void *)_NetServerClientAbort);
    }
    
}

void NetServerDelete(NetServerT *pServer)
{
	Int32 iClient;
    NetServerStop(pServer);

	for (iClient=0; iClient < NETSERVER_MAXCLIENTS; iClient++)
	{
		NetServerClientT *pClient = &pServer->clients[iClient];

		NetSocketDelete(&pClient->Socket);
	}
}

int NetServerStop(NetServerT *pServer)
{
    if (NetSocketGetStatus(&pServer->Socket) == NETSOCKET_STATUS_LISTENING)
    {
        int iClient;

	    NetPrintf("NetServer: Shutting down server...\n");
        //
        NetSocketDisconnect(&pServer->Socket);
        
        // kill all clients
        for (iClient=0; iClient < NETSERVER_MAXCLIENTS; iClient++)
        {
            if (NetSocketGetStatus(&pServer->clients[iClient].Socket) != NETSOCKET_STATUS_INVALID)
            {
                _NetServerClientDisconnect(&pServer->clients[iClient]);
            }
        }
        return 0;
    }

    return 0;
}

int NetServerStart(NetServerT *pServer, int port)
{
    if (NetSocketGetStatus(&pServer->Socket) != NETSOCKET_STATUS_INVALID)
    {
        //
	    NetPrintf("NetServer: Server already started!\n");
        return -1;
    }

    NetPrintf( "NetServer: Starting server %d....\n", port);
    
    if (NetSocketListen(&pServer->Socket, port)==0)
	{
		NetPrintf( "NetServer: Server started on port %d.\n", port);
	}

    return 0;
}



void NetServerDumpStatus(NetServerT *pServer)
{
	Int32 iClient;
	NetPrintf("NetServer: Name='%s' gamestate=%d\n", pServer->Name, pServer->eGameState);
	for (iClient=0; iClient < NETSERVER_MAXCLIENTS; iClient++)
	{
		NetServerClientT *pClient = &pServer->clients[iClient];
		NetPrintf("NetServer: Client%d socket=%d name='%s' gamestate=%d\n", 
			iClient, pClient->Socket.status,
			pClient->Name,
			pClient->eGameState
			);
	}


}



#if 0
#define BUFFER_SIZE  4024 
static int _NetServerClientRead( NetSocketT *pSocket, NetServerClientT *pClient )
{
    int rcvSize,sntSize;
    static char recvbuffer[ BUFFER_SIZE ];

    // recv data
    rcvSize = NetSocketRecv( pSocket, recvbuffer, BUFFER_SIZE, 0 );
    if (rcvSize > 0)
    {
        // send echo
        sntSize = NetSocketSend( pSocket, recvbuffer, rcvSize, 0 );
        if ( sntSize != rcvSize )
        {
            NetPrintf( "NetServer: send != recv\n" );
        }
    }
}    

static int _NetServerClientConnect( NetSocketT *pSocket, NetServerClientT *pClient )
{
    char str[32];
    sprintf(str, "Welcome client %d\n\r", pClient->clientid);
    NetSocketSend(pSocket, str, strlen(str), 0);
    return 0;
}
#endif
