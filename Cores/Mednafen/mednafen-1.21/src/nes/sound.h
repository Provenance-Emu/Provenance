#ifndef __MDFN_NES_SOUND_H
#define __MDFN_NES_SOUND_H

namespace MDFN_IEN_NES
{

typedef struct __EXPSOUND {
	   void (*HiFill)(void);
	   void (*HiSync)(int32 ts);

	   void (*Kill)(void);
} EXPSOUND;

extern std::vector<EXPSOUND> GameExpSound;

int FlushEmulateSound(int reverse, int16 *SoundBuf, int32 MaxSoundFrames);

alignas(16) extern int16 WaveHiEx[2 * 40000];

extern uint32 soundtsoffs;
#define SOUNDTS (timestamp + soundtsoffs)

int MDFNSND_Init(bool IsPAL) MDFN_COLD;
void MDFNSND_Close(void) MDFN_COLD;
void MDFNSND_Power(void) MDFN_COLD;
void MDFNSND_Reset(void) MDFN_COLD;

void MDFN_FASTCALL MDFN_SoundCPUHook(int);
void MDFNSND_StateAction(StateMem *sm, const unsigned load, const bool data_only);
void MDFNNES_SetSoundVolume(uint32 volume) MDFN_COLD;
void MDFNNES_SetSoundMultiplier(double multiplier) MDFN_COLD;
bool MDFNNES_SetSoundRate(double Rate) MDFN_COLD;

}

#endif
