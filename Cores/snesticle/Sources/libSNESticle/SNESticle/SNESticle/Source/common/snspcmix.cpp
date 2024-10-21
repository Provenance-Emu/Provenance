
#include <string.h>
#include <stdio.h>
#include "types.h"
#include "prof.h"
#include "snspcdsp.h"
#include "snspcmix.h"
#include "console.h"
#include "mixbuffer.h"
#include "sntiming.h"
#include "snspcdefs.h"
extern "C" {
#include "snspcbrr.h"
};
#if CODE_PLATFORM == CODE_PS2
#include "ps2mem.h"
#endif

#define SNSPCDSP_INFOSCRATCHPAD ((CODE_PLATFORM == CODE_PS2) && TRUE)
#define SNSPCDSP_MIXSILENCE (FALSE)


#define SNSPCDSP_MIXASM ((CODE_PLATFORM == CODE_PS2) && 1)

Uint32 _ChMask=0xFF;


typedef Int16 SNSpcEchoSampleT;
typedef Int32 SNSpcMixSampleT;


/*
SPC Timing:

CPU cycles/sec: 1022727.272727

sample rate: 32000hz (31.25 microseconds)
32 CPU cycles / sample (32 * 32000 = 1024000)
Envelope updates at 32000hz

Attack:
Linear 0->1 Increments by 1/64 
Requires 64 steps to reach 1.0
envticks = AttackTimeMS * 32000hz / 64

Decay:
Exponential 1->0    Decs by X * 1/256  		595 updates to 1/10

Sustain:
Exponential -> 0    Decs by X * 1/256  		595 updates to 1/10

Increase Bent Line:
0->0.75 Increase by 1/64
0.75->1 Increase by 1/256
(48+64) = 112 total steps
envticks = TimeMS * 32000hz / 112

*/


// channel[i].mix = channel[i].envx * channel[i].outx 
// main_mix = channel[i].mix *  * channel_vol
// echo_mix = channel[i].echo_enabled ? (channel[i].mix * channel_vol) : 0
// echo_out = filter(echo_buffer);
// echo_buffer = echo_out * echo_feedback + echo_mix
// output = main_mix * main_vol + echo_mix * echo_vol




static Uint32 _SNSpcDsp_AttackTimeMS[16]=
{
	4100, 2600, 1500, 1000, 640, 380, 260, 160, 96, 64, 40, 24, 16, 10, 6, 0
};

static Uint32 _SNSpcDsp_DecayTimeMS[8]=
{
	1200, 740, 440, 290, 180, 110, 74, 37
};

static Uint32 _SNSpcDsp_SustainTimeMS[32]=
{
	0xFFFFFFF, 38000, 28000, 24000, 19000, 14000, 12000, 9400, 7100, 5900, 4700, 3500, 2900, 2400, 1800, 1500,
		1200, 880, 740, 590, 440, 370, 290, 220, 180, 150, 110, 92, 74, 55, 37, 28
};

static Uint32 _SNSpcDsp_LinearMS[32]=
{
	0xFFFFFFF,
		4100, 	3100,	2600,	2000,	1500,	1300,	1000,	770,	640,	510,	380,	320,
		260,	190,	160,	130,	96, 	80,	64,	48,	40, 	32,	24,	20,	16,	12,	10,	8,	6,	4,	2,
};

static Uint32 _SNSpcDsp_BentLineMS[32]=
{
	0xFFFFFFF,
		7200, 5400, 4600, 3500, 2600, 2300, 1800,
		1300, 1100, 900, 670, 580, 450, 340, 280,
		220, 170, 140, 110, 84, 70, 56, 42, 
		35, 28, 21, 18, 14, 11, 7, 3
};

static Uint32 _SNSpcDsp_NoiseFreq[32]=
{
	0,	16,	21,	25,	31,	42,	50,	63,	83,	100,	
	125,	107,	200,	250,	333,	400,	500,	667,	800,	1000,	1300,
	1600,	2000,	2700,	3200,	4000,	5300,	6400,	8000,	10700,	16000,	32000
};



//
//
//

void SNSpcDspMix::BuildLookupTables(Uint32 nSampleRate)
{
	int i;
	Uint32 uFactor;

	uFactor = nSampleRate * 0x10000 / SNSPCDSP_SAMPLERATE;

	for (i=0; i < 16; i++)
	{
		m_AttackTicks[i] = _SNSpcDsp_AttackTimeMS[i] * (32 * uFactor / 64);
	}

	for (i=0; i < 8; i++)
	{
		m_DecayTicks[i] = _SNSpcDsp_DecayTimeMS[i] * (32 * uFactor / 595);
	}

	for (i=0; i < 32; i++)
	{
		if (_SNSpcDsp_SustainTimeMS[i] != 0xFFFFFFF) 
		{
			m_SustainTicks[i] = _SNSpcDsp_SustainTimeMS[i] * (32 * uFactor / 595);
		} else
		{
			m_SustainTicks[i] = 0xFFFFFFF;
		}
	}


	for (i=0; i < 32; i++)
	{
		if (_SNSpcDsp_LinearMS[i] != 0xFFFFFFF) 
		{
			m_LinearTicks[i] = _SNSpcDsp_LinearMS[i] * (32 * uFactor / 64);
		} else
		{
			m_LinearTicks[i] = 0xFFFFFFF;
		}
	}

	for (i=0; i < 32; i++)
	{
		if (_SNSpcDsp_BentLineMS[i] != 0xFFFFFFF) 
		{
			m_BentLineTicks[i] = _SNSpcDsp_BentLineMS[i] * (32 * uFactor / 112);
		} else
		{
			m_BentLineTicks[i] = 0xFFFFFFF;
		}
	}
}


void SNSpcDspMix::Reset()
{
	memset(m_Channels, 0, sizeof(m_Channels));
}

void SNSpcDspMix::KeyOn(Int32 iChannel)
{
	SNSpcChannelT *pChannel = &m_Channels[iChannel];
	const SNSpcVoiceRegsT *pRegs = m_pDsp->GetVoiceRegs(iChannel);

	pChannel->eEnvState  = SNSPCDSP_ENVSTATE_ATTACK;
	pChannel->nEnvCount  = 0;
	pChannel->uBlockAddr = m_pDsp->GetSampleDir(pRegs->srcn, 0);
    // clear endx
	pChannel->endx		 = FALSE;
}


void SNSpcDspMix::KeyOff(Int32 iChannel)
{
	SNSpcChannelT *pChannel = &m_Channels[iChannel];

	if ((pChannel->eEnvState!= SNSPCDSP_ENVSTATE_RELEASE) && (pChannel->eEnvState!= SNSPCDSP_ENVSTATE_SILENCE))
	{
		pChannel->eEnvState = SNSPCDSP_ENVSTATE_RELEASE;
		pChannel->nEnvCount = 0;
	}
}

Bool SNSpcDspMix::GetChannelState(Int32 iChannel, Uint8 *pEnvX, Uint8 *pOutX)
{
	SNSpcChannelT *pChannel = &m_Channels[iChannel];
	Bool endx = FALSE;

	*pEnvX = pChannel->envx;
	*pOutX = pChannel->outx;
	endx   = pChannel->endx;

	pChannel->endx = FALSE;
	return endx;
}


