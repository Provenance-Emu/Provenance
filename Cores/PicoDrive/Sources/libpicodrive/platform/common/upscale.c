/*
 * upscale.c		image upscaling
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
 * (C) 2021 irixxxx
 *
 * This work is licensed under the terms of any of these licenses
 * (at your option):
 *  - GNU GPL, version 2 or later.
 *  - MAME license.
 */

#include "upscale.h"

/* X x Y -> X*5/4 x Y */
void upscale_clut_nn_x_4_5(u8 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height)
{
	int y;

	for (y = 0; y < height; y++) {
		h_upscale_nn_4_5(di, ds, si, ss, width, f_nop);
	}
}

void upscale_rgb_nn_x_4_5(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal)
{
	int y;

	for (y = 0; y < height; y++) {
		h_upscale_nn_4_5(di, ds, si, ss, width, f_pal);
	}
}

void upscale_rgb_snn_x_4_5(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal)
{
	int y;

	for (y = 0; y < height; y++) {
		h_upscale_snn_4_5(di, ds, si, ss, width, f_pal);
	}
}

void upscale_rgb_bl2_x_4_5(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal)
{
	int y;

	for (y = 0; y < height; y++) {
		h_upscale_bl2_4_5(di, ds, si, ss, width, f_pal);
	}
}

void upscale_rgb_bl4_x_4_5(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal)
{
	int y;

	for (y = 0; y < height; y++) {
		h_upscale_bl4_4_5(di, ds, si, ss, width, f_pal);
	}
}

/* X x Y -> X*5/4 x Y*17/16 */
void upscale_clut_nn_x_4_5_y_16_17(u8 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height)
{
	int swidth = width * 5/4;
	int y, j;

	for (y = 0; y < height; y += 16) {
		for (j = 0; j < 8; j++) {
			h_upscale_nn_4_5(di, ds, si, ss, width, f_nop);
		}
		di +=  ds;
		for (j = 0; j < 8; j++) {
			h_upscale_nn_4_5(di, ds, si, ss, width, f_nop);
		}

		di -= 9*ds;
		v_copy(&di[0], &di[-ds], swidth, f_nop);
		di += 9*ds;
	}
}

void upscale_rgb_nn_x_4_5_y_16_17(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal)
{
	int swidth = width * 5/4;
	int y, j;

	for (y = 0; y < height; y += 16) {
		for (j = 0; j < 8; j++) {
			h_upscale_nn_4_5(di, ds, si, ss, width, f_pal);
		}
		di +=  ds;
		for (j = 0; j < 8; j++) {
			h_upscale_nn_4_5(di, ds, si, ss, width, f_pal);
		}

		di -= 9*ds;
		v_copy(&di[0], &di[-ds], swidth, f_nop);
		di += 9*ds;
	}
}

void upscale_rgb_snn_x_4_5_y_16_17(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal)
{
	int swidth = width * 5/4;
	int y, j;

	for (y = 0; y < height; y += 16) {
		for (j = 0; j < 8; j++) {
			h_upscale_snn_4_5(di, ds, si, ss, width, f_pal);
		}
		di +=  ds;
		for (j = 0; j < 8; j++) {
			h_upscale_snn_4_5(di, ds, si, ss, width, f_pal);
		}

		/* mix lines 6-8 */
		di -= 9*ds;
		v_mix(&di[0], &di[-ds], &di[ds], swidth, p_05, f_nop);
		v_mix(&di[-ds], &di[-2*ds], &di[-ds], swidth, p_05, f_nop);
		v_mix(&di[ ds], &di[ ds], &di[ 2*ds], swidth, p_05, f_nop);
		di += 9*ds;
	}
}

