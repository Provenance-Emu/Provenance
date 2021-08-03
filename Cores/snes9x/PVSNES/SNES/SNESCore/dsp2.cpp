/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#include "snes9x.h"
#include "memmap.h"

static void DSP2_Op01 (void);
static void DSP2_Op03 (void);
static void DSP2_Op05 (void);
static void DSP2_Op06 (void);
static void DSP2_Op09 (void);
static void DSP2_Op0D (void);


// convert bitmap to bitplane tile
static void DSP2_Op01 (void)
{
	// Op01 size is always 32 bytes input and output
	// The hardware does strange things if you vary the size

	uint8	c0, c1, c2, c3;
	uint8	*p1  = DSP2.parameters;
	uint8	*p2a = DSP2.output;
	uint8	*p2b = DSP2.output + 16; // halfway

	// Process 8 blocks of 4 bytes each

	for (int j = 0; j < 8; j++)
	{
		c0 = *p1++;
		c1 = *p1++;
		c2 = *p1++;
		c3 = *p1++;

		*p2a++ = (c0 & 0x10) << 3 |
				 (c0 & 0x01) << 6 |
				 (c1 & 0x10) << 1 |
				 (c1 & 0x01) << 4 |
				 (c2 & 0x10) >> 1 |
				 (c2 & 0x01) << 2 |
				 (c3 & 0x10) >> 3 |
				 (c3 & 0x01);

		*p2a++ = (c0 & 0x20) << 2 |
				 (c0 & 0x02) << 5 |
				 (c1 & 0x20)      |
				 (c1 & 0x02) << 3 |
				 (c2 & 0x20) >> 2 |
				 (c2 & 0x02) << 1 |
				 (c3 & 0x20) >> 4 |
				 (c3 & 0x02) >> 1;

		*p2b++ = (c0 & 0x40) << 1 |
				 (c0 & 0x04) << 4 |
				 (c1 & 0x40) >> 1 |
				 (c1 & 0x04) << 2 |
				 (c2 & 0x40) >> 3 |
				 (c2 & 0x04)      |
				 (c3 & 0x40) >> 5 |
				 (c3 & 0x04) >> 2;

		*p2b++ = (c0 & 0x80)      |
				 (c0 & 0x08) << 3 |
				 (c1 & 0x80) >> 2 |
				 (c1 & 0x08) << 1 |
				 (c2 & 0x80) >> 4 |
				 (c2 & 0x08) >> 1 |
				 (c3 & 0x80) >> 6 |
				 (c3 & 0x08) >> 3;
	}
}

// set transparent color
static void DSP2_Op03 (void)
{
	DSP2.Op05Transparent = DSP2.parameters[0];
}

// replace bitmap using transparent color
static void DSP2_Op05 (void)
{
	// Overlay bitmap with transparency.
	// Input:
	//
	//   Bitmap 1:  i[0] <=> i[size-1]
	//   Bitmap 2:  i[size] <=> i[2*size-1]
	//
	// Output:
	//
	//   Bitmap 3:  o[0] <=> o[size-1]
	//
	// Processing:
	//
	//   Process all 4-bit pixels (nibbles) in the bitmap
	//
	//   if ( BM2_pixel == transparent_color )
	//      pixelout = BM1_pixel
	//   else
	//      pixelout = BM2_pixel

	// The max size bitmap is limited to 255 because the size parameter is a byte
	// I think size=0 is an error.  The behavior of the chip on size=0 is to
	// return the last value written to DR if you read DR on Op05 with
	// size = 0.  I don't think it's worth implementing this quirk unless it's
	// proven necessary.

	uint8	color;
	uint8	c1, c2;
	uint8	*p1 = DSP2.parameters;
	uint8	*p2 = DSP2.parameters + DSP2.Op05Len;
	uint8	*p3 = DSP2.output;

	color = DSP2.Op05Transparent & 0x0f;

	for (int32 n = 0; n < DSP2.Op05Len; n++)
	{
		c1 = *p1++;
		c2 = *p2++;
		*p3++ = (((c2 >> 4) == color) ? c1 & 0xf0: c2 & 0xf0) | (((c2 & 0x0f) == color) ? c1 & 0x0f: c2 & 0x0f);
	}
}

