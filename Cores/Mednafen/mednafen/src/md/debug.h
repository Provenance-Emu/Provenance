#ifndef __MDFN_MD_DEBUG_H
#define __MDFN_MD_DEBUG_H

#ifdef WANT_DEBUGGER
namespace MDFN_IEN_MD
{


extern DebuggerInfoStruct DBGInfo;
void MDDBG_Init(void) MDFN_COLD;
void MDDBG_CPUHook(void);

extern bool MD_DebugMode;


};

#endif

#endif
