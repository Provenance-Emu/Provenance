#ifndef __MDFN_NET_NETWS2_H
#define __MDFN_NET_NETWS2_H

#include "Net.h"

namespace Net
{

std::unique_ptr<Connection> WS2_Connect(const char* host, unsigned int port);
std::unique_ptr<Connection> WS2_Accept(unsigned int port);

}

#endif
