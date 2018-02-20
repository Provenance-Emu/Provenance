#include <stdio.h>
#include <math.h>
#include <algorithm>
#include <assert.h>
#include "N64.h"
#include "GLideN64.h"
#include "DebugDump.h"
#include "Types.h"
#include "RSP.h"
#include "GBI.h"
#include "gSP.h"
#include "gDP.h"
#include "3DMath.h"
#include "CRC.h"
#include <string.h>
#include "convert.h"
#include "uCodes/S2DEX.h"
#include "VI.h"
#include "FrameBuffer.h"
#include "DepthBuffer.h"
#include "Config.h"
#include "Log.h"

#include <Graphics/Context.h>
#include <Graphics/Parameters.h>
#include "DisplayWindow.h"

using namespace std;
using namespace graphics;

#define INDEXMAP_SIZE 80U

#define SP_STATUS_HALT 0x0001
#define SP_STATUS_BROKE 0x0002
#define SP_STATUS_TASKDONE 0x0200

#ifdef __VEC4_OPT
#define VEC_OPT 4U
#else
#define VEC_OPT 1U
#endif

static bool g_ConkerUcode;

void gSPFlushTriangles()
{
	if ((gSP.geometryMode & G_SHADING_SMOOTH) == 0) {
		dwnd().getDrawer().drawTriangles();
		return;
	}

	if (
		(RSP.nextCmd != G_TRI1) &&
		(RSP.nextCmd != G_TRI2) &&
		(RSP.nextCmd != G_TRIX) &&
		(RSP.nextCmd != G_QUAD)
		) {
		dwnd().getDrawer().drawTriangles();
		DebugMsg(DEBUG_NORMAL, "Triangles flushed;\n");
	}
}

static
void _gSPCombineMatrices()
{
	MultMatrix(gSP.matrix.projection, gSP.matrix.modelView[gSP.matrix.modelViewi], gSP.matrix.combined);
	gSP.changed &= ~CHANGED_MATRIX;
}

void gSPCombineMatrices(u32 _mode)
{
	if (_mode == 1)
		_gSPCombineMatrices();
	else
		DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "// Unknown gSPCombineMatrices mode: %u\n", _mode);
	DebugMsg(DEBUG_NORMAL, "gSPCombineMatrices();\n");
}

void gSPTriangle(s32 v0, s32 v1, s32 v2)
{
	GraphicsDrawer & drawer = dwnd().getDrawer();
	if ((v0 < INDEXMAP_SIZE) && (v1 < INDEXMAP_SIZE) && (v2 < INDEXMAP_SIZE)) {
		if (drawer.isClipped(v0, v1, v2)) {
			DebugMsg(DEBUG_NORMAL, "Triangle clipped (%i, %i, %i)\n", v0, v1, v2);
			return;
		}
		drawer.addTriangle(v0, v1, v2);
		DebugMsg(DEBUG_NORMAL, "Triangle #%i added (%i, %i, %i)\n", gSP.tri_num++, v0, v1, v2);
	}
}

void gSP1Triangle( const s32 v0, const s32 v1, const s32 v2)
{
	DebugMsg(DEBUG_NORMAL, "gSP1Triangle (%i, %i, %i)\n", v0, v1, v2);

	gSPTriangle( v0, v1, v2);
	gSPFlushTriangles();
}

void gSP2Triangles(const s32 v00, const s32 v01, const s32 v02, const s32 flag0,
				   const s32 v10, const s32 v11, const s32 v12, const s32 flag1 )
{
	DebugMsg(DEBUG_NORMAL, "gSP2Triangle (%i, %i, %i)-(%i, %i, %i)\n", v00, v01, v02, v10, v11, v12);

	gSPTriangle( v00, v01, v02);
	gSPTriangle( v10, v11, v12);
	gSPFlushTriangles();
}

void gSP4Triangles(const s32 v00, const s32 v01, const s32 v02,
				   const s32 v10, const s32 v11, const s32 v12,
				   const s32 v20, const s32 v21, const s32 v22,
				   const s32 v30, const s32 v31, const s32 v32 )
{
	DebugMsg(DEBUG_NORMAL, "gSP4Triangle (%i, %i, %i)-(%i, %i, %i)-(%i, %i, %i)-(%i, %i, %i)\n",
			 v00, v01, v02, v10, v11, v12, v20, v21, v22, v30, v31, v32);

	gSPTriangle(v00, v01, v02);
	gSPTriangle(v10, v11, v12);
	gSPTriangle(v20, v21, v22);
	gSPTriangle(v30, v31, v32);
	gSPFlushTriangles();
}

gSPInfo gSP;

static
f32 identityMatrix[4][4] =
{
	{ 1.0f, 0.0f, 0.0f, 0.0f },
	{ 0.0f, 1.0f, 0.0f, 0.0f },
	{ 0.0f, 0.0f, 1.0f, 0.0f },
	{ 0.0f, 0.0f, 0.0f, 1.0f }
};

void gSPLoadUcodeEx( u32 uc_start, u32 uc_dstart, u16 uc_dsize )
{
	gSP.matrix.modelViewi = 0;
	gSP.changed |= CHANGED_MATRIX | CHANGED_LIGHT | CHANGED_LOOKAT;
	gSP.status[0] = gSP.status[1] = gSP.status[2] = gSP.status[3] = 0;

	if ((((uc_start & 0x1FFFFFFF) + 4096) > RDRAMSize) || (((uc_dstart & 0x1FFFFFFF) + uc_dsize) > RDRAMSize)) {
		DebugMsg(DEBUG_NORMAL|DEBUG_ERROR, "gSPLoadUcodeEx out of RDRAM\n");
		return;
	}

	GBI.loadMicrocode(uc_start, uc_dstart, uc_dsize);
	RSP.uc_start = uc_start;
	RSP.uc_dstart = uc_dstart;

	DebugMsg(DEBUG_NORMAL, "gSPLoadUcodeEx type: %d\n", GBI.getMicrocodeType());
}

void gSPNoOp()
{
	gSPFlushTriangles();
	DebugMsg(DEBUG_NORMAL | DEBUG_IGNORED, "gSPNoOp();\n");
}

void gSPMatrix( u32 matrix, u8 param )
{

	f32 mtx[4][4];
	u32 address = RSP_SegmentToPhysical( matrix );

	if (address + 64 > RDRAMSize) {
		DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "// Attempting to load matrix from invalid address\n");
		DebugMsg(DEBUG_NORMAL, "gSPMatrix( 0x%08X, %s | %s | %s );\n",
			matrix,
			(param & G_MTX_PROJECTION) ? "G_MTX_PROJECTION" : "G_MTX_MODELVIEW",
			(param & G_MTX_LOAD) ? "G_MTX_LOAD" : "G_MTX_MUL",
			(param & G_MTX_PUSH) ? "G_MTX_PUSH" : "G_MTX_NOPUSH" );
		return;
	}

	RSP_LoadMatrix( mtx, address );

	if (param & G_MTX_PROJECTION) {
		if (param & G_MTX_LOAD)
			CopyMatrix( gSP.matrix.projection, mtx );
		else
			MultMatrix2( gSP.matrix.projection, mtx );
	} else {
		if ((param & G_MTX_PUSH)) {
			if (gSP.matrix.modelViewi < (gSP.matrix.stackSize)) {
				CopyMatrix(gSP.matrix.modelView[gSP.matrix.modelViewi + 1], gSP.matrix.modelView[gSP.matrix.modelViewi]);
				gSP.matrix.modelViewi++;
			} else
				DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "// Modelview stack overflow\n");
		}

		if (param & G_MTX_LOAD)
			CopyMatrix( gSP.matrix.modelView[gSP.matrix.modelViewi], mtx );
		else
			MultMatrix2( gSP.matrix.modelView[gSP.matrix.modelViewi], mtx );
		gSP.changed |= CHANGED_LIGHT | CHANGED_LOOKAT;
	}

	gSP.changed |= CHANGED_MATRIX;

	DebugMsg(DEBUG_NORMAL, "gSPMatrix( 0x%08X, %s | %s | %s );\n",
		matrix,
		(param & G_MTX_PROJECTION) ? "G_MTX_PROJECTION" : "G_MTX_MODELVIEW",
		(param & G_MTX_LOAD) ? "G_MTX_LOAD" : "G_MTX_MUL",
		(param & G_MTX_PUSH) ? "G_MTX_PUSH" : "G_MTX_NOPUSH");
	DebugMsg(DEBUG_DETAIL, "// %12.6f %12.6f %12.6f %12.6f\n",
		mtx[0][0], mtx[0][1], mtx[0][2], mtx[0][3] );
	DebugMsg( DEBUG_DETAIL, "// %12.6f %12.6f %12.6f %12.6f\n",
		mtx[1][0], mtx[1][1], mtx[1][2], mtx[1][3] );
	DebugMsg( DEBUG_DETAIL, "// %12.6f %12.6f %12.6f %12.6f\n",
		mtx[2][0], mtx[2][1], mtx[2][2], mtx[2][3] );
	DebugMsg( DEBUG_DETAIL, "// %12.6f %12.6f %12.6f %12.6f\n",
		mtx[3][0], mtx[3][1], mtx[3][2], mtx[3][3] );
}

void gSPDMAMatrix( u32 matrix, u8 index, u8 multiply )
{
	f32 mtx[4][4];
	u32 address = gSP.DMAOffsets.mtx + RSP_SegmentToPhysical( matrix );

	if (address + 64 > RDRAMSize) {
		DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "// Attempting to load matrix from invalid address\n");
		DebugMsg(DEBUG_NORMAL, "gSPDMAMatrix( 0x%08X, %i, %s );\n",
			matrix, index, multiply ? "TRUE" : "FALSE");
		return;
	}

	RSP_LoadMatrix(mtx, address);

	gSP.matrix.modelViewi = index;

	if (multiply)
		MultMatrix(gSP.matrix.modelView[0], mtx, gSP.matrix.modelView[gSP.matrix.modelViewi]);
	else
		CopyMatrix( gSP.matrix.modelView[gSP.matrix.modelViewi], mtx );

	CopyMatrix( gSP.matrix.projection, identityMatrix );


	gSP.changed |= CHANGED_MATRIX | CHANGED_LIGHT | CHANGED_LOOKAT;

	DebugMsg(DEBUG_NORMAL, "gSPDMAMatrix( 0x%08X, %i, %s );\n",
		matrix, index, multiply ? "TRUE" : "FALSE");
	DebugMsg(DEBUG_DETAIL, "// %12.6f %12.6f %12.6f %12.6f\n",
		mtx[0][0], mtx[0][1], mtx[0][2], mtx[0][3] );
	DebugMsg( DEBUG_DETAIL, "// %12.6f %12.6f %12.6f %12.6f\n",
		mtx[1][0], mtx[1][1], mtx[1][2], mtx[1][3] );
	DebugMsg( DEBUG_DETAIL, "// %12.6f %12.6f %12.6f %12.6f\n",
		mtx[2][0], mtx[2][1], mtx[2][2], mtx[2][3] );
	DebugMsg( DEBUG_DETAIL, "// %12.6f %12.6f %12.6f %12.6f\n",
		mtx[3][0], mtx[3][1], mtx[3][2], mtx[3][3] );
}

void gSPViewport( u32 v )
{
	u32 address = RSP_SegmentToPhysical( v );

	if ((address + 16) > RDRAMSize) {
		DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "// Attempting to load viewport from invalid address\n");
		DebugMsg(DEBUG_NORMAL, "gSPViewport( 0x%08X );\n", v);
		return;
	}

	gSP.viewport.vscale[0] = _FIXED2FLOAT( *(s16*)&RDRAM[address +  2], 2 );
	gSP.viewport.vscale[1] = _FIXED2FLOAT( *(s16*)&RDRAM[address     ], 2 );
	gSP.viewport.vscale[2] = _FIXED2FLOAT( *(s16*)&RDRAM[address +  6], 10 );// * 0.00097847357f;
	gSP.viewport.vscale[3] = *(s16*)&RDRAM[address +  4];
	gSP.viewport.vtrans[0] = _FIXED2FLOAT( *(s16*)&RDRAM[address + 10], 2 );
	gSP.viewport.vtrans[1] = _FIXED2FLOAT( *(s16*)&RDRAM[address +  8], 2 );
	gSP.viewport.vtrans[2] = _FIXED2FLOAT( *(s16*)&RDRAM[address + 14], 10 );// * 0.00097847357f;
	gSP.viewport.vtrans[3] = *(s16*)&RDRAM[address + 12];

	if (gSP.viewport.vscale[1] < 0.0f && !GBI.isNegativeY())
		gSP.viewport.vscale[1] = -gSP.viewport.vscale[1];

	gSP.viewport.x		= gSP.viewport.vtrans[0] - gSP.viewport.vscale[0];
	gSP.viewport.y		= gSP.viewport.vtrans[1] - gSP.viewport.vscale[1];
	gSP.viewport.width = fabs(gSP.viewport.vscale[0]) * 2;
	gSP.viewport.height	= fabs(gSP.viewport.vscale[1] * 2);
	gSP.viewport.nearz	= gSP.viewport.vtrans[2] - gSP.viewport.vscale[2];
	gSP.viewport.farz	= (gSP.viewport.vtrans[2] + gSP.viewport.vscale[2]) ;

	gSP.changed |= CHANGED_VIEWPORT;

	DebugMsg(DEBUG_NORMAL, "gSPViewport scale(%02f, %02f, %02f), trans(%02f, %02f, %02f)\n",
		gSP.viewport.vscale[0], gSP.viewport.vscale[1], gSP.viewport.vscale[2],
		gSP.viewport.vtrans[0], gSP.viewport.vtrans[1], gSP.viewport.vtrans[2]);
}

void gSPForceMatrix( u32 mptr )
{
	u32 address = RSP_SegmentToPhysical( mptr );

	if (address + 64 > RDRAMSize) {
		DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "// Attempting to load from invalid address");
		DebugMsg(DEBUG_NORMAL, "gSPForceMatrix( 0x%08X );\n", mptr);
		return;
	}

	RSP_LoadMatrix(gSP.matrix.combined, address);

	gSP.changed &= ~CHANGED_MATRIX;

	DebugMsg(DEBUG_NORMAL, "gSPForceMatrix( 0x%08X );\n", mptr);
}

