/*  Copyright 2006, 2013 Theo Berkau

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

#ifndef NETLINK_H
#define NETLINK_H

#include "sock.h"

#define NETLINK_BUFFER_SIZE     1024

enum NL_RESULTCODE
{
   NL_RESULTCODE_OK=0,
   NL_RESULTCODE_CONNECT,
   NL_RESULTCODE_RING,
   NL_RESULTCODE_NOCARRIER,
   NL_RESULTCODE_ERROR,
   NL_RESULTCODE_CONNECT1200,
   NL_RESULTCODE_NODIALTONE,
   NL_RESULTCODE_BUSY,
   NL_RESULTCODE_NOANSWER,
};

enum NL_CONNECTSTATUS
{
   NL_CONNECTSTATUS_IDLE,
   NL_CONNECTSTATUS_WAIT,
   NL_CONNECTSTATUS_CONNECT,
   NL_CONNECTSTATUS_LOGIN1,
   NL_CONNECTSTATUS_LOGIN2,
   NL_CONNECTSTATUS_LOGIN3,
   NL_CONNECTSTATUS_CONNECTED,
};

enum NL_MODEMSTATE
{
   NL_MODEMSTATE_COMMAND,
   NL_MODEMSTATE_DATA,
};

typedef struct
{
   u8 RBR;
   u8 THR;
   u8 IER;
   u8 DLL;
   u8 DLM;
   u8 IIR;
   u8 FCR;
   u8 LCR;
   u8 MCR;
   u8 LSR;
   u8 MSR;
   u8 SCR;
   u8 SREG[256];
} netlinkregs_struct;

typedef struct {
   volatile u8 inbuffer[NETLINK_BUFFER_SIZE];
   volatile u8 outbuffer[NETLINK_BUFFER_SIZE];
   volatile u32 inbufferstart, inbufferend, inbuffersize;
   volatile int inbufferupdate;
   volatile u32 outbufferstart, outbufferend, outbuffersize;
   volatile int outbufferupdate;
   netlinkregs_struct reg;
   int isechoenab;
   YabSock listensocket;
   YabSock connectsocket;
   YabSock clientsocket;
   enum NL_CONNECTSTATUS connectstatus;
   u32 cycles;
   enum NL_MODEMSTATE modemstate;
   char ipstring[16];
   char portstring[6];
   u32 connect_time, connect_timeout;
   int internet_enable;
   volatile u32 thb_write_time;
   int escape_count;
} Netlink;

typedef struct
{
   char ip[16];
   int port;
   YabSock sock;
} netlink_thread;

extern Netlink *NetlinkArea;

u8 FASTCALL NetlinkReadByte(u32 addr);
void FASTCALL NetlinkWriteByte(u32 addr, u8 val);
int NetlinkInit(const char *ip, const char *port);
void NetlinkDeInit(void);
void NetlinkExec(u32 timing);

#endif
