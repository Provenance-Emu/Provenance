/*
    ---------------------------------------------------------------------
    sjpcm_rpc.c - SjPCM EE-side code. (c) Nick Van Veen (aka Sjeep), 2002
	---------------------------------------------------------------------

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
#include <kernel.h>
#include <stdio.h>
#include <stdlib.h>
#include <sifrpc.h>
//#include <stdarg.h>
#include "sjpcm.h"


static unsigned sbuff[64] __attribute__((aligned (64)));


static unsigned enqueue_sbuff[64] __attribute__((aligned (64)));
static unsigned enqueue_rbuff[64] __attribute__((aligned (64)));

static unsigned buffered_sbuff[64] __attribute__((aligned (64)));
static unsigned buffered_rbuff[64] __attribute__((aligned (64)));

static SifRpcClientData_t cd0;

int sjpcm_inited = 0;
int pcmbufl, pcmbufr;
int bufpos;

static int _Buffered = 0;

static int _sjpcm_sema;


#if 0
void SjPCM_Puts(char *format, ...)
{
	static char buff[4096];
    va_list args;
    int rv;

	if(!sjpcm_inited) return;

    va_start(args, format);
    rv = vsnprintf(buff, 4096, format, args);

	memcpy((char*)(&sbuff[0]),buff,252);
	SifCallRpc(&cd0,SJPCM_PUTS,0,(void*)(&sbuff[0]),252,(void*)(&sbuff[0]),252,0,0);
}
#endif

void SjPCM_Play()
{
	if(!sjpcm_inited) return;

	SifCallRpc(&cd0,SJPCM_PLAY,0,(void*)(&sbuff[0]),0,(void*)(&sbuff[0]),0,0,0);
}

void SjPCM_Pause()
{
	if(!sjpcm_inited) return;

	SifCallRpc(&cd0,SJPCM_PAUSE,0,(void*)(&sbuff[0]),0,(void*)(&sbuff[0]),0,0,0);
}

void SjPCM_Setvol(unsigned int volume)
{
	if(!sjpcm_inited) return;

	sbuff[5] = volume&0x3fff;
	SifCallRpc(&cd0,SJPCM_SETVOL,0,(void*)(&sbuff[0]),64,(void*)(&sbuff[0]),64,0,0);
}

void SjPCM_Clearbuff()
{
	if(!sjpcm_inited) return;

	SifCallRpc(&cd0,SJPCM_CLEARBUFF,0,(void*)(&sbuff[0]),0,(void*)(&sbuff[0]),0,0,0);
}

int SjPCM_Init(int sync, int numsamples, int maxenqueuesamples)
{
	int i;
    ee_sema_t compSema;

/*
	do {
        if (sif_bind_rpc(&cd0, SJPCM_IRX, 0) < 0) {
            return -1;
        }
        nopdelay();
    } while(!cd0.server);
*/
	while(1){
		if (SifBindRpc( &cd0, SJPCM_IRX, 0) < 0) return -1; // bind error
 		if (cd0.server != 0) break;
    	i = 0x10000;
    	while(i--);
	}

	sbuff[0] = sync;
    sbuff[1] = numsamples;
    sbuff[2] = maxenqueuesamples;

	FlushCache(0);

	SifCallRpc(&cd0,SJPCM_INIT,0,(void*)(&sbuff[0]),64,(void*)(&sbuff[0]),64,0,0);

	FlushCache(0);

	pcmbufl = sbuff[1];
	pcmbufr = sbuff[2];
	bufpos = sbuff[3];


    compSema.init_count = 1;
	compSema.max_count = 1;
	compSema.option = 0;
	_sjpcm_sema = CreateSema(&compSema);
	if (_sjpcm_sema < 0)
		return -1;

	sjpcm_inited = 1;

    SjPCM_BufferedAsyncStart();
    SjPCM_BufferedAsyncGet();

	return 0;
}

#include "types.h"
#include "prof.h"

// size should either be either 800 (NTSC) or 960 (PAL)
void SjPCM_Enqueue(short *left, short *right, int size, int wait)
{
    int i;
    SifDmaTransfer_t sdt;

    if (!sjpcm_inited) return;

    sdt.src = (void *)left;
    sdt.dest = (void *)(pcmbufl + bufpos);
    sdt.size = size*2;
    sdt.attr = 0;

    PROF_ENTER("FlushCache0");
	FlushCache(0);
    PROF_LEAVE("FlushCache0");
    

    i = SifSetDma(&sdt, 1); // start dma transfer
    while ((wait != 0) && (SifDmaStat(i) >= 0)); // wait for completion of dma transfer

    sdt.src = (void *)right;
    sdt.dest = (void *)(pcmbufr + bufpos);
    sdt.size = size*2;
    sdt.attr = 0;

    PROF_ENTER("FlushCache0");
	FlushCache(0);
    PROF_LEAVE("FlushCache0");

    i = SifSetDma(&sdt, 1);
    while ((wait != 0) && (SifDmaStat(i) >= 0));

    PROF_ENTER("SifCallRpc");
	sbuff[0] = size;
	SifCallRpc(&cd0,SJPCM_ENQUEUE,0,(void*)(&sbuff[0]),64,(void*)(&sbuff[0]),64,0,0);
	bufpos = sbuff[3];
    PROF_LEAVE("SifCallRpc");
    
//    printf("done enqueue: %d\n", bufpos);
} 



