/*
  _____     ___ ____
   ____|   |    ____|      PS2LIB OpenSource Project
  |     ___|   |____       (C)2002, Pukko 
  ------------------------------------------------------------------------
  pad.c

  Pad library functions
  Quite easy rev engineered from util demos..
  Find any bugs? Mail me: pukko@home.se
 
  rev 1.3 (20030416)
*/


#include <tamtypes.h>
#include <kernel.h>
#include <sifrpc.h>
#include <sifcmd.h>
#include "libxmtap.h"



/*
 * Defines
 */

#define MTAP_BIND_RPC_ID1 0x80000901
#define MTAP_BIND_RPC_ID2 0x80000902

#define MTAP_RPCCMD_INIT 0x00
#define MTAP_RPCCMD_OPEN 0x01
#define MTAP_RPCCMD_CLOSE 0x02
#define MTAP_RPCCMD_END   0x03

// pad rpc call
static SifRpcClientData_t mtapsif[2] __attribute__((aligned(64)));
static u32 buffer[32] __attribute__((aligned(16)));
static int mtapInitialised = 0;

int
xmtapInit(int a)
{
//	int i;

    if(mtapInitialised)
        return 0;

    mtapsif[0].server = NULL;
    mtapsif[1].server = NULL;
    
//	printf("xmtap: bind %08X\n", MTAP_BIND_RPC_ID1);
    do {
        if (SifBindRpc(&mtapsif[0], MTAP_BIND_RPC_ID1, 0) < 0) {
            return -1;
        }
        nopdelay();
    } while(!mtapsif[0].server);


//	printf("xmtap: bind %08X\n", MTAP_BIND_RPC_ID2);
    do {
        if (SifBindRpc(&mtapsif[1], MTAP_BIND_RPC_ID2, 0) < 0) {
            return -3;
        }
        nopdelay();
    } while(!mtapsif[1].server);

//	printf("xmtap: bind done\n");

    buffer[0]=MTAP_RPCCMD_INIT;
	if (SifCallRpc( &mtapsif[0], 1, 0, buffer, 128, buffer, 128, 0, 0) < 0)
	{
        return -1;
	}

#if 0
	for (i=0; i < 16; i++)
		printf("mtap-init %d=%08X\n", i,buffer[i]);
#endif

//	printf("mtap-init %08X\n", buffer[0]);

    mtapInitialised = 1;
    return buffer[1];
}




int
xmtapPortOpen(int port, int slot)
{
//    int i;

    buffer[0] = MTAP_RPCCMD_OPEN;
    buffer[1] = port;
    buffer[2] = slot;
    buffer[3] = 0;
    
    if (SifCallRpc(&mtapsif[0], 1, 0, buffer, 128, buffer, 128, 0, 0) < 0)
	{
		return 0;
	}

#if 0
	for (i=0; i < 16; i++)
		printf("mtap-open %d=%08X\n", i,buffer[i]);
#endif

    return buffer[1];
}






