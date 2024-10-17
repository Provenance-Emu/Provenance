

#ifndef _SNSPCIO_H
#define _SNSPCIO_H

#include "snspctimer.h"
#include "snesreg.h"
#include "snqueue.h"

struct SNSpc_t;
class SNSpcDsp;

#define SNSPCIO_WRITEQUEUE (TRUE)

struct SNSpcIORegsT
{
	SnesReg8T		apu_r[4];		// apu read ports
	SnesReg8T		apu_w[4];		// apu write ports
	SNSpcTimerT		spc_timer[3];	// spc timers
};

class SNSpcIO
{
	SNSpc_t			*m_pSpc;
	SNSpcDsp		*m_pSpcDsp;

public:
	SNSpcIORegsT	m_Regs;

	#if SNSPCIO_WRITEQUEUE
	SNQueue			m_Queue;
	#endif

public:

	static Uint8 Read8Trap(struct SNSpc_t *pSpc, Uint32 uAddr);
	static void Write8Trap(struct SNSpc_t *pSpc, Uint32 uAddr, Uint8 uData);

	void	Reset();
	void	SetSpc(struct SNSpc_t *pSpc) {m_pSpc = pSpc;}
	void	SetSpcDsp(SNSpcDsp *pSpcDsp) {m_pSpcDsp = pSpcDsp;}

	void	SaveState(struct SNStateSPCIOT *pState);
	void	RestoreState(struct SNStateSPCIOT *pState);

	#if SNSPCIO_WRITEQUEUE
	Bool	EnqueueWrite(Uint32 uCycle, Uint32 uAddr, Uint8 uData);
	void	SyncQueue(Uint32 uCycle);
	void	SyncQueueAll();
	#endif

};


#endif
