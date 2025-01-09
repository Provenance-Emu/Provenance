#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "types.h"
#include "proflog.h"
#include "profctr.h"
#include "console.h"

#define PROFLOG_MAXDEPTH 	16
#define PROFLOG_MAXSECTIONS 64

typedef struct ProfLogSection_t
{
	Char 	*pName;
	Int32	nEntry;
	Int32	Count[PROF_COUNTER_NUM];
} ProfLogSectionT;


static Int32 _ProfLog_nSections;
static ProfLogSectionT _ProfLog_Section[PROFLOG_MAXSECTIONS];



//
//
//

static void _ProfLogTabify(Int32 nTabs)
{
	while (nTabs > 0)
	{
		ConPrint("\t");
		nTabs--;
	}
}


static Bool _ProfLogEntryEqual(ProfLogEntryT *pA, ProfLogEntryT *pB)
{
	return !strcmp(pA->pName + 1, pB->pName + 1);
}

static ProfLogSectionT *_ProfLogAddSection(Char *pSectionName)
{
	Int32 iSection;
	ProfLogSectionT *pSection = NULL;

	// find section if already exists
	for (iSection=0; iSection < _ProfLog_nSections; iSection++)
	{
		if (!strcmp(pSectionName, _ProfLog_Section[iSection].pName))
		{
			pSection = &_ProfLog_Section[iSection];
			break;
		}
	}

	if (!pSection && _ProfLog_nSections < PROFLOG_MAXSECTIONS)
	{
		// add section
		pSection = &_ProfLog_Section[_ProfLog_nSections++];

		pSection->pName      = pSectionName;
		pSection->nEntry     = 0;
		pSection->Count[0]     = 0;
		pSection->Count[1]     = 0;
		pSection->Count[2]     = 0;
	}

	return pSection;
}


static void _ProfLogSection(Bool bPrint, Int32 nTabs, Char *pSectionName, ProfLogEntryT *pBegin, ProfLogEntryT *pEnd)
{
	Int32 nCount[PROF_COUNTER_NUM];
	ProfLogSectionT *pSection;

	nCount[PROF_COUNTER_CYCLE]    = (pEnd->Counter[PROF_COUNTER_CYCLE] - pBegin->Counter[PROF_COUNTER_CYCLE]) * PROFCTR_CYCLEMULTIPLY;
	nCount[PROF_COUNTER_COUNTER0] = (pEnd->Counter[PROF_COUNTER_COUNTER0] - pBegin->Counter[PROF_COUNTER_COUNTER0]);
	nCount[PROF_COUNTER_COUNTER1] = (pEnd->Counter[PROF_COUNTER_COUNTER1] - pBegin->Counter[PROF_COUNTER_COUNTER1]);

    pSection = _ProfLogAddSection(pSectionName);
	if (pSection)
	{
		// add to section summary
		pSection->nEntry++;
		pSection->Count[PROF_COUNTER_CYCLE]+=nCount[PROF_COUNTER_CYCLE];
		pSection->Count[PROF_COUNTER_COUNTER0]+=nCount[PROF_COUNTER_COUNTER0];
		pSection->Count[PROF_COUNTER_COUNTER1]+=nCount[PROF_COUNTER_COUNTER1];
	}

	if (bPrint)
	{
		_ProfLogTabify(nTabs);
		ConPrint("%-16s %7d %d %d %d\n", pSectionName, nCount[PROF_COUNTER_COUNTER0], nCount[PROF_COUNTER_COUNTER1], nCount[PROF_COUNTER_CYCLE], pEnd->Counter[PROF_COUNTER_USER]);
	}
}


static void _ProfLogPrintSummary(ProfLogSectionT *pSection, Int32 nSections)
{
	Int32 iSection;
	ConPrint("\n");
	ConPrint("Section summary: \n");

	for (iSection=0; iSection < nSections; iSection++)
	{
		if (pSection->nEntry > 0) 
		{
			ConPrint("%-24s %4d %7d %7d %7d %7d %7d %7d\n", pSection->pName, 
                 pSection->nEntry, 
                pSection->Count[PROF_COUNTER_COUNTER0], 
                pSection->Count[PROF_COUNTER_COUNTER1], 
                pSection->Count[PROF_COUNTER_CYCLE], 

                pSection->Count[PROF_COUNTER_COUNTER0] / pSection->nEntry,
                pSection->Count[PROF_COUNTER_COUNTER1] / pSection->nEntry,
                pSection->Count[PROF_COUNTER_CYCLE] / pSection->nEntry
                );
		}
		pSection++;
	}
}


