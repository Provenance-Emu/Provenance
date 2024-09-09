
#include <windows.h>
#include "netsys.h"
#include "netprint.h"


NetSysSemaT NetSysNewSema(int initcount)
{
	return CreateSemaphore(NULL, initcount, 1, NULL);
}
void NetSysDeleteSema(NetSysSemaT sema)
{
	CloseHandle(sema);
}
int NetSysWaitSema(NetSysSemaT sema)
{
	return WaitForSingleObject(sema, 0);
}

int NetSysSignalSema(NetSysSemaT sema)
{
	return ReleaseSemaphore(sema, 1, NULL);
}

NetSysThreadT NetSysThreadStart(void *pThreadFunc, int priority, void *arg)
{
	DWORD dwThreadId;
	HANDLE hThread;

	hThread = CreateThread(NULL, 0, pThreadFunc, arg, 0, &dwThreadId);
	return (NetSysThreadT)hThread;
}

int NetSysGetSystemTime(void)
{
	return timeGetTime() * 1000;
}

