/*
 * colours_pal.c - Atari PAL colour palette generation and adjustment
 *
 * Copyright (C) 2009-2014 Atari800 development team (see DOC/CREDITS)
 *
 * This file is part of the Atari800 emulator project which emulates
 * the Atari 400, 800, 800XL, 130XE, and 5200 8-bit computers.
 *
 * Atari800 is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * Atari800 is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Atari800; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */
#include <math.h>
#include <stdlib.h>
#include <string.h>

#include "colours_pal.h"

#include "atari.h" /* for TRUE/FALSE */
#include "colours.h"
#include "log.h"
#include "util.h"

#ifndef M_PI
#define M_PI		3.14159265358979323846
#endif

Colours_setup_t COLOURS_PAL_setup;

/* PAL-specific default setup. */
static struct {
	double color_delay;
} const default_setup = {
	23.2, /* chosen by eye to give a smooth rainbow */
};

COLOURS_EXTERNAL_t COLOURS_PAL_external = { "", FALSE, FALSE };

/* Fills YUV_TABLE from external palette. External palette is not adjusted if
   COLOURS_PAL_external.adjust is false. */
static void GetYUVFromExternal(double yuv_table[256*5])
{
	double const gamma = 1 - COLOURS_PAL_setup.gamma / 2.0;
	unsigned char *ext_ptr = COLOURS_PAL_external.palette;
	int n;

	double const hue = COLOURS_PAL_setup.hue * M_PI;
	double const s = sin(hue);
	double const c = cos(hue);

	for (n = 0; n < 256; n ++) {
		/* Convert RGB values from external palette to YUV. */
		double r = (double)*ext_ptr++ / 255.0;
		double g = (double)*ext_ptr++ / 255.0;
		double b = (double)*ext_ptr++ / 255.0;
		double y, u, v, tmp_u;
		Colours_RGB2YUV(r, g, b, &y, &u, &v);
		tmp_u = u;
		u = tmp_u * c - v * s;
		v = tmp_u * s + v * c;
		/* Optionally adjust external palette. */
		if (COLOURS_PAL_external.adjust) {
			y = pow(y, gamma);
			y *= COLOURS_PAL_setup.contrast * 0.5 + 1;
			y += COLOURS_PAL_setup.brightness * 0.5;
			if (y > 1.0)
				y = 1.0;
			else if (y < 0.0)
				y = 0.0;
			u *= COLOURS_PAL_setup.saturation + 1.0;
			v *= COLOURS_PAL_setup.saturation + 1.0;
		}

		*yuv_table++ = y;
		/* Cannot retrieve different U/V values for even and odd lines from an
		   external palette - instead write each value twice. */
		*yuv_table++ = u;
		*yuv_table++ = u;
		*yuv_table++ = v;
		*yuv_table++ = v;
	}
}

