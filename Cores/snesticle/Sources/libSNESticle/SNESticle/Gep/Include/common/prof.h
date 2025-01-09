									  
#ifndef _PROF_H
#define _PROF_H

#include "proflog.h"
#include "profctr.h"

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

extern ProfLogEntryT *Prof_pLogEntry;

#ifndef PROF_ENABLED
#define PROF_ENABLED ((CODE_PROFILE==TRUE) || FALSE)
#endif



//
// profile section macros
//

#if PROF_ENABLED

#define PROF_ENTER(__SectionName) \
	Prof_pLogEntry->pName = "!" __SectionName; \
	Prof_pLogEntry->Counter[PROF_COUNTER_CYCLE] = ProfCtrGetCycle(); \
	Prof_pLogEntry->Counter[PROF_COUNTER_COUNTER0] = ProfCtrGetCounter0(); \
	Prof_pLogEntry->Counter[PROF_COUNTER_COUNTER1] = ProfCtrGetCounter1(); \
	Prof_pLogEntry->Counter[PROF_COUNTER_USER] = 0; \
	Prof_pLogEntry++;

#define PROF_LEAVE(__SectionName) \
	Prof_pLogEntry->Counter[PROF_COUNTER_CYCLE] = ProfCtrGetCycle(); \
	Prof_pLogEntry->Counter[PROF_COUNTER_COUNTER0] = ProfCtrGetCounter0(); \
	Prof_pLogEntry->Counter[PROF_COUNTER_COUNTER1] = ProfCtrGetCounter1(); \
	Prof_pLogEntry->Counter[PROF_COUNTER_USER] = 0; \
	Prof_pLogEntry->pName = "~" __SectionName; \
	Prof_pLogEntry++;

#define PROF_ENTER2(__SectionName, _counter) \
	Prof_pLogEntry->pName = "!" __SectionName; \
	Prof_pLogEntry->Counter[PROF_COUNTER_CYCLE] = ProfCtrGetCycle(); \
	Prof_pLogEntry->Counter[PROF_COUNTER_COUNTER0] = ProfCtrGetCounter0(); \
	Prof_pLogEntry->Counter[PROF_COUNTER_COUNTER1] = ProfCtrGetCounter1(); \
	Prof_pLogEntry->Counter[PROF_COUNTER_USER] = _counter; \
	Prof_pLogEntry++;

#define PROF_LEAVE2(__SectionName, _counter) \
	Prof_pLogEntry->Counter[PROF_COUNTER_CYCLE] = ProfCtrGetCycle(); \
	Prof_pLogEntry->Counter[PROF_COUNTER_COUNTER0] = ProfCtrGetCounter0(); \
	Prof_pLogEntry->Counter[PROF_COUNTER_COUNTER1] = ProfCtrGetCounter1(); \
	Prof_pLogEntry->Counter[PROF_COUNTER_USER] = _counter; \
	Prof_pLogEntry->pName = "~" __SectionName; \
	Prof_pLogEntry++;

#else

#define PROF_ENTER(__SectionName) 
#define PROF_LEAVE(__SectionName) 
#define PROF_ENTER2(__SectionName,__x) 
#define PROF_LEAVE2(__SectionName,__x) 

#endif


void ProfInit(Int32 MaxLogEntries);
void ProfShutdown(void);
void ProfProcess(void);
void ProfStartProfile(Int32 nFrames);


#ifdef __cplusplus
}
#endif /* __cplusplus */


#endif
