#ifndef F3DEX_H
#define F3DEX_H

#define F3DEX_MTX_STACKSIZE		18

#define F3DEX_MTX_MODELVIEW		0x00
#define F3DEX_MTX_PROJECTION	0x01
#define F3DEX_MTX_MUL			0x00
#define F3DEX_MTX_LOAD			0x02
#define F3DEX_MTX_NOPUSH		0x00
#define F3DEX_MTX_PUSH			0x04

#define F3DEX_TEXTURE_ENABLE	0x00000002
#define F3DEX_SHADING_SMOOTH	0x00000200
#define F3DEX_CULL_FRONT		0x00001000
#define F3DEX_CULL_BACK			0x00002000
#define F3DEX_CULL_BOTH			0x00003000
#define F3DEX_CLIPPING			0x00800000

#define F3DEX_MV_VIEWPORT		0x80

#define F3DEX_MWO_aLIGHT_1		0x00
#define F3DEX_MWO_bLIGHT_1		0x04
#define F3DEX_MWO_aLIGHT_2		0x20
#define F3DEX_MWO_bLIGHT_2		0x24
#define F3DEX_MWO_aLIGHT_3		0x40
#define F3DEX_MWO_bLIGHT_3		0x44
#define F3DEX_MWO_aLIGHT_4		0x60
#define F3DEX_MWO_bLIGHT_4		0x64
#define F3DEX_MWO_aLIGHT_5		0x80
#define F3DEX_MWO_bLIGHT_5		0x84
#define F3DEX_MWO_aLIGHT_6		0xa0
#define F3DEX_MWO_bLIGHT_6		0xa4
#define F3DEX_MWO_aLIGHT_7		0xc0
#define F3DEX_MWO_bLIGHT_7		0xc4
#define F3DEX_MWO_aLIGHT_8		0xe0
#define F3DEX_MWO_bLIGHT_8		0xe4

// F3DEX commands
#define F3DEX_MODIFYVTX				0xB2
#define F3DEX_TRI2					0xB1
#define F3DEX_BRANCH_Z				0xB0
#define F3DEX_LOAD_UCODE			0xAF // 0xCF

void F3DEX_Vtx( u32 w0, u32 w1 );
void F3DEX_Tri1( u32 w0, u32 w1 );
void F3DEX_CullDL( u32 w0, u32 w1 );
void F3DEX_ModifyVtx( u32 w0, u32 w1 );
void F3DEX_Tri2( u32 w0, u32 w1 );
void F3DEX_Branch_Z( u32 w0, u32 w1 );
void F3DEX_Load_uCode( u32 w0, u32 w1 );
void F3DEX_Init();
#endif