void gSPLight( u32 l, s32 n )
{
	--n;
	u32 addrByte = RSP_SegmentToPhysical( l );

	if ((addrByte + sizeof( Light )) > RDRAMSize) {
		DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "// Attempting to load light from invalid address\n");
		DebugMsg(DEBUG_NORMAL, "gSPLight( 0x%08X, LIGHT_%i );\n", l, n );
		return;
	}

	Light *light = (Light*)&RDRAM[addrByte];

	if (n < 8) {
		gSP.lights.rgb[n][R] = light->r * 0.0039215689f;
		gSP.lights.rgb[n][G] = light->g * 0.0039215689f;
		gSP.lights.rgb[n][B] = light->b * 0.0039215689f;

		gSP.lights.xyz[n][X] = light->x;
		gSP.lights.xyz[n][Y] = light->y;
		gSP.lights.xyz[n][Z] = light->z;

		Normalize( gSP.lights.xyz[n] );
		u32 addrShort = addrByte >> 1;
		gSP.lights.pos_xyzw[n][X] = (float)(((short*)RDRAM)[(addrShort+4)^1]);
		gSP.lights.pos_xyzw[n][Y] = (float)(((short*)RDRAM)[(addrShort+5)^1]);
		gSP.lights.pos_xyzw[n][Z] = (float)(((short*)RDRAM)[(addrShort+6)^1]);
		gSP.lights.ca[n] = (float)(RDRAM[(addrByte +  3) ^ 3]);
		gSP.lights.la[n] = (float)(RDRAM[(addrByte +  7) ^ 3]);
		gSP.lights.qa[n] = (float)(RDRAM[(addrByte + 14) ^ 3]);
	}

	gSP.changed |= CHANGED_LIGHT;

	DebugMsg( DEBUG_DETAIL, "// x = %2.6f    y = %2.6f    z = %2.6f\n",
		_FIXED2FLOAT( light->x, 7 ), _FIXED2FLOAT( light->y, 7 ), _FIXED2FLOAT( light->z, 7 ) );
	DebugMsg( DEBUG_DETAIL, "// r = %3i    g = %3i   b = %3i\n",
		light->r, light->g, light->b );
	DebugMsg(DEBUG_NORMAL, "gSPLight( 0x%08X, LIGHT_%i );\n",
		l, n );
}

void gSPLightCBFD( u32 l, s32 n )
{
	u32 addrByte = RSP_SegmentToPhysical( l );

	if ((addrByte + sizeof( Light )) > RDRAMSize) {
		DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "// Attempting to load light from invalid address\n");
		DebugMsg(DEBUG_NORMAL, "gSPLight( 0x%08X, LIGHT_%i );\n", l, n );
		return;
	}

	Light *light = (Light*)&RDRAM[addrByte];

	if (n < 12) {
		gSP.lights.rgb[n][R] = _FIXED2FLOATCOLOR(light->r, 8);
		gSP.lights.rgb[n][G] = _FIXED2FLOATCOLOR(light->g, 8);
		gSP.lights.rgb[n][B] = _FIXED2FLOATCOLOR(light->b, 8);

		gSP.lights.xyz[n][X] = light->x;
		gSP.lights.xyz[n][Y] = light->y;
		gSP.lights.xyz[n][Z] = light->z;

		Normalize( gSP.lights.xyz[n] );
		u32 addrShort = addrByte >> 1;
		gSP.lights.pos_xyzw[n][X] = (float)(((short*)RDRAM)[(addrShort+16)^1]);
		gSP.lights.pos_xyzw[n][Y] = (float)(((short*)RDRAM)[(addrShort+17)^1]);
		gSP.lights.pos_xyzw[n][Z] = (float)(((short*)RDRAM)[(addrShort+18)^1]);
		gSP.lights.pos_xyzw[n][W] = (float)(((short*)RDRAM)[(addrShort+19)^1]);
		gSP.lights.ca[n] = (float)(RDRAM[(addrByte + 12) ^ 3]) / 16.0f;
	}

	gSP.changed |= CHANGED_LIGHT;

	DebugMsg(DEBUG_NORMAL, "gSPLight( 0x%08X, LIGHT_%i );\n", l, n);
	DebugMsg(DEBUG_DETAIL, "// x = %2.6f    y = %2.6f    z = %2.6f\n",
		_FIXED2FLOAT( light->x, 7 ), _FIXED2FLOAT( light->y, 7 ), _FIXED2FLOAT( light->z, 7 ) );
	DebugMsg( DEBUG_DETAIL, "// r = %3i    g = %3i   b = %3i\n",
		light->r, light->g, light->b );
}

void gSPLightAcclaim(u32 l, s32 n)
{
	u32 addrByte = RSP_SegmentToPhysical(l);

	if (n < 10) {
		const u32 addrShort = addrByte >> 1;
		gSP.lights.pos_xyzw[n][X] = (f32)(((s16*)RDRAM)[(addrShort + 0) ^ 1]);
		gSP.lights.pos_xyzw[n][Y] = (f32)(((s16*)RDRAM)[(addrShort + 1) ^ 1]);
		gSP.lights.pos_xyzw[n][Z] = (f32)(((s16*)RDRAM)[(addrShort + 2) ^ 1]);
		gSP.lights.ca[n] = (f32)(((s16*)RDRAM)[(addrShort + 5) ^ 1]);
		gSP.lights.la[n] = _FIXED2FLOAT((((u16*)RDRAM)[(addrShort + 6) ^ 1]), 16);
		gSP.lights.qa[n] = (f32)(((u16*)RDRAM)[(addrShort + 7) ^ 1]);
		gSP.lights.rgb[n][R] = _FIXED2FLOATCOLOR((RDRAM[(addrByte + 6) ^ 3]), 8);
		gSP.lights.rgb[n][G] = _FIXED2FLOATCOLOR((RDRAM[(addrByte + 7) ^ 3]), 8);
		gSP.lights.rgb[n][B] = _FIXED2FLOATCOLOR((RDRAM[(addrByte + 8) ^ 3]), 8);
	}

	gSP.changed |= CHANGED_LIGHT;

	DebugMsg(DEBUG_NORMAL, "gSPLightAcclaim( 0x%08X, LIGHT_%i ca=%f la=%f);\n", l, n, gSP.lights.ca[n], gSP.lights.la[n]);
}

void gSPLookAt( u32 _l, u32 _n )
{
	u32 address = RSP_SegmentToPhysical(_l);

	if ((address + sizeof(Light)) > RDRAMSize) {
		DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "// Attempting to load light from invalid address\n");
		DebugMsg(DEBUG_NORMAL, "gSPLookAt( 0x%08X, LOOKAT_%i );\n", _l, _n);
		return;
	}
	assert(_n < 2);

	Light *light = (Light*)&RDRAM[address];

	gSP.lookat.xyz[_n][X] = light->x;
	gSP.lookat.xyz[_n][Y] = light->y;
	gSP.lookat.xyz[_n][Z] = light->z;

	gSP.lookatEnable = (_n == 0) || (_n == 1 && (light->x != 0 || light->y != 0));

	Normalize(gSP.lookat.xyz[_n]);
	gSP.changed |= CHANGED_LOOKAT;
	DebugMsg(DEBUG_NORMAL, "gSPLookAt( 0x%08X, LOOKAT_%i );\n", _l, _n);
}

static
void gSPUpdateLightVectors()
{
	InverseTransformVectorNormalizeN(&gSP.lights.xyz[0], &gSP.lights.i_xyz[0], 
			gSP.matrix.modelView[gSP.matrix.modelViewi], gSP.numLights);
	gSP.changed ^= CHANGED_LIGHT;
	gSP.changed |= CHANGED_HW_LIGHT;
}

static
void gSPUpdateLookatVectors()
{
	if (gSP.lookatEnable) {
		InverseTransformVectorNormalizeN(&gSP.lookat.xyz[0], &gSP.lookat.i_xyz[0],
				gSP.matrix.modelView[gSP.matrix.modelViewi], 2);
	}
	gSP.changed ^= CHANGED_LOOKAT;
}

/*---------------------------------Vertex Load------------------------------------*/

static
void gSPTransformVector_default(float vtx[4], float mtx[4][4])
{
	const float x = vtx[0];
	const float y = vtx[1];
	const float z = vtx[2];

	vtx[0] = x * mtx[0][0] + y * mtx[1][0] + z * mtx[2][0] + mtx[3][0];
	vtx[1] = x * mtx[0][1] + y * mtx[1][1] + z * mtx[2][1] + mtx[3][1];
	vtx[2] = x * mtx[0][2] + y * mtx[1][2] + z * mtx[2][2] + mtx[3][2];
	vtx[3] = x * mtx[0][3] + y * mtx[1][3] + z * mtx[2][3] + mtx[3][3];
}

static
void gSPInverseTransformVector_default(float vec[3], float mtx[4][4])
{
	const float x = vec[0];
	const float y = vec[1];
	const float z = vec[2];

	vec[0] = mtx[0][0] * x + mtx[0][1] * y + mtx[0][2] * z;
	vec[1] = mtx[1][0] * x + mtx[1][1] * y + mtx[1][2] * z;
	vec[2] = mtx[2][0] * x + mtx[2][1] * y + mtx[2][2] * z;
}

template <u32 VNUM>
void gSPLightVertexStandard(u32 v, SPVertex * spVtx)
{
#ifndef __NEON_OPT
	if (!isHWLightingAllowed()) {
		for(int j = 0; j < VNUM; ++j) {
			SPVertex & vtx = spVtx[v+j];
			vtx.r = gSP.lights.rgb[gSP.numLights][R];
			vtx.g = gSP.lights.rgb[gSP.numLights][G];
			vtx.b = gSP.lights.rgb[gSP.numLights][B];
			vtx.HWLight = 0;

			for (u32 i = 0; i < gSP.numLights; ++i) {
				const f32 intensity = DotProduct( &vtx.nx, gSP.lights.i_xyz[i] );
				if (intensity > 0.0f) {
					vtx.r += gSP.lights.rgb[i][R] * intensity;
					vtx.g += gSP.lights.rgb[i][G] * intensity;
					vtx.b += gSP.lights.rgb[i][B] * intensity;
				}
			}
			vtx.r = min(1.0f, vtx.r);
			vtx.g = min(1.0f, vtx.g);
			vtx.b = min(1.0f, vtx.b);
		}
	} else {
		for(int j = 0; j < VNUM; ++j) {
			SPVertex & vtx = spVtx[v+j];
			TransformVectorNormalize(&vtx.r, gSP.matrix.modelView[gSP.matrix.modelViewi]);
			vtx.HWLight = gSP.numLights;
		}
	}
#else
	void gSPLightVertex_NEON(u32 vnum, u32 v, SPVertex * spVtx);
	gSPLightVertex_NEON(VNUM, v, spVtx);
#endif
}

template <u32 VNUM>
void gSPLightVertexCBFD(u32 v, SPVertex * spVtx)
{
	for (int j = 0; j < VNUM; ++j) {
		SPVertex & vtx = spVtx[v + j];
		f32 r = gSP.lights.rgb[gSP.numLights][R];
		f32 g = gSP.lights.rgb[gSP.numLights][G];
		f32 b = gSP.lights.rgb[gSP.numLights][B];

		for (u32 l = 0; l < gSP.numLights; ++l) {
			const f32 vx = (vtx.x + gSP.vertexCoordMod[8])*gSP.vertexCoordMod[12] - gSP.lights.pos_xyzw[l][X];
			const f32 vy = (vtx.y + gSP.vertexCoordMod[9])*gSP.vertexCoordMod[13] - gSP.lights.pos_xyzw[l][Y];
			const f32 vz = (vtx.z + gSP.vertexCoordMod[10])*gSP.vertexCoordMod[14] - gSP.lights.pos_xyzw[l][Z];
			const f32 vw = (vtx.w + gSP.vertexCoordMod[11])*gSP.vertexCoordMod[15] - gSP.lights.pos_xyzw[l][W];
			const f32 len = (vx*vx + vy*vy + vz*vz + vw*vw) / 65536.0f;
			f32 intensity = gSP.lights.ca[l] / len;
			if (intensity > 1.0f) intensity = 1.0f;
			r += gSP.lights.rgb[l][R] * intensity;
			g += gSP.lights.rgb[l][G] * intensity;
			b += gSP.lights.rgb[l][B] * intensity;
		}

		r = min(1.0f, r);
		g = min(1.0f, g);
		b = min(1.0f, b);

		vtx.r *= r;
		vtx.g *= g;
		vtx.b *= b;
		vtx.HWLight = 0;
	}
}

template <u32 VNUM>
void gSPLightVertex(u32 _v, SPVertex * _spVtx)
{
	if (g_ConkerUcode)
		gSPLightVertexCBFD<VNUM>(_v, _spVtx);
	else
		gSPLightVertexStandard<VNUM>(_v, _spVtx);
}

void gSPLightVertex(SPVertex & _vtx)
{
	gSPLightVertex<1>(0, &_vtx);
}

template <u32 VNUM>
void gSPPointLightVertexZeldaMM(u32 v, float _vecPos[VNUM][4], SPVertex * spVtx)
{
	f32 intensity = 0.0f;
	for (int j = 0; j < VNUM; ++j) {
		SPVertex & vtx = spVtx[v + j];
		vtx.HWLight = 0;
		vtx.r = gSP.lights.rgb[gSP.numLights][R];
		vtx.g = gSP.lights.rgb[gSP.numLights][G];
		vtx.b = gSP.lights.rgb[gSP.numLights][B];
		gSPTransformVector(_vecPos[j], gSP.matrix.modelView[gSP.matrix.modelViewi]);

		for (u32 l = 0; l < gSP.numLights; ++l) {
			if (gSP.lights.ca[l] != 0.0f) {
				// Point lighting
				f32 lvec[3] = { gSP.lights.pos_xyzw[l][X], gSP.lights.pos_xyzw[l][Y], gSP.lights.pos_xyzw[l][Z] };
				lvec[0] -= _vecPos[j][0];
				lvec[1] -= _vecPos[j][1];
				lvec[2] -= _vecPos[j][2];

				const f32 K = lvec[0] * lvec[0] + lvec[1] * lvec[1] + lvec[2] * lvec[2] * 2.0f;
				const f32 KS = sqrtf(K);

				gSPInverseTransformVector(lvec, gSP.matrix.modelView[gSP.matrix.modelViewi]);

				for (u32 i = 0; i < 3; ++i) {
					lvec[i] = (4.0f * lvec[i] / KS);
					if (lvec[i] < -1.0f)
						lvec[i] = -1.0f;
					if (lvec[i] > 1.0f)
						lvec[i] = 1.0f;
				}

				f32 V = lvec[0] * vtx.nx + lvec[1] * vtx.ny + lvec[2] * vtx.nz;
				if (V < -1.0f)
					V = -1.0f;
				if (V > 1.0f)
					V = 1.0f;

				const f32 KSF = floorf(KS);
				const f32 D = (KSF * gSP.lights.la[l] * 2.0f + KSF * KSF * gSP.lights.qa[l] / 8.0f) / 65536.0f + 1.0f;
				intensity = V / D;
			} else {
				// Standard lighting
				intensity = DotProduct(&vtx.nx, gSP.lights.i_xyz[l]);
			}
			if (intensity > 0.0f) {
				vtx.r += gSP.lights.rgb[l][R] * intensity;
				vtx.g += gSP.lights.rgb[l][G] * intensity;
				vtx.b += gSP.lights.rgb[l][B] * intensity;
			}
		}
		if (vtx.r > 1.0f) vtx.r = 1.0f;
		if (vtx.g > 1.0f) vtx.g = 1.0f;
		if (vtx.b > 1.0f) vtx.b = 1.0f;
	}
}

