#pragma once
#include "types.h"

void os_SetWindowText(const char* text);
void os_MakeExecutable(void* ptr, u32 sz);
double os_GetSeconds();

void os_DoEvents();
void os_CreateWindow();
void os_SetupInput();
void WriteSample(s16 right, s16 left);

#if BUILD_COMPILER==COMPILER_VC
#include <intrin.h>
#endif

u32 static INLINE bitscanrev(u32 v)
{
#if (BUILD_COMPILER==COMPILER_GCC)
	return 31-__builtin_clz(v);
#else
	unsigned long rv;
	_BitScanReverse(&rv,v);
	return rv;
#endif
}

//FIX ME
#define __assume(x)

void os_DebugBreak();
