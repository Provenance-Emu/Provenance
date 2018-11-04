#pragma once
#include "types.h"

u32 maple_GetBusId(u32 addr);
u32 maple_GetPort(u32 addr);
u32 maple_GetAttachedDevices(u32 bus);
u32 maple_GetAddress(u32 bus,u32 port);