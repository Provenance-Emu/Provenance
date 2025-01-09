
#include "types.h"
#include "profctr.h"

void ProfCtrInit()
{
}

void ProfCtrShutdown()
{
}

void ProfCtrReset()
{
}

Uint32 ProfCtrGetCycle()
{
	Uint32 uCycles;
	__asm {
		RDTSC
		mov	uCycles,eax
	};

	return uCycles;
}

Uint32 ProfCtrGetCounter0()
{
	return 0;
}

Uint32 ProfCtrGetCounter1()
{
	return 0;
}

//	__asm __emit 0fh __asm _emit 031h

