
#include <tamtypes.h>
#include <stdlib.h>
#include <sifrpc.h>
#include <kernel.h>
#include <fileio.h>
#include <stdio.h>
#include <sifcmd.h>
#include <sifrpc.h>
#include <libsd.h>
#include <sysmem.h>

#define	MCSAVE_IRX		0xB0D1DCD
#define MCSAVE_PUTS		0x01
#define	MCSAVE_INIT		0x02
#define MCSAVE_STORE	0x03
#define MCSAVE_QUIT		0x04
#define MCSAVE_DREAD	0x05

static SifRpcDataQueue_t qd;
static SifRpcServerData_t sd0;

void MCSave_Thread(void* param);
void MCSave_PlayThread(void* param);

void* MCSave_rpc_server(int fno, void *data, int size);
void* MCSave_Puts(char* s);
void* MCSave_Init(unsigned int* sbuff);
void* MCSave_Write(unsigned * s);
void* MCSave_DRead(unsigned * sbuff);
void* MCSave_Quit();

static unsigned int buffer[0x80];

static int _MCSave_uBufferSize;
static char *_MCSave_pBuffer;

int _start ()
{
  struct t_thread param;
  int th;

  FlushDcache();

  param.type         = TH_C;
  param.function     = MCSave_Thread;
  param.priority 	 = 40;
  param.stackSize    = 0x800;
  param.unknown      = 0;
  th = CreateThread(&param);
  if (th > 0) {
  	StartThread(th,0);
	return 0;
  }
  else return 1;

}

void MCSave_Thread(void* param)
{
  printf("MCSave IRX v1.0\n");

  SifInitRpc(0);
  SifSetRpcQueue(&qd, GetThreadId());
  SifRegisterRpc(&sd0, MCSAVE_IRX,MCSave_rpc_server,(void *) &buffer[0],0,0,&qd);
  SifRpcLoop(&qd);
}



void* MCSave_rpc_server(int fno, void *data, int size)
{

	switch(fno) {
		case MCSAVE_INIT:
			return MCSave_Init((unsigned*)data);
		case MCSAVE_PUTS:
			return MCSave_Puts((char*)data);
		case MCSAVE_STORE:
			return MCSave_Write((unsigned*)data);
		case MCSAVE_DREAD:
			return MCSave_DRead((unsigned*)data);
		case MCSAVE_QUIT:
			return MCSave_Quit();
	}

	return NULL;
}

void* MCSave_Puts(char* s)
{
	printf("MCSave: %s",s);

	return NULL;
}

static fio_dirent_t dbuff  __attribute__((aligned(16)));

void* MCSave_DRead(unsigned * sbuff)
{
	struct t_SifDmaTransfer dmaStruct;
	int intStatus;	// interrupt status - for dis/en-abling interrupts

	int result;

	// read directory entry
	result = dread(sbuff[0], &dbuff);
	if (result > 0)
	{
		int dmaID;

		// setup dma
		dmaStruct.src  = (void *)&dbuff;
		dmaStruct.dest = (void *)sbuff[1];
		dmaStruct.size = sizeof(fio_dirent_t);
		dmaStruct.attr = 0;

		// Do the DMA transfer
		CpuSuspendIntr(&intStatus);

		dmaID = SifSetDma(&dmaStruct, 1);

		CpuResumeIntr(intStatus);

		// wait for any previous DMA to complete
		// before over-writing localTocEntry
		while(SifDmaStat(dmaID)>=0);
	}

	// return result
    sbuff[0] = result;
	return sbuff;
}


void* MCSave_Write(unsigned * sbuff)
{
    int nBytes;
    char *pFileName;
    int fd;
    
    nBytes = sbuff[0];
    pFileName = (char *)&sbuff[1];

	printf("MCSave: %d %s\n", nBytes, pFileName);

    fd = open(pFileName, O_WRONLY | O_CREAT);
    if (fd >= 0)
    {
        int ret;
        ret = write(fd, _MCSave_pBuffer, nBytes);
        close(fd);
        
    	printf("MCSave: Done %d\n", ret);
        sbuff[0] = 1;
    } else
    {
        sbuff[0] = 0;
    }
	return sbuff;
}

void* MCSave_Init(unsigned int* sbuff)
{
    _MCSave_uBufferSize = sbuff[0];

	// Allocate memory
	_MCSave_pBuffer = AllocSysMemory(0,_MCSave_uBufferSize,NULL);
	if(_MCSave_pBuffer == NULL) {
		printf("MCSave: Failed to allocate memory for buffer!\n");
		ExitDeleteThread();
	}

	printf("MCSave: Memory Allocated. %d bytes left.\n", QueryTotalFreeMemSize());

	sbuff[1] = (unsigned)_MCSave_pBuffer;
	return sbuff;
}

void* MCSave_Quit(unsigned int* sbuff)
{
	return sbuff;
}

