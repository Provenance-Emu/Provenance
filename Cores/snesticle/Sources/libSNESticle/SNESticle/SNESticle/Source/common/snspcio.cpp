

#include <stdlib.h>
#include <string.h>
#include "types.h"
#include "console.h"
#include "snspcio.h"
#include "sntiming.h"
extern "C" {
#include "snspc.h"
};
#include "snspcdsp.h"

#define SNES_DEBUGSPCIO (CODE_DEBUG && FALSE)

#if SNES_DEBUGSPCIO
Uint32  _SpcOp;
Uint32 _SpcAddr;
Uint32 _SpcData;

static void _SpcDebugRead(SNSpcT *pSpc, Uint32 uAddr, Uint32 uData)
{
	if (_SpcOp || _SpcAddr!=uAddr || _SpcData!=uData)
	{
		//ConDebug("%08d: spc read  %04X %02X\n", SNSPCGetCounter(pSpc, SNSPC_COUNTER_TOTAL, 0), uAddr, uData);
		_SpcOp = 0;
		_SpcAddr = uAddr;
		_SpcData = uData;
	}
}

static void _SpcDebugWrite(SNSpcT *pSpc, Uint32 uAddr, Uint32 uData)
{
	if (!_SpcOp || _SpcAddr!=uAddr || _SpcData!=uData)
	{
		ConDebug("%08d: spc write %04X %02X %02X %02X %02X %02X %08X\n", 
			SNSPCGetCounter(pSpc, SNSPC_COUNTER_TOTAL, 0), 
			uAddr, uData,
			pSpc->Regs.rA,
			pSpc->Regs.rX,
			pSpc->Regs.rY,
			pSpc->Regs.rSP,
			SNSPCMemChecksum(pSpc)
			);
		_SpcOp = 1;
		_SpcAddr = uAddr;
		_SpcData = uData;
	}
}
#endif

Bool SNSpcIO::EnqueueWrite(Uint32 uCycle, Uint32 uAddr, Uint8 uData)
{
	return m_Queue.Enqueue(uCycle, uAddr, uData);
}

void SNSpcIO::SyncQueueAll()
{
	SNQueueElementT *pElement;

	// dequeue all pending writes
	while ( (pElement=m_Queue.Dequeue()) != NULL)
	{
		// perform write
		m_Regs.apu_w[pElement->uAddr] = pElement->uData;
	}

	// empty queue
	m_Queue.Reset();
}

inline void SNSpcIO::SyncQueue(Uint32 uCycle)
{
	SNQueueElementT *pElement;

	// dequeue all pending writes  up to cycle time
	while ( (pElement=m_Queue.Dequeue(uCycle)) != NULL)
	{
		// perform write
		m_Regs.apu_w[pElement->uAddr] = pElement->uData;
	}
}


void SNSpcIO::Reset()
{
	memset(&m_Regs, 0, sizeof(m_Regs));

	m_Queue.Reset();

	SNSpcTimerReset(&m_Regs.spc_timer[0], 128 * SNSPC_CYCLE); //SNES_MASTERCLOCKRATE / 8000);
	SNSpcTimerReset(&m_Regs.spc_timer[1], 128 * SNSPC_CYCLE); //SNES_MASTERCLOCKRATE / 8000);
	SNSpcTimerReset(&m_Regs.spc_timer[2], 16  * SNSPC_CYCLE); //SNES_MASTERCLOCKRATE / 64000);
}



#if SNES_STATEDEBUG
extern "C" Bool g_bStateDebug;
#endif

