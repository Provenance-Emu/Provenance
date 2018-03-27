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
#include "scsp.h"
#include "main.h"
#include <stdio.h>

#define SCSPREG_TIMERA  (*(volatile u16 *)0x25B00418)
#define SCSPREG_TIMERB  (*(volatile u16 *)0x25B0041A)
#define SCSPREG_TIMERC  (*(volatile u16 *)0x25B0041C)

#define SCSPREG_SCIEB   (*(volatile u16 *)0x25B0041E)
#define SCSPREG_SCIPD   (*(volatile u16 *)0x25B00420)
#define SCSPREG_SCIRE   (*(volatile u16 *)0x25B00422)

#define SCSPREG_MCIEB   (*(volatile u16 *)0x25B0042A)
#define SCSPREG_MCIPD   (*(volatile u16 *)0x25B0042C)
#define SCSPREG_MCIRE   (*(volatile u16 *)0x25B0042E)

struct SlotRegs
{
   u8 kx;
   u8 kb;
   u8 sbctl;
   u8 ssctl;
   u8 lpctl;
   u8 pcm8b;
   u32 sa;
   u16 lsa;
   u16 lea;
   u8 d2r;
   u8 d1r;
   u8 hold;
   u8 ar;
   u8 ls;
   u8 krs;
   u8 dl;
   u8 rr;
   u8 si;
   u8 sd;
   u16 tl;
   u8 mdl;
   u8 mdxsl;
   u8 mdysl;
   u8 oct;
   u16 fns;
   u8 re;
   u8 lfof;
   u8 plfows;
   u8 plfos;
   u8 alfows;
   u8 alfos;
   u8 isel;
   u8 imxl;
   u8 disdl;
   u8 dipan;
   u8 efsdl;
   u8 efpan;
};

volatile u32 hblank_counter=0;

int tinc=0;

void scsp_interactive_test();

void vdp1_setup(u32 vdp1_tile_address);
void vdp1_print_str(int x, int y, int palette, u32 vdp1_tile_address, char* str);
void load_font_8x8_to_vram_1bpp_to_4bpp(u32 tile_start_address, u32 ram_pointer);
extern u8 sine_tbl[];

//////////////////////////////////////////////////////////////////////////////

void scsp_test()
{
   int choice;

   menu_item_struct vdp1_menu[] = {
//   { "Individual slots(Mute sound first)" , &scspslottest, },
   { "SCSP timing" , &scsp_timing_test, },
   { "Misc" , &scsp_misc_test, },
//   { "Interactive" , &scspinteractivetest, },
   { "\0", NULL }
   };

   for (;;)
   {
      choice = gui_do_menu(vdp1_menu, &test_disp_font, 0, 0, "SCSP Tests", MTYPE_CENTER, -1);
      if (choice == -1)
         break;
   }
}

//////////////////////////////////////////////////////////////////////////////

void scsp_minimal_init()
{
   // Put system in minimalized state
   interrupt_set_level_mask(0xF);

   init_iapetus(RES_320x224);
   vdp_rbg0_init(&test_disp_settings);
   vdp_set_default_palette();

   // Turn off sound cpu
   smpc_issue_command(0x07);

   // Display On
   vdp_disp_on();
}

//////////////////////////////////////////////////////////////////////////////

void scsp_minimal_slot_init(int slotnum)
{
/*
   void *slot=(void *)(0x25B00000 + (slotnum << 5));

   // Setup slot
   *(volatile u32 *)(slot+0x00) = 0x10300000 | (info->ssctl << 23) | 0; // key off, normal loop, start address
   *(volatile u16 *)(slot+0x04) = 0x0000; // LSA
   *(volatile u16 *)(slot+0x06) = 0x00FF; // LEA
   *(volatile u16 *)(slot+0x08) = (info->d2r << 11) | (info->d1r << 6) | (info->eghold << 5) | info->ar; // Normal D2R, D1R, EGHOLD, AR
   *(volatile u16 *)(slot+0x0A) = (info->lpslnk << 14) | (info->krs << 10) | (info->dl << 5) | info->rr; // Normal LPSLNK, KRS, DL, RR
   *(volatile u16 *)(slot+0x0C) = (info->stwinh << 9) | (info->sdir << 8) | info->tl; // stwinh, sdir, tl
   *(volatile u16 *)(slot+0x0E) = (info->mdl << 12) | (info->mdxsl << 6) | info->mdysl; // modulation stuff
   *(volatile u16 *)(slot+0x10) = (info->oct << 11) | info->fns; // oct/fns
   *(volatile u16 *)(slot+0x12) = (info->lfof << 10) | (info->plfows << 8) | (info->plfos << 5) | (info->alfows << 3) | info->alfos; // lfo
   *(volatile u16 *)(slot+0x14) = (info->isel << 3) | info->imxl; // isel/imxl
   *(volatile u16 *)(slot+0x16) = (info->disdl << 13) | (info->dipan << 8) | (info->efsdl << 5) | info->efpan; //

   // Time to key on
   *(volatile u8 *)(slot+0x00) = 0x18 | (info->ssctl >> 1);
*/
}

//////////////////////////////////////////////////////////////////////////////

void scsp_slot_test()
{
   scsp_minimal_init();
   unregister_all_tests();
   register_test(&scu_interrupt_test, "Key On/Off");
   register_test(&scsp_timer_a_test, "8/16-bit/Noise samples");
   register_test(&scsp_timer_a_test, "Source bit");
   register_test(&scsp_timer_a_test, "Looping");
   register_test(&scsp_timer_a_test, "Octaves"); // not sure I can easily test this
   register_test(&scsp_timer_a_test, "Attack rate"); // not sure I can easily test this
   register_test(&scsp_timer_a_test, "Decay rate"); // not sure I can easily test this
   register_test(&scsp_timer_a_test, "Decay level"); // not sure I can easily test this
   register_test(&scsp_timer_a_test, "Release rate"); // not sure I can easily test this
   register_test(&scsp_timer_a_test, "Total level");
   // modulation test here
   // LFO tests here
   // direct pan/sdl tests here
   do_tests("SCSP Timer tests", 0, 0);
}

//////////////////////////////////////////////////////////////////////////////

void scsp_timing_test()
{
   scsp_minimal_init();
   unregister_all_tests();
   register_test(&scu_interrupt_test, "Sound Request Interrupt");
   register_test(&scsp_timer_a_test, "Timer A");
   register_test(&scsp_timer_b_test, "Timer B");
   register_test(&scsp_timer_c_test, "Timer C");
/*
   register_test(&ScspTimerTimingTest0, "Timer timing w/1 sample inc");
   register_test(&ScspTimerTimingTest1, "Timer timing w/2 sample inc");
   register_test(&ScspTimerTimingTest2, "Timer timing w/4 sample inc");
   register_test(&ScspTimerTimingTest3, "Timer timing w/8 sample inc");
   register_test(&ScspTimerTimingTest4, "Timer timing w/16 sample inc");
   register_test(&ScspTimerTimingTest5, "Timer timing w/32 sample inc");
   register_test(&ScspTimerTimingTest6, "Timer timing w/64 sample inc");
   register_test(&ScspTimerTimingTest7, "Timer timing w/128 sample inc");
*/
   do_tests("SCSP Timer tests", 0, 0);
}

//////////////////////////////////////////////////////////////////////////////

void scsp_misc_test()
{
   scsp_minimal_init();
   unregister_all_tests();
   register_test(&scsp_int_on_timer_enable_test, "Int on Timer enable behaviour");
   register_test(&scsp_int_on_timer_reset_test, "Int on Timer reset behaviour");
   register_test(&scsp_int_dup_test, "No second Int after Timer done");
//   register_test(&scsp_mcipd_test, "MCIPD bit cleared after Timer Int");
   register_test(&scsp_scipd_test, "Timers start after SCIRE write");
   register_test(&scsp_scipd_test, "Timers start after MCIRE write");

   // DMA tests here

   // MSLC/CA tests here

   do_tests("SCSP Interrupt tests", 0, 0);
}

//////////////////////////////////////////////////////////////////////////////

int scsp_counter;

void scsp_interrupt()
{
   scsp_counter++;
}

//////////////////////////////////////////////////////////////////////////////

