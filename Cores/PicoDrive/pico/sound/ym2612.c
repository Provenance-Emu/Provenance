/*
** This is a bunch of remains of original fm.c from MAME project. All stuff
** unrelated to ym2612 was removed, multiple chip support was removed,
** some parts of code were slightly rewritten and tied to the emulator.
**
** SSG-EG was also removed, because it's rarely used, Sega2.doc even does not
** document it ("proprietary") and tells to write 0 to SSG-EG control register.
*/

/*
**
** File: fm.c -- software implementation of Yamaha FM sound generator
**
** Copyright (C) 2001, 2002, 2003 Jarek Burczynski (bujar at mame dot net)
** Copyright (C) 1998 Tatsuyuki Satoh , MultiArcadeMachineEmulator development
**
** Version 1.4 (final beta)
**
*/

/*
** History:
**
** 03-08-2003 Jarek Burczynski:
**  - fixed YM2608 initial values (after the reset)
**  - fixed flag and irqmask handling (YM2608)
**  - fixed BUFRDY flag handling (YM2608)
**
** 14-06-2003 Jarek Burczynski:
**  - implemented all of the YM2608 status register flags
**  - implemented support for external memory read/write via YM2608
**  - implemented support for deltat memory limit register in YM2608 emulation
**
** 22-05-2003 Jarek Burczynski:
**  - fixed LFO PM calculations (copy&paste bugfix)
**
** 08-05-2003 Jarek Burczynski:
**  - fixed SSG support
**
** 22-04-2003 Jarek Burczynski:
**  - implemented 100% correct LFO generator (verified on real YM2610 and YM2608)
**
** 15-04-2003 Jarek Burczynski:
**  - added support for YM2608's register 0x110 - status mask
**
** 01-12-2002 Jarek Burczynski:
**  - fixed register addressing in YM2608, YM2610, YM2610B chips. (verified on real YM2608)
**    The addressing patch used for early Neo-Geo games can be removed now.
**
** 26-11-2002 Jarek Burczynski, Nicola Salmoria:
**  - recreated YM2608 ADPCM ROM using data from real YM2608's output which leads to:
**  - added emulation of YM2608 drums.
**  - output of YM2608 is two times lower now - same as YM2610 (verified on real YM2608)
**
** 16-08-2002 Jarek Burczynski:
**  - binary exact Envelope Generator (verified on real YM2203);
**    identical to YM2151
**  - corrected 'off by one' error in feedback calculations (when feedback is off)
**  - corrected connection (algorithm) calculation (verified on real YM2203 and YM2610)
**
** 18-12-2001 Jarek Burczynski:
**  - added SSG-EG support (verified on real YM2203)
**
** 12-08-2001 Jarek Burczynski:
**  - corrected ym_sin_tab and ym_tl_tab data (verified on real chip)
**  - corrected feedback calculations (verified on real chip)
**  - corrected phase generator calculations (verified on real chip)
**  - corrected envelope generator calculations (verified on real chip)
**  - corrected FM volume level (YM2610 and YM2610B).
**  - changed YMxxxUpdateOne() functions (YM2203, YM2608, YM2610, YM2610B, YM2612) :
**    this was needed to calculate YM2610 FM channels output correctly.
**    (Each FM channel is calculated as in other chips, but the output of the channel
**    gets shifted right by one *before* sending to accumulator. That was impossible to do
**    with previous implementation).
**
** 23-07-2001 Jarek Burczynski, Nicola Salmoria:
**  - corrected YM2610 ADPCM type A algorithm and tables (verified on real chip)
**
** 11-06-2001 Jarek Burczynski:
**  - corrected end of sample bug in ADPCMA_calc_cha().
**    Real YM2610 checks for equality between current and end addresses (only 20 LSB bits).
**
** 08-12-98 hiro-shi:
** rename ADPCMA -> ADPCMB, ADPCMB -> ADPCMA
** move ROM limit check.(CALC_CH? -> 2610Write1/2)
** test program (ADPCMB_TEST)
** move ADPCM A/B end check.
** ADPCMB repeat flag(no check)
** change ADPCM volume rate (8->16) (32->48).
**
** 09-12-98 hiro-shi:
** change ADPCM volume. (8->16, 48->64)
** replace ym2610 ch0/3 (YM-2610B)
** change ADPCM_SHIFT (10->8) missing bank change 0x4000-0xffff.
** add ADPCM_SHIFT_MASK
** change ADPCMA_DECODE_MIN/MAX.
*/




/************************************************************************/
/*    comment of hiro-shi(Hiromitsu Shioya)                             */
/*    YM2610(B) = OPN-B                                                 */
/*    YM2610  : PSG:3ch FM:4ch ADPCM(18.5KHz):6ch DeltaT ADPCM:1ch      */
/*    YM2610B : PSG:3ch FM:6ch ADPCM(18.5KHz):6ch DeltaT ADPCM:1ch      */
/************************************************************************/

//#include <stdio.h>

#include <string.h>
#include <math.h>

#include "ym2612.h"

#ifndef EXTERNAL_YM2612
#include <stdlib.h>
// let it be 1 global to simplify things
YM2612 ym2612;

#else
extern YM2612 *ym2612_940;
#define ym2612 (*ym2612_940)

#endif

void memset32(int *dest, int c, int count);


#ifndef __GNUC__
#pragma warning (disable:4100) // unreferenced formal parameter
#pragma warning (disable:4244)
#pragma warning (disable:4245) // signed/unsigned in conversion
#pragma warning (disable:4710)
#pragma warning (disable:4018) // signed/unsigned
#endif

// Joe M - I changed this because it causes linking errors in XCode / iOS
//#ifndef INLINE
#define INLINE static __inline
//#endif

#ifndef M_PI
#define M_PI    3.14159265358979323846
#endif


/* globals */

#define FREQ_SH			16  /* 16.16 fixed point (frequency calculations) */
#define EG_SH			16  /* 16.16 fixed point (envelope generator timing) */
#define LFO_SH			25  /*  7.25 fixed point (LFO calculations)       */
#define TIMER_SH		16  /* 16.16 fixed point (timers calculations)    */

#define ENV_BITS		10
#define ENV_LEN			(1<<ENV_BITS)
#define ENV_STEP		(128.0/ENV_LEN)

#define MAX_ATT_INDEX	(ENV_LEN-1) /* 1023 */
#define MIN_ATT_INDEX	(0)			/* 0 */

#define EG_ATT			4
#define EG_DEC			3
#define EG_SUS			2
#define EG_REL			1
#define EG_OFF			0

#define SIN_BITS		10
#define SIN_LEN			(1<<SIN_BITS)
#define SIN_MASK		(SIN_LEN-1)

#define TL_RES_LEN		(256) /* 8 bits addressing (real chip) */

#define EG_TIMER_OVERFLOW (3*(1<<EG_SH)) /* envelope generator timer overflows every 3 samples (on real chip) */

#define MAXOUT		(+32767)
#define MINOUT		(-32768)

/* limitter */
#define Limit(val, max,min) { \
	if ( val > max )      val = max; \
	else if ( val < min ) val = min; \
}


/*  TL_TAB_LEN is calculated as:
*   13 - sinus amplitude bits     (Y axis)
*   2  - sinus sign bit           (Y axis)
*   TL_RES_LEN - sinus resolution (X axis)
*/
//#define TL_TAB_LEN (13*2*TL_RES_LEN)
#define TL_TAB_LEN (13*TL_RES_LEN*256/8) // 106496*2
UINT16 ym_tl_tab[TL_TAB_LEN];

/* ~3K wasted but oh well */
UINT16 ym_tl_tab2[13*TL_RES_LEN];

#define ENV_QUIET		(2*13*TL_RES_LEN/8)

/* sin waveform table in 'decibel' scale (use only period/4 values) */
static UINT16 ym_sin_tab[256];

/* sustain level table (3dB per step) */
/* bit0, bit1, bit2, bit3, bit4, bit5, bit6 */
/* 1,    2,    4,    8,    16,   32,   64   (value)*/
/* 0.75, 1.5,  3,    6,    12,   24,   48   (dB)*/

/* 0 - 15: 0, 3, 6, 9,12,15,18,21,24,27,30,33,36,39,42,93 (dB)*/
#define SC(db) (UINT32) ( db * (4.0/ENV_STEP) )
static const UINT32 sl_table[16]={
 SC( 0),SC( 1),SC( 2),SC(3 ),SC(4 ),SC(5 ),SC(6 ),SC( 7),
 SC( 8),SC( 9),SC(10),SC(11),SC(12),SC(13),SC(14),SC(31)
};
#undef SC


#if 0
#define RATE_STEPS (8)
static const UINT8 eg_inc[19*RATE_STEPS]={

/*cycle:0 1  2 3  4 5  6 7*/

/* 0 */ 0,1, 0,1, 0,1, 0,1, /* rates 00..11 0 (increment by 0 or 1) */
/* 1 */ 0,1, 0,1, 1,1, 0,1, /* rates 00..11 1 */
/* 2 */ 0,1, 1,1, 0,1, 1,1, /* rates 00..11 2 */
/* 3 */ 0,1, 1,1, 1,1, 1,1, /* rates 00..11 3 */

/* 4 */ 1,1, 1,1, 1,1, 1,1, /* rate 12 0 (increment by 1) */
/* 5 */ 1,1, 1,2, 1,1, 1,2, /* rate 12 1 */
/* 6 */ 1,2, 1,2, 1,2, 1,2, /* rate 12 2 */
/* 7 */ 1,2, 2,2, 1,2, 2,2, /* rate 12 3 */

/* 8 */ 2,2, 2,2, 2,2, 2,2, /* rate 13 0 (increment by 2) */
/* 9 */ 2,2, 2,4, 2,2, 2,4, /* rate 13 1 */
/*10 */ 2,4, 2,4, 2,4, 2,4, /* rate 13 2 */
/*11 */ 2,4, 4,4, 2,4, 4,4, /* rate 13 3 */

/*12 */ 4,4, 4,4, 4,4, 4,4, /* rate 14 0 (increment by 4) */
/*13 */ 4,4, 4,8, 4,4, 4,8, /* rate 14 1 */
/*14 */ 4,8, 4,8, 4,8, 4,8, /* rate 14 2 */
/*15 */ 4,8, 8,8, 4,8, 8,8, /* rate 14 3 */

/*16 */ 8,8, 8,8, 8,8, 8,8, /* rates 15 0, 15 1, 15 2, 15 3 (increment by 8) */
/*17 */ 16,16,16,16,16,16,16,16, /* rates 15 2, 15 3 for attack */
/*18 */ 0,0, 0,0, 0,0, 0,0, /* infinity rates for attack and decay(s) */
};
#endif


