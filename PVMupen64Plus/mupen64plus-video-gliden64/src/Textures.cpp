#include <assert.h>
#include <memory.h>
#include <algorithm>
#include <thread>         // std::this_thread::sleep_for
#include <chrono>         // std::chrono::seconds
#include "Platform.h"
#include "Textures.h"
#include "GBI.h"
#include "RSP.h"
#include "gDP.h"
#include "gSP.h"
#include "N64.h"
#include "convert.h"
#include "FrameBuffer.h"
#include "Config.h"
#include "Keys.h"
#include "GLideNHQ/Ext_TxFilter.h"
#include "TextureFilterHandler.h"
#include "DisplayLoadProgress.h"
#include "Graphics/Context.h"
#include "Graphics/Parameters.h"
#include "DisplayWindow.h"

using namespace std;
using namespace graphics;

inline u32 GetNone( u64 *src, u16 x, u16 i, u8 palette )
{
	return 0x00000000;
}

inline u32 GetCI4IA_RGBA4444( u64 *src, u16 x, u16 i, u8 palette )
{
	u8 color4B;

	color4B = ((u8*)src)[(x>>1)^(i<<1)];

	if (x & 1)
		return IA88_RGBA4444( *(u16*)&TMEM[256 + (palette << 4) + (color4B & 0x0F)] );
	else
		return IA88_RGBA4444( *(u16*)&TMEM[256 + (palette << 4) + (color4B >> 4)] );
}

inline u32 GetCI4IA_RGBA8888( u64 *src, u16 x, u16 i, u8 palette )
{
	u8 color4B;

	color4B = ((u8*)src)[(x>>1)^(i<<1)];

	if (x & 1)
		return IA88_RGBA8888( *(u16*)&TMEM[256 + (palette << 4) + (color4B & 0x0F)] );
	else
		return IA88_RGBA8888( *(u16*)&TMEM[256 + (palette << 4) + (color4B >> 4)] );
}

inline u32 GetCI4RGBA_RGBA5551( u64 *src, u16 x, u16 i, u8 palette )
{
	u8 color4B;

	color4B = ((u8*)src)[(x>>1)^(i<<1)];

	if (x & 1)
		return RGBA5551_RGBA5551( *(u16*)&TMEM[256 + (palette << 4) + (color4B & 0x0F)] );
	else
		return RGBA5551_RGBA5551( *(u16*)&TMEM[256 + (palette << 4) + (color4B >> 4)] );
}

inline u32 GetCI4RGBA_RGBA8888( u64 *src, u16 x, u16 i, u8 palette )
{
	u8 color4B;

	color4B = ((u8*)src)[(x>>1)^(i<<1)];

	if (x & 1)
		return RGBA5551_RGBA8888( *(u16*)&TMEM[256 + (palette << 4) + (color4B & 0x0F)] );
	else
		return RGBA5551_RGBA8888( *(u16*)&TMEM[256 + (palette << 4) + (color4B >> 4)] );
}

inline u32 GetIA31_RGBA8888( u64 *src, u16 x, u16 i, u8 palette )
{
	u8 color4B;

	color4B = ((u8*)src)[(x>>1)^(i<<1)];

	return IA31_RGBA8888( (x & 1) ? (color4B & 0x0F) : (color4B >> 4) );
}

inline u32 GetIA31_RGBA4444( u64 *src, u16 x, u16 i, u8 palette )
{
	u8 color4B;

	color4B = ((u8*)src)[(x>>1)^(i<<1)];

	return IA31_RGBA4444( (x & 1) ? (color4B & 0x0F) : (color4B >> 4) );
}

inline u32 GetI4_RGBA8888( u64 *src, u16 x, u16 i, u8 palette )
{
	u8 color4B;

	color4B = ((u8*)src)[(x>>1)^(i<<1)];

	return I4_RGBA8888( (x & 1) ? (color4B & 0x0F) : (color4B >> 4) );
}

inline u32 GetI4_RGBA4444( u64 *src, u16 x, u16 i, u8 palette )
{
	u8 color4B;

	color4B = ((u8*)src)[(x>>1)^(i<<1)];

	return I4_RGBA4444( (x & 1) ? (color4B & 0x0F) : (color4B >> 4) );
}

inline u32 GetCI8IA_RGBA4444( u64 *src, u16 x, u16 i, u8 palette )
{
	return IA88_RGBA4444( *(u16*)&TMEM[256 + ((u8*)src)[x^(i<<1)]] );
}

inline u32 GetCI8IA_RGBA8888( u64 *src, u16 x, u16 i, u8 palette )
{
	return IA88_RGBA8888( *(u16*)&TMEM[256 + ((u8*)src)[x^(i<<1)]] );
}

inline u32 GetCI8RGBA_RGBA5551( u64 *src, u16 x, u16 i, u8 palette )
{
	return RGBA5551_RGBA5551( *(u16*)&TMEM[256 + ((u8*)src)[x^(i<<1)]] );
}

inline u32 GetCI8RGBA_RGBA8888( u64 *src, u16 x, u16 i, u8 palette )
{
	return RGBA5551_RGBA8888( *(u16*)&TMEM[256 + ((u8*)src)[x^(i<<1)]] );
}

inline u32 GetIA44_RGBA8888( u64 *src, u16 x, u16 i, u8 palette )
{
	return IA44_RGBA8888(((u8*)src)[x^(i<<1)]);
}

inline u32 GetIA44_RGBA4444( u64 *src, u16 x, u16 i, u8 palette )
{
	return IA44_RGBA4444(((u8*)src)[x^(i<<1)]);
}

inline u32 GetI8_RGBA8888( u64 *src, u16 x, u16 i, u8 palette )
{
	return I8_RGBA8888(((u8*)src)[x^(i<<1)]);
}

inline u32 GetI8_RGBA4444( u64 *src, u16 x, u16 i, u8 palette )
{
	return I8_RGBA4444(((u8*)src)[x^(i<<1)]);
}

inline u32 GetCI16IA_RGBA8888(u64 *src, u16 x, u16 i, u8 palette)
{
	const u16 tex = ((u16*)src)[x^i];
	const u16 col = (*(u16*)&TMEM[256 + (tex >> 8)]);
	const u16 c = col >> 8;
	const u16 a = col & 0xFF;
	return (a << 24) | (c << 16) | (c << 8) | c;
}

inline u32 GetCI16IA_RGBA4444(u64 *src, u16 x, u16 i, u8 palette)
{
	const u16 tex = ((u16*)src)[x^i];
	const u16 col = (*(u16*)&TMEM[256 + (tex >> 8)]);
	const u16 c = col >> 12;
	const u16 a = col & 0x0F;
	return (a << 12) | (c << 8) | (c << 4) | c;
}

inline u32 GetCI16RGBA_RGBA8888(u64 *src, u16 x, u16 i, u8 palette)
{
	const u16 tex = (((u16*)src)[x^i])&0xFF;
	return RGBA5551_RGBA8888(((u16*)&TMEM[256])[tex << 2]);
}

inline u32 GetCI16RGBA_RGBA5551(u64 *src, u16 x, u16 i, u8 palette)
{
	const u16 tex = (((u16*)src)[x^i]) & 0xFF;
	return RGBA5551_RGBA5551(((u16*)&TMEM[256])[tex << 2]);
}

inline u32 GetRGBA5551_RGBA8888(u64 *src, u16 x, u16 i, u8 palette)
{
	u16 tex = ((u16*)src)[x^i];
	return RGBA5551_RGBA8888(tex);
}

inline u32 GetRGBA5551_RGBA5551( u64 *src, u16 x, u16 i, u8 palette )
{
	u16 tex = ((u16*)src)[x^i];
	return RGBA5551_RGBA5551(tex);
}

inline u32 GetIA88_RGBA8888( u64 *src, u16 x, u16 i, u8 palette )
{
	return IA88_RGBA8888(((u16*)src)[x^i]);
}

inline u32 GetIA88_RGBA4444( u64 *src, u16 x, u16 i, u8 palette )
{
	return IA88_RGBA4444(((u16*)src)[x^i]);
}

inline u32 GetRGBA8888_RGBA8888( u64 *src, u16 x, u16 i, u8 palette )
{
	return ((u32*)src)[x^i];
}

inline u32 GetRGBA8888_RGBA4444( u64 *src, u16 x, u16 i, u8 palette )
{
	return RGBA8888_RGBA4444(((u32*)src)[x^i]);
}

#if 0
u32 YUV_RGBA8888(u8 y, u8 u, u8 v)
{
	s32 r = (s32)(y + (1.370705f * (v - 128)));
	s32 g = (s32)((y - (0.698001f * (v - 128)) - (0.337633f * (u - 128))));
	s32 b = (s32)(y + (1.732446f * (u - 128)));
	//clipping the result
	if (r > 255) r = 255;
	if (g > 255) g = 255;
	if (b > 255) b = 255;
	if (r < 0) r = 0;
	if (g < 0) g = 0;
	if (b < 0) b = 0;

	return (0xff << 24) | (b << 16) | (g << 8) | r;
}
#else
inline u32 YUV_RGBA8888(u8 y, u8 u, u8 v)
{
	return (0xff << 24) | (y << 16) | (v << 8) | u;
}
#endif

