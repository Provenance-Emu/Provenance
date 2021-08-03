/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#ifndef _GETSET_H_
#define _GETSET_H_

#include "cpuexec.h"
#include "dsp.h"
#include "sa1.h"
#include "spc7110.h"
#include "c4.h"
#include "obc1.h"
#include "seta.h"
#include "bsx.h"
#include "msu1.h"

#define addCyclesInMemoryAccess \
	if (!CPU.InDMAorHDMA) \
	{ \
		CPU.Cycles += speed; \
		while (CPU.Cycles >= CPU.NextEvent) \
			S9xDoHEventProcessing(); \
	}

#define addCyclesInMemoryAccess_x2 \
	if (!CPU.InDMAorHDMA) \
	{ \
		CPU.Cycles += speed << 1; \
		while (CPU.Cycles >= CPU.NextEvent) \
			S9xDoHEventProcessing(); \
	}

extern uint8	OpenBus;

static inline int32 memory_speed (uint32 address)
{
	if (address & 0x408000)
	{
		if (address & 0x800000)
			return (CPU.FastROMSpeed);

		return (SLOW_ONE_CYCLE);
	}

	if ((address + 0x6000) & 0x4000)
		return (SLOW_ONE_CYCLE);

	if ((address - 0x4000) & 0x7e00)
		return (ONE_CYCLE);

	return (TWO_CYCLES);
}

inline uint8 S9xGetByte (uint32 Address)
{
	int		block = (Address & 0xffffff) >> MEMMAP_SHIFT;
	uint8	*GetAddress = Memory.Map[block];
	int32	speed = memory_speed(Address);
	uint8	byte;

	if (GetAddress >= (uint8 *) CMemory::MAP_LAST)
	{
		byte = *(GetAddress + (Address & 0xffff));
		addCyclesInMemoryAccess;
		return (byte);
	}

	switch ((pint) GetAddress)
	{
		case CMemory::MAP_CPU:
			byte = S9xGetCPU(Address & 0xffff);
			addCyclesInMemoryAccess;
			return (byte);

		case CMemory::MAP_PPU:
			if (CPU.InDMAorHDMA && (Address & 0xff00) == 0x2100)
				return (OpenBus);

			byte = S9xGetPPU(Address & 0xffff);
			addCyclesInMemoryAccess;
			return (byte);

		case CMemory::MAP_LOROM_SRAM:
		case CMemory::MAP_SA1RAM:
			// Address & 0x7fff   : offset into bank
			// Address & 0xff0000 : bank
			// bank >> 1 | offset : SRAM address, unbound
			// unbound & SRAMMask : SRAM offset
			byte = *(Memory.SRAM + ((((Address & 0xff0000) >> 1) | (Address & 0x7fff)) & Memory.SRAMMask));
			addCyclesInMemoryAccess;
			return (byte);

		case CMemory::MAP_LOROM_SRAM_B:
			byte = *(Multi.sramB + ((((Address & 0xff0000) >> 1) | (Address & 0x7fff)) & Multi.sramMaskB));
			addCyclesInMemoryAccess;
			return (byte);

		case CMemory::MAP_HIROM_SRAM:
		case CMemory::MAP_RONLY_SRAM:
			byte = *(Memory.SRAM + (((Address & 0x7fff) - 0x6000 + ((Address & 0xf0000) >> 3)) & Memory.SRAMMask));
			addCyclesInMemoryAccess;
			return (byte);

		case CMemory::MAP_BWRAM:
			byte = *(Memory.BWRAM + ((Address & 0x7fff) - 0x6000));
			addCyclesInMemoryAccess;
			return (byte);

		case CMemory::MAP_DSP:
			byte = S9xGetDSP(Address & 0xffff);
			addCyclesInMemoryAccess;
			return (byte);

		case CMemory::MAP_SPC7110_ROM:
			byte = S9xGetSPC7110Byte(Address);
			addCyclesInMemoryAccess;
			return (byte);

		case CMemory::MAP_SPC7110_DRAM:
			byte = S9xGetSPC7110(0x4800);
			addCyclesInMemoryAccess;
			return (byte);

		case CMemory::MAP_C4:
			byte = S9xGetC4(Address & 0xffff);
			addCyclesInMemoryAccess;
			return (byte);

		case CMemory::MAP_OBC_RAM:
			byte = S9xGetOBC1(Address & 0xffff);
			addCyclesInMemoryAccess;
			return (byte);

		case CMemory::MAP_SETA_DSP:
			byte = S9xGetSetaDSP(Address);
			addCyclesInMemoryAccess;
			return (byte);

		case CMemory::MAP_SETA_RISC:
			byte = S9xGetST018(Address);
			addCyclesInMemoryAccess;
			return (byte);

		case CMemory::MAP_BSX:
			byte = S9xGetBSX(Address);
			addCyclesInMemoryAccess;
			return (byte);

		case CMemory::MAP_NONE:
		default:
			byte = OpenBus;
			addCyclesInMemoryAccess;
			return (byte);
	}
}