Int32 SNSpcDspMix::OutputEnvelope(Int32 iChannel, Uint8 *pOut, Int32 nSamples)
{
	SNSpcChannelT *pChannel = GetChannel(iChannel);
	const SNSpcVoiceRegsT *pRegs = m_pDsp->GetVoiceRegs(iChannel);
	Int32 iEnvelope;
	Int32 nEnvCount;
	Int32 nEnvRate = 0;
	Int32 iEnvTarget;

	// envx=0 by default
	pChannel->envx = 0;					
	pChannel->outx = 0;

	#if !SNSPCDSP_MIXSILENCE
	// sample has ended
	if (pChannel->uBlockAddr== 0)
	{
		return 0;
	}
	#endif

	//
	// initialze envelope state based on register settings
	//
	if (!(pRegs->adsr1 & 0x80))
	{
		SNSpcEnvStateE eNewState = pChannel->eEnvState;
		
		#if !SNSPCDSP_MIXSILENCE
		if (!pRegs->gain)
		{
			return 0;
		}
		#endif

		if (pChannel->eEnvState!=SNSPCDSP_ENVSTATE_RELEASE && pChannel->eEnvState!=SNSPCDSP_ENVSTATE_SILENCE)
		{
			// enforce gain modes
			switch (pRegs->gain >> 5)
			{
			case 0x6:
				eNewState = SNSPCDSP_ENVSTATE_INCREASELINEAR;
				break;
			case 0x7:
				eNewState = SNSPCDSP_ENVSTATE_INCREASEBENTLINE;
				break;
			case 0x4:
				eNewState = SNSPCDSP_ENVSTATE_DECREASELINEAR;
				break;
			case 0x5:
				eNewState = SNSPCDSP_ENVSTATE_DECREASEEXP;
				break;
			default:
				eNewState = SNSPCDSP_ENVSTATE_DIRECT;
			}

			// the equivilent of a gain "key-on"
			if (eNewState!= pChannel->eEnvState)
			{
				pChannel->eEnvState = eNewState;
				pChannel->nEnvCount = 0;
			}
		}
	} 

#if !SNSPCDSP_MIXSILENCE
	if (pChannel->eEnvState==SNSPCDSP_ENVSTATE_SILENCE)
	{
		return 0;
	}
#endif
	

	PROF_ENTER("SNSpcDspOutputEnvelope");

	//
	// process envelope
	//
	iEnvelope = pChannel->iEnvelope;
	nEnvCount = pChannel->nEnvCount;
	while (nSamples > 0)
	{
		// see if enough time elapsed between envelope updates
		if (nEnvCount <= 0)
		{
			// update envelope
			switch (pChannel->eEnvState)
			{
			case SNSPCDSP_ENVSTATE_ATTACK:
				// get attack rate
				nEnvRate = m_AttackTicks[pRegs->adsr1&0xF];
				// update envelope
				iEnvelope += SNSPCDSP_ENVELOPE_MAX >> 6;		// increment by 1/64

				// has attack completed?
				if (iEnvelope >= SNSPCDSP_ENVELOPE_MAX)
				{
					iEnvelope = SNSPCDSP_ENVELOPE_MAX;

					// begin decay
					pChannel->eEnvState = SNSPCDSP_ENVSTATE_DECAY;
				}
				break;

			case SNSPCDSP_ENVSTATE_DECAY:
				// get decay rate
				nEnvRate = m_DecayTicks[(pRegs->adsr1>>4) & 7];
				// get sustain level
				iEnvTarget = ((pRegs->adsr2>>5) + 1) << (SNSPCDSP_ENVELOPE_BITS - 3);

				// update envelope
				iEnvelope -= iEnvelope >> 8;           // decrement by x / 256

				// has decay completed?
				if (iEnvelope <= iEnvTarget)
				{
					iEnvelope = iEnvTarget;
					// begin sustain
					pChannel->eEnvState = SNSPCDSP_ENVSTATE_SUSTAIN;
				}
				break;

			case SNSPCDSP_ENVSTATE_SUSTAIN:
				// get sustain rate
				nEnvRate = m_SustainTicks[pRegs->adsr2&0x1F];
				// update envelope
				iEnvelope -= iEnvelope >> 8;					// decrement by x / 256

				// has sustain completed?
				if (iEnvelope <= 0)
				{
					iEnvelope = 0;
				}
				break;

			case SNSPCDSP_ENVSTATE_RELEASE:
				// set rate, should decrease to 0 in 256 steps ( 256 / 32000 = 0.008 sec)
				nEnvRate = 1 << 16;

				iEnvelope -= SNSPCDSP_ENVELOPE_MAX >> 8;		// decrement by 1/256
				if (iEnvelope <= 0)
				{
					iEnvelope = 0;
					pChannel->eEnvState = SNSPCDSP_ENVSTATE_SILENCE;
				}
				break;

			case SNSPCDSP_ENVSTATE_DECREASELINEAR:
				// get rate
				nEnvRate = m_LinearTicks[pRegs->gain & 0x1F];

				iEnvelope -= SNSPCDSP_ENVELOPE_MAX >> 6;		// decrement by 1/64
				if (iEnvelope <= 0)
				{
					iEnvelope = 0;
				}
				break;

			case SNSPCDSP_ENVSTATE_DECREASEEXP:
				// get sustain rate
				nEnvRate = m_SustainTicks[pRegs->gain & 0x1F];
				// update envelope
				iEnvelope -= iEnvelope >> 8;					// decrement by x / 256

				// has decrease completed?
				if (iEnvelope <= 0)
				{
					iEnvelope = 0;
				}
				break;

			case SNSPCDSP_ENVSTATE_INCREASELINEAR:
				// get rate
				nEnvRate = m_LinearTicks[pRegs->gain & 0x1F];
				// update envelope
				iEnvelope += SNSPCDSP_ENVELOPE_MAX >> 6;		// increment by 1/64

				// has increase completed?
				if (iEnvelope >= SNSPCDSP_ENVELOPE_MAX)
				{
					iEnvelope = SNSPCDSP_ENVELOPE_MAX;
				}
				break;

			case SNSPCDSP_ENVSTATE_INCREASEBENTLINE:
				// get rate
				nEnvRate = m_BentLineTicks[pRegs->gain & 0x1F];

				if (iEnvelope >= (SNSPCDSP_ENVELOPE_MAX * 3 / 4 ))
				{
					// update envelope
					iEnvelope += SNSPCDSP_ENVELOPE_MAX >> 8;		// increment by 1/256
				} else
				{
					// update envelope
					iEnvelope += SNSPCDSP_ENVELOPE_MAX >> 6;		// increment by 1/64
				}

				// has increase completed?
				if (iEnvelope >= SNSPCDSP_ENVELOPE_MAX)
				{
					iEnvelope = SNSPCDSP_ENVELOPE_MAX;
				}
				break;

			case SNSPCDSP_ENVSTATE_DIRECT:
				iEnvelope = pRegs->gain << (SNSPCDSP_ENVELOPE_BITS - 7);
				nEnvCount = 0x10000000;
				nEnvRate  = 0;
				break;

			default:
			case SNSPCDSP_ENVSTATE_SILENCE:
				iEnvelope = 0;
				nEnvCount = 0x10000000;
				nEnvRate  = 0;
				break;
			}

			// increment envcount (number of ticks until next update)
			nEnvCount += nEnvRate;
		}

		// write envelope
		*pOut = iEnvelope >> (SNSPCDSP_ENVELOPE_BITS - 7);
		pOut++;

		// next sample
		nEnvCount-= 1 << 16;
		nSamples--;
	}

	// cleanup
	pChannel->iEnvelope = iEnvelope;
	pChannel->nEnvCount = nEnvCount;

	// update envx
	pChannel->envx = iEnvelope >> (SNSPCDSP_ENVELOPE_BITS - 7);

	// voice ended?
	if (pChannel->eEnvState == SNSPCDSP_ENVSTATE_SILENCE)
	{
		// signal end of channel
		pChannel->endx = TRUE;
	}

	PROF_LEAVE("SNSpcDspOutputEnvelope");
	return 1;
}

