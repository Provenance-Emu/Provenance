/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* msu1.cpp - MSU1 emulation
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

#include "snes.h"
#include "msu1.h"
#include "apu.h"

#include <bitset>

#include <mednafen/sound/OwlResampler.h>
#include <mednafen/sound/DSPUtility.h>
#include <mednafen/MTStreamReader.h>
//
//
#undef NDEBUG
#include <assert.h>

namespace MDFN_IEN_SNES_FAUST
{

static bool Active;
//
static MTStreamReader* audio_reader;
static MTStreamReader* data_reader;

struct TrackDef
{
 uint32 w;
 uint32 frame_count;
};

static std::map<uint16, TrackDef> tracks;
//
//
static uint32 InputBufRatio;
static const int NumPhases = 128; // Don't change without adjusting code
static const int NumCoeffs = 32;
static float Impulse[NumPhases + 1][NumCoeffs];
//
static OwlBuffer ResampBuf[2];
static OwlResampler* Resampler;
static int16 IntermediateBuf[0x4000];
//
static uint32 InputBufPhase;	// 44.1KHz -> 64KHz(roughly) resampler phase
static uint16 ResampBufPos;	// 64KHz -> output resampler input buffer position
//
static uint64 virtual_data_pos;

static uint16 virtual_play_track;
static uint64 virtual_play_frame_pos;	// [0, ~(uint64)0]
static uint64 virtual_play_frame_count;
//
static uint32 data_busy_until;
static uint32 audio_busy_until;
//
static uint32 pending_data_seek_pos;
static uint16 pending_track;
static uint8 status;
static uint8 volume;
static uint8 control;

static INLINE uint32 CalcNextEventTS(void)
{
 return std::max<uint32>(audio_busy_until, data_busy_until);
}

static uint32 NO_INLINE Update(uint32 master_timestamp)
{
 int32 run_count = APU_UpdateGetResampBufPos(master_timestamp) * 2 - ResampBufPos;
 //
 //
 //
 const float eff_volume = volume * ((1.0 / 255.0f) * 256.0f);

 if(MDFN_UNLIKELY(!(status & 0x10) || (status & 0x40)))
 {
  while(run_count)
  {
   (&ResampBuf[0].BufPudding()->f)[ResampBufPos] = 0;
   (&ResampBuf[1].BufPudding()->f)[ResampBufPos] = 0;
   run_count--;
   ResampBufPos++;
  }
 }
 else while(MDFN_LIKELY(run_count > 0))
 {
  unsigned eff_num_coeffs = NumCoeffs;
  unsigned phase = InputBufPhase;
  unsigned phase_index = phase >> 17;
  float phase_ip = (phase & 0x1FFFF) * (1.0f / 131072.0f);
  float accum[2] = { 0, 0 };
  const uint8* const inbuf = audio_reader->get_buffer(NumCoeffs * sizeof(int16) * 2);

  if(!(status & 0x20))
   eff_num_coeffs = std::min<uint64>(eff_num_coeffs, virtual_play_frame_count - std::min<uint64>(virtual_play_frame_count, virtual_play_frame_pos));

  for(unsigned i = 0; i < eff_num_coeffs; i++)
  {
   const float imp_a = Impulse[phase_index + 0][i];
   const float imp_b = Impulse[phase_index + 1][i];
   const float imp = imp_a + (imp_b - imp_a) * phase_ip;

   accum[0] += imp * MDFN_densb<int16>(&inbuf[(i << 2) + 0]);
   accum[1] += imp * MDFN_densb<int16>(&inbuf[(i << 2) + 2]);
  }

  (&ResampBuf[0].BufPudding()->f)[ResampBufPos] = accum[0] * eff_volume;
  (&ResampBuf[1].BufPudding()->f)[ResampBufPos] = accum[1] * eff_volume;
  //
  run_count--;
  ResampBufPos++;

  if(MDFN_LIKELY(status & 0x10))
  {
   uint32 advance_frame_count;

   InputBufPhase += InputBufRatio;
   advance_frame_count = (InputBufPhase >> 24);
   InputBufPhase = InputBufPhase & 0xFFFFFF;
   //
   //
   //
   audio_reader->advance(advance_frame_count * sizeof(int16) * 2);
   virtual_play_frame_pos += advance_frame_count;
   if(virtual_play_frame_pos >= virtual_play_frame_count)
   {
    if(!(status & 0x20))
     status &= ~0x10;
   }
  }
 }
 //
 //
 //
 if(master_timestamp >= data_busy_until)
 {
  status &= ~0x80;
  data_busy_until = SNES_EVENT_MAXTS;
 }

 if(master_timestamp >= audio_busy_until)
 {
  status &= ~0x40;
  audio_busy_until = SNES_EVENT_MAXTS;
 }

 return CalcNextEventTS();
}

void MSU1_StartFrame(double master_clock, double rate, int32 apu_clock_multiplier, int32 resamp_num, int32 resamp_denom, bool resamp_clear_buf)
{
 if(!Active)
  return;
 //
 //if(resamp_num && resamp_denom)
 // printf("%f %d %d %d %d--- %f\n", master_clock, apu_clock_multiplier, resamp_clear_buf, resamp_num, resamp_denom, (master_clock * apu_clock_multiplier) / (65536.0 * 32) * resamp_num / resamp_denom);
 //
 InputBufRatio = (int64)44100 * 65536 * 16 * (1 << 24) / ((int64)floor(0.5 + master_clock) * apu_clock_multiplier);

 if(resamp_clear_buf)
 {
  if(Resampler)
  {
   delete Resampler;
   Resampler = nullptr;
  }

  if(rate)
  {
   if(!resamp_num || !resamp_denom)
   {
    resamp_num = 1;
    resamp_denom = 1;
   }

   if(!(resamp_denom & 1))
    resamp_denom >>= 1;
   else
    resamp_num <<= 1;

   Resampler = new OwlResampler((master_clock * apu_clock_multiplier) / (65536.0 * 16), rate, 0, 10, MDFN_GetSettingUI("snes_faust.msu1.resamp_quality"), 1.05, 44100, resamp_num, resamp_denom);

   for(unsigned i = 0; i < 2; i++)
    Resampler->ResetBufResampState(&ResampBuf[i]);
  }
 }
}

void MSU1_EndFrame(int16* SoundBuf, int32 SoundBufSize)
{
 if(!Active)
  return;
 //
 if(SoundBuf)
 {
  int32 IntermediateBufPos;
  for(unsigned i = 0; i < 2; i++)
  {
   IntermediateBufPos = Resampler->Resample(&ResampBuf[i], ResampBufPos, &IntermediateBuf[i], 0); //sizeof(IntermediateBuf) / (2 * sizeof(int16));
  }
  assert(IntermediateBufPos == SoundBufSize);

  for(int32 i = 0; i < SoundBufSize; i++)
  {
   SoundBuf[(i * 2) + 0] = std::max<int32>(-32768, std::min<int32>(32767, SoundBuf[(i * 2) + 0] + IntermediateBuf[(i * 2) + 0]));
   SoundBuf[(i * 2) + 1] = std::max<int32>(-32768, std::min<int32>(32767, SoundBuf[(i * 2) + 1] + IntermediateBuf[(i * 2) + 1]));
  }
#if 0
  {
   int32 leftover;
   uint32 InputIndex;
   uint32 InputPhase;

   ResampBuf[0].GetDebugInfo(&leftover, &InputIndex, &InputPhase);

   printf("[MSU1] leftover=%4d, InputIndex=%4u, InputPhase=%4u\n", leftover, InputIndex, InputPhase);
  }
#endif
 }
 else
 {
  for(unsigned i = 0; i < 2; i++)
   ResampBuf[i].ResampleSkipped(ResampBufPos);
 }
 ResampBufPos = 0;
}

void MSU1_AdjustTS(const int32 delta)
{
 if(!Active)
  return;
 //
 if(data_busy_until != SNES_EVENT_MAXTS)
  data_busy_until = std::max<int64>(0, (int64)data_busy_until + delta);
 if(audio_busy_until != SNES_EVENT_MAXTS)
  audio_busy_until = std::max<int64>(0, (int64)audio_busy_until + delta);
}

static MDFN_COLD uint32 DummyEventHandler(uint32 timestamp)
{
 return SNES_EVENT_MAXTS;
}

snes_event_handler MSU1_GetEventHandler(void)
{
 if(!Active)
  return DummyEventHandler;

 return Update;
}

static DEFREAD(MSU1_ReadStatus)
{
 if(MDFN_LIKELY(!DBG_InHLRead))
 {
  CPUM.timestamp += MEMCYC_FAST;
 }

 //printf("Read status: %02x\n", status);

 return status;
}

static DEFREAD(MSU1_ReadData)
{
 uint8 ret = *data_reader->get_buffer(1);

 if(MDFN_LIKELY(!DBG_InHLRead))
 {
  CPUM.timestamp += MEMCYC_FAST;

  if(!(status & 0x80))
  {
   data_reader->advance(1);
   virtual_data_pos += 1;
  }
 }

 return ret;
}

static DEFREAD(MSU1_ReadID)
{
 static const uint8 sig[8] = { 0, 0, 'S', '-', 'M', 'S', 'U', '1' };

 if(MDFN_LIKELY(!DBG_InHLRead))
  CPUM.timestamp += MEMCYC_FAST;

 return sig[A & 0x7];
}

static DEFWRITE(MSU1_WriteDataSeek)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 Update(CPUM.timestamp);
 //
 SNES_DBG("[MSU1] Write data seek: %06x %02x\n", A, V);

