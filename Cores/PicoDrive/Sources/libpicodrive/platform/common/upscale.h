/*
 * upscale.h		image upscaling
 *
 * This file contains upscalers for picodrive.
 *
 * scaler types:
 * nn:	nearest neighbour
 * snn:	"smoothed" nearest neighbour (see below)
 * bln:	n-level-bilinear with n quantized weights
 *	quantization: 0: a<1/(2*n), 1/n: 1/(2*n)<=a<3/(2*n), etc
 *	currently n=2, n=4 are implemented (there's n=8 mixing, but no filters)
 *	[NB this has been brought to my attn, which is probably the same as bl2:
 *	https://www.drdobbs.com/image-scaling-with-bresenham/184405045?pgno=1]
 *
 * "smoothed" nearest neighbour: uses the average of the source pixels if no
 *	source pixel covers more than 65% of the result pixel. It definitely
 *	looks better than nearest neighbour and is still quite fast. It creates
 *	a sharper look than a bilinear filter, at the price of some visible jags
 *	on diagonal edges.
 * 
 * example scaling modes:
 * 256x_Y_ -> 320x_Y_, H32/mode 4, PAR 5:4, for PAL DAR 4:3 (NTSC 7% aspect err)
 * 256x224 -> 320x240, H32/mode 4, PAR 5:4, for NTSC DAR 4:3 (PAL 7% aspect err)
 * 320x224 -> 320x240, PAR 1:1, for NTSC, DAR 4:3 (PAL 7% etc etc...)
 * 160x144 -> 320x240: GG, PAR 6:5, scaling to 320x240 for DAR 4:3
 *
 *
 * (C) 2021 irixxxx
 *
 * This work is licensed under the terms of any of these licenses
 * (at your option):
 *  - GNU GPL, version 2 or later.
 *  - MAME license.
 * See COPYING file in the top-level directory.
 */
#include <pico/pico_types.h>


/* LSB of all colors in 1 or 2 pixels */
#if defined(USE_BGR555)
#define PXLSB		0x04210421
#else
#define PXLSB		0x08210821
#endif

/* RGB565 pixel mixing, see https://www.compuphase.com/graphic/scale3.htm and
  			    http://blargg.8bitalley.com/info/rgb_mixing.html */
/* 2-level mixing. NB blargg version isn't 2-pixel-at-once safe for RGB565 */
//#define p_05(d,p1,p2)	d=(((p1)+(p2)  + ( ((p1)^(p2))&PXLSB))>>1) // round up
//#define p_05(d,p1,p2)	d=(((p1)+(p2)  - ( ((p1)^(p2))&PXLSB))>>1) // round down
#define p_05(d,p1,p2)	d=(((p1)&(p2)) + ((((p1)^(p2))&~PXLSB)>>1))
/* 4-level mixing, 2 times slower */
// 1/4*p1 + 3/4*p2 = 1/2*(1/2*(p1+p2) + p2)
#define p_025(d,p1,p2)	p_05(t, p1, p2); p_05( d, t, p2)
#define p_075(d,p1,p2)	p_025(d,p2,p1)
/* 8-level mixing, 3 times slower */
// 1/8*p1 + 7/8*p2 = 1/2*(1/2*(1/2*(p1+p2) + p2) + p2)
#define p_0125(d,p1,p2)	p_05(t, p1, p2); p_05( u, t, p2); p_05( d, u, p2)
// 3/8*p1 + 5/8*p2 = 1/2*(1/2*(1/2*(p1+p2) + p2) + 1/2*(p1+p2))
#define p_0375(d,p1,p2)	p_05(t, p1, p2); p_05( u, t, p2); p_05( d, u,  t)
#define p_0625(d,p1,p2)	p_0375(d,p2,p1)
#define p_0875(d,p1,p2)	p_0125(d,p2,p1)

/* pixel transforms */
#define	f_pal(v)	pal[v]	// convert CLUT index -> RGB565
#define f_nop(v)	(v)	// source already in dest format (CLUT/RGB)
#define f_or(v)		(v|pal)	// CLUT, add palette selection

