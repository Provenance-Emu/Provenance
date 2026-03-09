/***************************************************************************

  sn76496.c

  Routines to emulate the Texas Instruments SN76489 / SN76496 programmable
  tone /noise generator. Also known as (or at least compatible with) TMS9919.

  Noise emulation is not accurate due to lack of documentation. The noise
  generator uses a shift register with a XOR-feedback network, but the exact
  layout is unknown. It can be set for either period or white noise; again,
  the details are unknown.

  28/03/2005 : Sebastien Chevalier
  Update th SN76496Write func, according to SN76489 doc found on SMSPower.
   - On write with 0x80 set to 0, when LastRegister is other then TONE,
   the function is similar than update with 0x80 set to 1
***************************************************************************/

#ifndef __GNUC__
#pragma warning (disable:4244)
#endif

#include "sn76496.h"

#define MAX_OUTPUT 0x4800 // was 0x7fff

#define STEP 0x10000


/* Formulas for noise generator */
/* bit0 = output */

/* noise feedback for white noise mode (verified on real SN76489 by John Kortink) */
#define FB_WNOISE_T 0x3000	/* (15bits) bit15 = bit1 ^ bit2, TI */
#define FB_WNOISE_S 0x9000	/* (16bits) bit16 = bit0 ^ bit3, Sega PSG */

/* noise feedback for periodic noise mode */
#define FB_PNOISE_T 0x4000	/* 15bit rotate for TI */
#define FB_PNOISE_S 0x8000	/* 16bit rotate for Sega PSG */

#define FB_WNOISE FB_WNOISE_S	/* Sega */
#define FB_PNOISE FB_PNOISE_S


struct SN76496
{
	//sound_stream * Channel;
	int SampleRate;
	unsigned int UpdateStep;
	int VolTable[16];	/* volume table         */
	int Register[8];	/* registers */
	int LastRegister;	/* last register written */
	int Volume[4];		/* volume of voice 0-2 and noise */
	unsigned int RNG;	/* noise generator      */
	int NoiseFB;		/* noise feedback mask */
	int Period[4];
	int Count[4];
	int Output[4];
	int Panning;
};

static struct SN76496 ono_sn; // one and only SN76496
int *sn76496_regs = ono_sn.Register;

//static
void SN76496Write(int data)
{
	struct SN76496 *R = &ono_sn;
	int n, r, c;

	/* update the output buffer before changing the registers */
	//stream_update(R->Channel,0);

	r = R->LastRegister;
	if (data & 0x80)
		r = R->LastRegister = (data & 0x70) >> 4;
	c = r / 2;

	if (!(data & 0x80) && (r == 0 || r == 2 || r == 4))
		// data byte (tone only)
		R->Register[r] = (R->Register[r] & 0x0f) | ((data & 0x3f) << 4);
	else
		R->Register[r] = (R->Register[r] & 0x3f0) | (data & 0x0f);

	data = R->Register[r];
	switch (r)
	{
		case 0:	/* tone 0 : frequency */
		case 2:	/* tone 1 : frequency */
		case 4:	/* tone 2 : frequency */
			R->Period[c] = R->UpdateStep * data;
			if (R->Period[c] == 0) R->Period[c] = R->UpdateStep;
			if (R->Count[c] > R->Period[c]) R->Count[c] = R->Period[c];
			if (r == 4)
			{
				/* update noise shift frequency */
				if ((R->Register[6] & 0x03) == 0x03)
					R->Period[3] = 2 * R->Period[2];
			}
			break;
		case 1:	/* tone 0 : volume */
		case 3:	/* tone 1 : volume */
		case 5:	/* tone 2 : volume */
		case 7:	/* noise  : volume */
			R->Volume[c] = R->VolTable[data & 0x0f];
			break;
		case 6:	/* noise  : frequency, mode */
			n = data;
			R->NoiseFB = (n & 4) ? FB_WNOISE : FB_PNOISE;
			n &= 3;
			/* N/512,N/1024,N/2048,Tone #3 output */
			R->Period[3] = 2 * (n == 3 ? R->Period[2] : R->UpdateStep << (4 + n));

			/* reset noise shifter */
			R->RNG = FB_PNOISE;
			R->Output[3] = R->RNG & 1;
			break;
	}
}

/*
WRITE8_HANDLER( SN76496_0_w ) {	SN76496Write(0,data); }
WRITE8_HANDLER( SN76496_1_w ) {	SN76496Write(1,data); }
WRITE8_HANDLER( SN76496_2_w ) {	SN76496Write(2,data); }
WRITE8_HANDLER( SN76496_3_w ) {	SN76496Write(3,data); }
WRITE8_HANDLER( SN76496_4_w ) {	SN76496Write(4,data); }
*/

