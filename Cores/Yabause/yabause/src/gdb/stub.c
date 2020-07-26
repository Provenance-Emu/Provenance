#include "stub.h"
#include "client.h"
#include "../sh2core.h"
#include "../threads.h"
#include "../sock.h"

#include <errno.h>
#include <string.h>
#include <stdio.h>

/*! \file stub.c
    \brief GDB stub interface.
*/

typedef struct
{
   SH2_struct * context;
   YabSock server;
} gdb_stub;

static void gdb_stub_client(void * data)
{
   gdb_client * client = data;
   char buffer[1024];
   size_t got;
   gdb_packet packet;

   packet.state = 0;
   packet.client = client;

   
   while(-1 != (got = YabSockReceive(client->sock, buffer, 1024, 0)))
   {
      gdb_packet_read(&packet, buffer, got);
   }
}

static void gdb_stub_listener(void * data)
{
   gdb_stub * stub = data;
   YabSock sock;

   while(1)
   {
      gdb_client * client;

      sock = YabSockAccept(stub->server);
      if (sock == -1)
      {
         perror("accept");
         return;
      }

      client = malloc(sizeof(gdb_client));
      client->context = stub->context;
      client->sock = sock;

      SH2SetBreakpointCallBack(stub->context, gdb_client_lock, client);

      YabThreadStart(YAB_THREAD_GDBSTUBCLIENT, gdb_stub_client, client);
   }
}

int GdbStubInit(SH2_struct * context, int port)
{
   int opt = 1;
   YabSock server;
   gdb_stub * stub;
   int ret;

   YabSockInit();

   if ((ret = YabSockListenSocket(port, &server)) != 0)
      return ret;

   stub = malloc(sizeof(gdb_stub));
   stub->context = context;
   stub->server = server;

   YabThreadStart(YAB_THREAD_GDBSTUBLISTENER, gdb_stub_listener, stub);

   return 0;
}

int GdbStubDeInit()
{
   YabSockDeInit();
   return 0;
}