template <u32 VNUM>
void gSPPointLightVertexCBFD(u32 v, SPVertex * spVtx)
{
	f32 intensity = 0.0f;
	for (int j = 0; j < VNUM; ++j) {
		SPVertex & vtx = spVtx[v + j];
		f32 r = gSP.lights.rgb[gSP.numLights][R];
		f32 g = gSP.lights.rgb[gSP.numLights][G];
		f32 b = gSP.lights.rgb[gSP.numLights][B];

		for (u32 l = 0; l < gSP.numLights - 1; ++l) {
			intensity = DotProduct(&vtx.nx, gSP.lights.xyz[l]);
			if ((gSP.lights.rgb[l][R] == 0.0f && gSP.lights.rgb[l][G] == 0.0f && gSP.lights.rgb[l][B] == 0.0f) || intensity < 0.0f)
				continue;
			if (gSP.lights.ca[l] > 0.0f) {
				const f32 vx = (vtx.x + gSP.vertexCoordMod[8])*gSP.vertexCoordMod[12] - gSP.lights.pos_xyzw[l][X];
				const f32 vy = (vtx.y + gSP.vertexCoordMod[9])*gSP.vertexCoordMod[13] - gSP.lights.pos_xyzw[l][Y];
				const f32 vz = (vtx.z + gSP.vertexCoordMod[10])*gSP.vertexCoordMod[14] - gSP.lights.pos_xyzw[l][Z];
				const f32 vw = (vtx.w + gSP.vertexCoordMod[11])*gSP.vertexCoordMod[15] - gSP.lights.pos_xyzw[l][W];
				const f32 len = (vx*vx + vy*vy + vz*vz + vw*vw) / 65536.0f;
				float p_i = gSP.lights.ca[l] / len;
				if (p_i > 1.0f) p_i = 1.0f;
				intensity *= p_i;
			}
			r += gSP.lights.rgb[l][R] * intensity;
			g += gSP.lights.rgb[l][G] * intensity;
			b += gSP.lights.rgb[l][B] * intensity;
		}

		intensity = DotProduct(&vtx.nx, gSP.lights.i_xyz[gSP.numLights - 1]);
		if ((gSP.lights.i_xyz[gSP.numLights - 1][R] != 0.0 || gSP.lights.i_xyz[gSP.numLights - 1][G] != 0.0 || gSP.lights.i_xyz[gSP.numLights - 1][B] != 0.0) && intensity > 0) {
			r += gSP.lights.rgb[gSP.numLights - 1][R] * intensity;
			g += gSP.lights.rgb[gSP.numLights - 1][G] * intensity;
			b += gSP.lights.rgb[gSP.numLights - 1][B] * intensity;
		}

		r = min(1.0f, r);
		g = min(1.0f, g);
		b = min(1.0f, b);

		vtx.r *= r;
		vtx.g *= g;
		vtx.b *= b;
		vtx.HWLight = 0;
	}
}

template <u32 VNUM>
void gSPPointLightVertex(u32 _v, float _vecPos[VNUM][4], SPVertex * _spVtx)
{
	if (g_ConkerUcode)
		gSPPointLightVertexCBFD<VNUM>(_v, _spVtx);
	else
		gSPPointLightVertexZeldaMM<VNUM>(_v, _vecPos, _spVtx);
}

template <u32 VNUM>
void gSPPointLightVertexAcclaim(u32 v, SPVertex * spVtx)
{
	for (int j = 0; j < VNUM; ++j) {
		SPVertex & vtx = spVtx[v + j];
		vtx.HWLight = 0;

		for (u32 l = 2; l < 10; ++l) {
			if (gSP.lights.ca[l] < 0)
				continue;

			const f32 dX = fabsf(gSP.lights.pos_xyzw[l][X] - vtx.x);
			const f32 dY = fabsf(gSP.lights.pos_xyzw[l][Y] - vtx.y);
			const f32 dZ = fabsf(gSP.lights.pos_xyzw[l][Z] - vtx.z);
			const f32 distance = dX + dY + dZ - gSP.lights.ca[l];
			if (distance >= 0.0f)
				continue;

			const f32 light_intensity = -distance * gSP.lights.la[l];
			vtx.r += gSP.lights.rgb[l][R] * light_intensity;
			vtx.g += gSP.lights.rgb[l][G] * light_intensity;
			vtx.b += gSP.lights.rgb[l][B] * light_intensity;
		}

		if (vtx.r > 1.0f) vtx.r = 1.0f;
		if (vtx.g > 1.0f) vtx.g = 1.0f;
		if (vtx.b > 1.0f) vtx.b = 1.0f;
	}
}

template <u32 VNUM>
void gSPBillboardVertex(u32 v, SPVertex * spVtx)
{
#ifndef __NEON_OPT
	SPVertex & vtx0 = spVtx[0];
	for (u32 j = 0; j < VNUM; ++j) {
		SPVertex & vtx = spVtx[v + j];
		vtx.x += vtx0.x;
		vtx.y += vtx0.y;
		vtx.z += vtx0.z;
		vtx.w += vtx0.w;
	}
#else
	if (VNUM == 1) {
		SPVertex & vtx0 = spVtx[0];
		SPVertex & vtx = spVtx[v];
		vtx.x += vtx0.x;
		vtx.y += vtx0.y;
		vtx.z += vtx0.z;
		vtx.w += vtx0.w;
	} else {
		void gSPBillboardVertex4NEON(u32 v);
		gSPBillboardVertex4NEON(v);
	}
#endif //__NEON_OPT
}

template <u32 VNUM>
void gSPClipVertex(u32 v, SPVertex * spVtx)
{
	for (u32 j = 0; j < VNUM; ++j) {
		SPVertex & vtx = spVtx[v+j];
		vtx.clip = 0;
		if (vtx.x > +vtx.w) vtx.clip |= CLIP_POSX;
		if (vtx.x < -vtx.w) vtx.clip |= CLIP_NEGX;
		if (vtx.y > +vtx.w) vtx.clip |= CLIP_POSY;
		if (vtx.y < -vtx.w) vtx.clip |= CLIP_NEGY;
		if (vtx.w < 0.01f) vtx.clip |= CLIP_W;
	}
}

template <u32 VNUM>
void gSPTransformVertex(u32 v, SPVertex * spVtx, float mtx[4][4])
{
#ifndef __NEON_OPT
	float x, y, z;
	for (int i = 0; i < VNUM; ++i) {
		SPVertex & vtx = spVtx[v+i];
		x = vtx.x;
		y = vtx.y;
		z = vtx.z;
		vtx.x = x * mtx[0][0] + y * mtx[1][0] + z * mtx[2][0] + mtx[3][0];
		vtx.y = x * mtx[0][1] + y * mtx[1][1] + z * mtx[2][1] + mtx[3][1];
		vtx.z = x * mtx[0][2] + y * mtx[1][2] + z * mtx[2][2] + mtx[3][2];
		vtx.w = x * mtx[0][3] + y * mtx[1][3] + z * mtx[2][3] + mtx[3][3];
	}
#else
	void gSPTransformVector_NEON(float vtx[4], float mtx[4][4]);
	void gSPTransformVertex4NEON(u32 v, float mtx[4][4]);
	if (VNUM == 1)
		gSPTransformVector_NEON(&spVtx[v].x, mtx);
	else
		gSPTransformVertex4NEON(v, mtx);
#endif //__NEON_OPT
}

template <u32 VNUM>
void gSPProcessVertex(u32 v, SPVertex * spVtx)
{
	if (gSP.changed & CHANGED_MATRIX)
		_gSPCombineMatrices();

	float vPos[VNUM][4];
	for(u32 i = 0; i < VNUM; ++i) {
		SPVertex & vtx = spVtx[v+i];
		vPos[i][0] = vtx.x;
		vPos[i][1] = vtx.y;
		vPos[i][2] = vtx.z;
		vPos[i][3] = 0.0f;
		vtx.modify = 0;
	}

	gSPTransformVertex<VNUM>(v, spVtx, gSP.matrix.combined );

	if (dwnd().isAdjustScreen() && (gDP.colorImage.width > VI.width * 98 / 100)) {
		const f32 adjustScale = dwnd().getAdjustScale();
		for(int i = 0; i < VNUM; ++i) {
			SPVertex & vtx = spVtx[v+i];
			vtx.x *= adjustScale;
			if (gSP.matrix.projection[3][2] == -1.f)
				vtx.w *= adjustScale;
		}
	}
	if (gSP.viewport.vscale[0] < 0) {
		for(int i = 0; i < VNUM; ++i) {
			SPVertex & vtx = spVtx[v+i];
			vtx.x = -vtx.x;
		}
	}
	if (gSP.viewport.vscale[1] < 0) {
		for(int i = 0; i < VNUM; ++i) {
			SPVertex & vtx = spVtx[v+i];
			vtx.y = -vtx.y;
		}
	}

	if (gSP.matrix.billboard)
		gSPBillboardVertex<VNUM>(v, spVtx);

	gSPClipVertex<VNUM>(v, spVtx);

	if (gSP.geometryMode & G_LIGHTING) {
		if (gSP.geometryMode & G_POINT_LIGHTING)
			gSPPointLightVertex<VNUM>(v, vPos, spVtx);
		else
			gSPLightVertex<VNUM>(v, spVtx);

		if (gSP.geometryMode & G_ACCLAIM_LIGHTING)
			gSPPointLightVertexAcclaim<VNUM>(v, spVtx);

		if ((gSP.geometryMode & G_TEXTURE_GEN) != 0) {
			if (GBI.getMicrocodeType() != F3DFLX2) {
				for(int i = 0; i < VNUM; ++i) {
					SPVertex & vtx = spVtx[v+i];
					f32 fLightDir[3] = {vtx.nx, vtx.ny, vtx.nz};
					f32 x, y;
					if (gSP.lookatEnable) {
						x = DotProduct(gSP.lookat.i_xyz[0], fLightDir);
						y = DotProduct(gSP.lookat.i_xyz[1], fLightDir);
					} else {
						fLightDir[0] *= 128.0f;
						fLightDir[1] *= 128.0f;
						fLightDir[2] *= 128.0f;
						TransformVectorNormalize(fLightDir, gSP.matrix.modelView[gSP.matrix.modelViewi]);
						x = fLightDir[0];
						y = fLightDir[1];
					}
					if (gSP.geometryMode & G_TEXTURE_GEN_LINEAR) {
						vtx.s = acosf(-x) * 325.94931f;
						vtx.t = acosf(-y) * 325.94931f;
					} else { // G_TEXTURE_GEN
						vtx.s = (x + 1.0f) * 512.0f;
						vtx.t = (y + 1.0f) * 512.0f;
					}
				}
			} else {
				for(int i = 0; i < VNUM; ++i) {
					SPVertex & vtx = spVtx[v+i];
					const f32 intensity = DotProduct(gSP.lookat.i_xyz[0], &vtx.nx) * 128.0f;
					const s16 index = static_cast<s16>(intensity);
					vtx.a = _FIXED2FLOATCOLOR(RDRAM[(gSP.DMAIO_address + 128 + index) ^ 3], 8);
				}
			}
		}
	} else if (gSP.geometryMode & G_ACCLAIM_LIGHTING) {
		gSPPointLightVertexAcclaim<VNUM>(v, spVtx);
	} else {
		for(u32 i = 0; i < VNUM; ++i)
			spVtx[v].HWLight = 0;
	}

	for(u32 i = 0; i < VNUM; ++i) {
		SPVertex & vtx = spVtx[v+i];
		DebugMsg(DEBUG_DETAIL, "v%d - x: %f, y: %f, z: %f, w: %f, s: %f, t: %f, r=%02f, g=%02f, b=%02f, a=%02f\n",
				 i, vtx.x, vtx.y, vtx.z, vtx.w, vtx.s, vtx.t, vtx.r, vtx.g, vtx.b, vtx.a);
	}
}

template <u32 VNUM>
u32 gSPLoadVertexData(const Vertex *orgVtx, SPVertex * spVtx, u32 v0, u32 vi, u32 n)
{
	const u32 end = n - (n%VNUM) + v0;
	for (; vi < end; vi += VNUM) {
		for(u32 j = 0; j < VNUM; ++j) {
			SPVertex & vtx = spVtx[vi+j];
			vtx.x = orgVtx->x;
			vtx.y = orgVtx->y;
			vtx.z = orgVtx->z;
			//vtx.flag = vertex->flag;
			vtx.s = _FIXED2FLOAT( orgVtx->s, 5 );
			vtx.t = _FIXED2FLOAT( orgVtx->t, 5 );

			if (gSP.geometryMode & G_LIGHTING) {
				vtx.nx = _FIXED2FLOATCOLOR(orgVtx->normal.x, 7);
				vtx.ny = _FIXED2FLOATCOLOR(orgVtx->normal.y, 7);
				vtx.nz = _FIXED2FLOATCOLOR(orgVtx->normal.z, 7);
				if (isHWLightingAllowed()) {
					vtx.r = orgVtx->normal.x;
					vtx.g = orgVtx->normal.y;
					vtx.b = orgVtx->normal.z;
				}
			} else {
				vtx.r = _FIXED2FLOATCOLOR(orgVtx->color.r, 8);
				vtx.g = _FIXED2FLOATCOLOR(orgVtx->color.g, 8);
				vtx.b = _FIXED2FLOATCOLOR(orgVtx->color.b, 8);
			}
			vtx.a = _FIXED2FLOATCOLOR(orgVtx->color.a, 8);

			++orgVtx;
		}
		gSPProcessVertex<VNUM>(vi, spVtx);
	}
	return vi;
}

