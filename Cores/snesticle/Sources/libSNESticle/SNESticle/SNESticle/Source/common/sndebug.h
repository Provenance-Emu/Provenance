




#ifndef _SNDEBUG_H
#define _SNDEBUG_H

#define SNES_DEBUG (CODE_DEBUG && (CODE_PLATFORM==CODE_WIN32) && 1)

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

#if SNES_DEBUG
void SnesDebug(const char *pFormat, ...);
void SnesDebugRead(Uint32 uAddr);
void SnesDebugReadData(Uint32 uAddr, Uint8 uData);
void SnesDebugWrite(Uint32 uAddr, Uint8 uData);

extern Bool Snes_bDebugFrame       ;
extern Bool Snes_bDebugIO          ;
extern Bool Snes_bDebugUnhandledIO ;
extern Bool Snes_bDebugINT         ;

extern Bool g_bStateDebug;
#endif


#ifdef __cplusplus
}
#endif /* __cplusplus */



#endif
