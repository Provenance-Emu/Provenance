#include <assert.h>
#include <math.h>
#include "N64.h"
#include "RSP.h"
#include "RDP.h"
#include "gSP.h"
#include "gDP.h"
#include "Log.h"
#include "F3D.h"
#include "ZSort.h"
#include "3DMath.h"
#include "DisplayWindow.h"

#define	GZM_USER0		0
#define	GZM_USER1		2
#define	GZM_MMTX		4
#define	GZM_PMTX		6
#define	GZM_MPMTX		8
#define	GZM_OTHERMODE	10
#define	GZM_VIEWPORT	12
#define	GZF_LOAD		0
#define	GZF_SAVE		1

#define	ZH_NULL		0
#define	ZH_SHTRI	1
#define	ZH_TXTRI	2
#define	ZH_SHQUAD	3
#define	ZH_TXQUAD	4

struct ZSORTRDP
{
	f32 view_scale[2];
	f32 view_trans[2];
} zSortRdp = {{0, 0}, {0, 0}};

void ZSort_RDPCMD( u32, u32 _w1 )
{
	u32 addr = RSP_SegmentToPhysical(_w1) >> 2;
	if (addr) {
		RSP.LLE = true;
		while(true)
		{
			u32 w0 = ((u32*)RDRAM)[addr++];
			RSP.cmd = _SHIFTR( w0, 24, 8 );
			if (RSP.cmd == 0xDF)
				break;
			u32 w1 = ((u32*)RDRAM)[addr++];
			if (RSP.cmd == G_TEXRECT || RSP.cmd == G_TEXRECTFLIP) {
				addr++;
				RDP.w2 = ((u32*)RDRAM)[addr++];
				addr++;
				RDP.w3 = ((u32*)RDRAM)[addr++];
			}
			GBI.cmd[RSP.cmd]( w0, w1 );
		};
		RSP.LLE = false;
	}
}

int Calc_invw (int _w) {
	if (_w == 0)
		return 0x7FFFFFFF;
	return 0x7FFFFFFF / _w;
}

static
void ZSort_DrawObject (u8 * _addr, u32 _type)
{
	u32 textured = 0, vnum = 0, vsize = 0;
	switch (_type) {
	case ZH_NULL:
		textured = vnum = vsize = 0;
	break;
	case ZH_SHTRI:
		textured = 0;
		vnum = 3;
		vsize = 8;
	break;
	case ZH_TXTRI:
		textured = 1;
		vnum = 3;
		vsize = 16;
	break;
	case ZH_SHQUAD:
		textured = 0;
		vnum = 4;
		vsize = 8;
	break;
	case ZH_TXQUAD:
		textured = 1;
		vnum = 4;
		vsize = 16;
	break;
	}

	GraphicsDrawer & drawer = dwnd().getDrawer();
	drawer.setDMAVerticesSize(vnum);
	SPVertex * pVtx = drawer.getDMAVerticesData();
	for (u32 i = 0; i < vnum; ++i) {
		SPVertex & vtx = pVtx[i];
		vtx.x = _FIXED2FLOAT(((s16*)_addr)[0 ^ 1], 2);
		vtx.y = _FIXED2FLOAT(((s16*)_addr)[1 ^ 1], 2);
		vtx.z = 0.0f;
		vtx.r = _addr[4^3] * 0.0039215689f;
		vtx.g = _addr[5^3] * 0.0039215689f;
		vtx.b = _addr[6^3] * 0.0039215689f;
		vtx.a = _addr[7^3] * 0.0039215689f;
		vtx.flag = 0;
		vtx.HWLight = 0;
		vtx.clip = 0;
		if (textured != 0) {
			if (gDP.otherMode.texturePersp != 0) {
				vtx.s = _FIXED2FLOAT(((s16*)_addr)[4 ^ 1], 5);
				vtx.t = _FIXED2FLOAT(((s16*)_addr)[5 ^ 1], 5);
			} else {
				vtx.s = _FIXED2FLOAT(((s16*)_addr)[4 ^ 1], 6);
				vtx.t = _FIXED2FLOAT(((s16*)_addr)[5 ^ 1], 6);
			}
			vtx.w = Calc_invw(((int*)_addr)[3]) / 31.0f;
		} else
			vtx.w = 1.0f;

		_addr += vsize;
	}
	drawer.drawScreenSpaceTriangle(vnum);
}

