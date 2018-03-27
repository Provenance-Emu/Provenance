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

#include <iapetus.h>
#include "tests.h"
#include "dsp.h"
#include <stdio.h>
#include <string.h>
#include "main.h"

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
   register_test(&dsp_test_alu, "DSP ALU Test");
   // Time DSP instructions
   register_test(&test_dsp_timing, "DSP Timing");
   do_tests("SCU DSP tests", 0, 0);
   gui_clear_scr(&test_disp_font);
}

//////////////////////////////////////////////////////////////////////////////

void dsp_test_begin(int * yval)
{
   u32 testval = SCU_REG_PPAF;
   testval &= 1;//silence warning

   dsp_stop();

   if (dsp_is_exec())
   {
      vdp_printf(&test_disp_font, 0 * 8, *yval * 8, 0xF, "dsp_is_exec() == 1");
      *yval = *yval+1;
   }

   //set program ram address to 0
   //and load program ram address to pc
   SCU_REG_PPAF = 0x8000;
}

//table of alu results acquired from hardware
struct DspAllResults {
   struct DspResultsForOneInstruction {
      struct DspSingleResult {
         u32 val[5];
      }results_of_value_combination[16];
   }instruction_results[12];
};

struct DspAllResults dsp_alu_all_results =
{
   {
      { { { { 0x00000001, 0x00000001, 0x00000000, 0x00000001, 0x00000025 } }, { { 0x00000001, 0xffffffff, 0x00000000, 0x00000001, 0x00000025 } }, { { 0x00000001, 0x00ffffff, 0x00000000, 0x00000001, 0x00000025 } }, { { 0x00000001, 0xff000000, 0x00000000, 0x00000001, 0x00000025 } }, { { 0xffffffff, 0x00000001, 0xffffffff, 0xffffffff, 0x00000025 } }, { { 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0x00000025 } }, { { 0xffffffff, 0x00ffffff, 0xffffffff, 0xffffffff, 0x00000025 } }, { { 0xffffffff, 0xff000000, 0xffffffff, 0xffffffff, 0x00000025 } }, { { 0x00ffffff, 0x00000001, 0x000000ff, 0x00ffffff, 0x00000025 } }, { { 0x00ffffff, 0xffffffff, 0x000000ff, 0x00ffffff, 0x00000025 } }, { { 0x00ffffff, 0x00ffffff, 0x000000ff, 0x00ffffff, 0x00000025 } }, { { 0x00ffffff, 0xff000000, 0x000000ff, 0x00ffffff, 0x00000025 } }, { { 0xff000000, 0x00000001, 0xffffff00, 0xff000000, 0x00000025 } }, { { 0xff000000, 0xffffffff, 0xffffff00, 0xff000000, 0x00000025 } }, { { 0xff000000, 0x00ffffff, 0xffffff00, 0xff000000, 0x00000025 } }, { { 0xff000000, 0xff000000, 0xffffff00, 0xff000000, 0x00000025 } } } },
      { { { { 0x00000001, 0x00000001, 0x00000000, 0x00000001, 0x00000025 } }, { { 0x00000001, 0xffffffff, 0x00000000, 0x00000001, 0x00000025 } }, { { 0x00000001, 0x00ffffff, 0x00000000, 0x00000001, 0x00000025 } }, { { 0x00000001, 0xff000000, 0x00000000, 0x00000000, 0x00200025 } }, { { 0xffffffff, 0x00000001, 0xffff0000, 0x00000001, 0x00000025 } }, { { 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0x00400025 } }, { { 0xffffffff, 0x00ffffff, 0xffff00ff, 0x00ffffff, 0x00000025 } }, { { 0xffffffff, 0xff000000, 0xffffff00, 0xff000000, 0x00400025 } }, { { 0x00ffffff, 0x00000001, 0x00000000, 0x00000001, 0x00000025 } }, { { 0x00ffffff, 0xffffffff, 0x000000ff, 0x00ffffff, 0x00000025 } }, { { 0x00ffffff, 0x00ffffff, 0x000000ff, 0x00ffffff, 0x00000025 } }, { { 0x00ffffff, 0xff000000, 0x00000000, 0x00000000, 0x00200025 } }, { { 0xff000000, 0x00000001, 0xffff0000, 0x00000000, 0x00200025 } }, { { 0xff000000, 0xffffffff, 0xffffff00, 0xff000000, 0x00400025 } }, { { 0xff000000, 0x00ffffff, 0xffff0000, 0x00000000, 0x00200025 } }, { { 0xff000000, 0xff000000, 0xffffff00, 0xff000000, 0x00400025 } } } },
      { { { { 0x00000001, 0x00000001, 0x00000000, 0x00000001, 0x00000025 } }, { { 0x00000001, 0xffffffff, 0x0000ffff, 0xffffffff, 0x00400025 } }, { { 0x00000001, 0x00ffffff, 0x000000ff, 0x00ffffff, 0x00000025 } }, { { 0x00000001, 0xff000000, 0x0000ff00, 0xff000001, 0x00400025 } }, { { 0xffffffff, 0x00000001, 0xffffffff, 0xffffffff, 0x00400025 } }, { { 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0x00400025 } }, { { 0xffffffff, 0x00ffffff, 0xffffffff, 0xffffffff, 0x00400025 } }, { { 0xffffffff, 0xff000000, 0xffffffff, 0xffffffff, 0x00400025 } }, { { 0x00ffffff, 0x00000001, 0x000000ff, 0x00ffffff, 0x00000025 } }, { { 0x00ffffff, 0xffffffff, 0x0000ffff, 0xffffffff, 0x00400025 } }, { { 0x00ffffff, 0x00ffffff, 0x000000ff, 0x00ffffff, 0x00000025 } }, { { 0x00ffffff, 0xff000000, 0x0000ffff, 0xffffffff, 0x00400025 } }, { { 0xff000000, 0x00000001, 0xffffff00, 0xff000001, 0x00400025 } }, { { 0xff000000, 0xffffffff, 0xffffffff, 0xffffffff, 0x00400025 } }, { { 0xff000000, 0x00ffffff, 0xffffffff, 0xffffffff, 0x00400025 } }, { { 0xff000000, 0xff000000, 0xffffff00, 0xff000000, 0x00400025 } } } },
      { { { { 0x00000001, 0x00000001, 0x00000000, 0x00000000, 0x00200025 } }, { { 0x00000001, 0xffffffff, 0x0000ffff, 0xfffffffe, 0x00400025 } }, { { 0x00000001, 0x00ffffff, 0x000000ff, 0x00fffffe, 0x00000025 } }, { { 0x00000001, 0xff000000, 0x0000ff00, 0xff000001, 0x00400025 } }, { { 0xffffffff, 0x00000001, 0xffffffff, 0xfffffffe, 0x00400025 } }, { { 0xffffffff, 0xffffffff, 0xffff0000, 0x00000000, 0x00200025 } }, { { 0xffffffff, 0x00ffffff, 0xffffff00, 0xff000000, 0x00400025 } }, { { 0xffffffff, 0xff000000, 0xffff00ff, 0x00ffffff, 0x00000025 } }, { { 0x00ffffff, 0x00000001, 0x000000ff, 0x00fffffe, 0x00000025 } }, { { 0x00ffffff, 0xffffffff, 0x0000ff00, 0xff000000, 0x00400025 } }, { { 0x00ffffff, 0x00ffffff, 0x00000000, 0x00000000, 0x00200025 } }, { { 0x00ffffff, 0xff000000, 0x0000ffff, 0xffffffff, 0x00400025 } }, { { 0xff000000, 0x00000001, 0xffffff00, 0xff000001, 0x00400025 } }, { { 0xff000000, 0xffffffff, 0xffff00ff, 0x00ffffff, 0x00000025 } }, { { 0xff000000, 0x00ffffff, 0xffffffff, 0xffffffff, 0x00400025 } }, { { 0xff000000, 0xff000000, 0xffff0000, 0x00000000, 0x00200025 } } } },
      { { { { 0x00000001, 0x00000001, 0x00000000, 0x00000002, 0x00000025 } }, { { 0x00000001, 0xffffffff, 0x00000000, 0x00000000, 0x00300025 } }, { { 0x00000001, 0x00ffffff, 0x00000100, 0x01000000, 0x00000025 } }, { { 0x00000001, 0xff000000, 0x0000ff00, 0xff000001, 0x00400025 } }, { { 0xffffffff, 0x00000001, 0xffff0000, 0x00000000, 0x00300025 } }, { { 0xffffffff, 0xffffffff, 0xffffffff, 0xfffffffe, 0x00500025 } }, { { 0xffffffff, 0x00ffffff, 0xffff00ff, 0x00fffffe, 0x00100025 } }, { { 0xffffffff, 0xff000000, 0xfffffeff, 0xfeffffff, 0x00500025 } }, { { 0x00ffffff, 0x00000001, 0x00000100, 0x01000000, 0x00000025 } }, { { 0x00ffffff, 0xffffffff, 0x000000ff, 0x00fffffe, 0x00100025 } }, { { 0x00ffffff, 0x00ffffff, 0x000001ff, 0x01fffffe, 0x00000025 } }, { { 0x00ffffff, 0xff000000, 0x0000ffff, 0xffffffff, 0x00400025 } }, { { 0xff000000, 0x00000001, 0xffffff00, 0xff000001, 0x00400025 } }, { { 0xff000000, 0xffffffff, 0xfffffeff, 0xfeffffff, 0x00500025 } }, { { 0xff000000, 0x00ffffff, 0xffffffff, 0xffffffff, 0x00400025 } }, { { 0xff000000, 0xff000000, 0xfffffe00, 0xfe000000, 0x00500025 } } } },
      { { { { 0x00000001, 0x00000001, 0x00000000, 0x00000000, 0x00200025 } }, { { 0x00000001, 0xffffffff, 0x00000000, 0x00000002, 0x00100025 } }, { { 0x00000001, 0x00ffffff, 0x0000ff00, 0xff000002, 0x00500025 } }, { { 0x00000001, 0xff000000, 0x00000100, 0x01000001, 0x00100025 } }, { { 0xffffffff, 0x00000001, 0xffffffff, 0xfffffffe, 0x00400025 } }, { { 0xffffffff, 0xffffffff, 0xffff0000, 0x00000000, 0x00200025 } }, { { 0xffffffff, 0x00ffffff, 0xffffff00, 0xff000000, 0x00400025 } }, { { 0xffffffff, 0xff000000, 0xffff00ff, 0x00ffffff, 0x00000025 } }, { { 0x00ffffff, 0x00000001, 0x000000ff, 0x00fffffe, 0x00000025 } }, { { 0x00ffffff, 0xffffffff, 0x00000100, 0x01000000, 0x00100025 } }, { { 0x00ffffff, 0x00ffffff, 0x00000000, 0x00000000, 0x00200025 } }, { { 0x00ffffff, 0xff000000, 0x000001ff, 0x01ffffff, 0x00100025 } }, { { 0xff000000, 0x00000001, 0xfffffeff, 0xfeffffff, 0x00400025 } }, { { 0xff000000, 0xffffffff, 0xffffff00, 0xff000001, 0x00500025 } }, { { 0xff000000, 0x00ffffff, 0xfffffe00, 0xfe000001, 0x00400025 } }, { { 0xff000000, 0xff000000, 0xffff0000, 0x00000000, 0x00200025 } } } },
      { { { { 0x00000001, 0x00000001, 0x00000000, 0x00000002, 0x00000025 } }, { { 0x00000001, 0xffffffff, 0x00000000, 0x00000000, 0x00300025 } }, { { 0x00000001, 0x00ffffff, 0x00000100, 0x01000000, 0x00000025 } }, { { 0x00000001, 0xff000000, 0xffffff00, 0xff000001, 0x00400025 } }, { { 0xffffffff, 0x00000001, 0x00000000, 0x00000000, 0x00300025 } }, { { 0xffffffff, 0xffffffff, 0xffffffff, 0xfffffffe, 0x00500025 } }, { { 0xffffffff, 0x00ffffff, 0x000000ff, 0x00fffffe, 0x00100025 } }, { { 0xffffffff, 0xff000000, 0xfffffeff, 0xfeffffff, 0x00500025 } }, { { 0x00ffffff, 0x00000001, 0x00000100, 0x01000000, 0x00000025 } }, { { 0x00ffffff, 0xffffffff, 0x000000ff, 0x00fffffe, 0x00100025 } }, { { 0x00ffffff, 0x00ffffff, 0x000001ff, 0x01fffffe, 0x00000025 } }, { { 0x00ffffff, 0xff000000, 0xffffffff, 0xffffffff, 0x00400025 } }, { { 0xff000000, 0x00000001, 0xffffff00, 0xff000001, 0x00400025 } }, { { 0xff000000, 0xffffffff, 0xfffffeff, 0xfeffffff, 0x00500025 } }, { { 0xff000000, 0x00ffffff, 0xffffffff, 0xffffffff, 0x00400025 } }, { { 0xff000000, 0xff000000, 0xfffffe00, 0xfe000000, 0x00500025 } } } },
      { { { { 0x00000001, 0x00000001, 0x00000000, 0x00000000, 0x00300025 } }, { { 0x00000001, 0xffffffff, 0x00000000, 0x00000000, 0x00300025 } }, { { 0x00000001, 0x00ffffff, 0x00000000, 0x00000000, 0x00300025 } }, { { 0x00000001, 0xff000000, 0x00000000, 0x00000000, 0x00300025 } }, { { 0xffffffff, 0x00000001, 0xffffffff, 0xffffffff, 0x00500025 } }, { { 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0x00500025 } }, { { 0xffffffff, 0x00ffffff, 0xffffffff, 0xffffffff, 0x00500025 } }, { { 0xffffffff, 0xff000000, 0xffffffff, 0xffffffff, 0x00500025 } }, { { 0x00ffffff, 0x00000001, 0x0000007f, 0x007fffff, 0x00100025 } }, { { 0x00ffffff, 0xffffffff, 0x0000007f, 0x007fffff, 0x00100025 } }, { { 0x00ffffff, 0x00ffffff, 0x0000007f, 0x007fffff, 0x00100025 } }, { { 0x00ffffff, 0xff000000, 0x0000007f, 0x007fffff, 0x00100025 } }, { { 0xff000000, 0x00000001, 0xffffff80, 0xff800000, 0x00400025 } }, { { 0xff000000, 0xffffffff, 0xffffff80, 0xff800000, 0x00400025 } }, { { 0xff000000, 0x00ffffff, 0xffffff80, 0xff800000, 0x00400025 } }, { { 0xff000000, 0xff000000, 0xffffff80, 0xff800000, 0x00400025 } } } },
      { { { { 0x00000001, 0x00000001, 0x00008000, 0x80000000, 0x00500025 } }, { { 0x00000001, 0xffffffff, 0x00008000, 0x80000000, 0x00500025 } }, { { 0x00000001, 0x00ffffff, 0x00008000, 0x80000000, 0x00500025 } }, { { 0x00000001, 0xff000000, 0x00008000, 0x80000000, 0x00500025 } }, { { 0xffffffff, 0x00000001, 0xffffffff, 0xffffffff, 0x00500025 } }, { { 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0x00500025 } }, { { 0xffffffff, 0x00ffffff, 0xffffffff, 0xffffffff, 0x00500025 } }, { { 0xffffffff, 0xff000000, 0xffffffff, 0xffffffff, 0x00500025 } }, { { 0x00ffffff, 0x00000001, 0x0000807f, 0x807fffff, 0x00500025 } }, { { 0x00ffffff, 0xffffffff, 0x0000807f, 0x807fffff, 0x00500025 } }, { { 0x00ffffff, 0x00ffffff, 0x0000807f, 0x807fffff, 0x00500025 } }, { { 0x00ffffff, 0xff000000, 0x0000807f, 0x807fffff, 0x00500025 } }, { { 0xff000000, 0x00000001, 0xffff7f80, 0x7f800000, 0x00000025 } }, { { 0xff000000, 0xffffffff, 0xffff7f80, 0x7f800000, 0x00000025 } }, { { 0xff000000, 0x00ffffff, 0xffff7f80, 0x7f800000, 0x00000025 } }, { { 0xff000000, 0xff000000, 0xffff7f80, 0x7f800000, 0x00000025 } } } },
      { { { { 0x00000001, 0x00000001, 0x00000000, 0x00000002, 0x00000025 } }, { { 0x00000001, 0xffffffff, 0x00000000, 0x00000002, 0x00000025 } }, { { 0x00000001, 0x00ffffff, 0x00000000, 0x00000002, 0x00000025 } }, { { 0x00000001, 0xff000000, 0x00000000, 0x00000002, 0x00000025 } }, { { 0xffffffff, 0x00000001, 0xffffffff, 0xfffffffe, 0x00500025 } }, { { 0xffffffff, 0xffffffff, 0xffffffff, 0xfffffffe, 0x00500025 } }, { { 0xffffffff, 0x00ffffff, 0xffffffff, 0xfffffffe, 0x00500025 } }, { { 0xffffffff, 0xff000000, 0xffffffff, 0xfffffffe, 0x00500025 } }, { { 0x00ffffff, 0x00000001, 0x000001ff, 0x01fffffe, 0x00000025 } }, { { 0x00ffffff, 0xffffffff, 0x000001ff, 0x01fffffe, 0x00000025 } }, { { 0x00ffffff, 0x00ffffff, 0x000001ff, 0x01fffffe, 0x00000025 } }, { { 0x00ffffff, 0xff000000, 0x000001ff, 0x01fffffe, 0x00000025 } }, { { 0xff000000, 0x00000001, 0xfffffe00, 0xfe000000, 0x00500025 } }, { { 0xff000000, 0xffffffff, 0xfffffe00, 0xfe000000, 0x00500025 } }, { { 0xff000000, 0x00ffffff, 0xfffffe00, 0xfe000000, 0x00500025 } }, { { 0xff000000, 0xff000000, 0xfffffe00, 0xfe000000, 0x00500025 } } } },
      { { { { 0x00000001, 0x00000001, 0x00000000, 0x00000002, 0x00000025 } }, { { 0x00000001, 0xffffffff, 0x00000000, 0x00000002, 0x00000025 } }, { { 0x00000001, 0x00ffffff, 0x00000000, 0x00000002, 0x00000025 } }, { { 0x00000001, 0xff000000, 0x00000000, 0x00000002, 0x00000025 } }, { { 0xffffffff, 0x00000001, 0xffffffff, 0xffffffff, 0x00500025 } }, { { 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0x00500025 } }, { { 0xffffffff, 0x00ffffff, 0xffffffff, 0xffffffff, 0x00500025 } }, { { 0xffffffff, 0xff000000, 0xffffffff, 0xffffffff, 0x00500025 } }, { { 0x00ffffff, 0x00000001, 0x000001ff, 0x01fffffe, 0x00000025 } }, { { 0x00ffffff, 0xffffffff, 0x000001ff, 0x01fffffe, 0x00000025 } }, { { 0x00ffffff, 0x00ffffff, 0x000001ff, 0x01fffffe, 0x00000025 } }, { { 0x00ffffff, 0xff000000, 0x000001ff, 0x01fffffe, 0x00000025 } }, { { 0xff000000, 0x00000001, 0xfffffe00, 0xfe000001, 0x00500025 } }, { { 0xff000000, 0xffffffff, 0xfffffe00, 0xfe000001, 0x00500025 } }, { { 0xff000000, 0x00ffffff, 0xfffffe00, 0xfe000001, 0x00500025 } }, { { 0xff000000, 0xff000000, 0xfffffe00, 0xfe000001, 0x00500025 } } } },
      { { { { 0x00000001, 0x00000001, 0x00000000, 0x00000100, 0x00000025 } }, { { 0x00000001, 0xffffffff, 0x00000000, 0x00000100, 0x00000025 } }, { { 0x00000001, 0x00ffffff, 0x00000000, 0x00000100, 0x00000025 } }, { { 0x00000001, 0xff000000, 0x00000000, 0x00000100, 0x00000025 } }, { { 0xffffffff, 0x00000001, 0xffffffff, 0xffffffff, 0x00500025 } }, { { 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0x00500025 } }, { { 0xffffffff, 0x00ffffff, 0xffffffff, 0xffffffff, 0x00500025 } }, { { 0xffffffff, 0xff000000, 0xffffffff, 0xffffffff, 0x00500025 } }, { { 0x00ffffff, 0x00000001, 0x0000ffff, 0xffffff00, 0x00400025 } }, { { 0x00ffffff, 0xffffffff, 0x0000ffff, 0xffffff00, 0x00400025 } }, { { 0x00ffffff, 0x00ffffff, 0x0000ffff, 0xffffff00, 0x00400025 } }, { { 0x00ffffff, 0xff000000, 0x0000ffff, 0xffffff00, 0x00400025 } }, { { 0xff000000, 0x00000001, 0xffff0000, 0x000000ff, 0x00100025 } }, { { 0xff000000, 0xffffffff, 0xffff0000, 0x000000ff, 0x00100025 } }, { { 0xff000000, 0x00ffffff, 0xffff0000, 0x000000ff, 0x00100025 } }, { { 0xff000000, 0xff000000, 0xffff0000, 0x000000ff, 0x00100025 } } } }
   }
};

