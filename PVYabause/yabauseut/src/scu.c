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

//#include <lapetus.h>
#include "tests.h"
#include "dsp.h"
#include "scu.h"

#define SCUREG_D0R   (*(volatile u32 *)0x25FE0000)
#define SCUREG_D0W   (*(volatile u32 *)0x25FE0004)
#define SCUREG_D0C   (*(volatile u32 *)0x25FE0008)
#define SCUREG_D0AD  (*(volatile u32 *)0x25FE000C)
#define SCUREG_D0EN  (*(volatile u32 *)0x25FE0010)
#define SCUREG_D0MD  (*(volatile u32 *)0x25FE0014)

#define SCUREG_D1R   (*(volatile u32 *)0x25FE0020)
#define SCUREG_D1W   (*(volatile u32 *)0x25FE0024)
#define SCUREG_D1C   (*(volatile u32 *)0x25FE0028)
#define SCUREG_D1AD  (*(volatile u32 *)0x25FE002C)
#define SCUREG_D1EN  (*(volatile u32 *)0x25FE0030)
#define SCUREG_D1MD  (*(volatile u32 *)0x25FE0034)

#define SCUREG_D2R   (*(volatile u32 *)0x25FE0040)
#define SCUREG_D2W   (*(volatile u32 *)0x25FE0044)
#define SCUREG_D2C   (*(volatile u32 *)0x25FE0048)
#define SCUREG_D2AD  (*(volatile u32 *)0x25FE004C)
#define SCUREG_D2EN  (*(volatile u32 *)0x25FE0050)
#define SCUREG_D2MD  (*(volatile u32 *)0x25FE0054)

#define SCUREG_DSTP  (*(volatile u32 *)0x25FE0060)
#define SCUREG_DSTA  (*(volatile u32 *)0x25FE0070)

#define SCUREG_T0C   (*(volatile u32 *)0x25FE0090)
#define SCUREG_T1S   (*(volatile u32 *)0x25FE0094)
#define SCUREG_T1MD  (*(volatile u32 *)0x25FE0098)

#define SCUREG_IMS   (*(volatile u32 *)0x25FE00A0)
#define SCUREG_IMS   (*(volatile u32 *)0x25FE00A0)

#define SCUREG_IMS   (*(volatile u32 *)0x25FE00A0)
#define SCUREG_IST   (*(volatile u32 *)0x25FE00A4)

#define SCUREG_AIACK (*(volatile u32 *)0x25FE00A8)
#define SCUREG_ASR0  (*(volatile u32 *)0x25FE00B0)
#define SCUREG_ASR1  (*(volatile u32 *)0x25FE00B4)

#define SCUREG_RSEL  (*(volatile u32 *)0x25FE00C4)
#define SCUREG_VER   (*(volatile u32 *)0x25FE00C8)

//////////////////////////////////////////////////////////////////////////////

void scu_test()
{
   int choice;

   menu_item_struct scumenu[] = {
   { "Register Test", &scu_register_test, },
   { "Interrupt Test", &scu_int_test, },
   { "DMA Test" , &scu_dma_test, },
   { "DSP Test" , &scu_dsp_test, },
//   { "Misc" , &scumisctest, },
   { "\0", NULL }
   };

   for (;;)
   {
      choice = gui_do_menu(scumenu, &test_disp_font, 0, 0, "SCU Menu", MTYPE_CENTER, -1);
      if (choice == -1)
         break;
   }   
}

//////////////////////////////////////////////////////////////////////////////

void scu_register_test(void)
{
   interrupt_set_level_mask(0xF);

   init_iapetus(RES_320x224);
   vdp_rbg0_init(&test_disp_settings);
   vdp_set_default_palette();

   // Display On
   vdp_disp_on();

   unregister_all_tests();
   register_test(&test_scu_ver_register, "VER Register");

   do_tests("SCU Register tests", 0, 0);
}

//////////////////////////////////////////////////////////////////////////////

