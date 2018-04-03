/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* Net_WS2.cpp:
**  Copyright (C) 2012-2016 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

#include "Net_WS2.h"
#include <mednafen/string/string.h>

#include <sys/time.h>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <wspiapi.h>
#include <windows.h>
#include <strsafe.h>

#ifndef AI_ADDRCONFIG
 #define AI_ADDRCONFIG	0x0400
#endif

namespace Net
{

class WS2_Connection : public Connection
{
 public:

 WS2_Connection();
 virtual ~WS2_Connection() override;

 virtual bool CanSend(int32 timeout = 0) override;
 virtual bool CanReceive(int32 timeout = 0) override;

 virtual uint32 Send(const void *data, uint32 len) override;

 virtual uint32 Receive(void *data, uint32 len) override;

 protected:

 SOCKET sd = INVALID_SOCKET;
 bool fully_established = false;
};

class WS2_Client : public WS2_Connection
{
 public:
 WS2_Client(const char *host, unsigned int port);

 virtual bool Established(int32 timeout = 0) override;
};

static std::string ErrCodeToString(int errcode)
{
 std::string ret;
 void* msg_buffer = NULL;
 unsigned int tchar_count;

 tchar_count = FormatMessageW(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
	       		     NULL, errcode,
		             MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
               		     (LPWSTR)&msg_buffer, 0, NULL);

 if(tchar_count == 0)
  return "Error Error";

 //{
 // TCHAR trim_chars[] = TEXT("\r\n\t ");
 //
 // StrTrim((PTSTR)msg_buffer, trim_chars);
 //}
 try
 {
  ret = UTF16_to_UTF8((char16_t*)msg_buffer, tchar_count);
 }
 catch(...)
 {
  LocalFree(msg_buffer);
  throw;
 }
 LocalFree(msg_buffer);
 return ret;
}

WS2_Connection::WS2_Connection()
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
}

WS2_Connection::~WS2_Connection()
{
 if(sd != INVALID_SOCKET)
 {
  //shutdown(sd, SHUT_RDWR); // TODO: investigate usage scenarios
  closesocket(sd);
  sd = INVALID_SOCKET;
 }
 WSACleanup();
}

WS2_Client::WS2_Client(const char *host, unsigned int port)
{
 {
  struct addrinfo hints;
  struct addrinfo *result;
  int rv;
  char service[64];

  sd = INVALID_SOCKET;

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

    sd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
    if(sd == INVALID_SOCKET)
    {
     int errcode = WSAGetLastError();

     freeaddrinfo(result);

     throw MDFN_Error(0, _("socket() failed: %d %s"), errcode, ErrCodeToString(errcode).c_str());
    }

    {
     unsigned long nbv = 1;
     DWORD numbytesout = 0;

     if(WSAIoctl(sd, FIONBIO, &nbv, sizeof(nbv), NULL, 0, &numbytesout, NULL, NULL) == SOCKET_ERROR)
     {
      int errcode = WSAGetLastError();

      closesocket(sd);
      sd = INVALID_SOCKET;

      throw MDFN_Error(0, _("WSAIoctl() failed: %d %s"), errcode, ErrCodeToString(errcode).c_str());
     }
    }

    if(connect(sd, rp->ai_addr, rp->ai_addrlen) != 0)
    {
     const int errcode = WSAGetLastError();

     if(errcode != WSAEWOULDBLOCK)
     {
      freeaddrinfo(result);

      closesocket(sd);
      sd = INVALID_SOCKET;

      throw MDFN_Error(0, _("connect() failed: %d %s"), errcode, ErrCodeToString(errcode).c_str());
     }
    }
    goto BreakOut;
   }
  }

  BreakOut: ;

  freeaddrinfo(result);
  result = NULL;

  if(sd == INVALID_SOCKET)
  {
   throw MDFN_Error(0, "BOOGA BOOGA");
  }
 }
}

