/*
 * PicoDrive
 * (c) Copyright Dave, 2004
 * (C) notaz, 2006-2009
 * (C) irixxxx, 2019-2024
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include <string.h>
#include "../pico_int.h"
#include "ym2612.h"
#include "sn76496.h"
#include "emu2413/emu2413.h"
#include "../cd/megasd.h"
#include "resampler.h"
#include "mix.h"

#define YM2612_CH6PAN   0x1b6   // panning register for channel 6 (used for DAC)

void (*PsndMix_32_to_16)(s16 *dest, s32 *src, int count) = mix_32_to_16_stereo;

// master int buffer to mix to
// +1 for a fill triggered by an instruction overhanging into the next scanline
static s32 PsndBuffer[2*(54000+100)/50+2];

// cdda output buffer
s16 cdda_out_buffer[2*1152];

// sn76496
extern int *sn76496_regs;

// FM resampling polyphase FIR
static resampler_t *fmresampler;
static int (*PsndFMUpdate)(s32 *buffer, int length, int stereo, int is_buf_empty);

// ym2413
static OPLL *opll = NULL;
static struct {
  uint32_t adr;
  uint8_t reg[sizeof(opll->reg)];
} opll_buf;


void YM2413_regWrite(unsigned data){
  OPLL_writeIO(opll,0,data);
}
void YM2413_dataWrite(unsigned data){
  OPLL_writeIO(opll,1,data);
}

PICO_INTERNAL void *YM2413GetRegs(void)
{
  memcpy(opll_buf.reg, opll->reg, sizeof(opll->reg));
  opll_buf.adr = opll->adr;
  return &opll_buf;
}

PICO_INTERNAL void YM2413UnpackState(void)
{
  int i;

  for (i = sizeof(opll->reg)-1; i >= 0; i--) {
    OPLL_writeIO(opll, 0, i);
    OPLL_writeIO(opll, 1, opll_buf.reg[i]);
  }
  opll->adr = opll_buf.adr;
}

PICO_INTERNAL void PsndInit(void)
{
  opll = OPLL_new(OSC_NTSC/15, OSC_NTSC/15/72);
  OPLL_setChipType(opll,0);
  OPLL_reset(opll);
}

PICO_INTERNAL void PsndExit(void)
{
  OPLL_delete(opll);
  opll = NULL;

  resampler_free(fmresampler); fmresampler = NULL;
}

PICO_INTERNAL void PsndReset(void)
{
  // PsndRerate calls YM2612Init, which also resets
  PsndRerate(0);
  timers_reset();
}

// FM polyphase FIR resampling
#define FMFIR_TAPS	8

// resample FM from its native 53267Hz/52781Hz with polyphase FIR filter
static int ymchans;
static void YM2612Update(s32 *buffer, int length, int stereo)
{
  ymchans = YM2612UpdateOne(buffer, length, stereo, 1);
}

static int YM2612UpdateFIR(s32 *buffer, int length, int stereo, int is_buf_empty)
{
  resampler_update(fmresampler, buffer, length, YM2612Update);
  return ymchans;
}

// resample SMS FM from its native 49716Hz/49262Hz with polyphase FIR filter
static void YM2413Update(s32 *buffer, int length, int stereo)
{
  while (length-- > 0) {
    int16_t getdata = OPLL_calc(opll) * 3;
    *buffer++ = getdata;
    buffer += stereo; // only left for stereo, to be mixed to right later
  }
}

static int YM2413UpdateFIR(s32 *buffer, int length, int stereo, int is_buf_empty)
{
  if (!is_buf_empty) memset(buffer, 0, (length << stereo) * sizeof(*buffer));
  resampler_update(fmresampler, buffer, length, YM2413Update);
  return 0;
}

// FIR setup, looks for a close enough rational number matching the ratio
static void YMFM_setup_FIR(int inrate, int outrate, int stereo)
{
  int mindiff = 999;
  int diff, mul, div;
  int minmult = 11, maxmult = 61; // min,max interpolation factor

  // compute filter ratio with largest multiplier for smallest error
  for (mul = minmult; mul <= maxmult; mul++) {
    div = (inrate*mul + outrate/2) / outrate;
    diff = outrate*div/mul - inrate;
    if (abs(diff) < abs(mindiff)) {
      mindiff = diff;
      Pico.snd.fm_fir_mul = mul;
      Pico.snd.fm_fir_div = div;
      if (abs(mindiff)*1000 <= inrate) break; // below error limit
    }
  }
  printf("FM polyphase FIR ratio=%d/%d error=%.3f%%\n",
        Pico.snd.fm_fir_mul, Pico.snd.fm_fir_div, 100.0*mindiff/inrate);

  resampler_free(fmresampler);
  fmresampler = resampler_new(FMFIR_TAPS, Pico.snd.fm_fir_mul, Pico.snd.fm_fir_div,
        0.85, 2, 2*inrate/50, stereo);
}

// wrapper for the YM2612UpdateONE macro
static int YM2612UpdateONE(s32 *buffer, int length, int stereo, int is_buf_empty)
{
  return YM2612UpdateOne(buffer, length, stereo, is_buf_empty);
}

static int ymclock;
static int ymrate;
static int ymopts;

// to be called after changing sound rate or chips
void PsndRerate(int preserve_state)
{
  void *state = NULL;
  int target_fps = Pico.m.pal ? 50 : 60;
  int target_lines = Pico.m.pal ? 313 : 262;
  int sms_clock = Pico.m.pal ? OSC_PAL/15 : OSC_NTSC/15;
  int ym2413_rate = (sms_clock + 36) / 72;
  int ym2612_clock = Pico.m.pal ? OSC_PAL/7 : OSC_NTSC/7;
  int ym2612_rate = YM2612_NATIVE_RATE();
  int ym2612_init = !preserve_state;

  // don't init YM2612 if preserve_state and no parameter changes
  ym2612_init |= ymclock != ym2612_clock || ymopts != (PicoIn.opt & (POPT_DIS_FM_SSGEG|POPT_EN_FM_DAC));
  ym2612_init |= ymrate != (PicoIn.opt & POPT_EN_FM_FILTER ? ym2612_rate : PicoIn.sndRate);
  ymclock = ym2612_clock;
  ymrate = (PicoIn.opt & POPT_EN_FM_FILTER ? ym2612_rate : PicoIn.sndRate);
  ymopts = PicoIn.opt & (POPT_DIS_FM_SSGEG|POPT_EN_FM_DAC);

  if (preserve_state && ym2612_init) {
    state = malloc(0x204);
    if (state == NULL) return;
    ym2612_pack_state();
    memcpy(state, YM2612GetRegs(), 0x204);
  }

  if (PicoIn.AHW & PAHW_SMS) {
    OPLL_setRate(opll, ym2413_rate);
    if (!preserve_state)
      OPLL_reset(opll);
    YMFM_setup_FIR(ym2413_rate, PicoIn.sndRate, 0);
    PsndFMUpdate = YM2413UpdateFIR;
  } else if ((PicoIn.opt & POPT_EN_FM_FILTER) && ym2612_rate != PicoIn.sndRate) {
    // polyphase FIR resampler, resampling directly from native to output rate
    if (ym2612_init)
      YM2612Init(ym2612_clock, ym2612_rate,
        ((PicoIn.opt&POPT_DIS_FM_SSGEG) ? 0 : ST_SSG) |
        ((PicoIn.opt&POPT_EN_FM_DAC)    ? ST_DAC : 0));
    YMFM_setup_FIR(ym2612_rate, PicoIn.sndRate, PicoIn.opt & POPT_EN_STEREO);
    PsndFMUpdate = YM2612UpdateFIR;
  } else {
    if (ym2612_init)
      YM2612Init(ym2612_clock, PicoIn.sndRate,
        ((PicoIn.opt&POPT_DIS_FM_SSGEG) ? 0 : ST_SSG) |
        ((PicoIn.opt&POPT_EN_FM_DAC)    ? ST_DAC : 0));
    PsndFMUpdate = YM2612UpdateONE;
  }

  if (preserve_state && ym2612_init) {
    // feed it back it's own registers, just like after loading state
    memcpy(YM2612GetRegs(), state, 0x204);
    ym2612_unpack_state();
    free(state);
  }

  if (preserve_state)
    SN76496_set_clockrate(Pico.m.pal ? OSC_PAL/15 : OSC_NTSC/15, PicoIn.sndRate);
  else
    SN76496_init(Pico.m.pal ? OSC_PAL/15 : OSC_NTSC/15, PicoIn.sndRate);

  // calculate Pico.snd.len
  Pico.snd.len = PicoIn.sndRate / target_fps;
  Pico.snd.len_e_add = ((PicoIn.sndRate - Pico.snd.len * target_fps) << 16) / target_fps;
  Pico.snd.len_e_cnt = 0; // Q16

  // samples per line (Q16)
  Pico.snd.smpl_mult = 65536LL * PicoIn.sndRate / (target_fps*target_lines);
  // samples per z80 clock (Q20)
  Pico.snd.clkl_mult = 16 * Pico.snd.smpl_mult * 15/7 / 488.5;
  // samples per 44.1 KHz sample
  Pico.snd.cdda_mult = 65536LL * 44100 / PicoIn.sndRate;
  Pico.snd.cdda_div  = 65536LL * PicoIn.sndRate / 44100;

  // clear all buffers
  memset32(PsndBuffer, 0, sizeof(PsndBuffer)/4);
  memset(cdda_out_buffer, 0, sizeof(cdda_out_buffer));
  if (PicoIn.sndOut)
    PsndClear();

  // set mixer
  PsndMix_32_to_16 = (PicoIn.opt & POPT_EN_STEREO) ? mix_32_to_16_stereo : mix_32_to_16_mono;
  mix_reset(PicoIn.opt & POPT_EN_SNDFILTER ? PicoIn.sndFilterAlpha : 0);

  if (PicoIn.AHW & PAHW_PICO)
    PicoReratePico();
}


PICO_INTERNAL void PsndStartFrame(void)
{
  // compensate for float part of Pico.snd.len
  Pico.snd.len_use = Pico.snd.len;
  Pico.snd.len_e_cnt += Pico.snd.len_e_add;
  if (Pico.snd.len_e_cnt >= 0x10000) {
    Pico.snd.len_e_cnt -= 0x10000;
    Pico.snd.len_use++;
  }
}

PICO_INTERNAL void PsndDoDAC(int cyc_to)
{
  int pos, len;
  int dout = ym2612.dacout;

  // nothing to do if sound is off
  if (!PicoIn.sndOut) return;

  // number of samples to fill in buffer (Q20)
  len = (cyc_to * Pico.snd.clkl_mult) - Pico.snd.dac_pos;

  // update position and calculate buffer offset and length
  pos = (Pico.snd.dac_pos+0x80000) >> 20;
  Pico.snd.dac_pos += len;
  len = ((Pico.snd.dac_pos+0x80000) >> 20) - pos;

  // avoid loss of the 1st sample of a new block (Q rounding issues)
  if (pos+len == 0)
    len = 1, Pico.snd.dac_pos += 0x80000;
  if (len <= 0)
    return;

  // fill buffer, applying a rather weak order 1 bessel IIR on the way
  // y[n] = (x[n] + x[n-1])*(1/2) (3dB cutoff at 11025 Hz, no gain)
  // 1 sample delay for correct IIR filtering over audio frame boundaries
  if (PicoIn.opt & POPT_EN_STEREO) {
    s16 *d = PicoIn.sndOut + pos*2;
    int pan = ym2612.REGS[YM2612_CH6PAN];
    int l = pan & 0x80 ? Pico.snd.dac_val : 0;
    int r = pan & 0x40 ? Pico.snd.dac_val : 0;
    *d++ += pan & 0x80 ? Pico.snd.dac_val2 : 0;
    *d++ += pan & 0x40 ? Pico.snd.dac_val2 : 0;
    while (--len) *d++ += l, *d++ += r;
  } else {
    s16 *d = PicoIn.sndOut + pos;
    *d++ += Pico.snd.dac_val2;
    while (--len) *d++ += Pico.snd.dac_val;
  }
  Pico.snd.dac_val2 = (Pico.snd.dac_val + dout) >> 1;
  Pico.snd.dac_val = dout;
}

PICO_INTERNAL void PsndDoPSG(int cyc_to)
{
  int pos, len;
  int stereo = 0;

  // nothing to do if sound is off
  if (!PicoIn.sndOut) return;

  // number of samples to fill in buffer (Q20)
  len = (cyc_to * Pico.snd.clkl_mult) - Pico.snd.psg_pos;

  // update position and calculate buffer offset and length
  pos = (Pico.snd.psg_pos+0x80000) >> 20;
  Pico.snd.psg_pos += len;
  len = ((Pico.snd.psg_pos+0x80000) >> 20) - pos;

  if (len <= 0)
    return;
  if (!(PicoIn.opt & POPT_EN_PSG))
    return;

  if (PicoIn.opt & POPT_EN_STEREO) {
    stereo = 1;
    pos <<= 1;
  }
  SN76496Update(PicoIn.sndOut + pos, len, stereo);
}

PICO_INTERNAL void PsndDoSMSFM(int cyc_to)
{
  int pos, len;
  int stereo = 0;
  s32 *buf32 = PsndBuffer;
  s16 *buf = PicoIn.sndOut;

  // nothing to do if sound is off
  if (!PicoIn.sndOut) return;

  // number of samples to fill in buffer (Q20)
  len = (cyc_to * Pico.snd.clkl_mult) - Pico.snd.ym2413_pos;

  // update position and calculate buffer offset and length
  pos = (Pico.snd.ym2413_pos+0x80000) >> 20;
  Pico.snd.ym2413_pos += len;
  len = ((Pico.snd.ym2413_pos+0x80000) >> 20) - pos;

  if (len <= 0)
    return;
  if (!(PicoIn.opt & POPT_EN_YM2413))
    return;

  if (PicoIn.opt & POPT_EN_STEREO) {
    stereo = 1;
    pos <<= 1;
  }

  if (Pico.m.hardware & PMS_HW_FMUSED) {
    buf += pos;
    PsndFMUpdate(buf32, len, 0, 0);
    if (stereo) 
      while (len--) {
        *buf++ += *buf32;
        *buf++ += *buf32++;
      }
    else
      while (len--) {
        *buf++ += *buf32++;
      }
  }
}

PICO_INTERNAL void PsndDoFM(int cyc_to)
{
  int pos, len;
  int stereo = 0;

  // nothing to do if sound is off
  if (!PicoIn.sndOut) return;

  // Q20, number of samples since last call
  len = (cyc_to * Pico.snd.clkl_mult) - Pico.snd.fm_pos;

  // update position and calculate buffer offset and length
  pos = (Pico.snd.fm_pos+0x80000) >> 20;
  Pico.snd.fm_pos += len;
  len = ((Pico.snd.fm_pos+0x80000) >> 20) - pos;
  if (len <= 0)
    return;

  // fill buffer
  if (PicoIn.opt & POPT_EN_STEREO) {
    stereo = 1;
    pos <<= 1;
  }
  if (PicoIn.opt & POPT_EN_FM)
    PsndFMUpdate(PsndBuffer + pos, len, stereo, 1);
}

PICO_INTERNAL void PsndDoPCM(int cyc_to)
{
  int pos, len;
  int stereo = 0;

  // nothing to do if sound is off
  if (!PicoIn.sndOut) return;

  // Q20, number of samples since last call
  len = (cyc_to * Pico.snd.clkl_mult) - Pico.snd.pcm_pos;

  // update position and calculate buffer offset and length
  pos = (Pico.snd.pcm_pos+0x80000) >> 20;
  Pico.snd.pcm_pos += len;
  len = ((Pico.snd.pcm_pos+0x80000) >> 20) - pos;
  if (len <= 0)
    return;

  // fill buffer
  if (PicoIn.opt & POPT_EN_STEREO) {
    stereo = 1;
    pos <<= 1;
  }
  PicoPicoPCMUpdate(PicoIn.sndOut + pos, len, stereo);
}

// cdda
static void cdda_raw_update(s32 *buffer, int length, int stereo)
{
  int ret, cdda_bytes;

  cdda_bytes = (length * Pico.snd.cdda_mult >> 16) * 4;

  ret = pm_read_audio(cdda_out_buffer, cdda_bytes, Pico_mcd->cdda_stream);
  if (ret < cdda_bytes) {
    memset((char *)cdda_out_buffer + ret, 0, cdda_bytes - ret);
    Pico_mcd->cdda_stream = NULL;
    return;
  }

  // now mix
  if (stereo) switch (Pico.snd.cdda_mult) {
    case 0x10000: mix_16h_to_32(buffer, cdda_out_buffer, length*2);     break;
    case 0x20000: mix_16h_to_32_s1(buffer, cdda_out_buffer, length*2);  break;
    case 0x40000: mix_16h_to_32_s2(buffer, cdda_out_buffer, length*2);  break;
    default: mix_16h_to_32_resample_stereo(buffer, cdda_out_buffer, length, Pico.snd.cdda_mult);
  } else
    mix_16h_to_32_resample_mono(buffer, cdda_out_buffer, length, Pico.snd.cdda_mult);
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
  int len = Pico.snd.len;
  if (Pico.snd.len_e_add) len++;

  // drop pos remainder to avoid rounding errors (not entirely correct though)
  Pico.snd.dac_pos = Pico.snd.fm_pos = Pico.snd.psg_pos = Pico.snd.ym2413_pos = Pico.snd.pcm_pos = 0;
  if (!PicoIn.sndOut) return;

  if (PicoIn.opt & POPT_EN_STEREO)
    memset32((int *) PicoIn.sndOut, 0, len); // assume PicoIn.sndOut to be aligned
  else {
    s16 *out = PicoIn.sndOut;
    if ((uintptr_t)out & 2) { *out++ = 0; len--; }
    memset32((int *) out, 0, len/2);
    if (len & 1) out[len-1] = 0;
  }
  if (!(PicoIn.opt & POPT_EN_FM))
    memset32(PsndBuffer, 0, PicoIn.opt & POPT_EN_STEREO ? len*2 : len);
}


static int PsndRender(int offset, int length)
{
  s32 *buf32;
  int stereo = (PicoIn.opt & 8) >> 3;
  int fmlen = ((Pico.snd.fm_pos+0x80000) >> 20);
  int daclen = ((Pico.snd.dac_pos+0x80000) >> 20);
  int psglen = ((Pico.snd.psg_pos+0x80000) >> 20);
  int pcmlen = ((Pico.snd.pcm_pos+0x80000) >> 20);

  buf32 = PsndBuffer+(offset<<stereo);

  pprof_start(sound);

  // Add in parts of the PSG output not yet done
  if (length-psglen > 0 && PicoIn.sndOut) {
    s16 *psgbuf = PicoIn.sndOut + (psglen << stereo);
    Pico.snd.psg_pos += (length-psglen) << 20;
    if (PicoIn.opt & POPT_EN_PSG)
      SN76496Update(psgbuf, length-psglen, stereo);
  }

  if (PicoIn.AHW & PAHW_PICO) {
    // always need to render sound for interrupts
    s16 *buf16 = PicoIn.sndOut ? PicoIn.sndOut + (pcmlen<<stereo) : NULL;
    PicoPicoPCMUpdate(buf16, length-pcmlen, stereo);
    return length;
  }

  // Fill up DAC output in case of missing samples (Q rounding errors)
  if (length-daclen > 0 && PicoIn.sndOut) {
    Pico.snd.dac_pos += (length-daclen) << 20;
    if (PicoIn.opt & POPT_EN_STEREO) {
      s16 *d = PicoIn.sndOut + daclen*2;
      int pan = ym2612.REGS[YM2612_CH6PAN];
      int l = pan & 0x80 ? Pico.snd.dac_val : 0;
      int r = pan & 0x40 ? Pico.snd.dac_val : 0;
      *d++ += pan & 0x80 ? Pico.snd.dac_val2 : 0;
      *d++ += pan & 0x40 ? Pico.snd.dac_val2 : 0;
      if (l|r) for (daclen++; length-daclen > 0; daclen++)
          *d++ += l, *d++ += r;
    } else {
      s16 *d = PicoIn.sndOut + daclen;
      *d++ += Pico.snd.dac_val2;
      if (Pico.snd.dac_val) for (daclen++; length-daclen > 0; daclen++)
        *d++ += Pico.snd.dac_val;
    }
    Pico.snd.dac_val2 = Pico.snd.dac_val;
  }

  // Add in parts of the FM buffer not yet done
  if (length-fmlen > 0 && PicoIn.sndOut) {
    s32 *fmbuf = buf32 + ((fmlen-offset) << stereo);
    Pico.snd.fm_pos += (length-fmlen) << 20;
    if (PicoIn.opt & POPT_EN_FM)
      PsndFMUpdate(fmbuf, length-fmlen, stereo, 1);
  }

  // CD: PCM sound
  if (PicoIn.AHW & PAHW_MCD) {
    pcd_pcm_update(buf32, length-offset, stereo);
  }

  // CD: CDDA audio
  // CD mode, cdda enabled, not data track, CDC is reading
  if ((PicoIn.AHW & PAHW_MCD) && (PicoIn.opt & POPT_EN_MCD_CDDA)
      && Pico_mcd->cdda_stream != NULL
      && (!(Pico_mcd->s68k_regs[0x36] & 1) || Pico_msd.state == 3))
  {
    if (Pico_mcd->cdda_type == CT_MP3)
      mp3_update(buf32, length-offset, stereo);
    else
      cdda_raw_update(buf32, length-offset, stereo);
  }

  if ((PicoIn.AHW & PAHW_32X) && (PicoIn.opt & POPT_EN_PWM))
    p32x_pwm_update(buf32, length-offset, stereo);

  // convert + limit to normal 16bit output
  if (PicoIn.sndOut)
    PsndMix_32_to_16(PicoIn.sndOut+(offset<<stereo), buf32, length-offset);

  pprof_end(sound);

  return length;
}

PICO_INTERNAL void PsndGetSamples(int y)
{
  static int curr_pos = 0;

  curr_pos  = PsndRender(0, Pico.snd.len_use);

  if (PicoIn.writeSound && PicoIn.sndOut)
    PicoIn.writeSound(curr_pos * ((PicoIn.opt & POPT_EN_STEREO) ? 4 : 2));
  // clear sound buffer
  PsndClear();
}

static int PsndRenderMS(int offset, int length)
{
  s32 *buf32 = PsndBuffer;
  int stereo = (PicoIn.opt & 8) >> 3;
  int psglen = ((Pico.snd.psg_pos+0x80000) >> 20);
  int ym2413len = ((Pico.snd.ym2413_pos+0x80000) >> 20);

  if (!PicoIn.sndOut)
    return length;

  pprof_start(sound);

  // Add in parts of the PSG output not yet done
  if (length-psglen > 0) {
    s16 *psgbuf = PicoIn.sndOut + (psglen << stereo);
    Pico.snd.psg_pos += (length-psglen) << 20;
    if (PicoIn.opt & POPT_EN_PSG)
      SN76496Update(psgbuf, length-psglen, stereo);
  }

  if (length-ym2413len > 0) {
    s16 *ym2413buf = PicoIn.sndOut + (ym2413len << stereo);
    Pico.snd.ym2413_pos += (length-ym2413len) << 20;
    int len = (length-ym2413len);
    if (Pico.m.hardware & PMS_HW_FMUSED) {
      PsndFMUpdate(buf32, len, 0, 0);
      if (stereo)
        while (len--) {
          *ym2413buf++ += *buf32;
          *ym2413buf++ += *buf32++;
        }
      else
        while (len--) {
          *ym2413buf++ += *buf32++;
        }
    }
  }

  pprof_end(sound);

  return length;
}

PICO_INTERNAL void PsndGetSamplesMS(int y)
{
  static int curr_pos = 0;

  curr_pos  = PsndRenderMS(0, Pico.snd.len_use);

  if (PicoIn.writeSound != NULL && PicoIn.sndOut)
    PicoIn.writeSound(curr_pos * ((PicoIn.opt & POPT_EN_STEREO) ? 4 : 2));
  PsndClear();
}

// vim:shiftwidth=2:ts=2:expandtab
