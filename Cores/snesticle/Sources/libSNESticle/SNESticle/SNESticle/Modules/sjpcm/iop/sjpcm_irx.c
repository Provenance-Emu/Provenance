/*
    ----------------------------------------------------------------------
    sjpcm_irx.c - SjPCM IOP-side code. (c) Nick Van Veen (aka Sjeep), 2002
	----------------------------------------------------------------------

    This library is free software; you can redistribute it and/or
	modify it under the terms of the GNU Lesser General Public
	License as published by the Free Software Foundation; either
	version 2.1 of the License, or (at your option) any later version.

	This library is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	Lesser General Public License for more details.

	You should have received a copy of the GNU Lesser General Public
	License along with this library; if not, write to the Free Software
	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

*/

#include <tamtypes.h>
#include <stdlib.h>
#include <sifrpc.h>
#include <kernel.h>
#include <stdio.h>
#include <sifcmd.h>
#include <sifrpc.h>
#include <libsd.h>
#include <sysmem.h>

#define SJPCM_PRIORITY_RPCSERVER  (20)
#define SJPCM_PRIORITY_PLAYTHREAD (19)

// LIBSD defines

#define SD_CORE_1			1
#define SD_P_BVOLL			((0x0F<<8)+(0x01<<7))
#define SD_P_BVOLR			((0x10<<8)+(0x01<<7))
#define SD_P_MVOLL			((0x09<<8)+(0x01<<7))
#define SD_P_MVOLR			((0x0A<<8)+(0x01<<7))

#define SD_INIT_COLD		0
#define SD_C_NOISE_CLK		(4<<1)

#define SD_BLOCK_ONESHOT	(0<<4)
#define SD_BLOCK_LOOP		(1<<4)

#define SD_TRANS_MODE_STOP  2

////////////////

#define	SJPCM_IRX		0xB0110C5
#define SJPCM_PUTS		0x01
#define	SJPCM_INIT		0x02
#define SJPCM_PLAY		0x03
#define SJPCM_PAUSE		0x04
#define SJPCM_SETVOL	0x05
#define SJPCM_ENQUEUE	0x06
#define SJPCM_CLEARBUFF	0x07
#define SJPCM_QUIT		0x08
#define SJPCM_GETAVAIL  0x09
#define SJPCM_GETBUFFD  0x10

#define TH_C		0x02000000

SifRpcDataQueue_t qd;
SifRpcServerData_t sd0;

void SjPCM_Thread(void* param);
void SjPCM_PlayThread(void* param);
static int SjPCM_TransCallback(void* param);

void* SjPCM_rpc_server(int fno, void *data, int size);
void* SjPCM_Puts(char* s);
void* SjPCM_Init(unsigned int* sbuff);
void* SjPCM_Enqueue(unsigned int* sbuff);
void* SjPCM_Play();
void* SjPCM_Pause();
void* SjPCM_Setvol(unsigned int* sbuff);
void* SjPCM_Clearbuff();
void* SjPCM_Available(unsigned int* sbuff);
void* SjPCM_Buffered(unsigned int* sbuff);
void* SjPCM_Quit();

extern void wmemcpy(void *dest, void *src, int numwords);

static unsigned int buffer[0x80];

char *pcmbufl;
char *pcmbufr;
char *spubuf;

int pcmbufsize; // size of pcm buffer (in bytes)
int pcmbufloop; // pcm buffer loop position
int maxenqueuesize; // maximum number of bytes that can be enqueued at once

int readpos = 0;
int writepos = 0;

int writetotal =0;
int readtotal;

int volume = 0x3fff;

int transfer_sema = 0;
int play_tid = 0;

int intr_state;


int _start ()
{
  struct t_thread param;
  int th;

  FlushDcache();

  CpuEnableIntr(0);
  EnableIntr(36);	// Enables SPU DMA (channel 0) interrupt.
  EnableIntr(40);	// Enables SPU DMA (channel 1) interrupt.
  EnableIntr(9);	// Enables SPU IRQ interrupt.

  param.type         = TH_C;
  param.function     = SjPCM_Thread;
  param.priority 	 = SJPCM_PRIORITY_RPCSERVER;
  param.stackSize    = 0x800;
  param.unknown      = 0;
  th = CreateThread(&param);
  if (th > 0) {
  	StartThread(th,0);
	return 0;
  }
  else return 1;

}

void SjPCM_Thread(void* param)
{
  printf("SjPCM v2.1 - by Sjeep\n");

  printf("SjPCM: RPC Initialize\n");
  SifInitRpc(0);

  SifSetRpcQueue(&qd, GetThreadId());
  SifRegisterRpc(&sd0, SJPCM_IRX,SjPCM_rpc_server,(void *) &buffer[0],0,0,&qd);
  SifRpcLoop(&qd);
}