void scsp_interactive_test()
{
   u16 scieb=0;
   u16 mcieb=0;

   scsp_minimal_init();

   test_disp_font.transparent = 0;
   scsp_counter=0;
   SCSPREG_SCIEB = mcieb;
   SCSPREG_MCIEB = scieb;

   // Mask SCSP interrupt temporarily
   bios_change_scu_interrupt_mask(0xFFFFFFFF, 0x40);

   // Set SCSP interrupt function
   bios_set_scu_interrupt(0x46, scsp_interrupt);

   // Unmask SCSP interrupt
   bios_change_scu_interrupt_mask(~0x40, 0);

   for (;;)
   {
      u16 scipd;
      u16 mcipd;

      vdp_vsync();

#define Refresh(line) \
      scipd = SCSPREG_SCIPD; \
      mcipd = SCSPREG_MCIPD; \
      \
      vdp_printf(&test_disp_font, 2 * 8, line * 8, 0xF, "SCIEB = %04X", scieb); \
      vdp_printf(&test_disp_font, 2 * 8, (line+1) * 8, 0xF, "MCIEB = %04X", mcieb); \
      vdp_printf(&test_disp_font, 2 * 8, (line+2) * 8, 0xF, "SCIPD = %04X", scipd); \
      vdp_printf(&test_disp_font, 2 * 8, (line+3) * 8, 0xF, "MCIPD = %04X", mcipd); \
      vdp_printf(&test_disp_font, 2 * 8, (line+4)* 8, 0xF, "int counter = %d", scsp_counter);

      Refresh(17);

      if (per[0].but_push_once & PAD_A)
      {
         SCSPREG_TIMERA = 0x700;
         Refresh(23);
      }
      else if (per[0].but_push_once & PAD_B)
      {
         SCSPREG_TIMERA = 0x07FF;
         Refresh(23);
      }
      else if (per[0].but_push_once & PAD_C)
      {
         SCSPREG_SCIRE = 0x40;
         Refresh(23);
      }
      else if (per[0].but_push_once & PAD_X)
      {
         mcieb ^= 0x40;
         SCSPREG_MCIEB = mcieb;
         Refresh(23);
      }
      else if (per[0].but_push_once & PAD_Y)
      {
         SCSPREG_MCIRE = 0x40;
         Refresh(23);
      }
      else if (per[0].but_push_once & PAD_L)
      {
         mcieb ^= 0x20;
         SCSPREG_MCIEB = mcieb;
         Refresh(23);
      }
      else if (per[0].but_push_once & PAD_R)
      {
         if (SCSPREG_MCIPD & 0x20)
            SCSPREG_MCIRE = 0x20;
         else
            SCSPREG_MCIPD = 0x20;
         Refresh(23);
      }
   }
}

//////////////////////////////////////////////////////////////////////////////

void scsp_int_test_func()
{
   stage_status = STAGESTAT_DONE;

   // Mask SCSP interrupts
   bios_change_scu_interrupt_mask(0xFFFFFFFF, 0x40);
}

//////////////////////////////////////////////////////////////////////////////

void scu_interrupt_test()
{
   // Disable everything temporarily
   SCSPREG_SCIEB = 0;
   SCSPREG_MCIEB = 0;

   // Mask SCSP interrupt temporarily
   bios_change_scu_interrupt_mask(0xFFFFFFFF, 0x40);

   // Set SCSP interrupt function
   bios_set_scu_interrupt(0x46, scsp_int_test_func);

   // Unmask SCSP interrupt
   bios_change_scu_interrupt_mask(~0x40, 0);

   // Enable all SCSP Main cpu interrupts
   SCSPREG_MCIEB = 0x7FF;
   SCSPREG_MCIRE = 0x7FF;
}

//////////////////////////////////////////////////////////////////////////////

void scsp_timer_pending_test(int timer_mask, int main_cpu)
{
   // Disable everything
   SCSPREG_SCIEB = 0;
   SCSPREG_MCIEB = 0;

   if (main_cpu)
   {
      // Clear any pending interrupts
      SCSPREG_SCIRE = timer_mask;

      // Make sure it isn't set prematurely
      if (SCSPREG_SCIPD & timer_mask)
      {
         stage_status = STAGESTAT_BADTIMING;
         return;
      }

      // Wait a bit while testing SCIPD
      wait_test(SCSPREG_SCIPD & timer_mask, 80000, STAGESTAT_BADINTERRUPT)
   }
   else
   {
      // Clear any pending interrupts
      SCSPREG_MCIRE = timer_mask;

      // Make sure it isn't set prematurely
      if (SCSPREG_MCIPD & timer_mask)
      {
         stage_status = STAGESTAT_BADTIMING;
         return;
      }

      // Wait a bit while testing SCIPD
      wait_test(SCSPREG_MCIPD & timer_mask, 80000, STAGESTAT_BADINTERRUPT)
   }
}

//////////////////////////////////////////////////////////////////////////////

void scsp_scipd_test()
{
   int i;
   u16 mask_list[] = { 0x0040, 0x0080, 0x0100 };

   for (i = 0; i < (sizeof(mask_list) / sizeof(u16)); i++)
   {
      scsp_timer_pending_test(mask_list[i], 0);
      if (stage_status != STAGESTAT_DONE)
         return;
   }
}

//////////////////////////////////////////////////////////////////////////////

void scsp_mcipd_test()
{
   int i;
   u16 mask_list[] = { 0x0040, 0x0080, 0x0100 };

   for (i = 0; i < (sizeof(mask_list) / sizeof(u16)); i++)
   {
      scsp_timer_pending_test(mask_list[i], 1);
      if (stage_status != STAGESTAT_DONE)
         return;
   }
}

//////////////////////////////////////////////////////////////////////////////

void scsp_timer_test(int timer_mask)
{
   // Disable everything temporarily
   SCSPREG_SCIEB = 0;
   SCSPREG_MCIEB = 0;

   // Mask SCSP interrupt temporarily
   bios_change_scu_interrupt_mask(0xFFFFFFFF, 0x40);

   // Set SCSP interrupt function
   bios_set_scu_interrupt(0x46, scsp_int_test_func);

   // Unmask SCSP interrupt
   bios_change_scu_interrupt_mask(~0x40, 0);

   stage_status = STAGESTAT_WAITINGFORINT;

   // Enable Timer interrupt
   SCSPREG_MCIRE = timer_mask;
   SCSPREG_MCIEB = timer_mask;
}

//////////////////////////////////////////////////////////////////////////////

void scsp_timer_a_test()
{
   scsp_timer_test(0x40);
}

//////////////////////////////////////////////////////////////////////////////

void scsp_timer_b_test()
{
   scsp_timer_test(0x80);
}

//////////////////////////////////////////////////////////////////////////////

void scsp_timer_c_test()
{
   scsp_timer_test(0x100);
}

//////////////////////////////////////////////////////////////////////////////

void scsp_timing_func(void)
{
   u32 hblank_temp;
   hblank_temp = hblank_counter;

//   vdp_printf(&test_disp_font, 1 * 8, 22 * 8, 0xF, "hblankcounter: %08X", hblanktemp);

   switch (tinc)
   {
      case 0:
         if ((hblank_temp & 0xFF00) < 0x100) // fix me
            stage_status = STAGESTAT_DONE;
         else
            stage_status = STAGESTAT_BADTIMING;
         break;
      case 1:
         if ((hblank_temp & 0xFF00) < 0x100) // fix me
            stage_status = STAGESTAT_DONE;
         else
            stage_status = STAGESTAT_BADTIMING;
         break;
      case 2:
         if ((hblank_temp & 0xFF00) == 0x100) // fix me
            stage_status = STAGESTAT_DONE;
         else
            stage_status = STAGESTAT_BADTIMING;
         break;
      case 3:
         if ((hblank_temp & 0xFF00) == 0x200) // fix me
            stage_status = STAGESTAT_DONE;
         else
            stage_status = STAGESTAT_BADTIMING;
         break;
      case 4:
         if ((hblank_temp & 0xFF00) == 0x500) // fix me
            stage_status = STAGESTAT_DONE;
         else
            stage_status = STAGESTAT_BADTIMING;
         break;
      case 5:
         if ((hblank_temp & 0xFF00) == 0xB00) // fix me
            stage_status = STAGESTAT_DONE;
         else
            stage_status = STAGESTAT_BADTIMING;
         break;
      case 6:
         if ((hblank_temp & 0xFF00) == 0x1600) // fix me
            stage_status = STAGESTAT_DONE;
         else
            stage_status = STAGESTAT_BADTIMING;
         break;
      case 7:
         if ((hblank_temp & 0xFF00) == 0x2D00) // fix me
            stage_status = STAGESTAT_DONE;
         else
            stage_status = STAGESTAT_BADTIMING;
      default:
         stage_status = STAGESTAT_DONE;
         break;
   }
}

