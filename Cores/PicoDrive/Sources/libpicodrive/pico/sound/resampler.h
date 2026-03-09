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

struct resampler {
  int	stereo;         // mono or stereo?
  int   taps;           // taps to compute per output sample
  int   interpolation;  // upsampling factor (numerator)
  int   decimation;     // downsampling factor (denominator)
  int   ratio_int;      // floor(decimation/interpolation)
  u32   interp_inv;     // Q16, 1.0/interpolation
  s16   *filter;        // filter taps
  s32   *buffer;        // filter history and input buffer (w/o zero stuffing)
  int   buffer_sz;      // buffer size in frames
  int   buffer_idx;     // buffer offset
  int	phase;          // filter phase for last output sample
};
typedef struct resampler resampler_t;


/* Release a resampler */
void resampler_free(resampler_t *r);
/* Create a resampler with upsampling factor :interpolation and downsampling
 * factor :decimation, Kaiser windowed SINC polyphase FIR with bank size :taps.
 * The created filter has a size of :taps*:interpolation for upsampling and
 * :taps*:decimation for downsampling. :taps is limiting the cost per sample and
 * should be big enough to avoid inaccuracy (>= 8, higher is more accurate).
 * :cutoff is in [0..1] with 1 representing the Nyquist rate after decimation.
 * :beta is the Kaiser window beta.
 * :max_input is the maximum length in a resampler_update call */
resampler_t *resampler_new(unsigned taps, unsigned interpolation, unsigned decimation,
       double cutoff, double beta, unsigned max_input, int stereo);
/* Obtain :length resampled audio frames in :buffer. Use :get_samples to obtain
 * the needed amount of input samples */
void resampler_update(resampler_t *r, s32 *buffer, int length,
       void (*generate_samples)(s32 *buffer, int length, int stereo));

