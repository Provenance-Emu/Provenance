/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#include "snes9x.h"
#include "memmap.h"
#include "seta.h"

static int	line;	// line counter


uint8 S9xGetST018 (uint32 Address)
{
	uint8	t       = 0;
	uint16	address = (uint16) Address & 0xFFFF;

	line++;

	// these roles may be flipped
	// op output
	if (address == 0x3804)
	{
		if (ST018.out_count)
		{
			t = (uint8) ST018.output[ST018.out_index];
			ST018.out_index++;
			if (ST018.out_count == ST018.out_index)
				ST018.out_count = 0;
		}
		else
			t = 0x81;
	}
	// status register
	else
	if (address == 0x3800)
		t = ST018.status;

#ifdef DEBUGGER
	printf("ST018 R: %06X %02X\n", Address, t);
#endif

	return (t);
}

void S9xSetST018 (uint8 Byte, uint32 Address)
{
	static bool	reset   = false;
	uint16		address = (uint16) Address & 0xFFFF;

#ifdef DEBUGGER
	printf("ST018 W: %06X %02X\n", Address, Byte);
#endif

	line++;

	if (!reset)
	{
		// bootup values
		ST018.waiting4command = true;
		ST018.part_command    = 0;
		reset = true;
	}

	Memory.SRAM[address] = Byte;

	// default status for now
	ST018.status = 0x00;

	// op data goes through this address
	if (address == 0x3804)
	{
		// check for new commands: 3 bytes length
		if (ST018.waiting4command && ST018.part_command == 2)
		{
			ST018.waiting4command = false;
			ST018.in_index        = 0;
			ST018.out_index       = 0;
			ST018.part_command    = 0; // 3-byte commands
			ST018.pass            = 0; // data streams into the chip
			ST018.command <<= 8;
			ST018.command |= Byte;

			switch (ST018.command & 0xFFFFFF)
			{
				case 0x0100: ST018.in_count        = 0;    break;
				case 0xFF00: ST018.in_count        = 0;    break;
				default:     ST018.waiting4command = true; break;
			}
		}
		else
		if (ST018.waiting4command)
		{
			// 3-byte commands
			ST018.part_command++;
			ST018.command <<= 8;
			ST018.command |= Byte;
		}
	}
	// extra parameters
	else
	if (address == 0x3802)
	{
		ST018.parameters[ST018.in_index] = Byte;
		ST018.in_index++;
	}

	if (ST018.in_count == ST018.in_index)
	{
		// qctually execute the command
		ST018.waiting4command = true;
		ST018.in_index        = 0;
		ST018.out_index       = 0;

		switch (ST018.command)
		{
			// hardware check?
			case 0x0100:
				ST018.waiting4command = false;
				ST018.pass++;

				if (ST018.pass == 1)
				{
					ST018.in_count  = 1;
					ST018.out_count = 2;

					// Overload's research
					ST018.output[0x00] = 0x81;
					ST018.output[0x01] = 0x81;
				}
				else
				{
					//ST018.in_count = 1;
					ST018.out_count = 3;

					// no reason to change this
					//ST018.output[0x00] = 0x81;
					//ST018.output[0x01] = 0x81;
					ST018.output[0x02] = 0x81;

					// done processing requests
					if (ST018.pass == 3)
						ST018.waiting4command = true;
				}

				break;

			// unknown: feels like a security detection
			// format identical to 0x0100
			case 0xFF00:
				ST018.waiting4command = false;
				ST018.pass++;

				if (ST018.pass == 1)
				{
					ST018.in_count  = 1;
					ST018.out_count = 2;

					// Overload's research
					ST018.output[0x00] = 0x81;
					ST018.output[0x01] = 0x81;
				}
				else
				{
					//ST018.in_count = 1;
					ST018.out_count = 3;

					// no reason to change this
					//ST018.output[0x00] = 0x81;
					//ST018.output[0x01] = 0x81;
					ST018.output[0x02] = 0x81;

					// done processing requests
					if (ST018.pass == 3)
						ST018.waiting4command = true;
				}

				break;
		}
	}
}
