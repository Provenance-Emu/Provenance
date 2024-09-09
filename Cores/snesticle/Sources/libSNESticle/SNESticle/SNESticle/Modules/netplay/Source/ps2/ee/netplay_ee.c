

#include <tamtypes.h>
#include <kernel.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sifrpc.h>
#include <stdarg.h>
#include "netplay.h"
#include "netplay_rpc.h"
#include "netplay_ee.h"

// ee rpc client
static unsigned sbuff[64] __attribute__((aligned (64)));
static unsigned rbuff[64] __attribute__((aligned (64)));
static SifRpcClientData_t cd0;

// ee rpc server
static unsigned int buffer[0x80] __attribute__((aligned (64)));
static SifRpcDataQueue_t qd;
static SifRpcServerData_t sd0;

static int netplay_inited = 0;
static int _netplay_sema;

static int _NetPlayCallRPC(int rpcnum, int sendsize, int recvsize)
{
    int result;
    
	WaitSema(_netplay_sema);

	if(netplay_inited)
    {
        result = SifCallRpc(&cd0,rpcnum,0,(void*)(&sbuff[0]),sendsize,(void*)(&sbuff[0]),recvsize,0,0);
    } else
    {
    
        // return 0 buffer
        memset(sbuff, 0, recvsize);
        result = -100;
    }
	SignalSema(_netplay_sema);
    return result;
}

void NetPlayPuts(char *format, ...)
{
	static char buff[4096];
    va_list args;
    int rv;

	if(!netplay_inited) return;

    va_start(args, format);
    rv = vsnprintf(buff, 4096, format, args);

	memcpy((char*)(&sbuff[0]),buff,252);
    _NetPlayCallRPC(NETPLAY_RPC_PUTS, 252,252);
}

void NetPlayRPCProcess()
{
    SifRpcServerData_t *pReq;
    
    while ((pReq = SifGetNextRequest(&qd)) != NULL)
    {
        SifExecRequest(pReq);
    }
}

int NetPlayInit(void *pCallback)
{
	int i;
    ee_sema_t compSema;

    
    SifSetRpcQueue(&qd, GetThreadId());
    SifRegisterRpc(&sd0, NETPLAY_RPC_EE, pCallback,(void *) &buffer[0],0,0,&qd);

	while(1)
    {
		if (SifBindRpc( &cd0, NETPLAY_RPC_IRX, 0) < 0) return -1; // bind error
 		if (cd0.server != 0) break;
    	i = 0x10000;
    	while(i--);
	}

	SifCallRpc(&cd0,NETPLAY_RPC_INIT,0,(void*)(&sbuff[0]),64,(void*)(&sbuff[0]),64,0,0);

	FlushCache(0);


    compSema.init_count = 1;
	compSema.max_count = 1;
	compSema.option = 0;
	_netplay_sema = CreateSema(&compSema);
	if (_netplay_sema < 0)
		return -1;


	netplay_inited = 1;
	return 0;
}

int NetPlayServerStart(int port, int latency)
{
	if(!netplay_inited) return -100;

    sbuff[0] = port;
    sbuff[1] = latency;
    _NetPlayCallRPC(NETPLAY_RPC_SERVERSTART, 4,4);
    return sbuff[0];
}

void NetPlayServerStop()
{
	if(!netplay_inited) return;

    _NetPlayCallRPC(NETPLAY_RPC_SERVERSTOP, 0,0);
}



int NetPlayClientConnect(unsigned ipaddr, int port)
{
	if(!netplay_inited) return -100;

    sbuff[0] = ipaddr;
    sbuff[1] = port;
    _NetPlayCallRPC(NETPLAY_RPC_CLIENTCONNECT, 8,4);
    return sbuff[0];
}

int NetPlayClientDisconnect()
{
	if(!netplay_inited) return -100;

    _NetPlayCallRPC(NETPLAY_RPC_CLIENTDISCONNECT, 0,4);
    return sbuff[0];
}

int NetPlayServerPingAll()
{
	if(!netplay_inited) return -100;

    _NetPlayCallRPC(NETPLAY_RPC_SERVERPINGALL, 0,0);
    return 0;
}

int NetPlayGetStatus(NetPlayRPCStatusT *pStatus)
{
    memset(pStatus, 0, sizeof(*pStatus));
	if(!netplay_inited) return 0;

    _NetPlayCallRPC(NETPLAY_RPC_GETSTATUS, 0, sizeof(NetPlayRPCStatusT));
    
    memcpy(pStatus, sbuff, sizeof(NetPlayRPCStatusT));
    return 1;
}

void NetPlayClientSendLoadReq(char *pStr)
{
	if(!netplay_inited) return;
    
    strcpy((char *)&sbuff[0], pStr ? pStr : "");

    _NetPlayCallRPC(NETPLAY_RPC_CLIENTSENDLOADREQ, 128, 0);
}

void NetPlayClientSendLoadAck(NetPlayLoadAckE eLoadAck)
{
	if(!netplay_inited) return;

    sbuff[0] = eLoadAck;    
    _NetPlayCallRPC(NETPLAY_RPC_CLIENTSENDLOADACK, 4, 0);
}


#if 0
void NetPlayClientInput(NetPlayRPCInputT *pInput)
{
    pInput->eGameState = NETPLAY_GAMESTATE_PAUSE;

	if(!netplay_inited) return;
    
    memcpy(sbuff, pInput, sizeof(*pInput));

	SifCallRpc(&cd0, NETPLAY_RPC_CLIENTINPUT,0,(void*)(&sbuff[0]),sizeof(NetPlayRPCInputT),(void*)(&rbuff[0]),sizeof(NetPlayRPCInputT),0,0);

    memcpy(pInput, rbuff, sizeof(*pInput));

}
#else

void _Netplay_InputIntr(unsigned *arg)
{
	iSignalSema(_netplay_sema);
}


void NetPlayClientInput(NetPlayRPCInputT *pInput)
{
    pInput->eGameState = NETPLAY_GAMESTATE_PAUSE;

	if(!netplay_inited)
    {
        pInput->eGameState = NETPLAY_GAMESTATE_IDLE;
         return;
    }

	WaitSema(_netplay_sema);
    
    // copy to output
    memcpy(sbuff, pInput, sizeof(*pInput));

    // get last input
    memcpy(pInput, rbuff, sizeof(*pInput));

    // trigger next call
	SifCallRpc(&cd0, NETPLAY_RPC_CLIENTINPUT,1,(void*)(&sbuff[0]),sizeof(NetPlayRPCInputT),(void*)(&rbuff[0]),sizeof(NetPlayRPCInputT),(void *)_Netplay_InputIntr,rbuff);
}
#endif





