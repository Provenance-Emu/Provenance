/* Mednafen - Multi-system Emulator
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

#include "NetClient_WS2.h"

#include <sys/time.h>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <wspiapi.h>
#include <windows.h>
#include <strsafe.h>

#ifndef AI_ADDRCONFIG
 #define AI_ADDRCONFIG	0x0400
#endif

#include <string>

static std::string ErrCodeToString(int errcode)
{
 std::string ret;
 void *msg_buffer;
 unsigned int tchar_count;

 tchar_count = FormatMessage(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
	       		     NULL, errcode,
		             MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
               		     (LPTSTR)&msg_buffer, 0, NULL);

 if(tchar_count == 0)
 {
  return std::string("Error Error");
 }

 //{
 // TCHAR trim_chars[] = TEXT("\r\n\t ");
 //
 // StrTrim((PTSTR)msg_buffer, trim_chars);
 //}

 #ifdef UNICODE
  #warning "UNICODE TODO"
  ret = "";
 #else
  ret = std::string((char *)msg_buffer);
 #endif
 LocalFree(msg_buffer);

 return(ret);
}

NetClient_WS2::NetClient_WS2()
{
 WORD requested_version;
 WSADATA wsa_data;

 requested_version = MAKEWORD(2, 2);

 if(WSAStartup(requested_version, &wsa_data) != 0)
 {
  int errcode = WSAGetLastError();

  throw MDFN_Error(0, _("WSAStartup() failed: %d %s"), errcode, ErrCodeToString(errcode).c_str());
 }

 if(wsa_data.wVersion < 0x202)
 {
  WSACleanup();
  throw MDFN_Error(0, _("Suitable version of Winsock not found."));
 }

 sd = new SOCKET;
 *(SOCKET*)sd = INVALID_SOCKET;
}

NetClient_WS2::~NetClient_WS2()
{
 Disconnect();
 delete (SOCKET*)sd;

 WSACleanup();
}

void NetClient_WS2::Connect(const char *host, unsigned int port)
{
 {
  struct addrinfo hints;
  struct addrinfo *result;
  int rv;
  char service[64];

  *(SOCKET*)sd = INVALID_SOCKET;

  snprintf(service, sizeof(service), "%u", port);

  memset(&hints, 0, sizeof(struct addrinfo));
  hints.ai_family = AF_UNSPEC;
  hints.ai_socktype = SOCK_STREAM;
  hints.ai_flags = AI_ADDRCONFIG;
  hints.ai_protocol = 0;

  if((rv = getaddrinfo(host, service, &hints, &result)) != 0)
  {
   int errcode = WSAGetLastError();

   throw MDFN_Error(0, _("getaddrinfo() failed: %d %s"), errcode, ErrCodeToString(errcode).c_str());
  }

  for(int tryit = 0; tryit < 2; tryit++) // Quick hackish way to "sort" IPv4 ahead of everything else.
  {
   for(struct addrinfo *rp = result; rp != NULL; rp = rp->ai_next)
   {
    //printf("%u\n", rp->ai_family);
    if(tryit == 0 && rp->ai_family != AF_INET)
     continue;

    *(SOCKET *)sd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
    if(*(SOCKET *)sd == INVALID_SOCKET)
    {
     int errcode = WSAGetLastError();

     freeaddrinfo(result);

     throw MDFN_Error(0, _("socket() failed: %d %s"), errcode, ErrCodeToString(errcode).c_str());
    }

    if(connect(*(SOCKET*)sd, rp->ai_addr, rp->ai_addrlen) != 0)
    {
     int errcode = WSAGetLastError();

     freeaddrinfo(result);

     closesocket(*(SOCKET *)sd);
     *(SOCKET *)sd = INVALID_SOCKET;

     throw MDFN_Error(0, _("connect() failed: %d %s"), errcode, ErrCodeToString(errcode).c_str());
    }
    goto BreakOut;
   }
  }

  BreakOut: ;

  freeaddrinfo(result);
  result = NULL;

  if(*(SOCKET *)sd == INVALID_SOCKET)
  {
   throw MDFN_Error(0, "BOOGA BOOGA");
  }
 }

 {
  BOOL tcpopt = 1;
  if(setsockopt(*(SOCKET*)sd, IPPROTO_TCP, TCP_NODELAY, (char*)&tcpopt, sizeof(BOOL)) == SOCKET_ERROR)
  {
   int errcode = WSAGetLastError();

   closesocket(*(SOCKET *)sd);
   *(SOCKET *)sd = INVALID_SOCKET;

   throw MDFN_Error(0, _("setsockopt() failed: %d %s"), errcode, ErrCodeToString(errcode).c_str());
  }
 }

 {
  unsigned long nbv = 1;
  DWORD numbytesout = 0;

  if(WSAIoctl(*(SOCKET*)sd, FIONBIO, &nbv, sizeof(nbv), NULL, 0, &numbytesout, NULL, NULL) == SOCKET_ERROR)
  {
   int errcode = WSAGetLastError();

   closesocket(*(SOCKET *)sd);
   *(SOCKET *)sd = INVALID_SOCKET;

   throw MDFN_Error(0, _("WSAIoctl() failed: %d %s"), errcode, ErrCodeToString(errcode).c_str());
  }
 }
}

void NetClient_WS2::Disconnect(void)
{
 if(*(SOCKET *)sd != INVALID_SOCKET)
 {
  //shutdown(*(SOCKET*)sd, SHUT_RDWR); // TODO: investigate usage scenarios
  closesocket(*(SOCKET *)sd);
  *(SOCKET *)sd = INVALID_SOCKET;
 }
}

bool NetClient_WS2::IsConnected(void)
{
 if(*(SOCKET *)sd == INVALID_SOCKET)
  return(false);

 return(true);
}

bool NetClient_WS2::CanSend(int32 timeout)
{
 int rv;
 fd_set wfds;
 struct timeval tv;

 FD_ZERO(&wfds);
 FD_SET(*(SOCKET*)sd, &wfds);

 tv.tv_sec = timeout / (1000 * 1000);
 tv.tv_usec = timeout % (1000 * 1000);

 rv = select(-1, NULL, &wfds, NULL, &tv);

 if(rv == -1)
 {
  int errcode = WSAGetLastError();

  throw MDFN_Error(0, _("select() failed: %d %s"), errcode, ErrCodeToString(errcode).c_str());
 }

 return (bool)rv;
}

bool NetClient_WS2::CanReceive(int32 timeout)
{
 int rv;
 fd_set rfds;
 struct timeval tv;

 FD_ZERO(&rfds);
 FD_SET(*(SOCKET*)sd, &rfds);

 tv.tv_sec = timeout / (1000 * 1000);
 tv.tv_usec = timeout % (1000 * 1000);

 rv = select(-1, &rfds, NULL, NULL, (timeout == -1) ? NULL : &tv);

 if(rv == -1)
 {
  int errcode = WSAGetLastError();

  throw MDFN_Error(0, _("select() failed: %d %s"), errcode, ErrCodeToString(errcode).c_str());
 }

 return (bool)rv;
}

uint32 NetClient_WS2::Send(const void *data, uint32 len)
{
 int rv;

 rv = send(*(SOCKET*)sd, (const char *)data, len, 0);

 if(rv < 0)
 {
  int errcode = WSAGetLastError();
  if(errcode != WSAEWOULDBLOCK && errcode != WSAEINTR)
  {
   throw MDFN_Error(0, _("send() failed: %d %s"), errcode, ErrCodeToString(errcode).c_str());
  }
  return(0);
 }

 return rv;
}

uint32 NetClient_WS2::Receive(void *data, uint32 len)
{
 int rv;

 rv = recv(*(SOCKET*)sd, (char *)data, len, 0);

 if(rv < 0)
 {
  int errcode = WSAGetLastError();
  if(errcode != WSAEWOULDBLOCK && errcode != WSAEINTR)
  {
   throw MDFN_Error(0, _("recv() failed: %d %s"), errcode, ErrCodeToString(errcode).c_str());
  }
  return(0);
 }
 else if(rv == 0)
 {
  throw MDFN_Error(0, _("recv() failed: peer has closed connection"));
 }

 return rv;
}