static
u32 ZSort_LoadObject (u32 _zHeader, u32 * _pRdpCmds)
{
	const u32 type = _zHeader & 7;
	u8 * addr = RDRAM + (_zHeader&0xFFFFFFF8);
	u32 w1;
	switch (type) {
	case ZH_SHTRI:
	case ZH_SHQUAD:
	{
		w1 = ((u32*)addr)[1];
		if (w1 != _pRdpCmds[0]) {
			_pRdpCmds[0] = w1;
			ZSort_RDPCMD (0, w1);
		}
		ZSort_DrawObject(addr + 8, type);
	}
	break;
	case ZH_NULL:
	case ZH_TXTRI:
	case ZH_TXQUAD:
	{
		w1 = ((u32*)addr)[1];
		if (w1 != _pRdpCmds[0]) {
			_pRdpCmds[0] = w1;
			ZSort_RDPCMD (0, w1);
		}
		w1 = ((u32*)addr)[2];
		if (w1 != _pRdpCmds[1]) {
			ZSort_RDPCMD (0, w1);
			_pRdpCmds[1] = w1;
		}
		w1 = ((u32*)addr)[3];
		if (w1 != _pRdpCmds[2]) {
			ZSort_RDPCMD (0,  w1);
			_pRdpCmds[2] = w1;
		}
		if (type != 0) {
			ZSort_DrawObject(addr + 16, type);
		}
	}
	break;
	}
	return RSP_SegmentToPhysical(((u32*)addr)[0]);
}

void ZSort_Obj( u32 _w0, u32 _w1 )
{
	u32 rdpcmds[3] = {0, 0, 0};
	u32 cmd1 = _w1;
	u32 zHeader = RSP_SegmentToPhysical(_w0);
	while (zHeader)
		zHeader = ZSort_LoadObject(zHeader, rdpcmds);
	zHeader = RSP_SegmentToPhysical(cmd1);
	while (zHeader)
		zHeader = ZSort_LoadObject(zHeader, rdpcmds);
}

void ZSort_Interpolate( u32, u32 )
{
	LOG(LOG_VERBOSE, "ZSort_Interpolate Ignored\n");
}

void ZSort_XFMLight( u32 _w0, u32 _w1 )
{
	int mid = _SHIFTR(_w0, 0, 8);
	gSPNumLights(1 + _SHIFTR(_w1, 12, 8));
	u32 addr = -1024 + _SHIFTR(_w1, 0, 12);

	assert(mid == GZM_MMTX);
/*
	M44 *m;
	switch (mid) {
	case 4:
		m = (M44*)rdp.model;
	break;
	case 6:
		m = (M44*)rdp.proj;
	break;
	case 8:
		m = (M44*)gSP.matrix.combined;
	break;
	}
*/


	gSP.lights.rgb[gSP.numLights][R] = _FIXED2FLOATCOLOR(((u8*)DMEM)[(addr+0)^3], 8 );
	gSP.lights.rgb[gSP.numLights][G] = _FIXED2FLOATCOLOR(((u8*)DMEM)[(addr+1)^3], 8 );
	gSP.lights.rgb[gSP.numLights][B] = _FIXED2FLOATCOLOR(((u8*)DMEM)[(addr+2)^3], 8 );
	addr += 8;
	u32 i;
	for (i = 0; i < gSP.numLights; ++i)
	{
		gSP.lights.rgb[i][R] = _FIXED2FLOATCOLOR(((u8*)DMEM)[(addr+0)^3], 8 );
		gSP.lights.rgb[i][G] = _FIXED2FLOATCOLOR(((u8*)DMEM)[(addr+1)^3], 8 );
		gSP.lights.rgb[i][B] = _FIXED2FLOATCOLOR(((u8*)DMEM)[(addr+2)^3], 8 );
		gSP.lights.xyz[i][X] = (f32)(((s8*)DMEM)[(addr+8)^3]);
		gSP.lights.xyz[i][Y] = (f32)(((s8*)DMEM)[(addr+9)^3]);
		gSP.lights.xyz[i][Z] = (f32)(((s8*)DMEM)[(addr+10)^3]);
		addr += 24;
	}
	for (i = 0; i < 2; i++)
	{
		gSP.lookat.xyz[i][X] = (f32)(((s8*)DMEM)[(addr+8)^3]);
		gSP.lookat.xyz[i][Y] = (f32)(((s8*)DMEM)[(addr+9)^3]);
		gSP.lookat.xyz[i][Z] = (f32)(((s8*)DMEM)[(addr+10)^3]);
		gSP.lookatEnable = (i == 0) || (gSP.lookat.xyz[i][X] != 0 && gSP.lookat.xyz[i][Y] != 0);
		addr += 24;
	}
}