// reverse bitmap
static void DSP2_Op06 (void)
{
	// Input:
	//    size
	//    bitmap

	for (int32 i = 0, j = DSP2.Op06Len - 1; i < DSP2.Op06Len; i++, j--)
		DSP2.output[j] = (DSP2.parameters[i] << 4) | (DSP2.parameters[i] >> 4);
}

// multiply
static void DSP2_Op09 (void)
{
	DSP2.Op09Word1 = DSP2.parameters[0] | (DSP2.parameters[1] << 8);
	DSP2.Op09Word2 = DSP2.parameters[2] | (DSP2.parameters[3] << 8);

	uint32	temp = DSP2.Op09Word1 * DSP2.Op09Word2;
	DSP2.output[0] =  temp        & 0xFF;
	DSP2.output[1] = (temp >>  8) & 0xFF;
	DSP2.output[2] = (temp >> 16) & 0xFF;
	DSP2.output[3] = (temp >> 24) & 0xFF;
}

// scale bitmap
static void DSP2_Op0D (void)
{
	// Bit accurate hardware algorithm - uses fixed point math
	// This should match the DSP2 Op0D output exactly
	// I wouldn't recommend using this unless you're doing hardware debug.
	// In some situations it has small visual artifacts that
	// are not readily apparent on a TV screen but show up clearly
	// on a monitor.  Use Overload's scaling instead.
	// This is for hardware verification testing.
	//
	// One note:  the HW can do odd byte scaling but since we divide
	// by two to get the count of bytes this won't work well for
	// odd byte scaling (in any of the current algorithm implementations).
	// So far I haven't seen Dungeon Master use it.
	// If it does we can adjust the parameters and code to work with it

	uint32	multiplier; // Any size int >= 32-bits
	uint32	pixloc;	    // match size of multiplier
	uint8	pixelarray[512];

	if (DSP2.Op0DInLen <= DSP2.Op0DOutLen)
		multiplier = 0x10000; // In our self defined fixed point 0x10000 == 1
	else
		multiplier = (DSP2.Op0DInLen << 17) / ((DSP2.Op0DOutLen << 1) + 1);

	pixloc = 0;

	for (int32 i = 0; i < DSP2.Op0DOutLen * 2; i++)
	{
		int32	j = pixloc >> 16;

		if (j & 1)
			pixelarray[i] =  DSP2.parameters[j >> 1] & 0x0f;
		else
			pixelarray[i] = (DSP2.parameters[j >> 1] & 0xf0) >> 4;

		pixloc += multiplier;
	}

	for (int32 i = 0; i < DSP2.Op0DOutLen; i++)
		DSP2.output[i] = (pixelarray[i << 1] << 4) | pixelarray[(i << 1) + 1];
}

/*
static void DSP2_Op0D (void)
{
	// Overload's algorithm - use this unless doing hardware testing

	// One note:  the HW can do odd byte scaling but since we divide
	// by two to get the count of bytes this won't work well for
	// odd byte scaling (in any of the current algorithm implementations).
	// So far I haven't seen Dungeon Master use it.
	// If it does we can adjust the parameters and code to work with it

	int32	pixel_offset;
	uint8	pixelarray[512];

	for (int32 i = 0; i < DSP2.Op0DOutLen * 2; i++)
	{
		pixel_offset = (i * DSP2.Op0DInLen) / DSP2.Op0DOutLen;

		if ((pixel_offset & 1) == 0)
			pixelarray[i] = DSP2.parameters[pixel_offset >> 1] >> 4;
		else
			pixelarray[i] = DSP2.parameters[pixel_offset >> 1] & 0x0f;
	}

	for (int32 i = 0; i < DSP2.Op0DOutLen; i++)
		DSP2.output[i] = (pixelarray[i << 1] << 4) | pixelarray[(i << 1) + 1];
}
*/

