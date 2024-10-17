

#ifndef _PROFCTR_H
#define _PROFCTR_H

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

void ProfCtrInit();
void ProfCtrShutdown();
void ProfCtrReset();
Uint32 ProfCtrGetCycle();
Uint32 ProfCtrGetCounter0();
Uint32 ProfCtrGetCounter1();

#define PROFCTR_CYCLEMULTIPLY 1


#ifdef __cplusplus
}
#endif /* __cplusplus */


#endif


