/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#ifndef _MSU1_H_
#define _MSU1_H_
#include "snes9x.h"

#define MSU1_REVISION 0x02

struct SMSU1
{
	uint8	MSU1_STATUS;
	uint32	MSU1_DATA_SEEK;
	uint32	MSU1_DATA_POS;
	uint16	MSU1_TRACK_SEEK;
	uint16	MSU1_CURRENT_TRACK;
	uint32	MSU1_RESUME_TRACK;
	uint8	MSU1_VOLUME;
	uint8	MSU1_CONTROL;
	uint32	MSU1_AUDIO_POS;
	uint32	MSU1_RESUME_POS;
};

enum SMSU1_FLAG {
	Revision		= 0x07,	// bitmask, not the actual version number
	AudioError		= 0x08,
	AudioPlaying		= 0x10,
	AudioRepeating		= 0x20,
	AudioBusy		= 0x40,
	DataBusy		= 0x80
};

enum SMSU1_CMD {
	Play			= 0x01,
	Repeat			= 0x02,
	Resume			= 0x04
};

extern struct SMSU1	MSU1;

void S9xResetMSU(void);
void S9xMSU1Init(void);
void S9xMSU1DeInit(void);
bool S9xMSU1ROMExists(void);
STREAM S9xMSU1OpenFile(const char *msu_ext, bool skip_unpacked = FALSE);
void S9xMSU1Init(void);
void S9xMSU1Generate(size_t sample_count);
uint8 S9xMSU1ReadPort(uint8 port);
void S9xMSU1WritePort(uint8 port, uint8 byte);
size_t S9xMSU1Samples(void);
class Resampler;
void S9xMSU1SetOutput(Resampler *resampler);
void S9xMSU1PostLoadState(void);

#endif