inline void GetYUV_RGBA8888(u64 * src, u32 * dst, u16 x)
{
	const u32 t = (((u32*)src)[x]);
	u8 y1 = (u8)t & 0xFF;
	u8 v = (u8)(t >> 8) & 0xFF;
	u8 y0 = (u8)(t >> 16) & 0xFF;
	u8 u = (u8)(t >> 24) & 0xFF;
	u32 c = YUV_RGBA8888(y0, u, v);
	*(dst++) = c;
	c = YUV_RGBA8888(y1, u, v);
	*(dst++) = c;
}

struct TextureLoadParameters
{
	GetTexelFunc				Get16;
	DatatypeParam				glType16;
	InternalColorFormatParam	glInternalFormat16;
	GetTexelFunc				Get32;
	DatatypeParam				glType32;
	InternalColorFormatParam	glInternalFormat32;
	InternalColorFormatParam	autoFormat;
	u32							lineShift;
	u32							maxTexels;
};

struct ImageFormat {
	ImageFormat();

	TextureLoadParameters tlp[4][4][5];

	static ImageFormat & get() {
		static ImageFormat imageFmt;
		return imageFmt;
	}
};

ImageFormat::ImageFormat()
{
	TextureLoadParameters imageFormat[4][4][5] =
	{ // G_TT_NONE
		{ //		Get16					glType16	glInternalFormat16		Get32					glType32	glInternalFormat32	autoFormat
			{ // 4-bit
				{ GetI4_RGBA4444, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetI4_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA4, 4, 8192 }, // RGBA as I
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA4, 4, 8192 }, // YUV
				{ GetI4_RGBA4444, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetI4_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA4, 4, 8192 }, // CI without palette
				{ GetIA31_RGBA4444, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetIA31_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA4, 4, 8192 }, // IA
				{ GetI4_RGBA4444, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetI4_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA4, 4, 8192 }, // I
			},
			{ // 8-bit
				{ GetI8_RGBA4444, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetI8_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 3, 4096 }, // RGBA as I
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA4, 0, 4096 }, // YUV
				{ GetI8_RGBA4444, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetI8_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 3, 4096 }, // CI without palette
				{ GetIA44_RGBA4444, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetIA44_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA4, 3, 4096 }, // IA
				{ GetI8_RGBA4444, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetI8_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 3, 4096 }, // I
			},
			{ // 16-bit
				{ GetRGBA5551_RGBA5551, datatype::UNSIGNED_SHORT_5_5_5_1, internalcolorFormat::RGB5_A1, GetRGBA5551_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGB5_A1, 2, 2048 }, // RGBA
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 2, 2048 }, // YUV
				{ GetIA88_RGBA4444, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetIA88_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 2, 2048 }, // CI as IA
				{ GetIA88_RGBA4444, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetIA88_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 2, 2048 }, // IA
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA4, 0, 2048 }, // I
			},
			{ // 32-bit
				{ GetRGBA8888_RGBA4444, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetRGBA8888_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 2, 1024 }, // RGBA
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA4, 0, 1024 }, // YUV
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA4, 0, 1024 }, // CI
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA4, 0, 1024 }, // IA
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA4, 0, 1024 }, // I
			}
		},
			// DUMMY
		{ //		Get16					glType16	glInternalFormat16			Get32				glType32	glInternalFormat32	autoFormat
			{ // 4-bit
				{ GetCI4RGBA_RGBA5551, datatype::UNSIGNED_SHORT_5_5_5_1, internalcolorFormat::RGB5_A1, GetCI4RGBA_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGB5_A1, 4, 4096 }, // CI (Banjo-Kazooie uses this, doesn't make sense, but it works...)
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA4, 4, 8192 }, // YUV
				{ GetCI4RGBA_RGBA5551, datatype::UNSIGNED_SHORT_5_5_5_1, internalcolorFormat::RGB5_A1, GetCI4RGBA_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGB5_A1, 4, 4096 }, // CI
				{ GetCI4RGBA_RGBA5551, datatype::UNSIGNED_SHORT_5_5_5_1, internalcolorFormat::RGB5_A1, GetCI4RGBA_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGB5_A1, 4, 4096 }, // IA as CI
				{ GetCI4RGBA_RGBA5551, datatype::UNSIGNED_SHORT_5_5_5_1, internalcolorFormat::RGB5_A1, GetCI4RGBA_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGB5_A1, 4, 4096 }, // I as CI
			},
			{ // 8-bit
				{ GetCI8RGBA_RGBA5551, datatype::UNSIGNED_SHORT_5_5_5_1, internalcolorFormat::RGB5_A1, GetCI8RGBA_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGB5_A1, 3, 2048 }, // RGBA
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA4, 0, 4096 }, // YUV
				{ GetCI8RGBA_RGBA5551, datatype::UNSIGNED_SHORT_5_5_5_1, internalcolorFormat::RGB5_A1, GetCI8RGBA_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGB5_A1, 3, 2048 }, // CI
				{ GetCI8RGBA_RGBA5551, datatype::UNSIGNED_SHORT_5_5_5_1, internalcolorFormat::RGB5_A1, GetCI8RGBA_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGB5_A1, 3, 2048 }, // IA as CI
				{ GetCI8RGBA_RGBA5551, datatype::UNSIGNED_SHORT_5_5_5_1, internalcolorFormat::RGB5_A1, GetCI8RGBA_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGB5_A1, 3, 2048 }, // I as CI
			},
			{ // 16-bit
				{ GetCI16RGBA_RGBA5551, datatype::UNSIGNED_SHORT_5_5_5_1, internalcolorFormat::RGB5_A1, GetRGBA5551_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGB5_A1, 2, 2048 }, // RGBA
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 2, 2048 }, // YUV
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA4, 0, 2048 }, // CI
				{ GetCI16RGBA_RGBA5551, datatype::UNSIGNED_SHORT_5_5_5_1, internalcolorFormat::RGB5_A1, GetCI16RGBA_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGB5_A1, 2, 2048 }, // IA as CI
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA4, 0, 2048 }, // I
			},
			{ // 32-bit
				{ GetRGBA8888_RGBA4444, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetRGBA8888_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 2, 1024 }, // RGBA
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA4, 0, 1024 }, // YUV
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA4, 0, 1024 }, // CI
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA4, 0, 1024 }, // IA
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA4, 0, 1024 }, // I
			}
		},
			// G_TT_RGBA16
		{ //		Get16					glType16			glInternalFormat16	Get32				glType32	glInternalFormat32	autoFormat
			{ // 4-bit
				{ GetCI4RGBA_RGBA5551, datatype::UNSIGNED_SHORT_5_5_5_1, internalcolorFormat::RGB5_A1, GetCI4RGBA_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGB5_A1, 4, 4096 }, // CI (Banjo-Kazooie uses this, doesn't make sense, but it works...)
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA4, 4, 8192 }, // YUV
				{ GetCI4RGBA_RGBA5551, datatype::UNSIGNED_SHORT_5_5_5_1, internalcolorFormat::RGB5_A1, GetCI4RGBA_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGB5_A1, 4, 4096 }, // CI
				{ GetCI4RGBA_RGBA5551, datatype::UNSIGNED_SHORT_5_5_5_1, internalcolorFormat::RGB5_A1, GetCI4RGBA_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGB5_A1, 4, 4096 }, // IA as CI
				{ GetCI4RGBA_RGBA5551, datatype::UNSIGNED_SHORT_5_5_5_1, internalcolorFormat::RGB5_A1, GetCI4RGBA_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGB5_A1, 4, 4096 }, // I as CI
			},
			{ // 8-bit
				{ GetCI8RGBA_RGBA5551, datatype::UNSIGNED_SHORT_5_5_5_1, internalcolorFormat::RGB5_A1, GetCI8RGBA_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGB5_A1, 3, 2048 }, // RGBA
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA4, 0, 4096 }, // YUV
				{ GetCI8RGBA_RGBA5551, datatype::UNSIGNED_SHORT_5_5_5_1, internalcolorFormat::RGB5_A1, GetCI8RGBA_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGB5_A1, 3, 2048 }, // CI
				{ GetCI8RGBA_RGBA5551, datatype::UNSIGNED_SHORT_5_5_5_1, internalcolorFormat::RGB5_A1, GetCI8RGBA_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGB5_A1, 3, 2048 }, // IA as CI
				{ GetCI8RGBA_RGBA5551, datatype::UNSIGNED_SHORT_5_5_5_1, internalcolorFormat::RGB5_A1, GetCI8RGBA_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGB5_A1, 3, 2048 }, // I as CI
			},
			{ // 16-bit
				{ GetCI16RGBA_RGBA5551, datatype::UNSIGNED_SHORT_5_5_5_1, internalcolorFormat::RGB5_A1, GetRGBA5551_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGB5_A1, 2, 2048 }, // RGBA
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 2, 2048 }, // YUV
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA4, 0, 2048 }, // CI
				{ GetCI16RGBA_RGBA5551, datatype::UNSIGNED_SHORT_5_5_5_1, internalcolorFormat::RGB5_A1, GetCI16RGBA_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGB5_A1, 2, 2048 }, // IA as CI
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA4, 0, 2048 }, // I
			},
			{ // 32-bit
				{ GetRGBA8888_RGBA4444, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetRGBA8888_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 2, 1024 }, // RGBA
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA4, 0, 1024 }, // YUV
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA4, 0, 1024 }, // CI
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA4, 0, 1024 }, // IA
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA4, 0, 1024 }, // I
			}
		},
			// G_TT_IA16
		{ //		Get16					glType16			glInternalFormat16	Get32				glType32	glInternalFormat32	autoFormat
			{ // 4-bit
				{ GetCI4IA_RGBA4444, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetCI4IA_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 4, 4096 }, // IA
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 4, 8192 }, // YUV
				{ GetCI4IA_RGBA4444, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetCI4IA_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 4, 4096 }, // CI
				{ GetCI4IA_RGBA4444, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetCI4IA_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 4, 4096 }, // IA
				{ GetCI4IA_RGBA4444, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetCI4IA_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 4, 4096 }, // I
			},
			{ // 8-bit
				{ GetCI8IA_RGBA4444, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetCI8IA_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 3, 2048 }, // RGBA
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 0, 4096 }, // YUV
				{ GetCI8IA_RGBA4444, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetCI8IA_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 3, 2048 }, // CI
				{ GetCI8IA_RGBA4444, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetCI8IA_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 3, 2048 }, // IA
				{ GetCI8IA_RGBA4444, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetCI8IA_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 3, 2048 }, // I
			},
			{ // 16-bit
				{ GetCI16IA_RGBA4444, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetCI16IA_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 2, 2048 }, // RGBA
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 2, 2048 }, // YUV
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 0, 2048 }, // CI
				{ GetCI16IA_RGBA4444, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetCI16IA_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 2, 2048 }, // IA
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 0, 2048 }, // I
			},
			{ // 32-bit
				{ GetRGBA8888_RGBA4444, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetRGBA8888_RGBA8888, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 2, 1024 }, // RGBA
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 0, 1024 }, // YUV
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 0, 1024 }, // CI
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 0, 1024 }, // IA
				{ GetNone, datatype::UNSIGNED_SHORT_4_4_4_4, internalcolorFormat::RGBA4, GetNone, datatype::UNSIGNED_BYTE, internalcolorFormat::RGBA8, internalcolorFormat::RGBA8, 0, 1024 }, // I
			}
		}
	};

	memcpy(tlp, imageFormat, sizeof(tlp));
}

