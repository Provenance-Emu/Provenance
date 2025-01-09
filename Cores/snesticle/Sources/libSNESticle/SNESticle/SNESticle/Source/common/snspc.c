

#include <string.h>
#include <stdio.h>
#include "types.h"
#include "snspc.h"
#include "snspcrom.h"
#include "snspcdisasm.h"
#include "console.h"

#define SNSPC_SWITCHSPEED (FALSE)

static Uint8 SNSPC_TRAPFUNC _SNSPCDefaultRead(SNSpcT *pCpu, Uint32 Addr);
static void SNSPC_TRAPFUNC _SNSPCDefaultWrite(SNSpcT *pCpu, Uint32 Addr, Uint8 Data);
static Int32 _SNSPCDefaultExecuteFunc(SNSpcT *pCpu);


//
//
//

static SNSpcExecuteFuncT _SNSPC_pExecuteFunc = _SNSPCDefaultExecuteFunc;
static SNSpcExecuteFuncT _SNSPC_pDebugExecuteFunc = _SNSPCDefaultExecuteFunc;
static Bool _SNSPC_bDebug = FALSE;
static Int32 _SNSPC_nDebugCycles = 1;


static Uint8 SNSPC_TRAPFUNC _SNSPCDefaultRead(SNSpcT *pCpu, Uint32 Addr)
{
	return 0xFF;
}

static void SNSPC_TRAPFUNC _SNSPCDefaultWrite(SNSpcT *pCpu, Uint32 Addr, Uint8 Data)
{
}


static Int32 _SNSPCDefaultExecuteFunc(SNSpcT *pCpu)
{
	pCpu->Cycles = 0;
	return 0;
}


void SNSPCResetCounters(SNSpcT *pCpu)
{
	Int32 iCounter;

	// reset all counters
	pCpu->Cycles = 0;

	for (iCounter=0; iCounter < SNSPC_COUNTER_NUM; iCounter++)
	{
		pCpu->Counter[iCounter] = 0;
	}
}

void SNSPCSetSpeed(SNSpcT *pCpu, Uint32 uCycleShift)
{
#if SNSPC_SWITCHSPEED
#if CODE_DEBUG
	if (uCycleShift != pCpu->uCycleShift)
	{
		ConDebug("SPCSpeed %s\n", uCycleShift ? "fast" : "slow");
	}
#endif
	// adjust cycles
	pCpu->Cycles     >>= pCpu->uCycleShift;

	// set cycle shift
	pCpu->uCycleShift = uCycleShift;

	// readjust cycles
	pCpu->Cycles <<= pCpu->uCycleShift;
#endif
}

void SNSPCNew(SNSpcT *pCpu)
{
	pCpu->pReadTrapFunc  = _SNSPCDefaultRead;
	pCpu->pWriteTrapFunc = _SNSPCDefaultWrite;
	pCpu->pUserData  = NULL;
	pCpu->bRomEnable = FALSE;

	SNSPCReset(pCpu, TRUE);
}

void SNSPCDelete(SNSpcT *pCpu)
{
}

void SNSPCResetRegs(SNSpcT *pCpu)
{
	pCpu->Regs.rA   = 0;
	pCpu->Regs.rX   = 0;
	pCpu->Regs.rY   = 0;
	pCpu->Regs.rSP  = 0;
	pCpu->Regs.rPC  = 0;
	pCpu->Regs.rPSW = 0;
}

void SNSPCSetRomEnable(SNSpcT *pCpu, Bool bEnable)
{
	if (bEnable != pCpu->bRomEnable)
	{
		if (bEnable)
		{
			// copy ram data to shadow memory
			memcpy(pCpu->ShadowMem, pCpu->Mem + SNSPC_ROM_ADDR, SNSPC_ROM_SIZE);

			// copy rom data to FFC0
			memcpy(pCpu->Mem + SNSPC_ROM_ADDR, SNSpcRomGetRomData(), SNSPC_ROM_SIZE);

		} else
		{
			// copy ram data from shadow memory
			memcpy(pCpu->Mem + SNSPC_ROM_ADDR, pCpu->ShadowMem, SNSPC_ROM_SIZE);
		}

		pCpu->bRomEnable = bEnable;
	}

}

