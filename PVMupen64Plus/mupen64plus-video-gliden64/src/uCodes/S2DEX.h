#ifndef S2DEX_H
#define S2DEX_H

#include <Types.h>

#define	G_BGLT_LOADBLOCK		0x0033
#define	G_BGLT_LOADTILE			0xfff4

#define	G_BG_FLAG_FLIPS			0x01
#define	G_BG_FLAG_FLIPT			0x10

#define	G_OBJRM_NOTXCLAMP		0x01
#define	G_OBJRM_XLU				0x02
#define	G_OBJRM_ANTIALIAS		0x04
#define	G_OBJRM_BILERP			0x08
#define	G_OBJRM_SHRINKSIZE_1	0x10
#define	G_OBJRM_SHRINKSIZE_2	0x20
#define	G_OBJRM_WIDEN			0x40

struct uObjScaleBg
{
  u16 imageW;     /* Texture width (8-byte alignment, u10.2) */
  u16 imageX;     /* x-coordinate of upper-left
				  position of texture (u10.5) */
  u16 frameW;     /* Transfer destination frame width (u10.2) */
  s16 frameX;     /* x-coordinate of upper-left
				  position of transfer destination frame (s10.2) */

  u16 imageH;     /* Texture height (u10.2) */
  u16 imageY;     /* y-coordinate of upper-left position of
				  texture (u10.5) */
  u16 frameH;     /* Transfer destination frame height (u10.2) */
  s16 frameY;     /* y-coordinate of upper-left position of transfer
				  destination  frame (s10.2) */

  u32 imagePtr;  /* Address of texture source in DRAM*/
  u8  imageSiz;   /* Texel size
					 G_IM_SIZ_4b (4 bits/texel)
					 G_IM_SIZ_8b (8 bits/texel)
					 G_IM_SIZ_16b (16 bits/texel)
					 G_IM_SIZ_32b (32 bits/texel) */
  u8  imageFmt;   /*Texel format
					 G_IM_FMT_RGBA (RGBA format)
					 G_IM_FMT_YUV (YUV format)
					 G_IM_FMT_CI (CI format)
					 G_IM_FMT_IA (IA format)
					 G_IM_FMT_I (I format)  */
  u16 imageLoad;  /* Method for loading the BG image texture
					 G_BGLT_LOADBLOCK (use LoadBlock)
					 G_BGLT_LOADTILE (use LoadTile) */
  u16 imageFlip;  /* Image inversion on/off (horizontal
					 direction only)
					 0 (normal display (no inversion))
					 G_BG_FLAG_FLIPS (horizontal inversion of texture image) */
  u16 imagePal;   /* Position of palette for 4-bit color
				  index texture (4-bit precision, 0~15) */

  u16 scaleH;      /* y-direction scale value (u5.10) */
  u16 scaleW;      /* x-direction scale value (u5.10) */
  s32 imageYorig;  /* image drawing origin (s20.5)*/

  u8  padding[4];  /* Padding */
};   /* 40 bytes */

struct uSprite {
	u32 imagePtr;
	u32 tlutPtr;
	s16	imageW;
	s16	stride;
	s8	imageSiz;
	s8	imageFmt;
	s16	imageH;
	s16	imageY;
	s16	imageX;
	s8	dummy[4];
};    /* 24 bytes */

struct uObjSprite
{
	u16 scaleW;      /* Width-direction scaling (u5.10) */
	s16 objX;        /* x-coordinate of upper-left corner of OBJ (s10.2) */
	u16 paddingX;    /* Unused (always 0) */
	u16 imageW;      /* Texture width (length in s direction, u10.5)  */
	u16 scaleH;      /* Height-direction scaling (u5.10) */
	s16 objY;        /* y-coordinate of upper-left corner of OBJ (s10.2) */
	u16 paddingY;    /* Unused (always 0) */
	u16 imageH;      /* Texture height (length in t direction, u10.5)  */
	u16 imageAdrs;   /* Texture starting position in TMEM (In units of 64-bit words) */
	u16 imageStride; /* Texel wrapping width (In units of 64-bit words) */
	u8  imageFlags;  /* Display flag
				(*) More than one of the following flags can be specified as the bit sum of the flags:
					  0 (Normal display (no inversion))
					  G_OBJ_FLAG_FLIPS (s-direction (x) inversion)
					  G_OBJ_FLAG_FLIPT (t-direction (y) inversion)  */
	u8  imagePal;    /* Position of palette for 4-bit color index texture  (4-bit precision, 0~7)  */
	u8  imageSiz;    /* Texel size
					  G_IM_SIZ_4b (4 bits/texel)
					  G_IM_SIZ_8b (8 bits/texel)
					  G_IM_SIZ_16b (16 bits/texel)
					  G_IM_SIZ_32b (32 bits/texel) */
	u8  imageFmt;    /* Texel format
					  G_IM_FMT_RGBA (RGBA format)
					  G_IM_FMT_YUV (YUV format)
					  G_IM_FMT_CI (CI format)
					  G_IM_FMT_IA (IA format)
					  G_IM_FMT_I  (I format) */
};    /* 24 bytes */