/** cite from RiceVideo */
inline u32 CalculateDXT(u32 txl2words)
{
	if (txl2words == 0) return 1;
	else return (2048 + txl2words - 1) / txl2words;
}

u32 sizeBytes[4] = {0, 1, 2, 4};

inline u32 Txl2Words(u32 width, u32 size)
{
	if (size == 0)
		return max(1U, width / 16);
	else
		return max(1U, width*sizeBytes[size] / 8);
}

inline u32 ReverseDXT(u32 val, u32 lrs, u32 width, u32 size)
{
	if (val == 0x800) return 1;

	int low = 2047 / val;
	if (CalculateDXT(low) > val)	low++;
	int high = 2047 / (val - 1);

	if (low == high)	return low;

	for (int i = low; i <= high; i++) {
		if (Txl2Words(width, size) == (u32)i)
			return i;
	}

	return	(low + high) / 2;
}
/** end RiceVideo cite */

TextureCache & TextureCache::get() {
	static TextureCache cache;
	return cache;
}

void TextureCache::_initDummyTexture(CachedTexture * _pDummy)
{
	_pDummy->address = 0;
	_pDummy->clampS = 1;
	_pDummy->clampT = 1;
	_pDummy->clampWidth = 2;
	_pDummy->clampHeight = 2;
	_pDummy->crc = 0;
	_pDummy->format = 0;
	_pDummy->size = 0;
	_pDummy->frameBufferTexture = CachedTexture::fbNone;
	_pDummy->width = 2;
	_pDummy->height = 2;
	_pDummy->realWidth = 2;
	_pDummy->realHeight = 2;
	_pDummy->maskS = 0;
	_pDummy->maskT = 0;
	_pDummy->scaleS = 0.5f;
	_pDummy->scaleT = 0.5f;
	_pDummy->shiftScaleS = 1.0f;
	_pDummy->shiftScaleT = 1.0f;
	_pDummy->textureBytes = 2 * 2 * 4;
	_pDummy->tMem = 0;
}

void TextureCache::init()
{
	m_curUnpackAlignment = 0;

	u32 dummyTexture[16] = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

	m_pDummy = addFrameBufferTexture(false); // we don't want to remove dummy texture
	_initDummyTexture(m_pDummy);

	Context::InitTextureParams params;
	params.handle = m_pDummy->name;
	params.mipMapLevel = 0;
	params.msaaLevel = 0;
	params.width = m_pDummy->realWidth;
	params.height = m_pDummy->realHeight;
	params.format = colorFormat::RGBA;
	params.internalFormat = gfxContext.convertInternalTextureFormat(u32(internalcolorFormat::RGBA8));
	params.dataType = datatype::UNSIGNED_BYTE;
	params.data = dummyTexture;
	gfxContext.init2DTexture(params);

	m_cachedBytes = m_pDummy->textureBytes;
	activateDummy( 0 );
	activateDummy(1);
	current[0] = current[1] = nullptr;


	m_pMSDummy = nullptr;
	if (config.video.multisampling != 0 && gfxContext.isSupported(SpecialFeatures::Multisampling)) {
		m_pMSDummy = addFrameBufferTexture(true); // we don't want to remove dummy texture
		_initDummyTexture(m_pMSDummy);

		Context::InitTextureParams params;
		params.handle = m_pMSDummy->name;
		params.mipMapLevel = 0;
		params.msaaLevel = config.video.multisampling;
		params.width = m_pMSDummy->realWidth;
		params.height = m_pMSDummy->realHeight;
		params.format = colorFormat::RGBA;
		params.internalFormat = gfxContext.convertInternalTextureFormat(u32(internalcolorFormat::RGBA8));
		params.dataType = datatype::UNSIGNED_BYTE;
		gfxContext.init2DTexture(params);

		activateMSDummy(0);
		activateMSDummy(1);
	}

	assert(!gfxContext.isError());
}

void TextureCache::destroy()
{
	current[0] = current[1] = nullptr;

	for (Textures::const_iterator cur = m_textures.cbegin(); cur != m_textures.cend(); ++cur)
		gfxContext.deleteTexture(cur->name);
	m_textures.clear();
	m_lruTextureLocations.clear();

	for (FBTextures::const_iterator cur = m_fbTextures.cbegin(); cur != m_fbTextures.cend(); ++cur)
		gfxContext.deleteTexture(cur->second.name);
	m_fbTextures.clear();

	m_cachedBytes = 0;
}

void TextureCache::_checkCacheSize()
{
	if (m_textures.size() >= m_maxCacheSize) {
		CachedTexture& clsTex = m_textures.back();
		m_cachedBytes -= clsTex.textureBytes;
		gfxContext.deleteTexture(clsTex.name);
		m_lruTextureLocations.erase(clsTex.crc);
		m_textures.pop_back();
	}
}

CachedTexture * TextureCache::_addTexture(u32 _crc32)
{
	if (m_curUnpackAlignment == 0)
		m_curUnpackAlignment = gfxContext.getTextureUnpackAlignment();
	_checkCacheSize();
	m_textures.emplace_front(gfxContext.createTexture(textureTarget::TEXTURE_2D));
	Textures::iterator new_iter = m_textures.begin();
	new_iter->crc = _crc32;
	m_lruTextureLocations.insert(std::pair<u32, Textures::iterator>(_crc32, new_iter));
	return &(*new_iter);
}

void TextureCache::removeFrameBufferTexture(CachedTexture * _pTexture)
{
	if (_pTexture == nullptr)
		return;
	FBTextures::const_iterator iter = m_fbTextures.find(_pTexture->name);
	assert(iter != m_fbTextures.cend());
	m_cachedBytes -= iter->second.textureBytes;
	gfxContext.deleteTexture(ObjectHandle(iter->second.name));
	m_fbTextures.erase(iter);
}

