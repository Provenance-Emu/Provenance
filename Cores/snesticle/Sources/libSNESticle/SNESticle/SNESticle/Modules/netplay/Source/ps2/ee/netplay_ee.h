
#ifndef _NETPLAY_RPCCLIENT_H
#define _NETPLAY_RPCCLIENT_H

#include "netplay.h"
#include "netplay_rpc.h"

int NetPlayInit(void *pCallback);
void NetPlayShutdown();
void NetPlayPuts(char *format, ...);

int NetPlayServerStart(int port, int latency);
void NetPlayServerStop();

int NetPlayClientConnect(unsigned ipaddr, int port);
int NetPlayClientDisconnect();
int NetPlayGetStatus(NetPlayRPCStatusT *pStatus);

void NetPlayClientSendLoadReq(char *pStr);
void NetPlayClientSendLoadAck(NetPlayLoadAckE eLoadAck);
void NetPlayClientInput(NetPlayRPCInputT *pInput);
int NetPlayServerPingAll();

void NetPlayRPCProcess();

#endif
