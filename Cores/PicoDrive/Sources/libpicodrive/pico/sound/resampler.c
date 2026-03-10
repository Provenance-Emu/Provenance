/* Configurable fixed point resampling SINC filter for mono and stereo audio.
 *
 * (C) 2022 irixxxx
 *
 * This work is licensed under the terms of any of these licenses
 * (at your option):
 *  - GNU GPL, version 2 or later.
 *  - MAME license.
 * See COPYING file in the top-level directory.
 */


/* SINC filter generation taken from the blipper library, its license is:
 *
 * Copyright (C) 2013 - Hans-Kristian Arntzen
 *
 * Permission is hereby granted, free of charge, 
 * to any person obtaining a copy of this software and
 * associated documentation files (the "Software"),
 * to deal in the Software without restriction,
 * including without limitation the rights to
 * use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software,
 * and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 * DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */


#include <stdlib.h>
#include <stddef.h>
#include <string.h>
#include <math.h>

#include "../pico_types.h"
#include "resampler.h"

#ifndef M_PI
#define M_PI            3.14159265358979323846
#endif

static double besseli0(double x)
{
   unsigned i;
   double sum = 0.0;

   double factorial = 1.0;
   double factorial_mult = 0.0;
   double x_pow = 1.0;
   double two_div_pow = 1.0;
   double x_sqr = x * x;

   /* Approximate. This is an infinite sum.
    * Luckily, it converges rather fast. */
   for (i = 0; i < 18; i++)
   {
      sum += x_pow * two_div_pow / (factorial * factorial);

      factorial_mult += 1.0;
      x_pow *= x_sqr;
      two_div_pow *= 0.25;
      factorial *= factorial_mult;
   }

   return sum;
}

static double sinc(double v)
{
   if (fabs(v) < 0.00001)
      return 1.0;
   else
      return sin(v) / v;
}

/* index range = [-1, 1) */
static double kaiser_window(double index, double beta)
{
   return besseli0(beta * sqrt(1.0 - index * index));
}

/* Creates a polyphase SINC filter (:phases banks with :taps each)
 * Interleaves the filter for cache coherency and possibilities for SIMD */
static s16 *create_sinc(unsigned phases, unsigned taps, double cutoff, double beta)
{
   unsigned i, filter_len;
   double sidelobes, window_mod, window_phase, sinc_phase;
   s16 *filter;
   double tap;

   filter = (s16*)malloc(phases * taps * sizeof(*filter));
   if (!filter)
      return NULL;

   sidelobes = taps / 2.0;
   window_mod = 1.0 / kaiser_window(0.0, beta);
   filter_len = phases * taps;

   for (i = 0; i < filter_len; i++)
   {
      window_phase = (double)i / filter_len; /* [0, 1) */
      window_phase = 2.0 * window_phase - 1.0; /* [-1, 1) */
      sinc_phase = window_phase * sidelobes; /* [-taps / 2, taps / 2) */

      tap = (cutoff * sinc(M_PI * sinc_phase * cutoff) *
         kaiser_window(window_phase, beta) * window_mod);
      /* assign taking filter bank interleaving into account:
       * :phases banks of length :taps */
      filter[(i%phases)*taps + (i/phases)] = tap * 0x7fff + 0.5;
   }

   return filter;
}

/* Public interface */

/* Release a resampler */
void resampler_free(resampler_t *rs)
{
   if (rs)
   {
      free(rs->buffer);
      free(rs->filter);
      free(rs);
   }
}

/* Create a resampler with upsampling factor :interpolation and downsampling
 * factor :decimation, Kaiser windowed SINC polyphase FIR with bank size :taps.
 * The created filter has a size of :taps*:interpolation for upsampling and
 * :taps*:decimation for downsampling. :taps is limiting the cost per sample and
 * should be big enough to avoid inaccuracy (>= 8, higher is more accurate).
 * :cutoff is in [0..1] with 1 representing the Nyquist rate after decimation.
 * :beta is the Kaiser window beta.
 * :max_input is the maximum length in a resampler_update call */
