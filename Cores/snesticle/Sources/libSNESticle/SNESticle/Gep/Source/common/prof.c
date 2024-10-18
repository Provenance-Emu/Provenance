
#include "types.h"
#include "prof.h"


ProfLogEntryT *Prof_pLogEntry;

//
//
//

static ProfLogT _Prof_Log;
static Int32 _Prof_nFrames = 0;


//
//
//


void ProfInit(Int32 MaxLogEntries)
{
	ProfCtrInit();

	ProfLogNew(&_Prof_Log, MaxLogEntries);
	Prof_pLogEntry = ProfLogBegin(&_Prof_Log);
}


void ProfShutdown(void)
{
	ProfLogEnd(&_Prof_Log, Prof_pLogEntry);
	ProfLogDelete(&_Prof_Log);

	ProfCtrShutdown();
}


void ProfStartProfile(Int32 nFrames)
{
	_Prof_nFrames = nFrames;
}


void ProfProcess(void)
{
    ProfCtrReset();
	if (_Prof_nFrames > 0)
	{
		_Prof_nFrames--;

		if (_Prof_nFrames == 0)
		{
            // close log, print log, and reopen log
			ProfLogEnd(&_Prof_Log, Prof_pLogEntry);
			ProfLogPrint(&_Prof_Log, FALSE, TRUE);
//			ProfLogPrint(&_Prof_Log, TRUE, TRUE);
			Prof_pLogEntry = ProfLogBegin(&_Prof_Log);
		}
	} else
	{
        // close and reopen log for next frame
		ProfLogEnd(&_Prof_Log, Prof_pLogEntry);
		Prof_pLogEntry = ProfLogBegin(&_Prof_Log);
	}
}