void ZSort_LightingL( u32, u32 )
{
	LOG(LOG_VERBOSE, "ZSort_LightingL Ignored\n");
}


void ZSort_Lighting( u32 _w0, u32 _w1 )
{
	u32 csrs = -1024 + _SHIFTR(_w0, 12, 12);
	u32 nsrs = -1024 + _SHIFTR(_w0, 0, 12);
	u32 num = 1 + _SHIFTR(_w1, 24, 8);
	u32 cdest = -1024 + _SHIFTR(_w1, 12, 12);
	u32 tdest = -1024 + _SHIFTR(_w1, 0, 12);
	int use_material = (csrs != 0x0ff0);
	tdest >>= 1;
	GraphicsDrawer & drawer = dwnd().getDrawer();
	drawer.setDMAVerticesSize(num);
	SPVertex * pVtx = drawer.getDMAVerticesData();
	for (u32 i = 0; i < num; i++) {
		SPVertex & vtx = pVtx[i];

		vtx.nx = ((s8*)DMEM)[(nsrs++)^3];
		vtx.ny = ((s8*)DMEM)[(nsrs++)^3];
		vtx.nz = ((s8*)DMEM)[(nsrs++)^3];
		TransformVectorNormalize( &vtx.nx, gSP.matrix.modelView[gSP.matrix.modelViewi] );
		gSPLightVertex(vtx);
		f32 fLightDir[3] = {vtx.nx, vtx.ny, vtx.nz};
		TransformVectorNormalize(fLightDir, gSP.matrix.projection);
		f32 x, y;
		if (gSP.lookatEnable) {
			x = DotProduct(gSP.lookat.xyz[0], fLightDir);
			y = DotProduct(gSP.lookat.xyz[1], fLightDir);
		} else {
			x = fLightDir[0];
			y = fLightDir[1];
		}
		vtx.s = (x + 1.0f) * 512.0f;
		vtx.t = (y + 1.0f) * 512.0f;

		vtx.a = 1.0f;
		if (use_material)
		{
			vtx.r *= _FIXED2FLOATCOLOR(DMEM[(csrs++)^3], 8 );
			vtx.g *= _FIXED2FLOATCOLOR(DMEM[(csrs++)^3], 8 );
			vtx.b *= _FIXED2FLOATCOLOR(DMEM[(csrs++)^3], 8 );
			vtx.a = _FIXED2FLOATCOLOR(DMEM[(csrs++)^3], 8 );
		}
		DMEM[(cdest++)^3] = (u8)(vtx.r * 255.0f);
		DMEM[(cdest++)^3] = (u8)(vtx.g * 255.0f);
		DMEM[(cdest++)^3] = (u8)(vtx.b * 255.0f);
		DMEM[(cdest++)^3] = (u8)(vtx.a * 255.0f);
		((s16*)DMEM)[(tdest++)^1] = (s16)(vtx.s * 32.0f);
		((s16*)DMEM)[(tdest++)^1] = (s16)(vtx.t * 32.0f);
	}
}

