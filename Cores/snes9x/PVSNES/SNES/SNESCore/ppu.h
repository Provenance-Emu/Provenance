/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#ifndef _PPU_H_
#define _PPU_H_

#define FIRST_VISIBLE_LINE	1

#define TILE_2BIT			0
#define TILE_4BIT			1
#define TILE_8BIT			2
#define TILE_2BIT_EVEN		3
#define TILE_2BIT_ODD		4
#define TILE_4BIT_EVEN		5
#define TILE_4BIT_ODD		6

#define MAX_2BIT_TILES		4096
#define MAX_4BIT_TILES		2048
#define MAX_8BIT_TILES		1024

#define CLIP_OR				0
#define CLIP_AND			1
#define CLIP_XOR			2
#define CLIP_XNOR			3

struct ClipData
{
	uint8	Count;
	uint8	DrawMode[6];
	uint16	Left[6];
	uint16	Right[6];
};

struct InternalPPU
{
	struct ClipData Clip[2][6];
	bool8	ColorsChanged;
	bool8	OBJChanged;
	uint8	*TileCache[7];
	uint8	*TileCached[7];
	bool8	Interlace;
	bool8	InterlaceOBJ;
	bool8	PseudoHires;
	bool8	DoubleWidthPixels;
	bool8	DoubleHeightPixels;
	int		CurrentLine;
	int		PreviousLine;
	uint8	*XB;
	uint32	Red[256];
	uint32	Green[256];
	uint32	Blue[256];
	uint16	ScreenColors[256];
	uint8	MaxBrightness;
	bool8	RenderThisFrame;
	int		RenderedScreenWidth;
	int		RenderedScreenHeight;
	uint32	FrameCount;
	uint32	RenderedFramesCount;
	uint32	DisplayedRenderedFrameCount;
	uint32	TotalEmulatedFrames;
	uint32	SkippedFrames;
	uint32	FrameSkip;
};

struct SOBJ
{
	int16	HPos;
	uint16	VPos;
	uint8	HFlip;
	uint8	VFlip;
	uint16	Name;
	uint8	Priority;
	uint8	Palette;
	uint8	Size;
};

struct SPPU
{
	struct
	{
		bool8	High;
		uint8	Increment;
		uint16	Address;
		uint16	Mask1;
		uint16	FullGraphicCount;
		uint16	Shift;
	}	VMA;

	uint32	WRAM;

	struct
	{
		uint16	SCBase;
		uint16	HOffset;
		uint16	VOffset;
		uint8	BGSize;
		uint16	NameBase;
		uint16	SCSize;
	}	BG[4];

	uint8	BGMode;
	uint8	BG3Priority;

	bool8	CGFLIP;
	uint8	CGFLIPRead;
	uint8	CGADD;
	uint8	CGSavedByte;
	uint16	CGDATA[256];

	struct SOBJ OBJ[128];
	bool8	OBJThroughMain;
	bool8	OBJThroughSub;
	bool8	OBJAddition;
	uint16	OBJNameBase;
	uint16	OBJNameSelect;
	uint8	OBJSizeSelect;

	uint16	OAMAddr;
	uint16	SavedOAMAddr;
	uint8	OAMPriorityRotation;
	uint8	OAMFlip;
	uint8	OAMReadFlip;
	uint16	OAMTileAddress;
	uint16	OAMWriteRegister;
	uint8	OAMData[512 + 32];

	uint8	FirstSprite;
	uint8	LastSprite;
	uint8	RangeTimeOver;

	bool8	HTimerEnabled;
	bool8	VTimerEnabled;
	short	HTimerPosition;
	short	VTimerPosition;
	uint16	IRQHBeamPos;
	uint16	IRQVBeamPos;

	uint8	HBeamFlip;
	uint8	VBeamFlip;
	uint16	HBeamPosLatched;
	uint16	VBeamPosLatched;
	uint16	GunHLatch;
	uint16	GunVLatch;
	uint8	HVBeamCounterLatched;

	bool8	Mode7HFlip;
	bool8	Mode7VFlip;
	uint8	Mode7Repeat;
	short	MatrixA;
	short	MatrixB;
	short	MatrixC;
	short	MatrixD;
	short	CentreX;
	short	CentreY;
	short	M7HOFS;
	short	M7VOFS;

	uint8	Mosaic;
	uint8	MosaicStart;
	bool8	BGMosaic[4];