void* SjPCM_rpc_server(int fno, void *data, int size)
{

	switch(fno) {
		case SJPCM_INIT:
			return SjPCM_Init((unsigned*)data);
		case SJPCM_PUTS:
			return SjPCM_Puts((char*)data);
		case SJPCM_ENQUEUE:
			return SjPCM_Enqueue((unsigned*)data);
		case SJPCM_PLAY:
			return SjPCM_Play();
		case SJPCM_PAUSE:
			return SjPCM_Pause();
		case SJPCM_SETVOL:
			return SjPCM_Setvol((unsigned*)data);
		case SJPCM_CLEARBUFF:
			return SjPCM_Clearbuff();
		case SJPCM_QUIT:
			return SjPCM_Quit();
		case SJPCM_GETAVAIL:
			return SjPCM_Available((unsigned*)data);
		case SJPCM_GETBUFFD:
			return SjPCM_Buffered((unsigned*)data);
	}

	return NULL;
}

void* SjPCM_Clearbuff()
{
	CpuSuspendIntr(&intr_state);

	memset(spubuf,0,0x800);
	memset(pcmbufl,0,pcmbufsize);
	memset(pcmbufr,0,pcmbufsize);

	CpuResumeIntr(intr_state);
	
	return NULL;
}

void* SjPCM_Play()
{
	SdSetParam(SD_CORE_1|SD_P_BVOLL,volume);
	SdSetParam(SD_CORE_1|SD_P_BVOLR,volume);

	return NULL;
}

void* SjPCM_Pause()
{
	SdSetParam(SD_CORE_1|SD_P_BVOLL,0);
	SdSetParam(SD_CORE_1|SD_P_BVOLR,0);

	return NULL;
}

void* SjPCM_Setvol(unsigned int* sbuff)
{
	volume = sbuff[5];

	SdSetParam(SD_CORE_1|SD_P_BVOLL,volume);
	SdSetParam(SD_CORE_1|SD_P_BVOLR,volume);

	return NULL;
}

void* SjPCM_Puts(char* s)
{
	printf("SjPCM: %s",s);

	return NULL;
}

void* SjPCM_Init(unsigned int* sbuff)
{
	struct t_sema sema;
	struct t_thread play_thread;
/*
	int i=0,j=0;
	short *temppcmbufl,*temppcmbufr;
*/

    // get pcm buffer size (in bytes)
    pcmbufsize     = sbuff[1] * 2;
    if (pcmbufsize < 512 * 2) pcmbufsize = 960*20*2;   // default to old value

    // get maximum enqueue size (in bytes)
    maxenqueuesize = sbuff[2] * 2;
                   
                   
    
    printf("SjPCM: BufferSize=%d bytes, MaxEnqueue=%d\n", pcmbufsize, maxenqueuesize);

    // set loop point 
    pcmbufloop     = pcmbufsize - maxenqueuesize;

	sema.attr = SA_THFIFO;
	sema.init_count = 0;
	sema.max_count = 1;
	transfer_sema= CreateSema(&sema);
	if(transfer_sema <= 0) {
		printf("SjPCM: Failed to create semaphore!\n");
		ExitDeleteThread();
	}

	// Allocate memory
	pcmbufl = AllocSysMemory(0,pcmbufsize,NULL);
	if(pcmbufl == NULL) {
		printf("SjPCM: Failed to allocate memory for sound buffer!\n");
		ExitDeleteThread();
	}
	pcmbufr = AllocSysMemory(0,pcmbufsize,NULL);
	if(pcmbufr == NULL) {
		printf("SjPCM: Failed to allocate memory for sound buffer!\n");
		ExitDeleteThread();
	}
	spubuf = AllocSysMemory(0,0x800,NULL);
	if(spubuf == NULL) {
		printf("SjPCM: Failed to allocate memory for sound buffer!\n");
		ExitDeleteThread();
	}

	printf("SjPCM: Memory Allocated. %d bytes left.\n",QueryTotalFreeMemSize());

	memset(pcmbufl,0,pcmbufsize);
	memset(pcmbufr,0,pcmbufsize);
	memset(spubuf,0,0x800);

	printf("SjPCM: Sound buffers cleared\n");
/*
	// FOR DEBUG - SET PCMBUFL/R TO SQUARE WAVE
	temppcmbufl = (short*)pcmbufl;
	temppcmbufr = (short*)pcmbufr;

	for(i=0;i<pcmbufsize;i++) {
		if(!(i%480)) j ^= 1;
		if(j) {
			temppcmbufl[i] = 16000;
			temppcmbufr[i] = 16000;
		} else {
			temppcmbufl[i] = -16000;
			temppcmbufr[i] = -16000;
		}
	}
	memcpy(spubuf, pcmbufl,0x800);
*/
	// Initialise SPU
	if(SdInit(SD_INIT_COLD) < 0) {
		printf("SjPCM: Failed to initialise libsd!\n");
		ExitDeleteThread();
	}
	else printf("SjPCM: libsd initialised!\n");

	SdSetCoreAttr(SD_CORE_1|SD_C_NOISE_CLK,0);
	SdSetParam(SD_CORE_1|SD_P_MVOLL,0x3fff);
	SdSetParam(SD_CORE_1|SD_P_MVOLR,0x3fff);
	SdSetParam(SD_CORE_1|SD_P_BVOLL,volume);
	SdSetParam(SD_CORE_1|SD_P_BVOLR,volume);

	SdSetTransCallback(1,(void *)SjPCM_TransCallback);

	// Start audio streaming
	SdBlockTrans(1,SD_BLOCK_LOOP,spubuf, 0x800);

	printf("SjPCM: Setting up playing thread\n");

	// Start playing thread
	play_thread.type         = TH_C;
  	play_thread.function     = SjPCM_PlayThread;
  	play_thread.priority 	 = SJPCM_PRIORITY_PLAYTHREAD;
  	play_thread.stackSize    = 0x800;
  	play_thread.unknown      = 0;
  	play_tid = CreateThread(&play_thread);
	if (play_tid > 0) StartThread(play_tid,0);
	else {
		printf("SjPCM: Failed to start playing thread!\n");
		ExitDeleteThread();
	}

	// Return data
	sbuff[1] = (unsigned)pcmbufl;
	sbuff[2] = (unsigned)pcmbufr;
	sbuff[3] = writepos;

	printf("SjPCM: Entering playing thread.\n");

	return sbuff;
}

