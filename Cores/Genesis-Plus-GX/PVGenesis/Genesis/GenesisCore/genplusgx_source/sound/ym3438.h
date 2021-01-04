/*
 *  Copyright (C) 2017 Alexey Khokholov (Nuke.YKT)
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
 *  Nuked OPN2(Yamaha YM3438) emulator.
 *  Thanks:
 *      Silicon Pr0n:
 *          Yamaha YM3438 decap and die shot(digshadow).
 *      OPLx decapsulated(Matthew Gambrell, Olli Niemitalo):
 *          OPL2 ROMs.
 *
 * version: 1.0.8
 */

#ifndef YM3438_H
#define YM3438_H

enum {
    ym3438_mode_ym2612 = 0x01,      /* Enables YM2612 emulation (MD1, MD2 VA2) */
    ym3438_mode_readmode = 0x02,    /* Enables status read on any port (TeraDrive, MD1 VA7, MD2, etc) */
};

#include <stdint.h>

typedef uintptr_t       Bitu;
typedef intptr_t        Bits;
typedef uint64_t        Bit64u;
typedef int64_t         Bit64s;
typedef uint32_t        Bit32u;
typedef int32_t         Bit32s;
typedef uint16_t        Bit16u;
typedef int16_t         Bit16s;
typedef uint8_t         Bit8u;
typedef int8_t          Bit8s;

typedef struct
{
    Bit32u cycles;
    Bit32u slot;
    Bit32u channel;
    Bit16s mol, mor;
    /* IO */
    Bit16u write_data;
    Bit8u write_a;
    Bit8u write_d;
    Bit8u write_a_en;
    Bit8u write_d_en;
    Bit8u write_busy;
    Bit8u write_busy_cnt;
    Bit8u write_fm_address;
    Bit8u write_fm_data;
    Bit8u write_fm_mode_a;
    Bit16u address;
    Bit8u data;
    Bit8u pin_test_in;
    Bit8u pin_irq;
    Bit8u busy;
    /* LFO */
    Bit8u lfo_en;
    Bit8u lfo_freq;
    Bit8u lfo_pm;
    Bit8u lfo_am;
    Bit8u lfo_cnt;
    Bit8u lfo_inc;
    Bit8u lfo_quotient;
    /* Phase generator */
    Bit16u pg_fnum;
    Bit8u pg_block;
    Bit8u pg_kcode;
    Bit32u pg_inc[24];
    Bit32u pg_phase[24];
    Bit8u pg_reset[24];
    Bit32u pg_read;
    /* Envelope generator */
    Bit8u eg_cycle;
    Bit8u eg_cycle_stop;
    Bit8u eg_shift;
    Bit8u eg_shift_lock;
    Bit8u eg_timer_low_lock;
    Bit16u eg_timer;
    Bit8u eg_timer_inc;
    Bit16u eg_quotient;
    Bit8u eg_custom_timer;
    Bit8u eg_rate;
    Bit8u eg_ksv;
    Bit8u eg_inc;
    Bit8u eg_ratemax;
    Bit8u eg_sl[2];
    Bit8u eg_lfo_am;
    Bit8u eg_tl[2];
    Bit8u eg_state[24];
    Bit16u eg_level[24];
    Bit16u eg_out[24];
    Bit8u eg_kon[24];
    Bit8u eg_kon_csm[24];
    Bit8u eg_kon_latch[24];
    Bit8u eg_csm_mode[24];
    Bit8u eg_ssg_enable[24];
    Bit8u eg_ssg_pgrst_latch[24];
    Bit8u eg_ssg_repeat_latch[24];
    Bit8u eg_ssg_hold_up_latch[24];
    Bit8u eg_ssg_dir[24];
    Bit8u eg_ssg_inv[24];
    Bit32u eg_read[2];
    Bit8u eg_read_inc;
    /* FM */
    Bit16s fm_op1[6][2];
    Bit16s fm_op2[6];
    Bit16s fm_out[24];
    Bit16u fm_mod[24];
    /* Channel */
    Bit16s ch_acc[6];
    Bit16s ch_out[6];
    Bit16s ch_lock;
    Bit8u ch_lock_l;
    Bit8u ch_lock_r;
    Bit16s ch_read;
    /* Timer */
    Bit16u timer_a_cnt;
    Bit16u timer_a_reg;
    Bit8u timer_a_load_lock;
    Bit8u timer_a_load;
    Bit8u timer_a_enable;
    Bit8u timer_a_reset;
    Bit8u timer_a_load_latch;
    Bit8u timer_a_overflow_flag;
    Bit8u timer_a_overflow;
    
    Bit16u timer_b_cnt;
    Bit8u timer_b_subcnt;
    Bit16u timer_b_reg;
    Bit8u timer_b_load_lock;
    Bit8u timer_b_load;
    Bit8u timer_b_enable;
    Bit8u timer_b_reset;
    Bit8u timer_b_load_latch;
    Bit8u timer_b_overflow_flag;
    Bit8u timer_b_overflow;
    
    /* Register set */
    Bit8u mode_test_21[8];
    Bit8u mode_test_2c[8];
    Bit8u mode_ch3;
    Bit8u mode_kon_channel;
    Bit8u mode_kon_operator[4];
    Bit8u mode_kon[24];
    Bit8u mode_csm;
    Bit8u mode_kon_csm;
    Bit8u dacen;
    Bit16s dacdata;
    
    Bit8u ks[24];
    Bit8u ar[24];
    Bit8u sr[24];
    Bit8u dt[24];
    Bit8u multi[24];
    Bit8u sl[24];
    Bit8u rr[24];
    Bit8u dr[24];
    Bit8u am[24];
    Bit8u tl[24];
    Bit8u ssg_eg[24];
    
    Bit16u fnum[6];
    Bit8u block[6];
    Bit8u kcode[6];
    Bit16u fnum_3ch[6];
    Bit8u block_3ch[6];
    Bit8u kcode_3ch[6];
    Bit8u reg_a4;
    Bit8u reg_ac;
    Bit8u connect[6];
    Bit8u fb[6];
    Bit8u pan_l[6], pan_r[6];
    Bit8u ams[6];
    Bit8u pms[6];
    Bit8u status;
    Bit32u status_time;
} ym3438_t;

void OPN2_Reset(ym3438_t *chip);
void OPN2_SetChipType(Bit32u type);
void OPN2_Clock(ym3438_t *chip, Bit16s *buffer);
void OPN2_Write(ym3438_t *chip, Bit32u port, Bit8u data);
void OPN2_SetTestPin(ym3438_t *chip, Bit32u value);
Bit32u OPN2_ReadTestPin(ym3438_t *chip);
Bit32u OPN2_ReadIRQPin(ym3438_t *chip);
Bit8u OPN2_Read(ym3438_t *chip, Bit32u port);
#endif
