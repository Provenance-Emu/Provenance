
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "types.h"
#include "sndisasm.h"
#include "sncpu.h"
#include "console.h"
#include "sndebug.h"


#define SNCPU_FASTREADMEM TRUE

//
//
//

static Int32 _SNCPUDefaultExecuteFunc(SNCpuT *pCpu);
static Uint8 SNCPU_TRAPFUNC _SNCPUDefaultRead(SNCpuT *pCpu, Uint32 Addr);
static void SNCPU_TRAPFUNC _SNCPUDefaultWrite(SNCpuT *pCpu, Uint32 Addr, Uint8 Data);


//
//
//

static SNCpuExecuteFuncT _SNCPU_pExecuteFunc = _SNCPUDefaultExecuteFunc;
static SNCpuExecuteFuncT _SNCPU_pDebugExecuteFunc = _SNCPUDefaultExecuteFunc;
static Bool _SNCPU_bDebug = FALSE;
static Int32 _SNCPU_nDebugCycles = 1;


//
//
//

static Uint8 SNCPU_TRAPFUNC _SNCPUDefaultRead(SNCpuT *pCpu, Uint32 Addr)
{
	return 0xFF;
}

static void SNCPU_TRAPFUNC _SNCPUDefaultWrite(SNCpuT *pCpu, Uint32 Addr, Uint8 Data)
{
}

static Int32 _SNCPUDefaultExecuteFunc(SNCpuT *pCpu)
{
	pCpu->Cycles = 0;
	return 0;
}

//
//


void SNCPUNew(SNCpuT *pCpu)
{
	memset(pCpu, 0, sizeof(*pCpu));

	pCpu->pUserData = NULL;

	SNCPUSetBank(pCpu, 0, SNCPU_MEM_SIZE, NULL, FALSE);
	SNCPUSetTrap(pCpu, 0, SNCPU_MEM_SIZE, NULL, NULL);
	SNCPUSetMemSpeed(pCpu, 0, SNCPU_MEM_SIZE, SNCPU_CYCLE_SLOW);

	SNCPUResetRegs(pCpu);
	SNCPUResetCounters(pCpu);
}

void SNCPUResetCounters(SNCpuT *pCpu)
{
	Int32 iCounter;
	// reset all counters
	pCpu->Cycles = 0;
	pCpu->nAbortCycles = 0;
	for (iCounter=0; iCounter < SNCPU_COUNTER_NUM; iCounter++)
	{
		pCpu->Counter[iCounter] = 0;
	}
}


void SNCPUReset(SNCpuT *pCpu, Bool bHardReset)
{
	if (bHardReset)
	{
		SNCPUResetCounters(pCpu);
		SNCPUResetRegs(pCpu);
	}

	// no IRQ
	pCpu->uSignal = 0;

	// set cpu flags to default state
	pCpu->Regs.rP  = SNCPU_FLAG_M | SNCPU_FLAG_X |  SNCPU_FLAG_I;
	// set emulation bit
	pCpu->Regs.rE  = 1;
	// reset pc
	pCpu->Regs.rPC = SNCPURead16(pCpu, SNCPU_VECTOR_RESET);
	// reset stack
	pCpu->Regs.rS.b.h = 0x01;
}

void SNCPUDelete(SNCpuT *pCpu)
{
}

void SNCPUResetRegs(SNCpuT *pCpu)
{
	// reset registers
	pCpu->Regs.rA.w = 0;
	pCpu->Regs.rX.w = 0;
	pCpu->Regs.rY.w = 0;
	pCpu->Regs.rS.w = 0;
	pCpu->Regs.rP   = SNCPU_FLAG_I;
	
	pCpu->Regs.rPC = 0;
	pCpu->Regs.rDP = 0;
	pCpu->Regs.rDB = 0;
}