//////////////////////////////////////////////////////////////////////////////

void hblank_timing_func(void)
{
   hblank_counter++;
}

//////////////////////////////////////////////////////////////////////////////

void scsp_timer_timing_test(u16 timer_setting)
{
   // Disable everything temporarily
   SCSPREG_SCIEB = 0;
   SCSPREG_MCIEB = 0;

   tinc = timer_setting >> 8;

   interrupt_set_level_mask(0xF);

   // Mask SCSP/H-blank interrupts temporarily
   bios_change_scu_interrupt_mask(0xFFFFFFFF, 0x40 | 0x4);

   // Set SCSP interrupt function
   bios_set_scu_interrupt(0x46, scsp_timing_func);

   // Set Hblank-in interrupt function
   bios_set_scu_interrupt(0x42, hblank_timing_func);

   // Unmask SCSP/H-blank interrupts
   bios_change_scu_interrupt_mask(~(0x40 | 0x4), 0);

   hblank_counter = 0;
   vdp_vsync();

//   switch (timermask)
//   {
//      case 0x40:
         SCSPREG_TIMERA = timer_setting;
//         break;
//      case 0x80:
//         SCSPREG_TIMERB = timersetting;
//         break;
//      case 0x100:
//         SCSPREG_TIMERC = timersetting;
//         break;
//      default: break;
//   }
   interrupt_set_level_mask(0x8);

   stage_status = STAGESTAT_WAITINGFORINT;

   // Enable Timer interrupt
   SCSPREG_MCIRE = 0x0040;
   SCSPREG_MCIEB = 0x0040;
}

//////////////////////////////////////////////////////////////////////////////

void scsp_timer_timing_test0()
{
   scsp_timer_timing_test(0x0000);
}

//////////////////////////////////////////////////////////////////////////////

void scsp_timer_timing_test1()
{
   scsp_timer_timing_test(0x0100);
}

//////////////////////////////////////////////////////////////////////////////

void scsp_timer_timing_test2()
{
   scsp_timer_timing_test(0x0200);
}

//////////////////////////////////////////////////////////////////////////////

void scsp_timer_timing_test3()
{
   scsp_timer_timing_test(0x0300);
}

//////////////////////////////////////////////////////////////////////////////

void scsp_timer_timing_test4()
{
   scsp_timer_timing_test(0x0400);
}

//////////////////////////////////////////////////////////////////////////////

void scsp_timer_timing_test5()
{
   scsp_timer_timing_test(0x0500);
}

//////////////////////////////////////////////////////////////////////////////

void scsp_timer_timing_test6()
{
   scsp_timer_timing_test(0x0600);
}

//////////////////////////////////////////////////////////////////////////////

void scsp_timer_timing_test7()
{
   scsp_timer_timing_test(0x0700);
}

//////////////////////////////////////////////////////////////////////////////

void int_on_timer_enable_test_func(void)
{
//   u32 hblanktemp;
//   hblanktemp = hblankcounter;

   if (hblank_counter == 0)
      stage_status = STAGESTAT_DONE;
   else
      stage_status = STAGESTAT_BADTIMING;

//   vdp_printf(&test_disp_font, 1 * 8, 23 * 8, 0xF, "hblankcounter: %08X", hblanktemp);
}

//////////////////////////////////////////////////////////////////////////////

void scsp_int_on_timer_enable_test()
{
   // Disable everything temporarily
   SCSPREG_SCIEB = 0;
   SCSPREG_MCIEB = 0;

   // Mask SCSP/H-blank interrupts temporarily
   bios_change_scu_interrupt_mask(0xFFFFFFFF, 0x40 | 0x4);

   // Set SCSP interrupt function
   bios_set_scu_interrupt(0x46, int_on_timer_enable_test_func);

   // Set Hblank-in interrupt function
   bios_set_scu_interrupt(0x42, hblank_timing_func);

   // Unmask SCSP/H-blank interrupts
   bios_change_scu_interrupt_mask(~(0x40 | 0x4), 0);

   // Clear timer
   SCSPREG_TIMERA = 0x0700;
   SCSPREG_MCIRE = 0x40;

   // Wait until MCIPD is showing an interrupt pending
   while (!(SCSPREG_MCIPD & 0x40)) {}

   stage_status = STAGESTAT_WAITINGFORINT;

   // Enable Timer interrupt
   hblank_counter = 0;
   SCSPREG_MCIEB = 0x40;
}

//////////////////////////////////////////////////////////////////////////////

void scsp_int_on_timer_reset_test()
{
   // Disable everything temporarily
   SCSPREG_SCIEB = 0;
   SCSPREG_MCIEB = 0;

   // Mask SCSP interrupt temporarily
   bios_change_scu_interrupt_mask(0xFFFFFFFF, 0x40);

   // Set SCSP interrupt function
   bios_set_scu_interrupt(0x46, 0);

   // Unmask SCSP interrupt
   bios_change_scu_interrupt_mask(~0x40, 0);

   // Enable timer
   SCSPREG_TIMERA = 0x0700;
   SCSPREG_MCIRE = 0x40;
   SCSPREG_MCIEB = 0x40;

   // Wait until MCIPD is showing an interrupt pending
   while (!(SCSPREG_MCIPD & 0x40)) {}

   // Set SCSP interrupt function
   bios_set_scu_interrupt(0x46, scsp_int_test_func);

   stage_status = STAGESTAT_WAITINGFORINT;

   // Reset Timer
   hblank_counter = 0;
   SCSPREG_MCIRE = 0x40;
}

//////////////////////////////////////////////////////////////////////////////

void scsp_int_dup_test()
{
   // Disable everything temporarily
   SCSPREG_SCIEB = 0;
   SCSPREG_MCIEB = 0;

   // Mask SCSP/H-blank interrupts temporarily
   bios_change_scu_interrupt_mask(0xFFFFFFFF, 0x40 | 0x4);

   // Set SCSP interrupt function
   bios_set_scu_interrupt(0x46, 0);

   // Set Hblank-in interrupt function
   bios_set_scu_interrupt(0x42, hblank_timing_func);

   // Unmask SCSP/H-blank interrupts
   bios_change_scu_interrupt_mask(~(0x40 | 0x4), 0);

   // Enable timer
   SCSPREG_TIMERA = 0;
   SCSPREG_MCIRE = 0x40;
   SCSPREG_MCIEB = 0x40;

   // Wait until MCIPD is showing an interrupt pending
   while (!(SCSPREG_MCIPD & 0x40)) {}

   // Set SCSP interrupt function
   bios_set_scu_interrupt(0x46, scsp_int_test_func);

   // Wait around 0x2000 hblanks to make sure nothing else triggers the interrupt
   hblank_counter = 0;

   while (hblank_counter < 0x2000) {}

   if (stage_status == STAGESTAT_DONE)
      stage_status = STAGESTAT_BADINTERRUPT;
   else
      stage_status = STAGESTAT_DONE;
}

//////////////////////////////////////////////////////////////////////////////

u16 scsp_dsp_reg_test_pattern[8] = { 0xdead ,0xbeef,0xcafe ,0xbabe,0xba5e ,0xba11,0xf01d,0xab1e };

void scsp_dsp_do_reg_write(volatile u16* ptr, int length)
{
   int i;
   for (i = 0; i < length; i++)
   {
      ptr[i] = scsp_dsp_reg_test_pattern[i&7];
   }
}

//////////////////////////////////////////////////////////////////////////////

