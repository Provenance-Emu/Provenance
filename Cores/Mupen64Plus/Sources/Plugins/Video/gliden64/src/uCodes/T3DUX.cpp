#include "T3DUX.h"
#include "N64.h"
#include "RSP.h"
#include "RDP.h"
#include "gSP.h"
#include "gDP.h"
#include "DisplayWindow.h"

/******************T3DUX microcode*************************/

struct T3DUXGlobState
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

struct T3DUXState
{
	u32 renderState;	/* render state */

	u8 dmemVtxAddr;
	u8 vtxCount;	/* number of verts */
	u8 texmode;
	u8 geommode;

	u8 dmemVtxAttribsAddr;
	u8 attribsCount;	/* number of colors and texture coords */
	u8 matrixFlag;
	u8 triCount;	/* how many tris? */

	u32 rdpCmds;	/* ptr (segment address) to RDP DL */
	u32 othermode0;
	u32 othermode1;
};


struct T3DUXTriN
{
	u8	flag, v2, v1, v0; /* flag is which one for flat shade */
	u8	pal, v2tex, v1tex, v0tex; /* indexes in texture coords list */
};

static u32 t32uxSetTileW0 = 0;
static u32 t32uxSetTileW1 = 0;

static
void T3DUX_ProcessRDP(u32 _cmds)
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
			switch (RSP.cmd) {
			case G_TEXRECT:
			case G_TEXRECTFLIP:
				RDP.w2 = ((u32*)RDRAM)[addr++];
				RDP.w3 = ((u32*)RDRAM)[addr++];
				break;
			case G_SETTILE:
				t32uxSetTileW0 = w0;
				t32uxSetTileW1 = w1;
				break;
			}
		}
		RSP.LLE = false;
	}
}

static
void T3DUX_LoadGlobState(u32 pgstate)
{
	const u32 addr = RSP_SegmentToPhysical(pgstate);
	T3DUXGlobState *gstate = (T3DUXGlobState*)&RDRAM[addr];
	const u32 w0 = gstate->othermode0;
	const u32 w1 = gstate->othermode1;
	gDPSetOtherMode( _SHIFTR( w0, 0, 24 ),	// mode0
					 w1 );					// mode1

	for (int s = 0; s < 16; ++s)
		gSPSegment(s, gstate->segBases[s] & 0x00FFFFFF);

	gSPViewport(pgstate + 80);

	T3DUX_ProcessRDP(gstate->rdpCmds);
}

