#ifndef CONVERT_H
#define CONVERT_H

#include "Types.h"

extern const volatile unsigned char Five2Eight[32];
extern const volatile unsigned char Four2Eight[16];
extern const volatile unsigned char Three2Four[8];
extern const volatile unsigned char Three2Eight[8];
extern const volatile unsigned char Two2Eight[4];
extern const volatile unsigned char One2Four[2];
extern const volatile unsigned char One2Eight[2];

void UnswapCopyWrap(const u8 *src, u32 srcIdx, u8 *dest, u32 destIdx, u32 destMask, u32 numBytes);

void DWordInterleaveWrap(u32 *src, u32 srcIdx, u32 srcMask, u32 numQWords);

inline u16 swapword( u16 value )
{
#ifdef WIN32_ASM
	__asm
	{
		mov		ax, word ptr [value]
		xchg	ah, al
	}
#else // WIN32_ASM
	return (value << 8) | (value >> 8);
#endif // WIN32_ASM
}

inline u16 RGBA8888_RGBA4444( u32 color )
{
#ifdef WIN32_ASM
	__asm
	{
		mov		ebx, dword ptr [color]
		// R
		and		bl, 0F0h
		mov		ah, bl

		// G
		shr		bh, 4
		or		ah, bh

		bswap	ebx

		// B
		and		bh, 0F0h
		mov		al, bh

		// A
		shr		bl, 4
		or		al, bl
	}
#else // WIN32_ASM
	return ((color & 0x000000f0) <<  8) |	// r
			((color & 0x0000f000) >>  4) |	// g
			((color & 0x00f00000) >> 16) |	// b
			((color & 0xf0000000) >> 28);	// a
#endif // WIN32_ASM
}

inline u32 RGBA5551_RGBA8888( u16 color )
{
#ifdef WIN32_ASM
	__asm
	{
		mov		ebx, 00000000h
		mov		cx, word ptr [color]
		xchg	cl, ch

		mov		bx, cx
		and		bx, 01h
        mov		al, byte ptr [One2Eight+ebx]

		mov		bx, cx
		shr		bx, 01h
		and		bx, 1Fh
		mov		ah, byte ptr [Five2Eight+ebx]

		bswap	eax

		mov		bx, cx
		shr		bx, 06h
		and		bx, 1Fh
		mov		ah, byte ptr [Five2Eight+ebx]

		mov		bx, cx
		shr		bx, 0Bh
		and		bx, 1Fh
		mov		al, byte ptr [Five2Eight+ebx]
	}
#else // WIN32_ASM
	color = swapword( color );
	u8 r, g, b, a;
	r = Five2Eight[color >> 11];
	g = Five2Eight[(color >> 6) & 0x001f];
	b = Five2Eight[(color >> 1) & 0x001f];
	a = One2Eight [(color     ) & 0x0001];
	return (a << 24) | (b << 16) | (g << 8) | r;
#endif // WIN32_ASM
}

// Just swaps the word
inline u16 RGBA5551_RGBA5551( u16 color )
{
#ifdef WIN32_ASM
	__asm
	{
		mov		ax, word ptr [color]
		xchg	ah, al
	}
#else // WIN32_ASM
	return swapword( color );
#endif // WIN32_ASM
}

inline u32 IA88_RGBA8888( u16 color )
{
#ifdef WIN32_ASM
	__asm
	{
		mov		cx, word ptr [color]

        mov		al, ch
		mov		ah, cl

		bswap	eax

		mov		ah, cl
		mov		al, cl
	}
#else // WIN32_ASM
	// ok
	u8 a = color >> 8;
	u8 i = color & 0x00FF;
	return (a << 24) | (i << 16) | (i << 8) | i;
#endif // WIN32_ASM
}

inline u16 IA88_RGBA4444( u16 color )
{
#ifdef WIN32_ASM
	__asm
	{
		mov		cx, word ptr [color]

		shr		cl, 4
		mov		ah, cl
		shl		cl, 4
		or		ah, cl
		mov		al, cl

		shr		ch, 4
		or		al, ch
	}
#else // WIN32_ASM
	u8 a = color >> 12;
	u8 i = (color >> 4) & 0x000F;
	return (i << 12) | (i << 8) | (i << 4) | a;
#endif // WIN32_ASM
}