inline uint16 S9xGetWord (uint32 Address, enum s9xwrap_t w = WRAP_NONE)
{
	uint16	word;

	uint32	mask = MEMMAP_MASK & (w == WRAP_PAGE ? 0xff : (w == WRAP_BANK ? 0xffff : 0xffffff));
	if ((Address & mask) == mask)
	{
		PC_t	a;

		word = OpenBus = S9xGetByte(Address);

		switch (w)
		{
			case WRAP_PAGE:
				a.xPBPC = Address;
				a.B.xPCl++;
				return (word | (S9xGetByte(a.xPBPC) << 8));

			case WRAP_BANK:
				a.xPBPC = Address;
				a.W.xPC++;
				return (word | (S9xGetByte(a.xPBPC) << 8));

			case WRAP_NONE:
			default:
				return (word | (S9xGetByte(Address + 1) << 8));
		}
	}

	int		block = (Address & 0xffffff) >> MEMMAP_SHIFT;
	uint8	*GetAddress = Memory.Map[block];
	int32	speed = memory_speed(Address);

	if (GetAddress >= (uint8 *) CMemory::MAP_LAST)
	{
		word = READ_WORD(GetAddress + (Address & 0xffff));
		addCyclesInMemoryAccess_x2;
		return (word);
	}

	switch ((pint) GetAddress)
	{
		case CMemory::MAP_CPU:
			word  = S9xGetCPU(Address & 0xffff);
			addCyclesInMemoryAccess;
			word |= S9xGetCPU((Address + 1) & 0xffff) << 8;
			addCyclesInMemoryAccess;
			return (word);

		case CMemory::MAP_PPU:
			if (CPU.InDMAorHDMA)
			{
				word = OpenBus = S9xGetByte(Address);
				return (word | (S9xGetByte(Address + 1) << 8));
			}

			word  = S9xGetPPU(Address & 0xffff);
			addCyclesInMemoryAccess;
			word |= S9xGetPPU((Address + 1) & 0xffff) << 8;
			addCyclesInMemoryAccess;
			return (word);

		case CMemory::MAP_LOROM_SRAM:
		case CMemory::MAP_SA1RAM:
			if (Memory.SRAMMask >= MEMMAP_MASK)
				word = READ_WORD(Memory.SRAM + ((((Address & 0xff0000) >> 1) | (Address & 0x7fff)) & Memory.SRAMMask));
			else
				word = (*(Memory.SRAM + ((((Address & 0xff0000) >> 1) | (Address & 0x7fff)) & Memory.SRAMMask))) |
					  ((*(Memory.SRAM + (((((Address + 1) & 0xff0000) >> 1) | ((Address + 1) & 0x7fff)) & Memory.SRAMMask))) << 8);
			addCyclesInMemoryAccess_x2;
			return (word);

		case CMemory::MAP_LOROM_SRAM_B:
			if (Multi.sramMaskB >= MEMMAP_MASK)
				word = READ_WORD(Multi.sramB + ((((Address & 0xff0000) >> 1) | (Address & 0x7fff)) & Multi.sramMaskB));
			else
				word = (*(Multi.sramB + ((((Address & 0xff0000) >> 1) | (Address & 0x7fff)) & Multi.sramMaskB))) |
					  ((*(Multi.sramB + (((((Address + 1) & 0xff0000) >> 1) | ((Address + 1) & 0x7fff)) & Multi.sramMaskB))) << 8);
			addCyclesInMemoryAccess_x2;
			return (word);

		case CMemory::MAP_HIROM_SRAM:
		case CMemory::MAP_RONLY_SRAM:
			if (Memory.SRAMMask >= MEMMAP_MASK)
				word = READ_WORD(Memory.SRAM + (((Address & 0x7fff) - 0x6000 + ((Address & 0xf0000) >> 3)) & Memory.SRAMMask));
			else
				word = (*(Memory.SRAM + (((Address & 0x7fff) - 0x6000 + ((Address & 0xf0000) >> 3)) & Memory.SRAMMask)) |
					   (*(Memory.SRAM + ((((Address + 1) & 0x7fff) - 0x6000 + (((Address + 1) & 0xf0000) >> 3)) & Memory.SRAMMask)) << 8));
			addCyclesInMemoryAccess_x2;
			return (word);

		case CMemory::MAP_BWRAM:
			word = READ_WORD(Memory.BWRAM + ((Address & 0x7fff) - 0x6000));
			addCyclesInMemoryAccess_x2;
			return (word);

		case CMemory::MAP_DSP:
			word  = S9xGetDSP(Address & 0xffff);
			addCyclesInMemoryAccess;
			word |= S9xGetDSP((Address + 1) & 0xffff) << 8;
			addCyclesInMemoryAccess;
			return (word);

		case CMemory::MAP_SPC7110_ROM:
			word  = S9xGetSPC7110Byte(Address);
			addCyclesInMemoryAccess;
			word |= S9xGetSPC7110Byte(Address + 1) << 8;
			addCyclesInMemoryAccess;
			return (word);

		case CMemory::MAP_SPC7110_DRAM:
			word  = S9xGetSPC7110(0x4800);
			addCyclesInMemoryAccess;
			word |= S9xGetSPC7110(0x4800) << 8;
			addCyclesInMemoryAccess;
			return (word);

		case CMemory::MAP_C4:
			word  = S9xGetC4(Address & 0xffff);
			addCyclesInMemoryAccess;
			word |= S9xGetC4((Address + 1) & 0xffff) << 8;
			addCyclesInMemoryAccess;
			return (word);

		case CMemory::MAP_OBC_RAM:
			word  = S9xGetOBC1(Address & 0xffff);
			addCyclesInMemoryAccess;
			word |= S9xGetOBC1((Address + 1) & 0xffff) << 8;
			addCyclesInMemoryAccess;
			return (word);

		case CMemory::MAP_SETA_DSP:
			word  = S9xGetSetaDSP(Address);
			addCyclesInMemoryAccess;
			word |= S9xGetSetaDSP(Address + 1) << 8;
			addCyclesInMemoryAccess;
			return (word);

		case CMemory::MAP_SETA_RISC:
			word  = S9xGetST018(Address);
			addCyclesInMemoryAccess;
			word |= S9xGetST018(Address + 1) << 8;
			addCyclesInMemoryAccess;
			return (word);

		case CMemory::MAP_BSX:
			word  = S9xGetBSX(Address);
			addCyclesInMemoryAccess;
			word |= S9xGetBSX(Address + 1) << 8;
			addCyclesInMemoryAccess;
			return (word);

		case CMemory::MAP_NONE:
		default:
			word = OpenBus | (OpenBus << 8);
			addCyclesInMemoryAccess_x2;
			return (word);
	}
}

