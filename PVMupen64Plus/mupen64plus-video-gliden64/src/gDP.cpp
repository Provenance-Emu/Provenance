#include <assert.h>
#include <algorithm>
#include <cmath>
#include "GLideN64.h"
#include "N64.h"
#include "GBI.h"
#include "RSP.h"
#include "RDP.h"
#include "gDP.h"
#include "gSP.h"
#include "Types.h"
#include "DebugDump.h"
#include "convert.h"
#include "CRC.h"
#include "FrameBuffer.h"
#include "DepthBuffer.h"
#include "FrameBufferInfo.h"
#include "TextureFilterHandler.h"
#include "VI.h"
#include "Config.h"
#include "Combiner.h"
#include "Performance.h"
#include "DisplayWindow.h"
#include <Graphics/Context.h>

using namespace std;

gDPInfo gDP;

void gDPSetOtherMode( u32 mode0, u32 mode1 )
{
	gDP.otherMode.h = mode0;
	gDP.otherMode.l = mode1;

	gDP.changed |= CHANGED_RENDERMODE | CHANGED_CYCLETYPE | CHANGED_ALPHACOMPARE;

#ifdef DEBUG_DUMP
	DebugMsg( DEBUG_NORMAL, "gDPSetOtherMode( %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s, %s | %s | %s%s%s%s%s | %s | %s%s%s );\n",
		AlphaDitherText[gDP.otherMode.alphaDither],
		ColorDitherText[gDP.otherMode.colorDither],
		CombineKeyText[gDP.otherMode.combineKey],
		TextureConvertText[gDP.otherMode.convert_one | (gDP.otherMode.bi_lerp1 << 1) | (gDP.otherMode.bi_lerp0 << 2)],
		TextureFilterText[gDP.otherMode.textureFilter],
		TextureLUTText[gDP.otherMode.textureLUT],
		TextureLODText[gDP.otherMode.textureLOD],
		TextureDetailText[gDP.otherMode.textureDetail],
		TexturePerspText[gDP.otherMode.texturePersp],
		CycleTypeText[gDP.otherMode.cycleType],
		PipelineModeText[gDP.otherMode.pipelineMode],
		AlphaCompareText[gDP.otherMode.alphaCompare],
		DepthSourceText[gDP.otherMode.depthSource],
		gDP.otherMode.AAEnable ? "AA_EN | " : "",
		gDP.otherMode.depthCompare ? "Z_CMP | " : "",
		gDP.otherMode.depthUpdate ? "Z_UPD | " : "",
		gDP.otherMode.imageRead ? "IM_RD | " : "",
		CvgDestText[gDP.otherMode.cvgDest],
		DepthModeText[gDP.otherMode.depthMode],
		gDP.otherMode.cvgXAlpha ? "CVG_X_ALPHA | " : "",
		gDP.otherMode.alphaCvgSel ? "ALPHA_CVG_SEL | " : "",
		gDP.otherMode.forceBlender ? "FORCE_BL" : "" );
#endif
}

void gDPSetPrimDepth( u16 z, u16 dz )
{
	if (gSP.viewport.vscale[2] == 0)
		gDP.primDepth.z = _FIXED2FLOAT(_SHIFTR(z, 0, 15), 15);
	else
		gDP.primDepth.z = min(1.0f, max(-1.0f, (_FIXED2FLOAT(_SHIFTR(z, 0, 15), 15) - gSP.viewport.vtrans[2]) / gSP.viewport.vscale[2]));
	gDP.primDepth.deltaZ = _FIXED2FLOAT(_SHIFTR(dz, 0, 15), 15);

	DebugMsg( DEBUG_NORMAL, "gDPSetPrimDepth( %f, %f );\n", gDP.primDepth.z, gDP.primDepth.deltaZ);
}

void gDPSetTexturePersp( u32 enable )
{
	gDP.otherMode.texturePersp = enable & 1;

#ifdef DEBUG_DUMP
	DebugMsg( DEBUG_NORMAL, "gDPSetTexturePersp( %s );\n", TexturePerspText[gDP.otherMode.texturePersp] );
#endif
}

void gDPSetTextureLUT( u32 mode )
{
	gDP.otherMode.textureLUT = mode & 3;

#ifdef DEBUG_DUMP
	DebugMsg( DEBUG_NORMAL, "gDPSetTextureLUT( %s );\n", TextureLUTText[gDP.otherMode.textureLUT] );
#endif
}

void gDPSetCombine( s32 muxs0, s32 muxs1 )
{
	gDP.combine.muxs0 = muxs0;
	gDP.combine.muxs1 = muxs1;

	gDP.changed |= CHANGED_COMBINE;

	DebugMsg(DEBUG_NORMAL, "gDPSetCombine\n");
#ifdef DEBUG_DUMP
	DebugMsg( DEBUG_NORMAL, "	%s, %s, %s, %s, %s, %s, %s, %s,\n",
		saRGBText[gDP.combine.saRGB0],
		sbRGBText[gDP.combine.sbRGB0],
		mRGBText[gDP.combine.mRGB0],
		aRGBText[gDP.combine.aRGB0],
		saAText[gDP.combine.saA0],
		sbAText[gDP.combine.sbA0],
		mAText[gDP.combine.mA0],
		aAText[gDP.combine.aA0] );

	DebugMsg( DEBUG_NORMAL, "	%s, %s, %s, %s, %s, %s, %s, %s );\n",
		saRGBText[gDP.combine.saRGB1],
		sbRGBText[gDP.combine.sbRGB1],
		mRGBText[gDP.combine.mRGB1],
		aRGBText[gDP.combine.aRGB1],
		saAText[gDP.combine.saA1],
		sbAText[gDP.combine.sbA1],
		mAText[gDP.combine.mA1],
		aAText[gDP.combine.aA1] );
#endif
}

void gDPSetColorImage( u32 format, u32 size, u32 width, u32 address )
{
	address = RSP_SegmentToPhysical( address );

	frameBufferList().saveBuffer(address, (u16)format, (u16)size, (u16)width, false);

	gDP.colorImage.format = format;
	gDP.colorImage.size = size;
	gDP.colorImage.width = width;
	gDP.colorImage.height = 0;
	gDP.colorImage.address = address;

#ifdef DEBUG_DUMP
	DebugMsg( DEBUG_NORMAL, "gDPSetColorImage( %s, %s, %i, 0x%08X );\n",
		ImageFormatText[gDP.colorImage.format],
		ImageSizeText[gDP.colorImage.size],
		gDP.colorImage.width,
		gDP.colorImage.address );
#endif
}

void gDPSetTextureImage(u32 format, u32 size, u32 width, u32 address)
{
	gDP.textureImage.format = format;
	gDP.textureImage.size = size;
	gDP.textureImage.width = width;
	gDP.textureImage.address = RSP_SegmentToPhysical(address);
	gDP.textureImage.bpl = gDP.textureImage.width << gDP.textureImage.size >> 1;
	if (gSP.DMAOffsets.tex_offset != 0) {
		if (format == G_IM_FMT_RGBA) {
			u16 * t = (u16*)(RDRAM + gSP.DMAOffsets.tex_offset);
			gSP.DMAOffsets.tex_shift = t[gSP.DMAOffsets.tex_count ^ 1];
			gDP.textureImage.address += gSP.DMAOffsets.tex_shift;
		} else {
			gSP.DMAOffsets.tex_offset = 0;
			gSP.DMAOffsets.tex_shift = 0;
			gSP.DMAOffsets.tex_count = 0;
		}
	}
#ifdef DEBUG_DUMP
	DebugMsg( DEBUG_NORMAL, "gDPSetTextureImage( %s, %s, %i, 0x%08X );\n",
		ImageFormatText[gDP.textureImage.format],
		ImageSizeText[gDP.textureImage.size],
		gDP.textureImage.width,
		gDP.textureImage.address );
#endif
}

