
#include "types.h"
#include "snspctimer.h"

//
//
//

void SNSpcTimerReset(SNSpcTimerT *pTimer, Uint32 uCyclesPerTick)
{
	pTimer->bEnabled		= FALSE;
	pTimer->uUpCounter		= 0;
	pTimer->uCompare		= 0;
	pTimer->uCyclesPerTick	= uCyclesPerTick;
	pTimer->iDivisor = pTimer->uCyclesPerTick * 0x100;
	pTimer->iCycleSync		= 0;
	pTimer->nElapsedCycles	= 0;
}


void SNSpcTimerSync(SNSpcTimerT *pTimer, Int32 nCycles)
{
	if (pTimer->bEnabled)
	{
		// accumulate elapsed cycles while timer was running
		pTimer->nElapsedCycles += (nCycles - pTimer->iCycleSync);

		if (pTimer->nElapsedCycles >= pTimer->iDivisor)
		{
			Int32 nCount;

			// determine number of low-counter pulses generated
			nCount = pTimer->nElapsedCycles / pTimer->iDivisor;

			// decrement elapsed cycles
			pTimer->nElapsedCycles -= nCount * pTimer->iDivisor;

			// update upcounter
			pTimer->uUpCounter+=nCount;
		}
	}


	// reset cycle sync time
	pTimer->iCycleSync = nCycles;
}

void SNSpcTimerSetEnable(SNSpcTimerT *pTimer, Int32 nCycles, Bool bEnable)
{
	if (bEnable!=pTimer->bEnabled)
	{
		SNSpcTimerSync(pTimer, nCycles);
		if (bEnable) 
		{
			// reset up counter
			pTimer->uUpCounter = 0;
		}
		pTimer->bEnabled = bEnable;
	}
}

void SNSpcTimerSetTimer(SNSpcTimerT *pTimer, Uint8 uValue)
{
	pTimer->uCompare = uValue;

	if (uValue!=0)
	{
		pTimer->iDivisor = pTimer->uCyclesPerTick * pTimer->uCompare;
	} else
	{
		pTimer->iDivisor = pTimer->uCyclesPerTick * 0x100;
	}
}

Uint8 SNSpcTimerGetCounter(SNSpcTimerT *pTimer, Int32 iCycle)
{
	Uint8 uUpCounter;

	SNSpcTimerSync(pTimer, iCycle);

	// get up counter
	uUpCounter = pTimer->uUpCounter;

	// reset up counter
	pTimer->uUpCounter = 0;

	// return
	return uUpCounter & 0xF;
}