inline void S9xSetByte (uint8 Byte, uint32 Address)
{
	int		block = (Address & 0xffffff) >> MEMMAP_SHIFT;
	uint8	*SetAddress = Memory.WriteMap[block];
	int32	speed = memory_speed(Address);

	if (SetAddress >= (uint8 *) CMemory::MAP_LAST)
	{
		*(SetAddress + (Address & 0xffff)) = Byte;
		addCyclesInMemoryAccess;
		return;
	}

	switch ((pint) SetAddress)
	{
		case CMemory::MAP_CPU:
			S9xSetCPU(Byte, Address & 0xffff);
			addCyclesInMemoryAccess;
			return;

		case CMemory::MAP_PPU:
			if (CPU.InDMAorHDMA && (Address & 0xff00) == 0x2100)
				return;

			S9xSetPPU(Byte, Address & 0xffff);
			addCyclesInMemoryAccess;
			return;

		case CMemory::MAP_LOROM_SRAM:
			if (Memory.SRAMMask)
			{
				*(Memory.SRAM + ((((Address & 0xff0000) >> 1) | (Address & 0x7fff)) & Memory.SRAMMask)) = Byte;
				CPU.SRAMModified = TRUE;
			}

			addCyclesInMemoryAccess;
			return;

		case CMemory::MAP_LOROM_SRAM_B:
			if (Multi.sramMaskB)
			{
				*(Multi.sramB + ((((Address & 0xff0000) >> 1) | (Address & 0x7fff)) & Multi.sramMaskB)) = Byte;
				CPU.SRAMModified = TRUE;
			}

			addCyclesInMemoryAccess;
			return;

		case CMemory::MAP_HIROM_SRAM:
			if (Memory.SRAMMask)
			{
				*(Memory.SRAM + (((Address & 0x7fff) - 0x6000 + ((Address & 0xf0000) >> 3)) & Memory.SRAMMask)) = Byte;
				CPU.SRAMModified = TRUE;
			}

			addCyclesInMemoryAccess;
			return;

		case CMemory::MAP_BWRAM:
			*(Memory.BWRAM + ((Address & 0x7fff) - 0x6000)) = Byte;
			CPU.SRAMModified = TRUE;
			addCyclesInMemoryAccess;
			return;

		case CMemory::MAP_SA1RAM:
			*(Memory.SRAM + (Address & 0xffff)) = Byte;
			addCyclesInMemoryAccess;
			return;

		case CMemory::MAP_DSP:
			S9xSetDSP(Byte, Address & 0xffff);
			addCyclesInMemoryAccess;
			return;

		case CMemory::MAP_C4:
			S9xSetC4(Byte, Address & 0xffff);
			addCyclesInMemoryAccess;
			return;

		case CMemory::MAP_OBC_RAM:
			S9xSetOBC1(Byte, Address & 0xffff);
			addCyclesInMemoryAccess;
			return;

		case CMemory::MAP_SETA_DSP:
			S9xSetSetaDSP(Byte, Address);
			addCyclesInMemoryAccess;
			return;

		case CMemory::MAP_SETA_RISC:
			S9xSetST018(Byte, Address);
			addCyclesInMemoryAccess;
			return;

		case CMemory::MAP_BSX:
			S9xSetBSX(Byte, Address);
			addCyclesInMemoryAccess;
			return;

		case CMemory::MAP_NONE:
		default:
			addCyclesInMemoryAccess;
			return;
	}
}

