#ifndef _SHARED_H_
#define _SHARED_H_

#include <mednafen/mednafen.h>

#include <mednafen/hw_cpu/c68k/c68k.h>
#include <mednafen/hw_cpu/z80-fuse/z80.h>
#include <mednafen/state.h>

#include <stdio.h>
#include <math.h>

enum
{
 CLOCK_NTSC = 53693175,
 CLOCK_PAL = 53203424 // Is this correct?
};

#include "macros.h"
#include "header.h"
#include "debug.h"
#include "genesis.h"
#include "mem68k.h"
#include "memz80.h"
#include "membnk.h"
#include "memvdp.h"
#include "system.h"
#include "genio.h"
#include "sound.h"
#include "vdp.h"

using namespace MDFN_IEN_MD;

#endif /* _SHARED_H_ */