#define PACK(a0,a1,a2,a3,a4,a5,a6,a7) ((a7<<21)|(a6<<18)|(a5<<15)|(a4<<12)|(a3<<9)|(a2<<6)|(a1<<3)|(a0<<0))
static const UINT32 eg_inc_pack[19] =
{
/* 0 */ PACK(0,1,0,1,0,1,0,1), /* rates 00..11 0 (increment by 0 or 1) */
/* 1 */ PACK(0,1,0,1,1,1,0,1), /* rates 00..11 1 */
/* 2 */ PACK(0,1,1,1,0,1,1,1), /* rates 00..11 2 */
/* 3 */ PACK(0,1,1,1,1,1,1,1), /* rates 00..11 3 */

/* 4 */ PACK(1,1,1,1,1,1,1,1), /* rate 12 0 (increment by 1) */
/* 5 */ PACK(1,1,1,2,1,1,1,2), /* rate 12 1 */
/* 6 */ PACK(1,2,1,2,1,2,1,2), /* rate 12 2 */
/* 7 */ PACK(1,2,2,2,1,2,2,2), /* rate 12 3 */

/* 8 */ PACK(2,2,2,2,2,2,2,2), /* rate 13 0 (increment by 2) */
/* 9 */ PACK(2,2,2,3,2,2,2,3), /* rate 13 1 */
/*10 */ PACK(2,3,2,3,2,3,2,3), /* rate 13 2 */
/*11 */ PACK(2,3,3,3,2,3,3,3), /* rate 13 3 */

/*12 */ PACK(3,3,3,3,3,3,3,3), /* rate 14 0 (increment by 4) */
/*13 */ PACK(3,3,3,4,3,3,3,4), /* rate 14 1 */
/*14 */ PACK(3,4,3,4,3,4,3,4), /* rate 14 2 */
/*15 */ PACK(3,4,4,4,3,4,4,4), /* rate 14 3 */

/*16 */ PACK(4,4,4,4,4,4,4,4), /* rates 15 0, 15 1, 15 2, 15 3 (increment by 8) */
/*17 */ PACK(5,5,5,5,5,5,5,5), /* rates 15 2, 15 3 for attack */
/*18 */ PACK(0,0,0,0,0,0,0,0), /* infinity rates for attack and decay(s) */
};


//#define O(a) (a*RATE_STEPS)
#define O(a) a

/*note that there is no O(17) in this table - it's directly in the code */
static const UINT8 eg_rate_select[32+64+32]={	/* Envelope Generator rates (32 + 64 rates + 32 RKS) */
/* 32 infinite time rates */
O(18),O(18),O(18),O(18),O(18),O(18),O(18),O(18),
O(18),O(18),O(18),O(18),O(18),O(18),O(18),O(18),
O(18),O(18),O(18),O(18),O(18),O(18),O(18),O(18),
O(18),O(18),O(18),O(18),O(18),O(18),O(18),O(18),

/* rates 00-11 */
O( 0),O( 1),O( 2),O( 3),
O( 0),O( 1),O( 2),O( 3),
O( 0),O( 1),O( 2),O( 3),
O( 0),O( 1),O( 2),O( 3),
O( 0),O( 1),O( 2),O( 3),
O( 0),O( 1),O( 2),O( 3),
O( 0),O( 1),O( 2),O( 3),
O( 0),O( 1),O( 2),O( 3),
O( 0),O( 1),O( 2),O( 3),
O( 0),O( 1),O( 2),O( 3),
O( 0),O( 1),O( 2),O( 3),
O( 0),O( 1),O( 2),O( 3),

/* rate 12 */
O( 4),O( 5),O( 6),O( 7),

/* rate 13 */
O( 8),O( 9),O(10),O(11),

/* rate 14 */
O(12),O(13),O(14),O(15),

/* rate 15 */
O(16),O(16),O(16),O(16),

/* 32 dummy rates (same as 15 3) */
O(16),O(16),O(16),O(16),O(16),O(16),O(16),O(16),
O(16),O(16),O(16),O(16),O(16),O(16),O(16),O(16),
O(16),O(16),O(16),O(16),O(16),O(16),O(16),O(16),
O(16),O(16),O(16),O(16),O(16),O(16),O(16),O(16)

};
#undef O

/*rate  0,    1,    2,   3,   4,   5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15*/
/*shift 11,   10,   9,   8,   7,   6,  5,  4,  3,  2, 1,  0,  0,  0,  0,  0 */
/*mask  2047, 1023, 511, 255, 127, 63, 31, 15, 7,  3, 1,  0,  0,  0,  0,  0 */

#define O(a) (a*1)
static const UINT8 eg_rate_shift[32+64+32]={	/* Envelope Generator counter shifts (32 + 64 rates + 32 RKS) */
/* 32 infinite time rates */
O(0),O(0),O(0),O(0),O(0),O(0),O(0),O(0),
O(0),O(0),O(0),O(0),O(0),O(0),O(0),O(0),
O(0),O(0),O(0),O(0),O(0),O(0),O(0),O(0),
O(0),O(0),O(0),O(0),O(0),O(0),O(0),O(0),

/* rates 00-11 */
O(11),O(11),O(11),O(11),
O(10),O(10),O(10),O(10),
O( 9),O( 9),O( 9),O( 9),
O( 8),O( 8),O( 8),O( 8),
O( 7),O( 7),O( 7),O( 7),
O( 6),O( 6),O( 6),O( 6),
O( 5),O( 5),O( 5),O( 5),
O( 4),O( 4),O( 4),O( 4),
O( 3),O( 3),O( 3),O( 3),
O( 2),O( 2),O( 2),O( 2),
O( 1),O( 1),O( 1),O( 1),
O( 0),O( 0),O( 0),O( 0),

/* rate 12 */
O( 0),O( 0),O( 0),O( 0),

/* rate 13 */
O( 0),O( 0),O( 0),O( 0),

/* rate 14 */
O( 0),O( 0),O( 0),O( 0),

/* rate 15 */
O( 0),O( 0),O( 0),O( 0),

/* 32 dummy rates (same as 15 3) */
O( 0),O( 0),O( 0),O( 0),O( 0),O( 0),O( 0),O( 0),
O( 0),O( 0),O( 0),O( 0),O( 0),O( 0),O( 0),O( 0),
O( 0),O( 0),O( 0),O( 0),O( 0),O( 0),O( 0),O( 0),
O( 0),O( 0),O( 0),O( 0),O( 0),O( 0),O( 0),O( 0)

};
#undef O

static const UINT8 dt_tab[4 * 32]={
/* this is YM2151 and YM2612 phase increment data (in 10.10 fixed point format)*/
/* FD=0 */
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
/* FD=1 */
	0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2,
	2, 3, 3, 3, 4, 4, 4, 5, 5, 6, 6, 7, 8, 8, 8, 8,
/* FD=2 */
	1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5,
	5, 6, 6, 7, 8, 8, 9,10,11,12,13,14,16,16,16,16,
/* FD=3 */
	2, 2, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 6, 6, 7,
	8 ,8, 9,10,11,12,13,14,16,17,19,20,22,22,22,22
};


/* OPN key frequency number -> key code follow table */
/* fnum higher 4bit -> keycode lower 2bit */
static const UINT8 opn_fktable[16] = {0,0,0,0,0,0,0,1,2,3,3,3,3,3,3,3};


/* 8 LFO speed parameters */
/* each value represents number of samples that one LFO level will last for */
static const UINT32 lfo_samples_per_step[8] = {108, 77, 71, 67, 62, 44, 8, 5};



/*There are 4 different LFO AM depths available, they are:
  0 dB, 1.4 dB, 5.9 dB, 11.8 dB
  Here is how it is generated (in EG steps):

  11.8 dB = 0, 2, 4, 6, 8, 10,12,14,16...126,126,124,122,120,118,....4,2,0
   5.9 dB = 0, 1, 2, 3, 4, 5, 6, 7, 8....63, 63, 62, 61, 60, 59,.....2,1,0
   1.4 dB = 0, 0, 0, 0, 1, 1, 1, 1, 2,...15, 15, 15, 15, 14, 14,.....0,0,0

  (1.4 dB is loosing precision as you can see)

  It's implemented as generator from 0..126 with step 2 then a shift
  right N times, where N is:
    8 for 0 dB
    3 for 1.4 dB
    1 for 5.9 dB
    0 for 11.8 dB
*/
static const UINT8 lfo_ams_depth_shift[4] = {8, 3, 1, 0};



