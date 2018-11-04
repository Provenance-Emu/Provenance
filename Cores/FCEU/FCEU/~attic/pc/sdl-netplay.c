#include "sdl.h"
#include <SDL/SDL_net.h>
#include "sdl-netplay.h"

char *ServerHost;

static int LocalPortTCP=0xFCE;
static int LocalPortUDP=0xFCE;
static int RemotePortTCP=0xFCE;

static int RemotePortUDP;	/* Not configurable, figured out during handshake. */

static TCPsocket Socket;
static UDPsocket UDPSocket;
static SDLNet_SocketSet set;


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



int FCEUD_NetworkConnect(void)
{
 IPaddress rip;

 SDLNet_Init();

 if(netplay==1)	/* Be a server. */
 {
  TCPsocket tmp;
  Uint16 p=LocalPortUDP;

  SDLNet_ResolveHost(&rip,NULL,LocalPortTCP);

  UDPSocket=SDLNet_UDP_Open(&p);

  tmp=SDLNet_TCP_Open(&rip);
  Socket=SDLNet_TCP_Accept(&tmp);

  memcpy(&rip,SDLNet_TCP_GetPeerAddress(Socket),sizeof(IPaddress));

  {
   uint8 buf[12];
   uint32 player=1;

   magic=SDL_GetTicks();

   SDLNet_Write32(buf,uport);
   SDLNet_Write32(buf+4,1);
   SDLNet_Write32(buf+8,magic);

   SDLNet_TCP_Send(Socket, buf, 12);

   /* Get the UDP port the client is waiting for data on. */
   SDLNet_TCP_Recv(Socket, buf, 2);
   RemotePortUDP=de32(buf);
  }
 }
 else		/* Be a client	*/
 {
  SDLNet_ResolveHost(&rip,ServerHost,RemotePortTCP);
  Socket=SDLNet_TCP_Open(&rip);

  {
   Uint16 p=LocalPortUDP;
   uint8 buf[12];
  
   UDPSocket=SDLNet_UDP_Open(&p);

   /* Now, tell the server what local UDP port it should send to. */
   en32(buf,p);
   SDLNet_TCP_Send(Socket, buf, 4);
 
   /* Get the UDP port from the server we should send data to. */
   SDLNet_TCP_Recv(Socket, buf, 12);
   RemotePortUDP=de32(buf);
   magic=de32(buf+8);
  }
  set=SDLNet_AllocSocketSet(1);
  SDLNet_TCP_AddSocket(set,TCPSocket);
  SDLNet_UDP_AddSocket(set,UDPSocket);
 }	// End client connect code.

 rip.port=RemotePortUDP;
 SDLNet_UDP_Bind(UDPSocket, 0, &rip);
}




static int CheckUDP(uint8 *packet, int32 len, int32 alt)
{
 uint32 crc;
 uint32 repcrc;

 crc=FCEUI_CRC32(0,packet+4,len+8);
 repcrc=de32(packet);

 if(crc!=repcrc) return(0); /* CRC32 mismatch, bad packet. */
  packet+=4;

 if(de32(packet)!=magic) /* Magic number mismatch, bad or spoofed packet. */
  return(0);

 packet+=4;
 if(alt)
 {
  if(de32(packet)<incounter) /* Time warped packet. */
   return(0);
 }
 else
  if(de32(packet)!=incounter) /* Time warped packet. */
   return(0);
 return(1);
}
 
 
/* Be careful where these MakeXXX() functions are used. */
static uint8 *MakeUDP(uint8 *data, int32 len)
{
 /* UDP packet data header is 12 bytes in length. */
 static uint8 buf[12+32]; // arbitrary 32.
 
 en32(buf+4,magic);
 en32(buf+8,outcounter);
 memcpy(buf+12,data,len);
 en32(buf,FCEUI_CRC32(0,buf+4,8+len));
 return(buf);
}

static uint8 *MakeTCP(uint8 *data, int32 len)
{
 /* TCP packet data header is 4 bytes in length. */
 static uint8 buf[4+32]; // arbitrary 32.
 
 en32(buf,outcounter);
 memcpy(buf+4,data,len);
 return(buf);
}
 
#define UDPHEADSIZE 12
#define TCPHEADSIZE 4 

void FCEUD_NetworkClose(void)
{
 SDLNet_Quit();
}

/* 1 byte to server */
int FCEUD_SendDataToServer(uint8 v,uint8 cmd)
{
        UDPpacket upack;
 
        upack.channel=0;
        upack.data=MakeUDP(data,1);
        upack.len=upack.maxlen=UDPHEADSIZE+1;
        upack.status=0;
 
        SDLNet_UDP_Send(UDPSocket,0,&upack);

        outcounter++; 
        return(1);   
}

void FCEUD_SendDataToClients(uint8 *data)
{
	UDPpacket upack;

	SDLNet_TCP_Send(Socket,MakeTCP(data,5),TCPHEADSIZE+5);

	upack.channel=0;
	upack.data=MakeUDP(data,5);
	upack.len=upack.maxlen=UDPHEADSIZE+5;
	upack.status=0;

	SDLNet_UDP_Send(UDPSocket,0,&upack);

	outcounter++;
	return(1);
}

int FCEUD_GetDataFromServer(uint8 *data)
{
  uint8 buf[128];    
  NoWaiting&=~2;

  while(SDLNet_CheckSockets(set,1)==0)
  {
   // do something here.
  }
  if(SDLNet_SocketReady(Socket))
  {
   SDLNet_TCP_Recv
     if(de32(buf)==incounter) /* New packet, keep. */
     {
      unsigned long beefie; 
      memcpy(data,buf+TCPHEADSIZE,5);
      incounter++;
      
      if(!ioctl(Socket,FIONREAD,&beefie))
       if(beefie)
        NoWaiting|=2;
       
      return(1);
     }

  }
  if(SDLNet_SocketReady(UDPSocket)
  {


  }
}