void upscale_rgb_bl2_x_4_5_y_16_17(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal)
{
	int swidth = width * 5/4;
	int y, j;

	for (y = 0; y < height; y += 16) {
		for (j = 0; j < 4; j++) {
			h_upscale_bl2_4_5(di, ds, si, ss, width, f_pal);
		}
		di +=  ds;
		for (j = 0; j < 12; j++) {
			h_upscale_bl2_4_5(di, ds, si, ss, width, f_pal);
		}
		/* mix lines 3-10 */
		di -= 13*ds;
			v_mix(&di[0], &di[-ds], &di[ds], swidth, p_05, f_nop);
		for (j = 0; j < 7; j++) {
			di += ds;
			v_mix(&di[0], &di[0], &di[ds], swidth, p_05, f_nop);
		}
		di += 6*ds;
	}
}

void upscale_rgb_bl4_x_4_5_y_16_17(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal)
{
	int swidth = width * 5/4;
	int y, j;

	for (y = 0; y < height; y += 16) {
		for (j = 0; j < 2; j++) {
			h_upscale_bl4_4_5(di, ds, si, ss, width, f_pal);
		}
		di += ds;
		for (j = 0; j < 14; j++) {
			h_upscale_bl4_4_5(di, ds, si, ss, width, f_pal);
		}
		di -= 15*ds;
		/* mixing line 2: line 1 = -ds, line 2 = +ds */
			v_mix(&di[0], &di[-ds], &di[ds], swidth, p_025, f_nop);
			di += ds;
		/* mixing lines 3-5: line n-1 = 0, line n = +ds */
		for (j = 0; j < 3; j++) {
			v_mix(&di[0], &di[0], &di[ds], swidth, p_025, f_nop);
			di += ds;
			}
		/* mixing lines 6-9 */
		for (j = 0; j < 4; j++) {
			v_mix(&di[0], &di[0], &di[ds], swidth, p_05, f_nop);
			di += ds;
		}
		/* mixing lines 10-13 */
		for (j = 0; j < 4; j++) {
			v_mix(&di[0], &di[0], &di[ds], swidth, p_075, f_nop);
			di += ds;
		}
		/* lines 14-16, already in place */
		di += 3*ds;
	}
}

/* "classic" upscaler as found in several emulators. It's really more like a
 * x*4/3, y*16/15 upscaler, with an additional 5th row/17th line just inserted
 * from the source image. That gives nice n/4,n/16 alpha values plus better
 * symmetry in each block and avoids "borrowing" a row/line between blocks.
 */
void upscale_rgb_bln_x_4_5_y_16_17(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal)
{
	int swidth = width * 5/4;
	int y, j;

	for (y = 0; y < height; y += 16) {
		for (j = 0; j < 4; j++) {
			h_upscale_bln_4_5(di, ds, si, ss, width, f_pal);
		}
		di += ds;
		for (j = 0; j < 12; j++) {
			h_upscale_bln_4_5(di, ds, si, ss, width, f_pal);
		}
		di -= 13*ds;
		/* mixing line 4: line 3 = -ds, line 4 = +ds */
			v_mix(&di[0], &di[-ds], &di[ds], swidth, p_025, f_nop);
			di += ds;
		/* mixing lines 5-6: line n-1 = 0, line n = +ds */
		for (j = 0; j < 2; j++) {
			v_mix(&di[0], &di[0], &di[ds], swidth, p_025, f_nop);
			di += ds;
			}
		/* mixing line 7-9 */
		for (j = 0; j < 3; j++) {
			v_mix(&di[0], &di[0], &di[ds], swidth, p_05, f_nop);
			di += ds;
		}
		/* mixing lines 10-12 */
		for (j = 0; j < 3; j++) {
			v_mix(&di[0], &di[0], &di[ds], swidth, p_075, f_nop);
			di += ds;
		}
		/* lines 13-16, already in place */
		di += 4*ds;
	}
}