/*There are 8 different LFO PM depths available, they are:
  0, 3.4, 6.7, 10, 14, 20, 40, 80 (cents)

  Modulation level at each depth depends on F-NUMBER bits: 4,5,6,7,8,9,10
  (bits 8,9,10 = FNUM MSB from OCT/FNUM register)

  Here we store only first quarter (positive one) of full waveform.
  Full table (lfo_pm_table) containing all 128 waveforms is build
  at run (init) time.

  One value in table below represents 4 (four) basic LFO steps
  (1 PM step = 4 AM steps).

  For example:
   at LFO SPEED=0 (which is 108 samples per basic LFO step)
   one value from "lfo_pm_output" table lasts for 432 consecutive
   samples (4*108=432) and one full LFO waveform cycle lasts for 13824
   samples (32*432=13824; 32 because we store only a quarter of whole
            waveform in the table below)
*/
static const UINT8 lfo_pm_output[7*8][8]={ /* 7 bits meaningful (of F-NUMBER), 8 LFO output levels per one depth (out of 32), 8 LFO depths */
/* FNUM BIT 4: 000 0001xxxx */
/* DEPTH 0 */ {0,   0,   0,   0,   0,   0,   0,   0},
/* DEPTH 1 */ {0,   0,   0,   0,   0,   0,   0,   0},
/* DEPTH 2 */ {0,   0,   0,   0,   0,   0,   0,   0},
/* DEPTH 3 */ {0,   0,   0,   0,   0,   0,   0,   0},
/* DEPTH 4 */ {0,   0,   0,   0,   0,   0,   0,   0},
/* DEPTH 5 */ {0,   0,   0,   0,   0,   0,   0,   0},
/* DEPTH 6 */ {0,   0,   0,   0,   0,   0,   0,   0},
/* DEPTH 7 */ {0,   0,   0,   0,   1,   1,   1,   1},

/* FNUM BIT 5: 000 0010xxxx */
/* DEPTH 0 */ {0,   0,   0,   0,   0,   0,   0,   0},
/* DEPTH 1 */ {0,   0,   0,   0,   0,   0,   0,   0},
/* DEPTH 2 */ {0,   0,   0,   0,   0,   0,   0,   0},
/* DEPTH 3 */ {0,   0,   0,   0,   0,   0,   0,   0},
/* DEPTH 4 */ {0,   0,   0,   0,   0,   0,   0,   0},
/* DEPTH 5 */ {0,   0,   0,   0,   0,   0,   0,   0},
/* DEPTH 6 */ {0,   0,   0,   0,   1,   1,   1,   1},
/* DEPTH 7 */ {0,   0,   1,   1,   2,   2,   2,   3},

/* FNUM BIT 6: 000 0100xxxx */
/* DEPTH 0 */ {0,   0,   0,   0,   0,   0,   0,   0},
/* DEPTH 1 */ {0,   0,   0,   0,   0,   0,   0,   0},
/* DEPTH 2 */ {0,   0,   0,   0,   0,   0,   0,   0},
/* DEPTH 3 */ {0,   0,   0,   0,   0,   0,   0,   0},
/* DEPTH 4 */ {0,   0,   0,   0,   0,   0,   0,   1},
/* DEPTH 5 */ {0,   0,   0,   0,   1,   1,   1,   1},
/* DEPTH 6 */ {0,   0,   1,   1,   2,   2,   2,   3},
/* DEPTH 7 */ {0,   0,   2,   3,   4,   4,   5,   6},

/* FNUM BIT 7: 000 1000xxxx */
/* DEPTH 0 */ {0,   0,   0,   0,   0,   0,   0,   0},
/* DEPTH 1 */ {0,   0,   0,   0,   0,   0,   0,   0},
/* DEPTH 2 */ {0,   0,   0,   0,   0,   0,   1,   1},
/* DEPTH 3 */ {0,   0,   0,   0,   1,   1,   1,   1},
/* DEPTH 4 */ {0,   0,   0,   1,   1,   1,   1,   2},
/* DEPTH 5 */ {0,   0,   1,   1,   2,   2,   2,   3},
/* DEPTH 6 */ {0,   0,   2,   3,   4,   4,   5,   6},
/* DEPTH 7 */ {0,   0,   4,   6,   8,   8, 0xa, 0xc},

/* FNUM BIT 8: 001 0000xxxx */
/* DEPTH 0 */ {0,   0,   0,   0,   0,   0,   0,   0},
/* DEPTH 1 */ {0,   0,   0,   0,   1,   1,   1,   1},
/* DEPTH 2 */ {0,   0,   0,   1,   1,   1,   2,   2},
/* DEPTH 3 */ {0,   0,   1,   1,   2,   2,   3,   3},
/* DEPTH 4 */ {0,   0,   1,   2,   2,   2,   3,   4},
/* DEPTH 5 */ {0,   0,   2,   3,   4,   4,   5,   6},
/* DEPTH 6 */ {0,   0,   4,   6,   8,   8, 0xa, 0xc},
/* DEPTH 7 */ {0,   0,   8, 0xc,0x10,0x10,0x14,0x18},

/* FNUM BIT 9: 010 0000xxxx */
/* DEPTH 0 */ {0,   0,   0,   0,   0,   0,   0,   0},
/* DEPTH 1 */ {0,   0,   0,   0,   2,   2,   2,   2},
/* DEPTH 2 */ {0,   0,   0,   2,   2,   2,   4,   4},
/* DEPTH 3 */ {0,   0,   2,   2,   4,   4,   6,   6},
/* DEPTH 4 */ {0,   0,   2,   4,   4,   4,   6,   8},
/* DEPTH 5 */ {0,   0,   4,   6,   8,   8, 0xa, 0xc},
/* DEPTH 6 */ {0,   0,   8, 0xc,0x10,0x10,0x14,0x18},
/* DEPTH 7 */ {0,   0,0x10,0x18,0x20,0x20,0x28,0x30},

/* FNUM BIT10: 100 0000xxxx */
/* DEPTH 0 */ {0,   0,   0,   0,   0,   0,   0,   0},
/* DEPTH 1 */ {0,   0,   0,   0,   4,   4,   4,   4},
/* DEPTH 2 */ {0,   0,   0,   4,   4,   4,   8,   8},
/* DEPTH 3 */ {0,   0,   4,   4,   8,   8, 0xc, 0xc},
/* DEPTH 4 */ {0,   0,   4,   8,   8,   8, 0xc,0x10},
/* DEPTH 5 */ {0,   0,   8, 0xc,0x10,0x10,0x14,0x18},
/* DEPTH 6 */ {0,   0,0x10,0x18,0x20,0x20,0x28,0x30},
/* DEPTH 7 */ {0,   0,0x20,0x30,0x40,0x40,0x50,0x60},

};

/* all 128 LFO PM waveforms */
static INT32 lfo_pm_table[128*8*32]; /* 128 combinations of 7 bits meaningful (of F-NUMBER), 8 LFO depths, 32 LFO output levels per one depth */

/* there are 2048 FNUMs that can be generated using FNUM/BLK registers
	but LFO works with one more bit of a precision so we really need 4096 elements */
static UINT32 fn_table[4096];	/* fnumber->increment counter */

static int g_lfo_ampm = 0;

/* register number to channel number , slot offset */
#define OPN_CHAN(N) (N&3)
#define OPN_SLOT(N) ((N>>2)&3)

/* slot number */
#define SLOT1 0
#define SLOT2 2
#define SLOT3 1
#define SLOT4 3


/* OPN Mode Register Write */
INLINE void set_timers( int v )
{
	/* b7 = CSM MODE */
	/* b6 = 3 slot mode */
	/* b5 = reset b */
	/* b4 = reset a */
	/* b3 = timer enable b */
	/* b2 = timer enable a */
	/* b1 = load b */
	/* b0 = load a */
	ym2612.OPN.ST.mode = v;

	/* reset Timer b flag */
	if( v & 0x20 )
		ym2612.OPN.ST.status &= ~2;

	/* reset Timer a flag */
	if( v & 0x10 )
		ym2612.OPN.ST.status &= ~1;
}


INLINE void FM_KEYON(int c , int s )
{
	FM_SLOT *SLOT = &ym2612.CH[c].SLOT[s];
	if( !SLOT->key )
	{
		SLOT->key = 1;
		SLOT->phase = 0;		/* restart Phase Generator */
		SLOT->state = EG_ATT;	/* phase -> Attack */
		ym2612.slot_mask |= (1<<s) << (c*4);
	}
}

INLINE void FM_KEYOFF(int c , int s )
{
	FM_SLOT *SLOT = &ym2612.CH[c].SLOT[s];
	if( SLOT->key )
	{
		SLOT->key = 0;
		if (SLOT->state>EG_REL)
			SLOT->state = EG_REL;/* phase -> Release */
	}
}


/* set detune & multiple */
INLINE void set_det_mul(FM_CH *CH, FM_SLOT *SLOT, int v)
{
	SLOT->mul = (v&0x0f)? (v&0x0f)*2 : 1;
	SLOT->DT  = ym2612.OPN.ST.dt_tab[(v>>4)&7];
	CH->SLOT[SLOT1].Incr=-1;
}

/* set total level */
INLINE void set_tl(FM_SLOT *SLOT, int v)
{
	SLOT->tl = (v&0x7f)<<(ENV_BITS-7); /* 7bit TL */
}

/* set attack rate & key scale  */
INLINE void set_ar_ksr(FM_CH *CH, FM_SLOT *SLOT, int v)
{
	UINT8 old_KSR = SLOT->KSR;

	SLOT->ar = (v&0x1f) ? 32 + ((v&0x1f)<<1) : 0;

	SLOT->KSR = 3-(v>>6);
	if (SLOT->KSR != old_KSR)
	{
		CH->SLOT[SLOT1].Incr=-1;
	}
	else
	{
		int eg_sh_ar, eg_sel_ar;

		/* refresh Attack rate */
		if ((SLOT->ar + SLOT->ksr) < 32+62)
		{
			eg_sh_ar  = eg_rate_shift [SLOT->ar  + SLOT->ksr ];
			eg_sel_ar = eg_rate_select[SLOT->ar  + SLOT->ksr ];
		}
		else
		{
			eg_sh_ar  = 0;
			eg_sel_ar = 17;
		}

		SLOT->eg_pack_ar = eg_inc_pack[eg_sel_ar] | (eg_sh_ar<<24);
	}
}

/* set decay rate */
INLINE void set_dr(FM_SLOT *SLOT, int v)
{
	int eg_sh_d1r, eg_sel_d1r;

	SLOT->d1r = (v&0x1f) ? 32 + ((v&0x1f)<<1) : 0;

	eg_sh_d1r = eg_rate_shift [SLOT->d1r + SLOT->ksr];
	eg_sel_d1r= eg_rate_select[SLOT->d1r + SLOT->ksr];

	SLOT->eg_pack_d1r = eg_inc_pack[eg_sel_d1r] | (eg_sh_d1r<<24);
}

/* set sustain rate */
INLINE void set_sr(FM_SLOT *SLOT, int v)
{
	int eg_sh_d2r, eg_sel_d2r;

	SLOT->d2r = (v&0x1f) ? 32 + ((v&0x1f)<<1) : 0;

	eg_sh_d2r = eg_rate_shift [SLOT->d2r + SLOT->ksr];
	eg_sel_d2r= eg_rate_select[SLOT->d2r + SLOT->ksr];

	SLOT->eg_pack_d2r = eg_inc_pack[eg_sel_d2r] | (eg_sh_d2r<<24);
}

/* set release rate */
INLINE void set_sl_rr(FM_SLOT *SLOT, int v)
{
	int eg_sh_rr, eg_sel_rr;

	SLOT->sl = sl_table[ v>>4 ];

	SLOT->rr  = 34 + ((v&0x0f)<<2);

	eg_sh_rr  = eg_rate_shift [SLOT->rr  + SLOT->ksr];
	eg_sel_rr = eg_rate_select[SLOT->rr  + SLOT->ksr];

	SLOT->eg_pack_rr = eg_inc_pack[eg_sel_rr] | (eg_sh_rr<<24);
}



INLINE signed int op_calc(UINT32 phase, unsigned int env, signed int pm)
{
	int ret, sin = (phase>>16) + (pm>>1);
	int neg = sin & 0x200;
	if (sin & 0x100) sin ^= 0xff;
	sin&=0xff;
	env&=~1;

	// this was already checked
	// if (env >= ENV_QUIET) // 384
	//	return 0;

	ret = ym_tl_tab[sin | (env<<7)];

	return neg ? -ret : ret;
}