static
void T3DUX_LoadObject(u32 pstate, u32 pvtx, u32 ptri, u32 pcol)
{
	T3DUXState *ostate = (T3DUXState*)&RDRAM[RSP_SegmentToPhysical(pstate)];
	// TODO: fix me
	const u32 tile = 0;
	gSP.texture.tile = tile;
	gSP.textureTile[0] = &gDP.tiles[tile];
	gSP.textureTile[1] = &gDP.tiles[(tile + 1) & 7];
	gSP.texture.scales = 1.0f;
	gSP.texture.scalet = 1.0f;

	{
		const u32 w0 = ostate->othermode0;
		const u32 w1 = ostate->othermode1;
		gDPSetOtherMode(
			_SHIFTR(w0, 0, 24),	// mode0
			w1);				// mode1
	}

	if ((ostate->matrixFlag & 1) == 0) //load matrix
		gSPForceMatrix(pstate + sizeof(T3DUXState));

	gSPClearGeometryMode(G_LIGHTING | G_FOG);
	gSPSetGeometryMode(ostate->renderState | G_SHADING_SMOOTH | G_SHADE | G_ZBUFFER | G_CULL_BACK);

	if (pvtx != 0) //load vtx
		gSPT3DUXVertex(pvtx, ostate->vtxCount, pcol);

	T3DUX_ProcessRDP(ostate->rdpCmds);

	if (ptri == 0)
		return;

	GraphicsDrawer & drawer = dwnd().getDrawer();
	const u32 coladdr = RSP_SegmentToPhysical(pcol);
	const T3DUXTriN * tri = (const T3DUXTriN*)&RDRAM[RSP_SegmentToPhysical(ptri)];
	u8 pal = _SHIFTR(t32uxSetTileW1, 20, 4);
	t32uxSetTileW1 &= 0xFF0FFFFF;
	const bool flatShading = (ostate->geommode & 0x0F) == 0;
	const bool texturing = ostate->texmode != 1;
	f32 flatr, flatg, flatb, flata;

	drawer.setDMAVerticesSize(ostate->triCount * 3);
	SPVertex * pVtx = drawer.getDMAVerticesData();
	for (int t = 0; t < ostate->triCount; ++t, ++tri) {
		if (texturing && tri->pal != 0) {
			const u32 w1 = t32uxSetTileW1 | (tri->pal << 20);
			const u32 newPal = _SHIFTR(w1, 20, 4);
			if (pal != newPal) {
				drawer.drawDMATriangles(static_cast<u32>(pVtx - drawer.getDMAVerticesData()));
				pVtx = drawer.getDMAVerticesData();
				pal = newPal;
				RDP_SetTile(t32uxSetTileW0, w1);
			}
		}

		if (tri->v0 >= ostate->vtxCount || tri->v1 >= ostate->vtxCount || tri->v2 >= ostate->vtxCount)
			continue;

		if (drawer.isClipped(tri->v0, tri->v1, tri->v2))
			continue;

		if (flatShading) {
			struct T3DUXColor
			{
				u8 a;
				u8 b;
				u8 g;
				u8 r;
			} color = *(T3DUXColor*)&RDRAM[coladdr + ((tri->flag << 2) & 0x03FC)];
			flata = _FIXED2FLOAT(color.a, 8);
			flatb = _FIXED2FLOAT(color.b, 8);
			flatg = _FIXED2FLOAT(color.g, 8);
			flatr = _FIXED2FLOAT(color.r, 8);
		}

		u32 vtxIdx[3] = { tri->v0, tri->v1, tri->v2 };
		u32 texIdx[3] = { tri->v0tex, tri->v1tex, tri->v2tex };
		for (u32 v = 0; v < 3; ++v) {
			*pVtx = drawer.getVertex(vtxIdx[v]);

			if (texturing) {
				u32 texcoords = *(const u32*)&RDRAM[coladdr + (texIdx[v] << 2)];
				pVtx->s = _FIXED2FLOAT(_SHIFTR(texcoords, 16, 16), 5);
				pVtx->t = _FIXED2FLOAT(_SHIFTR(texcoords, 0, 16), 5);
			} else {
				pVtx->s = 0.0f;
				pVtx->t = 0.0f;
			}

			if (flatShading) {
				pVtx->r = flatr;
				pVtx->g = flatg;
				pVtx->b = flatb;
				pVtx->a = flata;
			}

			++pVtx;
		}
	}

	drawer.drawDMATriangles(static_cast<u32>(pVtx - drawer.getDMAVerticesData()));
}

void RunT3DUX()
{
	while (true) {
		u32 addr = RSP.PC[RSP.PCi] >> 2;
		const u32 pgstate = ((u32*)RDRAM)[addr++];
		const u32 pstate = ((u32*)RDRAM)[addr++];
		const u32 pvtx = ((u32*)RDRAM)[addr++];
		const u32 ptri = ((u32*)RDRAM)[addr++];
		const u32 pcol = ((u32*)RDRAM)[addr++];
		//const u32 pstore = ((u32*)RDRAM)[addr];
		if (pstate == 0) {
			RSP.halt = true;
			break;
		}
		if (pgstate != 0)
			T3DUX_LoadGlobState(pgstate);
		T3DUX_LoadObject(pstate, pvtx, ptri, pcol);
		// Go to the next instruction
		RSP.PC[RSP.PCi] += 24;
	};
}
