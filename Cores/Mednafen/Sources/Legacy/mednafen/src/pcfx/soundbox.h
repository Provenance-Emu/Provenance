/******************************************************************************/
/* Mednafen NEC PC-FX Emulation Module                                        */
/******************************************************************************/
/* soundbox.h:
**  Copyright (C) 2006-2016 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

#ifndef _PCFX_SOUNDBOX_H
#define _PCFX_SOUNDBOX_H

namespace MDFN_IEN_PCFX
{

bool SoundBox_SetSoundRate(uint32 rate);
int32 SoundBox_Flush(const v810_timestamp_t timestamp, v810_timestamp_t* new_base_timestamp, int16 *SoundBuf, const int32 MaxSoundFrames, const bool reverse);
void SoundBox_Write(uint32 A, uint16 V, const v810_timestamp_t timestamp);
void SoundBox_Init(bool arg_EmulateBuggyCodec, bool arg_ResetAntiClickEnabled) MDFN_COLD;
void SoundBox_Kill(void) MDFN_COLD;

void SoundBox_Reset(const v810_timestamp_t timestamp) MDFN_COLD;

void SoundBox_StateAction(StateMem *sm, const unsigned load, const bool data_only);

void SoundBox_SetKINGADPCMControl(uint32);

v810_timestamp_t SoundBox_ADPCMUpdate(const v810_timestamp_t timestamp);

void SoundBox_ResetTS(const v810_timestamp_t ts_base);

}

#include <mednafen/sound/Blip_Buffer.h>
#include <mednafen/sound/Stereo_Buffer.h>
#endif