void gDPSetDepthImage( u32 address )
{
	address = RSP_SegmentToPhysical( address );
	gDP.depthImageAddress = address;
	depthBufferList().saveBuffer(address);

	DebugMsg( DEBUG_NORMAL, "gDPSetDepthImage( 0x%08X );\n", gDP.depthImageAddress );
}

void gDPSetEnvColor( u32 r, u32 g, u32 b, u32 a )
{
	gDP.envColor.r = r * 0.0039215689f;
	gDP.envColor.g = g * 0.0039215689f;
	gDP.envColor.b = b * 0.0039215689f;
	gDP.envColor.a = a * 0.0039215689f;

	DebugMsg( DEBUG_NORMAL, "gDPSetEnvColor( %i, %i, %i, %i );\n", r, g, b, a );
}

void gDPSetBlendColor( u32 r, u32 g, u32 b, u32 a )
{
	gDP.blendColor.r = r * 0.0039215689f;
	gDP.blendColor.g = g * 0.0039215689f;
	gDP.blendColor.b = b * 0.0039215689f;
	gDP.blendColor.a = a * 0.0039215689f;

	gDP.changed |= CHANGED_BLENDCOLOR;

	DebugMsg( DEBUG_NORMAL, "gDPSetBlendColor( %i, %i, %i, %i );\n", r, g, b, a );
}

void gDPSetFogColor( u32 r, u32 g, u32 b, u32 a )
{
	gDP.fogColor.r = r * 0.0039215689f;
	gDP.fogColor.g = g * 0.0039215689f;
	gDP.fogColor.b = b * 0.0039215689f;
	gDP.fogColor.a = a * 0.0039215689f;

	gDP.changed |= CHANGED_FOGCOLOR;

	DebugMsg( DEBUG_NORMAL, "gDPSetFogColor( %i, %i, %i, %i );\n", r, g, b, a );
}

void gDPSetFillColor( u32 c )
{
	gDP.fillColor.color = c;
	gDP.fillColor.z = (f32)_SHIFTR( c,  2, 14 );
	gDP.fillColor.dz = (f32)_SHIFTR( c, 0, 2 );

	DebugMsg( DEBUG_NORMAL, "gDPSetFillColor( 0x%08X );\n", c );
}

void gDPGetFillColor(f32 _fillColor[4])
{
	const u32 c = gDP.fillColor.color;
	if (gDP.colorImage.size < 3) {
		_fillColor[0] = _SHIFTR( c, 11, 5 ) * 0.032258064f;
		_fillColor[1] = _SHIFTR( c,  6, 5 ) * 0.032258064f;
		_fillColor[2] = _SHIFTR( c,  1, 5 ) * 0.032258064f;
		_fillColor[3] = (f32)_SHIFTR( c,  0, 1 );
	} else {
		_fillColor[0] = _SHIFTR( c, 24, 8 ) * 0.0039215686f;
		_fillColor[1] = _SHIFTR( c, 16, 8 ) * 0.0039215686f;
		_fillColor[2] = _SHIFTR( c,  8, 8 ) * 0.0039215686f;
		_fillColor[3] = _SHIFTR( c,  0, 8 ) * 0.0039215686f;
	}
}

void gDPSetPrimColor( u32 m, u32 l, u32 r, u32 g, u32 b, u32 a )
{
	gDP.primColor.m = m * 0.0312500000f;
	gDP.primColor.l = l * 0.0039215689f;
	gDP.primColor.r = r * 0.0039215689f;
	gDP.primColor.g = g * 0.0039215689f;
	gDP.primColor.b = b * 0.0039215689f;
	gDP.primColor.a = a * 0.0039215689f;

	DebugMsg( DEBUG_NORMAL, "gDPSetPrimColor( %i, %i, %i, %i, %i, %i );\n", m, l, r, g, b, a );
}

void gDPSetTile( u32 format, u32 size, u32 line, u32 tmem, u32 tile, u32 palette, u32 cmt, u32 cms, u32 maskt, u32 masks, u32 shiftt, u32 shifts )
{
	gDP.tiles[tile].format = format;
	gDP.tiles[tile].size = size;
	gDP.tiles[tile].line = line;
	gDP.tiles[tile].tmem = tmem;
	gDP.tiles[tile].palette = palette;
	gDP.tiles[tile].cmt = cmt;
	gDP.tiles[tile].cms = cms;
	gDP.tiles[tile].maskt = maskt;
	gDP.tiles[tile].masks = masks;
	gDP.tiles[tile].shiftt = shiftt;
	gDP.tiles[tile].shifts = shifts;

	if (!gDP.tiles[tile].masks) gDP.tiles[tile].clamps = 1;
	if (!gDP.tiles[tile].maskt) gDP.tiles[tile].clampt = 1;

	if (tile == gSP.texture.tile || tile == gSP.texture.tile + 1) {
		u32 nTile = gDP.loadTileIdx;
		while(gDP.tiles[nTile].tmem != tmem && nTile > gSP.texture.tile + 1)
			--nTile;
		if (nTile > gSP.texture.tile + 1) {
			gDP.tiles[tile].textureMode = gDP.tiles[nTile].textureMode;
			gDP.tiles[tile].loadType = gDP.tiles[nTile].loadType;
			gDP.tiles[tile].frameBufferAddress = gDP.tiles[nTile].frameBufferAddress;
			gDP.tiles[tile].imageAddress = gDP.tiles[nTile].imageAddress;
		}
	}

	gDP.changed |= CHANGED_TILE;

#ifdef DEBUG_DUMP
	DebugMsg( DEBUG_NORMAL, "gDPSetTile( %s, %s, %i, %i, %i, %i, %s%s, %s%s, %i, %i, %i, %i );\n",
		ImageFormatText[format],
		ImageSizeText[size],
		line,
		tmem,
		tile,
		palette,
		cmt & G_TX_MIRROR ? "G_TX_MIRROR" : "G_TX_NOMIRROR",
		cmt & G_TX_CLAMP ? " | G_TX_CLAMP" : "",
		cms & G_TX_MIRROR ? "G_TX_MIRROR" : "G_TX_NOMIRROR",
		cms & G_TX_CLAMP ? " | G_TX_CLAMP" : "",
		maskt,
		masks,
		shiftt,
		shifts );
#endif
}


