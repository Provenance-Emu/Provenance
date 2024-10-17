#include <assert.h>
#include <algorithm>
#include "S2DEX.h"
#include "F3D.h"
#include "F3DEX.h"
#include "GBI.h"
#include "gSP.h"
#include "gDP.h"
#include "RSP.h"
#include "RDP.h"
#include "../Config.h"
#include "Log.h"
#include "DebugDump.h"
#include "DepthBuffer.h"
#include "FrameBuffer.h"

#include <Graphics/Context.h>
#include <Graphics/Parameters.h>
#include "DisplayWindow.h"

using namespace graphics;

#define S2DEX_MV_MATRIX			0
#define S2DEX_MV_SUBMUTRIX		2
#define S2DEX_MV_VIEWPORT		8

#define	S2DEX_BG_1CYC			0x01
#define	S2DEX_BG_COPY			0x02
#define	S2DEX_OBJ_RECTANGLE		0x03
#define	S2DEX_OBJ_SPRITE		0x04
#define	S2DEX_OBJ_MOVEMEM		0x05
#define	S2DEX_LOAD_UCODE		0xAF
#define	S2DEX_SELECT_DL			0xB0
#define	S2DEX_OBJ_RENDERMODE	0xB1
#define	S2DEX_OBJ_RECTANGLE_R	0xB2
#define	S2DEX_OBJ_LOADTXTR		0xC1
#define	S2DEX_OBJ_LDTX_SPRITE	0xC2
#define	S2DEX_OBJ_LDTX_RECT		0xC3
#define	S2DEX_OBJ_LDTX_RECT_R	0xC4
#define	S2DEX_RDPHALF_0			0xE4

// Tile indices
#define G_TX_LOADTILE			0x07
#define G_TX_RENDERTILE			0x00

struct uObjScaleBg
{
	u16 imageW;     /* Texture width (8-byte alignment, u10.2) */
	u16 imageX;     /* x-coordinate of upper-left
					position of texture (u10.5) */
	u16 frameW;     /* Transfer destination frame width (u10.2) */
	s16 frameX;     /* x-coordinate of upper-left
					position of transfer destination frame (s10.2) */

	u16 imageH;     /* Texture height (u10.2) */
	u16 imageY;     /* y-coordinate of upper-left position of
					texture (u10.5) */
	u16 frameH;     /* Transfer destination frame height (u10.2) */
	s16 frameY;     /* y-coordinate of upper-left position of transfer
					destination  frame (s10.2) */

	u32 imagePtr;  /* Address of texture source in DRAM*/
	u8  imageSiz;   /* Texel size
					G_IM_SIZ_4b (4 bits/texel)
					G_IM_SIZ_8b (8 bits/texel)
					G_IM_SIZ_16b (16 bits/texel)
					G_IM_SIZ_32b (32 bits/texel) */
	u8  imageFmt;   /*Texel format
					G_IM_FMT_RGBA (RGBA format)
					G_IM_FMT_YUV (YUV format)
					G_IM_FMT_CI (CI format)
					G_IM_FMT_IA (IA format)
					G_IM_FMT_I (I format)  */
	u16 imageLoad;  /* Method for loading the BG image texture
					G_BGLT_LOADBLOCK (use LoadBlock)
					G_BGLT_LOADTILE (use LoadTile) */
	u16 imageFlip;  /* Image inversion on/off (horizontal
					direction only)
					0 (normal display (no inversion))
					G_BG_FLAG_FLIPS (horizontal inversion of texture image) */
	u16 imagePal;   /* Position of palette for 4-bit color
					index texture (4-bit precision, 0~15) */

	u16 scaleH;      /* y-direction scale value (u5.10) */
	u16 scaleW;      /* x-direction scale value (u5.10) */
	s32 imageYorig;  /* image drawing origin (s20.5)*/

	u8  padding[4];  /* Padding */
};   /* 40 bytes */

struct uObjSprite
{
	u16 scaleW;      /* Width-direction scaling (u5.10) */
	s16 objX;        /* x-coordinate of upper-left corner of OBJ (s10.2) */
	u16 paddingX;    /* Unused (always 0) */
	u16 imageW;      /* Texture width (length in s direction, u10.5)  */
	u16 scaleH;      /* Height-direction scaling (u5.10) */
	s16 objY;        /* y-coordinate of upper-left corner of OBJ (s10.2) */
	u16 paddingY;    /* Unused (always 0) */
	u16 imageH;      /* Texture height (length in t direction, u10.5)  */
	u16 imageAdrs;   /* Texture starting position in TMEM (In units of 64-bit words) */
	u16 imageStride; /* Texel wrapping width (In units of 64-bit words) */
	u8  imageFlags;  /* Display flag
					 (*) More than one of the following flags can be specified as the bit sum of the flags:
					 0 (Normal display (no inversion))
					 G_OBJ_FLAG_FLIPS (s-direction (x) inversion)
					 G_OBJ_FLAG_FLIPT (t-direction (y) inversion)  */
	u8  imagePal;    /* Position of palette for 4-bit color index texture  (4-bit precision, 0~7)  */
	u8  imageSiz;    /* Texel size
					 G_IM_SIZ_4b (4 bits/texel)
					 G_IM_SIZ_8b (8 bits/texel)
					 G_IM_SIZ_16b (16 bits/texel)
					 G_IM_SIZ_32b (32 bits/texel) */
	u8  imageFmt;    /* Texel format
					 G_IM_FMT_RGBA (RGBA format)
					 G_IM_FMT_YUV (YUV format)
					 G_IM_FMT_CI (CI format)
					 G_IM_FMT_IA (IA format)
					 G_IM_FMT_I  (I format) */
};    /* 24 bytes */

struct uObjTxtrBlock
{
	u32   type;   /* Structure identifier (G_OBJLT_TXTRBLOCK) */
	u32   image; /* Texture source address in DRAM (8-byte alignment) */
	u16   tsize;  /* Texture size (specified by GS_TB_TSIZE) */
	u16   tmem;   /* TMEM word address where texture will be loaded (8-byte word) */
	u16   sid;    /* Status ID (multiple of 4: either 0, 4, 8, or 12) */
	u16   tline;  /* Texture line width (specified by GS_TB_TLINE) */
	u32   flag;   /* Status flag */
	u32   mask;   /* Status mask */
};     /* 24 bytes */

