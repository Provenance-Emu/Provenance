/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus-rsp-hle - ucodes.h                                        *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2014 Bobby Smiles                                       *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.          *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

#ifndef UCODES_H
#define UCODES_H

#include <stdint.h>

#define CACHED_UCODES_MAX_SIZE 16

struct hle_t;

typedef void(*ucode_func_t)(struct hle_t* hle);

struct ucode_info_t {
    uint32_t     uc_start;
    uint32_t     uc_dstart;
    uint16_t     uc_dsize;
    ucode_func_t uc_pfunc;
};

struct cached_ucodes_t {
    struct ucode_info_t infos[CACHED_UCODES_MAX_SIZE];
    int count;
};

/* cic_x105 ucode */
void cicx105_ucode(struct hle_t* hle);


/* audio list ucodes - audio */
enum { N_SEGMENTS = 16 };
struct alist_audio_t {
    /* segments */
    uint32_t segments[N_SEGMENTS];

    /* main buffers */
    uint16_t in;
    uint16_t out;
    uint16_t count;

    /* auxiliary buffers */
    uint16_t dry_right;
    uint16_t wet_left;
    uint16_t wet_right;

    /* gains */
    int16_t dry;
    int16_t wet;

    /* envelopes (0:left, 1:right) */
    int16_t vol[2];
    int16_t target[2];
    int32_t rate[2];

    /* ADPCM loop point address */
    uint32_t loop;

    /* storage for ADPCM table and polef coefficients */
    int16_t table[16 * 8];
};

void alist_process_audio   (struct hle_t* hle);
void alist_process_audio_ge(struct hle_t* hle);
void alist_process_audio_bc(struct hle_t* hle);


/* audio list ucodes - naudio */
struct alist_naudio_t {
    /* gains */
    int16_t dry;
    int16_t wet;

    /* envelopes (0:left, 1:right) */
    int16_t vol[2];
    int16_t target[2];
    int32_t rate[2];

    /* ADPCM loop point address */
    uint32_t loop;

    /* storage for ADPCM table and polef coefficients */
    int16_t table[16 * 8];
};

void alist_process_naudio     (struct hle_t* hle);
void alist_process_naudio_bk  (struct hle_t* hle);
void alist_process_naudio_dk  (struct hle_t* hle);
void alist_process_naudio_mp3 (struct hle_t* hle);
void alist_process_naudio_cbfd(struct hle_t* hle);


/* audio list ucodes - nead */
struct alist_nead_t {
    /* main buffers */
    uint16_t in;
    uint16_t out;
    uint16_t count;

    /* envmixer ramps */
    uint16_t env_values[3];
    uint16_t env_steps[3];

    /* ADPCM loop point address */
    uint32_t loop;

    /* storage for ADPCM table and polef coefficients */
    int16_t table[16 * 8];

    /* filter audio command state */
    uint16_t filter_count;
    uint32_t filter_lut_address[2];
};

void alist_process_nead_mk  (struct hle_t* hle);
void alist_process_nead_sfj (struct hle_t* hle);
void alist_process_nead_sf  (struct hle_t* hle);
void alist_process_nead_fz  (struct hle_t* hle);
void alist_process_nead_wrjb(struct hle_t* hle);
void alist_process_nead_ys  (struct hle_t* hle);
void alist_process_nead_1080(struct hle_t* hle);
void alist_process_nead_oot (struct hle_t* hle);
void alist_process_nead_mm  (struct hle_t* hle);
void alist_process_nead_mmb (struct hle_t* hle);
void alist_process_nead_ac  (struct hle_t* hle);
void alist_process_nead_mats(struct hle_t* hle);
void alist_process_nead_efz (struct hle_t* hle);

/* mp3 ucode */
void mp3_task(struct hle_t* hle, unsigned int index, uint32_t address);


/* musyx ucodes */
void musyx_v1_task(struct hle_t* hle);
void musyx_v2_task(struct hle_t* hle);


/* jpeg ucodes */
void jpeg_decode_PS0(struct hle_t* hle);
void jpeg_decode_PS(struct hle_t* hle);
void jpeg_decode_OB(struct hle_t* hle);

/* Resident evil 2 ucode */
void resize_bilinear_task(struct hle_t* hle);
void decode_video_frame_task(struct hle_t* hle);
void fill_video_double_buffer_task(struct hle_t* hle);

/* hvqm2 ucode */
void hvqm2_decode_sp1_task(struct hle_t* hle);
void hvqm2_decode_sp2_task(struct hle_t* hle);

#endif

