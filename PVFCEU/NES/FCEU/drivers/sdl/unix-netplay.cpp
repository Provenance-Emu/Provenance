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

//todo - ensure that #ifdef WIN32 makes sense
//consider changing this to use sdl net stuff?

#include "main.h"
#include "input.h"
#include "dface.h"
#include "unix-netplay.h"

#include "../../fceu.h"
#include "../../utils/md5.h"
#include "../../utils/memory.h"

#include <string>
#include "../common/configSys.h"

#include <unistd.h>
#include <sys/types.h>
#include <sys/time.h>
#include <cstring>
#include <cstdlib>
#include <cstdio>
#include <cerrno>
#include <fcntl.h>

#ifdef WIN32
#include <winsock.h>
#else
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <netdb.h>
#endif

extern Config *g_config;

#ifndef socklen_t
#define socklen_t int
#endif

#ifndef SOL_TCP
#define SOL_TCP IPPROTO_TCP
#endif

int FCEUDnetplay=0;

static int s_Socket = -1;

static void
en32(uint8 *buf,
     uint32 morp)
{
	buf[0] = morp;
	buf[1] = morp >> 8;
	buf[2] = morp >> 16;
	buf[3] = morp >> 24;
}

/*
static uint32 de32(uint8 *morp)
{
 return(morp[0]|(morp[1]<<8)|(morp[2]<<16)|(morp[3]<<24));
}
*/

int
FCEUD_NetworkConnect(void)
{
	struct sockaddr_in sockin;
	struct hostent *phostentb;
	unsigned long hadr;
	int TSocket, tcpopt, error;
	int netdivisor;

	// get any required configuration variables
	int port, localPlayers;
	std::string server, username, password, key;
	g_config->getOption("SDL.NetworkIP", &server);
	g_config->getOption("SDL.NetworkUsername", &username);
	g_config->getOption("SDL.NetworkPassword", &password);
	g_config->getOption("SDL.NetworkGameKey", &key);
	g_config->getOption("SDL.NetworkPort", &port);
	g_config->getOption("SDL.NetworkPlayers", &localPlayers);
    
    
	g_config->setOption("SDL.NetworkIP", "");
	g_config->setOption("SDL.NetworkPassword", "");
	g_config->setOption("SDL.NetworkGameKey", "");
    


	// only initialize if remote server is specified
	if(!server.size()) {
		return 0;
	}

	TSocket = socket(AF_INET, SOCK_STREAM, 0);
	if(TSocket < 0) {
		char* s = "Error creating stream socket.";
		puts(s);
		FCEU_DispMessage(s,0);
		FCEUD_NetworkClose();
		return 0;
	}

	// try to setup TCP_NODELAY to avoid network jitters
	tcpopt = 1;
#ifdef BEOS
	error = setsockopt(TSocket, SOL_SOCKET, TCP_NODELAY, &tcpopt, sizeof(int));
#elif WIN32
	error = setsockopt(TSocket, SOL_TCP, TCP_NODELAY,
						(char*)&tcpopt, sizeof(int));
#else
	error = setsockopt(TSocket, SOL_TCP, TCP_NODELAY, &tcpopt, sizeof(int));
#endif
	if(error) {
		puts("Nodelay fail");
	}

	memset(&sockin, 0, sizeof(sockin));
	sockin.sin_family = AF_INET;
	hadr = inet_addr(server.c_str());
	if(hadr != INADDR_NONE) {
		sockin.sin_addr.s_addr = hadr;
	} else {
		puts("*** Looking up host name...");
		phostentb = gethostbyname(server.c_str());
		if(!phostentb) {
			puts("Error getting host network information.");
			FCEU_DispMessage("Error getting host info",0);
			close(TSocket);
			FCEUD_NetworkClose();
			return(0);
		}
		memcpy(&sockin.sin_addr, phostentb->h_addr, phostentb->h_length);
	}

	sockin.sin_port = htons(port);
	puts("*** Connecting to remote host...");
	error = connect(TSocket, (struct sockaddr *)&sockin, sizeof(sockin));
	if(error < 0) {
		puts("Error connecting to remote host.");
		FCEU_DispMessage("Error connecting to server",0);
		close(TSocket);
		FCEUD_NetworkClose();
		return 0;
	}

	s_Socket = TSocket;

	puts("*** Sending initialization data to server...");
	uint8 *sendbuf;
	uint8 buf[5];
	uint32 sblen;

	sblen = 4 + 16 + 16 + 64 + 1 + username.size();
	sendbuf = (uint8 *)FCEU_dmalloc(sblen);
	memset(sendbuf, 0, sblen);

	// XXX soules - should use htons instead of en32() from above!
	//uint32 data = htons(sblen - 4);
	//memcpy(sendbuf, &data, sizeof(data));
	en32(sendbuf, sblen - 4);

	if(key.size())
	{
		struct md5_context md5;
		uint8 md5out[16];

		md5_starts(&md5);
		md5_update(&md5, (uint8*)&GameInfo->MD5.data, 16);
		md5_update(&md5, (uint8 *)key.c_str(), key.size());
		md5_finish(&md5, md5out);
		memcpy(sendbuf + 4, md5out, 16);
	} else
	{
		memcpy(sendbuf + 4, (uint8*)&GameInfo->MD5.data, 16);
    }

	if(password.size()) {
		struct md5_context md5;
		uint8 md5out[16];

		md5_starts(&md5);
		md5_update(&md5, (uint8 *)password.c_str(), password.size());
		md5_finish(&md5, md5out);
		memcpy(sendbuf + 4 + 16, md5out, 16);
	}

	memset(sendbuf + 4 + 16 + 16, 0, 64);

	sendbuf[4 + 16 + 16 + 64] = (uint8)localPlayers;

	if(username.size()) {
		memcpy(sendbuf + 4 + 16 + 16 + 64 + 1,
			username.c_str(), username.size());
	}

#ifdef WIN32
	send(s_Socket, (char*)sendbuf, sblen, 0);
#else
	send(s_Socket, sendbuf, sblen, 0);
#endif
	FCEU_dfree(sendbuf);

#ifdef WIN32
	recv(s_Socket, (char*)buf, 1, 0);
#else
	recv(s_Socket, buf, 1, MSG_WAITALL);
#endif
	netdivisor = buf[0];

	puts("*** Connection established.");
	FCEU_DispMessage("Connection established.",0);

	FCEUDnetplay = 1;
	FCEUI_NetplayStart(localPlayers, netdivisor);

	return 1;
}


