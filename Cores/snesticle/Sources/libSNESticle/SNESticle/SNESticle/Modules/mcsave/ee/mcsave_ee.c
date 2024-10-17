
#include <tamtypes.h>
#include <kernel.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sifrpc.h>
#include <stdarg.h>
#include <fileio.h>
#include "mcsave_ee.h"

static unsigned sbuff[64] __attribute__((aligned (64)));
static unsigned rbuff[64] __attribute__((aligned (64)));
static SifRpcClientData_t cd0;

static int _MCSave_bInitialized = 0;
static int _MCSave_uBufferAddr;
static int _MCSave_nBufferBytes;
static volatile int _MCSave_bAsync = 0;
static int _MCSave_Result;

static void _MCSave_StoreIntr(unsigned *arg)
{
    _MCSave_bAsync = 0;
	_MCSave_Result = arg[0];
}

int MCSave_IsInitialized()
{
	return _MCSave_bInitialized;
}

int MCSave_Init(int MaxSize)
{
	int i;

	while(1){
		if (SifBindRpc( &cd0, MCSAVE_IRX, 0) < 0) return -1; // bind error
 		if (cd0.server != 0) break;
    	i = 0x10000;
    	while(i--);
	}

	sbuff[0] = MaxSize;

	SifCallRpc(&cd0,MCSAVE_INIT,0,(void*)(&sbuff[0]),64,(void*)(&sbuff[0]),64,0,0);

	FlushCache(0);

	_MCSave_nBufferBytes = MaxSize;
	_MCSave_uBufferAddr = sbuff[1];
	_MCSave_bInitialized = 1;
	return 0;
}

int MCSave_WriteSync(int bSync, int *pResult)
{
	if (bSync)
	{
		// busy wait!
	    while (_MCSave_bAsync) ;
	}

	if (pResult)
	{
		// return result
		*pResult = _MCSave_Result;
	}

	return _MCSave_bAsync;
}

int MCSave_Write(char *pFileName, char *pData, int nBytes)
{
    int i;
    SifDmaTransfer_t sdt;

    MCSave_WriteSync(1, NULL);

	_MCSave_Result = 0;

	if (nBytes > _MCSave_nBufferBytes)
	{
		return 0;
	}

//    printf("MCSaveEE: %08X %d %s\n", (unsigned)pData, nBytes, pFileName);

    if (!_MCSave_bInitialized) return 0;

    // transfer data to sram buffer
    sdt.src = (void *)pData;
    sdt.dest = (void *)(_MCSave_uBufferAddr);
    sdt.size = nBytes;
    sdt.attr = 0;

	FlushCache(0);

    i = SifSetDma(&sdt, 1); // start dma transfer
//    while ((SifDmaStat(i) >= 0)); // wait for completion of dma transfer

    // perform async rpc
    _MCSave_bAsync= 1;
    SifWriteBackDCache(rbuff, 64);

    // call store
	sbuff[0] = nBytes;
    strcpy((char *)&sbuff[1], pFileName);
	SifCallRpc(&cd0,MCSAVE_STORE,1,(void*)(&sbuff[0]),64,(void*)(&rbuff[0]),64,(SifRpcEndFunc_t)_MCSave_StoreIntr,rbuff);

    return 1;
}

void MCSave_Shutdown()
{
	if(!_MCSave_bInitialized) return;

    MCSave_WriteSync(1, NULL);

	SifCallRpc(&cd0,MCSAVE_QUIT,0,(void*)(&sbuff[0]),0,(void*)(&sbuff[0]),0,0,0);
	_MCSave_bInitialized = 0;
}



int MCSave_Dread(int fd, fio_dirent_t *dir)
{
	union { int fd[2]; int result; } arg;

    MCSave_WriteSync(1, NULL);

	arg.fd[0] = fd;
	arg.fd[1] = (int)dir;

	if (!IS_UNCACHED_SEG(dir))
		SifWriteBackDCache(dir, sizeof(fio_dirent_t));

	SifCallRpc(&cd0,MCSAVE_DREAD,0,&arg,sizeof(arg),&arg, sizeof(arg), NULL, NULL);
	return arg.result;
}