INLINE signed int op_calc1(UINT32 phase, unsigned int env, signed int pm)
{
	int ret, sin = (phase+pm)>>16;
	int neg = sin & 0x200;
	if (sin & 0x100) sin ^= 0xff;
	sin&=0xff;
	env&=~1;

	// if (env >= ENV_QUIET) // 384
	//	return 0;

	ret = ym_tl_tab[sin | (env<<7)];

	return neg ? -ret : ret;
}

#if !defined(_ASM_YM2612_C) || defined(EXTERNAL_YM2612)
/* advance LFO to next sample */
INLINE int advance_lfo(int lfo_ampm, UINT32 lfo_cnt_old, UINT32 lfo_cnt)
{
	UINT8 pos;
	UINT8 prev_pos;

	prev_pos = (lfo_cnt_old >> LFO_SH) & 127;

	pos = (lfo_cnt >> LFO_SH) & 127;

	/* update AM when LFO output changes */

	if (prev_pos != pos)
	{
		lfo_ampm &= 0xff;
		/* triangle */
		/* AM: 0 to 126 step +2, 126 to 0 step -2 */
		if (pos<64)
			lfo_ampm |= ((pos&63) * 2) << 8;           /* 0 - 126 */
		else
			lfo_ampm |= (126 - (pos&63)*2) << 8;
	}
	else
	{
		return lfo_ampm;
	}

	/* PM works with 4 times slower clock */
	prev_pos >>= 2;
	pos >>= 2;
	/* update PM when LFO output changes */
	if (prev_pos != pos)
	{
		lfo_ampm &= ~0xff;
		lfo_ampm |= pos; /* 0 - 32 */
	}
	return lfo_ampm;
}

#define EG_INC_VAL() \
	((1 << ((pack >> ((eg_cnt>>shift)&7)*3)&7)) >> 1)

INLINE UINT32 update_eg_phase(FM_SLOT *SLOT, UINT32 eg_cnt)
{
	INT32 volume = SLOT->volume;

	switch(SLOT->state)
	{
		case EG_ATT:		/* attack phase */
		{
			UINT32 pack = SLOT->eg_pack_ar;
			UINT32 shift = pack>>24;
			if ( !(eg_cnt & ((1<<shift)-1) ) )
			{
				volume += ( ~volume * EG_INC_VAL() ) >>4;

				if (volume <= MIN_ATT_INDEX)
				{
					volume = MIN_ATT_INDEX;
					SLOT->state = EG_DEC;
				}
			}
			break;
		}

		case EG_DEC:	/* decay phase */
		{
			UINT32 pack = SLOT->eg_pack_d1r;
			UINT32 shift = pack>>24;
			if ( !(eg_cnt & ((1<<shift)-1) ) )
			{
				volume += EG_INC_VAL();

				if ( volume >= (INT32) SLOT->sl )
					SLOT->state = EG_SUS;
			}
			break;
		}

		case EG_SUS:	/* sustain phase */
		{
			UINT32 pack = SLOT->eg_pack_d2r;
			UINT32 shift = pack>>24;
			if ( !(eg_cnt & ((1<<shift)-1) ) )
			{
				volume += EG_INC_VAL();

				if ( volume >= MAX_ATT_INDEX )
				{
					volume = MAX_ATT_INDEX;
					/* do not change SLOT->state (verified on real chip) */
				}
			}
			break;
		}

		case EG_REL:	/* release phase */
		{
			UINT32 pack = SLOT->eg_pack_rr;
			UINT32 shift = pack>>24;
			if ( !(eg_cnt & ((1<<shift)-1) ) )
			{
				volume += EG_INC_VAL();

				if ( volume >= MAX_ATT_INDEX )
				{
					volume = MAX_ATT_INDEX;
					SLOT->state = EG_OFF;
				}
			}
			break;
		}
	}

	SLOT->volume = volume;
	return SLOT->tl + ((UINT32)volume); /* tl is 7bit<<3, volume 0-1023 (0-2039 total) */
}
#endif


typedef struct
{
	UINT16 vol_out1; /* 00: current output from EG circuit (without AM from LFO) */
	UINT16 vol_out2;
	UINT16 vol_out3;
	UINT16 vol_out4;
	UINT32 pad[2];
	UINT32 phase1;   /* 10 */
	UINT32 phase2;
	UINT32 phase3;
	UINT32 phase4;
	UINT32 incr1;    /* 20: phase step */
	UINT32 incr2;
	UINT32 incr3;
	UINT32 incr4;
	UINT32 lfo_cnt;  /* 30 */
	UINT32 lfo_inc;
	INT32  mem;      /* one sample delay memory */
	UINT32 eg_cnt;   /* envelope generator counter */
	FM_CH  *CH;      /* 40: envelope generator counter */
	UINT32 eg_timer;
	UINT32 eg_timer_add;
	UINT32 pack;     // 4c: stereo, lastchan, disabled, lfo_enabled | pan_r, pan_l, ams[2] | AMmasks[4] | FB[4] | lfo_ampm[16]
	UINT32 algo;     /* 50: algo[3], was_update */
	INT32  op1_out;
#ifdef _MIPS_ARCH_ALLEGREX
	UINT32 pad1[3+8];
#endif
} chan_rend_context;


#if !defined(_ASM_YM2612_C) || defined(EXTERNAL_YM2612)
static void chan_render_loop(chan_rend_context *ct, int *buffer, int length)
{
	int scounter;					/* sample counter */

	/* sample generating loop */
	for (scounter = 0; scounter < length; scounter++)
	{
		int smp = 0;		/* produced sample */
		unsigned int eg_out, eg_out2, eg_out4;

		if (ct->pack & 8) { /* LFO enabled ? (test Earthworm Jim in between demo 1 and 2) */
			ct->pack = (ct->pack&0xffff) | (advance_lfo(ct->pack >> 16, ct->lfo_cnt, ct->lfo_cnt + ct->lfo_inc) << 16);
			ct->lfo_cnt += ct->lfo_inc;
		}

		ct->eg_timer += ct->eg_timer_add;
		while (ct->eg_timer >= EG_TIMER_OVERFLOW)
		{
			ct->eg_timer -= EG_TIMER_OVERFLOW;
			ct->eg_cnt++;

			if (ct->CH->SLOT[SLOT1].state != EG_OFF) ct->vol_out1 = update_eg_phase(&ct->CH->SLOT[SLOT1], ct->eg_cnt);
			if (ct->CH->SLOT[SLOT2].state != EG_OFF) ct->vol_out2 = update_eg_phase(&ct->CH->SLOT[SLOT2], ct->eg_cnt);
			if (ct->CH->SLOT[SLOT3].state != EG_OFF) ct->vol_out3 = update_eg_phase(&ct->CH->SLOT[SLOT3], ct->eg_cnt);
			if (ct->CH->SLOT[SLOT4].state != EG_OFF) ct->vol_out4 = update_eg_phase(&ct->CH->SLOT[SLOT4], ct->eg_cnt);
		}

		if (ct->pack & 4) continue; /* output disabled */

		/* calculate channel sample */
		eg_out = ct->vol_out1;
		if ( (ct->pack & 8) && (ct->pack&(1<<(SLOT1+8))) ) eg_out += ct->pack >> (((ct->pack&0xc0)>>6)+24);

		if( eg_out < ENV_QUIET )	/* SLOT 1 */
		{
			int out = 0;

			if (ct->pack&0xf000) out = ((ct->op1_out>>16) + ((ct->op1_out<<16)>>16)) << ((ct->pack&0xf000)>>12); /* op1_out0 + op1_out1 */
			ct->op1_out <<= 16;
			ct->op1_out |= (unsigned short)op_calc1(ct->phase1, eg_out, out);
		} else {
			ct->op1_out <<= 16; /* op1_out0 = op1_out1; op1_out1 = 0; */
		}

		eg_out  = ct->vol_out3; // volume_calc(&CH->SLOT[SLOT3]);
		eg_out2 = ct->vol_out2; // volume_calc(&CH->SLOT[SLOT2]);
		eg_out4 = ct->vol_out4; // volume_calc(&CH->SLOT[SLOT4]);

		if (ct->pack & 8) {
			unsigned int add = ct->pack >> (((ct->pack&0xc0)>>6)+24);
			if (ct->pack & (1<<(SLOT3+8))) eg_out  += add;
			if (ct->pack & (1<<(SLOT2+8))) eg_out2 += add;
			if (ct->pack & (1<<(SLOT4+8))) eg_out4 += add;
		}

		switch( ct->CH->ALGO )
		{
			case 0:
			{
				/* M1---C1---MEM---M2---C2---OUT */
				int m2,c1,c2=0;	/* Phase Modulation input for operators 2,3,4 */
				m2 = ct->mem;
				c1 = ct->op1_out>>16;
				if( eg_out  < ENV_QUIET ) {		/* SLOT 3 */
					c2  = op_calc(ct->phase3, eg_out,  m2);
				}
				if( eg_out2 < ENV_QUIET ) {		/* SLOT 2 */
					ct->mem = op_calc(ct->phase2, eg_out2, c1);
				}
				else ct->mem = 0;
				if( eg_out4 < ENV_QUIET ) {		/* SLOT 4 */
					smp = op_calc(ct->phase4, eg_out4, c2);
				}
				break;
			}
			case 1:
			{
				/* M1------+-MEM---M2---C2---OUT */
				/*      C1-+                     */
				int m2,c2=0;
				m2 = ct->mem;
				ct->mem = ct->op1_out>>16;
				if( eg_out  < ENV_QUIET ) {		/* SLOT 3 */
					c2  = op_calc(ct->phase3, eg_out,  m2);
				}
				if( eg_out2 < ENV_QUIET ) {		/* SLOT 2 */
					ct->mem+= op_calc(ct->phase2, eg_out2, 0);
				}
				if( eg_out4 < ENV_QUIET ) {		/* SLOT 4 */
					smp = op_calc(ct->phase4, eg_out4, c2);
				}
				break;
			}
			case 2:
			{
				/* M1-----------------+-C2---OUT */
				/*      C1---MEM---M2-+          */
				int m2,c2;
				m2 = ct->mem;
				c2 = ct->op1_out>>16;
				if( eg_out  < ENV_QUIET ) {		/* SLOT 3 */
					c2 += op_calc(ct->phase3, eg_out,  m2);
				}
				if( eg_out2 < ENV_QUIET ) {		/* SLOT 2 */
					ct->mem = op_calc(ct->phase2, eg_out2, 0);
				}
				else ct->mem = 0;
				if( eg_out4 < ENV_QUIET ) {		/* SLOT 4 */
					smp = op_calc(ct->phase4, eg_out4, c2);
				}
				break;
			}
			case 3:
			{
				/* M1---C1---MEM------+-C2---OUT */
				/*                 M2-+          */
				int c1,c2;
				c2 = ct->mem;
				c1 = ct->op1_out>>16;
				if( eg_out  < ENV_QUIET ) {		/* SLOT 3 */
					c2 += op_calc(ct->phase3, eg_out,  0);
				}
				if( eg_out2 < ENV_QUIET ) {		/* SLOT 2 */
					ct->mem = op_calc(ct->phase2, eg_out2, c1);
				}
				else ct->mem = 0;
				if( eg_out4 < ENV_QUIET ) {		/* SLOT 4 */
					smp = op_calc(ct->phase4, eg_out4, c2);
				}
				break;
			}
			case 4:
			{
				/* M1---C1-+-OUT */
				/* M2---C2-+     */
				/* MEM: not used */
				int c1,c2=0;
				c1 = ct->op1_out>>16;
				if( eg_out  < ENV_QUIET ) {		/* SLOT 3 */
					c2  = op_calc(ct->phase3, eg_out,  0);
				}
				if( eg_out2 < ENV_QUIET ) {		/* SLOT 2 */
					smp = op_calc(ct->phase2, eg_out2, c1);
				}
				if( eg_out4 < ENV_QUIET ) {		/* SLOT 4 */
					smp+= op_calc(ct->phase4, eg_out4, c2);
				}
				break;
			}
			case 5:
			{
				/*    +----C1----+     */
				/* M1-+-MEM---M2-+-OUT */
				/*    +----C2----+     */
				int m2,c1,c2;
				m2 = ct->mem;
				ct->mem = c1 = c2 = ct->op1_out>>16;
				if( eg_out < ENV_QUIET ) {		/* SLOT 3 */
					smp = op_calc(ct->phase3, eg_out, m2);
				}
				if( eg_out2 < ENV_QUIET ) {		/* SLOT 2 */
					smp+= op_calc(ct->phase2, eg_out2, c1);
				}
				if( eg_out4 < ENV_QUIET ) {		/* SLOT 4 */
					smp+= op_calc(ct->phase4, eg_out4, c2);
				}
				break;
			}
			case 6:
			{
				/* M1---C1-+     */
				/*      M2-+-OUT */
				/*      C2-+     */
				/* MEM: not used */
				int c1;
				c1 = ct->op1_out>>16;
				if( eg_out < ENV_QUIET ) {		/* SLOT 3 */
					smp = op_calc(ct->phase3, eg_out,  0);
				}
				if( eg_out2 < ENV_QUIET ) {		/* SLOT 2 */
					smp+= op_calc(ct->phase2, eg_out2, c1);
				}
				if( eg_out4 < ENV_QUIET ) {		/* SLOT 4 */
					smp+= op_calc(ct->phase4, eg_out4, 0);
				}
				break;
			}
			case 7:
			{
				/* M1-+     */
				/* C1-+-OUT */
				/* M2-+     */
				/* C2-+     */
				/* MEM: not used*/
				smp = ct->op1_out>>16;
				if( eg_out < ENV_QUIET ) {		/* SLOT 3 */
					smp += op_calc(ct->phase3, eg_out,  0);
				}
				if( eg_out2 < ENV_QUIET ) {		/* SLOT 2 */
					smp += op_calc(ct->phase2, eg_out2, 0);
				}
				if( eg_out4 < ENV_QUIET ) {		/* SLOT 4 */
					smp += op_calc(ct->phase4, eg_out4, 0);
				}
				break;
			}
		}
		/* done calculating channel sample */

		/* mix sample to output buffer */
		if (smp) {
			if (ct->pack & 1) { /* stereo */
				if (ct->pack & 0x20) /* L */ /* TODO: check correctness */
					buffer[scounter*2] += smp;
				if (ct->pack & 0x10) /* R */
					buffer[scounter*2+1] += smp;
			} else {
				buffer[scounter] += smp;
			}
			ct->algo = 8; // algo is only used in asm, here only bit3 is used
		}

		/* update phase counters AFTER output calculations */
		ct->phase1 += ct->incr1;
		ct->phase2 += ct->incr2;
		ct->phase3 += ct->incr3;
		ct->phase4 += ct->incr4;
	}
}
#else
void chan_render_loop(chan_rend_context *ct, int *buffer, unsigned short length);
#endif