//
//
//

void _SjPCM_EnqueueIntr(unsigned *arg)
{
    // get buffer position
	bufpos = arg[3];

	iSignalSema(_sjpcm_sema);
}

void SjPCM_Sync()
{   
	WaitSema(_sjpcm_sema);
	SignalSema(_sjpcm_sema);
}

// size should either be either 800 (NTSC) or 960 (PAL)
void SjPCM_EnqueueAsync(short *left, short *right, int size)
{
    int i;
    SifDmaTransfer_t sdt;
    int wait = 0;

    if (!sjpcm_inited) return;
    
    PROF_ENTER("SjPCM_EnqueueWait");
    WaitSema(_sjpcm_sema);
    PROF_LEAVE("SjPCM_EnqueueWait");

    sdt.src = (void *)left;
    sdt.dest = (void *)(pcmbufl + bufpos);
    sdt.size = size*2;
    sdt.attr = 0;

    PROF_ENTER("FlushCache0");
	FlushCache(0);
    PROF_LEAVE("FlushCache0");
    

    i = SifSetDma(&sdt, 1); // start dma transfer
    while ((wait != 0) && (SifDmaStat(i) >= 0)); // wait for completion of dma transfer

    sdt.src = (void *)right;
    sdt.dest = (void *)(pcmbufr + bufpos);
    sdt.size = size*2;
    sdt.attr = 0;

    PROF_ENTER("FlushCache0");
	FlushCache(0);
    PROF_LEAVE("FlushCache0");

    i = SifSetDma(&sdt, 1);
    while ((wait != 0) && (SifDmaStat(i) >= 0));

    PROF_ENTER("SifCallRpc");
	enqueue_sbuff[0] = size;
  
    // perform async rpc
    SifWriteBackDCache(enqueue_rbuff, 64);
    
	SifCallRpc(&cd0,SJPCM_ENQUEUE,1,(void*)(&enqueue_sbuff[0]),64,(void*)(&enqueue_rbuff[0]),64,(SifRpcEndFunc_t)_SjPCM_EnqueueIntr,enqueue_rbuff);
    PROF_LEAVE("SifCallRpc");
} 


void _SjPCM_BufferedIntr(unsigned *arg)
{
    // get buffer samples enqueued
	_Buffered = arg[3];

	iSignalSema(_sjpcm_sema);
}


void SjPCM_BufferedAsyncStart()
{
  if (!sjpcm_inited) return;

  PROF_ENTER("SjPCM_BufferedWait");
  WaitSema(_sjpcm_sema);
  PROF_LEAVE("SjPCM_BufferedWait");

  SifWriteBackDCache(buffered_rbuff, 64);

  // perform async rpc
  SifCallRpc(&cd0,SJPCM_GETBUFFD,0,(void*)(&buffered_sbuff[0]),64,(void*)(&buffered_rbuff[0]),64,(SifRpcEndFunc_t)_SjPCM_BufferedIntr,buffered_rbuff);
}


int SjPCM_IsInitialized()
{
    return sjpcm_inited;
}

int SjPCM_BufferedAsyncGet()
{
  if (!sjpcm_inited) return 0;

  PROF_ENTER("SjPCM_BufferedWait");
  SjPCM_Sync();
  PROF_LEAVE("SjPCM_BufferedWait");
  
  return _Buffered;
}



int SjPCM_Available()
{
  if (!sjpcm_inited) return 0;
  SifCallRpc(&cd0,SJPCM_GETAVAIL,0,(void*)(&sbuff[0]),64,(void*)(&sbuff[0]),64,0,0);
  return sbuff[3];
}

int SjPCM_Buffered()
{
  if (!sjpcm_inited) return 0;
  SifCallRpc(&cd0,SJPCM_GETBUFFD,0,(void*)(&sbuff[0]),64,(void*)(&sbuff[0]),64,0,0);
  return sbuff[3];
}

void SjPCM_Quit()
{
	if(!sjpcm_inited) return;

	SifCallRpc(&cd0,SJPCM_QUIT,0,(void*)(&sbuff[0]),0,(void*)(&sbuff[0]),0,0,0);
	sjpcm_inited = 0;
}
