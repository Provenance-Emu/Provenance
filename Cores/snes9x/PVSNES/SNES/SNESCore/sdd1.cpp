/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#include "snes9x.h"
#include "memmap.h"
#include "sdd1.h"
#include "display.h"


void S9xSetSDD1MemoryMap (uint32 bank, uint32 value)
{
	bank = 0xc00 + bank * 0x100;
	value = value * 1024 * 1024;

	for (int c = 0; c < 0x100; c += 16)
	{
		uint8	*block = &Memory.ROM[value + (c << 12)];
		for (int i = c; i < c + 16; i++)
			Memory.Map[i + bank] = block;
	}
}

void S9xResetSDD1 (void)
{
	memset(&Memory.FillRAM[0x4800], 0, 4);
	for (int i = 0; i < 4; i++)
	{
		Memory.FillRAM[0x4804 + i] = i;
		S9xSetSDD1MemoryMap(i, i);
	}
}

void S9xSDD1PostLoadState (void)
{
	for (int i = 0; i < 4; i++)
		S9xSetSDD1MemoryMap(i, Memory.FillRAM[0x4804 + i]);
}
