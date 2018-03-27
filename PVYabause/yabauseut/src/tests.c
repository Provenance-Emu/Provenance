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

#include <stdio.h>
#include <string.h>
#include <iapetus.h>
#include "tests.h"

volatile int stage_status=STAGESTAT_START;
int waitcounter;
u32 errordata=0;

typedef struct
{
   void (*testfunc)(void);
   const char *name;
} tests_struct;

tests_struct tests[0x100];

u8 numtests=0;

//////////////////////////////////////////////////////////////////////////////

//the automated testing interface uses the last 4096 bytes of vdp2 ram
//to relay messages to yabause

int auto_test_write_string(char* str, u32 base_address, int offset)
{
#ifdef BUILD_AUTOMATED_TESTING
   char* dest = (char *)VDP2_RAM + offset + base_address;
   strcpy(dest, str);
   offset += strlen(str);
   dest[offset++] = '\0';
   return offset;
#endif
   return 0;
}

//////////////////////////////////////////////////////////////////////////////

void auto_test_set_status(int is_busy)
{
#ifdef BUILD_AUTOMATED_TESTING
   char* dest = (char *)VDP2_RAM + AUTO_TEST_STATUS_ADDRESS;
   dest[0] = is_busy;
#endif
}

//////////////////////////////////////////////////////////////////////////////

void auto_test_wait()
{
#ifdef BUILD_AUTOMATED_TESTING
   volatile u8* ptr = (volatile u8 *)VDP2_RAM;
   while (ptr[AUTO_TEST_STATUS_ADDRESS] != AUTO_TEST_MESSAGE_RECEIVED) {}
#endif
}

//////////////////////////////////////////////////////////////////////////////

void auto_test_send_message(char* tag, char* message)
{
#ifdef BUILD_AUTOMATED_TESTING
   int offset = auto_test_write_string(tag, AUTO_TEST_MESSAGE_ADDRESS, 0);
   auto_test_write_string(message, AUTO_TEST_MESSAGE_ADDRESS, offset);
   auto_test_set_status(AUTO_TEST_MESSAGE_SENT);
   auto_test_wait();
#endif
}

//////////////////////////////////////////////////////////////////////////////

void auto_test_all_finished()
{
#ifdef BUILD_AUTOMATED_TESTING
   auto_test_send_message("ALL_FINISHED", "");
#endif
}

//////////////////////////////////////////////////////////////////////////////

void auto_test_debug_message(char* debug_message)
{
#ifdef BUILD_AUTOMATED_TESTING
   auto_test_send_message("DEBUG_MESSAGE", debug_message);
#endif
}

//////////////////////////////////////////////////////////////////////////////

void auto_test_section_start(char* test_section_name)
{
#ifdef BUILD_AUTOMATED_TESTING
   auto_test_send_message("SECTION_START", test_section_name);
#endif
}

//////////////////////////////////////////////////////////////////////////////

void auto_test_sub_test_start(char* sub_test_name)
{
#ifdef BUILD_AUTOMATED_TESTING
   auto_test_send_message("SUB_TEST_START", sub_test_name);
#endif
}

//////////////////////////////////////////////////////////////////////////////

void auto_test_send_result(char* result)
{
#ifdef BUILD_AUTOMATED_TESTING
   auto_test_send_message("RESULT", result);
#endif
}

//////////////////////////////////////////////////////////////////////////////

void auto_test_section_end()
{
#ifdef BUILD_AUTOMATED_TESTING
   auto_test_send_message("SECTION_END", "");
#endif
}

//////////////////////////////////////////////////////////////////////////////

void auto_test_take_screenshot(int frames_to_wait)
{
#ifdef BUILD_AUTOMATED_TESTING
   int i;

   for (i = 0; i < frames_to_wait; i++)
   {
      vdp_vsync();
   }

   auto_test_send_message("SCREENSHOT", "");
#endif
}

//////////////////////////////////////////////////////////////////////////////

void auto_test_get_framebuffer()
{
#ifdef BUILD_AUTOMATED_TESTING
   auto_test_send_message("FRAMEBUFFER", "");
#endif
}

//////////////////////////////////////////////////////////////////////////////