/*
scalers h:
256->320:       - (4:5)         (256x224/240 -> 320x224/240)
256->299:	- (6:7)		(256x224 -> 299x224, alt?)
160->320:       - (1:2) 2x      (160x144 -> 320x240, GG)
160->288:	- (5:9)		(160x144 -> 288x216, GG alt?)
*/

/* scale 4:5 */
#define h_upscale_nn_4_5(di,ds,si,ss,w,f) do {		\
	int i;						\
	for (i = w/4; i > 0; i--, si += 4, di += 5) {	\
		di[0] = f(si[0]);			\
		di[1] = f(si[1]);			\
		di[2] = f(si[1]);			\
		di[3] = f(si[2]);			\
		di[4] = f(si[3]);			\
	}						\
	di += ds - w/4*5;				\
	si += ss - w;					\
} while (0)

// reverse version for overlapping buffers
#define rh_upscale_nn_4_5(di,ds,si,ss,w,f) do {	\
	int i;						\
	di += w/4*5;					\
	si += w;					\
	for (i = w/4; i > 0; i--, si -= 4, di -= 5) {	\
		di[-1] = f(si[-1]);			\
		di[-2] = f(si[-2]);			\
		di[-3] = f(si[-3]);			\
		di[-4] = f(si[-3]);			\
		di[-5] = f(si[-4]);			\
	}						\
	di += ds;					\
	si += ss;					\
} while (0)

#define h_upscale_snn_4_5(di,ds,si,ss,w,f) do {		\
	int i;						\
	for (i = w/4; i > 0; i--, si += 4, di += 5) {	\
		di[0] = f(si[0]);			\
		di[1] = f(si[1]);			\
		p_05(di[2], f(si[1]),f(si[2]));		\
		di[3] = f(si[2]);			\
		di[4] = f(si[3]);			\
	}						\
	di += ds - w/4*5;				\
	si += ss - w;					\
} while (0)

#define h_upscale_bln_4_5(di,ds,si,ss,w,f) do {		\
	int i; u16 t; 					\
	for (i = w/4; i > 0; i--, si += 4, di += 5) {	\
		di[0] = f(si[0]);			\
		p_025(di[1], f(si[0]),f(si[1]));	\
		p_05 (di[2], f(si[1]),f(si[2]));	\
		p_075(di[3], f(si[2]),f(si[3]));	\
		di[4] = f(si[3]);			\
	}						\
	di += ds - w/4*5;				\
	si += ss - w;					\
} while (0)

#define h_upscale_bl2_4_5(di,ds,si,ss,w,f) do {		\
	int i;						\
	for (i = w/4; i > 0; i--, si += 4, di += 5) {	\
		di[0] = f(si[0]);			\
		p_05(di[1], f(si[0]),f(si[1]));		\
		p_05(di[2], f(si[1]),f(si[2]));		\
		di[3] = f(si[2]);			\
		di[4] = f(si[3]);			\
	}						\
	di += ds - w/4*5;				\
	si += ss - w;					\
} while (0)

#define h_upscale_bl4_4_5(di,ds,si,ss,w,f) do {		\
	int i; u16 t, p = f(si[0]);			\
	for (i = w/4; i > 0; i--, si += 4, di += 5) {	\
		p_025(di[0], p,       f(si[0]));	\
		p_05 (di[1], f(si[0]),f(si[1]));	\
		p_05 (di[2], f(si[1]),f(si[2]));	\
		p_075(di[3], f(si[2]),f(si[3]));	\
		di[4] = p = f(si[3]);			\
	}						\
	di += ds - w/4*5;				\
	si += ss - w;					\
} while (0)