void ZSort_MTXRNSP( u32, u32 )
{
	LOG(LOG_VERBOSE, "ZSort_MTXRNSP Ignored\n");
}

void ZSort_MTXCAT(u32 _w0, u32 _w1)
{
	M44 *s = nullptr;
	M44 *t = nullptr;
	u32 S = _SHIFTR(_w0, 0, 4);
	u32 T = _SHIFTR(_w1, 16, 4);
	u32 D = _SHIFTR(_w1, 0, 4);
	switch (S) {
	case GZM_MMTX:
		s = (M44*)gSP.matrix.modelView[gSP.matrix.modelViewi];
	break;
	case GZM_PMTX:
		s = (M44*)gSP.matrix.projection;
	break;
	case GZM_MPMTX:
		s = (M44*)gSP.matrix.combined;
	break;
	}
	switch (T) {
	case GZM_MMTX:
		t = (M44*)gSP.matrix.modelView[gSP.matrix.modelViewi];
	break;
	case GZM_PMTX:
		t = (M44*)gSP.matrix.projection;
	break;
	case GZM_MPMTX:
		t = (M44*)gSP.matrix.combined;
	break;
	}
	assert(s != nullptr && t != nullptr);
	f32 m[4][4];
	MultMatrix(*s, *t, m);

	switch (D) {
	case GZM_MMTX:
		memcpy (gSP.matrix.modelView[gSP.matrix.modelViewi], m, 64);;
	break;
	case GZM_PMTX:
		memcpy (gSP.matrix.projection, m, 64);;
	break;
	case GZM_MPMTX:
		memcpy (gSP.matrix.combined, m, 64);;
	break;
	}
}

void ZSort_MultMPMTX( u32 _w0, u32 _w1 )
{
	int num = 1 + _SHIFTR(_w1, 24, 8);
	int src = -1024 + _SHIFTR(_w1, 12, 12);
	int dst = -1024 + _SHIFTR(_w1, 0, 12);
	s16 * saddr = (s16*)(DMEM+src);
	zSortVDest * daddr = (zSortVDest*)(DMEM+dst);
	int idx = 0;
	zSortVDest v;
	memset(&v, 0, sizeof(zSortVDest));
	for (int i = 0; i < num; ++i) {
		s16 sx = saddr[(idx++)^1];
		s16 sy = saddr[(idx++)^1];
		s16 sz = saddr[(idx++)^1];
		f32 x = sx*gSP.matrix.combined[0][0] + sy*gSP.matrix.combined[1][0] + sz*gSP.matrix.combined[2][0] + gSP.matrix.combined[3][0];
		f32 y = sx*gSP.matrix.combined[0][1] + sy*gSP.matrix.combined[1][1] + sz*gSP.matrix.combined[2][1] + gSP.matrix.combined[3][1];
		f32 z = sx*gSP.matrix.combined[0][2] + sy*gSP.matrix.combined[1][2] + sz*gSP.matrix.combined[2][2] + gSP.matrix.combined[3][2];
		f32 w = sx*gSP.matrix.combined[0][3] + sy*gSP.matrix.combined[1][3] + sz*gSP.matrix.combined[2][3] + gSP.matrix.combined[3][3];
		v.sx = (s16)(zSortRdp.view_trans[0] + x / w * zSortRdp.view_scale[0]);
		v.sy = (s16)(zSortRdp.view_trans[1] + y / w * zSortRdp.view_scale[1]);

		v.xi = (s16)x;
		v.yi = (s16)y;
		v.wi = (s16)w;
		v.invw = Calc_invw((int)(w * 31.0));

		if (w < 0.0f)
			v.fog = 0;
		else {
			int fog = (int)(z / w * gSP.fog.multiplier + gSP.fog.offset);
			if (fog > 255)
				fog = 255;
			v.fog = (fog >= 0) ? (u8)fog : 0;
		}

		v.cc = 0;
		if (x < -w) v.cc |= 0x10;
		if (x > w) v.cc |= 0x01;
		if (y < -w) v.cc |= 0x20;
		if (y > w) v.cc |= 0x02;
		if (w < 0.1f) v.cc |= 0x04;

		daddr[i] = v;
	}
}

