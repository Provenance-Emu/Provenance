
#include <tamtypes.h>
#include <stdlib.h>
#include <sifrpc.h>
#include <kernel.h>
#include <stdio.h>
#include <sifcmd.h>
#include <sifrpc.h>
#include <sysmem.h>
#include <ps2ip.h>
#include "netplay_rpc.h"
#include "netserver.h"
#include "netclient.h"
#include "netprint.h"
#include "netsys.h"
     
static SifRpcClientData_t cd0;

static SifRpcDataQueue_t qd;
static SifRpcServerData_t sd0;

void NetPlay_RpcThread(void* param);
void* NetPlay_rpc_server(int fno, void *data, int size);

static unsigned int buffer[0x80];
static char _clientcallbackdata[0x100];
static NetSysSemaT _clientcallback_sema;

static NetServerT _server;
static NetClientT _client;


int _start ()
{
  FlushDcache();
  
  NetPrintInit();
  
  if (NetSysThreadStart(NetPlay_RpcThread, 32, 0) > 0)
  {
     printf("NetPlay Initialized!\n");
    return 0;
  } else
  {
     printf("NetPlay could not start thread\n");
    return 1;
  }

}

void NetPlay_RpcThread(void* param)
{
  printf("NetPlay v0.0.2\n");
  printf("NetPlay: RPC Initialize\n");

  SifInitRpc(0);

  SifSetRpcQueue(&qd, GetThreadId());
  SifRegisterRpc(&sd0, NETPLAY_RPC_IRX,NetPlay_rpc_server,(void *) &buffer[0],0,0,&qd);
  SifRpcLoop(&qd);
}


void* NetPlay_Puts(char* s)
{
	printf("NetPlay: %s",s);

	return NULL;
}

int NetPlay_ServerStart(int port)
{
    return NetServerStart(&_server, port);
}

int NetPlay_ServerStop()
{
    return NetServerStop(&_server);
}


int NetPlay_ClientConnect(unsigned ipaddr, int port)
{
    return NetClientConnect(&_client, ipaddr, port);
}

int NetPlay_ClientDisconnect()
{
    return NetClientDisconnect(&_client);
}


#include "ps2ip.h"

#if 0
int _test()
{
    struct sockaddr_in addr;
    int sock;
    int rc;
    static char data[16]="blahlala\n\n\n\n";
    static char recvdata[512];
    
    
    sock     = socket( AF_INET, SOCK_STREAM, IPPROTO_TCP );
    if (socket < 0)
    {
        printf( "Failed to create socket\n" );
        return -1;
    } 
    
    
    memset( &addr, 0 , sizeof(addr));
    addr.sin_len    = sizeof(addr);
    addr.sin_family = AF_INET;

//	IP4_ADDR( &(addr.sin_addr),192,168,1,100 );
	IP4_ADDR( &(addr.sin_addr),216,109,125,69 );
    addr.sin_port = htons(80);


    printf("NetSocket: Connecting %X:%X %d..\n", addr.sin_addr.s_addr, addr.sin_port, sock);
    rc = connect(sock, (struct sockaddr *)&addr, sizeof(addr));
    if (rc < 0)
    {
        printf("NetSocket: Connect failed (%d)\n", rc);
        return -1;
    }

	printf("NetSocket: Connect %d\n", rc);
    
    printf("NetSocket: Sending ..\n");
    rc = send(sock, data, sizeof(data), 0);
    printf("NetSocket: Sent %d ..\n",rc);

    printf("NetSocket: Recving ..\n");
    rc = recv(sock, recvdata, sizeof(recvdata), 0);
    printf("NetSocket: Recv %d ..\n",rc);
    recvdata[rc]=0;
    printf("%s\n", recvdata);
    

    disconnect(sock);
    printf("NetSocket: Disconnected..\n");
    return 0;

}
#endif

#if 0

