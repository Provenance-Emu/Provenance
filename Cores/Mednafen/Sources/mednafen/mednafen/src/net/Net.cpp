/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* Net.cpp:
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

#include <mednafen/mednafen.h>

#include "Net.h"

#ifdef HAVE_POSIX_SOCKETS
#include "Net_POSIX.h"
#endif

#ifdef WIN32
#include "Net_WS2.h"
#endif

namespace Net
{

Connection::~Connection() { }

std::unique_ptr<Connection> Connect(const char *host, unsigned int port)
{
 #ifdef HAVE_POSIX_SOCKETS
 return POSIX_Connect(host, port);
 #elif defined(WIN32)
 return WS2_Connect(host, port);
 #else
 throw MDFN_Error(0, _("Networking system API support not compiled in."));
 #endif
}

#if 0
std::unique_ptr<Connection> Listen(unsigned int port)
{
 #ifdef HAVE_POSIX_SOCKETS
 return POSIX_Accept(port);
 #elif defined(WIN32)
 return WS2_Accept(port);
 #else
 throw MDFN_Error(0, _("Networking system API support not compiled in."));
 #endif
}
#endif

}