void SNCPUSetBank(SNCpuT *pCpu, Uint32 Addr, Uint32 Size, Uint8 *pMem, Bool bRAM)
{
	Int32 iBank, nBanks;

	assert(!(Size & SNCPU_BANK_MASK));
	assert(!(Addr & SNCPU_BANK_MASK));

	iBank  = Addr >> SNCPU_BANK_SHIFT;
	nBanks = Size >> SNCPU_BANK_SHIFT;
    
    if (pMem==NULL) 
    {
        bRAM = FALSE;
    }        

	while ((nBanks > 0) && (iBank < SNCPU_BANK_NUM))
	{
		// set bank pointer
		pCpu->Bank[iBank].pMem = pMem  ? (pMem  - Addr) : NULL;
		pCpu->Bank[iBank].bRAM = bRAM ? 0xFF : 0;

		// next bank
		iBank++;
		nBanks--;
	}
}

void SNCPUSetTrap(SNCpuT *pCpu, Uint32 Addr, Uint32 Size, SNCpuReadTrapFuncT pReadTrap, SNCpuWriteTrapFuncT pWriteTrap)
{
	Int32 iBank, nBanks;

	assert(!(Size & SNCPU_BANK_MASK));
	assert(!(Addr & SNCPU_BANK_MASK));
	
	iBank  = Addr >> SNCPU_BANK_SHIFT;
	nBanks = Size >> SNCPU_BANK_SHIFT;

	if (pReadTrap==NULL) pReadTrap = _SNCPUDefaultRead;
	if (pWriteTrap==NULL) pWriteTrap = _SNCPUDefaultWrite;

	while ((nBanks > 0) && (iBank < SNCPU_BANK_NUM))
	{
		// set bank pointer
		pCpu->Bank[iBank].pReadTrapFunc  = pReadTrap;
		pCpu->Bank[iBank].pWriteTrapFunc = pWriteTrap;
		pCpu->Bank[iBank].pMem = NULL;
		pCpu->Bank[iBank].bRAM =  0;
        
		// next bank
		iBank++;
		nBanks--;
	}
}

void SNCPUSetMemSpeed(SNCpuT *pCpu, Uint32 Addr, Uint32 Size, Uint32 uCycles)
{
	Int32 iBank, nBanks;

	assert(!(Size & SNCPU_BANK_MASK));
	assert(!(Addr & SNCPU_BANK_MASK));

	iBank  = Addr >> SNCPU_BANK_SHIFT;
	nBanks = Size >> SNCPU_BANK_SHIFT;

	while ((nBanks > 0) && (iBank < SNCPU_BANK_NUM))
	{
		// set cycle count
		pCpu->Bank[iBank].uBankCycle = uCycles;

		// next bank
		iBank++;
		nBanks--;
	}
}

void SNCPUSetRomSpeed(SNCpuT *pCpu, Uint32 Addr, Uint32 Size, Uint32 uCycles)
{
	Int32 iBank, nBanks;

	assert(!(Size & SNCPU_BANK_MASK));
	assert(!(Addr & SNCPU_BANK_MASK));

	iBank  = Addr >> SNCPU_BANK_SHIFT;
	nBanks = Size >> SNCPU_BANK_SHIFT;

	while ((nBanks > 0) && (iBank < SNCPU_BANK_NUM))
	{
		SNCpuBankT *pBank = &pCpu->Bank[iBank];

		// is this a rom bank?
		if (pBank->pMem!=NULL && !pBank->bRAM)
		{
			// set cycle count
			pBank->uBankCycle = uCycles;
		}

		// next bank
		iBank++;
		nBanks--;
	}
}


Uint8 SNCPUPeek8(SNCpuT *pCpu, Uint32 Addr)
{
	Uint32 iBank;
	Uint8 *pBankMem;

	iBank = Addr >> SNCPU_BANK_SHIFT;
	pBankMem = pCpu->Bank[iBank].pMem;

	if (pBankMem)
	{
		return pBankMem[Addr];
	}
	else
	{
		return 0xFF;
	}
}


void SNCPUPeekMem(SNCpuT *pCpu, Uint32 Addr, Uint8 *pBuffer, Uint32 nBytes)
{
	while (nBytes > 0)
	{
		// read byte into buffer
		*pBuffer = SNCPUPeek8(pCpu, Addr);

		Addr++;
		pBuffer++;
		nBytes--;
	}
}


//Uint32 uBankRead[256 * 8];
//Uint32 uBankWrite[256 * 8];
//Uint32 uLastAddr[128];

