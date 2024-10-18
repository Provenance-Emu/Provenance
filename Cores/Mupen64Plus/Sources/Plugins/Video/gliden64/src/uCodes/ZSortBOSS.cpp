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

#define CLAMP(x, min, max) ((x > max) ? max : ((x < min) ? min: x))
#define SATURATES8(x) ((x > 127) ? 127 : ((x < -128) ? -128: x))

#define	ZH_NULL		0
#define	ZH_TXTRI	4
#define	ZH_TXQUAD	8

#define DEFAULT		0
#define PROCESSED	1

struct ZSortBOSSState {
	u32 maindl;
	u32 subdl;
	u32 updatemask[2];
	f32 view_scale[2];
	f32 view_trans[2];
	u32 rdpcmds[3];
	f32 invw_factor;
	u8 fogtable[256];
	s16 table[8][8];
	bool waiting_for_signal;
};

struct ZSortBOSSState gstate;

void ZSortBOSS_EndMainDL( u32, u32 )
{
	if(gstate.subdl == PROCESSED) {
		// is this really happening?
		assert(0);
		RSP.halt = true;
		gstate.maindl = DEFAULT;
		gstate.subdl = DEFAULT;
	}
	else {
		gstate.maindl = PROCESSED;

		if((*REG.SP_STATUS & 0x80) == 0) {
			// wait for sig0
			RSP.PC[RSP.PCi] -= 8;
			RSP.infloop = true;
			RSP.halt = true;
		}
		else {
			// process sub dlist
			RSP.PCi = 1;
			*REG.SP_STATUS &= ~0x80;  // clear sig0
		}
	}
	LOG(LOG_VERBOSE, "ZSortBOSS_EndMainDL\n");
}

void ZSortBOSS_EndSubDL( u32, u32 )
{
	if(gstate.maindl == PROCESSED) {
		RSP.halt = true;
		gstate.maindl = DEFAULT;
		gstate.subdl = DEFAULT;
	}
	else {
		// is this really happening?
		assert(0);
		//process main dlist
		RSP.PCi = 0;
		gstate.subdl = PROCESSED;
	}
	LOG(LOG_VERBOSE, "ZSortBOSS_EndSubDL\n");
}

void ZSortBOSS_WaitSignal( u32 , u32 )
{
	if(!gstate.waiting_for_signal) {
		// *REG.MI_INTR |= MI_INTR_SP;
		*REG.SP_STATUS &= ~0x300;  // clear sig1 | sig2
		*REG.SP_STATUS |= 0x400;   // set sig3
	}

	if((*REG.SP_STATUS & 0x400)) {
		// wait !sig3
		RSP.PC[RSP.PCi] -= 8;
		RSP.infloop = true;
		RSP.halt = true;
		gstate.waiting_for_signal = true;
	}
	else
		gstate.waiting_for_signal = false;

	LOG(LOG_VERBOSE, "ZSortBOSS_WaitSignal\n");
}

void ZSortBOSS_MoveWord( u32 _w0, u32 _w1 )
{
	assert((_w0 & 3) == 0);

	if(((_w0 & 0xfff) == 0x10) && (RSP.nextCmd == 0x04)) {	// Next cmd is G_ZSBOSS_MOVEMEM
		gstate.invw_factor = (f32)_w1;
	}

	memcpy((DMEM + (_w0 & 0xfff)), &_w1, sizeof(u32));
	LOG(LOG_VERBOSE, "ZSortBOSS_MoveWord (Write 0x%08x to DMEM: 0x%04x)\n", _w1, (_w0 & 0xfff));
}

void ZSortBOSS_ClearBuffer( u32, u32 )
{
	memset((DMEM + 0xc20), 0, 512);
	LOG(LOG_VERBOSE, "ZSortBOSS_ClearBuffer (Write 0x0 to DMEM: 0x0c20 -> 0x0e20)\n");
}

static
void StoreMatrix( f32 mtx[4][4], u32 address )
{
	struct _N64Matrix
	{
		s16 integer[4][4];
		u16 fraction[4][4];
	} *n64Mat = (struct _N64Matrix *)&RDRAM[address];
	
	for (u32 i = 0; i < 4; i++) {
		for (u32 j = 0; j < 4; j++) {
			const auto element = GetIntMatrixElement(mtx[i][j]);
			n64Mat->fraction[i][j^1] = element.second;
			n64Mat->integer[i][j^1] = element.first;
		}
	}
}