void gSPVertex(u32 a, u32 n, u32 v0)
{
	DebugMsg(DEBUG_NORMAL, "gSPVertex n = %i, v0 = %i, from %08x\n", n, v0, a);

	if ((n + v0) > INDEXMAP_SIZE) {
		LOG(LOG_ERROR, "Using Vertex outside buffer v0=%i, n=%i\n", v0, n);
		DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "//Using Vertex outside buffer v0 = %i, n = %i\n", v0, n);
		return;
	}

	const u32 address = RSP_SegmentToPhysical(a);

	if ((address + sizeof(Vertex)* n) > RDRAMSize) {
		DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "gSPVertex Using Vertex outside RDRAM n = %i, v0 = %i, from %08x\n", n, v0, a);
		return;
	}

	if ((gSP.geometryMode & G_LIGHTING) != 0) {

		if ((gSP.changed & CHANGED_LIGHT) != 0)
			gSPUpdateLightVectors();

		if (((gSP.geometryMode & G_TEXTURE_GEN) != 0) && ((gSP.changed & CHANGED_LOOKAT) != 0))
			gSPUpdateLookatVectors();
	}

	const Vertex *vertex = (Vertex*)&RDRAM[address];
	SPVertex * spVtx = dwnd().getDrawer().getVertexPtr(0);
	u32 i = gSPLoadVertexData<VEC_OPT>(vertex, spVtx, v0, v0, n);
	if (i < n + v0)
		gSPLoadVertexData<1>(vertex + (i - v0), spVtx, v0, i, n);
}

template <u32 VNUM>
u32 gSPLoadCIVertexData(const PDVertex *orgVtx, SPVertex * spVtx, u32 v0, u32 vi, u32 n)
{
	const u32 end = n - (n%VNUM) + v0;
	for (; vi < end; vi += VNUM) {
		for(u32 j = 0; j < VNUM; ++j) {
			SPVertex & vtx = spVtx[vi+j];
			vtx.x = orgVtx->x;
			vtx.y = orgVtx->y;
			vtx.z = orgVtx->z;
			vtx.s = _FIXED2FLOAT( orgVtx->s, 5 );
			vtx.t = _FIXED2FLOAT( orgVtx->t, 5 );
			u8 *color = &RDRAM[gSP.vertexColorBase + (orgVtx->ci & 0xff)];

			if (gSP.geometryMode & G_LIGHTING) {
				vtx.nx = _FIXED2FLOATCOLOR((s8)color[3], 7);
				vtx.ny = _FIXED2FLOATCOLOR((s8)color[2], 7);
				vtx.nz = _FIXED2FLOATCOLOR((s8)color[1], 7);
				if (isHWLightingAllowed()) {
					vtx.r = (s8)color[3];
					vtx.g = (s8)color[2];
					vtx.b = (s8)color[1];
				}
			} else {
				vtx.r = _FIXED2FLOATCOLOR(color[3], 8);
				vtx.g = _FIXED2FLOATCOLOR(color[2], 8);
				vtx.b = _FIXED2FLOATCOLOR(color[1], 8);
			}
			vtx.a = _FIXED2FLOATCOLOR(color[0], 8);

			++orgVtx;
		}
		gSPProcessVertex<VNUM>(vi, spVtx);
	}
	return vi;
}

void gSPCIVertex( u32 a, u32 n, u32 v0 )
{
	DebugMsg(DEBUG_NORMAL, "gSPCIVertex n = %i, v0 = %i, from %08x\n", n, v0, a);

	if ((n + v0) > INDEXMAP_SIZE) {
		LOG(LOG_ERROR, "Using Vertex outside buffer v0=%i, n=%i\n", v0, n);
		DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "//Using Vertex outside buffer v0 = %i, n = %i\n", v0, n);
		return;
	}

	const u32 address = RSP_SegmentToPhysical( a );

	if ((address + sizeof( PDVertex ) * n) > RDRAMSize)
		return;

	if ((gSP.geometryMode & G_LIGHTING) != 0) {

		if ((gSP.changed & CHANGED_LIGHT) != 0)
			gSPUpdateLightVectors();

		if (((gSP.geometryMode & G_TEXTURE_GEN) != 0) && ((gSP.changed & CHANGED_LOOKAT) != 0))
			gSPUpdateLookatVectors();
	}

	const PDVertex *vertex = (PDVertex*)&RDRAM[address];
	SPVertex * spVtx = dwnd().getDrawer().getVertexPtr(0);
	u32 i = gSPLoadCIVertexData<VEC_OPT>(vertex, spVtx, v0, v0, n);
	if (i < n + v0)
		gSPLoadCIVertexData<1>(vertex + (i - v0), spVtx, v0, i, n);
}


template <u32 VNUM>
u32 gSPLoadDMAVertexData(u32 address, SPVertex * spVtx, u32 v0, u32 vi, u32 n)
{
	const u32 end = n - (n%VNUM) + v0;
	for (; vi < end; vi += VNUM) {
		for(u32 j = 0; j < VNUM; ++j) {
			SPVertex & vtx = spVtx[vi+j];
			vtx.x = *(s16*)&RDRAM[address ^ 2];
			vtx.y = *(s16*)&RDRAM[(address + 2) ^ 2];
			vtx.z = *(s16*)&RDRAM[(address + 4) ^ 2];

			vtx.r = _FIXED2FLOATCOLOR((*(u8*)&RDRAM[(address + 6) ^ 3]), 8);
			vtx.g = _FIXED2FLOATCOLOR((*(u8*)&RDRAM[(address + 7) ^ 3]), 8);
			vtx.b = _FIXED2FLOATCOLOR((*(u8*)&RDRAM[(address + 8) ^ 3]), 8);
			vtx.a = _FIXED2FLOATCOLOR((*(u8*)&RDRAM[(address + 9) ^ 3]), 8);

			address += 10;
		}
		gSPProcessVertex<VNUM>(vi, spVtx);
	}
	return vi;
}

void gSPDMAVertex( u32 a, u32 n, u32 v0 )
{
	DebugMsg(DEBUG_NORMAL, "gSPDMAVertex n = %i, v0 = %i, from %08x\n", n, v0, a);

	if ((n + v0) > INDEXMAP_SIZE) {
		LOG(LOG_ERROR, "Using Vertex outside buffer v0=%i, n=%i\n", v0, n);
		DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "//Using Vertex outside buffer v0 = %i, n = %i\n", v0, n);
		return;
	}

	const u32 address = gSP.DMAOffsets.vtx + RSP_SegmentToPhysical(a);

	if ((address + 10 * n) > RDRAMSize)
		return;

	SPVertex * spVtx = dwnd().getDrawer().getVertexPtr(0);
	u32 i = gSPLoadDMAVertexData<VEC_OPT>(address, spVtx, v0, v0, n);
	if (i < n + v0)
		gSPLoadDMAVertexData<1>(address + (i - v0) * 10, spVtx, v0, i, n);
}

template <u32 VNUM>
u32 gSPLoadCBFDVertexData(const Vertex *orgVtx, SPVertex * spVtx, u32 v0, u32 vi, u32 n)
{
	const u32 end = n - (n%VNUM) + v0;
	for (; vi < end; vi += VNUM) {
		for(u32 j = 0; j < VNUM; ++j) {
			SPVertex & vtx = spVtx[vi+j];
			vtx.x = orgVtx->x;
			vtx.y = orgVtx->y;
			vtx.z = orgVtx->z;
			vtx.s = _FIXED2FLOAT( orgVtx->s, 5 );
			vtx.t = _FIXED2FLOAT( orgVtx->t, 5 );
			if (gSP.geometryMode & G_LIGHTING) {
				const u32 normaleAddrOffset = ((vi+j)<<1);
				vtx.nx = _FIXED2FLOATCOLOR(((s8*)RDRAM)[(gSP.vertexNormalBase + normaleAddrOffset + 0) ^ 3], 7);
				vtx.ny = _FIXED2FLOATCOLOR(((s8*)RDRAM)[(gSP.vertexNormalBase + normaleAddrOffset + 1) ^ 3], 7);
				vtx.nz = _FIXED2FLOATCOLOR((s8)(orgVtx->flag & 0xFF), 7);
			}
			vtx.r = _FIXED2FLOATCOLOR(orgVtx->color.r, 8);
			vtx.g = _FIXED2FLOATCOLOR(orgVtx->color.g, 8);
			vtx.b = _FIXED2FLOATCOLOR(orgVtx->color.b, 8);
			vtx.a = _FIXED2FLOATCOLOR(orgVtx->color.a, 8);
			++orgVtx;
		}
		gSPProcessVertex<VNUM>(vi, spVtx);
	}
	return vi;
}

void gSPCBFDVertex( u32 a, u32 n, u32 v0 )
{
	DebugMsg(DEBUG_NORMAL, "gSPCBFDVertex n = %i, v0 = %i, from %08x\n", n, v0, a);

	if ((n + v0) > INDEXMAP_SIZE) {
		LOG(LOG_ERROR, "Using Vertex outside buffer v0=%i, n=%i\n", v0, n);
		DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "//Using Vertex outside buffer v0 = %i, n = %i\n", v0, n);
		return;
	}

	const u32 address = RSP_SegmentToPhysical(a);

	if ((address + sizeof( Vertex ) * n) > RDRAMSize)
		return;

	if ((gSP.geometryMode & G_LIGHTING) != 0) {

		if ((gSP.changed & CHANGED_LIGHT) != 0)
			gSPUpdateLightVectors();

		if (((gSP.geometryMode & G_TEXTURE_GEN) != 0) && ((gSP.changed & CHANGED_LOOKAT) != 0))
			gSPUpdateLookatVectors();
	}

	const Vertex *vertex = (Vertex*)&RDRAM[address];
	SPVertex * spVtx = dwnd().getDrawer().getVertexPtr(0);
	u32 i = gSPLoadCBFDVertexData<VEC_OPT>(vertex, spVtx, v0, v0, n);
	if (i < n + v0)
		gSPLoadCBFDVertexData<1>(vertex + (i - v0), spVtx, v0, i, n);
}

static
void calcF3DAMTexCoords(const Vertex * _vertex, SPVertex & _vtx)
{
	const u32 s0 = (u32)_vertex->s;
	const u32 t0 = (u32)_vertex->t;
	const u32 acum_0 = ((_SHIFTR(gSP.textureCoordScaleOrg, 0, 16) * t0) << 1) + 0x8000;
	const u32 acum_1 = ((_SHIFTR(gSP.textureCoordScale[1], 0, 16) * t0) << 1) + 0x8000;
	const u32 sres = ((_SHIFTR(gSP.textureCoordScaleOrg, 16, 16) * s0) << 1) + acum_0;
	const u32 tres = ((_SHIFTR(gSP.textureCoordScale[1], 16, 16) * s0) << 1) + acum_1;
	const s16 s = _SHIFTR(sres, 16, 16) + _SHIFTR(gSP.textureCoordScale[0], 16, 16);
	const s16 t = _SHIFTR(tres, 16, 16) + _SHIFTR(gSP.textureCoordScale[0], 0, 16);

	_vtx.s = _FIXED2FLOAT( s, 5 );
	_vtx.t = _FIXED2FLOAT( t, 5 );
}

template <u32 VNUM>
u32 gSPLoadF3DAMVertexData(const Vertex *orgVtx, SPVertex * spVtx, u32 v0, u32 vi, u32 n)
{
	const u32 end = n - (n%VNUM) + v0;
	for (; vi < end; vi += VNUM) {
		for(u32 j = 0; j < VNUM; ++j) {
			SPVertex & vtx = spVtx[vi+j];
			vtx.x = orgVtx->x;
			vtx.y = orgVtx->y;
			vtx.z = orgVtx->z;
			//vtx.flag = orgVtx->flag;
			calcF3DAMTexCoords(orgVtx, vtx);
			if (gSP.geometryMode & G_LIGHTING) {
				vtx.nx = _FIXED2FLOATCOLOR( orgVtx->normal.x, 7 );
				vtx.ny = _FIXED2FLOATCOLOR( orgVtx->normal.y, 7 );
				vtx.nz = _FIXED2FLOATCOLOR( orgVtx->normal.z, 7 );
				vtx.a = orgVtx->color.a * 0.0039215689f;
			} else {
				vtx.r = orgVtx->color.r * 0.0039215689f;
				vtx.g = orgVtx->color.g * 0.0039215689f;
				vtx.b = orgVtx->color.b * 0.0039215689f;
				vtx.a = orgVtx->color.a * 0.0039215689f;
			}
			++orgVtx;
		}
		gSPProcessVertex<VNUM>(vi, spVtx);
	}
	return vi;
}

void gSPF3DAMVertex(u32 a, u32 n, u32 v0)
{
	DebugMsg(DEBUG_NORMAL, "gSPF3DAMVertex n = %i, v0 = %i, from %08x\n", n, v0, a);

	if ((n + v0) > INDEXMAP_SIZE) {
		LOG(LOG_ERROR, "Using Vertex outside buffer v0=%i, n=%i\n", v0, n);
		DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "//Using Vertex outside buffer v0 = %i, n = %i\n", v0, n);
		return;
	}

	const u32 address = RSP_SegmentToPhysical(a);

	if ((address + sizeof(Vertex)* n) > RDRAMSize) {
		DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "gSPF3DAMVertex Using Vertex outside RDRAM n = %i, v0 = %i, from %08x\n", n, v0, a);
		return;
	}

	if ((gSP.geometryMode & G_LIGHTING) != 0) {

		if ((gSP.changed & CHANGED_LIGHT) != 0)
			gSPUpdateLightVectors();

		if (((gSP.geometryMode & G_TEXTURE_GEN) != 0) && ((gSP.changed & CHANGED_LOOKAT) != 0))
			gSPUpdateLookatVectors();
	}

	const Vertex *vertex = (Vertex*)&RDRAM[address];
	SPVertex * spVtx = dwnd().getDrawer().getVertexPtr(0);
	u32 i = gSPLoadF3DAMVertexData<VEC_OPT>(vertex, spVtx, v0, v0, n);
	if (i < n + v0)
		gSPLoadF3DAMVertexData<1>(vertex + (i - v0), spVtx, v0, i, n);
}

