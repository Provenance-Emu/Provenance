

/*!

    \File    console.cpp

    \Description
	    Description

    \Notes
	    None.

    \Copyright
	    (c) 2004 Icer Addis

*/


/*-- Include files -------------------------------------------------------------------------------*/

#include <stdlib.h>
#include <stdarg.h>
#include <stdio.h>
#include "types.h"
#include "console.h"

/*-- Preprocessor Defines ------------------------------------------------------------------------*/

/*-- Type Definitions ----------------------------------------------------------------------------*/

/*-- Private Implementation ----------------------------------------------------------------------*/

/*-- Public Implementation -----------------------------------------------------------------------*/


extern "C" {

void ConInit()
{
}

void ConShutdown()
{
}

void ConRedirect(const Char *pFileName)
{
}

void ConPrintv(ConE eConsole, const char *pFormat, va_list *pArgPtr)
{
	char Str[512];

	// format string
	int nChars = vsprintf(Str, pFormat, *pArgPtr);
	assert(nChars < sizeof(Str));

	ConPuts(eConsole, Str);
}

void ConPrint(const char *pFormat, ...)
{
	va_list argptr;
	va_start(argptr,pFormat);
	ConPrintv(CON_STANDARD, pFormat, &argptr);
	va_end(argptr);
}


void ConError(const char *pFormat, ...)
{
	va_list argptr;
	va_start(argptr,pFormat);
	ConPrintv(CON_ERROR, pFormat, &argptr);
	va_end(argptr);
}


void ConWarning(const char *pFormat, ...)
{
	va_list argptr;
	va_start(argptr,pFormat);
	ConPrintv(CON_WARNING, pFormat, &argptr);
	va_end(argptr);
}

void ConDebug(const char *pFormat, ...)
{
	va_list argptr;
	va_start(argptr,pFormat);
	ConPrintv(CON_DEBUG, pFormat, &argptr);
	va_end(argptr);
}

void ConPrintf(const char *pFormat, ...)
{
	va_list argptr;
	va_start(argptr,pFormat);
	ConPrintv(CON_STANDARD, pFormat, &argptr);
	va_end(argptr);
}

}