void ZSortBOSS_MoveMem( u32 _w0, u32 _w1 )
{
	int flag = (_w0 >> 23) & 0x01;
	int len = 1 + (_w0 >> 12) & 0x7ff;
	u32 addr = RSP_SegmentToPhysical(_w1);
	assert((addr & 3) == 0);
	assert((_w0 & 3) == 0);

	LOG(LOG_VERBOSE, "ZSortBOSS_MoveMem (R/W: %d, RDRAM: 0x%08x, DMEM: 0x%04x; len: %d)\n", flag, addr, (_w0 & 0xfff), len);

	// model matrix
	if((_w0 & 0xfff) == 0x830) {
		assert(flag == 0);
		RSP_LoadMatrix(gSP.matrix.modelView[gSP.matrix.modelViewi], addr);
		gSP.changed |= CHANGED_MATRIX;
		return;
	}

	// projection matrix
	if((_w0 & 0xfff) == 0x870) {
		assert(flag == 0);
		RSP_LoadMatrix(gSP.matrix.projection, addr);
		gSP.changed |= CHANGED_MATRIX;
		return;
	}

	// combined matrix
	if((_w0 & 0xfff) == 0x8b0) {
		if(flag == 0) {
			RSP_LoadMatrix(gSP.matrix.combined, addr);
			gSP.changed &= ~CHANGED_MATRIX;
		} else {
			StoreMatrix(gSP.matrix.combined, addr);
		}
		return;
	}

	// VIEWPORT
	if((_w0 & 0xfff) == 0x0) {
		u32 a = addr >> 1;

		const f32 scale_x = _FIXED2FLOAT( ((s16*)RDRAM)[(a+0)^1], 2 );
		const f32 scale_y = _FIXED2FLOAT( ((s16*)RDRAM)[(a+1)^1], 2 );
		const f32 scale_z = _FIXED2FLOAT( ((s16*)RDRAM)[(a+2)^1], 10 );
		const s16 fm = ((s16*)RDRAM)[(a+3)^1];
		const f32 trans_x = _FIXED2FLOAT( ((s16*)RDRAM)[(a+4)^1], 2 );
		const f32 trans_y = _FIXED2FLOAT( ((s16*)RDRAM)[(a+5)^1], 2 );
		const f32 trans_z = _FIXED2FLOAT( ((s16*)RDRAM)[(a+6)^1], 10 );
		const s16 fo = ((s16*)RDRAM)[(a+7)^1];
		gSPFogFactor(fm, fo);

		gSP.viewport.vscale[0] = scale_x;
		gSP.viewport.vscale[1] = scale_y;
		gSP.viewport.vscale[2] = scale_z;
		gSP.viewport.vtrans[0] = trans_x;
		gSP.viewport.vtrans[1] = trans_y;
		gSP.viewport.vtrans[2] = trans_z;

		gSP.viewport.x = gSP.viewport.vtrans[0] - gSP.viewport.vscale[0];
		gSP.viewport.y = gSP.viewport.vtrans[1] - gSP.viewport.vscale[1];
		gSP.viewport.width = gSP.viewport.vscale[0] * 2;
		gSP.viewport.height	= gSP.viewport.vscale[1] * 2;
		gSP.viewport.nearz = gSP.viewport.vtrans[2] - gSP.viewport.vscale[2];
		gSP.viewport.farz = (gSP.viewport.vtrans[2] + gSP.viewport.vscale[2]);

		gstate.view_scale[0] = scale_x*4.0f;
		gstate.view_scale[1] = scale_y*4.0f;
		gstate.view_trans[0] = trans_x*4.0f;
		gstate.view_trans[1] = trans_y*4.0f;

		gSP.changed |= CHANGED_VIEWPORT;
		return;
	}

	if((_w0 & 0xfff) == 0x730) {
		assert(len == 256);
		memcpy(gstate.fogtable, (RDRAM + addr), len);
	}

	if(flag == 0) {
		memcpy((DMEM + (_w0 & 0xfff)), (RDRAM + addr), len);
	} else {
		memcpy((RDRAM + addr), (DMEM + (_w0 & 0xfff)), len);
	}
}

void ZSortBOSS_MTXCAT(u32 _w0, u32 _w1)
{
	M44 *s = nullptr;
	M44 *t = nullptr;
	M44 *d = nullptr;
	u32 S = (_w1 >> 16) & 0xfff;
	u32 T = _w0 & 0xfff;
	u32 D = _w1 & 0xfff;

	switch(S) {
		// model matrix
		case 0x830:
			s = (M44*)gSP.matrix.modelView[gSP.matrix.modelViewi];
		break;

		// projection matrix
		case 0x870:
			s = (M44*)gSP.matrix.projection;
		break;

		// combined matrix
		case 0x8b0:
			s = (M44*)gSP.matrix.combined;
		break;
	}

	switch(T) {
		// model matrix
		case 0x830:
			t = (M44*)gSP.matrix.modelView[gSP.matrix.modelViewi];
		break;

		// projection matrix
		case 0x870:
			t = (M44*)gSP.matrix.projection;
		break;

		// combined matrix
		case 0x8b0:
			t = (M44*)gSP.matrix.combined;
		break;
	}

	assert(s != nullptr && t != nullptr);
	f32 m[4][4];
	MultMatrix(*s, *t, m);

	switch(D) {
		// model matrix
		case 0x830:
			d = (M44*)gSP.matrix.modelView[gSP.matrix.modelViewi];
		break;

		// projection matrix
		case 0x870:
			d = (M44*)gSP.matrix.projection;
		break;

		// combined matrix
		case 0x8b0:
			d = (M44*)gSP.matrix.combined;
		break;
	}

	assert(d != nullptr);
	memcpy(*d, m, 64);

	LOG(LOG_VERBOSE, "ZSortBOSS_MTXCAT (S: 0x%04x, T: 0x%04x, D: 0x%04x)\n", S, T, D);
}

