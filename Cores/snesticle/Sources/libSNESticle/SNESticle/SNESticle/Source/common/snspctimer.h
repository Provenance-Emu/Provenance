

#ifndef _SNSPCTIMER_H
#define _SNSPCTIMER_H


typedef struct SNSpcTimer_t
{
	Int32	iCycleSync;

	Int32	nElapsedCycles;		// # of elapsed cycles since timer was started
	Int32	iDivisor;			// UpCounter = nElapsedCycles / Divisor

	Uint32	uCyclesPerTick;		// clock cycles per tick (low-counter)
	Uint8	uCompare;			// low-counter compare
	Uint8	uUpCounter;			// 4-bit hi-counter value
	Bool	bEnabled;	
} SNSpcTimerT;

void SNSpcTimerReset(SNSpcTimerT *pTimer, Uint32 uCyclesPerTick);
void SNSpcTimerSetEnable(SNSpcTimerT *pTimer, Int32 nCycles, Bool bEnable);
void SNSpcTimerSetTimer(SNSpcTimerT *pTimer, Uint8 uValue);
void SNSpcTimerSync(SNSpcTimerT *pTimer, Int32 nCycles);
Uint8 SNSpcTimerGetCounter(SNSpcTimerT *pTimer, Int32 nCycles);

#endif