void SNSPCReset(SNSpcT *pCpu, Bool bHardReset)
{
	if (bHardReset)
	{
		SNSPCResetRegs(pCpu);
		SNSPCResetCounters(pCpu);

		pCpu->bRomEnable = FALSE;
		
		// clear spc Mem
		memset(pCpu->Mem, 0, SNSPC_MEM_SIZE);

		// copy rom data
		SNSPCSetRomEnable(pCpu, TRUE);
	}

	// reset flags
	pCpu->Regs.rPSW = 0;

	// setup PC on reset?
	pCpu->Regs.rPC = SNSPCRead16(pCpu, SNSPC_VECTOR_RESET);
}

Uint8 SNSPCPeek8(SNSpcT *pCpu, Uint32 uAddr)
{
	return pCpu->Mem[uAddr];
}


void SNSPCPeekMem(SNSpcT *pCpu, Uint32 Addr, Uint8 *pBuffer, Uint32 nBytes)
{
	while (nBytes > 0)
	{
		// read byte into buffer
		*pBuffer = SNSPCPeek8(pCpu, Addr);

		Addr++;
		pBuffer++;
		nBytes--;
	}
}


Uint8 SNSPCRead8(SNSpcT *pCpu, Uint32 uAddr)
{
	if (uAddr >= 0xF0 && uAddr < 0x100)
	{
		return pCpu->pReadTrapFunc(pCpu, uAddr);
	} else
	{
		return pCpu->Mem[uAddr];
	}
}


Uint16 SNSPCRead16(SNSpcT *pCpu, Uint32 Addr)
{
	Uint32 uData;
	uData =  SNSPCRead8(pCpu, Addr);
	uData|= (SNSPCRead8(pCpu, Addr+1)<<8);
	return  uData;
}

void SNSPCReadMem(SNSpcT *pCpu, Uint32 Addr, Uint8 *pBuffer, Uint32 nBytes)
{
	while (nBytes > 0)
	{
		// read byte into buffer
		*pBuffer = SNSPCRead8(pCpu, Addr);

		Addr++;
		pBuffer++;
		nBytes--;
	}
}

void SNSPCSetTrapFunc(SNSpcT *pSpc, SNSpcReadTrapFuncT pReadTrap, SNSpcWriteTrapFuncT pWriteTrap)
{
	pSpc->pReadTrapFunc = pReadTrap;
	pSpc->pWriteTrapFunc = pWriteTrap;
}

void SNSPCWrite8(SNSpcT *pCpu, Uint32 uAddr, Uint8 uData)
{
	// don't write to rom area
	if (uAddr < SNSPC_ROM_ADDR || !pCpu->bRomEnable)
	{
		pCpu->Mem[uAddr] = uData;
	}  else
	{
		pCpu->ShadowMem[uAddr & (SNSPC_ROM_SIZE -1)] = uData;
	}


	if (uAddr >= 0xF0 && uAddr < 0x100)
	{
		pCpu->pWriteTrapFunc(pCpu, uAddr, uData);
	}
}

void SNSPCWrite16(SNSpcT *pCpu, Uint32 Addr, Uint16 Data)
{
	SNSPCWrite8(pCpu, Addr + 0, Data >> 0);
	SNSPCWrite8(pCpu, Addr + 1, Data >> 8);
}


void SNSPCSetExecuteFunc(SNSpcExecuteFuncT pFunc)
{
	if (_SNSPC_bDebug)
	{
		_SNSPC_pDebugExecuteFunc = pFunc;
	} else
	{
		_SNSPC_pExecuteFunc = pFunc;
	}
}