int _GameLoop(NetClientT *pClient)
{
	printf("Gameloop: Started\n");

	while (pClient->eStatus == NETPLAY_STATUS_CONNECTED)
	{
		Bool result;
		Uint32 Input[4];
        static int tempinput = 0xCCCC;
        
		result = NetClientRecvInput(pClient, 4, Input);
		if (result)
		{
			printf("frame %04X %04X %04X %04X %3d i%2d o%2d i%2d o%2d\n", 
				Input[0],Input[1],Input[2],Input[3],
				_client.uFrame,
				NetQueueGetCount(&_client.Peers[0].InputQueue),
				NetQueueGetCount(&_client.Peers[0].OutputQueue),
				NetQueueGetCount(&_client.Peers[1].InputQueue),
				NetQueueGetCount(&_client.Peers[1].OutputQueue)
				);

			NetClientEnqueueInput(pClient,tempinput++);
		} else
		{
		   	printf("input stalled\n");
		}
		NetClientTransmit(pClient);

		DelayThread(1000*1000);
	}

	printf("Gameloop: End\n");
	return 0;
}

#endif

static void _NetPlayRPC_ClientInput(NetClientT *pClient, NetPlayRPCInputT *pInput)
{
    pInput->uFrame = pClient->uFrame + 1;
    
    if (pClient->eStatus == NETPLAY_STATUS_CONNECTED)
    {
        int iPeer;
    
		// transmit/recv input data now
		if (NetClientProcess(pClient, pInput->InputSend, NETPLAY_RPC_NUMPEERS, pInput->InputRecv))
		{
            pInput->eGameState = NETPLAY_GAMESTATE_PLAY;
		} else
		{
            pInput->eGameState = NETPLAY_GAMESTATE_PAUSE;
		}
        
        for (iPeer=0; iPeer < 4; iPeer++)
        {
            pInput->InputSize[iPeer]  = NetQueueGetCount(&pClient->Peers[iPeer].InputQueue);
            pInput->OutputSize[iPeer] = NetQueueGetCount(&pClient->Peers[iPeer].OutputQueue);
        }
    
    } else
    {
        pInput->eGameState = NETPLAY_GAMESTATE_IDLE;
    }
    
}


static void _Netplay_InputIntr(unsigned *arg)
{
	iSignalSema(_clientcallback_sema);
}


static int _ClientCallback(NetClientT *pClient, NetPlayCallbackE eMsg, void *arg)
{
    int arglen;
    
    NetSysSemaWait(_clientcallback_sema);
    
    // set current callback data
    strcpy(_clientcallbackdata, arg ? arg : "");
    arglen = strlen(_clientcallbackdata) + 1;

    // call rpc async
    SifCallRpc(&cd0, eMsg, 1, _clientcallbackdata, arglen, NULL, 0, (void *)_Netplay_InputIntr, 0);

	switch (eMsg)
	{
	case NETPLAY_CALLBACK_LOADGAME:
		printf("iopcallback: LoadGame %s\n", (char *)arg);
		break;

	case NETPLAY_CALLBACK_UNLOADGAME:
		printf("iopcallback: UnloadGame\n");
		break;

	case NETPLAY_CALLBACK_CONNECTED:
		printf("iopcallback: connected\n");
		break;

	case NETPLAY_CALLBACK_DISCONNECTED:
		printf("iopcallback: disconnected\n");
		break;

	case NETPLAY_CALLBACK_STARTGAME:
		printf("iopcallback: startgame\n");
		break;
        
    default:
        break;

	}
	return 0;
}

static void* _NetPlayRPC_Init(unsigned int* sbuff)
{
    _clientcallback_sema = NetSysSemaNew(1);

    // bind to ee rpc server
	while(1)
    {
	    int i;
		if (SifBindRpc( &cd0, NETPLAY_RPC_EE, 0) < 0)
        {
            NetPrintf("NetPlay: ERROR Failed to bind to EE rpc\n");
            break;
        }             
 		if (cd0.server != 0) break;
    	i = 0x10000;
    	while(i--);
	}

    
    NetServerNew(&_server);
    NetClientNew(&_client);
	NetClientSetCallback(&_client, _ClientCallback);

	printf("NetPlay: Initialized %dK\n",QueryTotalFreeMemSize() / 1024);
	return sbuff;
}