int scsp_dsp_check_reg(volatile u16* ptr, int length, int mask, char* name, int pos)
{
   int i;
   for (i = 0; i < length; i++)
   {
      u16 ptr_val = ptr[i];
      u16 correct_val = scsp_dsp_reg_test_pattern[i & 7] & mask;
      if (ptr_val != correct_val)
      {
         char str[64] = { 0 };
         sprintf(str, "%d %s %04X != %04X", i, name, ptr_val, correct_val);
         vdp_printf(&test_disp_font, 0 * 8, pos * 8, 40, str);
         return 1;
      }
   }
   return 0;
}

//////////////////////////////////////////////////////////////////////////////

void scsp_dsp_register_write_test()
{
   volatile u16* coef_ptr = (volatile u16 *)0x25B00700;
   volatile u16* madrs_ptr = (volatile u16 *)0x25B00780;
   volatile u16* mpro_ptr = (volatile u16 *)0x25B00800;
   int failure = 0;
   int coef_length = 64;
   int madrs_length = 32;
   int mpro_length = 128;

   scsp_dsp_do_reg_write(coef_ptr, coef_length);
   scsp_dsp_do_reg_write(madrs_ptr, madrs_length);
   scsp_dsp_do_reg_write(mpro_ptr, mpro_length);

   int i;
   for (i = 0; i < 28; i++)
   {
      vdp_printf(&test_disp_font, 0 * 8, i * 8, 0xF, "coef: %04X", coef_ptr[i]);
      vdp_printf(&test_disp_font, 12 * 8, i * 8, 0xF, "madrs: %04X", madrs_ptr[i]);
      vdp_printf(&test_disp_font, 24 * 8, i * 8, 0xF, "mpro: %04X", mpro_ptr[i]);
   }

   if (scsp_dsp_check_reg(coef_ptr, coef_length, 0xfff8, "COEF", 0))
      failure = 1;
   if (scsp_dsp_check_reg(madrs_ptr, madrs_length, 0xffff, "MADRS", 1))
      failure = 1;
   if (scsp_dsp_check_reg(mpro_ptr, mpro_length, 0xffff, "MPRO", 2))
      failure = 1;

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
         break;
      }
   }
#endif

   if (!failure)
   {
      stage_status = STAGESTAT_DONE;
   }
   else
   {
      stage_status = STAGESTAT_BADDATA;
   }
}

//////////////////////////////////////////////////////////////////////////////

void scsp_dsp_write_mpro(u16 instr0, u16 instr1, u16 instr2, u16 instr3, u32 addr)
{
   volatile u16* mpro_ptr = (u16 *)0x25b00800;
   addr *= 4;
   mpro_ptr[addr+0] = instr0;
   mpro_ptr[addr+1] = instr1;
   mpro_ptr[addr+2] = instr2;
   mpro_ptr[addr+3] = instr3;
}

//////////////////////////////////////////////////////////////////////////////

void scsp_dsp_clear_instr(u16 *instr0, u16 *instr1, u16 *instr2, u16 *instr3)
{
   *instr0 = 0;
   *instr1 = 0;
   *instr2 = 0;
   *instr3 = 0;
}

//////////////////////////////////////////////////////////////////////////////

void scsp_dsp_erase_mpro()
{
   volatile u16* mpro_ptr = (u16 *)0x25b00800;
   int i;

   for (i = 0; i < 128 * 4; i++)
   {
      mpro_ptr[i] = 0;
   }
}

//////////////////////////////////////////////////////////////////////////////

void scsp_dsp_clear()
{
   volatile u16* sound_ram_ptr = (u16 *)0x25a00000;
   volatile u16* coef_ptr = (u16 *)0x25b00700;
   volatile u16* madrs_ptr = (u16 *)0x25b00780;
   volatile u16* temp_ptr = (u16 *)0x25b00C00;
   volatile u16* mems_ptr = (u16 *)0x25b00E00;

   int i;

   scsp_dsp_erase_mpro();

   for (i = 0; i < 0xffff; i++)
      sound_ram_ptr[i] = 0;

   for (i = 0; i < 64; i++)
      mems_ptr[i] = 0;

   for (i = 0; i < 64; i++)
      coef_ptr[i] = 0;

   for (i = 0; i < 64; i++)
      madrs_ptr[i] = 0;

   for (i = 0; i < 256; i++)
      temp_ptr[i] = 0;
}

//////////////////////////////////////////////////////////////////////////////

void scsp_dsp_start_test(u16 a_val, u16 b_val, int*yval)
{

   volatile u16* sound_ram_ptr = (u16 *)0x25a00000;
   volatile u16* coef_ptr = (u16 *)0x25b00700;
   volatile u16* start_dsp = (u16 *)0x25b00BF0;

   u16 instr0 = 0;
   u16 instr1 = 0;
   u16 instr2 = 0;
   u16 instr3 = 0;

   scsp_dsp_clear();

   coef_ptr[0] = a_val;

   sound_ram_ptr[0] = b_val;

   //nop
   scsp_dsp_write_mpro(0, 0, 0, 0, 0);

   //set memval
   instr2 = 1 << 13;//set mrd
   instr2 |= 1 << 15;// set table
   instr3 = 1 << 15; //set nofl

   scsp_dsp_write_mpro(0, 0, instr2, instr3, 1);

   scsp_dsp_clear_instr(&instr0, &instr1, &instr2, &instr3);

   //load memval to inputs
   instr1 = 1 << 5;//set iwt
   //ira and iwa will be 0 and equal to each other

   scsp_dsp_write_mpro(0, instr1, 0, 0, 2);

   scsp_dsp_clear_instr(&instr0, &instr1, &instr2, &instr3);

   scsp_dsp_write_mpro(0, 0, 0, 0, 3);//nop

   //load inputs to x, load coef to y, set B to zero
   instr1 = 1 << 15;//set xsel
   instr1 |= 1 << 13;//set ysel to 1
   //coef == 0
   instr2 = 1 << 1;//zero

   scsp_dsp_write_mpro(0, instr1, instr2, 0, 4);

   scsp_dsp_clear_instr(&instr0, &instr1, &instr2, &instr3);

   //needs to be on an odd instruction
   instr2 |= 1 << 14;//set mwt
   instr3 |= 1;//set nxadr
   instr2 |= 1 << 15; //set table
   instr3 |= 1 << 15; //set nofl

   scsp_dsp_write_mpro(instr0, instr1, instr2, instr3, 5);

   //start the dsp
   start_dsp[0] = 1;

   //wait a frame
   vdp_vsync();

   vdp_printf(&test_disp_font, 0 * 8, *yval * 8, 0xF, "a: 0x%04x * b: 0x%04x = 0x%04x", a_val,b_val, sound_ram_ptr[1]);
   *yval = *yval + 1;
}

//convert float in ring buffer to 24 bit int and store it in mems
void scsp_dsp_float_to_int_test(u16 test_val, int*yval)
{
   volatile u16* sound_ram_ptr = (u16 *)0x25a00000;//ring buffer
   volatile u16* start_dsp = (u16 *)0x25b00BF0;

   u16 instr1 = 0;
   u16 instr2 = 0;
   u16 instr3 = 0;

   scsp_dsp_clear();

   start_dsp[0] = 0;

   int i;
   for (i = 0; i < 0xffff; i++)
      sound_ram_ptr[i] = test_val;

   int instr_pos = 0;

   scsp_dsp_write_mpro(0, 0, 0, 0, instr_pos++);//nop

   //convert ring buffer value to float
   //and put it in memval
   instr2 = 1 << 13;//set mrd
   instr2 |= 1 << 15;// set table
   instr3 = 1 << 15; //set nofl

   scsp_dsp_write_mpro(0, 0, instr2, instr3, instr_pos++);

   scsp_dsp_write_mpro(0, 0, 0, 0, instr_pos++);//nop

   scsp_dsp_write_mpro(0, 1 << 5 | 1, 1 << 13, 0, instr_pos++);//iwa = 1, iwt, mrd

   //store memval in mems[0]
   instr1 = 1 << 5;//set iwt

   scsp_dsp_write_mpro(0, instr1, 0, 0, instr_pos++);

   //start the dsp
   start_dsp[0] = 1;

   int q;

   for(q = 0; q < 10; q++)
      vdp_wait_hblankout();

   vdp_printf(&test_disp_font, 0 * 8, *yval * 8, 0, "NNNNNNNNNNNNNN");

   volatile u16* mems_ptr = (u16 *)0x25b00E00;

   u32 test_result = mems_ptr[2] | mems_ptr[3] << 8;

   vdp_printf(&test_disp_font, 0 * 8, *yval * 8, 0xF, "0x%04x 0x%08x", test_val, test_result);
   *yval = *yval + 1;

}