template <u32 VNUM>
u32 gSPLoadSWVertexData(const SWVertex *orgVtx, SPVertex * spVtx, u32 v0, u32 vi, u32 n)
{
	const u32 end = n - (n%VNUM) + v0;
	for (; vi < end; vi += VNUM) {
		for(u32 j = 0; j < VNUM; ++j) {
			SPVertex & vtx = spVtx[vi+j];
			vtx.x = orgVtx->x;
			vtx.y = orgVtx->y;
			vtx.z = orgVtx->z;
			++orgVtx;
		}
		gSPProcessVertex<VNUM>(vi, spVtx);
		for (u32 j = 0; j < VNUM; ++j) {
			SPVertex & vtx = spVtx[vi+j];
			vtx.y = -vtx.y;
		}
	}
	return vi;
}

void gSPSWVertex(const SWVertex * vertex, u32 n, u32 v0)
{
	DebugMsg(DEBUG_NORMAL, "gSPSWVertex n = %i, v0 = %i\n", n, v0);

	if ((n + v0) > INDEXMAP_SIZE) {
		LOG(LOG_ERROR, "Using Vertex outside buffer v0=%i, n=%i\n", v0, n);
		DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "//Using Vertex outside buffer v0 = %i, n = %i\n", v0, n);
		return;
	}

	SPVertex * spVtx = dwnd().getDrawer().getVertexPtr(0);
	u32 i = gSPLoadSWVertexData<VEC_OPT>(vertex, spVtx, v0, v0, n);
	if (i < n + v0)
		gSPLoadSWVertexData<1>(vertex + (i - v0), spVtx, v0, i, n);
}

void gSPT3DUXVertex(u32 a, u32 n, u32 ci)
{
	const u32 address = RSP_SegmentToPhysical(a);
	const u32 colors = RSP_SegmentToPhysical(ci);

	struct T3DUXVertex {
		s16 y;
		s16 x;
		u16 flag;
		s16 z;
	} *vertex = (T3DUXVertex*)&RDRAM[address];

	struct T3DUXColor
	{
		u8 a;
		u8 b;
		u8 g;
		u8 r;
	} *color = (T3DUXColor*)&RDRAM[colors];

	if ((address + sizeof(T3DUXVertex)* n) > RDRAMSize)
		return;

	SPVertex * spVtx = dwnd().getDrawer().getVertexPtr(0);
	u32 i = 0;
#ifdef __VEC4_OPT
	for (; i < n - (n % 4); i += 4) {
		u32 v = i;
		for (int j = 0; j < 4; ++j) {
			SPVertex & vtx = spVtx[v+j];
			vtx.x = vertex->x;
			vtx.y = vertex->y;
			vtx.z = vertex->z;
			vtx.s = 0;
			vtx.t = 0;
			vtx.r = _FIXED2FLOATCOLOR(color->r, 8);
			vtx.g = _FIXED2FLOATCOLOR(color->g, 8);
			vtx.b = _FIXED2FLOATCOLOR(color->b, 8);
			vtx.a = _FIXED2FLOATCOLOR(color->a, 8);
			vertex++;
			color++;
		}
		gSPProcessVertex<4>(v, spVtx);
	}
#endif
	for (; i < n; ++i) {
		SPVertex & vtx = spVtx[i];
		vtx.x = vertex->x;
		vtx.y = vertex->y;
		vtx.z = vertex->z;
		vtx.s = 0;
		vtx.t = 0;
		vtx.r = _FIXED2FLOATCOLOR(color->r, 8);
		vtx.g = _FIXED2FLOATCOLOR(color->g, 8);
		vtx.b = _FIXED2FLOATCOLOR(color->b, 8);
		vtx.a = _FIXED2FLOATCOLOR(color->a, 8);
		gSPProcessVertex<1>(i, spVtx);
		vertex++;
		color++;
	}
}

void gSPDisplayList( u32 dl )
{
	u32 address = RSP_SegmentToPhysical( dl );

	if ((address + 8) > RDRAMSize) {
		DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "// Attempting to load display list from invalid address\n");
		DebugMsg(DEBUG_NORMAL, "gSPDisplayList( 0x%08X );\n", dl );
		return;
	}

	if (RSP.PCi < (GBI.PCStackSize - 1)) {
		DebugMsg(DEBUG_NORMAL, "gSPDisplayList( 0x%08X ) push\n", dl);
		RSP.PCi++;
		RSP.PC[RSP.PCi] = address;
		RSP.nextCmd = _SHIFTR( *(u32*)&RDRAM[address], 24, 8 );
	} else {
		assert(false);
		DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "// PC stack overflow\n");
		DebugMsg(DEBUG_NORMAL, "gSPDisplayList( 0x%08X );\n", dl );
	}
}

void gSPBranchList( u32 dl )
{
	u32 address = RSP_SegmentToPhysical( dl );

	if ((address + 8) > RDRAMSize) {
		DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "// Attempting to branch to display list at invalid address\n");
		DebugMsg(DEBUG_NORMAL, "gSPBranchList( 0x%08X );\n", dl );
		return;
	}

	DebugMsg(DEBUG_NORMAL, "gSPBranchList( 0x%08X ) nopush\n", dl );

	if (((config.generalEmulation.hacks & hack_Infloop) != 0) && (address == (RSP.PC[RSP.PCi] - 8))) {
		RSP.infloop = true;
		RSP.PC[RSP.PCi] -= 8;
		*REG.SP_STATUS &= ~(SP_STATUS_TASKDONE | SP_STATUS_HALT | SP_STATUS_BROKE);
		RSP.halt = true;
		return;
	}

	RSP.PC[RSP.PCi] = address;
	RSP.nextCmd = _SHIFTR( *(u32*)&RDRAM[address], 24, 8 );
}

void gSPBranchLessZ(u32 branchdl, u32 vtx, u32 zval)
{
	const u32 address = RSP_SegmentToPhysical( branchdl );

	if ((address + 8) > RDRAMSize) {
		DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "// Specified display list at invalid address\n");
		DebugMsg(DEBUG_NORMAL, "gSPBranchLessZ( 0x%08X, %i, %i );\n", branchdl, vtx, zval );
		return;
	}

	SPVertex & v = dwnd().getDrawer().getVertex(vtx);
	const u32 zTest = u32((v.z / v.w) * 1023.0f);
	if (zTest > 0x03FF || zTest <= zval)
		RSP.PC[RSP.PCi] = address;

	DebugMsg(DEBUG_NORMAL, "gSPBranchLessZ( 0x%08X, %i, %i );\n", branchdl, vtx, zval );
}

void gSPBranchLessW( u32 branchdl, u32 vtx, u32 wval )
{
	const u32 address = RSP_SegmentToPhysical( branchdl );

	if ((address + 8) > RDRAMSize) {
		DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "// Specified display list at invalid address\n");
		DebugMsg(DEBUG_NORMAL, "gSPBranchLessW( 0x%08X, %i, %i );\n", branchdl, vtx, wval);
		return;
	}

	SPVertex & v = dwnd().getDrawer().getVertex(vtx);
	if (v.w < (float)wval)
		RSP.PC[RSP.PCi] = address;

	DebugMsg(DEBUG_NORMAL, "gSPBranchLessZ( 0x%08X, %i, %i );\n", branchdl, vtx, wval);
}

void gSPDlistCount(u32 count, u32 v)
{
	u32 address = RSP_SegmentToPhysical( v );
	if (address == 0 || (address + 8) > RDRAMSize) {
		DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "// Attempting to branch to display list at invalid address\n");
		DebugMsg(DEBUG_NORMAL, "gSPDlistCnt(%d, 0x%08X );\n", count, v);
		return;
	}

	if (RSP.PCi >= 9) {
		DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "// ** DL stack overflow **\n");
		DebugMsg(DEBUG_NORMAL, "gSPDlistCnt(%d, 0x%08X );\n", count, v);
		return;
	}

	DebugMsg(DEBUG_NORMAL, "gSPDlistCnt(%d, 0x%08X );\n", count, v);

	++RSP.PCi;  // go to the next PC in the stack
	RSP.PC[RSP.PCi] = address;  // jump to the address
	RSP.nextCmd = _SHIFTR( *(u32*)&RDRAM[address], 24, 8 );
	RSP.count = count + 1;
}

void gSPSetDMAOffsets( u32 mtxoffset, u32 vtxoffset )
{
	gSP.DMAOffsets.mtx = mtxoffset;
	gSP.DMAOffsets.vtx = vtxoffset;

	DebugMsg(DEBUG_NORMAL, "gSPSetDMAOffsets( 0x%08X, 0x%08X );\n", mtxoffset, vtxoffset );
}

void gSPSetDMATexOffset(u32 _addr)
{
	gSP.DMAOffsets.tex_offset = RSP_SegmentToPhysical(_addr);
	gSP.DMAOffsets.tex_shift = 0;
	gSP.DMAOffsets.tex_count = 0;
}

void gSPSetVertexColorBase( u32 base )
{
	gSP.vertexColorBase = RSP_SegmentToPhysical( base );

	DebugMsg(DEBUG_NORMAL, "gSPSetVertexColorBase( 0x%08X );\n", base );
}

void gSPSetVertexNormaleBase( u32 base )
{
	gSP.vertexNormalBase = RSP_SegmentToPhysical( base );

	DebugMsg(DEBUG_NORMAL, "gSPSetVertexNormaleBase( 0x%08X );\n", base );
}

void gSPDMATriangles( u32 tris, u32 n ){
	const u32 address = RSP_SegmentToPhysical( tris );

	if (address + sizeof( DKRTriangle ) * n > RDRAMSize) {
		DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "// Attempting to load triangles from invalid address\n");
		DebugMsg(DEBUG_NORMAL, "gSPDMATriangles( 0x%08X, %i );\n");
		return;
	}

	GraphicsDrawer & drawer = dwnd().getDrawer();
	drawer.setDMAVerticesSize(n * 3);

	DKRTriangle *triangles = (DKRTriangle*)&RDRAM[address];
	SPVertex * pVtx = drawer.getDMAVerticesData();
	for (u32 i = 0; i < n; ++i) {
		int mode = 0;
		if (!(triangles->flag & 0x40)) {
			if (gSP.viewport.vscale[0] > 0)
				mode |= G_CULL_BACK;
			else
				mode |= G_CULL_FRONT;
		}
		if ((gSP.geometryMode&G_CULL_BOTH) != mode) {
			drawer.drawDMATriangles(pVtx - drawer.getDMAVerticesData());
			pVtx = drawer.getDMAVerticesData();
			gSP.geometryMode &= ~G_CULL_BOTH;
			gSP.geometryMode |= mode;
			gSP.changed |= CHANGED_GEOMETRYMODE;
		}

		const s32 v0 = triangles->v0;
		const s32 v1 = triangles->v1;
		const s32 v2 = triangles->v2;
		if (drawer.isClipped(v0, v1, v2)) {
			++triangles;
			continue;
		}
		*pVtx = drawer.getVertex(v0);
		pVtx->s = _FIXED2FLOAT(triangles->s0, 5);
		pVtx->t = _FIXED2FLOAT(triangles->t0, 5);
		++pVtx;
		*pVtx = drawer.getVertex(v1);
		pVtx->s = _FIXED2FLOAT(triangles->s1, 5);
		pVtx->t = _FIXED2FLOAT(triangles->t1, 5);
		++pVtx;
		*pVtx = drawer.getVertex(v2);
		pVtx->s = _FIXED2FLOAT(triangles->s2, 5);
		pVtx->t = _FIXED2FLOAT(triangles->t2, 5);
		++pVtx;
		++triangles;
	}
	DebugMsg(DEBUG_NORMAL, "gSPDMATriangles( 0x%08X, %i );\n");
	drawer.drawDMATriangles(pVtx - drawer.getDMAVerticesData());
}

void gSP1Quadrangle( s32 v0, s32 v1, s32 v2, s32 v3 )
{
	gSPTriangle( v0, v1, v2);
	gSPTriangle( v0, v2, v3);
	gSPFlushTriangles();

	DebugMsg(DEBUG_NORMAL, "gSP1Quadrangle( %i, %i, %i, %i );\n", v0, v1, v2, v3 );
}

bool gSPCullVertices( u32 v0, u32 vn )
{
	if (vn < v0) {
		// Aidyn Chronicles - The First Mage seems to pass parameters in reverse order.
		const u32 v = v0;
		v0 = vn;
		vn = v;
	}
	u32 clip = 0;
	GraphicsDrawer & drawer = dwnd().getDrawer();
	for (u32 i = v0; i <= vn; ++i) {
		clip |= (~drawer.getVertex(i).clip) & CLIP_ALL;
		if (clip == CLIP_ALL)
			return false;
	}
	return true;
}

void gSPCullDisplayList( u32 v0, u32 vn )
{
	if (gSPCullVertices( v0, vn )) {
		if (RSP.PCi > 0)
			RSP.PCi--;
		else {
			DebugMsg(DEBUG_NORMAL, "End of display list, halting execution\n");
			RSP.halt = true;
		}
		DebugMsg( DEBUG_DETAIL, "// Culling display list\n" );
		DebugMsg(DEBUG_NORMAL, "gSPCullDisplayList( %i, %i );\n\n", v0, vn );
	} else {
		DebugMsg( DEBUG_DETAIL, "// Not culling display list\n" );
		DebugMsg(DEBUG_NORMAL, "gSPCullDisplayList( %i, %i );\n", v0, vn);
	}
}

void gSPPopMatrixN(u32 param, u32 num)
{
	if (gSP.matrix.modelViewi > num - 1) {
		gSP.matrix.modelViewi -= num;
		gSP.changed |= CHANGED_MATRIX | CHANGED_LIGHT | CHANGED_LOOKAT;
	} else {
		DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "// Attempting to pop matrix stack below 0\n");
	}
	DebugMsg(DEBUG_NORMAL, "gSPPopMatrixN( %s, %i );\n",
		(param == G_MTX_MODELVIEW) ? "G_MTX_MODELVIEW" :
		(param == G_MTX_PROJECTION) ? "G_MTX_PROJECTION" : "G_MTX_INVALID",	num );
}

