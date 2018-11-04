#include "types.h"
#include "maple_if.h"

u32 maple_GetBusId(u32 addr)
{
	return addr>>6;
}

u32 maple_GetPort(u32 addr)
{
	for (int i=0;i<6;i++)
	{
		if ((1<<i)&addr)
			return i;
	}
	return 0;
}
u32 maple_GetAttachedDevices(u32 bus)
{
	verify(MapleDevices[bus][5]!=0);

	u32 rv=0;
	
	for (int i=0;i<5;i++)
		rv|=(MapleDevices[bus][i]!=0?1:0)<<i;

	return rv;
}

//device : 0 .. 4 -> subdevice , 5 -> main device :)
u32 maple_GetAddress(u32 bus,u32 port)
{
	u32 rv=bus<<6;
	rv|=1<<port;

	return rv;
}