static chan_rend_context crct;

static void chan_render_prep(void)
{
	crct.eg_timer_add = ym2612.OPN.eg_timer_add;
	crct.lfo_inc = ym2612.OPN.lfo_inc;
}

static void chan_render_finish(void)
{
	ym2612.OPN.eg_cnt = crct.eg_cnt;
	ym2612.OPN.eg_timer = crct.eg_timer;
	g_lfo_ampm = crct.pack >> 16; // need_save
	ym2612.OPN.lfo_cnt = crct.lfo_cnt;
}

static int chan_render(int *buffer, int length, int c, UINT32 flags) // flags: stereo, ?, disabled, ?, pan_r, pan_l
{
	crct.CH = &ym2612.CH[c];
	crct.mem = crct.CH->mem_value;		/* one sample delay memory */
	crct.lfo_cnt = ym2612.OPN.lfo_cnt;

	flags &= 0x35;

	if (crct.lfo_inc) {
		flags |= 8;
		flags |= g_lfo_ampm << 16;
		flags |= crct.CH->AMmasks << 8;
		if (crct.CH->ams == 8) // no ams
		     flags &= ~0xf00;
		else flags |= (crct.CH->ams&3)<<6;
	}
	flags |= (crct.CH->FB&0xf)<<12;				/* feedback shift */
	crct.pack = flags;

	crct.eg_cnt = ym2612.OPN.eg_cnt;			/* envelope generator counter */
	crct.eg_timer = ym2612.OPN.eg_timer;

	/* precalculate phase modulation incr */
	crct.phase1 = crct.CH->SLOT[SLOT1].phase;
	crct.phase2 = crct.CH->SLOT[SLOT2].phase;
	crct.phase3 = crct.CH->SLOT[SLOT3].phase;
	crct.phase4 = crct.CH->SLOT[SLOT4].phase;

	/* current output from EG circuit (without AM from LFO) */
	crct.vol_out1 = crct.CH->SLOT[SLOT1].tl + ((UINT32)crct.CH->SLOT[SLOT1].volume);
	crct.vol_out2 = crct.CH->SLOT[SLOT2].tl + ((UINT32)crct.CH->SLOT[SLOT2].volume);
	crct.vol_out3 = crct.CH->SLOT[SLOT3].tl + ((UINT32)crct.CH->SLOT[SLOT3].volume);
	crct.vol_out4 = crct.CH->SLOT[SLOT4].tl + ((UINT32)crct.CH->SLOT[SLOT4].volume);

	crct.op1_out = crct.CH->op1_out;
	crct.algo = crct.CH->ALGO & 7;

	if(crct.CH->pms)
	{
		/* add support for 3 slot mode */
		UINT32 block_fnum = crct.CH->block_fnum;

		UINT32 fnum_lfo   = ((block_fnum & 0x7f0) >> 4) * 32 * 8;
		INT32  lfo_fn_table_index_offset = lfo_pm_table[ fnum_lfo + crct.CH->pms + ((crct.pack>>16)&0xff) ];

		if (lfo_fn_table_index_offset)	/* LFO phase modulation active */
		{
			UINT8  blk;
			UINT32 fn;
			int kc,fc;

			blk = block_fnum >> 11;
			block_fnum = block_fnum*2 + lfo_fn_table_index_offset;

			fn  = block_fnum & 0xfff;

			/* keyscale code */
			kc = (blk<<2) | opn_fktable[fn >> 8];
			/* phase increment counter */
			fc = fn_table[fn]>>(7-blk);

			crct.incr1 = ((fc+crct.CH->SLOT[SLOT1].DT[kc])*crct.CH->SLOT[SLOT1].mul) >> 1;
			crct.incr2 = ((fc+crct.CH->SLOT[SLOT2].DT[kc])*crct.CH->SLOT[SLOT2].mul) >> 1;
			crct.incr3 = ((fc+crct.CH->SLOT[SLOT3].DT[kc])*crct.CH->SLOT[SLOT3].mul) >> 1;
			crct.incr4 = ((fc+crct.CH->SLOT[SLOT4].DT[kc])*crct.CH->SLOT[SLOT4].mul) >> 1;
		}
		else	/* LFO phase modulation  = zero */
		{
			crct.incr1 = crct.CH->SLOT[SLOT1].Incr;
			crct.incr2 = crct.CH->SLOT[SLOT2].Incr;
			crct.incr3 = crct.CH->SLOT[SLOT3].Incr;
			crct.incr4 = crct.CH->SLOT[SLOT4].Incr;
		}
	}
	else	/* no LFO phase modulation */
	{
		crct.incr1 = crct.CH->SLOT[SLOT1].Incr;
		crct.incr2 = crct.CH->SLOT[SLOT2].Incr;
		crct.incr3 = crct.CH->SLOT[SLOT3].Incr;
		crct.incr4 = crct.CH->SLOT[SLOT4].Incr;
	}

	chan_render_loop(&crct, buffer, length);

	crct.CH->op1_out = crct.op1_out;
	crct.CH->mem_value = crct.mem;
	if (crct.CH->SLOT[SLOT1].state | crct.CH->SLOT[SLOT2].state | crct.CH->SLOT[SLOT3].state | crct.CH->SLOT[SLOT4].state)
	{
		crct.CH->SLOT[SLOT1].phase = crct.phase1;
		crct.CH->SLOT[SLOT2].phase = crct.phase2;
		crct.CH->SLOT[SLOT3].phase = crct.phase3;
		crct.CH->SLOT[SLOT4].phase = crct.phase4;
	}
	else
		ym2612.slot_mask &= ~(0xf << (c*4));

	return (crct.algo & 8) >> 3; // had output
}

