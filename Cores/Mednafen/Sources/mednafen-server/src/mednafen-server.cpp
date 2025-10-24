/* FIXME IMPORTANT:
	Add setting to restrict /take and /dupe.

	Add setting to restrict arbitrary save state loading.

	Add setting to restrict command < 0x40(IE reset, power, disc change, etc.).

*/

/* Mednafen Network Play Server
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

/*
 TODO to protocol 4:
	Revamped login process:
		Give protocol-version-agnostic error message on unsupported protocol versions.

		<other stuff>

 Next version TODO:
	More verbose quit messages(sent to remaining players).

	Better exception handling - different exceptions for client-specific error and game-end "error".
*/

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <unistd.h>
#include <time.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <stdio.h>
#include <netdb.h>
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <signal.h>

#ifdef HAVE_MLOCKALL
#include <sys/mman.h>
#endif

#include <assert.h>

#include <exception>
#include <algorithm>
#include <vector>

#include "types.h"
#include "md5.h"
#include "time64.h"
#include "trim.inc"
#include "rand.inc"
#include "errno_holder.h"

#ifndef SOL_TCP
#define 	SOL_TCP   IPPROTO_TCP
#endif

static const int MaxNickLen = 150; 		// In bytes, not glyphs(worst-case max glyphs using UTF8 is probably around MaxNickLen / 5).
static const int MaxClientsPerGame = 32;	// Maximum number of clients per game.
static const int MaxControllersPerGame = 16;	// Maximum number of controllers per game.  Values higher than 16 are currently illegal.

static const int MaxTotalControllersDataSize = 	512; // Maximum data size for all the controller data per game.
						// Assume usable-worst-case 12 bytes per controller(in case of mouse, x delta, y delta, buttons), a maximum of 8
						// controllers, would give us 96 bytes.
						// We'll be extra-generous and set it to 512 bytes(in case anyone is goofy enough to try to use
						// the Family Keyboard over netplay or something).

// TODO: Ignoring incoming save state receives for a game if a previous save state transfer is in progress.  Or perhaps, if any sendq is >= MaxCommandPayload
// for the game, ignore all large incoming data transfers.

// TODO: Save state transfer throttling.

// TODO: Text throttling.

// TODO: Connection throttling.

// TODO: Nick change throttling.


// 0x40 ... 0x7F are used for payload-less netplay-specific commands(or when the payload can fit in the 4-byte length field).
#define MDFNNPCMD_SETFPS        0x40 /* Sent from client to server ONLY(it should be ignored server-side if it's not from the first
                                        active player for the game). */
#define MDFNNPCMD_NOP		0x41

//
#define MDFNNPCMD_CTRL_CHANGE     0x43  // Server->client, new local MPS mask as len.
#define MDFNNPCMD_CTRL_CHANGE_ACK 0x44  // Client->server.  Acknowledge controller change.  Sent using old local data length, everything after
                                        // this should be new data size.

//
#define MDFNNPCMD_CTRLR_SWAP_NOTIF	0x68	// Server->Client

//

#define MDFNNPCMD_CTRLR_TAKE		0x70	// Client->server.  Take the specified controllers(from other clients)
#define MDFNNPCMD_CTRLR_DROP		0x71	// Client->server.  Drop(relinquish) the specified controllers.
#define MDFNNPCMD_CTRLR_DUPE		0x72	// Client->server.  Take the specified controllers(but let other clients still keep their control).
#define MDFNNPCMD_CTRLR_SWAP		0x78	// Client->server.
//

#define MDFNNPCMD_REQUEST_LIST  0x7F    // client->server	(return list of players, and what controllers they control)

#define MDFNNPCMD_LOADSTATE     0x80    // Client->server, and server->client
#define	MDFNNPCMD_REQUEST_STATE 0x81	// Server->client
//
//
//


#define MDFNNPCMD_TEXT          0x90
#define MDFNNPCMD_SERVERTEXT    0x93 // Server text message(informational), server->client (TODO;;; Restrict to protocol 3 and higher).
#define MDFNNPCMD_ECHO          0x94 // Echos the string(no larger than 256 bytes) back to the client(used for pinging).
#define MDFNNPCMD_INTEGRITY     0x95 // Send from a client to a server, then from the server to all clients.
#define MDFNNPCMD_INTEGRITY_RES 0x96 // Integrity result, sent from the clients to the server.  The result should be no larger
                                     // than 256 bytes.
#define MDFNNPCMD_SETNICK       0x98 /* Sent from client to server only. */
#define MDFNNPCMD_PLAYERJOINED  0xA0    // Data:  <byte: bitmask, which inputs this player controls>
                                        //        <bytestream: nickname>
#define MDFNNPCMD_PLAYERLEFT    0xA1    // Data: (see above)
#define MDFNNPCMD_YOUJOINED     0xB0
#define MDFNNPCMD_YOULEFT       0xB1

#define MDFNNPCMD_NICKCHANGED   0xB8    // Sent from server to client

#define MDFNNPCMD_LIST          0xC0 // Server->client

#define MDFNNPCMD_SET_MEDIA             0xD0    // Client->server, and server->client

#define MDFNNPCMD_CTRLR_TAKE_NOTIF	0xF0	// Server->client
#define MDFNNPCMD_CTRLR_DROP_NOTIF	0xF1	// Server->client
#define MDFNNPCMD_CTRLR_DUPE_NOTIF	0xF2	// Server->client

#define MDFNNPCMD_QUIT          	0xFF // Client->server

struct GameEntry;

struct ClientEntry
{
	bool InUse;

	uint32 id;	/* mainly for faster referencing when pointed to from the Games
		           entries.
			 */
	char nickname[MaxNickLen + 1];

	int TCPSocket;
	GameEntry *game;	/* Pointer to the game this player is in. */
	unsigned int game_csid;	// index into game->Clients[]

	unsigned int local_players;	/* The number of local players the client requests.  Can be anywhere from 0 to UINT_MAX(granted we won't be able to GIVE a client anywhere near the number of controllers :b) */

	int64 timeconnect_us;	// Time the client made the connection(used in connection/login idle timeout calculation)


	uint8 pending_command;	/* Only for protocol >= 1 */
	int total_controllers;  /* Total controllers for the emulated system. */
	int controller_type[MaxControllersPerGame];	/* Controller type. */
	int controller_data_size[MaxControllersPerGame]; /* Controller data size. */
	int total_controllers_data_size; /* Data size of all controllers */
	int local_controllers_data_size; /* Data size of local controllers */
	int controller_data_offset[MaxControllersPerGame];

	int protocol_version;	/* 0 = FCE Ultra + Mednafen < 0.5.0 - NOT SUPPORTED*/
				/* 1 = Mednafen >= 0.5.0 
				    Changes:  
					1 extra byte in incoming data packet to denote command, instead
					of using 0xFF in the first joystick byte as an escape.
				   2 = Mednafen >= 0.7.0
				    Changes:
					Support for a wider variety of input devices.
				*/
	uint64 change_pending;

	/* Variables to handle non-blocking TCP reads. */
	uint8 *nbtcp;
	uint32 nbtcphas, nbtcplen;
	uint32 nbtcptype;
	int64 last_receive_time;	// In microseconds

	uint32 sendqcork;
	uint8 *sendq;
	uint32 sendqlen;
	uint32 sendqalloced;

	// Local controller buffer
	uint8 local_controller_buffer[MaxTotalControllersDataSize];
	char DisconnectReason[1024];
};

struct GameEntry
{
	/* No players, slated for deletion. */
	bool Zombie;

	/* Unique 128-bit identifier for this game session. */
        uint8 id[16];

	/* The version of the protocol the clients in this game are communicating with. */
	int ProtocolVersion;

	/* Text string(not necessarily null-terminated) representing the emulator being used, and the version. */
	uint8 EmulatorID[64];

	/* Total controllers for this game. */
	int TotalControllers;

	/* Controller type for each controller. */
	int ControllerType[MaxControllersPerGame];

	/* Data size for each controller. */
	int ControllerDataSize[MaxControllersPerGame];

	/* Total data size for all controllers. */
        int TotalControllersDataSize;

	/* Offset into joybuf for each controller. */
	int ControllerDataOffset[MaxControllersPerGame];

	/* Pointers to connected clients. */
        ClientEntry *Clients[MaxClientsPerGame];

	uint32 ClientToController[MaxClientsPerGame];	// array of bitfields
	uint32 ControllersInUse;			// bitfield.