struct DspAllResults dsp_alu_all_results_dma =
{
   {
      { { { { 0x10000000, 0x10000000, 0x00001000, 0x10000000, 0x00100027 } }, { { 0x10000000, 0x50000000, 0x00001000, 0x10000000, 0x00100027 } }, { { 0x10000000, 0x90000000, 0x00001000, 0x10000000, 0x00100027 } }, { { 0x10000000, 0xd0000000, 0x00001000, 0x10000000, 0x00100027 } }, { { 0x50000000, 0x10000000, 0x00005000, 0x50000000, 0x00100027 } }, { { 0x50000000, 0x50000000, 0x00005000, 0x50000000, 0x00100027 } }, { { 0x50000000, 0x90000000, 0x00005000, 0x50000000, 0x00100027 } }, { { 0x50000000, 0xd0000000, 0x00005000, 0x50000000, 0x00100027 } }, { { 0x90000000, 0x10000000, 0xffff9000, 0x90000000, 0x00100027 } }, { { 0x90000000, 0x50000000, 0xffff9000, 0x90000000, 0x00100027 } }, { { 0x90000000, 0x90000000, 0xffff9000, 0x90000000, 0x00100027 } }, { { 0x90000000, 0xd0000000, 0xffff9000, 0x90000000, 0x00100027 } }, { { 0xd0000000, 0x10000000, 0xffffd000, 0xd0000000, 0x00100027 } }, { { 0xd0000000, 0x50000000, 0xffffd000, 0xd0000000, 0x00100027 } }, { { 0xd0000000, 0x90000000, 0xffffd000, 0xd0000000, 0x00100027 } }, { { 0xd0000000, 0xd0000000, 0xffffd000, 0xd0000000, 0x00100027 } } } },
      { { { { 0x10000000, 0x10000000, 0x00001000, 0x10000000, 0x00000027 } }, { { 0x10000000, 0x50000000, 0x00001000, 0x10000000, 0x00000027 } }, { { 0x10000000, 0x90000000, 0x00001000, 0x10000000, 0x00000027 } }, { { 0x10000000, 0xd0000000, 0x00001000, 0x10000000, 0x00000027 } }, { { 0x50000000, 0x10000000, 0x00001000, 0x10000000, 0x00000027 } }, { { 0x50000000, 0x50000000, 0x00005000, 0x50000000, 0x00000027 } }, { { 0x50000000, 0x90000000, 0x00001000, 0x10000000, 0x00000027 } }, { { 0x50000000, 0xd0000000, 0x00005000, 0x50000000, 0x00000027 } }, { { 0x90000000, 0x10000000, 0xffff1000, 0x10000000, 0x00000027 } }, { { 0x90000000, 0x50000000, 0xffff1000, 0x10000000, 0x00000027 } }, { { 0x90000000, 0x90000000, 0xffff9000, 0x90000000, 0x00400027 } }, { { 0x90000000, 0xd0000000, 0xffff9000, 0x90000000, 0x00400027 } }, { { 0xd0000000, 0x10000000, 0xffff1000, 0x10000000, 0x00000027 } }, { { 0xd0000000, 0x50000000, 0xffff5000, 0x50000000, 0x00000027 } }, { { 0xd0000000, 0x90000000, 0xffff9000, 0x90000000, 0x00400027 } }, { { 0xd0000000, 0xd0000000, 0xffffd000, 0xd0000000, 0x00400027 } } } },
      { { { { 0x10000000, 0x10000000, 0x00001000, 0x10000000, 0x00000027 } }, { { 0x10000000, 0x50000000, 0x00005000, 0x50000000, 0x00000027 } }, { { 0x10000000, 0x90000000, 0x00009000, 0x90000000, 0x00400027 } }, { { 0x10000000, 0xd0000000, 0x0000d000, 0xd0000000, 0x00400027 } }, { { 0x50000000, 0x10000000, 0x00005000, 0x50000000, 0x00000027 } }, { { 0x50000000, 0x50000000, 0x00005000, 0x50000000, 0x00000027 } }, { { 0x50000000, 0x90000000, 0x0000d000, 0xd0000000, 0x00400027 } }, { { 0x50000000, 0xd0000000, 0x0000d000, 0xd0000000, 0x00400027 } }, { { 0x90000000, 0x10000000, 0xffff9000, 0x90000000, 0x00400027 } }, { { 0x90000000, 0x50000000, 0xffffd000, 0xd0000000, 0x00400027 } }, { { 0x90000000, 0x90000000, 0xffff9000, 0x90000000, 0x00400027 } }, { { 0x90000000, 0xd0000000, 0xffffd000, 0xd0000000, 0x00400027 } }, { { 0xd0000000, 0x10000000, 0xffffd000, 0xd0000000, 0x00400027 } }, { { 0xd0000000, 0x50000000, 0xffffd000, 0xd0000000, 0x00400027 } }, { { 0xd0000000, 0x90000000, 0xffffd000, 0xd0000000, 0x00400027 } }, { { 0xd0000000, 0xd0000000, 0xffffd000, 0xd0000000, 0x00400027 } } } },
      { { { { 0x10000000, 0x10000000, 0x00000000, 0x00000000, 0x00200027 } }, { { 0x10000000, 0x50000000, 0x00004000, 0x40000000, 0x00000027 } }, { { 0x10000000, 0x90000000, 0x00008000, 0x80000000, 0x00400027 } }, { { 0x10000000, 0xd0000000, 0x0000c000, 0xc0000000, 0x00400027 } }, { { 0x50000000, 0x10000000, 0x00004000, 0x40000000, 0x00000027 } }, { { 0x50000000, 0x50000000, 0x00000000, 0x00000000, 0x00200027 } }, { { 0x50000000, 0x90000000, 0x0000c000, 0xc0000000, 0x00400027 } }, { { 0x50000000, 0xd0000000, 0x00008000, 0x80000000, 0x00400027 } }, { { 0x90000000, 0x10000000, 0xffff8000, 0x80000000, 0x00400027 } }, { { 0x90000000, 0x50000000, 0xffffc000, 0xc0000000, 0x00400027 } }, { { 0x90000000, 0x90000000, 0xffff0000, 0x00000000, 0x00200027 } }, { { 0x90000000, 0xd0000000, 0xffff4000, 0x40000000, 0x00000027 } }, { { 0xd0000000, 0x10000000, 0xffffc000, 0xc0000000, 0x00400027 } }, { { 0xd0000000, 0x50000000, 0xffff8000, 0x80000000, 0x00400027 } }, { { 0xd0000000, 0x90000000, 0xffff4000, 0x40000000, 0x00000027 } }, { { 0xd0000000, 0xd0000000, 0xffff0000, 0x00000000, 0x00200027 } } } },
      { { { { 0x10000000, 0x10000000, 0x00002000, 0x20000000, 0x00000027 } }, { { 0x10000000, 0x50000000, 0x00006000, 0x60000000, 0x00000027 } }, { { 0x10000000, 0x90000000, 0x0000a000, 0xa0000000, 0x00400027 } }, { { 0x10000000, 0xd0000000, 0x0000e000, 0xe0000000, 0x00400027 } }, { { 0x50000000, 0x10000000, 0x00006000, 0x60000000, 0x00000027 } }, { { 0x50000000, 0x50000000, 0x0000a000, 0xa0000000, 0x00400027 } }, { { 0x50000000, 0x90000000, 0x0000e000, 0xe0000000, 0x00400027 } }, { { 0x50000000, 0xd0000000, 0x00002000, 0x20000000, 0x00100027 } }, { { 0x90000000, 0x10000000, 0xffffa000, 0xa0000000, 0x00400027 } }, { { 0x90000000, 0x50000000, 0xffffe000, 0xe0000000, 0x00400027 } }, { { 0x90000000, 0x90000000, 0xffff2000, 0x20000000, 0x00100027 } }, { { 0x90000000, 0xd0000000, 0xffff6000, 0x60000000, 0x00100027 } }, { { 0xd0000000, 0x10000000, 0xffffe000, 0xe0000000, 0x00400027 } }, { { 0xd0000000, 0x50000000, 0xffff2000, 0x20000000, 0x00100027 } }, { { 0xd0000000, 0x90000000, 0xffff6000, 0x60000000, 0x00100027 } }, { { 0xd0000000, 0xd0000000, 0xffffa000, 0xa0000000, 0x00500027 } } } },
      { { { { 0x10000000, 0x10000000, 0x00000000, 0x00000000, 0x00200027 } }, { { 0x10000000, 0x50000000, 0x0000c000, 0xc0000000, 0x00500027 } }, { { 0x10000000, 0x90000000, 0x00008000, 0x80000000, 0x00500027 } }, { { 0x10000000, 0xd0000000, 0x00004000, 0x40000000, 0x00100027 } }, { { 0x50000000, 0x10000000, 0x00004000, 0x40000000, 0x00000027 } }, { { 0x50000000, 0x50000000, 0x00000000, 0x00000000, 0x00200027 } }, { { 0x50000000, 0x90000000, 0x0000c000, 0xc0000000, 0x00500027 } }, { { 0x50000000, 0xd0000000, 0x00008000, 0x80000000, 0x00500027 } }, { { 0x90000000, 0x10000000, 0xffff8000, 0x80000000, 0x00400027 } }, { { 0x90000000, 0x50000000, 0xffff4000, 0x40000000, 0x00000027 } }, { { 0x90000000, 0x90000000, 0xffff0000, 0x00000000, 0x00200027 } }, { { 0x90000000, 0xd0000000, 0xffffc000, 0xc0000000, 0x00500027 } }, { { 0xd0000000, 0x10000000, 0xffffc000, 0xc0000000, 0x00400027 } }, { { 0xd0000000, 0x50000000, 0xffff8000, 0x80000000, 0x00400027 } }, { { 0xd0000000, 0x90000000, 0xffff4000, 0x40000000, 0x00000027 } }, { { 0xd0000000, 0xd0000000, 0xffff0000, 0x00000000, 0x00200027 } } } },
      { { { { 0x10000000, 0x10000000, 0x00002000, 0x20000000, 0x00000027 } }, { { 0x10000000, 0x50000000, 0x00006000, 0x60000000, 0x00000027 } }, { { 0x10000000, 0x90000000, 0xffffa000, 0xa0000000, 0x00400027 } }, { { 0x10000000, 0xd0000000, 0xffffe000, 0xe0000000, 0x00400027 } }, { { 0x50000000, 0x10000000, 0x00006000, 0x60000000, 0x00000027 } }, { { 0x50000000, 0x50000000, 0x0000a000, 0xa0000000, 0x00000027 } }, { { 0x50000000, 0x90000000, 0xffffe000, 0xe0000000, 0x00400027 } }, { { 0x50000000, 0xd0000000, 0x00002000, 0x20000000, 0x00100027 } }, { { 0x90000000, 0x10000000, 0xffffa000, 0xa0000000, 0x00400027 } }, { { 0x90000000, 0x50000000, 0xffffe000, 0xe0000000, 0x00400027 } }, { { 0x90000000, 0x90000000, 0xffff2000, 0x20000000, 0x00500027 } }, { { 0x90000000, 0xd0000000, 0xffff6000, 0x60000000, 0x00500027 } }, { { 0xd0000000, 0x10000000, 0xffffe000, 0xe0000000, 0x00400027 } }, { { 0xd0000000, 0x50000000, 0x00002000, 0x20000000, 0x00100027 } }, { { 0xd0000000, 0x90000000, 0xffff6000, 0x60000000, 0x00500027 } }, { { 0xd0000000, 0xd0000000, 0xffffa000, 0xa0000000, 0x00500027 } } } },
      { { { { 0x10000000, 0x10000000, 0x00000800, 0x08000000, 0x00000027 } }, { { 0x10000000, 0x50000000, 0x00000800, 0x08000000, 0x00000027 } }, { { 0x10000000, 0x90000000, 0x00000800, 0x08000000, 0x00000027 } }, { { 0x10000000, 0xd0000000, 0x00000800, 0x08000000, 0x00000027 } }, { { 0x50000000, 0x10000000, 0x00002800, 0x28000000, 0x00000027 } }, { { 0x50000000, 0x50000000, 0x00002800, 0x28000000, 0x00000027 } }, { { 0x50000000, 0x90000000, 0x00002800, 0x28000000, 0x00000027 } }, { { 0x50000000, 0xd0000000, 0x00002800, 0x28000000, 0x00000027 } }, { { 0x90000000, 0x10000000, 0xffffc800, 0xc8000000, 0x00400027 } }, { { 0x90000000, 0x50000000, 0xffffc800, 0xc8000000, 0x00400027 } }, { { 0x90000000, 0x90000000, 0xffffc800, 0xc8000000, 0x00400027 } }, { { 0x90000000, 0xd0000000, 0xffffc800, 0xc8000000, 0x00400027 } }, { { 0xd0000000, 0x10000000, 0xffffe800, 0xe8000000, 0x00400027 } }, { { 0xd0000000, 0x50000000, 0xffffe800, 0xe8000000, 0x00400027 } }, { { 0xd0000000, 0x90000000, 0xffffe800, 0xe8000000, 0x00400027 } }, { { 0xd0000000, 0xd0000000, 0xffffe800, 0xe8000000, 0x00400027 } } } },
      { { { { 0x10000000, 0x10000000, 0x00000800, 0x08000000, 0x00000027 } }, { { 0x10000000, 0x50000000, 0x00000800, 0x08000000, 0x00000027 } }, { { 0x10000000, 0x90000000, 0x00000800, 0x08000000, 0x00000027 } }, { { 0x10000000, 0xd0000000, 0x00000800, 0x08000000, 0x00000027 } }, { { 0x50000000, 0x10000000, 0x00002800, 0x28000000, 0x00000027 } }, { { 0x50000000, 0x50000000, 0x00002800, 0x28000000, 0x00000027 } }, { { 0x50000000, 0x90000000, 0x00002800, 0x28000000, 0x00000027 } }, { { 0x50000000, 0xd0000000, 0x00002800, 0x28000000, 0x00000027 } }, { { 0x90000000, 0x10000000, 0xffff4800, 0x48000000, 0x00000027 } }, { { 0x90000000, 0x50000000, 0xffff4800, 0x48000000, 0x00000027 } }, { { 0x90000000, 0x90000000, 0xffff4800, 0x48000000, 0x00000027 } }, { { 0x90000000, 0xd0000000, 0xffff4800, 0x48000000, 0x00000027 } }, { { 0xd0000000, 0x10000000, 0xffff6800, 0x68000000, 0x00000027 } }, { { 0xd0000000, 0x50000000, 0xffff6800, 0x68000000, 0x00000027 } }, { { 0xd0000000, 0x90000000, 0xffff6800, 0x68000000, 0x00000027 } }, { { 0xd0000000, 0xd0000000, 0xffff6800, 0x68000000, 0x00000027 } } } },
      { { { { 0x10000000, 0x10000000, 0x00002000, 0x20000000, 0x00000027 } }, { { 0x10000000, 0x50000000, 0x00002000, 0x20000000, 0x00000027 } }, { { 0x10000000, 0x90000000, 0x00002000, 0x20000000, 0x00000027 } }, { { 0x10000000, 0xd0000000, 0x00002000, 0x20000000, 0x00000027 } }, { { 0x50000000, 0x10000000, 0x0000a000, 0xa0000000, 0x00400027 } }, { { 0x50000000, 0x50000000, 0x0000a000, 0xa0000000, 0x00400027 } }, { { 0x50000000, 0x90000000, 0x0000a000, 0xa0000000, 0x00400027 } }, { { 0x50000000, 0xd0000000, 0x0000a000, 0xa0000000, 0x00400027 } }, { { 0x90000000, 0x10000000, 0xffff2000, 0x20000000, 0x00100027 } }, { { 0x90000000, 0x50000000, 0xffff2000, 0x20000000, 0x00100027 } }, { { 0x90000000, 0x90000000, 0xffff2000, 0x20000000, 0x00100027 } }, { { 0x90000000, 0xd0000000, 0xffff2000, 0x20000000, 0x00100027 } }, { { 0xd0000000, 0x10000000, 0xffffa000, 0xa0000000, 0x00500027 } }, { { 0xd0000000, 0x50000000, 0xffffa000, 0xa0000000, 0x00500027 } }, { { 0xd0000000, 0x90000000, 0xffffa000, 0xa0000000, 0x00500027 } }, { { 0xd0000000, 0xd0000000, 0xffffa000, 0xa0000000, 0x00500027 } } } },
      { { { { 0x10000000, 0x10000000, 0x00002000, 0x20000000, 0x00000027 } }, { { 0x10000000, 0x50000000, 0x00002000, 0x20000000, 0x00000027 } }, { { 0x10000000, 0x90000000, 0x00002000, 0x20000000, 0x00000027 } }, { { 0x10000000, 0xd0000000, 0x00002000, 0x20000000, 0x00000027 } }, { { 0x50000000, 0x10000000, 0x0000a000, 0xa0000000, 0x00400027 } }, { { 0x50000000, 0x50000000, 0x0000a000, 0xa0000000, 0x00400027 } }, { { 0x50000000, 0x90000000, 0x0000a000, 0xa0000000, 0x00400027 } }, { { 0x50000000, 0xd0000000, 0x0000a000, 0xa0000000, 0x00400027 } }, { { 0x90000000, 0x10000000, 0xffff2000, 0x20000001, 0x00100027 } }, { { 0x90000000, 0x50000000, 0xffff2000, 0x20000001, 0x00100027 } }, { { 0x90000000, 0x90000000, 0xffff2000, 0x20000001, 0x00100027 } }, { { 0x90000000, 0xd0000000, 0xffff2000, 0x20000001, 0x00100027 } }, { { 0xd0000000, 0x10000000, 0xffffa000, 0xa0000001, 0x00500027 } }, { { 0xd0000000, 0x50000000, 0xffffa000, 0xa0000001, 0x00500027 } }, { { 0xd0000000, 0x90000000, 0xffffa000, 0xa0000001, 0x00500027 } }, { { 0xd0000000, 0xd0000000, 0xffffa000, 0xa0000001, 0x00500027 } } } },
      { { { { 0x10000000, 0x10000000, 0x00000000, 0x00000010, 0x00000027 } }, { { 0x10000000, 0x50000000, 0x00000000, 0x00000010, 0x00000027 } }, { { 0x10000000, 0x90000000, 0x00000000, 0x00000010, 0x00000027 } }, { { 0x10000000, 0xd0000000, 0x00000000, 0x00000010, 0x00000027 } }, { { 0x50000000, 0x10000000, 0x00000000, 0x00000050, 0x00000027 } }, { { 0x50000000, 0x50000000, 0x00000000, 0x00000050, 0x00000027 } }, { { 0x50000000, 0x90000000, 0x00000000, 0x00000050, 0x00000027 } }, { { 0x50000000, 0xd0000000, 0x00000000, 0x00000050, 0x00000027 } }, { { 0x90000000, 0x10000000, 0xffff0000, 0x00000090, 0x00000027 } }, { { 0x90000000, 0x50000000, 0xffff0000, 0x00000090, 0x00000027 } }, { { 0x90000000, 0x90000000, 0xffff0000, 0x00000090, 0x00000027 } }, { { 0x90000000, 0xd0000000, 0xffff0000, 0x00000090, 0x00000027 } }, { { 0xd0000000, 0x10000000, 0xffff0000, 0x000000d0, 0x00000027 } }, { { 0xd0000000, 0x50000000, 0xffff0000, 0x000000d0, 0x00000027 } }, { { 0xd0000000, 0x90000000, 0xffff0000, 0x000000d0, 0x00000027 } }, { { 0xd0000000, 0xd0000000, 0xffff0000, 0x000000d0, 0x00000027 } } } }
   }
};

