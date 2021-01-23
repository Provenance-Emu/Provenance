/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#include "snes9x.h"
#include "memmap.h"

#define CPU								SA1
#define ICPU							SA1
#define Registers						SA1Registers
#define OpenBus							SA1OpenBus
#define S9xGetByte						S9xSA1GetByte
#define S9xGetWord						S9xSA1GetWord
#define S9xSetByte						S9xSA1SetByte
#define S9xSetWord						S9xSA1SetWord
#define S9xSetPCBase					S9xSA1SetPCBase
#define S9xOpcodesM1X1					S9xSA1OpcodesM1X1
#define S9xOpcodesM1X0					S9xSA1OpcodesM1X0
#define S9xOpcodesM0X1					S9xSA1OpcodesM0X1
#define S9xOpcodesM0X0					S9xSA1OpcodesM0X0
#define S9xOpcodesE1					S9xSA1OpcodesE1
#define S9xOpcodesSlow					S9xSA1OpcodesSlow
#define S9xOpcode_IRQ					S9xSA1Opcode_IRQ
#define S9xOpcode_NMI					S9xSA1Opcode_NMI
#define S9xUnpackStatus					S9xSA1UnpackStatus
#define S9xPackStatus					S9xSA1PackStatus
#define S9xFixCycles					S9xSA1FixCycles
#define Immediate8						SA1Immediate8
#define Immediate16						SA1Immediate16
#define Relative						SA1Relative
#define RelativeLong					SA1RelativeLong
#define Absolute						SA1Absolute
#define AbsoluteLong					SA1AbsoluteLong
#define AbsoluteIndirect				SA1AbsoluteIndirect
#define AbsoluteIndirectLong			SA1AbsoluteIndirectLong
#define AbsoluteIndexedIndirect			SA1AbsoluteIndexedIndirect
#define Direct							SA1Direct
#define DirectIndirectIndexed			SA1DirectIndirectIndexed
#define DirectIndirectIndexedLong		SA1DirectIndirectIndexedLong
#define DirectIndexedIndirect			SA1DirectIndexedIndirect
#define DirectIndexedX					SA1DirectIndexedX
#define DirectIndexedY					SA1DirectIndexedY
#define AbsoluteIndexedX				SA1AbsoluteIndexedX
#define AbsoluteIndexedY				SA1AbsoluteIndexedY
#define AbsoluteLongIndexedX			SA1AbsoluteLongIndexedX
#define DirectIndirect					SA1DirectIndirect
#define DirectIndirectLong				SA1DirectIndirectLong
#define StackRelative					SA1StackRelative
#define StackRelativeIndirectIndexed	SA1StackRelativeIndirectIndexed

#define SA1_OPCODES

#include "cpuops.cpp"

static void S9xSA1UpdateTimer (void);


