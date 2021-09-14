#ifndef __MDFN_DRIVERS_SOUND_H
#define __MDFN_DRIVERS_SOUND_H

bool Sound_Init(MDFNGI *gi) MDFN_COLD;
void Sound_Kill(void) noexcept MDFN_COLD;

bool Sound_NeedReInit(void);

void Sound_Write(int16 *Buffer, int Count);
void Sound_WriteSilence(int ms);

uint32 Sound_CanWrite(void);

int16 *Sound_GetEmuModBuffer(int32 *max_size);

double Sound_GetRate(void);

#endif