CachedTexture * TextureCache::addFrameBufferTexture(bool _multisample)
{
	_checkCacheSize();
	ObjectHandle texName(gfxContext.createTexture(_multisample ?
		textureTarget::TEXTURE_2D_MULTISAMPLE : textureTarget::TEXTURE_2D));
	m_fbTextures.emplace(texName, texName);
	return &m_fbTextures.at(texName);
}

struct TileSizes
{
	u32 maskWidth, clampWidth, width, realWidth;
	u32 maskHeight, clampHeight, height, realHeight;
	u32 bytes;
};

static
void _calcTileSizes(u32 _t, TileSizes & _sizes, gDPTile * _pLoadTile)
{
	gDPTile * pTile = _t < 2 ? gSP.textureTile[_t] : &gDP.tiles[_t];

	const TextureLoadParameters & loadParams =
			ImageFormat::get().tlp[gDP.otherMode.textureLUT][pTile->size][pTile->format];
	const u32 maxTexels = loadParams.maxTexels;
	const u32 tileWidth = ((pTile->lrs - pTile->uls) & 0x03FF) + 1;
	const u32 tileHeight = ((pTile->lrt - pTile->ult) & 0x03FF) + 1;

	const bool bUseLoadSizes = _pLoadTile != nullptr && _pLoadTile->loadType == LOADTYPE_TILE &&
		(pTile->tmem == _pLoadTile->tmem);

	u32 loadWidth = 0, loadHeight = 0;
	if (bUseLoadSizes) {
		loadWidth = ((_pLoadTile->lrs - _pLoadTile->uls) & 0x03FF) + 1;
		loadHeight = ((_pLoadTile->lrt - _pLoadTile->ult) & 0x03FF) + 1;
	}

	const u32 lineWidth = pTile->line << loadParams.lineShift;
	const u32 lineHeight = lineWidth != 0 ? min(maxTexels / lineWidth, tileHeight) : 0;

	u32 maskWidth = 1 << pTile->masks;
	u32 maskHeight = 1 << pTile->maskt;
	u32 width, height;

	const u32 tMemMask = gDP.otherMode.textureLUT == G_TT_NONE ? 0x1FF : 0xFF;
	gDPLoadTileInfo &info = gDP.loadInfo[pTile->tmem & tMemMask];
	_sizes.bytes = info.bytes;
	if (info.loadType == LOADTYPE_TILE) {
		if (pTile->masks && ((maskWidth * maskHeight) <= maxTexels))
			width = maskWidth; // Use mask width if set and valid
		else {
			width = info.width;
			if (info.size > pTile->size)
				width <<= info.size - pTile->size;
		}
		if (pTile->maskt && ((maskWidth * maskHeight) <= maxTexels))
			height = maskHeight;
		else
			height = info.height;
	} else {
		if (pTile->masks && ((maskWidth * maskHeight) <= maxTexels))
			width = maskWidth; // Use mask width if set and valid
		else if ((tileWidth * tileHeight) <= maxTexels)
			width = tileWidth; // else use tile width if valid
		else
			width = lineWidth; // else use line-based width

		if (pTile->maskt && ((maskWidth * maskHeight) <= maxTexels))
			height = maskHeight;
		else if ((tileWidth * tileHeight) <= maxTexels)
			height = tileHeight;
		else
			height = lineHeight;
	}

	_sizes.clampWidth = (pTile->clamps && gDP.otherMode.cycleType != G_CYC_COPY) ? tileWidth : width;
	_sizes.clampHeight = (pTile->clampt && gDP.otherMode.cycleType != G_CYC_COPY) ? tileHeight : height;

	if (_sizes.clampWidth > 256)
		pTile->clamps = 0;
	if (_sizes.clampHeight > 256)
		pTile->clampt = 0;

	// Make sure masking is valid
	if (maskWidth > width) {
		pTile->masks = powof(width);
		maskWidth = 1 << pTile->masks;
	}

	if (maskHeight > height) {
		pTile->maskt = powof(height);
		maskHeight = 1 << pTile->maskt;
	}

	_sizes.maskWidth = maskWidth;
	_sizes.maskHeight = maskHeight;
	_sizes.width = width;
	_sizes.height = height;

	if (pTile->clamps != 0)
		_sizes.realWidth = _sizes.clampWidth;
	else if (pTile->masks != 0)
		_sizes.realWidth = _sizes.maskWidth;
	else
		_sizes.realWidth = _sizes.width;

	if (pTile->clampt != 0)
		_sizes.realHeight = _sizes.clampHeight;
	else if (pTile->maskt != 0)
		_sizes.realHeight = _sizes.maskHeight;
	else
		_sizes.realHeight = _sizes.height;

	if (gSP.texture.level > 0) {
		_sizes.realWidth = pow2(_sizes.realWidth);
		_sizes.realHeight = pow2(_sizes.realHeight);
	}
}

inline
void _updateCachedTexture(const GHQTexInfo & _info, CachedTexture *_pTexture, f32 _scale)
{
	_pTexture->textureBytes = _info.width * _info.height;

	Parameter format(_info.format);
	if (format == internalcolorFormat::RGB8 ||
		format == internalcolorFormat::RGBA4 ||
		format == internalcolorFormat::RGB5_A1) {
		_pTexture->textureBytes <<= 1;
	}
	else {
		_pTexture->textureBytes <<= 2;
	}

	if (_pTexture->realWidth == _pTexture->width * 2)
		_pTexture->clampS = 0; // force wrap or mirror s
	if (_pTexture->realHeight == _pTexture->height * 2)
		_pTexture->clampT = 0; // force wrap or mirror t

	_pTexture->realWidth = _info.width;
	_pTexture->realHeight = _info.height;
	_pTexture->scaleS = _scale / f32(_info.width);
	_pTexture->scaleT = _scale / f32(_info.height);

	_pTexture->bHDTexture = true;
}

bool TextureCache::_loadHiresBackground(CachedTexture *_pTexture)
{
	if (!TFH.isInited())
		return false;

	u8 * addr = (u8*)(RDRAM + gSP.bgImage.address);
	int tile_width = gSP.bgImage.width;
	int tile_height = gSP.bgImage.height;
	int bpl = tile_width << gSP.bgImage.size >> 1;

	u8 * paladdr = nullptr;
	u16 * palette = nullptr;
	if ((gSP.bgImage.size < G_IM_SIZ_16b) && (gDP.otherMode.textureLUT != G_TT_NONE || gSP.bgImage.format == G_IM_FMT_CI)) {
		if (gSP.bgImage.size == G_IM_SIZ_8b)
			paladdr = (u8*)(gDP.TexFilterPalette);
		else if (config.textureFilter.txHresAltCRC)
			paladdr = (u8*)(gDP.TexFilterPalette + (gSP.bgImage.palette << 5));
		else
			paladdr = (u8*)(gDP.TexFilterPalette + (gSP.bgImage.palette << 4));
		// TODO: fix palette load
		//			palette = (rdp.pal_8 + (gSP.textureTile[_t]->palette << 4));
	}

	u64 ricecrc = txfilter_checksum(addr, tile_width,
						tile_height, (unsigned short)(gSP.bgImage.format << 8 | gSP.bgImage.size),
						bpl, paladdr);
	GHQTexInfo ghqTexInfo;
	// TODO: fix problem with zero texture dimensions on GLideNHQ side.
	if (txfilter_hirestex(_pTexture->crc, ricecrc, palette, &ghqTexInfo) &&
			ghqTexInfo.width != 0 && ghqTexInfo.height != 0) {
		ghqTexInfo.format = gfxContext.convertInternalTextureFormat(ghqTexInfo.format);
		Context::InitTextureParams params;
		params.handle = _pTexture->name;
		params.mipMapLevel = 0;
		params.msaaLevel = 0;
		params.width = ghqTexInfo.width;
		params.height = ghqTexInfo.height;
		params.format = ColorFormatParam(ghqTexInfo.texture_format);
		params.internalFormat = InternalColorFormatParam(ghqTexInfo.format);
		params.dataType = DatatypeParam(ghqTexInfo.pixel_type);
		params.data = ghqTexInfo.data;
		gfxContext.init2DTexture(params);

		assert(!gfxContext.isError());
		_updateCachedTexture(ghqTexInfo, _pTexture, f32(ghqTexInfo.width) / f32(tile_width));
		return true;
	}
	return false;
}

