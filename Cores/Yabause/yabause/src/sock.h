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

#ifndef SOCK_H
#define SOCK_H

typedef int YabSock;

// YabSockInit: Initializes socket code.
// Returns 0 on success. -1 on error.
int YabSockInit();

// YabSockDeInit: DeInitialize/frees socket code. 
// Returns 0 on success. -1 on error.
int YabSockDeInit();

// YabSockConnectSocket: Attempts to connect to specified ip and port.
// Returns 0 on success. -1 on error.
int YabSockConnectSocket(const char *ip, int port, YabSock *sock);

// YabSockListenSocket: Listen for connection attempts on specified port.
// Returns 0 on success. -1 on error.
int YabSockListenSocket(int port, YabSock *sock);

// YabSockCloseSocket: Closes previously opened socket.
// Returns 0 on success. -1 on error.
int YabSockCloseSocket(YabSock sock);

// YabSockSelect: Determines the status of one or more sockets.
// Returns 0 on success. -1 on error.
int YabSockSelect(YabSock sock, int check_read, int check_write);

// YabSockIsReadSet: Is socket's read flag set
// Returns 1 on true. 0 on false.
int YabSockIsReadSet(YabSock sock);

// YabSockIsWriteSet: Is socket's write flag set
// Returns 1 on true. 0 on false.
int YabSockIsWriteSet(YabSock sock);

// YabSockAccept: Accept connection from socket.
// Returns opened connected socket.
YabSock YabSockAccept(YabSock sock);

// YabSockSend: Sends data via specified socket
// Returns 0 on success. -1 on error.
int YabSockSend(YabSock sock, const void *buf, int len, int flags);

// YabSockSend: Receive data via specified socket
// Returns 0 on success. -1 on error.
int YabSockReceive(YabSock sock, void *buf, int len, int flags);

#endif  // SOCK_H
