#ifndef _EMU2413_H_
#define _EMU2413_H_

#ifndef INLINE
#if defined(_MSC_VER)
#define INLINE __forceinline
#elif defined(__GNUC__)
#define INLINE __inline__
#elif defined(_MWERKS_)
#define INLINE inline
#else
#define INLINE
#endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef unsigned char uint8 ;
typedef signed char int8 ;

typedef unsigned short uint16 ;
typedef signed short int16 ;

typedef unsigned int uint32 ;
typedef signed int int32 ;

#define PI 3.14159265358979323846

enum { OPLL_VRC7_TONE=0 };

/* voice data */
typedef struct {
	uint32 TL, FB, EG, ML, AR, DR, SL, RR, KR, KL, AM, PM, WF;
} OPLL_PATCH;

/* slot */
typedef struct {
	OPLL_PATCH patch;

	int32 type;         /* 0 : modulator 1 : carrier */

	/* OUTPUT */
	int32 feedback;
	int32 output[2];  /* Output value of slot */

	/* for Phase Generator (PG) */
	uint16 *sintbl;   /* Wavetable */
	uint32 phase;     /* Phase */
	uint32 dphase;    /* Phase increment amount */
	uint32 pgout;     /* output */

	/* for Envelope Generator (EG) */
	int32 fnum;         /* F-Number */
	int32 block;        /* Block */
	int32 volume;       /* Current volume */
	int32 sustine;      /* Sustine 1 = ON, 0 = OFF */
	uint32 tll;             /* Total Level + Key scale level*/
	uint32 rks;       /* Key scale offset (Rks) */
	int32 eg_mode;      /* Current state */
	uint32 eg_phase;  /* Phase */
	uint32 eg_dphase; /* Phase increment amount */
	uint32 egout;     /* output */
} OPLL_SLOT;

/* Mask */
#define OPLL_MASK_CH(x) (1 << (x))

/* opll */
typedef struct {
	uint32 adr;
	int32 out;

	uint32 realstep;
	uint32 oplltime;
	uint32 opllstep;
	int32 prev, next;

	/* Register */
	uint8 LowFreq[6];
	uint8 HiFreq[6];
	uint8 InstVol[6];

	uint8 CustInst[8];

	int32 slot_on_flag[6 * 2];

	/* Pitch Modulator */
	uint32 pm_phase;
	int32 lfo_pm;

	/* Amp Modulator */
	int32 am_phase;
	int32 lfo_am;

	uint32 quality;

	/* Channel Data */
	int32 patch_number[6];
	int32 key_status[6];

	/* Slot */
	OPLL_SLOT slot[6 * 2];

	uint32 mask;
} OPLL;

/* Create Object */
OPLL *OPLL_new(uint32 clk, uint32 rate);
void OPLL_delete(OPLL *);

/* Setup */
void OPLL_reset(OPLL *);
void OPLL_set_rate(OPLL *opll, uint32 r);
void OPLL_set_quality(OPLL *opll, uint32 q);

/* Port/Register access */
void OPLL_writeIO(OPLL *, uint32 reg, uint32 val);
void OPLL_writeReg(OPLL *, uint32 reg, uint32 val);

/* Synthsize */
int16 OPLL_calc(OPLL *);

/* Misc */
void OPLL_forceRefresh(OPLL *);

/* Channel Mask */
uint32 OPLL_setMask(OPLL *, uint32 mask);
uint32 OPLL_toggleMask(OPLL *, uint32 mask);


void OPLL_fillbuf(OPLL* opll, int32 *buf, int32 len, int shift);

#ifdef __cplusplus
}
#endif

#endif