void TextureCache::_loadBackground(CachedTexture *pTexture)
{
	if (_loadHiresBackground(pTexture))
		return;

	u32 *pDest;

	u8 *pSwapped, *pSrc;
	u32 numBytes, bpl;
	u32 x, y, j, tx, ty;
	u16 clampSClamp;
	u16 clampTClamp;
	GetTexelFunc GetTexel;
	InternalColorFormatParam glInternalFormat;
	DatatypeParam glType;

	const TextureLoadParameters & loadParams =
			ImageFormat::get().tlp[pTexture->format == 2 ? G_TT_RGBA16 : G_TT_NONE][pTexture->size][pTexture->format];
	if (loadParams.autoFormat == internalcolorFormat::RGBA8) {
		pTexture->textureBytes = (pTexture->realWidth * pTexture->realHeight) << 2;
		GetTexel = loadParams.Get32;
		glInternalFormat = loadParams.glInternalFormat32;
		glType = loadParams.glType32;
	} else {
		pTexture->textureBytes = (pTexture->realWidth * pTexture->realHeight) << 1;
		GetTexel = loadParams.Get16;
		glInternalFormat = loadParams.glInternalFormat16;
		glType = loadParams.glType16;
	}

	bpl = gSP.bgImage.width << gSP.bgImage.size >> 1;
	numBytes = bpl * gSP.bgImage.height;
	pSwapped = (u8*)malloc(numBytes);
	if (pSwapped == nullptr)
		return;
	UnswapCopyWrap(RDRAM, gSP.bgImage.address, pSwapped, 0, RDRAMSize, numBytes);
	pDest = (u32*)malloc(pTexture->textureBytes);
	if (pDest == nullptr) {
		free(pSwapped);
		return;
	}

	clampSClamp = pTexture->width - 1;
	clampTClamp = pTexture->height - 1;

	j = 0;
	for (y = 0; y < pTexture->realHeight; y++) {
		ty = min(y, (u32)clampTClamp);

		pSrc = &pSwapped[bpl * ty];

		for (x = 0; x < pTexture->realWidth; x++) {
			tx = min(x, (u32)clampSClamp);

			if (glInternalFormat == internalcolorFormat::RGBA8)
				((u32*)pDest)[j++] = GetTexel((u64*)pSrc, tx, 0, pTexture->palette);
			else
				((u16*)pDest)[j++] = GetTexel((u64*)pSrc, tx, 0, pTexture->palette);
		}
	}

	if ((config.generalEmulation.hacks&hack_LoadDepthTextures) != 0 && gDP.colorImage.address == gDP.depthImageAddress) {
		_loadDepthTexture(pTexture, (u16*)pDest);
		free(pDest);
		free(pSwapped);
		return;
	}

	bool bLoaded = false;
	if ((config.textureFilter.txEnhancementMode | config.textureFilter.txFilterMode) != 0 &&
			config.textureFilter.txFilterIgnoreBG == 0 &&
			TFH.isInited()) {
		GHQTexInfo ghqTexInfo;
		if (txfilter_filter((u8*)pDest, pTexture->realWidth, pTexture->realHeight,
				(u16)u32(glInternalFormat), (uint64)pTexture->crc, &ghqTexInfo) != 0 &&
				ghqTexInfo.data != nullptr) {

			if (ghqTexInfo.width % 2 != 0 &&
				ghqTexInfo.format != u32(internalcolorFormat::RGBA8) &&
				m_curUnpackAlignment > 1)
				gfxContext.setTextureUnpackAlignment(2);

			ghqTexInfo.format = gfxContext.convertInternalTextureFormat(ghqTexInfo.format);
			Context::InitTextureParams params;
			params.handle = pTexture->name;
			params.mipMapLevel = 0;
			params.msaaLevel = 0;
			params.width = ghqTexInfo.width;
			params.height = ghqTexInfo.height;
			params.format = ColorFormatParam(ghqTexInfo.texture_format);
			params.internalFormat = InternalColorFormatParam(ghqTexInfo.format);
			params.dataType = DatatypeParam(ghqTexInfo.pixel_type);
			params.data = ghqTexInfo.data;
			gfxContext.init2DTexture(params);
			_updateCachedTexture(ghqTexInfo, pTexture, f32(ghqTexInfo.width) / f32(pTexture->realWidth));
			bLoaded = true;
		}
	}
	if (!bLoaded) {
		if (pTexture->realWidth % 2 != 0 && glInternalFormat != internalcolorFormat::RGBA8)
			gfxContext.setTextureUnpackAlignment(2);
		Context::InitTextureParams params;
		params.handle = pTexture->name;
		params.mipMapLevel = 0;
		params.msaaLevel = 0;
		params.width = pTexture->realWidth;
		params.height = pTexture->realHeight;
		params.format = colorFormat::RGBA;
		params.internalFormat = gfxContext.convertInternalTextureFormat(u32(glInternalFormat));
		params.dataType = glType;
		params.data = pDest;
		gfxContext.init2DTexture(params);
	}
	if (m_curUnpackAlignment > 1)
		gfxContext.setTextureUnpackAlignment(m_curUnpackAlignment);
	free(pSwapped);
	free(pDest);
}

bool TextureCache::_loadHiresTexture(u32 _tile, CachedTexture *_pTexture, u64 & _ricecrc)
{
	if (config.textureFilter.txHiresEnable == 0 || !TFH.isInited())
		return false;

	gDPLoadTileInfo & info = gDP.loadInfo[_pTexture->tMem];

	int bpl;
	int width, height;
	u8 * addr = (u8*)(RDRAM + info.texAddress);
	if (info.loadType == LOADTYPE_TILE) {
		bpl = info.texWidth << info.size >> 1;
		addr += (info.ult * bpl) + (((info.uls << info.size) + 1) >> 1);

		width = min(info.width, info.texWidth);
		if (info.size > _pTexture->size)
			width <<= info.size - _pTexture->size;

		height = info.height;
		if ((config.generalEmulation.hacks & hack_MK64) != 0 && (height % 2) != 0)
			height--;
	} else {
		int tile_width = gDP.tiles[_tile].lrs - gDP.tiles[_tile].uls + 1;
		int tile_height = gDP.tiles[_tile].lrt - gDP.tiles[_tile].ult + 1;

		int mask_width = (gDP.tiles[_tile].masks == 0) ? (tile_width) : (1 << gDP.tiles[_tile].masks);
		int mask_height = (gDP.tiles[_tile].maskt == 0) ? (tile_height) : (1 << gDP.tiles[_tile].maskt);

		if ((gDP.tiles[_tile].clamps && tile_width <= 256))
			width = min(mask_width, tile_width);
		else
			width = mask_width;

		if ((gDP.tiles[_tile].clampt && tile_height <= 256) || (mask_height > 256))
			height = min(mask_height, tile_height);
		else
			height = mask_height;

		if (gSP.textureTile[_tile]->size == G_IM_SIZ_32b)
			bpl = gSP.textureTile[_tile]->line << 4;
		else if (info.dxt == 0)
			bpl = gSP.textureTile[_tile]->line << 3;
		else {
			u32 dxt = info.dxt;
			if (dxt > 1)
				dxt = ReverseDXT(dxt, info.width, _pTexture->width, _pTexture->size);
			bpl = dxt << 3;
		}
	}

	u8 * paladdr = nullptr;
	u16 * palette = nullptr;
	if ((_pTexture->size < G_IM_SIZ_16b) && (gDP.otherMode.textureLUT != G_TT_NONE || _pTexture->format == G_IM_FMT_CI)) {
		if (_pTexture->size == G_IM_SIZ_8b)
			paladdr = (u8*)(gDP.TexFilterPalette);
		else if (config.textureFilter.txHresAltCRC)
			paladdr = (u8*)(gDP.TexFilterPalette + (_pTexture->palette << 5));
		else
			paladdr = (u8*)(gDP.TexFilterPalette + (_pTexture->palette << 4));
		// TODO: fix palette load
		//			palette = (rdp.pal_8 + (gSP.textureTile[_t]->palette << 4));
	}

	_ricecrc = txfilter_checksum(addr, width, height, (unsigned short)(_pTexture->format << 8 | _pTexture->size), bpl, paladdr);
	GHQTexInfo ghqTexInfo;
	// TODO: fix problem with zero texture dimensions on GLideNHQ side.
	if (txfilter_hirestex(_pTexture->crc, _ricecrc, palette, &ghqTexInfo) &&
		ghqTexInfo.width != 0 && ghqTexInfo.height != 0) {
		ghqTexInfo.format = gfxContext.convertInternalTextureFormat(ghqTexInfo.format);
		Context::InitTextureParams params;
		params.handle = _pTexture->name;
		params.mipMapLevel = 0;
		params.msaaLevel = 0;
		params.width = ghqTexInfo.width;
		params.height = ghqTexInfo.height;
		params.internalFormat = InternalColorFormatParam(ghqTexInfo.format);
		params.format = ColorFormatParam(ghqTexInfo.texture_format);
		params.dataType = DatatypeParam(ghqTexInfo.pixel_type);
		params.data = ghqTexInfo.data;
		params.textureUnitIndex = textureIndices::Tex[_tile];
		gfxContext.init2DTexture(params);
		assert(!gfxContext.isError());
		_updateCachedTexture(ghqTexInfo, _pTexture, f32(ghqTexInfo.width) / f32(width));
		return true;
	}

	return false;
}