inline void S9xSetWord (uint16 Word, uint32 Address, enum s9xwrap_t w = WRAP_NONE, enum s9xwriteorder_t o = WRITE_01)
{
	uint32	mask = MEMMAP_MASK & (w == WRAP_PAGE ? 0xff : (w == WRAP_BANK ? 0xffff : 0xffffff));
	if ((Address & mask) == mask)
	{
		PC_t	a;

		if (!o)
			S9xSetByte((uint8) Word, Address);

		switch (w)
		{
			case WRAP_PAGE:
				a.xPBPC = Address;
				a.B.xPCl++;
				S9xSetByte(Word >> 8, a.xPBPC);
				break;

			case WRAP_BANK:
				a.xPBPC = Address;
				a.W.xPC++;
				S9xSetByte(Word >> 8, a.xPBPC);
				break;

			case WRAP_NONE:
			default:
				S9xSetByte(Word >> 8, Address + 1);
				break;
		}

		if (o)
			S9xSetByte((uint8) Word, Address);

		return;
	}

	int		block = (Address & 0xffffff) >> MEMMAP_SHIFT;
	uint8	*SetAddress = Memory.WriteMap[block];
	int32	speed = memory_speed(Address);

	if (SetAddress >= (uint8 *) CMemory::MAP_LAST)
	{
		WRITE_WORD(SetAddress + (Address & 0xffff), Word);
		addCyclesInMemoryAccess_x2;
		return;
	}

	switch ((pint) SetAddress)
	{
		case CMemory::MAP_CPU:
			if (o)
			{
				S9xSetCPU(Word >> 8, (Address + 1) & 0xffff);
				addCyclesInMemoryAccess;
				S9xSetCPU((uint8) Word, Address & 0xffff);
				addCyclesInMemoryAccess;
				return;
			}
			else
			{
				S9xSetCPU((uint8) Word, Address & 0xffff);
				addCyclesInMemoryAccess;
				S9xSetCPU(Word >> 8, (Address + 1) & 0xffff);
				addCyclesInMemoryAccess;
				return;
			}

		case CMemory::MAP_PPU:
			if (CPU.InDMAorHDMA)
			{
				if ((Address & 0xff00) != 0x2100)
					S9xSetPPU((uint8) Word, Address & 0xffff);
				if (((Address + 1) & 0xff00) != 0x2100)
					S9xSetPPU(Word >> 8, (Address + 1) & 0xffff);
				return;
			}

			if (o)
			{
				S9xSetPPU(Word >> 8, (Address + 1) & 0xffff);
				addCyclesInMemoryAccess;
				S9xSetPPU((uint8) Word, Address & 0xffff);
				addCyclesInMemoryAccess;
				return;
			}
			else
			{
				S9xSetPPU((uint8) Word, Address & 0xffff);
				addCyclesInMemoryAccess;
				S9xSetPPU(Word >> 8, (Address + 1) & 0xffff);
				addCyclesInMemoryAccess;
				return;
			}

		case CMemory::MAP_LOROM_SRAM:
			if (Memory.SRAMMask)
			{
				if (Memory.SRAMMask >= MEMMAP_MASK)
					WRITE_WORD(Memory.SRAM + ((((Address & 0xff0000) >> 1) | (Address & 0x7fff)) & Memory.SRAMMask), Word);
				else
				{
					*(Memory.SRAM + ((((Address & 0xff0000) >> 1) | (Address & 0x7fff)) & Memory.SRAMMask)) = (uint8) Word;
					*(Memory.SRAM + (((((Address + 1) & 0xff0000) >> 1) | ((Address + 1) & 0x7fff)) & Memory.SRAMMask)) = Word >> 8;
				}

				CPU.SRAMModified = TRUE;
			}

			addCyclesInMemoryAccess_x2;
			return;

		case CMemory::MAP_LOROM_SRAM_B:
			if (Multi.sramMaskB)
			{
				if (Multi.sramMaskB >= MEMMAP_MASK)
					WRITE_WORD(Multi.sramB + ((((Address & 0xff0000) >> 1) | (Address & 0x7fff)) & Multi.sramMaskB), Word);
				else
				{
					*(Multi.sramB + ((((Address & 0xff0000) >> 1) | (Address & 0x7fff)) & Multi.sramMaskB)) = (uint8) Word;
					*(Multi.sramB + (((((Address + 1) & 0xff0000) >> 1) | ((Address + 1) & 0x7fff)) & Multi.sramMaskB)) = Word >> 8;
				}

				CPU.SRAMModified = TRUE;
			}

			addCyclesInMemoryAccess_x2;
			return;

		case CMemory::MAP_HIROM_SRAM:
			if (Memory.SRAMMask)
			{
				if (Memory.SRAMMask >= MEMMAP_MASK)
					WRITE_WORD(Memory.SRAM + (((Address & 0x7fff) - 0x6000 + ((Address & 0xf0000) >> 3)) & Memory.SRAMMask), Word);
				else
				{
					*(Memory.SRAM + (((Address & 0x7fff) - 0x6000 + ((Address & 0xf0000) >> 3)) & Memory.SRAMMask)) = (uint8) Word;
					*(Memory.SRAM + ((((Address + 1) & 0x7fff) - 0x6000 + (((Address + 1) & 0xf0000) >> 3)) & Memory.SRAMMask)) = Word >> 8;
				}

				CPU.SRAMModified = TRUE;
			}

			addCyclesInMemoryAccess_x2;
			return;

		case CMemory::MAP_BWRAM:
			WRITE_WORD(Memory.BWRAM + ((Address & 0x7fff) - 0x6000), Word);
			CPU.SRAMModified = TRUE;
			addCyclesInMemoryAccess_x2;
			return;

		case CMemory::MAP_SA1RAM:
			WRITE_WORD(Memory.SRAM + (Address & 0xffff), Word);
			addCyclesInMemoryAccess_x2;
			return;

		case CMemory::MAP_DSP:
			if (o)
			{
				S9xSetDSP(Word >> 8, (Address + 1) & 0xffff);
				addCyclesInMemoryAccess;
				S9xSetDSP((uint8) Word, Address & 0xffff);
				addCyclesInMemoryAccess;
				return;
			}
			else
			{
				S9xSetDSP((uint8) Word, Address & 0xffff);
				addCyclesInMemoryAccess;
				S9xSetDSP(Word >> 8, (Address + 1) & 0xffff);
				addCyclesInMemoryAccess;
				return;
			}

		case CMemory::MAP_C4:
			if (o)
			{
				S9xSetC4(Word >> 8, (Address + 1) & 0xffff);
				addCyclesInMemoryAccess;
				S9xSetC4((uint8) Word, Address & 0xffff);
				addCyclesInMemoryAccess;
				return;
			}
			else
			{
				S9xSetC4((uint8) Word, Address & 0xffff);
				addCyclesInMemoryAccess;
				S9xSetC4(Word >> 8, (Address + 1) & 0xffff);
				addCyclesInMemoryAccess;
				return;
			}

		case CMemory::MAP_OBC_RAM:
			if (o)
			{
				S9xSetOBC1(Word >> 8, (Address + 1) & 0xffff);
				addCyclesInMemoryAccess;
				S9xSetOBC1((uint8) Word, Address & 0xffff);
				addCyclesInMemoryAccess;
				return;
			}
			else
			{
				S9xSetOBC1((uint8) Word, Address & 0xffff);
				addCyclesInMemoryAccess;
				S9xSetOBC1(Word >> 8, (Address + 1) & 0xffff);
				addCyclesInMemoryAccess;
				return;
			}

		case CMemory::MAP_SETA_DSP:
			if (o)
			{
				S9xSetSetaDSP(Word >> 8, Address + 1);
				addCyclesInMemoryAccess;
				S9xSetSetaDSP((uint8) Word, Address);
				addCyclesInMemoryAccess;
				return;
			}
			else
			{
				S9xSetSetaDSP((uint8) Word, Address);
				addCyclesInMemoryAccess;
				S9xSetSetaDSP(Word >> 8, Address + 1);
				addCyclesInMemoryAccess;
				return;
			}

		case CMemory::MAP_SETA_RISC:
			if (o)
			{
				S9xSetST018(Word >> 8, Address + 1);
				addCyclesInMemoryAccess;
				S9xSetST018((uint8) Word, Address);
				addCyclesInMemoryAccess;
				return;
			}
			else
			{
				S9xSetST018((uint8) Word, Address);
				addCyclesInMemoryAccess;
				S9xSetST018(Word >> 8, Address + 1);
				addCyclesInMemoryAccess;
				return;
			}

		case CMemory::MAP_BSX:
			if (o)
			{
				S9xSetBSX(Word >> 8, Address + 1);
				addCyclesInMemoryAccess;
				S9xSetBSX((uint8) Word, Address);
				addCyclesInMemoryAccess;
				return;
			}
			else
			{
				S9xSetBSX((uint8) Word, Address);
				addCyclesInMemoryAccess;
				S9xSetBSX(Word >> 8, Address + 1);
				addCyclesInMemoryAccess;
				return;
			}

		case CMemory::MAP_NONE:
		default:
			addCyclesInMemoryAccess_x2;
			return;
	}
}

