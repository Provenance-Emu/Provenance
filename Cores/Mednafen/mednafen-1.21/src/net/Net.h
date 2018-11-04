/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* Net.h:
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

#ifndef __MDFN_NET_NETCLIENT_H
#define __MDFN_NET_NETCLIENT_H

#include <mednafen/mednafen.h>

namespace Net
{

class Connection
{
 public:

 virtual ~Connection() = 0;

 //
 // returns 'true' once a connection has been established(regardless of whether or not the connection has been lost since)
 //
 virtual bool Established(int32 timeout = 0) = 0;

 //
 // CanSend()/CanReceive() returns 'true' if Send()/Receive() with len=1 would be non-blocking if Send()/Receive() actually were blocking;
 // i.e. Can*() have select() style semantics.
 //
 // May timeout before timeout specified(if a signal interrupts an underlying system call).
 //
 virtual bool CanSend(int32 timeout = 0) = 0;
 virtual bool CanReceive(int32 timeout = 0) = 0;

 virtual uint32 Send(const void* data, uint32 len) = 0;		// Non-blocking
 virtual uint32 Receive(void* data, uint32 len) = 0;		// Non-blocking
};

std::unique_ptr<Connection> Connect(const char* host, unsigned int port);
std::unique_ptr<Connection> Accept(unsigned int port);

}
#endif