void init_test(void)
{
   // Put saturn in a minimalized state
   int i;

   interrupt_set_level_mask(0xF);

   for (i = 0; i < 0x80; i++)
      bios_set_sh2_interrupt(i, 0);

   for (i = 0x40; i < 0x60; i++)
      bios_set_scu_interrupt(i, 0);

   // Make sure all interrupts have been called
   bios_change_scu_interrupt_mask(0, 0);
   bios_change_scu_interrupt_mask(0xFFFFFFFF, 0xFFFFFFFF);

   vdp_init(RES_320x224);
//   per_init();

   commlink_stop_service();

//   if (InterruptGetLevelMask() > 0x7)
//      interrupt_set_level_mask(0x7);

   vdp_rbg0_init(&test_disp_settings);
}

//////////////////////////////////////////////////////////////////////////////

void tests_wait_press()
{
   per_init();

   if (interrupt_get_level_mask() > 0x7)
      interrupt_set_level_mask(0x7);

   vdp_vsync();

   // Wait until no buttons are pressed
   while (per[0].but_push_once || per[0].but_push)
      vdp_vsync();

   for (;;)
   {
      vdp_vsync(); 

      // return whenever a button pressed
      if (per[0].but_push_once & PAD_A ||
         per[0].but_push_once & PAD_B ||
         per[0].but_push_once & PAD_C ||
         per[0].but_push_once & PAD_X ||
         per[0].but_push_once & PAD_Y ||
         per[0].but_push_once & PAD_Z ||
         per[0].but_push_once & PAD_L ||
         per[0].but_push_once & PAD_R ||
         per[0].but_push_once & PAD_START)
         break;
   }

   vdp_vsync();
}

//////////////////////////////////////////////////////////////////////////////

void do_tests(const char *testname, int x, int y)
{
   int i;
   u8 stage=0;

   // Print messages and cursor
   vdp_printf(&test_disp_font, x * 8, y * 8, 0xF, (char *)testname);

   auto_test_section_start((char *)testname);

   for(;;)
   {
      vdp_vsync();

      if (stage_status != STAGESTAT_BUSY && stage_status != STAGESTAT_WAITINGFORINT)
      {
         if (stage_status == STAGESTAT_DONE)
         {
            vdp_printf(&test_disp_font, (x + 38) * 8, (y + stage + 2) * 8, 0xA, "OK");
            auto_test_send_result("PASS");
         }

         else if (stage_status < 0)
         {
            // Handle error
            switch (stage_status)
            {
               case STAGESTAT_BADTIMING:
                  vdp_printf(&test_disp_font, (x+38) * 8, (y + stage + 2) * 8, 0xE, "BT");
                  auto_test_send_result("FAIL (Bad Timing)");
                  break;
               case STAGESTAT_BADDATA:
                  vdp_printf(&test_disp_font, (x+38) * 8, (y + stage + 2) * 8, 0xC, "BD");
                  auto_test_send_result("FAIL (Bad Data)");
                  break;
               case STAGESTAT_BADSIZE:
                  vdp_printf(&test_disp_font, (x+38) * 8, (y + stage + 2) * 8, 0xC, "BS");
                  auto_test_send_result("FAIL (Bad Size)");
                  break;
               case STAGESTAT_BADINTERRUPT:
                  vdp_printf(&test_disp_font, (x+38) * 8, (y + stage + 2) * 8, 0xC, "BI");
                  auto_test_send_result("FAIL (Bad Interrupt)");
                  break;
               case STAGESTAT_NOTEST:
                  vdp_printf(&test_disp_font, (x+38) * 8, (y + stage + 2) * 8, 0xF, "NT");
                  auto_test_send_result("FAIL (No Test)");
                  break;
               default:
                  vdp_printf(&test_disp_font, (x+38) * 8, (y + stage + 2) * 8, 0xC, "failed");
                  auto_test_send_result("FAIL");
                  break;
            }
         }

         if (stage >= numtests)
         {
            vdp_printf(&test_disp_font, x * 8, (y + stage + 3) * 8, 0xF, "All tests done.");
            break;
         }

         stage_status = STAGESTAT_BUSY;

         if (tests[stage].name)
         {
            vdp_printf(&test_disp_font, x * 8, (y + stage + 3) * 8, 0xF, (char *)tests[stage].name);
            auto_test_sub_test_start((char *)tests[stage].name);
         }

         if (tests[stage].testfunc)
            tests[stage].testfunc();

         waitcounter = 60 * 5;

         stage++;
      }
      else
      {
         if (stage_status == STAGESTAT_WAITINGFORINT)
         {
            // decrement waitcounter
            waitcounter--;
            if (waitcounter <= 0)
               stage_status = STAGESTAT_BADINTERRUPT;
#ifdef DEBUG
            vdp_printf(&test_disp_font, 0 * 8, 23 * 8, 0xF, "%08X", waitcounter);
#endif
         }
      }
   }

   interrupt_set_level_mask(0xF);

   // Reset all interrupts
   for (i = 0; i < 0x80; i++)
      bios_set_sh2_interrupt(i, 0);

   for (i = 0x40; i < 0x60; i++)
      bios_set_scu_interrupt(i, 0);

   // Make sure all interrupts have been called
   bios_change_scu_interrupt_mask(0, 0);
   bios_change_scu_interrupt_mask(0xFFFFFFFF, 0xFFFFFFFF);

   auto_test_section_end();

   tests_wait_press();
}

