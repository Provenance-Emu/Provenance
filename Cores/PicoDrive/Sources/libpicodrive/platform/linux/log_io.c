/*
 * PicoDrive
 * (C) notaz, 2007
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */
#include <stdio.h>

typedef struct
{
	unsigned int addr_min, addr_max;
	int r8, r16, r32, w8, w16, w32;
} io_log_location;

static io_log_location io_locations[] =
{
	{ 0x400000, 0x9FFFFF, 0, }, // unused
	{ 0xa00000, 0xa03fff, 0, }, // z80 RAM
	{ 0xa04000, 0xa05fff, 0, }, // ym2612
	{ 0xa06000, 0xa060ff, 0, }, // bank reg
	{ 0xa06100, 0xa07eff, 0, }, // unused
	{ 0xa07f00, 0xa07fff, 0, }, // vdp
	{ 0xa08000, 0xa0ffff, 0, }, // 0xa00000-0xa07fff mirror
	{ 0xa10000, 0xa1001f, 0, }, // i/o
	{ 0xa10020, 0xa10fff, 0, }, // expansion
	{ 0xa11000, 0xa110ff, 0, }, // expansion
	{ 0xa11100, 0xa11101, 0, }, // z80 busreq
	{ 0xa11102, 0xa111ff, 0, }, // expansion
	{ 0xa11200, 0xa11201, 0, }, // z80 reset
	{ 0xa11202, 0xbfffff, 0, }, // expansion
	{ 0xc00000, 0xc00003, 0, }, // vdp data port
	{ 0xc00004, 0xc00007, 0, }, // vdp control
	{ 0xc00009, 0xc0000f, 0, }, // hv counter
	{ 0xc00010, 0xc00017, 0, }, // PSG
	{ 0xc00018, 0xc0001f, 0, }, // unused
	{ 0xc00020, 0xdfffff, 0, }  // vdp mirrors
};


void log_io(unsigned int a, int bits, int is_write)
{
	int i;
	a &= 0x00ffffff;
	if (bits > 8) a&=~1;

	for (i = 0; i < sizeof(io_locations)/sizeof(io_locations[0]); i++)
	{
		if (a >= io_locations[i].addr_min && a <= io_locations[i].addr_max)
		{
			switch (bits|(is_write<<8)) {
				case 0x008: io_locations[i].r8 ++; break;
				case 0x010: io_locations[i].r16++; break;
				case 0x020: io_locations[i].r32++; break;
				case 0x108: io_locations[i].w8 ++; break;
				case 0x110: io_locations[i].w16++; break;
				case 0x120: io_locations[i].w32++; break;
				default:    printf("%06x %i %i\n", a, bits, is_write); break;
			}
		}
	}
}

void log_io_clear(void)
{
	int i;
	for (i = 0; i < sizeof(io_locations)/sizeof(io_locations[0]); i++)
	{
		io_log_location *iol = &io_locations[i];
		iol->r8 = iol->r16 = iol->r32 = iol->w8 = iol->w16 = iol->w32 = 0;
	}
}

void log_io_dump(void)
{
	int i;
	printf("          range :       r8      r16      r32       w8      w16      w32\n");
	for (i = 0; i < sizeof(io_locations)/sizeof(io_locations[0]); i++)
	{
		io_log_location *iol = &io_locations[i];
		if (iol->r8 == 0 && iol->r16 == 0 && iol->r32 == 0 && iol->w8 == 0 && iol->w16 == 0 && iol->w32 == 0)
			continue;
		printf("%06x - %06x : %8i %8i %8i %8i %8i %8i\n", iol->addr_min, iol->addr_max,
			iol->r8, iol->r16, iol->r32, iol->w8, iol->w16, iol->w32);
	}
	printf("\n");
}

