#ifndef __NES_SOUND_H
#define __NES_SOUND_H

typedef struct __EXPSOUND {
	   void (*HiFill)(void);
	   void (*HiSync)(int32 ts);

	   void (*Kill)(void);
} EXPSOUND;

#include <vector>

extern std::vector<EXPSOUND> GameExpSound;

int FlushEmulateSound(int reverse, int16 *SoundBuf, int32 MaxSoundFrames);

extern MDFN_ALIGN(16) int16 WaveHiEx[40000];

extern uint32 soundtsoffs;
#define SOUNDTS (timestamp + soundtsoffs)

int MDFNSND_Init(bool IsPAL) MDFN_COLD;
void MDFNSND_Close(void) MDFN_COLD;
void MDFNSND_Power(void) MDFN_COLD;
void MDFNSND_Reset(void) MDFN_COLD;
void MDFNSND_SaveState(void);
void MDFNSND_LoadState(int version);

void MDFN_SoundCPUHook(int);
int MDFNSND_StateAction(StateMem *sm, int load, int data_only);
void MDFNNES_SetSoundVolume(uint32 volume) MDFN_COLD;
void MDFNNES_SetSoundMultiplier(double multiplier) MDFN_COLD;
bool MDFNNES_SetSoundRate(double Rate) MDFN_COLD;

#endif