struct uObjTxtrTile
{
	u32   type;   /* Structure identifier (G_OBJLT_TXTRTILE) */
	u32   image; /* Texture source address in DRAM (8-byte alignment) */
	u16   twidth; /* Texture width (specified by GS_TT_TWIDTH) */
	u16   tmem;   /* TMEM word address where texture will be loaded (8-byte word) */
	u16   sid;    /* Status ID (multiple of 4: either 0, 4, 8, or 12) */
	u16   theight;/* Texture height (specified by GS_TT_THEIGHT) */
	u32   flag;   /* Status flag */
	u32   mask;   /* Status mask  */
};      /* 24 bytes */

struct uObjTxtrTLUT
{
	u32   type;   /* Structure identifier (G_OBJLT_TLUT) */
	u32   image; /* Texture source address in DRAM */
	u16   pnum;   /* Number of palettes to load - 1 */
	u16   phead;  /* Palette position at start of load (256~511) */
	u16   sid;    /* Status ID (multiple of 4: either 0, 4, 8, or 12) */
	u16   zero;   /* Always assign 0 */
	u32   flag;   /* Status flag */
	u32   mask;   /* Status mask */
};      /* 24 bytes */

typedef union
{
	uObjTxtrBlock      block;
	uObjTxtrTile       tile;
	uObjTxtrTLUT       tlut;
} uObjTxtr;

struct uObjTxSprite
{
	uObjTxtr      txtr;
	uObjSprite    sprite;
};

struct uObjMtx
{
	s32 A, B, C, D;   /* s15.16 */
	s16 Y, X;         /* s10.2 */
	u16 BaseScaleY;   /* u5.10 */
	u16 BaseScaleX;   /* u5.10 */
};

struct uObjSubMtx
{
	s16 Y, X;		/* s10.2  */
	u16 BaseScaleY;	/* u5.10  */
	u16 BaseScaleX;	/* u5.10  */
};

static uObjMtx objMtx;

void resetObjMtx()
{
	objMtx.A = 1 << 16;
	objMtx.B = 0;
	objMtx.C = 0;
	objMtx.D = 1 << 16;
	objMtx.X = 0;
	objMtx.Y = 0;
	objMtx.BaseScaleX = 1 << 10;
	objMtx.BaseScaleY = 1 << 10;
}

static
bool gs_bVer1_3 = true;

struct S2DEXCoordCorrector
{
	S2DEXCoordCorrector()
	{
		static const u32 CorrectorsA01[] = {
			0x00000000,
			0x00100020,
			0x00200040,
			0x00300060,
			0x0000FFF4,
			0x00100014,
			0x00200034,
			0x00300054
		};
		static const s16 * CorrectorsA01_16 = reinterpret_cast<const s16*>(CorrectorsA01);

		static const u32 CorrectorsA23[] = {
			0x0001FFFE,
			0xFFFEFFFE,
			0x00010000,
			0x00000000
		};
		static const s16 * CorrectorsA23_16 = reinterpret_cast<const s16*>(CorrectorsA23);

		const u32 O1 = (gSP.objRendermode & (G_OBJRM_SHRINKSIZE_1 | G_OBJRM_SHRINKSIZE_2 | G_OBJRM_WIDEN)) >> 3;
		A0 = CorrectorsA01_16[(0 + O1) ^ 1];
		A1 = CorrectorsA01_16[(1 + O1) ^ 1];
		const u32 O2 = (gSP.objRendermode & (G_OBJRM_SHRINKSIZE_1 | G_OBJRM_BILERP)) >> 2;
		A2 = CorrectorsA23_16[(0 + O2) ^ 1];
		A3 = CorrectorsA23_16[(1 + O2) ^ 1];

		const s16 * CorrectorsB03_16 = nullptr;
		u32 O3 = 0;
		if (gs_bVer1_3) {
			static const u32 CorrectorsB03_v1_3[] = {
				0xFFFC0000,
				0x00000000,
				0x00000001,
				0x00000000,
				0xFFFC0000,
				0x00000000,
				0x00000001,
				0xFFFF0001,
				0xFFFC0000,
				0x00030000,
				0x00000001,
				0x00000000,
				0xFFFC0000,
				0x00030000,
				0x00000001,
				0xFFFF0000,
				0xFFFF0003,
				0x0000FFF0,
				0x00000001,
				0x0000FFFF,
				0xFFFF0003,
				0x0000FFF0,
				0x00000001,
				0xFFFFFFFF,
				0xFFFF0003,
				0x0000FFF0,
				0x00000000,
				0x00000000,
				0xFFFF0003,
				0x0000FFF0,
				0x00000000,
				0xFFFF0000
			};
			CorrectorsB03_16 = reinterpret_cast<const s16*>(CorrectorsB03_v1_3);
			O3 = (_SHIFTL(gSP.objRendermode, 3, 16) & (G_OBJRM_SHRINKSIZE_1 | G_OBJRM_SHRINKSIZE_2 | G_OBJRM_WIDEN)) >> 1;
		} else {
			static const u32 CorrectorsB03[] = {
				0xFFFC0000,
				0x00000001,
				0xFFFF0003,
				0xFFF00000
			};
			CorrectorsB03_16 = reinterpret_cast<const s16*>(CorrectorsB03);
			O3 = (gSP.objRendermode & G_OBJRM_BILERP) >> 1;
		}
		B0 = CorrectorsB03_16[(0 + O3) ^ 1];
		B2 = CorrectorsB03_16[(2 + O3) ^ 1];
		B3 = CorrectorsB03_16[(3 + O3) ^ 1];
	}

	s16 A0, A1, A2, A3, B0, B2, B3;
};

struct ObjCoordinates
{
	f32 ulx, uly, lrx, lry;
	f32 uls, ult, lrs, lrt;
	f32 z, w;

