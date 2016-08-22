/*
 * artifact.c - management of video artifacting settings
 *
 * Copyright (C) 2013 Tomasz Krasuski
 * Copyright (C) 2013 Atari800 development team (see DOC/CREDITS)
 *
 * This file is part of the Atari800 emulator project which emulates
 * the Atari 400, 800, 800XL, 130XE, and 5200 8-bit computers.

 * Atari800 is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.

 * Atari800 is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License along
 * with Atari800; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include <stdio.h>
#include <string.h>

#include "artifact.h"

#include "antic.h"
#include "atari.h"
#include "cfg.h"
#include "log.h"
#ifdef PAL_BLENDING
#include "pal_blending.h"
#endif /* PAL_BLENDING */
#include "util.h"
#if SUPPORTS_CHANGE_VIDEOMODE
#include "videomode.h"
#endif /* SUPPORTS_CHANGE_VIDEOMODE */

ARTIFACT_t ARTIFACT_mode = ARTIFACT_NONE;

static ARTIFACT_t mode_ntsc = ARTIFACT_NONE;
static ARTIFACT_t mode_pal = ARTIFACT_NONE;

static char const * const mode_cfg_strings[ARTIFACT_SIZE] = {
	"NONE",
	"NTSC-OLD",
	"NTSC-NEW",
#if NTSC_FILTER
	"NTSC-FULL",
#endif /* NTSC_FILTER */
#ifndef NO_SIMPLE_PAL_BLENDING
	"PAL-SIMPLE",
#endif /* NO_SIMPLE_PAL_BLENDING */
#ifdef PAL_BLENDING
	"PAL-BLEND"
#endif /* PAL_BLENDING */
};

static void UpdateMode(int old_mode, int reinit)
{
#if (NTSC_FILTER && SUPPORTS_CHANGE_VIDEOMODE) || defined(PAL_BLENDING)
	int need_reinit = FALSE;
#endif /* (NTSC_FILTER && SUPPORTS_CHANGE_VIDEOMODE) || defined(PAL_BLENDING) */
	if (ARTIFACT_mode == old_mode)
		return;

	/* TV effect has changed. */
#if NTSC_FILTER && SUPPORTS_CHANGE_VIDEOMODE
	/* If switched between non-filter and NTSC filter, video mode needs update. */
	if (ARTIFACT_mode == ARTIFACT_NTSC_FULL ||
	    old_mode == ARTIFACT_NTSC_FULL)
		need_reinit = TRUE;
#endif /* NTSC_FILTER && SUPPORTS_CHANGE_VIDEOMODE */
#ifdef PAL_BLENDING
	/* If PAL blending was enabled/disabled, video mode needs update. */
	if (ARTIFACT_mode == ARTIFACT_PAL_BLEND ||
	    old_mode == ARTIFACT_PAL_BLEND)
		need_reinit = TRUE;
#endif /* PAL_BLENDING */
#ifndef NO_SIMPLE_PAL_BLENDING
	ANTIC_pal_blending = ARTIFACT_mode == ARTIFACT_PAL_SIMPLE;
#endif /* NO_SIMPLE_PAL_BLENDING */
	if (ARTIFACT_mode != ARTIFACT_NTSC_OLD &&
	    ARTIFACT_mode != ARTIFACT_NTSC_NEW) {
		ANTIC_artif_new = ANTIC_artif_mode = 0;
	} else {
		if (ANTIC_artif_mode == 0)
			/* ANTIC new or old artifacting is being enabled */
			ANTIC_artif_mode = 1;
		ANTIC_artif_new = ARTIFACT_mode == ARTIFACT_NTSC_NEW;
	}
	ANTIC_UpdateArtifacting();
#if SUPPORTS_CHANGE_VIDEOMODE
	if (need_reinit && reinit) {
		if (!VIDEOMODE_Update()) {
			ARTIFACT_t tmp = ARTIFACT_mode;
			/* Updating display failed, restore previous setting. */
			ARTIFACT_mode = old_mode;
			UpdateMode(tmp, FALSE);
		}
	}
#endif /* SUPPORTS_CHANGE_VIDEOMODE */
}

