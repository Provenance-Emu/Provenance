#ifndef _PCFX_SOUNDBOX_H
#define _PCFX_SOUNDBOX_H

bool SoundBox_SetSoundRate(uint32 rate);
int32 SoundBox_Flush(const v810_timestamp_t timestamp, v810_timestamp_t* new_base_timestamp, int16 *SoundBuf, const int32 MaxSoundFrames, const bool reverse);
void SoundBox_Write(uint32 A, uint16 V, const v810_timestamp_t timestamp);
void SoundBox_Init(bool arg_EmulateBuggyCodec, bool arg_ResetAntiClickEnabled);
void SoundBox_Kill(void);

void SoundBox_Reset(const v810_timestamp_t timestamp);

void SoundBox_StateAction(StateMem *sm, const unsigned load, const bool data_only);

void SoundBox_SetKINGADPCMControl(uint32);

v810_timestamp_t SoundBox_ADPCMUpdate(const v810_timestamp_t timestamp);

void SoundBox_ResetTS(const v810_timestamp_t ts_base);

#include <mednafen/sound/Blip_Buffer.h>
#include <mednafen/sound/Stereo_Buffer.h>
#endif
