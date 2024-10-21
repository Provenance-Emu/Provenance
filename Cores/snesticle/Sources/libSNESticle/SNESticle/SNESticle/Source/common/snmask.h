

#ifndef _SNMASK_H
#define _SNMASK_H

union SNMaskT 
{
	Uint8   uMask8[32];
	Uint32  uMask32[8];
    Uint64  uMask64[4];
	#if CODE_PLATFORM == CODE_PS2
	Uint128 uMask128[2];
	#endif
} _ALIGN(16);


#include "snmaskop.h"

#endif
