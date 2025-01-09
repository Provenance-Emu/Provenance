



#ifndef _CONSOLE_H
#define _CONSOLE_H

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

enum
{
	CON_STANDARD,
	CON_WARNING,
	CON_ERROR,
	CON_SYSTEM,
	CON_DEBUG,
	CON_NETWORK,

	CON_MAXCHANNELS
};

void ConInit();
void ConShutdown();

void ConPrint(Char *pFormat, ...);
void ConWarning(Char *pFormat, ...);
void ConError(Char *pFormat, ...);
void ConDebug(Char *pFormat, ...);

void ConPrintf(Int32 iChannel, Char *pFormat, ...);

void ConStdin(Char *pStr);

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif
