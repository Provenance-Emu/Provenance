/******************************************************************************/
/* Mednafen Apple II Emulation Module                                         */
/******************************************************************************/
/* sound.inc:
**  Copyright (C) 2018 Mednafen Team
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

/*
 TODO: Highpass filter, speaker frequency response, reverb.

 TODO: Dual AY-8910 card support; need to figure out relative channel volumes somehow probably... Slot 4

 TODO: SC-01 and SSI-263 spech chip support someday?  Slot 4
*/

namespace Sound
{

enum : size_t { ImpulseLength = 7 };

static const int16 Phase_Filter[2][8][7] =
{
 {
  /*   0 */ {   161,  1132,  2616,  2734,  1322,   224,     3 }, //  8192 8192.384750(diff = 0.384750)
  /*   1 */ {   112,   953,  2473,  2822,  1522,   302,     8 }, //  8192 8192.558171(diff = 0.558171)
  /*   2 */ {    75,   789,  2309,  2879,  1727,   397,    16 }, //  8192 8190.483720(diff = 1.516280)
  /*   3 */ {    48,   642,  2128,  2902,  1932,   511,    29 }, //  8192 8191.022151(diff = 0.977849)
  /*   4 */ {    29,   511,  1932,  2902,  2128,   642,    48 }, //  8192 8191.022151(diff = 0.977849)
  /*   5 */ {    16,   397,  1727,  2879,  2309,   789,    75 }, //  8192 8190.483720(diff = 1.516280)
  /*   6 */ {     8,   302,  1522,  2822,  2473,   953,   112 }, //  8192 8192.558171(diff = 0.558171)
  /*   7 */ {     3,   224,  1322,  2734,  2616,  1132,   161 }, //  8192 8192.384750(diff = 0.384750)
 },
 {
  /*   0 */ {  -161, -1132, -2616, -2734, -1322,  -224,    -3 }, // -8192 -8192.384750(diff = 0.384750)
  /*   1 */ {  -112,  -953, -2473, -2822, -1522,  -302,    -8 }, // -8192 -8192.558171(diff = 0.558171)
  /*   2 */ {   -75,  -789, -2309, -2879, -1727,  -397,   -16 }, // -8192 -8190.483720(diff = 1.516280)
  /*   3 */ {   -48,  -642, -2128, -2902, -1932,  -511,   -29 }, // -8192 -8191.022151(diff = 0.977849)
  /*   4 */ {   -29,  -511, -1932, -2902, -2128,  -642,   -48 }, // -8192 -8191.022151(diff = 0.977849)
  /*   5 */ {   -16,  -397, -1727, -2879, -2309,  -789,   -75 }, // -8192 -8190.483720(diff = 1.516280)
  /*   6 */ {    -8,  -302, -1522, -2822, -2473,  -953,  -112 }, // -8192 -8192.558171(diff = 0.558171)
  /*   7 */ {    -3,  -224, -1322, -2734, -2616, -1132,  -161 }, // -8192 -8192.384750(diff = 0.384750)
 }
};

static int16 SoundBuffer[65536 + (ImpulseLength - 1)];
static uint32 SoundBuffer_Ofs;
static int32 SoundBuffer_Accum;
static std::unique_ptr<SwiftResampler> resamp;

static bool SpeakerOut;
static int32 LPFilter;
static int32 HPFilter;

static void DoSpeakerToggle(void)
{
 SpeakerOut = !SpeakerOut;
 //
 //
 //
 const uint32 ofs = SoundBuffer_Ofs + timestamp;
 const int16* imp = Phase_Filter[SpeakerOut][ofs & 7];
 int16* const t = &SoundBuffer[(ofs >> 3) & 0xFFFF];

 for(size_t i = 0; i < ImpulseLength; i++)
  t[i] += imp[i];
}

static DEFRW(RWSpeakerToggle)
{
 if(!InHLPeek)
 {
  DoSpeakerToggle();
  //
  CPUTick1();
 }
}

void SetParams(double rate, double rate_error, unsigned quality)
{
 resamp.reset(nullptr);
 if(rate)
  resamp.reset(new SwiftResampler(APPLE2_MASTER_CLOCK / 8.0, rate, rate_error, 0, quality));
}

void StartTimePeriod(void)
{

}

static void Filter(int16* buf, uint32 count)
{
 for(uint32 i = 0; i < count; i++)
 {
  int32 s = buf[i];
  //
  //
  //
  LPFilter += ((int32)((uint32)s << 16) - LPFilter) >> 5;
  HPFilter += (LPFilter - HPFilter) >> 12;
  s = (LPFilter - HPFilter) >> 16;
  //
  //
  //
  if(s < -32768)
   s = 32768;

  if(s > 32767)
   s = 32767;

  buf[i] = s;
 }
}

uint32 EndTimePeriod(int16* OutSoundBuf, const int32 OutSoundBufMaxSize, const bool reverse)
{
 const uint32 ofs = SoundBuffer_Ofs + timestamp;
 uint32 ret = 0;
 int32 leftover = 0;
 const uint32 resamp_inlen = ofs >> 3;

 // Integrate
 for(size_t i = (SoundBuffer_Ofs >> 3); i < resamp_inlen; i++)
 {
  SoundBuffer_Accum += SoundBuffer[i];
  SoundBuffer[i] = SoundBuffer_Accum;
 }

 // Lowpass and highpass
 Filter(&SoundBuffer[SoundBuffer_Ofs >> 3], resamp_inlen - (SoundBuffer_Ofs >> 3));

 //printf("%d\n", SoundBuffer_Accum);

 // Reverse
 if(OutSoundBuf && reverse && resamp_inlen)
 {
  int16* p0 = &SoundBuffer[SoundBuffer_Ofs >> 3];
  int16* p1 = &SoundBuffer[resamp_inlen - 1];
  uint32 count = (p1 + 1 - p0) >> 1;

  while(MDFN_LIKELY(count--))
  {
   std::swap(*p0, *p1);
   p0++;
   p1--;
  }
 }

 // Resample
 if(OutSoundBuf && resamp)
 {
  ret = resamp->Do(SoundBuffer, OutSoundBuf, OutSoundBufMaxSize, resamp_inlen, &leftover);

  // Copy leftover samples and extra impulse overflow samples
  for(size_t i = 0; i < leftover + ImpulseLength; i++)
   SoundBuffer[i] = SoundBuffer[(resamp_inlen - leftover) + i];

  for(size_t i = leftover + ImpulseLength; i < resamp_inlen + ImpulseLength; i++)
   SoundBuffer[i] = 0;

  //
  //
  SoundBuffer_Ofs = (ofs & 0x7) | (leftover << 3);
 }
 else
 {
  ret = 0;
  SoundBuffer_Ofs = 0;
 }

 // TODO: Reverb

 //printf("soundaccum: %d\n", SoundBuffer_Accum);

 return ret;
}

static INLINE void Power(void)
{
 if(SpeakerOut)
 {
  DoSpeakerToggle();
  SpeakerOut = false;
 }
}

static INLINE void Init(void)
{
 memset(SoundBuffer, 0, sizeof(SoundBuffer));
 SoundBuffer_Accum = 0;
 SpeakerOut = false;
 HPFilter = 0;
 LPFilter = 0;
 //
 //
 for(unsigned A = 0xC030; A < 0xC040; A++)
  SetRWHandlers(A, RWSpeakerToggle, RWSpeakerToggle);
}

static INLINE void Kill(void)
{
 resamp.reset(nullptr);
}

void StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(SpeakerOut),
  SFVAR(SoundBuffer_Accum),
  SFPTR16(&SoundBuffer[((SoundBuffer_Ofs + timestamp) >> 3) & 0xFFFF], ImpulseLength),
  SFVAR(LPFilter),
  SFVAR(HPFilter),
  SFEND
 };

 //printf("%d\n", ((SoundBuffer_Ofs + timestamp) >> 3));

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "SOUND");

 if(load)
 {

 }
}


}
