

#ifndef _PROFCTR_H
#define _PROFCTR_H

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

#include <kos.h>

void ProfCtrInit();
void ProfCtrShutdown();

#define ProfCtrGetCycle() (-timer_count(TMU2))
#define PROFCTR_CYCLEMULTIPLY 16


#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif


