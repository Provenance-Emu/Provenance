#ifndef PLATFORM_H
#define PLATFORM_H

#ifdef OS_WINDOWS
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#else
#include "winlnxdefs.h"
#endif

#ifdef PANDORA
typedef char GLchar;
#endif

#endif // PLATFORM_H