//
// full (real) mixer
//

void SNSpcDspMixFull::Reset()
{
	SNSpcDspMix::Reset();

	memset(&m_Echo, 0, sizeof(m_Echo));
	memset(m_EchoBuffer, 0, sizeof(m_EchoBuffer));
	m_iNoisePhase = 0;
	m_uNoiseGen   = 1;
}

Int32 SNSpcDspMixFull::OutputNoise(Int16 *pOut, Uint16 *pFrac, Int32 nSamples, Int32 nSampleRate)
{
	Uint32 uNoiseFreq;
	Int32 iNoisePhase;
	Int32 iNoisePhaseInc;
	Uint32 uNoiseGen;

	iNoisePhase = m_iNoisePhase;
	uNoiseGen   = m_uNoiseGen;
	if (uNoiseGen==0) uNoiseGen=1;

	// get noise frequency
	uNoiseFreq = _SNSpcDsp_NoiseFreq[m_pDsp->GetReg(SNSPCDSP_REG_FLG) & 0x1F];

	iNoisePhaseInc = 0x10000 * uNoiseFreq / nSampleRate;

	while (nSamples > 0)
	{
		while (iNoisePhase >= 0x10000)
		{
			uNoiseGen<<=1;
			if (uNoiseGen & 0x80000000)
			{
				uNoiseGen^=0x0040001;
			}

			iNoisePhase-= 0x10000;
		}

		iNoisePhase+=iNoisePhaseInc;

		pOut[0] = uNoiseGen;
		pOut[1] = uNoiseGen;
		pFrac[0] = 0;
		pOut+=2;
		pFrac++;
		nSamples--;
	}

	m_iNoisePhase = iNoisePhase;
	m_uNoiseGen   = uNoiseGen;
	return 1;
}

void SNSpcDspMixFull::FetchBlock(Int32 iChannel)
{
	SNSpcChannelT *pChannel = GetChannel(iChannel);
	Uint8 uFlags = 0;

	// copy previous samples
	pChannel->BlockData[0][14] = pChannel->BlockData[1][14];
	pChannel->BlockData[0][15] = pChannel->BlockData[1][15];

	// decode next block
	if (pChannel->uBlockAddr!=0) 
	{
		PROF_ENTER("SNSpcBRRDecode");
		uFlags = SNSpcBRRDecode((m_pDsp->GetMem() + pChannel->uBlockAddr), pChannel->BlockData[1], pChannel->BlockData[0][15], pChannel->BlockData[0][14]);
		PROF_LEAVE("SNSpcBRRDecode");
		pChannel->uBlockAddr += 9;
	}  else
	{
		// fade out slowly
//		SNSpcBRRClear(pChannel->BlockData[1], pChannel->BlockData[0][15] - (pChannel->BlockData[0][15]>>1));
		SNSpcBRRClear(pChannel->BlockData[1], 0);
	}

	// end of sample reached?
	if (uFlags&1)
	{
		const SNSpcVoiceRegsT *pRegs = m_pDsp->GetVoiceRegs(iChannel);

		//$ set ENDX
		pChannel->endx = TRUE;
		//m_RegsSNSPCDSP_REG_ENDX] |=   1 << iChannel;

		if (uFlags & 2 )
		{
			// do looping here?
			pChannel->uBlockAddr = m_pDsp->GetSampleDir(pRegs->srcn, 2);
		} else
		{
			pChannel->uBlockAddr = 0;
		}
	}
}


Int32 SNSpcDspMixFull::OutputSample(Int32 iChannel, Int16 *pOut, Uint16 *pFrac, Int32 nSamples, Int32 nSampleRate)
{
	SNSpcChannelT *pChannel = GetChannel(iChannel);
	const SNSpcVoiceRegsT *pRegs = m_pDsp->GetVoiceRegs(iChannel);
	Int32 iPhase;
	Int32 iPhaseInc;
	Uint32 uPitch;
	Int16 *pBlockData;

#if !SNSPCDSP_MIXSILENCE
	if (pChannel->uBlockAddr == 0)
	{
		pChannel->uOldBlockAddr = pChannel->uBlockAddr;
		// silent sample data
		return 0;
	}
#endif

	PROF_ENTER("SNSpcDspOutputSample");

	pBlockData = pChannel->BlockData[1];

	// did something external change the block address?
	// fix to keep interpolation correct
	if (pChannel->uBlockAddr!= pChannel->uOldBlockAddr)
	{
		// this is done to ensure interpolation is correct from old sample to new sample
		pBlockData[14] = pBlockData[(pChannel->iPhase >> 16) + 0];
		pBlockData[15] = pBlockData[(pChannel->iPhase >> 16) + 1];

		// trigger decode, retain fractional component 
		pChannel->iPhase &= 0xFFFF;
		pChannel->iPhase |= 14 << 16;		
	}



	// get pitch
	uPitch = pRegs->pitch_lo | (pRegs->pitch_hi<<8);
	uPitch&= 0x3FFF;

	iPhase = pChannel->iPhase;
	
	// output at correct pitch based on sample rate
	iPhaseInc = uPitch * SNSPCDSP_SAMPLERATE / nSampleRate; 
	iPhaseInc <<= 4;


	while (nSamples > 0)
	{
		Int16 *pSample;
//		Int32 iFrac;
		Int32 iSample0, iSample1;

		if (iPhase >= (14 << 16))
		{
			// fetch next block
			FetchBlock(iChannel);

			iPhase -= (16<<16);
		}

		pSample = &pBlockData[iPhase>>16];
		iSample0 = pSample[0];
		iSample1 = pSample[1];
		// write samples to be filtered later
		pFrac[0]= (Uint16)iPhase;  // phase = 0.15,  % of interpolation,   0000 = Sample0  FFFF = Sample1
		pFrac++;
		pOut[0] = iSample0;
		pOut[1] = iSample1;
		pOut+=2;


		// next sample
		iPhase+= iPhaseInc;

		nSamples--;
	}


	// voice ended?
	if (pChannel->uBlockAddr == 0)
	{
		pChannel->eEnvState = SNSPCDSP_ENVSTATE_SILENCE;
		pChannel->endx = TRUE;
	}

	// set outx to be envx for now
	pChannel->outx = pChannel->envx;

	pChannel->uOldBlockAddr = pChannel->uBlockAddr;
	pChannel->iPhase = iPhase;
	PROF_LEAVE("SNSpcDspOutputSample");
	return 1;
}







#if SNSPCDSP_MIXASM

