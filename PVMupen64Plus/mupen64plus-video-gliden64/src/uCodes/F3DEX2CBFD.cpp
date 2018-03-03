#include <GLideN64.h>
#include <DebugDump.h>
#include "F3D.h"
#include "F3DEX.h"
#include "F3DEX2.h"
#include "F3DEX2CBFD.h"
#include <N64.h>
#include <RSP.h>
#include <RDP.h>
#include <gSP.h>
#include <gDP.h>
#include <GBI.h>

void F3DEX2CBFD_Vtx( u32 w0, u32 w1 )
{
	u32 n = _SHIFTR( w0, 12, 8 );

	gSPCBFDVertex( w1, n, _SHIFTR( w0, 1, 7 ) - n );
}

void F3DEX2CBFD_MoveWord( u32 w0, u32 w1 )
{
	switch (_SHIFTR( w0, 16, 8 ))
	{
		case G_MW_NUMLIGHT:
			gSPNumLights( w1 / 48 );
			break;
		case G_MW_CLIP:
			gSPClipRatio( w1 );
			break;
		case G_MW_SEGMENT:
			gSPSegment( _SHIFTR( w0, 0, 16 ) >> 2, w1 & 0x00FFFFFF );
			break;
		case G_MW_FOG:
			gSPFogFactor( (s16)_SHIFTR( w1, 16, 16 ), (s16)_SHIFTR( w1, 0, 16 ) );
			break;
		case G_MW_PERSPNORM:
			gSPPerspNormalize( w1 );
			break;
		case G_MW_COORD_MOD:
			gSPCoordMod( w0, w1 );
			break;
	}
}

void F3DEX2CBFD_MoveMem( u32 w0, u32 w1 )
{
	switch (_SHIFTR( w0, 0, 8 ))
	{
		case F3DEX2_MV_VIEWPORT:
			gSPViewport( w1 );
			break;
		case G_MV_LIGHT:
			{
			const u32 offset = _SHIFTR(w0, 5, 14);
			const u32 n = offset / 48;
			if (n < 2)
				gSPLookAt(w1, n);
			else
				gSPLightCBFD(w1, n - 2);
			}
			break;
		case G_MV_NORMALES:
			gSPSetVertexNormaleBase(w1);
			break;
	}
}

void F3DEX2CBFD_Tri4( u32 w0, u32 w1 )
{
	gSP4Triangles( _SHIFTR( w0, 23, 5 ), _SHIFTR( w0, 18, 5 ), (_SHIFTR( w0, 15, 3 )<<2)|_SHIFTR( w1, 30, 2 ),
				   _SHIFTR( w0, 10, 5 ), _SHIFTR( w0,  5, 5 ), _SHIFTR( w0,  0, 5 ),
				   _SHIFTR( w1, 25, 5 ), _SHIFTR( w1, 20, 5 ), _SHIFTR( w1, 15, 5 ),
				   _SHIFTR( w1, 10, 5 ), _SHIFTR( w1,  5, 5 ), _SHIFTR( w1,  0, 5 ) );
}

void F3DEX2CBFD_Init()
{
	gSPSetupFunctions();
	// Set GeometryMode flags
	GBI_InitFlags( F3DEX2 );

	GBI.PCStackSize = 18;

	// GBI Command						Command Value				Command Function
	GBI_SetGBI( G_RDPHALF_2,			F3DEX2_RDPHALF_2,			F3D_RDPHalf_2 );
	GBI_SetGBI( G_SETOTHERMODE_H,		F3DEX2_SETOTHERMODE_H,		F3DEX2_SetOtherMode_H );
	GBI_SetGBI( G_SETOTHERMODE_L,		F3DEX2_SETOTHERMODE_L,		F3DEX2_SetOtherMode_L );
	GBI_SetGBI( G_RDPHALF_1,			F3DEX2_RDPHALF_1,			F3D_RDPHalf_1 );
	GBI_SetGBI( G_SPNOOP,				F3DEX2_SPNOOP,				F3D_SPNoOp );
	GBI_SetGBI( G_ENDDL,				F3DEX2_ENDDL,				F3D_EndDL );
	GBI_SetGBI( G_DL,					F3DEX2_DL,					F3D_DList );
	GBI_SetGBI( G_LOAD_UCODE,			F3DEX2_LOAD_UCODE,			F3DEX_Load_uCode );
	GBI_SetGBI( G_MOVEMEM,				F3DEX2_MOVEMEM,				F3DEX2CBFD_MoveMem );
	GBI_SetGBI( G_MOVEWORD,				F3DEX2_MOVEWORD,			F3DEX2CBFD_MoveWord );
	GBI_SetGBI( G_MTX,					F3DEX2_MTX,					F3DEX2_Mtx );
	GBI_SetGBI( G_GEOMETRYMODE,			F3DEX2_GEOMETRYMODE,		F3DEX2_GeometryMode );
	GBI_SetGBI( G_POPMTX,				F3DEX2_POPMTX,				F3DEX2_PopMtx );
	GBI_SetGBI( G_TEXTURE,				F3DEX2_TEXTURE,				F3DEX2_Texture );
	GBI_SetGBI( G_DMA_IO,				F3DEX2_DMA_IO,				F3DEX2_DMAIO );
	GBI_SetGBI( G_SPECIAL_1,			F3DEX2_SPECIAL_1,			F3DEX2_Special_1 );
	GBI_SetGBI( G_SPECIAL_2,			F3DEX2_SPECIAL_2,			F3DEX2_Special_2 );
	GBI_SetGBI( G_SPECIAL_3,			F3DEX2_SPECIAL_3,			F3DEX2_Special_3 );

	GBI_SetGBI( G_VTX,					F3DEX2_VTX,					F3DEX2CBFD_Vtx );
	GBI_SetGBI( G_MODIFYVTX,			F3DEX2_MODIFYVTX,			F3DEX_ModifyVtx );
	GBI_SetGBI(	G_CULLDL,				F3DEX2_CULLDL,				F3DEX_CullDL );
	GBI_SetGBI( G_BRANCH_Z,				F3DEX2_BRANCH_Z,			F3DEX_Branch_Z );
	GBI_SetGBI( G_TRI1,					F3DEX2_TRI1,				F3DEX2_Tri1 );
	GBI_SetGBI( G_TRI2,					F3DEX2_TRI2,				F3DEX_Tri2 );
	GBI_SetGBI( G_QUAD,					F3DEX2_QUAD,				F3DEX2_Quad );
	GBI_SetGBI( G_LINE3D,				F3DEX2_LINE3D,				F3DEX2_Line3D );
	for (u32 i = 0; i < 16; ++i)
		GBI.cmd[F3DEX2CBFD_TRI4+i] = F3DEX2CBFD_Tri4;
}