	int64 last_time;
	uint32 fps;

        uint8 joybuf[MaxTotalControllersDataSize + 1]; /* X player data + 1 command byte8 */
};

struct CONFIG
{
	int MaxClients;		/* The maximum number of clients to allow. */
				/* You should expect each client to use
				   65-70Kbps(not including save state loads) while
				   connected(and logged in).
				*/

	int ConnectTimeout;	/* How long to wait(in seconds) for the client to provide
				   login data before disconnecting the client.
				*/

	int IdleTimeout;	/* If the data is not received from the client in this amount of time(in seconds), disconnect the client.
				*/

	int Port;		/* The port to listen on. */
	uint8 *Password;	/* The server password. */

	uint32 MinSendQSize;	//
	uint32 MaxSendQSize;	// Maximum size the internal soft send queue is allowed to grow to.  If it grows
                                // larger than this, the connection will be dropped.  Per client limit.
	uint32 MaxCommandPayload;
};

CONFIG ServerConfig;

int LoadConfig(char *fn)
{
 FILE *fp;

 ServerConfig.Port = -1;
 ServerConfig.MaxClients = -1;
 ServerConfig.ConnectTimeout = -1;

 // Settings with defaults(can be missing from config file):
 ServerConfig.IdleTimeout = 30;
 ServerConfig.MinSendQSize = 262144;
 ServerConfig.MaxSendQSize = 8388608;
 ServerConfig.MaxCommandPayload = 5 * 1024 * 1024;

 if((fp=fopen(fn,"rb")))
 {
  char buf[512];
  char sname[sizeof(buf)];
  char args[sizeof(buf)];

  while(fgets(buf, sizeof(buf), fp) != NULL)
  {
   char *sc_pos;

   // Handle comments
   if((sc_pos = strchr(buf, ';')))
    *sc_pos = 0;

   trim(buf);

   if(buf[0] == 0)
    continue;

   sscanf(buf, "%s %[^\n]", sname, args);
   trim(args);

   if(!strncasecmp(sname, "maxclients",strlen("maxclients")))
    sscanf(args, "%d",&ServerConfig.MaxClients);
   else if(!strncasecmp(sname, "connecttimeout ",strlen("connecttimeout")))
    sscanf(args, "%d",&ServerConfig.ConnectTimeout);
   else if(!strncasecmp(sname, "port",strlen("port")))
   {
    sscanf(args, "%d",&ServerConfig.Port);
   }
   else if(!strncasecmp(sname, "password",strlen("password")))
   {
    if(args[0] != 0)
    {
     struct md5_context md5;
     ServerConfig.Password = (uint8 *)malloc(16);
     md5_starts(&md5);
     md5_update(&md5,(uint8*)args,strlen(args));
     md5_finish(&md5,ServerConfig.Password);
     puts("Password required to log in.");
    }
   }
   else if(!strncasecmp(sname, "idletimeout", strlen("idletimeout")))
    sscanf(args, "%d", &ServerConfig.IdleTimeout);
   else if(!strncasecmp(sname, "minsendqsize", strlen("minsendqsize")))
    sscanf(args, "%u", &ServerConfig.MinSendQSize);
   else if(!strncasecmp(sname, "maxsendqsize", strlen("maxsendqsize")))
    sscanf(args, "%u", &ServerConfig.MaxSendQSize);
   else if(!strncasecmp(sname, "maxcmdpayload", strlen("maxcmdpayload")))
    sscanf(args, "%u", &ServerConfig.MaxCommandPayload);
   else
   {
    printf("Unknown directive in configuration file: %s\n", sname);
    return(0);
   }
  }
 }
 else return(0);

 if(ServerConfig.Port == -1 || ServerConfig.MaxClients == -1 || ServerConfig.ConnectTimeout == -1)
 {
  puts("Incomplete configuration file");
  return(0);
 }


 printf("Server configuration:\n");
 printf("\tMaximum clients: %u\n", ServerConfig.MaxClients);
 printf("\tConnect timeout: %u seconds\n", ServerConfig.ConnectTimeout);
 printf("\tListen port: %u\n", ServerConfig.Port);
 printf("\tPassword: %s\n", ServerConfig.Password ? "(used)" : "(unused)");
 printf("\tIdle timeout: %u seconds\n", ServerConfig.IdleTimeout);
 printf("\tMinimum internal send queue size: %u bytes\n", ServerConfig.MinSendQSize);
 printf("\tMaximum internal send queue size: %u bytes\n", ServerConfig.MaxSendQSize);
 printf("\tMaximum command payload size: %u bytes\n", ServerConfig.MaxCommandPayload);
 printf("\t---------------------------------------\n");
 printf("\tRough worst-case internal queue memory usage: %.2f MiB\n", ((double)ServerConfig.MaxSendQSize + ServerConfig.MaxCommandPayload) * ServerConfig.MaxClients / 1024 / 1024);
 printf("\n");

 return(1);
}

static ClientEntry *AllClients;
static GameEntry *Games;

static void en32(uint8 *buf, uint32 morp)
{
 buf[0]=morp;
 buf[1]=morp>>8;
 buf[2]=morp>>16;
 buf[3]=morp>>24;
}

static uint32 de32(const uint8 *morp)
{
 return(morp[0]|(morp[1]<<8)|(morp[2]<<16)|(morp[3]<<24));
}

static void MakeSendTCP(ClientEntry *client, const uint8 *data, uint32 len);
static void CleanText(char *text, unsigned len);
static void CleanNick(char *nick);
static bool NickUnique(ClientEntry *client, const char *);
static void ParseAndSetNickname(ClientEntry *client, const uint8 *data, uint32 data_len, bool is_change = false);

static bool AddClientToGame(ClientEntry *client, const uint8 id[16], const uint8 *emu_id);
static void SendCommand(ClientEntry *client, uint8 cmd, const uint8 *data, uint32 len);
static void SendDataToAllInGame(GameEntry *game, const uint8 *data, uint32 len);
static void SendCommandToAllInGame(GameEntry *game, int cmd, const uint8 *data, uint32 len);
static void TextToClient(ClientEntry *client, const char *fmt, ...) MDFN_FORMATSTR(printf, 2, 3);
static void AnnouncePlayer(ClientEntry *client, ClientEntry *newclient);
static void AnnouncePlayerLeft(ClientEntry *client, ClientEntry *newclient, uint32 mps);
static void SendPlayerList(ClientEntry *client);
static void DisconnectClient(ClientEntry *client, const char *format, ...) MDFN_FORMATSTR(printf, 2, 3);
static void KillClient(ClientEntry *client);


static uint32 EncodePlayerNumData(ClientEntry *client, uint8 *out_buffer, uint32 out_buffer_size, uint32 mps_override = 0, bool override_m = false);


#define NBTCP_LOGINLEN		0x100
#define NBTCP_LOGIN		0x200
#define NBTCP_COMMANDLEN	0x300
#define NBTCP_COMMAND		0x400

#define NBTCP_UPDATEDATA	0x800

static void StartNBTCPReceive(ClientEntry *client, uint32 type, uint32 len)
{
 if(client->TCPSocket == -1) // Client is disconnected?
  return;

 if(!(client->nbtcp = (uint8 *)malloc(len)))
 {
  DisconnectClient(client, "malloc() failed: %s", ErrnoHolder(errno).StrError());
  return;
 }

 client->nbtcplen = len;
 client->nbtcphas = 0;
 client->nbtcptype = type;
}

static void RedoNBTCPReceive(ClientEntry *client)
{
 if(client->TCPSocket == -1) // Client is disconnected?
  return;

 client->nbtcphas = 0;
}

static void EndNBTCPReceive(ClientEntry *client)
{
 if(client->TCPSocket == -1) // Client is disconnected?
  return;

 free(client->nbtcp);
 client->nbtcplen = 0;
 client->nbtcphas = 0;
 client->nbtcptype = 0;
 client->nbtcp = 0;
}

static uint32 MakeMPS(ClientEntry *client)
{
 return client->game->ClientToController[client->game_csid];
}

static void MakePRandNick(char *nick)
{
 int i;

 for(i = 0; i < 8 && i < MaxNickLen; i++)
 {
  int tmp = rand_range(0, 47);

  if(tmp >= 24)
   nick[i] = 'a' + tmp - 24;
  else
   nick[i] = 'A' + tmp;
 }

 nick[i] = 0;
}


