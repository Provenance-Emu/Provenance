


#include <stdio.h>
#include <stdarg.h>
#include "types.h"
#include "snes.h"
#include "sndebug.h"

#if SNES_DEBUG

static SnesSystem *_Snes_pDebugSnes;
static FILE *_Snes_pDebugFile;

extern "C" {
#if 1
Bool Snes_bDebugFrame       = false;
Bool Snes_bDebugIO          = false;
Bool Snes_bDebugUnhandledIO = false;
Bool Snes_bDebugINT         = false;
#else
Bool Snes_bDebugFrame       = true;
Bool Snes_bDebugIO          = true;
Bool Snes_bDebugUnhandledIO = false;
Bool Snes_bDebugINT         = true;
#endif

void SnesDebug(const char *pFormat, ...)
{
    if (_Snes_pDebugFile)
    {
        char str[256];
        va_list argptr;
        va_start(argptr,pFormat);
        vsprintf(str, pFormat, argptr);
        va_end(argptr);


        fprintf(_Snes_pDebugFile, 
            "%06d:%03d:%04d %s", 
            _Snes_pDebugSnes->GetFrame(),
            _Snes_pDebugSnes->GetLine(),
            SNCPUGetCounter(_Snes_pDebugSnes->GetCpu(), SNCPU_COUNTER_LINE),
            str
            );
    }
}

void SnesDebugRead(Uint32 uAddr)
{
    SnesDebug(" read8[%04X] (%s)\n", uAddr, SnesSystem::GetRegName(uAddr));
}

void SnesDebugReadData(Uint32 uAddr, Uint8 uData)
{
    SnesDebug(" read8[%04X]=%02X (%s)\n", uAddr, uData, SnesSystem::GetRegName(uAddr));
}


void SnesDebugWrite(Uint32 uAddr, Uint8 uData)
{
    SnesDebug("write8[%04X]=%02X (%s)\n", uAddr, uData, SnesSystem::GetRegName(uAddr) );
}
};

void SnesDebugBegin(SnesSystem *pSnes, const char *pFileName)
{
    if (_Snes_pDebugSnes == NULL)
    {
        _Snes_pDebugSnes = pSnes;
        _Snes_pDebugFile = fopen(pFileName, "wt");
    }
}
void SnesDebugEnd()
{
    if (_Snes_pDebugFile)
        fclose(_Snes_pDebugFile);
    _Snes_pDebugFile = NULL;
    _Snes_pDebugSnes = NULL;
}

#endif


