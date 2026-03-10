/*
 * some code for sample mixing
 * (C) notaz, 2006,2007
 * (C) irixxxx, 2019,2020		added filtering
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include <string.h>
#include "../pico_int.h"

#define MAXOUT		(+32767)
#define MINOUT		(-32768)

/* limitter */
#define Limit16(val) \
	val -= val >> 3; /* reduce level to avoid clipping */	\
	if ((s16)val != val) val = (val < 0 ? MINOUT : MAXOUT)

int mix_32_to_16_level;

static struct iir {
	int	alpha;		// alpha for EMA low pass
	int	y[2];		// filter intermediates
} lfi2, rfi2;

// NB ">>" rounds to -infinity, "/" to 0. To compensate the effect possibly use
// "-(-y>>n)" (round to +infinity) instead of "y>>n" in places.

// NB uses fixpoint; samples mustn't have more than (32-QB) bits. Adding the
// outputs of the sound sources together yields a max. of 18 bits, restricting
// QB to a maximum of 14.
#define QB	12
// NB alpha for DC filtering shouldn't be smaller than 1/(1<<QB) to avoid loss.


// exponential moving average combined DC filter and lowpass filter
// y0[n] = (x[n]-y0[n-1])*alpha+y0[n-1], y1[n] = (y0[n] - y1[n-1])*(1-1/8192)
static inline int filter_band(struct iir *fi2, int x)
{
	// low pass. alpha is Q8 to avoid loss by 32 bit overflow.
//	fi2->y[0] += ((x<<(QB-8)) - (fi2->y[0]>>8)) * fi2->alpha;
	fi2->y[0] += (x - (fi2->y[0]>>QB)) * fi2->alpha;
	// DC filter. for alpha=1-1/8192 cutoff ~1HZ, for 1-1/1024 ~7Hz
	fi2->y[1] += (fi2->y[0] - fi2->y[1]) >> QB;
	return (fi2->y[0] - fi2->y[1]) >> QB;
}

// exponential moving average filter for DC filtering
// y[n] = (x[n]-y[n-1])*(1-1/8192) (corner approx. 1Hz, gain 1)
static inline int filter_exp(struct iir *fi2, int x)
{
	fi2->y[1] += ((x << QB) - fi2->y[1]) >> QB;
	return x - (fi2->y[1] >> QB);
}

// unfiltered (for testing)
static inline int filter_null(struct iir *fi2, int x)
{
	return x;
}

#define filter	filter_band

#define mix_32_to_16_stereo_core(dest, src, count, lv, fl) {	\
	int l, r;						\
	struct iir lf = lfi2, rf = rfi2;			\
								\
	for (; count > 0; count--)				\
	{							\
		l = *dest;					\
		l += *src++ >> lv;				\
		l = fl(&lf, l);					\
		Limit16(l);					\
		*dest++ = l;					\
		r = *dest;					\
		r += *src++ >> lv;				\
		r = fl(&rf, r);					\
		Limit16(r);					\
		*dest++ = r;					\
	}							\
	lfi2 = lf, rfi2 = rf;					\
}

void mix_32_to_16_stereo_lvl(s16 *dest, s32 *src, int count)
{
	mix_32_to_16_stereo_core(dest, src, count, mix_32_to_16_level, filter);
}

void mix_32_to_16_stereo(s16 *dest, s32 *src, int count)
{
	mix_32_to_16_stereo_core(dest, src, count, 0, filter);
}

void mix_32_to_16_mono(s16 *dest, s32 *src, int count)
{
	int l;
	struct iir lf = lfi2;

	for (; count > 0; count--)
	{
		l = *dest;
		l += *src++;
		l = filter(&lf, l);
		Limit16(l);
		*dest++ = l;
	}
	lfi2 = lf;
}


void mix_16h_to_32(s32 *dest_buf, s16 *mp3_buf, int count)
{
	while (count--)
	{
		*dest_buf++ += (*mp3_buf++ * 5) >> 3;
	}
}

void mix_16h_to_32_s1(s32 *dest_buf, s16 *mp3_buf, int count)
{
	count >>= 1;
	while (count--)
	{
		*dest_buf++ += (*mp3_buf++ * 5) >> 3;
		*dest_buf++ += (*mp3_buf++ * 5) >> 3;
		mp3_buf += 1*2;
	}
}

void mix_16h_to_32_s2(s32 *dest_buf, s16 *mp3_buf, int count)
{
	count >>= 1;
	while (count--)
	{
		*dest_buf++ += (*mp3_buf++ * 5) >> 3;
		*dest_buf++ += (*mp3_buf++ * 5) >> 3;
		mp3_buf += 3*2;
	}
}

// mixes cdda audio @44.1 KHz into dest_buf, resampling with nearest neighbour
void mix_16h_to_32_resample_stereo(s32 *dest_buf, s16 *cdda_buf, int count, int fac16)
{
	int pos16 = 0;
	while (count--) {
		int pos = 2 * (pos16>>16);
		*dest_buf++ += (cdda_buf[pos  ] * 5) >> 3;
		*dest_buf++ += (cdda_buf[pos+1] * 5) >> 3;
		pos16 += fac16;
	}
}

// mixes cdda audio @44.1 KHz into dest_buf, resampling with nearest neighbour
void mix_16h_to_32_resample_mono(s32 *dest_buf, s16 *cdda_buf, int count, int fac16)
{
	int pos16 = 0;
	while (count--) {
		int pos = 2 * (pos16>>16);
		*dest_buf   += (cdda_buf[pos  ] * 5) >> 4;
		*dest_buf++ += (cdda_buf[pos+1] * 5) >> 4;
		pos16 += fac16;
	}
}

void mix_reset(int alpha_q16)
{
	memset(&lfi2, 0, sizeof(lfi2));
	memset(&rfi2, 0, sizeof(rfi2));
	lfi2.alpha = rfi2.alpha = (0x10000-alpha_q16) >> 4; // filter alpha, Q12
}