inline u16 IA44_RGBA4444( u8 color )
{
#ifdef WIN32_ASM
	__asm
	{
		mov		cl, byte ptr [color]
		mov		al, cl

		shr		cl, 4
		mov		ah, cl
		shl		cl, 4
		or		ah, cl
	}
#else // WIN32_ASM
	return ((color & 0xf0) << 8) | ((color & 0xf0) << 4) | (color);
#endif // WIN32_ASM
}

inline u32 IA44_RGBA8888( u8 color )
{
#ifdef WIN32_ASM
	__asm
	{
		mov		ebx, 00000000h
		mov		cl, byte ptr [color]

		mov		bl, cl
		shr		bl, 04h
		mov		ch, byte ptr [Four2Eight+ebx]

		mov		bl, cl
		and		bl, 0Fh
		mov		cl, byte ptr [Four2Eight+ebx]

        mov		al, cl
		mov		ah, ch

		bswap	eax

		mov		ah, ch
		mov		al, ch
	}
#else // WIN32_ASM
	u8 i = Four2Eight[color >> 4];
	u8 a = Four2Eight[color & 0x0F];
	return (a << 24) | (i << 16) | (i << 8) | i;
#endif // WIN32_ASM
}

inline u16 IA31_RGBA4444( u8 color )
{
#ifdef WIN32_ASM
	__asm
	{
		mov		ebx, 00000000h
		mov		cl, byte ptr [color]

		mov		bl, cl
		shr		bl, 01h
		mov		ch, byte ptr [Three2Four+ebx]
		mov		ah, ch
		shl		ch, 4
		or		ah, ch
		mov		al, ch

		mov		bl, cl
		and		bl, 01h
		mov		ch, byte ptr [One2Four+ebx]
		or		al, ch
	}
#else // WIN32_ASM
	u8 i = Three2Four[color >> 1];
	u8 a = One2Four[color & 0x01];
	return (i << 12) | (i << 8) | (i << 4) | a;
#endif // WIN32_ASM
}

inline u32 IA31_RGBA8888( u8 color )
{
#ifdef WIN32_ASM
	__asm
	{
		mov		ebx, 00000000h
		mov		cl, byte ptr [color]

		mov		bl, cl
		shr		bl, 01h
		mov		ch, byte ptr [Three2Eight+ebx]

		mov		bl, cl
		and		bl, 01h
		mov		cl, byte ptr [One2Eight+ebx]

        mov		al, cl
		mov		ah, ch

		bswap	eax

		mov		ah, ch
		mov		al, ch
	}
#else // WIN32_ASM
	u8 i = Three2Eight[color >> 1];
	u8 a = One2Eight[color & 0x01];
	return (i << 24) | (i << 16) | (i << 8) | a;
#endif // WIN32_ASM
}

inline u16 I8_RGBA4444( u8 color )
{
#ifdef WIN32_ASM
	__asm
	{
		mov		cl, byte ptr [color]

		shr		cl, 4
		mov		al, cl
		shl		cl, 4
		or		al, cl
		mov		ah, al
	}
#else // WIN32_ASM
	u8 c = color >> 4;
	return (c << 12) | (c << 8) | (c << 4) | c;
#endif // WIN32_ASM
}

inline u32 I8_RGBA8888( u8 color )
{
#ifdef WIN32_ASM
	__asm
	{
		mov		cl, byte ptr [color]

		mov		al, cl
		mov		ah, cl
		bswap	eax
		mov		ah, cl
		mov		al, cl
	}
#else // WIN32_ASM
	return (color << 24) | (color << 16) | (color << 8) | color;
#endif // WIN32_ASM
}

inline u16 I4_RGBA4444( u8 color )
{
#ifdef WIN32_ASM
	__asm
	{
		mov		cl, byte ptr [color]
		mov		al, cl
		shl		cl, 4
		or		al, cl
		mov		ah, al
	}
#else // WIN32_ASM
	u16 ret = color & 0x0f;
	ret |= ret << 4;
	ret |= ret << 8;
	return ret;
#endif // WIN32_ASM
}

inline u32 I4_RGBA8888( u8 color )
{
#ifdef WIN32_ASM
	__asm
	{
		mov		ebx, 00000000h

		mov		bl, byte ptr [color]
		mov		cl, byte ptr [Four2Eight+ebx]

        mov		al, cl
		mov		ah, cl
		bswap	eax
		mov		ah, cl
		mov		al, cl
	}
#else // WIN32_ASM
	u8 c = Four2Eight[color];
	c |= c << 4;
	return (c << 24) | (c << 16) | (c << 8) | c;
#endif // WIN32_ASM
}

#endif // CONVERT_H
