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

//////////////////////////////////////////////////////////////////////////////

int YabSockInit() { return -1; }

int YabSockDeInit() { return -1; }

int YabSockConnectSocket(const char *ip, int port, YabSock *sock) { return -1; }

int YabSockListenSocket(int port, YabSock *sock) { return -1; }

int YabSockCloseSocket(YabSock sock) { return -1; }

int YabSockSelect(YabSock sock, int check_read, int check_write ) { return -1; }

int YabSockIsReadSet(YabSock sock) { return -1; }

int YabSockIsWriteSet(YabSock sock) { return -1; }

YabSock YabSockAccept(YabSock sock) { return 0; }

int YabSockSend(YabSock sock, const void *buf, int len, int flags)  { return -1; }

int YabSockReceive(YabSock sock, void *buf, int len, int flags) { return -1; }


//////////////////////////////////////////////////////////////////////////////