void gSPPopMatrix( u32 param )
{
	switch (param) {
	case 0: // modelview
		if (gSP.matrix.modelViewi > 0) {
			gSP.matrix.modelViewi--;

			gSP.changed |= CHANGED_MATRIX | CHANGED_LIGHT | CHANGED_LOOKAT;
		}
	break;
	case 1: // projection, can't
	break;
	default:
		DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "// Attempting to pop matrix stack below 0\n");
	}
	DebugMsg(DEBUG_NORMAL, "gSPPopMatrix( %s );\n",
		(param == G_MTX_MODELVIEW) ? "G_MTX_MODELVIEW" :
		(param == G_MTX_PROJECTION) ? "G_MTX_PROJECTION" : "G_MTX_INVALID");
}

void gSPSegment( s32 seg, s32 base )
{
	gSP.segment[seg] = base;

	DebugMsg(DEBUG_NORMAL, "gSPSegment( %s, 0x%08X );\n", SegmentText[seg], base );
}

void gSPClipRatio( u32 r )
{
	DebugMsg(DEBUG_NORMAL|DEBUG_IGNORED, "gSPClipRatio(%u);\n", r);
}

void gSPInsertMatrix( u32 where, u32 num )
{
	DebugMsg(DEBUG_NORMAL, "gSPInsertMatrix(%u, %u);\n", where, num);

	f32 fraction, integer;

	if ((where & 0x3) || (where > 0x3C))
		return;

	if (where < 0x20) {
		fraction = modff( gSP.matrix.combined[0][where >> 1], &integer );
		gSP.matrix.combined[0][where >> 1] = (f32)((s16)_SHIFTR( num, 16, 16 ) + abs( (int)fraction ));

		fraction = modff( gSP.matrix.combined[0][(where >> 1) + 1], &integer );
		gSP.matrix.combined[0][(where >> 1) + 1] = (f32)((s16)_SHIFTR( num, 0, 16 ) + abs( (int)fraction ));
	} else {
		f32 newValue;

		fraction = modff( gSP.matrix.combined[0][(where - 0x20) >> 1], &integer );
		newValue = integer + _FIXED2FLOAT( _SHIFTR( num, 16, 16 ), 16);

		// Make sure the sign isn't lost
		if ((integer == 0.0f) && (fraction != 0.0f))
			newValue = newValue * (fraction / abs( (int)fraction ));

		gSP.matrix.combined[0][(where - 0x20) >> 1] = newValue;

		fraction = modff( gSP.matrix.combined[0][((where - 0x20) >> 1) + 1], &integer );
		newValue = integer + _FIXED2FLOAT( _SHIFTR( num, 0, 16 ), 16 );

		// Make sure the sign isn't lost
		if ((integer == 0.0f) && (fraction != 0.0f))
			newValue = newValue * (fraction / abs( (int)fraction ));

		gSP.matrix.combined[0][((where - 0x20) >> 1) + 1] = newValue;
	}
}

void gSPModifyVertex( u32 _vtx, u32 _where, u32 _val )
{
	GraphicsDrawer & drawer = dwnd().getDrawer();

	SPVertex & vtx0 = drawer.getVertex(_vtx);
	switch (_where) {
		case G_MWO_POINT_RGBA:
			vtx0.r = _SHIFTR( _val, 24, 8 ) * 0.0039215689f;
			vtx0.g = _SHIFTR( _val, 16, 8 ) * 0.0039215689f;
			vtx0.b = _SHIFTR( _val, 8, 8 ) * 0.0039215689f;
			vtx0.a = _SHIFTR( _val, 0, 8 ) * 0.0039215689f;
			vtx0.modify |= MODIFY_RGBA;
			DebugMsg(DEBUG_NORMAL, "gSPModifyVertex: RGBA(%02f, %02f, %02f, %02f);\n", vtx0.r, vtx0.g, vtx0.b, vtx0.a);
			break;
		case G_MWO_POINT_ST:
			vtx0.s = _FIXED2FLOAT( (s16)_SHIFTR( _val, 16, 16 ), 5 ) / gSP.texture.scales;
			vtx0.t = _FIXED2FLOAT((s16)_SHIFTR(_val, 0, 16), 5) / gSP.texture.scalet;
			//vtx0.modify |= MODIFY_ST; // still neeed to divide by 2 in vertex shader if TexturePersp disabled
			DebugMsg(DEBUG_NORMAL, "gSPModifyVertex: ST(%02f, %02f);\n", vtx0.s, vtx0.t);
			break;
		case G_MWO_POINT_XYSCREEN:
			vtx0.x = _FIXED2FLOAT((s16)_SHIFTR(_val, 16, 16), 2);
			vtx0.y = _FIXED2FLOAT((s16)_SHIFTR(_val, 0, 16), 2);
			DebugMsg(DEBUG_NORMAL, "gSPModifyVertex: XY(%02f, %02f);\n", vtx0.x, vtx0.y);
			if ((config.generalEmulation.hacks & hack_ModifyVertexXyInShader) == 0) {
				vtx0.x = (vtx0.x - gSP.viewport.vtrans[0]) / gSP.viewport.vscale[0];
				if (gSP.viewport.vscale[0] < 0)
					vtx0.x = -vtx0.x;
				vtx0.x *= vtx0.w;

				if (dwnd().isAdjustScreen()) {
					const f32 adjustScale = dwnd().getAdjustScale();
					vtx0.x *= adjustScale;
					if (gSP.matrix.projection[3][2] == -1.f)
						vtx0.w *= adjustScale;
				}

				vtx0.y = -(vtx0.y - gSP.viewport.vtrans[1]) / gSP.viewport.vscale[1];
				if (gSP.viewport.vscale[1] < 0)
					vtx0.y = -vtx0.y;
				vtx0.y *= vtx0.w;
			} else {
				vtx0.modify |= MODIFY_XY;
				if (vtx0.w == 0.0f) {
					vtx0.w = 1.0f;
					vtx0.clip &= ~(CLIP_W);
				}
			}
			vtx0.clip &= ~(CLIP_POSX | CLIP_NEGX | CLIP_POSY | CLIP_NEGY);
		break;
		case G_MWO_POINT_ZSCREEN:
		{
			f32 scrZ = _FIXED2FLOAT((s16)_SHIFTR(_val, 16, 16), 15);
			DebugMsg(DEBUG_NORMAL, "gSPModifyVertex: Z(%02f);\n", vtx0.z);
			vtx0.z = (scrZ - gSP.viewport.vtrans[2]) / (gSP.viewport.vscale[2]);
			vtx0.clip &= ~CLIP_W;
			vtx0.modify |= MODIFY_Z;
		}
		break;
	}
}

void gSPNumLights( s32 n )
{
	if (n < 12) {
		gSP.numLights = n;
		gSP.changed |= CHANGED_LIGHT;
	} else {
		DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "// Setting an invalid number of lights\n");
	}

	DebugMsg(DEBUG_NORMAL, "gSPNumLights( %i );\n", n);
}

void gSPLightColor( u32 lightNum, u32 packedColor )
{
	--lightNum;

	if (lightNum < 8)
	{
		gSP.lights.rgb[lightNum][R] = _SHIFTR( packedColor, 24, 8 ) * 0.0039215689f;
		gSP.lights.rgb[lightNum][G] = _SHIFTR( packedColor, 16, 8 ) * 0.0039215689f;
		gSP.lights.rgb[lightNum][B] = _SHIFTR( packedColor, 8, 8 ) * 0.0039215689f;
		gSP.changed |= CHANGED_HW_LIGHT;
	}
	DebugMsg(DEBUG_NORMAL, "gSPLightColor( %i, 0x%08X );\n", lightNum, packedColor );
}

void gSPFogFactor( s16 fm, s16 fo )
{
	gSP.fog.multiplier = fm;
	gSP.fog.offset = fo;
	gSP.fog.multiplierf = _FIXED2FLOAT(fm, 8);
	gSP.fog.offsetf = _FIXED2FLOAT(fo, 8);

	gSP.changed |= CHANGED_FOGPOSITION;
	DebugMsg(DEBUG_NORMAL, "gSPFogFactor( %i, %i );\n", fm, fo);
}

void gSPPerspNormalize( u16 scale )
{
	DebugMsg(DEBUG_NORMAL| DEBUG_IGNORED, "gSPPerspNormalize( %i );\n", scale);
}

void gSPCoordMod(u32 _w0, u32 _w1)
{
	DebugMsg(DEBUG_NORMAL, "gSPCoordMod( %u, %u );\n", _w0, _w1);
	if ((_w0 & 8) != 0)
		return;
	u32 idx = _SHIFTR(_w0, 1, 2);
	u32 pos = _w0&0x30;
	if (pos == 0) {
		gSP.vertexCoordMod[0+idx] = (f32)(s16)_SHIFTR(_w1, 16, 16);
		gSP.vertexCoordMod[1+idx] = (f32)(s16)_SHIFTR(_w1, 0, 16);
	} else if (pos == 0x10) {
		assert(idx < 3);
		gSP.vertexCoordMod[4+idx] = _SHIFTR(_w1, 16, 16)/65536.0f;
		gSP.vertexCoordMod[5+idx] = _SHIFTR(_w1, 0, 16)/65536.0f;
		gSP.vertexCoordMod[12+idx] = gSP.vertexCoordMod[0+idx] + gSP.vertexCoordMod[4+idx];
		gSP.vertexCoordMod[13+idx] = gSP.vertexCoordMod[1+idx] + gSP.vertexCoordMod[5+idx];
	} else if (pos == 0x20) {
		gSP.vertexCoordMod[8+idx] = (f32)(s16)_SHIFTR(_w1, 16, 16);
		gSP.vertexCoordMod[9+idx] = (f32)(s16)_SHIFTR(_w1, 0, 16);
	}
}

void gSPTexture( f32 sc, f32 tc, u32 level, u32 tile, u32 on )
{
	gSP.texture.on = on;
	if (on == 0) {
		DebugMsg(DEBUG_NORMAL, "gSPTexture skipped b/c of off\n");
		return;
	}

	gSP.texture.scales = sc;
	gSP.texture.scalet = tc;

	if (gSP.texture.scales == 0.0f) gSP.texture.scales = 1.0f;
	if (gSP.texture.scalet == 0.0f) gSP.texture.scalet = 1.0f;

	gSP.texture.level = level;

	gSP.texture.tile = tile;
	gSP.textureTile[0] = &gDP.tiles[tile];
	gSP.textureTile[1] = &gDP.tiles[(tile + 1) & 7];

	gSP.changed |= CHANGED_TEXTURE;

	DebugMsg(DEBUG_NORMAL, "gSPTexture:  tile: %d, mipmap_lvl: %d, on: %d, s_scale: %f, t_scale: %f\n", tile, level, on, sc, tc);
}

void gSPEndDisplayList()
{
	if (RSP.PCi > 0)
		--RSP.PCi;
	else {
		DebugMsg( DEBUG_NORMAL, "End of display list, halting execution\n" );
		RSP.halt = true;
	}

	DebugMsg(DEBUG_NORMAL, "gSPEndDisplayList();\n\n");
}

void gSPGeometryMode( u32 clear, u32 set )
{
	gSP.geometryMode = (gSP.geometryMode & ~clear) | set;

	gSP.changed |= CHANGED_GEOMETRYMODE;

	DebugMsg(DEBUG_NORMAL, "gSPGeometryMode( %s%s%s%s%s%s%s%s%s%s, %s%s%s%s%s%s%s%s%s%s );\n",
		clear & G_SHADE ? "G_SHADE | " : "",
		clear & G_LIGHTING ? "G_LIGHTING | " : "",
		clear & G_SHADING_SMOOTH ? "G_SHADING_SMOOTH | " : "",
		clear & G_ZBUFFER ? "G_ZBUFFER | " : "",
		clear & G_TEXTURE_GEN ? "G_TEXTURE_GEN | " : "",
		clear & G_TEXTURE_GEN_LINEAR ? "G_TEXTURE_GEN_LINEAR | " : "",
		clear & G_CULL_FRONT ? "G_CULL_FRONT | " : "",
		clear & G_CULL_BACK ? "G_CULL_BACK | " : "",
		clear & G_FOG ? "G_FOG | " : "",
		clear & G_CLIPPING ? "G_CLIPPING" : "",
		set & G_SHADE ? "G_SHADE | " : "",
		set & G_LIGHTING ? "G_LIGHTING | " : "",
		set & G_SHADING_SMOOTH ? "G_SHADING_SMOOTH | " : "",
		set & G_ZBUFFER ? "G_ZBUFFER | " : "",
		set & G_TEXTURE_GEN ? "G_TEXTURE_GEN | " : "",
		set & G_TEXTURE_GEN_LINEAR ? "G_TEXTURE_GEN_LINEAR | " : "",
		set & G_CULL_FRONT ? "G_CULL_FRONT | " : "",
		set & G_CULL_BACK ? "G_CULL_BACK | " : "",
		set & G_FOG ? "G_FOG | " : "",
		set & G_CLIPPING ? "G_CLIPPING" : "" );
}

void gSPSetGeometryMode( u32 mode )
{
	gSP.geometryMode |= mode;

	gSP.changed |= CHANGED_GEOMETRYMODE;

	DebugMsg(DEBUG_NORMAL, "gSPSetGeometryMode( %s%s%s%s%s%s%s%s%s%s );\n",
		mode & G_SHADE ? "G_SHADE | " : "",
		mode & G_LIGHTING ? "G_LIGHTING | " : "",
		mode & G_SHADING_SMOOTH ? "G_SHADING_SMOOTH | " : "",
		mode & G_ZBUFFER ? "G_ZBUFFER | " : "",
		mode & G_TEXTURE_GEN ? "G_TEXTURE_GEN | " : "",
		mode & G_TEXTURE_GEN_LINEAR ? "G_TEXTURE_GEN_LINEAR | " : "",
		mode & G_CULL_FRONT ? "G_CULL_FRONT | " : "",
		mode & G_CULL_BACK ? "G_CULL_BACK | " : "",
		mode & G_FOG ? "G_FOG | " : "",
		mode & G_CLIPPING ? "G_CLIPPING" : "" );
}

