// netplay.cpp : Defines the entry point for the console application.
//

#include <stdio.h>
#include <stdlib.h>
#include <conio.h>

#include "types.h"
extern "C" {
#include "netserver.h"
#include "netclient.h"
#include "netsys.h"
};

NetServerT _server;
NetClientT _client;

int _GameLoop(NetClientT *pClient)
{
	HANDLE hEvent;
	MMRESULT hTimer;
	printf("Gameloop: Started\n");

	hEvent = CreateEvent(NULL, FALSE, FALSE, NULL);
	// set timer event
	hTimer = timeSetEvent(1000/60, 0, (LPTIMECALLBACK)hEvent, NULL, TIME_PERIODIC | TIME_CALLBACK_EVENT_SET);

	while (pClient->eStatus == NETPLAY_STATUS_CONNECTED)
	{
		Uint32 InputData = 0;
		Uint32 Output[4];

		WaitForSingleObject(hEvent, INFINITE);

		if (NetClientProcess(pClient, InputData ,4, Output))
		{
			// running
			/*
			printf("frame %04X %04X %04X %04X %3d i%2d o%2d i%2d o%2d\n", 
				Input[0],Input[1],Input[2],Input[3],
				_client.uFrame,
				NetQueueGetCount(&_client.Peers[0].InputQueue),
				NetQueueGetCount(&_client.Peers[0].OutputQueue),
				NetQueueGetCount(&_client.Peers[1].InputQueue),
				NetQueueGetCount(&_client.Peers[1].OutputQueue)
				);
				*/
			/*
			printf("frame %04X %04X %04X %04X %3d t%2d 0[i%2d o%2d t%2d] 1[i%2d o%2d t%2d]\n", 
				Input[0],Input[1],Input[2],Input[3],
				_client.uFrame,
				_client.iThrottle,
				_client.Peers[0].AveStats[NETPLAY_STAT_INPUTQUEUE] / 128,
				_client.Peers[0].AveStats[NETPLAY_STAT_OUTPUTQUEUE] / 128,
				_client.Peers[0].iThrottleReq,
				_client.Peers[1].AveStats[NETPLAY_STAT_INPUTQUEUE] / 128,
				_client.Peers[1].AveStats[NETPLAY_STAT_OUTPUTQUEUE] / 128,
				_client.Peers[1].iThrottleReq
				);
				*/
		}
		else
		{
			// stalled
		}


//		timeGetTime();

//		static int b = 0;
//		printf("hi %d\n", b++);

//		Sleep(1000/60);
		//Sleep(1000);
	}

	timeKillEvent(hTimer);
	CloseHandle(hEvent);
	printf("Gameloop: End\n");
	return 0;
}


static int _ClientCallback(NetClientT *pClient, NetPlayCallbackE eMsg, void *arg)
{
	switch (eMsg)
	{
	case NETPLAY_CALLBACK_LOADGAME:
		printf("callback: LoadGame %s\n", (char *)arg);
		break;

	case NETPLAY_CALLBACK_UNLOADGAME:
		printf("callback: UnloadGame\n");
		break;

	case NETPLAY_CALLBACK_CONNECTED:
		printf("callback: connected\n");
		break;

	case NETPLAY_CALLBACK_DISCONNECTED:
		printf("callback: disconnected\n");
		break;

	case NETPLAY_CALLBACK_STARTGAME:
		printf("callback: startgame\n");
		NetSysThreadStart(_GameLoop, 0, (void *)pClient);
		break;

	}
	return 0;
}


int main(int argc, char * argv[])
{
	WORD wVersionRequested;
	WSADATA wsaData;
	int err;
	bool bDone = FALSE;

	wVersionRequested = MAKEWORD( 1, 1 );

	err = WSAStartup( wVersionRequested, &wsaData );
	if ( err != 0 ) {
		/* Tell the user that we could not find a usable */
		/* WinSock DLL.                                  */
		return -1;
	}

	NetServerNew(&_server);
	NetClientNew(&_client);
	NetClientSetCallback(&_client, _ClientCallback);
	_server.bRelay = 0;

	while(!bDone)
	{
		char key;

		key = getch();

		switch (key)
		{
		case 's':
			NetServerStart(&_server, 1234);
			break;
/*
		case 'i':
			NetServerDumpStatus(&_server);
			break;*/

		case 'c':
//			NetClientConnect(&_client, NetSocketIpAddr(192,168,1,100), 1234);
			NetClientConnect(&_client, NetSocketIpAddr(127,0,0,1), 1234);
			break;

		case 'C':
				NetClientConnect(&_client, NetSocketIpAddr(192,168,1,202), 1234);
			//NetClientConnect(&_client, NetSocketIpAddr(192,168,1,112), 1234);
			//			NetClientConnect(&_client, NetSocketIpAddr(127,0,0,1), 1234);
			break;

		case 'p':
			NetClientPingServer(&_client);
			break;
		case 't':
//			NetClientSendText(&_client, "Test message.");
			NetServerSendText(&_server, "Server message.");
			break;
		case 'T':
			NetClientSendText(&_client, "Test message.");
			break;
		case '1':
//			NetClientTest(&_client);
			NetClientEnqueueInput(&_client,rand());
			NetClientTransmit(&_client);
			break;

		case 'g':
			// start game thread
			NetSysThreadStart(_GameLoop, 0, (void *)&_client);
			break;

		case '2':
			{
				Bool result;
				Uint32 Input[4];
				result = NetClientRecvInput(&_client, 4, Input);
				if (result)
				{
					printf("frame %04X %04X %04X %04X %d\n", 
						Input[0],Input[1],Input[2],Input[3],
						_client.uFrame
						);
			//		NetClientEnqueueInput(&_client,rand());
				} else
				{
					printf("input stalled\n");
				}
			}

			break;
		case 'l':
			NetClientSendLoadReq(&_client, "mario.smc");
			break;
		case 'u':
			NetClientSendLoadReq(&_client, NULL);
			break;
		case 'e':
			NetClientSendLoadAck(&_client, NETPLAY_LOADACK_ERROR);
			break;
		case 'L':
			NetClientSendLoadAck(&_client, NETPLAY_LOADACK_OK);
			break;

		case 'q':
			bDone = TRUE;
			break;

		}
	}

	NetServerStop(&_server);
	NetClientDisconnect(&_client);
	NetClientDelete(&_client);
	NetServerDelete(&_server);

	WSACleanup();
	return 0;
}