#define h_upscale_bl8_4_5(di,ds,si,ss,w,f) do {		\
	int i; u16 t, u, p = f(si[0]);			\
	for (i = w/4; i > 0; i--, si += 4, di += 5) {	\
		p_025 (di[0], p,       f(si[0]));	\
		p_0375(di[1], f(si[0]),f(si[1]));	\
		p_0625(di[2], f(si[1]),f(si[2]));	\
		p_075 (di[3], f(si[2]),f(si[3]));	\
		di[4] = p = f(si[3]);			\
	}						\
	di += ds - w/4*5;				\
	si += ss - w;					\
} while (0)

/* scale 6:7 */
#define h_upscale_nn_6_7(di,ds,si,ss,w,f) do {		\
	int i;						\
	for (i = w/6; i > 0; i--, si += 6, di += 7) {	\
		di[0] = f(si[0]);			\
		di[1] = f(si[1]);			\
		di[2] = f(si[2]);			\
		di[3] = f(si[2]);			\
		di[4] = f(si[3]);			\
		di[5] = f(si[4]);			\
		di[6] = f(si[5]);			\
	}						\
	di += ds - w/6*7;				\
	si += ss - w;					\
} while (0)

// reverse version for overlapping buffers
#define rh_upscale_nn_6_7(di,ds,si,ss,w,f) do {	\
	int i;						\
	di += w/6*7;					\
	si += w;					\
	for (i = w/6; i > 0; i--, si -= 6, di -= 7) {	\
		di[-1] = f(si[-1]);			\
		di[-2] = f(si[-2]);			\
		di[-3] = f(si[-3]);			\
		di[-4] = f(si[-4]);			\
		di[-5] = f(si[-4]);			\
		di[-6] = f(si[-5]);			\
		di[-7] = f(si[-6]);			\
	}						\
	di += ds;					\
	si += ss;					\
} while (0)

#define h_upscale_snn_6_7(di,ds,si,ss,w,f) do {		\
	int i;						\
	for (i = w/6; i > 0; i--, si += 6, di += 7) {	\
		di[0] = f(si[0]);			\
		di[1] = f(si[1]);			\
		di[2] = f(si[2]);			\
		p_05(di[3], f(si[2]),f(si[3]));		\
		di[4] = f(si[3]);			\
		di[5] = f(si[4]);			\
		di[6] = f(si[5]);			\
	}						\
	di += ds - w/6*7;				\
	si += ss - w;					\
} while (0)

#define h_upscale_bl2_6_7(di,ds,si,ss,w,f) do {		\
	int i;						\
	for (i = w/6; i > 0; i--, si += 6, di += 7) {	\
		di[0] = f(si[0]);			\
		p_05(di[1], f(si[0]),f(si[1]));		\
		p_05(di[2], f(si[1]),f(si[2]));		\
		p_05(di[3], f(si[2]),f(si[3]));		\
		p_05(di[4], f(si[3]),f(si[4]));		\
		di[5] = f(si[4]);			\
		di[6] = f(si[5]);			\
	}						\
	di += ds - w/6*7;				\
	si += ss - w;					\
} while (0)

#define h_upscale_bl4_6_7(di,ds,si,ss,w,f) do {		\
	int i; u16 t p = f(si[0]);			\
	for (i = w/6; i > 0; i--, si += 6, di += 7) {	\
		p_025(di[0], p,       f(si[0]));	\
		p_025(di[1], f(si[0]),f(si[1]));	\
		p_05 (di[2], f(si[1]),f(si[2]));	\
		p_05 (di[3], f(si[2]),f(si[3]));	\
		p_075(di[4], f(si[3]),f(si[4]));	\
		p_075(di[5], f(si[4]),f(si[5]));	\
		di[6] = p = f(si[5]);			\
	}						\
	di += ds - w/6*7;				\
	si += ss - w;					\
} while (0)

/* scale 5:9 */
#define h_upscale_nn_5_9(di,ds,si,ss,w,f) do {		\
	int i;						\
	for (i = w/5; i > 0; i--, si += 5, di += 9) {	\
		di[0] = f(si[0]);			\
		di[1] = f(si[0]);			\
		di[2] = f(si[1]);			\
		di[3] = f(si[1]);			\
		di[4] = f(si[2]);			\
		di[5] = f(si[3]);			\
		di[6] = f(si[3]);			\
		di[7] = f(si[4]);			\
		di[8] = f(si[4]);			\
	}						\
	di += ds - w/5*9;				\
	si += ss - w;					\
} while (0)