/* experimental 8 level bilinear for quality assessment */
void upscale_rgb_bl8_x_4_5_y_16_17(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal)
{
	int swidth = width * 5/4;
	int y, j;

	for (y = 0; y < 224; y += 16) {
		for (j = 0; j < 2; j++) {
			h_upscale_bl8_4_5(di, ds, si, ss, width, f_pal);
		}
		di += ds;
		for (j = 0; j < 14; j++) {
			h_upscale_bl8_4_5(di, ds, si, ss, width, f_pal);
		}
		di -= 15*ds;
		/* mixing line 2: line 2 = -ds, line 3 = +ds */
			v_mix(&di[0], &di[-ds], &di[ds], swidth, p_0125, f_nop);
			di += ds;
		/* mixing line 3: line 3 = 0, line 4 = +ds */
			v_mix(&di[0], &di[0], &di[ds], swidth, p_0125, f_nop);
			di += ds;
		/* mixing lines 4-5: line n-1 = 0, line n = +ds */
		for (j = 0; j < 2; j++) {
			v_mix(&di[0], &di[0], &di[ds], swidth, p_025, f_nop);
			di += ds;
			}
		/* mixing lines 6-7 */
		for (j = 0; j < 2; j++) {
			v_mix(&di[0], &di[0], &di[ds], 320, p_0375, f_nop);
			di += ds;
		}
		/* mixing lines 8-9 */
		for (j = 0; j < 2; j++) {
			v_mix(&di[0], &di[0], &di[ds], 320, p_05, f_nop);
			di += ds;
		}
		/* mixing lines 10-11 */
		for (j = 0; j < 2; j++) {
			v_mix(&di[0], &di[0], &di[ds], 320, p_0625, f_nop);
			di += ds;
		}
		/* mixing lines 12-13 */
		for (j = 0; j < 2; j++) {
			v_mix(&di[0], &di[0], &di[ds], 320, p_075, f_nop);
			di += ds;
		}
		/* mixing lines 14-15 */
		for (j = 0; j < 2; j++) {
			v_mix(&di[0], &di[0], &di[ds], 320, p_0875, f_nop);
			di += ds;
		}
		/* line 16, already in place */
		di += ds;
	}
}

/* X x Y -> X x Y*17/16 */
void upscale_clut_nn_y_16_17(u8 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height)
{
	int y, j;

	for (y = 0; y < height; y += 16) {
		for (j = 0; j < 8; j++) {
			h_copy(di, ds, si, ss, width, f_nop);
		}
		di +=  ds;
		for (j = 0; j < 8; j++) {
			h_copy(di, ds, si, ss, width, f_nop);
		}

		di -= 9*ds;
		v_copy(&di[0], &di[-ds], width, f_nop);
		di += 9*ds;
	}
}

void upscale_rgb_nn_y_16_17(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal)
{
	int y, j;

	for (y = 0; y < height; y += 16) {
		for (j = 0; j < 8; j++) {
			h_copy(di, ds, si, ss, width, f_pal);
		}
		di +=  ds;
		for (j = 0; j < 8; j++) {
			h_copy(di, ds, si, ss, width, f_pal);
		}

		di -= 9*ds;
		v_copy(&di[0], &di[-ds], width, f_nop);
		di += 9*ds;
	}
}

void upscale_rgb_snn_y_16_17(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal)
{
	int y, j;

	for (y = 0; y < height; y += 16) {
		for (j = 0; j < 8; j++) {
			h_copy(di, ds, si, ss, width, f_pal);
		}
		di +=  ds;
		for (j = 0; j < 8; j++) {
			h_copy(di, ds, si, ss, width, f_pal);
		}

		/* mix lines 6-8 */
		di -= 9*ds;
		v_mix(&di[0], &di[-ds], &di[ds], width, p_05, f_nop);
		v_mix(&di[-ds], &di[-2*ds], &di[-ds], width, p_05, f_nop);
		v_mix(&di[ ds], &di[ ds], &di[ 2*ds], width, p_05, f_nop);
		di += 9*ds;
	}
}

