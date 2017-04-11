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
    along with Lapetus; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#ifndef SCSPH
#define SCSPH

void scsp_test();
void scsp_timing_test();
void scsp_misc_test();

void scu_interrupt_test(void);
void scsp_timer_a_test();
void scsp_timer_b_test();
void scsp_timer_c_test();
void scsp_timer_timing_test(u16 timersetting);
void scsp_timer_timing_test0();
void scsp_timer_timing_test1();
void scsp_timer_timing_test2();
void scsp_timer_timing_test3();
void scsp_timer_timing_test4();
void scsp_timer_timing_test5();
void scsp_timer_timing_test6();
void scsp_timer_timing_test7();
void scsp_int_on_timer_enable_test();
void scsp_int_on_timer_reset_test();
void scsp_int_dup_test();
void scsp_mcipd_test();
void scsp_scipd_test();

#endif