 const unsigned shift = (A & 0x3) << 3;
 pending_data_seek_pos &= ~(0xFF << shift);
 pending_data_seek_pos |= V << shift;

 if((A & 0x3) == 0x3)
 {
  data_reader->set_active_stream(0, pending_data_seek_pos);
  virtual_data_pos = pending_data_seek_pos;
  status |= 0x80;
  data_busy_until = CPUM.timestamp + 400000;
  SNES_SetEventNT(SNES_EVENT_MSU1, CalcNextEventTS());
 }
}

static DEFWRITE(MSU1_WriteTrack)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 Update(CPUM.timestamp);
 //
 SNES_DBG("[MSU1] Write track: %06x %02x\n", A, V);

 const unsigned shift = (A & 0x1) << 3;
 pending_track &= ~(0xFF << shift);
 pending_track |= V << shift;

 if((A & 0x1) == 0x1)
 {
  status &= ~0x78;
  virtual_play_frame_pos = 0;
  virtual_play_frame_count = 0;
  audio_busy_until = SNES_EVENT_MAXTS;
  //
  std::map<uint16, TrackDef>::iterator it = tracks.find(pending_track);

  if(it == tracks.end())
   status |= 0x08;
  else
  {
   audio_reader->set_active_stream(it->second.w, 8, (NumCoeffs / 2) * 4);
   virtual_play_frame_count = (uint64)it->second.frame_count + (NumCoeffs / 2);
   virtual_play_track = pending_track;
   InputBufPhase = 0;
   status |= 0x40;
   audio_busy_until = CPUM.timestamp + 400000;
   SNES_SetEventNT(SNES_EVENT_MSU1, CalcNextEventTS());
  }
 }
}

