
#ifndef _SNPPURENDER_H
#define _SNPPURENDER_H

#include "snppu.h"
#include "snppurenderi.h"
#include "snppublend.h"
#include "palette.h"

class CRenderSurface;


enum
{
	SNPPU_BGPLANE_PLANE0,
	SNPPU_BGPLANE_PLANE1,
	SNPPU_BGPLANE_PLANE2,
	SNPPU_BGPLANE_PLANE3,
	SNPPU_BGPLANE_PLANE4,
	SNPPU_BGPLANE_PLANE5,
	SNPPU_BGPLANE_PLANE6,
	SNPPU_BGPLANE_PLANE7,
	SNPPU_BGPLANE_PLANE8,
	SNPPU_BGPLANE_PLANE9,
	SNPPU_BGPLANE_PLANE10,

	SNPPU_BGPLANE_NUM
};

#define SNPPU_BGPLANE_OPAQUE	(SNPPU_BGPLANE_PLANE9)
#define SNPPU_BGPLANE_PRI		(SNPPU_BGPLANE_PLANE10)
#define SNPPU_BGPLANE_LAYER0	(SNPPU_BGPLANE_PLANE9)
#define SNPPU_BGPLANE_LAYER1	(SNPPU_BGPLANE_PLANE10)

#define SNPPU_BGFLAGS_FETCHCHR (1)
#define SNPPU_BGFLAGS_FETCHPAL (2)
#define SNPPU_BGFLAGS_OFFSET (4)

enum 
{
    SNPPU_BGWINDOW_BG1,
    SNPPU_BGWINDOW_BG2,
    SNPPU_BGWINDOW_BG3,
    SNPPU_BGWINDOW_BG4,
    SNPPU_BGWINDOW_OBJ,
    SNPPU_BGWINDOW_COLOR,

    SNPPU_BGWINDOW_NUM
};


// maximum number of lines (224 + first dummy line)
#define SNPPU_MAXLINE   225 

// maximum number of obj's per line
#define SNPPU_MAXOBJ    32

// maximum number of obj 8-pixel chr's per line
#define SNPPU_MAXOBJCHR 34


#define SNPPU_BGPLANE_SIZE 48

//
//

struct SnesRenderObjT
{
	Uint16	uPosX;		// x position
	Uint8	uPosY;
	Uint8   uPad;
	Uint16	uTile;
	Uint8	bHFlip;		// h-flip
	Uint8	uVXOR;		// v-flip
	Uint8	uSize;
	Uint8	uSizeShift;
	Uint8	uPri;		
	Uint8	uPal;
};


struct SnesRenderTileT
{
	Uint16	uTile;		// tile index
	Uint8	uPal;		// palette index
	Uint8	uFlip;		// flip
	Uint8   uOffsetY;
	Uint8	uPad;
};


struct SnesBGInfoT
{
	Uint32	uScrollX;
	Uint32	uScrollY;
	Uint32	uScrAddr;
	Uint32	uChrAddr;
	Uint8	uScrSize;
	Uint8	uChrSize;
	Uint8	uBitDepth;
	Uint8   uPalBase;
	Uint8	Priority;
	Uint32	uMosaic;
};

typedef Uint32 SnesChrLookupT[256][2];
typedef Uint64 SnesChrLookup64T[256];


struct SnesRenderObj8T
{
	Int16	iPosX;
	Uint8	uPri;	// priority
	Uint8	uPal;

	Uint8	uData[SNPPU_BGPLANE_NUM];
	Uint8   uPad[1];
};



struct SnesRender8pInfoT
{
    SNPPUBlendInfoT    BlendInfo _ALIGN(16);

	SNMaskT Main[SNPPU_BGPLANE_NUM] _ALIGN(16);
	SNMaskT Sub[SNPPU_BGPLANE_NUM] _ALIGN(16);

