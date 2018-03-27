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
#include "cdb.h"
#include "cart.h"
#include "m68k.h"
#include "mpeg.h"
#include "scsp.h"
#include "scu.h"
#include "slavesh.h"
#include "sh2.h"
#include "smpc.h"
#include "vdp1.h"
#include "vdp2.h"
#include "main.h"
#include "tests.h"

menu_item_struct main_menu[] = {
{ "SH2 Test" , &sh2_test, },
{ "Slave SH2 Test" , &slavesh2_test, },
{ "SCU Test", &scu_test, },
{ "CD Block Test" , &cdb_test, },
{ "MPEG Card Test" , &mpeg_test, },
{ "Cartridge Test" , &cart_test, }, // Could almost autodetect the cart type
{ "68k Test" , &m68k_test, },
{ "SCSP Test" , &scsp_test, },
{ "SMPC Test" , &smpc_test, },
{ "VDP1 Test" , &vdp1_test, },
{ "VDP2 Test" , &vdp2_test, },
{ "Run all tests" , &all_test, },
{ "Reset System" , &reset_system, },
{ "Goto AR Menu" , &ar_menu, },
{ "Goto CD Player" , &cd_player },
{ "\0", NULL }
};

screen_settings_struct test_disp_settings;
font_struct test_disp_font;

void all_test()
{
}

void reset_system()
{
   smpc_issue_command(SMPC_CMD_SYSRES);
}

void ar_menu()
{
   void (*ar)() = (void (*)())0x02000100;

   ar();
}

void cd_player()
{
   bios_run_cd_player();
}

void yabauseut_init()
{
   int i;

   bios_change_scu_interrupt_mask(0xFFFFFFFF, 0xFFFFFFFF);
   interrupt_set_level_mask(0);

   // Wait a bit
   for (i = 0; i < 200000; i++) {}

   interrupt_set_level_mask(0xF);

   bios_set_scu_interrupt(0x40, 0);
   bios_set_scu_interrupt(0x41, 0);
   bios_set_scu_interrupt(0x42, 0);
   bios_set_scu_interrupt(0x43, 0);
   bios_set_scu_interrupt(0x44, 0);
   bios_set_scu_interrupt(0x45, 0);
   bios_set_scu_interrupt(0x46, 0);
   bios_set_scu_interrupt(0x47, 0);
   bios_set_scu_interrupt(0x48, 0);
   bios_set_scu_interrupt(0x49, 0);
   bios_set_scu_interrupt(0x4A, 0);
   bios_set_scu_interrupt(0x4B, 0);
   bios_set_scu_interrupt(0x4C, 0);
   bios_set_scu_interrupt(0x4D, 0);
   bios_set_scu_interrupt(0x50, 0);   

   init_iapetus(RES_320x224);

   // Setup a screen for us draw on
   test_disp_settings.is_bitmap = TRUE;
   test_disp_settings.bitmap_size = BG_BITMAP512x256;
   test_disp_settings.transparent_bit = 0;
   test_disp_settings.color = BG_256COLOR;
   test_disp_settings.special_priority = 0;
   test_disp_settings.special_color_calc = 0;
   test_disp_settings.extra_palette_num = 0;
   test_disp_settings.map_offset = 0;
   test_disp_settings.rotation_mode = 0;
   test_disp_settings.parameter_addr = 0x25E60000;
   vdp_rbg0_init(&test_disp_settings);

   // Use the default palette
   vdp_set_default_palette();

   // Setup an 8x8 1BPP font
   test_disp_font.data = font_8x8;
   test_disp_font.width = 8;
   test_disp_font.height = 8;
   test_disp_font.bpp = 1;
   test_disp_font.out = (u8 *)0x25E00000;
   vdp_set_font(SCREEN_RBG0, &test_disp_font, 1);

   // Print messages and cursor
   vdp_disp_on();
}

#ifdef BUILD_AUTOMATED_TESTING

void (*auto_tests[])() =
{
   //sh2
   sh2_test,
   //sh2 slave
   slavesh2_test,
   //scu
   scu_register_test,
   scu_int_test,
   scu_dma_test,
   scu_dsp_test,
   //cd block
   //mpeg card
   //cartridge
   //68k
   //scsp
   scsp_timing_test,
   scsp_misc_test,
   scsp_dsp_test,
   //smpc
   //vdp1
   vdp1_framebuffer_tests,
   //vdp2
   vdp2_auto_tests,
   auto_test_all_finished
};

#endif

//by resetting the system inbetween tests, tests can't cause other tests to
//fail due to incomplete system state cleanup

int auto_test_get_selection()
{
#ifdef BUILD_AUTOMATED_TESTING
   volatile u8* ptr = (volatile u8 *)VDP2_RAM;
   return ptr[AUTO_TEST_SELECT_ADDRESS];
#endif
   return 0;
}

void auto_test_do_selected_test(int selection)
{
#ifdef BUILD_AUTOMATED_TESTING
   (*auto_tests[selection])();
#endif
}

int main()
{
   int choice;

   int auto_test_selection = auto_test_get_selection();

   yabauseut_init();

   auto_test_do_selected_test(auto_test_selection);

   // Display Main Menu
   for(;;)
   {
      vdp_printf(&test_disp_font, 0 * 8, 27 * 8, 0xF, "Build Time: %s %s", __DATE__, __TIME__);
      choice = gui_do_menu(main_menu, &test_disp_font, 0, 0, "YabauseUT v0.1", MTYPE_CENTER, -1);
      gui_clear_scr(&test_disp_font);
   }
}