/*
 * Option handlers shared between the tools.
 * Copyright (c) 2022 Taner Sener
 *
 * This file is part of FFmpeg.
 *
 * FFmpeg is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * FFmpeg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with FFmpeg; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

/*
 * This file is the modified version of opt_common.h file living in ffmpeg source code under the fftools folder. We
 * manually update it each time we depend on a new ffmpeg version. Below you can see the list of changes applied
 * by us to develop the ffmpeg-kit library.
 *
 * ffmpeg-kit changes by Taner Sener
 *
 * 09.2022
 * --------------------------------------------------------
 * - CMDUTILS_COMMON_OPTIONS and CMDUTILS_COMMON_OPTIONS_AVDEVICE defines dropped
 * - fftools_ prefix added to fftools headers
 */

#ifndef FFTOOLS_OPT_COMMON_H
#define FFTOOLS_OPT_COMMON_H

#include "config.h"

#include "fftools_cmdutils.h"

#if CONFIG_AVDEVICE
/**
 * Print a listing containing autodetected sinks of the output device.
 * Device name with options may be passed as an argument to limit results.
 */
int show_sinks(void *optctx, const char *opt, const char *arg);

/**
 * Print a listing containing autodetected sources of the input device.
 * Device name with options may be passed as an argument to limit results.
 */
int show_sources(void *optctx, const char *opt, const char *arg);
#endif

/**
 * Print the license of the program to stdout. The license depends on
 * the license of the libraries compiled into the program.
 * This option processing function does not utilize the arguments.
 */
int show_license(void *optctx, const char *opt, const char *arg);

/**
 * Generic -h handler common to all fftools.
 */
int show_help(void *optctx, const char *opt, const char *arg);

/**
 * Print the version of the program to stdout. The version message
 * depends on the current versions of the repository and of the libav*
 * libraries.
 * This option processing function does not utilize the arguments.
 */
int show_version(void *optctx, const char *opt, const char *arg);

/**
 * Print the build configuration of the program to stdout. The contents
 * depend on the definition of FFMPEG_CONFIGURATION.
 * This option processing function does not utilize the arguments.
 */
int show_buildconf(void *optctx, const char *opt, const char *arg);

/**
 * Print a listing containing all the formats supported by the
 * program (including devices).
 * This option processing function does not utilize the arguments.
 */
int show_formats(void *optctx, const char *opt, const char *arg);

/**
 * Print a listing containing all the muxers supported by the
 * program (including devices).
 * This option processing function does not utilize the arguments.
 */
int show_muxers(void *optctx, const char *opt, const char *arg);

/**
 * Print a listing containing all the demuxer supported by the
 * program (including devices).
 * This option processing function does not utilize the arguments.
 */
int show_demuxers(void *optctx, const char *opt, const char *arg);

/**
 * Print a listing containing all the devices supported by the
 * program.
 * This option processing function does not utilize the arguments.
 */
int show_devices(void *optctx, const char *opt, const char *arg);

/**
 * Print a listing containing all the codecs supported by the
 * program.
 * This option processing function does not utilize the arguments.
 */
int show_codecs(void *optctx, const char *opt, const char *arg);

/**
 * Print a listing containing all the decoders supported by the
 * program.
 */
int show_decoders(void *optctx, const char *opt, const char *arg);

/**
 * Print a listing containing all the encoders supported by the
 * program.
 */
int show_encoders(void *optctx, const char *opt, const char *arg);

/**
 * Print a listing containing all the bit stream filters supported by the
 * program.
 * This option processing function does not utilize the arguments.
 */
int show_bsfs(void *optctx, const char *opt, const char *arg);

/**
 * Print a listing containing all the protocols supported by the
 * program.
 * This option processing function does not utilize the arguments.
 */
int show_protocols(void *optctx, const char *opt, const char *arg);

/**
 * Print a listing containing all the filters supported by the
 * program.
 * This option processing function does not utilize the arguments.
 */
int show_filters(void *optctx, const char *opt, const char *arg);

/**
 * Print a listing containing all the pixel formats supported by the
 * program.
 * This option processing function does not utilize the arguments.
 */
int show_pix_fmts(void *optctx, const char *opt, const char *arg);

/**
 * Print a listing containing all the standard channel layouts supported by
 * the program.
 * This option processing function does not utilize the arguments.
 */
int show_layouts(void *optctx, const char *opt, const char *arg);

/**
 * Print a listing containing all the sample formats supported by the
 * program.
 */
int show_sample_fmts(void *optctx, const char *opt, const char *arg);

/**
 * Print a listing containing all supported stream dispositions.
 */
int show_dispositions(void *optctx, const char *opt, const char *arg);

/**
 * Print a listing containing all the color names and values recognized
 * by the program.
 */
int show_colors(void *optctx, const char *opt, const char *arg);

/**
 * Set the libav* libraries log level.
 */
int opt_loglevel(void *optctx, const char *opt, const char *arg);

int opt_report(void *optctx, const char *opt, const char *arg);
int init_report(const char *env, FILE **file);

int opt_max_alloc(void *optctx, const char *opt, const char *arg);

/**
 * Override the cpuflags.
 */
int opt_cpuflags(void *optctx, const char *opt, const char *arg);

/**
 * Override the cpucount.
 */
int opt_cpucount(void *optctx, const char *opt, const char *arg);

#endif /* FFTOOLS_OPT_COMMON_H */