	uint8	Window1Left;
	uint8	Window1Right;
	uint8	Window2Left;
	uint8	Window2Right;
	bool8	RecomputeClipWindows;
	uint8	ClipCounts[6];
	uint8	ClipWindowOverlapLogic[6];
	uint8	ClipWindow1Enable[6];
	uint8	ClipWindow2Enable[6];
	bool8	ClipWindow1Inside[6];
	bool8	ClipWindow2Inside[6];

	bool8	ForcedBlanking;

	uint8	FixedColourRed;
	uint8	FixedColourGreen;
	uint8	FixedColourBlue;
	uint8	Brightness;
	uint16	ScreenHeight;

	bool8	Need16x8Mulitply;
	uint8	BGnxOFSbyte;
	uint8	M7byte;

	uint8	HDMA;
	uint8	HDMAEnded;

	uint8	OpenBus1;
	uint8	OpenBus2;

	uint16	VRAMReadBuffer;
};

extern uint16				SignExtend[2];
extern struct SPPU			PPU;
extern struct InternalPPU	IPPU;

void S9xResetPPU (void);
void S9xResetPPUFast (void);
void S9xSoftResetPPU (void);
void S9xSetPPU (uint8, uint16);
uint8 S9xGetPPU (uint16);
void S9xSetCPU (uint8, uint16);
uint8 S9xGetCPU (uint16);
void S9xUpdateIRQPositions (bool initial);
void S9xFixColourBrightness (void);
void S9xDoAutoJoypad (void);

#include "gfx.h"
#include "memmap.h"

typedef struct
{
	uint8	_5C77;
	uint8	_5C78;
	uint8	_5A22;
}	SnesModel;

extern SnesModel	*Model;
extern SnesModel	M1SNES;
extern SnesModel	M2SNES;

#define MAX_5C77_VERSION	0x01
#define MAX_5C78_VERSION	0x03
#define MAX_5A22_VERSION	0x02

void S9xUpdateScreen (void);
static inline void FLUSH_REDRAW (void)
{
	if (IPPU.PreviousLine != IPPU.CurrentLine)
		S9xUpdateScreen();
}

static inline void S9xUpdateVRAMReadBuffer()
{
	if (PPU.VMA.FullGraphicCount)
	{
		uint32 addr = PPU.VMA.Address;
		uint32 rem = addr & PPU.VMA.Mask1;
		uint32 address = (addr & ~PPU.VMA.Mask1) + (rem >> PPU.VMA.Shift) + ((rem & (PPU.VMA.FullGraphicCount - 1)) << 3);
		PPU.VRAMReadBuffer = READ_WORD(Memory.VRAM + ((address << 1) & 0xffff));
	}
	else
		PPU.VRAMReadBuffer = READ_WORD(Memory.VRAM + ((PPU.VMA.Address << 1) & 0xffff));
}

