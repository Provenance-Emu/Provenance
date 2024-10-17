

#ifndef _SNCPU_H
#define _SNCPU_H

#include "sncpudefs.h"

//#define SNCPU_TRAPFUNC __fastcall
#define SNCPU_TRAPFUNC


enum SNCpuCounterE
{
	SNCPU_COUNTER_TOTAL,
	SNCPU_COUNTER_FRAME,
	SNCPU_COUNTER_LINE,
	SNCPU_COUNTER_USER0,

	SNCPU_COUNTER_NUM
};

struct SNCpu_t;

typedef Uint8 (SNCPU_TRAPFUNC *SNCpuReadTrapFuncT)(struct SNCpu_t *pCpu, Uint32 addr);
typedef void (SNCPU_TRAPFUNC *SNCpuWriteTrapFuncT)(struct SNCpu_t *pCpu, Uint32 addr, Uint8 data);
typedef Int32 (*SNCpuExecuteFuncT)(struct SNCpu_t *pCpu);
//typedef void (*SNCpuAbortFuncT)(struct SNCpu_t *pCpu);

typedef union
{
	Uint16	w;
	struct 
	{
		Uint8 l,h;
	} b;
} SNRegU;

typedef struct 
{
	SNRegU  rA;		// accumulator
    SNRegU  rX;		// X
    SNRegU  rY;		// Y
    SNRegU  rS;		// stack pointer

	Uint8	rP;		// flags
	Uint8	rE;		// emulation bit
    Uint16  rDP;    // direct page

	Uint32  rPC;    // PC | Program Bank
    Uint32  rDB;    // data bank 
} SNCpuRegsT;


typedef struct 
{
	Uint8				*pMem;

	SNCpuReadTrapFuncT  pReadTrapFunc; 
	SNCpuWriteTrapFuncT pWriteTrapFunc; 

	Uint8				uBankCycle;			// the # of cycles required to access this bank
    Uint8               bRAM;          // read only?
	Uint8				uPad[2];
} SNCpuBankT;

typedef struct SNCpu_t
{
	SNCpuRegsT			Regs;							// processor registers

	Int32				Cycles;							// cycle counter for current execution
	Int32				Counter[SNCPU_COUNTER_NUM];		// counter(s)
	void				*pUserData;						// user data pointer

	Int32				nAbortCycles;
	Bool				bRunning;
	Uint8				uSignal;
	Uint8				uPad;

	SNCpuBankT			Bank[SNCPU_BANK_NUM];			// cpu memory banks

} SNCpuT;


void SNCPUNew(SNCpuT *pCpu);
void SNCPUDelete(SNCpuT *pCpu);

void SNCPUResetRegs(SNCpuT *pCpu);
void SNCPUResetCounters(SNCpuT *pCpu);
void SNCPUReset(SNCpuT *pCpu, Bool bHardReset);
void SNCPUNMI(SNCpuT *pCpu);
void SNCPUIRQ(SNCpuT *pCpu);

void SNCPUAbort(SNCpuT *pCpu);
void SNCPUSignalIRQ(SNCpuT *pCpu, Uint32 bEnable);
void SNCPUSignalNMI(SNCpuT *pCpu, Uint32 bEnable);
void SNCPUSignalDMA(SNCpuT *pCpu, Uint32 bEnable);

void SNCPUSetBank(SNCpuT *pCpu, Uint32 Addr, Uint32 Size, Uint8 *pMem, Bool bRAM);
void SNCPUSetTrap(SNCpuT *pCpu, Uint32 Addr, Uint32 Size, SNCpuReadTrapFuncT pReadTrap, SNCpuWriteTrapFuncT pWriteTrap);
void SNCPUSetMemSpeed(SNCpuT *pCpu, Uint32 Addr, Uint32 Size, Uint32 uCycles);
void SNCPUSetRomSpeed(SNCpuT *pCpu, Uint32 Addr, Uint32 Size, Uint32 uCycles);

Uint8  SNCPUPeek8(SNCpuT *pCpu, Uint32 Addr);
void   SNCPUPeekMem(SNCpuT *pCpu, Uint32 Addr, Uint8 *pBuffer, Uint32 nBytes);

Uint8  SNCPURead8(SNCpuT *pCpu, Uint32 Addr);
Uint16 SNCPURead16(SNCpuT *pCpu, Uint32 Addr);
Uint32 SNCPURead24(SNCpuT *pCpu, Uint32 Addr);
void   SNCPUReadMem(SNCpuT *pCpu, Uint32 Addr, Uint8 *pBuffer, Uint32 nBytes);
void   SNCPUWrite8(SNCpuT *pCpu, Uint32 Addr, Uint8 Data);
void   SNCPUWrite16(SNCpuT *pCpu, Uint32 Addr, Uint16 Data);

void SNCPUPush8(SNCpuT *pCpu, Uint8 Data);
void SNCPUPush16(SNCpuT *pCpu, Uint16 Data);
void SNCPUPush24(SNCpuT *pCpu, Uint32 Data);
Uint8 SNCPUPop8(SNCpuT *pCpu);
Uint16 SNCPUPop16(SNCpuT *pCpu);
Uint32 SNCPUPop24(SNCpuT *pCpu);

Int32 SNCPUDisassemble(SNCpuT *pCpu, Uint32 Addr, Char *pStr, Uint8 *pFlags);

void SNCPUDumpRegs(SNCpuT *pCpu, Char *pStr);

//Int32 SNCPUGetCounter(SNCpuT *pCPU, Int32 iCounter);
void SNCPUResetCounter(SNCpuT *pCPU, Int32 iCounter);
//void SNCPUConsumeCycles(SNCpuT *pCPU, Int32 nCycles);

#define SNCPUConsumeCycles(__pCpu, __nCycles) (__pCpu)->Cycles-=(__nCycles);

void SNCPUSetExecuteFunc(SNCpuExecuteFuncT pFunc);
Bool SNCPUExecute(SNCpuT *pCpu);
Bool SNCPUExecuteOne(SNCpuT *pCpu);
void SNCPUSetDebug(Bool bDebug, Int32 nDebugCycles);


static _INLINE Int32 SNCPUGetCounter(SNCpuT *pCpu, Int32 iCounter)
{
	return pCpu->Counter[iCounter] - pCpu->Cycles;
}

static _INLINE void SNCPUAddCycles(SNCpuT *pCpu, Int32 nCycles)
{
    pCpu->Cycles += nCycles;
    pCpu->Counter[0] += nCycles;
    pCpu->Counter[1] += nCycles;
    pCpu->Counter[2] += nCycles;
    pCpu->Counter[3] += nCycles;
}



#endif