/* update phase increment and envelope generator */
INLINE void refresh_fc_eg_slot(FM_SLOT *SLOT, int fc, int kc)
{
	int ksr, fdt;

	/* (frequency) phase increment counter */
	fdt = fc+SLOT->DT[kc];
	/* detect overflow */
//	if (fdt < 0) fdt += fn_table[0x7ff*2] >> (7-blk-1);
	if (fdt < 0) fdt += fn_table[0x7ff*2] >> 2;
	SLOT->Incr = fdt*SLOT->mul >> 1;

	ksr = kc >> SLOT->KSR;
	if( SLOT->ksr != ksr )
	{
		int eg_sh, eg_sel;
		SLOT->ksr = ksr;

		/* calculate envelope generator rates */
		if ((SLOT->ar + ksr) < 32+62)
		{
			eg_sh  = eg_rate_shift [SLOT->ar  + ksr ];
			eg_sel = eg_rate_select[SLOT->ar  + ksr ];
		}
		else
		{
			eg_sh  = 0;
			eg_sel = 17;
		}

		SLOT->eg_pack_ar = eg_inc_pack[eg_sel] | (eg_sh<<24);

		eg_sh  = eg_rate_shift [SLOT->d1r + ksr];
		eg_sel = eg_rate_select[SLOT->d1r + ksr];

		SLOT->eg_pack_d1r = eg_inc_pack[eg_sel] | (eg_sh<<24);

		eg_sh  = eg_rate_shift [SLOT->d2r + ksr];
		eg_sel = eg_rate_select[SLOT->d2r + ksr];

		SLOT->eg_pack_d2r = eg_inc_pack[eg_sel] | (eg_sh<<24);

		eg_sh  = eg_rate_shift [SLOT->rr  + ksr];
		eg_sel = eg_rate_select[SLOT->rr  + ksr];

		SLOT->eg_pack_rr = eg_inc_pack[eg_sel] | (eg_sh<<24);
	}
}

/* update phase increment counters */
INLINE void refresh_fc_eg_chan(FM_CH *CH)
{
	if( CH->SLOT[SLOT1].Incr==-1){
		int fc = CH->fc;
		int kc = CH->kcode;
		refresh_fc_eg_slot(&CH->SLOT[SLOT1] , fc , kc );
		refresh_fc_eg_slot(&CH->SLOT[SLOT2] , fc , kc );
		refresh_fc_eg_slot(&CH->SLOT[SLOT3] , fc , kc );
		refresh_fc_eg_slot(&CH->SLOT[SLOT4] , fc , kc );
	}
}

INLINE void refresh_fc_eg_chan_sl3(void)
{
	if( ym2612.CH[2].SLOT[SLOT1].Incr==-1)
	{
		refresh_fc_eg_slot(&ym2612.CH[2].SLOT[SLOT1], ym2612.OPN.SL3.fc[1], ym2612.OPN.SL3.kcode[1] );
		refresh_fc_eg_slot(&ym2612.CH[2].SLOT[SLOT2], ym2612.OPN.SL3.fc[2], ym2612.OPN.SL3.kcode[2] );
		refresh_fc_eg_slot(&ym2612.CH[2].SLOT[SLOT3], ym2612.OPN.SL3.fc[0], ym2612.OPN.SL3.kcode[0] );
		refresh_fc_eg_slot(&ym2612.CH[2].SLOT[SLOT4], ym2612.CH[2].fc , ym2612.CH[2].kcode );
	}
}

/* initialize time tables */
static void init_timetables(const UINT8 *dttable)
{
	int i,d;
	double rate;

	/* DeTune table */
	for (d = 0;d <= 3;d++){
		for (i = 0;i <= 31;i++){
			rate = ((double)dttable[d*32 + i]) * SIN_LEN  * ym2612.OPN.ST.freqbase  * (1<<FREQ_SH) / ((double)(1<<20));
			ym2612.OPN.ST.dt_tab[d][i]   = (INT32) rate;
			ym2612.OPN.ST.dt_tab[d+4][i] = -ym2612.OPN.ST.dt_tab[d][i];
		}
	}
}


static void reset_channels(FM_CH *CH)
{
	int c,s;

	ym2612.OPN.ST.mode   = 0;	/* normal mode */
	ym2612.OPN.ST.TA     = 0;
	ym2612.OPN.ST.TAC    = 0;
	ym2612.OPN.ST.TB     = 0;
	ym2612.OPN.ST.TBC    = 0;

	for( c = 0 ; c < 6 ; c++ )
	{
		CH[c].fc = 0;
		for(s = 0 ; s < 4 ; s++ )
		{
			CH[c].SLOT[s].state= EG_OFF;
			CH[c].SLOT[s].volume = MAX_ATT_INDEX;
		}
		CH[c].mem_value = CH[c].op1_out = 0;
	}
	ym2612.slot_mask = 0;
}

/* initialize generic tables */
static void init_tables(void)
{
	signed int i,x,y,p;
	signed int n;
	double o,m;

	for (i=0; i < 256; i++)
	{
		/* non-standard sinus */
		m = sin( ((i*2)+1) * M_PI / SIN_LEN ); /* checked against the real chip */

		/* we never reach zero here due to ((i*2)+1) */

		if (m>0.0)
			o = 8*log(1.0/m)/log(2);	/* convert to 'decibels' */
		else
			o = 8*log(-1.0/m)/log(2);	/* convert to 'decibels' */

		o = o / (ENV_STEP/4);

		n = (int)(2.0*o);
		if (n&1)						/* round to nearest */
			n = (n>>1)+1;
		else
			n = n>>1;

		ym_sin_tab[ i ] = n;
		//dprintf("FM.C: sin [%4i]= %4i", i, ym_sin_tab[i]);
	}

	//dprintf("FM.C: ENV_QUIET= %08x", ENV_QUIET );


	for (x=0; x < TL_RES_LEN; x++)
	{
		m = (1<<16) / pow(2, (x+1) * (ENV_STEP/4.0) / 8.0);
		m = floor(m);

		/* we never reach (1<<16) here due to the (x+1) */
		/* result fits within 16 bits at maximum */

		n = (int)m;		/* 16 bits here */
		n >>= 4;		/* 12 bits here */
		if (n&1)		/* round to nearest */
			n = (n>>1)+1;
		else
			n = n>>1;
						/* 11 bits here (rounded) */
		n <<= 2;		/* 13 bits here (as in real chip) */
		ym_tl_tab2[ x ] = n;

		for (i=1; i < 13; i++)
		{
			ym_tl_tab2[ x + i*TL_RES_LEN ] = n >> i;
		}
	}

	for (x=0; x < 256; x++)
	{
		int sin = ym_sin_tab[ x ];

		for (y=0; y < 2*13*TL_RES_LEN/8; y+=2)
		{
			p = (y<<2) + sin;
			if (p >= 13*TL_RES_LEN)
				 ym_tl_tab[(y<<7) | x] = 0;
			else ym_tl_tab[(y<<7) | x] = ym_tl_tab2[p];
		}
	}


	/* build LFO PM modulation table */
	for(i = 0; i < 8; i++) /* 8 PM depths */
	{
		UINT8 fnum;
		for (fnum=0; fnum<128; fnum++) /* 7 bits meaningful of F-NUMBER */
		{
			UINT8 value;
			UINT8 step;
			UINT32 offset_depth = i;
			UINT32 offset_fnum_bit;
			UINT32 bit_tmp;

			for (step=0; step<8; step++)
			{
				value = 0;
				for (bit_tmp=0; bit_tmp<7; bit_tmp++) /* 7 bits */
				{
					if (fnum & (1<<bit_tmp)) /* only if bit "bit_tmp" is set */
					{
						offset_fnum_bit = bit_tmp * 8;
						value += lfo_pm_output[offset_fnum_bit + offset_depth][step];
					}
				}
				lfo_pm_table[(fnum*32*8) + (i*32) + step   + 0] = value;
				lfo_pm_table[(fnum*32*8) + (i*32) +(step^7)+ 8] = value;
				lfo_pm_table[(fnum*32*8) + (i*32) + step   +16] = -value;
				lfo_pm_table[(fnum*32*8) + (i*32) +(step^7)+24] = -value;
			}
		}
	}
}


/* CSM Key Controll */
#if 0
INLINE void CSMKeyControll(FM_CH *CH)
{
	/* this is wrong, atm */

	/* all key on */
	FM_KEYON(CH,SLOT1);
	FM_KEYON(CH,SLOT2);
	FM_KEYON(CH,SLOT3);
	FM_KEYON(CH,SLOT4);
}
#endif


/* prescaler set (and make time tables) */
static void OPNSetPres(int pres)
{
	int i;

	/* frequency base */
	ym2612.OPN.ST.freqbase = (ym2612.OPN.ST.rate) ? ((double)ym2612.OPN.ST.clock / ym2612.OPN.ST.rate) / pres : 0;

	ym2612.OPN.eg_timer_add  = (1<<EG_SH) * ym2612.OPN.ST.freqbase;

	/* make time tables */
	init_timetables( dt_tab );

	/* there are 2048 FNUMs that can be generated using FNUM/BLK registers
        but LFO works with one more bit of a precision so we really need 4096 elements */
	/* calculate fnumber -> increment counter table */
	for(i = 0; i < 4096; i++)
	{
		/* freq table for octave 7 */
		/* OPN phase increment counter = 20bit */
		fn_table[i] = (UINT32)( (double)i * 32 * ym2612.OPN.ST.freqbase * (1<<(FREQ_SH-10)) ); /* -10 because chip works with 10.10 fixed point, while we use 16.16 */
	}

	/* LFO freq. table */
	for(i = 0; i < 8; i++)
	{
		/* Amplitude modulation: 64 output levels (triangle waveform); 1 level lasts for one of "lfo_samples_per_step" samples */
		/* Phase modulation: one entry from lfo_pm_output lasts for one of 4 * "lfo_samples_per_step" samples  */
		ym2612.OPN.lfo_freq[i] = (1.0 / lfo_samples_per_step[i]) * (1<<LFO_SH) * ym2612.OPN.ST.freqbase;
	}
}


