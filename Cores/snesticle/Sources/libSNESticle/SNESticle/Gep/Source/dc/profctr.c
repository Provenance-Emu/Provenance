
#include <kos.h>
#include "types.h"
#include "profctr.h"

void ProfCtrInit()
{
	timer_set(TMU2, 0xFFFFFFFF, 0xFFFFFFFF, 0);
	timer_start(TMU2);
}

void ProfCtrShutdown()
{
	timer_stop(TMU2);
}




void ProfCtrReset()
{

}

