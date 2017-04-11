#ifndef GDB_CLIENT_H
#define GDB_CLIENT_H

#include "packet.h"
#include "../sh2core.h"
#include "../sock.h"
#include "../threads.h"

struct _gdb_client
{
   SH2_struct * context;
   YabSock sock;
};

void gdb_client_received(gdb_client * client, gdb_packet * packet);
void gdb_client_error(gdb_client * client);
void gdb_client_send(gdb_client * client, const char * message, int msglen);
void gdb_client_break(gdb_client * client);
void gdb_client_lock(void *context, u32 addr, void * userdata);

#endif
