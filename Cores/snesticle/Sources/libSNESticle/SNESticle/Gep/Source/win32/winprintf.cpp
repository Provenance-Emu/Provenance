
#include <windows.h>
#include "types.h"
#include <stdio.h>




void WinPrintf(Char *pFormat, ...)
{
	Char str[256];

	ShowCursor(TRUE);
	va_list argptr;
	va_start(argptr,pFormat);
	vsprintf(str,pFormat,argptr);
	va_end(argptr);
	MessageBox(NULL,str,"Message",MB_OK|MB_SETFOREGROUND);
	ShowCursor(FALSE);
}

