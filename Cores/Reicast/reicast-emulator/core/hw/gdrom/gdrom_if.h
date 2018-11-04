/*
**	gdrom_if.h
*/
#ifndef __GDROM_IF_H__
#define __GDROM_IF_H__

#include "types.h"
#include "types.h"

//there were at least 4 gdrom implementations, ZGDROM, HLE, gdromv1 (never worked), gdromv2 (first release)
//i removed the #defines to select them as they are now redundant, so this just becomes a part of
//the code's history :)
#include "gdromv3.h"

void gdrom_reg_Init(void);
void gdrom_reg_Term(void);
void gdrom_reg_Reset(bool Manual);

u32  ReadMem_gdrom(u32 Addr, u32 sz);
void WriteMem_gdrom(u32 Addr, u32 data, u32 sz);
void NotifyEvent_gdrom(u32 info,void* param);

#endif //__GDROM_IF_H__