//////////////////////////////////////////////////////////////////////////////

void scsp_dsp_multiply_test()
{
   int i, j;
   int yval = 0;
   u16 test_vals[] = { 0x0100,0x0200,0x0400,0x0800,0x1000};

   for (i = 0; i < 5; i++)
   {
      for (j = 0; j < 5; j++)
      {
         scsp_dsp_start_test(test_vals[i], test_vals[j], &yval);
      }
   }

   for (;;)
   {
      vdp_vsync();

      if (per[0].but_push_once & PAD_START)
      {
         reset_system();
      }
   }
}

//convert all possible 16 bit floats and store them in vdp1 ram
void scsp_dsp_generate_float_to_int_table()
{
   int i;
   int yval = 0;
   u16 test_val = 0;

   volatile u16* control_ptr = (u16 *)0x25b00400;

   control_ptr[1] = 0 << 7 | 0;

   int write_results = 1;

   if (write_results)//write results to vdp1 ram
   {
      volatile u32* dest = (u32 *)VDP1_RAM;
      int i;

      int pos = 1;

      dest[0] = 0xdeadbeef;//for verifying byte order

      //int increment = 1;

      int start = 0;
      int stop = 0xffff;

      for (i = start; i < stop; i++)
      {
         yval = 0;
         scsp_dsp_float_to_int_test(i, &yval);
         volatile u16* mems_ptr = (u16 *)0x25b00E00;
         u32 test_result = mems_ptr[2] | mems_ptr[3] << 8;
         dest[pos++] = test_result;
      }

      dest[pos] = 0xdeadbeef;//end of list

      vdp_printf(&test_disp_font, 24 * 8, 0 * 8, 0xF, "finished");

      for (;;)
      {
         while (!(VDP2_REG_TVSTAT & 8))
         {
            ud_check(0);
         }

         if (per[0].but_push_once & PAD_START)
         {
            reset_system();
         }
      }
   }

   for (;;)
   {
      vdp_vsync();

      if (per[0].but_push_once & PAD_A)
      {
         u32* dest = (u32 *)VDP2_RAM;

         int q;
         for (q = 0; q < 0x10000; q++)
            dest[q] = 0;

         scsp_dsp_float_to_int_test(test_val, &yval);
         test_val += 0x1111;

         volatile u16* mems_ptr = (u16 *)0x25b00E00;

         volatile u16* sound_ram_ptr = (u16 *)0x25a00000;

         for (i = 0; i < 28; i++)
            vdp_printf(&test_disp_font, 8 * 8, i * 8, 0xF, "0x%04x", sound_ram_ptr[i]);

         for (i = 0; i < 28; i++)
            vdp_printf(&test_disp_font, 16 * 8, i * 8, 0xF, "0x%04x", mems_ptr[i]);

         u32 test_result = mems_ptr[2] | mems_ptr[3] << 8;

         vdp_printf(&test_disp_font, 24 * 8, 0 * 8, 0xF, "0x%08x", test_result);
      }

      if (per[0].but_push_once & PAD_START)
      {
         reset_system();
      }
   }
}


//////////////////////////////////////////////////////////////////////////////

void scsp_dsp_test()
{
   scsp_minimal_init();
   unregister_all_tests();
   register_test(&scsp_dsp_register_write_test, "Register Read/Write Test");
   do_tests("SCSP DSP tests", 0, 0);
}

//////////////////////////////////////////////////////////////////////////////

u16 square_table[] =
{
   0xc000, 0xc000, 0xc000, 0xc000, 0xc000, 0xc000, 0xc000, 0xc000,
   0x4000, 0x4000, 0x4000, 0x4000, 0x4000, 0x4000, 0x4000, 0x4000
};

u16 square_table8[] =
{
   0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0,
   0x40, 0x40, 0x40, 0x40, 0x40, 0x40, 0x40, 0x40
};

#define KEYONEX 0x10000000
#define KEYONB 0x08000000

u16 fns_table[] = {
   0x0,0x3d,0x7d,0xc2,0x10a,0x157,0x1a8,0x1fe,0x25a,0x2ba,0x321,0x38d
};

//////////////////////////////////////////////////////////////////////////////

void write_note(u8 which_slot, u32 sa, u16 lsa, u16 lea, u8 oct, u16 fns, u8 pcm8b, u8 loop, u8 plfows, u8 plfos,u8 lfof, u8 ar)
{
   volatile u16* slot_ptr = (u16 *)0x25b00000;
   volatile u32* slot_ptr_l = (u32 *)0x25b00000;

   int offset = which_slot * 0x10;

   //force a note off
   slot_ptr_l[which_slot * 0x8] = KEYONEX;

   slot_ptr_l[which_slot*0x8] = KEYONEX | KEYONB | sa | (pcm8b << 20) | (loop << 21);
   slot_ptr[offset + 2] = lsa;//lsa
   slot_ptr[offset + 3] = lea;//lea
   slot_ptr[offset + 4] = 0x0000 | ar;//d2r,d1r,ho,ar
   slot_ptr[offset + 5] = 0x001f;//ls,krs,dl,rr
   slot_ptr[offset + 6] = 0x0000;//si,sd,tl
   slot_ptr[offset + 7] = 0x0000;//mdl,mdxsl,mdysl
   slot_ptr[offset + 8] = (oct << 11) | fns;//oct,fns
   slot_ptr[offset + 9] = (lfof << 10) | (plfows << 8) | (plfos << 5) | (0 << 3) | 0;//re,lfof,plfows,plfos,alfows,alfos
   slot_ptr[offset + 10] = 0x0000;//isel,imxl
   slot_ptr[offset + 11] = 0xE000;//disdl,dipan,efsdl,efpan
}

void write_note_struct(u8 which_slot, struct SlotRegs * regs)
{
   volatile u16* slot_ptr = (u16 *)0x25b00000;
   volatile u32* slot_ptr_l = (u32 *)0x25b00000;

   int offset = which_slot * 0x10;

   //force a note off
   slot_ptr_l[which_slot * 0x8] = KEYONEX;

   slot_ptr_l[which_slot * 0x8] =
      KEYONEX |
      KEYONB |
      (regs->sbctl << 25) |
      (regs->ssctl << 23) |
      (regs->lpctl << 21) |
      (regs->pcm8b << 20) |
      regs->sa;

   slot_ptr[offset + 2] = regs->lsa;//lsa
   slot_ptr[offset + 3] = regs->lea;//lea
   slot_ptr[offset + 4] =
      (regs->d2r << 11) |
      (regs->d1r << 6) |
      (regs->hold << 5) |
      regs->ar;//d2r,d1r,ho,ar
   slot_ptr[offset + 5] = (regs->ls << 14) | (regs->krs << 10) | (regs->dl << 5) | regs->rr;//ls,krs,dl,rr
   slot_ptr[offset + 6] = (regs->si << 9) | (regs->sd << 8) | regs->tl;//si,sd,tl
   slot_ptr[offset + 7] = (regs->mdl << 12) | (regs->mdxsl << 6) | regs->mdysl;//mdl,mdxsl,mdysl
   slot_ptr[offset + 8] = (regs->oct << 11) | regs->fns;//oct,fns
   slot_ptr[offset + 9] = (regs->re << 15) | (regs->lfof << 10) | (regs->plfows << 8) | (regs->plfos << 5) | (regs->alfows << 3) | regs->alfos;//re,lfof,plfows,plfos,alfows,alfos
   slot_ptr[offset + 10] = 0x0000;//isel,imxl
   slot_ptr[offset + 11] = (regs->disdl << 13);//disdl,dipan,efsdl,efpan
}

void all_note_off()
{
   volatile u32* slot_ptr_l = (u32 *)0x25b00000;

   int which_slot = 0;
   for(which_slot = 0; which_slot < 32; which_slot++)
      slot_ptr_l[which_slot * 0x8] = KEYONEX; //force a note off
}

