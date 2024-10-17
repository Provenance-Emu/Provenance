#include "Turbo3D.h"
#include "N64.h"
#include "RSP.h"
#include "RDP.h"
#include "gSP.h"
#include "gDP.h"
#include "DisplayWindow.h"

/******************Turbo3D microcode*************************/

#define GT_FLAG_NOMTX		0x01	/* don't load the matrix */
#define GT_FLAG_NO_XFM		0x02	/* load vtx, use verbatim */
#define GT_FLAG_XFM_ONLY	0x04	/* xform vtx, write to *TriN */

struct T3DGlobState
{
	u16 pad0;
	u16 perspNorm;
	u32 flag;
	u32 othermode0;
	u32 othermode1;
	u32 segBases[16];
	/* the viewport to use */
	s16 vsacle1;
	s16 vsacle0;
	s16 vsacle3;
	s16 vsacle2;
	s16 vtrans1;
	s16 vtrans0;
	s16 vtrans3;
	s16 vtrans2;
	u32 rdpCmds;
};

struct T3DState
{
	u32 renderState;	/* render state */
	u32 textureState;	/* texture state */
	u8 flag;
	u8 triCount;	/* how many tris? */
	u8 vtxV0;		/* where to load verts? */
	u8 vtxCount;	/* how many verts? */
	u32 rdpCmds;	/* ptr (segment address) to RDP DL */
	u32 othermode0;
	u32 othermode1;
};

struct T3DTriN
{
	u8	flag, v2, v1, v0;	/* flag is which one for flat shade */
};

struct VtxOut {
	s16 yscrn; /* x,y screen coordinates are SSSS10.2 */
	s16 xscrn;
	s32 zscrn; /* z screen is S15.16 */

	s16 t;
	s16 s;

	union {
		struct
		{
			u8 a;
			u8 b;
			u8 g;
			u8 r;
		} color;
		struct
		{
			s8 a;
			s8 z;	// b
			s8 y;	//g
			s8 x;	//r
		} normal;
	};
};

static
void Turbo3D_ProcessRDP(u32 _cmds)
{
	u32 addr = RSP_SegmentToPhysical(_cmds) >> 2;
	if (addr != 0) {
		RSP.LLE = true;
		u32 w0 = ((u32*)RDRAM)[addr++];
		u32 w1 = ((u32*)RDRAM)[addr++];
		RSP.cmd = _SHIFTR( w0, 24, 8 );
		while (w0 + w1 != 0) {
			GBI.cmd[RSP.cmd]( w0, w1 );
			w0 = ((u32*)RDRAM)[addr++];
			w1 = ((u32*)RDRAM)[addr++];
			RSP.cmd = _SHIFTR( w0, 24, 8 );
			if (RSP.cmd == G_TEXRECT || RSP.cmd == G_TEXRECTFLIP) {
				RDP.w2 = ((u32*)RDRAM)[addr++];
				RDP.w3 = ((u32*)RDRAM)[addr++];
			}
		}
		RSP.LLE = false;
	}
}

static
void Turbo3D_LoadGlobState(u32 pgstate)
{
	const u32 addr = RSP_SegmentToPhysical(pgstate);
	T3DGlobState *gstate = (T3DGlobState*)&RDRAM[addr];
	const u32 w0 = gstate->othermode0;
	const u32 w1 = gstate->othermode1;
	gDPSetOtherMode( _SHIFTR( w0, 0, 24 ),	// mode0
					 w1 );					// mode1

	for (int s = 0; s < 16; ++s)
		gSPSegment(s, gstate->segBases[s] & 0x00FFFFFF);

	gSPViewport(pgstate + 80);

	Turbo3D_ProcessRDP(gstate->rdpCmds);
}

static
void Turbo3D_LoadObject(u32 pstate, u32 pvtx, u32 ptri)
{
	u32 addr = RSP_SegmentToPhysical(pstate);
	T3DState *ostate = (T3DState*)&RDRAM[addr];
	const u32 tile = (ostate->textureState)&7;
	gSP.texture.tile = tile;
	gSP.textureTile[0] = &gDP.tiles[tile];
	gSP.textureTile[1] = &gDP.tiles[(tile + 1) & 7];
	gSP.texture.scales = 1.0f;
	gSP.texture.scalet = 1.0f;

	const u32 w0 = ostate->othermode0;
	const u32 w1 = ostate->othermode1;
	gDPSetOtherMode( _SHIFTR( w0, 0, 24 ),	// mode0
					 w1 );					// mode1

	gSPSetGeometryMode(ostate->renderState);

	if (ostate->flag != GT_FLAG_NOMTX)
		gSPForceMatrix(pstate + sizeof(T3DState));

	gSPClearGeometryMode(G_LIGHTING);
	gSPClearGeometryMode(G_FOG);
	gSPSetGeometryMode(G_SHADING_SMOOTH);

	if (pvtx != 0)
		gSPVertex(pvtx, ostate->vtxCount, ostate->vtxV0);

	Turbo3D_ProcessRDP(ostate->rdpCmds);

	GraphicsDrawer & drawer = dwnd().getDrawer();
	if (ptri != 0) {
		addr = RSP_SegmentToPhysical(ptri);
		if (ostate->flag != GT_FLAG_NO_XFM) {
			for (int t = 0; t < ostate->triCount; ++t) {
				T3DTriN * tri = (T3DTriN*)&RDRAM[addr];
				addr += 4;
				gSPTriangle(tri->v0, tri->v1, tri->v2);
			}
			drawer.drawTriangles();
		} else {
			const u32 vtxAddr = RSP_SegmentToPhysical(pvtx);
			const VtxOut *pVertices = (VtxOut*)&RDRAM[vtxAddr];
			for (u32 i = 0; i < ostate->vtxCount; ++i) {
				SPVertex & vtx = drawer.getVertex(i);
				vtx.x = _FIXED2FLOAT(pVertices[i].xscrn, 2);
				vtx.y = _FIXED2FLOAT(pVertices[i].yscrn, 2);
				vtx.z = _FIXED2FLOAT(pVertices[i].zscrn, 16);
				vtx.w = 1.0f;
			}
			for (int t = 0; t < ostate->triCount; ++t) {
				T3DTriN * tri = (T3DTriN*)&RDRAM[addr];
				addr += 4;
				u32 vtxIdx[3] = { tri->v0, tri->v1, tri->v2 };
				for (u32 i = 0; i < 3; ++i) {
					SPVertex & vtx = drawer.getCurrentDMAVertex();
					vtx = drawer.getVertex(vtxIdx[i]);
				}
			}
			drawer.drawScreenSpaceTriangle(drawer.getDMAVerticesCount(), graphics::drawmode::TRIANGLES);
		}
	}
}

void RunTurbo3D()
{
	while (true) {
		u32 addr = RSP.PC[RSP.PCi] >> 2;
		const u32 pgstate = ((u32*)RDRAM)[addr++];
		const u32 pstate = ((u32*)RDRAM)[addr++];
		const u32 pvtx = ((u32*)RDRAM)[addr++];
		const u32 ptri = ((u32*)RDRAM)[addr];
		if (pstate == 0) {
			RSP.halt = true;
			break;
		}
		if (pgstate != 0)
			Turbo3D_LoadGlobState(pgstate);
		Turbo3D_LoadObject(pstate, pvtx, ptri);
		// Go to the next instruction
		RSP.PC[RSP.PCi] += 16;
	};
}