inline void S9xSetPCBase (uint32 Address)
{
	Registers.PBPC = Address & 0xffffff;
	ICPU.ShiftedPB = Address & 0xff0000;

	uint8	*GetAddress = Memory.Map[(int)((Address & 0xffffff) >> MEMMAP_SHIFT)];

	CPU.MemSpeed = memory_speed(Address);
	CPU.MemSpeedx2 = CPU.MemSpeed << 1;

	if (GetAddress >= (uint8 *) CMemory::MAP_LAST)
	{
		CPU.PCBase = GetAddress;
		return;
	}

	switch ((pint) GetAddress)
	{
		case CMemory::MAP_LOROM_SRAM:
			if ((Memory.SRAMMask & MEMMAP_MASK) != MEMMAP_MASK)
				CPU.PCBase = NULL;
			else
				CPU.PCBase = Memory.SRAM + ((((Address & 0xff0000) >> 1) | (Address & 0x7fff)) & Memory.SRAMMask) - (Address & 0xffff);
			return;

		case CMemory::MAP_LOROM_SRAM_B:
			if ((Multi.sramMaskB & MEMMAP_MASK) != MEMMAP_MASK)
				CPU.PCBase = NULL;
			else
				CPU.PCBase = Multi.sramB + ((((Address & 0xff0000) >> 1) | (Address & 0x7fff)) & Multi.sramMaskB) - (Address & 0xffff);
			return;

		case CMemory::MAP_HIROM_SRAM:
			if ((Memory.SRAMMask & MEMMAP_MASK) != MEMMAP_MASK)
				CPU.PCBase = NULL;
			else
				CPU.PCBase = Memory.SRAM + (((Address & 0x7fff) - 0x6000 + ((Address & 0xf0000) >> 3)) & Memory.SRAMMask) - (Address & 0xffff);
			return;

		case CMemory::MAP_BWRAM:
			CPU.PCBase = Memory.BWRAM - 0x6000 - (Address & 0x8000);
			return;

		case CMemory::MAP_SA1RAM:
			CPU.PCBase = Memory.SRAM;
			return;

		case CMemory::MAP_SPC7110_ROM:
			CPU.PCBase = S9xGetBasePointerSPC7110(Address);
			return;

		case CMemory::MAP_C4:
			CPU.PCBase = S9xGetBasePointerC4(Address & 0xffff);
			return;

		case CMemory::MAP_OBC_RAM:
			CPU.PCBase = S9xGetBasePointerOBC1(Address & 0xffff);
			return;

		case CMemory::MAP_BSX:
			CPU.PCBase = S9xGetBasePointerBSX(Address);
			return;

		case CMemory::MAP_NONE:
		default:
			CPU.PCBase = NULL;
			return;
	}
}