void TextureCache::_loadDepthTexture(CachedTexture * _pTexture, u16* _pDest)
{
	if (!gfxContext.isSupported(SpecialFeatures::FragmentDepthWrite))
		return;

	Context::InitTextureParams params;
	params.handle = _pTexture->name;
	params.mipMapLevel = 0;
	params.msaaLevel = 0;
	params.width = _pTexture->realWidth;
	params.height = _pTexture->realHeight;
	params.internalFormat = internalcolorFormat::RED;
	params.format = colorFormat::RED;
	params.dataType = datatype::UNSIGNED_SHORT;
	params.data = _pDest;
	gfxContext.init2DTexture(params);
}

/*
 * Worker function for _load
*/
void TextureCache::_getTextureDestData(CachedTexture& tmptex,
						u32* pDest,
						Parameter glInternalFormat,
						GetTexelFunc GetTexel,
						u16* pLine)
{
	u16 mirrorSBit, maskSMask, clampSClamp;
	u16 mirrorTBit, maskTMask, clampTClamp;
	u16 x, y, i, j, tx, ty;
	u64 *pSrc;
	if (tmptex.maskS > 0) {
		clampSClamp = tmptex.clampS ? tmptex.clampWidth - 1 : (tmptex.mirrorS ? (tmptex.width << 1) - 1 : tmptex.width - 1);
		maskSMask = (1 << tmptex.maskS) - 1;
		mirrorSBit = tmptex.mirrorS != 0 ? 1 << tmptex.maskS : 0;
	} else {
		clampSClamp = tmptex.clampS ? tmptex.clampWidth - 1 : tmptex.width - 1;
		maskSMask = 0xFFFF;
		mirrorSBit = 0x0000;
	}

	if (tmptex.maskT > 0) {
		clampTClamp = tmptex.clampT ? tmptex.clampHeight - 1 : (tmptex.mirrorT ? (tmptex.height << 1) - 1 : tmptex.height - 1);
		maskTMask = (1 << tmptex.maskT) - 1;
		mirrorTBit = tmptex.mirrorT != 0 ? 1 << tmptex.maskT : 0;
	} else {
		clampTClamp = tmptex.clampT ? tmptex.clampHeight - 1 : tmptex.height - 1;
		maskTMask = 0xFFFF;
		mirrorTBit = 0x0000;
	}

	if (tmptex.size == G_IM_SIZ_32b) {
		const u16 * tmem16 = (u16*)TMEM;
		const u32 tbase = tmptex.tMem << 2;

		int wid_64 = (tmptex.clampWidth) << 2;
		if (wid_64 & 15) {
			wid_64 += 16;
		}
		wid_64 &= 0xFFFFFFF0;
		wid_64 >>= 3;
		int line32 = tmptex.line << 1;
		line32 = (line32 - wid_64) << 3;
		if (wid_64 < 1) {
			wid_64 = 1;
		}
		int width = wid_64 << 1;
		line32 = width + (line32 >> 2);

		u16 gr, ab;

		j = 0;
		for (y = 0; y < tmptex.realHeight; ++y) {
			ty = min(y, clampTClamp) & maskTMask;
			if (y & mirrorTBit) {
				ty ^= maskTMask;
			}

			u32 tline = tbase + line32 * ty;
			u32 xorval = (ty & 1) ? 3 : 1;

			for (x = 0; x < tmptex.realWidth; ++x) {
				tx = min(x, clampSClamp) & maskSMask;
				if (x & mirrorSBit) {
					tx ^= maskSMask;
				}

				u32 taddr = ((tline + tx) ^ xorval) & 0x3ff;
				gr = swapword(tmem16[taddr]);
				ab = swapword(tmem16[taddr | 0x400]);
				pDest[j++] = (ab << 16) | gr;
			}
		}
	} else if (tmptex.format == G_IM_FMT_YUV) {
		j = 0;
		*pLine <<= 1;
		for (y = 0; y < tmptex.realHeight; ++y) {
			pSrc = &TMEM[tmptex.tMem] + *pLine * y;
			for (x = 0; x < tmptex.realWidth / 2; x++) {
				GetYUV_RGBA8888(pSrc, pDest + j, x);
				j += 2;
			}
		}
	} else {
		j = 0;
		const u32 tMemMask = gDP.otherMode.textureLUT == G_TT_NONE ? 0x1FF : 0xFF;
		for (y = 0; y < tmptex.realHeight; ++y) {
			ty = min(y, clampTClamp) & maskTMask;

			if (y & mirrorTBit)
			ty ^= maskTMask;

			pSrc = &TMEM[(tmptex.tMem + *pLine * ty) & tMemMask];

			i = (ty & 1) << 1;
			for (x = 0; x < tmptex.realWidth; ++x) {
				tx = min(x, clampSClamp) & maskSMask;

				if (x & mirrorSBit) {
					tx ^= maskSMask;
				}

				if (glInternalFormat == internalcolorFormat::RGBA8) {
					pDest[j++] = GetTexel(pSrc, tx, i, tmptex.palette);
				} else {
					((u16*)pDest)[j++] = GetTexel(pSrc, tx, i, tmptex.palette);
				}
			}
		}
	}
}

void TextureCache::_load(u32 _tile, CachedTexture *_pTexture)
{
	u64 ricecrc = 0;
	if (_loadHiresTexture(_tile, _pTexture, ricecrc))
		return;

	u32 *pDest;

	u16 line;
	GetTexelFunc GetTexel;
	InternalColorFormatParam glInternalFormat;
	DatatypeParam glType;
	u32 sizeShift;

	const TextureLoadParameters & loadParams =
			ImageFormat::get().tlp[gDP.otherMode.textureLUT][_pTexture->size][_pTexture->format];
	if (loadParams.autoFormat == internalcolorFormat::RGBA8) {
		sizeShift = 2;
		_pTexture->textureBytes = (_pTexture->realWidth * _pTexture->realHeight) << sizeShift;
		GetTexel = loadParams.Get32;
		glInternalFormat = loadParams.glInternalFormat32;
		glType = loadParams.glType32;
	} else {
		sizeShift = 1;
		_pTexture->textureBytes = (_pTexture->realWidth * _pTexture->realHeight) << sizeShift;
		GetTexel = loadParams.Get16;
		glInternalFormat = loadParams.glInternalFormat16;
		glType = loadParams.glType16;
	}

	pDest = (u32*)malloc(_pTexture->textureBytes);
	assert(pDest != nullptr);

	s32 mipLevel = 0;
	_pTexture->max_level = 0;

	if (config.generalEmulation.enableLOD != 0 && gSP.texture.level > 1) {
		if (_tile == 0) {
			_pTexture->max_level = 0;
		} else {
			_pTexture->max_level = static_cast<u8>(gSP.texture.level - 1);
			const u16 dim = std::max(_pTexture->width, _pTexture->height);
			while (dim <  static_cast<u16>(1 << _pTexture->max_level))
				--_pTexture->max_level;
		}
	}

	ObjectHandle name;
	CachedTexture tmptex(name);
	memcpy(&tmptex, _pTexture, sizeof(CachedTexture));

	line = tmptex.line;

	while (true) {
		_getTextureDestData(tmptex, pDest, glInternalFormat, GetTexel, &line);

		if ((config.generalEmulation.hacks&hack_LoadDepthTextures) != 0 && gDP.colorImage.address == gDP.depthImageAddress) {
			_loadDepthTexture(_pTexture, (u16*)pDest);
			free(pDest);
			return;
		}

		if (m_toggleDumpTex &&
				config.textureFilter.txHiresEnable != 0 &&
				config.textureFilter.txDump != 0) {
			txfilter_dmptx((u8*)pDest, tmptex.realWidth, tmptex.realHeight,
					tmptex.realWidth, (u16)u32(glInternalFormat),
					(unsigned short)(_pTexture->format << 8 | _pTexture->size),
					ricecrc);
		}

		bool bLoaded = false;
		if ((config.textureFilter.txEnhancementMode | config.textureFilter.txFilterMode) != 0 &&
				_pTexture->max_level == 0 &&
				(config.textureFilter.txFilterIgnoreBG == 0 || (RSP.cmd != G_TEXRECT && RSP.cmd != G_TEXRECTFLIP)) &&
				TFH.isInited())
		{
			GHQTexInfo ghqTexInfo;
			if (txfilter_filter((u8*)pDest, tmptex.realWidth, tmptex.realHeight,
							(u16)u32(glInternalFormat), (uint64)_pTexture->crc,
							&ghqTexInfo) != 0 && ghqTexInfo.data != nullptr) {
				ghqTexInfo.format = gfxContext.convertInternalTextureFormat(ghqTexInfo.format);
				Context::InitTextureParams params;
				params.handle = _pTexture->name;
				params.textureUnitIndex = textureIndices::Tex[_tile];
				params.mipMapLevel = 0;
				params.msaaLevel = 0;
				params.width = ghqTexInfo.width;
				params.height = ghqTexInfo.height;
				params.internalFormat = InternalColorFormatParam(ghqTexInfo.format);
				params.format = ColorFormatParam(ghqTexInfo.texture_format);
				params.dataType = DatatypeParam(ghqTexInfo.pixel_type);
				params.data = ghqTexInfo.data;
				gfxContext.init2DTexture(params);
				_updateCachedTexture(ghqTexInfo, _pTexture, f32(ghqTexInfo.width) / f32(tmptex.realWidth));
				bLoaded = true;
			}
		}
		if (!bLoaded) {
			if (tmptex.realWidth % 2 != 0 &&
				glInternalFormat != internalcolorFormat::RGBA8 &&
				m_curUnpackAlignment > 1)
				gfxContext.setTextureUnpackAlignment(2);
			Context::InitTextureParams params;
			params.handle = _pTexture->name;
			params.textureUnitIndex = textureIndices::Tex[_tile];
			params.mipMapLevel = mipLevel;
			params.mipMapLevels = _pTexture->max_level + 1;
			params.msaaLevel = 0;
			params.width = tmptex.realWidth;
			params.height = tmptex.realHeight;
			params.internalFormat = gfxContext.convertInternalTextureFormat(u32(glInternalFormat));
			params.format = colorFormat::RGBA;
			params.dataType = glType;
			params.data = pDest;
			gfxContext.init2DTexture(params);
		}
		if (mipLevel == _pTexture->max_level)
			break;
		++mipLevel;
		const u32 tileMipLevel = gSP.texture.tile + mipLevel + 1;
		gDPTile & mipTile = gDP.tiles[tileMipLevel];
		line = mipTile.line;
		tmptex.tMem = mipTile.tmem;
		tmptex.palette = mipTile.palette;
		tmptex.maskS = mipTile.masks;
		tmptex.maskT = mipTile.maskt;
		TileSizes sizes;
		_calcTileSizes(tileMipLevel, sizes, nullptr);
		tmptex.width = sizes.width;
		tmptex.clampWidth = sizes.clampWidth;
		tmptex.height = sizes.height;
		tmptex.clampHeight = sizes.clampHeight;
		// Insure mip-map levels size consistency.
		if (tmptex.realWidth > 1)
			tmptex.realWidth >>= 1;
		if (tmptex.realHeight > 1)
			tmptex.realHeight >>= 1;
		_pTexture->textureBytes += (tmptex.realWidth * tmptex.realHeight) << sizeShift;
	}
	if (m_curUnpackAlignment > 1)
		gfxContext.setTextureUnpackAlignment(m_curUnpackAlignment);
	free(pDest);
}

