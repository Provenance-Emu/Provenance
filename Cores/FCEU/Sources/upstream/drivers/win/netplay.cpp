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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

#include "common.h"
#include "../../fceu.h"
#include "../../utils/md5.h"

static int recv_tcpwrap(uint8 *buf, int len);
static void NetStatAdd(char *text);

static HWND netwin=0;

static char *netstatt[64];
static int netstattcount=0;
static int netlocalplayers = 1;

static char *netplayhost = 0;
static char *netplaynick = 0;
static char *netgamekey = 0;
static char *netpassword = 0;
static int remotetport=0xFCE;

static SOCKET Socket=INVALID_SOCKET;

static int wsainit=0;

int FCEUDnetplay = 0;
static void WSE(char *ahh)
{
 char tmp[256];
 sprintf(tmp,"*** Winsock: %s",ahh);
 NetStatAdd(tmp);
}

static void en32(uint8 *buf, uint32 morp)
{
 buf[0]=morp;
 buf[1]=morp>>8;
 buf[2]=morp>>16;
 buf[3]=morp>>24;
}

static uint32 de32(uint8 *morp)
{
 return(morp[0]|(morp[1]<<8)|(morp[2]<<16)|(morp[3]<<24));
}
static void FixCDis(HWND hParent, int how);
void FCEUD_NetworkClose(void)
{
 NetStatAdd("*** Connection lost.");
 if(netwin)
 {
  SetDlgItemText(netwin,BTN_NETMOO_CONNECT,"Connect");
  FixCDis(netwin,1);
 }
 if(Socket!=INVALID_SOCKET)
 {
  closesocket(Socket);
  Socket=INVALID_SOCKET;
 }

 if(wsainit)
 {
  WSACleanup();
  wsainit=0;
 }
 /* Make sure blocking is returned to normal once network play is stopped. */
 NoWaiting&=~2;
 FCEUDnetplay = 0;
 FCEUI_NetplayStop();
}
static void FixCDis(HWND hParent, int how)
{
 int x;

 for(x=IDC_NETMOO_HOST;x<=IDC_NETMOO_PASS;x++) // XXX iterate over all netplay settings elements
  EnableWindow( GetDlgItem(hParent,x),how);
}
static void GetSettings(HWND hwndDlg)
{
                         char buf[256];
                         char **strs[4]={&netplayhost,&netplaynick,&netgamekey,&netpassword};
                         int ids[4]={IDC_NETMOO_HOST,IDC_NETMOO_NICK,IDC_NETMOO_KEY,IDC_NETMOO_PASS};
                         int x;

                         for(x=0;x<4;x++)
                         {
                          GetDlgItemText(hwndDlg,ids[x],buf,256);
                          if(*strs[x])
                          {
                           free(*strs[x]);
                           *strs[x] = 0;
                          }
                          if(buf[0])
                          {
                           *strs[x] = (char*)malloc(strlen(buf) + 1); //mbg merge 7/17/06 added cast
                           strcpy(*strs[x], buf);
                          }
                         }
                         remotetport = GetDlgItemInt(hwndDlg,IDC_NETMOO_PORT,0,0);                         
                         netlocalplayers=1 + SendDlgItemMessage(hwndDlg,COMBO_NETMOO_LOCAL_PLAYERS,CB_GETCURSEL,0,(LPARAM)(LPSTR)0);
}

static void NetStatAdd(char *text)
{
 int x;
 uint32 totallen = 0;
 char *textbuf;

 if(!netwin) return;
 if(netstattcount>=64) free(netstatt[netstattcount&63]);

 if(!(netstatt[netstattcount&63]=(char*)malloc(strlen(text)+1))) //mbg merge 7/17/06 added cast
  return;
 strcpy(netstatt[netstattcount&63],text);
 netstattcount++;

 if(netstattcount>=64)
 {  
  for(x=netstattcount&63;;)
  {
   totallen += strlen(netstatt[x]);
   x=(x+1)&63;
   if(x==(netstattcount&63)) break;
   totallen += 2;
  }

  totallen++;   // NULL
  textbuf = (char *)malloc(totallen); //mbg merge 7/17/06 added cast
  textbuf[0] = 0;

  for(x=netstattcount&63;;)
  {
   strcat(textbuf,netstatt[x]);
   x=(x+1)&63;
   if(x==(netstattcount&63)) break;
   strcat(textbuf,"\r\n");
  }
 }
 else
 {
  for(x=0;x<netstattcount;x++)
  {
   totallen += strlen(netstatt[x]);
   if(x<(netstattcount-1))
    totallen += 2;
  }
  totallen++;
  textbuf = (char*)malloc(totallen); //mbg merge 7/17/06 added cast
  textbuf[0] = 0;
  for(x=0;x<netstattcount;x++)
  {
   strcat(textbuf,netstatt[x]);
   if(x<(netstattcount-1))
    strcat(textbuf,"\r\n");
  }
 }
 SetDlgItemText(netwin,IDC_NETMOO_STATUS,textbuf);
 free(textbuf);
 SendDlgItemMessage(netwin,IDC_NETMOO_STATUS,EM_LINESCROLL,0,32767);
}