Int32 SNSPCExecute(SNSpcT *pCpu, Int32 nExecCycles)
{
	// increment cycle counter
	pCpu->Cycles += nExecCycles;
	pCpu->Counter[0] += nExecCycles;
	pCpu->Counter[1] += nExecCycles;

	_SNSPC_pExecuteFunc(pCpu);

	return nExecCycles - pCpu->Cycles;
}


void SNSPCResetCounter(SNSpcT *pCpu, Int32 iCounter)
{
	pCpu->Counter[iCounter] = 0;
}

#if 0
Int32 SNSPCGetCounter(SNSpcT *pCpu, Int32 iCounter)
{
	return pCpu->Counter[iCounter] - pCpu->Cycles;
}
#endif



void SNSPCDumpRegs(SNSpcT *pCpu, Char *pStr)
{
	Uint8 rF = pCpu->Regs.rPSW;

	sprintf(pStr, "A:%04X X:%04X Y:%04X SP:%04X PC:%06X %c%c%c%c%c%c%c%c",
		pCpu->Regs.rA,
		pCpu->Regs.rX,
		pCpu->Regs.rY,
		pCpu->Regs.rSP,
		pCpu->Regs.rPC,
		(rF & SNSPC_FLAG_N) ? 'N' : 'n',
		(rF & SNSPC_FLAG_V) ? 'V' : 'v',
		(rF & SNSPC_FLAG_P) ? 'P' : 'p',
		(rF & SNSPC_FLAG_B) ? 'B' : 'b',
		(rF & SNSPC_FLAG_H) ? 'H' : 'h',
		(rF & SNSPC_FLAG_I) ? 'I' : 'i',
		(rF & SNSPC_FLAG_Z) ? 'Z' : 'z',
		(rF & SNSPC_FLAG_C) ? 'C' : 'c'
		);

}


Int32 SNSPCExecuteDebug(SNSpcT *pCpu)
{
	Int32 nTotalCycles,nExecCycles;
	nTotalCycles = pCpu->Cycles;
	while (nTotalCycles > 0)
	{
		Char str[64];
  
  		SNSPCDisasm(str, pCpu->Mem + pCpu->Regs.rPC, pCpu->Regs.rPC);
		ConDebug("%06X: %s\n", pCpu->Regs.rPC, str);

		nExecCycles=_SNSPC_nDebugCycles;
		if (nExecCycles > nTotalCycles) nExecCycles = nTotalCycles;

		pCpu->Cycles = nExecCycles;
		_SNSPC_pDebugExecuteFunc(pCpu);
		nExecCycles = nExecCycles - pCpu->Cycles;

		// no instructions were executed
		if (nExecCycles <= 0 ) break;

		nTotalCycles -= nExecCycles;

//		SNSPCDumpRegs(pCpu, str);
//		ConDebug("%s %d\n", str, SNSPCGetCounter(pCpu, SNSPC_COUNTER_FRAME));
	}
	return 0;
}


void SNSPCSetDebug(Bool bDebug, Int32 nDebugCycles)
{
	if (_SNSPC_bDebug!=bDebug)
	{
		if (bDebug)
		{
			_SNSPC_pDebugExecuteFunc = _SNSPC_pExecuteFunc;
			_SNSPC_pExecuteFunc = SNSPCExecuteDebug;
		} else
		{
			_SNSPC_pExecuteFunc = _SNSPC_pDebugExecuteFunc;
		}

		_SNSPC_bDebug=bDebug;
	}

	_SNSPC_nDebugCycles = nDebugCycles;
}


Uint32 SNSPCMemChecksum(SNSpcT *pCpu)
{
	Uint32 uCheckSum = 0;
	Uint32 uAddr;

	for (uAddr=0; uAddr < sizeof(pCpu->Mem); uAddr++)
	{
		uCheckSum += (Uint32 )pCpu->Mem[uAddr];
	}
	return uCheckSum;
}