	ObjCoordinates(const uObjSprite *_pObjSprite, bool _useMatrix)
	{
		/* Fixed point coordinates calculation. Decoded by olivieryuyu */
		S2DEXCoordCorrector CC;
		s16 xh, xl, yh, yl;
		s16 sh, sl, th, tl;
		auto calcST = [&](s16 B, u32 scaleH) {
			sh = CC.A0 + B;
			sl = sh + _pObjSprite->imageW + CC.A0 - CC.A1 - 1;
			th = sh - (((yh & 3) * 0x0200 * scaleH) >> 16);
			tl = th + _pObjSprite->imageH + CC.A0 - CC.A1 - 1;
		};
		if (_useMatrix) {
			const u32 scaleW = (u32(objMtx.BaseScaleX) * 0x40 * _pObjSprite->scaleW) >> 16;
			const u32 scaleH = (u32(objMtx.BaseScaleY) * 0x40 * _pObjSprite->scaleH) >> 16;
			if (gs_bVer1_3) {
				// XH = AND ((((objX << 0x10) * 0x0800 * (0x80007FFF/BaseScaleX)) >> 0x30) + X + A2) by B0
				// XL = XH + AND (((((imageW - A1) * 0x100) *  (0x80007FFF/scaleW)) >> 0x20) + B2) by B0
				// YH = AND ((((objY << 0x10) * 0x0800 * (0x80007FFF/BaseScaleY)) >> 0x30) + Y + A2) by B0
				// YL = YH + AND (((((imageH - A1) * 0x100) *  (0x80007FFF/scaleH)) >> 0x20) + B2) by B0
				xh = static_cast<s16>(((((s64(_pObjSprite->objX) << 27) * (0x80007FFFU / u32(objMtx.BaseScaleX))) >> 0x30) + objMtx.X + CC.A2) & CC.B0);
				xl = static_cast<s16>((((((s64(_pObjSprite->imageW) - CC.A1) << 8) * (0x80007FFFU / scaleW)) >> 0x20) + CC.B2) & CC.B0) + xh;
				yh = static_cast<s16>(((((s64(_pObjSprite->objY) << 27) * (0x80007FFFU / u32(objMtx.BaseScaleY))) >> 0x30) + objMtx.Y + CC.A2) & CC.B0);
				yl = static_cast<s16>((((((s64(_pObjSprite->imageH) - CC.A1) << 8) * (0x80007FFFU / scaleH)) >> 0x20) + CC.B2) & CC.B0) + yh;
				calcST(CC.B3, scaleH);
			} else {
				// XHP = ((objX << 16) * 0x0800 * (0x80007FFF / BaseScaleX)) >> 16 + ((AND(X + A2) by B0) << 16))
				// XH = XHP >> 16
				// XLP = XHP + (((ImageW - A1) << 24) * (0x80007FFF / scaleW)) >> 32
				// XL = XLP >> 16
				// YHP = ((objY << 16) * 0x0800 * (0x80007FFF / BaseScaleY)) >> 16 + ((AND(Y + A2) by B0) << 16))
				// YH = YHP >> 16
				// YLP = YHP + (((ImageH - A1) << 24) * (0x80007FFF / scaleH)) >> 32
				// YL = YLP >> 16
				const s32 xhp = ((((s64(_pObjSprite->objX) << 16) * 0x0800) * (0x80007FFFU / u32(objMtx.BaseScaleX))) >> 32) + (((objMtx.X + CC.A2) & CC.B0) << 16);
				xh = static_cast<s16>(xhp >> 16);
				const s32 xlp = xhp + ((((u64(_pObjSprite->imageW) - CC.A1) << 24) * (0x80007FFFU / scaleW)) >> 32);
				xl = static_cast<s16>(xlp >> 16);
				const s32 yhp = ((((s64(_pObjSprite->objY) << 16) * 0x0800) * (0x80007FFFU / u32(objMtx.BaseScaleY))) >> 32) + (((objMtx.Y + CC.A2) & CC.B0) << 16);
				yh = static_cast<s16>(yhp >> 16);
				const s32 ylp = yhp + ((((u64(_pObjSprite->imageH) - CC.A1) << 24) * (0x80007FFFU / scaleH)) >> 32);
				yl = static_cast<s16>(ylp >> 16);
				calcST(CC.B2, scaleH);
			}
		} else {
			// XH = AND(objX + A2) by B0
			// XL = ((AND(objX + A2) by B0) << 16) + (((ImageW - A1) << 24)*(0x80007FFF / scaleW)) >> 48
			// YH = AND(objY + A2) by B0
			// YL = ((AND(objY + A2) by B0) << 16) + (((ImageH - A1) << 24)*(0x80007FFF / scaleH)) >> 48
			xh = (_pObjSprite->objX + CC.A2) & CC.B0;
			xl = static_cast<s16>((((u64(_pObjSprite->imageW) - CC.A1) << 24) * (0x80007FFFU / u32(_pObjSprite->scaleW))) >> 48) + xh;
			yh = (_pObjSprite->objY + CC.A2) & CC.B0;
			yl = static_cast<s16>((((u64(_pObjSprite->imageH) - CC.A1) << 24) * (0x80007FFFU / u32(_pObjSprite->scaleH))) >> 48) + yh;
			calcST(CC.B2, _pObjSprite->scaleH);
		}

		ulx = _FIXED2FLOAT(xh, 2);
		lrx = _FIXED2FLOAT(xl, 2);
		uly = _FIXED2FLOAT(yh, 2);
		lry = _FIXED2FLOAT(yl, 2);

		uls = _FIXED2FLOAT(sh, 5);
		lrs = _FIXED2FLOAT(sl, 5);
		ult = _FIXED2FLOAT(th, 5);
		lrt = _FIXED2FLOAT(tl, 5);

		if ((_pObjSprite->imageFlags & G_BG_FLAG_FLIPS) != 0)
			std::swap(uls, lrs);
		if ((_pObjSprite->imageFlags & G_BG_FLAG_FLIPT) != 0)
			std::swap(ult, lrt);

		z = (gDP.otherMode.depthSource == G_ZS_PRIM) ? gDP.primDepth.z : gSP.viewport.nearz;
		w = 1.0f;
	}

