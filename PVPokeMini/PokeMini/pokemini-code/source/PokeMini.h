/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2015  JustBurn

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#ifndef POKEMINI_EMU
#define POKEMINI_EMU

#include <stdint.h>
#include <stdlib.h>

// Common functions
#include "PMCommon.h"
#include "Endianess.h"

// Version control
#include "PokeMini_Version.h"

// Configuration Flags
// No sound support
#define POKEMINI_NOSOUND	0x01
// Generated sound only
#define POKEMINI_GENSOUND	0x02
// Auto battery support
#define POKEMINI_AUTOBATT	0x04

// Default cycles per frame
#define POKEMINI_FRAME_CYC	55634

extern int PokeMini_FreeBIOS;	// Using freebios?
extern int PokeMini_Flags;	// Configuration flags
extern int PokeMini_Rumbling;	// Pokemon-Mini is rumbling
extern uint8_t PM_BIOS[];	// Pokemon-Mini BIOS ($000000 to $000FFF, 4096)
extern uint8_t PM_RAM[];	// Pokemon-Mini RAM  ($001000 to $002100, 4096 + 256)
extern uint8_t *PM_ROM;		// Pokemon-Mini ROM  ($002100 to $1FFFFF, Up to 2MB)
extern int PM_ROM_Alloc;	// Pokemon-Mini ROM Allocated on memory?
extern int PM_ROM_Size;		// Pokemon-Mini ROM Size
extern int PM_ROM_Mask;		// Pokemon-Mini ROM Mask
extern int PokeMini_LCDMode;	// LCD Mode
extern int PokeMini_ColorFormat;	// Color Format (0 = 8x8, 1 = 4x4)
extern int PokeMini_HostBattStatus;	// Host battery status

// Number of cycles to process on hardware
extern int PokeHWCycles;

enum {
	LCDMODE_ANALOG = 0,
	LCDMODE_3SHADES,
	LCDMODE_2SHADES,
	LCDMODE_COLORS
};

// Include Interfaces
#include "IOMap.h"
#include "Video.h"
#include "MinxCPU.h"
#include "MinxTimers.h"
#include "MinxIO.h"
#include "MinxIRQ.h"
#include "MinxPRC.h"
#include "MinxColorPRC.h"
#include "MinxLCD.h"
#include "MinxAudio.h"
#include "CommandLine.h"
#include "Multicart.h"
#include "UI.h"

// Callbacks
extern void (*PokeMini_OnAllocMIN)(int newsize, int success);
extern void (*PokeMini_OnUnzipError)(const char *zipfile, const char *reason);
extern void (*PokeMini_OnLoadBIOSFile)(const char *filename, int success);
extern void (*PokeMini_OnLoadMINFile)(const char *filename, int success);
extern void (*PokeMini_OnLoadColorFile)(const char *filename, int success);
extern void (*PokeMini_OnLoadEEPROMFile)(const char *filename, int success);
extern void (*PokeMini_OnSaveEEPROMFile)(const char *filename, int success);
extern void (*PokeMini_OnLoadStateFile)(const char *filename, int success);
extern void (*PokeMini_OnSaveStateFile)(const char *filename, int success);
extern void (*PokeMini_OnReset)(int hardreset);

extern int (*PokeMini_CustomLoadEEPROM)(const char *filename);
extern int (*PokeMini_CustomSaveEEPROM)(const char *filename);

// PRC Read/Write
#ifdef PERFORMANCE

static inline uint8_t MinxPRC_OnRead(int cpu, uint32_t addr)
{
	if (addr >= 0x2100) {
		// ROM Read
		if (PM_ROM) return PM_ROM[addr & PM_ROM_Mask];
	} else if (addr >= 0x2000) {
		// I/O Read (Unused)
		return 0xFF;
	} else if (addr >= 0x1000) {
		// RAM Read
		return PM_RAM[addr-0x1000];
	} else {
		// BIOS Read
		return PM_BIOS[addr];
	}
	return 0xFF;
}

static inline void MinxPRC_OnWrite(int cpu, uint32_t addr, uint8_t data)
{
	if ((addr >= 0x1000) && (addr < 0x2000)) {
		// RAM Write
		PM_RAM[addr-0x1000] = data;
	}
}

#else

#include "Multicart.h"

#define MinxPRC_OnRead	MinxCPU_OnRead
#define MinxPRC_OnWrite	MinxCPU_OnWrite

#endif

// LCD Framebuffer
#define MinxPRC_LCDfb	PM_RAM

// Load state safe variables
#define POKELOADSS_START(size)\
	uint32_t rsize = 0;\
	uint32_t tmp32;\
	uint16_t tmp16;\
	if (size != bsize) return 0;\
	{ tmp32 = 0; tmp16 = 0; }

