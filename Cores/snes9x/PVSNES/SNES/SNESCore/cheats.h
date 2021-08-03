/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#ifndef _CHEATS_H_
#define _CHEATS_H_

#include "port.h"
#include <vector>

struct SCheat
{
	uint32	address;
	uint8	byte;
	uint8	saved_byte;
	bool8	conditional;
	bool8	cond_true;
	uint8	cond_byte;
	bool8	enabled;
};

struct SCheatGroup
{
	char *name;
	bool8 enabled;
	std::vector<struct SCheat> c;
};

struct SCheatData
{
	std::vector<struct SCheatGroup> g;
	bool8	enabled;
	uint8	CWRAM[0x20000];
	uint8	CSRAM[0x10000];
	uint8	CIRAM[0x2000];
	uint8	*RAM;
	uint8	*FillRAM;
	uint8	*SRAM;
	uint32	ALL_BITS[0x32000 >> 5];
	uint8	CWatchRAM[0x32000];
};

struct Watch
{
	bool	on;
	int		size;
	int		format;
	uint32	address;
	char	buf[12];
	char	desc[32];
};

typedef enum
{
	S9X_LESS_THAN,
	S9X_GREATER_THAN,
	S9X_LESS_THAN_OR_EQUAL,
	S9X_GREATER_THAN_OR_EQUAL,
	S9X_EQUAL,
	S9X_NOT_EQUAL
}	S9xCheatComparisonType;

typedef enum
{
	S9X_8_BITS,
	S9X_16_BITS,
	S9X_24_BITS,
	S9X_32_BITS
}	S9xCheatDataSize;

extern SCheatData	Cheat;
extern Watch		watches[16];

int S9xAddCheatGroup (const char *name, const char *cheat);
int S9xModifyCheatGroup (uint32 index, const char *name, const char *cheat);
void S9xEnableCheatGroup (uint32 index);
void S9xDisableCheatGroup (uint32 index);
void S9xDeleteCheats (void);
char *S9xCheatGroupToText (uint32 index);
void S9xDeleteCheatGroup (uint32 index);
bool8 S9xLoadCheatFile (const char *filename);
bool8 S9xSaveCheatFile (const char *filename);
void S9xUpdateCheatsInMemory (void);
int S9xImportCheatsFromDatabase(const char *filename);
void S9xCheatsDisable (void);
void S9xCheatsEnable (void);
char *S9xCheatValidate (char *cheat);

void S9xInitCheatData (void);
void S9xInitWatchedAddress (void);
void S9xStartCheatSearch (SCheatData *);
void S9xSearchForChange (SCheatData *, S9xCheatComparisonType, S9xCheatDataSize, bool8, bool8);
void S9xSearchForValue (SCheatData *, S9xCheatComparisonType, S9xCheatDataSize, uint32, bool8, bool8);
void S9xSearchForAddress (SCheatData *, S9xCheatComparisonType, S9xCheatDataSize, uint32, bool8);
void S9xOutputCheatSearchResults (SCheatData *);

const char * S9xGameGenieToRaw (const char *, uint32 &, uint8 &);
const char * S9xProActionReplayToRaw (const char *, uint32 &, uint8 &);
const char * S9xGoldFingerToRaw (const char *, uint32 &, bool8 &, uint8 &, uint8 bytes[3]);

#endif