/* Below are conclusions from analysis of oscillograms of PAL GTIA output.
   The oscillograms are available at:
   http://www.atari.org.pl/forum/viewtopic.php?pid=164037#p164037

   Like the NTSC GTIA, the PAL GTIA produces color signal by delaying
   (phase-shifting) a base chrominance subcarrier by a specified time -
   different for each displayed hue. The subcarrier's frequency is
   4433618.75 Hz (4.43 MHz in short). The subcarrier is provided at the chip's
   PAL pin; output signal is produced at the COL pin.

   As in NTSC, the delay introduced by the PAL GTIA can be adjusted to a
   certain extent by changing voltage applied at the DEL pin.

   This is where the similarities between the PAL GTIA and its NTSC
   counterpart end.

   In NTSC, each screen line contains, in its back porch, a burst of about 10
   cycles of color subcarrier (known as the coloburst). The colorburst is used
   by the TV as a reference for decoding colors in each line. Signal with
   phase shift equal to the colorburst's (ie. equal to the subcarrier's) is
   decoded as 180 deg angle in the YUV colorspace (-U). Delaying the signal is
   interpreted as rotating the angle clockwise in YUV.

   In PAL, there's also colorburst, but it is not equal to the color
   subcarrier. In even lines it lags the subcarrier by 45 deg, and in odd
   lines it leads it subcarrier by 45 deg. The resulting 90 deg difference is
   used by the TV to distinguish even and odd lines. The original subcarrier
   is recreated by the receiver by summing colorbursts from two consecutive
   lines (and adjusting its amplitude, since sum of two sine waves shifted by
   90 deg has higher amplitude than the original waves).

   Then, as in NTSC, signals equal in phase to the (recreated) subcarrier are
   decoded as 180 deg angle in YUV. But other signals are decoded differently
   in even and in odd lines. In even lines (or "NTSC lines"), delaying the
   signal is interpreted as rotating the angle clockwise in YUV, just like in
   NTSC. But in odd lines (or "PAL lines"), delaying the signal is akin to
   rotating the angle counter-clockwise. So, to achieve the same color in even
   and odd lines, the transmitter must send signal delayed wrt. the subcarrier
   in even lines but "rushed" (anti-delayed?) in odd lines.

   PAL GTIA can only delay input signal; it can't "rush" it, it would involve
   creating output before input has arrived. So the requirements of the PAL
   system are achieved in the chip by delaying the signal differently in even
   and odd lines.

   Measurements indicate that the PAL GTIA delays the input subcarrier by
   95.2ns; then it might delay it by further 100.7ns if needed; and finally
   can delay it further by X, 2*X, 3*X, ..., 7*X, where X is a delay adjusted
   by voltage at the DEL pin. The general formula is:
     DELAY(hue) = 95.2ns + ADD(hue)*100.7ns + MULT(hue)*X
   where
     ADD(hue) depends on a given hue and can be 0 or 1,
     MULT(hue) depends on a given hue and can be 0, 1, 2, ..., 7,
     X depends on voltage at the DEL pin.
   So, the chip can shift the input signal by 8*2=16 different delays.

   Mapping of ADD and MULT values to specific hues is random - it is
   implemented in the source code as the del_coeffs structure.

   The relation between DEL pin voltage and the resulting delay is not linear
   - it was measured to be:
       17.37ns at 5V,
       10.60ns at 7V,
       7.44ns at 9V.

   The PAL GTIA apparently contains a series of 7 delay elements similarly to
   the NTSC version (which contains 15 of them), and an additional 100.7ns
   delay element. (When looking at the oscillograms, for each hue that passes
   through this 100.7ns delay, the resulting waveform is different than for
   hues that don't involve the delay - it looks like it was inverted
   vertically. This gives a hint about how the delay is implemented
   internally.)

   The end result is, PAL GTIA actually produces more than 256 colors. It
   produces different hues in odd and even lines, but it is not normally
   visible since PAL TVs average hues on each two consecutive lines - but
   it can be made visible with specially-crafted screens. Currently this
   feature of the chip is not implemented - only 256 colors are produced,
   each one being an average of "even" and "odd" hues.

   In PAL GTIA, just as in NTSC, the colorburst signals have the same phase as
   Hue 1. But by changing voltage at the DEL pin, we also change the relative
   phase shift of the colorburst between even and odd lines - it is not always
   90 degrees. It has the following consequences - all of them observed on a
   real machine, and all currently emulated:
   1. Changing phase shift between odd and even colorbursts also changes
   amplitude of the resulting subcarrier, which is recreated by summing the
   two colorbursts. Since amplitude of the color subcarrier is used as a
   reference for decoding color saturation, changing voltage at DEL not only
   changes hues of displayed colors; it also changes their saturation.
   2. With appropriately chosen DEL voltage, phase shift between even and odd
   colorbursts can reach 180 deg. At this point the PAL TV can no longer
   distinguish even and odd lines, and stops interpreting color signal,
   displaying screen as black-and-white with visible chroma dots.
   3. Changing DEL voltage further causes phase shift between even and odd
   colorbursts to to be larger than 180 deg, at which point the TV starts
   interpreting color signal "backwards", as if the color subcarrier suddenly
   shifted by 180 deg.
*/