Uint8 SNSpcIO::Read8Trap(SNSpcT *pSpc, Uint32 uAddr)
{
	SNSpcIO *pIO = (SNSpcIO *)pSpc->pUserData;

#if SNES_STATEDEBUG
	if (g_bStateDebug)
		ConDebug("read_spc[%04X] %d %d %04X\n", uAddr, pSpc->Cycles, pIO->m_Regs.spc_timer[0].nElapsedCycles, pSpc->Regs.rPC);
#endif
	switch (uAddr)
	{
	case 0xF2:
		return pSpc->Mem[uAddr];

	case 0xF3:
		pIO->m_pSpcDsp->Sync();
		return pIO->m_pSpcDsp->Read8(pSpc->Mem[0xF2]);
	case 0xF4: // port 0-4
	case 0xF5:
	case 0xF6:
	case 0xF7:
		#if SNES_DEBUGSPCIO
	//	_SpcDebugRead(pSpc, uAddr, pIO->m_Regs.apu_w[uAddr & 3]);
		#endif

		#if SNSPCIO_WRITEQUEUE
		pIO->SyncQueue(SNSPCGetCounter(pSpc, SNSPC_COUNTER_FRAME));
		#endif

		return pIO->m_Regs.apu_w[uAddr & 3];

	case 0xFD:	// counter0
		return SNSpcTimerGetCounter(&pIO->m_Regs.spc_timer[0], SNSPCGetCounter(pSpc, SNSPC_COUNTER_TOTAL));
	case 0xFE:	// counter1
		return SNSpcTimerGetCounter(&pIO->m_Regs.spc_timer[1], SNSPCGetCounter(pSpc, SNSPC_COUNTER_TOTAL));
	case 0xFF:	// counter2
		return SNSpcTimerGetCounter(&pIO->m_Regs.spc_timer[2], SNSPCGetCounter(pSpc, SNSPC_COUNTER_TOTAL));
	default:
#if SNES_DEBUGPRINT
		ConDebug("read_spc[%04X]\n", uAddr);
#endif
		return 	pSpc->Mem[uAddr];
	}
}


void SNSpcIO::Write8Trap(SNSpcT *pSpc, Uint32 uAddr, Uint8 uData)
{
	SNSpcIO *pIO = (SNSpcIO *)pSpc->pUserData;
	Int32 iCycle;

	iCycle = SNSPCGetCounter(pSpc, SNSPC_COUNTER_TOTAL);

#if SNES_STATEDEBUG
	if (g_bStateDebug)
		ConDebug("write_spc[%04X]=%02X %d %d %04X\n", uAddr, uData, pSpc->Cycles, pIO->m_Regs.spc_timer[0].nElapsedCycles, pSpc->Regs.rPC);
#endif
	switch (uAddr)
	{
	case 0xF1:	// control
		{
			if (uData&0x10)
			{
				pSpc->Mem[0xf4] = pIO->m_Regs.apu_w[0] = 0x00;
				pSpc->Mem[0xf5] = pIO->m_Regs.apu_w[1] = 0x00;
			}
			if (uData&0x20)
			{
				pSpc->Mem[0xf6] = pIO->m_Regs.apu_w[2] = 0x00;
				pSpc->Mem[0xf7] = pIO->m_Regs.apu_w[3] = 0x00;
			}		
			SNSpcTimerSetEnable(&pIO->m_Regs.spc_timer[0], iCycle, (uData & 1));
			SNSpcTimerSetEnable(&pIO->m_Regs.spc_timer[1], iCycle, (uData & 2));
			SNSpcTimerSetEnable(&pIO->m_Regs.spc_timer[2], iCycle, (uData & 4));

			// set rom enable
			SNSPCSetRomEnable(pSpc, uData & 0x80);
		}
		break;
	case 0xF2:	// dsp addr
		break;
	case 0xF3:  // dsp data
		while (!pIO->m_pSpcDsp->EnqueueWrite(SNSPCGetCounter(pSpc, SNSPC_COUNTER_FRAME), pSpc->Mem[0xF2] & 0x7F, uData))
		{
			pIO->m_pSpcDsp->Sync();
		}
		//pIO->m_pSpcDsp->Write8(pSpc->Mem[0xF2] & 0x7F, uData);
		break;

	case 0xF4:
	case 0xF5:
	case 0xF6:
	case 0xF7:
		pIO->m_Regs.apu_r[uAddr & 3] = uData;
		#if SNES_DEBUGSPCIO
		_SpcDebugWrite(pSpc, uAddr, uData);
		#endif
		break;

	case 0xFA:	// timer0
		SNSpcTimerSync(&pIO->m_Regs.spc_timer[0], iCycle);
		SNSpcTimerSetTimer(&pIO->m_Regs.spc_timer[0], uData);
		break;
	case 0xFB:	// timer1
		SNSpcTimerSync(&pIO->m_Regs.spc_timer[1], iCycle);
		SNSpcTimerSetTimer(&pIO->m_Regs.spc_timer[1], uData);
		break;
	case 0xFC:	// timer2
		SNSpcTimerSync(&pIO->m_Regs.spc_timer[2], iCycle);
		SNSpcTimerSetTimer(&pIO->m_Regs.spc_timer[2], uData);
		break;

	default:
#if SNES_DEBUGPRINT
		ConDebug("write_spc[%04X]=%02X\n", uAddr, uData);
#endif
		break;
	}

	// store to memory
	pSpc->Mem[uAddr] = uData;
}