struct TextureParams
{
	u16 width;
	u16 height;
	u32 flags;
};

static
u32 _calculateCRC(u32 _t, const TextureParams & _params, u32 _bytes)
{
	const bool rgba32 = gSP.textureTile[_t]->size == G_IM_SIZ_32b;
	if (_bytes == 0) {
		const u32 lineBytes = gSP.textureTile[_t]->line << 3;
		_bytes = _params.height*lineBytes;
	}
	if (rgba32)
		_bytes >>= 1;
	const u32 tMemMask = (gDP.otherMode.textureLUT == G_TT_NONE && !rgba32) ? 0x1FF : 0xFF;
	const u64 *src = (u64*)&TMEM[gSP.textureTile[_t]->tmem & tMemMask];
	u32 crc = 0xFFFFFFFF;
	crc = CRC_Calculate(crc, src, _bytes);

	if (rgba32) {
		src = (u64*)&TMEM[gSP.textureTile[_t]->tmem + 256];
		crc = CRC_Calculate(crc, src, _bytes);
	}

	if (gDP.otherMode.textureLUT != G_TT_NONE || gSP.textureTile[_t]->format == G_IM_FMT_CI) {
		if (gSP.textureTile[_t]->size == G_IM_SIZ_4b)
			crc = CRC_Calculate( crc, &gDP.paletteCRC16[gSP.textureTile[_t]->palette], 4 );
		else if (gSP.textureTile[_t]->size == G_IM_SIZ_8b)
			crc = CRC_Calculate( crc, &gDP.paletteCRC256, 4 );
	}

	crc = CRC_Calculate(crc, &_params, sizeof(_params));

	return crc;
}

void TextureCache::activateTexture(u32 _t, CachedTexture *_pTexture)
{

	Context::TexParameters params;
	params.handle = _pTexture->name;
	if (config.video.multisampling > 0 && _pTexture->frameBufferTexture == CachedTexture::fbMultiSample) {
		params.target = textureTarget::TEXTURE_2D_MULTISAMPLE;
		params.textureUnitIndex = textureIndices::MSTex[_t];
	} else {
		params.target = textureTarget::TEXTURE_2D;
		params.textureUnitIndex = textureIndices::Tex[_t];

		const bool bUseBilinear = (gDP.otherMode.textureFilter | (gSP.objRendermode&G_OBJRM_BILERP)) != 0;
		const bool bUseLOD = currentCombiner()->usesLOD();
		const s32 texLevel = bUseLOD ? _pTexture->max_level : 0;
		params.maxMipmapLevel = Parameter(texLevel);

		if (texLevel > 0) { // Apply standard bilinear to mipmap textures
			if (bUseBilinear) {
				params.minFilter = textureParameters::FILTER_LINEAR_MIPMAP_NEAREST;
				params.magFilter = textureParameters::FILTER_LINEAR;
			} else {
				params.minFilter = textureParameters::FILTER_NEAREST_MIPMAP_NEAREST;
				params.magFilter = textureParameters::FILTER_NEAREST;
			}
		} else if (bUseBilinear && config.generalEmulation.enableLOD != 0 && bUseLOD) { // Apply standard bilinear to first tile of mipmap texture
			params.minFilter = textureParameters::FILTER_LINEAR;
			params.magFilter = textureParameters::FILTER_LINEAR;
		} else { // Don't use texture filter. Texture will be filtered by filter shader
			params.minFilter = textureParameters::FILTER_NEAREST;
			params.magFilter = textureParameters::FILTER_NEAREST;
		}

		// Set clamping modes
		params.wrapS = _pTexture->clampS ? textureParameters::WRAP_CLAMP_TO_EDGE :
			_pTexture->mirrorS ? textureParameters::WRAP_MIRRORED_REPEAT
			: textureParameters::WRAP_REPEAT;
		params.wrapT = _pTexture->clampT ? textureParameters::WRAP_CLAMP_TO_EDGE :
			_pTexture->mirrorT ? textureParameters::WRAP_MIRRORED_REPEAT
			: textureParameters::WRAP_REPEAT;

		if (dwnd().getDrawer().getDrawingState() == DrawingState::Triangle && config.texture.maxAnisotropyF > 0.0f)
			params.maxAnisotropy = Parameter(config.texture.maxAnisotropyF);
	}

	gfxContext.setTextureParameters(params);

	current[_t] = _pTexture;
}

void TextureCache::activateDummy(u32 _t)
{
	Context::TexParameters params;
	params.handle = m_pDummy->name;
	params.target = textureTarget::TEXTURE_2D;
	params.textureUnitIndex = textureIndices::Tex[_t];
	params.minFilter = textureParameters::FILTER_NEAREST;
	params.magFilter = textureParameters::FILTER_NEAREST;
	gfxContext.setTextureParameters(params);
}

void TextureCache::activateMSDummy(u32 _t)
{
	Context::TexParameters params;
	params.handle = m_pMSDummy->name;
	params.target = textureTarget::TEXTURE_2D_MULTISAMPLE;
	params.textureUnitIndex = textureIndices::MSTex[_t];
	gfxContext.setTextureParameters(params);
}