void FCEUD_NetplayText(uint8 *text)
{
 NetStatAdd((char*)text); //mbg merge 7/17/06 added cast
}

int FCEUD_NetworkConnect(void)
{
 WSADATA WSAData;
 SOCKADDR_IN sockin;    /* I want to play with fighting robots. */  /* clack clack clack razzzzzzzzzz */
 SOCKET TSocket;
 int netdivisor;

 if(WSAStartup(MAKEWORD(1,1),&WSAData))
 {
  NetStatAdd("*** Error initializing WIndows Sockets.");
  return(0);
 }
 wsainit=1;

 if( (TSocket=socket(AF_INET,SOCK_STREAM,0))==INVALID_SOCKET)
 {
  WSE("Error creating stream socket.");
  FCEUD_NetworkClose();
  return(0);
 }

 memset(&sockin,0,sizeof(sockin));
 sockin.sin_family=AF_INET;

 {
  struct hostent *phostentb;
  unsigned long hadr;
  int sockin_len;
  
  sockin.sin_port=0;
  sockin.sin_addr.s_addr=INADDR_ANY;
  sockin_len=sizeof(sockin);

  hadr=inet_addr(netplayhost);

  if(hadr!=INADDR_NONE)
   sockin.sin_addr.s_addr=hadr;
  else
  {
   NetStatAdd("*** Looking up host name...");
   if(!(phostentb=gethostbyname((const char *)netplayhost)))
   {
    WSE("Error getting host network information.");
    closesocket(TSocket);
    FCEUD_NetworkClose();
    return(0);
   }
   memcpy((char *)&sockin.sin_addr,((PHOSTENT)phostentb)->h_addr,((PHOSTENT)phostentb)->h_length);
  }

  sockin.sin_port=htons(remotetport);
  NetStatAdd("*** Connecting to remote host...");
  if(connect(TSocket,(PSOCKADDR)&sockin,sizeof(sockin))==SOCKET_ERROR)
  {
    WSE("Error connecting to remote host.");
    closesocket(TSocket);
    FCEUD_NetworkClose();
    return(0);
  }
  Socket=TSocket;
  NetStatAdd("*** Sending initialization data to server...");

  {
   uint8 *sendbuf;
   uint8 buf[1];
   uint32 sblen;

   sblen = 4 + 16 + 16 + 64 + 1 + (netplaynick?strlen(netplaynick):0);
   sendbuf = (uint8*)malloc(sblen); //mbg merge 7/17/06 added cast
   memset(sendbuf, 0, sblen);
                           
   en32(sendbuf, sblen - 4);
                           
   if(netgamekey)
   {
    struct md5_context md5;
    uint8 md5out[16];

    md5_starts(&md5);
    md5_update(&md5, (uint8*)&GameInfo->MD5.data, 16);
    md5_update(&md5, (uint8*)netgamekey, strlen(netgamekey)); //mbg merge 7/17/06 added cast
    md5_finish(&md5, md5out);
    memcpy(sendbuf + 4, md5out, 16);
   }
   else
    memcpy(sendbuf + 4, &GameInfo->MD5, 16);

   if(netpassword)
   {
    struct md5_context md5;
    uint8 md5out[16];
   
    md5_starts(&md5);
    md5_update(&md5, (uint8*)netpassword, strlen(netpassword));  //mbg merge 7/17/06 added cast
    md5_finish(&md5, md5out);
    memcpy(sendbuf + 4 + 16, md5out, 16);
   }
                        
   memset(sendbuf + 4 + 16 + 16, 0, 64);
   sendbuf[4 + 16 + 16 + 64] = netlocalplayers;

   if(netplaynick)
    memcpy(sendbuf + 4 + 16 + 16 + 64 + 1,netplaynick,strlen(netplaynick));

   send(Socket, (char*)sendbuf, sblen, 0); //mbg merge 7/17/06 added cast
   free(sendbuf);

   recv_tcpwrap(buf, 1);
   netdivisor = buf[0];
  }
 }


 FCEUI_NetplayStart(netlocalplayers,netdivisor);
 NetStatAdd("*** Connection established.");

 FCEUDnetplay = 1;
 char tcpopt = 1; //mbg merge 7/17/06 changed to char
 if(setsockopt(TSocket, IPPROTO_TCP, TCP_NODELAY, &tcpopt, sizeof(int)))
  puts("Nodelay fail");

 return(1);
}


int FCEUD_SendData(void *data, uint32 len)
{
 send(Socket, (char*)data, len ,0); //mbg merge 7/17/06 added cast
 return(1);
} 