Uint8 SNCPURead8(SNCpuT *pCpu, Uint32 Addr)
{
	Uint32 iBank;
	Uint8 *pBankMem;

	iBank = Addr >> SNCPU_BANK_SHIFT;
	pBankMem = pCpu->Bank[iBank].pMem;

//	uBankRead[iBank]++;
/*
	for (i=127; i >=1; i--)
		uLastAddr[i] = uLastAddr[i-1];
	uLastAddr[0] = Addr;*/
	if (pBankMem)
	{
		
//		char str[64];
//		sprintf(str,"read[%04X]=%02X\n", Addr, pBankMem[Addr]);
//		OutputDebugStr(str);
		return pBankMem[Addr];
	}
	else
	{
//		ConDebug("readtrap[%04X]", Addr);
		//call trap function
		return pCpu->Bank[iBank].pReadTrapFunc(pCpu, Addr);

//		return 0xFF;
	}
}

Uint16 SNCPURead16(SNCpuT *pCpu, Uint32 Addr)
{
	Uint32 uData;
	uData =  SNCPURead8(pCpu, Addr);
	uData|= (SNCPURead8(pCpu, Addr+1)<<8);
	return  uData;
}

Uint32 SNCPURead24(SNCpuT *pCpu, Uint32 Addr)
{
	Uint32 uData;
	uData = (SNCPURead8(pCpu, Addr+0) << 0);
	uData|= (SNCPURead8(pCpu, Addr+1) << 8);
	uData|= (SNCPURead8(pCpu, Addr+2) << 16);
	return  uData;
}


#if !SNCPU_FASTREADMEM

void SNCPUReadMem(SNCpuT *pCpu, Uint32 Addr, Uint8 *pBuffer, Uint32 nBytes)
{
	while (nBytes > 0)
	{
		// read byte into buffer
		*pBuffer = SNCPURead8(pCpu, Addr);

		Addr++;
		pBuffer++;
		nBytes--;
	}
}

#else

void SNCPUReadMem(SNCpuT *pCpu, Uint32 uAddr, Uint8 *pBuffer, Uint32 nTotalBytes)
{
	while (nTotalBytes > 0)
	{
		Uint32 nBankBytes, nBytes;
		Uint32 iBank;
		Uint8 *pBankMem;

		nBytes = nTotalBytes;

		// calculate number of bytes to end of bank
		nBankBytes = SNCPU_BANK_SIZE - (uAddr & (SNCPU_BANK_SIZE-1));

		// clamp size to bank size
		if (nBytes > nBankBytes) nBytes = nBankBytes;

		// resolve bank
		iBank = uAddr >> SNCPU_BANK_SHIFT;
		pBankMem = pCpu->Bank[iBank].pMem;

		if (pBankMem)
		{
			// copy data directly from bank memory
			memcpy(pBuffer, pBankMem + uAddr, nBytes);

			pBuffer += nBytes;
			nTotalBytes -= nBytes;
			uAddr += nBytes;
		} else
		{
			// trapped memory space
			while (nBytes > 0)
			{
				// call trap function
				*pBuffer = pCpu->Bank[iBank].pReadTrapFunc(pCpu, uAddr);

				pBuffer++;
				nBytes--;
				nTotalBytes--;
				uAddr++;
			}
		}
	}
}
#endif
















void  SNCPUWrite8(SNCpuT *pCpu, Uint32 Addr, Uint8 Data)
{
	Uint32 iBank;
	Uint8 *pBankMem;

	iBank = Addr >> SNCPU_BANK_SHIFT;

//	uBankWrite[iBank]++;

	if (pCpu->Bank[iBank].bRAM)
	{
    	pBankMem = pCpu->Bank[iBank].pMem;
		// write directly to memory
		pBankMem[Addr] = Data;
	}
	else
	{
		//call trap function
		pCpu->Bank[iBank].pWriteTrapFunc(pCpu, Addr, Data);
	}
}

void  SNCPUWrite16(SNCpuT *pCpu, Uint32 Addr, Uint16 Data)
{
	SNCPUWrite8(pCpu, Addr + 0, Data >> 0);
	SNCPUWrite8(pCpu, Addr + 1, Data >> 8);
}