static inline void REGISTER_2104 (uint8 Byte)
{
	if (!(PPU.OAMFlip & 1))
	{
		PPU.OAMWriteRegister &= 0xff00;
		PPU.OAMWriteRegister |= Byte;
	}

	if (PPU.OAMAddr & 0x100)
	{
		int addr = ((PPU.OAMAddr & 0x10f) << 1) + (PPU.OAMFlip & 1);
		if (Byte != PPU.OAMData[addr])
		{
			FLUSH_REDRAW();
			PPU.OAMData[addr] = Byte;
			IPPU.OBJChanged = TRUE;

			// X position high bit, and sprite size (x4)
			struct SOBJ *pObj = &PPU.OBJ[(addr & 0x1f) * 4];
			pObj->HPos = (pObj->HPos & 0xFF) | SignExtend[(Byte >> 0) & 1];
			pObj++->Size = Byte & 2;
			pObj->HPos = (pObj->HPos & 0xFF) | SignExtend[(Byte >> 2) & 1];
			pObj++->Size = Byte & 8;
			pObj->HPos = (pObj->HPos & 0xFF) | SignExtend[(Byte >> 4) & 1];
			pObj++->Size = Byte & 32;
			pObj->HPos = (pObj->HPos & 0xFF) | SignExtend[(Byte >> 6) & 1];
			pObj->Size = Byte & 128;
		}

	}
	else if (PPU.OAMFlip & 1)
	{
		PPU.OAMWriteRegister &= 0x00ff;
		uint8 lowbyte = (uint8) (PPU.OAMWriteRegister);
		uint8 highbyte = Byte;
		PPU.OAMWriteRegister |= Byte << 8;

		int addr = (PPU.OAMAddr << 1);
		if (lowbyte != PPU.OAMData[addr] || highbyte != PPU.OAMData[addr + 1])
		{
			FLUSH_REDRAW();
			PPU.OAMData[addr] = lowbyte;
			PPU.OAMData[addr + 1] = highbyte;
			IPPU.OBJChanged = TRUE;
			if (addr & 2)
			{
				// Tile
				PPU.OBJ[addr = PPU.OAMAddr >> 1].Name = PPU.OAMWriteRegister & 0x1ff;
				// priority, h and v flip.
				PPU.OBJ[addr].Palette  = (highbyte >> 1) & 7;
				PPU.OBJ[addr].Priority = (highbyte >> 4) & 3;
				PPU.OBJ[addr].HFlip    = (highbyte >> 6) & 1;
				PPU.OBJ[addr].VFlip    = (highbyte >> 7) & 1;
			}
			else
			{
				// X position (low)
				PPU.OBJ[addr = PPU.OAMAddr >> 1].HPos &= 0xff00;
				PPU.OBJ[addr].HPos |= lowbyte;
				// Sprite Y position
				PPU.OBJ[addr].VPos = highbyte;
			}
		}
	}

	PPU.OAMFlip ^= 1;
	if (!(PPU.OAMFlip & 1))
	{
		++PPU.OAMAddr;
		PPU.OAMAddr &= 0x1ff;
		if (PPU.OAMPriorityRotation && PPU.FirstSprite != (PPU.OAMAddr >> 1))
		{
			PPU.FirstSprite = (PPU.OAMAddr & 0xfe) >> 1;
			IPPU.OBJChanged = TRUE;
		}
	}
	else
	{
		if (PPU.OAMPriorityRotation && (PPU.OAMAddr & 1))
			IPPU.OBJChanged = TRUE;
	}
}

// This code is correct, however due to Snes9x's inaccurate timings, some games might be broken by this chage. :(
#ifdef DEBUGGER
#define CHECK_INBLANK() \
	if (!PPU.ForcedBlanking && CPU.V_Counter < PPU.ScreenHeight + FIRST_VISIBLE_LINE) \
	{ \
		printf("Invalid VRAM acess at (%04d, %04d) blank:%d\n", CPU.Cycles, CPU.V_Counter, PPU.ForcedBlanking); \
		if (Settings.BlockInvalidVRAMAccess) \
		{ \
			PPU.VMA.Address += !PPU.VMA.High ? PPU.VMA.Increment : 0; \
			return; \
		} \
	}
#else
#define CHECK_INBLANK() \
	if (Settings.BlockInvalidVRAMAccess && !PPU.ForcedBlanking && CPU.V_Counter < PPU.ScreenHeight + FIRST_VISIBLE_LINE) \
	{ \
		PPU.VMA.Address += !PPU.VMA.High ? PPU.VMA.Increment : 0; \
		return; \
	}
#endif

static inline void REGISTER_2118 (uint8 Byte)
{
	CHECK_INBLANK();

	uint32	address;

	if (PPU.VMA.FullGraphicCount)
	{
		uint32 rem = PPU.VMA.Address & PPU.VMA.Mask1;
		address = (((PPU.VMA.Address & ~PPU.VMA.Mask1) + (rem >> PPU.VMA.Shift) + ((rem & (PPU.VMA.FullGraphicCount - 1)) << 3)) << 1) & 0xffff;
		Memory.VRAM[address] = Byte;
	}
	else
		Memory.VRAM[address = (PPU.VMA.Address << 1) & 0xffff] = Byte;

	IPPU.TileCached[TILE_2BIT][address >> 4] = FALSE;
	IPPU.TileCached[TILE_4BIT][address >> 5] = FALSE;
	IPPU.TileCached[TILE_8BIT][address >> 6] = FALSE;
	IPPU.TileCached[TILE_2BIT_EVEN][address >> 4] = FALSE;
	IPPU.TileCached[TILE_2BIT_EVEN][((address >> 4) - 1) & (MAX_2BIT_TILES - 1)] = FALSE;
	IPPU.TileCached[TILE_2BIT_ODD] [address >> 4] = FALSE;
	IPPU.TileCached[TILE_2BIT_ODD] [((address >> 4) - 1) & (MAX_2BIT_TILES - 1)] = FALSE;
	IPPU.TileCached[TILE_4BIT_EVEN][address >> 5] = FALSE;
	IPPU.TileCached[TILE_4BIT_EVEN][((address >> 5) - 1) & (MAX_4BIT_TILES - 1)] = FALSE;
	IPPU.TileCached[TILE_4BIT_ODD] [address >> 5] = FALSE;
	IPPU.TileCached[TILE_4BIT_ODD] [((address >> 5) - 1) & (MAX_4BIT_TILES - 1)] = FALSE;

	if (!PPU.VMA.High)
	{
	#ifdef DEBUGGER
		if (Settings.TraceVRAM && !CPU.InDMAorHDMA)
			printf("VRAM write byte: $%04X (%d, %d)\n", PPU.VMA.Address, Memory.FillRAM[0x2115] & 3, (Memory.FillRAM[0x2115] & 0x0c) >> 2);
	#endif
		PPU.VMA.Address += PPU.VMA.Increment;
	}
}