static void UpdateFromTVMode(int tv_mode)
{
	if (tv_mode == Atari800_TV_NTSC)
		ARTIFACT_mode = mode_ntsc;
	else /* tv_mode == Atari800_TV_PAL */
		ARTIFACT_mode = mode_pal;
}

void ARTIFACT_Set(ARTIFACT_t mode)
{
	ARTIFACT_t old_effect = ARTIFACT_mode;
	ARTIFACT_mode = mode;
	if (Atari800_tv_mode == Atari800_TV_NTSC)
		mode_ntsc = mode;
	else /* Atari800_tv_mode == Atari800_TV_PAL */
		mode_pal = mode;
	UpdateMode(old_effect, TRUE);
}

void ARTIFACT_SetTVMode(int tv_mode)
{
	ARTIFACT_t old_mode = ARTIFACT_mode;
	UpdateFromTVMode(tv_mode);
	UpdateMode(old_mode, TRUE);
}

int ARTIFACT_ReadConfig(char *option, char *ptr)
{
	if (strcmp(option, "ARTIFACT_NTSC") == 0) {
		int i = CFG_MatchTextParameter(ptr, mode_cfg_strings, ARTIFACT_SIZE);
		if (i < 0)
			return FALSE;
		mode_ntsc = i;
	}
	else if (strcmp(option, "ARTIFACT_PAL") == 0) {
		int i = CFG_MatchTextParameter(ptr, mode_cfg_strings, ARTIFACT_SIZE);
		if (i < 0)
			return FALSE;
		mode_pal = i;
	}
	else if (strcmp(option, "ARTIFACT_NTSC_MODE") == 0) {
		int i = Util_sscandec(ptr);
		if (i < 0 || i > 4)
			return FALSE;
		ANTIC_artif_mode = i;
	}
	else
		return FALSE;
	return TRUE;
}

void ARTIFACT_WriteConfig(FILE *fp)
{
	fprintf(fp, "ARTIFACT_NTSC=%s\n", mode_cfg_strings[mode_ntsc]);
	fprintf(fp, "ARTIFACT_PAL=%s\n", mode_cfg_strings[mode_pal]);
	fprintf(fp, "ARTIFACT_NTSC_MODE=%i\n", ANTIC_artif_mode);
}

int ARTIFACT_Initialise(int *argc, char *argv[])
{
	int i;
	int j;

	for (i = j = 1; i < *argc; i++) {
		int i_a = (i + 1 < *argc);		/* is argument available? */
		int a_m = FALSE;			/* error, argument missing! */

		if (strcmp(argv[i], "-ntsc-artif") == 0) {
			if (i_a) {
				int idx = CFG_MatchTextParameter(argv[++i], mode_cfg_strings, ARTIFACT_SIZE);
				if (idx < 0) {
					Log_print("Invalid value for -ntsc-artif");
					return FALSE;
				}
				mode_ntsc = idx;
			} else a_m = TRUE;
		}
		else if (strcmp(argv[i], "-pal-artif") == 0) {
			if (i_a) {
				int idx = CFG_MatchTextParameter(argv[++i], mode_cfg_strings, ARTIFACT_SIZE);
				if (idx < 0) {
					Log_print("Invalid value for -pal-artif");
					return FALSE;
				}
				mode_pal = idx;
			} else a_m = TRUE;
		}

		else {
			if (strcmp(argv[i], "-help") == 0) {
				Log_print("\t-ntsc-artif none|ntsc-old|ntsc-new|ntsc-full");
				Log_print("\t                 Select video artifacts for NTSC");
				Log_print("\t-pal-artif none|pal-simple|pal-accu");
				Log_print("\t                 Select video artifacts for PAL");
			}
			argv[j++] = argv[i];
		}

		if (a_m) {
			Log_print("Missing argument for '%s'", argv[i]);
			return FALSE;
		}
	}
	*argc = j;

	/* Assume that Atari800_tv_mode has been already initialised. */
	UpdateFromTVMode(Atari800_tv_mode);
	UpdateMode(ARTIFACT_NONE, FALSE);
	return TRUE;
}
