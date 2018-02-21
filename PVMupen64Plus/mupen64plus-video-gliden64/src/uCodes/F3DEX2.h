#ifndef F3DEX2_H
#define F3DEX2_H

#define F3DEX2_MTX_STACKSIZE		18

#define F3DEX2_MTX_MODELVIEW		0x00
#define F3DEX2_MTX_PROJECTION		0x04
#define F3DEX2_MTX_MUL				0x00
#define F3DEX2_MTX_LOAD				0x02
#define F3DEX2_MTX_NOPUSH			0x00
#define F3DEX2_MTX_PUSH				0x01

#define F3DEX2_TEXTURE_ENABLE		0x00000000
#define F3DEX2_SHADING_SMOOTH		0x00200000
#define F3DEX2_CULL_FRONT			0x00000200
#define F3DEX2_CULL_BACK			0x00000400
#define F3DEX2_CULL_BOTH			0x00000600
#define F3DEX2_CLIPPING				0x00800000

#define F3DEX2_MV_VIEWPORT			8

#define F3DEX2_MWO_aLIGHT_1		0x00
#define F3DEX2_MWO_bLIGHT_1		0x04
#define F3DEX2_MWO_aLIGHT_2		0x18
#define F3DEX2_MWO_bLIGHT_2		0x1c
#define F3DEX2_MWO_aLIGHT_3		0x30
#define F3DEX2_MWO_bLIGHT_3		0x34
#define F3DEX2_MWO_aLIGHT_4		0x48
#define F3DEX2_MWO_bLIGHT_4		0x4c
#define F3DEX2_MWO_aLIGHT_5		0x60
#define F3DEX2_MWO_bLIGHT_5		0x64
#define F3DEX2_MWO_aLIGHT_6		0x78
#define F3DEX2_MWO_bLIGHT_6		0x7c
#define F3DEX2_MWO_aLIGHT_7		0x90
#define F3DEX2_MWO_bLIGHT_7		0x94
#define F3DEX2_MWO_aLIGHT_8		0xa8
#define F3DEX2_MWO_bLIGHT_8		0xac


#define	F3DEX2_RDPHALF_2		0xF1
#define	F3DEX2_SETOTHERMODE_H	0xE3
#define	F3DEX2_SETOTHERMODE_L	0xE2
#define	F3DEX2_RDPHALF_1		0xE1
#define	F3DEX2_SPNOOP			0xE0
#define	F3DEX2_ENDDL			0xDF
#define	F3DEX2_DL				0xDE
#define	F3DEX2_LOAD_UCODE		0xDD
#define	F3DEX2_MOVEMEM			0xDC
#define	F3DEX2_MOVEWORD			0xDB
#define	F3DEX2_MTX				0xDA
#define F3DEX2_GEOMETRYMODE		0xD9
#define	F3DEX2_POPMTX			0xD8
#define	F3DEX2_TEXTURE			0xD7
#define	F3DEX2_DMA_IO			0xD6
#define	F3DEX2_SPECIAL_1		0xD5
#define	F3DEX2_SPECIAL_2		0xD4
#define	F3DEX2_SPECIAL_3		0xD3

#define	F3DEX2_VTX				0x01
#define	F3DEX2_MODIFYVTX		0x02
#define	F3DEX2_CULLDL			0x03
#define	F3DEX2_BRANCH_Z			0x04
#define	F3DEX2_TRI1				0x05
#define F3DEX2_TRI2				0x06
#define F3DEX2_QUAD				0x07
#define F3DEX2_LINE3D			0x08


void F3DEX2_Mtx( u32 w0, u32 w1 );
void F3DEX2_MoveMem( u32 w0, u32 w1 );
void F3DEX2_Vtx( u32 w0, u32 w1 );
void F3DEX2_Reserved1( u32 w0, u32 w1 );
void F3DEX2_Tri1( u32 w0, u32 w1 );
void F3DEX2_PopMtx( u32 w0, u32 w1 );
void F3DEX2_MoveWord( u32 w0, u32 w1 );
void F3DEX2_Texture( u32 w0, u32 w1 );
void F3DEX2_SetOtherMode_H( u32 w0, u32 w1 );
void F3DEX2_SetOtherMode_L( u32 w0, u32 w1 );
void F3DEX2_GeometryMode( u32 w0, u32 w1 );
void F3DEX2_Line3D( u32 w0, u32 w1 );
void F3DEX2_DMAIO( u32 w0, u32 w1 );
void F3DEX2_Special_1( u32 w0, u32 w1 );
void F3DEX2_Special_2( u32 w0, u32 w1 );
void F3DEX2_Special_3( u32 w0, u32 w1 );
void F3DEX2_Quad( u32 w0, u32 w1 );
void F3DEX2_Init();
#endif