inline uint8 * S9xGetBasePointer (uint32 Address)
{
	uint8	*GetAddress = Memory.Map[(Address & 0xffffff) >> MEMMAP_SHIFT];

	if (GetAddress >= (uint8 *) CMemory::MAP_LAST)
		return (GetAddress);

	switch ((pint) GetAddress)
	{
		case CMemory::MAP_LOROM_SRAM:
			if ((Memory.SRAMMask & MEMMAP_MASK) != MEMMAP_MASK)
				return (NULL);
			return (Memory.SRAM + ((((Address & 0xff0000) >> 1) | (Address & 0x7fff)) & Memory.SRAMMask) - (Address & 0xffff));

		case CMemory::MAP_LOROM_SRAM_B:
			if ((Multi.sramMaskB & MEMMAP_MASK) != MEMMAP_MASK)
				return (NULL);
			return (Multi.sramB + ((((Address & 0xff0000) >> 1) | (Address & 0x7fff)) & Multi.sramMaskB) - (Address & 0xffff));

		case CMemory::MAP_HIROM_SRAM:
			if ((Memory.SRAMMask & MEMMAP_MASK) != MEMMAP_MASK)
				return (NULL);
			return (Memory.SRAM + (((Address & 0x7fff) - 0x6000 + ((Address & 0xf0000) >> 3)) & Memory.SRAMMask) - (Address & 0xffff));

		case CMemory::MAP_BWRAM:
			return (Memory.BWRAM - 0x6000 - (Address & 0x8000));

		case CMemory::MAP_SA1RAM:
			return (Memory.SRAM);

		case CMemory::MAP_SPC7110_ROM:
			return (S9xGetBasePointerSPC7110(Address));

		case CMemory::MAP_C4:
			return (S9xGetBasePointerC4(Address & 0xffff));

		case CMemory::MAP_OBC_RAM:
			return (S9xGetBasePointerOBC1(Address & 0xffff));

		case CMemory::MAP_NONE:
		default:
			return (NULL);
	}
}