struct uObjTxtrBlock
{
	u32   type;   /* Structure identifier (G_OBJLT_TXTRBLOCK) */
	u32   image; /* Texture source address in DRAM (8-byte alignment) */
	u16   tsize;  /* Texture size (specified by GS_TB_TSIZE) */
	u16   tmem;   /* TMEM word address where texture will be loaded (8-byte word) */
	u16   sid;    /* Status ID (multiple of 4: either 0, 4, 8, or 12) */
	u16   tline;  /* Texture line width (specified by GS_TB_TLINE) */
	u32   flag;   /* Status flag */
	u32   mask;   /* Status mask */
};     /* 24 bytes */

struct uObjTxtrTile
{
	u32   type;   /* Structure identifier (G_OBJLT_TXTRTILE) */
	u32   image; /* Texture source address in DRAM (8-byte alignment) */
	u16   twidth; /* Texture width (specified by GS_TT_TWIDTH) */
	u16   tmem;   /* TMEM word address where texture will be loaded (8-byte word) */
	u16   sid;    /* Status ID (multiple of 4: either 0, 4, 8, or 12) */
	u16   theight;/* Texture height (specified by GS_TT_THEIGHT) */
	u32   flag;   /* Status flag */
	u32   mask;   /* Status mask  */
};      /* 24 bytes */

struct uObjTxtrTLUT
{
	u32   type;   /* Structure identifier (G_OBJLT_TLUT) */
	u32   image; /* Texture source address in DRAM */
	u16   pnum;   /* Number of palettes to load - 1 */
	u16   phead;  /* Palette position at start of load (256~511) */
	u16   sid;    /* Status ID (multiple of 4: either 0, 4, 8, or 12) */
	u16   zero;   /* Always assign 0 */
	u32   flag;   /* Status flag */
	u32   mask;   /* Status mask */
};      /* 24 bytes */

typedef union
{
	uObjTxtrBlock      block;
	uObjTxtrTile       tile;
	uObjTxtrTLUT       tlut;
} uObjTxtr;

struct uObjTxSprite
{
	uObjTxtr      txtr;
	uObjSprite    sprite;
};

struct uObjMtx
{
  s32 A, B, C, D;   /* s15.16 */
  s16 Y, X;         /* s10.2 */
  u16 BaseScaleY;   /* u5.10 */
  u16 BaseScaleX;   /* u5.10 */
};

struct uObjSubMtx
{
	s16 Y, X;		/* s10.2  */
	u16 BaseScaleY;	/* u5.10  */
	u16 BaseScaleX;	/* u5.10  */
};

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

#define S2DEX_MV_MATRIX			0
#define S2DEX_MV_SUBMUTRIX		2
#define S2DEX_MV_VIEWPORT		8

#define	S2DEX_BG_1CYC			0x01
#define	S2DEX_BG_COPY			0x02
#define	S2DEX_OBJ_RECTANGLE		0x03
#define	S2DEX_OBJ_SPRITE		0x04
#define	S2DEX_OBJ_MOVEMEM		0x05
#define S2DEX_LOAD_UCODE		0xAF
#define	S2DEX_SELECT_DL			0xB0
#define	S2DEX_OBJ_RENDERMODE	0xB1
#define	S2DEX_OBJ_RECTANGLE_R	0xB2
#define	S2DEX_OBJ_LOADTXTR		0xC1
#define	S2DEX_OBJ_LDTX_SPRITE	0xC2
#define	S2DEX_OBJ_LDTX_RECT		0xC3
#define	S2DEX_OBJ_LDTX_RECT_R	0xC4
#define	S2DEX_RDPHALF_0			0xE4

#endif
