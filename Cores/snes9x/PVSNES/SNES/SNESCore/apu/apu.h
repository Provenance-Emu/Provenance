/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#ifndef _APU_H_
#define _APU_H_

#include "../snes9x.h"

typedef void (*apu_callback) (void *);

#define SPC_SAVE_STATE_BLOCK_SIZE (1024 * 65)
#define SPC_FILE_SIZE             (66048)

bool8 S9xInitAPU (void);
void S9xDeinitAPU (void);
void S9xResetAPU (void);
void S9xSoftResetAPU (void);
uint8 S9xAPUReadPort (int);
void S9xAPUWritePort (int, uint8);
void S9xAPUExecute (void);
void S9xAPUEndScanline (void);
void S9xAPUSetReferenceTime (int32);
void S9xAPUTimingSetSpeedup (int);
void S9xAPULoadState (uint8 *);
void S9xAPULoadBlarggState(uint8 *oldblock);
void S9xAPUSaveState (uint8 *);
void S9xDumpSPCSnapshot (void);
bool8 S9xSPCDump (const char *);

bool8 S9xInitSound (int);
bool8 S9xOpenSoundDevice (void);

bool8 S9xSyncSound (void);
int S9xGetSampleCount (void);
void S9xSetSoundControl (uint8);
void S9xSetSoundMute (bool8);
void S9xLandSamples (void);
void S9xClearSamples (void);
bool8 S9xMixSamples (uint8 *, int);
void S9xSetSamplesAvailableCallback (apu_callback, void *);
void S9xUpdateDynamicRate (int, int);

#define DSP_INTERPOLATION_NONE     0
#define DSP_INTERPOLATION_LINEAR   1
#define DSP_INTERPOLATION_GAUSSIAN 2
#define DSP_INTERPOLATION_CUBIC    3
#define DSP_INTERPOLATION_SINC     4

#endif
