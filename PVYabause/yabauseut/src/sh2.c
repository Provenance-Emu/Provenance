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

#define SH2REG_CCR      (*(volatile u8  *)0xFFFFFE92)
#define SH2REG_IPRA     (*(volatile u16 *)0xFFFFFEE2)
#define SH2REG_DVSR     (*(volatile u32 *)0xFFFFFF00)
#define SH2REG_DVDNT    (*(volatile u32 *)0xFFFFFF04)
#define SH2REG_DVCR     (*(volatile u32 *)0xFFFFFF08)
#define SH2REG_VCRDIV   (*(volatile u32 *)0xFFFFFF0C)
#define SH2REG_DVDNTH   (*(volatile u32 *)0xFFFFFF10)
#define SH2REG_DVDNTL   (*(volatile u32 *)0xFFFFFF14)
#define SH2REG_DVDNTUH  (*(volatile u32 *)0xFFFFFF18)
#define SH2REG_DVDNTUL  (*(volatile u32 *)0xFFFFFF1C)
#define SH2REG_DVSR2    (*(volatile u32 *)0xFFFFFF20)
#define SH2REG_DVDNT2   (*(volatile u32 *)0xFFFFFF24)
#define SH2REG_DVCR2    (*(volatile u32 *)0xFFFFFF28)
#define SH2REG_VCRDIV2  (*(volatile u32 *)0xFFFFFF2C)
#define SH2REG_DVDNTH2  (*(volatile u32 *)0xFFFFFF30)
#define SH2REG_DVDNTL2  (*(volatile u32 *)0xFFFFFF34)
#define SH2REG_DVDNTUH2 (*(volatile u32 *)0xFFFFFF38)
#define SH2REG_DVDNTUL2 (*(volatile u32 *)0xFFFFFF3C)

void div_mirror_test(void);
void div_operation_test(void);
void div_interrupt_test(void);

//////////////////////////////////////////////////////////////////////////////

void sh2_test()
{
   interrupt_set_level_mask(0xF);

   init_iapetus(RES_320x224);

   // Setup a screen for us draw on
   vdp_rbg0_init(&test_disp_settings);
   vdp_set_default_palette();

   // Display On
   vdp_disp_on();

   unregister_all_tests();
   register_test(&div_mirror_test, "DIV register access");
   register_test(&div_operation_test, "DIV operations");
   register_test(&div_interrupt_test, "DIV overflow interrupt");
   do_tests("SH2 tests", 0, 0);

   // Other tests to do: instruction tests, check all register accesses,
   // onchip functions
}

//////////////////////////////////////////////////////////////////////////////

#define test_access_b(r) \
   r = 0x01; \
   if (r != 0x01) \
   { \
      stage_status = STAGESTAT_BADDATA; \
      return; \
   }

#define test_access_w(r) \
   r = 0x0102; \
   if (r != 0x0102) \
   { \
      stage_status = STAGESTAT_BADDATA; \
      return; \
   }

#define test_access_l(r) \
   r = 0x01020304; \
   if (r != 0x01020304) \
   { \
      stage_status = STAGESTAT_BADDATA; \
      return; \
   }

void div_mirror_test(void)
{
   // This tests DIV register reads/writes and checks mirroring
   test_access_w(SH2REG_VCRDIV)
   test_access_w(SH2REG_VCRDIV2)
   SH2REG_VCRDIV = 0;

   test_access_b(SH2REG_DVCR)
   test_access_b(SH2REG_DVCR2)
   SH2REG_DVCR = 0;

   test_access_l(SH2REG_DVDNTH)
   test_access_l(SH2REG_DVDNTH2)
   test_access_l(SH2REG_DVSR)
   test_access_l(SH2REG_DVSR2)
   test_access_l(SH2REG_DVDNTUH)
   test_access_l(SH2REG_DVDNTUH2)
   test_access_l(SH2REG_DVDNTUL)
   test_access_l(SH2REG_DVDNTUL2)

   stage_status = STAGESTAT_DONE;
}

//////////////////////////////////////////////////////////////////////////////

