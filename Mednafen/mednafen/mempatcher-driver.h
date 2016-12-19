#ifndef __MDFN_MEMPATCHER_DRIVER_H
#define __MDFN_MEMPATCHER_DRIVER_H

struct MemoryPatch
{
 MemoryPatch();
 ~MemoryPatch();

 std::string name;
 std::string conditions;

 uint32 addr;
 uint64 val;
 uint64 compare;

 uint32 mltpl_count;
 uint32 mltpl_addr_inc;
 uint64 mltpl_val_inc;

 uint32 copy_src_addr;
 uint32 copy_src_addr_inc;

 unsigned length;
 bool bigendian;
 bool status;	// (in)active
 unsigned icount;

 char type; /* 'R' for replace, 'S' for substitute(GG), 'C' for substitute with compare */
	    /* 'T' for copy/transfer data, 'A' for add(variant of type R) */

 //enum { TypeReplace, TypeSubst, TypeCompSubst };
 //int type;
};


int MDFNI_DecodePAR(const char *code, uint32 *a, uint8 *v, uint8 *c, char *type);

void MDFNI_AddCheat(const MemoryPatch& patch);
void MDFNI_DelCheat(uint32 which);

int MDFNI_ToggleCheat(uint32 which);

int32 MDFNI_CheatSearchGetCount(void);
void MDFNI_CheatSearchGetRange(uint32 first, uint32 last, int (*callb)(uint32 a, uint8 last, uint8 current));
void MDFNI_CheatSearchGet(int (*callb)(uint32 a, uint64 last, uint64 current, void *data), void *data);
void MDFNI_CheatSearchBegin(void);
void MDFNI_CheatSearchEnd(int type, uint64 v1, uint64 v2, unsigned int bytelen, bool bigendian);
void MDFNI_ListCheats(int (*callb)(const MemoryPatch& patch, void *data), void *data);

MemoryPatch MDFNI_GetCheat(uint32 which);
void MDFNI_SetCheat(uint32 which, const MemoryPatch& patch);

void MDFNI_CheatSearchShowExcluded(void);
void MDFNI_CheatSearchSetCurrentAsOriginal(void);

#endif
