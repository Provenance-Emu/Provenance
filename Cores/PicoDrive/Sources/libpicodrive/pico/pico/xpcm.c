/*
 * PicoDrive
 * (C) notaz, 2008
 * (C) irixxxx, 2024
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 *
 * The following ADPCM algorithm was derived from MAME upd7759 driver.
 *
 * The Pico is using this chip in slave mode. In this mode there are no ROM
 * headers, but the first byte sent to the chip is used to start the ADPCM
 * engine. This byte is discarded, i.e. not processed by the engine.
 *
 * Data is fed into the chip through a FIFO. An Interrupt is created if the
 * FIFO has been drained below the low water mark.
 *
 * The Pico has 2 extensions to the standard upd7759 chip:
 * - gain control, used to control the volume of the ADPCM output
 * - filtering, used to remove (some of) the ADPCM compression artifacts
 */

#include <math.h>
#include "../pico_int.h"

/* limitter */
#define Limit(val, max, min) \
	(val > max ? max : val < min ? min : val)

#define ADPCM_CLOCK	(1280000/4)

#define FIFO_IRQ_THRESHOLD 16

static const int step_deltas[16][16] =
{
  { 0,  0,  1,  2,  3,   5,   7,  10,  0,   0,  -1,  -2,  -3,   -5,   -7,  -10 },
  { 0,  1,  2,  3,  4,   6,   8,  13,  0,  -1,  -2,  -3,  -4,   -6,   -8,  -13 },
  { 0,  1,  2,  4,  5,   7,  10,  15,  0,  -1,  -2,  -4,  -5,   -7,  -10,  -15 },
  { 0,  1,  3,  4,  6,   9,  13,  19,  0,  -1,  -3,  -4,  -6,   -9,  -13,  -19 },
  { 0,  2,  3,  5,  8,  11,  15,  23,  0,  -2,  -3,  -5,  -8,  -11,  -15,  -23 },
  { 0,  2,  4,  7, 10,  14,  19,  29,  0,  -2,  -4,  -7, -10,  -14,  -19,  -29 },
  { 0,  3,  5,  8, 12,  16,  22,  33,  0,  -3,  -5,  -8, -12,  -16,  -22,  -33 },
  { 1,  4,  7, 10, 15,  20,  29,  43, -1,  -4,  -7, -10, -15,  -20,  -29,  -43 },
  { 1,  4,  8, 13, 18,  25,  35,  53, -1,  -4,  -8, -13, -18,  -25,  -35,  -53 },
  { 1,  6, 10, 16, 22,  31,  43,  64, -1,  -6, -10, -16, -22,  -31,  -43,  -64 },
  { 2,  7, 12, 19, 27,  37,  51,  76, -2,  -7, -12, -19, -27,  -37,  -51,  -76 },
  { 2,  9, 16, 24, 34,  46,  64,  96, -2,  -9, -16, -24, -34,  -46,  -64,  -96 },
  { 3, 11, 19, 29, 41,  57,  79, 117, -3, -11, -19, -29, -41,  -57,  -79, -117 },
  { 4, 13, 24, 36, 50,  69,  96, 143, -4, -13, -24, -36, -50,  -69,  -96, -143 },
  { 4, 16, 29, 44, 62,  85, 118, 175, -4, -16, -29, -44, -62,  -85, -118, -175 },
  { 6, 20, 36, 54, 76, 104, 144, 214, -6, -20, -36, -54, -76, -104, -144, -214 },
};

static const int state_deltas[16] = { -1, -1, 0, 0, 1, 2, 2, 3, -1, -1, 0, 0, 1, 2, 2, 3 };

static s32 stepsamples;	// ratio as Q16, host sound rate / chip sample rate

static struct xpcm_state {
  s32 samplepos;	// leftover duration for current sample wrt sndrate, Q16
  int sample;		// current sample
  short state;		// ADPCM decoder state
  short samplegain;	// programmable gain

  char startpin;	// value on the !START pin
  char irqenable;	// IRQ enabled?

  char portstate;	// ADPCM stream state
  short silence;	// silence blocks still to be played
  short rate, nibbles;	// ADPCM nibbles still to be played
  unsigned char highlow, cache; // nibble selector and cache

  char filter;		// filter selector
  s32 x[3], y[3];	// filter history
} xpcm;
enum { RESET, START, HDR, COUNT }; // portstate


// SEGA Pico specific filtering

#define QB      16                      // mantissa bits
#define FP(f)	(int)((f)*(1<<QB))      // convert to fixpoint

static struct iir2 { // 2nd order Butterworth IIR coefficients
  s32 a[2], gain;	// coefficients
} filters[4];
static struct iir2 *filter; // currently selected filter