//
//
//



void ProfLogNew(ProfLogT *pLog, Int32 MaxLogEntries)
{
	pLog->nEntries   = 0;
	pLog->MaxEntries = MaxLogEntries;
	pLog->pLogStart  = (ProfLogEntryT *)malloc(MaxLogEntries * sizeof(ProfLogEntryT));
}

void ProfLogDelete(ProfLogT *pLog)
{
	if (pLog->pLogStart)
	{
		free(pLog->pLogStart);
		pLog->nEntries   = 0;
		pLog->MaxEntries = 0;
		pLog->pLogStart  = NULL;
	}
}


ProfLogEntryT *ProfLogBegin(ProfLogT *pLog)
{
	return pLog->pLogStart;
}

void ProfLogEnd(ProfLogT *pLog, ProfLogEntryT *pEntry)
{
	if (pEntry != NULL)
	{
		// calculate # of entries written
		pLog->nEntries = pEntry - pLog->pLogStart;

	    // max sure we haven't overflowed the log
	    assert (pLog->nEntries <= pLog->MaxEntries);
	}
}

void ProfLogPrint(ProfLogT *pLog, Bool bPrintLog, Bool bPrintSummary)
{
	Int32 iEntry;
	ProfLogEntryT *pEntry = pLog->pLogStart;
	ProfLogEntryT *Stack[PROFLOG_MAXDEPTH];
	Int32 iStackPtr;
	ProfLogEntryT *pLastEntry = NULL;


//	ConPrint("Profile log:\n");

	 _ProfLog_nSections = 0;
	 _ProfLogAddSection("<unknown>");

	iStackPtr = 0;
	for (iEntry=0; iEntry < pLog->nEntries; iEntry++)
	{
		ProfLogEntryT *pSectionEntry = NULL;
        
//        printf("%s %d\n", pEntry->pName, pEntry->Counter[PROF_COUNTER_CYCLE]);

		if (pEntry->pName[0] == '!')
		{
            // section begin
			if (pLastEntry)
			{
				// print last begin
				if (bPrintLog)
				{
					_ProfLogTabify(iStackPtr - 1);
					ConPrint("%s\n", pLastEntry->pName + 1);
				}
			}

			if (iEntry > 0)
			{
				// add unknown section
				_ProfLogSection(bPrintLog, iStackPtr, "<unknown>", pEntry - 1, pEntry);
			}


			// section begin, push on stack
            if (iStackPtr >= PROFLOG_MAXDEPTH)
            {
                ConError("ERROR: Section stack overflow\n");
                break;
            }
			Stack[iStackPtr++] = pEntry;
			pLastEntry = pEntry;
		}
		else
		{
			// section end, pop from stack
            if (iStackPtr <= 0)
            {
                ConError("ERROR: Section stack underflow\n");
                break;
            }
			pSectionEntry = Stack[--iStackPtr];

			// ensure begin/end are from same section
			if (!_ProfLogEntryEqual(pSectionEntry, pEntry))
            {
                ConError("ERROR: Unbalanced enter/leave pair: %s %s\n", pSectionEntry->pName, pEntry->pName);
                break;
            }

			// do we have a begin/end pair adjacent in log?
			if (pSectionEntry == pLastEntry)
			{
				// collapse begin/end
				_ProfLogSection(bPrintLog, iStackPtr, pEntry->pName + 1, pSectionEntry, pEntry);
			}
			else
			{
				// add unknown section
				_ProfLogSection(bPrintLog, iStackPtr + 1, "<unknown>", pEntry - 1, pEntry);

				// print section end
                if (pLastEntry)
                {
                    ConError("ERROR: End without matching begin %s\n", pEntry->pName);
                    break;
                }
				_ProfLogSection(bPrintLog, iStackPtr, pEntry->pName + 1, pSectionEntry, pEntry);
			}

			pLastEntry = NULL;
		}

		pEntry++;
	}

	// ensure stack is empty
	if (pLastEntry != NULL)
    {
        ConError("ERROR: Begin without matching end %s\n", pLastEntry->pName);
    }
    
    
	if (iStackPtr != 0)
    {
        ConError("ERROR: Stack not empty\n");
    }

	if (bPrintSummary)
	{
		_ProfLogPrintSummary(_ProfLog_Section, _ProfLog_nSections);
	}
}