void gSPClearGeometryMode( u32 mode )
{
	gSP.geometryMode &= ~mode;

	gSP.changed |= CHANGED_GEOMETRYMODE;

	DebugMsg(DEBUG_NORMAL, "gSPClearGeometryMode( %s%s%s%s%s%s%s%s%s%s );\n",
		mode & G_SHADE ? "G_SHADE | " : "",
		mode & G_LIGHTING ? "G_LIGHTING | " : "",
		mode & G_SHADING_SMOOTH ? "G_SHADING_SMOOTH | " : "",
		mode & G_ZBUFFER ? "G_ZBUFFER | " : "",
		mode & G_TEXTURE_GEN ? "G_TEXTURE_GEN | " : "",
		mode & G_TEXTURE_GEN_LINEAR ? "G_TEXTURE_GEN_LINEAR | " : "",
		mode & G_CULL_FRONT ? "G_CULL_FRONT | " : "",
		mode & G_CULL_BACK ? "G_CULL_BACK | " : "",
		mode & G_FOG ? "G_FOG | " : "",
		mode & G_CLIPPING ? "G_CLIPPING" : "" );
}

void gSPSetOtherMode_H(u32 _length, u32 _shift, u32 _data)
{
	const u32 mask = (((u64)1 << _length) - 1) << _shift;
	gDP.otherMode.h = (gDP.otherMode.h&(~mask)) | _data;

	if (mask & 0x00300000)  // cycle type
		gDP.changed |= CHANGED_CYCLETYPE;

	DebugMsg(DEBUG_NORMAL, "gSPSetOtherMode_H");
#ifdef DEBUG_DUMP
	std::string strRes;
	if (mask & 0x00000030) {
		strRes.append(AlphaDitherText[(gDP.otherMode.h>>4) & 3]);
		strRes.append(" | ");
	}

	if (mask & 0x000000C0) {
		strRes.append(ColorDitherText[(gDP.otherMode.h >> 6) & 3]);
		strRes.append(" | ");
	}

	if (mask & 0x00003000) {
		strRes.append(TextureFilterText[(gDP.otherMode.h & 0x00003000) >> 12]);
		strRes.append(" | ");
	}

	if (mask & 0x0000C000) {
		strRes.append(TextureLUTText[(gDP.otherMode.h & 0x0000C000) >> 14]);
		strRes.append(" | ");
	}

	if (mask & 0x00300000) {
		strRes.append(CycleTypeText[(gDP.otherMode.h & 0x00300000) >> 20]);
		strRes.append(" | ");
	}

	if (mask & 0x00010000) {
		strRes.append("LOD_en : ");
		strRes.append((gDP.otherMode.h & 0x00010000) ? "yes | " : "no | ");
	}

	if (mask & 0x00080000) {
		strRes.append("Persp_en : ");
		strRes.append((gDP.otherMode.h & 0x00080000) ? "yes" : "no");
	}

	DebugMsg(DEBUG_NORMAL, "( %s)", strRes.c_str());
#endif
	DebugMsg(DEBUG_NORMAL, " result: %08x\n", gDP.otherMode.h);
}

void gSPSetOtherMode_L(u32 _length, u32 _shift, u32 _data)
{
	const u32 mask = (((u64)1 << _length) - 1) << _shift;
	gDP.otherMode.l = (gDP.otherMode.l&(~mask)) | _data;

	if (mask & 0x00000003)  // alpha compare
		gDP.changed |= CHANGED_ALPHACOMPARE;

	if (mask & 0xFFFFFFF8)  // rendermode / blender bits
		gDP.changed |= CHANGED_RENDERMODE;

	DebugMsg(DEBUG_NORMAL, "gSPSetOtherMode_L");
#ifdef DEBUG_DUMP
	std::string strRes;

	if (mask & 0x00000003) {
		strRes.append(AlphaCompareText[gDP.otherMode.l & 0x00000003]);
		strRes.append(" | ");
	}

	if (mask & 0x00000004) {
		strRes.append(DepthSourceText[(gDP.otherMode.l & 0x00000004) >> 2]);
		strRes.append(" | ");
	}

	if (mask & 0xFFFFFFF8)  { // rendermode / blender bits
		strRes.append(" rendermode");
	}

	DebugMsg(DEBUG_NORMAL, "( %s)", strRes.c_str());
#endif
	DebugMsg(DEBUG_NORMAL, " result: %08x\n", gDP.otherMode.l);
}

void gSPLine3D( s32 v0, s32 v1, s32 flag )
{
	dwnd().getDrawer().drawLine(v0, v1, 1.5f);

	DebugMsg(DEBUG_NORMAL, "gSPLine3D( %i, %i, %i )\n", v0, v1, flag);
}

void gSPLineW3D( s32 v0, s32 v1, s32 wd, s32 flag )
{
	dwnd().getDrawer().drawLine(v0, v1, 1.5f + wd * 0.5f);

	DebugMsg(DEBUG_NORMAL, "gSPLineW3D( %i, %i, %i, %i )\n", v0, v1, wd, flag);
}

void gSPSetStatus(u32 sid, u32 val)
{
	assert(sid <= 12);
	gSP.status[sid>>2] = val;

	DebugMsg(DEBUG_NORMAL, "gSPSetStatus sid=%u val=%u\n", sid, val);
}

void gSPObjLoadTxtr( u32 tx )
{
	const u32 address = RSP_SegmentToPhysical( tx );
	uObjTxtr *objTxtr = (uObjTxtr*)&RDRAM[address];

	if ((gSP.status[objTxtr->block.sid >> 2] & objTxtr->block.mask) != objTxtr->block.flag) {
		switch (objTxtr->block.type) {
			case G_OBJLT_TXTRBLOCK:
				gDPSetTextureImage( 0, 1, 0, objTxtr->block.image );
				gDPSetTile( 0, 1, 0, objTxtr->block.tmem, 7, 0, 0, 0, 0, 0, 0, 0 );
				gDPLoadBlock( 7, 0, 0, ((objTxtr->block.tsize + 1) << 3) - 1, objTxtr->block.tline );
				DebugMsg(DEBUG_NORMAL, "gSPObjLoadTxtr: load block\n");
				break;
			case G_OBJLT_TXTRTILE:
				gDPSetTextureImage( 0, 1, (objTxtr->tile.twidth + 1) << 1, objTxtr->tile.image );
				gDPSetTile( 0, 1, (objTxtr->tile.twidth + 1) >> 2, objTxtr->tile.tmem, 0, 0, 0, 0, 0, 0, 0, 0 );
				gDPSetTile( 0, 1, (objTxtr->tile.twidth + 1) >> 2, objTxtr->tile.tmem, 7, 0, 0, 0, 0, 0, 0, 0 );
				gDPLoadTile( 7, 0, 0, (((objTxtr->tile.twidth + 1) << 1) - 1) << 2, (((objTxtr->tile.theight + 1) >> 2) - 1) << 2 );
				DebugMsg(DEBUG_NORMAL, "gSPObjLoadTxtr: load tile\n");
				break;
			case G_OBJLT_TLUT:
				gDPSetTextureImage( 0, 2, 1, objTxtr->tlut.image );
				gDPSetTile( 0, 2, 0, objTxtr->tlut.phead, 7, 0, 0, 0, 0, 0, 0, 0 );
				gDPLoadTLUT( 7, 0, 0, objTxtr->tlut.pnum << 2, 0 );
				DebugMsg(DEBUG_NORMAL, "gSPObjLoadTxtr: load tlut\n");
				break;
		}
		gSP.status[objTxtr->block.sid >> 2] = (gSP.status[objTxtr->block.sid >> 2] & ~objTxtr->block.mask) | (objTxtr->block.flag & objTxtr->block.mask);
	}
}

static
void gSPSetSpriteTile(const uObjSprite *_pObjSprite)
{
	const u32 w = max(_pObjSprite->imageW >> 5, 1);
	const u32 h = max(_pObjSprite->imageH >> 5, 1);

	gDPSetTile( _pObjSprite->imageFmt, _pObjSprite->imageSiz, _pObjSprite->imageStride, _pObjSprite->imageAdrs, 0, _pObjSprite->imagePal, G_TX_CLAMP, G_TX_CLAMP, 0, 0, 0, 0 );
	gDPSetTileSize( 0, 0, 0, (w - 1) << 2, (h - 1) << 2 );
	gSPTexture( 1.0f, 1.0f, 0, 0, TRUE );
}

struct ObjData
{
	f32 scaleW;
	f32 scaleH;
	u32 imageW;
	u32 imageH;
	f32 X0;
	f32 X1;
	f32 Y0;
	f32 Y1;
	bool flipS, flipT;
	ObjData(const uObjSprite *_pObjSprite)
	{
		scaleW = _FIXED2FLOAT(_pObjSprite->scaleW, 10);
		scaleH = _FIXED2FLOAT(_pObjSprite->scaleH, 10);
		imageW = _pObjSprite->imageW >> 5;
		imageH = _pObjSprite->imageH >> 5;
		X0 = _FIXED2FLOAT(_pObjSprite->objX, 2);
		X1 = X0 + imageW / scaleW;
		Y0 = _FIXED2FLOAT(_pObjSprite->objY, 2);
		Y1 = Y0 + imageH / scaleH;
		flipS = (_pObjSprite->imageFlags & 0x01) != 0;
		flipT = (_pObjSprite->imageFlags & 0x10) != 0;
	}
};

struct ObjCoordinates
{
	f32 ulx, uly, lrx, lry;
	f32 uls, ult, lrs, lrt;
	f32 z, w;

	ObjCoordinates(const uObjSprite *_pObjSprite, bool _useMatrix)
	{
		ObjData data(_pObjSprite);
		ulx = data.X0;
		lrx = data.X1;
		uly = data.Y0;
		lry = data.Y1;
		if (_useMatrix) {
			ulx = ulx/gSP.objMatrix.baseScaleX + gSP.objMatrix.X;
			lrx = lrx/gSP.objMatrix.baseScaleX + gSP.objMatrix.X;
			uly = uly/gSP.objMatrix.baseScaleY + gSP.objMatrix.Y;
			lry = lry/gSP.objMatrix.baseScaleY + gSP.objMatrix.Y;
		}

		uls = ult = 0;
		lrs = (f32)(data.imageW - 1);
		lrt = (f32)(data.imageH - 1);
		if (data.flipS) {
			uls = lrs;
			lrs = 0;
		}
		if (data.flipT) {
			ult = lrt;
			lrt = 0;
		}

		z = (gDP.otherMode.depthSource == G_ZS_PRIM) ? gDP.primDepth.z : gSP.viewport.nearz;
		w = 1.0f;
	}

	ObjCoordinates(const uObjScaleBg * _pObjScaleBg)
	{
		const f32 frameX = _FIXED2FLOAT(_pObjScaleBg->frameX, 2);
		const f32 frameY = _FIXED2FLOAT(_pObjScaleBg->frameY, 2);
		const f32 imageX = gSP.bgImage.imageX;
		const f32 imageY = gSP.bgImage.imageY;
		const f32 scaleW = gSP.bgImage.scaleW;
		const f32 scaleH = gSP.bgImage.scaleH;

		f32 frameW = _FIXED2FLOAT(_pObjScaleBg->frameW, 2);
		f32 frameH = _FIXED2FLOAT(_pObjScaleBg->frameH, 2);
		f32 imageW = (f32)(_pObjScaleBg->imageW>>2);
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
		}

		ulx = frameX;
		uly = frameY;
		lrx = frameX + min(imageW/scaleW, frameW);
		lry = frameY + min(imageH/scaleH, frameH);

		uls = imageX;
		ult = imageY;
		lrs = uls + (lrx - ulx) * scaleW;
		lrt = ult + (lry - uly) * scaleH;
		if (gDP.otherMode.cycleType != G_CYC_COPY) {
			if ((gSP.objRendermode&G_OBJRM_SHRINKSIZE_1) != 0) {
				lrs -= 1.0f / scaleW;
				lrt -= 1.0f / scaleH;
			} else if ((gSP.objRendermode&G_OBJRM_SHRINKSIZE_2) != 0) {
				lrs -= 1.0f;
				lrt -= 1.0f;
			}
		}

		if ((_pObjScaleBg->imageFlip & 0x01) != 0) {
			ulx = lrx;
			lrx = frameX;
		}