struct login_data_t
{
 uint8 gameid[16];
 uint8 password[16];

 union
 {
  struct
  {
   uint8 protocol_version;
   uint8 total_controllers;
   uint8 padding0[2];

   uint8 pd_name_len[4];		// (protocol 2.  port device name len.  Deprecated, never implemented server-side) LSB first, 32-bit
					// Protocol 3, length of emulator name and version string(up to 64 bytes) - (note that any non-0
					// bytes < 0x20 in this string will be replaced by 0x20).

   uint8 padding1[8];

   uint8 controller_data_size[16];	// Only valid for protocol >= 2.

   uint8 padding3[16];

   uint8 controller_type[16];		// Protocol >= 3+
  };

  uint8 extra[64];
 };

 uint8 local_players;
 uint8 nickname[0];
};


#if 0
// Ideas:
//  use MSB of login len to denote Protocol 4 and higher
//
struct p4_login_data_t
{
 uint8 magic[16]; 		// string 	- "MEDNAFEN_NETPLAY"
 uint8 protocol_version[4];	// uint32 	- Protocol version
 uint8 password[16];		//
 uint8 nickname[256];

 // Game configuration data.
 uint8 game_id[32];		//
 uint8 emu_id[64];		//		- Unique emulator identifier incorporating name and version.
 uint8 emu_config[2048];	//		- Free-form, emulator-specific emulator configuration data.
 uint8 total_controllers;
 uint8 controller_data_size[32];

 // Player-specific game configuration data.
 uint8 local_players;
};
#endif

static inline void RecalcCInUse(GameEntry *game)
{
 uint32 cinuse_mask = 0;

 for(int x = 0; x < MaxClientsPerGame; x++)
 {
  cinuse_mask |= game->ClientToController[x];
 }

 game->ControllersInUse = cinuse_mask;
}