void ZSortBOSS_MultMPMTX( u32 _w0, u32 _w1 )
{
	assert((_w0 & 0xfff) == 0x8b0); // combined matrix
	int num = 1 + _SHIFTR(_w1, 24, 8);
	int src = (_w1 >> 12) & 0xfff;
	int dst = _w1 & 0xfff;

	assert((src & 3) == 0);
	assert((dst & 3) == 0);

	s16 * saddr = (s16*)(DMEM+src);
	zSortVDest * daddr = (zSortVDest*)(DMEM+dst);
	int idx = 0;
	zSortVDest v;
	memset(&v, 0, sizeof(zSortVDest));

	for(int i = 0; i < num; ++i) {
		s16 sx = saddr[(idx++)^1];
		s16 sy = saddr[(idx++)^1];
		s16 sz = saddr[(idx++)^1];
		f32 x = sx*gSP.matrix.combined[0][0] + sy*gSP.matrix.combined[1][0] + sz*gSP.matrix.combined[2][0] + gSP.matrix.combined[3][0];
		f32 y = sx*gSP.matrix.combined[0][1] + sy*gSP.matrix.combined[1][1] + sz*gSP.matrix.combined[2][1] + gSP.matrix.combined[3][1];
		f32 z = sx*gSP.matrix.combined[0][2] + sy*gSP.matrix.combined[1][2] + sz*gSP.matrix.combined[2][2] + gSP.matrix.combined[3][2];
		f32 w = sx*gSP.matrix.combined[0][3] + sy*gSP.matrix.combined[1][3] + sz*gSP.matrix.combined[2][3] + gSP.matrix.combined[3][3];

		v.xi = (s16)x;
		v.yi = (s16)y;
		v.wi = (s16)w;

		v.invw = Calc_invw((int)(w * gstate.invw_factor));

		f32 invw = (w <= 0.f) ? gstate.invw_factor : (1.f / w);

		f32 x_w = CLAMP((x * invw), -gstate.invw_factor, gstate.invw_factor);
		f32 y_w = CLAMP((y * invw), -gstate.invw_factor, gstate.invw_factor);

		v.sx = (s16)(gstate.view_trans[0] + x_w * gstate.view_scale[0]);
		v.sy = (s16)(gstate.view_trans[1] + y_w * gstate.view_scale[1]);

		int fog = (int)(w * _FIXED2FLOAT(gSP.fog.multiplier, 16) + gSP.fog.offset);
		fog = SATURATES8(fog);
		v.fog = gstate.fogtable[fog+128];

		v.cc = 0;
		if(x >= w) v.cc |= 0x10;
		if(y >= w) v.cc |= 0x20;
		if(z >= w) v.cc |= 0x40;
		if(x <= -w) v.cc |= 0x01;
		if(y <= -w) v.cc |= 0x02;
		if(z <= -w) v.cc |= 0x04;

		daddr[i] = v;
	}

	LOG(LOG_VERBOSE, "ZSortBOSS_MultMPMTX (src: 0x%04x, dest: 0x%04x, num: %d)\n", src, dst, num);
}