void ZSort_LinkSubDL( u32, u32 )
{
	LOG(LOG_VERBOSE, "ZSort_LinkSubDL Ignored\n");
}

void ZSort_SetSubDL( u32, u32 )
{
	LOG(LOG_VERBOSE, "ZSort_SetSubDL Ignored\n");
}

void ZSort_WaitSignal( u32, u32 )
{
	LOG(LOG_VERBOSE, "ZSort_WaitSignal Ignored\n");
}

void ZSort_SendSignal( u32, u32 )
{
	LOG(LOG_VERBOSE, "ZSort_SendSignal Ignored\n");
}

static
void ZSort_SetTexture()
{
	gSP.texture.scales = 1.0f;
	gSP.texture.scalet = 1.0f;
	gSP.texture.level = 0;
	gSP.texture.on = 1;
	gSP.texture.tile = 0;

	gSPSetGeometryMode(G_SHADING_SMOOTH | G_SHADE);
}

void ZSort_MoveMem( u32 _w0, u32 _w1 )
{
	int idx = _w0 & 0x0E;
	int ofs = _SHIFTR(_w0, 6, 9)<<3;
	int len = 1 + (_SHIFTR(_w0, 15, 9)<<3);
	int flag = _w0 & 0x01;
	u32 addr = RSP_SegmentToPhysical(_w1);
	switch (idx)
	{

	case GZF_LOAD: //save/load
		if (flag == 0) {
			int dmem_addr = (idx<<3) + ofs;
			memcpy(DMEM + dmem_addr, RDRAM + addr, len);
		} else {
			int dmem_addr = (idx<<3) + ofs;
			memcpy(RDRAM + addr, DMEM + dmem_addr, len);
		}
	break;

	case GZM_MMTX:  // model matrix
		RSP_LoadMatrix(gSP.matrix.modelView[gSP.matrix.modelViewi], addr);
		gSP.changed |= CHANGED_MATRIX;
	break;

	case GZM_PMTX:  // projection matrix
		RSP_LoadMatrix(gSP.matrix.projection, addr);
		gSP.changed |= CHANGED_MATRIX;
	break;

	case GZM_MPMTX:  // combined matrix
		RSP_LoadMatrix(gSP.matrix.combined, addr);
		gSP.changed &= ~CHANGED_MATRIX;
	break;

	case GZM_OTHERMODE:
		LOG(LOG_VERBOSE, "MoveMem Othermode Ignored\n");
	break;

	case GZM_VIEWPORT:   // VIEWPORT
	{
		u32 a = addr >> 1;
		const f32 scale_x = _FIXED2FLOAT( *(s16*)&RDRAM[(a+0)^1], 2 );
		const f32 scale_y = _FIXED2FLOAT( *(s16*)&RDRAM[(a+1)^1], 2 );
		const f32 scale_z = _FIXED2FLOAT( *(s16*)&RDRAM[(a+2)^1], 10 );
		const s16 fm = ((s16*)RDRAM)[(a+3)^1];
		const f32 trans_x = _FIXED2FLOAT( *(s16*)&RDRAM[(a+4)^1], 2 );
		const f32 trans_y = _FIXED2FLOAT( *(s16*)&RDRAM[(a+5)^1], 2 );
		const f32 trans_z = _FIXED2FLOAT( *(s16*)&RDRAM[(a+6)^1], 10 );
		const s16 fo = ((s16*)RDRAM)[(a+7)^1];
		gSPFogFactor(fm, fo);

		gSP.viewport.vscale[0] = scale_x;
		gSP.viewport.vscale[1] = scale_y;
		gSP.viewport.vscale[2] = scale_z;
		gSP.viewport.vtrans[0] = trans_x;
		gSP.viewport.vtrans[1] = trans_y;
		gSP.viewport.vtrans[2] = trans_z;

		gSP.viewport.x		= gSP.viewport.vtrans[0] - gSP.viewport.vscale[0];
		gSP.viewport.y		= gSP.viewport.vtrans[1] - gSP.viewport.vscale[1];
		gSP.viewport.width	= gSP.viewport.vscale[0] * 2;
		gSP.viewport.height	= gSP.viewport.vscale[1] * 2;
		gSP.viewport.nearz	= gSP.viewport.vtrans[2] - gSP.viewport.vscale[2];
		gSP.viewport.farz	= (gSP.viewport.vtrans[2] + gSP.viewport.vscale[2]) ;

		zSortRdp.view_scale[0] = scale_x*4.0f;
		zSortRdp.view_scale[1] = scale_y*4.0f;
		zSortRdp.view_trans[0] = trans_x*4.0f;
		zSortRdp.view_trans[1] = trans_y*4.0f;

		gSP.changed |= CHANGED_VIEWPORT;

		ZSort_SetTexture();
	}
	break;

	default:
		LOG(LOG_ERROR, "ZSort_MoveMem UNKNOWN %d\n", idx);
	}

}

