#ifndef __MDFN_NET_NETPOSIX_H
#define __MDFN_NET_NETPOSIX_H

#include "Net.h"

namespace Net
{

std::unique_ptr<Connection> POSIX_Connect(const char* host, unsigned int port);
std::unique_ptr<Connection> POSIX_Accept(unsigned int port);

}
#endif