void scu_int_test()
{
   interrupt_set_level_mask(0xF);

   init_iapetus(RES_320x224);
   vdp_rbg0_init(&test_disp_settings);
   vdp_set_default_palette();

   // Display On
   vdp_disp_on();

   unregister_all_tests();
//   register_test(&TestISTandIMS, "Interrupt status and mask");
   register_test(&test_vblank_in_interrupt, "Vblank-out Interrupt");
   register_test(&test_vblank_out_interrupt, "Vblank-in Interrupt");
   register_test(&test_hblank_in_interrupt, "HBlank-in Interrupt");
   register_test(&test_timer0_interrupt, "Timer 0 Interrupt");
   register_test(&test_timer1_interrupt, "Timer 1 Interrupt");
   register_test(&test_dsp_end_interrupt, "DSP End Interrupt");
   register_test(&test_sound_request_interrupt, "Sound Request Interrupt");
   register_test(&test_smpc_interrupt, "SMPC Interrupt");
   register_test(&test_pad_interrupt, "Pad Interrupt");
   register_test(&test_dma0_interrupt, "DMA0 Interrupt");
   register_test(&test_dma1_interrupt, "DMA1 Interrupt");
   register_test(&test_dma2_interrupt, "DMA2 Interrupt");
   register_test(&test_dma_illegal_interrupt, "Illegal DMA Interrupt");
   register_test(&test_sprite_draw_end_interrupt, "Sprite Draw End Interrupt");
//   register_test(&TestCDBlockInterrupt, "CD Block Interrupt");
   // If Netlink is connected, do a test on it too
//   if (NetlinkInit() == IAPETUS_ERR_OK)
//      register_test(&TestNetlinkInterrupt, "Netlink Interrupt");
   do_tests("SCU Interrupt tests", 0, 0);
}

//////////////////////////////////////////////////////////////////////////////

void scu_dma_test()
{
   interrupt_set_level_mask(0xF);

   init_iapetus(RES_320x224);
   vdp_rbg0_init(&test_disp_settings);
   vdp_set_default_palette();

   // Display On
   vdp_disp_on();

   unregister_all_tests();
   register_test(&test_dma0, "DMA 0 transfer");
   register_test(&test_dma1, "DMA 1 transfer");
   register_test(&test_dma2, "DMA 2 transfer");
   register_test(&test_dma_misalignment, "Misaligned DMA transfer");
   register_test(&test_indirect_dma, "Indirect DMA transfer");
//   register_test(&TestTransNum0, "0 Transfer Number transfer");
//   register_test(&TestDMAStatus, "DMA Status Register");
   // Test out DMA start factors here

//   register_test(&, );
   do_tests("SCU DMA tests", 0, 0);
}

//////////////////////////////////////////////////////////////////////////////

void test_scu_ver_register()
{
   // Make sure it's at least version 4
   if (SCUREG_VER < 4)
      stage_status = STAGESTAT_BADDATA;
   else
      stage_status = STAGESTAT_DONE;
}

//////////////////////////////////////////////////////////////////////////////

int is_int_time=0;
void (*old_func)();
u8 int_vector;
u32 old_mask;

void test_int_func()
{
   interrupt_set_level_mask(0xF);

   // Return interrupt settings back to normal
   bios_set_scu_interrupt(int_vector, old_func);
   bios_set_scu_interrupt_mask(old_mask);

   if (is_int_time)
      stage_status = STAGESTAT_DONE;
   else
      stage_status = STAGESTAT_BADINTERRUPT;

   is_int_time = 0;

   if (int_vector >= 0x50)
   {
      // Need to do an A-bus interrupt acknowledge
   }
}

//////////////////////////////////////////////////////////////////////////////

void setup_interrupt(u8 vector, u32 mask)
{
   interrupt_set_level_mask(0xF);
   int_vector = vector;
   stage_status = STAGESTAT_WAITINGFORINT;
   old_func = bios_get_scu_interrupt(int_vector);
   old_mask = bios_get_scu_interrupt_mask();
   bios_set_scu_interrupt_mask(0xFFFFFFFF);
   bios_set_scu_interrupt(int_vector, test_int_func);
   is_int_time = 1;
   bios_change_scu_interrupt_mask(~mask, 0);
}

//////////////////////////////////////////////////////////////////////////////

void test_vblank_in_interrupt()
{
   setup_interrupt(0x40, MASK_VBLANKIN);

   interrupt_set_level_mask(0xE);
}

//////////////////////////////////////////////////////////////////////////////

void test_vblank_out_interrupt()
{
   setup_interrupt(0x41, MASK_VBLANKOUT);

   interrupt_set_level_mask(0xD);
}

//////////////////////////////////////////////////////////////////////////////