static int dsp_output_offset = 0;

//result string copied to end of vdp1 ram
void dsp_copy_str_to_offset(char*result)
{
   char* dest = (char *)VDP1_RAM + dsp_output_offset + 0x70000;
   strcpy(dest, result);
   dsp_output_offset += strlen(result);
}

void dsp_test_end(int * yval, int count, int which_test, int * test_status, struct DspAllResults *results)
{
   dsp_exec(0);

   while (dsp_is_exec()) {}

   //get flags
   u32 ppaf = SCU_REG_PPAF;

   //read data regs
   int i;
   u32 ppd[4];
   for (i = 0; i < 4; i++)
   {
      //select data ram
      SCU_REG_PDA = (i << 6) | 0;
      ppd[i] = SCU_REG_PDD;
   }

   char result[64] = { 0 };

   //format into C struct and write result to memory
   if (count == 15)
   {
      sprintf(result, "{0x%08x, 0x%08x, 0x%08x, 0x%08x, 0x%08x}", (unsigned int)ppd[0], (unsigned int)ppd[1], (unsigned int)ppd[2], (unsigned int)ppd[3], (unsigned int)ppaf);
   }
   else
   {
      sprintf(result, "{0x%08x, 0x%08x, 0x%08x, 0x%08x, 0x%08x},", (unsigned int)ppd[0], (unsigned int)ppd[1], (unsigned int)ppd[2], (unsigned int)ppd[3], (unsigned int)ppaf);
   }

   dsp_copy_str_to_offset(result);

   //check that the data matches and print it to the screen
   int x = 0;
   char str[64] = { 0 };
   for (i = 0; i < 4; i++)
   {
      
      int color = 0xf;
      if (ppd[i] != results->instruction_results[which_test].results_of_value_combination[count].val[i])
      {
         color = 40;//red, result doesn't match the table. test failed
         stage_status = STAGESTAT_BADDATA;
         *test_status = 0xdead;//test failed
      }
      //print reg data
      sprintf(str, "%08x", (unsigned int)ppd[i]);
      vdp_printf(&test_disp_font, x * 8, *yval * 8, color, str);
      x += 9;
   }

   //hardware tested flag values
   int ppaf_correct = results->instruction_results[which_test].results_of_value_combination[count].val[4];

   int flags[4] = { 0 };
   int flags_correct[4] = { 0 };

   //get the flag bits
   for (i = 0; i < 4; i++)
   {
      flags[i] = (ppaf >> (22-i)) & 1;
      flags_correct[i] = (ppaf_correct >> (22-i)) & 1;
   }

  for (i = 0; i < 4; i++)
  {
      int color = 0xf;
      //check that the flags match
      if (flags[i] != flags_correct[i])
      {
         color = 40;//wrong, test failed
         stage_status = STAGESTAT_BADDATA;
         *test_status = 0xdead;//test failed
      }
      //print flag
      sprintf(str, "%01x", (unsigned int)flags[i]);
      vdp_printf(&test_disp_font, x * 8, *yval * 8, color, str);
      x += 1;
   }

   *yval = *yval + 1;
}