	ObjCoordinates(const uObjScaleBg * _pObjScaleBg)
	{
		const f32 frameX = _FIXED2FLOAT(_pObjScaleBg->frameX, 2);
		const f32 frameY = _FIXED2FLOAT(_pObjScaleBg->frameY, 2);
		const f32 imageX = gSP.bgImage.imageX;
		const f32 imageY = gSP.bgImage.imageY;
		f32 scaleW = gSP.bgImage.scaleW;
		f32 scaleH = gSP.bgImage.scaleH;

		// gSPBgRectCopy() does not support scaleW and scaleH
		if (gDP.otherMode.cycleType == G_CYC_COPY) {
			scaleW = 1.0f;
			scaleH = 1.0f;
		}

		f32 frameW = _FIXED2FLOAT(_pObjScaleBg->frameW, 2);
		f32 frameH = _FIXED2FLOAT(_pObjScaleBg->frameH, 2);
		f32 imageW = (f32)(_pObjScaleBg->imageW >> 2);
		f32 imageH = (f32)(_pObjScaleBg->imageH >> 2);
		//		const f32 imageW = (f32)gSP.bgImage.width;
		//		const f32 imageH = (f32)gSP.bgImage.height;

		if (u32(imageW) == 512 && (config.generalEmulation.hacks & hack_RE2) != 0) {
			const f32 width = f32(*REG.VI_WIDTH);
			const f32 scale = imageW / width;
			imageW = width;
			frameW = width;
			imageH *= scale;
			frameH *= scale;
			scaleW = 1.0f;
			scaleH = 1.0f;
		}

		uls = imageX;
		ult = imageY;
		lrs = uls + std::min(imageW, frameW * scaleW) - 1;
		lrt = ult + std::min(imageH, frameH * scaleH) - 1;

		gSP.bgImage.clampS = lrs <= (imageW - 1) ? 1 : 0 ;
		gSP.bgImage.clampT = lrt <= (imageH - 1) ? 1 : 0 ;

		// G_CYC_COPY (gSPBgRectCopy()) does not allow texture filtering
		if (gDP.otherMode.cycleType != G_CYC_COPY) {
			// Correct texture coordinates -0.5f and +0.5 if G_OBJRM_BILERP 
			// bilinear interpolation is set
			if (gDP.otherMode.textureFilter == G_TF_BILERP) {
				uls -= 0.5f;
				ult -= 0.5f;
				lrs += 0.5f;
				lrt += 0.5f;
			}
			// SHRINKSIZE_1 adds a 0.5f perimeter around the image
			// upper left texture coords += 0.5f; lower left texture coords -= 0.5f
			if ((gSP.objRendermode&G_OBJRM_SHRINKSIZE_1) != 0) {
				uls += 0.5f;
				ult += 0.5f;
				lrs -= 0.5f;
				lrt -= 0.5f;
				// SHRINKSIZE_2 adds a 1.0f perimeter 
				// upper left texture coords += 1.0f; lower left texture coords -= 1.0f
			}
			else if ((gSP.objRendermode&G_OBJRM_SHRINKSIZE_2) != 0) {
				uls += 1.0f;
				ult += 1.0f;
				lrs -= 1.0f;
				lrt -= 1.0f;
			}
		}

		// Calculate lrx and lry width new ST values
		ulx = frameX;
		uly = frameY;
		lrx = ulx + (lrs - uls) / scaleW;
		lry = uly + (lrt - ult) / scaleH;
		if (((gSP.objRendermode&G_OBJRM_BILERP) == 0 && gDP.otherMode.textureFilter != G_TF_BILERP) ||
			((gSP.objRendermode&G_OBJRM_BILERP) != 0 && gDP.otherMode.textureFilter == G_TF_POINT && (gSP.objRendermode&G_OBJRM_NOTXCLAMP) != 0)) {
			lrx += 1.0f / scaleW;
			lry += 1.0f / scaleH;
		}

		// gSPBgRect1Cyc() and gSPBgRectCopy() do only support 
		// imageFlip in horizontal direction
		if ((_pObjScaleBg->imageFlip & G_BG_FLAG_FLIPS) != 0) {
			std::swap(ulx, lrx);
		}

		z = (gDP.otherMode.depthSource == G_ZS_PRIM) ? gDP.primDepth.z : gSP.viewport.nearz;
		w = 1.0f;
	}
};

static
u16 _YUVtoRGBA(u8 y, u8 u, u8 v)
{
	float r = y + (1.370705f * (v - 128));
	float g = y - (0.698001f * (v - 128)) - (0.337633f * (u - 128));
	float b = y + (1.732446f * (u - 128));
	r *= 0.125f;
	g *= 0.125f;
	b *= 0.125f;
	//clipping the result
	if (r > 31) r = 31;
	if (g > 31) g = 31;
	if (b > 31) b = 31;
	if (r < 0) r = 0;
	if (g < 0) g = 0;
	if (b < 0) b = 0;

	u16 c = (u16)(((u16)(r) << 11) |
		((u16)(g) << 6) |
		((u16)(b) << 1) | 1);
	return c;
}

static
void _drawYUVImageToFrameBuffer(const ObjCoordinates & _objCoords)
{
	const u32 ulx = (u32)_objCoords.ulx;
	const u32 uly = (u32)_objCoords.uly;
	const u32 lrx = (u32)_objCoords.lrx;
	const u32 lry = (u32)_objCoords.lry;
	const u32 ci_width = gDP.colorImage.width;
	const u32 ci_height = (u32)gDP.scissor.lry;
	if (ulx >= ci_width)
		return;
	if (uly >= ci_height)
		return;
	u32 width = 16, height = 16;
	if (lrx > ci_width)
		width = ci_width - ulx;
	if (lry > ci_height)
		height = ci_height - uly;
	u32 * mb = (u32*)(RDRAM + gDP.textureImage.address); //pointer to the first macro block
	u16 * dst = (u16*)(RDRAM + gDP.colorImage.address);
	dst += ulx + uly * ci_width;
	//yuv macro block contains 16x16 texture. we need to put it in the proper place inside cimg
	for (u16 h = 0; h < 16; h++) {
		for (u16 w = 0; w < 16; w += 2) {
			u32 t = *(mb++); //each u32 contains 2 pixels
			if ((h < height) && (w < width)) //clipping. texture image may be larger than color image
			{
				u8 y0 = (u8)t & 0xFF;
				u8 v = (u8)(t >> 8) & 0xFF;
				u8 y1 = (u8)(t >> 16) & 0xFF;
				u8 u = (u8)(t >> 24) & 0xFF;
				*(dst++) = _YUVtoRGBA(y0, u, v);
				*(dst++) = _YUVtoRGBA(y1, u, v);
			}
		}
		dst += ci_width - 16;
	}
	FrameBuffer *pBuffer = frameBufferList().getCurrent();
	if (pBuffer != nullptr)
		pBuffer->m_isOBScreen = true;
}

static
void gSPDrawObjRect(const ObjCoordinates & _coords)
{
	GraphicsDrawer & drawer = dwnd().getDrawer();
	drawer.setDMAVerticesSize(4);
	SPVertex * pVtx = drawer.getDMAVerticesData();
	SPVertex & vtx0 = pVtx[0];
	vtx0.x = _coords.ulx;
	vtx0.y = _coords.uly;
	vtx0.z = _coords.z;
	vtx0.w = _coords.w;
	vtx0.s = _coords.uls;
	vtx0.t = _coords.ult;
	SPVertex & vtx1 = pVtx[1];
	vtx1.x = _coords.lrx;
	vtx1.y = _coords.uly;
	vtx1.z = _coords.z;
	vtx1.w = _coords.w;
	vtx1.s = _coords.lrs;
	vtx1.t = _coords.ult;
	SPVertex & vtx2 = pVtx[2];
	vtx2.x = _coords.ulx;
	vtx2.y = _coords.lry;
	vtx2.z = _coords.z;
	vtx2.w = _coords.w;
	vtx2.s = _coords.uls;
	vtx2.t = _coords.lrt;
	SPVertex & vtx3 = pVtx[3];
	vtx3.x = _coords.lrx;
	vtx3.y = _coords.lry;
	vtx3.z = _coords.z;
	vtx3.w = _coords.w;
	vtx3.s = _coords.lrs;
	vtx3.t = _coords.lrt;

	drawer.drawScreenSpaceTriangle(4);
}

