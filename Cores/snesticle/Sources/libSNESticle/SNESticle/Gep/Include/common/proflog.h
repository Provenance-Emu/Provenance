

#ifndef _PROFLOG_H
#define _PROFLOG_H

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */


enum 
{
	PROF_COUNTER_CYCLE,
	PROF_COUNTER_COUNTER0,
	PROF_COUNTER_COUNTER1,
	PROF_COUNTER_USER,
	PROF_COUNTER_NUM 
};

typedef struct ProfLogEntry_t
{
	char 	*pName;
	Int32	Counter[PROF_COUNTER_NUM];
} ProfLogEntryT;

typedef struct ProfLog_t
{
	Int32		  	MaxEntries;	/* # of log entries */

	Int32			nEntries;
	ProfLogEntryT 	*pLogStart;	/* pointer to start of log data */
} ProfLogT;

void ProfLogNew(ProfLogT *pLog, Int32 MaxLogEntries);
void ProfLogDelete(ProfLogT *pLog);
ProfLogEntryT *ProfLogBegin(ProfLogT *pLog);
void ProfLogEnd(ProfLogT *pLog, ProfLogEntryT *pEntry);
void ProfLogParse(ProfLogT *pLog);
void ProfLogPrint(ProfLogT *pLog, Bool bPrintLog, Bool bPrintSummary);


#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif




