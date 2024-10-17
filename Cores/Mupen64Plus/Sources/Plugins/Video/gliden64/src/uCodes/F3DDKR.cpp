#include "GLideN64.h"
#include "DebugDump.h"
#include "F3D.h"
#include "F3DDKR.h"
#include "N64.h"
#include "RSP.h"
#include "RDP.h"
#include "gSP.h"
#include "gDP.h"
#include "GBI.h"

void F3DDKR_DMA_Mtx( u32 w0, u32 w1 )
{
	if (_SHIFTR( w0, 0, 16 ) != 64) {
		DebugMsg(DEBUG_NORMAL | DEBUG_ERROR, "G_MTX: address = 0x%08X    length = %i    params = 0x%02X\n", w1, _SHIFTR(w0, 0, 16), _SHIFTR(w0, 16, 8));
		return;
	}

	u32 index = _SHIFTR( w0, 16, 4 );
	u32 multiply;

	if (index == 0) {// DKR
		index = _SHIFTR( w0, 22, 2 );
		multiply = 0;
	}
	else { // JFG
		multiply = _SHIFTR( w0, 23, 1 );
	}

	gSPDMAMatrix( w1, index, multiply );
}

void F3DDKR_DMA_Vtx( u32 w0, u32 w1 )
{
	if ((w0 & F3DDKR_VTX_APPEND)) {
		if (gSP.matrix.billboard)
			gSP.vertexi = 1;
	} else
		gSP.vertexi = 0;

	u32 n = _SHIFTR( w0, 19, 5 ) + 1;

	gSPDMAVertex( w1, n, gSP.vertexi + _SHIFTR( w0, 9, 5 ) );

	gSP.vertexi += n;
}

void F3DJFG_DMA_Vtx(u32 w0, u32 w1)
{
	if ((w0 & F3DDKR_VTX_APPEND)) {
		if (gSP.matrix.billboard)
			gSP.vertexi = 1;
	} else
		gSP.vertexi = 0;

	u32 n = _SHIFTR(w0, 19, 5);

	gSPDMAVertex(w1, n, gSP.vertexi + _SHIFTR(w0, 9, 5));

	gSP.vertexi += n;
}

void F3DDKR_DMA_Tri(u32 w0, u32 w1)
{
	gSPDMATriangles( w1, _SHIFTR( w0, 4, 12 ) );
	gSP.vertexi = 0;
}

void F3DDKR_DMA_DList( u32 w0, u32 w1 )
{
	gSPDlistCount(_SHIFTR(w0, 16, 8), w1);
}

void F3DDKR_DMA_Offsets( u32 w0, u32 w1 )
{
	gSPSetDMAOffsets( _SHIFTR( w0, 0, 24 ), _SHIFTR( w1, 0, 24 ) );
}

void F3DDKR_DMA_Tex_Offset(u32 w0, u32 w1)
{
	gSPSetDMATexOffset(w1);
}

void F3DDKR_MoveWord( u32 w0, u32 w1 )
{
	switch (_SHIFTR( w0, 0, 8 )) {
		case 0x02:
			gSP.matrix.billboard = w1 & 1;
			break;
		case 0x0A:
			gSP.matrix.modelViewi = _SHIFTR( w1, 6, 2 );
			gSP.changed |= CHANGED_MATRIX;
			break;
		default:
			F3D_MoveWord( w0, w1 );
			break;
	}
}

void F3DDKR_Init()
{
	gSPSetupFunctions();
	// Set GeometryMode flags
	GBI_InitFlags( F3D );

	GBI.PCStackSize = 10;

	//          GBI Command             Command Value			Command Function
	GBI_SetGBI( G_SPNOOP,				F3D_SPNOOP,				F3D_SPNoOp );
	GBI_SetGBI( G_DMA_MTX,				F3DDKR_DMA_MTX,			F3DDKR_DMA_Mtx );
	GBI_SetGBI( G_DMA_TEX_OFFSET,		F3DDKR_DMA_TEX_OFFSET,	F3DDKR_DMA_Tex_Offset );
	GBI_SetGBI( G_MOVEMEM,				F3D_MOVEMEM,			F3D_MoveMem );
	GBI_SetGBI( G_DMA_VTX,				F3DDKR_DMA_VTX,			F3DDKR_DMA_Vtx );
	GBI_SetGBI( G_DL,					F3D_DL,					F3D_DList );
	GBI_SetGBI( G_DMA_DL,				F3DDKR_DMA_DL,			F3DDKR_DMA_DList );
	GBI_SetGBI( G_DMA_TRI,				F3DDKR_DMA_TRI,			F3DDKR_DMA_Tri );

	GBI_SetGBI( G_DMA_OFFSETS,			F3DDKR_DMA_OFFSETS,		F3DDKR_DMA_Offsets );
	GBI_SetGBI( G_CULLDL,				F3D_CULLDL,				F3D_CullDL );
	GBI_SetGBI( G_MOVEWORD,				F3D_MOVEWORD,			F3DDKR_MoveWord );
	GBI_SetGBI( G_TEXTURE,				F3D_TEXTURE,			F3D_Texture );
	GBI_SetGBI( G_SETOTHERMODE_H,		F3D_SETOTHERMODE_H,		F3D_SetOtherMode_H );
	GBI_SetGBI( G_SETOTHERMODE_L,		F3D_SETOTHERMODE_L,		F3D_SetOtherMode_L );
	GBI_SetGBI( G_ENDDL,				F3D_ENDDL,				F3D_EndDL );
	GBI_SetGBI( G_SETGEOMETRYMODE,		F3D_SETGEOMETRYMODE,	F3D_SetGeometryMode );
	GBI_SetGBI( G_CLEARGEOMETRYMODE,	F3D_CLEARGEOMETRYMODE,	F3D_ClearGeometryMode );
	GBI_SetGBI( G_QUAD,					F3D_QUAD,				F3D_Quad );
	GBI_SetGBI( G_RDPHALF_1,			F3D_RDPHALF_1,			F3D_RDPHalf_1 );
	GBI_SetGBI( G_RDPHALF_2,			F3D_RDPHALF_2,			F3D_RDPHalf_2 );
	GBI_SetGBI( G_RDPHALF_CONT,			F3D_RDPHALF_CONT,		F3D_RDPHalf_Cont );

	gSPSetDMAOffsets( 0, 0 );
}

void F3DJFG_Init()
{
	F3DDKR_Init();
	GBI_SetGBI(G_DMA_VTX, F3DDKR_DMA_VTX, F3DJFG_DMA_Vtx);
}
