

#ifndef _PROFCTR_H
#define _PROFCTR_H

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

void ProfCtrInit();
void ProfCtrShutdown();
void ProfCtrReset();

//#define ProfCtrGetCycle() (0)

static inline Uint32 ProfCtrGetCycle()
{                                            
    Uint32 uCycle;                          
	__asm__ volatile ("mfc0  %0, $9" : "=r" (uCycle) : );    
    return uCycle;                          
}


static inline Uint32 ProfCtrGetCounter0()
{                                            
    Uint32 uCount;                          
	__asm__ volatile ("mfpc  %0, 0" : "=r" (uCount) : );    
    return uCount;                          
}

static inline Uint32 ProfCtrGetCounter1()
{                                            
    Uint32 uCount;                          
	__asm__ volatile ("mfpc  %0, 1" : "=r" (uCount) : );    
    return uCount;                          
}



#define PROFCTR_CYCLEMULTIPLY 1


#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif



