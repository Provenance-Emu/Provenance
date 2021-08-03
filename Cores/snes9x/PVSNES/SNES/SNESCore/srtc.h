/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#ifndef _SRTC_H_
#define _SRTC_H_

struct SRTCData
{
	uint8	reg[20];
};

// for snapshot only
struct SSRTCSnapshot
{
	int32	rtc_mode;	// enum RTC_Mode
	int32	rtc_index;	// signed
};

extern struct SRTCData		RTCData;
extern struct SSRTCSnapshot	srtcsnap;

void S9xInitSRTC (void);
void S9xResetSRTC (void);
void S9xSRTCPreSaveState (void);
void S9xSRTCPostLoadState (int);
void S9xSetSRTC (uint8, uint16);
uint8 S9xGetSRTC (uint16);

#endif