void test_hblank_in_interrupt()
{
   setup_interrupt(0x42, MASK_HBLANKIN);

   interrupt_set_level_mask(0xC);
}

//////////////////////////////////////////////////////////////////////////////

void test_timer0_interrupt()
{
   setup_interrupt(0x43, MASK_TIMER0);

   // Enable Timer 0 compare
   SCUREG_T1MD = 0x001;
   SCUREG_T0C = 19;

   interrupt_set_level_mask(0xB);
}

//////////////////////////////////////////////////////////////////////////////

void test_timer1_interrupt()
{
   SCUREG_T1MD = 0;
   SCUREG_T1S = 100;

   setup_interrupt(0x44, MASK_TIMER1);
   SCUREG_T1MD = 1;

   interrupt_set_level_mask(0xA);
}

//////////////////////////////////////////////////////////////////////////////

void test_dsp_end_interrupt()
{
   u32 dsp_prog[1];

   setup_interrupt(0x45, MASK_DSPEND);

   dsp_prog[0] = ENDI();

   if (dsp_load(dsp_prog, 0, 1) != IAPETUS_ERR_OK)
   {
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   dsp_exec(0);

   interrupt_set_level_mask(0x9);
}

//////////////////////////////////////////////////////////////////////////////

void test_sound_request_interrupt()
{
   setup_interrupt(0x46,  MASK_SNDREQUEST);

   // Reset all Sound interrupts
   *((volatile u16*)0x25B0042E) = 0x7FF;

   // Set MCIEB to reset when we write to bit 5 of MCIPD
   *((volatile u16*)0x25B0042A) = 0x20;

   // trigger interrupt using MCIPD
   *((volatile u16*)0x25B0042C) = 0x20;

   interrupt_set_level_mask(0x8);
}

//////////////////////////////////////////////////////////////////////////////

void test_smpc_interrupt()
{
   setup_interrupt(0x47, MASK_SYSTEMMANAGER);
   smpc_wait_till_ready();
   SMPC_REG_IREG(0) = 0x00; // no intback status
   SMPC_REG_IREG(1) = 0x0A; // 15-byte mode, peripheral data returned, time optimized
   SMPC_REG_IREG(2) = 0xF0; // ???
   smpc_issue_command(SMPC_CMD_INTBACK);
   interrupt_set_level_mask(0x7);
}

//////////////////////////////////////////////////////////////////////////////

void test_pad_interrupt()
{
   setup_interrupt(0x48, MASK_PAD);
   // Insert triggering mechanism here(fix me) - How does this one even work?
   SMPC_REG_DDR1 = 0x60;
   SMPC_REG_IOSEL = 0x1;
   SMPC_REG_EXLE = 1;
   interrupt_set_level_mask(0x7);
}

//////////////////////////////////////////////////////////////////////////////

void test_dma0_interrupt()
{
   setup_interrupt(0x4B, MASK_DMA0);

   // Do a quick DMA
   SCUREG_D0EN = 0;
   SCUREG_D0R = 0x060F0000;
   SCUREG_D0W = 0x25C40000;
   SCUREG_D0C = 0x4;
   SCUREG_D0AD = 0x101;
   SCUREG_D0MD = 0x00000007;
   SCUREG_D0EN = 0x101;

   interrupt_set_level_mask(0x4);
}

//////////////////////////////////////////////////////////////////////////////

void test_dma1_interrupt()
{
   setup_interrupt(0x4A, MASK_DMA1);

   // Do a quick DMA
   SCUREG_D1EN = 0;
   SCUREG_D1R = 0x060F0000;
   SCUREG_D1W = 0x25C40000;
   SCUREG_D1C = 0x4;
   SCUREG_D1AD = 0x101;
   SCUREG_D1MD = 0x00000007;
   SCUREG_D1EN = 0x101;

   interrupt_set_level_mask(0x5);
}

//////////////////////////////////////////////////////////////////////////////

void test_dma2_interrupt()
{
   setup_interrupt(0x49, MASK_DMA2);

   // Do a quick DMA
   SCUREG_D2EN = 0;
   SCUREG_D2R = 0x060F0000;
   SCUREG_D2W = 0x25C40000;
   SCUREG_D2C = 0x4;
   SCUREG_D2AD = 0x101;
   SCUREG_D2MD = 0x00000007;
   SCUREG_D2EN = 0x101;

   interrupt_set_level_mask(0x5);
}

//////////////////////////////////////////////////////////////////////////////

void test_dma_illegal_interrupt()
{
   setup_interrupt(0x4C, MASK_DMAILLEGAL);

   // Insert triggering mechanism here(fix me)
   // Do a quick DMA
   SCUREG_D0EN = 0;
   SCUREG_D0R = 0x060F0000;
   SCUREG_D0W = 0;
   SCUREG_D0C = 0x4;
   SCUREG_D0AD = 0x101;
   SCUREG_D0MD = 0x00000007;
   SCUREG_D0EN = 0x101;
   interrupt_set_level_mask(0x2);
}

//////////////////////////////////////////////////////////////////////////////

void test_sprite_draw_end_interrupt()
{
   sprite_struct localcoord;

   setup_interrupt(0x4D, MASK_DRAWEND);

   localcoord.attr = 0;
   localcoord.x = 0;
   localcoord.y = 0;

   vdp_start_draw_list();
   vdp_local_coordinate(&localcoord);
   vdp_end_draw_list();

   interrupt_set_level_mask(0x1);
}

//////////////////////////////////////////////////////////////////////////////

void test_cd_block_interrupt()
{
   setup_interrupt(0x50, 0x10000);

   // Unmask Subcode Q irq
   CDB_REG_HIRQ = ~HIRQ_SCDQ;
   CDB_REG_HIRQMASK = ~HIRQ_SCDQ;

   interrupt_set_level_mask(0x6);
}

//////////////////////////////////////////////////////////////////////////////

u32 dma_val_test;

void dma_int (void)
{
   bios_set_scu_interrupt(0x49, 0);
   bios_set_scu_interrupt(0x4A, 0);
   bios_set_scu_interrupt(0x4B, 0);
   bios_change_scu_interrupt_mask(0xFFFFFFFF, 0x800 | 0x400 | 0x200);

   if (*((volatile u32 *)0x25C40000) != dma_val_test)
   {
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   interrupt_set_level_mask(0xF);

   stage_status = STAGESTAT_DONE;
}

//////////////////////////////////////////////////////////////////////////////

void test_dma0()
{
   dma_val_test = 0x02030405;
   *((volatile u32 *)0x260F0000) = dma_val_test;

   bios_set_scu_interrupt(0x4B, dma_int);
   bios_change_scu_interrupt_mask(~MASK_DMA0, 0);
   stage_status = STAGESTAT_WAITINGFORINT;

   // Do a quick DMA
   SCUREG_D0EN = 0;
   SCUREG_D0R = 0x060F0000;
   SCUREG_D0W = 0x25C40000;
   SCUREG_D0C = 0x4;
   SCUREG_D0AD = 0x101;
   SCUREG_D0MD = 0x00000007;
   SCUREG_D0EN = 0x101;

   interrupt_set_level_mask(0x4);
}

//////////////////////////////////////////////////////////////////////////////

void test_dma1()
{
   dma_val_test = 0x02030405;
   *((volatile u32 *)0x260F0000) = dma_val_test;

   bios_set_scu_interrupt(0x4A, dma_int);
   bios_change_scu_interrupt_mask(~MASK_DMA1, 0);
   stage_status = STAGESTAT_WAITINGFORINT;

   // Do a quick DMA
   SCUREG_D1EN = 0;
   SCUREG_D1R = 0x060F0000;
   SCUREG_D1W = 0x25C40000;
   SCUREG_D1C = 0x4;
   SCUREG_D1AD = 0x101;
   SCUREG_D1MD = 0x00000007;
   SCUREG_D1EN = 0x101;

   interrupt_set_level_mask(0x5);
}

//////////////////////////////////////////////////////////////////////////////

void test_dma2()
{
   dma_val_test = 0x02030405;
   *((volatile u32 *)0x260F0000) = dma_val_test;

   bios_set_scu_interrupt(0x49, dma_int);
   bios_change_scu_interrupt_mask(~MASK_DMA2, 0);
   stage_status = STAGESTAT_WAITINGFORINT;

   // Do a quick DMA
   SCUREG_D2EN = 0;
   SCUREG_D2R = 0x060F0000;
   SCUREG_D2W = 0x25C40000;
   SCUREG_D2C = 0x4;
   SCUREG_D2AD = 0x101;
   SCUREG_D2MD = 0x00000007;
   SCUREG_D2EN = 0x101;

   interrupt_set_level_mask(0x5);
}

//////////////////////////////////////////////////////////////////////////////

void test_dma_misalignment()
{
   *((volatile u32 *)0x260F0000) = 0x00010203;
   *((volatile u32 *)0x260F0004) = 0x04050600;
   dma_val_test = 0x02030405;

   bios_set_scu_interrupt(0x4B, dma_int);
   bios_change_scu_interrupt_mask(~MASK_DMA0, 0);
   stage_status = STAGESTAT_WAITINGFORINT;

   // Do a quick DMA
   SCUREG_D0EN = 0;
   SCUREG_D0R = 0x060F0001;
   SCUREG_D0W = 0x25C3FFFF;
   SCUREG_D0C = 0x5;
   SCUREG_D0AD = 0x101;
   SCUREG_D0MD = 0x00000007;
   SCUREG_D0EN = 0x101;

   interrupt_set_level_mask(0x4);
}

//////////////////////////////////////////////////////////////////////////////

void test_indirect_dma()
{
   static u32 dma_array[3 * 3];
   static u32 dma_data_array[] = {
      0x02030405,
      0x0708090A, 
      0x0C0D0E0F, 
   };

   interrupt_set_level_mask(0xF);

   bios_set_scu_interrupt(0x4B, dma_int);
   bios_change_scu_interrupt_mask(~MASK_DMA0, 0);
   stage_status = STAGESTAT_WAITINGFORINT;

   dma_array[0] = 1;
   dma_array[1] = 0x25C40000;
   dma_array[2] = (u32)dma_data_array;

   dma_array[3] = 2;
   dma_array[4] = 0x25C40001;
   dma_array[5] = (u32)dma_data_array+1;

//   dmaarray[6] = 1;
   dma_array[6] = 0x20000;
   dma_array[7] = 0x05C40003;
   dma_array[8] = 0x80000000 | ((u32)dma_data_array+3);

   // Do an Indirect DMA
   SCUREG_D0EN = 0;
   SCUREG_D0W = ((u32)dma_array);
   SCUREG_D0AD = 0x101;
   SCUREG_D0MD = 0x01000007;
   SCUREG_D0EN = 0x101;

   vdp_printf(&test_disp_font, 0 * 8, 21 * 8, 0xF, "DSTA = %08X", SCUREG_DSTA);

   while (SCUREG_D0EN == 0x101)
   {
      vdp_vsync();
      vdp_printf(&test_disp_font, 0 * 8, 20 * 8, 0xF, "D0EN = %08X", SCUREG_D0EN);
   }

   interrupt_set_level_mask(0x4);
}

//////////////////////////////////////////////////////////////////////////////

void test_ist_and_ims()
{
   // Mask All interrupts
   SCUREG_IMS = 0xBFFF;

   is_int_time = 0;

   // Clear any pending interrupts
   SCUREG_IST = 0;

   // Set DMA 0 interrupt function
//   bios_set_scu_interrupt(0x4B, testintfunc);
//   stagestatus = STAGESTAT_WAITINGFORINT;
   setup_interrupt(0x4B, MASK_DMA0);

   // Do a quick DMA
   SCUREG_D0R = 0x06000C00;
   SCUREG_D0W = 0x05C40000;
   SCUREG_D0C = 4;
   SCUREG_D0AD = 0x102;
   SCUREG_D0MD = 0x00010107;
   SCUREG_D0EN = 0x101;

   // Wait until DMA is finished
   while (SCUREG_DSTA & 0x13) {}

   // Unmask interrupt
   interrupt_set_level_mask(0x4);
   is_int_time = 1;
//   vdp_printf(&test_disp_font, 0 * 8, 10 * 8, 0xF, "%04X", SCUREG_IST);
   SCUREG_IMS = 0xB7FF;

/*
   // wait a while
   for (i = 0; i < (60 * 2); i++)
   {
      wait_vblank_out();
      wait_vblank_in();

      vdp_printf(&test_disp_font, 0 * 8, 11 * 8, 0xF, "%04X", SCUREG_IST);
   }
   interrupt_set_level_mask(0x4);
*/
}

//////////////////////////////////////////////////////////////////////////////