//////////////////////////////////////////////////////////////////////////////

void register_test(void (*func)(void), const char *name)
{
   tests[numtests].testfunc = func;
   tests[numtests].name = name;
   numtests++;
}

//////////////////////////////////////////////////////////////////////////////

void unregister_all_tests()
{
   int i;

   for (i = 0; i < 0x100; i++)
   {
      tests[i].testfunc = 0;
      tests[i].name = 0;
   }

   numtests=0;
   stage_status=STAGESTAT_START;
}

//////////////////////////////////////////////////////////////////////////////

void tests_disp_iapetus_error(enum IAPETUS_ERR err, char *file, int line)
{
   char err_msg[512];
   char *filename = strrchr(file, '/');

   if (filename == NULL)
      filename = file;
   else
      filename++;

   sprintf(err_msg, "%s:%d ", filename, line);
   switch(err)
   {
      case IAPETUS_ERR_OK:
         strcat(err_msg, "No error");
         break;
      case IAPETUS_ERR_COMM:
         strcat(err_msg, "Communication error");
         break;
      case IAPETUS_ERR_HWNOTFOUND:
         strcat(err_msg, "Hardware not found");
         break;
      case IAPETUS_ERR_SIZE:
         strcat(err_msg, "Invalid size");
         break;
      case IAPETUS_ERR_INVALIDPOINTER:
         strcat(err_msg, "Invalid pointer");
         break;
      case IAPETUS_ERR_INVALIDARG:
         strcat(err_msg, "Invalid argument");
         break;
      case IAPETUS_ERR_BUSY:
         strcat(err_msg, "Hardware is busy");
         break;
      case IAPETUS_ERR_AUTH:
         strcat(err_msg, "Disc/MPEG authentication error");
         break;
      case IAPETUS_ERR_FILENOTFOUND:
         strcat(err_msg, "File not found");
         break;
      case IAPETUS_ERR_UNSUPPORTED:
         strcat(err_msg, "Unsupported feature");
         break;
      case IAPETUS_ERR_TIMEOUT:
         strcat(err_msg, "Operation timeout");
         break;
      case IAPETUS_ERR_MPEGCMD:
         strcat(err_msg, "MPEGCMD hirq bit not set");
         break;
      case IAPETUS_ERR_CMOK:
         strcat(err_msg, "CMOK hirq bit not set");
         break;
      case IAPETUS_ERR_CDNOTFOUND:
         strcat(err_msg, "CD not found");
         break;
      case IAPETUS_ERR_UNKNOWN:
      default:
         strcat(err_msg, "Unknown error");
         break;
   }
   int old_transparent = test_disp_font.transparent;
   vdp_print_text(&test_disp_font, 0 * 8, 0 * 8, 0xF, err_msg);
   test_disp_font.transparent = old_transparent;
}