static
void gSPSetSpriteTile(const uObjSprite *_pObjSprite)
{
	const u32 w = std::max(_pObjSprite->imageW >> 5, 1);
	const u32 h = std::max(_pObjSprite->imageH >> 5, 1);

	gDPSetTile( _pObjSprite->imageFmt, _pObjSprite->imageSiz, _pObjSprite->imageStride, _pObjSprite->imageAdrs, G_TX_RENDERTILE, _pObjSprite->imagePal, G_TX_NOMIRROR | G_TX_CLAMP, G_TX_NOMIRROR | G_TX_CLAMP, 0, 0, 0, 0 );
	gDPSetTileSize( G_TX_RENDERTILE, 0, 0, (w - 1) << 2, (h - 1) << 2 );
	gSPTexture(1.0f, 1.0f, 0, 0, TRUE);
}

static
void gSPObjLoadTxtr(u32 tx)
{
	const u32 address = RSP_SegmentToPhysical(tx);
	uObjTxtr *objTxtr = (uObjTxtr*)&RDRAM[address];

	if ((gSP.status[objTxtr->block.sid >> 2] & objTxtr->block.mask) != objTxtr->block.flag) {
		switch (objTxtr->block.type) {
			case G_OBJLT_TXTRBLOCK:
				gDPSetTextureImage( G_IM_FMT_RGBA, G_IM_SIZ_8b, 0, objTxtr->block.image );
				gDPSetTile( G_IM_FMT_RGBA, G_IM_SIZ_8b, 0, objTxtr->block.tmem, G_TX_LOADTILE, 0, G_TX_NOMIRROR | G_TX_WRAP, G_TX_NOMIRROR | G_TX_WRAP, 0, 0, 0, 0 );
				gDPLoadBlock( G_TX_LOADTILE, 0, 0, ((objTxtr->block.tsize + 1) << 3) - 1, objTxtr->block.tline );
				DebugMsg(DEBUG_NORMAL, "gSPObjLoadTxtr: load block\n");
				break;
			case G_OBJLT_TXTRTILE:
				gDPSetTextureImage( G_IM_FMT_RGBA, G_IM_SIZ_8b, (objTxtr->tile.twidth + 1) << 1, objTxtr->tile.image );
				gDPSetTile( G_IM_FMT_RGBA, G_IM_SIZ_8b, (objTxtr->tile.twidth + 1) >> 2, objTxtr->tile.tmem, G_TX_RENDERTILE, 0, G_TX_NOMIRROR | G_TX_WRAP, G_TX_NOMIRROR | G_TX_WRAP, 0, 0, 0, 0 );
				gDPSetTile( G_IM_FMT_RGBA, G_IM_SIZ_8b, (objTxtr->tile.twidth + 1) >> 2, objTxtr->tile.tmem, G_TX_LOADTILE, 0, G_TX_NOMIRROR | G_TX_WRAP, G_TX_NOMIRROR | G_TX_WRAP, 0, 0, 0, 0 );
				gDPLoadTile( G_TX_LOADTILE, 0, 0, (((objTxtr->tile.twidth + 1) << 1) - 1) << 2, (((objTxtr->tile.theight + 1) >> 2) - 1) << 2 );
				DebugMsg(DEBUG_NORMAL, "gSPObjLoadTxtr: load tile\n");
				break;
			case G_OBJLT_TLUT:
				gDPSetTextureImage( G_IM_FMT_RGBA, G_IM_SIZ_16b, 1, objTxtr->tlut.image );
				gDPSetTile( G_IM_FMT_RGBA, G_IM_SIZ_16b, 0, objTxtr->tlut.phead, G_TX_LOADTILE, 0, G_TX_NOMIRROR | G_TX_WRAP, G_TX_NOMIRROR | G_TX_WRAP, 0, 0, 0, 0 );
				gDPLoadTLUT( G_TX_LOADTILE, 0, 0, objTxtr->tlut.pnum << 2, 0 );
				DebugMsg(DEBUG_NORMAL, "gSPObjLoadTxtr: load tlut\n");
				break;
		}
		gSP.status[objTxtr->block.sid >> 2] = (gSP.status[objTxtr->block.sid >> 2] & ~objTxtr->block.mask) | (objTxtr->block.flag & objTxtr->block.mask);
	}
}

static
void gSPObjRectangle(u32 _sp)
{
	const u32 address = RSP_SegmentToPhysical(_sp);
	uObjSprite *objSprite = (uObjSprite*)&RDRAM[address];
	gSPSetSpriteTile(objSprite);

	ObjCoordinates objCoords(objSprite, false);
	gSPDrawObjRect(objCoords);
	DebugMsg(DEBUG_NORMAL, "gSPObjRectangle\n");
}

static
void gSPObjRectangleR(u32 _sp)
{
	const u32 address = RSP_SegmentToPhysical(_sp);
	const uObjSprite *objSprite = (uObjSprite*)&RDRAM[address];
	gSPSetSpriteTile(objSprite);
	ObjCoordinates objCoords(objSprite, true);

	if (objSprite->imageFmt == G_IM_FMT_YUV && (config.generalEmulation.hacks&hack_Ogre64)) //Ogre Battle needs to copy YUV texture to frame buffer
		_drawYUVImageToFrameBuffer(objCoords);
	gSPDrawObjRect(objCoords);

	DebugMsg(DEBUG_NORMAL, "gSPObjRectangleR\n");
}