void _MixChannel(Int32 *pOutLeft, Int32 *pOutRight, Int16 *pIn, Uint8 *pEnvelope, Uint16 *pFrac, Int32 nSamples, Int32 iVolLeft, Int32 iVolRight)
{
	__asm__ (
		"pcpyh       %0,%0           \n"    
		"pcpyld      %0,%0,%0           \n"    
		"pcpyh       %1,%1           \n"    
		"pcpyld      %1,%1,%1           \n"    

		: "+r" (iVolLeft), "+r" (iVolRight)
		);    


	__asm__ __volatile__ (
		".set noreorder \n"
		".align 3           \n"
		"_MixChannelPS2_Loop:         \n"
		"lq         $10,0x00(%1)     \n"    // $10 = 8x frac bits (0.0.16)
		"lq          $8,0x00(%0)     \n"    // $8  = 4x sample pairs (1.15.0)
		"pnor       $11,$10,$0       \n"    // $11 = inv frac bits
		"lq          $9,0x10(%0)     \n"    // $9  = 4x sample pairs (1.15.0)
		"pextlh     $12,$10,$11      \n"    // $12 = invfrac, frac x 4  0.0.16
		"pextuh     $13,$10,$11      \n"    // $13 = invfrac, frac x 4  0.0.16

		"psrlh      $12,$12,1        \n"    // $12 = invfrace frac x 4  1.0.15
		"psrlh      $13,$13,1        \n"    // $13 = invfrace frac x 4  1.0.15

		"ld         $10,0x00(%4)     \n"    // $10 = 8x8 envelope 0.1.7   

		"phmadh     $8,$8,$12        \n"    // $8  = 4 interpolated samplse 2.15.15
		"pextlb     $10,$0,$10       \n"    // $10 =  8x8 envelope  8.1.7
		"phmadh     $9,$9,$13        \n"    // $9  = 4 interpolated samplse 2.15.15

		"pextuh     $11,$0,$10       \n"    // $11 = 4x16 envelope 24.1.7
		"pextlh     $10,$0,$10       \n"    // $10 = 4x16 envelope 24.1.7

		"psraw      $8,$8,15         \n"    // $8 = 32-bit interpolated samples 17.15.0
		"pmulth     $8,$8,$10        \n"    // $8 = 32-bit sample * envelope  10.15.7

		"psraw      $9,$9,15         \n"    // $9 = 32-bit interpolated samples 17.15.0
		"pmulth     $9,$9,$11        \n"    // $9 = 32-bit sample * envelope  10.15.7

		"addiu      %0,%0,0x20       \n"    // pInn+=16
		"addiu      %1,%1,0x10       \n"    // pFrac+=8
		"addiu      %4,%4,0x08       \n"    // pEnvelope+=8

		"psraw      $8,$8,7          \n"    // $8 = 32-bit sample * envelope 17.15.0
		"pmulth     $10,$8,%6        \n"    // $10= right  32-bit sample * envelope * volr  .15.14
		"psraw      $9,$9,7          \n"    // $9 = 32-bit sample * envelope 17.15.0
		"pmulth     $11,$9,%6        \n"    // $11= right  32-bit sample * envelope * volr  .15.14

		"pmulth     $8,$8,%5        \n"     // $8 = left   32-bit sample * envelope * voll  .15.14
		"lq         $12,0x00(%2)     \n"    // $12 = outl0
		"pmulth     $9,$9,%5        \n"     // $9 = left   32-bit sample * envelope * voll  .15.14
		"lq         $13,0x10(%2)     \n"    // $13 = outl1
		"lq         $14,0x00(%3)     \n"    // $14 = outr0
		"lq         $15,0x10(%3)     \n"    // $15 = outr1

		"paddsw		$12,$12,$8       \n"
		"paddsw		$13,$13,$9       \n"
		"paddsw		$14,$14,$10      \n"
		"paddsw		$15,$15,$11      \n"

		"sq         $12,0x00(%2)     \n"    // $12 = outl0
		"sq         $13,0x10(%2)     \n"    // $13 = outl1
		"sq         $14,0x00(%3)     \n"    // $12 = outr0
		"sq         $15,0x10(%3)     \n"    // $12 = outr1

		"addiu      %7,%7,-8         \n"
		"addiu      %2,%2,0x20       \n"

		"bgtz       %7,_MixChannelPS2_Loop \n"
		"addiu      %3,%3,0x20       \n"

		".set reorder \n"

		: 
	: "r" (pIn), "r" (pFrac), "r" (pOutLeft), "r" (pOutRight), "r" (pEnvelope), "r" (iVolLeft), "r" (iVolRight), "r" (nSamples)
		: "$8", "$9", "$10", "$11", "$12", "$13", "$14", "$15"
		);    
}


void _MixChannelEcho(Int32 *pOutLeft, Int32 *pOutRight, Int16 *pEchoLeft, Int16 *pEchoRight, Int16 *pIn, Uint8 *pEnvelope, Uint16 *pFrac, Int32 nSamples, Int32 iVolLeft, Int32 iVolRight)
{
	__asm__ (
		"pcpyh       %0,%0           \n"    
		"pcpyld      %0,%0,%0           \n"    
		"pcpyh       %1,%1           \n"    
		"pcpyld      %1,%1,%1           \n"    

		: "+r" (iVolLeft), "+r" (iVolRight)
		);    


	__asm__ __volatile__ (
		".set noreorder \n"
		".align 3           \n"
		"_MixChannelEchoPS2_Loop:         \n"
		"lq         $10,0x00(%1)     \n"    // $10 = 8x frac bits (0.0.16)
		"lq          $8,0x00(%0)     \n"    // $8  = 4x sample pairs (1.15.0)
		"pnor       $11,$10,$0       \n"    // $11 = inv frac bits
		"lq          $9,0x10(%0)     \n"    // $9  = 4x sample pairs (1.15.0)
		"pextlh     $12,$10,$11      \n"    // $12 = invfrac, frac x 4  0.0.16
		"pextuh     $13,$10,$11      \n"    // $13 = invfrac, frac x 4  0.0.16

		"psrlh      $12,$12,1        \n"    // $12 = invfrace frac x 4  1.0.15
		"psrlh      $13,$13,1        \n"    // $13 = invfrace frac x 4  1.0.15

		"ld         $10,0x00(%4)     \n"    // $10 = 8x8 envelope 0.1.7   

		"phmadh     $8,$8,$12        \n"    // $8  = 4 interpolated samplse 2.15.15
		"pextlb     $10,$0,$10       \n"    // $10 =  8x8 envelope  8.1.7
		"phmadh     $9,$9,$13        \n"    // $9  = 4 interpolated samplse 2.15.15

		"pextuh     $11,$0,$10       \n"    // $11 = 4x16 envelope 24.1.7
		"pextlh     $10,$0,$10       \n"    // $10 = 4x16 envelope 24.1.7

		"psraw      $8,$8,15         \n"    // $8 = 32-bit interpolated samples 17.15.0
		"pmulth     $8,$8,$10        \n"    // $8 = 32-bit sample * envelope  10.15.7

		"psraw      $9,$9,15         \n"    // $9 = 32-bit interpolated samples 17.15.0
		"pmulth     $9,$9,$11        \n"    // $9 = 32-bit sample * envelope  10.15.7

		"addiu      %0,%0,0x20       \n"    // pInn+=16
		"addiu      %1,%1,0x10       \n"    // pFrac+=8
		"addiu      %4,%4,0x08       \n"    // pEnvelope+=8

		"psraw      $8,$8,7          \n"    // $8 = 32-bit sample * envelope 17.15.0
		"pmulth     $10,$8,%6        \n"    // $10= right  32-bit sample * envelope * volr  .15.14
		"psraw      $9,$9,7          \n"    // $9 = 32-bit sample * envelope 17.15.0
		"pmulth     $11,$9,%6        \n"    // $11= right  32-bit sample * envelope * volr  .15.14

		"pmulth     $8,$8,%5        \n"     // $8 = left   32-bit sample * envelope * voll  .15.14
		"lq         $12,0x00(%2)     \n"    // $12 = outl0
		"pmulth     $9,$9,%5        \n"     // $9 = left   32-bit sample * envelope * voll  .15.14
		"lq         $13,0x10(%2)     \n"    // $13 = outl1
		"lq         $14,0x00(%3)     \n"    // $14 = outr0
		"lq         $15,0x10(%3)     \n"    // $15 = outr1

		"paddsw		$12,$12,$8       \n"
		"paddsw		$13,$13,$9       \n"
		"paddsw		$14,$14,$10      \n"
		"paddsw		$15,$15,$11      \n"

		"sq         $12,0x00(%2)     \n"    // $12 = outl0
		"sq         $13,0x10(%2)     \n"    // $13 = outl1
		"sq         $14,0x00(%3)     \n"    // $12 = outr0
		"sq         $15,0x10(%3)     \n"    // $12 = outr1

		"psraw      $10,$10,7        \n"    // $10 = 32-bit sample * envelope * volr  17.15.0
		"psraw      $11,$11,7        \n"    // $11 = 32-bit sample * envelope * volr  17.15.0
		"psraw      $8,$8,7          \n"    // $8  = 32-bit sample * envelope * voll  17.15.0
		"psraw      $9,$9,7          \n"    // $9  = 32-bit sample * envelope * voll  17.15.0

		"lq         $12,0x00(%8)     \n"    // $12 = outl
		"lq         $13,0x00(%9)     \n"    // $13 = outr
		"ppach      $8,$9,$8         \n"    // $8 = left   1.15.0
		"ppach      $9,$11,$10       \n"    // $9 = right  1.15.0
		"paddsh     $12,$12,$8       \n"    // $12 = outl + samples
		"paddsh     $13,$13,$9       \n"    // $13 = outr + samples
		"sq         $12,0x00(%8)     \n"    // store outl
		"sq         $13,0x00(%9)     \n"    // store outr
		"addiu      %8,%8,0x10       \n"
		"addiu      %9,%9,0x10       \n"

		"addiu      %7,%7,-8         \n"
		"addiu      %2,%2,0x20       \n"

		"bgtz       %7,_MixChannelEchoPS2_Loop \n"
		"addiu      %3,%3,0x20       \n"

		".set reorder \n"

		: 
	: "r" (pIn), "r" (pFrac), "r" (pOutLeft), "r" (pOutRight), "r" (pEnvelope), "r" (iVolLeft), "r" (iVolRight), "r" (nSamples), "r" (pEchoLeft), "r" (pEchoRight)
		: "$8", "$9", "$10", "$11", "$12", "$13", "$14", "$15"
		);    
}




