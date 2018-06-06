#ifndef __MDFN_MEMPATCHER_H
#define __MDFN_MEMPATCHER_H

#include "mempatcher-driver.h"
#include "Stream.h"

// Substitution cheat/patch stuff
struct SUBCHEAT
{
	uint32 addr;
	uint8 value;
	int compare; // < 0 on no compare
};

extern std::vector<SUBCHEAT> SubCheats[8];
extern bool SubCheatsOn;


void MDFNMP_Init(uint32 ps, uint32 numpages) MDFN_COLD;
void MDFNMP_AddRAM(uint32 size, uint32 address, uint8 *RAM, bool use_in_search = true);	// Deprecated
void MDFNMP_RegSearchable(uint32 addr, uint32 size);
void MDFNMP_Kill(void) MDFN_COLD;

void MDFN_LoadGameCheats(Stream* override = NULL);
void MDFNMP_InstallReadPatches(void);
void MDFNMP_RemoveReadPatches(void);

void MDFNMP_ApplyPeriodicCheats(void);

extern const MDFNSetting MDFNMP_Settings[];

#endif