bool WS2_Client::Established(int32 timeout)
{
 if(fully_established)
  return true;

 {
  int rv;
  fd_set wfds, efds;
  struct timeval tv;

  FD_ZERO(&wfds);
  FD_ZERO(&efds);
  FD_SET(sd, &wfds);
  FD_SET(sd, &efds);

  tv.tv_sec = timeout / (1000 * 1000);
  tv.tv_usec = timeout % (1000 * 1000);

  rv = select(-1, NULL, &wfds, &efds, (timeout >= 0) ? &tv : NULL);

  if(rv == -1)
  {
   int errcode = WSAGetLastError();

   throw MDFN_Error(0, _("select() failed: %d %s"), errcode, ErrCodeToString(errcode).c_str());
  }
  else if(!rv)
   return false;
  else
  {
   if(FD_ISSET(sd, &efds))
   {
    int errc = 0;
    int errc_len = sizeof(errc);

    if(getsockopt(sd, SOL_SOCKET, SO_ERROR, (char*)&errc, &errc_len) == -1)
    {
     const int errcode = WSAGetLastError();

     throw MDFN_Error(0, _("getsockopt() failed: %d %s"), errcode, ErrCodeToString(errcode).c_str());
    }

    throw MDFN_Error(0, _("connect() failed: %d %s"), errc, ErrCodeToString(errc).c_str());
   }
  }
 }

 {
  BOOL tcpopt = 1;
  if(setsockopt(sd, IPPROTO_TCP, TCP_NODELAY, (char*)&tcpopt, sizeof(BOOL)) == SOCKET_ERROR)
  {
   int errcode = WSAGetLastError();

   closesocket(sd);
   sd = INVALID_SOCKET;

   throw MDFN_Error(0, _("setsockopt() failed: %d %s"), errcode, ErrCodeToString(errcode).c_str());
  }
 }

 fully_established = true;

 return true;
}


bool WS2_Connection::CanSend(int32 timeout)
{
 int rv;
 fd_set wfds;
 struct timeval tv;

 FD_ZERO(&wfds);
 FD_SET(sd, &wfds);

 tv.tv_sec = timeout / (1000 * 1000);
 tv.tv_usec = timeout % (1000 * 1000);

 rv = select(-1, NULL, &wfds, NULL, (timeout >= 0) ? &tv : NULL);

 if(rv == -1)
 {
  int errcode = WSAGetLastError();

  throw MDFN_Error(0, _("select() failed: %d %s"), errcode, ErrCodeToString(errcode).c_str());
 }

 return (bool)rv;
}

bool WS2_Connection::CanReceive(int32 timeout)
{
 int rv;
 fd_set rfds;
 struct timeval tv;

 FD_ZERO(&rfds);
 FD_SET(sd, &rfds);

 tv.tv_sec = timeout / (1000 * 1000);
 tv.tv_usec = timeout % (1000 * 1000);

 rv = select(-1, &rfds, NULL, NULL, (timeout >= 0) ? &tv : NULL);

 if(rv == -1)
 {
  int errcode = WSAGetLastError();

  throw MDFN_Error(0, _("select() failed: %d %s"), errcode, ErrCodeToString(errcode).c_str());
 }

 return (bool)rv;
}

uint32 WS2_Connection::Send(const void *data, uint32 len)
{
 if(!fully_established)
  throw MDFN_Error(0, _("Bug: Send() called when connection not fully established."));

 int rv;

 rv = send(sd, (const char *)data, len, 0);

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

uint32 WS2_Connection::Receive(void *data, uint32 len)
{
 if(!fully_established)
  throw MDFN_Error(0, _("Bug: Receive() called when connection not fully established."));

 int rv;

 rv = recv(sd, (char *)data, len, 0);

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

std::unique_ptr<Connection> WS2_Connect(const char* host, unsigned int port)
{
 return std::unique_ptr<Connection>(new WS2_Client(host, port));
}

}