/* Generates PAL palette into YUV_TABLE. */
static void GetYUVFromGenerated(double yuv_table[256*5])
{
	struct del_coeff {
		int add;
		int mult;
	};

	/* Delay coefficients for each hue. */
	static struct {
		struct del_coeff even[15];
		struct del_coeff odd[15];
	} const del_coeffs = {
		{ { 1, 5 }, /* Hue $1 in even lines */
		  { 1, 6 }, /* Hue $2 in even lines */
		  { 1, 7 },
		  { 0, 0 },
		  { 0, 1 },
		  { 0, 2 },
		  { 0, 4 },
		  { 0, 5 },
		  { 0, 6 },
		  { 0, 7 },
		  { 1, 1 },
		  { 1, 2 },
		  { 1, 3 },
		  { 1, 4 },
		  { 1, 5 } /* Hue $F in even lines */
		},
		{ { 1, 1 }, /* Hue $1 in odd lines */
		  { 1, 0 }, /* Hue $2 in odd lines */
		  { 0, 7 },
		  { 0, 6 },
		  { 0, 5 },
		  { 0, 4 },
		  { 0, 2 },
		  { 0, 1 },
		  { 0, 0 },
		  { 1, 7 },
		  { 1, 5 },
		  { 1, 4 },
		  { 1, 3 },
		  { 1, 2 },
		  { 1, 1 } /* Hue $F in odd lines */
		}
	};
	int cr, lm;

	double const scaled_black_level = (double)COLOURS_PAL_setup.black_level / 255.0f;
	double const scaled_white_level = (double)COLOURS_PAL_setup.white_level / 255.0f;
	double const gamma = 1 - COLOURS_PAL_setup.gamma / 2.0;

	/* NTSC luma multipliers from CGIA.PDF */
	static double const luma_mult[16] = {
		0.6941, 0.7091, 0.7241, 0.7401,
		0.7560, 0.7741, 0.7931, 0.8121,
		0.8260, 0.8470, 0.8700, 0.8930,
		0.9160, 0.9420, 0.9690, 1.0000};

	/* When phase shift between even and odd colorbursts is close to 180 deg, the
	   TV stops interpreting color signal. This value determines how close to 180
	   deg that phase shift must be. It is specific to a TV set. */
	static double const color_disable_threshold = 0.05;
	/* Base delay - 1/4.43MHz * base_del = ca. 95.2ns */
	static double const base_del = 0.421894970414201;
	/* Additional delay - 1/4.43MHz * add_del = ca. 100.7ns */
	static double const add_del = 0.446563064859117;
	/* Delay introduced by the DEL pin voltage. */
	double const del_adj = COLOURS_PAL_setup.color_delay / 360.0;

	/* Phase delays of colorbursts in even and odd lines. They are equal to
	   Hue 1. */
	double const even_burst_del = base_del + add_del * del_coeffs.even[0].add + del_adj * del_coeffs.even[0].mult;
	double const odd_burst_del = base_del + add_del * del_coeffs.odd[0].add + del_adj * del_coeffs.odd[0].mult;

	/* Reciprocal of the recreated subcarrier's amplitude. */
	double saturation_mult;
	/* Phase delay of the recreated amplitude. */
	double subcarrier_del = (even_burst_del + odd_burst_del + COLOURS_PAL_setup.hue) / 2.0;

	/* Phase difference between colorbursts in even and odd lines. */
	double burst_diff = even_burst_del - odd_burst_del;
	burst_diff -= floor(burst_diff); /* Normalize to 0..1. */

	if (burst_diff > 0.5 - color_disable_threshold && burst_diff < 0.5 + color_disable_threshold)
		/* Shift between colorbursts close to 180 deg. Don't produce color. */
		saturation_mult = 0.0;
	else {
		/* Subcarrier is a sum of two waves with equal frequency and amplitude,
		   but phase-shifted by 2pi*burst_diff. The formula is derived from
		   http://2000clicks.com/mathhelp/GeometryTrigEquivPhaseShift.aspx */
		double subcarrier_amplitude = sqrt(2.0 * cos(burst_diff*2.0*M_PI) + 2.0);
		/* Normalise saturation_mult by multiplying by sqrt(2), so that it
		   equals 1.0 when odd & even colorbursts are shifted by 90 deg (ie.
		   burst_diff == 0.25). */
		saturation_mult = sqrt(2.0) / subcarrier_amplitude;
	}

	for (cr = 0; cr < 16; cr ++) {
		double even_u = 0.0;
		double odd_u = 0.0;
		double even_v = 0.0;
		double odd_v = 0.0;
		if (cr) {
			struct del_coeff const *even_delay = &(del_coeffs.even[cr - 1]);
			struct del_coeff const *odd_delay = &(del_coeffs.odd[cr - 1]);
			double even_del = base_del + add_del * even_delay->add + del_adj * even_delay->mult;
			double odd_del = base_del + add_del * odd_delay->add + del_adj * odd_delay->mult;
			double even_angle = (0.5 - (even_del - subcarrier_del)) * 2.0 * M_PI;
			double odd_angle = (0.5 + (odd_del - subcarrier_del)) * 2.0 * M_PI;
			double saturation = (COLOURS_PAL_setup.saturation + 1) * 0.175 * saturation_mult;
			even_u = cos(even_angle) * saturation;
			even_v = sin(even_angle) * saturation;
			odd_u = cos(odd_angle) * saturation;
			odd_v = sin(odd_angle) * saturation;
		}
		for (lm = 0; lm < 16; lm ++) {
			/* calculate yuv for color entry */
			double y = (luma_mult[lm] - luma_mult[0]) / (luma_mult[15] - luma_mult[0]);
			y = pow(y, gamma);
			y *= COLOURS_PAL_setup.contrast * 0.5 + 1;
			y += COLOURS_PAL_setup.brightness * 0.5;
			/* Scale the Y signal's range from 0..1 to
			   scaled_black_level..scaled_white_level */
			y = y * (scaled_white_level - scaled_black_level) + scaled_black_level;
			/*
			if (y < scaled_black_level)
				y = scaled_black_level;
			else if (y > scaled_white_level)
				y = scaled_white_level;
			*/
			*yuv_table++ = y;
			*yuv_table++ = even_u;
			*yuv_table++ = odd_u;
			*yuv_table++ = even_v;
			*yuv_table++ = odd_v;
		}
	}
}

