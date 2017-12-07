#ifndef __VB_DEBUG_H
#define __VB_DEBUG_H

namespace MDFN_IEN_VB
{

void VBDBG_FlushBreakPoints(int type);
void VBDBG_AddBreakPoint(int type, unsigned int A1, unsigned int A2, bool logical);
void VBDBG_Disassemble(uint32 &a, uint32 SpecialA, char *);

uint32 VBDBG_MemPeek(uint32 A, unsigned int bsize, bool hl, bool logical);

void VBDBG_SetCPUCallback(void (*callb)(uint32 PC, bool bpoint), bool continuous);

void VBDBG_EnableBranchTrace(bool enable);
std::vector<BranchTraceResult> VBDBG_GetBranchTrace(void);

void VBDBG_CheckBP(int type, uint32 address, uint32 value, unsigned int len);

void VBDBG_SetLogFunc(void (*func)(const char *, const char *));

void VBDBG_DoLog(const char *type, const char *format, ...);


extern bool VB_LoggingOn;

bool VBDBG_Init(void);

};

#endif
