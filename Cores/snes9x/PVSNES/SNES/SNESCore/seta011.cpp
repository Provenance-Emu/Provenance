/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#include "snes9x.h"
#include "memmap.h"
#include "seta.h"

static uint8	board[9][9];	// shougi playboard
static int		line = 0;		// line counter


uint8 S9xGetST011 (uint32 Address)
{
	uint8	t;
	uint16	address = (uint16) Address & 0xFFFF;

	line++;

	// status check
	if (address == 0x01)
		t = 0xFF;	
	else
		t = Memory.SRAM[address]; // read directly from s-ram

#ifdef DEBUGGER
	if (address < 0x150)
		printf("ST011 R: %06X %02X\n", Address, t);
#endif

	return (t);
}

void S9xSetST011 (uint32 Address, uint8 Byte)
{
	static bool	reset   = false;
	uint16		address = (uint16) Address & 0xFFFF;

	line++;

	if (!reset)
	{
		// bootup values
		ST011.waiting4command = true;
		reset = true;
	}

#ifdef DEBUGGER
	if (address < 0x150)
		printf("ST011 W: %06X %02X\n", Address, Byte);
#endif

	Memory.SRAM[address] = Byte;

	// op commands/data goes through this address
	if (address == 0x00)
	{
		// check for new commands
		if (ST011.waiting4command)
		{
			ST011.waiting4command = false;
			ST011.command         = Byte;
			ST011.in_index        = 0;
			ST011.out_index       = 0;

			switch (ST011.command)
			{
				case 0x01: ST011.in_count = 12 * 10 + 8; break;
				case 0x02: ST011.in_count = 4;           break;
				case 0x04: ST011.in_count = 0;           break;
				case 0x05: ST011.in_count = 0;           break;
				case 0x06: ST011.in_count = 0;           break;
				case 0x07: ST011.in_count = 0;           break;
				case 0x0E: ST011.in_count = 0;           break;
				default:   ST011.waiting4command = true; break;
			}
		}
		else
		{
			ST011.parameters[ST011.in_index] = Byte;
			ST011.in_index++;
		}
	}

	if (ST011.in_count == ST011.in_index)
	{
		// actually execute the command
		ST011.waiting4command = true;
		ST011.out_index       = 0;

		switch (ST011.command)
		{
			// unknown: download playboard
			case 0x01:
				// 9x9 board data: top to bottom, left to right
				// Values represent piece types and ownership
				for (int lcv = 0; lcv < 9; lcv++)
					memcpy(board[lcv], ST011.parameters + lcv * 10, 9 * 1);
				break;

			// unknown
			case 0x02:
				break;

			// unknown
			case 0x04:
				// outputs
				Memory.SRAM[0x12C] = 0x00;
				//Memory.SRAM[0x12D] = 0x00;
				Memory.SRAM[0x12E] = 0x00;
				break;

			// unknown
			case 0x05:
				// outputs
				Memory.SRAM[0x12C] = 0x00;
				//Memory.SRAM[0x12D] = 0x00;
				Memory.SRAM[0x12E] = 0x00;
				break;

			// unknown
			case 0x06:
				break;

			case 0x07:
				break;

			// unknown
			case 0x0E:
				// outputs
				Memory.SRAM[0x12C] = 0x00;
				Memory.SRAM[0x12D] = 0x00;
				break;
		}
	}
}