inline uint8 * S9xGetMemPointer (uint32 Address)
{
	uint8	*GetAddress = Memory.Map[(Address & 0xffffff) >> MEMMAP_SHIFT];

	if (GetAddress >= (uint8 *) CMemory::MAP_LAST)
		return (GetAddress + (Address & 0xffff));

	switch ((pint) GetAddress)
	{
		case CMemory::MAP_LOROM_SRAM:
			if ((Memory.SRAMMask & MEMMAP_MASK) != MEMMAP_MASK)
				return (NULL);
			return (Memory.SRAM + ((((Address & 0xff0000) >> 1) | (Address & 0x7fff)) & Memory.SRAMMask));

		case CMemory::MAP_LOROM_SRAM_B:
			if ((Multi.sramMaskB & MEMMAP_MASK) != MEMMAP_MASK)
				return (NULL);
			return (Multi.sramB + ((((Address & 0xff0000) >> 1) | (Address & 0x7fff)) & Multi.sramMaskB));

		case CMemory::MAP_HIROM_SRAM:
			if ((Memory.SRAMMask & MEMMAP_MASK) != MEMMAP_MASK)
				return (NULL);
			return (Memory.SRAM + (((Address & 0x7fff) - 0x6000 + ((Address & 0xf0000) >> 3)) & Memory.SRAMMask));

		case CMemory::MAP_BWRAM:
			return (Memory.BWRAM - 0x6000 + (Address & 0x7fff));

		case CMemory::MAP_SA1RAM:
			return (Memory.SRAM + (Address & 0xffff));

		case CMemory::MAP_SPC7110_ROM:
			return (S9xGetBasePointerSPC7110(Address) + (Address & 0xffff));

		case CMemory::MAP_C4:
			return (S9xGetMemPointerC4(Address & 0xffff));

		case CMemory::MAP_OBC_RAM:
			return (S9xGetMemPointerOBC1(Address & 0xffff));

		case CMemory::MAP_NONE:
		default:
			return (NULL);
	}
}

#endif
