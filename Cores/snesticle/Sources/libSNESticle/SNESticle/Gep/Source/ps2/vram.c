
#include <stdlib.h>
#include "types.h"
#include "vram.h"

#define VRAM_MAXADDR   (0x10000)
#define VRAM_MAXBLOCKS (256)

static VramBlockT _Vram_Blocks[VRAM_MAXBLOCKS];
static Uint32 _Vram_nBlocks;

static Uint32 _Vram_uAddr;

static VramBlockT *_VramBlockAlloc()
{
	if (_Vram_nBlocks < VRAM_MAXBLOCKS)
	{
		return &_Vram_Blocks[_Vram_nBlocks++];
	} else
	{
		return NULL;
	}
}



void VramInit()
{
	// set current address
	_Vram_uAddr = 0;
	_Vram_nBlocks = 0;
}

void VramShutdown()
{
}


VramBlockT *VramAlloc(Uint16 uSize, Uint32 uAlignment)
{
	VramBlockT *pBlock = NULL;
	Uint32 uAddr;

	uAddr = _Vram_uAddr;

	if (uAlignment > 0)
	{
		// align address
		uAddr +=  (uAlignment - 1);
		uAddr &= ~(uAlignment - 1);
	}

	// determine if space is available
	if (uAddr < VRAM_MAXADDR)
	{
		pBlock = _VramBlockAlloc();
		if (pBlock)
		{
			// set block info
			pBlock->uAddr = uAddr;
			pBlock->uSize = uSize;
		}

		// allocate space
		uAddr += uSize;
		_Vram_uAddr = uAddr;
	}
	return pBlock;
}




void VramFree(VramBlockT *pBlock)
{
	// not implemented

}

#if 0

Uint32 VramCalcTextureSize(Uint32 uWidth, Uint32 uHeight, Uint32 eFormat)
{
    int numq;

    numq = uWidth * uHeight;
    switch (pxlfmt)
    {
    case 0x00: numq = (numq+0x03) >> 2; break;
    case 0x02: numq = (numq+0x07) >> 3; break;
    case 0x13: numq = (numq+0x0F) >> 4; break;
    case 0x14: numq = (numq+0x1F) >> 5; break;
    default:   numq = 0;
    }

	return numq;
}
#endif