static void _NetPlayRPC_Quit(unsigned int* sbuff)
{
    NetSysSemaDelete(_clientcallback_sema);
    NetClientDelete(&_client);
    NetServerDelete(&_server);

}

void _NetPlayRPC_GetStatus(NetPlayRPCStatusT *pStatus, NetClientT *pClient, NetServerT *pServer)
{
    int iPeer;
    memset(pStatus, 0, sizeof(*pStatus));
    pStatus->eClientStatus = pClient->eStatus;
    pStatus->eGameState    = pClient->eGameState;

    pStatus->eServerStatus = pServer->eStatus;
    
    for (iPeer=0; iPeer < 4; iPeer++)
    {
        NetPlayRPCPeerStatusT *pPeerStatus = &pStatus->peer[iPeer];
        
        pPeerStatus->eStatus =    pClient->Peers[iPeer].eStatus;
        pPeerStatus->eGameState = pClient->Peers[iPeer].eGameState;
        pPeerStatus->ipaddr  = pClient->Peers[iPeer].Addr.sin_addr;
        pPeerStatus->udpport = pClient->Peers[iPeer].Addr.sin_port;
        
        pPeerStatus->InputSize  = NetQueueGetCount(&pClient->Peers[iPeer].InputQueue);
        pPeerStatus->OutputSize = NetQueueGetCount(&pClient->Peers[iPeer].OutputQueue);
    }

}


void* NetPlay_rpc_server(int fno, void *data, int size)
{
    int *buf =(int *)data;
    
//    NetPrintf("NetRPCMessage %d\n",fno);
    
	switch(fno) {
		case NETPLAY_RPC_INIT:
			return _NetPlayRPC_Init((unsigned*)data);
		case NETPLAY_RPC_QUIT:
            {
                _NetPlayRPC_Quit((unsigned*)data);
			    return NULL;
            }
		case NETPLAY_RPC_PUTS:
			return NetPlay_Puts((char*)data);
        case NETPLAY_RPC_SERVERSTART:
            {
                _server.uStartLatency = buf[1];
                buf[0] = NetPlay_ServerStart(buf[0]);
                return buf;
            }
        case NETPLAY_RPC_SERVERSTOP:
            {
                buf[0] = NetPlay_ServerStop();
                return buf;
            }

        case NETPLAY_RPC_CLIENTCONNECT:
            {
                buf[0] = NetPlay_ClientConnect(buf[0], buf[1]);
                return buf;                                 
            }

        case NETPLAY_RPC_CLIENTDISCONNECT:
            {
                buf[0] = NetPlay_ClientDisconnect();
                return buf;
            }

        case NETPLAY_RPC_CLIENTSENDLOADREQ:
            {
                NetClientSendLoadReq(&_client, (char *)&buf[0]);
                return NULL;
            }

        case NETPLAY_RPC_CLIENTSENDLOADACK:
            {
                NetClientSendLoadAck(&_client, buf[0]);
                return NULL;
            }


        case NETPLAY_RPC_CLIENTINPUT:
            {
                _NetPlayRPC_ClientInput(&_client, (NetPlayRPCInputT *)buf);
                return buf;
            }

        case NETPLAY_RPC_GETSTATUS:
            {
                _NetPlayRPC_GetStatus((NetPlayRPCStatusT *)buf, &_client, &_server);
                return buf;                                 
            }

        case NETPLAY_RPC_SERVERPINGALL:
            {
                NetServerSendText(&_server, "test");
                return NULL;                                 
            }
	}

	return NULL;
}
