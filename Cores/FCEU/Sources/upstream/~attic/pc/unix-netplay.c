#ifdef NETWORK
/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2002 Xodnizel
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <stdlib.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <stdio.h>
#include <unistd.h>
#include <netdb.h>
#include <errno.h>
#include <fcntl.h>
#include "main.h"
#include "dface.h"
#include "unix-netplay.h"

#include "../../md5.h"

#ifndef socklen_t
#define socklen_t int
#endif

#ifndef SOL_TCP
#define SOL_TCP IPPROTO_TCP
#endif


char *netplayhost=0;
char *netplaynick=0;
char *netgamekey = 0;
char *netpassword = 0;
int netlocalplayers = 1;

int Port=0xFCE;
int FCEUDnetplay=0; 

int tport=0xFCE;
 
static int Socket=-1;

static void en32(uint8 *buf, uint32 morp)
{
 buf[0]=morp;
 buf[1]=morp>>8;
 buf[2]=morp>>16;
 buf[3]=morp>>24;
}
/*
static uint32 de32(uint8 *morp)
{ 
 return(morp[0]|(morp[1]<<8)|(morp[2]<<16)|(morp[3]<<24));
}
*/
int FCEUD_NetworkConnect(void)
{
 struct sockaddr_in sockin;    /* I want to play with fighting robots. */
 struct hostent *phostentb;
 unsigned long hadr;
 int TSocket;
 int netdivisor;
  
 if(!netplayhost) return(0);

 if( (TSocket=socket(AF_INET,SOCK_STREAM,0))==-1)
 {
  puts("Error creating stream socket.");
  FCEUD_NetworkClose();
  return(0);
 }

 {
 int tcpopt = 1;  
  #ifdef BEOS
  if(setsockopt(TSocket, SOL_SOCKET, TCP_NODELAY, &tcpopt, sizeof(int)))
  #else
 if(setsockopt(TSocket, SOL_TCP, TCP_NODELAY, &tcpopt, sizeof(int)))
  #endif
  puts("Nodelay fail");
 }

 memset(&sockin,0,sizeof(sockin));
 sockin.sin_family=AF_INET;
 
 hadr=inet_addr(netplayhost);
 
 if(hadr!=INADDR_NONE)
  sockin.sin_addr.s_addr=hadr;
 else
 {
  puts("*** Looking up host name...");
  if(!(phostentb=gethostbyname((const char *)netplayhost)))
  {
   puts("Error getting host network information.");
   close(TSocket);
   FCEUD_NetworkClose();
   return(0);
  }
  memcpy(&sockin.sin_addr,phostentb->h_addr,phostentb->h_length);
 }
 
 sockin.sin_port=htons(tport);
 puts("*** Connecting to remote host...");
 if(connect(TSocket,(struct sockaddr *)&sockin,sizeof(sockin))==-1)
 {
   puts("Error connecting to remote host.");
   close(TSocket);
   FCEUD_NetworkClose();
  return(0);
 }
 Socket=TSocket;
 puts("*** Sending initialization data to server...");
 {
  uint8 *sendbuf;
  uint8 buf[5];
  uint32 sblen;

   sblen = 4 + 16 + 16 + 64 + 1 + (netplaynick?strlen(netplaynick):0);
   sendbuf = malloc(sblen);
   memset(sendbuf, 0, sblen);
                           
   en32(sendbuf, sblen - 4);
                           
   if(netgamekey)
   {
    struct md5_context md5;
    uint8 md5out[16];

    md5_starts(&md5);
    md5_update(&md5, CurGame->MD5, 16);
    md5_update(&md5, netgamekey, strlen(netgamekey));
    md5_finish(&md5, md5out);
    memcpy(sendbuf + 4, md5out, 16);
   }
   else
    memcpy(sendbuf + 4, CurGame->MD5, 16);

   if(netpassword)
   {
    struct md5_context md5;
    uint8 md5out[16];
   
    md5_starts(&md5);
    md5_update(&md5, netpassword, strlen(netpassword));
    md5_finish(&md5, md5out);
    memcpy(sendbuf + 4 + 16, md5out, 16);
   }
                        
   memset(sendbuf + 4 + 16 + 16, 0, 64);

   sendbuf[4 + 16 + 16 + 64] = netlocalplayers;

   if(netplaynick)
    memcpy(sendbuf + 4 + 16 + 16 + 64 + 1,netplaynick,strlen(netplaynick));

  send(Socket, sendbuf, sblen, 0);
  free(sendbuf);

  recv(Socket, buf, 1, MSG_WAITALL);
  netdivisor = buf[0];
 }

 puts("*** Connection established.");

 FCEUDnetplay = 1;
 FCEUI_NetplayStart(netlocalplayers, netdivisor);
 return(1);
}


int FCEUD_SendData(void *data, uint32 len)
{
 int check;
 if(!ioctl(fileno(stdin),FIONREAD,&check))
 if(check)
 {
  char buf[1024];
  char *f;
  fgets(buf,1024,stdin);
  if((f=strrchr(buf,'\n')))
   *f=0;
  FCEUI_NetplayText(buf);
 }
 send(Socket, data, len ,0);
 return(1);
}

int FCEUD_RecvData(void *data, uint32 len)
{
  NoWaiting&=~2;
   
  for(;;)
  {
   fd_set funfun;
   struct timeval popeye;
    
   popeye.tv_sec=0;
   popeye.tv_usec=100000;
  
   FD_ZERO(&funfun);
   FD_SET(Socket,&funfun);

   switch(select(Socket + 1,&funfun,0,0,&popeye))
   {
    case 0: continue;
    case -1:return(0);
   }

  if(FD_ISSET(Socket,&funfun))
  {
   if(recv(Socket,data,len,MSG_WAITALL) == len)
   {
    //unsigned long beefie;

    FD_ZERO(&funfun);
    FD_SET(Socket, &funfun);

    popeye.tv_sec = popeye.tv_usec = 0;
    if(select(Socket + 1, &funfun, 0, 0, &popeye) == 1)
    //if(!ioctl(Socket,FIONREAD,&beefie))
    // if(beefie)
    {
      NoWaiting|=2;
      //puts("Yaya");
    }
    return(1);
   }
   else
    return(0);
  }

 }
  return 0;
}

void FCEUD_NetworkClose(void)
{
 if(Socket>0)
 {
  #ifdef BEOS
  closesocket(Socket);
  #else
  close(Socket);
  #endif
 }
 Socket=-1;

 if(FCEUDnetplay)
  FCEUI_NetplayStop();
 FCEUDnetplay = 0;
}


void FCEUD_NetplayText(uint8 *text)
{
 char *tot = malloc(strlen(text) + 1);
 char *tmp;
 strcpy(tot, text);
 tmp = tot;

 while(*tmp)
 {
  if(*tmp < 0x20) *tmp = ' ';
  tmp++;
 }
 puts(tot);
 free(tot);
}
#endif