void div_operation_test(void)
{
   // This tests to make sure the dividing operation is correct
   int i;

   // Test 64-bit/32-bit operation
   SH2REG_DVSR = 0x10;
   SH2REG_DVDNTH = 0x1;
   SH2REG_DVDNTL = 0x9;

   // Wait a bit
   for (i = 0; i < 20; i++) {}

   if (SH2REG_DVDNTL != 0x10000000 ||
       SH2REG_DVDNTL2 != 0x10000000 ||
       SH2REG_DVDNT != 0x10000000 ||
       SH2REG_DVDNT2 != 0x10000000 ||
       SH2REG_DVDNTUL != 0x10000000 ||
       SH2REG_DVDNTUL2 != 0x10000000 ||
       SH2REG_DVDNTH != 9 ||
       SH2REG_DVDNTH2 != 9 ||
       SH2REG_DVDNTUH != 9 ||
       SH2REG_DVDNTUH2 != 9)
   {
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   // Ok, mirrors are working alright, and 64-bit/32-bit operation is correct

   // Test 32-bit/32-bit operation
   SH2REG_DVSR = 0x10;
   SH2REG_DVDNT = 0x10000009;

   // Wait a bit
   for (i = 0; i < 20; i++) {}

   if (SH2REG_DVDNTL != 0x1000000 ||
       SH2REG_DVDNTL2 != 0x1000000 ||
       SH2REG_DVDNT != 0x1000000 ||
       SH2REG_DVDNT2 != 0x1000000 ||
       SH2REG_DVDNTUL != 0x1000000 ||
       SH2REG_DVDNTUL2 != 0x1000000 ||
       SH2REG_DVDNTH != 9 ||
       SH2REG_DVDNTH2 != 9 ||
       SH2REG_DVDNTUH != 9 ||
       SH2REG_DVDNTUH2 != 9)
   {
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   // Ok, mirrors are working alright, and 32-bit/32-bit operation is correct

   // Now let's do an overflow test(It seems you can only trigger it using 64-bit/32-bit operation)
   SH2REG_DVSR = 0x1;
   SH2REG_DVCR = 0;
   SH2REG_DVDNTH = 0x1;
   SH2REG_DVDNTL = 0x0;

   // Wait a bit
   for (i = 0; i < 20; i++) {}

   if (SH2REG_DVDNTL != 0x7FFFFFFF ||
       SH2REG_DVDNTH != 0xFFFFFFFE ||
       SH2REG_DVCR != 0x1)
   {
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   // Lastly, do two divide by zero tests
   SH2REG_DVSR = 0;
   SH2REG_DVCR = 0;
   SH2REG_DVDNT = 0;

   // Wait a bit
   for (i = 0; i < 20; i++) {}

   if (SH2REG_DVDNT != 0x7FFFFFFF ||
       SH2REG_DVDNTH != 0 ||
       SH2REG_DVCR != 0x1)
   {
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   SH2REG_DVSR = 0;
   SH2REG_DVCR = 0;
   SH2REG_DVDNT = 0xD0000000;

   // Wait a bit
   for (i = 0; i < 20; i++) {}

   if (SH2REG_DVDNT != 0x80000000 ||
       SH2REG_DVDNTH != 0xFFFFFFFE ||
       SH2REG_DVCR != 0x1)
   {
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   stage_status = STAGESTAT_DONE;
}

//////////////////////////////////////////////////////////////////////////////

void sh2_int_test_func(void) __attribute__ ((interrupt_handler));

void sh2_int_test_func(void)
{
   bios_set_sh2_interrupt(0x6E, 0);
   SH2REG_DVCR = 0;
   stage_status = STAGESTAT_DONE;
}

//////////////////////////////////////////////////////////////////////////////

void div_interrupt_test(void)
{
   // This tests to make sure an interrupt is generated when the registers are setup
   // for it, and an overflow occurs

   stage_status = STAGESTAT_WAITINGFORINT;
   bios_set_sh2_interrupt(0x6E, sh2_int_test_func);
   SH2REG_VCRDIV = 0x6E;
   SH2REG_IPRA = 0xF << 12;
   interrupt_set_level_mask(0xE);

   SH2REG_DVSR = 0;
   SH2REG_DVCR = 0x2;
   SH2REG_DVDNT = 0xD0000000;

   // Alright, test is all setup, now when the interrupt is done, the test
   // will successfully complete
}

//////////////////////////////////////////////////////////////////////////////

void clear_framebuffer()
{
   u32* dest = (u32 *)VDP2_RAM;

   int q;

   for (q = 0; q < 0x10000; q++)
   {
      dest[q] = 0;
   }
}

//////////////////////////////////////////////////////////////////////////////

//assuming the 28th bit is 0
//0b0000 0x0 cache area
//0b0010 0x2 cache through
//0b0100 0x4 purge
//0b0110 0x6 address array
//0b1100 0xC data array
//0x1110 0xE I/O area

volatile u32 *wram_cache = (volatile u32 *)(0x06000000);
volatile u32 *wram_cache_through = (volatile u32 *)(0x26000000);
volatile u32 *address_array = (volatile u32 *)(0x60000000);
volatile u32 *data_array = (volatile u32 *)(0xC0000000);

//////////////////////////////////////////////////////////////////////////////

void print_addr_data(int x_start, int y_start, u32 addr_val)
{
   int x_pos = x_start;
   int y_pos = y_start;

   u32 tag = addr_val & 0x1FFFFC00;
   u32 lru = (addr_val >> 4) & 0x3f;
   u32 v = (addr_val >> 2) & 1;

   y_pos += 2;

   vdp_printf(&test_disp_font, x_pos * 8, y_pos * 8, 0xC, "tag: 0x%08x lru: 0x%02x v: 0x%01x", tag, lru, v);
}

//////////////////////////////////////////////////////////////////////////////

void print_cache_for_way(int x_start, int y_start, int way, int index)
{
   int x_pos = x_start;
   int y_pos = y_start;

   vdp_printf(&test_disp_font, x_pos * 8, y_pos * 8, 0xC, "0x%02x", way);

   x_pos += 5;

   SH2REG_CCR = way << 6;

   u32 addr = 0x60000000 | (index << 4);
   u32 addr_val = (*(volatile u32 *)addr);

   vdp_printf(&test_disp_font, x_pos * 8, y_pos * 8, 0xC, "0x%08x", addr_val);

   x_pos += 11;

   u32 data = data_array[(index * 4) + 0 + (way * 0x100)];
   vdp_printf(&test_disp_font, x_pos * 8, y_pos * 8, 0xC, "0x%08x", data);

   x_pos += 11;

   data = data_array[(index * 4) + 1 + (way * 0x100)];
   vdp_printf(&test_disp_font, x_pos * 8, y_pos * 8, 0xC, "0x%08x", data);

   x_pos -= 11;
   y_pos += 1;

   data = data_array[(index * 4) + 2 + (way * 0x100)];
   vdp_printf(&test_disp_font, x_pos * 8, y_pos * 8, 0xC, "0x%08x", data);

   x_pos += 11;

   data = data_array[(index * 4) + 3 + (way * 0x100)];
   vdp_printf(&test_disp_font, x_pos * 8, y_pos * 8, 0xC, "0x%08x", data);

   x_pos = 0;

   print_addr_data(x_pos, y_pos, addr_val);
}

//////////////////////////////////////////////////////////////////////////////

void print_cache_all_ways(int y_start, int index)
{
   int y = y_start;

   vdp_printf(&test_disp_font, 0 * 8, y * 8, 0xC, "index: 0x%02x", index);
   y += 2;

   int way;

   for (way = 0; way < 4; way++)
   {
      print_cache_for_way(0, y, way, index);
      y += 6;
   }
}

//////////////////////////////////////////////////////////////////////////////

void print_cache_at_index(int index)
{
   clear_framebuffer();

   vdp_printf(&test_disp_font, 0 * 8, 0 * 8, 0xC, "way    address    data");

   print_cache_all_ways(2, index);
}

//////////////////////////////////////////////////////////////////////////////

void cache_print_and_wait()
{
   int index = 0;

   print_cache_at_index(0);

   for (;;)
   {
      vdp_vsync();

      if (per[0].but_push_once & PAD_A)
      {
         break;
      }

      if (per[0].but_push_once & PAD_Y)
      {
         reset_system();
      }

      if (per[0].but_push_once & PAD_UP)
      {
         index--;
         if (index < 0)
            index = 0;
         print_cache_at_index(index);
      }

      if (per[0].but_push_once & PAD_DOWN)
      {
         index++;
         print_cache_at_index(index);
      }
   }
}

//////////////////////////////////////////////////////////////////////////////

void cache_test()
{
   int i = 0;
   int way = 0;

   SH2REG_CCR = 0;//disable cache

   //clear address arrays
   for (way = 0; way < 4; way++)
   {
      //bank switch
      SH2REG_CCR = way << 6;

      for (i = 0; i < 64; i++)
      {
         address_array[i] = 0;
      }
   }

   //clear data array
   for (i = 0; i < 0x400; i++)
      data_array[i] = 0;

   wram_cache_through[0x11000] = 0xdeadbeef;
   wram_cache_through[0x11001] = 0xcafef00d;
   wram_cache_through[0x11002] = 0xb01dface;
   wram_cache_through[0x11003] = 0xba5eba11;

   for (i = 0; i < 64; i++)
   {
      wram_cache_through[0x12000 + i] = i;
   }

   SH2REG_CCR = (1 << 4); //purge
   SH2REG_CCR = 1; //enable

   //test write
   wram_cache[0x10000] = wram_cache[0x11000];

   SH2REG_CCR = 0;//disable cache

   way = 0;

   cache_print_and_wait();

   //part 2

   for (i = 0; i < 64; i+=4)
   {
      SH2REG_CCR = 1; //enable

      wram_cache[0x13000 + i] = wram_cache[0x12000 + i];

      SH2REG_CCR = 0;//disable

      cache_print_and_wait();
   }
}