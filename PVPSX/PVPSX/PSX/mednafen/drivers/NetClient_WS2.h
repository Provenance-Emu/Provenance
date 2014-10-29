#ifndef __MDFN_DRIVERS_NETCLIENT_WS2_H
#define __MDFN_DRIVERS_NETCLIENT_WS2_H

#include "NetClient.h"

class NetClient_WS2 : public NetClient
{
 public:

 NetClient_WS2();
 virtual ~NetClient_WS2();

 virtual void Connect(const char *host, unsigned int port);

 virtual void Disconnect(void);

 virtual bool IsConnected(void);

 virtual bool CanSend(int32 timeout = 0);
 virtual bool CanReceive(int32 timeout = 0);

 virtual uint32 Send(const void *data, uint32 len);

 virtual uint32 Receive(void *data, uint32 len);

 private:

 void *sd;
};

#endif
