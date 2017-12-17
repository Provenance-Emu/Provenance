#ifndef __PCFX_DEBUG_H
#define __PCFX_DEBUG_H

#ifdef WANT_DEBUGGER

void PCFXDBG_CheckBP(int type, uint32 address, uint32 value, unsigned int len);

void PCFXDBG_SetLogFunc(void (*func)(const char *, const char *));

void PCFXDBG_DoLog(const char *type, const char *format, ...);
char *PCFXDBG_ShiftJIS_to_UTF8(const uint16 sjc);


extern bool PCFX_LoggingOn;

void PCFXDBG_Init(void);
extern DebuggerInfoStruct PCFXDBGInfo;

#endif

#endif
