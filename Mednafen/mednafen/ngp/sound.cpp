/* Mednafen - Multi-system Emulator
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "neopop.h"
#include "sound.h"

#include <mednafen/sound/Blip_Buffer.h>
#include "T6W28_Apu.h"
#include <mednafen/sound/Stereo_Buffer.h>

static T6W28_Apu apu;

static Stereo_Buffer st_buf;

static uint8 LastDACLeft = 0, LastDACRight = 0;
static uint8 CurrentDACLeft = 0, CurrentDACRight = 0;

typedef Blip_Synth<blip_good_quality, 0xFF> Synth;
static Synth synth;
extern int32 ngpc_soundTS;
static bool schipenable = 0;

void MDFNNGPCSOUND_SetEnable(bool set)
{
 schipenable = set;
 if(!set)
  apu.reset();
}

void Write_SoundChipLeft(uint8 data)
{
 if(schipenable)
  apu.write_data_left(ngpc_soundTS >> 1, data);
}

void Write_SoundChipRight(uint8 data)
{
 if(schipenable)
  apu.write_data_right(ngpc_soundTS >> 1, data);
}


void dac_write_left(uint8 data)
{
 CurrentDACLeft = data;

 synth.offset_inline(ngpc_soundTS >> 1, CurrentDACLeft - LastDACLeft, st_buf.left());

 LastDACLeft = data;
}

void dac_write_right(uint8 data)
{
 CurrentDACRight = data;

 synth.offset_inline(ngpc_soundTS >> 1, CurrentDACRight - LastDACRight, st_buf.right());

 LastDACRight = data;
}


int32 MDFNNGPCSOUND_Flush(int16 *SoundBuf, const int32 MaxSoundFrames)
{
	int32 FrameCount = 0;

        apu.end_frame(ngpc_soundTS >> 1);

        st_buf.end_frame(ngpc_soundTS >> 1);

	if(SoundBuf)
         FrameCount = st_buf.read_samples(SoundBuf, MaxSoundFrames * 2) / 2;
	else
	 st_buf.clear();

        return(FrameCount);
}

static void RedoVolume(void)
{
 apu.output(st_buf.center(), st_buf.left(), st_buf.right());
 apu.volume(0.30);
 synth.volume(0.40);
}

void MDFNNGPCSOUND_Init(void)
{
 MDFNNGPC_SetSoundRate(0);
 st_buf.clock_rate((long)(3072000));

 RedoVolume();
 st_buf.bass_freq(20);
}

bool MDFNNGPC_SetSoundRate(uint32 rate)
{
 st_buf.set_sample_rate(rate?rate:44100, 60);
 return(TRUE);
}

int MDFNNGPCSOUND_StateAction(StateMem *sm, int load, int data_only)
{
 T6W28_ApuState sn_state;

 apu.save_state(&sn_state);

 SFORMAT StateRegs[] =
 {
  SFVAR(CurrentDACLeft),
  SFVAR(CurrentDACRight),

  SFVAR(schipenable),

  SFARRAY32N(sn_state.volume_left, 4, "VolumeLeft"),
  SFARRAY32N(sn_state.volume_right, 4, "VolumeRight"),
  SFARRAY32N(sn_state.sq_period, 3, "SQPeriod"),
  SFARRAY32N(sn_state.sq_phase, 3, "SQPhase"),
  SFVARN(sn_state.noise_period, "NPeriod"),
  SFVARN(sn_state.noise_shifter, "NShifter"),
  SFVARN(sn_state.noise_tap, "NTap"),
  SFVARN(sn_state.latch_left, "LatchLeft"),
  SFVARN(sn_state.latch_right, "LatchRight"),
  SFEND
 };

 if(!MDFNSS_StateAction(sm, load, data_only, StateRegs, "SND"))
 {
  return(0);
 }

 if(load)
 {
  apu.load_state(&sn_state);
  synth.offset(ngpc_soundTS >> 1, CurrentDACLeft - LastDACLeft, st_buf.left());
  synth.offset(ngpc_soundTS >> 1, CurrentDACRight - LastDACRight, st_buf.right());
  LastDACLeft = CurrentDACLeft;
  LastDACRight = CurrentDACRight;
 }

 return(1);
}