#else

void _MixChannel(Int32 *pOutLeft, Int32 *pOutRight, Int16 *pIn, Uint8 *pEnvelope, Uint16 *pFrac, Int32 nSamples, Int32 iVolLeft, Int32 iVolRight)
{
	while (nSamples > 0)
	{
		Int32 iSample1;
		Int32 iFrac0, iFrac1;
		Int32 iSample, iSampleLeft, iSampleRight;
		Int32 iEnvelope;

		iSample  = pIn[0];
		iSample1 = pIn[1];
		
		iFrac0   = pFrac[0] >> 1;
		iFrac1   = iFrac0 ^ 0x7FFF;
		
		iSample  =  iSample * iFrac1 + iSample1 * iFrac0;
		iSample >>= 15;

		iEnvelope = *pEnvelope;
		iSample *= iEnvelope;
		iSample >>= 7;

		iSampleLeft  = iSample * iVolLeft;
		iSampleRight = iSample * iVolRight;

		*pOutLeft  += iSampleLeft;
		*pOutRight += iSampleRight;

		pEnvelope++;
		pOutLeft++;
		pOutRight++;
		pIn+=2;
		pFrac++;
		nSamples--;
	}
}


void _MixChannelEcho(Int32 *pOutLeft, Int32 *pOutRight, SNSpcEchoSampleT *pEchoLeft, SNSpcEchoSampleT *pEchoRight, Int16 *pIn, Uint8 *pEnvelope, Uint16 *pFrac, Int32 nSamples, Int32 iVolLeft, Int32 iVolRight)
{
	while (nSamples > 0)
	{
		Int32 iSample1;
		Int32 iFrac0, iFrac1;
		Int32 iSample, iSampleLeft, iSampleRight;
		Int32 iEnvelope;

		iSample  = pIn[0];
		iSample1 = pIn[1];
		
		iFrac0   = pFrac[0] >> 1;
		iFrac1   = iFrac0 ^ 0x7FFF;
		
		iSample  =  iSample * iFrac1 + iSample1 * iFrac0;
		iSample >>= 15;

		iEnvelope = *pEnvelope;
		iSample *= iEnvelope;
		iSample >>= 7;

		iSampleLeft  = iSample * iVolLeft;
		iSampleRight = iSample * iVolRight;

		*pOutLeft  += iSampleLeft;
		*pOutRight += iSampleRight;
		iSampleLeft >>= 7;
		iSampleRight >>= 7;


		iSampleLeft += *pEchoLeft;
		iSampleRight += *pEchoRight;

#if 0
		if (iSampleLeft > 0x7FFF)
		{
			ConDebug("%d\n", iSampleLeft);
			iSampleLeft = 0x7FFF;
		}
		if (iSampleLeft < -0x8000)
		{
			ConDebug("%d\n", iSampleLeft);
			iSampleLeft = -0x8000;
		}
		if (iSampleRight > 0x7FFF)
		{
			ConDebug("%d\n", iSampleRight);
			iSampleRight = 0x7FFF;
		}
		if (iSampleRight < -0x8000)
		{
			ConDebug("%d\n", iSampleRight);
			iSampleRight = -0x8000;
		}
#endif


		*pEchoLeft  = iSampleLeft;
		*pEchoRight = iSampleRight;

		pEchoLeft++;
		pEchoRight++;

		pEnvelope++;
		pOutLeft++;
		pOutRight++;
		pIn+=2;
		pFrac++;
		nSamples--;
	}
}

#endif




static void _SNSpcDspMemset64(Uint64 *pDest, Int32 nDwords)
{
	while (nDwords>=4)
	{
		pDest[0] = 0;
		pDest[1] = 0;
		pDest[2] = 0;
		pDest[3] = 0;
		pDest+=4;
		nDwords-=4;
	}

	while (nDwords > 0)
	{
		pDest[0] = 0;
		pDest+=1;
		nDwords-=1;
	}
}


#if SNSPCDSP_MIXASM

#if 1
void _MixEcho(Int16 *pOut, Int32 *pMain, Int16 *pEcho, Int32 nSamples, Int32 iMainVol, Int32 iEchoVol)
{

	__asm__ __volatile__ (
		"pcpyh       %4,%4           \n"    
		"pcpyld      %4,%4,%4           \n"    
		"pcpyh       %5,%5           \n"    
		"pcpyld      %5,%5,%5           \n"    

		"pnor		 $14, $0,$0			\n"
		"psrlw		 $14,$14,17         \n" // 7FFF
		"pnor		 $15, $0,$0			\n"
		"psllw		 $15,$15,15         \n" // 8000

		".set noreorder \n"
		".align 3           \n"
		"_MixEchoPS2_Loop:         \n"
		"lq          $8,0x00(%1)     \n"    // $8 = 4x main samples
		"lq          $9,0x10(%1)     \n"    // $9 = 4x main samples
		"lq         $10,0x00(%2)     \n"    // $10  = 8x echo samples
		"psraw		 $8,$8,7		 \n"
		"psraw		 $9,$9,7		 \n"
		"pminw       $8,$8,$14       \n"
		"pminw       $9,$9,$14       \n"
		"pmaxw       $8,$8,$15       \n"
		"pmaxw       $9,$9,$15       \n"
		"ppach		 $8,$9,$8         \n" 
		"pmulth		 $0,$8,%4         \n"     // lo = 5 4 1 0
		"pmaddh		 $0,$10,%5        \n"     // hi = 7 6 3 2

		"pmflo		 $8				\n"  // 8 = 5 4 1 0
		"pmfhi		 $9				\n"  // 9 = 7 6 3 2 
		"psraw		 $8,$8,6		 \n"
		"psraw		 $9,$9,6		 \n"
		"pminw       $8,$8,$14       \n"
		"pminw       $9,$9,$14       \n"
		"pmaxw       $8,$8,$15       \n"
		"pmaxw       $9,$9,$15       \n"
		"pcpyld		$10,$9,$8       \n"    // 3 2 1 0
 		"pcpyud		$11,$8,$9       \n"    // 7 6 5 4 
		"ppach		$10,$11,$10        \n" // 76543210
		"sq			$10,0x00(%0)     \n" 
		"addiu      %0,%0,0x10         \n"

		"addiu      %3,%3,-8         \n"
		"addiu      %1,%1,0x20       \n"
		"bgtz       %3,_MixEchoPS2_Loop \n"
		"addiu      %2,%2,0x10       \n"

		".set reorder \n"

		: 
		: "r" (pOut), "r" (pMain), "r" (pEcho), "r" (nSamples), "r" (iMainVol), "r" (iEchoVol)
		: "$8", "$9", "$10", "$11", "$12", "$13", "$14", "$15"
		);    
}
#endif

