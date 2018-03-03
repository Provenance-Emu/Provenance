#ifndef GDP_H
#define GDP_H

#include "Types.h"

#define CHANGED_RENDERMODE		0x001
#define CHANGED_CYCLETYPE		0x002
#define CHANGED_SCISSOR			0x004
#define CHANGED_TMEM			0x008
#define CHANGED_TILE			0x010
//#define CHANGED_COMBINE_COLORS	0x020
#define CHANGED_COMBINE			0x040
#define CHANGED_ALPHACOMPARE	0x080
#define CHANGED_FOGCOLOR		0x100
#define CHANGED_BLENDCOLOR      0x200
#define CHANGED_FB_TEXTURE	    0x400
#define CHANGED_COLORBUFFER		0x1000
#define CHANGED_CPU_FB_WRITE	0x2000

#define TEXTUREMODE_NORMAL			0
#define TEXTUREMODE_BGIMAGE			2
#define TEXTUREMODE_FRAMEBUFFER		3
#define TEXTUREMODE_FRAMEBUFFER_BG	4

#define LOADTYPE_BLOCK			0
#define LOADTYPE_TILE			1

struct gDPCombine
{
	union
	{
		struct
		{
			// muxs1
			unsigned	aA1		: 3;
			unsigned	sbA1	: 3;
			unsigned	aRGB1	: 3;
			unsigned	aA0		: 3;
			unsigned	sbA0	: 3;
			unsigned	aRGB0	: 3;
			unsigned	mA1		: 3;
			unsigned	saA1	: 3;
			unsigned	sbRGB1	: 4;
			unsigned	sbRGB0	: 4;

			// muxs0
			unsigned	mRGB1	: 5;
			unsigned	saRGB1	: 4;
			unsigned	mA0		: 3;
			unsigned	saA0	: 3;
			unsigned	mRGB0	: 5;
			unsigned	saRGB0	: 4;
		};

		struct
		{
			u32			muxs1, muxs0;
		};

		u64				mux;
	};
};

struct FrameBuffer;
struct gDPTile
{
	u32 format, size, line, tmem, palette;

	union
	{
		struct
		{
			unsigned	mirrort	: 1;
			unsigned	clampt	: 1;
			unsigned	pad0	: 30;

			unsigned	mirrors	: 1;
			unsigned	clamps	: 1;
			unsigned	pad1	: 30;
		};

		struct
		{
			u32 cmt, cms;
		};
	};

	u32 maskt, masks;
	u32 shiftt, shifts;
	f32 fuls, fult, flrs, flrt;
	u32 uls, ult, lrs, lrt;

	u32 textureMode;
	u32 loadType;
	u32 imageAddress;
	u32 frameBufferAddress;
};

struct gDPLoadTileInfo {
	u8 size;
	u8 loadType;
	u16 uls;
	u16 ult;
	u16 lrs;
	u16 lrt;
	u16 width;
	u16 height;
	u16 texWidth;
	u32 texAddress;
	u32 dxt;
	u32 bytes;
};

struct gDPScissor
{
	u32 mode;
	f32 ulx, uly, lrx, lry;
};

struct gDPInfo
{
	struct OtherMode
	{
		union
		{
			struct
			{
				unsigned int alphaCompare : 2;
				unsigned int depthSource : 1;

//				struct
//				{
					unsigned int AAEnable : 1;
					unsigned int depthCompare : 1;
					unsigned int depthUpdate : 1;
					unsigned int imageRead : 1;
					unsigned int colorOnCvg : 1;

					unsigned int cvgDest : 2;
					unsigned int depthMode : 2;

					unsigned int cvgXAlpha : 1;
					unsigned int alphaCvgSel : 1;
					unsigned int forceBlender : 1;
					unsigned int textureEdge : 1;
//				} renderMode;

//				struct
//				{
					unsigned int c2_m2b : 2;
					unsigned int c1_m2b : 2;
					unsigned int c2_m2a : 2;
					unsigned int c1_m2a : 2;
					unsigned int c2_m1b : 2;
					unsigned int c1_m1b : 2;
					unsigned int c2_m1a : 2;
					unsigned int c1_m1a : 2;
//				} blender;

				unsigned int blendMask : 4;
				unsigned int alphaDither : 2;
				unsigned int colorDither : 2;

				unsigned int combineKey : 1;
//				unsigned int textureConvert : 3;
				unsigned int convert_one : 1;
				unsigned int bi_lerp1 : 1;
				unsigned int bi_lerp0 : 1;

				unsigned int textureFilter : 2;
				unsigned int textureLUT : 2;