void gDPSetTileSize( u32 tile, u32 uls, u32 ult, u32 lrs, u32 lrt )
{
	gDP.tiles[tile].uls = _SHIFTR( uls, 2, 10 );
	gDP.tiles[tile].ult = _SHIFTR( ult, 2, 10 );
	gDP.tiles[tile].lrs = _SHIFTR( lrs, 2, 10 );
	gDP.tiles[tile].lrt = _SHIFTR( lrt, 2, 10 );

	gDP.tiles[tile].fuls = _FIXED2FLOAT( uls, 2 );
	gDP.tiles[tile].fult = _FIXED2FLOAT( ult, 2 );
	gDP.tiles[tile].flrs = _FIXED2FLOAT( lrs, 2 );
	gDP.tiles[tile].flrt = _FIXED2FLOAT( lrt, 2 );

	gDP.changed |= CHANGED_TILE;

	DebugMsg( DEBUG_NORMAL, "gDPSetTileSize( %i, %.2f, %.2f, %.2f, %.2f );\n",
		tile,
		gDP.tiles[tile].fuls,
		gDP.tiles[tile].fult,
		gDP.tiles[tile].flrs,
		gDP.tiles[tile].flrt );
}

static
bool CheckForFrameBufferTexture(u32 _address, u32 _bytes)
{
	gDP.loadTile->textureMode = TEXTUREMODE_NORMAL;
	gDP.loadTile->frameBufferAddress = 0U;
	gDP.changed |= CHANGED_TMEM;
	if (!config.frameBufferEmulation.enable)
		return false;

	FrameBufferList & fbList = frameBufferList();
	FrameBuffer *pBuffer = fbList.findBuffer(_address);
	bool bRes = pBuffer != nullptr && pBuffer->m_readable;
	if (bRes) {
		if ((config.generalEmulation.hacks & hack_blurPauseScreen) != 0) {
			if (gDP.colorImage.address == gDP.depthImageAddress && pBuffer->m_copiedToRdram) {
				memcpy(RDRAM + gDP.depthImageAddress, RDRAM + pBuffer->m_startAddress, (pBuffer->m_width*pBuffer->m_height) << pBuffer->m_size >> 1);
				pBuffer->m_copiedToRdram = false;
				fbList.getCurrent()->m_isPauseScreen = true;
			}
			if (pBuffer->m_isPauseScreen)
				bRes = false;
		}

		if (pBuffer->m_cfb) {
			fbList.removeBuffer(pBuffer->m_startAddress);
			bRes = false;
		}

		if ((config.generalEmulation.hacks & hack_noDepthFrameBuffers) != 0 && pBuffer->m_isDepthBuffer) {
			fbList.removeBuffer(pBuffer->m_startAddress);
			bRes = false;
		}

		const u32 texEndAddress = _address + _bytes - 1;
		if (_address > pBuffer->m_startAddress && texEndAddress > (pBuffer->m_endAddress + (pBuffer->m_width << pBuffer->m_size >> 1))) {
			//fbList.removeBuffer(pBuffer->m_startAddress);
			bRes = false;
		}

		if (bRes && gDP.loadTile->loadType == LOADTYPE_TILE && gDP.textureImage.width != pBuffer->m_width && gDP.textureImage.size != pBuffer->m_size) {
			//fbList.removeBuffer(pBuffer->m_startAddress); // Does not work with Zelda MM
			bRes = false;
		}

		if (bRes) {
			bRes = pBuffer->isValid(false);
			if (!bRes)
				fbList.removeBuffer(pBuffer->m_startAddress);
		}

		if (bRes) {
			pBuffer->m_loadType = gDP.loadTile->loadType;
			pBuffer->m_loadTileOrigin.uls = gDP.loadTile->uls;
			pBuffer->m_loadTileOrigin.ult = gDP.loadTile->ult;
			gDP.loadTile->frameBufferAddress = pBuffer->m_startAddress;
			gDP.loadTile->textureMode = TEXTUREMODE_FRAMEBUFFER;
		}
	}

	for (int nTile = gSP.texture.tile; nTile < 6; ++nTile) {
		if (gDP.tiles[nTile].tmem == gDP.loadTile->tmem) {
			gDPTile & curTile = gDP.tiles[nTile];
			curTile.textureMode = gDP.loadTile->textureMode;
			curTile.loadType = gDP.loadTile->loadType;
			curTile.frameBufferAddress = gDP.loadTile->frameBufferAddress;
			curTile.imageAddress = gDP.loadTile->imageAddress;
		}
	}
	return bRes;
}

//****************************************************************
// LoadTile for 32bit RGBA texture
// Based on sources of angrylion's software plugin.
//
void gDPLoadTile32b(u32 uls, u32 ult, u32 lrs, u32 lrt)
{
	const u32 width = lrs - uls + 1;
	const u32 height = lrt - ult + 1;
	const u32 line = gDP.loadTile->line << 2;
	const u32 tbase = gDP.loadTile->tmem << 2;
	const u32 addr = gDP.textureImage.address >> 2;
	const u32 * src = (const u32*)RDRAM;
	u16 * tmem16 = (u16*)TMEM;
	u32 c, ptr, tline, s, xorval;

	for (u32 j = 0; j < height; ++j) {
		tline = tbase + line * j;
		s = ((j + ult) * gDP.textureImage.width) + uls;
		xorval = (j & 1) ? 3 : 1;
		for (u32 i = 0; i < width; ++i) {
			c = src[addr + s + i];
			ptr = ((tline + i) ^ xorval) & 0x3ff;
			tmem16[ptr] = c >> 16;
			tmem16[ptr | 0x400] = c & 0xffff;
		}
	}
}

void gDPLoadTile(u32 tile, u32 uls, u32 ult, u32 lrs, u32 lrt)
{
	gDPSetTileSize( tile, uls, ult, lrs, lrt );
	gDP.loadTileIdx = tile;
	gDP.loadTile = &gDP.tiles[tile];
	gDP.loadTile->loadType = LOADTYPE_TILE;
	gDP.loadTile->imageAddress = gDP.textureImage.address;

	if (gDP.loadTile->lrs < gDP.loadTile->uls || gDP.loadTile->lrt < gDP.loadTile->ult)
		return;

	const u32 width = (gDP.loadTile->lrs - gDP.loadTile->uls + 1) & 0x03FF;
	const u32 height = (gDP.loadTile->lrt - gDP.loadTile->ult + 1) & 0x03FF;
	const u32 bpl = gDP.loadTile->line << 3;

	gDPLoadTileInfo &info = gDP.loadInfo[gDP.loadTile->tmem];
	info.texAddress = gDP.loadTile->imageAddress;
	info.uls = gDP.loadTile->uls;
	info.ult = gDP.loadTile->ult;
	info.lrs = gDP.loadTile->lrs;
	info.lrt = gDP.loadTile->lrt;
	info.width = gDP.loadTile->masks != 0 ? (u16)min(width, 1U << gDP.loadTile->masks) : (u16)width;
	info.height = gDP.loadTile->maskt != 0 ? (u16)min(height, 1U<<gDP.loadTile->maskt) : (u16)height;
	info.texWidth = gDP.textureImage.width;
	info.size = gDP.textureImage.size;
	info.loadType = LOADTYPE_TILE;
	info.bytes = bpl * height;

	if (gDP.loadTile->line == 0)
		return;

	u32 address = gDP.textureImage.address + gDP.loadTile->ult * gDP.textureImage.bpl + (gDP.loadTile->uls << gDP.textureImage.size >> 1);
	u32 bpl2 = bpl;
	if (gDP.loadTile->lrs > gDP.textureImage.width)
		bpl2 = (gDP.textureImage.width - gDP.loadTile->uls);
	u32 height2 = height;
	if (gDP.loadTile->lrt > gDP.scissor.lry)
		height2 = (u32)gDP.scissor.lry - gDP.loadTile->ult;

	if (CheckForFrameBufferTexture(address, bpl2*height2))
		return;

	if ((address + height * gDP.textureImage.bpl) > RDRAMSize)
		return;

	if (gDP.loadTile->size == G_IM_SIZ_32b)
		gDPLoadTile32b(gDP.loadTile->uls, gDP.loadTile->ult, gDP.loadTile->lrs, gDP.loadTile->lrt);
	else {
		u32 tmemAddr = gDP.loadTile->tmem;
		const u32 line = gDP.loadTile->line;
		for (u32 y = 0; y < height; ++y) {
			UnswapCopyWrap(RDRAM, address, (u8*)TMEM, tmemAddr << 3, 0xFFF, bpl);
			if (y & 1)
				DWordInterleaveWrap((u32*)TMEM, tmemAddr << 1, 0x3FF, line);

			address += gDP.textureImage.bpl;
			tmemAddr += line;
		}
	}

	DebugMsg( DEBUG_NORMAL, "gDPLoadTile( %i, %i, %i, %i, %i );\n",
			tile, gDP.loadTile->uls, gDP.loadTile->ult, gDP.loadTile->lrs, gDP.loadTile->lrt );
}

