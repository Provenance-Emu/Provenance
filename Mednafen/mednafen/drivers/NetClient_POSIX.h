#ifndef __MDFN_DRIVERS_NETCLIENT_POSIX_H
#define __MDFN_DRIVERS_NETCLIENT_POSIX_H

#include "NetClient.h"

class NetClient_POSIX : public NetClient
{
 public:

 NetClient_POSIX();   //const char *host);
 virtual ~NetClient_POSIX();

 virtual void Connect(const char *host, unsigned int port);

 virtual void Disconnect(void);

 virtual bool IsConnected(void);

 virtual bool CanSend(int32 timeout = 0);
 virtual bool CanReceive(int32 timeout = 0);

 virtual uint32 Send(const void *data, uint32 len);

 virtual uint32 Receive(void *data, uint32 len);

 private:

 int fd;
};

#endif
