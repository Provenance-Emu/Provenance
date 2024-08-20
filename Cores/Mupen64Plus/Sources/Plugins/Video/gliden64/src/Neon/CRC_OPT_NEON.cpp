#include "CRC.h"
#include "xxHash/xxhash.h"
#include <arm_neon.h>

#define CRC32_POLYNOMIAL	 0x04C11DB7

unsigned int CRCTable[256];

static
u32 Reflect(u32 ref, char ch) {
	u32 value = 0;

	// Swap bit 0 for bit 7
	// bit 1 for bit 6, etc.
	for (int i = 1; i < (ch + 1); ++i) {
		if (ref & 1)
			value |= 1 << (ch - i);
		ref >>= 1;
	}
	return value;
}

void CRC_Init() {
	u32 crc;

	for (int i = 0; i < 256; ++i) {
		crc = Reflect(i, 8) << 24;
		for (int j = 0; j < 8; ++j)
			crc = (crc << 1) ^ (crc & (1 << 31) ? CRC32_POLYNOMIAL : 0);

		CRCTable[i] = Reflect(crc, 32);
	}
}

u32 CRC_Calculate_Strict(u32 crc, const void *buffer, u32 count) {
	u8 *p;
	u32 orig = crc;

	p = (u8 *) buffer;
	while (count--)
		crc = (crc >> 8) ^ CRCTable[(crc & 0xFF) ^ *p++];

	return crc ^ orig;
}

#define PRIME32_1   2654435761U
#define PRIME32_2   2246822519U
#define PRIME32_3   3266489917U
#define PRIME32_4	668265263U
#define PRIME32_5	374761393U

#if defined(_MSC_VER)
#  define XXH_rotl32(x,r) _rotl(x,r)
#else
#  define XXH_rotl32(x, r) ((x << r) | (x >> (32 - r)))
#endif

u32 ReliableHash32NEON(const void *input, size_t len, u32 seed) {
	if (((uintptr_t) input & 3) != 0) {
		// Cannot handle misaligned data. Fall back to XXH32.
		return XXH32(input, len, seed);
	}

	const u8 *p = (const u8 *) input;
	const u8 *const bEnd = p + len;
	u32 h32;


	if (len >= 16) {
		const unsigned char *const limit = bEnd - 16;
		u32 v1 = seed + PRIME32_1 + PRIME32_2;
		u32 v2 = seed + PRIME32_2;
		u32 v3 = seed + 0;
		u32 v4 = seed - PRIME32_1;

		uint32x4_t prime32_1q = vdupq_n_u32(PRIME32_1);
		uint32x4_t prime32_2q = vdupq_n_u32(PRIME32_2);
		uint32x4_t vq = vcombine_u32(vcreate_u32(v1 | ((u64) v2 << 32)),
									 vcreate_u32(v3 | ((u64) v4 << 32)));

		do {
			__builtin_prefetch(p + 0xc0, 0, 0);
			vq = vmlaq_u32(vq, vld1q_u32((const u32 *) p), prime32_2q);
			vq = vorrq_u32(vshlq_n_u32(vq, 13), vshrq_n_u32(vq, 32 - 13));
			p += 16;
			vq = vmulq_u32(vq, prime32_1q);
		} while (p <= limit);

		v1 = vgetq_lane_u32(vq, 0);
		v2 = vgetq_lane_u32(vq, 1);
		v3 = vgetq_lane_u32(vq, 2);
		v4 = vgetq_lane_u32(vq, 3);

		h32 = XXH_rotl32(v1, 1) + XXH_rotl32(v2, 7) + XXH_rotl32(v3, 12) + XXH_rotl32(v4, 18);
	} else {
		h32 = seed + PRIME32_5;
	}

	h32 += (u32) len;

	while (p <= bEnd - 4) {
		h32 += *(const u32 *) p * PRIME32_3;
		h32 = XXH_rotl32(h32, 17) * PRIME32_4;
		p += 4;
	}

	while (p < bEnd) {
		h32 += (*p) * PRIME32_5;
		h32 = XXH_rotl32(h32, 11) * PRIME32_1;
		p++;
	}

	h32 ^= h32 >> 15;
	h32 *= PRIME32_2;
	h32 ^= h32 >> 13;
	h32 *= PRIME32_3;
	h32 ^= h32 >> 16;

	return h32;
}

u32 CRC_Calculate(u32 crc, const void *buffer, u32 count) {
	return ReliableHash32NEON(buffer, count, crc);
}

u32 CRC_CalculatePalette(u32 crc, const void *buffer, u32 count) {
	u8 *p = (u8 *) buffer;
	while (count--) {
		crc = ReliableHash32NEON(p, 2, crc);
		p += 8;
	}
	return crc;
}