void dsp_test_alu_write_program(int*yval, int imm_a, int imm_b, u32 instruction, int count, int which_test, int*test_status, int dma_type)
{
   dsp_test_begin(yval);

   int i;

   //clear beginning of data ram
   for (i = 0; i < 6; i++)
   {
      SCU_REG_PPD = MVI_Imm_d(0, MVIDEST_MC0);
      SCU_REG_PPD = MVI_Imm_d(0, MVIDEST_MC1);
      SCU_REG_PPD = MVI_Imm_d(0, MVIDEST_MC2);
      SCU_REG_PPD = MVI_Imm_d(0, MVIDEST_MC3);
   }

   //reset counters
   SCU_REG_PPD = MOV_Imm_d(0, MOVDEST_CT0);
   SCU_REG_PPD = MOV_Imm_d(0, MOVDEST_CT1);
   SCU_REG_PPD = MOV_Imm_d(0, MOVDEST_CT2);
   SCU_REG_PPD = MOV_Imm_d(0, MOVDEST_CT3);

   if (dma_type)
   {
      //dma the variable from high wram to ram0
      SCU_REG_PPD = MVI_Imm_d((0x06000000 + 0x80000) >> 2, MVIDEST_RA0);
      SCU_REG_PPD = DMA_D0_RAM_Imm(DMAADD_4, DMARAM_0, 1);

      //dma the variable from high wram to ram1
      SCU_REG_PPD = MVI_Imm_d((0x06000000 + 0x90000) >> 2, MVIDEST_RA0);
      SCU_REG_PPD = DMA_D0_RAM_Imm(DMAADD_4, DMARAM_1, 1);
   }
   else
   {
      //load immediate values to md0 and md1
      SCU_REG_PPD = MVI_Imm_d(imm_a, MVIDEST_MC0);
      SCU_REG_PPD = MVI_Imm_d(imm_b, MVIDEST_MC1);
   }

   //reset counters
   SCU_REG_PPD = MOV_Imm_d(0, MOVDEST_CT0);
   SCU_REG_PPD = MOV_Imm_d(0, MOVDEST_CT1);

   //load acl and pl with md0 and md1 values
   SCU_REG_PPD = MOV_s_A(MOVSRC_MC0P) | MOV_s_P(MOVSRC_MC1P);

   //MOV_ALU_A needs to be used to preserve the value so we can get both parts
   SCU_REG_PPD = instruction | MOV_ALU_A() |  MOV_s_d(MOVSRC_ALUH, MOVDEST_MC2);

   //move alul
   SCU_REG_PPD = MOV_s_d(MOVSRC_ALUL, MOVDEST_MC3);
   SCU_REG_PPD = END();

   if (dma_type)
   {
      dsp_test_end(yval, count, which_test, test_status, &dsp_alu_all_results_dma);
   }
   else
   {
      dsp_test_end(yval, count, which_test, test_status, &dsp_alu_all_results);
   }
}

