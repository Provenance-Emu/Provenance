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

#include "NetClient_POSIX.h"

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

NetClient_POSIX::NetClient_POSIX() : fd(-1)
{

}

NetClient_POSIX::~NetClient_POSIX()
{
 Disconnect();
}

void NetClient_POSIX::Connect(const char *host, unsigned int port)
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

    if(connect(fd, rp->ai_addr, rp->ai_addrlen) == -1)
    {
     ErrnoHolder ene(errno);

     freeaddrinfo(result);
     close(fd);
     fd = -1;

     throw(MDFN_Error(ene.Errno(), _("connect() failed: %s"), ene.StrError()));
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

 fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK);
 {
  int tcpopt = 1;
  if(setsockopt(fd, SOL_TCP, TCP_NODELAY, &tcpopt, sizeof(int)) == -1)
  {
   ErrnoHolder ene(errno);

   close(fd);
   fd = -1;

   throw(MDFN_Error(ene.Errno(), _("setsockopt() failed: %s"), ene.StrError()));
  }
 }

 #ifdef SO_NOSIGPIPE
 {
  int opt = 1;

  if(setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &opt, sizeof(opt)) == -1)
  {
   ErrnoHolder ene(errno);

   close(fd);
   fd = -1;

   throw(MDFN_Error(ene.Errno(), _("setsockopt() failed: %s"), ene.StrError()));
  }
 }
 #endif
}

void NetClient_POSIX::Disconnect(void)
{
 if(fd != -1)
 {
  //shutdown(fd, SHUT_RDWR); // TODO: investigate usage scenarios
  close(fd);
  fd = -1;
 }
}

bool NetClient_POSIX::IsConnected(void)
{
 if(fd == -1)
  return(false);


 return(true);
}

//
// Use poll() instead of select() so the code doesn't malfunction when
// exceeding the FD_SETSIZE ceiling(which can occur in some quasi-pathological Mednafen use cases, such as making and running with an M3U file
// that ultimately references thousands of files through CUE sheets).
//
bool NetClient_POSIX::CanSend(int32 timeout)
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

bool NetClient_POSIX::CanReceive(int32 timeout)
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

uint32 NetClient_POSIX::Send(const void *data, uint32 len)
{
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

uint32 NetClient_POSIX::Receive(void *data, uint32 len)
{
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