#define POKELOADSS_32(var) {\
	rsize += (uint32_t)fread((void *)&tmp32, 1, 4, fi);\
	var = Endian32(tmp32);\
}

#define POKELOADSS_16(var) {\
	rsize += (uint32_t)fread((void *)&tmp16, 1, 2, fi);\
	var = Endian16(tmp16);\
}

#define POKELOADSS_8(var) {\
	rsize += (uint32_t)fread((void *)&var, 1, 1, fi);\
}

#define POKELOADSS_A(array, size) {\
	rsize += (uint32_t)fread((void *)array, 1, size, fi);\
}

#define POKELOADSS_X(size) {\
	rsize += fseek(fi, size, SEEK_CUR) ? 0 : size;\
}

#define POKELOADSS_END(size) {\
	tmp32 = 0; tmp16 = 0;\
	return (rsize == size) + tmp32 + (uint32_t)tmp16;\
}

// Save state safe variables
#define POKESAVESS_START(size)\
	uint32_t wsize = 0;\
	uint32_t tmp32 = Endian32(size);\
	uint16_t tmp16;\
	if (fwrite((void *)&tmp32, 1, 4, fi) != 4) return 0;\
	{ tmp32 = 0; tmp16 = 0; }

#define POKESAVESS_32(var) {\
	tmp32 = Endian32((uint32_t)var);\
	wsize += (uint32_t)fwrite((void *)&tmp32, 1, 4, fi);\
}

#define POKESAVESS_16(var) {\
	tmp16 = Endian16((uint16_t)var);\
	wsize += (uint32_t)fwrite((void *)&tmp16, 1, 2, fi);\
}

#define POKESAVESS_8(var) {\
	wsize += (uint32_t)fwrite((void *)&var, 1, 1, fi);\
}

#define POKESAVESS_A(array, size) {\
	wsize += (uint32_t)fwrite((void *)array, 1, size, fi);\
}

#define POKESAVESS_X(size) {\
	tmp16 = 0;\
	for (tmp32=0; tmp32<(uint32_t)size; tmp32++) {\
		wsize += (uint32_t)fwrite((void *)&tmp16, 1, 1, fi);\
	}\
}

#define POKESAVESS_END(size) {\
	tmp32 = 0; tmp16 = 0;\
	return (wsize == size) + tmp32 + (uint32_t)tmp16;\
}

// Stream I/O
typedef int TPokeMini_StreamIO(void *data, int size, void *ptr);

// Create emulator and all interfaces
int PokeMini_Create(int flags, int soundfifo);

// Destroy emulator and all interfaces
void PokeMini_Destroy();

// Apply changes from command lines
void PokeMini_ApplyChanges();

// User press or release a Pokemon-Mini key
void PokeMini_KeypadEvent(uint8_t key, int pressed);

// Low power battery emulation
void PokeMini_LowPower(int enable);

// Set LCD mode
void PokeMini_SetLCDMode(int mode);

// Generate rumble offset
int PokeMini_GenRumbleOffset(int pitch);

// Load BIOS file
int PokeMini_LoadBIOSFile(const char *filename);

// Save BIOS file
int PokeMini_SaveBIOSFile(const char *filename);

// Load FreeBIOS
int PokeMini_LoadFreeBIOS();

// Check if file exist
int PokeMini_FileExist(const char *filename);

// New MIN ROM
int PokeMini_NewMIN(uint32_t size);

// Load MIN ROM
int PokeMini_LoadMINFile(const char *filename);

// Save MIN ROM
int PokeMini_SaveMINFile(const char *filename);

// Load color information from file, MIN must be loaded first
int PokeMini_LoadColorFile(const char *filename);

// Set MIN from memory
int PokeMini_SetMINMem(uint8_t *mem, int size);

// Syncronize host time
int PokeMini_SyncHostTime();

// Load EEPROM data
int PokeMini_LoadEEPROMFile(const char *filename);

// Save EEPROM data
int PokeMini_SaveEEPROMFile(const char *filename);

// Check emulator state, output romfile from assigned ROM in state
int PokeMini_CheckSSFile(const char *statefile, char *romfile);

// Load emulator state
int PokeMini_LoadSSFile(const char *statefile);

// Save emulator state
int PokeMini_SaveSSFile(const char *statefile, const char *romfile);

// Load MIN ROM (and others)
int PokeMini_LoadROM(const char *filename);

// Load all files from command-line, return false if require menu
int PokeMini_LoadFromCommandLines(const char *nobios, const char *noeeprom);

// Save all files from command-line
void PokeMini_SaveFromCommandLines(int exitemulator);

// Use default callbacks messages
void PokeMini_UseDefaultCallbacks();

// Reset CPU
void PokeMini_Reset(int hardreset);

// Internals, do not call directly!
void PokeMini_FreeColorInfo();

#endif
