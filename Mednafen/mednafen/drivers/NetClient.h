#ifndef __MDFN_DRIVERS_NETCLIENT_H
#define __MDFN_DRIVERS_NETCLIENT_H

#include <mednafen/mednafen.h>

class NetClient
{
 public:

 //NetClient();	//const char *host);
 virtual ~NetClient() { };

 virtual void Connect(const char *host, unsigned int port) = 0;

 virtual void Disconnect(void) = 0;

 virtual bool IsConnected(void) = 0;

 //
 // Returns 'true' if Send()/Receive() with len=1 would be non-blocking if Send()/Receive() actually were blocking; i.e. Can*() have select() style semantics.
 //
 // May timeout before timeout specified(if a signal interrupts an underlying system call).
 //
 virtual bool CanSend(int32 timeout = 0) = 0;
 virtual bool CanReceive(int32 timeout = 0) = 0;

 virtual uint32 Send(const void *data, uint32 len) = 0;		// Non-blocking
 virtual uint32 Receive(void *data, uint32 len) = 0;		// Non-blocking
};

#endif