void COLOURS_PAL_GetYUV(double yuv_table[256*5])
{
	if (COLOURS_PAL_external.loaded)
		GetYUVFromExternal(yuv_table);
	else
		GetYUVFromGenerated(yuv_table);
}

/* Averages YUV values from YUV_TABLE and converts them to RGB values. Stores
   them in COLOURTABLE. */
static void YUV2RGB(int colourtable[256], double const yuv_table[256*5])
{
	double const *yuv_ptr = yuv_table;
	int n;
	for (n = 0; n < 256; ++n) {
		double y = *yuv_ptr++;
		double even_u = *yuv_ptr++;
		double odd_u = *yuv_ptr++;
		double even_v = *yuv_ptr++;
		double odd_v = *yuv_ptr++;
		double r, g, b;
		/* The different colors in odd and even lines are not
		   emulated - instead the palette contains averaged values. */
		double u = (even_u + odd_u) / 2.0;
		double v = (even_v + odd_v) / 2.0;
		Colours_YUV2RGB(y, u, v, &r, &g, &b);
		Colours_SetRGB(n, (int) (r * 255), (int) (g * 255), (int) (b * 255), colourtable);
	}
}

void COLOURS_PAL_Update(int colourtable[256])
{
	double yuv_table[256*5];
	COLOURS_PAL_GetYUV(yuv_table);
	YUV2RGB(colourtable, yuv_table);
}

void COLOURS_PAL_RestoreDefaults(void)
{
	COLOURS_PAL_setup.color_delay = default_setup.color_delay;
}

Colours_preset_t COLOURS_PAL_GetPreset()
{
	if (Util_almostequal(COLOURS_PAL_setup.color_delay, default_setup.color_delay, 0.001))
		return COLOURS_PRESET_STANDARD;
	return COLOURS_PRESET_CUSTOM;
}

int COLOURS_PAL_ReadConfig(char *option, char *ptr)
{
	if (strcmp(option, "COLOURS_PAL_SATURATION") == 0)
		return Util_sscandouble(ptr, &COLOURS_PAL_setup.saturation);
	else if (strcmp(option, "COLOURS_PAL_CONTRAST") == 0)
		return Util_sscandouble(ptr, &COLOURS_PAL_setup.contrast);
	else if (strcmp(option, "COLOURS_PAL_BRIGHTNESS") == 0)
		return Util_sscandouble(ptr, &COLOURS_PAL_setup.brightness);
	else if (strcmp(option, "COLOURS_PAL_GAMMA") == 0)
		return Util_sscandouble(ptr, &COLOURS_PAL_setup.gamma);
	else if (strcmp(option, "COLOURS_PAL_HUE") == 0)
		return Util_sscandouble(ptr, &COLOURS_PAL_setup.hue);
	else if (strcmp(option, "COLOURS_PAL_GTIA_DELAY") == 0)
		return Util_sscandouble(ptr, &COLOURS_PAL_setup.color_delay);
	else if (strcmp(option, "COLOURS_PAL_EXTERNAL_PALETTE") == 0)
		Util_strlcpy(COLOURS_PAL_external.filename, ptr, sizeof(COLOURS_PAL_external.filename));
	else if (strcmp(option, "COLOURS_PAL_EXTERNAL_PALETTE_LOADED") == 0)
		/* Use the "loaded" flag to indicate that the palette must be loaded later. */
		return (COLOURS_PAL_external.loaded = Util_sscanbool(ptr)) != -1;
	else if (strcmp(option, "COLOURS_PAL_ADJUST_EXTERNAL_PALETTE") == 0)
		return (COLOURS_PAL_external.adjust = Util_sscanbool(ptr)) != -1;
	else
		return FALSE;
	return TRUE;
}

