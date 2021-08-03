/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

/*****
 * S-RTC emulation code
 * Copyright (c) byuu
 *****/


#include <limits>

#include "snes9x.h"
#include "memmap.h"
#include "srtc.h"
#include "display.h"

#define memory_cartrtc_read(a)		RTCData.reg[(a)]
#define memory_cartrtc_write(a, b)	{ RTCData.reg[(a)] = (b); }
#define cpu_regs_mdr				OpenBus

static inline unsigned max (unsigned a, unsigned b)
{
	return ((a > b) ? a : b);
}

static inline unsigned min (unsigned a, unsigned b)
{
	return ((a < b) ? a : b);
}

#include "srtcemu.h"
#include "srtcemu.cpp"

static SRTC	srtcemu;


void S9xInitSRTC (void)
{
	srtcemu.power();
	memset(RTCData.reg, 0, 20);
}

void S9xResetSRTC (void)
{
	srtcemu.reset();
}

void S9xSetSRTC (uint8 data, uint16 address)
{
	srtcemu.mmio_write(address, data);
}

uint8 S9xGetSRTC (uint16 address)
{
	return (srtcemu.mmio_read(address));
}

void S9xSRTCPreSaveState (void)
{
	srtcsnap.rtc_mode  = (int32) srtcemu.rtc_mode;
	srtcsnap.rtc_index = (int32) srtcemu.rtc_index;
}

void S9xSRTCPostLoadState (int)
{
	srtcemu.rtc_mode  = (SRTC::RTC_Mode) srtcsnap.rtc_mode;
	srtcemu.rtc_index = (signed)         srtcsnap.rtc_index;

	srtcemu.update_time();
}