//****************************************************************
// LoadBlock for 32bit RGBA texture
// Based on sources of angrylion's software plugin.
//
void gDPLoadBlock32(u32 uls,u32 lrs, u32 dxt)
{
	const u32 * src = (const u32*)RDRAM;
	const u32 tb = gDP.loadTile->tmem << 2;
	const u32 line = gDP.loadTile->line << 2;

	u16 *tmem16 = (u16*)TMEM;
	u32 addr = gDP.loadTile->imageAddress >> 2;
	u32 width = (lrs - uls + 1) << 2;
	if (width == 4) // lr_s == 0, 1x1 texture
		width = 1;
	else if (width & 7)
		width = (width & (~7)) + 8;

	if (dxt != 0) {
		u32 j = 0;
		u32 t = 0;
		u32 oldt = 0;
		u32 ptr;

		u32 c = 0;
		for (u32 i = 0; i < width; i += 2) {
			oldt = t;
			t = ((j >> 11) & 1) ? 3 : 1;
			if (t != oldt)
				i += line;
			ptr = ((tb + i) ^ t) & 0x3ff;
			c = src[addr + i];
			tmem16[ptr] = c >> 16;
			tmem16[ptr | 0x400] = c & 0xffff;
			ptr = ((tb + i + 1) ^ t) & 0x3ff;
			c = src[addr + i + 1];
			tmem16[ptr] = c >> 16;
			tmem16[ptr | 0x400] = c & 0xffff;
			j += dxt;
		}
	} else {
		u32 c, ptr;
		for (u32 i = 0; i < width; i++) {
			ptr = ((tb + i) ^ 1) & 0x3ff;
			c = src[addr + i];
			tmem16[ptr] = c >> 16;
			tmem16[ptr | 0x400] = c & 0xffff;
		}
	}
}

void gDPLoadBlock(u32 tile, u32 uls, u32 ult, u32 lrs, u32 dxt)
{
	gDPSetTileSize( tile, uls, ult, lrs, dxt );
	gDP.loadTileIdx = tile;
	gDP.loadTile = &gDP.tiles[tile];
	gDP.loadTile->loadType = LOADTYPE_BLOCK;

	if (gSP.DMAOffsets.tex_offset != 0) {
		if (gSP.DMAOffsets.tex_shift % (((lrs>>2) + 1) << 3)) {
			gDP.textureImage.address -= gSP.DMAOffsets.tex_shift;
			gSP.DMAOffsets.tex_offset = 0;
			gSP.DMAOffsets.tex_shift = 0;
			gSP.DMAOffsets.tex_count = 0;
		} else
			++gSP.DMAOffsets.tex_count;
	}
	gDP.loadTile->imageAddress = gDP.textureImage.address;

	gDPLoadTileInfo &info = gDP.loadInfo[gDP.loadTile->tmem];
	info.texAddress = gDP.loadTile->imageAddress;
	info.uls = gDP.loadTile->uls;
	info.ult = gDP.loadTile->ult;
	info.lrs = gDP.loadTile->lrs;
	info.lrt = gDP.loadTile->lrt;
	info.width = gDP.loadTile->lrs;
	info.dxt = dxt;
	info.size = gDP.textureImage.size;
	info.loadType = LOADTYPE_BLOCK;

	u32 bytes = (lrs - uls + 1) << gDP.loadTile->size >> 1;
	if ((bytes & 7) != 0)
		bytes = (bytes & (~7)) + 8;

	info.bytes = bytes;
	u32 address = gDP.textureImage.address + ult * gDP.textureImage.bpl + (uls << gDP.textureImage.size >> 1);

	if (bytes == 0 || (address + bytes) > RDRAMSize) {
		DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "// Attempting to load texture block out of range\n");
		DebugMsg(DEBUG_NORMAL, "gDPLoadBlock( %i, %i, %i, %i, %i );\n", tile, uls, ult, lrs, dxt );
		return;
	}

	gDP.loadTile->frameBufferAddress = 0;
	CheckForFrameBufferTexture(address, bytes); // Load data to TMEM even if FB texture is found. See comment to texturedRectDepthBufferCopy

	if (gDP.loadTile->size == G_IM_SIZ_32b)
		gDPLoadBlock32(gDP.loadTile->uls, gDP.loadTile->lrs, dxt);
	else if (gDP.loadTile->format == G_IM_FMT_YUV)
		memcpy(TMEM, &RDRAM[address], bytes); // HACK!
	else {
		u32 tmemAddr = gDP.loadTile->tmem;
		UnswapCopyWrap(RDRAM, address, (u8*)TMEM, tmemAddr << 3, 0xFFF, bytes);
		if (dxt != 0) {
			u32 dxtCounter = 0;
			u32 qwords = (bytes >> 3);
			u32 line = 0;
			while (true) {
				do {
					++tmemAddr;
					--qwords;
					if (qwords == 0)
						goto end_dxt_test;
					dxtCounter += dxt;
				} while ((dxtCounter & 0x800) == 0);
				do {
					++line;
					--qwords;
					if (qwords == 0)
						goto end_dxt_test;
					dxtCounter += dxt;
				} while ((dxtCounter & 0x800) != 0);
				DWordInterleaveWrap((u32*)TMEM, tmemAddr << 1, 0x3FF, line);
				tmemAddr += line;
				line = 0;
			}
			end_dxt_test:
				DWordInterleaveWrap((u32*)TMEM, tmemAddr << 1, 0x3FF, line);
		}
	}

	DebugMsg( DEBUG_NORMAL, "gDPLoadBlock( %i, %i, %i, %i, %i );\n", tile, uls, ult, lrs, dxt );
}