void COLOURS_PAL_WriteConfig(FILE *fp)
{
	fprintf(fp, "COLOURS_PAL_SATURATION=%g\n", COLOURS_PAL_setup.saturation);
	fprintf(fp, "COLOURS_PAL_CONTRAST=%g\n", COLOURS_PAL_setup.contrast);
	fprintf(fp, "COLOURS_PAL_BRIGHTNESS=%g\n", COLOURS_PAL_setup.brightness);
	fprintf(fp, "COLOURS_PAL_GAMMA=%g\n", COLOURS_PAL_setup.gamma);
	fprintf(fp, "COLOURS_PAL_HUE=%g\n", COLOURS_PAL_setup.hue);
	fprintf(fp, "COLOURS_PAL_GTIA_DELAY=%g\n", COLOURS_PAL_setup.color_delay);
	fprintf(fp, "COLOURS_PAL_EXTERNAL_PALETTE=%s\n", COLOURS_PAL_external.filename);
	fprintf(fp, "COLOURS_PAL_EXTERNAL_PALETTE_LOADED=%d\n", COLOURS_PAL_external.loaded);
	fprintf(fp, "COLOURS_PAL_ADJUST_EXTERNAL_PALETTE=%d\n", COLOURS_PAL_external.adjust);
}

int COLOURS_PAL_Initialise(int *argc, char *argv[])
{
	int i;
	int j;

	for (i = j = 1; i < *argc; i++) {
		int i_a = (i + 1 < *argc);		/* is argument available? */
		int a_m = FALSE;			/* error, argument missing! */
		
		if (strcmp(argv[i], "-pal-saturation") == 0) {
			if (i_a)
				COLOURS_PAL_setup.saturation = atof(argv[++i]);
			else a_m = TRUE;
		}
		else if (strcmp(argv[i], "-pal-contrast") == 0) {
			if (i_a)
				COLOURS_PAL_setup.contrast = atof(argv[++i]);
			else a_m = TRUE;
		}
		else if (strcmp(argv[i], "-pal-brightness") == 0) {
			if (i_a)
				COLOURS_PAL_setup.brightness = atof(argv[++i]);
			else a_m = TRUE;
		}
		else if (strcmp(argv[i], "-pal-gamma") == 0) {
			if (i_a)
				COLOURS_PAL_setup.gamma = atof(argv[++i]);
			else a_m = TRUE;
		}
		else if (strcmp(argv[i], "-pal-tint") == 0) {
			if (i_a)
				COLOURS_PAL_setup.hue = atof(argv[++i]);
			else a_m = TRUE;
		}
		else if (strcmp(argv[i], "-pal-colordelay") == 0) {
			if (i_a)
				COLOURS_PAL_setup.color_delay = atof(argv[++i]);
			else a_m = TRUE;
		}
		else if (strcmp(argv[i], "-palettep") == 0) {
			if (i_a) {
				Util_strlcpy(COLOURS_PAL_external.filename, argv[++i], sizeof(COLOURS_PAL_external.filename));
				/* Use the "loaded" flag to indicate that the palette must be loaded later. */
				COLOURS_PAL_external.loaded = TRUE;
			} else a_m = TRUE;
		}
		else if (strcmp(argv[i], "-palettep-adjust") == 0)
			COLOURS_PAL_external.adjust = TRUE;
		else {
			if (strcmp(argv[i], "-help") == 0) {
				Log_print("\t-pal-saturation <num>  Set PAL color saturation");
				Log_print("\t-pal-contrast <num>    Set PAL contrast");
				Log_print("\t-pal-brightness <num>  Set PAL brightness");
				Log_print("\t-pal-gamma <num>       Set PAL color gamma factor");
				Log_print("\t-pal-tint <num>        Set PAL tint");
				Log_print("\t-pal-colordelay <num>  Set PAL GTIA color delay");
				Log_print("\t-palettep <filename>   Load PAL external palette");
				Log_print("\t-palettep-adjust       Apply adjustments to PAL external palette");
			}
			argv[j++] = argv[i];
		}

		if (a_m) {
			Log_print("Missing argument for '%s'", argv[i]);
			return FALSE;
		}
	}
	*argc = j;

	/* Try loading an external palette if needed. */
	if (COLOURS_PAL_external.loaded && !COLOURS_EXTERNAL_Read(&COLOURS_PAL_external))
		Log_print("Cannot read PAL palette from %s", COLOURS_PAL_external.filename);

	return TRUE;
}
