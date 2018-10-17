/*  Copyright 2013 Theo Berkau

    This file is part of Yabause.

    Yabause is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Yabause is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Yabause; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

#include "core.h"
#include "sock.h"
#include "debug.h"

#include <sys/socket.h>
#include <netdb.h>
#include <errno.h>
#include <sys/select.h>
#include <netinet/in.h>
#include <unistd.h>

static fd_set read_fds;
static fd_set write_fds;

//////////////////////////////////////////////////////////////////////////////

int YabSockInit()
{
   return 0;
}

int YabSockDeInit()
{
   return 0;
}

int YabSockConnectSocket(const char *ip, int port, YabSock *sock)
{
   struct addrinfo *result = NULL, hints;
   char port_str[256];

   memset(&hints, 0, sizeof(hints));

   hints.ai_family = AF_UNSPEC;
   hints.ai_socktype = SOCK_STREAM;
   hints.ai_protocol = IPPROTO_TCP;

   sprintf(port_str, "%d", port);
   if (getaddrinfo(ip, port_str, &hints, &result) != 0)
   {
      perror("getaddrinfo");
      return -1;
   }

   // Create a Socket
   if ((sock[0] = socket(result->ai_family, result->ai_socktype,
      result->ai_protocol)) == -1)
   {
      freeaddrinfo(result);
      perror("socket");
      return -1;
   }

   // Connect to the socket
   if (connect(sock[0], result->ai_addr, (int)result->ai_addrlen) == -1)
   {
      perror("connect");
      freeaddrinfo(result);
      close(sock[0]);
      return -1;
   }

   freeaddrinfo(result);
   return 0;
}

int YabSockListenSocket(int port, YabSock *sock)
{
   struct sockaddr_in addr;
   char opt = 1;

   sock[0] = socket(AF_INET, SOCK_STREAM, 0);

   if (setsockopt(sock[0], SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(int)) == -1)
   {
      perror("setsockopt");
      return -1;
   }

   memset(&addr, 0, sizeof(struct sockaddr_in));
   addr.sin_family = AF_INET;
   addr.sin_addr.s_addr = INADDR_ANY;
   addr.sin_port = htons(port);
   if (bind(sock[0], (struct sockaddr *) &addr, sizeof(addr)) == -1)
   {
      fprintf(stderr, "Can't bind to port %d: %s\n", port, strerror(errno));
      return -1;
   }

   if (listen(sock[0], 3) == -1)
   {
      perror("listen");
      return -1;
   }

   return 0;
}

int YabSockCloseSocket(YabSock sock)
{
   return close(sock);
}

int YabSockSelect(YabSock sock, int check_read, int check_write )
{
   fd_set *read_fds_ptr;
   fd_set *write_fds_ptr;
   struct timeval tv;
   int ret;

   FD_ZERO(&read_fds);
   FD_ZERO(&write_fds);

   // Let's see if we can even connect at this point
   if (check_read)
   {
      FD_SET(sock, &read_fds);
      read_fds_ptr = &read_fds;
   }
   else
      read_fds_ptr = NULL;

   if (check_write)
   {
      FD_SET(sock, &write_fds);
      write_fds_ptr = &write_fds;
   }
   else
      write_fds_ptr = NULL;

   tv.tv_sec = 0;
   tv.tv_usec = 0;

   if ((ret=select(sock+1, read_fds_ptr, write_fds_ptr, NULL, &tv)) < 1)
   {
      LOG("select: %d\n", ret);
      return -1;
   }

   return 0;
}

int YabSockIsReadSet(YabSock sock)
{
   return FD_ISSET(sock, &read_fds);
}

int YabSockIsWriteSet(YabSock sock)
{
   return FD_ISSET(sock, &write_fds);
}

YabSock YabSockAccept(YabSock sock)
{
   return accept(sock,NULL,NULL);
}

int YabSockSend(YabSock sock, const void *buf, int len, int flags)
{
   return send(sock, buf, len, flags);
}

int YabSockReceive(YabSock sock, void *buf, int len, int flags)
{
   return recv(sock, buf, len, flags);
}


//////////////////////////////////////////////////////////////////////////////