void DSP2SetByte (uint8 byte, uint16 address)
{
	if ((address & 0xf000) == 0x6000 || (address >= 0x8000 && address < 0xc000))
	{
		if (DSP2.waiting4command)
		{
			DSP2.command         = byte;
			DSP2.in_index        = 0;
			DSP2.waiting4command = FALSE;

			switch (byte)
			{
				case 0x01: DSP2.in_count = 32; break;
				case 0x03: DSP2.in_count =  1; break;
				case 0x05: DSP2.in_count =  1; break;
				case 0x06: DSP2.in_count =  1; break;
				case 0x09: DSP2.in_count =  4; break;
				case 0x0D: DSP2.in_count =  2; break;
				default:
				#ifdef DEBUGGER
					//printf("Op%02X\n", byte);
				#endif
				case 0x0f: DSP2.in_count =  0; break;
			}
		}
		else
		{
			DSP2.parameters[DSP2.in_index] = byte;
			DSP2.in_index++;
		}

		if (DSP2.in_count == DSP2.in_index)
		{
			DSP2.waiting4command = TRUE;
			DSP2.out_index       = 0;

			switch (DSP2.command)
			{
				case 0x01:
					DSP2.out_count = 32;
					DSP2_Op01();
					break;

				case 0x03:
					DSP2_Op03();
					break;

				case 0x05:
					if (DSP2.Op05HasLen)
					{
						DSP2.Op05HasLen = FALSE;
						DSP2.out_count  = DSP2.Op05Len;
						DSP2_Op05();
					}
					else
					{
						DSP2.Op05Len    = DSP2.parameters[0];
						DSP2.in_index   = 0;
						DSP2.in_count   = 2 * DSP2.Op05Len;
						DSP2.Op05HasLen = TRUE;
						if (byte)
							DSP2.waiting4command = FALSE;
					}

					break;

				case 0x06:
					if (DSP2.Op06HasLen)
					{
						DSP2.Op06HasLen = FALSE;
						DSP2.out_count  = DSP2.Op06Len;
						DSP2_Op06();
					}
					else
					{
						DSP2.Op06Len    = DSP2.parameters[0];
						DSP2.in_index   = 0;
						DSP2.in_count   = DSP2.Op06Len;
						DSP2.Op06HasLen = TRUE;
						if (byte)
							DSP2.waiting4command = FALSE;
					}

					break;

				case 0x09:
					DSP2.out_count = 4;
					DSP2_Op09();
					break;

				case 0x0D:
					if (DSP2.Op0DHasLen)
					{
						DSP2.Op0DHasLen = FALSE;
						DSP2.out_count  = DSP2.Op0DOutLen;
						DSP2_Op0D();
					}
					else
					{
						DSP2.Op0DInLen  = DSP2.parameters[0];
						DSP2.Op0DOutLen = DSP2.parameters[1];
						DSP2.in_index   = 0;
						DSP2.in_count   = (DSP2.Op0DInLen + 1) >> 1;
						DSP2.Op0DHasLen = TRUE;
						if (byte)
							DSP2.waiting4command = FALSE;
					}

					break;

				case 0x0f:
				default:
					break;
			}
		}
	}
}

uint8 DSP2GetByte (uint16 address)
{
	uint8	t;

	if ((address & 0xf000) == 0x6000 || (address >= 0x8000 && address < 0xc000))
	{
		if (DSP2.out_count)
		{
			t = (uint8) DSP2.output[DSP2.out_index];
			DSP2.out_index++;
			if (DSP2.out_count == DSP2.out_index)
				DSP2.out_count = 0;
		}
		else
			t = 0xff;
	}
	else
		t = 0x80;

	return (t);
}