void dsp_test_alu()
{
   int yval = 0;
   int test_status = 0;

   int test_vals[] = {
      0x0000001,  //  1
      0x1FFFFFF,  // -1
      0x0FFFFFF,  //  16777215
      0x1000000   // -16777216
   };

   int dma_test_vals[] = {
      0x10000000,
      0x50000000,
      0x90000000,
      0xD0000000
   };

   u32 test_commands[] = { NOP(), AND(), OR(), XOR(), ADD(), SUB(), AD2(), SR(), RR(), SL(), RL(), RL8() };
   char* names[] = { "NOP","AND", "OR", "XOR", "ADD", "SUB", "AD2", "SR", "RR", "SL", "RL", "RL8" };
   char* test_type_name[] = { "Immediate","DMA" };
   char output_str[128] = { 0 };

   int which_test;//nop / and / etc...
   int test_type;//immediate or dma

   for (test_type = 0; test_type < 2; test_type++)
   {
      for (which_test = 0; which_test < sizeof(test_commands) / sizeof(test_commands[0]); which_test++)
      {
         //print name of test
         char str1[64] = { 0 };
         sprintf(str1, "%s %s", names[which_test], test_type_name[test_type]);
         vdp_printf(&test_disp_font, 0 * 8, yval * 8, 0xF, str1);
         yval += 2;

         //print reg names
         vdp_printf(&test_disp_font, 0 * 8, yval * 8, 0xF, "ACL      PL       ALUH     ALUL     SZCV");
         yval++;

         int count = 0;
         sprintf(output_str, "%s", "{{");
         dsp_copy_str_to_offset(output_str);

         int num_vals = sizeof(test_vals) / sizeof(test_vals[0]);
         int k;
         for (k = 0; k < num_vals; k++)
         {
            int i;
            for (i = 0; i < num_vals; i++)
            {
               int a = test_vals[k];
               int b = test_vals[i];

               if (test_type == 1)
               {
                  u32* ptr = (u32*)((0x06000000 + 0x80000));
                  ptr[0] = dma_test_vals[k];
                  ptr = (u32*)((0x06000000 + 0x90000));
                  ptr[0] = dma_test_vals[i];
               }

               dsp_test_alu_write_program(&yval, a, b, test_commands[which_test], count, which_test, &test_status, test_type);
               count++;
            }
         }

         //don't place a comma if it is the last line
         if (which_test == 11)
         {
            sprintf(output_str, "%s", "}}\n");
         }
         else
         {
            sprintf(output_str, "%s", "}},\n");
         }

         dsp_copy_str_to_offset(output_str);

         //we don't want to require user input if in auto mode
#ifndef BUILD_AUTOMATED_TESTING
         for (;;)
         {
            vdp_vsync();

            //start to advance to the next test
            if (per[0].but_push_once & PAD_START)
            {

               int q;
               u32* dest = (u32 *)VDP2_RAM;

               //clear framebuffer
               for (q = 0; q < 0x10000; q++)
               {
                  dest[q] = 0;
               }
               yval = 0;
               break;
            }

            //exit to ar menu to retrieve data
            if (per[0].but_push_once & PAD_X)
            {
               sprintf(output_str, "%s", "}};\n\0");
               dsp_copy_str_to_offset(output_str);
               ar_menu();
               break;
            }

            if (per[0].but_push_once & PAD_Y)
            {
               reset_system();
               break;
            }
         }
#else
         yval = 0;//reset printf y counter
#endif
      }
   }

   //check if the test failed
   if (test_status != 0xdead)
   {
      stage_status = STAGESTAT_DONE;
   }
}