//////////////////////////////////////////////////////////////////////////////

void scsp_setup(u32 base_addr)
{
   int i;

   volatile u16* erase = (u16 *)(0x25a00000);

   for (i = 0; i < 0x20000; i++)
   {
      erase[i] = 0;
   }

   volatile u16* sound_ram_ptr_16 = (u16 *)(0x25a00000 + base_addr);

   for (i = 0; i < 16; i++)
   {
      sound_ram_ptr_16[i] = square_table[i];
   }
   int offset = 128;

   volatile u8* su8 = (u8 *)(0x25a00000 + offset + base_addr);

   for (i = 0; i < 16; i++)
   {
      su8[i] = square_table8[i];
   }

   volatile u16* control = (u16 *)0x25b00400;
   control[0] = 7;//master vol

   //write a long sample
   volatile u16* sound_ram_ptr_16a = (u16 *)(0x25a00000 + base_addr + 256);

   for (i = 0; i < 0xfff0; i++)
   {
      sound_ram_ptr_16a[i] = square_table[i&0xf];
   }
}

void vdp1_setup(u32 vdp1_tile_address)
{
   load_font_8x8_to_vram_1bpp_to_4bpp(vdp1_tile_address, VDP1_RAM);
   VDP1_REG_PTMR = 0x02;//draw automatically with frame change
   VDP2_REG_PRISA = 7 | (6 << 8);
   VDP2_REG_PRISB = 5 | (4 << 8);
   VDP2_REG_PRISC = 3 | (2 << 8);
   VDP2_REG_PRISD = 1 | (0 << 8);
   VDP2_REG_SPCTL = (0 << 12) | (0 << 8) | (0 << 5) | 7;
}

void scsp_test_note_on()
{
   volatile u32* slot_ptr_l = (u32 *)0x25b00000;

   int oct = 0xd;
   int which_note = 0;
   int major_scale[] = { 0,2,4,5,7,9,11 };

   scsp_setup(0);

   write_note(0, 0, 0, 0x10 - 1, oct, 0x0, 0, 1,0,0,0,0x1f);

   int oct_test = 0xd;

   int lfof = 7;
   int plfows = 2;
   int plfos = 5;

   int is_8_bit = 0;

   if (!is_8_bit)
      write_note(0, 0, 0, 0x10 - 1, oct_test & 0xf, 0, 0, 1, plfows, plfos, lfof,0x8);
   else
      write_note(0, 128, 0, 15, oct_test & 0xf, 0, 1, 1, plfows, plfos, lfof, 0x8);

   for (;;)
   {
      vdp_vsync();

      int scale_note = major_scale[which_note];
      int fns = fns_table[scale_note];

      //key on
      if (per[0].but_push_once & PAD_A)
      {
         write_note(0, 0, 0, 0x10 - 1, oct, fns, 0, 1, 0, 0, 0, 0x1f);
         which_note++;
         if (which_note > 6)
            which_note = 0;
      }

      if (per[0].but_push_once & PAD_X)
      {
         write_note(1, 0, 0, 0x10 - 1, oct, fns, 0, 1, 0, 0, 0, 0x1f);
         which_note++;
         if (which_note > 6)
            which_note = 0;
      }

      //key off
      if (per[0].but_push_once & PAD_B)
      {
         slot_ptr_l[0] = KEYONB;
      }

      if (per[0].but_push_once & PAD_Z)
      {
         oct_test++;
         write_note(0, 0, 0, 0x10 - 1, oct_test & 0xf, fns, 0, 1, 0, 0, 0, 0x1f);

      }

      if (per[0].but_push_once & PAD_C)
      {
         oct_test--;
         write_note(0, 0, 0, 0x10 - 1, oct_test & 0xf, fns, 0, 1, 0, 0, 0, 0x1f);
      }

      if (per[0].but_push_once & PAD_L)
      {
         plfows++;

         if (plfows > 3)
            plfows = 0;
         write_note(0, 0, 0, 0x10 - 1, oct_test & 0xf, fns, 0, 1, plfows, plfos, lfof, 0x1f);
      }

      if (per[0].but_push_once & PAD_R)
      {
         lfof++;

         if (lfof > 31)
            lfof = 0;
         write_note(0, 0, 0, 0x10 - 1, oct_test & 0xf, fns, 0, 1, plfows, plfos, lfof, 0x1f);
      }

      if (per[0].but_push_once & PAD_Y)
      {
         plfos++;

         if (plfos > 7)
            plfos = 0;
         write_note(0, 0, 0, 0x10 - 1, oct_test & 0xf, fns, 0, 1, plfows, plfos, lfof, 0x1f);
      }


      if (per[0].but_push_once & PAD_START)
      {
         reset_system();
      }
   }
}

//play note from different starting addresses
void scsp_test_addrs()
{
   u32 addr = 0;

   scsp_setup(addr);

   write_note(0, addr + 128, 0, 0x10 - 1, 0xd, 0, 1, 1, 0, 0, 0, 0x1f);

   for (;;)
   {
      vdp_vsync();
      if (per[0].but_push_once & PAD_A)
      {

         addr += 0x100;
         addr &= 0xfffff;

         scsp_setup(addr);

         write_note(0, addr + 128, 0, 0x10 - 1, 0xd & 0xf, 0, 1, 1, 0, 0, 0, 0x1f);
      }

      if (per[0].but_push_once & PAD_START)
      {
         reset_system();
      }
   }
}

//write key on to each channel
void scsp_test_all_channels()
{
   u32 addr = 0;

   scsp_setup(addr);

   write_note(0, addr + 128, 0, 0x10 - 1, 0xd, 0, 1, 1, 0, 0, 0, 0x1f);

   int channel = 0;

   for (;;)
   {
      vdp_vsync();
      if (per[0].but_push_once & PAD_A)
      {
         channel++;

         all_note_off();

         write_note(channel, addr + 128, 0, 0x10 - 1, 0xd & 0xf, 0, 1, 1, 0, 0, 0, 0x1f);
      }

      if (per[0].but_push_once & PAD_START)
      {
         reset_system();
      }
   }
}

void vdp1_boilerplate()
{
   vdp_start_draw_list();
   sprite_struct quad = { 0 };

   //system clipping
   quad.x = 320;
   quad.y = 224;

   vdp_system_clipping(&quad);

   //user clipping
   quad.x = 0;
   quad.y = 0;
   quad.x2 = 320;
   quad.y2 = 224;

   vdp_user_clipping(&quad);

   quad.x = 0;
   quad.y = 0;

   vdp_local_coordinate(&quad);
}

void print_regs(u32 which_slot, u32 vdp1_tile_address, u8 is_word)
{
   char str[128] = { 0 };

   int i;

   if (is_word)
   {
      volatile u16* slot_ptr = (u16 *)0x25b00000;

      int offset = which_slot * 0x10;

      for (i = 0; i < 16; i++)
      {
         u16 val = slot_ptr[offset + i];
         sprintf(str, "%04x", val);
         vdp1_print_str(0, i * 8, 4, vdp1_tile_address, str);
      }
   }
   else
   {
      volatile u8* slot_ptr = (u8 *)0x25b00000;

      int offset = which_slot * 0x20;

      int j = 0;
      for (i = 0; i < 32; i+=2)
      {
         u8 val = slot_ptr[offset + i];
         sprintf(str, "%02x", val);
         vdp1_print_str(0, j * 8, 4, vdp1_tile_address, str);
         val = slot_ptr[offset + i + 1];
         sprintf(str, "%02x", val);
         vdp1_print_str(16, j * 8, 4, vdp1_tile_address, str);
         j++;
      }
   }
}

void do_word_write(int which_slot, u16 value, u32 vdp1_tile_address)
{
   int i;

   for (i = 0; i < 16; i++)
   {
      volatile u16* slot_ptr = (u16 *)0x25b00000;
      int offset = which_slot * 0x10;

      slot_ptr[i + offset] = value;
   }
   print_regs(which_slot, vdp1_tile_address, 1);
}

