/*
    sound.c
    YM2612 and SN76489 emulation
*/

#include "shared.h"
#include <mednafen/hw_sound/ym2612/Ym2612_Emu.h>
#include <mednafen/hw_sound/sms_apu/Sms_Apu.h>
#include <mednafen/sound/Blip_Buffer.h>
#include <mednafen/sound/Stereo_Buffer.h>

static Stereo_Buffer zebuf;
static Sms_Apu apu;

/* YM2612 data */
static Blip_Synth<blip_good_quality, 65536> FMSynth;
static int16 fm_last_values[2];
static int32 fm_last_timestamp;
static int32 fm_div;
static uint32 fm_latch;          // Address latch(9-bits)
static Ym2612_Emu FMUnit;
static bool FMReset;

namespace MDFN_IEN_MD
{

static void UpdateFM(void)
{
 int32 cycles = md_timestamp - fm_last_timestamp;

 fm_div -= cycles;
 while(fm_div <= 0)
 {
  int16 new_values[2];

  new_values[0] = new_values[1] = 0;

  if(!FMReset)
   FMUnit.run(new_values);

  //if(FSettings.SndRate)
  {
   FMSynth.offset((md_timestamp + fm_div) / 15, new_values[0] - fm_last_values[0], zebuf.left());
   FMSynth.offset((md_timestamp + fm_div) / 15, new_values[1] - fm_last_values[1], zebuf.right());

   fm_last_values[0] = new_values[0];
   fm_last_values[1] = new_values[1];
  }

  fm_div += (72 * 7 * 2);
 }

 fm_last_timestamp = md_timestamp;
}

void fm_write(int address, int data)
{
 if(FMReset)
  return;

 if(address & 0x1)
 {
	UpdateFM();

	if(fm_latch & 0x100)
	 FMUnit.write1(fm_latch & 0xFF, data);
	else
	 FMUnit.write0(fm_latch & 0xFF, data);
 }
 else
 {
        /* Register latch */
        fm_latch = data | ((address & 0x2) ? 0x100 : 0x00);
 }
}


int MDSound_ReadFM(int address)
{
 if(FMReset)
  return(0x00);

 UpdateFM();

 return(FMUnit.read());
}

void MDSound_SetYM2612Reset(bool new_reset)
{
 // Only call the reset routine when reset begins, and just ignore all
 // reads/writes while reset is active.
 if(new_reset && !FMReset)
 {
  UpdateFM();
  FMUnit.reset();
 }
 FMReset = new_reset;
}


void psg_write(int data)
{
 apu.write_data(md_timestamp / 15, data);
}

static void RedoVolume(void)
{
 apu.output(zebuf.center(), zebuf.left(), zebuf.right());
 //apu.volume(0.15);
 apu.volume(0.25);
 FMSynth.volume(1.00);
}

bool MDSound_SetSoundRate(uint32 rate)
{
 zebuf.set_sample_rate(rate ?rate : 44100, 60);
 return(TRUE);
}

int32 MDSound_Flush(int16 *SoundBuf, const int32 MaxSoundFrames)
{
 int32 FrameCount = 0;

 UpdateFM();
 apu.end_frame(md_timestamp / 15);

 zebuf.end_frame(md_timestamp / 15);

 if(SoundBuf)
  FrameCount = zebuf.read_samples(SoundBuf, MaxSoundFrames * 2) / 2;
 else
  zebuf.clear();

 fm_last_timestamp = 0;

 return(FrameCount);
}

void MDSound_Init(void)
{
 MDSound_SetSoundRate(0);
 zebuf.clock_rate((long)(CLOCK_NTSC / 15));

 RedoVolume();
 zebuf.bass_freq(20);
}

void MDSound_Kill(void)
{
 zebuf.clear();
 fm_last_values[0] = 0;
 fm_last_values[1] = 0;
}

void MDSound_Power(void)
{
 FMUnit.reset();
 apu.reset();
}

void MDSound_StateAction(StateMem *sm, const unsigned load, const bool data_only)
{
 Sms_ApuState sn_state;
 MDFN::LEPacker fm_slizer;

 apu.save_state(&sn_state);
 FMUnit.serialize(fm_slizer, false);

 SFORMAT StateRegs[] =
 {
  SFVAR(fm_last_timestamp),
  SFVAR(FMReset),
  SFVAR(fm_div),
  SFVAR(fm_latch),

  SFARRAYN(&fm_slizer[0], fm_slizer.size(), "FMState"),

  SFARRAY32N(sn_state.volume, 4, "Volume"),
  SFARRAY32N(sn_state.sq_period, 3, "SQPeriod"),
  SFARRAY32N(sn_state.sq_phase, 3, "SQPhase"),
  SFVARN(sn_state.noise_period, "NPeriod"),
  SFVARN(sn_state.noise_shifter, "NShifter"),
  SFVARN(sn_state.noise_feedback, "NFeedback"),
  SFVARN(sn_state.latch, "Latch"),
  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "SND");

 if(load)
 {
  FMUnit.serialize(fm_slizer, true);
  apu.load_state(&sn_state);
 }
}

};
