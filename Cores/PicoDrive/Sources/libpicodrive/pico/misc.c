/*
 * rarely used EEPROM code
 * (C) notaz, 2006-2008
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include "pico_int.h"


#ifndef _ASM_MISC_C
PICO_INTERNAL_ASM void memcpy16bswap(unsigned short *dest, void *src, int count)
{
	unsigned char *src_ = src;

	for (; count; count--, src_ += 2)
		*dest++ = (src_[0] << 8) | src_[1];
}

#ifndef _ASM_MISC_C_AMIPS
PICO_INTERNAL_ASM void memset32(void *dest_in, int c, int count)
{
	int *dest = dest_in;

	for (; count >= 8; count -= 8, dest += 8)
		dest[0] = dest[1] = dest[2] = dest[3] =
		dest[4] = dest[5] = dest[6] = dest[7] = c;

	switch (count) {
		case 7: *dest++ = c;
		case 6: *dest++ = c;
		case 5: *dest++ = c;
		case 4: *dest++ = c;
		case 3: *dest++ = c;
		case 2: *dest++ = c;
		case 1: *dest++ = c;
	}
}
void memset32_uncached(int *dest, int c, int count) { memset32(dest, c, count); }
#endif
#endif