void do_byte_write(int which_slot, u8 value, u32 vdp1_tile_address)
{
   int i;

   for (i = 0; i < 32; i++)
   {
      volatile u8* slot_ptr = (u8 *)0x25b00000;
      int offset = which_slot * 0x20;

      slot_ptr[i + offset] = value;
   }
   print_regs(which_slot, vdp1_tile_address, 0);
}

//write and read all the slot registers
void scsp_slot_reg_write_read()
{
   const u32 vdp1_tile_address = 0x10000;

   vdp1_setup(vdp1_tile_address);

   int which_slot = 0;

   u8 val = 0;

   for (;;)
   {
      vdp_vsync();

      u16 write_val = val << 12 | val << 8 | val << 4 | val;

      if (per[0].but_push_once & PAD_A)
      {
         do_word_write(which_slot, write_val, vdp1_tile_address);
         val++;
      }
      if (per[0].but_push_once & PAD_B)
      {
         do_byte_write(which_slot, write_val, vdp1_tile_address);
         val++;
      }

      if (per[0].but_push_once & PAD_C)
      {
         which_slot++;
      }
      if (per[0].but_push_once & PAD_START)
      {
         reset_system();
      }
   }
}

void display_registers(int slot, u32 vdp1_tile_address)
{
   char str[128] = { 0 };
   int i;
   volatile u16* control = (u16 *)(0x25b00400);

   int x_coord = 5;

   print_regs(slot, vdp1_tile_address, 1);

   for (i = 0; i < 30; i++)
   {
      u16 var = control[i];
      sprintf(str, "%04x ", var);
      vdp1_print_str(x_coord * 8, i * 8, 4, vdp1_tile_address, str);
   }

   x_coord += 5;

   for (i = 0; i < 32; i++)
   {
      volatile u16* stack = (u16 *)0x25b00600;
      sprintf(str, "%04x", stack[0 + i]);
      vdp1_print_str(x_coord * 8, i * 8, 4, vdp1_tile_address, str);
      sprintf(str, "%04x", stack[32 + i]);
      vdp1_print_str((x_coord+5) * 8, i * 8, 4, vdp1_tile_address, str);
   }
}

//record envelope deltas
void scsp_envelope_edit()
{
   u32 addr = 0;

   const u32 vdp1_tile_address = 0x10000;

   vdp1_setup(vdp1_tile_address);

   scsp_setup(addr);

   int i;

   u32 max_snd_addr = 512;

   volatile u16* max_snd_ptr = (u16 *)(0x25a00000 + max_snd_addr);

   for (i = 0; i < 128; i++)
      max_snd_ptr[i] = 0x7fff;

   volatile u16* control = (u16 *)(0x25b00400);

   int monitor = 0;

   int menu_cursor = 0;

   int values[8] = { 0 };

   int initial_setting = 2;

   if (initial_setting == 0)
   {
      values[0] = 0x1;//ar
      values[5] = 0xf;//krs
   }
   else if (initial_setting == 1)
   {
      values[0] = 0xf;//ar
      values[1] = 0xf;//d1r
      values[2] = 0x0;//d2r
      values[3] = 0x0;//rr
      values[4] = 0x4;//dl
      values[5] = 0xf;//krs
   }
   else if (initial_setting == 2)
   {
      values[0] = 0xf;//ar
      values[1] = 0xf;//d1r
      values[2] = 0xe;//d2r
      values[3] = 0x0;//rr
      values[4] = 0x4;//dl
      values[5] = 0xf;//krs
   }

   char* value_names[] =
   {
      "ar",
      "d1r",
      "d2r",
      "rr",
      "dl",
      "krs",
      "ho"
   };

   struct ResultRecord
   {
      int frame;
      int env_value;
      int env_state;
   };

   struct ResultRecord results[512] = { { 0 } };
   int result_record_pos = 0;

   int test_active = 0;
   int test_frame = 0;

   int write_keyoff = 0;
   int keyoff_timer = 0;
   int keyoff_limit = 0;

   int record_all = 0;

   for (;;)
   {
      char str[128] = { 0 };

      vdp_vsync();

      if (write_keyoff)
      {
         if (keyoff_timer == keyoff_limit)
         {
            write_keyoff = 0;
            keyoff_timer = 0;
            volatile u8* slot_ptr = (u8 *)0x25b00000;
            //execute keyoff
            slot_ptr[0] = (1 << 4);
         }
         else
             keyoff_timer++;
      }

      if (test_active)
      {
         u32 val1 = (control[4] & 0x1f) << 5;//upper 5 bits of internal eg value
         u32 val2 = (control[4] >> 5) & 3;//current envelope state

         if (record_all)
         {
            result_record_pos++;
            results[result_record_pos].frame = test_frame;
            results[result_record_pos].env_value = val1;
            results[result_record_pos].env_state = val2;
         }
         else
         {
            //just record the differences
            if (results[result_record_pos].env_value != val1 ||
               results[result_record_pos].env_state != val2)
            {
               result_record_pos++;
               results[result_record_pos].frame = test_frame;
               results[result_record_pos].env_value = val1;
               results[result_record_pos].env_state = val2;
            }
         }

         if (result_record_pos > 28 || test_frame > (60*5))
         {
            test_active = 0;

            int j;

            //zero unused results
            for (j = result_record_pos + 1; j < 28; j++)
            {
               results[j].frame = 0;
               results[j].env_value = 0;
               results[j].env_state = 0;
            }
         }

         test_frame++;
      }

      control[4] = monitor << 11;

      vdp1_boilerplate();

      display_registers(monitor, vdp1_tile_address);

      vdp1_print_str(20 * 8, menu_cursor * 8, 4, vdp1_tile_address, ">");

      for (i = 0; i < 6; i++)
      {
         sprintf(str, "%s: %02x", value_names[i], values[i]);
         vdp1_print_str(21 * 8, i * 8, 4, vdp1_tile_address, str);
      }

      u16 val1 = (control[4] & 0x1f) << 5;//upper 5 bits of internal eg value
      u16 val2 = (control[4] >> 5) & 3;//current envelope state
      sprintf(str, "%04x  %01x", val1, val2);
      vdp1_print_str(21 * 8, 27 * 8, 4, vdp1_tile_address, str);

      for (i = 0; i < 28; i++)
      {
         sprintf(str, "%02x %03x %01x", results[i].frame, results[i].env_value, results[i].env_state);
         vdp1_print_str(30 * 8, i * 8, 4, vdp1_tile_address, str);
      }

      vdp_end_draw_list();

      if (
         per[0].but_push_once & PAD_A ||
         per[0].but_push_once & PAD_B ||
         per[0].but_push_once & PAD_C)
      {
         struct SlotRegs slot = { 0 };

         slot.sa = addr;
         slot.lsa = 0;
         slot.lea = 15;

         slot.lpctl = 1;
         slot.oct = 0xb;
         slot.fns = 0;
         slot.disdl = 7;

         slot.ar = values[0];
         slot.d1r = values[1];
         slot.d2r = values[2];
         slot.rr = values[3];
         slot.dl = values[4];
         slot.krs = values[5];
         slot.hold = values[6];

         all_note_off();

         test_active = 1;
         test_frame = 0;
         result_record_pos = 0;

         write_note_struct(0, &slot);

         if(per[0].but_push_once & PAD_B)
         {
            write_keyoff = 1;
            keyoff_timer = 0;
            keyoff_limit = 10;
         }

         if (per[0].but_push_once & PAD_C)
         {
            write_keyoff = 1;
            keyoff_timer = 0;
            keyoff_limit = 2;
         }
      }

      if (per[0].but_push_once & PAD_UP)
      {
         menu_cursor--;

         if (menu_cursor < 0)
            menu_cursor = 0;
      }

      if (per[0].but_push_once & PAD_DOWN)
      {
         menu_cursor++;
      }

      if (per[0].but_push_once & PAD_LEFT)
      {
         values[menu_cursor]--;
      }

      if (per[0].but_push_once & PAD_RIGHT)
      {
         values[menu_cursor]++;
      }

      if (per[0].but_push_once & PAD_START)
      {
         reset_system();
      }
   }
}