void gDPLoadTLUT( u32 tile, u32 uls, u32 ult, u32 lrs, u32 lrt )
{
	gDPSetTileSize( tile, uls, ult, lrs, lrt );
	if (gDP.tiles[tile].tmem < 256) {
		DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "gDPLoadTLUT wrong tile tmem addr: tile[%d].tmem=%04x;\n", tile, gDP.tiles[tile].tmem);
		return;
	}
	u16 count = (u16)((gDP.tiles[tile].lrs - gDP.tiles[tile].uls + 1) * (gDP.tiles[tile].lrt - gDP.tiles[tile].ult + 1));
	u32 address = gDP.textureImage.address + gDP.tiles[tile].ult * gDP.textureImage.bpl + (gDP.tiles[tile].uls << gDP.textureImage.size >> 1);
	u16 pal = (u16)((gDP.tiles[tile].tmem - 256) >> 4);
	u16 *dest = (u16*)&TMEM[gDP.tiles[tile].tmem];
	
	// Workaround for possible game/emulator bug (see bug #1250)
	if (pal != 0)
		count = 16;

	int i = 0;
	u32 destIdx = 0;
	while (i < count) {
		for (u16 j = 0; (j < 16) && (i < count); ++j, ++i) {
			dest[destIdx&0x3FF] = swapword(*(u16*)(RDRAM + (address ^ 2)));
			address += 2;
			destIdx += 4;
		}

		gDP.paletteCRC16[pal] = CRC_CalculatePalette(0xFFFFFFFF, &TMEM[256 + (pal << 4)], 16);
		pal = (pal + 1) & 0x0F;
	}

	gDP.paletteCRC256 = CRC_Calculate(0xFFFFFFFF, gDP.paletteCRC16, 64);

	if (TFH.isInited()) {
		const u16 start = gDP.tiles[tile].tmem - 256; // starting location in the palettes
		u16 *spal = (u16*)(RDRAM + gDP.textureImage.address);
		memcpy((u8*)(gDP.TexFilterPalette + start), spal, count<<1);
	}

	gDP.changed |= CHANGED_TMEM;

	DebugMsg( DEBUG_NORMAL, "gDPLoadTLUT( %i, %i, %i, %i, %i );\n",
		tile, gDP.tiles[tile].uls, gDP.tiles[tile].ult, gDP.tiles[tile].lrs, gDP.tiles[tile].lrt );
}

void gDPSetScissor( u32 mode, f32 ulx, f32 uly, f32 lrx, f32 lry )
{
	gDP.scissor.mode = mode;
	gDP.scissor.ulx = ulx;
	gDP.scissor.uly = uly;
	gDP.scissor.lrx = lrx;
	gDP.scissor.lry = lry;

	gDP.changed |= CHANGED_SCISSOR;

	if (config.video.cropMode == Config::cmAuto && gDP.depthImageAddress != gDP.colorImage.address) {
		const u32 maxCropH = VI.width / 16;
		const u32 maxCropV = VI.height / 10;
		if (ulx > 0 && ulx < maxCropH &&
			uly > 0 && uly < maxCropV &&
			(VI.width - lrx) < maxCropH && (VI.height - lry) < maxCropV) {
			config.video.cropWidth = (u32)ulx;
			config.video.cropHeight = (u32)uly;
		}
	}

#ifdef DEBUG_DUMP
	DebugMsg( DEBUG_NORMAL, "gDPSetScissor( %s, %.2f, %.2f, %.2f, %.2f );\n",
		ScissorModeText[gDP.scissor.mode],
		gDP.scissor.ulx,
		gDP.scissor.uly,
		gDP.scissor.lrx,
		gDP.scissor.lry );
#endif
}

void gDPFillRectangle( s32 ulx, s32 uly, s32 lrx, s32 lry )
{
	GraphicsDrawer & drawer = dwnd().getDrawer();
	if (gDP.otherMode.cycleType == G_CYC_FILL) {
		++lrx;
		++lry;
	} else if (lry == uly)
		++lry;

	enum {
		dbNone,
		dbFound,
		dbCleared
	} depthBuffer = dbNone;
	if (gDP.depthImageAddress == gDP.colorImage.address) {
		// Game may use depth texture as auxilary color texture. Example: Mario Tennis
		// If color is not depth clear color, that is most likely the case
		if (gDP.fillColor.color == DepthClearColor) {
			frameBufferList().fillRDRAM(ulx, uly, lrx, lry);
			depthBuffer = dbFound;
			if (config.frameBufferEmulation.N64DepthCompare == 0 &&
				(config.generalEmulation.enableFragmentDepthWrite == 0 ||
				(ulx == 0 && uly == 0 && lrx == gDP.scissor.lrx && lry == gDP.scissor.lry))) {
				drawer.clearDepthBuffer(ulx, uly, lrx, lry);
				depthBuffer = dbCleared;
			} else
				depthBufferList().clearBuffer(ulx, uly, lrx, lry);
		}
	} else if (gDP.fillColor.color == DepthClearColor && gDP.otherMode.cycleType == G_CYC_FILL) {
		depthBuffer = dbFound;
		depthBufferList().saveBuffer(gDP.colorImage.address);
		frameBufferList().fillRDRAM(ulx, uly, lrx, lry);
		if (config.frameBufferEmulation.N64DepthCompare == 0 &&
			(config.generalEmulation.enableFragmentDepthWrite == 0 ||
			(ulx == 0 && uly == 0 && lrx == gDP.scissor.lrx && lry == gDP.scissor.lry))) {
			drawer.clearDepthBuffer(ulx, uly, lrx, lry);
			depthBuffer = dbCleared;
		} else
			depthBufferList().clearBuffer(ulx, uly, lrx, lry);
	}

	if (depthBuffer != dbCleared) {
		if (gDP.otherMode.cycleType == G_CYC_FILL) {
			f32 fillColor[4];
			gDPGetFillColor(fillColor);
			if ((depthBuffer == dbNone) &&
				(ulx == 0) &&
				(uly == 0) &&
				(lrx == gDP.scissor.lrx) &&
				(lry == gDP.scissor.lry)) {
				frameBufferList().fillRDRAM(ulx, uly, lrx, lry);
				drawer.clearColorBuffer(fillColor);
			} else {
				gDP.rectColor.r = fillColor[0];
				gDP.rectColor.g = fillColor[1];
				gDP.rectColor.b = fillColor[2];
				gDP.rectColor.a = fillColor[3];
				drawer.drawRect(ulx, uly, lrx, lry);
			}
		} else {
			gDP.rectColor = gDPInfo::Color();
			drawer.drawRect(ulx, uly, lrx, lry);
		}
	}

	frameBufferList().setBufferChanged(f32(lry));

	DebugMsg( DEBUG_NORMAL, "gDPFillRectangle #%i- #%i ( %i, %i, %i, %i );\n", gSP.tri_num, gSP.tri_num +1, ulx, uly, lrx, lry );
	gSP.tri_num += 2;
}

void gDPSetConvert( s32 k0, s32 k1, s32 k2, s32 k3, s32 k4, s32 k5 )
{
// angrylion's macro
#define SIGN(x, numb)	(((x) & ((1 << numb) - 1)) | -((x) & (1 << (numb - 1))))

	gDP.convert.k0 = (SIGN(k0, 9) << 1) + 1;
	gDP.convert.k1 = (SIGN(k1, 9) << 1) + 1;
	gDP.convert.k2 = (SIGN(k2, 9) << 1) + 1;
	gDP.convert.k3 = (SIGN(k3, 9) << 1) + 1;
	gDP.convert.k4 = k4;
	gDP.convert.k5 = k5;

	DebugMsg( DEBUG_NORMAL, "gDPSetConvert( %i, %i, %i, %i, %i, %i );\n", k0, k1, k2, k3, k4, k5);
}

