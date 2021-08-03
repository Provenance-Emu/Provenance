/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#ifndef _FXEMU_H_
#define _FXEMU_H_

#define FX_BREAKPOINT				(-1)
#define FX_ERROR_ILLEGAL_ADDRESS	(-2)

// The FxInfo_s structure, the link between the FxEmulator and the Snes Emulator
struct FxInfo_s
{
	uint32	vFlags;
	uint8	*pvRegisters;	// 768 bytes located in the memory at address 0x3000
	uint32	nRamBanks;		// Number of 64kb-banks in GSU-RAM/BackupRAM (banks 0x70-0x73)
	uint8	*pvRam;			// Pointer to GSU-RAM
	uint32	nRomBanks;		// Number of 32kb-banks in Cart-ROM
	uint8	*pvRom;			// Pointer to Cart-ROM
	uint32	speedPerLine;
	bool8	oneLineDone;
};

extern struct FxInfo_s	SuperFX;

void S9xInitSuperFX (void);
void S9xResetSuperFX (void);
void S9xSuperFXExec (void);
void S9xSetSuperFX (uint8, uint16);
uint8 S9xGetSuperFX (uint16);
void fx_flushCache (void);
void fx_computeScreenPointers (void);
uint32 fx_run (uint32);

#endif