void S9xSA1MainLoop (void)
{
	if (Memory.FillRAM[0x2200] & 0x60)
	{
		SA1.Cycles += 6; // FIXME
		S9xSA1UpdateTimer();
		return;
	}

	// SA-1 NMI
	if ((Memory.FillRAM[0x2200] & 0x10) && !(Memory.FillRAM[0x220b] & 0x10))
	{
		Memory.FillRAM[0x2301] |= 0x10;
		Memory.FillRAM[0x220b] |= 0x10;

		if (SA1.WaitingForInterrupt)
		{
			SA1.WaitingForInterrupt = FALSE;
			SA1Registers.PCw++;
		}

		S9xSA1Opcode_NMI();
	}
	else
	if (!SA1CheckFlag(IRQ))
	{
		// SA-1 Timer IRQ
		if ((Memory.FillRAM[0x220a] & 0x40) && !(Memory.FillRAM[0x220b] & 0x40))
		{
			Memory.FillRAM[0x2301] |= 0x40;

			if (SA1.WaitingForInterrupt)
			{
				SA1.WaitingForInterrupt = FALSE;
				SA1Registers.PCw++;
			}

			S9xSA1Opcode_IRQ();
		}
		else
		// SA-1 DMA IRQ
		if ((Memory.FillRAM[0x220a] & 0x20) && !(Memory.FillRAM[0x220b] & 0x20))
		{
			Memory.FillRAM[0x2301] |= 0x20;

			if (SA1.WaitingForInterrupt)
			{
				SA1.WaitingForInterrupt = FALSE;
				SA1Registers.PCw++;
			}

			S9xSA1Opcode_IRQ();
		}
		else
		// SA-1 IRQ
		if ((Memory.FillRAM[0x2200] & 0x80) && !(Memory.FillRAM[0x220b] & 0x80))
		{
			Memory.FillRAM[0x2301] |= 0x80;

			if (SA1.WaitingForInterrupt)
			{
				SA1.WaitingForInterrupt = FALSE;
				SA1Registers.PCw++;
			}

			S9xSA1Opcode_IRQ();
		}
	}

	#undef CPU
	int cycles = CPU.Cycles * 3;
	#define CPU SA1

	for (; SA1.Cycles < cycles && !(Memory.FillRAM[0x2200] & 0x60);)
	{
	#ifdef DEBUGGER
		if (SA1.Flags & TRACE_FLAG)
			S9xSA1Trace();
	#endif

		uint8				Op;
		struct SOpcodes	*Opcodes;

		if (SA1.PCBase)
		{
			SA1OpenBus = Op = SA1.PCBase[Registers.PCw];
			Opcodes = SA1.S9xOpcodes;
			SA1.Cycles += SA1.MemSpeed;
		}
		else
		{
			Op = S9xSA1GetByte(Registers.PBPC);
			Opcodes = S9xOpcodesSlow;
		}

		if ((SA1Registers.PCw & MEMMAP_MASK) + SA1.S9xOpLengths[Op] >= MEMMAP_BLOCK_SIZE)
		{
			uint32	oldPC = SA1Registers.PBPC;
			S9xSA1SetPCBase(SA1Registers.PBPC);
			SA1Registers.PBPC = oldPC;
			Opcodes = S9xSA1OpcodesSlow;
		}

		Registers.PCw++;
		(*Opcodes[Op].S9xOpcode)();
	}

	S9xSA1UpdateTimer();
}

static void S9xSA1UpdateTimer (void) // FIXME
{
	SA1.PrevHCounter = SA1.HCounter;

	if (Memory.FillRAM[0x2210] & 0x80)
	{
		SA1.HCounter += (SA1.Cycles - SA1.PrevCycles);
		if (SA1.HCounter >= 0x800)
		{
			SA1.HCounter -= 0x800;
			SA1.PrevHCounter -= 0x800;
			if (++SA1.VCounter >= 0x200)
				SA1.VCounter = 0;
		}
	}
	else
	{
		SA1.HCounter += (SA1.Cycles - SA1.PrevCycles);
		if (SA1.HCounter >= Timings.H_Max_Master)
		{
			SA1.HCounter -= Timings.H_Max_Master;
			SA1.PrevHCounter -= Timings.H_Max_Master;
			if (++SA1.VCounter >= Timings.V_Max_Master)
				SA1.VCounter = 0;
		}
	}

	SA1.PrevCycles = SA1.Cycles;

	bool8	thisIRQ = Memory.FillRAM[0x2210] & 0x03;

	if (Memory.FillRAM[0x2210] & 0x01)
	{
		if (SA1.PrevHCounter >= SA1.HTimerIRQPos * ONE_DOT_CYCLE || SA1.HCounter < SA1.HTimerIRQPos * ONE_DOT_CYCLE)
			thisIRQ = FALSE;
	}

	if (Memory.FillRAM[0x2210] & 0x02)
	{
		if (SA1.VCounter != SA1.VTimerIRQPos * ONE_DOT_CYCLE)
			thisIRQ = FALSE;
	}

	// SA-1 Timer IRQ control
	if (!SA1.TimerIRQLastState && thisIRQ)
	{
		Memory.FillRAM[0x2301] |= 0x40;
		if (Memory.FillRAM[0x220a] & 0x40)
		{
			Memory.FillRAM[0x220b] &= ~0x40;
		#ifdef DEBUGGER
			S9xTraceFormattedMessage("--- SA-1 Timer IRQ triggered  prev HC:%04d  curr HC:%04d  HTimer:%d Pos:%04d  VTimer:%d Pos:%03d",
				SA1.PrevHCounter, SA1.HCounter,
				(Memory.FillRAM[0x2210] & 0x01) ? 1 : 0, SA1.HTimerIRQPos * ONE_DOT_CYCLE,
				(Memory.FillRAM[0x2210] & 0x02) ? 1 : 0, SA1.VTimerIRQPos);
		#endif
		}
	}

	SA1.TimerIRQLastState = thisIRQ;
}