static
void gSPObjSprite(u32 _sp)
{
	const u32 address = RSP_SegmentToPhysical(_sp);
	uObjSprite *objSprite = (uObjSprite*)&RDRAM[address];
	gSPSetSpriteTile(objSprite);

	/* Fixed point coordinates calculation. Decoded by olivieryuyu */
	//	X1 = AND (X + B3) by B0 + ((objX + A3) * A) >> 16 + ((objY + A3) * B) >> 16
	//	Y1 = AND (Y + B3) by B0 + ((objX + A3) * C) >> 16 + ((objY + A3) * D) >> 16
	//	X2 = AND (X + B3) by B0 + (((((imageW - A1) * 0x0100)* (0x80007FFF/scaleW)) >> 32+ objX + A3) * A) >> 16  + (((((imageH - A1) * 0x0100)* (0x80007FFF/scaleH)) >> 32 + objY + A3) * B) >> 16
	//	Y2 = AND (Y + B3) by B0 + (((((imageW - A1) * 0x0100)* (0x80007FFF/scaleW)) >> 32 + objX + A3) * C) >> 16 + (((((imageH - A1) * 0x0100)* (0x80007FFF/scaleH)) >> 32 + objY + A3) * D) >> 16
	S2DEXCoordCorrector CC;
	const s16 x0 = (objMtx.X + CC.B3) & CC.B0;
	const s16 y0 = (objMtx.Y + CC.B3) & CC.B0;
	const s16 ulx = objSprite->objX + CC.A3;
	const s16 uly = objSprite->objY + CC.A3;
	const s16 lrx = ((((u64(objSprite->imageW) - CC.A1) << 8) * (0x80007FFFU / u32(objSprite->scaleW))) >> 32) + ulx;
	const s16 lry = ((((u64(objSprite->imageH) - CC.A1) << 8) * (0x80007FFFU / u32(objSprite->scaleH))) >> 32) + uly;

	auto calcX = [&](s16 _x, s16 _y) -> f32
	{
		const s16 X = x0 + static_cast<s16>(((_x * objMtx.A) >> 16)) + static_cast<s16>(((_y * objMtx.B) >> 16));
		return _FIXED2FLOAT(X, 2);
	};

	auto calcY = [&](s16 _x, s16 _y) -> f32
	{
		const s16 Y = y0 + static_cast<s16>(((_x * objMtx.C) >> 16)) + static_cast<s16>(((_y * objMtx.D) >> 16));
		return _FIXED2FLOAT(Y, 2);
	};

	f32 uls = 0.0f;
	f32 lrs = _FIXED2FLOAT(objSprite->imageW, 5) - 1.0f;
	f32 ult = 0.0f;
	f32 lrt = _FIXED2FLOAT(objSprite->imageH, 5) - 1.0f;

	if (objSprite->imageFlags & G_BG_FLAG_FLIPS)
		std::swap(uls, lrs);

	if (objSprite->imageFlags & G_BG_FLAG_FLIPT)
		std::swap(ult, lrt);

	const float z = (gDP.otherMode.depthSource == G_ZS_PRIM) ? gDP.primDepth.z : gSP.viewport.nearz;

	GraphicsDrawer & drawer = dwnd().getDrawer();
	drawer.setDMAVerticesSize(4);
	SPVertex * pVtx = drawer.getDMAVerticesData();

	SPVertex & vtx0 = pVtx[0];
	vtx0.x = calcX(ulx, uly);
	vtx0.y = calcY(ulx, uly);
	vtx0.z = z;
	vtx0.w = 1.0f;
	vtx0.s = uls;
	vtx0.t = ult;
	SPVertex & vtx1 = pVtx[1];
	vtx1.x = calcX(lrx, uly);
	vtx1.y = calcY(lrx, uly);
	vtx1.z = z;
	vtx1.w = 1.0f;
	vtx1.s = lrs;
	vtx1.t = ult;
	SPVertex & vtx2 = pVtx[2];
	vtx2.x = calcX(ulx, lry);
	vtx2.y = calcY(ulx, lry);
	vtx2.z = z;
	vtx2.w = 1.0f;
	vtx2.s = uls;
	vtx2.t = lrt;
	SPVertex & vtx3 = pVtx[3];
	vtx3.x = calcX(lrx, lry);
	vtx3.y = calcY(lrx, lry);
	vtx3.z = z;
	vtx3.w = 1.0f;
	vtx3.s = lrs;
	vtx3.t = lrt;

	drawer.drawScreenSpaceTriangle(4);

	DebugMsg(DEBUG_NORMAL, "gSPObjSprite\n");
}

static
void gSPObjMatrix(u32 mtx)
{
	objMtx = *reinterpret_cast<const uObjMtx *>(RDRAM + RSP_SegmentToPhysical(mtx));
	DebugMsg(DEBUG_NORMAL, "gSPObjMatrix\n");
}

static
void gSPObjSubMatrix(u32 mtx)
{
	const uObjSubMtx * pObjSubMtx = reinterpret_cast<const uObjSubMtx*>(RDRAM + RSP_SegmentToPhysical(mtx));
	objMtx.X = pObjSubMtx->X;
	objMtx.Y = pObjSubMtx->Y;
	objMtx.BaseScaleX = pObjSubMtx->BaseScaleX;
	objMtx.BaseScaleY = pObjSubMtx->BaseScaleY;
	DebugMsg(DEBUG_NORMAL, "gSPObjSubMatrix\n");
}

static
void _copyDepthBuffer()
{
	if (!config.frameBufferEmulation.enable)
		return;

	if (!Context::BlitFramebuffer)
		return;

	// The game copies content of depth buffer into current color buffer
	// OpenGL has different format for color and depth buffers, so this trick can't be performed directly
	// To do that, depth buffer with address of current color buffer created and attached to the current FBO
	// It will be copy depth buffer
	DepthBufferList & dbList = depthBufferList();
	dbList.saveBuffer(gDP.colorImage.address);
	// Take any frame buffer and attach source depth buffer to it, to blit it into copy depth buffer
	FrameBufferList & fbList = frameBufferList();
	FrameBuffer * pTmpBuffer = fbList.findTmpBuffer(fbList.getCurrent()->m_startAddress);
	if (pTmpBuffer == nullptr)
		return;
	DepthBuffer * pCopyBufferDepth = dbList.findBuffer(gSP.bgImage.address);
	if (pCopyBufferDepth == nullptr)
		return;
	pCopyBufferDepth->setDepthAttachment(pTmpBuffer->m_FBO, bufferTarget::READ_FRAMEBUFFER);

	DisplayWindow & wnd = dwnd();
	Context::BlitFramebuffersParams blitParams;
	blitParams.readBuffer = pTmpBuffer->m_FBO;
	blitParams.drawBuffer = fbList.getCurrent()->m_FBO;
	blitParams.srcX0 = 0;
	blitParams.srcY0 = 0;
	blitParams.srcX1 = wnd.getWidth();
	blitParams.srcY1 = wnd.getHeight();
	blitParams.dstX0 = 0;
	blitParams.dstY0 = 0;
	blitParams.dstX1 = wnd.getWidth();
	blitParams.dstY1 = wnd.getHeight();
	blitParams.mask = blitMask::DEPTH_BUFFER;
	blitParams.filter = textureParameters::FILTER_NEAREST;

	gfxContext.blitFramebuffers(blitParams);

	// Restore objects
	if (pTmpBuffer->m_pDepthBuffer != nullptr)
		pTmpBuffer->m_pDepthBuffer->setDepthAttachment(fbList.getCurrent()->m_FBO, bufferTarget::READ_FRAMEBUFFER);
	gfxContext.bindFramebuffer(bufferTarget::READ_FRAMEBUFFER, ObjectHandle::defaultFramebuffer);

	// Set back current depth buffer
	dbList.saveBuffer(gDP.depthImageAddress);
}

