/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* msu1.h:
**  Copyright (C) 2019 Mednafen Team
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

#ifndef __MDFN_SNES_FAUST_MSU1_H
#define __MDFN_SNES_FAUST_MSU1_H

namespace MDFN_IEN_SNES_FAUST
{
//
//
//
 void MSU1_Init(GameFile* gf, double* IdealSoundRate, uint64 affinity_audio, uint64 affinity_data) MDFN_COLD;
 void MSU1_Kill(void) MDFN_COLD;
 void MSU1_Reset(bool powering_up) MDFN_COLD;
 void MSU1_StateAction(StateMem* sm, const unsigned load, const bool data_only);

 void MSU1_StartFrame(double master_clock, double rate, int32 apu_clock_multiplier, int32 resamp_num, int32 resamp_denom, bool resamp_clear_buf);
 void MSU1_EndFrame(int16* SoundBuf, int32 SoundBufSize);
 void MSU1_AdjustTS(const int32 delta) MDFN_COLD;
 snes_event_handler MSU1_GetEventHandler(void) MDFN_COLD;
}

#endif