void SNCPUPush8(SNCpuT *pCpu, Uint8 Data)
{
	SNCPUWrite8(pCpu, pCpu->Regs.rS.w, Data);
	if (pCpu->Regs.rE)
	{
		// decrement 8-bit S
		pCpu->Regs.rS.b.l--;
	} else
	{
		// decrement 16-bit S
		pCpu->Regs.rS.w--;
	}
}

void SNCPUPush16(SNCpuT *pCpu, Uint16 Data)
{
	SNCPUPush8(pCpu, Data >> 8);
	SNCPUPush8(pCpu, Data & 0xFF);
}

void SNCPUPush24(SNCpuT *pCpu, Uint32 Data)
{
	SNCPUPush8(pCpu, Data >> 16);
	SNCPUPush8(pCpu, Data >> 8);
	SNCPUPush8(pCpu, Data & 0xFF);
}

Uint8 SNCPUPop8(SNCpuT *pCpu)
{
	if (pCpu->Regs.rE)
	{
		// inc 8-bit S
		pCpu->Regs.rS.b.l++;
	} else
	{
		// inc 16-bit S
		pCpu->Regs.rS.w++;
	}
	return SNCPURead8(pCpu, pCpu->Regs.rS.w);
}

Uint16 SNCPUPop16(SNCpuT *pCpu)
{
	Uint32 uData;
	uData =  SNCPUPop8(pCpu);
	uData|= (SNCPUPop8(pCpu)<<8);
	return uData;
}


Uint32 SNCPUPop24(SNCpuT *pCpu)
{
	Uint32 uData;
	uData =  SNCPUPop8(pCpu);
	uData|= (SNCPUPop8(pCpu)<<8);
	uData|= (SNCPUPop8(pCpu)<<16);
	return uData;
}

void SNCPUNMI(SNCpuT *pCpu)
{
  
#if SNES_DEBUG
    if (Snes_bDebugIO)
        SnesDebug("-NMI\n");
#endif

	// are we stopped at a WAI instruction?
	if (pCpu->uSignal & SNCPU_SIGNAL_WAI)
	{
		// skip it
		pCpu->Regs.rPC++;
		pCpu->uSignal &= ~SNCPU_SIGNAL_WAI;
	}

	if (pCpu->Regs.rE)
	{
		// emulation
		SNCPUPush8(pCpu, (Uint8)(pCpu->Regs.rPC >> 8));
		SNCPUPush8(pCpu, (Uint8)(pCpu->Regs.rPC >> 0));
		SNCPUPush8(pCpu, pCpu->Regs.rP & (~SNCPU_FLAG_B));

		pCpu->Regs.rPC = SNCPURead16(pCpu, SNCPU_VECTORE_NMI);
	} else
	{
		// native
		SNCPUPush8(pCpu, (Uint8)(pCpu->Regs.rPC >> 16));
		SNCPUPush8(pCpu, (Uint8)(pCpu->Regs.rPC >> 8));
		SNCPUPush8(pCpu, (Uint8)(pCpu->Regs.rPC >> 0));
		SNCPUPush8(pCpu, pCpu->Regs.rP);
	
		pCpu->Regs.rPC = SNCPURead16(pCpu, SNCPU_VECTOR_NMI);
	}

	pCpu->Regs.rP &= ~(SNCPU_FLAG_D);

	SNCPUConsumeCycles(pCpu, SNCPU_CYCLE_SLOW * 6 + SNCPU_CYCLE_FAST * 2);
}