static void PicoPicoFilterCoeff(struct iir2 *iir, int cutoff, int rate)
{
  // no filter if the cutoff is above the Nyquist frequency
  if (cutoff >= rate/2) {
    memset(iir, 0, sizeof(*iir));
    return;
  }

  // compute 2nd order butterworth filter coefficients
  double a = 1 / tan(M_PI * cutoff / rate);
  double axa = a*a;
  double gain = 1/(1 + M_SQRT2*a + axa);
  iir->gain = FP(gain);
  iir->a[0] = FP(2 * (axa-1) * gain);
  iir->a[1] = FP(-(1 - M_SQRT2*a + axa) * gain);
}

static int PicoPicoFilterApply(struct iir2 *iir, int sample)
{
  if (!iir)
    return sample;

  // NB Butterworth specific!
  xpcm.x[0] = xpcm.x[1]; xpcm.x[1] = xpcm.x[2];
  xpcm.x[2] = sample * iir->gain; // Qb
  xpcm.y[0] = xpcm.y[1]; xpcm.y[1] = xpcm.y[2];
  xpcm.y[2] = (xpcm.x[0] + 2*xpcm.x[1] + xpcm.x[2]
               + xpcm.y[0]*iir->a[1] + xpcm.y[1]*iir->a[0]) >> QB;
  return xpcm.y[2];
}


// pin functions, N designating a negated pin

PICO_INTERNAL void PicoPicoPCMResetN(int pin)
{
  if (!pin) {
    xpcm.portstate = RESET;
    xpcm.sample = xpcm.samplepos = xpcm.state = 0;
    xpcm.nibbles = xpcm.silence = 0;
  } else if (xpcm.portstate == RESET)
    xpcm.portstate = START;
}

PICO_INTERNAL void PicoPicoPCMStartN(int pin)
{
  xpcm.startpin = pin;
}

PICO_INTERNAL int PicoPicoPCMBusyN(void)
{
  return (xpcm.portstate <= START);
}


// configuration functions

PICO_INTERNAL void PicoPicoPCMRerate(void)
{
  s32 nextstep = ((u64)PicoIn.sndRate<<16)/ADPCM_CLOCK;

  // if the sound rate changes, erase filter history to avoid freak behaviour
  if (stepsamples != nextstep) {
    memset(xpcm.x, 0, sizeof(xpcm.x));
    memset(xpcm.y, 0, sizeof(xpcm.y));
  }

  // output samples per chip clock
  stepsamples = nextstep;

  // compute filter coefficients, cutoff at half the ADPCM sample rate
  PicoPicoFilterCoeff(&filters[1],  6000/2, PicoIn.sndRate); // 5-6 KHz
  PicoPicoFilterCoeff(&filters[2],  9000/2, PicoIn.sndRate); // 8-12 KHz
  PicoPicoFilterCoeff(&filters[3], 15000/2, PicoIn.sndRate); // 14-16 KHz

  PicoPicoPCMFilter(xpcm.filter);
}

PICO_INTERNAL void PicoPicoPCMGain(int gain)
{
  xpcm.samplegain = gain*4;
}

PICO_INTERNAL void PicoPicoPCMFilter(int index)
{
  // if the filter changes, erase the history to avoid freak behaviour
  if (index != xpcm.filter) {
    memset(xpcm.x, 0, sizeof(xpcm.x));
    memset(xpcm.y, 0, sizeof(xpcm.y));
  }

  xpcm.filter = index;
  filter = filters+index;
  if (filter->a[0] == 0)
    filter = NULL;
}

PICO_INTERNAL void PicoPicoPCMIrqEn(int enable)
{
  xpcm.irqenable = (enable ? 3 : 0);
}

// TODO need an interupt pending mask?
PICO_INTERNAL int PicoPicoIrqAck(int level)
{
  return (PicoPicohw.fifo_bytes < FIFO_IRQ_THRESHOLD && level != xpcm.irqenable
            ? xpcm.irqenable : 0);
}


// adpcm operation

#define apply_filter(v) PicoPicoFilterApply(filter, v)

// compute next ADPCM sample
#define do_sample(nibble) \
{ \
  xpcm.sample += step_deltas[xpcm.state][nibble]; \
  xpcm.state += state_deltas[nibble]; \
  xpcm.state = (xpcm.state < 0 ? 0 : xpcm.state > 15 ? 15 : xpcm.state); \
}

// writes samples with sndRate, nearest neighbour resampling, filtering
#define write_sample(buffer, length, stereo) \
{ \
  while (xpcm.samplepos > 0 && length > 0) { \
    int val = Limit(xpcm.samplegain*xpcm.sample, 16383, -16384); \
    xpcm.samplepos -= 1<<16; \
    length --; \
    if (buffer) { \
      int out = apply_filter(val); \
      *buffer++ += out; \
      if (stereo) *buffer++ += out; \
    } \
  } \
}