		z = (gDP.otherMode.depthSource == G_ZS_PRIM) ? gDP.primDepth.z : gSP.viewport.nearz;
		w = 1.0f;
	}
};

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
u16 _YUVtoRGBA(u8 y, u8 u, u8 v)
{
	float r = y + (1.370705f * (v - 128));
	float g = y - (0.698001f * (v - 128)) - (0.337633f * (u - 128));
	float b = y + (1.732446f * (u - 128));
	r *= 0.125f;
	g *= 0.125f;
	b *= 0.125f;
	//clipping the result
	if (r > 32) r = 32;
	if (g > 32) g = 32;
	if (b > 32) b = 32;
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

void gSPObjRectangle(u32 _sp)
{
	const u32 address = RSP_SegmentToPhysical(_sp);
	uObjSprite *objSprite = (uObjSprite*)&RDRAM[address];
	gSPSetSpriteTile(objSprite);
	ObjCoordinates objCoords(objSprite, false);
	gSPDrawObjRect(objCoords);
	DebugMsg(DEBUG_NORMAL, "gSPObjRectangle\n");
}

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
void _copyDepthBuffer()
{
	if (!config.frameBufferEmulation.enable)
		return;

	if (!gfxContext.isSupported(SpecialFeatures::BlitFramebuffer))
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
	gfxContext.bindFramebuffer(bufferTarget::READ_FRAMEBUFFER, ObjectHandle::null);

	// Set back current depth buffer
	dbList.saveBuffer(gDP.depthImageAddress);
}

static
void _loadBGImage(const uObjScaleBg * _bgInfo, bool _loadScale)
{
	gSP.bgImage.address = RSP_SegmentToPhysical( _bgInfo->imagePtr );

	const u32 imageW = _bgInfo->imageW >> 2;
	const u32 imageH = _bgInfo->imageH >> 2;
	if (imageW == 512 && (config.generalEmulation.hacks & hack_RE2) != 0) {
		gSP.bgImage.width = *REG.VI_WIDTH;
		gSP.bgImage.height = (imageH * imageW) / gSP.bgImage.width;
	} else {
		gSP.bgImage.width = imageW - imageW%2;
		gSP.bgImage.height = imageH - imageH%2;
	}
	gSP.bgImage.format = _bgInfo->imageFmt;
	gSP.bgImage.size = _bgInfo->imageSiz;
	gSP.bgImage.palette = _bgInfo->imagePal;
	gDP.tiles[0].textureMode = TEXTUREMODE_BGIMAGE;
	gSP.bgImage.imageX = _FIXED2FLOAT( _bgInfo->imageX, 5 );
	gSP.bgImage.imageY = _FIXED2FLOAT( _bgInfo->imageY, 5 );
	if (_loadScale) {
		gSP.bgImage.scaleW = _FIXED2FLOAT( _bgInfo->scaleW, 10 );
		gSP.bgImage.scaleH = _FIXED2FLOAT( _bgInfo->scaleH, 10 );
	} else
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

void gSPBgRect1Cyc( u32 _bg )
{
	const u32 address = RSP_SegmentToPhysical( _bg );
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

void gSPBgRectCopy( u32 _bg )
{
	const u32 address = RSP_SegmentToPhysical( _bg );
	uObjScaleBg *objBg = (uObjScaleBg*)&RDRAM[address];
	_loadBGImage(objBg, false);

	// See comment to gSPBgRect1Cyc
	if ((config.generalEmulation.hacks & hack_ZeldaMM) != 0 &&
		(gSP.bgImage.address == gDP.depthImageAddress || depthBufferList().findBuffer(gSP.bgImage.address) != nullptr)
	)
		_copyDepthBuffer();

	gSPTexture( 1.0f, 1.0f, 0, 0, TRUE );

	ObjCoordinates objCoords(objBg);
	gSPDrawObjRect(objCoords);

	DebugMsg(DEBUG_NORMAL, "gSPBgRectCopy\n");
}

void gSPObjSprite(u32 _sp)
{
	const u32 address = RSP_SegmentToPhysical( _sp );
	uObjSprite *objSprite = (uObjSprite*)&RDRAM[address];
	gSPSetSpriteTile(objSprite);
	ObjData data(objSprite);

	const f32 ulx = data.X0;
	const f32 uly = data.Y0;
	const f32 lrx = data.X1;
	const f32 lry = data.Y1;

	f32 uls = 0;
	f32 lrs = (f32)(data.imageW - 1);
	f32 ult = 0;
	f32 lrt = (f32)(data.imageH - 1);

	if (objSprite->imageFlags & 0x01) { // flipS
		uls = lrs;
		lrs = 0;
	}

	if (objSprite->imageFlags & 0x10) { // flipT
		ult = lrt;
		lrt = 0;
	}

	const float z = (gDP.otherMode.depthSource == G_ZS_PRIM) ? gDP.primDepth.z : gSP.viewport.nearz;

	GraphicsDrawer & drawer = dwnd().getDrawer();
	drawer.setDMAVerticesSize(4);
	SPVertex * pVtx = drawer.getDMAVerticesData();

	SPVertex & vtx0 = pVtx[0];
	vtx0.x = gSP.objMatrix.A * ulx + gSP.objMatrix.B * uly + gSP.objMatrix.X;
	vtx0.y = gSP.objMatrix.C * ulx + gSP.objMatrix.D * uly + gSP.objMatrix.Y;
	vtx0.z = z;
	vtx0.w = 1.0f;
	vtx0.s = uls;
	vtx0.t = ult;
	SPVertex & vtx1 = pVtx[1];
	vtx1.x = gSP.objMatrix.A * lrx + gSP.objMatrix.B * uly + gSP.objMatrix.X;
	vtx1.y = gSP.objMatrix.C * lrx + gSP.objMatrix.D * uly + gSP.objMatrix.Y;
	vtx1.z = z;
	vtx1.w = 1.0f;
	vtx1.s = lrs;
	vtx1.t = ult;
	SPVertex & vtx2 = pVtx[2];
	vtx2.x = gSP.objMatrix.A * ulx + gSP.objMatrix.B * lry + gSP.objMatrix.X;
	vtx2.y = gSP.objMatrix.C * ulx + gSP.objMatrix.D * lry + gSP.objMatrix.Y;
	vtx2.z = z;
	vtx2.w = 1.0f;
	vtx2.s = uls;
	vtx2.t = lrt;
	SPVertex & vtx3 = pVtx[3];
	vtx3.x = gSP.objMatrix.A * lrx + gSP.objMatrix.B * lry + gSP.objMatrix.X;
	vtx3.y = gSP.objMatrix.C * lrx + gSP.objMatrix.D * lry + gSP.objMatrix.Y;
	vtx3.z = z;
	vtx3.w = 1.0f;
	vtx3.s = lrs;
	vtx3.t = lrt;

	drawer.drawScreenSpaceTriangle(4);

	DebugMsg(DEBUG_NORMAL, "gSPObjSprite\n");
}

static
void _loadSpriteImage(const uSprite *_pSprite)
{
	gSP.bgImage.address = RSP_SegmentToPhysical( _pSprite->imagePtr );

	gSP.bgImage.width = _pSprite->stride;
	gSP.bgImage.height = _pSprite->imageY + _pSprite->imageH;
	gSP.bgImage.format = _pSprite->imageFmt;
	gSP.bgImage.size = _pSprite->imageSiz;
	gSP.bgImage.palette = 0;
	gDP.tiles[0].textureMode = TEXTUREMODE_BGIMAGE;
	gSP.bgImage.imageX = _pSprite->imageX;
	gSP.bgImage.imageY = _pSprite->imageY;
	gSP.bgImage.scaleW = gSP.bgImage.scaleH = 1.0f;

	if (config.frameBufferEmulation.enable != 0)
	{
		FrameBuffer *pBuffer = frameBufferList().findBuffer(gSP.bgImage.address);
		if (pBuffer != nullptr) {
			gDP.tiles[0].frameBufferAddress = pBuffer->m_startAddress;
			gDP.tiles[0].textureMode = TEXTUREMODE_FRAMEBUFFER_BG;
			gDP.tiles[0].loadType = LOADTYPE_TILE;
			gDP.changed |= CHANGED_TMEM;
		}
	}
}

void gSPSprite2DBase(u32 _base)
{
	DebugMsg(DEBUG_NORMAL, "gSPSprite2DBase\n");
	assert(RSP.nextCmd == 0xBE);
	const u32 address = RSP_SegmentToPhysical( _base );
	uSprite *pSprite = (uSprite*)&RDRAM[address];

	if (pSprite->tlutPtr != 0) {
		gDPSetTextureImage( 0, 2, 1, pSprite->tlutPtr );
		gDPSetTile( 0, 2, 0, 256, 7, 0, 0, 0, 0, 0, 0, 0 );
		gDPLoadTLUT( 7, 0, 0, 1020, 0 );

		if (pSprite->imageFmt != G_IM_FMT_RGBA)
			gDP.otherMode.textureLUT = G_TT_RGBA16;
		else
			gDP.otherMode.textureLUT = G_TT_NONE;
	} else
		gDP.otherMode.textureLUT = G_TT_NONE;

	_loadSpriteImage(pSprite);
	gSPTexture( 1.0f, 1.0f, 0, 0, TRUE );
	gDP.otherMode.texturePersp = 1;

	const f32 z = (gDP.otherMode.depthSource == G_ZS_PRIM) ? gDP.primDepth.z : gSP.viewport.nearz;
	const f32 w = 1.0f;

	f32 scaleX = 1.0f, scaleY = 1.0f;
	u32 flipX = 0, flipY = 0;
	do {
		u32 w0 = *(u32*)&RDRAM[RSP.PC[RSP.PCi]];
		u32 w1 = *(u32*)&RDRAM[RSP.PC[RSP.PCi] + 4];
		RSP.cmd = _SHIFTR( w0, 24, 8 );

		RSP.PC[RSP.PCi] += 8;
		RSP.nextCmd = _SHIFTR( *(u32*)&RDRAM[RSP.PC[RSP.PCi]], 24, 8 );

		if ( RSP.cmd == 0xBE ) { // gSPSprite2DScaleFlip
			scaleX  = _FIXED2FLOAT( _SHIFTR(w1, 16, 16), 10 );
			scaleY  = _FIXED2FLOAT( _SHIFTR(w1,  0, 16), 10 );
			flipX = _SHIFTR(w0, 8, 8);
			flipY = _SHIFTR(w0, 0, 8);
			continue;
		}
		// gSPSprite2DDraw
		const f32 frameX = _FIXED2FLOAT(((s16)_SHIFTR(w1, 16, 16)), 2);
		const f32 frameY = _FIXED2FLOAT(((s16)_SHIFTR(w1,  0, 16)), 2);
		const f32 frameW = pSprite->imageW / scaleX;
		const f32 frameH = pSprite->imageH / scaleY;

		f32 ulx, uly, lrx, lry;
		if (flipX != 0) {
			ulx = frameX + frameW;
			lrx = frameX;
		} else {
			ulx = frameX;
			lrx = frameX + frameW;
		}
		if (flipY != 0) {
			uly = frameY + frameH;
			lry = frameY;
		} else {
			uly = frameY;
			lry = frameY + frameH;
		}

		f32 uls = pSprite->imageX;
		f32 ult = pSprite->imageY;
		f32 lrs = uls + pSprite->imageW - 1;
		f32 lrt = ult + pSprite->imageH - 1;

		/* Hack for WCW Nitro. TODO : activate it later.
		if (WCW_NITRO) {
			gSP.bgImage.height /= scaleY;
			gSP.bgImage.imageY /= scaleY;
			ult /= scaleY;
			lrt /= scaleY;
			gSP.bgImage.width *= scaleY;
		}
		*/

		GraphicsDrawer & drawer = dwnd().getDrawer();
		drawer.setDMAVerticesSize(4);
		SPVertex * pVtx = drawer.getDMAVerticesData();

		SPVertex & vtx0 = pVtx[0];
		vtx0.x = ulx;
		vtx0.y = uly;
		vtx0.z = z;
		vtx0.w = w;
		vtx0.s = uls;
		vtx0.t = ult;
		SPVertex & vtx1 = pVtx[1];
		vtx1.x = lrx;
		vtx1.y = uly;
		vtx1.z = z;
		vtx1.w = w;
		vtx1.s = lrs;
		vtx1.t = ult;
		SPVertex & vtx2 = pVtx[2];
		vtx2.x = ulx;
		vtx2.y = lry;
		vtx2.z = z;
		vtx2.w = w;
		vtx2.s = uls;
		vtx2.t = lrt;
		SPVertex & vtx3 = pVtx[3];
		vtx3.x = lrx;
		vtx3.y = lry;
		vtx3.z = z;
		vtx3.w = w;
		vtx3.s = lrs;
		vtx3.t = lrt;

		if (pSprite->stride > 0)
			drawer.drawScreenSpaceTriangle(4);
	} while (RSP.nextCmd == 0xBD || RSP.nextCmd == 0xBE);
}

void gSPObjLoadTxSprite(u32 txsp)
{
	gSPObjLoadTxtr( txsp );
	gSPObjSprite( txsp + sizeof( uObjTxtr ) );
}

void gSPObjLoadTxRect(u32 txsp)
{
	gSPObjLoadTxtr(txsp);
	gSPObjRectangle(txsp + sizeof(uObjTxtr));
}

void gSPObjLoadTxRectR(u32 txsp)
{
	gSPObjLoadTxtr( txsp );
	gSPObjRectangleR( txsp + sizeof( uObjTxtr ) );
}

void gSPObjMatrix( u32 mtx )
{
	u32 address = RSP_SegmentToPhysical(mtx);
	uObjMtx *objMtx = (uObjMtx*)&RDRAM[address];

	gSP.objMatrix.A = _FIXED2FLOAT( objMtx->A, 16 );
	gSP.objMatrix.B = _FIXED2FLOAT( objMtx->B, 16 );
	gSP.objMatrix.C = _FIXED2FLOAT( objMtx->C, 16 );
	gSP.objMatrix.D = _FIXED2FLOAT( objMtx->D, 16 );
	gSP.objMatrix.X = _FIXED2FLOAT( objMtx->X, 2 );
	gSP.objMatrix.Y = _FIXED2FLOAT( objMtx->Y, 2 );
	gSP.objMatrix.baseScaleX = _FIXED2FLOAT( objMtx->BaseScaleX, 10 );
	gSP.objMatrix.baseScaleY = _FIXED2FLOAT( objMtx->BaseScaleY, 10 );

	DebugMsg(DEBUG_NORMAL, "gSPObjMatrix\n");
}

void gSPObjSubMatrix( u32 mtx )
{
	u32 address = RSP_SegmentToPhysical(mtx);
	uObjSubMtx *objMtx = (uObjSubMtx*)&RDRAM[address];
	gSP.objMatrix.X = _FIXED2FLOAT(objMtx->X, 2);
	gSP.objMatrix.Y = _FIXED2FLOAT(objMtx->Y, 2);
	gSP.objMatrix.baseScaleX = _FIXED2FLOAT(objMtx->BaseScaleX, 10);
	gSP.objMatrix.baseScaleY = _FIXED2FLOAT(objMtx->BaseScaleY, 10);

	DebugMsg(DEBUG_NORMAL, "gSPObjSubMatrix\n");
}

void gSPObjRendermode(u32 _mode)
{
	gSP.objRendermode = _mode;

	DebugMsg(DEBUG_NORMAL, "gSPObjRendermode(0x%08x)\n", _mode);
}

#ifndef __NEON_OPT
void(*gSPInverseTransformVector)(float vec[3], float mtx[4][4]) = gSPInverseTransformVector_default;
void(*gSPTransformVector)(float vtx[4], float mtx[4][4]) = gSPTransformVector_default;
#else
void gSPInverseTransformVector_NEON(float vec[3], float mtx[4][4]);
void gSPTransformVector_NEON(float vtx[4], float mtx[4][4]);
void(*gSPInverseTransformVector)(float vec[3], float mtx[4][4]) = gSPInverseTransformVector_NEON;
void(*gSPTransformVector)(float vtx[4], float mtx[4][4]) = gSPTransformVector_NEON;
#endif //__NEON_OPT

void gSPSetupFunctions()
{
	g_ConkerUcode = GBI.getMicrocodeType() == F3DEX2CBFD;
}
