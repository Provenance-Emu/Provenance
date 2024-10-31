#include "convert.h"

const volatile unsigned char Five2Eight[32] =
{
	  0, // 00000 = 00000000
	  8, // 00001 = 00001000
	 16, // 00010 = 00010000
	 25, // 00011 = 00011001
	 33, // 00100 = 00100001
	 41, // 00101 = 00101001
	 49, // 00110 = 00110001
	 58, // 00111 = 00111010
	 66, // 01000 = 01000010
	 74, // 01001 = 01001010
	 82, // 01010 = 01010010
	 90, // 01011 = 01011010
	 99, // 01100 = 01100011
	107, // 01101 = 01101011
	115, // 01110 = 01110011
	123, // 01111 = 01111011
	132, // 10000 = 10000100
	140, // 10001 = 10001100
	148, // 10010 = 10010100
	156, // 10011 = 10011100
	165, // 10100 = 10100101
	173, // 10101 = 10101101
	181, // 10110 = 10110101
	189, // 10111 = 10111101
	197, // 11000 = 11000101
	206, // 11001 = 11001110
	214, // 11010 = 11010110
	222, // 11011 = 11011110
	230, // 11100 = 11100110
	239, // 11101 = 11101111
	247, // 11110 = 11110111
	255  // 11111 = 11111111
};

const volatile unsigned char Four2Eight[16] =
{
	  0, // 0000 = 00000000
	 17, // 0001 = 00010001
	 34, // 0010 = 00100010
	 51, // 0011 = 00110011
	 68, // 0100 = 01000100
	 85, // 0101 = 01010101
	102, // 0110 = 01100110
	119, // 0111 = 01110111
	136, // 1000 = 10001000
	153, // 1001 = 10011001
	170, // 1010 = 10101010
	187, // 1011 = 10111011
	204, // 1100 = 11001100
	221, // 1101 = 11011101
	238, // 1110 = 11101110
	255  // 1111 = 11111111
};

const volatile unsigned char Three2Four[8] =
{
	 0, // 000 = 0000
     2, // 001 = 0010
	 4, // 010 = 0100
	 6, // 011 = 0110
	 9, // 100 = 1001
	11, // 101 = 1011
    13, // 110 = 1101
	15, // 111 = 1111
};

const volatile unsigned char Three2Eight[8] =
{
	  0, // 000 = 00000000
     36, // 001 = 00100100
	 73, // 010 = 01001001
	109, // 011 = 01101101
	146, // 100 = 10010010
	182, // 101 = 10110110
    219, // 110 = 11011011
	255, // 111 = 11111111
};
const volatile unsigned char Two2Eight[4] =
{
	  0, // 00 = 00000000
	 85, // 01 = 01010101
	170, // 10 = 10101010
	255  // 11 = 11111111
};

const volatile unsigned char One2Four[2] =
{
	 0, // 0 = 0000
	15, // 1 = 1111
};

const volatile unsigned char One2Eight[2] =
{
	  0, // 0 = 00000000
	255, // 1 = 11111111
};

void UnswapCopyWrap(const u8 *src, u32 srcIdx, u8 *dest, u32 destIdx, u32 destMask, u32 numBytes)
{
	// copy leading bytes
	u32 leadingBytes = srcIdx & 3;
	if (leadingBytes != 0) {
		leadingBytes = 4 - leadingBytes;
		if ((u32)leadingBytes > numBytes)
			leadingBytes = numBytes;
		numBytes -= leadingBytes;

		srcIdx ^= 3;
		for (u32 i = 0; i < leadingBytes; i++) {
			dest[destIdx&destMask] = src[srcIdx];
			++destIdx;
			--srcIdx;
		}
		srcIdx += 5;
	}

	// copy dwords
	int numDWords = numBytes >> 2;
	while (numDWords--) {
		dest[(destIdx + 3) & destMask] = src[srcIdx++];
		dest[(destIdx + 2) & destMask] = src[srcIdx++];
		dest[(destIdx + 1) & destMask] = src[srcIdx++];
		dest[(destIdx + 0) & destMask] = src[srcIdx++];
		destIdx += 4;
	}

	// copy trailing bytes
	int trailingBytes = numBytes & 3;
	if (trailingBytes) {
		srcIdx ^= 3;
		for (int i = 0; i < trailingBytes; i++) {
			dest[destIdx&destMask] = src[srcIdx];
			++destIdx;
			--srcIdx;
		}
	}
}

void DWordInterleaveWrap(u32 *src, u32 srcIdx, u32 srcMask, u32 numQWords)
{
	u32 p0, idx0, idx1;
	while (numQWords--)	{
		idx0 = srcIdx++ & srcMask;
		idx1 = srcIdx++ & srcMask;
		p0 = src[idx0];
		src[idx0] = src[idx1];
		src[idx1] = p0;
	}
}