static DEFWRITE(MSU1_WriteVolume)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 Update(CPUM.timestamp);
 //
 SNES_DBG("[MSU1] Write volume: %02x\n", V);

 volume = V;
}

static DEFWRITE(MSU1_WriteControl)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 Update(CPUM.timestamp);
 //
 SNES_DBG("[MSU1] Write control: %02x\n", V);

 if(!(status & 0x40))
 {
  status &= ~0x30;
  status |= (V << 4) & 0x30;
 }
}

void MSU1_Init(GameFile* gf, double* IdealSoundRate, uint64 affinity_audio, uint64 affinity_data)
{
 Active = false;
 //
 if(gf->outside.vfs != &NVFS)	// TODO/FIXME
  return;

 if(!gf->outside.dir.size() || !gf->outside.fbase.size())
  return;
 //
 //
 std::unique_ptr<Stream> dfp;

 for(unsigned i = 0; i < 2; i++)
 {
  static const char* try_ext[2] = { ".msu", ".MSU" };

  std::string msu_path = gf->outside.dir + gf->outside.vfs->get_preferred_path_separator() + gf->outside.fbase + try_ext[i];
  //printf("%s\n", msu_path.c_str());

  dfp.reset(gf->outside.vfs->open(msu_path, VirtualFS::MODE_READ, false, false));

  if(dfp)
   break;
 }

 if(!dfp)
  return;
 //
 MDFN_printf(_("MSU1 Enabled:\n"));
 MDFN_AutoIndent aind(1);
 //

 for(unsigned bank = 0x00; bank < 0x100; bank++)
 {
  if(bank <= 0x3F || (bank >= 0x80 && bank <= 0xBF))
  {
   Set_A_Handlers((bank << 16) | 0x2000, MSU1_ReadStatus, MSU1_WriteDataSeek);
   Set_A_Handlers((bank << 16) | 0x2001, MSU1_ReadData,   MSU1_WriteDataSeek);
   Set_A_Handlers((bank << 16) | 0x2002, MSU1_ReadID, 	  MSU1_WriteDataSeek);
   Set_A_Handlers((bank << 16) | 0x2003, MSU1_ReadID, 	  MSU1_WriteDataSeek);
   Set_A_Handlers((bank << 16) | 0x2004, MSU1_ReadID, 	  MSU1_WriteTrack);
   Set_A_Handlers((bank << 16) | 0x2005, MSU1_ReadID, 	  MSU1_WriteTrack);
   Set_A_Handlers((bank << 16) | 0x2006, MSU1_ReadID, 	  MSU1_WriteVolume);
   Set_A_Handlers((bank << 16) | 0x2007, MSU1_ReadID, 	  MSU1_WriteControl);
  }
 }
 //
 {
  std::unique_ptr<double[]> ImpBuf(new double[NumPhases * NumCoeffs]);

  DSPUtility::generate_kaiser_sinc_lp(ImpBuf.get(), NumPhases * NumCoeffs, 0.50 / NumPhases, 9.0);
  DSPUtility::normalize(ImpBuf.get(), NumPhases * NumCoeffs, NumPhases);

  for(int phase = 0; phase < NumPhases + 1; phase++)
  {
   for(int coeff = 0; coeff < NumCoeffs; coeff++)
   {
    int32 index = coeff * NumPhases + (NumPhases - 1 - phase);
    float v;

    if(index < 0 || index >= (NumCoeffs * NumPhases))
     v = 0;
    else
     v = ImpBuf[index];

    Impulse[phase][coeff] = v;
    //printf("Phase: %3u, Coeff: %2u --- % f --- % f : % f\n", phase, coeff, Impulse[phase][coeff], Impulse[phase][coeff] - Impulse[std::max<int>(0, phase - 1)][coeff], Impulse[std::max<int>(0, phase - 1)][coeff] - Impulse[std::max<int>(0, phase - 2)][coeff]);
   }
  }

#if 0
  {
   std::unique_ptr<Stream> fp(NVFS.open("/tmp/dump.raw", VirtualFS::MODE_WRITE));
   float goat[65536] = { 0 };

   memcpy(&goat[32768 - NumCoeffs / 2], &Impulse[NumPhases / 2][0], NumCoeffs * sizeof(float));
   fp->write(goat, 65536 * sizeof(float));
  }
#endif
 }

 ResampBufPos = 0;

 Active = true;

 *IdealSoundRate *= 2;
 //
 //
 //
 audio_reader = new MTStreamReader(affinity_audio);
 data_reader = new MTStreamReader(affinity_data);
 //
 {
  MTStreamReader::StreamInfo dsi;

  dsi.size = dfp->size();
  dsi.loop_pos = dsi.size;

  dsi.pos = 0;
  dsi.stream = std::move(dfp);
  //
  MDFN_printf(_("Data File Size: 0x%08llx\n"), (unsigned long long)dsi.size);
  //
  data_reader->add_stream(std::move(dsi));
 }

 const std::string filebase = gf->outside.fbase;
 const std::string fnamepat = filebase + "-%.pcm";
 const std::string dirpath = gf->outside.dir;
 std::bitset<65536> trypcm;	// May have false positives, should not have false negatives, but who knows with case insensitive filesystems...
 try
 {
  gf->outside.vfs->readdirentries(dirpath,
	[&](const std::string& fname)
	{
	 const bool ret = true;
	 unsigned tnum = ~0U;
	 {
	  for(size_t i = 0, si = 0; i < fnamepat.size(); i++)
	  {
	   if(si >= fname.size())
	    return ret;
	   //
	   if(fnamepat[i] == '%')
	   {
	    bool first = true;

	    tnum = 0;
	    do
	    {
	     const unsigned d = (fname[si] - '0');

 	     if(d > 9)
	     {
	      if(first)
	       return ret;
	      else
	       break;
	     }

	     if(!first && tnum == 0)
	      return ret;

	     tnum = (tnum * 10) + d;
	     first = false;
	     si++;
	    } while(si < fname.size());
	   }
	   else
	   {
	    if(!(fnamepat[i] & fname[si] & 0x80) && MDFN_azlower(fnamepat[i]) != MDFN_azlower(fname[si]))
	     return ret;
	    si++;
	   }
	  }
	 }
	 if(tnum < 65536)
	  trypcm[tnum] = true;
	 return ret;
	});
 }
 catch(std::exception& e)
 {
  MDFN_printf(_("Doing brute-force search for audio tracks due to error: %s\n"), e.what());
  trypcm.set();
 }
 const std::string fbp = dirpath + gf->outside.vfs->get_preferred_path_separator() + filebase;
 for(unsigned tnum = 0, w = 0; tnum < 65536; tnum++)
 {
  if(!trypcm[tnum])
   continue;
  //
  std::unique_ptr<Stream> afp;

  for(unsigned i = 0; i < /*8*/2; i++)
  {
   const char* tryext[/*8*/2] = { "pcm", "PCM"/*, "pcM", "pCm", "pCM", "Pcm", "PcM", "PCm"*/ };
   char fnsuffix[32];
   snprintf(fnsuffix, sizeof(fnsuffix), "-%u.%s", tnum, tryext[i]);
   //
   //printf("%s\n", (fbp + fnsuffix).c_str());
   afp.reset(gf->outside.vfs->open(fbp + fnsuffix, VirtualFS::MODE_READ, false, false));
   if(afp)
    break;
  }
  if(!afp)
   continue;
  //
  uint8 header[8];
  MTStreamReader::StreamInfo asi;
  TrackDef td;
  const uint64 raw_size = afp->size();
  const uint64 size = raw_size &~ 3;
  uint64 loop_pos;

  afp->read(header, sizeof(header));
  loop_pos = (uint64)MDFN_de32lsb(&header[4]) * 4 + sizeof(header);
  loop_pos = std::min<uint64>(loop_pos, size);
  //
  MDFN_printf(_("Audio Track 0x%04x:\n"), tnum);
  {
   MDFN_AutoIndent aindt(1);

   MDFN_printf(_("Byte Size: 0x%08llx\n"), (unsigned long long)raw_size);
   MDFN_printf(_("Loop Pos:  0x%08llx (frame 0x%08x)\n"), (unsigned long long)loop_pos, MDFN_de32lsb(&header[4]));
  }
  //
  //
  asi.size = size;
  asi.loop_pos = loop_pos;

  asi.pos = 0;
  asi.stream = std::move(afp);

  audio_reader->add_stream(std::move(asi));
  //
  td.w = w++;
  td.frame_count = (size - 8) >> 2;
  tracks[tnum] = td;
 }
}

