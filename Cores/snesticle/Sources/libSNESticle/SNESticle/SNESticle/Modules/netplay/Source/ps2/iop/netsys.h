
#ifndef _NETSYS_H
#define _NETSYS_H


typedef int NetSysSemaT;
typedef int NetSysThreadT;

#define NETSYS_THREAD_INVALID (-1)

NetSysSemaT NetSysSemaNew(int initcount);
void NetSysSemaDelete(NetSysSemaT sema);
int NetSysSemaWait(NetSysSemaT sema);
int NetSysSemaSignal(NetSysSemaT sema);

int NetSysThreadStart(void *pThreadFunc, int priority, void *arg);
int NetSysGetSystemTime(void);


#endif
