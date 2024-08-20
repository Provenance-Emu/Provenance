/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus-rsp-hle - alist.h                                         *
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

#ifndef ALIST_INTERNAL_H
#define ALIST_INTERNAL_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

struct hle_t;

typedef void (*acmd_callback_t)(struct hle_t* hle, uint32_t w1, uint32_t w2);

void alist_process(struct hle_t* hle, const acmd_callback_t abi[], unsigned int abi_size);
uint32_t alist_get_address(struct hle_t* hle, uint32_t so, const uint32_t *segments, size_t n);
void alist_set_address(struct hle_t* hle, uint32_t so, uint32_t *segments, size_t n);
void alist_clear(struct hle_t* hle, uint16_t dmem, uint16_t count);
void alist_load(struct hle_t* hle, uint16_t dmem, uint32_t address, uint16_t count);
void alist_save(struct hle_t* hle, uint16_t dmem, uint32_t address, uint16_t count);
void alist_move(struct hle_t* hle, uint16_t dmemo, uint16_t dmemi, uint16_t count);
void alist_copy_every_other_sample(struct hle_t* hle, uint16_t dmemo, uint16_t dmemi, uint16_t count);
void alist_repeat64(struct hle_t* hle, uint16_t dmemo, uint16_t dmemi, uint8_t count);
void alist_copy_blocks(struct hle_t* hle, uint16_t dmemo, uint16_t dmemi, uint16_t block_size, uint8_t count);
void alist_interleave(struct hle_t* hle, uint16_t dmemo, uint16_t left, uint16_t right, uint16_t count);

void alist_envmix_exp(
        struct hle_t* hle,
        bool init,
        bool aux,
        uint16_t dmem_dl, uint16_t dmem_dr,
        uint16_t dmem_wl, uint16_t dmem_wr,
        uint16_t dmemi, uint16_t count,
        int16_t dry, int16_t wet,
        const int16_t *vol,
        const int16_t *target,
        const int32_t *rate,
        uint32_t address);

void alist_envmix_ge(
        struct hle_t* hle,
        bool init,
        bool aux,
        uint16_t dmem_dl, uint16_t dmem_dr,
        uint16_t dmem_wl, uint16_t dmem_wr,
        uint16_t dmemi, uint16_t count,
        int16_t dry, int16_t wet,
        const int16_t *vol,
        const int16_t *target,
        const int32_t *rate,
        uint32_t address);

void alist_envmix_lin(
        struct hle_t* hle,
        bool init,
        uint16_t dmem_dl, uint16_t dmem_dr,
        uint16_t dmem_wl, uint16_t dmem_wr,
        uint16_t dmemi, uint16_t count,
        int16_t dry, int16_t wet,
        const int16_t *vol,
        const int16_t *target,
        const int32_t *rate,
        uint32_t address);

void alist_envmix_nead(
        struct hle_t* hle,
        bool swap_wet_LR,
        uint16_t dmem_dl,
        uint16_t dmem_dr,
        uint16_t dmem_wl,
        uint16_t dmem_wr,
        uint16_t dmemi,
        unsigned count,
        uint16_t *env_values,
        uint16_t *env_steps,
        const int16_t *xors);

void alist_mix(struct hle_t* hle, uint16_t dmemo, uint16_t dmemi, uint16_t count, int16_t gain);
void alist_multQ44(struct hle_t* hle, uint16_t dmem, uint16_t count, int8_t gain);
void alist_add(struct hle_t* hle, uint16_t dmemo, uint16_t dmemi, uint16_t count);

void alist_adpcm(
        struct hle_t* hle,
        bool init,
        bool loop,
        bool two_bit_per_sample,
        uint16_t dmemo,
        uint16_t dmemi,
        uint16_t count,
        const int16_t* codebook,
        uint32_t loop_address,
        uint32_t last_frame_address);

void alist_resample(
        struct hle_t* hle, 
        bool init,
        bool flag2,
        uint16_t dmemo, uint16_t dmemi, uint16_t count,
        uint32_t pitch, uint32_t address);

void alist_resample_zoh(
        struct hle_t* hle,
        uint16_t dmemo,
        uint16_t dmemi,
        uint16_t count,
        uint32_t pitch,
        uint32_t pitch_accu);

void alist_filter(
        struct hle_t* hle,
        uint16_t dmem,
        uint16_t count,
        uint32_t address,
        const uint32_t* lut_address);

void alist_polef(
        struct hle_t* hle,
        bool init,
        uint16_t dmemo,
        uint16_t dmemi,
        uint16_t count,
        uint16_t gain,
        int16_t* table,
        uint32_t address);

void alist_iirf(
        struct hle_t* hle,
        bool init,
        uint16_t dmemo,
        uint16_t dmemi,
        uint16_t count,
        int16_t* table,
        uint32_t address);

/*
 * Audio flags
 */

#define A_INIT          0x01
#define A_CONTINUE      0x00
#define A_LOOP          0x02
#define A_OUT           0x02
#define A_LEFT          0x02
#define A_RIGHT         0x00
#define A_VOL           0x04
#define A_RATE          0x00
#define A_AUX           0x08
#define A_NOAUX         0x00
#define A_MAIN          0x00
#define A_MIX           0x10

#endif
