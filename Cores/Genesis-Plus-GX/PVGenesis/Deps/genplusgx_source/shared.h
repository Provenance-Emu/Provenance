#ifndef _SHARED_H_
#define _SHARED_H_

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include "types.h"
#include "osd.h"
#include "macros.h"
#include "loadrom.h"
#include "m68k.h"
#include "z80.h"
#include "system.h"
#include "genesis.h"
#include "vdp_ctrl.h"
#include "vdp_render.h"
#include "mem68k.h"
#include "memz80.h"
#include "membnk.h"
#include "io_ctrl.h"
#include "input.h"
#include "sound.h"
#include "psg.h"
#include "ym2413.h"
#include "ym2612.h"
#ifdef HAVE_YM3438_CORE
#include "ym3438.h"
#endif
#ifdef HAVE_OPLL_CORE
#include "opll.h"
#endif
#include "sram.h"
#include "ggenie.h"
#include "areplay.h"
#include "svp.h"
#include "state.h"

#endif /* _SHARED_H_ */