static inline void REGISTER_2118_tile (uint8 Byte)
{
	CHECK_INBLANK();

	uint32 rem = PPU.VMA.Address & PPU.VMA.Mask1;
	uint32 address = (((PPU.VMA.Address & ~PPU.VMA.Mask1) + (rem >> PPU.VMA.Shift) + ((rem & (PPU.VMA.FullGraphicCount - 1)) << 3)) << 1) & 0xffff;

	Memory.VRAM[address] = Byte;

	IPPU.TileCached[TILE_2BIT][address >> 4] = FALSE;
	IPPU.TileCached[TILE_4BIT][address >> 5] = FALSE;
	IPPU.TileCached[TILE_8BIT][address >> 6] = FALSE;
	IPPU.TileCached[TILE_2BIT_EVEN][address >> 4] = FALSE;
	IPPU.TileCached[TILE_2BIT_EVEN][((address >> 4) - 1) & (MAX_2BIT_TILES - 1)] = FALSE;
	IPPU.TileCached[TILE_2BIT_ODD] [address >> 4] = FALSE;
	IPPU.TileCached[TILE_2BIT_ODD] [((address >> 4) - 1) & (MAX_2BIT_TILES - 1)] = FALSE;
	IPPU.TileCached[TILE_4BIT_EVEN][address >> 5] = FALSE;
	IPPU.TileCached[TILE_4BIT_EVEN][((address >> 5) - 1) & (MAX_4BIT_TILES - 1)] = FALSE;
	IPPU.TileCached[TILE_4BIT_ODD] [address >> 5] = FALSE;
	IPPU.TileCached[TILE_4BIT_ODD] [((address >> 5) - 1) & (MAX_4BIT_TILES - 1)] = FALSE;

	if (!PPU.VMA.High)
		PPU.VMA.Address += PPU.VMA.Increment;
}

static inline void REGISTER_2118_linear (uint8 Byte)
{
	CHECK_INBLANK();

	uint32	address;

	Memory.VRAM[address = (PPU.VMA.Address << 1) & 0xffff] = Byte;

	IPPU.TileCached[TILE_2BIT][address >> 4] = FALSE;
	IPPU.TileCached[TILE_4BIT][address >> 5] = FALSE;
	IPPU.TileCached[TILE_8BIT][address >> 6] = FALSE;
	IPPU.TileCached[TILE_2BIT_EVEN][address >> 4] = FALSE;
	IPPU.TileCached[TILE_2BIT_EVEN][((address >> 4) - 1) & (MAX_2BIT_TILES - 1)] = FALSE;
	IPPU.TileCached[TILE_2BIT_ODD] [address >> 4] = FALSE;
	IPPU.TileCached[TILE_2BIT_ODD] [((address >> 4) - 1) & (MAX_2BIT_TILES - 1)] = FALSE;
	IPPU.TileCached[TILE_4BIT_EVEN][address >> 5] = FALSE;
	IPPU.TileCached[TILE_4BIT_EVEN][((address >> 5) - 1) & (MAX_4BIT_TILES - 1)] = FALSE;
	IPPU.TileCached[TILE_4BIT_ODD] [address >> 5] = FALSE;
	IPPU.TileCached[TILE_4BIT_ODD] [((address >> 5) - 1) & (MAX_4BIT_TILES - 1)] = FALSE;

	if (!PPU.VMA.High)
		PPU.VMA.Address += PPU.VMA.Increment;
}