#else

/*

void _MixEcho(Int16 *pOut, Int32 *pMain, Int16 *pEcho, Int32 nSamples, Int32 iMainVol, Int32 iEchoVol)
{
	Int32 iMin = -0x8000;
	Int32 iMax = 0x7FFF;

	while (nSamples > 0)
	{
		Int32 iSample;

		// mix main + echo
		iSample  = pMain[0];
		iSample >>= 7;
		iSample *= iMainVol;           // (1.15.14)

		iSample += pEcho[0] * iEchoVol;        // (1.15.14)
		iSample >>= 6;
		if (iSample >  iMax) iSample = iMax;
		if (iSample <  iMin) iSample = iMin;
		pOut[0] = iSample;           // (1.15.0)

		pOut++;
		pMain++;
		pEcho++;
		nSamples--;
	}
}
*/

void _MixEcho(Int16 *pOut, Int32 *pMain, SNSpcEchoSampleT *pEcho, Int32 nSamples, Int32 iMainVol, Int32 iEchoVol)
{
	Int32 iMin = -0x8000;
	Int32 iMax = 0x7FFF;

	iEchoVol <<= 7;
	while (nSamples > 0)
	{
		Int32 iSample0, iSample1;

		// mix main + echo
		iSample0  = pMain[0] * iMainVol;           // (1.15.14)
		iSample0 += pEcho[0] * iEchoVol;        // (1.15.14)
		iSample0 >>= 14 - 1;

		iSample1  = pMain[1] * iMainVol;           // (1.15.14)
		iSample1 += pEcho[1] * iEchoVol;        // (1.15.14)
		iSample1 >>= 14 - 1;

		if (iSample0 >  iMax) iSample0 = iMax;
		if (iSample0 <  iMin) iSample0 = iMin;

		if (iSample1 >  iMax) iSample1 = iMax;
		if (iSample1 <  iMin) iSample1 = iMin;

		pOut[0] = iSample0;           // (1.15.0)
		pOut[1] = iSample1;           // (1.15.0)

		pOut+=2;
		pMain+=2;
		pEcho+=2;
		nSamples-=2;
	}
}
#endif


/*
 
            FLG(ECEN) ESA EDL    C0-C7           |
                 \/  \/  \/      \/     EVOL(L) |
                 *--------*   *------*    \/    |   *--------*
>-------------X->|External|-->|FIR   |-----X--->+-->|Parallel|---> Left D/O
 L-CH ECHO   /\  |Memory  |   |Filter| \/           |Serial  |
              |  *--------*   *------*  |           *--------*
              |                         |
              --------------X------------
                           /\
                           EFB

 */

static Int32 _FilterEchoStereo(SNSpcEchoSampleT *pEchoLeft, SNSpcEchoSampleT *pEchoRight, Int32 nSamples, Int32 iEchoFeedback, Int16 *pEchoBuf, Uint32 uEchoAddr, Uint32 uEchoSize, const Int16 *pCoeff, SNSpcFIRFilterT *pFilter)
{
	Int32 iFilterPos;
	iFilterPos = pFilter[0].iPos;

	while (nSamples > 0)
	{
		Int32 iSampleL, iSampleR;
		Int32 iEchoSampleL, iEchoSampleR;
		Int16 *pFilterLineL, *pFilterLineR;

		iSampleL  = pEchoLeft[0];
		iSampleR  = pEchoRight[0];

		// fetch sample from echo buffer
		iEchoSampleL = pEchoBuf[uEchoAddr+0];             // (1.15.0)
		iEchoSampleR = pEchoBuf[uEchoAddr+1];             // (1.15.0)

		// get pointer to start of filter line
		pFilterLineL = &pFilter[0].Line[iFilterPos&7];
		pFilterLineR = &pFilter[1].Line[iFilterPos&7];
		iFilterPos--;

		// write sample twice for doubled line
		pFilterLineL[0] = iEchoSampleL;
		pFilterLineL[8] = iEchoSampleL;
		pFilterLineR[0] = iEchoSampleR;
		pFilterLineR[8] = iEchoSampleR;

		// calculate FIR filter
		iEchoSampleL = pFilterLineL[0] * pCoeff[0];
		iEchoSampleR = pFilterLineR[0] * pCoeff[0];
		iEchoSampleL+= pFilterLineL[1] * pCoeff[1];
		iEchoSampleR+= pFilterLineR[1] * pCoeff[1];
		iEchoSampleL+= pFilterLineL[2] * pCoeff[2];
		iEchoSampleR+= pFilterLineR[2] * pCoeff[2];
		iEchoSampleL+= pFilterLineL[3] * pCoeff[3];
		iEchoSampleR+= pFilterLineR[3] * pCoeff[3];
		iEchoSampleL+= pFilterLineL[4] * pCoeff[4];
		iEchoSampleR+= pFilterLineR[4] * pCoeff[4];
		iEchoSampleL+= pFilterLineL[5] * pCoeff[5];
		iEchoSampleR+= pFilterLineR[5] * pCoeff[5];
		iEchoSampleL+= pFilterLineL[6] * pCoeff[6];
		iEchoSampleR+= pFilterLineR[6] * pCoeff[6];
		iEchoSampleL+= pFilterLineL[7] * pCoeff[7];
		iEchoSampleR+= pFilterLineR[7] * pCoeff[7];
		iEchoSampleL >>= 7;
		iEchoSampleR >>= 7;

		// store sample (post-filter) for use by mixing this frame
		pEchoLeft[0] = iEchoSampleL;
		pEchoRight[0] = iEchoSampleR;

		// apply feedback to echo sample
		iEchoSampleL *= iEchoFeedback;
		iEchoSampleR *= iEchoFeedback;
		iEchoSampleL >>= 7;
		iEchoSampleR >>= 7;

		// add echo (1.15.0)
		iEchoSampleL += iSampleL;
		iEchoSampleR += iSampleR;

		// write sample to echo buffer (1.15.0)
		pEchoBuf[uEchoAddr+0] = iEchoSampleL;
		pEchoBuf[uEchoAddr+1] = iEchoSampleR;

		// wrap echo address
		uEchoAddr+=2;
		if (uEchoAddr >= uEchoSize) uEchoAddr = 0;

		pEchoLeft++;
		pEchoRight++;
		nSamples--;
	}

	pFilter[0].iPos = iFilterPos;
	pFilter[1].iPos = iFilterPos;
	return uEchoAddr;
}