#define h_upscale_snn_5_9(di,ds,si,ss,w,f) do {		\
	int i;						\
	for (i = w/5; i > 0; i--, si += 5, di += 9) {	\
		di[0] = f(si[0]);			\
		di[1] = f(si[0]);			\
		di[2] = f(si[1]);			\
		p_05(di[3], f(si[1]),f(si[2]));		\
		di[4] = f(si[2]);			\
		p_05(di[5], f(si[2]),f(si[3]));		\
		di[6] = f(si[3]);			\
		di[7] = f(si[4]);			\
		di[8] = f(si[4]);			\
	}						\
	di += ds - w/5*9;				\
	si += ss - w;					\
} while (0)

#define h_upscale_bl2_5_9(di,ds,si,ss,w,f) do {		\
	int i;						\
	for (i = w/5; i > 0; i--, si += 5, di += 9) {	\
		di[0] = f(si[0]);			\
		p_05(di[1], f(si[0]),f(si[1]));		\
		di[2] = f(si[1]);			\
		p_05(di[3], f(si[1]),f(si[2]));		\
		di[4] = f(si[2]);			\
		p_05(di[5], f(si[2]),f(si[3]));		\
		di[6] = f(si[3]);			\
		p_05(di[7], f(si[3]),f(si[4]));		\
		di[8] = f(si[4]);			\
	}						\
	di += ds - w/5*9;				\
	si += ss - w;					\
} while (0)

#define h_upscale_bl4_5_9(di,ds,si,ss,w,f) do {		\
	int i; u16 t, p = f(si[0]);			\
	for (i = w/5; i > 0; i--, si += 5, di += 9) {	\
		p_05 (di[0], p,       f(si[0]));	\
		di[1] = f(si[0]);			\
		p_025(di[2], f(si[0]),f(si[1]));	\
		p_075(di[3], f(si[1]),f(si[2]));	\
		p_025(di[4], f(si[1]),f(si[2]));	\
		p_075(di[5], f(si[2]),f(si[3]));	\
		di[6] = f(si[3]);			\
		p_05 (di[7], f(si[3]),f(si[4]));	\
		di[8] = p = f(si[4]);			\
	}						\
	di += ds - w/5*9;				\
	si += ss - w;					\
} while (0)

/* scale 1:2 integer scale */
#define h_upscale_nn_1_2(di,ds,si,ss,w,f) do {		\
	int i;						\
	for (i = w/2; i > 0; i--, si += 2, di += 4) {	\
		di[0] = f(si[0]);			\
		di[1] = f(si[0]);			\
		di[2] = f(si[1]);			\
		di[3] = f(si[1]);			\
	}						\
	di += ds - w*2;					\
	si += ss - w;					\
} while (0)

// reverse version for overlapping buffers
#define rh_upscale_nn_1_2(di,ds,si,ss,w,f) do {	\
	int i;						\
	di += w*2;					\
	si += w;					\
	for (i = w/2; i > 0; i--, si -= 2, di -= 4) {	\
		di[-1] = f(si[-1]);			\
		di[-2] = f(si[-1]);			\
		di[-3] = f(si[-2]);			\
		di[-4] = f(si[-2]);			\
	}						\
	di += ds;					\
	si += ss;					\
} while (0)

#define h_upscale_bl2_1_2(di,ds,si,ss,w,f) do {		\
	int i; uint p = f(si[0]);			\
	for (i = w/2; i > 0; i--, si += 2, di += 4) {	\
		p_05 (di[0], p,       f(si[0]));	\
		di[1] = f(si[0]);			\
		p_05 (di[2], f(si[0]),f(si[1]));	\
		di[3] = p = f(si[1]);			\
	}						\
	di += ds - w*2;					\
	si += ss - w;					\
} while (0)

