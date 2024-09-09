
#ifndef _SNPPU_H
#define _SNPPU_H

#include "snesreg.h"
#include "snmask.h"
#include "snppurenderi.h"
#include "snqueue.h"

#define SNPPU_WRITEQUEUE (TRUE)

#define SNESPPU_VRAM_NUMWORDS	0x8000
#define SNESPPU_CGRAM_NUM			256
#define	SNESPPU_OBJ_NUM			128

enum SnesPPULayerE
{
	SNESPPU_LAYER_BG1 = 0,
	SNESPPU_LAYER_BG2 = 1,
	SNESPPU_LAYER_BG3 = 2,
	SNESPPU_LAYER_BG4 = 3,
	SNESPPU_LAYER_OBJ = 4,
	SNESPPU_LAYER_BACK = 5,
	
	SNESPPU_LAYER_NUM
};

#define SNESPPU_MASK_BG1            (1 << SNESPPU_LAYER_BG1)
#define SNESPPU_MASK_BG2            (1 << SNESPPU_LAYER_BG2)
#define SNESPPU_MASK_BG3            (1 << SNESPPU_LAYER_BG3)
#define SNESPPU_MASK_BG4            (1 << SNESPPU_LAYER_BG4)
#define SNESPPU_MASK_OBJ            (1 << SNESPPU_LAYER_OBJ)
#define SNESPPU_MASK_BACK           (1 << SNESPPU_LAYER_BACK)

//
//
//

typedef Uint16 SnesColor16T;

struct SnesPPUOBJT
{
	Uint8	uX;
	Uint8	uY;
	Uint8	uTile;
	Uint8	uAttrib;
};

struct SnesOAMT
{
	SnesPPUOBJT	Objs[SNESPPU_OBJ_NUM];
	Uint8		ObjEx[SNESPPU_OBJ_NUM / 4];
};

struct SnesPPUTile2T
{
	Uint8	uPlane01[8][2];
};

struct SnesPPUTile4T
{
	Uint8	uPlane01[8][2];
	Uint8	uPlane23[8][2];
};

struct SnesPPUTile8T
{
	Uint8	uPlane01[8][2];
	Uint8	uPlane23[8][2];
	Uint8	uPlane45[8][2];
	Uint8	uPlane67[8][2];
};


struct SnesPPUScreenT
{
	Uint16	uTile[32][32];
};




// ppu registers
struct SnesPPURegsT
{
	SnesReg8T   	        inidisp;
	SnesReg8T   	        obsel;
	SnesReg16T   	        oamaddr;
	SnesReg16T   	        oamaddrlatch;
	SnesReg16T   	        oampri;
	SnesReg8T   	        bgmode;
	SnesReg8T   	        mosaic;
	SnesReg8T   	        bg1sc;
	SnesReg8T   	        bg2sc;
	SnesReg8T   	        bg3sc;
	SnesReg8T   	        bg4sc;
	SnesReg8T   	        bg12nba;
	SnesReg8T   	        bg34nba;
	
	SnesReg8T		        bgofslo;
	SnesReg16T   	        bg1hofs;
	SnesReg16T   	        bg1vofs;
	SnesReg16T   	        bg2hofs;
	SnesReg16T   	        bg2vofs;
	SnesReg16T   	        bg3hofs;
	SnesReg16T   	        bg3vofs;
	SnesReg16T   	        bg4hofs;
	SnesReg16T   	        bg4vofs;

	SnesReg8T   	        vmain;
	SnesReg16T   	        vmaddr;
	SnesReg16T   	        vmreadlatch;
	Uint8			        vminc[2];

	SnesReg8T   	        m7sel;
	SnesReg16T   	        m7a;
	SnesReg16T   	        m7b;
	SnesReg16T   	        m7c;
	SnesReg16T   	        m7d;
	SnesReg16T   	        m7x;
	SnesReg16T   	        m7y;

	SnesReg8T   	        mpyl;
	SnesReg8T   	        mpym;
	SnesReg8T   	        mpyh;

	SnesReg16T   	        cgadd;
	
	SnesReg8T   	        w12sel;
	SnesReg8T   	        w34sel;
	SnesReg8T   	        wobjsel;
	SnesReg8T   	        wh0;
	SnesReg8T   	        wh1;
	SnesReg8T   	        wh2;
	SnesReg8T   	        wh3;
	SnesReg8T   	        wbglog;
	SnesReg8T   	        wobjlog;

	SnesReg8T   	        tm;
	SnesReg8T   	        ts;
	SnesReg8T   	        tmw;
	SnesReg8T   	        tsw;
	SnesReg8T   	        cgwsel;
	SnesReg8T   	        cgadsub;
	SnesColor16T   	        coldata;

	SnesReg8T   	        setini;

	SnesReg16FT		        ophct;
	SnesReg16FT		        opvct;
	SnesReg8T		        stat77;
	SnesReg8T		        stat78;
};

class SnesPPU
{
public:
	SnesPPU();

	void                    Reset();
	void                    BeginFrame();
	void                    EndFrame();
	void                    SetPPURender(ISnesPPURender *pPPURender)    {m_pRender=pPPURender;}

	const SnesPPURegsT *    GetRegs() const                             {return &m_Regs;}
	SnesOAMT *              GetOAM()                                    {return &m_OAM;}
	Uint16 *                GetVramPtr(Uint32 uVramAddr)                {return &m_VRAM[uVramAddr & 0x7FFF];}
	Bool                    IsForceBlank() const                        {return !(m_Regs.inidisp & 0x80);}
	Bool                    InVBlank() const                            {return m_bVBlank;}
	Uint32                  GetIntensity()  const                       {return m_Regs.inidisp & 0xF;}

	#if SNPPU_WRITEQUEUE
	Bool                    EnqueueWrite(Uint32 uLine, Uint32 uAddr, Uint8 uData);
	#endif
	void                    Sync(Uint32 uLine);

	void                    WriteCGDATA(Uint8 uData);
	void                    WriteOAMDATA(Uint8 uData);
	void                    WriteVMDATAL(Uint8 uData);
	void                    WriteVMDATAH(Uint8 uData);
	void                    WriteVMDATALH(Uint8 uDataL, Uint8 uDataH);
	void                    Write8(Uint32 uAddr, Uint8 uData);
	Uint8                   Read8(Uint32 uAddr);
	Uint8                   ReadOAMDATA();
	Uint8                   ReadCGDATA();
	Uint8                   ReadVMDATAL();
	Uint8                   ReadVMDATAH();


	SnesColor16T            GetCG(Uint32 uEntry)  const                       {return m_CGRAM[uEntry];}
	SnesColor16T *          GetCGData()                                       {return m_CGRAM;}

	void                    SaveState(struct SNStatePPUT *pState);
	void                    RestoreState(struct SNStatePPUT *pState);

	static Char *           GetRegName(Uint32 uAddr);

private:
    friend class SnesDMAC;

    Uint32			        m_uLine;
    Bool                    m_bVBlank;

    SnesPPURegsT	        m_Regs;
    SnesColor16T	        m_CGRAM[SNESPPU_CGRAM_NUM] _ALIGN(16);			// 16-bit palette
    Uint16			        m_VRAM[SNESPPU_VRAM_NUMWORDS] _ALIGN(16);
    SnesOAMT		        m_OAM;

    ISnesPPURender *        m_pRender;

#if SNPPU_WRITEQUEUE
    SNQueue			        m_Queue;	// write queue
#endif

    void                    UpdateMatMul();
};


#endif