#undef CHECK_INBLANK
#ifdef DEBUGGER
#define CHECK_INBLANK() \
    if (!PPU.ForcedBlanking && CPU.V_Counter < PPU.ScreenHeight + FIRST_VISIBLE_LINE) \
    { \
        printf("Invalid VRAM acess at (%04d, %04d) blank:%d\n", CPU.Cycles, CPU.V_Counter, PPU.ForcedBlanking); \
        if (Settings.BlockInvalidVRAMAccess) \
        { \
            PPU.VMA.Address += PPU.VMA.High ? PPU.VMA.Increment : 0; \
            return; \
        } \
    }
#else
#define CHECK_INBLANK() \
        if (Settings.BlockInvalidVRAMAccess && !PPU.ForcedBlanking && CPU.V_Counter < PPU.ScreenHeight + FIRST_VISIBLE_LINE) \
        { \
            PPU.VMA.Address += PPU.VMA.High ? PPU.VMA.Increment : 0; \
            return; \
        }
#endif


static inline void REGISTER_2119 (uint8 Byte)
{
	CHECK_INBLANK();
	uint32	address;

	if (PPU.VMA.FullGraphicCount)
	{
		uint32 rem = PPU.VMA.Address & PPU.VMA.Mask1;
		address = ((((PPU.VMA.Address & ~PPU.VMA.Mask1) + (rem >> PPU.VMA.Shift) + ((rem & (PPU.VMA.FullGraphicCount - 1)) << 3)) << 1) + 1) & 0xffff;
		Memory.VRAM[address] = Byte;
	}
	else
		Memory.VRAM[address = ((PPU.VMA.Address << 1) + 1) & 0xffff] = Byte;

	IPPU.TileCached[TILE_2BIT][address >> 4] = FALSE;
	IPPU.TileCached[TILE_4BIT][address >> 5] = FALSE;
	IPPU.TileCached[TILE_8BIT][address >> 6] = FALSE;
	IPPU.TileCached[TILE_2BIT_EVEN][address >> 4] = FALSE;
	IPPU.TileCached[TILE_2BIT_EVEN][((address >> 4) - 1) & (MAX_2BIT_TILES - 1)] = FALSE;
	IPPU.TileCached[TILE_2BIT_ODD] [address >> 4] = FALSE;
	IPPU.TileCached[TILE_2BIT_ODD] [((address >> 4) - 1) & (MAX_2BIT_TILES - 1)] = FALSE;
	IPPU.TileCached[TILE_4BIT_EVEN][address >> 5] = FALSE;
	IPPU.TileCached[TILE_4BIT_EVEN][((address >> 5) - 1) & (MAX_4BIT_TILES - 1)] = FALSE;
	IPPU.TileCached[TILE_4BIT_ODD] [address >> 5] = FALSE;
	IPPU.TileCached[TILE_4BIT_ODD] [((address >> 5) - 1) & (MAX_4BIT_TILES - 1)] = FALSE;

	if (PPU.VMA.High)
	{
	#ifdef DEBUGGER
		if (Settings.TraceVRAM && !CPU.InDMAorHDMA)
			printf("VRAM write word: $%04X (%d, %d)\n", PPU.VMA.Address, Memory.FillRAM[0x2115] & 3, (Memory.FillRAM[0x2115] & 0x0c) >> 2);
	#endif
		PPU.VMA.Address += PPU.VMA.Increment;
	}
}

static inline void REGISTER_2119_tile (uint8 Byte)
{
	CHECK_INBLANK();

	uint32 rem = PPU.VMA.Address & PPU.VMA.Mask1;
	uint32 address = ((((PPU.VMA.Address & ~PPU.VMA.Mask1) + (rem >> PPU.VMA.Shift) + ((rem & (PPU.VMA.FullGraphicCount - 1)) << 3)) << 1) + 1) & 0xffff;

	Memory.VRAM[address] = Byte;

	IPPU.TileCached[TILE_2BIT][address >> 4] = FALSE;
	IPPU.TileCached[TILE_4BIT][address >> 5] = FALSE;
	IPPU.TileCached[TILE_8BIT][address >> 6] = FALSE;
	IPPU.TileCached[TILE_2BIT_EVEN][address >> 4] = FALSE;
	IPPU.TileCached[TILE_2BIT_EVEN][((address >> 4) - 1) & (MAX_2BIT_TILES - 1)] = FALSE;
	IPPU.TileCached[TILE_2BIT_ODD] [address >> 4] = FALSE;
	IPPU.TileCached[TILE_2BIT_ODD] [((address >> 4) - 1) & (MAX_2BIT_TILES - 1)] = FALSE;
	IPPU.TileCached[TILE_4BIT_EVEN][address >> 5] = FALSE;
	IPPU.TileCached[TILE_4BIT_EVEN][((address >> 5) - 1) & (MAX_4BIT_TILES - 1)] = FALSE;
	IPPU.TileCached[TILE_4BIT_ODD] [address >> 5] = FALSE;
	IPPU.TileCached[TILE_4BIT_ODD] [((address >> 5) - 1) & (MAX_4BIT_TILES - 1)] = FALSE;

	if (PPU.VMA.High)
		PPU.VMA.Address += PPU.VMA.Increment;
}

