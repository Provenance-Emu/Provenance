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

#include <iapetus.h>
#include "tests.h"
#include "dsp.h"

u32 dspprog[256];

//////////////////////////////////////////////////////////////////////////////

void scu_dsp_test()
{
   interrupt_set_level_mask(0xF);

   init_iapetus(RES_320x224);
   vdp_rbg0_init(&test_disp_settings);
   vdp_set_default_palette();

   // Display On
   vdp_disp_on();

   unregister_all_tests();
   register_test(&test_dsp, "DSP Execution");
   // Test DSP data port
   // Test DSP instructions
   register_test(&test_mvi_imm_d, "MVI Imm, [d]");
   // Time DSP instructions
   register_test(&test_dsp_timing, "DSP Timing");
   do_tests("SCU DSP tests", 0, 0);
}

//////////////////////////////////////////////////////////////////////////////

void test_dsp()
{
   // This test sets up the DSP with a very simple program and checks to see
   // if we can get it to execute correctly

   // Still doesn't work correctly on a real system. I don't know why. Somehow
   // the pause flag is getting set

   // Clear out program control port
   u32 testval = SCUREG_PPAF;
   // Make sure program is stopped, etc.
   dsp_stop();

   if (dsp_is_exec())
   {
      vdp_printf(&test_disp_font, 0 * 8, 20 * 8, 0xF, "dsp_is_exec() == 1");
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   // Setup DSP so we can send a program to it
   SCUREG_PPAF = 0x8000;

   // Upload our program(END instruction)
   SCUREG_PPD = END();
   SCUREG_PPD = 0x00000000;
   SCUREG_PPD = END();
   SCUREG_PPD = END();
   SCUREG_PPD = END();
   SCUREG_PPD = END();

   if ((SCUREG_PPAF & 0xFF) != 0x06)
   {
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   // Start executing program
   dsp_exec(0);

   // Check the flags
   while (dsp_is_exec()) {}

   testval = SCUREG_PPAF;

   if (testval != 0x02)
   {
      vdp_printf(&test_disp_font, 0 * 8, 20 * 8, 0xF, "testval != 0x02(%08X)", testval);
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   stage_status = STAGESTAT_DONE;
}

//////////////////////////////////////////////////////////////////////////////

void exec_dsp_command(u32 command)
{
   // Clear out program control port
   u32 testval = SCUREG_PPAF;
   testval = 0; // fix warning

   // Make sure program is stopped, etc.
   SCUREG_PPAF = 0; 

   // Setup DSP so we can send a program to it
   SCUREG_PPAF = 0x8000;

   // Upload our program
   SCUREG_PPD = command;

   // Execute program step
   SCUREG_PPAF = 0x20000;

   while (SCUREG_PPAF == 0x20000) {}
}

//////////////////////////////////////////////////////////////////////////////

void fill_dsp_prog(u32 cmd)
{
   int i;

   for (i = 0; i < 256; i++)
      dspprog[i] = cmd;
}

//////////////////////////////////////////////////////////////////////////////

void test_mvi_imm_d()
{
   fill_dsp_prog(END());

   dspprog[0] = MOV_Imm_d(0, MOVDEST_CT0);
   dspprog[1] = MOV_Imm_d(0, MOVDEST_CT1);
   dspprog[2] = MOV_Imm_d(0, MOVDEST_CT2);
   dspprog[3] = MOV_Imm_d(0, MOVDEST_CT3);

   // MVI 0x10DEAD0, MC0
   dspprog[4] = 0x810DEAD0;
   // MVI 0x11DEAD0, MC1
   dspprog[5] = 0x851DEAD0;
   // MVI 0x12DEAD0, MC2
   dspprog[6] = 0x892DEAD0;
   // MVI 0x12DEAD0, MC3
   dspprog[7] = 0x8D3DEAD0;

   // MVI to RX, PL, RA0, WA0
   // Copy RX, PL, RA0, WA0 to MC0

   // MVI 0x1FEEDED to PC
   dspprog[8] = 0xB1FEEDED;
   // NOP
   dspprog[9] = NOP();
   dspprog[0xEE] = NOP();

   if (dsp_load(dspprog, 0, 255) != IAPETUS_ERR_OK)
   {
      vdp_printf(&test_disp_font, 0 * 8, 20 * 8, 0xF, "dsp_load error");
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   dsp_exec(0);

   // Wait until we're done
   while (SCUREG_PPAF & 0x10000) {}

   // Let's see what the data ports hold
   SCUREG_PDA = (0 << 6) | 0;
   if (SCUREG_PDD != 0xFF0DEAD0)
   {
      vdp_printf(&test_disp_font, 0 * 8, 21 * 8, 0xF, "SCUREG_PDD != 0xFF0DEAD0(%08X)", SCUREG_PDD);
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   SCUREG_PDA = (1 << 6) | 0;
   if (SCUREG_PDD != 0xFF1DEAD0)
   {
      vdp_printf(&test_disp_font, 0 * 8, 22 * 8, 0xF, "SCUREG_PDD != 0xFF1DEAD0(%08X)", SCUREG_PDD);
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   SCUREG_PDA = (2 << 6) | 0;
   if (SCUREG_PDD != 0xFF2DEAD0)
   {
      vdp_printf(&test_disp_font, 0 * 8, 22 * 8, 0xF, "SCUREG_PDD != 0xFF2DEAD0(%08X)", SCUREG_PDD);
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   SCUREG_PDA = (3 << 6) | 0;
   if (SCUREG_PDD != 0xFF3DEAD0)
   {
      vdp_printf(&test_disp_font, 0 * 8, 22 * 8, 0xF, "SCUREG_PDD != 0xFF3DEAD0(%08X)", SCUREG_PDD);
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   // Ok, that looks good. Now check the PC, and we're done!
   if ((SCUREG_PPAF & 0xFF) != 0xEF)
   {
      vdp_printf(&test_disp_font, 0 * 8, 22 * 8, 0xF, "(SCUREG_PPAF & 0xFF) != 0xEF(%08X)", SCUREG_PPAF);
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   // Ok, it works, now try the rest of the destinations
   stage_status = STAGESTAT_DONE;
}

//////////////////////////////////////////////////////////////////////////////

void test_dsp_timing()
{
   u32 freq;
   u32 starttime;
   u32 endtime;
   u32 test_val;

   fill_dsp_prog(NOP());

   dspprog[0] = CLR_A();
   dspprog[1] = MOV_Imm_d(1, MOVDEST_PL);
   dspprog[2] = ADD() | MOV_ALU_A();
   dspprog[4] = MOV_Imm_d(0, MOVDEST_CT0);
   dspprog[5] = MOV_s_d(MOVSRC_ALUL, MOVDEST_MC0);
   dspprog[249] = JMP_Imm(2);

   timer_setup(TIMER_HBLANK, &freq);

   if (dsp_load(dspprog, 0, 255) != IAPETUS_ERR_OK)
   {
      vdp_printf(&test_disp_font, 0 * 8, 20 * 8, 0xF, "dsp_load error");
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   starttime = timer_counter();
   dsp_exec(0);

   // Wait about X number of seconds, etc.
   while (((endtime = timer_counter()) - starttime) < freq) {
      if (!dsp_is_exec())
         vdp_printf(&test_disp_font, 0 * 8, 25 * 8, 0xF, "DSP stopped prematurely");
   }

   // Stop DSP, check counter in data ram to see how much got executed
   dsp_stop();

   // Now we can figure out how much time it took
   SCUREG_PDA = (0 << 6) | 0;
   test_val = SCUREG_PDD;

   if (test_val != 0xB40F)
   {
      vdp_printf(&test_disp_font, 0 * 8, 23 * 8, 0xF, "SCUREG_PDD != 0xB40F(%08X)", test_val);
      stage_status = STAGESTAT_BADTIMING;
      return;
   }

   stage_status = STAGESTAT_DONE;
}

//////////////////////////////////////////////////////////////////////////////
