/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#include "snes9x.h"
#include "memmap.h"


uint8 S9xGetOBC1 (uint16 Address)
{
	switch (Address)
	{
		case 0x7ff0:
			return (Memory.OBC1RAM[OBC1.basePtr + (OBC1.address << 2)]);

		case 0x7ff1:
			return (Memory.OBC1RAM[OBC1.basePtr + (OBC1.address << 2) + 1]);

		case 0x7ff2:
			return (Memory.OBC1RAM[OBC1.basePtr + (OBC1.address << 2) + 2]);

		case 0x7ff3:
			return (Memory.OBC1RAM[OBC1.basePtr + (OBC1.address << 2) + 3]);

		case 0x7ff4:
			return (Memory.OBC1RAM[OBC1.basePtr + (OBC1.address >> 2) + 0x200]);
	}

	return (Memory.OBC1RAM[Address - 0x6000]);
}

void S9xSetOBC1 (uint8 Byte, uint16 Address)
{
	switch (Address)
	{
		case 0x7ff0:
			Memory.OBC1RAM[OBC1.basePtr + (OBC1.address << 2)] = Byte;
			break;

		case 0x7ff1:
			Memory.OBC1RAM[OBC1.basePtr + (OBC1.address << 2) + 1] = Byte;
			break;

		case 0x7ff2:
			Memory.OBC1RAM[OBC1.basePtr + (OBC1.address << 2) + 2] = Byte;
			break;

		case 0x7ff3:
			Memory.OBC1RAM[OBC1.basePtr + (OBC1.address << 2) + 3] = Byte;
			break;

		case 0x7ff4:
		{
			uint8 Temp;
			Temp = Memory.OBC1RAM[OBC1.basePtr + (OBC1.address >> 2) + 0x200];
			Temp = (Temp & ~(3 << OBC1.shift)) | ((Byte & 3) << OBC1.shift);
			Memory.OBC1RAM[OBC1.basePtr + (OBC1.address >> 2) + 0x200] = Temp;
			break;
		}

		case 0x7ff5:
			if (Byte & 1)
				OBC1.basePtr = 0x1800;
			else
				OBC1.basePtr = 0x1c00;
			break;

		case 0x7ff6:
			OBC1.address = Byte & 0x7f;
			OBC1.shift = (Byte & 3) << 1;
			break;
	}

	Memory.OBC1RAM[Address - 0x6000] = Byte;
}

void S9xResetOBC1 (void)
{
	for (int i = 0; i <= 0x1fff; i++)
		Memory.OBC1RAM[i] = 0xff;

	if (Memory.OBC1RAM[0x1ff5] & 1)
		OBC1.basePtr = 0x1800;
	else
		OBC1.basePtr = 0x1c00;

	OBC1.address = Memory.OBC1RAM[0x1ff6] & 0x7f;
	OBC1.shift = (Memory.OBC1RAM[0x1ff6] & 3) << 1;
}

uint8 * S9xGetBasePointerOBC1 (uint16 Address)
{
	if (Address >= 0x7ff0 && Address <= 0x7ff6)
		return (NULL);
	return (Memory.OBC1RAM - 0x6000);
}

uint8 * S9xGetMemPointerOBC1 (uint16 Address)
{
	if (Address >= 0x7ff0 && Address <= 0x7ff6)
		return (NULL);
	return (Memory.OBC1RAM + Address - 0x6000);
}