/* scale 1:1, copy */
#define h_copy(di,ds,si,ss,w,f) do {			\
	int i;						\
	for (i = w/4; i > 0; i--, si += 4, di += 4) {	\
		di[0] = f(si[0]);			\
		di[1] = f(si[1]);			\
		di[2] = f(si[2]);			\
		di[3] = f(si[3]);			\
	}						\
	di += ds - w;					\
	si += ss - w;					\
} while (0)

/*
scalers v:
224->240:       - (14:15)       (256/320x224 -> 320x240)
224->238:       - (16:17)       (256/320x224 -> 320x238 alt?)
144->240:       - (3:5)         (160x144 -> 320x240, GG)
144->216:	- (2:3)		(160x144 -> 288x216, GG alt?)
*/

#define v_mix(di,li,ri,w,p_mix,f) do {			\
	int i; u32 t, u; (void)t, (void)u;		\
	for (i = 0; i < w; i += 4) {			\
		p_mix((di)[i  ], f((li)[i  ]),f((ri)[i  ])); \
		p_mix((di)[i+1], f((li)[i+1]),f((ri)[i+1])); \
		p_mix((di)[i+2], f((li)[i+2]),f((ri)[i+2])); \
		p_mix((di)[i+3], f((li)[i+3]),f((ri)[i+3])); \
	}						\
} while (0)

#define v_copy(di,ri,w,f) do {				\
	int i;						\
	for (i = 0; i < w; i += 4) {			\
		(di)[i  ] = f((ri)[i  ]);		\
		(di)[i+1] = f((ri)[i+1]);		\
		(di)[i+2] = f((ri)[i+2]);		\
		(di)[i+3] = f((ri)[i+3]);		\
	}						\
} while (0)

/* scale 14:15 */
#define v_upscale_nn_14_15(di,ds,w,l) do {		\
	if (++l == 7) {					\
		di += ds; 				\
	} else if (l >= 14) {				\
		l = 0;					\
		di -= 7*ds;				\
		v_copy(&di[0], &di[-ds], w, f_nop);	\
		di += 7*ds;				\
	}						\
} while (0)

#define v_upscale_snn_14_15(di,ds,w,l) do {		\
	if (++l == 7) {					\
		di += ds; 				\
	} else if (l >= 14) {				\
		l = 0;					\
		di -= 7*ds;				\
		v_mix(&di[0], &di[-ds], &di[ds], w, p_05, f_nop); \
		v_mix(&di[-ds], &di[-2*ds], &di[-ds], w, p_05, f_nop); \
		v_mix(&di[ ds], &di[ ds], &di[ 2*ds], w, p_05, f_nop); \
		di += 7*ds;				\
	}						\
} while (0)

#define v_upscale_bl2_14_15(di,ds,w,l) do {		\
	if (++l == 3) {					\
		di += ds; 				\
	} else if (l >= 14) {				\
		int j;					\
		l = 0;					\
		di -= 11*ds;				\
			v_mix(&di[0], &di[-ds], &di[ds], w, p_05, f_nop); \
		for (j = 0; j < 7; j++)	{		\
			di += ds;			\
			v_mix(&di[0], &di[0], &di[ds], w, p_05, f_nop); \
		}					\
		di += 4*ds;				\
	}						\
} while (0)

#define v_upscale_bl4_14_15(di,ds,w,l) do {		\
	if (++l == 1) {					\
		di += ds; 				\
	} else if (l >= 14) {				\
		int j;					\
		l = 0;					\
		di -= 13*ds;				\
			v_mix(&di[0], &di[-ds], &di[ds], w, p_025, f_nop); \
			di += ds;			\
		for (j = 0; j < 3; j++) {		\
			v_mix(&di[0], &di[0], &di[ds], w, p_025, f_nop); \
			di += ds;			\
			}				\
		for (j = 0; j < 4; j++) {		\
			v_mix(&di[0], &di[0], &di[ds], w, p_05, f_nop); \
			di += ds;			\
		}					\
		for (j = 0; j < 4; j++) {		\
			v_mix(&di[0], &di[0], &di[ds], w, p_075, f_nop); \
			di += ds;			\
		}					\
		di += 1*ds;				\
	}						\
} while (0)