static
void _loadBGImage(const uObjScaleBg * _bgInfo, bool _loadScale)
{
	gSP.bgImage.address = RSP_SegmentToPhysical(_bgInfo->imagePtr);

	const u32 imageW = _bgInfo->imageW >> 2;
	const u32 imageH = _bgInfo->imageH >> 2;
	if (imageW == 512 && (config.generalEmulation.hacks & hack_RE2) != 0) {
		gSP.bgImage.width = *REG.VI_WIDTH;
		gSP.bgImage.height = (imageH * imageW) / gSP.bgImage.width;
	}
	else {
		gSP.bgImage.width = imageW - imageW % 2;
		gSP.bgImage.height = imageH - imageH % 2;
	}
	gSP.bgImage.format = _bgInfo->imageFmt;
	gSP.bgImage.size = _bgInfo->imageSiz;
	gSP.bgImage.palette = _bgInfo->imagePal;
	gDP.tiles[0].textureMode = TEXTUREMODE_BGIMAGE;
	gSP.bgImage.imageX = _FIXED2FLOAT(_bgInfo->imageX, 5);
	gSP.bgImage.imageY = _FIXED2FLOAT(_bgInfo->imageY, 5);
	if (_loadScale) {
		gSP.bgImage.scaleW = _FIXED2FLOAT(_bgInfo->scaleW, 10);
		gSP.bgImage.scaleH = _FIXED2FLOAT(_bgInfo->scaleH, 10);
	}
	else
		gSP.bgImage.scaleW = gSP.bgImage.scaleH = 1.0f;

	if (config.frameBufferEmulation.enable) {
		FrameBuffer *pBuffer = frameBufferList().findBuffer(gSP.bgImage.address);
		if ((pBuffer != nullptr) && pBuffer->m_size == gSP.bgImage.size && (!pBuffer->m_isDepthBuffer || pBuffer->m_changed)) {
			if (gSP.bgImage.format == G_IM_FMT_CI && gSP.bgImage.size == G_IM_SIZ_8b) {
				// Can't use 8bit CI buffer as texture
				return;
			}

			if (pBuffer->m_cfb || !pBuffer->isValid(false)) {
				frameBufferList().removeBuffer(pBuffer->m_startAddress);
				return;
			}

			gDP.tiles[0].frameBufferAddress = pBuffer->m_startAddress;
			gDP.tiles[0].textureMode = TEXTUREMODE_FRAMEBUFFER_BG;
			gDP.tiles[0].loadType = LOADTYPE_TILE;
			gDP.changed |= CHANGED_TMEM;

			if ((config.generalEmulation.hacks & hack_ZeldaMM) != 0) {
				if (gDP.colorImage.address == gDP.depthImageAddress)
					frameBufferList().setCopyBuffer(frameBufferList().getCurrent());
			}
		}
	}
}

static
void gSPBgRect1Cyc(u32 _bg)
{
	const u32 address = RSP_SegmentToPhysical(_bg);
	uObjScaleBg *objScaleBg = (uObjScaleBg*)&RDRAM[address];
	_loadBGImage(objScaleBg, true);

	// Zelda MM uses depth buffer copy in LoT and in pause screen.
	// In later case depth buffer is used as temporal color buffer, and usual rendering must be used.
	// Since both situations are hard to distinguish, do the both depth buffer copy and bg rendering.
	if ((config.generalEmulation.hacks & hack_ZeldaMM) != 0 &&
		(gSP.bgImage.address == gDP.depthImageAddress || depthBufferList().findBuffer(gSP.bgImage.address) != nullptr)
		)
		_copyDepthBuffer();

	gDP.otherMode.cycleType = G_CYC_1CYCLE;
	gDP.changed |= CHANGED_CYCLETYPE;
	gSPTexture(1.0f, 1.0f, 0, 0, TRUE);

	ObjCoordinates objCoords(objScaleBg);
	gSPDrawObjRect(objCoords);

	DebugMsg(DEBUG_NORMAL, "gSPBgRect1Cyc\n");
}

static
void gSPBgRectCopy(u32 _bg)
{
	const u32 address = RSP_SegmentToPhysical(_bg);
	uObjScaleBg *objBg = (uObjScaleBg*)&RDRAM[address];
	_loadBGImage(objBg, false);

	// See comment to gSPBgRect1Cyc
	if ((config.generalEmulation.hacks & hack_ZeldaMM) != 0 &&
		(gSP.bgImage.address == gDP.depthImageAddress || depthBufferList().findBuffer(gSP.bgImage.address) != nullptr)
		)
		_copyDepthBuffer();

	gDP.otherMode.cycleType = G_CYC_COPY;
	gDP.changed |= CHANGED_CYCLETYPE;
	gSPTexture(1.0f, 1.0f, 0, 0, TRUE);

	ObjCoordinates objCoords(objBg);
	gSPDrawObjRect(objCoords);

	DebugMsg(DEBUG_NORMAL, "gSPBgRectCopy\n");
}

void S2DEX_BG_1Cyc(u32 w0, u32 w1)
{
	gSPBgRect1Cyc(w1);
}

void S2DEX_BG_Copy(u32 w0, u32 w1)
{
	gSPBgRectCopy(w1);
}

void S2DEX_Obj_MoveMem(u32 w0, u32 w1)
{
	switch (_SHIFTR(w0, 0, 16)) {
	case S2DEX_MV_MATRIX:
		gSPObjMatrix(w1);
		break;
	case S2DEX_MV_SUBMUTRIX:
		gSPObjSubMatrix(w1);
		break;
	case S2DEX_MV_VIEWPORT:
		gSPViewport(w1);
		break;
	}
}