void gDPSetKeyR( u32 cR, u32 sR, u32 wR )
{
	gDP.key.center.r = cR * 0.0039215689f;
	gDP.key.scale.r = sR * 0.0039215689f;
	gDP.key.width.r = wR * 0.0039215689f;
	DebugMsg( DEBUG_NORMAL, "gDPSetKeyR( %u, %u, %u );\n", cR, sR, wR );
}

void gDPSetKeyGB(u32 cG, u32 sG, u32 wG, u32 cB, u32 sB, u32 wB )
{
	gDP.key.center.g = cG * 0.0039215689f;
	gDP.key.scale.g = sG * 0.0039215689f;
	gDP.key.width.g = wG * 0.0039215689f;
	gDP.key.center.b = cB * 0.0039215689f;
	gDP.key.scale.b = sB * 0.0039215689f;
	gDP.key.width.b = wB * 0.0039215689f;
	DebugMsg( DEBUG_NORMAL, "gDPSetKeyGB( %u, %u, %u, %u, %u, %u );\n",
			  cG, sG, wG, cB, sB, wB );
}

void gDPTextureRectangle(f32 ulx, f32 uly, f32 lrx, f32 lry, s32 tile, s16 s, s16 t, f32 dsdx, f32 dtdy , bool flip)
{
	if (gDP.otherMode.cycleType == G_CYC_COPY) {
		dsdx = 1.0f;
		lrx += 1.0f;
		lry += 1.0f;
	}
	lry = max(lry, uly + 1.0f);

	gDPTile *textureTileOrg[2];
	textureTileOrg[0] = gSP.textureTile[0];
	textureTileOrg[1] = gSP.textureTile[1];
	gSP.textureTile[0] = &gDP.tiles[tile];
	gSP.textureTile[1] = &gDP.tiles[(tile + 1) & 7];

	// HACK ALERT!
	if (s == 0x4000 && (gDP.colorImage.width + gSP.textureTile[0]->uls < 512))
		s = 0;

	gDP.rectColor = gDPInfo::Color();
	if (gDP.otherMode.cycleType < G_CYC_COPY) {
		if ((config.generalEmulation.hacks & hack_texrect_shade_alpha) != 0 &&
			gDP.combine.mA0 == G_ACMUX_0 && gDP.combine.aA0 == G_ACMUX_SHADE)
			gDP.rectColor.a = 1.0f;
	}

	GraphicsDrawer & drawer = dwnd().getDrawer();
	GraphicsDrawer::TexturedRectParams params(ulx, uly, lrx, lry, dsdx, dtdy, s, t,
		flip, false, true, frameBufferList().getCurrent());
	if (config.generalEmulation.enableNativeResTexrects == 0 && config.generalEmulation.correctTexrectCoords != Config::tcDisable)
		drawer.correctTexturedRectParams(params);
	drawer.drawTexturedRect(params);

	gSP.textureTile[0] = textureTileOrg[0];
	gSP.textureTile[1] = textureTileOrg[1];

	frameBufferList().setBufferChanged(lry);

	if (flip)
		DebugMsg( DEBUG_NORMAL, "gDPTextureRectangleFlip( %f, %f, %f, %f, %i, %f, %f, %f, %f);\n",
				  ulx, uly, lrx, lry, tile, s/32.0f, t/32.0f, dsdx, dtdy );
	else
		DebugMsg( DEBUG_NORMAL, "gDPTextureRectangle( %f, %f, %f, %f, %i, %i, %f, %f, %f, %f );\n",
				  ulx, uly, lrx, lry, tile, s/32.0f, t/32.0f, dsdx, dtdy);
	gSP.tri_num += 2;
}

void gDPFullSync()
{
	if (config.frameBufferEmulation.copyAuxToRDRAM != 0) {
		frameBufferList().copyAux();
		frameBufferList().removeAux();
	}

	dwnd().getDrawer().flush();

	const bool sync = config.frameBufferEmulation.copyToRDRAM == Config::ctSync;
	if ((config.frameBufferEmulation.copyToRDRAM != Config::ctDisable || (config.generalEmulation.hacks & hack_subscreen) != 0) &&
		!FBInfo::fbInfo.isSupported() &&
		frameBufferList().getCurrent() != nullptr &&
		!frameBufferList().getCurrent()->isAuxiliary()
	)
		FrameBuffer_CopyToRDRAM(gDP.colorImage.address, sync);

	if (RSP.LLE) {
		if (config.frameBufferEmulation.copyDepthToRDRAM != Config::cdDisable && !FBInfo::fbInfo.isSupported())
			FrameBuffer_CopyDepthBuffer(gDP.colorImage.address);
	}

	*REG.MI_INTR |= MI_INTR_DP;

	CheckInterrupts();

	DebugMsg( DEBUG_NORMAL, "gDPFullSync();\n" );
}

void gDPTileSync()
{
	DebugMsg( DEBUG_NORMAL | DEBUG_IGNORED, "gDPTileSync();\n" );
}

void gDPPipeSync()
{
	DebugMsg( DEBUG_NORMAL | DEBUG_IGNORED, "gDPPipeSync();\n" );
}

void gDPLoadSync()
{
	DebugMsg( DEBUG_NORMAL | DEBUG_IGNORED, "gDPLoadSync();\n" );
}

void gDPNoOp()
{
	DebugMsg( DEBUG_NORMAL | DEBUG_IGNORED, "gDPNoOp();\n" );
}

/*******************************************
 *          Low level triangle             *
 *******************************************
 *    based on sources of ziggy's z64      *
 *******************************************/

