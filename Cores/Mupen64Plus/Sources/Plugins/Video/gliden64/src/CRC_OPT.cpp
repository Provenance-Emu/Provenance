#include "CRC.h"
#include "xxHash/xxhash.h"

#define CRC32_POLYNOMIAL     0x04C11DB7

unsigned int CRCTable[ 256 ];

static
u32 Reflect( u32 ref, char ch )
{
	 u32 value = 0;

	 // Swap bit 0 for bit 7
	 // bit 1 for bit 6, etc.
	 for (int i = 1; i < (ch + 1); ++i) {
		  if(ref & 1)
			value |= 1 << (ch - i);
		  ref >>= 1;
	 }
	 return value;
}

void CRC_Init()
{
	u32 crc;

	for (int i = 0; i < 256; ++i) {
		crc = Reflect( i, 8 ) << 24;
		for (int j = 0; j < 8; ++j)
			crc = (crc << 1) ^ (crc & (1 << 31) ? CRC32_POLYNOMIAL : 0);

		CRCTable[i] = Reflect( crc, 32 );
	}
}

u32 CRC_Calculate_Strict( u32 crc, const void * buffer, u32 count )
{
	u8 *p;
	u32 orig = crc;

	p = (u8*) buffer;
	while (count--)
		crc = (crc >> 8) ^ CRCTable[(crc & 0xFF) ^ *p++];

	return crc ^ orig;
}

u32 CRC_Calculate( u32 crc, const void * buffer, u32 count )
{
	return XXH32(buffer, count, crc);
}

u32 CRC_CalculatePalette(u32 crc, const void * buffer, u32 count )
{
	u8 *p = (u8*) buffer;
	while (count--) {
		crc = XXH32(p, 2, crc);
		p += 8;
	}
	return crc;
}