//static
void SN76496Update(short *buffer, int length, int stereo)
{
	int i;
	struct SN76496 *R = &ono_sn;

	while (length > 0)
	{
		int vol[4];
		int left;


		/* vol[] keeps track of how long each square wave stays */
		/* in the 1 position during the sample period. */
		vol[0] = vol[1] = vol[2] = vol[3] = 0;

		for (i = 0;i < 3;i++)
		{
			if (R->Output[i]) vol[i] += R->Count[i];
			R->Count[i] -= STEP;
			/* Period[i] is the half period of the square wave. Here, in each */
			/* loop I add Period[i] twice, so that at the end of the loop the */
			/* square wave is in the same status (0 or 1) it was at the start. */
			/* vol[i] is also incremented by Period[i], since the wave has been 1 */
			/* exactly half of the time, regardless of the initial position. */
			/* If we exit the loop in the middle, Output[i] has to be inverted */
			/* and vol[i] incremented only if the exit status of the square */
			/* wave is 1. */
			if (R->Count[i] < -2*R->Period[i] || R->Volume[i] == 0) {
				/* Cut off anything above the Nyquist frequency. */
				/* It will only create aliasing anyway. This is actually an */
				/* ideal lowpass filter with Nyquist corner frequency. */
				vol[i] += STEP/2; // mean value
				R->Count[i] = R->Output[i] = 0;
			}
			while (R->Count[i] < 0)
			{
				R->Count[i] += R->Period[i];
				if (R->Count[i] >= 0)
				{
					R->Output[i] ^= 1;
					if (R->Output[i]) vol[i] += R->Period[i];
					break;
				}
				R->Count[i] += R->Period[i];
				vol[i] += R->Period[i];
			}
			if (R->Output[i]) vol[i] -= R->Count[i];
		}

		left = STEP;
		if (R->Output[3]) vol[3] += R->Count[3];
		do
		{
			int nextevent;

			if (R->Count[3] < left) nextevent = R->Count[3];
			else nextevent = left;

			R->Count[3] -= nextevent;
			if (R->Count[3] <= 0)
			{
				R->Output[3] = R->RNG & 1;
				R->RNG >>= 1;
				if (R->Output[3])
				{
					R->RNG ^= R->NoiseFB;
					vol[3] += R->Period[3];
				}
				R->Count[3] += R->Period[3];
			}

			left -= nextevent;
		} while (left > 0 && R->Volume[3]);
		if (R->Output[3]) vol[3] -= R->Count[3];

		length--;
		if (R->Panning == 0xff || !stereo) {
			unsigned int out =
				vol[0] * R->Volume[0] + vol[1] * R->Volume[1] +
				vol[2] * R->Volume[2] + vol[3] * R->Volume[3];

			if (out > MAX_OUTPUT * STEP) out = MAX_OUTPUT * STEP;

			out /= STEP; // will be optimized to shift; max 0x4800 = 18432
			*buffer++ += out;
			if (stereo) *buffer++ += out;
		} else {
#define P(n) !!(R->Panning & (1<<(n)))
			unsigned int outl =
				vol[0] * R->Volume[0] * P(4) + vol[1] * R->Volume[1] * P(5) +
				vol[2] * R->Volume[2] * P(6) + vol[3] * R->Volume[3] * P(7);
			unsigned int outr =
				vol[0] * R->Volume[0] * P(0) + vol[1] * R->Volume[1] * P(1) +
				vol[2] * R->Volume[2] * P(2) + vol[3] * R->Volume[3] * P(3);
#undef P
			if (outl > MAX_OUTPUT * STEP) outl = MAX_OUTPUT * STEP;
			if (outr > MAX_OUTPUT * STEP) outr = MAX_OUTPUT * STEP;

			outl /= STEP; // will be optimized to shift; max 0x4800 = 18432
			outr /= STEP; // will be optimized to shift; max 0x4800 = 18432
			*buffer++ += outl;
			*buffer++ += outr;
		}
	}
}

void SN76496Config(int panning)
{
	struct SN76496 *R = &ono_sn;
	R->Panning = panning & 0xff;
}


static void SN76496_set_clock(struct SN76496 *R,int clock)
{

	/* the base clock for the tone generators is the chip clock divided by 16; */
	/* for the noise generator, it is clock / 256. */
	/* Here we calculate the number of steps which happen during one sample */
	/* at the given sample rate. No. of events = sample rate / (clock/16). */
	/* STEP is a multiplier used to turn the fraction into a fixed point */
	/* number. */
	R->UpdateStep = ((double)STEP * R->SampleRate * 16) / clock;
}


static void SN76496_set_gain(struct SN76496 *R,int gain)
{
	int i;
	double out;


	gain &= 0xff;

	/* increase max output basing on gain (0.2 dB per step) */
	out = MAX_OUTPUT / 4.0;
	while (gain-- > 0)
		out *= 1.023292992;	/* = (10 ^ (0.2/20)) */

	/* build volume table (2dB per step) */
	for (i = 0;i < 15;i++)
	{
		/* limit volume to avoid clipping */
		if (out > MAX_OUTPUT / 4) R->VolTable[i] = MAX_OUTPUT / 4;
		else R->VolTable[i] = out;

		out /= 1.258925412;	/* = 10 ^ (2/20) = 2dB */
	}
	R->VolTable[15] = 0;
}


//static
void SN76496_set_clockrate(int clock,int sample_rate)
{
	struct SN76496 *R = &ono_sn;

	R->SampleRate = sample_rate;
	SN76496_set_clock(R,clock);
}

//static
int SN76496_init(int clock,int sample_rate)
{
	struct SN76496 *R = &ono_sn;
	int i;

	//R->Channel = stream_create(0,1, sample_rate,R,SN76496Update);

	SN76496_set_clockrate(clock,sample_rate);

	for (i = 0;i < 4;i++) R->Volume[i] = 0;

	R->LastRegister = 0;
	for (i = 0;i < 8;i+=2)
	{
		R->Register[i] = 0;
		R->Register[i + 1] = 0x0f;	/* volume = 0 */
	}

	for (i = 0;i < 4;i++)
	{
		R->Volume[i] = R->Output[i] = R->Count[i] = 0;
		R->Period[i] = R->UpdateStep;
	}
	R->RNG = FB_PNOISE;
	R->Output[3] = R->RNG & 1;

	// added
	SN76496_set_gain(R, 0);
	R->Panning = 0xff;

	return 0;
}

