#ifndef F3D_H
#define F3D_H
#include "Types.h"

#define F3D_MTX_STACKSIZE		10

#define F3D_MTX_MODELVIEW		0x00
#define F3D_MTX_PROJECTION		0x01
#define F3D_MTX_MUL				0x00
#define F3D_MTX_LOAD			0x02
#define F3D_MTX_NOPUSH			0x00
#define F3D_MTX_PUSH			0x04

#define F3D_TEXTURE_ENABLE		0x00000002
#define F3D_SHADING_SMOOTH		0x00000200
#define F3D_CULL_FRONT			0x00001000
#define F3D_CULL_BACK			0x00002000
#define F3D_CULL_BOTH			0x00003000
#define F3D_CLIPPING			0x00000000

#define F3D_MV_VIEWPORT			0x80

#define F3D_MWO_aLIGHT_1		0x00
#define F3D_MWO_bLIGHT_1		0x04
#define F3D_MWO_aLIGHT_2		0x20
#define F3D_MWO_bLIGHT_2		0x24
#define F3D_MWO_aLIGHT_3		0x40
#define F3D_MWO_bLIGHT_3		0x44
#define F3D_MWO_aLIGHT_4		0x60
#define F3D_MWO_bLIGHT_4		0x64
#define F3D_MWO_aLIGHT_5		0x80
#define F3D_MWO_bLIGHT_5		0x84
#define F3D_MWO_aLIGHT_6		0xa0
#define F3D_MWO_bLIGHT_6		0xa4
#define F3D_MWO_aLIGHT_7		0xc0
#define F3D_MWO_bLIGHT_7		0xc4
#define F3D_MWO_aLIGHT_8		0xe0
#define F3D_MWO_bLIGHT_8		0xe4

// FAST3D commands
#define F3D_SPNOOP				0x00
#define F3D_MTX					0x01
#define F3D_RESERVED0			0x02
#define F3D_MOVEMEM				0x03
#define F3D_VTX					0x04
#define F3D_RESERVED1			0x05
#define F3D_DL					0x06
#define F3D_RESERVED2			0x07
#define F3D_RESERVED3			0x08
#define F3D_SPRITE2D_BASE		0x09

#define F3D_TRI1				0xBF
#define F3D_CULLDL				0xBE
#define F3D_POPMTX				0xBD
#define F3D_MOVEWORD			0xBC
#define F3D_TEXTURE				0xBB
#define F3D_SETOTHERMODE_H		0xBA
#define F3D_SETOTHERMODE_L		0xB9
#define F3D_ENDDL				0xB8
#define F3D_SETGEOMETRYMODE		0xB7
#define F3D_CLEARGEOMETRYMODE	0xB6
//#define F3D_LINE3D				0xB5 // Only used in Line3D
#define F3D_QUAD				0xB5
#define F3D_RDPHALF_1			0xB4
#define F3D_RDPHALF_2			0xB3
#define F3D_RDPHALF_CONT		0xB2
#define F3D_TRI4				0xB1

void F3D_SPNoOp( u32 w0, u32 w1 );
void F3D_Mtx( u32 w0, u32 w1 );
void F3D_Reserved0( u32 w0, u32 w1 );
void F3D_MoveMem( u32 w0, u32 w1 );
void F3D_Vtx( u32 w0, u32 w1 );
void F3D_Reserved1( u32 w0, u32 w1 );
void F3D_DList( u32 w0, u32 w1 );
void F3D_Reserved2( u32 w0, u32 w1 );
void F3D_Reserved3( u32 w0, u32 w1 );
void F3D_Sprite2D_Base( u32 w0, u32 w1 );
void F3D_Tri1( u32 w0, u32 w1 );
void F3D_CullDL( u32 w0, u32 w1 );
void F3D_PopMtx( u32 w0, u32 w1 );
void F3D_MoveWord( u32 w0, u32 w1 );
void F3D_Texture( u32 w0, u32 w1 );
void F3D_SetOtherMode_H( u32 w0, u32 w1 );
void F3D_SetOtherMode_L( u32 w0, u32 w1 );
void F3D_EndDL( u32 w0, u32 w1 );
void F3D_SetGeometryMode( u32 w0, u32 w1 );
void F3D_ClearGeometryMode( u32 w0, u32 w1 );
//void F3D_Line3D( u32 w0, u32 w1 );
void F3D_Quad( u32 w0, u32 w1 );
void F3D_RDPHalf_1( u32 w0, u32 w1 );
void F3D_RDPHalf_2( u32 w0, u32 w1 );
void F3D_RDPHalf_Cont( u32 w0, u32 w1 );
void F3D_Init();
#endif

