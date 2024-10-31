#ifndef __LOG_H__
#define __LOG_H__

#define LOG_NONE	0
#define LOG_ERROR   1
#define LOG_MINIMAL	2
#define LOG_WARNING 3
#define LOG_VERBOSE 4
#define LOG_APIFUNC 5

#define LOG_LEVEL LOG_WARNING

#if LOG_LEVEL > 0

#include "Types.h"

void LOG(u16 type, const char * format, ...);

#else

#define LOG(A, ...)

#endif

#if defined(OS_WINDOWS) && !defined(MINGW)
void debugPrint(const char * format, ...);
#else
#define debugPrint(A, ...)
#endif

#endif