/* scale 16:17 */
#define v_upscale_nn_16_17(di,ds,w,l) do {		\
	if (++l == 8) {					\
		di += ds; 				\
	} else if (l >= 16) {				\
		l = 0;					\
		di -= 8*ds;				\
		v_copy(&di[0], &di[-ds], w, f_nop);	\
		di += 8*ds;				\
	}						\
} while (0)

#define v_upscale_snn_16_17(di,ds,w,l) do {		\
	if (++l == 8) {					\
		di += ds; 				\
	} else if (l >= 16) {				\
		l = 0;					\
		di -= 8*ds;				\
		v_mix(&di[0], &di[-ds], &di[ds], w, p_05, f_nop); \
		v_mix(&di[-ds], &di[-2*ds], &di[-ds], w, p_05, f_nop); \
		v_mix(&di[ ds], &di[ ds], &di[ 2*ds], w, p_05, f_nop); \
		di += 8*ds;				\
	}						\
} while (0)

#define v_upscale_bl2_16_17(di,ds,w,l) do {		\
	if (++l == 4) {					\
		di += ds; 				\
	} else if (l >= 16) {				\
		int j;					\
		l = 0;					\
		di -= 12*ds;				\
			v_mix(&di[0], &di[-ds], &di[ds], w, p_05, f_nop); \
		for (j = 0; j < 7; j++)	{		\
			di += ds;			\
			v_mix(&di[0], &di[0], &di[ds], w, p_05, f_nop); \
		}					\
		di += 5*ds;				\
	}						\
} while (0)

#define v_upscale_bl4_16_17(di,ds,w,l) do {		\
	if (++l == 2) {					\
		di += ds; 				\
	} else if (l >= 16) {				\
		int j;					\
		l = 0;					\
		di -= 14*ds;				\
			v_mix(&di[0], &di[-ds], &di[ds], w, p_025, f_nop); \
			di += ds;			\
		for (j = 0; j < 3; j++) {		\
			v_mix(&di[0], &di[0], &di[ds], w, p_025, f_nop); \
			di += ds;			\
			}				\
		for (j = 0; j < 4; j++) {		\
			v_mix(&di[0], &di[0], &di[ds], w, p_05, f_nop); \
			di += ds;			\
		}					\
		for (j = 0; j < 4; j++) {		\
			v_mix(&di[0], &di[0], &di[ds], w, p_075, f_nop); \
			di += ds;			\
		}					\
		di += 2*ds;				\
	}						\
} while (0)

/* scale 3:5 */
#define v_upscale_nn_3_5(di,ds,w,l) do {		\
	if (++l < 3) {					\
		di += ds; 				\
	} else  {					\
		int j;					\
		l = 0;					\
		di -= 3*ds;				\
		for (j = 0; j < 2; j++) {		\
			v_copy(&di[0], &di[-ds], w, f_nop); \
			di += 2*ds;			\
		}					\
		di -= ds;			\
	}						\
} while (0)

#define v_upscale_snn_3_5(di,ds,w,l) do {		\
	if (++l < 3) {					\
		di += ds; 				\
	} else  {					\
		int j;					\
		l = 0;					\
		di -= 3*ds;				\
		for (j = 0; j < 2; j++) {		\
			v_mix(&di[0], &di[-ds], &di[ds], w, p_05, f_nop); \
			di += 2*ds;			\
		}					\
		di -= ds;			\
	}						\
} while (0)

/* scale 2:3 */
#define v_upscale_nn_2_3(di,ds,w,l) do {		\
	if (++l < 2) {					\
		di += ds; 				\
	} else  {					\
		int j;					\
		l = 0;					\
		di -= 2*ds;				\
		v_copy(&di[0], &di[-ds], w, f_nop);	\
		di += 2*ds;				\
	}						\
} while (0)