struct SNSpcDspDataT
{
	Int16 iSampleData[SNSPCDSP_BUFFERSIZE*2] _ALIGN(16);
	Uint16 FracData[SNSPCDSP_BUFFERSIZE] _ALIGN(16);
	Uint8 EnvData[SNSPCDSP_BUFFERSIZE] _ALIGN(16);

	SNSpcMixSampleT  Main[2][SNSPCDSP_BUFFERSIZE] _ALIGN(16);
	SNSpcEchoSampleT Echo[2][SNSPCDSP_BUFFERSIZE] _ALIGN(16);
};


#if 0
Int32 _MixTemp(Int32 level, Int16 *pSamples, Int32 nSamples)
{
	while (nSamples > 0)
	{
		pSamples[0] = (level&0x10000) ? 4096 : -4096;

		level += 0x10000 * 220 / 48000;
		pSamples++;
		nSamples--;
	}
	return level;
}
#endif


// filter echo buffer into echo memory

void SNSpcDspMixFull::FilterEcho(Int16 *pLeftEcho, Int16 *pRightEcho, Int32 nSamples, Int32 nSampleRate, Bool bEchoSPCMem)
{
	Int16 *pEchoBuf;
	Uint32 uEchoAddr;
	Uint32 uEchoSize;
	Int16	FilterCoeff[8];

	// use internal echo buffer. Can only use spc memory if sample rate = 32000 (not deterministic!)
	if (bEchoSPCMem && (nSampleRate == SNSPCDSP_SAMPLERATE))
	{
		pEchoBuf  = (Int16*)(m_pDsp->GetMem() + (m_pDsp->GetReg(SNSPCDSP_REG_ESA) * 0x100));
	} else
	{
		pEchoBuf = m_EchoBuffer;
	}

	uEchoAddr = m_Echo.uEchoAddr;

	// calculate echo buffer size based on sample rate
	uEchoSize = (m_pDsp->GetReg(SNSPCDSP_REG_EDL)&0xF) * 512 * 2;
	uEchoSize = uEchoSize * nSampleRate / SNSPCDSP_SAMPLERATE;
	if (uEchoSize > SNSPCDSP_ECHOBUFFER_SIZE) uEchoSize = SNSPCDSP_ECHOBUFFER_SIZE;

	// set filter coefficients
	FilterCoeff[0] = (Int8)m_pDsp->GetReg(SNSPCDSP_REG_ECHOFIR0);
	FilterCoeff[1] = (Int8)m_pDsp->GetReg(SNSPCDSP_REG_ECHOFIR1);
	FilterCoeff[2] = (Int8)m_pDsp->GetReg(SNSPCDSP_REG_ECHOFIR2);
	FilterCoeff[3] = (Int8)m_pDsp->GetReg(SNSPCDSP_REG_ECHOFIR3);
	FilterCoeff[4] = (Int8)m_pDsp->GetReg(SNSPCDSP_REG_ECHOFIR4);
	FilterCoeff[5] = (Int8)m_pDsp->GetReg(SNSPCDSP_REG_ECHOFIR5);
	FilterCoeff[6] = (Int8)m_pDsp->GetReg(SNSPCDSP_REG_ECHOFIR6);
	FilterCoeff[7] = (Int8)m_pDsp->GetReg(SNSPCDSP_REG_ECHOFIR7);

	// fix echo address
	if (uEchoAddr >= uEchoSize)
	{
		if (uEchoSize > 0) uEchoAddr %= uEchoSize;
		else uEchoAddr=0;
	}

	PROF_ENTER("SNSpcDspFilterEchoStereo");
	// filter echo (left)
	m_Echo.uEchoAddr = _FilterEchoStereo(pLeftEcho, pRightEcho, nSamples, 
		(Int8)m_pDsp->GetReg(SNSPCDSP_REG_EFB), pEchoBuf, uEchoAddr, uEchoSize, FilterCoeff, m_Echo.Filter);

	PROF_LEAVE("SNSpcDspFilterEchoStereo");
}


