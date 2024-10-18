#include <assert.h>
#include "GLideN64.h"
#include "DebugDump.h"
#include "F3D.h"
#include "F3DSETA.h"
#include "N64.h"
#include "RSP.h"
#include "RDP.h"
#include "gSP.h"
#include "gDP.h"
#include "GBI.h"

#define F3DSETA_PERSPNORM	0xB4
#define F3DSETA_RDPHALF_1	0xB3
#define F3DSETA_RDPHALF_2	0xB2
#define F3DSETA_RDPHALF_CONT	0xB1

#define F3DSETA_MW_NUMLIGHT	0x00
#define F3DSETA_MW_CLIP		0x02
#define F3DSETA_MW_SEGMENT	0x04
#define F3DSETA_MW_FOG		0x06
#define F3DSETA_MW_LIGHTCOL	0x08

void F3DSETA_MoveWord(u32 w0, u32 w1)
{
	switch (_SHIFTR( w0, 8, 8 )) {
		case F3DSETA_MW_NUMLIGHT:
			gSPNumLights( ((w1 - 0x80000000) >> 5) - 1 );
			break;
		case F3DSETA_MW_CLIP:
			gSPClipRatio( w1 );
			break;
		case F3DSETA_MW_SEGMENT:
			gSPSegment( _SHIFTR( w0, 10, 4 ), w1 & 0x00FFFFFF );
			break;
		case F3DSETA_MW_FOG:
			gSPFogFactor( (s16)_SHIFTR( w1, 16, 16 ), (s16)_SHIFTR( w1, 0, 16 ) );
			break;
		case F3DSETA_MW_LIGHTCOL:
			switch (_SHIFTR( w0, 0, 8 ))
			{
				case F3D_MWO_aLIGHT_1:
					gSPLightColor( LIGHT_1, w1 );
					break;
				case F3D_MWO_aLIGHT_2:
					gSPLightColor( LIGHT_2, w1 );
					break;
				case F3D_MWO_aLIGHT_3:
					gSPLightColor( LIGHT_3, w1 );
					break;
				case F3D_MWO_aLIGHT_4:
					gSPLightColor( LIGHT_4, w1 );
					break;
				case F3D_MWO_aLIGHT_5:
					gSPLightColor( LIGHT_5, w1 );
					break;
				case F3D_MWO_aLIGHT_6:
					gSPLightColor( LIGHT_6, w1 );
					break;
				case F3D_MWO_aLIGHT_7:
					gSPLightColor( LIGHT_7, w1 );
					break;
				case F3D_MWO_aLIGHT_8:
					gSPLightColor( LIGHT_8, w1 );
					break;
			}
			break;
		default:
			assert(false && "F3DSETA unknown MoveWord");
	}
}

void F3DSETA_Perpnorm(u32 w0, u32 w1)
{
	gSPPerspNormalize(w1);
}

void F3DSETA_Init()
{
	gSPSetupFunctions();
	// Set GeometryMode flags
	GBI_InitFlags( F3D );

	GBI.PCStackSize = 10;

	//          GBI Command             Command Value			Command Function
	GBI_SetGBI( G_SPNOOP,				F3D_SPNOOP,				F3D_SPNoOp );
	GBI_SetGBI( G_MTX,					F3D_MTX,				F3D_Mtx );
	GBI_SetGBI( G_RESERVED0,			F3D_RESERVED0,			F3D_Reserved0 );
	GBI_SetGBI( G_MOVEMEM,				F3D_MOVEMEM,			F3D_MoveMem );
	GBI_SetGBI( G_VTX,					F3D_VTX,				F3D_Vtx );
	GBI_SetGBI( G_RESERVED1,			F3D_RESERVED1,			F3D_Reserved1 );
	GBI_SetGBI( G_DL,					F3D_DL,					F3D_DList );
	GBI_SetGBI( G_RESERVED2,			F3D_RESERVED2,			F3D_Reserved2 );
	GBI_SetGBI( G_RESERVED3,			F3D_RESERVED3,			F3D_Reserved3 );
	GBI_SetGBI( G_SPRITE2D_BASE,		F3D_SPRITE2D_BASE,		F3D_Sprite2D_Base );

	GBI_SetGBI( G_TRI1,					F3D_TRI1,				F3D_Tri1 );
	GBI_SetGBI( G_CULLDL,				F3D_CULLDL,				F3D_CullDL );
	GBI_SetGBI( G_POPMTX,				F3D_POPMTX,				F3D_PopMtx );
	GBI_SetGBI( G_MOVEWORD,				F3D_MOVEWORD,			F3DSETA_MoveWord );
	GBI_SetGBI( G_PERSPNORM,			F3DSETA_PERSPNORM,		F3DSETA_Perpnorm);
	GBI_SetGBI( G_TEXTURE,				F3D_TEXTURE,			F3D_Texture );
	GBI_SetGBI( G_SETOTHERMODE_H,		F3D_SETOTHERMODE_H,		F3D_SetOtherMode_H );
	GBI_SetGBI( G_SETOTHERMODE_L,		F3D_SETOTHERMODE_L,		F3D_SetOtherMode_L );
	GBI_SetGBI( G_ENDDL,				F3D_ENDDL,				F3D_EndDL );
	GBI_SetGBI( G_SETGEOMETRYMODE,		F3D_SETGEOMETRYMODE,	F3D_SetGeometryMode );
	GBI_SetGBI( G_CLEARGEOMETRYMODE,	F3D_CLEARGEOMETRYMODE,	F3D_ClearGeometryMode );
	GBI_SetGBI( G_QUAD,					F3D_QUAD,				F3D_Quad );
	GBI_SetGBI( G_RDPHALF_1,			F3DSETA_RDPHALF_1,		F3D_RDPHalf_1 );
	GBI_SetGBI( G_RDPHALF_2,			F3DSETA_RDPHALF_2,		F3D_RDPHalf_2 );
	GBI_SetGBI( G_RDPHALF_CONT,			F3DSETA_RDPHALF_CONT,	F3D_RDPHalf_Cont );
}