resampler_t *resampler_new(unsigned taps, unsigned interpolation, unsigned decimation,
      double cutoff, double beta, unsigned max_input, int stereo)
{
   resampler_t *rs = NULL;

   if (taps == 0 || interpolation == 0 || decimation == 0 || max_input == 0)
      return NULL; /* invalid parameters */

   rs = (resampler_t*)calloc(1, sizeof(*rs));
   if (!rs)
      return NULL; /* out of memory */

   /* :cutoff is relative to the decimated frequency, but filtering is taking
    * place at the interpolated frequency. It needs to be adapted if resampled
    * rate is lower. Also needs more taps to keep the transition band width */
   if (decimation > interpolation) {
      cutoff = cutoff * interpolation/decimation;
      taps = taps * decimation/interpolation;
   }

   rs->interpolation = interpolation;
   rs->decimation = decimation;
   rs->taps = taps;
   /* optimizers for resampler_update: */
   rs->interp_inv = (1ULL<<32) / interpolation; 
   rs->ratio_int = decimation / interpolation;

   rs->filter = create_sinc(interpolation, taps, cutoff, beta);
   if (!rs->filter)
      goto error;

   rs->stereo = !!stereo;
   rs->buffer_sz = (max_input * decimation/interpolation) + decimation + 1;
   rs->buffer = calloc(1, rs->buffer_sz * (stereo ? 2:1) * sizeof(*rs->buffer));
   if (!rs->buffer)
      goto error;

   return rs;

error:
   if (rs->filter)
      free(rs->filter);
   if (rs->buffer)
      free(rs->buffer);
   free(rs);
   return NULL;
}

/* Obtain :length resampled audio frames in :buffer. Use :get_samples to obtain
 * the needed amount of input samples */
void resampler_update(resampler_t *rs, s32 *buffer, int length,
       void (*get_samples)(s32 *buffer, int length, int stereo))
{
  s16 *u;
  s32 *p, *q = buffer;
  int spf = rs->stereo;
  s32 inlen;
  s32 l, r;
  int n, i;

  if (length <= 0) return;

  /* compute samples needed on input side:
   * inlen = (length*decimation + interpolation-phase) / interpolation */
  n = length*rs->decimation + rs->interpolation-rs->phase;
  inlen = ((u64)n * rs->interp_inv) >> 32; /* input samples, n/interpolation */
  if (n - inlen * rs->interpolation > rs->interpolation) inlen++; /* rounding */

  /* reset buffer to start if the input doesn't fit into the buffer */
  if (rs->buffer_idx + inlen+rs->taps >= rs->buffer_sz) {
    memcpy(rs->buffer, rs->buffer + (rs->buffer_idx<<spf), (rs->taps<<spf)*sizeof(*rs->buffer));
    rs->buffer_idx = 0;
  }
  p = rs->buffer + (rs->buffer_idx<<spf);

  /* generate input samples */
  if (inlen > 0)
    get_samples(p + (rs->taps<<spf), inlen, rs->stereo);

  if (rs->stereo) {
    while (--length >= 0) {
      /* compute filter output */
      s32 *h = p;
      u = rs->filter + (rs->phase * rs->taps);
      for (i = rs->taps-1, l = r = 0; i > 0; i -= 2)
        { n = *u++; l += n * *h++; r += n * *h++;  
          n = *u++; l += n * *h++; r += n * *h++; }
      if (i == 0)
        { n = *u++; l += n * *h++; r += n * *h++; }
      *q++ = l >> 15, *q++ = r >> 15;
      /* advance position to next sample */
      rs->phase -= rs->decimation;
//    if (rs->ratio_int) {
         rs->phase += rs->ratio_int*rs->interpolation,
         p += 2*rs->ratio_int, rs->buffer_idx += rs->ratio_int;
//    }
      if (rs->phase < 0)
        { rs->phase += rs->interpolation, p += 2, rs->buffer_idx ++; }
    }
  } else {
    while (--length >= 0) {
      /* compute filter output */
      s32 *h = p;
      u = rs->filter + (rs->phase * rs->taps);
      for (i = rs->taps-1, l = r = 0; i > 0; i -= 2)
        { n = *u++; l += n * *h++;
          n = *u++; l += n * *h++; }
      if (i == 0)
        { n = *u++; l += n * *h++; }
      *q++ = l >> 15;
      /* advance position to next sample */
      rs->phase -= rs->decimation;
//    if (rs->ratio_int) {
         rs->phase += rs->ratio_int*rs->interpolation,
         p +=   rs->ratio_int, rs->buffer_idx += rs->ratio_int;
//    }
      if (rs->phase < 0)
        { rs->phase += rs->interpolation, p += 1, rs->buffer_idx ++; }
    }
  }
}