#define v_upscale_snn_2_3(di,ds,w,l) do {		\
	if (++l < 2) {					\
		di += ds; 				\
	} else  {					\
		int j;					\
		l = 0;					\
		di -= 2*ds;				\
		v_mix(&di[0], &di[-ds], &di[ds], w, p_05, f_nop); \
		di += 2*ds;				\
	}						\
} while (0)


/* exponentially smoothing (for LCD ghosting): y[n] = x[n]*a + y[n-1]*(1-a) */

#define PXLSBn (PXLSB*15) // using 4 LSBs of each subpixel for subtracting
// NB implement rounding to x[n] by adding 1 to counter round down if y[n] is
// smaller than x[n]: use some of the lower bits to implement subtraction on
// subpixels, with an additional bit to detect borrow, then add the borrow.
// It's doing the increment wrongly in a lot of cases, which doesn't matter
// much since it will converge to x[n] in a few frames anyway if x[n] is static
#define p_05_round(d,p1,p2)				\
	p_05(u, p1, p2);				\
	t=(u|~PXLSBn)-(p1&PXLSBn); d = u+(~(t>>4)&PXLSB)
// Unfortunately this won't work for p_025, where adding 1 isn't enough and
// adding 2 would be too much, so offer only p_075 here
#define p_075_round(d,p1,p2)				\
	p_075(u, p1, p2);				\
	t=(u|~PXLSBn)-(p1&PXLSBn); d = u+(~(t>>4)&PXLSB)

// this is essentially v_mix and v_copy combined
#define v_blend(di,ri,w,p_mix) do {			\
	int i; u32 t, u; (void)t, (void)u;		\
	for (i = 0; i < w; i += 4) {			\
		p_mix((ri)[i  ], (di)[i  ],(ri)[i  ]); (di)[i  ] = (ri)[i  ]; \
		p_mix((ri)[i+1], (di)[i+1],(ri)[i+1]); (di)[i+1] = (ri)[i+1]; \
		p_mix((ri)[i+2], (di)[i+2],(ri)[i+2]); (di)[i+2] = (ri)[i+2]; \
		p_mix((ri)[i+3], (di)[i+3],(ri)[i+3]); (di)[i+3] = (ri)[i+3]; \
	}						\
} while (0)


/* X x Y -> X*5/4 x Y, for X 256->320 */
void upscale_rgb_nn_x_4_5(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal);
void upscale_rgb_snn_x_4_5(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal);
void upscale_rgb_bl2_x_4_5(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal);
void upscale_rgb_bl4_x_4_5(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal);

/* X x Y -> X x Y*17/16, for Y 224->238 or 192->204 (SMS) */
void upscale_rgb_nn_y_16_17(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal);
void upscale_rgb_snn_y_16_17(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal);
void upscale_rgb_bl2_y_16_17(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal);
void upscale_rgb_bl4_y_16_17(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal);

/* X x Y -> X*5/4 x Y*17/16 */
void upscale_rgb_nn_x_4_5_y_16_17(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal);
void upscale_rgb_snn_x_4_5_y_16_17(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal);
void upscale_rgb_bl2_x_4_5_y_16_17(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal);
void upscale_rgb_bl4_x_4_5_y_16_17(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal);

/* X x Y -> X*2/1 x Y, e.g. for X 160->320 (GG) */
void upscale_rgb_nn_x_1_2(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal);
void upscale_rgb_bl2_x_1_2(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal);

/* X x Y -> X x Y*5/3, e.g. for Y 144->240 (GG) */
void upscale_rgb_nn_y_3_5(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal);
void upscale_rgb_bl2_y_3_5(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal);
void upscale_rgb_bl4_y_3_5(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal);

/* X x Y -> X*2/1 x Y*5/3 (GG) */
void upscale_rgb_nn_x_1_2_y_3_5(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal);
void upscale_rgb_bl2_x_1_2_y_3_5(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal);
void upscale_rgb_bl4_x_1_2_y_3_5(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal);

