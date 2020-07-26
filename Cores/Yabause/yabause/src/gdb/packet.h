#ifndef GDB_PACKET_H
#define GDB_PACKET_H

#include "../core.h"
#include <sys/types.h>

typedef struct _gdb_client gdb_client;

typedef struct
{
   char buffer[2048];
   size_t buflen;
   u8 bufsum;
   char checksum[2];
   size_t cslen;
   int state;
   gdb_client * client;
} gdb_packet;

void gdb_packet_read(gdb_packet * packet, char * buffer, size_t got);

#endif