/* Returns 1 if we are back to normal game mode, 0 if more data is yet to arrive. */
static int CheckNBTCPReceive(ClientEntry *client)
{
 if(client->TCPSocket == -1)	// Client is disconnected?
  return(0);

 if(!client->nbtcplen)
  return(0);			/* Should not happen. */

 while(1)
 {
  if(client->TCPSocket == -1)
   return(0);

  int l = recv(client->TCPSocket, client->nbtcp + client->nbtcphas, client->nbtcplen  - client->nbtcphas, 0);

  if(l == -1)
  {
   if(errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR)
    break;
   
   DisconnectClient(client, "recv() failed: %s", ErrnoHolder(errno).StrError());
   return(0);
  }
  else if(l == 0)
  {
   DisconnectClient(client, "Client gracefully closed connection.");
   return(0);
  }

  client->last_receive_time = MBL_Time64();
  client->nbtcphas += l;

  //printf("Read: %d, %04x, %d, %d\n",l,client->nbtcptype,client->nbtcphas, client->nbtcplen);

  /* We're all full.  Yippie. */
  if(client->nbtcphas == client->nbtcplen)
  {
   switch(client->nbtcptype & 0xF00)
   {
    case NBTCP_UPDATEDATA:
			{
			 if(client->nbtcp[0])
			 {
			  client->pending_command = client->nbtcp[0];
			  EndNBTCPReceive(client);
			  StartNBTCPReceive(client, NBTCP_COMMANDLEN, 4);
			  return(1);
			 }

			 if(!client->change_pending)
			 {
			  memcpy(client->local_controller_buffer, &client->nbtcp[1], client->local_controllers_data_size);
			 }
			 RedoNBTCPReceive(client);
			}
			return(1);

    case NBTCP_COMMANDLEN:
			{
			 const uint8 cmd = client->pending_command;
			 uint32 len = de32(client->nbtcp);

			 if((cmd & 0x80) && len > ServerConfig.MaxCommandPayload)	/* Sanity check. */
			 {
			  DisconnectClient(client, "Tried to exceed maximum command payload by %u bytes!", len - ServerConfig.MaxCommandPayload);
			  return(0);
			 }

			 if(!(cmd & 0x80))	// No payload, or payload is length data.
		         {
			  if(cmd == MDFNNPCMD_SETFPS)
                          {
			   const uint32 fps = len;
			   GameEntry *game = client->game;

			   if(fps < (1U * 65536 * 256) || fps > (130U * 65536 * 256))
			   {
                            TextToClient(client, "FPS out of range(range is from 1 to 130).");
                            EndNBTCPReceive(client);
                            StartNBTCPReceive(client, NBTCP_UPDATEDATA, client->local_controllers_data_size + 1);
			    return(1);
			   }

                           game->fps = fps;

                           EndNBTCPReceive(client);
                           StartNBTCPReceive(client, NBTCP_UPDATEDATA, client->local_controllers_data_size + 1);
                          }
			  else if(cmd == MDFNNPCMD_NOP)
			  {
                           EndNBTCPReceive(client);
                           StartNBTCPReceive(client, NBTCP_UPDATEDATA, client->local_controllers_data_size + 1);
			  }
			  else if(cmd == MDFNNPCMD_CTRLR_SWAP)
			  {
			   GameEntry *game = client->game;
			   const uint8 sconts[2] = { (uint8)(len & 0xFF), (uint8)((len >> 8) & 0xFF) };
			   bool had_any = false;

			   for(int i = 0; i < 2; i++)
			   {
			    if(sconts[i] >= game->TotalControllers)
			    {
                             TextToClient(client, "Nonexistent controller(s) specified.");
                             EndNBTCPReceive(client);
                             StartNBTCPReceive(client, NBTCP_UPDATEDATA, client->local_controllers_data_size + 1);
			     return(1);
			    }
			   }

			   for(int n = 0; n < MaxClientsPerGame; n++)
			   {
			    if(!game->Clients[n])
			     continue;

			    if((bool)(game->ClientToController[n] & (1U << sconts[0])) ^ (bool)(game->ClientToController[n] & (1U << sconts[1])))
			    {
			     had_any = true;

			     if(game->ClientToController[n] & (1U << sconts[0]))
			     {
			      game->ClientToController[n] &= ~(1U << sconts[0]);
			      game->ClientToController[n] |= (1U << sconts[1]);
			     }
			     else
			     {
			      game->ClientToController[n] &= ~(1U << sconts[1]);
			      game->ClientToController[n] |= (1U << sconts[0]);
			     }
			     //printf("%d %08x\n", n, game->ClientToController[n]);
			     game->Clients[n]->change_pending++;
			     SendCommand(game->Clients[n], MDFNNPCMD_CTRL_CHANGE, NULL, game->ClientToController[n]);
			    }
			   }

			   if(!had_any)
			   {
                            TextToClient(client, "No client had any of the controller(s) you specified.");
                            EndNBTCPReceive(client);
                            StartNBTCPReceive(client, NBTCP_UPDATEDATA, client->local_controllers_data_size + 1);
			    return(1);
		           }

			   RecalcCInUse(game);

			   SendCommandToAllInGame(game, MDFNNPCMD_CTRLR_SWAP_NOTIF, NULL, len & 0xFFFF);
                           EndNBTCPReceive(client);
                           StartNBTCPReceive(client, NBTCP_UPDATEDATA, client->local_controllers_data_size + 1);
			  }
			  else if(cmd == MDFNNPCMD_CTRLR_TAKE || cmd == MDFNNPCMD_CTRLR_DROP || cmd == MDFNNPCMD_CTRLR_DUPE)
			  {
			   GameEntry *game = client->game;

			   //printf("%02x %08x\n", cmd, len);
			   if(len > ((1ULL << game->TotalControllers) - 1))
			   {
                            TextToClient(client, "Nonexistent controller(s) specified.");
                            EndNBTCPReceive(client);
                            StartNBTCPReceive(client, NBTCP_UPDATEDATA, client->local_controllers_data_size + 1);
			    return(1);
			   }

			   if(cmd == MDFNNPCMD_CTRLR_DROP && ((len & game->ClientToController[client->game_csid]) != len))
			   {
                            TextToClient(client, "Controller(s) you don't have control of specified.");
                            EndNBTCPReceive(client);
                            StartNBTCPReceive(client, NBTCP_UPDATEDATA, client->local_controllers_data_size + 1);
			    return(1);
			   }

			   client->change_pending++;

			   if(cmd == MDFNNPCMD_CTRLR_DROP)
			    game->ClientToController[client->game_csid] &= ~len;
			   else
			    game->ClientToController[client->game_csid] |= len;

                           SendCommand(client, MDFNNPCMD_CTRL_CHANGE, NULL, game->ClientToController[client->game_csid]);

			   if(cmd == MDFNNPCMD_CTRLR_TAKE)
			   {
			    for(int n = 0; n < MaxClientsPerGame; n++)
			    {
			     if(game->Clients[n] && game->Clients[n] != client && (game->ClientToController[n] & len))
			     {
			      game->Clients[n]->change_pending++;
			      game->ClientToController[n] &= ~len;
			      SendCommand(game->Clients[n], MDFNNPCMD_CTRL_CHANGE, NULL, game->ClientToController[n]);
			     }
			    }
			   }

			   RecalcCInUse(game);

			   {
			    uint8 ntf_buf[4 + 4 + 4 + MaxNickLen];
			    uint8 ntf_cmd;
			    uint32 ntf_len = 0;

			    if(cmd == MDFNNPCMD_CTRLR_TAKE)
			     ntf_cmd = MDFNNPCMD_CTRLR_TAKE_NOTIF;
			    else if(cmd == MDFNNPCMD_CTRLR_DROP)
			     ntf_cmd = MDFNNPCMD_CTRLR_DROP_NOTIF;
			    else
			     ntf_cmd = MDFNNPCMD_CTRLR_DUPE_NOTIF;

			    en32(&ntf_buf[ntf_len], len);
			    ntf_len += 4;

			    ntf_len += EncodePlayerNumData(client, ntf_buf + 4, sizeof(ntf_buf) - 4);
			    SendCommandToAllInGame(client->game, ntf_cmd, ntf_buf, ntf_len);
			   }

                           EndNBTCPReceive(client);
                           StartNBTCPReceive(client, NBTCP_UPDATEDATA, client->local_controllers_data_size + 1);
			  }
			  else if(cmd == MDFNNPCMD_CTRL_CHANGE_ACK)
			  {
                           // Calculate the size of this client's local controllers data size.
                           uint32 localmask = MakeMPS(client);
                           client->local_controllers_data_size = 0;

			   if(client->change_pending > 0)
			    client->change_pending--;
			   else
			    puts("BUG? :(");

			   if(client->change_pending)	// Icky way to handle change_pending > 1.  (Caution: might have security implications if we change too much stuff around)
			    localmask = len;

                           for(int x = 0; x < client->total_controllers; x++)
                            if(localmask & (1U << x))
                             client->local_controllers_data_size += client->controller_data_size[x];

			   if(!client->change_pending)	// Clear out any leftover (potential garbage) that would be used now that client->change_pending == 0
			    memset(client->local_controller_buffer, 0, client->local_controllers_data_size);

                           EndNBTCPReceive(client);
                           StartNBTCPReceive(client, NBTCP_UPDATEDATA, client->local_controllers_data_size + 1);
			  }
			  else if(cmd == MDFNNPCMD_REQUEST_LIST)
			  {
			   SendPlayerList(client);
                           EndNBTCPReceive(client);
                           StartNBTCPReceive(client, NBTCP_UPDATEDATA, client->local_controllers_data_size + 1);
			  }
		          else if(cmd < 0x40)	// Emulator commands, like power, reset, etc.
			  {
			   SendCommandToAllInGame(client->game, cmd, 0, 0);
			   EndNBTCPReceive(client);
			   StartNBTCPReceive(client, NBTCP_UPDATEDATA, client->local_controllers_data_size + 1);
			  }
			  else
			  {
                           TextToClient(client, "Unknown command: 0x%02x", cmd);
                           EndNBTCPReceive(client);
                           StartNBTCPReceive(client, NBTCP_UPDATEDATA, client->local_controllers_data_size + 1);
			  }
			 }
			 else // Everything else.
			 {
			  if(cmd == MDFNNPCMD_INTEGRITY)
                          {
                           SendCommandToAllInGame(client->game, MDFNNPCMD_INTEGRITY, NULL, 0);
                           EndNBTCPReceive(client);
                           StartNBTCPReceive(client, NBTCP_UPDATEDATA, client->local_controllers_data_size + 1);
                          }
			  else
			  {
                           EndNBTCPReceive(client);

			   if(len)
			    StartNBTCPReceive(client, NBTCP_COMMAND | cmd,len);
			   else	/* Woops.  Client probably tried to send a text message of 0 length. Or maybe a 0-length cheat file?  Better be safe! */
			    StartNBTCPReceive(client, NBTCP_UPDATEDATA, client->local_controllers_data_size + 1);
			  }
			 }
			}
			return(1);

    case NBTCP_COMMAND: 
			{
			 uint32 len = client->nbtcplen;
			 uint32 tocmd = client->nbtcptype & 0xFF;

                         if(tocmd == MDFNNPCMD_INTEGRITY_RES)
                         {
                          printf("%s\n", md5_asciistr(client->nbtcp));
                         }
                         else if(tocmd == MDFNNPCMD_ECHO)
                         {
                          uint32 newlen = len;

                          if(newlen > 256)
                           newlen = 256;

                          SendCommand(client, tocmd, client->nbtcp, newlen);
                         }
			 else if(tocmd == MDFNNPCMD_SETNICK)
			 {
			  ParseAndSetNickname(client, client->nbtcp, len, true);
			 }
			 else if(tocmd == MDFNNPCMD_TEXT)
			 {
                          const uint32 nicklen = strlen(client->nickname);
                          uint8 mewmewbuf[4 + MaxNickLen];

                          en32(mewmewbuf, nicklen);
                          memcpy(mewmewbuf + 4, client->nickname, nicklen);

                          SendCommandToAllInGame(client->game, tocmd, NULL, 4 + nicklen + len);
			  SendDataToAllInGame(client->game, mewmewbuf, 4 + nicklen);
			  SendDataToAllInGame(client->game, client->nbtcp, len);
			 }
			 else if(tocmd == MDFNNPCMD_SET_MEDIA)
			 {
			  if(len != 16)
			  {
			   DisconnectClient(client, "SET_MEDIA command length is wrong.");
			   return 0;
			  }

			  SendCommandToAllInGame(client->game, tocmd, client->nbtcp, len);
			 }
			 else if(tocmd == MDFNNPCMD_QUIT)
		         {
			  if(len)
			  {
			   char quit_message[1024 + 1];
			   uint32 quit_len = std::min<uint32>(1024, len);

			   memcpy(quit_message, client->nbtcp, quit_len);
			   quit_message[quit_len] = 0;

			   CleanText(quit_message, quit_len);
                           DisconnectClient(client, "Quit: %s", quit_message);
			  }
			  else
			   DisconnectClient(client, "Quit");

			  return(0);
			 }
			 else if(tocmd == MDFNNPCMD_LOADSTATE)
			  SendCommandToAllInGame(client->game, tocmd, client->nbtcp, len);

                         EndNBTCPReceive(client);
			 StartNBTCPReceive(client,NBTCP_UPDATEDATA, client->local_controllers_data_size + 1);
			}
			return(1);

    case NBTCP_LOGINLEN:
			{
			 uint32 len = de32(client->nbtcp);

			 // + 8192 because the client wouldn't know our maximum nickname length setting on the server beforehand, and to handle
			 // versions of Mednafen that send garbage(not technically garbage, but never really implemented on the server side, and a poor
			 // solution to the problem of input device selection anyway, so GARBAGE).
			 if(len > (sizeof(login_data_t) + MaxNickLen + 8192) || len < sizeof(login_data_t))
			 {
			  DisconnectClient(client, "Login len(%u) out of range.", len);
			  return(0);
			 }

			 EndNBTCPReceive(client);
			 StartNBTCPReceive(client, NBTCP_LOGIN, len);
			}
			return(1);

    case NBTCP_LOGIN:
			{
			 const login_data_t *ld = (const login_data_t *)client->nbtcp;
			 const uint32 len = client->nbtcplen;
			 const uint32 pd_name_len = de32(ld->pd_name_len);
			 uint32 nickname_len = 0;
			 uint8 emu_id[64];

			 if(pd_name_len < (len - sizeof(login_data_t)))
			  nickname_len = len - (sizeof(login_data_t) + pd_name_len);

			 client->local_players = ld->local_players;
			 client->protocol_version = ld->protocol_version;
			 client->total_controllers = ld->total_controllers;

			 // Don't even send error messages for these, because the
			 // message sending code relies on the parameters that are invalid x_x
                         if(client->protocol_version < 3 && client->total_controllers > 8)
                         {
			  DisconnectClient(client,"That number of controllers(%u) isn't supported with that protocol version.", client->total_controllers);
			  return(0);
                         }

                         if(client->total_controllers > MaxControllersPerGame)
                         {
			  DisconnectClient(client, "That number of controllers(%u) isn't supported.", client->total_controllers);
			  return(0);
                         }

			 if(!client->protocol_version)
			 {
			  DisconnectClient(client, "Protocol 0 not supported.");
			  return(0);
		         }

			 client->sendqcork = 0;
			 client->sendqalloced = ServerConfig.MinSendQSize;
			 client->sendqlen = 0;
			 client->sendq = (uint8 *)calloc(client->sendqalloced, 1);

			 if(!client->controller_data_size || !client->controller_data_offset || !client->sendq)
			 {
			  DisconnectClient(client, "Memory allocation failure!");
			  return(0);
			 }

			 if(client->protocol_version < 2)
			 {
			  for(int x = 0; x < client->total_controllers; x++)
			  {
			   client->controller_type[x] = 1;
			   client->controller_data_size[x] = 1;
			   client->controller_data_offset[x] = x;
			  }
			  client->total_controllers_data_size = client->total_controllers;
			 }
		 	 else
			 {
			  int zeindex = 0;

			  for(int x = 0; x < client->total_controllers; x++)
			  {
			   client->controller_type[x] = ld->controller_type[x];
			   client->controller_data_size[x] = ld->controller_data_size[x];
			   client->controller_data_offset[x] = zeindex;
			   zeindex += client->controller_data_size[x];
			  }
			  client->total_controllers_data_size = zeindex;
		 	 }

			 // Hack so we can always be able to encode our command length...
			 if(client->total_controllers_data_size < 4) 
			  client->total_controllers_data_size = 4;

			 if(client->total_controllers_data_size > MaxTotalControllersDataSize)
			 {
			  DisconnectClient(client, "Exceeded MaxTotalControllersDataSize");
			  return(0);
			 }

			 client->local_controllers_data_size = 0;

                         if(ServerConfig.Password)
			 {
                          if(memcmp(ServerConfig.Password, ld->password, 16))
                          {
                           TextToClient(client, "Invalid server password.");
			   DisconnectClient(client, "Invalid server password.");
			   return(0);
                          }
			 }

			 memset(emu_id, 0, 64);

			 if(client->protocol_version == 3 && pd_name_len && pd_name_len <= 64 && ((int64_t)sizeof(login_data_t) + nickname_len + pd_name_len) <= len)
			 {
			  strncpy((char *)emu_id, (const char *)ld->nickname + nickname_len, pd_name_len);

			  for(int i = 0; i < 64; i++)
			  {
			   if(emu_id[i] > 0 && emu_id[i] < 0x20)
			    emu_id[i] = 0x20;
			  }
			 }

			 // Needs to be before nickname set, but we'll fix this eventually.
                         if(!AddClientToGame(client, ld->gameid, emu_id))
			  return(0);

                         ParseAndSetNickname(client, ld->nickname, nickname_len);

			 printf("Client(protocol %u) %u assigned to game %u as player mask 0x%08x <%s> - EmuID=%.64s\n", client->protocol_version, client->id, (int)(client->game - Games), MakeMPS(client), client->nickname, emu_id);

			 // First, announce any existing clients to the new client.
			 SendPlayerList(client);

			 // Now, announce this new client to other players.
			 // (Do this in a separate loop so we need less convoluted error handling and to avoid out-of-order messages)
			 GameEntry *tg = client->game;
                         for(int x = 0; x < MaxClientsPerGame; x++)
                         {
                          if(tg->Clients[x])
                          {
                           if(tg->Clients[x] != client)
                           {
                            AnnouncePlayer(tg->Clients[x], client);
                           }
                          }
                         }

			 // Calculate the size of this client's local controllers data size.
			 {
			  uint32 localmask = MakeMPS(client);
			  client->local_controllers_data_size = 0;

			  for(int x = 0; x < client->total_controllers; x++)
			   if(localmask & (1U << x))
			    client->local_controllers_data_size += client->controller_data_size[x];
			 }
			} 
			EndNBTCPReceive(client);
			StartNBTCPReceive(client,NBTCP_UPDATEDATA,client->local_controllers_data_size + 1);
			return(1);
   }
  }
 }
 return(0);
}