void SZort_SetScissor(u32 _w0, u32 _w1)
{
	RDP_SetScissor(_w0, _w1);

	if ((gDP.scissor.lrx - gDP.scissor.ulx) > (zSortRdp.view_scale[0] - zSortRdp.view_trans[0]))
	{
		f32 w = (gDP.scissor.lrx - gDP.scissor.ulx) / 2.0f;
		f32 h = (gDP.scissor.lry - gDP.scissor.uly) / 2.0f;

		gSP.viewport.vscale[0] = w;
		gSP.viewport.vscale[1] = h;
		gSP.viewport.vtrans[0] = w;
		gSP.viewport.vtrans[1] = h;

		gSP.viewport.x = gSP.viewport.vtrans[0] - gSP.viewport.vscale[0];
		gSP.viewport.y = gSP.viewport.vtrans[1] - gSP.viewport.vscale[1];
		gSP.viewport.width = gSP.viewport.vscale[0] * 2;
		gSP.viewport.height = gSP.viewport.vscale[1] * 2;

		zSortRdp.view_scale[0] = w * 4.0f;
		zSortRdp.view_scale[1] = h * 4.0f;
		zSortRdp.view_trans[0] = w * 4.0f;
		zSortRdp.view_trans[1] = h * 4.0f;

		gSP.changed |= CHANGED_VIEWPORT;

		ZSort_SetTexture();
	}
}

#define	G_ZS_ZOBJ			0x80
#define	G_ZS_RDPCMD			0x81
#define	G_ZS_SETOTHERMODE_H	0xE3
#define	G_ZS_SETOTHERMODE_L	0xE2
#define	G_ZS_ENDDL			0xDF
#define	G_ZS_DL				0xDE
#define	G_ZS_MOVEMEM		0xDC
#define	G_ZS_MOVEWORD		0xDB
#define	G_ZS_SENDSIGNAL		0xDA
#define	G_ZS_WAITSIGNAL		0xD9
#define	G_ZS_SETSUBDL		0xD8
#define	G_ZS_LINKSUBDL		0xD7
#define	G_ZS_MULT_MPMTX		0xD6
#define	G_ZS_MTXCAT			0xD5
#define	G_ZS_MTXTRNSP		0xD4
#define	G_ZS_LIGHTING_L		0xD3
#define	G_ZS_LIGHTING		0xD2
#define	G_ZS_XFMLIGHT		0xD1
#define	G_ZS_INTERPOLATE	0xD0

u32 G_ZSENDSIGNAL, G_ZSETSUBDL, G_ZLINKSUBDL, G_ZMTXTRNSP;
u32 G_ZLIGHTING_L, G_ZXFMLIGHT, G_ZINTERPOLATE, G_ZSETSCISSOR;