void SNCPUIRQ(SNCpuT *pCpu)
{
	if (!(pCpu->Regs.rP & SNCPU_FLAG_I))
	{
#if SNES_DEBUG
        if (Snes_bDebugIO)
            SnesDebug("-IRQ\n");
#endif

        
        // are we stopped at a WAI instruction?
		if (pCpu->uSignal & SNCPU_SIGNAL_WAI)
		{
			// skip it
			pCpu->Regs.rPC++;
			pCpu->uSignal &= ~SNCPU_SIGNAL_WAI;
		}

		if (pCpu->Regs.rE)
		{
			// emulation
			SNCPUPush8(pCpu, (Uint8)(pCpu->Regs.rPC >> 8));
			SNCPUPush8(pCpu, (Uint8)(pCpu->Regs.rPC >> 0));
			SNCPUPush8(pCpu, pCpu->Regs.rP & (~SNCPU_FLAG_B));

			pCpu->Regs.rPC = SNCPURead16(pCpu, SNCPU_VECTORE_IRQ);
		} else
		{
			// native
			SNCPUPush8(pCpu, (Uint8)(pCpu->Regs.rPC >> 16));
			SNCPUPush8(pCpu, (Uint8)(pCpu->Regs.rPC >> 8));
			SNCPUPush8(pCpu, (Uint8)(pCpu->Regs.rPC >> 0));
			SNCPUPush8(pCpu, pCpu->Regs.rP);

			pCpu->Regs.rPC = SNCPURead16(pCpu, SNCPU_VECTOR_IRQ);
		}

		pCpu->Regs.rP &= ~(SNCPU_FLAG_D);
		pCpu->Regs.rP |= SNCPU_FLAG_I;

		SNCPUConsumeCycles(pCpu, SNCPU_CYCLE_SLOW * 6 + SNCPU_CYCLE_FAST * 2);
	}
}

//
//
//

Int32 SNCPUDisassemble(SNCpuT *pCpu, Uint32 Addr, Char *pStr, Uint8 *pFlags)
{
	Uint8 Opcode[4];
    Uint8 uFlags;
    
    if (!pFlags)
    {
        uFlags = pCpu->Regs.rP;
        pFlags = &uFlags;
    }

	// read memory
	SNCPUReadMem(pCpu, Addr, Opcode, sizeof(Opcode));

	// disassemble
	return SNDisasm(pStr, Opcode, Addr, pFlags);
}


void SNCPUDumpRegs(SNCpuT *pCpu, Char *pStr)
{
	Uint8 rF = pCpu->Regs.rP;

	sprintf(pStr, "A:%04X X:%04X Y:%04X S:%04X PC:%06X DB:%02X DP:%04X %c%c%c%c%c%c%c%c %c",
		pCpu->Regs.rA.w,
		pCpu->Regs.rX.w,
		pCpu->Regs.rY.w,
		pCpu->Regs.rS.w,
		pCpu->Regs.rPC,
		pCpu->Regs.rDB >> 16,
		pCpu->Regs.rDP,
		(rF & SNCPU_FLAG_N) ? 'N' : 'n',
		(rF & SNCPU_FLAG_V) ? 'V' : 'v',
		(rF & SNCPU_FLAG_M) ? 'M' : 'm',
		(rF & SNCPU_FLAG_X) ? 'X' : 'x',
		(rF & SNCPU_FLAG_D) ? 'D' : 'd',
		(rF & SNCPU_FLAG_I) ? 'I' : 'i',
		(rF & SNCPU_FLAG_Z) ? 'Z' : 'z',
		(rF & SNCPU_FLAG_C) ? 'C' : 'c',
		(pCpu->Regs.rE) ? 'E' : 'e'
		);

}


void SNCPUResetCounter(SNCpuT *pCpu, Int32 iCounter)
{
	pCpu->Counter[iCounter] = 0;
}


void SNCPUSetExecuteFunc(SNCpuExecuteFuncT pFunc)
{
	if (_SNCPU_bDebug)
	{
		_SNCPU_pDebugExecuteFunc = pFunc;
	} else
	{
		_SNCPU_pExecuteFunc = pFunc;
	}
}


Bool SNCPUExecute(SNCpuT *pCpu)
{
    pCpu->nAbortCycles = 0;

    // execute cpu cycles
    pCpu->bRunning = TRUE;
    _SNCPU_pExecuteFunc(pCpu);
    pCpu->bRunning = FALSE;

    // restore cycle count if we were just aborted
    if (pCpu->nAbortCycles != 0)
    {
        pCpu->Cycles = pCpu->nAbortCycles;
        pCpu->nAbortCycles = 0; 
        return FALSE;
    } else
    {
        return TRUE;
    }
}