void SjPCM_PlayThread(void* param)
{
	int which;

	while(1) {
        int bytes,totalbytes;
        int outpos;

		WaitSema(transfer_sema);

		// Interrupts are suspended, instead of using semaphores.
		CpuSuspendIntr(&intr_state);

		// determine which buffer to output to
		which = 1 - (SdBlockTransStatus(1, 0 )>>24);

		// outpos points to buffer to output to
        outpos = (1024*which);

		// we must output 512 bytes per channel
        totalbytes = 512;
        while (totalbytes > 0)
        {
			int numenqueued;

			// calculate number of bytes enqueued
			numenqueued = writetotal - readtotal;

			// are bytes available from enqueueing?
			if (numenqueued > 0)
			{
            	// determine number of bytes to end of pcm buffer (from the loop point)
            	bytes = pcmbufloop - readpos;
				// don't copy more bytes than needed
            	if (bytes > totalbytes) bytes = totalbytes;
				// don't copy more bytes than have been enqueued
				if (bytes > numenqueued) bytes = numenqueued;

            	// copy bytes            
    			wmemcpy(spubuf + outpos,      pcmbufl+readpos,bytes); // left
    			wmemcpy(spubuf + outpos + 512,pcmbufr+readpos,bytes);	// right

				// update total read
				readtotal+=bytes;
            	// advance read position
    			readpos += bytes;
            	// wrap read position if necessary
    			if(readpos >= (pcmbufloop)) readpos = 0;
			} else
			{
				// no bytes are available from the EE, so output silence
				bytes = totalbytes;
    			memset(spubuf + outpos,      0,bytes); // left
    			memset(spubuf + outpos + 512,0,bytes);	// right
			}

            // subtract from total
            totalbytes -= bytes;
            // advance out position
            outpos += bytes;
        }

		CpuResumeIntr(intr_state);

	}
}

void* SjPCM_Enqueue(unsigned int* sbuff)
{
	// update write position within buffer
	writepos += sbuff[0]*2;

	// update total # of samples enqueued
	writetotal += sbuff[0]*2;

    // wrap write position? ensure that maxenqueuesize samples are always available in pcm buffer
	if(writepos >= (pcmbufsize - maxenqueuesize)) 
    {
        // set loop position to last sample written
        pcmbufloop = writepos;
        // wrap write position
        writepos = 0;
    }

	sbuff[3] = writepos;

	return sbuff;
}

static int SjPCM_TransCallback(void* param)
{
	iSignalSema(transfer_sema);

	return 1;
}

void* SjPCM_Available(unsigned int* sbuff)
{
  unsigned int rp = readpos, wp = writepos;
  if (wp<rp) wp+=pcmbufloop;
  sbuff[3] = (pcmbufloop-(wp-rp))/2;
  return sbuff;
}

void* SjPCM_Buffered(unsigned int* sbuff)
{
  unsigned int rp = readpos, wp = writepos;
  if (wp<rp) wp+=pcmbufloop;
  sbuff[3] = (wp-rp)/2;
  return sbuff;
}

void* SjPCM_Quit(unsigned int* sbuff)
{

	SdSetTransCallback(1,NULL);
	SdBlockTrans(1,SD_TRANS_MODE_STOP,0,0);


	TerminateThread(play_tid);
	DeleteThread(play_tid);

	DeleteSema(transfer_sema);
/*
	FreeSysMemory(pcmbufl);
	FreeSysMemory(pcmbufr);
	FreeSysMemory(spubuf);
*/
	return sbuff;

}