static
void ZSortBOSS_DrawObject(u8 * _addr, u32 _type)
{
	u32 textured = 0, vnum = 0, vsize = 0;
	switch(_type) {
	case ZH_NULL:
		assert(0);
		textured = vnum = vsize = 0;
	break;
	case ZH_TXTRI:
		textured = 1;
		vnum = 3;
		vsize = 16;
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

	for(u32 i = 0; i < vnum; ++i) {
		SPVertex & vtx = pVtx[i];
		vtx.x = _FIXED2FLOAT(((s16*)_addr)[0 ^ 1], 2);
		vtx.y = _FIXED2FLOAT(((s16*)_addr)[1 ^ 1], 2);
		vtx.z = 0.0f;
		vtx.r = _FIXED2FLOATCOLOR(_addr[4^3], 8 );
		vtx.g = _FIXED2FLOATCOLOR(_addr[5^3], 8 );
		vtx.b = _FIXED2FLOATCOLOR(_addr[6^3], 8 );
		vtx.a = _FIXED2FLOATCOLOR(_addr[7^3], 8 );
		vtx.flag = 0;
		vtx.HWLight = 0;
		vtx.clip = 0;
		if(textured != 0) {
			if (gDP.otherMode.texturePersp != 0) {
				vtx.s = _FIXED2FLOAT(((s16*)_addr)[4 ^ 1], 5);
				vtx.t = _FIXED2FLOAT(((s16*)_addr)[5 ^ 1], 5);
			} else {
				vtx.s = _FIXED2FLOAT(((s16*)_addr)[4 ^ 1], 6);
				vtx.t = _FIXED2FLOAT(((s16*)_addr)[5 ^ 1], 6);
			}

			int invw = ((int*)_addr)[3];
			int rgba = ((int*)_addr)[1];

			if((invw == rgba) || (invw < 0))
				vtx.w = 1.0f;
			else
				vtx.w = Calc_invw(invw) / gstate.invw_factor;

		} else
			vtx.w = 1.0f;

		_addr += vsize;
	}
	drawer.drawScreenSpaceTriangle(vnum);
}

static
u32 ZSortBOSS_LoadObject(u32 _zHeader)
{
	const u32 type = (_zHeader & 7) << 1;
	u8 * addr = RDRAM + (_zHeader&0xFFFFFFF8);
	u32 w1;
	switch(type) {
		case ZH_NULL:
		case ZH_TXTRI:
		case ZH_TXQUAD:
		{
			w1 = ((u32*)addr)[1];
			if(w1 != gstate.rdpcmds[0]) {
				gstate.rdpcmds[0] = w1;
				ZSort_RDPCMD (0, w1);
			}
			w1 = ((u32*)addr)[2];
			if(w1 != gstate.rdpcmds[1]) {
				ZSort_RDPCMD (0, w1);
				gstate.rdpcmds[1] = w1;
			}
			w1 = ((u32*)addr)[3];
			if(w1 != gstate.rdpcmds[2]) {
				ZSort_RDPCMD (0,  w1);
				gstate.rdpcmds[2] = w1;
			}
			if(type != ZH_NULL) {
				ZSortBOSS_DrawObject(addr + 16, type);
			}
		}
		break;
	}
	return RSP_SegmentToPhysical(((u32*)addr)[0]);
}

void ZSortBOSS_Obj( u32 _w0, u32 _w1 )
{
	// make sure no pending subdl
	assert((*REG.SP_STATUS & 0x80) == 0);

	u32 zHeader = RSP_SegmentToPhysical(_w0);
	while(zHeader)
		zHeader = ZSortBOSS_LoadObject(zHeader);
	zHeader = RSP_SegmentToPhysical(_w1);
	while(zHeader)
		zHeader = ZSortBOSS_LoadObject(zHeader);
}

void ZSortBOSS_TransposeMTX( u32, u32 _w1 )
{
	M44 *mtx = nullptr;
	f32 m[4][4];
	assert((_w1 & 0xfff) == 0x830); // model matrix

	switch(_w1 & 0xfff) {
		// model matrix
		case 0x830:
			mtx = (M44*)gSP.matrix.modelView[gSP.matrix.modelViewi];
		break;

		// projection matrix
		case 0x870:
			mtx = (M44*)gSP.matrix.projection;
		break;

		// combined matrix
		case 0x8b0:
			mtx = (M44*)gSP.matrix.combined;
		break;

		default:
			assert(false);
			return;
	}

	memcpy(m, mtx, 64);

	for(int i = 0; i < 3; i++) {
		for(int j = 0; j < 3; j++) {
			(*mtx)[j][i] = m[i][j];
		}
	}

	LOG(LOG_VERBOSE, "ZSortBOSS_TransposeMTX (MTX: 0x%04x)\n", (_w1 & 0xfff));
}

void ZSortBOSS_Lighting( u32 _w0, u32 _w1 )
{
	u32 num = 1 + (_w1 >> 24);
	u32 nsrs = _w0 & 0xfff;
	u32 csrs = (_w0 >> 12) & 0xfff;
	u32 cdest = (_w1 >> 12) & 0xfff;
	u32 tdest = _w1 & 0xfff;
	assert((tdest & 3) == 0);
	tdest >>= 1;

	u32 r4 = _w0 << 7;
	assert(r4 >= 0);

	u32 r9 = DMEM[0x944];
	assert(r9 == 0);

	GraphicsDrawer & drawer = dwnd().getDrawer();
	drawer.setDMAVerticesSize(num);
	SPVertex * pVtx = drawer.getDMAVerticesData();

	for(u32 i = 0; i < num; i++) {
		SPVertex & vtx = pVtx[i];

		vtx.nx = _FIXED2FLOAT(((s8*)DMEM)[(nsrs++)^3],8);
		vtx.ny = _FIXED2FLOAT(((s8*)DMEM)[(nsrs++)^3],8);
		vtx.nz = _FIXED2FLOAT(((s8*)DMEM)[(nsrs++)^3],8);

		// TODO: implement light vertex if ever needed
		//gSPLightVertex(vtx);

		f32 fLightDir[3] = {vtx.nx, vtx.ny, vtx.nz};
		f32 x, y;
		x = DotProduct(gSP.lookat.xyz[0], fLightDir);
		y = DotProduct(gSP.lookat.xyz[1], fLightDir);
		vtx.s = (x + 0.5f) * 1024.0f;
		vtx.t = (y + 0.5f) * 1024.0f;

		// TODO: is this ever send to RDRAM?
		//DMEM[(cdest++)^3] = (u8)(vtx.r * 255.0f);
		//DMEM[(cdest++)^3] = (u8)(vtx.g * 255.0f);
		//DMEM[(cdest++)^3] = (u8)(vtx.b * 255.0f);
		//DMEM[(cdest++)^3] = (u8)(vtx.a * 255.0f);
		
		((s16*)DMEM)[(tdest++)^1] = (s16)vtx.s;
		((s16*)DMEM)[(tdest++)^1] = (s16)vtx.t;
	}
	
	LOG(LOG_VERBOSE, "ZSortBOSS_Lighting (0x%08x, 0x%08x)\n", _w0, _w1);
}

static
void ZSortBOSS_TransformVectorNormalize(float vec[3], float mtx[4][4])
{
	float vres[3];
	float len;
	float recip = 256.f;

	vres[0] = mtx[0][0] * vec[0] + mtx[1][0] * vec[1] + mtx[2][0] * vec[2];
	vres[1] = mtx[0][1] * vec[0] + mtx[1][1] * vec[1] + mtx[2][1] * vec[2];
	vres[2] = mtx[0][2] * vec[0] + mtx[1][2] * vec[1] + mtx[2][2] * vec[2];

	len = vres[0]*vres[0] + vres[1]*vres[1] + vres[2]*vres[2];

	if(len != 0.0)
		recip = 1.f / sqrtf( len );

	if(recip > 256.f) recip = 256.f;
	vec[0] = vres[0] * recip;
	vec[1] = vres[1] * recip;
	vec[2] = vres[2] * recip;
}

void ZSortBOSS_TransformLights( u32 _w0, u32 _w1 )
{
	assert((_w0 & 0xfff) == 0x830); // model matrix
	assert(_w1 == 0x1630); // no light only lookat
	assert((_w1 & 3) == 0);

	M44 *mtx = nullptr;
	int addr = _w1 & 0xfff;
	gSP.numLights = 1 - (_w1 >> 12);

	/*
	switch(_w0 & 0xfff) {
		// model matrix
		case 0x830:
			mtx = (M44*)gSP.matrix.modelView[gSP.matrix.modelViewi];
		break;

		// projection matrix
		case 0x870:
			mtx = (M44*)gSP.matrix.projection;
		break;

		// combined matrix
		case 0x8b0:
			mtx = (M44*)gSP.matrix.combined;
		break;
	}
	*/

	for(u32 i = 0; i < gSP.numLights; ++i)
	{
		assert(0);

		gSP.lights.rgb[i][R] = _FIXED2FLOATCOLOR(((u8*)DMEM)[(addr+8+0)^3], 8 );
		gSP.lights.rgb[i][G] = _FIXED2FLOATCOLOR(((u8*)DMEM)[(addr+8+1)^3], 8 );
		gSP.lights.rgb[i][B] = _FIXED2FLOATCOLOR(((u8*)DMEM)[(addr+8+2)^3], 8 );

		gSP.lights.xyz[i][X] = _FIXED2FLOAT((((s8*)DMEM)[(addr+16+0)^3]),8);
		gSP.lights.xyz[i][Y] = _FIXED2FLOAT((((s8*)DMEM)[(addr+16+1)^3]),8);
		gSP.lights.xyz[i][Z] = _FIXED2FLOAT((((s8*)DMEM)[(addr+16+2)^3]),8);
		ZSortBOSS_TransformVectorNormalize( gSP.lights.xyz[i], gSP.matrix.modelView[gSP.matrix.modelViewi] );
		addr += 24;
	}
	for(int i = 0; i < 2; i++)
	{
		gSP.lookat.xyz[i][X] = _FIXED2FLOAT((((s8*)DMEM)[(addr+16+0)^3]),8);
		gSP.lookat.xyz[i][Y] = _FIXED2FLOAT((((s8*)DMEM)[(addr+16+1)^3]),8);
		gSP.lookat.xyz[i][Z] = _FIXED2FLOAT((((s8*)DMEM)[(addr+16+2)^3]),8);
		ZSortBOSS_TransformVectorNormalize( gSP.lookat.xyz[i], gSP.matrix.modelView[gSP.matrix.modelViewi] );
		addr += 24;
	}

	LOG(LOG_VERBOSE, "ZSortBOSS_TransformLights (0x%08x, 0x%08x)\n", _w0, _w1);
}

void ZSortBOSS_Audio1( u32 _w0, u32 _w1 )
{
	u32 addr = RSP_SegmentToPhysical(_w1);
	u32 val = ((u32*)DMEM)[(_w0 & 0xfff) >> 2];
	((u32*)DMEM)[0] = val;
	memcpy(RDRAM+addr, DMEM, 0x8);
	LOG(LOG_VERBOSE, "ZSortBOSS_Audio1 (0x%08x, 0x%08x)\n", _w0, _w1);
}

void ZSortBOSS_Audio2( u32 _w0, u32 _w1 )
{
	int len = _w1 >> 24;

	// Written by previous ZSortBOSS_MoveWord
	u32 dst = ((u32*)DMEM)[0x10>>2];

	f32 f1 = (f32)((_w0>>16) & 0xff) + (f32)(_w0 & 0xffff) / 65536.f;
	f32 f2 = (f32)((_w1>>16) & 0xff) + (f32)(_w1 & 0xffff) / 65536.f;

	// Written by previous ZSortBOSS_MoveWord
	u16 v11[2];
	v11[0] = ((u16*)DMEM)[(0x904>>1)^1];
	v11[1] = ((u16*)DMEM)[((0x904+2)>>1)^1];

	for(int i = 0; i < len; i+=4) {

		for(int j = 0; j < 4; j++) {

			f32 intpart, fractpart;
			f32 val = i*f1 + j*f1 + f2;

			fractpart = fabsf(modff(val, &intpart));
			int index = ((int)intpart) << 1;

			s16 v9 = ((s16*)DMEM)[((0x30+index)>>1)^1];
			s16 v10 = ((s16*)DMEM)[((0x32+index)>>1)^1];
			s16 v12 = v10 - v9;
			s16 v13 = ((s16*)DMEM)[(dst>>1)^1];

			for(int k = 0; k < 2; k++) {

				s32 res1 = v12 * (u16)(fractpart * 65536.f);
				s32 res2 = v9 << 16;
				s16 res3 = (res2 + res1) >> 16;

				res1 = v11[k] * res3;
				res2 = v13 << 16;
				res3 = (res2 + res1) >> 16;

				((s16*)DMEM)[(dst>>1)^1] = res3;
				dst+=2;
			}
		}
	}

	LOG(LOG_VERBOSE, "ZSortBOSS_Audio2 (0x%08x, 0x%08x)\n", _w0, _w1);
}

void ZSortBOSS_Audio3( u32 _w0, u32 _w1 )
{
	u32 addr = RSP_SegmentToPhysical(_w0);
	assert((addr & 3) == 0);

	for(int i = 0; i < 8; i++) {
		for(int j = 0; j < 8; j++) {
			gstate.table[i][j] = ((s16*)RDRAM)[((addr+(i<<4)+(j<<1))>>1)^1];
		}
	}

	addr = RSP_SegmentToPhysical(_w1);
	assert((addr & 3) == 0);

	// What is this?
	memcpy(DMEM, (RDRAM + addr), 0x8);
	memcpy((DMEM+8), &addr, sizeof(addr));

	LOG(LOG_VERBOSE, "ZSortBOSS_Audio3 (0x%08x, 0x%08x)\n", _w0, _w1);
}

void ZSortBOSS_Audio4( u32 _w0, u32 _w1 )
{
	u32 addr = RSP_SegmentToPhysical(_w1);
	assert((addr & 3) == 0);

	u32 src = ((_w0 & 0xf000) >> 12) + addr;
	s16 * dst = (s16*)(DMEM+0x30);
	int len = (_w0 & 0xfff);

	// Written by previous ZSortBOSS_MoveWord
	s16 v1 = ((s16*)DMEM)[(0>>1)^1];
	s16 v2 = ((s16*)DMEM)[(2>>1)^1];

	for(int l1 = len; l1 != 0; l1-=9) {

		u32 r9 = ((u8*)RDRAM)[(src++)^3];
		int index = (r9 & 0xf) << 1;

		if(index > 6) {
			LOG(LOG_VERBOSE, "ZSortBOSS_Audio4: Index out of bound\n");
			break;
		}

		assert(index <= 6);
		assert((index&1) == 0);

		s16 c1 = 1 << ((r9>>4) & 0x1f);
		s16 c2 = 0x20;

		for(int l2 = 0; l2 < 2; l2++) {

			s32 a = ((s8*)RDRAM)[(src++)^3];
			s32 b = ((s8*)RDRAM)[(src++)^3];
			s32 c = ((s8*)RDRAM)[(src++)^3];
			s32 d = ((s8*)RDRAM)[(src++)^3];

			s16 coeff[8];
			coeff[0] = a>>4;
			coeff[1] = (a<<28)>>28;
			coeff[2] = b>>4;
			coeff[3] = (b<<28)>>28;
			coeff[4] = c>>4;
			coeff[5] = (c<<28)>>28;
			coeff[6] = d>>4;
			coeff[7] = (d<<28)>>28;

			int i, j, k;

			for(i = 0; i < 8; i++) {
				s32 res1 = 0;

				for(j = 0, k = i; j < i; j++, k--)
					res1 += gstate.table[index+1][k-1] * coeff[j];

				res1 += coeff[i] * (s16)0x0800;
				res1 *= c1;

				s32 res2 = v1*gstate.table[index][i] + v2*gstate.table[index+1][i];

				dst[i^1] = (res1*c2 + res2*c2) >> 16;
			}
			v1 = dst[6^1];
			v2 = dst[7^1];
			dst += 8;
		}
	}

	LOG(LOG_VERBOSE, "ZSortBOSS_Audio4 (0x%08x, 0x%08x)\n", _w0, _w1);
}

// RDP Commands
void ZSortBOSS_UpdateMask( u32 _w0, u32 _w1 )
{
	gstate.updatemask[0] = _w0 | 0xff000000;
	gstate.updatemask[1] = _w1;
	LOG(LOG_VERBOSE, "ZSortBOSS_UpdateMask (mask0: 0x%08x, mask1: 0x%08x)\n", gstate.updatemask[0], gstate.updatemask[1]);
}

void ZSortBOSS_SetOtherMode_L( u32 _w0, u32 _w1 )
{
	u32 mask = (s32)0x80000000 >> (_w0 & 0x1f);
	mask >>= (_w0 >> 8) & 0x1f;
	gDP.otherMode.l = (gDP.otherMode.l & ~mask) | _w1;

	const u32 w0 = gDP.otherMode.h;
	const u32 w1 = gDP.otherMode.l;

	gDPSetOtherMode( _SHIFTR( w0, 0, 24 ),	// mode0
					 w1 );					// mode1

	LOG(LOG_VERBOSE, "ZSortBOSS_SetOtherMode_L (mode0: 0x%08x, mode1: 0x%08x)\n", gDP.otherMode.h, gDP.otherMode.l);
}

void ZSortBOSS_SetOtherMode_H( u32 _w0, u32 _w1 )
{
	u32 mask = (s32)0x80000000 >> (_w0 & 0x1f);
	mask >>= (_w0 >> 8) & 0x1f;
	gDP.otherMode.h = (gDP.otherMode.h & ~mask) | _w1;

	const u32 w0 = gDP.otherMode.h;
	const u32 w1 = gDP.otherMode.l;

	gDPSetOtherMode( _SHIFTR( w0, 0, 24 ),	// mode0
					 w1 );					// mode1

	LOG(LOG_VERBOSE, "ZSortBOSS_SetOtherMode_H (mode0: 0x%08x, mode1: 0x%08x)\n", gDP.otherMode.h, gDP.otherMode.l);
}

void ZSortBOSS_SetOtherMode( u32 _w0, u32 _w1 )
{
	gDP.otherMode.h = (_w0 & gstate.updatemask[0]) | (gDP.otherMode.h & ~gstate.updatemask[0]);
	gDP.otherMode.l = (_w1 & gstate.updatemask[1]) | (gDP.otherMode.l & ~gstate.updatemask[1]);

	const u32 w0 = gDP.otherMode.h;
	const u32 w1 = gDP.otherMode.l;

	gDPSetOtherMode( _SHIFTR( w0, 0, 24 ),	// mode0
					 w1 );					// mode1

	LOG(LOG_VERBOSE, "ZSortBOSS_SetOtherMode (mode0: 0x%08x, mode1: 0x%08x)\n", gDP.otherMode.h, gDP.otherMode.l);
}

void ZSortBOSS_TriangleCommand( u32, u32 _w1 )
{
	assert(((_w1 >> 8) & 0x3f) == 0x0e);	//Shade, Texture Triangle
	gSP.texture.scales = 1.0f;
	gSP.texture.scalet = 1.0f;
	gSP.texture.level = (_w1 >> 3) & 0x7;
	gSP.texture.on = 1;
	gSP.texture.tile = _w1 & 0x7;

	gSPSetGeometryMode(G_SHADING_SMOOTH | G_SHADE);
	LOG(LOG_VERBOSE, "ZSortBOSS_TriangleCommand (cmd: 0x%02x, level: %d, tile: %d)\n", ((_w1 >> 8) & 0x3f), gSP.texture.level, gSP.texture.tile);
}

void ZSortBOSS_FlushRDPCMDBuffer( u32, u32 )
{
	LOG(LOG_VERBOSE, "ZSortBOSS_FlushRDPCMDBuffer Ignored\n");
}

void ZSortBOSS_Reserved( u32, u32 )
{
	assert(0);
}

#define	G_ZSBOSS_ENDMAINDL			0x02
#define	G_ZSBOSS_MOVEMEM			0x04
#define	G_ZSBOSS_MTXCAT				0x0A
#define	G_ZSBOSS_MULT_MPMTX			0x0C
#define	G_ZSBOSS_MOVEWORD			0x06
#define	G_ZSBOSS_TRANSPOSEMTX		0x08
#define	G_ZSBOSS_RDPCMD				0x0E
#define	G_ZSBOSS_OBJ				0x10
#define	G_ZSBOSS_WAITSIGNAL			0x12
#define	G_ZSBOSS_LIGHTING			0x14
#define	G_ZSBOSS_RESERVED0			0x16
#define	G_ZSBOSS_TRANSFORMLIGHTS	0x18
#define	G_ZSBOSS_ENDSUBDL			0x1A
#define	G_ZSBOSS_AUDIO2				0x1C
#define	G_ZSBOSS_CLEARBUFFER		0x1E
#define	G_ZSBOSS_RESERVED1			0x20
#define	G_ZSBOSS_AUDIO3				0x22
#define	G_ZSBOSS_AUDIO4				0x24
#define	G_ZSBOSS_AUDIO1				0x26
#define	G_ZSBOSS_UPDATEMASK			0xDD
#define	G_ZSBOSS_TRIANGLECOMMAND	0xDE
#define	G_ZSBOSS_FLUSHRDPCMDBUFFER	0xDF
#define	G_ZSBOSS_RDPHALF_1			0xE1
#define	G_ZSBOSS_SETOTHERMODE_H		0xE3
#define	G_ZSBOSS_SETOTHERMODE_L		0xE2
#define	G_ZSBOSS_RDPSETOTHERMODE	0xEF
#define	G_ZSBOSS_RDPHALF_2			0xF1

u32 G_ZENDMAINDL, G_ZENDSUBDL, G_ZUPDATEMASK, G_ZSETOTHERMODE, G_ZFLUSHRDPCMDBUFFER, G_ZMOVEWORD, G_ZCLEARBUFFER, G_ZTRIANGLECOMMAND, G_ZTRANSPOSEMTX, G_ZTRANSFORMLIGHTS, G_ZAUDIO1, G_ZAUDIO2, G_ZAUDIO3, G_ZAUDIO4;

void ZSortBOSS_Init()
{
	gSPSetupFunctions();
	// Set GeometryMode flags
	GBI_InitFlags( F3D );

	GBI.PCStackSize = 10;

	memset(&gstate, 0, sizeof(gstate));
	gstate.invw_factor = 10.0f;

	//			GBI Command				Command Value				Command Function
	GBI_SetGBI( G_SPNOOP,				F3D_SPNOOP,					F3D_SPNoOp );
	GBI_SetGBI( G_ZENDMAINDL,			G_ZSBOSS_ENDMAINDL,			ZSortBOSS_EndMainDL );
	GBI_SetGBI( G_MOVEMEM,				G_ZSBOSS_MOVEMEM,			ZSortBOSS_MoveMem );
	GBI_SetGBI( G_ZMOVEWORD,			G_ZSBOSS_MOVEWORD,			ZSortBOSS_MoveWord );
	GBI_SetGBI( G_ZTRANSPOSEMTX,		G_ZSBOSS_TRANSPOSEMTX,		ZSortBOSS_TransposeMTX );
	GBI_SetGBI( G_ZMTXCAT,				G_ZSBOSS_MTXCAT,			ZSortBOSS_MTXCAT );
	GBI_SetGBI( G_ZMULT_MPMTX,			G_ZSBOSS_MULT_MPMTX,		ZSortBOSS_MultMPMTX );
	GBI_SetGBI( G_ZRDPCMD,				G_ZSBOSS_RDPCMD,			ZSort_RDPCMD );
	GBI_SetGBI( G_ZOBJ,					G_ZSBOSS_OBJ,				ZSortBOSS_Obj );
	GBI_SetGBI( G_ZWAITSIGNAL,			G_ZSBOSS_WAITSIGNAL,		ZSortBOSS_WaitSignal );
	GBI_SetGBI( G_ZLIGHTING,			G_ZSBOSS_LIGHTING,			ZSortBOSS_Lighting );
	GBI_SetGBI( G_RESERVED0,			G_ZSBOSS_RESERVED0,			ZSortBOSS_Reserved );
	GBI_SetGBI( G_ZTRANSFORMLIGHTS,		G_ZSBOSS_TRANSFORMLIGHTS,	ZSortBOSS_TransformLights );
	GBI_SetGBI( G_ZENDSUBDL,			G_ZSBOSS_ENDSUBDL,			ZSortBOSS_EndSubDL );
	GBI_SetGBI( G_ZAUDIO2,				G_ZSBOSS_AUDIO2,			ZSortBOSS_Audio2 );
	GBI_SetGBI( G_ZCLEARBUFFER,			G_ZSBOSS_CLEARBUFFER,		ZSortBOSS_ClearBuffer );
	GBI_SetGBI( G_RESERVED1,			G_ZSBOSS_RESERVED1,			ZSortBOSS_Reserved );
	GBI_SetGBI( G_ZAUDIO3,				G_ZSBOSS_AUDIO3,			ZSortBOSS_Audio3 );
	GBI_SetGBI( G_ZAUDIO4,				G_ZSBOSS_AUDIO4,			ZSortBOSS_Audio4 );
	GBI_SetGBI( G_ZAUDIO1,				G_ZSBOSS_AUDIO1,			ZSortBOSS_Audio1 );

	// RDP Commands
	GBI_SetGBI( G_ZUPDATEMASK,			G_ZSBOSS_UPDATEMASK,		ZSortBOSS_UpdateMask );
	GBI_SetGBI( G_ZTRIANGLECOMMAND,		G_ZSBOSS_TRIANGLECOMMAND,	ZSortBOSS_TriangleCommand );
	GBI_SetGBI( G_ZFLUSHRDPCMDBUFFER,	G_ZSBOSS_FLUSHRDPCMDBUFFER,	ZSortBOSS_FlushRDPCMDBuffer );
	GBI_SetGBI( G_RDPHALF_1,			G_ZSBOSS_RDPHALF_1,			F3D_RDPHalf_1 );
	GBI_SetGBI( G_SETOTHERMODE_L,		G_ZSBOSS_SETOTHERMODE_L,	ZSortBOSS_SetOtherMode_L );
	GBI_SetGBI( G_SETOTHERMODE_H,		G_ZSBOSS_SETOTHERMODE_H,	ZSortBOSS_SetOtherMode_H );
	GBI_SetGBI( G_ZSETOTHERMODE,		G_ZSBOSS_RDPSETOTHERMODE,	ZSortBOSS_SetOtherMode );
	GBI_SetGBI( G_RDPHALF_2,			G_ZSBOSS_RDPHALF_2,			F3D_RDPHalf_2 );
}