void SNSpcDspMixFull::Mix(CMixBuffer *pMixBuf)
{
	static Int16 OutLeftData[SNSPCDSP_BUFFERSIZE] _ALIGN(16);
	static Int16 OutRightData[SNSPCDSP_BUFFERSIZE] _ALIGN(16);
#if !SNSPCDSP_INFOSCRATCHPAD
	SNSpcDspDataT Data;
#endif
	SNSpcDspDataT *pData;
	Int32 nTotalSamples, nSamples;
	Uint32 nSampleRate, nSampleChannels, nSampleBits;
	Uint32 uCycle=0;
	Uint32 uCyclesPerSample;
	Int32 nSamplesPerUpdate;

#if SNSPCDSP_INFOSCRATCHPAD
	pData = (SNSpcDspDataT *)PS2MEM_SCRATCHPAD;
#else
	pData = (SNSpcDspDataT *)&Data;
#endif

#if CODE_PLATFORM == CODE_PS2
	if (sizeof(SNSpcDspDataT) > 16384)
	{
		printf("%d\n",sizeof(SNSpcDspDataT));
		return;
	}
#endif

	if (!pMixBuf)
	{
		return;
	}

	pMixBuf->GetFormat(&nSampleRate, &nSampleBits, &nSampleChannels);
	if (nSampleBits!=16) return;

	// get number of samples needed to mix
	nTotalSamples = pMixBuf->GetOutputSamples();

	// build envelope lookup tables based on sample rate
	if (nSampleRate!=m_nSampleRate)
	{
		BuildLookupTables(nSampleRate);
		m_nSampleRate = nSampleRate;
	}

	// calculate number of cycles per sample
	uCyclesPerSample  = 32 * SNSPC_CYCLE;
	nSamplesPerUpdate = SNSPCDSP_MAXSAMPLES;

	// mix in chunks of <SNSPCDSP_MAXSAMPLES size for cache coherency
	while (nTotalSamples > 0)
	{
		Int32 iChannel;
		Uint8 uEchoEnable;

		// dequeue write queue up to current cycle time
		m_pDsp->Sync(uCycle);

		// get echo enable bits
		uEchoEnable = m_pDsp->GetReg(SNSPCDSP_REG_EON);
		if (m_pDsp->GetReg(SNSPCDSP_REG_FLG)&0x20) uEchoEnable=0;

		// dont update more than samples-per-update at a time
		nSamples = nTotalSamples;
		if (nSamples > nSamplesPerUpdate) nSamples = nSamplesPerUpdate;

		// clear main and echo buffers
		_SNSpcDspMemset64((Uint64 *)pData->Main[0], (sizeof(Int32) * nSamples+7) / 8);
		_SNSpcDspMemset64((Uint64 *)pData->Main[1], (sizeof(Int32) * nSamples+7) / 8);
		_SNSpcDspMemset64((Uint64 *)pData->Echo[0], (sizeof(SNSpcEchoSampleT) * nSamples+7) / 8);
		_SNSpcDspMemset64((Uint64 *)pData->Echo[1], (sizeof(SNSpcEchoSampleT) * nSamples+7) / 8);

		// output niose
		if (m_pDsp->GetReg(SNSPCDSP_REG_NOV))
		{
			PROF_ENTER("SNSpcDspOutputNoise");
			OutputNoise(m_iNoiseSample, m_iNoiseFrac, nSamples, nSampleRate);
			PROF_LEAVE("SNSpcDspOutputNoise");
		}

		// check mute
		if (!(m_pDsp->GetReg(SNSPCDSP_REG_FLG) & 0x40)) 
		{
			for (iChannel=0; iChannel < SNSPCDSP_CHANNEL_NUM; iChannel++)
			{
				#if CODE_DEBUG
				if (_ChMask & (1<<iChannel))
				#endif
				
				// calculate envelope values for channel
				if (OutputEnvelope(iChannel, pData->EnvData, nSamples))
				{
					Bool bMix;
					Int16 *pSampleData;
					Uint16 *pFracData;

					pSampleData = pData->iSampleData;
					pFracData   = pData->FracData;

					if (m_pDsp->GetReg(SNSPCDSP_REG_PMON) & (1<<iChannel))
					{
						// output sample data (pitch modulation!)
						bMix = OutputSample(iChannel, pSampleData, pFracData, nSamples, nSampleRate);
						#if CODE_DEBUG
						//ConDebug("PitchModulation %d\n", iChannel);
						#endif
					} else
					{
						// output sample data
						bMix = OutputSample(iChannel, pSampleData, pFracData, nSamples, nSampleRate);
					}

					if (bMix)
					{
						const SNSpcVoiceRegsT *pRegs = m_pDsp->GetVoiceRegs(iChannel);

						// is noise enabled for this channel?
						if (m_pDsp->GetReg(SNSPCDSP_REG_NOV) & (1<<iChannel))
						{
							// use pre-generated noise channel data instead of pcm data
							pSampleData = m_iNoiseSample;
							pFracData   = m_iNoiseFrac;
						}

						//
						// mix channel into main and echo buffers
						//

						PROF_ENTER("SNSpcDspMixStereo");
						if ( uEchoEnable & (1<<iChannel) )
						{
							// Echo is enabled, so mix channel into both the main and the echo buffers
							// mix using channel volume
							_MixChannelEcho(
								pData->Main[0], pData->Main[1], 
								pData->Echo[0], pData->Echo[1], 
								pSampleData, pData->EnvData, pFracData, nSamples, 
								pRegs->vol_l, pRegs->vol_r
								);
						} else
						{
							// Echo is not enabled, so mix channel into the main channel only
							// mix using channel volume
							_MixChannel(
								pData->Main[0], pData->Main[1], 
								pSampleData, pData->EnvData, pFracData, nSamples, 
								pRegs->vol_l, pRegs->vol_r
								);
						}

						PROF_LEAVE("SNSpcDspMixStereo");
					}
				}
			}

			if (!(m_pDsp->GetReg(SNSPCDSP_REG_FLG) & 0x20))
			{
				// filter echo output to echo buffer
				FilterEcho(pData->Echo[0], pData->Echo[1], nSamples, nSampleRate, FALSE);
			}
		}

		// mix main + echo to output buffer
		PROF_ENTER("SNSpcDspMixEcho");
		_MixEcho(OutLeftData, pData->Main[0], pData->Echo[0], nSamples, 
			(Int8)m_pDsp->GetReg(SNSPCDSP_REG_MVOLL), (Int8)m_pDsp->GetReg(SNSPCDSP_REG_EVOLL));
		_MixEcho(OutRightData, pData->Main[1], pData->Echo[1], nSamples, 
			(Int8)m_pDsp->GetReg(SNSPCDSP_REG_MVOLR), (Int8)m_pDsp->GetReg(SNSPCDSP_REG_EVOLR));
		PROF_LEAVE("SNSpcDspMixEcho");

		// output buffer to sound hardware
		if (nSampleChannels == 2)
			pMixBuf->OutputSamplesStereo(OutLeftData, OutRightData, nSamples);
		else
			pMixBuf->OutputSamplesMono(OutLeftData, nSamples);

		// decrement total sample count
		nTotalSamples -= nSamples;

		// increment cycle count
		uCycle += nSamples * uCyclesPerSample;
	}

	// flush sample data to output
	pMixBuf->Flush();
}




//
// silent (deterministic) mixer
//


void SNSpcDspMixSilent::FetchBlock(Int32 iChannel)
{
	SNSpcChannelT *pChannel = GetChannel(iChannel);

	// decode next block
	if (pChannel->uBlockAddr!=0) 
	{
		Uint8 uFlags = 0;

		uFlags = m_pDsp->GetMem()[pChannel->uBlockAddr];
		pChannel->uBlockAddr += 9;

		// end of sample reached?
		if (uFlags&1)
		{
			const SNSpcVoiceRegsT *pRegs = m_pDsp->GetVoiceRegs(iChannel);

			// set ENDX
			pChannel->endx = TRUE;
			if (uFlags & 2 )
			{
				// do looping here?
				pChannel->uBlockAddr = m_pDsp->GetSampleDir(pRegs->srcn, 2);
			} else
			{
				pChannel->uBlockAddr = 0;
			}
		}

	}  
}





Int32 SNSpcDspMixSilent::OutputSample(Int32 iChannel, Int32 nSamples, Int32 nSampleRate)
{
	SNSpcChannelT *pChannel = GetChannel(iChannel);
	const SNSpcVoiceRegsT *pRegs = m_pDsp->GetVoiceRegs(iChannel);
	Int32 iPhase;
	Int32 iPhaseInc;
	Uint32 uPitch;

	if (pChannel->uBlockAddr == 0)
	{
		pChannel->uOldBlockAddr = pChannel->uBlockAddr;
		// silent sample data
		return 0;
	}

	PROF_ENTER("SNSpcDspOutputSampleSilent");

	// get pitch
	uPitch = pRegs->pitch_lo | (pRegs->pitch_hi<<8);
	uPitch&= 0x3FFF;

	iPhase = pChannel->iPhase;
	
	// output at correct pitch based on sample rate
	iPhaseInc = uPitch * SNSPCDSP_SAMPLERATE / nSampleRate; 
	iPhaseInc <<= 4;

	while (nSamples > 0)
	{
		if (iPhase >= (14 << 16))
		{
			// fetch next block
			FetchBlock(iChannel);
			iPhase -= (16<<16);
		}

		// next sample
		iPhase+= iPhaseInc;

		nSamples--;
	}

	// voice ended?
	if (pChannel->uBlockAddr == 0)
	{
		pChannel->eEnvState = SNSPCDSP_ENVSTATE_SILENCE;
		pChannel->endx = TRUE;      // this is what we came here for
	}

	// set outx to be envx for now
	pChannel->outx = pChannel->envx;

	pChannel->uOldBlockAddr = pChannel->uBlockAddr;
	pChannel->iPhase = iPhase;
	PROF_LEAVE("SNSpcDspOutputSampleSilent");
	return 1;
}




void SNSpcDspMixSilent::Mix(CMixBuffer *pMixBuf)
{
	Int32 nTotalSamples;
	Uint32 nSampleRate, nSampleChannels, nSampleBits;
	Uint8 Envelope[SNSPCDSP_SAMPLERATE / 60];
	Int32 iChannel;

	nSampleRate = SNSPCDSP_SAMPLERATE;
	nSampleBits = 16;
	nSampleChannels = 0;
	nTotalSamples = SNSPCDSP_SAMPLERATE / 60;

	// build envelope lookup tables based on sample rate
	if (nSampleRate!=m_nSampleRate)
	{
		BuildLookupTables(nSampleRate);
		m_nSampleRate = nSampleRate;
	}

	if (!(m_pDsp->GetReg(SNSPCDSP_REG_FLG) & 0x40)) // check mute
	{
		for (iChannel=0; iChannel < SNSPCDSP_CHANNEL_NUM; iChannel++)
		{
			// calculate envelope values for channel
			if (OutputEnvelope(iChannel, Envelope, nTotalSamples))
			{
					// output sample data
				OutputSample(iChannel, nTotalSamples, nSampleRate);
			}
		}
	}
}