void test_dsp()
{
   // This test sets up the DSP with a very simple program and checks to see
   // if we can get it to execute correctly

   // Still doesn't work correctly on a real system. I don't know why. Somehow
   // the pause flag is getting set

   // Clear out program control port
   u32 testval = SCU_REG_PPAF;
   // Make sure program is stopped, etc.
   dsp_stop();

   if (dsp_is_exec())
   {
      vdp_printf(&test_disp_font, 0 * 8, 20 * 8, 0xF, "dsp_is_exec() == 1");
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   // Setup DSP so we can send a program to it
   SCU_REG_PPAF = 0x8000;

   // Upload our program(END instruction)
   SCU_REG_PPD = END();
   SCU_REG_PPD = 0x00000000;
   SCU_REG_PPD = END();
   SCU_REG_PPD = END();
   SCU_REG_PPD = END();
   SCU_REG_PPD = END();

   if ((SCU_REG_PPAF & 0xFF) != 0x06)
   {
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   // Start executing program
   dsp_exec(0);

   // Check the flags
   while (dsp_is_exec()) {}

   testval = SCU_REG_PPAF;

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
   u32 testval = SCU_REG_PPAF;
   testval &= 1; // fix warning

   // Make sure program is stopped, etc.
   SCU_REG_PPAF = 0; 

   // Setup DSP so we can send a program to it
   SCU_REG_PPAF = 0x8000;

   // Upload our program
   SCU_REG_PPD = command;

   // Execute program step
   SCU_REG_PPAF = 0x20000;

   while (SCU_REG_PPAF == 0x20000) {}
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
   while (SCU_REG_PPAF & 0x10000) {}

   // Let's see what the data ports hold
   SCU_REG_PDA = (0 << 6) | 0;
   if (SCU_REG_PDD != 0xFF0DEAD0)
   {
      vdp_printf(&test_disp_font, 0 * 8, 21 * 8, 0xF, "SCUREG_PDD != 0xFF0DEAD0(%08X)", SCU_REG_PDD);
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   SCU_REG_PDA = (1 << 6) | 0;
   if (SCU_REG_PDD != 0xFF1DEAD0)
   {
      vdp_printf(&test_disp_font, 0 * 8, 22 * 8, 0xF, "SCUREG_PDD != 0xFF1DEAD0(%08X)", SCU_REG_PDD);
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   SCU_REG_PDA = (2 << 6) | 0;
   if (SCU_REG_PDD != 0xFF2DEAD0)
   {
      vdp_printf(&test_disp_font, 0 * 8, 22 * 8, 0xF, "SCUREG_PDD != 0xFF2DEAD0(%08X)", SCU_REG_PDD);
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   SCU_REG_PDA = (3 << 6) | 0;
   if (SCU_REG_PDD != 0xFF3DEAD0)
   {
      vdp_printf(&test_disp_font, 0 * 8, 22 * 8, 0xF, "SCUREG_PDD != 0xFF3DEAD0(%08X)", SCU_REG_PDD);
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   // Ok, that looks good. Now check the PC, and we're done!
   if ((SCU_REG_PPAF & 0xFF) != 0xEF)
   {
      vdp_printf(&test_disp_font, 0 * 8, 22 * 8, 0xF, "(SCUREG_PPAF & 0xFF) != 0xEF(%08X)", SCU_REG_PPAF);
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
   SCU_REG_PDA = (0 << 6) | 0;
   test_val = SCU_REG_PDD;

   if (test_val != 0xB40F)
   {
      vdp_printf(&test_disp_font, 0 * 8, 23 * 8, 0xF, "SCUREG_PDD != 0xB40F(%08X)", test_val);
      stage_status = STAGESTAT_BADTIMING;
      return;
   }

   stage_status = STAGESTAT_DONE;
}

//////////////////////////////////////////////////////////////////////////////
