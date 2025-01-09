
#ifndef _NETPRINT_H
#define _NETPRINT_H

#include <stdlib.h>
#include <stdio.h>
#include <kernel.h>

#if 0
void NetPrintInit();
int NetPrintf( const char * fmt, ... );
#else
#define NetPrintInit()
#define NetPrintf printf
#endif


#endif
