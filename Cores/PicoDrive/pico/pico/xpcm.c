/*
 * PicoDrive
 * (C) notaz, 2008
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 *
 * The following ADPCM algorithm was stolen from MAME aica driver.
 * I'm quite sure it's not the right one, but it's the
 * best sounding of the ones that I tried.
 */

#include "../pico_int.h"

#define ADPCMSHIFT      8
#define ADFIX(f)        (int) ((double)f * (double)(1<<ADPCMSHIFT))

/* limitter */
#define Limit(val, max, min) { \
	if ( val > max )      val = max; \
	else if ( val < min ) val = min; \
}

static const int TableQuant[8] =
{
  ADFIX(0.8984375),
  ADFIX(0.8984375),
  ADFIX(0.8984375),
  ADFIX(0.8984375),
  ADFIX(1.19921875),
  ADFIX(1.59765625),
  ADFIX(2.0),
  ADFIX(2.3984375)
};

// changed using trial and error..
//static const int quant_mul[16] = { 1, 3, 5, 7, 9, 11, 13, 15, -1, -3, -5, -7, -9, -11, -13, -15 };
static const int quant_mul[16]   = { 1, 3, 5, 7, 9, 11, 13, -1, -1, -3, -5, -7, -9, -11, -13, -15 };

static int sample = 0, quant = 0, sgn = 0;
static int stepsamples = (44100<<10)/16000;


PICO_INTERNAL void PicoPicoPCMReset(void)
{
  sample = sgn = 0;
  quant = 0x7f;
  memset(PicoPicohw.xpcm_buffer, 0, sizeof(PicoPicohw.xpcm_buffer));
}

PICO_INTERNAL void PicoPicoPCMRerate(int xpcm_rate)
{
  stepsamples = (PsndRate<<10)/xpcm_rate;
}

#define XSHIFT 6

#define do_sample() \
{ \
  int delta = quant * quant_mul[srcval] >> XSHIFT; \
  sample += delta - (delta >> 2); /* 3/4 */ \
  quant = (quant * TableQuant[srcval&7]) >> ADPCMSHIFT; \
  Limit(quant, 0x6000, 0x7f); \
  Limit(sample, 32767*3/4, -32768*3/4); \
}

PICO_INTERNAL void PicoPicoPCMUpdate(short *buffer, int length, int stereo)
{
  unsigned char *src = PicoPicohw.xpcm_buffer;
  unsigned char *lim = PicoPicohw.xpcm_ptr;
  int srcval, needsamples = 0;

  if (src == lim) goto end;

  for (; length > 0 && src < lim; src++)
  {
    srcval = *src >> 4;
    do_sample();

    for (needsamples += stepsamples; needsamples > (1<<10) && length > 0; needsamples -= (1<<10), length--) {
      *buffer++ += sample;
      if (stereo) { buffer[0] = buffer[-1]; buffer++; }
    }

    srcval = *src & 0xf;
    do_sample();

    for (needsamples += stepsamples; needsamples > (1<<10) && length > 0; needsamples -= (1<<10), length--) {
      *buffer++ += sample;
      if (stereo) { buffer[0] = buffer[-1]; buffer++; }
    }

    // lame normalization stuff, needed due to wrong adpcm algo
    sgn += (sample < 0) ? -1 : 1;
    if (sgn < -16 || sgn > 16) sample -= sample >> 5;
  }

  if (src < lim) {
    int di = lim - src;
    memmove(PicoPicohw.xpcm_buffer, src, di);
    PicoPicohw.xpcm_ptr = PicoPicohw.xpcm_buffer + di;
    elprintf(EL_PICOHW, "xpcm update: over %i", di);
    // adjust fifo
    PicoPicohw.fifo_bytes = di;
    return;
  }

  elprintf(EL_PICOHW, "xpcm update: under %i", length);
  PicoPicohw.xpcm_ptr = PicoPicohw.xpcm_buffer;

end:
  if (stereo)
    // still must expand SN76496 to stereo
    for (; length > 0; buffer+=2, length--)
      buffer[1] = buffer[0];

  sample = sgn = 0;
  quant = 0x7f;
}