void upscale_rgb_bl2_y_16_17(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal)
{
	int y, j;

	for (y = 0; y < height; y += 16) {
		for (j = 0; j < 4; j++) {
			h_copy(di, ds, si, ss, width, f_pal);
		}
		di +=  ds;
		for (j = 0; j < 12; j++) {
			h_copy(di, ds, si, ss, width, f_pal);
		}
		/* mix lines 4-11 */
		di -= 13*ds;
			v_mix(&di[0], &di[-ds], &di[ds], width, p_05, f_nop);
		for (j = 0; j < 7; j++) {
			di += ds;
			v_mix(&di[0], &di[0], &di[ds], width, p_05, f_nop);
		}
		di += 6*ds;
	}
}

void upscale_rgb_bl4_y_16_17(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal)
{
	int y, j;

	for (y = 0; y < height; y += 16) {
		for (j = 0; j < 2; j++) {
			h_copy(di, ds, si, ss, width, f_pal);
		}
		di += ds;
		for (j = 0; j < 14; j++) {
			h_copy(di, ds, si, ss, width, f_pal);
		}
		di -= 15*ds;
		/* mixing line 2: line 1 = -ds, line 2 = +ds */
			v_mix(&di[0], &di[-ds], &di[ds], width, p_025, f_nop);
			di += ds;
		/* mixing lines 3-5: line n-1 = 0, line n = +ds */
		for (j = 0; j < 3; j++) {
			v_mix(&di[0], &di[0], &di[ds], width, p_025, f_nop);
			di += ds;
			}
		/* mixing lines 6-9 */
		for (j = 0; j < 4; j++) {
			v_mix(&di[0], &di[0], &di[ds], width, p_05, f_nop);
			di += ds;
		}
		/* mixing lines 10-13 */
		for (j = 0; j < 4; j++) {
			v_mix(&di[0], &di[0], &di[ds], width, p_075, f_nop);
			di += ds;
		}
		/* lines 14-16, already in place */
		di += 3*ds;
	}
}

/* X x Y -> X*2/1 x Y, e.g. for X 160->320 (GG) */
void upscale_clut_nn_x_1_2(u8 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height)
{
	int y;

	for (y = 0; y < height; y++) {
		h_upscale_nn_1_2(di, ds, si, ss, width, f_nop);
	}
}

void upscale_rgb_nn_x_1_2(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal)
{
	int y;

	for (y = 0; y < height; y++) {
		h_upscale_nn_1_2(di, ds, si, ss, width, f_pal);
	}
}

void upscale_rgb_bl2_x_1_2(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal)
{
	int y;

	for (y = 0; y < height; y++) {
		h_upscale_bl2_1_2(di, ds, si, ss, width, f_pal);
	}
}

/* X x Y -> X*2/1 x Y*5/3 (GG) */
void upscale_clut_nn_x_1_2_y_3_5(u8 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height)
{
	int swidth = width * 2;
	int y, j;

	for (y = 0; y < height; y += 3) {
		/* lines 0,2,4 */
		for (j = 0; j < 3; j++) {
			h_upscale_nn_1_2(di, ds, si, ss, width, f_nop);
			di += ds;
		}
		/* lines 1,3 */
		di -= 5*ds;
		for (j = 0; j < 2; j++) {
			v_copy(&di[0], &di[-ds], swidth, f_nop);
			di += 2*ds;
		}
	}
}

void upscale_rgb_nn_x_1_2_y_3_5(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal)
{
	int swidth = width * 2;
	int y, j;

	for (y = 0; y < height; y += 3) {
		for (j = 0; j < 3; j++) {
			h_upscale_nn_1_2(di, ds, si, ss, width, f_pal);
			di += ds;
		}
		di -= 5*ds;
		for (j = 0; j < 2; j++) {
			v_copy(&di[0], &di[-ds], swidth, f_nop);
			di += 2*ds;
		}
	}
}

