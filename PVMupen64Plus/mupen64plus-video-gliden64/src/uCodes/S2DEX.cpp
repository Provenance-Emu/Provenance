#include <assert.h>
#include "S2DEX.h"
#include "F3D.h"
#include "F3DEX.h"
#include <GBI.h>
#include <gSP.h>
#include <gDP.h>
#include <RSP.h>
#include <RDP.h>
#include <Types.h>
#include <Log.h>

void S2DEX_BG_1Cyc( u32 w0, u32 w1 )
{
	gSPBgRect1Cyc( w1 );
}

void S2DEX_BG_Copy( u32 w0, u32 w1 )
{
	gSPBgRectCopy( w1 );
}

void S2DEX_Obj_Rectangle( u32 w0, u32 w1 )
{
	gSPObjRectangle( w1 );
}

void S2DEX_Obj_Sprite( u32 w0, u32 w1 )
{
	gSPObjSprite( w1 );
}

void S2DEX_Obj_MoveMem( u32 w0, u32 w1 )
{
	switch (_SHIFTR( w0, 0, 16 )) {
		case S2DEX_MV_MATRIX:
			gSPObjMatrix( w1 );
			break;
		case S2DEX_MV_SUBMUTRIX:
			gSPObjSubMatrix( w1 );
			break;
		case S2DEX_MV_VIEWPORT:
			gSPViewport( w1 );
			break;
	}
}

void S2DEX_MoveWord( u32 w0, u32 w1 )
{
	switch (_SHIFTR( w0, 16, 8 ))
	{
	case G_MW_GENSTAT:
		gSPSetStatus(_SHIFTR(w0, 0, 16), w1);
		break;
	default:
		F3D_MoveWord(w0, w1);
		break;
	}
}

void S2DEX_RDPHalf_0( u32 w0, u32 w1 ) {
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

void S2DEX_Select_DL( u32 w0, u32 w1 )
{
	gSP.selectDL.addr |= (_SHIFTR(w0, 0, 16)) << 16;
	const u8 sid = gSP.selectDL.sid;
	const u32 flag = gSP.selectDL.flag;
	const u32 mask = w1;
	if ((gSP.status[sid] & mask) == flag)
		// Do nothing;
		return;

	gSP.status[sid] = (gSP.status[sid] & ~mask) | (flag & mask);

	switch (_SHIFTR( w0, 16, 8 ))
	{
		case G_DL_PUSH:
			gSPDisplayList( gSP.selectDL.addr );
			break;
		case G_DL_NOPUSH:
			gSPBranchList( gSP.selectDL.addr );
			break;
	}
}

void S2DEX_Obj_RenderMode( u32 w0, u32 w1 )
{
	gSPObjRendermode(w1);
}

void S2DEX_Obj_Rectangle_R( u32 w0, u32 w1 )
{
	gSPObjRectangleR(w1);
}

void S2DEX_Obj_LoadTxtr( u32 w0, u32 w1 )
{
	gSPObjLoadTxtr( w1 );
}

void S2DEX_Obj_LdTx_Sprite( u32 w0, u32 w1 )
{
	gSPObjLoadTxSprite( w1 );
}

void S2DEX_Obj_LdTx_Rect( u32 w0, u32 w1 )
{
	gSPObjLoadTxRect(w1);
}

void S2DEX_Obj_LdTx_Rect_R( u32 w0, u32 w1 )
{
	gSPObjLoadTxRectR( w1 );
}

void S2DEX_Init()
{
	gSPSetupFunctions();
	// Set GeometryMode flags
	GBI_InitFlags( F3DEX );

	GBI.PCStackSize = 18;

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