void TextureCache::_updateBackground()
{
	u32 numBytes = gSP.bgImage.width * gSP.bgImage.height << gSP.bgImage.size >> 1;
	u32 crc;

	crc = CRC_Calculate( 0xFFFFFFFF, &RDRAM[gSP.bgImage.address], numBytes );

	if (gDP.otherMode.textureLUT != G_TT_NONE || gSP.bgImage.format == G_IM_FMT_CI) {
		if (gSP.bgImage.size == G_IM_SIZ_4b)
			crc = CRC_Calculate( crc, &gDP.paletteCRC16[gSP.bgImage.palette], 4 );
		else if (gSP.bgImage.size == G_IM_SIZ_8b)
			crc = CRC_Calculate( crc, &gDP.paletteCRC256, 4 );
	}

	u32 params[4] = {gSP.bgImage.width, gSP.bgImage.height, gSP.bgImage.format, gSP.bgImage.size};
	crc = CRC_Calculate(crc, params, sizeof(u32)*4);

	Texture_Locations::iterator locations_iter = m_lruTextureLocations.find(crc);
	if (locations_iter != m_lruTextureLocations.end()) {
		Textures::iterator iter = locations_iter->second;
		CachedTexture & currentTex = *iter;
		m_textures.splice(m_textures.begin(), m_textures, iter);

		assert(currentTex.width == gSP.bgImage.width);
		assert(currentTex.height == gSP.bgImage.height);
		assert(currentTex.format == gSP.bgImage.format);
		assert(currentTex.size == gSP.bgImage.size);

		activateTexture(0, &currentTex);
		m_hits++;
		return;
	}

	m_misses++;

	CachedTexture * pCurrent = _addTexture(crc);

	pCurrent->address = gSP.bgImage.address;

	pCurrent->format = gSP.bgImage.format;
	pCurrent->size = gSP.bgImage.size;

	pCurrent->width = gSP.bgImage.width;
	pCurrent->height = gSP.bgImage.height;

	pCurrent->clampWidth = gSP.bgImage.width;
	pCurrent->clampHeight = gSP.bgImage.height;
	pCurrent->palette = gSP.bgImage.palette;
	pCurrent->maskS = 0;
	pCurrent->maskT = 0;
	pCurrent->mirrorS = 0;
	pCurrent->mirrorT = 0;
	pCurrent->clampS = 0;
	pCurrent->clampT = 0;
	pCurrent->line = 0;
	pCurrent->tMem = 0;
	pCurrent->frameBufferTexture = CachedTexture::fbNone;

	pCurrent->realWidth = gSP.bgImage.width;
	pCurrent->realHeight = gSP.bgImage.height;

	pCurrent->scaleS = 1.0f / (f32)(pCurrent->realWidth);
	pCurrent->scaleT = 1.0f / (f32)(pCurrent->realHeight);

	pCurrent->shiftScaleS = 1.0f;
	pCurrent->shiftScaleT = 1.0f;

	pCurrent->offsetS = 0.5f;
	pCurrent->offsetT = 0.5f;

	_loadBackground(pCurrent);
	activateTexture(0, pCurrent);

	m_cachedBytes += pCurrent->textureBytes;
	current[0] = pCurrent;
}

void TextureCache::_clear()
{
	current[0] = current[1] = nullptr;

	for (auto cur = m_textures.cbegin(); cur != m_textures.cend(); ++cur) {
		m_cachedBytes -= cur->textureBytes;
		gfxContext.deleteTexture(cur->name);
	}
	m_textures.clear();
	m_lruTextureLocations.clear();
}

void TextureCache::update(u32 _t)
{
	if (config.textureFilter.txHiresEnable != 0 && config.textureFilter.txDump != 0) {
		/* Force reload hi-res textures. Useful for texture artists */
		if (isKeyPressed(G64_VK_R, 0x0001)) {
			if (txfilter_reloadhirestex()) {
				_clear();
			}
		}
		/* Turn on texture dump */
		else if (isKeyPressed(G64_VK_D, 0x0001)) {
			m_toggleDumpTex = !m_toggleDumpTex;
			if (m_toggleDumpTex) {
				displayLoadProgress(L"Texture dump - ON\n");
				_clear();
				std::this_thread::sleep_for(std::chrono::seconds(1));
			}
			else {
				displayLoadProgress(L"Texture dump - OFF\n");
				std::this_thread::sleep_for(std::chrono::seconds(1));
			}
		}
	}

	const gDPTile * pTile = gSP.textureTile[_t];
	switch (pTile->textureMode) {
	case TEXTUREMODE_BGIMAGE:
		_updateBackground();
		return;
	case TEXTUREMODE_FRAMEBUFFER:
		FrameBuffer_ActivateBufferTexture( _t, pTile->frameBufferAddress );
		return;
	case TEXTUREMODE_FRAMEBUFFER_BG:
		FrameBuffer_ActivateBufferTextureBG( _t, pTile->frameBufferAddress );
		return;
	}

	if (gDP.otherMode.textureLOD == G_TL_LOD && gSP.texture.level == 0 && !currentCombiner()->usesLOD() && _t == 1) {
		current[1] = current[0];
		if (current[1] != nullptr) {
			activateTexture(1, current[1]);
			return;
		}
	}

	if (gSP.texture.tile == 7 &&
		_t == 0 &&
		gSP.textureTile[0] == gDP.loadTile &&
		gDP.loadTile->loadType == LOADTYPE_BLOCK &&
		gSP.textureTile[0]->tmem == gSP.textureTile[1]->tmem) {
		gSP.textureTile[0] = gSP.textureTile[1];
		pTile = gSP.textureTile[_t];
	}

	TileSizes sizes;
	_calcTileSizes(_t, sizes, gDP.loadTile);
	TextureParams params;
	params.flags = pTile->masks	|
		(pTile->maskt   << 4)	|
		(pTile->mirrors << 8)	|
		(pTile->mirrort << 9)	|
		(pTile->clamps << 10)	|
		(pTile->clampt << 11)	|
		(pTile->size   << 12)	|
		(pTile->format << 14)	|
		(gDP.otherMode.textureLUT << 17);
	params.width = sizes.realWidth;
	params.height = sizes.realHeight;

	const u32 crc = _calculateCRC(_t, params, sizes.bytes);

	if (current[_t] != nullptr && current[_t]->crc == crc) {
		activateTexture(_t, current[_t]);
		return;
	}

	Texture_Locations::iterator locations_iter = m_lruTextureLocations.find(crc);
	if (locations_iter != m_lruTextureLocations.end()) {
		Textures::iterator iter = locations_iter->second;
		CachedTexture & currentTex = *iter;

		if (currentTex.width == sizes.width && currentTex.height == sizes.height) {
			m_textures.splice(m_textures.begin(), m_textures, iter);

			assert(currentTex.format == pTile->format);
			assert(currentTex.size == pTile->size);

			activateTexture(_t, &currentTex);
			m_hits++;
			return;
		}

		m_cachedBytes -= currentTex.textureBytes;
		gfxContext.deleteTexture(currentTex.name);
		m_lruTextureLocations.erase(locations_iter);
		m_textures.erase(iter);
	}

	m_misses++;

	CachedTexture * pCurrent = _addTexture(crc);

	pCurrent->address = gDP.loadInfo[pTile->tmem].texAddress;

	pCurrent->format = pTile->format;
	pCurrent->size = pTile->size;

	pCurrent->width = sizes.width;
	pCurrent->height = sizes.height;

	pCurrent->clampWidth = sizes.clampWidth;
	pCurrent->clampHeight = sizes.clampHeight;

	pCurrent->palette = pTile->palette;
/*	pCurrent->fulS = gSP.textureTile[t]->fulS;
	pCurrent->fulT = gSP.textureTile[t]->fulT;
	pCurrent->ulS = gSP.textureTile[t]->ulS;
	pCurrent->ulT = gSP.textureTile[t]->ulT;
	pCurrent->lrS = gSP.textureTile[t]->lrS;
	pCurrent->lrT = gSP.textureTile[t]->lrT;*/
	pCurrent->maskS = pTile->masks;
	pCurrent->maskT = pTile->maskt;
	pCurrent->mirrorS = pTile->mirrors;
	pCurrent->mirrorT = pTile->mirrort;
	pCurrent->clampS = pTile->clamps;
	pCurrent->clampT = pTile->clampt;
	pCurrent->line = pTile->line;
	pCurrent->tMem = pTile->tmem;
	pCurrent->frameBufferTexture = CachedTexture::fbNone;

	pCurrent->realWidth = sizes.realWidth;
	pCurrent->realHeight = sizes.realHeight;

	pCurrent->scaleS = 1.0f / (f32)(pCurrent->realWidth);
	pCurrent->scaleT = 1.0f / (f32)(pCurrent->realHeight);

	pCurrent->offsetS = 0.5f;
	pCurrent->offsetT = 0.5f;

	_load(_t, pCurrent);
	activateTexture( _t, pCurrent );

	m_cachedBytes += pCurrent->textureBytes;
	current[_t] = pCurrent;
}

void getTextureShiftScale(u32 t, const TextureCache & cache, f32 & shiftScaleS, f32 & shiftScaleT)
{
	if (gSP.textureTile[t]->textureMode != TEXTUREMODE_NORMAL) {
		shiftScaleS = cache.current[t]->shiftScaleS;
		shiftScaleT = cache.current[t]->shiftScaleT;
		return;
	}

	if (gDP.otherMode.textureLOD == G_TL_LOD && gSP.texture.level == 0 && !currentCombiner()->usesLOD())
		t = 0;

	if (gSP.textureTile[t]->shifts > 10)
		shiftScaleS = (f32)(1 << (16 - gSP.textureTile[t]->shifts));
	else if (gSP.textureTile[t]->shifts > 0)
		shiftScaleS /= (f32)(1 << gSP.textureTile[t]->shifts);

	if (gSP.textureTile[t]->shiftt > 10)
		shiftScaleT = (f32)(1 << (16 - gSP.textureTile[t]->shiftt));
	else if (gSP.textureTile[t]->shiftt > 0)
		shiftScaleT /= (f32)(1 << gSP.textureTile[t]->shiftt);
}