void gDPLLETriangle(u32 _w1, u32 _w2, int _shade, int _texture, int _zbuffer, u32 * _pRdpCmd)
{
	gSP.texture.level = _SHIFTR(_w1, 19, 3);
	const u32 tile = _SHIFTR(_w1, 16, 3);
	gDPTile *textureTileOrg[2];
	textureTileOrg[0] = gSP.textureTile[0];
	textureTileOrg[1] = gSP.textureTile[1];
	gSP.textureTile[0] = &gDP.tiles[tile];
	gSP.textureTile[1] = &gDP.tiles[(tile + 1) & 7];

	int j;
	int xleft, xright, xleft_inc, xright_inc;
	int r, g, b, a, z, s, t, w;
	int drdx = 0, dgdx = 0, dbdx = 0, dadx = 0, dzdx = 0, dsdx = 0, dtdx = 0, dwdx = 0;
	int drde = 0, dgde = 0, dbde = 0, dade = 0, dzde = 0, dsde = 0, dtde = 0, dwde = 0;
	int flip = (_w1 & 0x800000) ? 1 : 0;

	s32 yl, ym, yh;
	s32 xl, xm, xh;
	s32 dxldy, dxhdy, dxmdy;
	u32 w3, w4, w5, w6, w7, w8;

	u32 * shade_base = _pRdpCmd + 8;
	u32 * texture_base = _pRdpCmd + 8;
	u32 * zbuffer_base = _pRdpCmd + 8;

	if (_shade != 0) {
		texture_base += 16;
		zbuffer_base += 16;
	}
	if (_texture != 0) {
		zbuffer_base += 16;
	}

	w3 = _pRdpCmd[2];
	w4 = _pRdpCmd[3];
	w5 = _pRdpCmd[4];
	w6 = _pRdpCmd[5];
	w7 = _pRdpCmd[6];
	w8 = _pRdpCmd[7];

	yl = (_w1 & 0x3fff);
	ym = ((_w2 >> 16) & 0x3fff);
	yh = ((_w2 >>  0) & 0x3fff);
	xl = (s32)(w3);
	xh = (s32)(w5);
	xm = (s32)(w7);
	dxldy = (s32)(w4);
	dxhdy = (s32)(w6);
	dxmdy = (s32)(w8);

	if (yl & (0x800<<2)) yl |= 0xfffff000<<2;
	if (ym & (0x800<<2)) ym |= 0xfffff000<<2;
	if (yh & (0x800<<2)) yh |= 0xfffff000<<2;

	yh &= ~3;

	r = 0xff; g = 0xff; b = 0xff; a = 0xff; z = 0xffff0000; s = 0;  t = 0;  w = 0x30000;

	if (_shade != 0) {
		r    = (shade_base[0] & 0xffff0000) | ((shade_base[+4 ] >> 16) & 0x0000ffff);
		g    = ((shade_base[0 ] << 16) & 0xffff0000) | (shade_base[4 ] & 0x0000ffff);
		b    = (shade_base[1 ] & 0xffff0000) | ((shade_base[5 ] >> 16) & 0x0000ffff);
		a    = ((shade_base[1 ] << 16) & 0xffff0000) | (shade_base[5 ] & 0x0000ffff);
		drdx = (shade_base[2 ] & 0xffff0000) | ((shade_base[6 ] >> 16) & 0x0000ffff);
		dgdx = ((shade_base[2 ] << 16) & 0xffff0000) | (shade_base[6 ] & 0x0000ffff);
		dbdx = (shade_base[3 ] & 0xffff0000) | ((shade_base[7 ] >> 16) & 0x0000ffff);
		dadx = ((shade_base[3 ] << 16) & 0xffff0000) | (shade_base[7 ] & 0x0000ffff);
		drde = (shade_base[8 ] & 0xffff0000) | ((shade_base[12] >> 16) & 0x0000ffff);
		dgde = ((shade_base[8 ] << 16) & 0xffff0000) | (shade_base[12] & 0x0000ffff);
		dbde = (shade_base[9 ] & 0xffff0000) | ((shade_base[13] >> 16) & 0x0000ffff);
		dade = ((shade_base[9 ] << 16) & 0xffff0000) | (shade_base[13] & 0x0000ffff);
	}
	if (_texture != 0) {
		s    = (texture_base[0 ] & 0xffff0000) | ((texture_base[4 ] >> 16) & 0x0000ffff);
		t    = ((texture_base[0 ] << 16) & 0xffff0000)      | (texture_base[4 ] & 0x0000ffff);
		w    = (texture_base[1 ] & 0xffff0000) | ((texture_base[5 ] >> 16) & 0x0000ffff);
		//    w = abs(w);
		dsdx = (texture_base[2 ] & 0xffff0000) | ((texture_base[6 ] >> 16) & 0x0000ffff);
		dtdx = ((texture_base[2 ] << 16) & 0xffff0000)      | (texture_base[6 ] & 0x0000ffff);
		dwdx = (texture_base[3 ] & 0xffff0000) | ((texture_base[7 ] >> 16) & 0x0000ffff);
		dsde = (texture_base[8 ] & 0xffff0000) | ((texture_base[12] >> 16) & 0x0000ffff);
		dtde = ((texture_base[8 ] << 16) & 0xffff0000)      | (texture_base[12] & 0x0000ffff);
		dwde = (texture_base[9 ] & 0xffff0000) | ((texture_base[13] >> 16) & 0x0000ffff);
	}
	if (_zbuffer != 0) {
		z    = zbuffer_base[0];
		dzdx = zbuffer_base[1];
		dzde = zbuffer_base[2];
	}

	xh <<= 2;  xm <<= 2;  xl <<= 2;
	r <<= 2;  g <<= 2;  b <<= 2;  a <<= 2;
	dsde >>= 2;  dtde >>= 2;  dsdx >>= 2;  dtdx >>= 2;
	dzdx >>= 2;  dzde >>= 2;
	dwdx >>= 2;  dwde >>= 2;

#define XSCALE(x) (float(x)/(1<<18))
#define YSCALE(y) (float(y)/(1<<2))
#define ZSCALE(z) ((gDP.otherMode.depthSource == G_ZS_PRIM)? gDP.primDepth.z : float(u32(z))/0xffff0000)
#define PERSP_EN (gDP.otherMode.texturePersp != 0)
#define WSCALE(z) 1.0f/(PERSP_EN? (float(u32(z) + 0x10000)/0xffff0000) : 1.0f)
#define CSCALE(c) ((((c)>0x3ff0000? 0x3ff0000:((c)<0? 0 : (c)))>>18)*0.0039215689f)
#define _PERSP(w) ( w )
#define PERSP(s, w) ( ((s64)(s) << 20) / (_PERSP(w)? _PERSP(w):1) )
#define SSCALE(s, _w) (PERSP_EN? float(PERSP(s, _w))/(1 << 10) : float(s)/(1<<21))
#define TSCALE(s, w) (PERSP_EN? float(PERSP(s, w))/(1 << 10) : float(s)/(1<<21))

	GraphicsDrawer & drawer = dwnd().getDrawer();
	drawer.setDMAVerticesSize(16);
	SPVertex * vtx0 = drawer.getDMAVerticesData();
	SPVertex * vtx = vtx0;

	xleft = xm;
	xright = xh;
	xleft_inc = dxmdy;
	xright_inc = dxhdy;

	while (yh<ym &&
		!((!flip && xleft < xright+0x10000) ||
		 (flip && xleft > xright-0x10000))) {
		xleft += xleft_inc;
		xright += xright_inc;
		s += dsde;    t += dtde;    w += dwde;
		r += drde;    g += dgde;    b += dbde;    a += dade;
		z += dzde;
		yh++;
	}

	j = ym-yh;
	if (j > 0) {
		int dx = (xleft-xright)>>16;
		if ((!flip && xleft < xright) || (flip/* && xleft > xright*/))
		{
			if (_shade != 0) {
				vtx->r = CSCALE(r+drdx*dx);
				vtx->g = CSCALE(g+dgdx*dx);
				vtx->b = CSCALE(b+dbdx*dx);
				vtx->a = CSCALE(a+dadx*dx);
			}
			if (_texture != 0) {
				vtx->s = SSCALE(s+dsdx*dx, w+dwdx*dx);
				vtx->t = TSCALE(t+dtdx*dx, w+dwdx*dx);
			}
			vtx->x = XSCALE(xleft);
			vtx->y = YSCALE(yh);
			vtx->z = ZSCALE(z+dzdx*dx);
			vtx->w = WSCALE(w+dwdx*dx);
			++vtx;
		}
		if ((!flip/* && xleft < xright*/) || (/*flip &&*/ xleft > xright))
		{
			if (_shade != 0) {
				vtx->r = CSCALE(r);
				vtx->g = CSCALE(g);
				vtx->b = CSCALE(b);
				vtx->a = CSCALE(a);
			}
			if (_texture != 0) {
				vtx->s = SSCALE(s, w);
				vtx->t = TSCALE(t, w);
			}
			vtx->x = XSCALE(xright);
			vtx->y = YSCALE(yh);
			vtx->z = ZSCALE(z);
			vtx->w = WSCALE(w);
			++vtx;
		}
		xleft += xleft_inc*j;  xright += xright_inc*j;
		s += dsde*j;  t += dtde*j;
		if (w + dwde*j != 0) w += dwde*j;
		else w += dwde*(j-1);
		r += drde*j;  g += dgde*j;  b += dbde*j;  a += dade*j;
		z += dzde*j;
		// render ...
	}

	if (xl != xh)
		xleft = xl;

	//if (yl-ym > 0)
	{
		int dx = (xleft-xright)>>16;
		if ((!flip && xleft <= xright) ||
				(flip/* && xleft >= xright*/))
		{
			if (_shade != 0) {
				vtx->r = CSCALE(r+drdx*dx);
				vtx->g = CSCALE(g+dgdx*dx);
				vtx->b = CSCALE(b+dbdx*dx);
				vtx->a = CSCALE(a+dadx*dx);
			}
			if (_texture != 0) {
				vtx->s = SSCALE(s+dsdx*dx, w+dwdx*dx);
				vtx->t = TSCALE(t+dtdx*dx, w+dwdx*dx);
			}
			vtx->x = XSCALE(xleft);
			vtx->y = YSCALE(ym);
			vtx->z = ZSCALE(z+dzdx*dx);
			vtx->w = WSCALE(w+dwdx*dx);
			++vtx;
		}
		if ((!flip/* && xleft <= xright*/) ||
				(/*flip && */xleft >= xright))
		{
			if (_shade != 0) {
				vtx->r = CSCALE(r);
				vtx->g = CSCALE(g);
				vtx->b = CSCALE(b);
				vtx->a = CSCALE(a);
			}
			if (_texture != 0) {
				vtx->s = SSCALE(s, w);
				vtx->t = TSCALE(t, w);
			}
			vtx->x = XSCALE(xright);
			vtx->y = YSCALE(ym);
			vtx->z = ZSCALE(z);
			vtx->w = WSCALE(w);
			++vtx;
		}
	}
	xleft_inc = dxldy;
	xright_inc = dxhdy;

	j = yl-ym;
	//j--; // ?
	xleft += xleft_inc*j;  xright += xright_inc*j;
	s += dsde*j;  t += dtde*j;  w += dwde*j;
	r += drde*j;  g += dgde*j;  b += dbde*j;  a += dade*j;
	z += dzde*j;

	while (yl>ym &&
		   !((!flip && xleft < xright+0x10000) ||
			 (flip && xleft > xright-0x10000))) {
		xleft -= xleft_inc;    xright -= xright_inc;
		s -= dsde;    t -= dtde;    w -= dwde;
		r -= drde;    g -= dgde;    b -= dbde;    a -= dade;
		z -= dzde;
		--j;
		--yl;
	}

	// render ...
	if (j >= 0) {
		int dx = (xleft-xright)>>16;
		if ((!flip && xleft <= xright) ||
				(flip/* && xleft >= xright*/))
		{
			if (_shade != 0) {
				vtx->r = CSCALE(r+drdx*dx);
				vtx->g = CSCALE(g+dgdx*dx);
				vtx->b = CSCALE(b+dbdx*dx);
				vtx->a = CSCALE(a+dadx*dx);
			}
			if (_texture != 0) {
				vtx->s = SSCALE(s+dsdx*dx, w+dwdx*dx);
				vtx->t = TSCALE(t+dtdx*dx, w+dwdx*dx);
			}
			vtx->x = XSCALE(xleft);
			vtx->y = YSCALE(yl);
			vtx->z = ZSCALE(z+dzdx*dx);
			vtx->w = WSCALE(w+dwdx*dx);
			++vtx;
		}
		if ((!flip/* && xleft <= xright*/) ||
				(/*flip &&*/ xleft >= xright))
		{
			if (_shade != 0) {
				vtx->r = CSCALE(r);
				vtx->g = CSCALE(g);
				vtx->b = CSCALE(b);
				vtx->a = CSCALE(a);
			}
			if (_texture != 0) {
				vtx->s = SSCALE(s, w);
				vtx->t = TSCALE(t, w);
			}
			vtx->x = XSCALE(xright);
			vtx->y = YSCALE(yl);
			vtx->z = ZSCALE(z);
			vtx->w = WSCALE(w);
			++vtx;
		}
	}

	if (_texture != 0)
		gDP.changed |= CHANGED_TILE;
	if (_zbuffer != 0)
		gSP.geometryMode |= G_ZBUFFER;

	drawer.drawScreenSpaceTriangle(vtx - vtx0);
	gSP.textureTile[0] = textureTileOrg[0];
	gSP.textureTile[1] = textureTileOrg[1];

	DebugMsg( DEBUG_NORMAL, "gDPLLETriangle(%08x, %08x) shade: %d, texture: %d, zbuffer: %d\n",
			  _w1, _w2, _shade, _texture, _zbuffer);
}