struct ListenSocketDef
{
 int fd;
 int family;
};

static std::vector<ListenSocketDef> ListenSockets;

static void CleanText(char *text, unsigned len)
{
 for(unsigned i = 0; i < len; i++)
 {
  if((unsigned char)text[i] < 0x20)
   text[i] = 0x20;
 }
}

// Remove any control characters or reserved characters from the nickname.
static void CleanNick(char *nick)
{
 for(unsigned int x = 0; x < strlen(nick); x++)
  if(nick[x] == '<' || nick[x] == '>' || nick[x] == '*' || ((unsigned char)nick[x] < 0x20))
   nick[x] = 0;
}

static bool NickUnique(ClientEntry *client, const char *newnick)
{
 GameEntry *game = client->game;

 for(int x = 0; x < MaxClientsPerGame; x++)
  if(game->Clients[x] && client != game->Clients[x])
   if(!strcasecmp(newnick, game->Clients[x]->nickname))
    return(0);
 return(1);
}

static void ParseAndSetNickname(ClientEntry *client, const uint8 *data, uint32 data_len, bool is_change)        // is_change is false on initial login, true if trying to change nickname after login.
{
 char newnick[MaxNickLen + 1];

 if(data_len > (uint32)MaxNickLen)
  data_len = MaxNickLen;

 newnick[data_len] = 0;
 memcpy(newnick, data, data_len);

 CleanNick(newnick);

 if(!strlen(newnick) || !NickUnique(client, newnick))
 {
  do
  {
   MakePRandNick(newnick);
  } while(!NickUnique(client, newnick));
 }

 if(!is_change) // Login nickname set
 {
  strcpy(client->nickname, newnick);
 }
 else
 {
  uint8 ncdata[MaxNickLen + 1 + MaxNickLen + 1];
  uint32 ncdata_len;

  ncdata_len = strlen(client->nickname) + 1 + strlen(newnick) + 1;

  memcpy(ncdata, client->nickname, strlen(client->nickname));
  ncdata[strlen(client->nickname)] = '\n';
  strcpy((char*)ncdata + strlen(client->nickname) + 1, newnick);

  strcpy(client->nickname, newnick);

  SendCommandToAllInGame(client->game, MDFNNPCMD_NICKCHANGED, ncdata, ncdata_len);
 }
}

static void MakeSendTCP(ClientEntry *client, const uint8 *data, uint32 len)
{
 if(client->TCPSocket == -1) // Client is disconnected?
  return;

 //if(client->sendqcork > 0)
 // puts("CORKED");

 // If there's no data in our software sendq, try sending this data without using the soft sendq.
 if(!client->sendqlen)
 {
  int32 sent;

  if(client->sendqcork > 0)
   sent = 0;
  else 
   sent = send(client->TCPSocket, data, len, 0);

  if(sent < 0)
  {
   if(errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR)
    sent = 0;
   else
   {
    DisconnectClient(client, "send() failed: %s", ErrnoHolder(errno).StrError());
    return;
   }
  }

  assert((uint32)sent <= len);

  // ...and adjust the data pointer and length appropriately.
  data += sent;
  len -= sent;

  // If we sent all the data, no need to go through the software sendq code at all~
  if(!len)
   return;
 }

 assert(client->sendq);
 if((client->sendqlen + len) > client->sendqalloced)
 {
  uint32 new_alloc_size;

  new_alloc_size = client->sendqlen + len;

  if(new_alloc_size > ServerConfig.MaxSendQSize)
  {
   DisconnectClient(client, "Exceeded MaxSendQSize by %u bytes", ServerConfig.MaxSendQSize - new_alloc_size);
   return;
  }

  new_alloc_size += new_alloc_size >> 1;
  if(new_alloc_size > ServerConfig.MaxSendQSize)
   new_alloc_size = ServerConfig.MaxSendQSize;

  uint8 *new_sendq = (uint8 *)realloc(client->sendq, new_alloc_size);
  if(!new_sendq && new_alloc_size)
  {
   DisconnectClient(client, "realloc() failed: %s", ErrnoHolder(errno).StrError());
   return;
  }
  client->sendq = new_sendq;
  client->sendqalloced = new_alloc_size;
 }

 //puts("SendQ path");

 // Append new data to the end of the sendq
 memcpy(client->sendq + client->sendqlen, data, len);
 client->sendqlen += len;

 // Now try to send all the data in the sendq
 int32 sent;

 if(client->sendqcork > 0)
  sent = 0;
 else
  sent = send(client->TCPSocket, client->sendq, client->sendqlen, 0);

 if(sent < 0) 
 {
  if(errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR)
   sent = 0;
  else
  {
   DisconnectClient(client, "send() failed: %s", ErrnoHolder(errno).StrError());
   return;
  }
 }

 if(sent)
 {
  uint32 new_alloc_size;

  client->sendqlen -= sent;
  memmove(client->sendq, client->sendq + sent, client->sendqlen);

  new_alloc_size = client->sendqlen;
  if(new_alloc_size < ServerConfig.MinSendQSize)
   new_alloc_size = ServerConfig.MinSendQSize;

  uint8 *new_sendq = (uint8 *)realloc(client->sendq, new_alloc_size);
  if(!new_sendq && new_alloc_size)
  {
   DisconnectClient(client, "realloc() failed: %s", ErrnoHolder(errno).StrError());
   return;
  }
  client->sendq = new_sendq;
  client->sendqalloced = new_alloc_size;
 }
}