Bool SNCPUExecuteOne(SNCpuT *pCpu)
{
    if (pCpu->Cycles > 0)
    {
        // execute one instruction
        int delta = pCpu->Cycles - 1;

        pCpu->Cycles    -= delta;
        pCpu->Counter[0]-= delta;
        pCpu->Counter[1]-= delta;
        pCpu->Counter[2]-= delta;
        pCpu->Counter[3]-= delta;

        SNCPUExecute(pCpu);
        pCpu->Cycles    += delta;
        pCpu->Counter[0]+= delta;
        pCpu->Counter[1]+= delta;
        pCpu->Counter[2]+= delta;
        pCpu->Counter[3]+= delta;

        return TRUE;
    } else
    {
        return FALSE;
    }
}

Int32 SNCPUExecuteDebug(SNCpuT *pCpu)
{
    SNCPUSetDebug(0, 1);

    while (pCpu->Cycles > 0)
    {
        Char str[64];

        // disassemble instruction
        SNCPUDisassemble(pCpu, pCpu->Regs.rPC, str, NULL);
        ConDebug("%06d: cpu %06X: %s\n", SNCPUGetCounter(pCpu, SNCPU_COUNTER_FRAME), pCpu->Regs.rPC, str);

        // execute just one instruction
        SNCPUExecuteOne(pCpu);

        // print registers
        SNCPUDumpRegs(pCpu, str);
        ConDebug("%06d: cpu %s\n", SNCPUGetCounter(pCpu, SNCPU_COUNTER_FRAME), str);

    }
    SNCPUSetDebug(1, 1);
	return 0;
}


void SNCPUSetDebug(Bool bDebug, Int32 nDebugCycles)
{
	if (_SNCPU_bDebug!=bDebug)
	{
		if (bDebug)
		{
			_SNCPU_pDebugExecuteFunc = _SNCPU_pExecuteFunc;
			_SNCPU_pExecuteFunc = SNCPUExecuteDebug;
		} else
		{
			_SNCPU_pExecuteFunc = _SNCPU_pDebugExecuteFunc;
		}

		_SNCPU_bDebug=bDebug;
	}

	_SNCPU_nDebugCycles = nDebugCycles;
}


void SNCPUAbort(SNCpuT *pCpu)
{
	if (pCpu->bRunning)
	{
		// cpu is executing, so force it to terminate by setting
		// the cycle count to zero. Termination will
		// cause the abort handler to be called, then execution will resume
		pCpu->nAbortCycles = pCpu->Cycles;
		pCpu->Cycles       = 0;
	}
}


void SNCPUSignalIRQ(SNCpuT *pCpu, Uint32 bEnable)
{
    //
    // IRQs will continuously occur while the IRQ signal is set.
    // IRQs can be enabled/disabled by CPU flags
    // IRQ can be cleared by reading timeup register or setting nmitimen v-en, h-en to 0
    //
	if (bEnable)
	{
		pCpu->uSignal |= SNCPU_SIGNAL_IRQ;
        // if we're currently running, abort so IRQ can happen now
		SNCPUAbort(pCpu);
	} else
	{
		pCpu->uSignal &= ~SNCPU_SIGNAL_IRQ;
	}
}

void SNCPUSignalNMI(SNCpuT *pCpu, Uint32 bEnable)
{
    //
    // NMIs are edge triggered. 
    // If the signal transitions from 0 -> 1 then the NMIEDGE flag becomes set.
    // When NMIEDGE is set, a cpu nmi will trigger with a one instruction delay.
    // If the NMI signal is set to 0, NMIEDGE is cleared.
    // 
	if (bEnable)
	{
		if (!(pCpu->uSignal & SNCPU_SIGNAL_NMI))
		{
			// trigger NMI on lo->hi transition
			pCpu->uSignal |= SNCPU_SIGNAL_NMIEDGE;
            // if we're currently running abort so NMI can happen now
			SNCPUAbort(pCpu);
		}
		pCpu->uSignal |= SNCPU_SIGNAL_NMI;
	} else
	{
		pCpu->uSignal &= ~(SNCPU_SIGNAL_NMI | SNCPU_SIGNAL_NMIEDGE);
	}
}


void SNCPUSignalDMA(SNCpuT *pCpu, Uint32 bEnable)
{
    if (bEnable)
    {
        pCpu->uSignal |= SNCPU_SIGNAL_DMA;
        // if we're currently running, abort so we can MDMA
        SNCPUAbort(pCpu);
    } else
    {
        pCpu->uSignal &= ~SNCPU_SIGNAL_DMA;
    }
}