void MSU1_Kill(void)
{
 Active = false;
 //
 if(audio_reader)
 {
  delete audio_reader;
  audio_reader = nullptr;
 }

 if(data_reader)
 {
  delete data_reader;
  data_reader = nullptr;
 }

 tracks.clear();
}

void MSU1_Reset(bool powering_up)
{
 if(!Active)
  return;
 //
 InputBufPhase = 0;
 ResampBufPos = 0;
 //
 virtual_data_pos = 0;

 virtual_play_track = 0;
 virtual_play_frame_pos = 0;
 virtual_play_frame_count = 0;

 data_busy_until = SNES_EVENT_MAXTS;
 audio_busy_until = SNES_EVENT_MAXTS;

 pending_data_seek_pos = 0;
 pending_track = 0;

 status = 0x01;
 volume = 0x00;
 control = 0x00;
 
 data_reader->set_active_stream(0, 0);
 if(tracks.size())
  audio_reader->set_active_stream(0, 8);
 //
 //
#if 0
 MSU1_WriteVolume(0x2006, 0xFF);
 MSU1_WriteTrack(0x2004, 0x0D);
 MSU1_WriteTrack(0x2005, 0x00);
 status &= ~0x40;
 audio_busy_until = SNES_EVENT_MAXTS;
 //
 MSU1_WriteControl(0x2007, 0x03);
 printf("%02x\n", status);

 CPUM.timestamp = 0;
#endif

}