int
FCEUD_SendData(void *data,
               uint32 len)
{
	int check = 0, error = 0;
#ifndef WIN32
	error = ioctl(fileno(stdin), FIONREAD, &check);
#endif
	if(!error && check) {
		char buf[1024];
		char *f;
		fgets(buf, 1024, stdin);
		if((f=strrchr(buf,'\n'))) {
			*f = 0;
		}
		FCEUI_NetplayText((uint8 *)buf);
	}

#ifdef WIN32
	send(s_Socket, (char*)data, len ,0);
#else
	send(s_Socket, data, len ,0);
#endif
	return 1;
}

int
FCEUD_RecvData(void *data,
			uint32 len)
{
	int size;
	NoWaiting &= ~2;

	for(;;)
	{
		fd_set funfun;
		struct timeval popeye;

		popeye.tv_sec=0;
		popeye.tv_usec=100000;

		FD_ZERO(&funfun);
		FD_SET(s_Socket, &funfun);

		switch(select(s_Socket + 1,&funfun,0,0,&popeye)) {
		case 0: continue;
		case -1:return 0;
		}

		if(FD_ISSET(s_Socket,&funfun)) {
#ifdef WIN32
			size = recv(s_Socket, (char*)data, len, 0);
#else
			size = recv(s_Socket, data, len, MSG_WAITALL);
#endif

			if(size == len) {
				//unsigned long beefie;

				FD_ZERO(&funfun);
				FD_SET(s_Socket, &funfun);

				popeye.tv_sec = popeye.tv_usec = 0;
				if(select(s_Socket + 1, &funfun, 0, 0, &popeye) == 1)
					//if(!ioctl(s_Socket,FIONREAD,&beefie))
					// if(beefie)
					{
						NoWaiting|=2;
					}
				return 1;
			} else {
				return 0;
			}
		}
	}

	return 0;
}

void
FCEUD_NetworkClose(void)
{
	if(s_Socket > 0) {
#ifdef BEOS
		closesocket(s_Socket);
#else
		close(s_Socket);
#endif
	}
	s_Socket = -1;

	if(FCEUDnetplay) {
		FCEUI_NetplayStop();
	}
	FCEUDnetplay = 0;
}


void
FCEUD_NetplayText(uint8 *text)
{
	char *tot = (char *)FCEU_dmalloc(strlen((const char *)text) + 1);
	char *tmp;
	if (!tot)
		return;
	strcpy(tot, (const char *)text);
	tmp = tot;

	while(*tmp) {
		if(*tmp < 0x20) {
			*tmp = ' ';
		}
		tmp++;
	}
	puts(tot);
	FCEU_dfree(tot);
}
