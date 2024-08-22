/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* Net_POSIX.cpp:
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

#include "Net_POSIX.h"

#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <sys/time.h>
#include <poll.h>

#ifndef SOL_TCP
 #define SOL_TCP IPPROTO_TCP
#endif

namespace Net
{

class POSIX_Connection : public Connection
{
 public:

 POSIX_Connection();
 virtual ~POSIX_Connection() override;

 virtual bool CanSend(int32 timeout = 0) override;
 virtual bool CanReceive(int32 timeout = 0) override;

 virtual uint32 Send(const void *data, uint32 len) override;

 virtual uint32 Receive(void *data, uint32 len) override;

 protected:

 int fd = -1;
 bool fully_established = false;
};

class POSIX_Client : public POSIX_Connection
{
 public:
 POSIX_Client(const char *host, unsigned int port);

 virtual bool Established(int32 timeout = 0) override;
};

#if 0
class POSIX_Server : public POSIX_Connection
{
 public:
 POSIX_Server(unsigned int port);

 virtual bool Established(bool wait = false) override;
};
#endif

POSIX_Client::POSIX_Client(const char *host, unsigned int port)
{
 {
  struct addrinfo hints;
  struct addrinfo *result;
  int rv;
  char service[64];

  fd = -1;

  snprintf(service, sizeof(service), "%u", port);

  memset(&hints, 0, sizeof(struct addrinfo));
  hints.ai_family = AF_UNSPEC;
  hints.ai_socktype = SOCK_STREAM;
#ifdef AI_ADDRCONFIG
  hints.ai_flags = AI_ADDRCONFIG;
#else
  hints.ai_flags = 0;
#endif
  hints.ai_protocol = 0;

  if((rv = getaddrinfo(host, service, &hints, &result)) != 0)
  {
   if(rv == EAI_SYSTEM)
   {
    ErrnoHolder ene(errno);
    throw MDFN_Error(ene.Errno(), _("getaddrinfo() failed: %s"), ene.StrError());
   }
   else
    throw MDFN_Error(0, _("getaddrinfo() failed: %s"), gai_strerror(rv));
  }

  for(int tryit = 0; tryit < 2; tryit++) // Quick hackish way to "sort" IPv4 ahead of everything else.
  {
   for(struct addrinfo *rp = result; rp != NULL; rp = rp->ai_next)
   {
    //printf("%u\n", rp->ai_family);

    if(tryit == 0 && rp->ai_family != AF_INET)
     continue;

    fd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
    if(fd == -1)
    {
     ErrnoHolder ene(errno);

     freeaddrinfo(result);

     throw(MDFN_Error(ene.Errno(), _("socket() failed: %s"), ene.StrError()));
    }

    #ifdef SO_NOSIGPIPE
    {
     int opt = 1;

     if(setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &opt, sizeof(opt)) == -1)
     {
      ErrnoHolder ene(errno);

      throw MDFN_Error(ene.Errno(), _("setsockopt() failed: %s"), ene.StrError());
     }
    }
    #endif

    fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK);

    TryConnectAgain:;
    if(connect(fd, rp->ai_addr, rp->ai_addrlen) == -1)
    {
     if(errno == EINTR)
      goto TryConnectAgain;
     else if(errno != EINPROGRESS)
     {
      ErrnoHolder ene(errno);

      freeaddrinfo(result);
      close(fd);
      fd = -1;

      throw MDFN_Error(ene.Errno(), _("connect() failed: %s"), ene.StrError());
     }
    }
    goto BreakOut;
   }
  }

  BreakOut: ;

  freeaddrinfo(result);
  result = NULL;

  if(fd == -1)
  {
   throw MDFN_Error(0, "BOOGA BOOGA");
  }
 }
}