static int recv_tcpwrap(uint8 *buf, int len)
{
 fd_set fdoo;
 int t;
 struct timeval popeye;

 popeye.tv_sec=0;
 popeye.tv_usec=100000;

 while(len)
 {
  FD_ZERO(&fdoo);
  FD_SET(Socket,&fdoo);

  switch(select(0,&fdoo,0,0,&popeye))
  {
   case 0: //BlockingCheck();
           continue;
   case SOCKET_ERROR:return(0);
  }

  t=recv(Socket,(char*)buf,len,0); //mbg merge 7/17/06 added csat
  if(t<=0) return(0);
  len -= t;
  buf += t;
 }
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

   switch(select(0,&funfun,0,0,&popeye))
   {
    case 0:continue;
    case SOCKET_ERROR:return(0);
   }

  if(FD_ISSET(Socket,&funfun))
  {
   if(recv_tcpwrap((uint8*)data,len)>0) //mbg merge 7/17/06 added cast
   {    
    unsigned long beefie;
    if(!ioctlsocket(Socket,FIONREAD,&beefie))
     if(beefie)
      NoWaiting|=2;
    return(1);
   }
   else
    return(0);
  }
  else
   return(0);
  }
  return 0;
}

CFGSTRUCT NetplayConfig[]={
        AC(remotetport),
        AC(netlocalplayers),
        ACS(netgamekey),
        ACS(netplayhost),
        ACS(netplaynick),
        ACS(netpassword),
        ENDCFGSTRUCT
};


static BOOL CALLBACK NetCon(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
  switch(uMsg)
  {
   case WM_CLOSE:
                        GetSettings(hwndDlg);
                        DestroyWindow(hwndDlg);
                        netwin=0;
                        FCEUD_NetworkClose();
                        break;
   case WM_COMMAND:
                   if(HIWORD(wParam)==BN_CLICKED)
                   {
                    switch(LOWORD(wParam))
                    {
                     case BTN_NETMOO_CONNECT:
                        if(FCEUDnetplay)
                        {
                         FCEUD_NetworkClose();
                         SetDlgItemText(hwndDlg,BTN_NETMOO_CONNECT,"Connect");
                         FixCDis(hwndDlg,1);
                        }
                        else if(GameInfo)
                        {
                         GetSettings(hwndDlg);
                         if(FCEUD_NetworkConnect())
                         {
                          SetDlgItemText(hwndDlg,BTN_NETMOO_CONNECT,"Disconnect");
                          FixCDis(hwndDlg,0);
                         }
                        }
                        break;
                    }
                   }
                   else if(HIWORD(wParam)==EN_CHANGE && Socket!=INVALID_SOCKET)
                   {
                    char buf[1024];
                    int t;


                    t=GetDlgItemText(hwndDlg,IDC_NETMOO_CMD_INPUT,buf,1024);
                    buf[1023]=0;

                    if(strchr(buf,'\r'))
                    {
                     char *src,*dest;

                     src=dest=buf;
                    
                     while(*src)
                     {
                      if(*src != '\n' && *src != '\r')
                      {
                       *dest = *src;
                       dest++;
                      }
                      src++;
                     }
                     *dest = 0;
                     FCEUI_NetplayText((uint8*)buf); //mbg merge 7/17/06 added cast
                     SetDlgItemText(hwndDlg,IDC_NETMOO_CMD_INPUT,"");                    
                    }
                   }
                   break;
   case WM_INITDIALOG:
                   if(netplayhost)
                    SetDlgItemText(hwndDlg,IDC_NETMOO_HOST,netplayhost);
                   SetDlgItemInt(hwndDlg,IDC_NETMOO_PORT,remotetport,0);
                   if(netplaynick)
                    SetDlgItemText(hwndDlg,IDC_NETMOO_NICK,netplaynick);
                   if(netgamekey)
                    SetDlgItemText(hwndDlg,IDC_NETMOO_KEY,netgamekey);
                   if(netpassword)
                    SetDlgItemText(hwndDlg,IDC_NETMOO_PASS,netpassword);

                   {
                    int x;
                    char buf[8];
                    for(x=0;x<4;x++)
                    {
                     sprintf(buf,"%d",x+1);
                     SendDlgItemMessage(hwndDlg,COMBO_NETMOO_LOCAL_PLAYERS,CB_ADDSTRING,0,(LPARAM)(LPSTR)buf);
                    }
                    SendDlgItemMessage(hwndDlg,COMBO_NETMOO_LOCAL_PLAYERS,CB_SETCURSEL,netlocalplayers-1,(LPARAM)(LPSTR)0);
                   }


                   break;
  }

 return 0;
}

/**
* Shows Netplay dialog.
**/
void ShowNetplayConsole(void)
{
	if(!netwin)
	{
		netwin = CreateDialog(fceu_hInstance, "NETMOO", 0, NetCon);
	}
}