/* write a OPN register (0x30-0xff) */
static int OPNWriteReg(int r, int v)
{
	int ret = 1;
	FM_CH *CH;
	FM_SLOT *SLOT;

	UINT8 c = OPN_CHAN(r);

	if (c == 3) return 0; /* 0xX3,0xX7,0xXB,0xXF */

	if (r >= 0x100) c+=3;

	CH = &ym2612.CH[c];

	SLOT = &(CH->SLOT[OPN_SLOT(r)]);

	switch( r & 0xf0 ) {
	case 0x30:	/* DET , MUL */
		set_det_mul(CH,SLOT,v);
		break;

	case 0x40:	/* TL */
		set_tl(SLOT,v);
		break;

	case 0x50:	/* KS, AR */
		set_ar_ksr(CH,SLOT,v);
		break;

	case 0x60:	/* bit7 = AM ENABLE, DR | depends on ksr */
		set_dr(SLOT,v);
		if(v&0x80) CH->AMmasks |=   1<<OPN_SLOT(r);
		else       CH->AMmasks &= ~(1<<OPN_SLOT(r));
		break;

	case 0x70:	/*     SR | depends on ksr */
		set_sr(SLOT,v);
		break;

	case 0x80:	/* SL, RR | depends on ksr */
		set_sl_rr(SLOT,v);
		break;

	case 0x90:	/* SSG-EG */
		// removed.
		ret = 0;
		break;

	case 0xa0:
		switch( OPN_SLOT(r) ){
		case 0:		/* 0xa0-0xa2 : FNUM1 | depends on fn_h (below) */
			{
				UINT32 fn = (((UINT32)( (CH->fn_h)&7))<<8) + v;
				UINT8 blk = CH->fn_h>>3;
				/* keyscale code */
				CH->kcode = (blk<<2) | opn_fktable[fn >> 7];
				/* phase increment counter */
				CH->fc = fn_table[fn*2]>>(7-blk);

				/* store fnum in clear form for LFO PM calculations */
				CH->block_fnum = (blk<<11) | fn;

				CH->SLOT[SLOT1].Incr=-1;
			}
			break;
		case 1:		/* 0xa4-0xa6 : FNUM2,BLK */
			CH->fn_h = v&0x3f;
			ret = 0;
			break;
		case 2:		/* 0xa8-0xaa : 3CH FNUM1 */
			if(r < 0x100)
			{
				UINT32 fn = (((UINT32)(ym2612.OPN.SL3.fn_h&7))<<8) + v;
				UINT8 blk = ym2612.OPN.SL3.fn_h>>3;
				/* keyscale code */
				ym2612.OPN.SL3.kcode[c]= (blk<<2) | opn_fktable[fn >> 7];
				/* phase increment counter */
				ym2612.OPN.SL3.fc[c] = fn_table[fn*2]>>(7-blk);
				ym2612.OPN.SL3.block_fnum[c] = (blk<<11) | fn;
				ym2612.CH[2].SLOT[SLOT1].Incr=-1;
			}
			break;
		case 3:		/* 0xac-0xae : 3CH FNUM2,BLK */
			if(r < 0x100)
				ym2612.OPN.SL3.fn_h = v&0x3f;
			ret = 0;
			break;
		default:
			ret = 0;
			break;
		}
		break;

	case 0xb0:
		switch( OPN_SLOT(r) ){
		case 0:		/* 0xb0-0xb2 : FB,ALGO */
			{
				int feedback = (v>>3)&7;
				CH->ALGO = v&7;
				CH->FB   = feedback ? feedback+6 : 0;
			}
			break;
		case 1:		/* 0xb4-0xb6 : L , R , AMS , PMS (YM2612/YM2610B/YM2610/YM2608) */
			{
				int panshift = c<<1;

				/* b0-2 PMS */
				CH->pms = (v & 7) * 32; /* CH->pms = PM depth * 32 (index in lfo_pm_table) */

				/* b4-5 AMS */
				CH->ams = lfo_ams_depth_shift[(v>>4) & 3];

				/* PAN :  b7 = L, b6 = R */
				ym2612.OPN.pan &= ~(3<<panshift);
				ym2612.OPN.pan |= ((v & 0xc0) >> 6) << panshift; // ..LRLR
			}
			break;
		default:
			ret = 0;
			break;
		}
		break;
	default:
		ret = 0;
		break;
	}

	return ret;
}


/*******************************************************************************/
/*      YM2612 local section                                                   */
/*******************************************************************************/

/* Generate samples for YM2612 */
int YM2612UpdateOne_(int *buffer, int length, int stereo, int is_buf_empty)
{
	int pan;
	int active_chs = 0;

	// if !is_buf_empty, it means it has valid samples to mix with, else it may contain trash
	if (is_buf_empty) memset32(buffer, 0, length<<stereo);

/*
	{
		int c, s;
		ppp();
		for (c = 0; c < 6; c++) {
			int slr = 0, slm;
			printf("%i: ", c);
			for (s = 0; s < 4; s++) {
				if (ym2612.CH[c].SLOT[s].state != EG_OFF) slr = 1;
				printf(" %i", ym2612.CH[c].SLOT[s].state != EG_OFF);
			}
			slm = (ym2612.slot_mask&(0xf<<(c*4))) ? 1 : 0;
			printf(" | %i", slm);
			printf(" | %i\n", ym2612.CH[c].SLOT[SLOT1].Incr==-1);
			if (slr != slm) exit(1);
		}
	}
*/
	/* refresh PG and EG */
	refresh_fc_eg_chan( &ym2612.CH[0] );
	refresh_fc_eg_chan( &ym2612.CH[1] );
	if( (ym2612.OPN.ST.mode & 0xc0) )
		/* 3SLOT MODE */
		refresh_fc_eg_chan_sl3();
	else
		refresh_fc_eg_chan( &ym2612.CH[2] );
	refresh_fc_eg_chan( &ym2612.CH[3] );
	refresh_fc_eg_chan( &ym2612.CH[4] );
	refresh_fc_eg_chan( &ym2612.CH[5] );

	pan = ym2612.OPN.pan;
	if (stereo) stereo = 1;

	/* mix to 32bit dest */
	// flags: stereo, ?, disabled, ?, pan_r, pan_l
	chan_render_prep();
	if (ym2612.slot_mask & 0x00000f) active_chs |= chan_render(buffer, length, 0, stereo|((pan&0x003)<<4)) << 0;
	if (ym2612.slot_mask & 0x0000f0) active_chs |= chan_render(buffer, length, 1, stereo|((pan&0x00c)<<2)) << 1;
	if (ym2612.slot_mask & 0x000f00) active_chs |= chan_render(buffer, length, 2, stereo|((pan&0x030)   )) << 2;
	if (ym2612.slot_mask & 0x00f000) active_chs |= chan_render(buffer, length, 3, stereo|((pan&0x0c0)>>2)) << 3;
	if (ym2612.slot_mask & 0x0f0000) active_chs |= chan_render(buffer, length, 4, stereo|((pan&0x300)>>4)) << 4;
	if (ym2612.slot_mask & 0xf00000) active_chs |= chan_render(buffer, length, 5, stereo|((pan&0xc00)>>6)|(ym2612.dacen<<2)) << 5;
	chan_render_finish();

	return active_chs; // 1 if buffer updated
}


/* initialize YM2612 emulator */
void YM2612Init_(int clock, int rate)
{
	memset(&ym2612, 0, sizeof(ym2612));
	init_tables();

	ym2612.OPN.ST.clock = clock;
	ym2612.OPN.ST.rate = rate;

	OPNSetPres( 6*24 );

	/* Extend handler */
	YM2612ResetChip_();
}


/* reset */
void YM2612ResetChip_(void)
{
	int i;

	memset(ym2612.REGS, 0, sizeof(ym2612.REGS));

	set_timers( 0x30 ); /* mode 0 , timer reset */
	ym2612.REGS[0x27] = 0x30;

	ym2612.OPN.eg_timer = 0;
	ym2612.OPN.eg_cnt   = 0;
	ym2612.OPN.ST.status = 0;

	reset_channels( &ym2612.CH[0] );
	for(i = 0xb6 ; i >= 0xb4 ; i-- )
	{
		OPNWriteReg(i      ,0xc0);
		OPNWriteReg(i|0x100,0xc0);
		ym2612.REGS[i      ] = 0xc0;
		ym2612.REGS[i|0x100] = 0xc0;
	}
	for(i = 0xb2 ; i >= 0x30 ; i-- )
	{
		OPNWriteReg(i      ,0);
		OPNWriteReg(i|0x100,0);
	}
	for(i = 0x26 ; i >= 0x20 ; i-- ) OPNWriteReg(i,0);
	/* DAC mode clear */
	ym2612.dacen = 0;
	ym2612.addr_A1 = 0;
}


/* YM2612 write */
/* a = address */
/* v = value   */
/* returns 1 if sample affecting state changed */
int YM2612Write_(unsigned int a, unsigned int v)
{
	int addr, ret=1;

	v &= 0xff;	/* adjust to 8 bit bus */

	switch( a&3){
	case 0:	/* address port 0 */
		ym2612.OPN.ST.address = v;
		ym2612.addr_A1 = 0;
		ret=0;
		break;

	case 1:	/* data port 0    */
		if (ym2612.addr_A1 != 0) {
			ret=0;
			break;	/* verified on real YM2608 */
		}

		addr = ym2612.OPN.ST.address;

		switch( addr & 0xf0 )
		{
		case 0x20:	/* 0x20-0x2f Mode */
			switch( addr )
			{
			case 0x22:	/* LFO FREQ (YM2608/YM2610/YM2610B/YM2612) */
				if (v&0x08) /* LFO enabled ? */
				{
					ym2612.OPN.lfo_inc = ym2612.OPN.lfo_freq[v&7];
				}
				else
				{
					ym2612.OPN.lfo_inc = 0;
				}
				break;
#if 0 // handled elsewhere
			case 0x24: { // timer A High 8
					int TAnew = (ym2612.OPN.ST.TA & 0x03)|(((int)v)<<2);
					if(ym2612.OPN.ST.TA != TAnew) {
						// we should reset ticker only if new value is written. Outrun requires this.
						ym2612.OPN.ST.TA = TAnew;
						ym2612.OPN.ST.TAC = (1024-TAnew)*18;
						ym2612.OPN.ST.TAT = 0;
					}
				}
				ret=0;
				break;
			case 0x25: { // timer A Low 2
					int TAnew = (ym2612.OPN.ST.TA & 0x3fc)|(v&3);
					if(ym2612.OPN.ST.TA != TAnew) {
						ym2612.OPN.ST.TA = TAnew;
						ym2612.OPN.ST.TAC = (1024-TAnew)*18;
						ym2612.OPN.ST.TAT = 0;
					}
				}
				ret=0;
				break;
			case 0x26: // timer B
				if(ym2612.OPN.ST.TB != v) {
					ym2612.OPN.ST.TB = v;
					ym2612.OPN.ST.TBC  = (256-v)<<4;
					ym2612.OPN.ST.TBC *= 18;
					ym2612.OPN.ST.TBT  = 0;
				}
				ret=0;
				break;
#endif
			case 0x27:	/* mode, timer control */
				set_timers( v );
				ret=0;
				break;
			case 0x28:	/* key on / off */
				{
					UINT8 c;

					c = v & 0x03;
					if( c == 3 ) { ret=0; break; }
					if( v&0x04 ) c+=3;
					if(v&0x10) FM_KEYON(c,SLOT1); else FM_KEYOFF(c,SLOT1);
					if(v&0x20) FM_KEYON(c,SLOT2); else FM_KEYOFF(c,SLOT2);
					if(v&0x40) FM_KEYON(c,SLOT3); else FM_KEYOFF(c,SLOT3);
					if(v&0x80) FM_KEYON(c,SLOT4); else FM_KEYOFF(c,SLOT4);
					break;
				}
			case 0x2a:	/* DAC data (YM2612) */
				ym2612.dacout = ((int)v - 0x80) << 6;	/* level unknown (notaz: 8 seems to be too much) */
				ret=0;
				break;
			case 0x2b:	/* DAC Sel  (YM2612) */
				/* b7 = dac enable */
				ym2612.dacen = v & 0x80;
				ret=0;
				break;
			default:
				break;
			}
			break;
		default:	/* 0x30-0xff OPN section */
			/* write register */
			ret = OPNWriteReg(addr,v);
		}
		break;

	case 2:	/* address port 1 */
		ym2612.OPN.ST.address = v;
		ym2612.addr_A1 = 1;
		ret=0;
		break;

	case 3:	/* data port 1    */
		if (ym2612.addr_A1 != 1) {
			ret=0;
			break;	/* verified on real YM2608 */
		}

		addr = ym2612.OPN.ST.address | 0x100;

		ret = OPNWriteReg(addr, v);
		break;
	}

	return ret;
}

