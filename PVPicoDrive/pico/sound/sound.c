/*
 * PicoDrive
 * (c) Copyright Dave, 2004
 * (C) notaz, 2006-2009
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include <string.h>
#include "ym2612.h"
#include "sn76496.h"
#include "../pico_int.h"
#include "../cd/cue.h"
#include "mix.h"

#define SIMPLE_WRITE_SOUND 0

void (*PsndMix_32_to_16l)(short *dest, int *src, int count) = mix_32_to_16l_stereo;

// master int buffer to mix to
static int PsndBuffer[2*(44100+100)/50];

// dac
static unsigned short dac_info[312+4]; // pppppppp ppppllll, p - pos in buff, l - length to write for this sample

// cdda output buffer
short cdda_out_buffer[2*1152];

// for Pico
int PsndRate=0;
int PsndLen=0; // number of mono samples, multiply by 2 for stereo
int PsndLen_exc_add=0; // this is for non-integer sample counts per line, eg. 22050/60
int PsndLen_exc_cnt=0;
int PsndDacLine=0;
short *PsndOut=NULL; // PCM data buffer

// timers
int timer_a_next_oflow, timer_a_step; // in z80 cycles
int timer_b_next_oflow, timer_b_step;

// sn76496
extern int *sn76496_regs;


static void dac_recalculate(void)
{
  int i, dac_cnt, pos, len, lines = Pico.m.pal ? 312 : 262, mid = Pico.m.pal ? 68 : 93;

  if (PsndLen <= lines)
  {
    // shrinking algo
    dac_cnt = -PsndLen;
    len=1; pos=0;
    dac_info[225] = 1;

    for(i=226; i != 225; i++)
    {
      if (i >= lines) i = 0;
      len = 0;
      if(dac_cnt < 0) {
        len=1;
        pos++;
        dac_cnt += lines;
      }
      dac_cnt -= PsndLen;
      dac_info[i] = (pos<<4)|len;
    }
  }
  else
  {
    // stretching
    dac_cnt = PsndLen;
    pos=0;
    for(i = 225; i != 224; i++)
    {
      if (i >= lines) i = 0;
      len=0;
      while(dac_cnt >= 0) {
        dac_cnt -= lines;
        len++;
      }
      if (i == mid) // midpoint
        while(pos+len < PsndLen/2) {
          dac_cnt -= lines;
          len++;
        }
      dac_cnt += PsndLen;
      dac_info[i] = (pos<<4)|len;
      pos+=len;
    }
    // last sample
    for(len = 0, i = pos; i < PsndLen; i++) len++;
    if (PsndLen_exc_add) len++;
    dac_info[224] = (pos<<4)|len;
  }
  mid = (dac_info[lines-1] & 0xfff0) + ((dac_info[lines-1] & 0xf) << 4);
  for (i = lines; i < sizeof(dac_info) / sizeof(dac_info[0]); i++)
    dac_info[i] = mid;
  //for(i=len=0; i < lines; i++) {
  //  printf("%03i : %03i : %i\n", i, dac_info[i]>>4, dac_info[i]&0xf);
  //  len+=dac_info[i]&0xf;
  //}
  //printf("rate is %i, len %f\n", PsndRate, (double)PsndRate/(Pico.m.pal ? 50.0 : 60.0));
  //printf("len total: %i, last pos: %i\n", len, pos);
  //exit(8);
}


PICO_INTERNAL void PsndReset(void)
{
  // PsndRerate calls YM2612Init, which also resets
  PsndRerate(0);
  timers_reset();
}


// to be called after changing sound rate or chips
void PsndRerate(int preserve_state)
{
  void *state = NULL;
  int target_fps = Pico.m.pal ? 50 : 60;

  if (preserve_state) {
    state = malloc(0x204);
    if (state == NULL) return;
    ym2612_pack_state();
    memcpy(state, YM2612GetRegs(), 0x204);
  }
  YM2612Init(Pico.m.pal ? OSC_PAL/7 : OSC_NTSC/7, PsndRate);
  if (preserve_state) {
    // feed it back it's own registers, just like after loading state
    memcpy(YM2612GetRegs(), state, 0x204);
    ym2612_unpack_state();
  }

  if (preserve_state) memcpy(state, sn76496_regs, 28*4); // remember old state
  SN76496_init(Pico.m.pal ? OSC_PAL/15 : OSC_NTSC/15, PsndRate);
  if (preserve_state) memcpy(sn76496_regs, state, 28*4); // restore old state

  if (state)
    free(state);

  // calculate PsndLen
  PsndLen=PsndRate / target_fps;
  PsndLen_exc_add=((PsndRate - PsndLen*target_fps)<<16) / target_fps;
  PsndLen_exc_cnt=0;

  // recalculate dac info
  dac_recalculate();

  // clear all buffers
  memset32(PsndBuffer, 0, sizeof(PsndBuffer)/4);
  memset(cdda_out_buffer, 0, sizeof(cdda_out_buffer));
  if (PsndOut)
    PsndClear();

  // set mixer
  PsndMix_32_to_16l = (PicoOpt & POPT_EN_STEREO) ? mix_32_to_16l_stereo : mix_32_to_16_mono;

  if (PicoAHW & PAHW_PICO)
    PicoReratePico();
}


PICO_INTERNAL void PsndDoDAC(int line_to)
{
  int pos, pos1, len;
  int dout = ym2612.dacout;
  int line_from = PsndDacLine;

  if (line_to >= 312)
    line_to = 311;

  PsndDacLine = line_to + 1;

  pos =dac_info[line_from]>>4;
  pos1=dac_info[line_to];
  len = ((pos1>>4)-pos) + (pos1&0xf);
  if (!len) return;

  if (PicoOpt & POPT_EN_STEREO) {
    short *d = PsndOut + pos*2;
    for (; len > 0; len--, d+=2) *d = dout;
  } else {
    short *d = PsndOut + pos;
    for (; len > 0; len--, d++)  *d = dout;
  }
}

// cdda
static void cdda_raw_update(int *buffer, int length)
{
  int ret, cdda_bytes, mult = 1;

  cdda_bytes = length*4;
  if (PsndRate <= 22050 + 100) mult = 2;
  if (PsndRate <  22050 - 100) mult = 4;
  cdda_bytes *= mult;

  ret = pm_read(cdda_out_buffer, cdda_bytes, Pico_mcd->cdda_stream);
  if (ret < cdda_bytes) {
    memset((char *)cdda_out_buffer + ret, 0, cdda_bytes - ret);
    Pico_mcd->cdda_stream = NULL;
    return;
  }

  // now mix
  switch (mult) {
    case 1: mix_16h_to_32(buffer, cdda_out_buffer, length*2); break;
    case 2: mix_16h_to_32_s1(buffer, cdda_out_buffer, length*2); break;
    case 4: mix_16h_to_32_s2(buffer, cdda_out_buffer, length*2); break;
  }
}

void cdda_start_play(int lba_base, int lba_offset, int lb_len)
{
  if (Pico_mcd->cdda_type == CT_MP3)
  {
    int pos1024 = 0;

    if (lba_offset)
      pos1024 = lba_offset * 1024 / lb_len;

    mp3_start_play(Pico_mcd->cdda_stream, pos1024);
    return;
  }

  pm_seek(Pico_mcd->cdda_stream, (lba_base + lba_offset) * 2352, SEEK_SET);
  if (Pico_mcd->cdda_type == CT_WAV)
  {
    // skip headers, assume it's 44kHz stereo uncompressed
    pm_seek(Pico_mcd->cdda_stream, 44, SEEK_CUR);
  }
}


PICO_INTERNAL void PsndClear(void)
{
  int len = PsndLen;
  if (PsndLen_exc_add) len++;
  if (PicoOpt & POPT_EN_STEREO)
    memset32((int *) PsndOut, 0, len); // assume PsndOut to be aligned
  else {
    short *out = PsndOut;
    if ((long)out & 2) { *out++ = 0; len--; }
    memset32((int *) out, 0, len/2);
    if (len & 1) out[len-1] = 0;
  }
}


static int PsndRender(int offset, int length)
{
  int  buf32_updated = 0;
  int *buf32 = PsndBuffer+offset;
  int stereo = (PicoOpt & 8) >> 3;

  offset <<= stereo;

  pprof_start(sound);

#if !SIMPLE_WRITE_SOUND
  if (offset == 0) { // should happen once per frame
    // compensate for float part of PsndLen
    PsndLen_exc_cnt += PsndLen_exc_add;
    if (PsndLen_exc_cnt >= 0x10000) {
      PsndLen_exc_cnt -= 0x10000;
      length++;
    }
  }
#endif

  // PSG
  if (PicoOpt & POPT_EN_PSG)
    SN76496Update(PsndOut+offset, length, stereo);

  if (PicoAHW & PAHW_PICO) {
    PicoPicoPCMUpdate(PsndOut+offset, length, stereo);
    return length;
  }

  // Add in the stereo FM buffer
  if (PicoOpt & POPT_EN_FM) {
    buf32_updated = YM2612UpdateOne(buf32, length, stereo, 1);
  } else
    memset32(buf32, 0, length<<stereo);

//printf("active_chs: %02x\n", buf32_updated);
  (void)buf32_updated;

  // CD: PCM sound
  if (PicoAHW & PAHW_MCD) {
    pcd_pcm_update(buf32, length, stereo);
    //buf32_updated = 1;
  }

  // CD: CDDA audio
  // CD mode, cdda enabled, not data track, CDC is reading
  if ((PicoAHW & PAHW_MCD) && (PicoOpt & POPT_EN_MCD_CDDA)
      && Pico_mcd->cdda_stream != NULL
      && !(Pico_mcd->s68k_regs[0x36] & 1))
  {
    // note: only 44, 22 and 11 kHz supported, with forced stereo
    if (Pico_mcd->cdda_type == CT_MP3)
      mp3_update(buf32, length, stereo);
    else
      cdda_raw_update(buf32, length);
  }

  if ((PicoAHW & PAHW_32X) && (PicoOpt & POPT_EN_PWM))
    p32x_pwm_update(buf32, length, stereo);

  // convert + limit to normal 16bit output
  PsndMix_32_to_16l(PsndOut+offset, buf32, length);

  pprof_end(sound);

  return length;
}

// to be called on 224 or line_sample scanlines only
PICO_INTERNAL void PsndGetSamples(int y)
{
#if SIMPLE_WRITE_SOUND
  if (y != 224) return;
  PsndRender(0, PsndLen);
  if (PicoWriteSound)
    PicoWriteSound(PsndLen * ((PicoOpt & POPT_EN_STEREO) ? 4 : 2));
  PsndClear();
#else
  static int curr_pos = 0;

  if (y == 224)
  {
    if (emustatus & 2)
         curr_pos += PsndRender(curr_pos, PsndLen-PsndLen/2);
    else curr_pos  = PsndRender(0, PsndLen);
    if (emustatus & 1)
         emustatus |=  2;
    else emustatus &= ~2;
    if (PicoWriteSound)
      PicoWriteSound(curr_pos * ((PicoOpt & POPT_EN_STEREO) ? 4 : 2));
    // clear sound buffer
    PsndClear();
  }
  else if (emustatus & 3) {
    emustatus|= 2;
    emustatus&=~1;
    curr_pos = PsndRender(0, PsndLen/2);
  }
#endif
}

PICO_INTERNAL void PsndGetSamplesMS(void)
{
  int stereo = (PicoOpt & 8) >> 3;
  int length = PsndLen;

#if !SIMPLE_WRITE_SOUND
  // compensate for float part of PsndLen
  PsndLen_exc_cnt += PsndLen_exc_add;
  if (PsndLen_exc_cnt >= 0x10000) {
    PsndLen_exc_cnt -= 0x10000;
    length++;
  }
#endif

  // PSG
  if (PicoOpt & POPT_EN_PSG)
    SN76496Update(PsndOut, length, stereo);

  // upmix to "stereo" if needed
  if (stereo) {
    int i, *p;
    for (i = length, p = (void *)PsndOut; i > 0; i--, p++)
      *p |= *p << 16;
  }

  if (PicoWriteSound != NULL)
    PicoWriteSound(length * ((PicoOpt & POPT_EN_STEREO) ? 4 : 2));
  PsndClear();
}

