/*! \file client.c
    \brief GDB stub client functions.
*/

#include "client.h"
#include "../sh2core.h"

#include <stdlib.h>

void gdb_client_unlock(gdb_client * client) {
   YabThreadWake(YAB_THREAD_GDBSTUBCLIENT);
}

void gdb_client_step(gdb_client * client) {
   SH2BreakNow(client->context);
   gdb_client_unlock(client);
}

void gdb_client_received(gdb_client * client, gdb_packet * packet)
{
   char ack = '+';
   printf("packet received: %s\n", packet->buffer);
   YabSockSend(client->sock, &ack, 1, 0);

   if (packet->buffer[0] == '?')
      gdb_client_break(client);
   else if (packet->buffer[0] == 'c')
      gdb_client_unlock(client);
   else if (packet->buffer[0] == 'g')
   {
      int i;
      char buffer[184+1];

      for(i = 0;i < 16;i++)
         sprintf(buffer + 8 * i, "%08x", client->context->regs.R[i]);

      sprintf(buffer + 8 * 16, "%08x", client->context->regs.PC);
      sprintf(buffer + 8 * 17, "%08x", client->context->regs.PR);
      sprintf(buffer + 8 * 18, "%08x", client->context->regs.GBR);
      sprintf(buffer + 8 * 19, "%08x", client->context->regs.VBR);
      sprintf(buffer + 8 * 20, "%08x", client->context->regs.MACH);
      sprintf(buffer + 8 * 21, "%08x", client->context->regs.MACL);
      sprintf(buffer + 8 * 22, "%08x", client->context->regs.SR);

      gdb_client_send(client, buffer, 184);
   }
   else if (packet->buffer[0] == 'H')
      gdb_client_send(client, "OK", 2);
   else if (packet->buffer[0] == 'q')
   {
      if (!strncmp(packet->buffer, "qSupported", 10))
         gdb_client_send(client, "PacketSize=1024", 15);
      else if (packet->buffer[1] == 'C')
         gdb_client_send(client, "", 0);
      else if (!strncmp(packet->buffer, "qAttached", 9))
         gdb_client_send(client, "0", 1);
      else if (!strncmp(packet->buffer, "qTStatus", 8))
         gdb_client_send(client, "T0", 2);
      else if (!strncmp(packet->buffer, "qTfP", 8))
         gdb_client_send(client, "", 0);
      else if (!strncmp(packet->buffer, "qTfV", 8))
         gdb_client_send(client, "", 0);
      else if (!strncmp(packet->buffer, "qTsP", 8))
         gdb_client_send(client, "", 0);
   }
   else if (packet->buffer[0] == 'm')
   {
      u32 addr;
      int len, i;
      char * buffer;
      char * pos;

      sscanf(packet->buffer, "m%x,%d", &addr, &len);

      buffer = malloc(2 * len);
      pos = buffer;

      i = 0;
      while(i < len / 4) {
         u32 val = MappedMemoryReadLong(addr + 4 * i);
         sprintf(pos, "%08x", val);
         i += 1;
         pos += 8;
      }

      switch(len % 4) {
         case 2: {
            u16 val = MappedMemoryReadWord(addr + 4 * i);
            sprintf(pos, "%04x", val);
            break;
         }
         case 1: {
            u8 val = MappedMemoryReadByte(addr + 4 * i);
            sprintf(pos, "%02x", val);
            break;
         }
      }

      gdb_client_send(client, buffer, 2 * len);

      free(buffer);
   }
   else if (packet->buffer[0] == 'v')
   {
      if (!strncmp(packet->buffer, "vCont?", 6))
         gdb_client_send(client, "", 0);
   }
   else if (packet->buffer[0] == 's')
      gdb_client_step(client);
   else if (packet->buffer[0] == 'Z') /* insert breakpoint */
   {
      if (packet->buffer[1] == '0') /* code breakpoint */
      {
         u32 addr;
         int dummy;
         sscanf(packet->buffer, "Z0,%x,%d", &addr, &dummy);
         SH2AddCodeBreakpoint(client->context, addr);
      }
      gdb_client_send(client, "OK", 2);
   }
   else if (packet->buffer[0] == 'z') /* remove breakpoint */
   {
      if (packet->buffer[1] == '0') /* code breakpoint */
      {
         u32 addr;
         int dummy;
         sscanf(packet->buffer, "Z0,%x,%d", &addr, &dummy);
         SH2DelCodeBreakpoint(client->context, addr);
      }
      gdb_client_send(client, "OK", 2);
   }
}

void gdb_client_send(gdb_client * client, const char * message, int msglen)
{
   char * buffer;
   u8 checksum = 0;
   int i;

   for(i = 0;i < msglen;i++)
      checksum += message[i];

   buffer = malloc(msglen + 5);
   buffer[0] = '$';
   memcpy(buffer + 1, message, msglen);
   buffer[msglen + 1] = '#';
   sprintf(buffer + msglen + 2, "%02x", checksum);
   buffer[msglen + 4] = '\0';
   YabSockSend(client->sock, buffer, msglen + 4, 0);
   printf("sent: %s\n", buffer);
   free(buffer);
}

void gdb_client_error(gdb_client * client)
{
}

void gdb_client_lock(void *context, u32 addr, void * userdata) {
   gdb_client * client = userdata;

   gdb_client_send(client, "S05", 3);

   YabThreadRemoteSleep(YAB_THREAD_GDBSTUBCLIENT);
}

void gdb_client_break(gdb_client * client)
{
   SH2BreakNow(client->context);
}
