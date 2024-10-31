
#include <tamtypes.h>
#include <stdlib.h>
#include <sifrpc.h>
#include <kernel.h>
#include <stdio.h>
#include <sifcmd.h>
#include <sifrpc.h>
#include <timer.h>
#include <sysmem.h>
#include "netsys.h"
#include "netprint.h"




NetSysSemaT NetSysSemaNew(int initcount)
{
    struct t_sema sem_info;
    int sem;

    sem_info.attr = 1;
    sem_info.option = 1;
    sem_info.init_count = initcount;
    sem_info.max_count = 1;

    sem = CreateSema(&sem_info);
    if (sem <= 0) 
    {
        printf( "CreateSema failed %i\n", sem);
        return 0;
    }
    return sem;
}

void NetSysSemaDelete(NetSysSemaT sema)
{
    if (sema == 0) 
    {
        printf("Trying to delete illegal sema (%d)\n", sema);
        return;
    }
    DeleteSema( sema );
}

int NetSysSemaWait(NetSysSemaT sema)
{
    return WaitSema(sema);
}

int NetSysSemaSignal(NetSysSemaT sema)
{
    return SignalSema(sema);
}


int NetSysThreadStart(void *pThreadFunc, int priority, void *arg)
{
    struct t_thread server_thread;
    int threadid;

	server_thread.type         = TH_C;
  	server_thread.function     = pThreadFunc;
  	server_thread.priority 	   = priority;
  	server_thread.stackSize    = 0x1000;
  	server_thread.unknown      = 0;
  	threadid = CreateThread(&server_thread);
	if (threadid <= 0)
    {
		NetPrintf("NetServer: Failed to create thread!\n");
	} else
    {
        // start server thread
        StartThread(threadid, (void *)arg);
    }
    return threadid;
}



int NetSysGetSystemTime(void)
{
    struct timestamp time;
    int sec, usec;
    GetSystemTime(&time);
    
    SysClock2USec(&time, &sec, &usec);
    
    return sec * 1000000 + usec;

}
