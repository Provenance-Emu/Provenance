/*  Copyright 2013 Theo Berkau

    This file is part of YabauseUT

    YabauseUT is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    YabauseUT is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with YabauseUT; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#ifndef SCUH
#define SCUH
void scu_test();

void test_scu_ver_register();

void test_vblank_in_interrupt();
void test_vblank_out_interrupt();
void test_hblank_in_interrupt();
void test_timer0_interrupt();
void test_timer1_interrupt();
void test_dsp_end_interrupt();
void test_sound_request_interrupt();
void test_smpc_interrupt();
void test_pad_interrupt();
void test_dma0_interrupt();
void test_dma1_interrupt();
void test_dma2_interrupt();
void test_dma_illegal_interrupt();
void test_sprite_draw_end_interrupt();
void test_cd_block_interrupt();

void TestDMA();
void test_dma0();
void test_dma1();
void test_dma2();
void test_dma_misalignment();
void test_indirect_dma();
void test_ist_and_ims();
void test_dsp();
void test_mvi_imm_d();

void scu_register_test(void);
void scu_int_test(void);
void scu_dma_test();
void scu_dsp_test();

#endif
