/*
 * Copyright (C) 2019 Nuke.YKT
 * 
 *  Redistribution and use of this code or any derivative works are permitted
 *  provided that the following conditions are met:
 *
 *   - Redistributions may not be sold, nor may they be used in a commercial
 *     product or activity.
 *
 *   - Redistributions that are modified from the original source must include the
 *     complete source code, including the source code for all components used by a
 *     binary built from the modified sources. However, as a special exception, the
 *     source code distributed need not include anything that is normally distributed
 *     (in either source or binary form) with the major components (compiler, kernel,
 *     and so on) of the operating system on which the executable runs, unless that
 *     component itself accompanies the executable.
 *
 *   - Redistributions must reproduce the above copyright notice, this list of
 *     conditions and the following disclaimer in the documentation and/or other
 *     materials provided with the distribution.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 *  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 *  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 *  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 *  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 *  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 *  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 *  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 *  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *  POSSIBILITY OF SUCH DAMAGE.
 *
 *
 *  Yamaha YM2413 emulator
 *  Thanks:
 *      siliconpr0n.org(digshadow, John McMaster):
 *          VRC VII decap and die shot.
 *
 *  version: 1.0
 */

#ifndef OPLL_H
#define OPLL_H

#include <stdint.h>

enum {
    opll_type_ym2413 = 0x00,    /* Yamaha YM2413  */
    opll_type_ds1001,           /* Konami VRC VII */
    opll_type_ym2413b           /* Yamaha YM2413B */
};

enum {
    opll_patch_1 = 0x00,
    opll_patch_2,
    opll_patch_3,
    opll_patch_4,
    opll_patch_5,
    opll_patch_6,
    opll_patch_7,
    opll_patch_8,
    opll_patch_9,
    opll_patch_10,
    opll_patch_11,
    opll_patch_12,
    opll_patch_13,
    opll_patch_14,
    opll_patch_15,
    opll_patch_drum_0,
    opll_patch_drum_1,
    opll_patch_drum_2,
    opll_patch_drum_3,
    opll_patch_drum_4,
    opll_patch_drum_5,
    opll_patch_max
};

typedef struct {
    uint8_t tl;
    uint8_t dc;
    uint8_t dm;
    uint8_t fb;
    uint8_t am[2];
    uint8_t vib[2];
    uint8_t et[2];
    uint8_t ksr[2];
    uint8_t multi[2];
    uint8_t ksl[2];
    uint8_t ar[2];
    uint8_t dr[2];
    uint8_t sl[2];
    uint8_t rr[2];
} opll_patch_t;

typedef struct {
    uint32_t chip_type;
    uint32_t cycles;
    uint32_t slot;
    const opll_patch_t *patchrom;
    /* IO */
    uint8_t write_data;
    uint8_t write_a;
    uint8_t write_d;
    uint8_t write_a_en;
    uint8_t write_d_en;
    uint8_t write_fm_address;
    uint8_t write_fm_data;
    uint8_t write_mode_address;
    uint8_t address;
    uint8_t data;
    /* Envelope generator */
    uint8_t eg_counter_state;
    uint8_t eg_counter_state_prev;
    uint32_t eg_timer;
    uint8_t eg_timer_low_lock;
    uint8_t eg_timer_carry;
    uint8_t eg_timer_shift;
    uint8_t eg_timer_shift_lock;
    uint8_t eg_timer_shift_stop;
    uint8_t eg_state[18];
    uint8_t eg_level[18];
    uint8_t eg_kon;
    uint32_t eg_dokon;
    uint8_t eg_off;
    uint8_t eg_rate;
    uint8_t eg_maxrate;
    uint8_t eg_zerorate;
    uint8_t eg_inc_lo;
    uint8_t eg_inc_hi;
    uint8_t eg_rate_hi;
    uint16_t eg_sl;
    uint16_t eg_ksltl;
    uint8_t eg_out;
    uint8_t eg_silent;
    /* Phase generator */
    uint16_t pg_fnum;
    uint8_t pg_block;
    uint16_t pg_out;
    uint32_t pg_inc;
    uint32_t pg_phase[18];
    uint32_t pg_phase_next;
    /* Operator */
    int16_t op_fb1[9];
    int16_t op_fb2[9];
    int16_t op_fbsum;
    int16_t op_mod;
    uint8_t op_neg;
    uint16_t op_logsin;
    uint16_t op_exp_m;
    uint16_t op_exp_s;
    /* Channel */
    int16_t ch_out;
    int16_t ch_out_hh;
    int16_t ch_out_tm;
    int16_t ch_out_bd;
    int16_t ch_out_sd;
    int16_t ch_out_tc;
    /* LFO */
    uint16_t lfo_counter;
    uint8_t lfo_vib_counter;
    uint16_t lfo_am_counter;
    uint8_t lfo_am_step;
    uint8_t lfo_am_dir;
    uint8_t lfo_am_car;
    uint8_t lfo_am_out;
    /* Register set */
    uint16_t fnum[9];
    uint8_t block[9];
    uint8_t kon[9];
    uint8_t son[9];
    uint8_t vol[9];
    uint8_t inst[9];
    uint8_t rhythm;
    uint8_t testmode;
    opll_patch_t patch;
    uint8_t c_instr;
    uint8_t c_op;
    uint8_t c_tl;
    uint8_t c_dc;
    uint8_t c_dm;
    uint8_t c_fb;
    uint8_t c_am;
    uint8_t c_vib;
    uint8_t c_et;
    uint8_t c_ksr;
    uint8_t c_ksr_freq;
    uint8_t c_ksl_freq;
    uint8_t c_ksl_block;
    uint8_t c_multi;
    uint8_t c_ksl;
    uint8_t c_adrr[3];
    uint8_t c_sl;
    uint16_t c_fnum;
    uint16_t c_block;
    /* Rhythm mode */
    int8_t rm_enable;
    uint32_t rm_noise;
    uint32_t rm_select;
    uint8_t rm_hh_bit2;
    uint8_t rm_hh_bit3;
    uint8_t rm_hh_bit7;
    uint8_t rm_hh_bit8;
    uint8_t rm_tc_bit3;
    uint8_t rm_tc_bit5;

    int16_t output_m;
    int16_t output_r;

} opll_t;

void OPLL_Reset(opll_t *chip, uint32_t chip_type);
void OPLL_Clock(opll_t *chip, int32_t *buffer);
void OPLL_Write(opll_t *chip, uint32_t port, uint8_t data);
#endif