PICO_INTERNAL void PicoPicoPCMUpdate(short *buffer, int length, int stereo)
{
  unsigned char *src = PicoPicohw.xpcm_buffer;
  unsigned char *lim = PicoPicohw.xpcm_ptr;
  int srcval, irq = 0;

  // leftover partial sample from last run
  write_sample(buffer, length, stereo);

  // loop over FIFO data, generating ADPCM samples
  while (length > 0 && src < lim)
  {
    // ADPCM state engine
    if (xpcm.silence > 0) { // generate silence
      xpcm.silence --;
      xpcm.sample = 0;
      xpcm.samplepos += stepsamples*256;

    } else if (xpcm.nibbles > 0) { // produce samples
      xpcm.nibbles --;

      if (xpcm.highlow)
        xpcm.cache = *src++;
      else
        xpcm.cache <<= 4;
      xpcm.highlow = !xpcm.highlow;

      do_sample((xpcm.cache & 0xf0) >> 4);
      xpcm.samplepos += stepsamples*xpcm.rate;

    } else switch (xpcm.portstate) { // handle stream headers
      case RESET:
        xpcm.sample = 0;
        xpcm.samplepos += length<<16;
        break;
      case START:
        if (xpcm.startpin) {
          if (*src)
            xpcm.portstate ++;
          else // kill 0x00 bytes at stream start
            src ++;
        } else {
          xpcm.sample = 0;
          xpcm.samplepos += length<<16;
        }
        break;
      case HDR:
        srcval = *src++;
        xpcm.nibbles = xpcm.silence = xpcm.rate = 0;
        xpcm.highlow = 1;
        if (srcval == 0) { // terminator
          // HACK, kill leftover odd byte to avoid restart (Minna de Odorou)
          if (lim-src == 1) src++;
          xpcm.portstate = START;
        } else switch (srcval >> 6) {
          case 0: xpcm.silence = (srcval & 0x3f) + 1; break;
          case 1: xpcm.rate = (srcval & 0x3f) + 1; xpcm.nibbles = 256; break;
          case 2: xpcm.rate = (srcval & 0x3f) + 1; xpcm.portstate = COUNT; break;
          case 3: break;
        }
        break;
      case COUNT:
        xpcm.nibbles = *src++ + 1; xpcm.portstate = HDR;
        break;
      }

    write_sample(buffer, length, stereo);
  }

  // buffer cleanup, generate irq if lowwater reached
  if (src < lim && src != PicoPicohw.xpcm_buffer) {
    int di = lim - src;
    memmove(PicoPicohw.xpcm_buffer, src, di);
    PicoPicohw.xpcm_ptr = PicoPicohw.xpcm_buffer + di;
    elprintf(EL_PICOHW, "xpcm update: over %i", di);

    if (!irq && di < FIFO_IRQ_THRESHOLD)
      irq = xpcm.irqenable;
    PicoPicohw.fifo_bytes = di;
  } else if (src == lim && src != PicoPicohw.xpcm_buffer) {
    PicoPicohw.xpcm_ptr = PicoPicohw.xpcm_buffer;
    elprintf(EL_PICOHW, "xpcm update: under %i", length);

    if (!irq)
      irq = xpcm.irqenable;
    PicoPicohw.fifo_bytes = 0;
  }

  // TODO need an IRQ mask somewhere to avoid loosing one in cases of HINT/VINT
  if (irq && SekIrqLevel != irq) {
    elprintf(EL_PICOHW, "irq%d", irq);
    if (SekIrqLevel < irq)
      SekInterrupt(irq);
  }

  if (buffer && length) {
    // for underflow, use last sample to avoid clicks
    int val = Limit(xpcm.samplegain*xpcm.sample, 16383, -16384);
    while (length--) {
      int out = apply_filter(val);
      *buffer++ += out;
      if (stereo) *buffer++ += out;
    }
  }
}

PICO_INTERNAL int PicoPicoPCMSave(void *buffer, int length)
{
  u8 *bp = buffer;

  if (length < sizeof(xpcm)) {
    elprintf(EL_ANOMALY, "save buffer too small?");
    return 0;
  }

  memcpy(bp, &xpcm, sizeof(xpcm));
  bp += sizeof(xpcm);
  return (bp - (u8*)buffer);
}

PICO_INTERNAL void PicoPicoPCMLoad(void *buffer, int length)
{
  u8 *bp = buffer;

  if (length >= sizeof(xpcm))
    memcpy(&xpcm, bp, sizeof(xpcm));
  bp += sizeof(xpcm);
}