static void SendCommand(ClientEntry *client, uint8 cmd, const uint8 *data, uint32 len)
{
 uint8 poo[MaxTotalControllersDataSize + 1];

 memset(poo, 0, client->total_controllers_data_size);

 poo[client->total_controllers_data_size] = cmd;

 en32(poo, len);
 MakeSendTCP(client, poo, client->total_controllers_data_size + 1);

 if((cmd & 0x80) && data != NULL)
  MakeSendTCP(client, data, len);
}

static void SendDataToAllInGame(GameEntry *game, const uint8 *data, uint32 len)
{
 for(int x = 0; x < MaxClientsPerGame; x++)
 {
  if(!game->Clients[x])
   continue;

  MakeSendTCP(game->Clients[x], data, len);
 }
}


static void SendCommandToAllInGame(GameEntry *game, int cmd, const uint8 *data, uint32 len)
{
 for(int x = 0; x < MaxClientsPerGame; x++)
 {
  if(!game->Clients[x])
   continue;

  SendCommand(game->Clients[x], cmd, data, len);
 }
}

static void TextToClient(ClientEntry *client, const char *fmt, ...)
{
 uint8 moo[4 + 1024]; // nick len(=0) and message
 va_list ap;

 va_start(ap,fmt);
 vsnprintf((char*)moo + 4, 1024, fmt, ap);
 va_end(ap);
 
 en32(moo, 0); // nick len of 0 to signify this is a server message
 SendCommand(client, MDFNNPCMD_TEXT, moo, 4 + strlen((char*)moo + 4));
}

// out_buffer should have at least 4 + 4 + MaxNickLen bytes size
static uint32 EncodePlayerNumData(ClientEntry *client, uint8 *out_buffer, uint32 out_buffer_size, uint32 mps_override, bool override_m)
{
 uint32 mps;
 uint32 datalen;

 if(override_m)
 {
  mps = mps_override;
 }
 else
  mps = MakeMPS(client);

 if(client->game->ProtocolVersion >= 3)
 {
  datalen = 4 + 4 + strlen(client->nickname);

  assert(datalen <= out_buffer_size);

  en32(&out_buffer[0], mps);
  en32(&out_buffer[4], 0);

  memcpy(out_buffer + 8, client->nickname, strlen(client->nickname));
 }
 else
 {
  datalen = 1 + 1 + strlen(client->nickname);

  assert(datalen <= out_buffer_size);

  out_buffer[0] = mps;
  out_buffer[1] = 0;

  memcpy(out_buffer + 2, client->nickname, strlen(client->nickname));
 }

 return(datalen);
}

static void AnnouncePlayer(ClientEntry *client, ClientEntry *newclient)
{
 uint8 data[4 + 4 + MaxNickLen];
 uint32 datalen;

 datalen = EncodePlayerNumData(newclient, data, sizeof(data));

 if(client == newclient)
  SendCommand(client, MDFNNPCMD_YOUJOINED, data, datalen);
 else
  SendCommand(client, MDFNNPCMD_PLAYERJOINED, data, datalen);
}

static void AnnouncePlayerLeft(ClientEntry *client, ClientEntry *newclient, uint32 mps)
{
 uint8 data[4 + 4 + MaxNickLen];
 uint32 datalen;

 datalen = EncodePlayerNumData(newclient, data, sizeof(data), mps, true);

 if(client == newclient)
  SendCommand(client, MDFNNPCMD_YOULEFT, data, datalen);
 else
  SendCommand(client, MDFNNPCMD_PLAYERLEFT, data, datalen);
}

static void SendPlayerList(ClientEntry *client)
{
 GameEntry *tg = client->game;

 //if(client->protocol >= 4)
 //{
 //
 //}
 //else
 {
  for(int x = 0; x < MaxClientsPerGame; x++)
  {
   if(tg->Clients[x])
   {
    AnnouncePlayer(client, tg->Clients[x]);
   }
  }
 }
}

// Disconnect client, and destroy some of the connection structures, but leave everything else intact.
static void DisconnectClient(ClientEntry *client, const char *format, ...)
{
 if(client->TCPSocket != -1)
 {
  time_t curtime = time(NULL);

  if(format == NULL)
  {
   client->DisconnectReason[0] = 0;
  }
  else
  {
   va_list ap;
   va_start(ap, format);
   vsnprintf(client->DisconnectReason, sizeof(client->DisconnectReason), format, ap);
   va_end(ap);
  }

  if(client->game)
   printf("Client %u, <%s> disconnected from game %u for reason <%s> on %s", client->id, client->nickname, (unsigned)(client->game - Games), client->DisconnectReason, ctime(&curtime));
  else
   printf("Unassigned client %u disconnected for reason <%s> on %s", client->id, client->DisconnectReason, ctime(&curtime));
 }

 if(client->sendq)
 {
  free(client->sendq);
  client->sendq = NULL;
 }

 if(client->nbtcp)
 {
  free(client->nbtcp);
  client->nbtcp = NULL;
 }
 
 if(client->TCPSocket != -1)
 {
  close(client->TCPSocket);
  client->TCPSocket = -1;
 }

 client->nbtcphas = 0;
 client->nbtcplen = 0;
 client->nbtcptype = 0;

 client->sendqcork = 0;
 client->sendqlen = 0;
 client->sendqalloced = 0;
}

static void KillClient(ClientEntry *client)
{
 GameEntry *game;

 if(!client)
 {
  puts("Erhm, attempt to kill NULL client o_O");
  return;
 }

 game = client->game;
 if(game)
 {
  //
  // Calculate what the player controlled before we destroy that information.
  //
  uint32 mps;

  mps = MakeMPS(client);

  // Remove the client from the game's player list BEFORE we do an announcement that the client has left.  Which should be obvious, but we used to do it backwards
  // and wonkiness randomly ensued. :/
  //
  // And uncomment out this code immediately below if we ever have a "nice" quit handshake rather than a hard disconnect.
  // AnnouncePlayerLeft(client, client, mps, mergedto);

  for(int x = 0; x < MaxClientsPerGame; x++)
  {
   if(game->Clients[x] && (game->Clients[x] == client))
   {
    game->Clients[x] = NULL;
    game->ClientToController[x] = 0;
    break;
   }
  }

  RecalcCInUse(game); // Recalc ControllersInUse bitfield.

  // Now announce to the remaining players that the client has left.
  for(int x = 0; x < MaxClientsPerGame; x++)
  {
   if(!game->Clients[x])
    continue;

   AnnouncePlayerLeft(game->Clients[x], client, mps);
  }

  if(!game->Zombie)	// Make sure the game is not already a zombie, since we could have zombified it in a recursive call to KillClient() above.
  {
   bool AnyClientsLeft = false;		// Any clients left connected to this game?

   for(int x = 0; x < MaxClientsPerGame && !AnyClientsLeft; x++)
    if(game->Clients[x])
     AnyClientsLeft = true;

   if(!AnyClientsLeft)
   {
    game->Zombie = true;
   }
  }
 }

 DisconnectClient(client, NULL);

 memset(client, 0, sizeof(ClientEntry));
 client->TCPSocket = -1;
}