	SNMaskT BGPlanes[4][SNPPU_BGPLANE_NUM]; // this is the fetched raw BG data from each bglayer

//    Uint8   CacheLines[8][SNPPU_BGPLANE_SIZE] _ALIGN(16);
	SnesRenderTileT Tiles[4][34];
	Uint16	BGOffset[68];

	SNMaskT MainAddSubMask;					// this is the mask of pixels of the main screen that have add/sub enabled
	SNMaskT SubAddSubMask;					// this is the mask of pixels of the sub screen that are opaque
	SNMaskT	WindowMask[4];					// these represent the 2 real windows and their inverse
	SNMaskT	BGWindow[SNPPU_BGWINDOW_NUM];	// these represent the combination of the real windows based on bg logic operation

	Uint32  uBGVramAddr[4];

	Uint8  uObjY[128];
    Uint8  uObjSize[128];
};                     





//
//
//


class SnesPPURender : public ISnesPPURender
{
private:
    SnesRender8pInfoT *m_pRenderInfo;

	// derived state
	SnesRenderObjT	m_Objs[SNESPPU_OBJ_NUM];

	// render target
	CRenderSurface	*m_pTarget;

    Uint8           m_nObjLine[SNPPU_MAXLINE];
    Uint8           m_ObjLine[SNPPU_MAXLINE][SNPPU_MAXOBJ];

    ISNPPUBlend    *m_pBlend;

	void DecodeBGInfo(SnesBGInfoT *pBGInfo);
	void DecodeWindows(SNMaskT *pWindow, SNMaskT *pBGWindow);

    void UpdateOBJVisibility(Uint8 *pObjY, Uint8 *pObjSize, Int32 iObj, Int32 nObjs);
    Int32 CheckOBJ(SnesRenderObjT *pObjs, Int32 iObj, Int32 nObjs, Uint8 *pObjList, Int32 MaxObjLine, Int32 iLine);
    Int32 CheckOBJ(Uint8 *pObjY, Uint8 *pObjSize, Int32 iObj, Int32 nObjs, Uint8 *pObjList, Int32 MaxObjLine, Int32 iLine);
    Int32 CheckOBJ(Uint8 *pObjList, Int32 iLine);

    Uint32 FetchBG(SnesBGInfoT *pBGInfo, struct SnesRenderTileT *pTiles, Int32 nTiles, Int32 iLine, Uint32 &uOldVramAddr);
	Uint32 FetchBGOffset(SnesBGInfoT *pBGInfo, struct SnesRenderTileT *pTiles, Int32 nTiles, Int32 iLine, Uint16 *pOffset, Uint32 uOffsetMask, Bool bVOffset);
	Uint32 FetchOffset(SnesBGInfoT *pBGInfo, Uint16 *pOffset, Int32 iLine, Uint32 &uOldVramAddr, Bool bVOffset);

	void RenderLine8Planar(Int32 iLine, SnesRender8pInfoT *pRenderInfo);
	void RenderLine8(Int32 iLine,  SnesRender8pInfoT *pRenderInfo);
	void RenderLine8Mode7(Int32 iLine,  SnesRender8pInfoT *pRenderInfo);

    void UpdateOBJ(Uint8 *pObjY, Uint8 *pObjSize);

	void RenderLine32(Int32 iLine, Bool bPlanar);
	void RenderLine16(Int32 iLine);

public:
	void RenderLine(Int32 iLine);
	void Reset();
	void BeginRender(CRenderSurface *pTarget);
	void EndRender();
	void UpdateVRAM(Uint32 uVramAddr);
	void UpdateCGRAM(Uint32 uAddr, Uint16 uData);
};



extern SnesChrLookupT _SnesPPU_PlaneLookup[2];
extern Uint8 _SnesPPU_HFlipLookup[2][256];
extern Uint8 _tm;
extern Uint8 _tmw;
extern Uint8 _ts;
extern Uint8 _tsw;

#endif
