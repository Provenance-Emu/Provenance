
#ifndef _SNSPC_H
#define _SNSPC_H

#define SNSPC_TRAPFUNC
#include "snspcdefs.h"

enum SNSpcCounterE
{
	SNSPC_COUNTER_TOTAL,
	SNSPC_COUNTER_FRAME,

	SNSPC_COUNTER_NUM
};

struct SNSpc_t;

typedef Uint8 (SNSPC_TRAPFUNC *SNSpcReadTrapFuncT)(struct SNSpc_t *pSpc, Uint32 addr);
typedef void (SNSPC_TRAPFUNC *SNSpcWriteTrapFuncT)(struct SNSpc_t *pSpc, Uint32 addr, Uint8 data);
typedef Int32 (*SNSpcExecuteFuncT)(struct SNSpc_t *pCpu);

typedef struct SNSpcRegs_t
{
	Uint16		rPC;
	Uint8		rA;
	Uint8		rY;
	Uint8		rX;
	Uint8		rSP;
	Uint8		rPSW;
    Uint8       uPad;
} SNSpcRegsT;

typedef struct SNSpc_t
{
	SNSpcRegsT	Regs;

	Int32		Cycles;
	Int32		Counter[SNSPC_COUNTER_NUM];
	void		*pUserData;						// user data pointer

	SNSpcReadTrapFuncT	pReadTrapFunc;
	SNSpcWriteTrapFuncT	pWriteTrapFunc;

	Uint8		Mem[SNSPC_MEM_SIZE];
	Uint8		ShadowMem[SNSPC_ROM_SIZE];

	Bool		bRomEnable;
	Uint8		uPad; 
} SNSpcT;

void SNSPCNew(SNSpcT *pCpu);
void SNSPCDelete(SNSpcT *pCpu);

void SNSPCResetRegs(SNSpcT *pCpu);
void SNSPCReset(SNSpcT *pCpu, Bool bHardReset);

Uint8 SNSPCPeek8(SNSpcT *pCpu, Uint32 uAddr);
void SNSPCPeekMem(SNSpcT *pCpu, Uint32 Addr, Uint8 *pBuffer, Uint32 nBytes);

Uint8 SNSPCRead8(SNSpcT *pCpu, Uint32 uAddr);
Uint16 SNSPCRead16(SNSpcT *pCpu, Uint32 Addr);
void SNSPCReadMem(SNSpcT *pCpu, Uint32 Addr, Uint8 *pBuffer, Uint32 nBytes);
void SNSPCWrite8(SNSpcT *pCpu, Uint32 uAddr, Uint8 uData);
void SNSPCWrite16(SNSpcT *pCpu, Uint32 Addr, Uint16 Data);

void SNSPCSetExecuteFunc(SNSpcExecuteFuncT pFunc);
Int32 SNSPCExecute(SNSpcT *pCpu, Int32 nExecCycles);

//Int32 SNSPCGetCounter(SNSpcT *pCPU, Int32 iCounter);
void SNSPCResetCounter(SNSpcT *pCPU, Int32 iCounter);
void SNSPCResetCounters(SNSpcT *pCpu);

Uint8 SNSPCRead8Trap(SNSpcT *pSpc, Uint32 uAddr);
void SNSPCWrite8Trap(SNSpcT *pSpc, Uint32 uAddr, Uint8 uData);

void SNSPCSetTrapFunc(SNSpcT *pSpc, SNSpcReadTrapFuncT pReadTrap, SNSpcWriteTrapFuncT pWriteTrap);

void SNSPCSetRomEnable(SNSpcT *pSpc, Bool bEnable);

void SNSPCDumpRegs(SNSpcT *pCpu, Char *pStr);
void SNSPCSetDebug(Bool bDebug, Int32 nDebugCycles);

static _INLINE Int32 SNSPCGetCounter(SNSpcT *pCpu, Int32 iCounter)
{
	return pCpu->Counter[iCounter] - pCpu->Cycles;
}

Uint32 SNSPCMemChecksum(SNSpcT *pCpu);

#endif