static bool AddClientToGame(ClientEntry *client, const uint8 id[16], const uint8 *emu_id)
{
 GameEntry *game,*fegame;
 game = NULL;

 fegame = NULL;

 /* First, find an available game. */
 for(int wg = 0; wg < ServerConfig.MaxClients; wg++)
 {
  if(!Games[wg].TotalControllers && !fegame)
  {
   if(!fegame)
    fegame=&Games[wg];
  }
  else if(Games[wg].TotalControllers && !memcmp(Games[wg].id,id,16)) /* A match was found! */
  {
   game = &Games[wg];
   break;
  }
 }

 if(game)
 {
  if(game->ProtocolVersion != client->protocol_version)
  {
   TextToClient(client, "Protocol version mismatch.  Game: %u, You: %u", game->ProtocolVersion, client->protocol_version);
   DisconnectClient(client, "Protocol version mismatch.  Game: %u, You: %u", game->ProtocolVersion, client->protocol_version);
   return(0);
  }

  if(memcmp(game->EmulatorID, emu_id, 64))
  {
   TextToClient(client, "Emulator (version) mismatch.  Game: %.64s, You: %.64s", game->EmulatorID, emu_id);
   DisconnectClient(client, "Emulator (version) mismatch.  Game: %.64s, You: %.64s", game->EmulatorID, emu_id);
   return(0);
  }

  if(game->TotalControllers != client->total_controllers)
  {
   TextToClient(client, "Number of controllers mismatch.  Game: %u, You: %u", game->TotalControllers, client->total_controllers);
   DisconnectClient(client, "Number of controllers mismatch.  Game: %u, You: %u", game->TotalControllers, client->total_controllers);
   return(0);
  }

  for(int x = 0; x < client->total_controllers; x++)
  {
   if(game->ControllerType[x] != client->controller_type[x])
   {
    TextToClient(client, "Controller type mismatch for controller %u.  Game: %u, You: %u", x + 1, game->ControllerType[x], client->controller_type[x]);
    DisconnectClient(client, "Controller type mismatch for controller %u.  Game: %u, You: %u", x + 1, game->ControllerType[x], client->controller_type[x]);
    return(0);
   }

   if(game->ControllerDataSize[x] != client->controller_data_size[x])
   {
    TextToClient(client, "Controller data size mismatch for controller %u.  Game: %u, You: %u", x + 1, game->ControllerDataSize[x], client->controller_data_size[x]);
    DisconnectClient(client, "Controller data size mismatch for controller %u.  Game: %u, You: %u", x + 1, game->ControllerDataSize[x], client->controller_data_size[x]);
    return(0);
   }
  }

  if(game->TotalControllersDataSize != client->total_controllers_data_size)
  {
   // This shouldn't happen...
   TextToClient(client, "Controllers total data size mismatch.  Game: %u, You: %u", game->TotalControllersDataSize, client->total_controllers_data_size);
   DisconnectClient(client, "Controllers total data size mismatch.  Game: %u, You: %u", game->TotalControllersDataSize, client->total_controllers_data_size);
   return(0);
  }
 }

 if(!game) /* Hmm, no game found.  Guess we'll have to create one. */
 {
  time_t curtime = time(NULL);

  game=fegame;
  printf("Game %u added on %s", (int)(game-Games), ctime(&curtime));
  memset(game, 0, sizeof(GameEntry));

  game->Zombie = false;
  game->TotalControllers = client->total_controllers; // total_controllers is validated in the user login code
  game->TotalControllersDataSize = client->total_controllers_data_size;

  for(int x = 0; x < game->TotalControllers; x++)
  {
   game->ControllerType[x] = client->controller_type[x];
   game->ControllerDataSize[x] = client->controller_data_size[x];
   game->ControllerDataOffset[x] = client->controller_data_offset[x];
  }

  game->fps = 1008307711; // NES NTSC FPS magical number from beyond the moon, the default.
  game->last_time = MBL_Time64();
  game->ProtocolVersion = client->protocol_version;
  memcpy(game->EmulatorID, emu_id, 64);
  memcpy(game->id, id, 16);
 }

 for(int n = 0; n < MaxClientsPerGame; n++)
 {
  if(game->Clients[n])
  {
   SendCommand(game->Clients[n], MDFNNPCMD_REQUEST_STATE, NULL, 0);
   break;
  }
 }

 // First, find an empty client slot.
 int client_slot = -1;
 for(int n = 0; n < MaxClientsPerGame; n++)
 {
  if(!game->Clients[n])
  {
   game->Clients[n] = client;
   client_slot = n;
   break;
  }
 }

 // Game is full.
 if(client_slot < 0)
 {
  TextToClient(client, "Sorry, game is full.");
  DisconnectClient(client, "Game is full.");
  return(0);
 }

 client->game = game;
 client->game_csid = client_slot;

 {
  game->ClientToController[client_slot] = 0;
  unsigned int lc_count = client->local_players;
  for(int n = 0; n < game->TotalControllers && lc_count; n++)
  {
   if(!(game->ControllersInUse & (1U << n)))
   {
    game->ClientToController[client_slot] |= (1U << n);
    game->ControllersInUse |= (1U << n); 
    lc_count--;
   }
  }
 }

 // Zap the game with the de-zombification ray since it has a guaranteed juicy player now.
 game->Zombie = false;
 return(true);
}

