#pragma once

#if 1
#include "../types.h"
#else
//basic types
typedef signed __int8  s8;
typedef signed __int16 s16;
typedef signed __int32 s32;
typedef signed __int64 s64;

typedef unsigned __int8  u8;
typedef unsigned __int16 u16;
typedef unsigned __int32 u32;
typedef unsigned __int64 u64;

typedef float f32;
typedef double f64;

#ifdef X86
typedef u32 unat;
#endif

#ifdef X64
typedef u64 unat;
#endif


//Do not complain when i use enum::member
#pragma warning( disable : 4482)

//unnamed struncts/unions
#pragma warning( disable : 4201)

//unused parameters
#pragma warning( disable : 4100)

*/
//basic includes from runtime lib
#include <stdlib.h>
#include <stdio.h>

#include <vector>
using namespace std;

#ifndef dbgbreak
#define dbgbreak __asm {int 3}
#endif

#ifndef verify
#define verify(x) if((x)==false){ printf("Verify Failed  : " #x "\n in %s -> %s : %d \n",__FUNCTION__,__FILE__,__LINE__); dbgbreak;}
#endif

#ifndef die
#define die(reason) { printf("Fatal error : %s\n in %s -> %s : %d \n",reason,__FUNCTION__,__FILE__,__LINE__); dbgbreak;}
#endif
#endif
