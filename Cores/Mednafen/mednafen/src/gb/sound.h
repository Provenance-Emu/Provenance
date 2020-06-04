#ifndef __MDFN_GB_SOUND_H
#define __MDFN_GB_SOUND_H

namespace MDFN_IEN_GB
{

uint32 SOUND_Read(int ts, uint32_t addr);
void SOUND_Write(int ts, uint32 addr, uint8 val);

int32 SOUND_Flush(int ts, int16 *SoundBuf, const int32 MaxSoundFrames);
void SOUND_Init(void) MDFN_COLD;
void SOUND_Kill(void) MDFN_COLD;
void SOUND_Reset(void) MDFN_COLD;
void SOUND_StateAction(StateMem *sm, int load, int data_only);

bool MDFNGB_SetSoundRate(uint32 rate);

}

#endif