#if 0
UINT8 YM2612Read_(void)
{
	return ym2612.OPN.ST.status;
}

int YM2612PicoTick_(int n)
{
	int ret = 0;

	// timer A
	if(ym2612.OPN.ST.mode & 0x01 && (ym2612.OPN.ST.TAT+=64*n) >= ym2612.OPN.ST.TAC) {
		ym2612.OPN.ST.TAT -= ym2612.OPN.ST.TAC;
		if(ym2612.OPN.ST.mode & 0x04) ym2612.OPN.ST.status |= 1;
		// CSM mode total level latch and auto key on
		if(ym2612.OPN.ST.mode & 0x80) {
			CSMKeyControll( &(ym2612.CH[2]) ); // Vectorman2, etc.
			ret = 1;
		}
	}

	// timer B
	if(ym2612.OPN.ST.mode & 0x02 && (ym2612.OPN.ST.TBT+=64*n) >= ym2612.OPN.ST.TBC) {
		ym2612.OPN.ST.TBT -= ym2612.OPN.ST.TBC;
		if(ym2612.OPN.ST.mode & 0x08) ym2612.OPN.ST.status |= 2;
	}

	return ret;
}
#endif

void YM2612PicoStateLoad_(void)
{
	reset_channels( &ym2612.CH[0] );
	ym2612.slot_mask = 0xffffff;
}

/* rather stupid design because I wanted to fit in unused register "space" */
typedef struct
{
	UINT32  state_phase;
	INT16   volume;
} ym_save_addon_slot;

typedef struct
{
	UINT32  magic;
	UINT8   address;
	UINT8   status;
	UINT8   addr_A1;
	UINT8   unused;
	int     TAT;
	int     TBT;
	UINT32  eg_cnt;		// 10
	UINT32  eg_timer;
	UINT32  lfo_cnt;
	UINT16  lfo_ampm;
	UINT16  unused2;
	UINT32  keyon_field;	// 20
	UINT32  kcode_fc_sl3_3;
	UINT32  reserved[2];
} ym_save_addon;

typedef struct
{
	UINT16  block_fnum[6];
	UINT16  block_fnum_sl3[3];
	UINT16  reserved[7];
} ym_save_addon2;


void YM2612PicoStateSave2(int tat, int tbt)
{
	ym_save_addon_slot ss;
	ym_save_addon2 sa2;
	ym_save_addon sa;
	unsigned char *ptr;
	int c, s;

	memset(&sa, 0, sizeof(sa));
	memset(&sa2, 0, sizeof(sa2));

	// chans 1,2,3
	ptr = &ym2612.REGS[0x0b8];
	for (c = 0; c < 3; c++)
	{
		for (s = 0; s < 4; s++) {
			ss.state_phase = (ym2612.CH[c].SLOT[s].state << 29) | (ym2612.CH[c].SLOT[s].phase >> 3);
			ss.volume = ym2612.CH[c].SLOT[s].volume;
			if (ym2612.CH[c].SLOT[s].key)
				sa.keyon_field |= 1 << (c*4 + s);
			memcpy(ptr, &ss, 6);
			ptr += 6;
		}
		sa2.block_fnum[c] = ym2612.CH[c].block_fnum;
	}
	// chans 4,5,6
	ptr = &ym2612.REGS[0x1b8];
	for (; c < 6; c++)
	{
		for (s = 0; s < 4; s++) {
			ss.state_phase = (ym2612.CH[c].SLOT[s].state << 29) | (ym2612.CH[c].SLOT[s].phase >> 3);
			ss.volume = ym2612.CH[c].SLOT[s].volume;
			if (ym2612.CH[c].SLOT[s].key)
				sa.keyon_field |= 1 << (c*4 + s);
			memcpy(ptr, &ss, 6);
			ptr += 6;
		}
		sa2.block_fnum[c] = ym2612.CH[c].block_fnum;
	}
	for (c = 0; c < 3; c++)
	{
		sa2.block_fnum_sl3[c] = ym2612.OPN.SL3.block_fnum[c];
	}

	memcpy(&ym2612.REGS[0], &sa2, sizeof(sa2)); // 0x20 max

	// other things
	ptr = &ym2612.REGS[0x100];
	sa.magic = 0x41534d59; // 'YMSA'
	sa.address = ym2612.OPN.ST.address;
	sa.status  = ym2612.OPN.ST.status;
	sa.addr_A1 = ym2612.addr_A1;
	sa.TAT     = tat;
	sa.TBT     = tbt;
	sa.eg_cnt  = ym2612.OPN.eg_cnt;
	sa.eg_timer = ym2612.OPN.eg_timer;
	sa.lfo_cnt  = ym2612.OPN.lfo_cnt;
	sa.lfo_ampm = g_lfo_ampm;
	memcpy(ptr, &sa, sizeof(sa)); // 0x30 max
}

int YM2612PicoStateLoad2(int *tat, int *tbt)
{
	ym_save_addon_slot ss;
	ym_save_addon2 sa2;
	ym_save_addon sa;
	unsigned char *ptr;
	UINT32 fn;
	UINT8 blk;
	int c, s;

	ptr = &ym2612.REGS[0x100];
	memcpy(&sa, ptr, sizeof(sa)); // 0x30 max
	if (sa.magic != 0x41534d59) return -1;

	ptr = &ym2612.REGS[0];
	memcpy(&sa2, ptr, sizeof(sa2));

	ym2612.OPN.ST.address = sa.address;
	ym2612.OPN.ST.status = sa.status;
	ym2612.addr_A1 = sa.addr_A1;
	ym2612.OPN.eg_cnt = sa.eg_cnt;
	ym2612.OPN.eg_timer = sa.eg_timer;
	ym2612.OPN.lfo_cnt = sa.lfo_cnt;
	g_lfo_ampm = sa.lfo_ampm;
	if (tat != NULL) *tat = sa.TAT;
	if (tbt != NULL) *tbt = sa.TBT;

	// chans 1,2,3
	ptr = &ym2612.REGS[0x0b8];
	for (c = 0; c < 3; c++)
	{
		for (s = 0; s < 4; s++) {
			memcpy(&ss, ptr, 6);
			ym2612.CH[c].SLOT[s].state = ss.state_phase >> 29;
			ym2612.CH[c].SLOT[s].phase = ss.state_phase << 3;
			ym2612.CH[c].SLOT[s].volume = ss.volume;
			ym2612.CH[c].SLOT[s].key = (sa.keyon_field & (1 << (c*4 + s))) ? 1 : 0;
			ym2612.CH[c].SLOT[s].ksr = (UINT8)-1;
			ptr += 6;
		}
		ym2612.CH[c].SLOT[SLOT1].Incr=-1;
		ym2612.CH[c].block_fnum = sa2.block_fnum[c];
		fn = ym2612.CH[c].block_fnum & 0x7ff;
		blk = ym2612.CH[c].block_fnum >> 11;
		ym2612.CH[c].kcode= (blk<<2) | opn_fktable[fn >> 7];
		ym2612.CH[c].fc = fn_table[fn*2]>>(7-blk);
	}
	// chans 4,5,6
	ptr = &ym2612.REGS[0x1b8];
	for (; c < 6; c++)
	{
		for (s = 0; s < 4; s++) {
			memcpy(&ss, ptr, 6);
			ym2612.CH[c].SLOT[s].state = ss.state_phase >> 29;
			ym2612.CH[c].SLOT[s].phase = ss.state_phase << 3;
			ym2612.CH[c].SLOT[s].volume = ss.volume;
			ym2612.CH[c].SLOT[s].key = (sa.keyon_field & (1 << (c*4 + s))) ? 1 : 0;
			ym2612.CH[c].SLOT[s].ksr = (UINT8)-1;
			ptr += 6;
		}
		ym2612.CH[c].SLOT[SLOT1].Incr=-1;
		ym2612.CH[c].block_fnum = sa2.block_fnum[c];
		fn = ym2612.CH[c].block_fnum & 0x7ff;
		blk = ym2612.CH[c].block_fnum >> 11;
		ym2612.CH[c].kcode= (blk<<2) | opn_fktable[fn >> 7];
		ym2612.CH[c].fc = fn_table[fn*2]>>(7-blk);
	}
	for (c = 0; c < 3; c++)
	{
		ym2612.OPN.SL3.block_fnum[c] = sa2.block_fnum_sl3[c];
		fn = ym2612.OPN.SL3.block_fnum[c] & 0x7ff;
		blk = ym2612.OPN.SL3.block_fnum[c] >> 11;
		ym2612.OPN.SL3.kcode[c]= (blk<<2) | opn_fktable[fn >> 7];
		ym2612.OPN.SL3.fc[c] = fn_table[fn*2]>>(7-blk);
	}

	return 0;
}

void *YM2612GetRegs(void)
{
	return ym2612.REGS;
}

