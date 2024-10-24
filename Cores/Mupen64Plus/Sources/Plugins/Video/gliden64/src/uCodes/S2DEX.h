#ifndef S2DEX_H
#define S2DEX_H

#include "Types.h"

void S2DEX_BG_1Cyc(u32 w0, u32 w1);
void S2DEX_BG_Copy( u32 w0, u32 w1 );
void S2DEX_Obj_Rectangle( u32 w0, u32 w1 );
void S2DEX_Obj_Sprite( u32 w0, u32 w1 );
void S2DEX_Obj_MoveMem( u32 w0, u32 w1 );
void S2DEX_RDPHalf_0( u32 w0, u32 w1 );
void S2DEX_Select_DL( u32 w0, u32 w1 );
void S2DEX_Obj_RenderMode( u32 w0, u32 w1 );
void S2DEX_Obj_Rectangle_R( u32 w0, u32 w1 );
void S2DEX_Obj_LoadTxtr( u32 w0, u32 w1 );
void S2DEX_Obj_LdTx_Sprite( u32 w0, u32 w1 );
void S2DEX_Obj_LdTx_Rect( u32 w0, u32 w1 );
void S2DEX_Obj_LdTx_Rect_R( u32 w0, u32 w1 );
void S2DEX_Init();
void S2DEX_1_03_Init();
void resetObjMtx();

#endif