static inline void REGISTER_2119_linear (uint8 Byte)
{
	CHECK_INBLANK();

	uint32	address;

	Memory.VRAM[address = ((PPU.VMA.Address << 1) + 1) & 0xffff] = Byte;

	IPPU.TileCached[TILE_2BIT][address >> 4] = FALSE;
	IPPU.TileCached[TILE_4BIT][address >> 5] = FALSE;
	IPPU.TileCached[TILE_8BIT][address >> 6] = FALSE;
	IPPU.TileCached[TILE_2BIT_EVEN][address >> 4] = FALSE;
	IPPU.TileCached[TILE_2BIT_EVEN][((address >> 4) - 1) & (MAX_2BIT_TILES - 1)] = FALSE;
	IPPU.TileCached[TILE_2BIT_ODD] [address >> 4] = FALSE;
	IPPU.TileCached[TILE_2BIT_ODD] [((address >> 4) - 1) & (MAX_2BIT_TILES - 1)] = FALSE;
	IPPU.TileCached[TILE_4BIT_EVEN][address >> 5] = FALSE;
	IPPU.TileCached[TILE_4BIT_EVEN][((address >> 5) - 1) & (MAX_4BIT_TILES - 1)] = FALSE;
	IPPU.TileCached[TILE_4BIT_ODD] [address >> 5] = FALSE;
	IPPU.TileCached[TILE_4BIT_ODD] [((address >> 5) - 1) & (MAX_4BIT_TILES - 1)] = FALSE;

	if (PPU.VMA.High)
		PPU.VMA.Address += PPU.VMA.Increment;
}

static inline void REGISTER_2122 (uint8 Byte)
{
	if (PPU.CGFLIP)
	{
		if ((Byte & 0x7f) != (PPU.CGDATA[PPU.CGADD] >> 8) || PPU.CGSavedByte != (uint8) (PPU.CGDATA[PPU.CGADD] & 0xff))
		{
			FLUSH_REDRAW();
			PPU.CGDATA[PPU.CGADD] = (Byte & 0x7f) << 8 | PPU.CGSavedByte;
			IPPU.ColorsChanged = TRUE;
			IPPU.Red[PPU.CGADD] = IPPU.XB[PPU.CGSavedByte & 0x1f];
			IPPU.Blue[PPU.CGADD] = IPPU.XB[(Byte >> 2) & 0x1f];
			IPPU.Green[PPU.CGADD] = IPPU.XB[(PPU.CGDATA[PPU.CGADD] >> 5) & 0x1f];
			IPPU.ScreenColors[PPU.CGADD] = (uint16) BUILD_PIXEL(IPPU.Red[PPU.CGADD], IPPU.Green[PPU.CGADD], IPPU.Blue[PPU.CGADD]);
		}

		PPU.CGADD++;
	}
	else
	{
		PPU.CGSavedByte = Byte;
	}

	PPU.CGFLIP ^= 1;
}

static inline void REGISTER_2180 (uint8 Byte)
{
	Memory.RAM[PPU.WRAM++] = Byte;
	PPU.WRAM &= 0x1ffff;
}

static inline uint8 REGISTER_4212 (void)
{
	uint8	byte = 0;

    if ((CPU.V_Counter >= PPU.ScreenHeight + FIRST_VISIBLE_LINE) && (CPU.V_Counter < PPU.ScreenHeight + FIRST_VISIBLE_LINE + 3))
		byte = 1;
	if ((CPU.Cycles < Timings.HBlankEnd) || (CPU.Cycles >= Timings.HBlankStart))
		byte |= 0x40;
    if (CPU.V_Counter >= PPU.ScreenHeight + FIRST_VISIBLE_LINE)
		byte |= 0x80;

    return (byte);
}

#endif