bool POSIX_Client::Established(int32 timeout)
{
 if(fully_established)
  return true;

 if(!CanSend(timeout))
  return false;

 {
  int errc = 0;
  socklen_t errc_len = sizeof(errc);

  if(getsockopt(fd, SOL_SOCKET, SO_ERROR, &errc, &errc_len) == -1)
  {
   ErrnoHolder ene(errno);

   throw MDFN_Error(ene.Errno(), _("getsockopt() failed: %s"), ene.StrError());
  }
  else if(errc)
  {
   ErrnoHolder ene(errc);

   throw MDFN_Error(ene.Errno(), _("connect() failed: %s"), ene.StrError());
  }
 }

 {
  int tcpopt = 1;
  if(setsockopt(fd, SOL_TCP, TCP_NODELAY, &tcpopt, sizeof(int)) == -1)
  {
   ErrnoHolder ene(errno);

   throw MDFN_Error(ene.Errno(), _("setsockopt() failed: %s"), ene.StrError());
  }
 }

 fully_established = true;

 return true;
}

POSIX_Connection::POSIX_Connection()
{

}

POSIX_Connection::~POSIX_Connection()
{
 if(fd != -1)
 {
  //shutdown(fd, SHUT_RDWR); // TODO: investigate usage scenarios
  close(fd);
  fd = -1;
 }
}

//
// Use poll() instead of select() so the code doesn't malfunction when
// exceeding the FD_SETSIZE ceiling(which can occur in some quasi-pathological Mednafen use cases, such as making and running with an M3U file
// that ultimately references thousands of files through CUE sheets).
//
bool POSIX_Connection::CanSend(int32 timeout)
{
 int rv;
 struct pollfd fds[1];

 TryAgain:
 memset(fds, 0, sizeof(fds));
 fds[0].fd = fd;
 fds[0].events = POLLOUT | POLLHUP | POLLERR;
 rv = poll(fds, 1, ((timeout >= 0) ? (timeout + 500) / 1000 : -1));

 if(rv == -1)
 {
  if(errno == EINTR)
  {
   timeout = 0;
   goto TryAgain;
  }

  ErrnoHolder ene(errno);

  throw MDFN_Error(ene.Errno(), _("poll() failed: %s"), ene.StrError());
 }

 return (bool)(fds[0].revents & (POLLOUT | POLLERR));
}

bool POSIX_Connection::CanReceive(int32 timeout)
{
 int rv;
 struct pollfd fds[1];

 TryAgain:
 memset(fds, 0, sizeof(fds));
 fds[0].fd = fd;
 fds[0].events = POLLIN | POLLHUP | POLLERR;
 rv = poll(fds, 1, ((timeout >= 0) ? (timeout + 500) / 1000 : -1));

 if(rv == -1)
 {
  if(errno == EINTR)
  {
   timeout = 0;
   goto TryAgain;
  }

  ErrnoHolder ene(errno);

  throw MDFN_Error(ene.Errno(), _("poll() failed: %s"), ene.StrError());
 }

 return (bool)(fds[0].revents & (POLLIN | POLLHUP | POLLERR));
}

uint32 POSIX_Connection::Send(const void* data, uint32 len)
{
 if(!fully_established)
  throw MDFN_Error(0, _("Bug: Send() called when connection not fully established."));

 ssize_t rv;

 #ifdef MSG_NOSIGNAL
 rv = send(fd, data, len, MSG_NOSIGNAL);
 #else
 rv = send(fd, data, len, 0);
 #endif

 if(rv < 0)
 {
  if(errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR)
  {
   ErrnoHolder ene(errno);

   throw MDFN_Error(ene.Errno(), _("send() failed: %s"), ene.StrError());
  }
  return(0);
 }

 return rv;
}

uint32 POSIX_Connection::Receive(void* data, uint32 len)
{
 if(!fully_established)
  throw MDFN_Error(0, _("Bug: Receive() called when connection not fully established."));

 ssize_t rv;

 rv = recv(fd, data, len, 0);

 if(rv < 0)
 {
  if(errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR)
  {
   ErrnoHolder ene(errno);

   throw MDFN_Error(ene.Errno(), _("recv() failed: %s"), ene.StrError());
  }
  return(0);
 }
 else if(rv == 0)
 {
  throw MDFN_Error(0, _("recv() failed: peer has closed connection"));
 }
 return rv;
}

std::unique_ptr<Connection> POSIX_Connect(const char* host, unsigned int port)
{
 return std::unique_ptr<Connection>(new POSIX_Client(host, port));
}

#if 0
std::unique_ptr<Connection> POSIX_Accept(unsigned int port)
{
 return new POSIX_Server(port);
}
#endif

}
