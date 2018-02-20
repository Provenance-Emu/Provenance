// Copyright (c) 2017-Present Stefan Eschenbacher. All rights reserved.
//
// This ARMv8 CRC32 code, is dual-licensed under GNU General Public License 
// version 2 ("GPL") and the Apache License version 2 ("ASL"). For the GPL, 
// please see LICENSE. For the ASL, you may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// This software is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY KIND,
// either express or implied. See the LICENSE file for specific language governing
// rights and limitations of this software.

#include "CRC.h"
#include <arm_acle.h>

void CRC_Init()
{
}

u32 CRC_Calculate( u32 crc, const void * buffer, u32 count )
{
	u8 *p;
	u32 orig = crc;

	p = (u8*) buffer;

	// use eight byte crc intrinsic __crc32d if count is high enough.
	// __crc32d, __crc32w, __crc32h and __crc32b use polynomial 0x04C11DB7
	while (count >= 8) {
		crc = __crc32d(crc, *((u64*)p));
		p += 8;
		count -= 8;
	}
	if (count >= 4) {
		crc = __crc32w(crc, *((u32*)p));
		p += 4;
		count -= 4;
	}
	if (count >= 2) {
		crc = __crc32h(crc, *((u16*)p));
		p += 2;
		count -= 2;
	}
	if (count == 1)
		crc = __crc32b(crc, *p);

	return crc ^ orig;
}

u32 CRC_Calculate_Strict( u32 crc, const void * buffer, u32 count )
{
	return CRC_Calculate(crc, buffer, count);
}

u32 CRC_CalculatePalette(u32 crc, const void * buffer, u32 count )
{
	u8 *p;
	u32 orig = crc;

	p = (u8*) buffer;
	while (count--) {
		// use two byte intrinsic __crc32h
		crc = __crc32h(crc, *((u16*)p));
		p += 8;
	}

	return crc ^ orig;
}