//sweep entire pitch spectrum
void scsp_full_sweep()
{
   const u32 vdp1_tile_address = 0x10000;

   vdp1_setup(vdp1_tile_address);

   int addr = 0;

   scsp_setup(addr);

   int monitor = 0;

   int oct = 10;
   int fns = 0;

   for (;;)
   {
      vdp_vsync();

      fns += 10;

      if (fns >= 0x3FF)
         fns = 0;

      volatile u16* slot_ptr = (u16 *)0x25b00000;

      int offset = 0 * 0x10;

      slot_ptr[offset + 8] = (oct << 11) | fns;//oct,fns

      vdp1_boilerplate();

      display_registers(monitor, vdp1_tile_address);

      vdp_end_draw_list();

      if (per[0].but_push_once & PAD_UP)
      {
         oct++;

         if (oct > 0xf)
            oct = 0xf;
      }

      if (per[0].but_push_once & PAD_DOWN)
      {
         oct--;

         if (oct < 0)
            oct = 0;
      }

      if (per[0].but_push_once & PAD_A)
      {
         struct SlotRegs slot = { 0 };

         slot.sa = addr;
         slot.lsa = 0;
         slot.lea = 15;

         slot.lpctl = 1;
         slot.disdl = 7;

         slot.ar = 0x1f;

         all_note_off();

         write_note_struct(0, &slot);
      }

      if (per[0].but_push_once & PAD_START)
      {
         reset_system();
      }
   }
}

//test different starting addresses
void scsp_address_decode()
{
   const u32 vdp1_tile_address = 0x10000;

   vdp1_setup(vdp1_tile_address);

   int addr = 0;

   scsp_setup(addr);

   int monitor = 0;

   int oct = 10;
   int fns = 0;

   char str[128] = { 0 };

   for (;;)
   {
      vdp_vsync();

      volatile u16* slot_ptr = (u16 *)0x25b00000;

      int offset = 0 * 0x10;

      slot_ptr[offset + 8] = (oct << 11) | fns;//oct,fns

      vdp1_boilerplate();

      display_registers(monitor, vdp1_tile_address);

      sprintf(str, "%04x", addr);
      vdp1_print_str(21 * 8, 27 * 8, 4, vdp1_tile_address, str);

      vdp_end_draw_list();

      if (per[0].but_push_once & PAD_UP)
      {
         oct++;

         if (oct > 0xf)
            oct = 0xf;
      }

      if (per[0].but_push_once & PAD_DOWN)
      {
         oct--;

         if (oct < 0)
            oct = 0;
      }

      if (per[0].but_push_once & PAD_A ||
         per[0].but_push_once & PAD_B ||
         per[0].but_push_once & PAD_C ||
         per[0].but_push_once & PAD_X ||
         per[0].but_push_once & PAD_Y ||
         per[0].but_push_once & PAD_Z)
      {
         struct SlotRegs slot = { 0 };


         if (per[0].but_push_once & PAD_A)
            addr -= 0x10;

         if (per[0].but_push_once & PAD_X)
            addr += 0x10;

         if (per[0].but_push_once & PAD_B)
            addr -= 0x100;

         if (per[0].but_push_once & PAD_Y)
            addr += 0x100;

         if (per[0].but_push_once & PAD_C)
            addr -= 0x1000;

         if (per[0].but_push_once & PAD_Z)
            addr += 0x1000;

         if (addr < 0)
            addr = 0;

         slot.sa = addr;
         slot.lsa = 0;
         slot.lea = 15;

         slot.lpctl = 1;
         slot.disdl = 7;

         slot.ar = 0x1f;

         all_note_off();

         write_note_struct(0, &slot);
      }

      if (per[0].but_push_once & PAD_START)
      {
         reset_system();
      }
   }
}

void scsp_fm_slot_connection()
{
   u32 addr = 0;

   const u32 vdp1_tile_address = 0x10000;

   vdp1_setup(vdp1_tile_address);

   scsp_setup(addr);

   struct SlotRegs slot = { 0 };

   slot.sa = addr;
   slot.lpctl = 1;
   slot.oct = 0xf;
   slot.fns = 0;
   slot.disdl = 7;
   slot.lsa = 0;
   slot.lea = 15;
   slot.ar = 0x1f;

   write_note_struct(0, &slot);

   int mdxsl = 0x20;
   int mdl = 0xa;

   char str[128] = { 0 };

   int i;

   u32 sound_len = 1024*3;

   volatile u16* sound_ram_ptr_16 = (u16 *)(0x25a00000);

   for (i = 0; i < sound_len; i++)
   {
      sound_ram_ptr_16[i] = sine_tbl[i & 0xff] << 8;
   }

   volatile u16* control = (u16 *)(0x25b00400);

   int monitor = 0xa;

   int capture = 0;

   for (;;)
   {
      vdp_vsync();

      control[4] = monitor << 11;

      vdp1_boilerplate();

      display_registers(monitor, vdp1_tile_address);

      if (per[0].but_push_once & PAD_UP)
      {
         mdxsl++;
      }
      if (per[0].but_push_once & PAD_DOWN)
      {
         mdxsl--;

         if (mdxsl < 0)
            mdxsl = 0;
      }
      if (per[0].but_push_once & PAD_LEFT)
      {
         mdl--;
      }
      if (per[0].but_push_once & PAD_RIGHT)
      {
         mdl++;

         if (mdl > 0xf)
            mdl = 0xf;
      }

      if (per[0].but_push_once & PAD_L)
      {
         monitor--;

         if (monitor < 0)
            monitor = 0;
      }

      if (per[0].but_push_once & PAD_R)
      {
         monitor++;
      }

      sprintf(str, "mdxsl: %02x mdl: %02x", mdxsl, mdl);
      vdp1_print_str(20 * 8, 0 * 8, 4, vdp1_tile_address, str);

      u16 ca = (control[4] >> 7) & 0xf;
      sprintf(str, "ca: %04x mon: %04x %04x", ca, monitor, capture);
      vdp1_print_str(20 * 8, 16 * 8, 4, vdp1_tile_address, str);

      vdp_end_draw_list();

      //one modulator both slots
      if (per[0].but_push_once & PAD_X)
      {
         slot.krs = 0xf;
         slot.sd = 1;
         slot.tl = 0;
         slot.sa = 1024;
         slot.lsa = 0;
         slot.lea = 1023;

         slot.ar = 0x1f;
         slot.hold = 0;
         slot.d1r = 0;
         slot.d2r = 0;
         slot.rr = 0;
         slot.dl = 0;
         slot.disdl = 7;

         slot.mdl = mdl;
         slot.mdxsl = mdxsl;
         slot.mdysl = mdxsl;

         all_note_off();

         write_note_struct(monitor + 0, &slot);

         slot.sa = 1024;
         slot.lsa = 0;
         slot.lea = 1023;

         slot.ar = 0x1f;
         slot.hold = 0;
         slot.d1r = 0;
         slot.d2r = 0;
         slot.rr = 0;
         slot.dl = 0;

         slot.disdl = 0;

         slot.mdl = 0;
         slot.mdxsl = 0;
         slot.mdysl = 0;

         write_note_struct(monitor + 1, &slot);
      }

      if (per[0].but_push_once & PAD_START)
      {
         reset_system();
      }
   }
}

//////////////////////////////////////////////////////////////////////////////

/*
void mcipd_test_func()
{
   u16 mcipd_temp=SCSPREG_MCIPD;

   vdp_printf(&test_disp_font, 1 * 8, 22 * 8, 0xF, "MCIPD: %04X", mcipd_temp);
}

//////////////////////////////////////////////////////////////////////////////

void scsp_mcipd_test()
{
   // Disable everything temporarily
   SCSPREG_SCIEB = 0;
   SCSPREG_MCIEB = 0;

   // Mask SCSP/H-blank interrupts temporarily
   bios_change_scu_interrupt_mask(0xFFFFFFFF, 0x40);

   // Set SCSP interrupt function
   bios_set_scu_interrupt(0x46, mcipd_test_func);

   // Unmask SCSP/H-blank interrupts
   bios_change_scu_interrupt_mask(~0x40, 0);

   stagestatus = STAGESTAT_WAITINGFORINT;

   // Enable timer
   SCSPREG_TIMERA = 0x0700;
   SCSPREG_MCIRE = 0x40;
   SCSPREG_MCIEB = 0x40;
}

//////////////////////////////////////////////////////////////////////////////

*/
