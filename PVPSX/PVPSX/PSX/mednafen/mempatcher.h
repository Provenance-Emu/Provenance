#ifndef __MDFN_MEMPATCHER_H
#define __MDFN_MEMPATCHER_H

#include "mempatcher-driver.h"
#include "Stream.h"
#include <vector>

// Substitution cheat/patch stuff
struct SUBCHEAT
{
	uint32 addr;
	uint8 value;
	int compare; // < 0 on no compare
};

extern std::vector<SUBCHEAT> SubCheats[8];
extern bool SubCheatsOn;


bool MDFNMP_Init(uint32 ps, uint32 numpages);
void MDFNMP_AddRAM(uint32 size, uint32 address, uint8 *RAM, bool use_in_search = true);
void MDFNMP_Kill(void);

void MDFN_LoadGameCheats(Stream* override = NULL);
void MDFNMP_InstallReadPatches(void);
void MDFNMP_RemoveReadPatches(void);

void MDFNMP_ApplyPeriodicCheats(void);

extern MDFNSetting MDFNMP_Settings[];

#endif
