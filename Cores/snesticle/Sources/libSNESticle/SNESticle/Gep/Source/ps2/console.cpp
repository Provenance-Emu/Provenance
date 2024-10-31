
//#include <stdarg.h>
#include <stdlib.h>
#include "types.h"
#include "console.h"
#include "msgnode.h"

#if 0
CMsgNode	_Console_Stdin;
CMsgStdout	_Console_Stdout;

CMsgNode	_Console_Channel[CON_MAXCHANNELS];

CMsgNode *ConGetChannel(Int32 iChannel)
{
	if (iChannel>=0 && iChannel < CON_MAXCHANNELS)
	{
		return &_Console_Channel[iChannel];
	}

	return NULL;
}
#endif

void ConInit()
{
    #if 0
	_Console_Channel[CON_STANDARD].ConnectTo(&_Console_Stdout);
	_Console_Channel[CON_ERROR].ConnectTo(&_Console_Stdout);
	_Console_Channel[CON_WARNING].ConnectTo(&_Console_Stdout);
	_Console_Channel[CON_DEBUG].ConnectTo(&_Console_Stdout);
    #endif
}

void ConShutdown()
{

}

#if 0

void ConPrintv(Int32 iChannel, Char *pFormat, va_list *pArgPtr)
{
	Char Str[256];
	CMsgNode *pChannel;

	// get channel
	pChannel = ConGetChannel(iChannel);

	if (pChannel)
	{
		// format string
		vsprintf(Str, pFormat, *pArgPtr);

		// send to channel
		pChannel->SendStr(Str);
	}
}

void ConPrint(Char *pFormat, ...)
{
	va_list argptr;
	va_start(argptr,pFormat);
	ConPrintv(CON_STANDARD, pFormat, &argptr);
	va_end(argptr);
}


void ConError(Char *pFormat, ...)
{
	va_list argptr;
	va_start(argptr,pFormat);
	ConPrintv(CON_ERROR, pFormat, &argptr);
	va_end(argptr);
}


void ConWarning(Char *pFormat, ...)
{
	va_list argptr;
	va_start(argptr,pFormat);
	ConPrintv(CON_WARNING, pFormat, &argptr);
	va_end(argptr);
}

void ConDebug(Char *pFormat, ...)
{
	va_list argptr;
	va_start(argptr,pFormat);
	ConPrintv(CON_DEBUG, pFormat, &argptr);
	va_end(argptr);
}

void ConPrintf(Int32 iChannel, Char *pFormat, ...)
{
	va_list argptr;
	va_start(argptr,pFormat);
	ConPrintv(iChannel, pFormat, &argptr);
	va_end(argptr);
}

void ConStdin(Char *pStr)
{
	// send to stdin
	_Console_Stdin.SendStr(pStr);
}


#endif