void S2DEX_MoveWord(u32 w0, u32 w1)
{
	switch (_SHIFTR(w0, 16, 8))
	{
	case G_MW_GENSTAT:
		gSPSetStatus(_SHIFTR(w0, 0, 16), w1);
		break;
	default:
		F3D_MoveWord(w0, w1);
		break;
	}
}

void S2DEX_RDPHalf_0(u32 w0, u32 w1) {
	if (RSP.nextCmd == G_SELECT_DL) {
		gSP.selectDL.addr = _SHIFTR(w0, 0, 16);
		gSP.selectDL.sid = _SHIFTR(w0, 18, 8);
		gSP.selectDL.flag = w1;
		return;
	}
	if (RSP.nextCmd == G_RDPHALF_1) {
		RDP_TexRect(w0, w1);
		return;
	}
	assert(false);
}

void S2DEX_Select_DL(u32 w0, u32 w1)
{
	gSP.selectDL.addr |= (_SHIFTR(w0, 0, 16)) << 16;
	const u8 sid = gSP.selectDL.sid;
	const u32 flag = gSP.selectDL.flag;
	const u32 mask = w1;
	if ((gSP.status[sid] & mask) == flag)
		// Do nothing;
		return;

	gSP.status[sid] = (gSP.status[sid] & ~mask) | (flag & mask);

	switch (_SHIFTR(w0, 16, 8))
	{
	case G_DL_PUSH:
		gSPDisplayList(gSP.selectDL.addr);
		break;
	case G_DL_NOPUSH:
		gSPBranchList(gSP.selectDL.addr);
		break;
	}
}

void S2DEX_Obj_RenderMode(u32 w0, u32 w1)
{
	gSP.objRendermode = w1;
	DebugMsg(DEBUG_NORMAL, "gSPObjRendermode(0x%08x)\n", gSP.objRendermode);
}

void S2DEX_Obj_Rectangle(u32 w0, u32 w1)
{
	gSPObjRectangle(w1);
}

void S2DEX_Obj_Rectangle_R(u32 w0, u32 w1)
{
	gSPObjRectangleR(w1);
}

void S2DEX_Obj_Sprite(u32 w0, u32 w1)
{
	gSPObjSprite(w1);
}

void S2DEX_Obj_LoadTxtr(u32 w0, u32 w1)
{
	gSPObjLoadTxtr(w1);
}

void S2DEX_Obj_LdTx_Rect(u32 w0, u32 w1)
{
	gSPObjLoadTxtr(w1);
	gSPObjRectangle(w1 + sizeof(uObjTxtr));
}

void S2DEX_Obj_LdTx_Rect_R(u32 w0, u32 w1)
{
	gSPObjLoadTxtr(w1);
	gSPObjRectangleR(w1 + sizeof(uObjTxtr));
}

void S2DEX_Obj_LdTx_Sprite(u32 w0, u32 w1)
{
	gSPObjLoadTxtr(w1);
	gSPObjSprite(w1 + sizeof(uObjTxtr));
}

void S2DEX_Init()
{
	gSPSetupFunctions();
	// Set GeometryMode flags
	GBI_InitFlags( F3DEX );
	resetObjMtx();

	GBI.PCStackSize = 18;
	gs_bVer1_3 = false;

	//          GBI Command             Command Value			Command Function
	GBI_SetGBI( G_SPNOOP,				F3D_SPNOOP,				F3D_SPNoOp );
	GBI_SetGBI( G_BG_1CYC,				S2DEX_BG_1CYC,			S2DEX_BG_1Cyc );
	GBI_SetGBI( G_BG_COPY,				S2DEX_BG_COPY,			S2DEX_BG_Copy );
	GBI_SetGBI( G_OBJ_RECTANGLE,		S2DEX_OBJ_RECTANGLE,	S2DEX_Obj_Rectangle );
	GBI_SetGBI( G_OBJ_SPRITE,			S2DEX_OBJ_SPRITE,		S2DEX_Obj_Sprite );
	GBI_SetGBI( G_OBJ_MOVEMEM,			S2DEX_OBJ_MOVEMEM,		S2DEX_Obj_MoveMem );
	GBI_SetGBI( G_DL,					F3D_DL,					F3D_DList );
	GBI_SetGBI( G_SELECT_DL,			S2DEX_SELECT_DL,		S2DEX_Select_DL );
	GBI_SetGBI( G_OBJ_RENDERMODE,		S2DEX_OBJ_RENDERMODE,	S2DEX_Obj_RenderMode );
	GBI_SetGBI( G_OBJ_RECTANGLE_R,		S2DEX_OBJ_RECTANGLE_R,	S2DEX_Obj_Rectangle_R );
	GBI_SetGBI( G_OBJ_LOADTXTR,			S2DEX_OBJ_LOADTXTR,		S2DEX_Obj_LoadTxtr );
	GBI_SetGBI( G_OBJ_LDTX_SPRITE,		S2DEX_OBJ_LDTX_SPRITE,	S2DEX_Obj_LdTx_Sprite );
	GBI_SetGBI( G_OBJ_LDTX_RECT,		S2DEX_OBJ_LDTX_RECT,	S2DEX_Obj_LdTx_Rect );
	GBI_SetGBI( G_OBJ_LDTX_RECT_R,		S2DEX_OBJ_LDTX_RECT_R,	S2DEX_Obj_LdTx_Rect_R );
	GBI_SetGBI( G_MOVEWORD,				F3D_MOVEWORD,			S2DEX_MoveWord );
	GBI_SetGBI( G_SETOTHERMODE_H,		F3D_SETOTHERMODE_H,		F3D_SetOtherMode_H );
	GBI_SetGBI( G_SETOTHERMODE_L,		F3D_SETOTHERMODE_L,		F3D_SetOtherMode_L );
	GBI_SetGBI( G_ENDDL,				F3D_ENDDL,				F3D_EndDL );
	GBI_SetGBI( G_RDPHALF_0,			S2DEX_RDPHALF_0,		S2DEX_RDPHalf_0 );
	GBI_SetGBI( G_RDPHALF_1,			F3D_RDPHALF_1,			F3D_RDPHalf_1 );
	GBI_SetGBI( G_RDPHALF_2,			F3D_RDPHALF_2,			F3D_RDPHalf_2 );
	GBI_SetGBI(	G_LOAD_UCODE,			S2DEX_LOAD_UCODE,		F3DEX_Load_uCode );
}

void S2DEX_1_03_Init()
{
	S2DEX_Init();
	gs_bVer1_3 = true;
}