				unsigned int textureLOD : 1;
				unsigned int textureDetail : 2;
				unsigned int texturePersp : 1;
				unsigned int cycleType : 2;
				unsigned int unusedColorDither : 1; // unsupported
				unsigned int pipelineMode : 1;

				unsigned int pad : 8;

			};

			u64			_u64;

			struct
			{
				u32			l, h;
			};
		};
	} otherMode;

	gDPCombine combine;

	gDPTile tiles[8], *loadTile;
	u32 loadTileIdx;

	struct Color
	{
		Color() : r(0), g(0), b(0), a(0) {}
		f32 r, g, b, a;
	} fogColor,  blendColor, envColor, rectColor;

	struct FillColor
	{
		f32 z, dz;
		u32 color;
	} fillColor;

	struct PrimColor : public Color
	{
		f32 l, m;
	} primColor;

	struct
	{
		f32 z, deltaZ;
	} primDepth;

	struct
	{
		u32 format, size, width, bpl;
		u32 address;
	} textureImage;

	struct
	{
		u32 format, size, width, height, bpl;
		u32 address, changed;
	} colorImage;

	u32	depthImageAddress;

	gDPScissor scissor;

	struct
	{
		s32 k0, k1, k2, k3, k4, k5;
	} convert;

	struct
	{
		Color center, scale, width;
	} key;

	u32 changed;

	u16 TexFilterPalette[512];
	u32 paletteCRC16[16];
	u32 paletteCRC256;
	u32 half_1, half_2;

	 gDPLoadTileInfo loadInfo[512];
};

extern gDPInfo gDP;

void gDPSetOtherMode( u32 mode0, u32 mode1 );
void gDPSetPrimDepth( u16 z, u16 dz );
void gDPSetTexturePersp( u32 enable );
void gDPSetTextureLUT( u32 mode );
void gDPSetCombine( s32 muxs0, s32 muxs1 );
void gDPSetColorImage( u32 format, u32 size, u32 width, u32 address );
void gDPSetTextureImage( u32 format, u32 size, u32 width, u32 address );
void gDPSetDepthImage( u32 address );
void gDPSetEnvColor( u32 r, u32 g, u32 b, u32 a );
void gDPSetBlendColor( u32 r, u32 g, u32 b, u32 a );
void gDPSetFogColor( u32 r, u32 g, u32 b, u32 a );
void gDPSetFillColor( u32 c );
void gDPGetFillColor(f32 _fillColor[4]);
void gDPSetPrimColor( u32 m, u32 l, u32 r, u32 g, u32 b, u32 a );
void gDPSetTile( u32 format, u32 size, u32 line, u32 tmem, u32 tile, u32 palette, u32 cmt, u32 cms, u32 maskt, u32 masks, u32 shiftt, u32 shifts );
void gDPSetTileSize( u32 tile, u32 uls, u32 ult, u32 lrs, u32 lrt );
void gDPLoadTile( u32 tile, u32 uls, u32 ult, u32 lrs, u32 lrt );
void gDPLoadBlock( u32 tile, u32 uls, u32 ult, u32 lrs, u32 dxt );
void gDPLoadTLUT( u32 tile, u32 uls, u32 ult, u32 lrs, u32 lrt );
void gDPSetScissor( u32 mode, f32 ulx, f32 uly, f32 lrx, f32 lry );
void gDPFillRectangle( s32 ulx, s32 uly, s32 lrx, s32 lry );
void gDPSetConvert( s32 k0, s32 k1, s32 k2, s32 k3, s32 k4, s32 k5 );
void gDPSetKeyR( u32 cR, u32 sR, u32 wR );
void gDPSetKeyGB(u32 cG, u32 sG, u32 wG, u32 cB, u32 sB, u32 wB );
void gDPTextureRectangle( f32 ulx, f32 uly, f32 lrx, f32 lry, s32 tile, s16 s, s16 t, f32 dsdx, f32 dtdy, bool flip );
void gDPFullSync();
void gDPTileSync();
void gDPPipeSync();
void gDPLoadSync();
void gDPNoOp();

void gDPTriFill( u32 w0, u32 w1 );
void gDPTriShade( u32 w0, u32 w1 );
void gDPTriTxtr( u32 w0, u32 w1 );
void gDPTriShadeTxtr( u32 w0, u32 w1 );
void gDPTriFillZ( u32 w0, u32 w1 );
void gDPTriShadeZ( u32 w0, u32 w1 );
void gDPTriTxtrZ( u32 w0, u32 w1 );
void gDPTriShadeTxtrZ( u32 w0, u32 w1 );

#endif