void MSU1_StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 if(!Active)
  return;

 SFORMAT StateRegs[] =
 {
  SFVAR(InputBufPhase),

  SFVAR(virtual_data_pos),

  SFVAR(virtual_play_track),
  SFVAR(virtual_play_frame_pos),

  SFVAR(data_busy_until),
  SFVAR(audio_busy_until),

  SFVAR(pending_data_seek_pos),
  SFVAR(pending_track),

  SFVAR(status),
  SFVAR(volume),
  SFVAR(control),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "MSU1");

 if(load)
 {
  InputBufPhase &= 0xFFFFFF;
  //
  data_reader->set_active_stream(0, virtual_data_pos);
  //
  std::map<uint16, TrackDef>::iterator it = tracks.find(virtual_play_track);

  if(it == tracks.end())
  {
   status &= ~0x78;

   audio_busy_until = SNES_EVENT_MAXTS;
   virtual_play_track = 0;
   virtual_play_frame_count = 0;
   virtual_play_frame_pos = 0;
   virtual_play_frame_count = 0;
  }
  else
  {
   uint64 pos;
   uint32 pzb;

   virtual_play_frame_count = (uint64)it->second.frame_count + (NumCoeffs / 2);

   // 2**64 / 44100 = biiiig
   if(virtual_play_frame_pos < (NumCoeffs / 2))
   {
    pos = 8;
    pzb = virtual_play_frame_pos * 4;
   }
   else
   {
    pos = 8 + (virtual_play_frame_pos - (NumCoeffs / 2)) * 4;
    pzb = 0;
   }

   audio_reader->set_active_stream(it->second.w, pos, pzb);
  }
 }

 if(data_only)
 {
  ResampBuf[0].StateAction(sm, load, data_only, "MSU1_RESBUF0", ResampBufPos);
  ResampBuf[1].StateAction(sm, load, data_only, "MSU1_RESBUF1", ResampBufPos);
 }
}

}