void upscale_rgb_bl2_x_1_2_y_3_5(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal)
{
	int swidth = width * 2;
	int y, j;

	for (y = 0; y < height; y += 3) {
		for (j = 0; j < 3; j++) {
			h_upscale_bl2_1_2(di, ds, si, ss, width, f_pal);
			di += ds;
		}
		di -= 5*ds;
		for (j = 0; j < 2; j++) {
			v_mix(&di[0], &di[-ds], &di[ds], swidth, p_05, f_nop);
			di += 2*ds;
		}
	}
}

void upscale_rgb_bl4_x_1_2_y_3_5(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal)
{
	int swidth = width * 2;
	int y, j, d;

	/* for 1st block backwards reference virtually duplicate source line 0 */
	for (y = 0, d = 2*ds; y < height; y += 3, d = -ds) {
		di += 2*ds;
		for (j = 0; j < 3; j++) {
			h_upscale_bl2_1_2(di, ds, si, ss, width, f_pal);
		}
		di -= 5*ds;
		v_mix(&di[0], &di[d ], &di[2*ds], swidth, p_05, f_nop); /*-1+0 */
		di += ds;
		v_mix(&di[0], &di[ds], &di[2*ds], swidth, p_075, f_nop);/* 0+1 */
		di += ds;
		v_mix(&di[0], &di[ 0], &di[  ds], swidth, p_025, f_nop);/* 0+1 */
		di += ds;
		v_mix(&di[0], &di[ 0], &di[  ds], swidth, p_05, f_nop); /* 1+2 */
		di += 2*ds;
	}
}

/* X x Y -> X x Y*5/3, e.g. for Y 144->240 (GG) */
void upscale_clut_nn_y_3_5(u8 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height)
{
	int y, j;

	for (y = 0; y < height; y += 3) {
		/* lines 0,2,4 */
		for (j = 0; j < 3; j++) {
			h_copy(di, ds, si, ss, width, f_nop);
			di += ds;
		}
		/* lines 1,3 */
		di -= 5*ds;
		for (j = 0; j < 2; j++) {
			v_copy(&di[0], &di[-ds], width, f_nop);
			di += 2*ds;
		}
	}
}

void upscale_rgb_nn_y_3_5(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal)
{
	int y, j;

	for (y = 0; y < height; y += 3) {
		for (j = 0; j < 3; j++) {
			h_copy(di, ds, si, ss, width, f_pal);
			di += ds;
		}
		di -= 5*ds;
		for (j = 0; j < 2; j++) {
			v_copy(&di[0], &di[-ds], width, f_nop);
			di += 2*ds;
		}
	}
}

void upscale_rgb_bl2_y_3_5(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal)
{
	int y, j;

	for (y = 0; y < height; y += 3) {
		for (j = 0; j < 3; j++) {
			h_copy(di, ds, si, ss, width, f_pal);
			di += ds;
		}
		di -= 5*ds;
		for (j = 0; j < 2; j++) {
			v_mix(&di[0], &di[-ds], &di[ds], width, p_05, f_nop);
			di += 2*ds;
		}
	}
}

void upscale_rgb_bl4_y_3_5(u16 *__restrict di, int ds, u8 *__restrict si, int ss, int width, int height, u16 *pal)
{
	int y, j, d;

	/* for 1st block backwards reference virtually duplicate source line 0 */
	for (y = 0, d = 2*ds; y < height; y += 3, d = -ds) {
		di += 2*ds;
		for (j = 0; j < 3; j++) {
			h_copy(di, ds, si, ss, width, f_pal);
		}
		di -= 5*ds;
		v_mix(&di[0], &di[d ], &di[2*ds], width, p_05, f_nop); /*-1+0 */
		di += ds;
		v_mix(&di[0], &di[ds], &di[2*ds], width, p_075, f_nop);/* 0+1 */
		di += ds;
		v_mix(&di[0], &di[ 0], &di[  ds], width, p_025, f_nop);/* 0+1 */
		di += ds;
		v_mix(&di[0], &di[ 0], &di[  ds], width, p_05, f_nop); /* 1+2 */
		di += 2*ds;
	}
}

