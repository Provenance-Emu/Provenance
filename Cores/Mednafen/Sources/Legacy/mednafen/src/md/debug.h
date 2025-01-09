#ifndef __MDFN_MD_DEBUG_H
#define __MDFN_MD_DEBUG_H

#ifdef WANT_DEBUGGER
namespace MDFN_IEN_MD
{


MDFN_HIDE extern DebuggerInfoStruct DBGInfo;
void MDDBG_Init(void) MDFN_COLD;
void MDDBG_CPUHook(void);

MDFN_HIDE extern bool MD_DebugMode;


};

#endif

#endif