int main(int argc, char *argv[])
{
 union
 {
  struct sockaddr_in6 sockin6;
  struct sockaddr_in sockin;
  struct sockaddr saddr;
 };

 SeedRand(time(NULL));

 if(argc < 2)
 {
  if(strchr(argv[0],' '))
   printf("Usage: \"%s\" <configfile>\n",argv[0]);
  else
   printf("Usage: %s <configfile>\n",argv[0]);
  exit(-1);
 }

 printf("Starting Mednafen-Server %s\n\n", VERSION);

 if(!LoadConfig(argv[1]))
 {
  puts("Error loading configuration file");
  exit(-1);
 }

#ifdef SIGPIPE
 signal(SIGPIPE, SIG_IGN);
#endif

 Games = (GameEntry *)calloc(ServerConfig.MaxClients, sizeof(GameEntry));
 AllClients = (ClientEntry *)calloc(ServerConfig.MaxClients, sizeof(ClientEntry));

 for(int x = 0; x < ServerConfig.MaxClients; x++)
 {
  AllClients[x].TCPSocket = -1;
 }

 const int family_try[2] = { AF_INET, AF_INET6 };
 const char *family_try_name[2] = { "IPv4", "IPv6" };

 for(unsigned fti = 0; fti < 2; fti++)
 {
  ListenSocketDef lsd;

  lsd.family = family_try[fti];

  /* Create the socket. */
  if(-1 == (lsd.fd = socket(family_try[fti], SOCK_STREAM, 0)))
  {
   ErrnoHolder ene(errno);

   printf("Error creating %s socket: %s\n", family_try_name[fti], ene.StrError());
   continue;
  }

  /* Disallow IPv4 connections on an IPv6 socket. */
  if(lsd.family == AF_INET6)
  {
#ifdef IPV6_V6ONLY
   int v6only_opt = 1;
   if(setsockopt(lsd.fd, IPPROTO_IPV6, IPV6_V6ONLY, &v6only_opt, sizeof(int)))
   {
    ErrnoHolder ene(errno);

    printf("Warning: Failed to set IPv6 socket to disallow IPv4 connections: %s\n", ene.StrError());
   }
#endif
  }

  /* Bind */
  socklen_t saddr_len;
  if(lsd.family == AF_INET6)
  {
   saddr_len = sizeof(sockin6);

   memset(&sockin6, 0, sizeof(sockin6));
   memcpy(&sockin6.sin6_addr, &in6addr_any, sizeof(in6_addr));	// = IN6ADDR_ANY_INIT;
   sockin6.sin6_family = AF_INET6;
   sockin6.sin6_port = htons(ServerConfig.Port);
  }
  else
  {
   saddr_len = sizeof(sockin);

   memset(&sockin, 0, sizeof(sockin));
   sockin.sin_addr.s_addr = INADDR_ANY;
   sockin.sin_family = AF_INET;
   sockin.sin_port = htons(ServerConfig.Port);
  }

  if(bind(lsd.fd, &saddr, saddr_len))
  {
   ErrnoHolder ene(errno);
   printf("Bind error: %s\n", ene.StrError());
   exit(-1);
  }

  /* Set send buffer size to 262,144 bytes. */
  int sndbufsize = 262144;
  if(setsockopt(lsd.fd, SOL_SOCKET, SO_SNDBUF, &sndbufsize, sizeof(int)))
  {
   // Not a fatal error.
   ErrnoHolder ene(errno);

   printf("Warning: Send buffer size set failed: %s", ene.StrError());
  }

  int tcpopt = 1;
  if(setsockopt(lsd.fd, SOL_TCP, TCP_NODELAY, &tcpopt, sizeof(int)))
  {
   ErrnoHolder ene(errno);

   printf("Enabling option TCP_NODELAY failed: %s\n", ene.StrError());
   exit(-1);
  }

  if(listen(lsd.fd, 16))
  {
   ErrnoHolder ene(errno);

   printf("Listen error: %s\n", ene.StrError());
   exit(-1);
  }

  { 
   char tbuf[256];

   if(lsd.family == AF_INET6)
    inet_ntop(lsd.family, &sockin6.sin6_addr, tbuf, sizeof(tbuf));
   else
    inet_ntop(lsd.family, &sockin.sin_addr, tbuf, sizeof(tbuf));

   printf("Listening on %s %u\n", tbuf, ServerConfig.Port);
  }

  /* We don't want to block on accept() */
  fcntl(lsd.fd, F_SETFL, fcntl(lsd.fd, F_GETFL) | O_NONBLOCK);

  ListenSockets.push_back(lsd);
 }

 if(ListenSockets.size() == 0)
  exit(-1);

 #if defined(HAVE_MLOCKALL) && defined(MCL_CURRENT)
 if(mlockall(MCL_CURRENT) != 0)
 {
  ErrnoHolder ene(errno);

  printf("Note: mlockall(MCL_CURRENT) failed: %s (not a major problem; see the documentation if curious)\n", ene.StrError());
 }
 #endif

 /* Now for the BIG LOOP. */
 while(1)
 {
  const time_t cur_epoch_time = time(NULL);
  bool try_accept = true;

  // Kill(and send quit messages) any zombie-type clients, and accept() new connections.
  for(int n = 0; n < ServerConfig.MaxClients; n++)
  {
   if(AllClients[n].TCPSocket != -1)
    continue;

   if(AllClients[n].TCPSocket == -1 && AllClients[n].InUse)
    KillClient(&AllClients[n]);

   if(try_accept)
   {  
    for(unsigned lsi = 0; lsi < ListenSockets.size() && (AllClients[n].TCPSocket == -1); lsi++)
    {
     socklen_t saddr_accept_len;

     if(ListenSockets[lsi].family == AF_INET6)
      saddr_accept_len = sizeof(sockin6);
     else
      saddr_accept_len = sizeof(sockin);

     if((AllClients[n].TCPSocket = accept(ListenSockets[lsi].fd, &saddr, &saddr_accept_len)) != -1)
     {
      char tbuf[256];

      /* We have a new client.  Yippie. */

      fcntl(AllClients[n].TCPSocket, F_SETFL, fcntl(AllClients[n].TCPSocket, F_GETFL) | O_NONBLOCK);

      AllClients[n].InUse = true;
      AllClients[n].timeconnect_us = MBL_Time64();
      AllClients[n].id = n;

      if(ListenSockets[lsi].family == AF_INET6)
       inet_ntop(ListenSockets[lsi].family, &sockin6.sin6_addr, tbuf, sizeof(tbuf));
      else
       inet_ntop(ListenSockets[lsi].family, &sockin.sin_addr, tbuf, sizeof(tbuf));

      printf("Client %u connecting from %s on %s", n, tbuf, ctime(&cur_epoch_time));

      StartNBTCPReceive(&AllClients[n], NBTCP_LOGINLEN, 4);
     }

     // If we didn't accept() any new client, don't call accept() any more on iterating through AllClients; we'll catch any new clients the next time around the BIG LOOP.
     if(AllClients[n].TCPSocket == -1)
      try_accept = false;
    } // end if(try_accept)
   }  
  }

  /* Check for users still in the login process(not yet assigned a game). BOING */
  {
   const int64 CurTimeUS = MBL_Time64();

   for(int n = 0; n < ServerConfig.MaxClients; n++)
   {
    if(AllClients[n].TCPSocket != -1 && !AllClients[n].game)
    {
     if((AllClients[n].timeconnect_us + (int64)ServerConfig.ConnectTimeout * 1000 * 1000) < CurTimeUS)
     {
      KillClient(&AllClients[n]);
     }
     else
      while(CheckNBTCPReceive(&AllClients[n])) {};
    }
   }
  }

  for(int whichgame = 0; whichgame < ServerConfig.MaxClients; whichgame++)
  {
   if(!Games[whichgame].fps)
    continue;

   // Destroy zombies. noooooo, poor zombies :(
   if(Games[whichgame].Zombie)
   {
    time_t curtime = time(NULL);
    printf("Game %u destroyed on %s", whichgame, ctime(&curtime));
    memset(&Games[whichgame], 0, sizeof(GameEntry));
    continue;
   }

   int64 last_time_inc = (int64)65536 * 256 * 1000000 / Games[whichgame].fps;
   const int64 CurGameTimeUS = MBL_Time64();

   if((Games[whichgame].last_time + last_time_inc) > CurGameTimeUS)
    continue;

   Games[whichgame].last_time += last_time_inc;
   //printf("%lld\n", last_time_inc);

   /* Now, the loop to get data from each client.  Meep. */
   for(int n = 0; n < MaxClientsPerGame; n++)
   {
    ClientEntry *client = Games[whichgame].Clients[n];

    if(!client)
     continue;

    while(CheckNBTCPReceive(client)) {};

    if((client->last_receive_time + (int64)ServerConfig.IdleTimeout * 1000 * 1000) < CurGameTimeUS)
    {
     DisconnectClient(client, "Idle timeout met.");
     continue;
    }
   } // A games clients

   //
   //
   //
   memset(Games[whichgame].joybuf, 0, Games[whichgame].TotalControllersDataSize + 1);
   for(int n = 0; n < MaxClientsPerGame; n++)
   {
    if(!Games[whichgame].Clients[n])
     continue;

    if(Games[whichgame].Clients[n]->change_pending)
     continue;

    int wx = 0;
    for(int c = 0; c < Games[whichgame].TotalControllers; c++)
    {
     if(Games[whichgame].ClientToController[n] & (1U << c))
     {
      for(int cnt = 0; cnt < Games[whichgame].ControllerDataSize[c]; cnt++)
      {
       Games[whichgame].joybuf[Games[whichgame].ControllerDataOffset[c] + cnt] |= Games[whichgame].Clients[n]->local_controller_buffer[wx];
       wx++;
      }
     }
    }
   }
   //
   //
   //

   /* Now we send the data to all the clients. */
   for(int n = 0; n < MaxClientsPerGame; n++)
   {
    if(!Games[whichgame].Clients[n])
     continue;

    Games[whichgame].Clients[n]->sendqcork = 0;
    MakeSendTCP(Games[whichgame].Clients[n], Games[whichgame].joybuf, Games[whichgame].TotalControllersDataSize + 1);
    Games[whichgame].Clients[n]->sendqcork = 1;
   } // A game's clients
  } // Games

  // Now, determine the amount of time we should sleep, and sleep it.
  // TODO: Consider using select() with a timeout in the future, so that throughput will be higher
  //       when running on very fast links with small local OS TCP receive and send buffers.
  int64 sleep_amount = 25000;
  int64 curgametime = MBL_Time64(); // Don't use cached game time from above, otherwise we could oversleep.
  for(int whichgame = 0; whichgame < ServerConfig.MaxClients; whichgame ++)
  {
   if(!Games[whichgame].fps)
    continue;
   int64 last_time_inc = (int64)65536 * 256 * 1000000 / Games[whichgame].fps;
   int64 sandwich = (Games[whichgame].last_time + last_time_inc) - curgametime;
   if(sandwich <= 0)
   {
    sleep_amount = 0;
    break;
   }
   else if(sandwich < sleep_amount)
    sleep_amount = sandwich;
  }

  if(sleep_amount > 0)
   MBL_Sleep64(sleep_amount);
  //printf("%lld, %lld\n", sleep_amount, MBL_Time64() - curgametime);
 } // while(1)
}