static void gDPTriangle(u32 _w1, u32 _w2, int shade, int texture, int zbuffer)
{
	gDPLLETriangle(_w1, _w2, shade, texture, zbuffer, RDP.cmd_data + RDP.cmd_cur);
}

void gDPTriFill(u32 w0, u32 w1)
{
	gDPTriangle(w0, w1, 0, 0, 0);
	DebugMsg( DEBUG_NORMAL, "trifill\n");
}

void gDPTriShade(u32 w0, u32 w1)
{
	gDPTriangle(w0, w1, 1, 0, 0);
	DebugMsg( DEBUG_NORMAL, "trishade\n");
}

void gDPTriTxtr(u32 w0, u32 w1)
{
	gDPTriangle(w0, w1, 0, 1, 0);
	DebugMsg( DEBUG_NORMAL, "tritxtr\n");
}

void gDPTriShadeTxtr(u32 w0, u32 w1)
{
	gDPTriangle(w0, w1, 1, 1, 0);
	DebugMsg( DEBUG_NORMAL, "trishadetxtr\n");
}

void gDPTriFillZ(u32 w0, u32 w1)
{
	gDPTriangle(w0, w1, 0, 0, 1);
	DebugMsg( DEBUG_NORMAL, "trifillz\n");
}

void gDPTriShadeZ(u32 w0, u32 w1)
{
	gDPTriangle(w0, w1, 1, 0, 1);
	DebugMsg( DEBUG_NORMAL, "trishadez\n");
}

void gDPTriTxtrZ(u32 w0, u32 w1)
{
	gDPTriangle(w0, w1, 0, 1, 1);
	DebugMsg( DEBUG_NORMAL, "tritxtrz\n");
}

void gDPTriShadeTxtrZ(u32 w0, u32 w1)
{
	gDPTriangle(w0, w1, 1, 1, 1);
	DebugMsg( DEBUG_NORMAL, "trishadetxtrz\n");
}