void ZSort_Init()
{
	gSPSetupFunctions();
	// Set GeometryMode flags
	GBI_InitFlags( F3D );

	GBI.PCStackSize = 10;

	//          GBI Command             Command Value			Command Function
	GBI_SetGBI( G_SPNOOP,				F3D_SPNOOP,				F3D_SPNoOp );
	GBI_SetGBI( G_RESERVED0,			F3D_RESERVED0,			F3D_Reserved0 );
	GBI_SetGBI( G_RESERVED1,			F3D_RESERVED1,			F3D_Reserved1 );
	GBI_SetGBI( G_DL,					G_ZS_DL,				F3D_DList );
	GBI_SetGBI( G_RESERVED2,			F3D_RESERVED2,			F3D_Reserved2 );
	GBI_SetGBI( G_RESERVED3,			F3D_RESERVED3,			F3D_Reserved3 );

	GBI_SetGBI( G_CULLDL,				F3D_CULLDL,				F3D_CullDL );
	GBI_SetGBI( G_MOVEWORD,				G_ZS_MOVEWORD,			F3D_MoveWord );
	GBI_SetGBI( G_TEXTURE,				F3D_TEXTURE,			F3D_Texture );
	GBI_SetGBI( G_ZSETSCISSOR,			G_SETSCISSOR,			SZort_SetScissor );
	GBI_SetGBI( G_SETOTHERMODE_H,		G_ZS_SETOTHERMODE_H,	F3D_SetOtherMode_H );
	GBI_SetGBI( G_SETOTHERMODE_L,		G_ZS_SETOTHERMODE_L,	F3D_SetOtherMode_L );
	GBI_SetGBI( G_ENDDL,				G_ZS_ENDDL,				F3D_EndDL );
	GBI_SetGBI( G_SETGEOMETRYMODE,		F3D_SETGEOMETRYMODE,	F3D_SetGeometryMode );
	GBI_SetGBI( G_CLEARGEOMETRYMODE,	F3D_CLEARGEOMETRYMODE,	F3D_ClearGeometryMode );
	GBI_SetGBI( G_RDPHALF_1,			F3D_RDPHALF_1,			F3D_RDPHalf_1 );
	GBI_SetGBI( G_RDPHALF_2,			F3D_RDPHALF_2,			F3D_RDPHalf_2 );
	GBI_SetGBI( G_RDPHALF_CONT,			F3D_RDPHALF_CONT,		F3D_RDPHalf_Cont );

	GBI_SetGBI( G_ZOBJ,					G_ZS_ZOBJ,				ZSort_Obj );
	GBI_SetGBI( G_ZRDPCMD,				G_ZS_RDPCMD,			ZSort_RDPCMD );
	GBI_SetGBI( G_MOVEMEM,				G_ZS_MOVEMEM,			ZSort_MoveMem );
	GBI_SetGBI( G_ZSENDSIGNAL,			G_ZS_SENDSIGNAL,		ZSort_SendSignal );
	GBI_SetGBI( G_ZWAITSIGNAL,			G_ZS_WAITSIGNAL,		ZSort_WaitSignal );
	GBI_SetGBI( G_ZSETSUBDL,			G_ZS_SETSUBDL,			ZSort_SetSubDL );
	GBI_SetGBI( G_ZLINKSUBDL,			G_ZS_LINKSUBDL,			ZSort_LinkSubDL );
	GBI_SetGBI( G_ZMULT_MPMTX,			G_ZS_MULT_MPMTX,		ZSort_MultMPMTX );
	GBI_SetGBI( G_ZMTXCAT,				G_ZS_MTXCAT,			ZSort_MTXCAT );
	GBI_SetGBI( G_ZMTXTRNSP,			G_ZS_MTXTRNSP,			ZSort_MTXRNSP );
	GBI_SetGBI( G_ZLIGHTING_L,			G_ZS_LIGHTING_L,		ZSort_LightingL );
	GBI_SetGBI( G_ZLIGHTING,			G_ZS_LIGHTING,			ZSort_Lighting );
	GBI_SetGBI( G_ZXFMLIGHT,			G_ZS_XFMLIGHT,			ZSort_XFMLight );
	GBI_SetGBI( G_ZINTERPOLATE,			G_ZS_INTERPOLATE,		ZSort_Interpolate );
}
