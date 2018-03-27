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

#include "tests.h"
#include "main.h"
#include "smpc.h"
#include <stdio.h>
#include <string.h>

extern vdp2_settings_struct vdp2_settings;

void vdp2_nbg0_test ();
void vdp2_nbg1_test ();
void vdp2_nbg2_test ();
void vdp2_nbg3_test ();
void vdp2_rbg0_test ();
void vdp2_rbg1_test ();
void vdp2_window_test ();
void vdp2_all_scroll_test();
void vdp2_line_color_screen_test();
void vdp2_extended_color_calculation_test();
void vdp2_sprite_priority_shadow_test();
void vdp2_special_priority_test();
//////////////////////////////////////////////////////////////////////////////

void hline(int x1, int y1, int x2, u8 color)
{
   int i;
   volatile u8 *buf=(volatile u8 *)(0x25E00000+(y1 * 512));

   for (i = x1; i < (x2+1); i++)
      buf[i] = color;
}

//////////////////////////////////////////////////////////////////////////////

void vline(int x1, int y1, int y2, u8 color)
{
   int i;
   volatile u8 *buf=(volatile u8 *)(0x25E00000+(y1 * 512) + x1);

   for (i = 0; i < (y2-y1+1); i++)
      buf[i * 512] = color;
}

//////////////////////////////////////////////////////////////////////////////

void draw_box(int x1, int y1, int x2, int y2, u8 color)
{
   hline(x1, y1, x2, color);
   hline(x1, y2, x2, color);
   vline(x1, y1, y2, color);
   vline(x2, y1, y2, color);
}

//////////////////////////////////////////////////////////////////////////////

void working_query(const char *question)
{
   // Ask the user if it's visible
   vdp_printf(&test_disp_font, 2 * 8, 20 * 8, 0xF, "%s", question);
   vdp_printf(&test_disp_font, 2 * 8, 21 * 8, 0xF, "C - Yes B - No");

   for(;;)
   {
      vdp_vsync();

      if (per[0].but_push_once & PAD_B)
      {
         stage_status = STAGESTAT_BADGRAPHICS;
         break;
      }
      else if (per[0].but_push_once & PAD_C)
      {
         stage_status = STAGESTAT_DONE;
         break;
      }
   }
}

//////////////////////////////////////////////////////////////////////////////

void vdp2_test()
{
   // Put system in minimalized state
   interrupt_set_level_mask(0xF);

   init_iapetus(RES_320x224);
   vdp_rbg0_init(&test_disp_settings);
   vdp_set_default_palette();

   // Display On
   vdp_disp_on();

   unregister_all_tests();
//   register_test(&Vdp2InterruptTest, "Sound Request Interrupt");
//   register_test(&Vdp2RBG0Test, "RBG0 bitmap");
   register_test(&vdp2_window_test, "Window test");
   //register_test(&vdp2_all_scroll_test, "NBG0-4 scroll test");
   //register_test(&vdp2_line_color_screen_test, "Line color screen test");
   //register_test(&vdp2_extended_color_calculation_test, "Extended color calc test");
   //register_test(&vdp2_sprite_priority_shadow_test, "Sprite priority shadow test");
   //register_test(&vdp2_special_priority_test, "Special priority test");

   do_tests("VDP2 Screen tests", 0, 0);
}

//////////////////////////////////////////////////////////////////////////////

void load_font_8x8_to_vram_1bpp_to_4bpp(u32 tile_start_address, u32 ram_pointer)
{
   int x, y;
   int chr;
   volatile u8 *dest = (volatile u8 *)(ram_pointer + tile_start_address);

   for (chr = 0; chr < 128; chr++)//128 ascii chars total
   {
      for (y = 0; y < 8; y++)
      {
         u8 scanline = font_8x8[(chr * 8) + y];//get one scanline

         for (x = 0; x < 8; x++)
         {
            //get the corresponding bit for the x pos
            u8 bit = (scanline >> (x ^ 7)) & 1;

            if ((x & 1) == 0)
               bit *= 16;

            dest[(chr * 32) + (y * 4) + (x / 2)] |= bit;
         }
      }
   }
}

//////////////////////////////////////////////////////////////////////////////

void write_tile(int x_pos, int y_pos, int palette, int name, u32 base,
   u32 tile_start_address, int special_priority, int special_color)
{
   volatile u32 *p = (volatile u32 *)(VDP2_RAM + base);
   //64 cells across in the plane
   p[(y_pos * 64) + x_pos] = (special_priority << 29) |
      (special_color << 28) | (tile_start_address >> 5) | name |
      (palette << 16);
}

//////////////////////////////////////////////////////////////////////////////

void write_str_as_pattern_name_data_special(int x_pos, int y_pos, const char* str,
   int palette, u32 base, u32 tile_start_address,int special_priority,
   int special_color)
{
   int x;

   int len = strlen(str);

   for (x = 0; x < len; x++)
   {
      int name = str[x];

      int offset = x + x_pos;

      volatile u32 *p = (volatile u32 *)(VDP2_RAM + base);
      //64 cells across in the plane
      p[(y_pos * 64) + offset] = (special_priority << 29) |
         (special_color << 28) | (tile_start_address >> 5) | name |
         (palette << 16);
   }
}

//////////////////////////////////////////////////////////////////////////////

void write_str_as_pattern_name_data(int x_pos, int y_pos, const char* str,
   int palette, u32 base, u32 tile_start_address)
{
   write_str_as_pattern_name_data_special(x_pos, y_pos, str, palette, base, tile_start_address, 0, 0);
}

//////////////////////////////////////////////////////////////////////////////

//simple menu and reg writing system for tests that need a lot of reg changes
#define REG_ADJUSTER_MAX_VARS 28
#define REG_ADJUSTER_STRING_LEN 32

struct RegAdjusterVarInfo
{
   char name[REG_ADJUSTER_STRING_LEN];
   int num_values;
   int value;
   int *dest;
};

struct RegAdjusterState
{
   int repeat_timer;
   int menu_selection;
   int num_menu_items;
   struct RegAdjusterVarInfo vars[REG_ADJUSTER_MAX_VARS];
};

//////////////////////////////////////////////////////////////////////////////

void ra_add_var(struct RegAdjusterState* s, int * dest, char* name, int num_vals)
{
   strcpy(s->vars[s->num_menu_items].name, name);
   s->vars[s->num_menu_items].num_values = num_vals;
   s->vars[s->num_menu_items].dest = dest;
   s->num_menu_items++;
}

//////////////////////////////////////////////////////////////////////////////

void ra_update_vars(struct RegAdjusterState* s)
{
   int i;
   for (i = 0; i < s->num_menu_items; i++)
   {
      *s->vars[i].dest = s->vars[i].value;
   }
}

//////////////////////////////////////////////////////////////////////////////

void ra_add_array(struct RegAdjusterState* s, int(*vars)[], int length, char* name, int num_vals)
{
   int i;
   for (i = 0; i < length; i++)
   {
      char str[REG_ADJUSTER_STRING_LEN] = { 0 };
      strcpy(str, name);

      char str2[REG_ADJUSTER_STRING_LEN] = { 0 };
      sprintf(str2, "%d", i);
      strcat(str, str2);
      ra_add_var(s, &(*vars)[i], str, num_vals);
   }
}

//////////////////////////////////////////////////////////////////////////////

void ra_do_menu(struct RegAdjusterState* s, int x_pos, int y_pos, int base)
{
   int i;
   for (i = 0; i < s->num_menu_items; i++)
   {
      char current_line[REG_ADJUSTER_STRING_LEN] = { 0 };

      if (s->menu_selection == i)
      {
         strcat(current_line, ">");
      }
      else
      {
         strcat(current_line, " ");
      }
      char value[REG_ADJUSTER_STRING_LEN] = { 0 };
      sprintf(value, "=%02d", s->vars[i].value);
      strcat(current_line, s->vars[i].name);
      strcat(current_line, value);
      write_str_as_pattern_name_data(x_pos, i+y_pos, current_line, 3, base, 0x40000);
   }

   if (per[0].but_push_once & PAD_UP)
   {
      s->menu_selection--;
      if (s->menu_selection < 0)
      {
         s->menu_selection = s->num_menu_items - 1;
      }
   }

   if (per[0].but_push_once & PAD_DOWN)
   {
      s->menu_selection++;
      if (s->menu_selection >(s->num_menu_items - 1))
      {
         s->menu_selection = 0;
      }
   }

   if (per[0].but_push_once & PAD_LEFT)
   {
      s->vars[s->menu_selection].value--;
      if (s->vars[s->menu_selection].value < 0)
      {
         s->vars[s->menu_selection].value = s->vars[s->menu_selection].num_values;
      }
   }

   if (per[0].but_push_once & PAD_RIGHT)
   {
      s->vars[s->menu_selection].value++;
      if (s->vars[s->menu_selection].value > s->vars[s->menu_selection].num_values)
      {
         s->vars[s->menu_selection].value = 0;
      }
   }
}

//////////////////////////////////////////////////////////////////////////////

void ra_do_preset(struct RegAdjusterState* s, int * vars)
{
   int i;
   for (i = 0; i < s->num_menu_items; i++)
   {
      s->vars[i].value = vars[i];
   }
}

//////////////////////////////////////////////////////////////////////////////

void vdp2_scroll_test_set_scroll(int pos)
{
   //scroll the first two layers a little slower
   //than 1px per frame in the x direction
   *(volatile u32 *)0x25F80070 = pos << 15;
   VDP2_REG_SCYIN0 = pos;

   *(volatile u32 *)0x25F80080 = -(pos << 15);
   VDP2_REG_SCYIN1 = pos;

   VDP2_REG_SCXN2 = pos;
   VDP2_REG_SCYN2 = pos;

   VDP2_REG_SCXN3 = -pos;
   VDP2_REG_SCYN3 = pos;
}

//////////////////////////////////////////////////////////////////////////////

void vdp2_scroll_test_set_map(screen_settings_struct* settings, int which)
{
   int i;

   for (i = 0; i < 4; i++)
   {
      settings->map[i] = which;
   }
}

//////////////////////////////////////////////////////////////////////////////

void vdp2_basic_tile_scroll_setup(const u32 tile_address)
{
   int i;

   vdp_rbg0_deinit();

   VDP2_REG_CYCA0L = 0x0123;
   VDP2_REG_CYCA0U = 0xFFFF;
   VDP2_REG_CYCB0L = 0xF4F5;
   VDP2_REG_CYCB0U = 0xFF76;

   load_font_8x8_to_vram_1bpp_to_4bpp(tile_address, VDP2_RAM);

   screen_settings_struct settings;

   settings.color = 0;
   settings.is_bitmap = 0;
   settings.char_size = 0;
   settings.pattern_name_size = 0;
   settings.plane_size = 0;
   vdp2_scroll_test_set_map(&settings, 0);
   settings.transparent_bit = 0;
   settings.map_offset = 0;
   vdp_nbg0_init(&settings);

   vdp2_scroll_test_set_map(&settings, 1);
   vdp_nbg1_init(&settings);

   vdp2_scroll_test_set_map(&settings, 2);
   vdp_nbg2_init(&settings);

   vdp2_scroll_test_set_map(&settings, 3);
   vdp_nbg3_init(&settings);

   vdp_set_default_palette();

   //set pattern name data to the empty font tile
   for (i = 0; i < 256; i++)
   {
      write_str_as_pattern_name_data(0, i, "                                                                ", 0, 0x000000, tile_address);
   }

   vdp_disp_on();
}

//////////////////////////////////////////////////////////////////////////////


void vdp2_basic_tile_scroll_deinit()
{
   int i;
   //restore settings so the menus don't break

   vdp_nbg0_deinit();
   vdp_nbg1_deinit();
   vdp_nbg2_deinit();
   vdp_nbg3_deinit();

   vdp_rbg0_init(&test_disp_settings);

   //clear the vram we used
   for (i = 0; i < 0x11000; i++)
   {
      vdp2_ram[i] = 0;
   }

   VDP2_REG_CYCA0U = 0xffff;
   VDP2_REG_CYCB0U = 0xffff;

   VDP2_REG_MPABN1 = 0x0000;
   VDP2_REG_MPCDN1 = 0x0000;
   VDP2_REG_MPABN2 = 0x0000;
   VDP2_REG_MPCDN2 = 0x0000;
   VDP2_REG_MPABN3 = 0x0000;
   VDP2_REG_MPCDN3 = 0x0000;

   VDP2_REG_PRIR  = 0x0002;
   VDP2_REG_PRISA = 0x0101;
   VDP2_REG_PRISB = 0x0101;
   VDP2_REG_PRISC = 0x0101;
   VDP2_REG_PRISD = 0x0101;

   VDP2_REG_CCCTL = 0;
   VDP2_REG_LNCLEN = 0;
   VDP2_REG_RAMCTL = 0x1000;
   VDP2_REG_CCRNA = 0;
   VDP2_REG_CCRNB = 0;
   VDP2_REG_CCRLB = 0;

   yabauseut_init();
}

//////////////////////////////////////////////////////////////////////////////

void vdp2_all_scroll_test()
{
   int i;
   const u32 tile_address = 0x40000;

   auto_test_sub_test_start("All scroll screen test");

   vdp2_basic_tile_scroll_setup(tile_address);

   for (i = 0; i < 64; i += 4)
   {
      write_str_as_pattern_name_data(0, i, "A button: Start scrolling. NBG0. Testing NBG0. This is NBG0.... ", 3, 0x000000, tile_address);
      write_str_as_pattern_name_data(0, i + 1, "B button: Stop scrolling.  NBG1. Testing NBG1. This is NBG1.... ", 4, 0x004000, tile_address);
      write_str_as_pattern_name_data(0, i + 2, "C button: Reset.           NBG2. Testing NBG2. This is NBG2.... ", 5, 0x008000, tile_address);
      write_str_as_pattern_name_data(0, i + 3, "Start:    Exit.            NBG3. Testing NBG3. This is NBG3.... ", 6, 0x00C000, tile_address);
   }

   int do_scroll = 0;
   int scroll_pos = 0;
   int framecount = 0;

#ifdef BUILD_AUTOMATED_TESTING
   auto_test_take_screenshot(1);
#else
   for (;;)
   {

      vdp_vsync();

      framecount++;

      if (do_scroll)
      {
         if ((framecount % 3) == 0)
            scroll_pos++;

         vdp2_scroll_test_set_scroll(scroll_pos);
      }

      if (per[0].but_push_once & PAD_A)
      {
         do_scroll = 1;
      }

      if (per[0].but_push_once & PAD_B)
      {
         do_scroll = 0;
      }

      if (per[0].but_push_once & PAD_C)
      {
         do_scroll = 0;
         scroll_pos = 0;
         vdp2_scroll_test_set_scroll(scroll_pos);
      }

      if (per[0].but_push_once & PAD_START)
         break;
   }
#endif

   vdp2_basic_tile_scroll_deinit();
}

//////////////////////////////////////////////////////////////////////////////

void vdp2_line_color_screen_test_set_up_line_screen(const u32 table_address)
{
   int i;

   //create palette entries used by line screen
   //and write them to color ram

   int r = 0, g = 0, b = 31;

   const int line_palette_start = 256;//starting entry in color ram

   volatile u16 * color_ram_ptr = (volatile u16 *)(VDP2_CRAM + line_palette_start * 2);

   for (i = 0; i < 224; i++)
   {
      if ((i % 8) == 0)
      {
         r++;
         b--;
      }
      color_ram_ptr[i] = RGB555(r, g, b);
   }

   //write line screen table to vram
   volatile u16 *color_table_ptr = (volatile u16 *)(VDP2_RAM + table_address);

   for (i = 0; i < 224; i++)
   {
      color_table_ptr[i] = i + line_palette_start;
   }
}

//////////////////////////////////////////////////////////////////////////////

struct Ccctl {
   int exccen, ccrtmd, ccmd, spccen, lcccen, r0ccen;
   int nccen[4];
};

void do_color_ratios(int *framecount, int * ratio, int *ratio_dir)
{
   *framecount = *framecount + 1;

   if ((*framecount % 3) == 0)
      *ratio = *ratio_dir + *ratio;

   if (*ratio > 30)
      *ratio_dir = -1;
   if (*ratio < 2)
      *ratio_dir = 1;
}

//////////////////////////////////////////////////////////////////////////////

void vdp2_line_color_write_regs(struct Ccctl ccctl, int lnclen, int lcclmd, u32 table_address)
{
   VDP2_REG_CCCTL = (ccctl.exccen << 10) | (ccctl.ccrtmd << 9) | (ccctl.ccmd << 8) | (ccctl.lcccen << 5) | 0xf;
   VDP2_REG_LNCLEN = lnclen;
   *(volatile u32 *)0x25F800A8 = (lcclmd << 31) | (table_address / 2);
}

void vdp2_line_color_screen_test()
{
   const u32 tile_address = 0x40000;
   const u32 table_address = 0x10000;
   int i;

   auto_test_sub_test_start("Line color screen test");

   vdp2_basic_tile_scroll_setup(tile_address);

   vdp2_line_color_screen_test_set_up_line_screen(table_address);

   //set up instructions
   char * instructions[] = {
      "Controls:     (START to exit)          ",
      "A:     ccmd   (as is/ratio)    on/off  ",
      "B:     ccrtmd (2nd/top)        on/off  ",
      "C:     lnclen (insert line)    on/off  ",
      "X:     exccen (extended calc)  on/off  ",
      "Y:     NBG0-4 ratio update     on/off  ",
      "Z:     line color per line     on/off  ",
      "UP:    set bugged emu settings #1      ",
      "LEFT:  set bugged emu settings #2      ",
      "RIGHT: set bugged emu settings #3      "
   };

   for (i = 0; i < 10; i++)
   {
      write_str_as_pattern_name_data(0, 8 + i, instructions[i], 3, 0x000000, tile_address);
   }

   //test pattern at bottom of screen
   for (i = 20; i < 28; i += 4)
   {

      write_str_as_pattern_name_data(0, i, "\n\n\n\nNBG0\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\nNBG0\n\n\n\n", 3, 0x000000, tile_address);
      write_str_as_pattern_name_data(0, i + 1, "\n\n\n\nNBG1\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\nNBG1\n\n\n\n", 3, 0x004000, tile_address);
      write_str_as_pattern_name_data(0, i + 2, "\n\n\n\nNBG2\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\nNBG2\n\n\n\n", 3, 0x008000, tile_address);
      write_str_as_pattern_name_data(0, i + 3, "\n\n\n\nNBG3\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\nNBG3\n\n\n\n", 3, 0x00C000, tile_address);
   }

   //overlapping tiles, so that they will be colored differently from the rest of the screen depending on settings
   write_str_as_pattern_name_data(0, 19, "NBG0 and NBG1 overlap on this line.      ", 3, 0x000000, tile_address);
   write_str_as_pattern_name_data(0, 19, "NBG0 and NBG1 overlap on this line.      ", 4, 0x004000, tile_address);

   struct Ccctl ccctl;

   ccctl.exccen = 0;
   ccctl.ccrtmd = 1;
   ccctl.ccmd = 0;
   ccctl.lcccen = 1;

   int lnclen = 0x3f;
   int lcclmd = 1;

   int framecount = 0;
   int ratio = 0;
   int ratio_dir = 1;
   int update_nbg_ratios = 1;
   int nbg_ratio[4] = {0};
   char ratio_status_str[64];
   int lsmd = 0;

#ifdef BUILD_AUTOMATED_TESTING
   vdp2_line_color_write_regs(ccctl, lnclen, lcclmd, table_address);
   auto_test_take_screenshot(1);
#else
   for (;;)
   {
      vdp_vsync();

      VDP2_REG_TVMD = (1 << 15) | (lsmd << 6) | 0;

      vdp2_line_color_write_regs(ccctl, lnclen, lcclmd, table_address);

      //update color calculation ratios
      do_color_ratios(&framecount, &ratio, &ratio_dir);

      if (update_nbg_ratios)
      {
         nbg_ratio[2] = nbg_ratio[0] = ((-ratio) & 0x1f);
         nbg_ratio[3] = nbg_ratio[1] = ratio;

         VDP2_REG_CCRNA = nbg_ratio[0] | nbg_ratio[1] << 8;
         VDP2_REG_CCRNB = nbg_ratio[2] | nbg_ratio[3] << 8;
      }

      VDP2_REG_CCRLB = ratio;

      //update register status
      if (ccctl.ccmd)
      {
         write_str_as_pattern_name_data(0, 0, "CCMD  =   1  Add as is                   ", 3, 0x000000, tile_address);
      }
      else
      {
         write_str_as_pattern_name_data(0, 0, "CCMD  =   0  Add according to reg value  ", 3, 0x000000, tile_address);
      }

      if (ccctl.ccrtmd)
      {
         write_str_as_pattern_name_data(0, 1, "CCRTMD=   1  Select per 2nd screen       ", 3, 0x000000, tile_address);
      }
      else
      {
         write_str_as_pattern_name_data(0, 1, "CCRTMD=   0  Select per top screen       ", 3, 0x000000, tile_address);
      }

      if (lnclen)
      {
         write_str_as_pattern_name_data(0, 2, "LNCLEN=0x3f  Line screen inserts on all  ", 3, 0x000000, tile_address);
      }
      else
      {
         write_str_as_pattern_name_data(0, 2, "LNCLEN=0x00  Line screen disabled on all ", 3, 0x000000, tile_address);
      }

      if (ccctl.exccen)
      {
         write_str_as_pattern_name_data(0, 3, "EXCCEN=   1  Extended color calc on      ", 3, 0x000000, tile_address);
      }
      else
      {
         write_str_as_pattern_name_data(0, 3, "EXCCEN=   0  Extended color calc off     ", 3, 0x000000, tile_address);
      }
      if (lcclmd)
      {
         write_str_as_pattern_name_data(0, 4, "LCCLMD=   1  Line color per line         ", 3, 0x000000, tile_address);
      }
      else
      {
         write_str_as_pattern_name_data(0, 4, "LCCLMD=   0  Single color                ", 3, 0x000000, tile_address);
      }

      sprintf(ratio_status_str, "Ratios    NBG0=%04x NBG1=%04x           ", nbg_ratio[0], nbg_ratio[1]);
      write_str_as_pattern_name_data(0, 5, ratio_status_str, 3, 0x000000, tile_address);

      sprintf(ratio_status_str, "          NBG2=%04x NBG3=%04x LINE=%04x ", nbg_ratio[2], nbg_ratio[3], ratio);
      write_str_as_pattern_name_data(0, 6, ratio_status_str, 3, 0x000000, tile_address);

      //handle user inputs
      if (per[0].but_push_once & PAD_A)
      {
         ccctl.ccmd = !ccctl.ccmd;
      }

      if (per[0].but_push_once & PAD_B)
      {
         ccctl.ccrtmd = !ccctl.ccrtmd;
      }

      if (per[0].but_push_once & PAD_C)
      {
         if (lnclen == 0)
         {
            lnclen = 0x3f;//enable all
         }
         else
         {
            lnclen = 0;//disable all
         }
      }

      if (per[0].but_push_once & PAD_X)
      {
         ccctl.exccen = !ccctl.exccen;
      }

      if (per[0].but_push_once & PAD_Y)
      {
         update_nbg_ratios = !update_nbg_ratios;
      }

      if (per[0].but_push_once & PAD_Z)
      {
         lcclmd = !lcclmd;
      }

      if (per[0].but_push_once & PAD_UP)
      {
         ccctl.ccrtmd = 1;
         ccctl.ccmd = 0;
         ccctl.exccen = 0;
         update_nbg_ratios = 0;
         lcclmd = 0;
         lnclen = 0x3f;
      }

      if (per[0].but_push_once & PAD_LEFT)
      {
         ccctl.ccrtmd = 1;
         ccctl.ccmd = 0;
         ccctl.exccen = 0;
         update_nbg_ratios = 0;
         lcclmd = 1;
         lnclen = 0x3f;
      }

      if (per[0].but_push_once & PAD_RIGHT)
      {
         ccctl.ccrtmd = 0;
         ccctl.ccmd = 1;
         ccctl.exccen = 0;
         update_nbg_ratios = 1;
         lcclmd = 1;
         lnclen = 0x3f;
      }

      if (per[0].but_push_once & PAD_DOWN)
      {
         if (lsmd == 3)
            lsmd = 0;
         else
            lsmd = 3;
      }

      if (per[0].but_push_once & PAD_START)
         break;
   }
#endif

   vdp2_basic_tile_scroll_deinit();
   vdp_set_default_palette();
}

//////////////////////////////////////////////////////////////////////////////

void write_large_font(int x_pos, int y_pos, int* number, int palette, u32 base, const u32 tile_address)
{
   int y, x, j = 0;
   for (y = 0; y < 5; y++)
   {
      for (x = 0; x < 3; x++)
      {
         if (number[j])
         {
            write_str_as_pattern_name_data(x + x_pos, y + y_pos, "\n", palette, base, tile_address);
         }
         j++;
      }
   }
}

//////////////////////////////////////////////////////////////////////////////

//vars for reg adjuster
struct ExtendedColorRegs{
   int nbg_priority[4];
   int nbg_color_calc_enable[4];
   int nbg_color_calc_ratio[4];
   int color_calculation_ratio_mode;
   int extended_color_calculation;
   int color_calculation_mode_bit;
   int color_ram_mode;
   int line_color_screen_inserts[4];
   int line_color_mode_bit;
   int line_color_screen_color_calc_enable;
   int line_color_screen_ratio;
};

void vdp2_extended_color_write_regs(struct ExtendedColorRegs v, u32 line_table_address)
{
   VDP2_REG_CCCTL =
      (v.extended_color_calculation << 10) |
      (v.color_calculation_ratio_mode << 9) |
      (v.color_calculation_mode_bit << 8) |
      (v.nbg_color_calc_enable[0]) |
      (v.nbg_color_calc_enable[1] << 1) |
      (v.nbg_color_calc_enable[2] << 2) |
      (v.nbg_color_calc_enable[3] << 3) |
      (v.line_color_screen_color_calc_enable << 5);

   VDP2_REG_CCRNA = v.nbg_color_calc_ratio[0] | (v.nbg_color_calc_ratio[1] << 8);
   VDP2_REG_CCRNB = v.nbg_color_calc_ratio[2] | (v.nbg_color_calc_ratio[3] << 8);
   VDP2_REG_CCRLB = v.line_color_screen_ratio;

   VDP2_REG_LNCLEN = (v.line_color_screen_inserts[0]) |
      (v.line_color_screen_inserts[1] << 1) |
      (v.line_color_screen_inserts[2] << 2) |
      (v.line_color_screen_inserts[3] << 3);

   VDP2_REG_PRINA = v.nbg_priority[0] | (v.nbg_priority[1] << 8);
   VDP2_REG_PRINB = v.nbg_priority[2] | (v.nbg_priority[3] << 8);

   VDP2_REG_RAMCTL = v.color_ram_mode << 12;

   *(volatile u32 *)0x25F800A8 = (v.line_color_mode_bit << 31) | (line_table_address / 2);
}

//////////////////////////////////////////////////////////////////////////////

void vdp2_extended_color_calculation_test()
{
   const u32 tile_address = 0x40000;
   const u32 line_table_address = 0x10000;
   int zero[] = { 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1 };
   int one[] = { 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0 };
   int two[] = { 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1 };
   int three[] = { 1, 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 1, 1 };
   const char* fill = "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n";

   int i;

   auto_test_sub_test_start("Extended color calculation test");

   vdp2_basic_tile_scroll_setup(tile_address);
   vdp2_line_color_screen_test_set_up_line_screen(line_table_address);

   int palette = 9;

   for (i = 0; i < 32; i++)
   {
      write_str_as_pattern_name_data(0, i, fill, palette, 0x000000, tile_address);
   }

   palette++;
   for (i = 7; i < 32; i++)
   {
      write_str_as_pattern_name_data(0, i, fill, palette, 0x004000, tile_address);
   }

   palette++;
   for (i = 14; i < 32; i++)
   {
      write_str_as_pattern_name_data(0, i, fill, palette, 0x008000, tile_address);
   }

   palette++;
   for (i = 21; i < 32; i++)
   {
      write_str_as_pattern_name_data(0, i, fill, palette, 0x00c000, tile_address);
   }

   for (i = 1; i < 24; i += 7)
   {
      write_large_font(1, i, zero, 0, 0x000000, tile_address);
      write_large_font(5, i, one, 0, 0x004000, tile_address);
      write_large_font(9, i, two, 0, 0x008000, tile_address);
      write_large_font(13, i, three, 0, 0x00C000, tile_address);
   }


   //set up instructions
   char * instructions[] = {
      "U/D/L/R: Reg menu     ",
      "A: Change Preset      ",
      "Start: Exit           "
   };

   int j = 0;
   for (i = 24; i < 24 + 7; i++)
   {
      write_str_as_pattern_name_data(18, i, instructions[j++], 3, 0x000000, tile_address);
   }

   //vars for reg adjuster
   struct ExtendedColorRegs v = { { 0 } };

   struct RegAdjusterState s = { 0 };

   ra_add_array(&s, (int(*)[])v.nbg_priority, 4,          "NBG Priority   NBG", 7);
   ra_add_array(&s, (int(*)[])v.nbg_color_calc_enable, 4, "Color cl enabl NBG", 1);
   ra_add_array(&s, (int(*)[])v.nbg_color_calc_ratio, 4,  "Color cl ratio NBG", 31);
   ra_add_var(&s, &v.extended_color_calculation,          "Extended color cal ", 1);
   ra_add_var(&s, &v.color_calculation_ratio_mode,        "Color cal ratio md ", 1);
   ra_add_var(&s, &v.color_calculation_mode_bit,          "Color cal mode bit ", 1);
   ra_add_var(&s, &v.color_ram_mode,                      "Color ram mode     ", 3);
   ra_add_array(&s, &v.line_color_screen_inserts, 4, "Line screen in NBG", 1);
   ra_add_var(&s, &v.line_color_mode_bit,                 "Line color mode bt ", 1);
   ra_add_var(&s, &v.line_color_screen_color_calc_enable, "Line col cal enabl ", 1);
   ra_add_var(&s, &v.line_color_screen_ratio,             "Line color cal rat ", 31);

   int presets[][24] =
   {
      //preset 0
      {
         //nbg priority
         1, 1, 1, 1,
         //nbg color calc enable
         1, 1, 1, 1,
         //nbg color calc ratio
         15, 0, 0, 0,
         //extended color calc
         1,
         //color calc ratio mode
         0,
         //color calc mode bit
         0,
         //color ram mode
         0,
         //Line screen inserts
         0, 0, 0, 0,
         //Line color mode bit
         0,
         //Line color calc enable
         0,
         //Line color ratio
         0
      },

      //preset 1
      {
         //nbg priority
         3, 2, 4, 0,
         //nbg color calc enable
         1, 1, 1, 1,
         //nbg color calc ratio
         15, 0, 0, 0,
         //extended color calc
         1,
         //color calc ratio mode
         0,
         //color calc mode bit
         1,
         //color ram mode
         0,
         //Line screen inserts
         0, 0, 0, 0,
         //Line color mode bit
         0,
         //Line color calc enable
         0,
         //Line color ratio
         0
      },

      //preset 2
      {
         //nbg priority
         3, 2, 7, 7,
         //nbg color calc enable
         1, 1, 1, 1,
         //nbg color calc ratio
         15, 0, 0, 0,
         //extended color calc
         1,
         //color calc ratio mode
         0,
         //color calc mode bit
         1,
         //color ram mode
         0,
         //Line screen inserts
         0, 0, 0, 0,
         //Line color mode bit
         0,
         //Line color calc enable
         0,
         //Line color ratio
         0
      },

      //preset 3
      {
         //nbg priority
         5, 7, 6, 0,
         //nbg color calc enable
         1, 0, 1, 1,
         //nbg color calc ratio
         15, 0, 0, 0,
         //extended color calc
         1,
         //color calc ratio mode
         0,
         //color calc mode bit
         1,
         //color ram mode
         0,
         //Line screen inserts
         0, 0, 0, 0,
         //Line color mode bit
         0,
         //Line color calc enable
         0,
         //Line color ratio
         0
      },

      //preset 4
      {
         //nbg priority
         7, 7, 0, 4,
         //nbg color calc enable
         1, 0, 1, 1,
         //nbg color calc ratio
         15, 0, 0, 0,
         //extended color calc
         1,
         //color calc ratio mode
         0,
         //color calc mode bit
         1,
         //color ram mode
         0,
         //Line screen inserts
         0, 0, 0, 0,
         //Line color mode bit
         0,
         //Line color calc enable
         0,
         //Line color ratio
         0
      },

      //preset 5
      {
         //nbg priority
         1, 1, 1, 1,
         //nbg color calc enable
         1, 1, 1, 1,
         //nbg color calc ratio
         0, 20, 31, 2,
         //extended color calc
         1,
         //color calc ratio mode
         1,
         //color calc mode bit
         0,
         //color ram mode
         0,
         //Line screen inserts
         0,0,0,0,
         //Line color mode bit
         0,
         //Line color calc enable
         0,
         //Line color ratio
         0
      }
   };

#ifdef BUILD_AUTOMATED_TESTING
   for (i = 0; i < 5; i++)
   {
      ra_do_preset(&s, presets[i]);
      ra_update_vars(&s);
      ra_do_menu(&s, 17, 0, 0);
      vdp2_extended_color_write_regs(v, line_table_address);
      auto_test_take_screenshot(1);
   }
#else

   int preset = 1;

   ra_do_preset(&s, presets[preset]);

   for (;;)
   {
      vdp_vsync();

      ra_update_vars(&s);

      ra_do_menu(&s, 17,0,0);

      vdp2_extended_color_write_regs(v,line_table_address);

      char preset_status[64] = { 0 };
      sprintf(preset_status, "Preset %d", preset);
      write_str_as_pattern_name_data(18, 27, preset_status, 3, 0x000000, tile_address);

      if (per[0].but_push_once & PAD_A)
      {
         preset++;

         if (preset > 5)
            preset = 0;

         ra_do_preset(&s, presets[preset]);
      }

      if (per[0].but_push_once & PAD_START)
         break;
   }
#endif

   vdp2_basic_tile_scroll_deinit();
}

//////////////////////////////////////////////////////////////////////////////

void vpd2_priority_shadow_draw_sprites(int start_x, int start_y, u32 vdp1_tile_address, int operation)
{
   int i, j;
   sprite_struct quad = { 0 };

   const int size = 8;

   quad.x = start_x * size;
   quad.y = start_y * size;

   int vdp2_priority = 0;
   int vdp2_color_calc = 0;
   int palette = 4;

   for (j = 0; j < 4; j++)
   {
      quad.x = start_x * size;

      for (i = 0; i < 4; i++)
      {
         quad.bank = (vdp2_priority << 12) | (vdp2_color_calc << 9) | (palette << 4);

         //use the "\n" tile
         quad.addr = vdp1_tile_address + (10 * 32);

         //msb on
         if (operation == 2)
         {
            quad.attr = (1 << 15);
         }

         quad.height = size;
         quad.width = size;

         vdp_draw_normal_sprite(&quad);

         quad.x += size;

         if (operation == 0 || operation == 1)
         {
            vdp2_priority++;
            vdp2_priority &= 7;
         }
         if (operation == 1)
         {
            vdp2_color_calc++;
            vdp2_color_calc &= 7;
         }

      }
      quad.y += size;
   }
}

//////////////////////////////////////////////////////////////////////////////

void write_tiles_4x(int x, int y, char * str, u32 vdp2_tile_address, u32 base)
{
   int i;
   for (i = 0; i < 4; i++)
   {
      write_str_as_pattern_name_data(x, y + i, str, 3, base, vdp2_tile_address);
   }
}

//////////////////////////////////////////////////////////////////////////////

void draw_normal_shadow_sprite(int x, int y, const char * str)
{
   sprite_struct quad = { 0 };

   int size = 32;

   int top_right_x = x * 8;
   int top_right_y = y * 8;
   quad.x = top_right_x + size;
   quad.y = top_right_y;
   quad.x2 = top_right_x + size;
   quad.y2 = top_right_y + size;
   quad.x3 = top_right_x;
   quad.y3 = top_right_y + size;
   quad.x4 = top_right_x;
   quad.y4 = top_right_y;
   quad.bank = 0x0ffe;

   vdp_draw_polygon(&quad);
}

//////////////////////////////////////////////////////////////////////////////

void vdp2_sprite_priority_shadow_test()
{
   const u32 vdp2_tile_address = 0x40000;
   const u32 vdp1_tile_address = 0x10000;
   vdp2_basic_tile_scroll_setup(vdp2_tile_address);

   load_font_8x8_to_vram_1bpp_to_4bpp(vdp1_tile_address, VDP1_RAM);

   VDP1_REG_PTMR = 0x02;//draw automatically with frame change

   int s0prin = 7;
   int s1prin = 6;

   VDP2_REG_PRISA = s0prin | (s1prin << 8);
   VDP2_REG_PRISB = 5 | (4 << 8);
   VDP2_REG_PRISC = 3 | (2 << 8);
   VDP2_REG_PRISD = 1 | (0 << 8);

   int nbg_priority[4] = { 0 };

   nbg_priority[0] = 7;
   nbg_priority[1] = 6;
   nbg_priority[2] = 5;
   nbg_priority[3] = 4;

   VDP2_REG_PRINA = nbg_priority[0] | (nbg_priority[1] << 8);
   VDP2_REG_PRINB = nbg_priority[2] | (nbg_priority[3] << 8);

   VDP2_REG_SDCTL = 0x9 | (1 << 8);

   int nbg_ratio[4] = { 0 };
   int framecount = 0;
   int ratio = 0;
   int ratio_dir = 1;

   int spccs = 2;
   int spccn = 5;

   write_str_as_pattern_name_data(0, 0, "Normal Shadow    ->", 3, 0x000000, vdp2_tile_address);
   write_str_as_pattern_name_data(0, 5, "MSB Transparent ", 3, 0x000000, vdp2_tile_address);
   write_str_as_pattern_name_data(0, 6, "          Shadow ->", 3, 0x000000, vdp2_tile_address);
   write_str_as_pattern_name_data(0, 10, "Sprite priority  ->", 3, 0x000000, vdp2_tile_address);
   write_str_as_pattern_name_data(0, 15, "MSB Sprite     ", 3, 0x000000, vdp2_tile_address);
   write_str_as_pattern_name_data(0, 16, "          Shadow ->", 3, 0x000000, vdp2_tile_address);
   write_str_as_pattern_name_data(0, 20, "Special Color    ", 3, 0x000000, vdp2_tile_address);
   write_str_as_pattern_name_data(0, 21, "     Calculation ->", 3, 0x000000, vdp2_tile_address);
   write_str_as_pattern_name_data(20, 25, "NBG0 NBG1 NBG2 NBG3", 3, 0x000000, vdp2_tile_address);

   int x;

   u32 addresses[4] = { 0x000000, 0x004000, 0x008000, 0x00c000 };

   char* str = "\n\n\n\n";

   for (x = 0; x < 4; x++)
   {
      int x_pos = 20 + (5 * x);
      write_tiles_4x(x_pos, 0, str, vdp2_tile_address, addresses[x]);//normal shadow tiles
      write_tiles_4x(x_pos, 5, str, vdp2_tile_address, addresses[x]);//msb shadow tiles
      write_tiles_4x(x_pos, 10, str, vdp2_tile_address, addresses[x]);//sprite priority tiles
      write_tiles_4x(x_pos, 15, str, vdp2_tile_address, addresses[x]);//msb shadow and cc tiles
      write_tiles_4x(x_pos, 20, str, vdp2_tile_address, addresses[x]);//special color calc tiles
   }

   int tvm = 0;
   int hreso = 0;
   int lsmd = 0;
   int die = 0;
   int dil = 0;

   for (;;)
   {
      vdp_vsync();

      VDP1_REG_TVMR = tvm;

      VDP1_REG_FBCR = ((die&1) << 3) | ((dil&1) << 2);

      VDP2_REG_TVMD = (1 << 15) | (lsmd << 6) | hreso;

      if (tvm == 0)
         VDP2_REG_SPCTL = (spccs << 12) | (spccn << 8) | (0 << 5) | 7;
      else
         VDP2_REG_SPCTL = (spccs << 12) | (spccn << 8) | (0 << 5) | 8;

      VDP2_REG_CCCTL = (1 << 6) | (1 << 0) | (1 << 3);

      VDP2_REG_CCRSA = (u16)(nbg_ratio[0] | (nbg_ratio[1] << 8));
      VDP2_REG_CCRSB = (u16)(nbg_ratio[2] | (nbg_ratio[3] << 8));
      VDP2_REG_CCRSC = (u16)(nbg_ratio[0] | (nbg_ratio[1] << 8));
      VDP2_REG_CCRSD = (u16)(nbg_ratio[2] | (nbg_ratio[3] << 8));

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

      for (x = 0; x < 4; x++)
      {
         int x_pos = 20 + (5 * x);
         //normal shadow
         draw_normal_shadow_sprite(x_pos, 0, str);
         //msb shadow
         vpd2_priority_shadow_draw_sprites(x_pos, 5, vdp1_tile_address, 2);
         //sprite priority
         vpd2_priority_shadow_draw_sprites(x_pos, 10, vdp1_tile_address, 0);
         //msb shadow and color calculation
         vpd2_priority_shadow_draw_sprites(x_pos, 15, vdp1_tile_address, 0);
         vpd2_priority_shadow_draw_sprites(x_pos, 15, vdp1_tile_address, 2);
         //special color calc
         vpd2_priority_shadow_draw_sprites(x_pos, 20, vdp1_tile_address, 1);
      }

      vdp_end_draw_list();

      char status[64] = "";

      sprintf(status, "S0PRIN=%02x S1PRIN=%02x", s0prin, s1prin);
      write_str_as_pattern_name_data(0, 25, status, 3, 0x000000, vdp2_tile_address);
      sprintf(status, "SOCCRT=%02x S1CCRT=%02x", nbg_ratio[0], nbg_ratio[1]);
      write_str_as_pattern_name_data(0, 26, status, 3, 0x000000, vdp2_tile_address);
      sprintf(status, "SPCCS =%02x SPCCN =%02x (Press A,B) ", spccs, spccn);
      write_str_as_pattern_name_data(0, 27, status, 3, 0x000000, vdp2_tile_address);

      do_color_ratios(&framecount, &ratio, &ratio_dir);

      nbg_ratio[0] = ((-ratio) & 0x1f);
      nbg_ratio[2] = nbg_ratio[0];
      nbg_ratio[3] = nbg_ratio[1] = ratio;

      if (per[0].but_push_once & PAD_A)
      {
         spccs++;
         spccs &= 3;
      }

      if (per[0].but_push_once & PAD_B)
      {
         spccn++;
         spccn &= 7;
      }

      if (per[0].but_push_once & PAD_C)
      {
         tvm = !tvm;
      }

      if (per[0].but_push_once & PAD_X)
      {
         if (hreso == 2)
            hreso = 0;
         else
            hreso = 2;
      }

      if (per[0].but_push_once & PAD_Y)
      {
         reset_system();
      }

      if (per[0].but_push_once & PAD_Z)
      {
         if (lsmd == 3)
            lsmd = 0;
         else
            lsmd = 3;
      }

      if (per[0].but_push_once & PAD_UP)
      {
         die = !die;
      }

      if (per[0].but_push_once & PAD_DOWN)
      {
         dil = !dil;
      }

      if (per[0].but_push_once & PAD_START)
         break;
   }

   vdp2_basic_tile_scroll_deinit();
}

//////////////////////////////////////////////////////////////////////////////

void draw_grid(int clipping_mode)
{
   sprite_struct quad = { 0 };

   int j;

   quad.bank = 3;
   quad.attr = (1 << 10) | (clipping_mode << 9);
   for (j = 0; j < 40; j++)
   {
      quad.x = j * 8;
      quad.y = 0;
      quad.x2 = j * 8;
      quad.y2 = 224;

      vdp_draw_line(&quad);
   }

   for (j = 0; j < 40; j++)
   {
      quad.x = 0;
      quad.y = j * 8;
      quad.x2 = 321;
      quad.y2 = j * 8;

      vdp_draw_line(&quad);
   }
}

//////////////////////////////////////////////////////////////////////////////

void scaled_sprite(int x, int y, int x3, int y3, u32 vdp1_tile_address, int flip)
{
   sprite_struct quad = { 0 };

   quad.width = 8;
   quad.height = 8;

   int palette = 3;

   quad.x = x;
   quad.y = y;
   quad.x2 = 0;
   quad.y2 = 0;

   quad.x3 = x3;
   quad.y3 = y3;

   quad.bank = (palette << 4);

   quad.addr = vdp1_tile_address + ('a' * 32);

   quad.attr = (flip << 4) << 12 | 0x80;

   vdp_draw_scaled_sprite(&quad);
}

//////////////////////////////////////////////////////////////////////////////

void draw_scaled_sprites(int x, int y, u32 vdp1_tile_address, int flip)
{
   //x1 < x2, y1 < y2
   scaled_sprite(
      x,
      y,
      x + 7,
      y + 7, vdp1_tile_address, flip);

   //x2 < x1, y1 < y2
   scaled_sprite(
      x + 16 + 7,
      y + 0,
      x + 16,
      y + 0 + 7, vdp1_tile_address, flip);

   //x1 < x2, y2 < y1
   scaled_sprite(
      x + 48,
      y + 0 + 7,
      x + 48 + 7,
      y + 0, vdp1_tile_address, flip);

   //x2 < x1, y2 < y1
   scaled_sprite(
      x + 32 + 7,
      y + 0 + 7,
      x + 32,
      y + 0, vdp1_tile_address, flip);
}

//////////////////////////////////////////////////////////////////////////////

void vdp1_scaled_sprite_clipping_latch()
{
   const u32 vdp2_tile_address = 0x40000;
   const u32 vdp1_tile_address = 0x10000;
   vdp2_basic_tile_scroll_setup(vdp2_tile_address);

   load_font_8x8_to_vram_1bpp_to_4bpp(vdp1_tile_address, VDP1_RAM);

   VDP1_REG_PTMR = 0x02;//draw automatically with frame change

   VDP2_REG_PRISA = 7 | (6 << 8);
   VDP2_REG_PRISB = 5 | (4 << 8);
   VDP2_REG_PRISC = 3 | (2 << 8);
   VDP2_REG_PRISD = 1 | (0 << 8);

   int tvm = 0;
   int hreso = 0;
   int lsmd = 0;
   int die = 0;
   int dil = 0;

   vdp_start_draw_list();
   sprite_struct quad = { 0 };

   //system clipping
   quad.x = 320 - 8;
   quad.y = 224 - 8;

   vdp_system_clipping(&quad);

   //user clipping
   quad.x = 0;
   quad.y = 0;
   quad.x2 = 320 - 16;
   quad.y2 = 224 - 16;

   vdp_user_clipping(&quad);

   vdp_end_draw_list();

   struct Pos
   {
      int x, y;
   };

   struct Pos system_clipping = { 0 };

   system_clipping.x = 319 - 8;
   system_clipping.y = 223 - 8;

   struct UserClipping
   {
      struct Pos a, b;
   };

   struct UserClipping user_clipping = { { 0 } };

   user_clipping.a.x = 8;
   user_clipping.a.y = 8;

   user_clipping.b.x = 319 - 16;
   user_clipping.b.y = 223 - 16;

   int clipping_mode = 0;

   struct Preset
   {
      struct Pos system_clipping;
      struct UserClipping user_clipping;
      int clipping_mode;
   };

   int num_presets = 7;

   struct Preset presets[7] =
   {
      //normal setting
      {
         { 0x28, 0x28 },
         { { 0x08, 0x08 },{ 0x20, 0x20 } },
         0
      },
      //user x1 < user x0
      {
         { 0x28, 0x28 },
         { { 0x20, 0x08 },{ 0x08, 0x20 } },
         0
      },
      //user y1 < user y0
      {
         { 0x28, 0x28 },
         { { 0x08, 0x20 },{ 0x20, 0x08 } },
         0
      },
      //user x1 < user x0, user y1 < user y0
      {
         { 0x28, 0x28 },
         { { 0x20, 0x20 },{ 0x08, 0x08 } },
         0
      },
      //user x1 > system x
      {
         { 0x28, 0x28 },
         { { 0x08, 0x08 },{ 0x30, 0x20 } },
         0
      },
      //user y1 > system y
      {
         { 0x28, 0x28 },
         { { 0x08, 0x08 },{ 0x20, 0x30 } },
         0
      },
      //user x1 > system x, user y1 > system y
      {
         { 0x28, 0x28 },
         { { 0x08, 0x08 },{ 0x30, 0x30 } },
         0
      },
   };

   int current_preset = 0;

   for (;;)
   {
      vdp_vsync();

      VDP1_REG_TVMR = tvm;

      VDP1_REG_FBCR = ((die & 1) << 3) | ((dil & 1) << 2);

      VDP2_REG_TVMD = (1 << 15) | (lsmd << 6) | hreso;

      vdp_start_draw_list();

      if (per[0].but_push & PAD_A)
      {
         if (per[0].but_push & PAD_LEFT)
            system_clipping.x--;
         if (per[0].but_push & PAD_RIGHT)
            system_clipping.x++;
         if (per[0].but_push & PAD_UP)
            system_clipping.y--;
         if (per[0].but_push & PAD_DOWN)
            system_clipping.y++;
      }

      quad.x = system_clipping.x;
      quad.y = system_clipping.y;

      vdp_system_clipping(&quad);

      if (per[0].but_push & PAD_B)
      {
         if (per[0].but_push & PAD_L)
         {
            if (per[0].but_push & PAD_LEFT)
               user_clipping.a.x--;
            if (per[0].but_push & PAD_RIGHT)
               user_clipping.a.x++;
            if (per[0].but_push & PAD_UP)
               user_clipping.a.y--;
            if (per[0].but_push & PAD_DOWN)
               user_clipping.a.y++;
         }
         else
         {
            if (per[0].but_push & PAD_LEFT)
               user_clipping.b.x--;
            if (per[0].but_push & PAD_RIGHT)
               user_clipping.b.x++;
            if (per[0].but_push & PAD_UP)
               user_clipping.b.y--;
            if (per[0].but_push & PAD_DOWN)
               user_clipping.b.y++;
         }
      }

      quad.x = user_clipping.a.x;
      quad.y = user_clipping.a.y;
      quad.x2 = user_clipping.b.x;
      quad.y2 = user_clipping.b.y;

      vdp_user_clipping(&quad);

      quad.x = 0;
      quad.y = 0;
      quad.x2 = 0;
      quad.y2 = 0;

      vdp_local_coordinate(&quad);

      draw_grid(clipping_mode);

      draw_scaled_sprites(0, 0, vdp1_tile_address, 0);
      draw_scaled_sprites(0, 16, vdp1_tile_address, 1);
      draw_scaled_sprites(0, 32, vdp1_tile_address, 2);
      draw_scaled_sprites(0, 48, vdp1_tile_address, 3);

      vdp_end_draw_list();

      char status[64] = "";

      sprintf(status, "clip mode = %02x", clipping_mode);
      write_str_as_pattern_name_data(0, 24, status, 3, 0x000000, vdp2_tile_address);
      sprintf(status, "sys x =%02x sys y =%02x  ", system_clipping.x, system_clipping.y);
      write_str_as_pattern_name_data(0, 25, status, 3, 0x000000, vdp2_tile_address);
      sprintf(status, "usr x0=%02x usr y0=%02x  ", user_clipping.a.x, user_clipping.a.y);
      write_str_as_pattern_name_data(0, 26, status, 3, 0x000000, vdp2_tile_address);
      sprintf(status, "usr x1=%02x usr y1=%02x  ", user_clipping.b.x, user_clipping.b.y);
      write_str_as_pattern_name_data(0, 27, status, 3, 0x000000, vdp2_tile_address);

      if (per[0].but_push_once & PAD_R)
      {
         clipping_mode++;

         clipping_mode &= 3;
      }

      if (per[0].but_push_once & PAD_C)
      {
         tvm = !tvm;
      }

      if (per[0].but_push_once & PAD_X)
      {
         if (hreso == 2)
            hreso = 0;
         else
            hreso = 2;
      }

      if (per[0].but_push_once & PAD_Y)
      {
         reset_system();
      }

      if (per[0].but_push_once & PAD_Z)
      {
         system_clipping.x = presets[current_preset].system_clipping.x;
         system_clipping.y = presets[current_preset].system_clipping.y;
         user_clipping.a.x = presets[current_preset].user_clipping.a.x;
         user_clipping.a.y = presets[current_preset].user_clipping.a.y;
         user_clipping.b.x = presets[current_preset].user_clipping.b.x;
         user_clipping.b.y = presets[current_preset].user_clipping.b.y;
         clipping_mode = presets[current_preset].clipping_mode;

         current_preset++;

         if (current_preset >= num_presets)
            current_preset = 0;
      }

      if (per[0].but_push_once & PAD_L)
      {
         if (die == 0)
            die = 1;
         else
            die = 0;
      }

      if (per[0].but_push_once & PAD_START)
         break;
   }

   vdp2_basic_tile_scroll_deinit();
}

//////////////////////////////////////////////////////////////////////////////

void vdp2_change_4bbp_tile_color(u32 address, int amount)
{
   int i;

   for (i = 0; i < font_8x8_size; i++)
   {
      volatile u8 *dest = (volatile u8 *)(VDP2_RAM + address);

      u8 value = dest[i];
      u8 pix1 = (value >> 4) & 0xf;
      u8 pix2 = value & 0xf;

      if (pix1 != 0)
         pix1 += amount;
      if (pix2 != 0)
         pix2 += amount;

      dest[i] = (pix1 << 4) | pix2;
   }
}

//////////////////////////////////////////////////////////////////////////////

struct SpecialPriorityRegs {
   int special_color_calc_mode[4];
   int nbg_color_calc_enable[4];
   int color_calculation_ratio_mode;//select per top
   int special_priority_mode_bit[4];
   int special_function_code_select[4];
   int special_function_code_bit[8];
   int color_calculation_mode_bit;
   int nbg_priority[4];
};

void vdp2_special_priority_write_regs(struct SpecialPriorityRegs v, int* nbg_ratio)
{
   VDP2_REG_SFPRMD = v.special_priority_mode_bit[0] |
      (v.special_priority_mode_bit[1] << 2) |
      (v.special_priority_mode_bit[2] << 4) |
      (v.special_priority_mode_bit[3] << 6);

   VDP2_REG_PRINA = v.nbg_priority[0] | (v.nbg_priority[1] << 8);
   VDP2_REG_PRINB = v.nbg_priority[2] | (v.nbg_priority[3] << 8);

   VDP2_REG_SFSEL = v.special_function_code_select[0] |
      (v.special_function_code_select[1] << 1) |
      (v.special_function_code_select[2] << 2) |
      (v.special_function_code_select[3] << 3);

   VDP2_REG_SFCODE =
      (v.special_function_code_bit[0] << 0) |
      (v.special_function_code_bit[1] << 1) |
      (v.special_function_code_bit[2] << 2) |
      (v.special_function_code_bit[3] << 3) |
      (v.special_function_code_bit[4] << 4) |
      (v.special_function_code_bit[5] << 5) |
      (v.special_function_code_bit[6] << 6) |
      (v.special_function_code_bit[7] << 7);

   VDP2_REG_CCRNA = (u16)(nbg_ratio[0] | (nbg_ratio[1] << 8));
   VDP2_REG_CCRNB = (u16)(nbg_ratio[2] | (nbg_ratio[3] << 8));

   VDP2_REG_CCCTL =
      (v.color_calculation_ratio_mode << 9) |
      (v.color_calculation_mode_bit << 8) |
      (v.nbg_color_calc_enable[0]) |
      (v.nbg_color_calc_enable[1] << 1) |
      (v.nbg_color_calc_enable[2] << 2) |
      (v.nbg_color_calc_enable[3] << 3);

   VDP2_REG_SFCCMD =
      v.special_color_calc_mode[0] |
      (v.special_color_calc_mode[1] << 2) |
      (v.special_color_calc_mode[2] << 4) |
      (v.special_color_calc_mode[3] << 6);
}

//////////////////////////////////////////////////////////////////////////////

void vdp2_special_priority_test()
{
   const u32 test_tile[] =
   {
      0x11111111,
      0x11111111,
      0x22222222,
      0x22222222,
      0x33333333,
      0x33333333,
      0x44444444,
      0x44444444
   };
   const u32 test_tile2[] =
   {
      0x55555555,
      0x55555555,
      0x66666666,
      0x66666666,
      0x77777777,
      0x77777777,
      0x88888888,
      0x88888888
   };

   const u32 vdp2_tile_address[] = { 0x40000, 0x42000, 0x44000, 0x46000 };

   auto_test_sub_test_start("Special priority test");

   vdp2_basic_tile_scroll_setup(vdp2_tile_address[0]);

   int j = 0;

   for (j = 0; j < 4; j++)
   {
      int q = 0;
      for (q = 0; q < 8; q++)
      {
         volatile u32 *dest = (volatile u32 *)(VDP2_RAM + vdp2_tile_address[j] + 32);
         dest[q] = test_tile[q];
         dest[q + 8] = test_tile2[q];
      }
   }

   u32 addresses[4] = { 0x000000, 0x004000, 0x008000, 0x00c000 };

   int y = 0;
   int x = 0;

   for (y = 0; y < 4; y++)
   {
      for (x = 0; x < 4; x++)
      {
         int checker_pattern = 0;
         if ((x&1) == 0)
            checker_pattern = 1;

         write_tile(x + 0, y, 3, 1, addresses[0], vdp2_tile_address[0], 0, 0);
         write_tile(x + 0, y, 4, 1, addresses[1], vdp2_tile_address[0], checker_pattern, 0);

         write_tile(x + 4, y, 3, 2, addresses[0], vdp2_tile_address[0], 0, 0);
         write_tile(x + 4, y, 4, 2, addresses[1], vdp2_tile_address[0], checker_pattern, 0);

         write_tile(x + 8, y, 5, 1, addresses[2], vdp2_tile_address[0], 0, 0);
         write_tile(x + 8, y, 6, 1, addresses[3], vdp2_tile_address[0], checker_pattern, 0);

         write_tile(x + 12, y, 5, 2, addresses[2], vdp2_tile_address[0], 0, 0);
         write_tile(x + 12, y, 6, 2, addresses[3], vdp2_tile_address[0], checker_pattern, 0);
      }
   }

   write_str_as_pattern_name_data_special(0, 5, "NBG0", 3, addresses[0], vdp2_tile_address[0], 0, 0);
   write_str_as_pattern_name_data_special(0, 6, "NBG1", 4, addresses[1], vdp2_tile_address[0], 0, 0);
   write_str_as_pattern_name_data_special(0, 7, "NBG2", 5, addresses[2], vdp2_tile_address[0], 0, 0);
   write_str_as_pattern_name_data_special(0, 8, "NBG3", 6, addresses[3], vdp2_tile_address[0], 0, 0);

   write_tile(5, 5, 3, 1, addresses[0], vdp2_tile_address[0], 0, 0);
   write_tile(5, 6, 4, 1, addresses[1], vdp2_tile_address[0], 0, 0);
   write_tile(5, 7, 5, 1, addresses[2], vdp2_tile_address[0], 0, 0);
   write_tile(5, 8, 6, 1, addresses[3], vdp2_tile_address[0], 0, 0);

   write_tile(7, 5, 3, 2, addresses[0], vdp2_tile_address[0], 0, 0);
   write_tile(7, 6, 4, 2, addresses[1], vdp2_tile_address[0], 0, 0);
   write_tile(7, 7, 5, 2, addresses[2], vdp2_tile_address[0], 0, 0);
   write_tile(7, 8, 6, 2, addresses[3], vdp2_tile_address[0], 0, 0);

   int preset = 0;

   int nbg_ratio[4] = { 0x1f, 0x10, 0x8, 0x1 };

   //vars for reg adjuster
   struct SpecialPriorityRegs v = { { 0 } };

   struct RegAdjusterState s = { 0 };

   ra_add_array(&s, (int(*)[])v.special_color_calc_mode, 4, "Spcl clr cl md NBG", 3);
   ra_add_array(&s, (int(*)[])v.nbg_color_calc_enable, 4, "Color calc enb NBG", 1);
   ra_add_array(&s, (int(*)[])v.special_function_code_bit, 4, "Specl functn cde #", 1);
   ra_add_array(&s, (int(*)[])v.special_priority_mode_bit, 4, "Special priort NBG", 3);
   ra_add_array(&s, (int(*)[])v.special_function_code_select, 4, "Specl func cod NBG", 1);
   ra_add_var(&s, &v.color_calculation_ratio_mode, "Color cal rati mode", 1);
   ra_add_var(&s, &v.color_calculation_mode_bit, "Color calcultn mode", 1);
   ra_add_array(&s, (int(*)[])v.nbg_priority, 4, "Priority       NBG", 7);

   int presets[][26] =
   {
      {
         //special color calc mode
         0, 0, 0, 0,
         //nbg color calc enable
         0, 0, 0, 0,
         //special function code bit
         1, 0, 0, 0,
         //special priority mode bit
         0, 2, 0, 0,
         //special function code select
         0, 0, 0, 0,
         //color calculation ratio mode
         0,
         //color calculation mode bit
         0,
         //nbg priority
         6, 6, 7, 7
      },
      {
         //special color calc mode
         0, 0, 0, 0,
         //nbg color calc enable
         0, 0, 0, 0,
         //special function code bit
         0, 0, 1, 0,
         //special priority mode bit
         0, 0, 0, 2,
         //special function code select
         0, 0, 0, 0,
         //color calculation ratio mode
         0,
         //color calculation mode bit
         0,
         //nbg priority
         5, 5, 6, 6
      },
      {
         //special color calc mode
         0, 0, 0, 0,
         //nbg color calc enable
         0, 0, 0, 0,
         //special function code bit
         1, 0, 0, 0,
         //special priority mode bit
         0, 2, 0, 0,
         //special function code select
         0, 0, 0, 0,
         //color calculation ratio mode
         0,
         //color calculation mode bit
         0,
         //nbg priority
         6, 7, 5, 5
      },
      {
         //special color calc mode
         0, 0, 0, 0,
         //nbg color calc enable
         0, 0, 0, 0,
         //special function code bit
         1, 0, 1, 0,
         //special priority mode bit
         0, 2, 2, 2,
         //special function code select
         0, 0, 0, 0,
         //color calculation ratio mode
         0,
         //color calculation mode bit
         0,
         //nbg priority
         1, 0, 0, 0
      }
   };

   //set up instructions
   char * instructions[] = {
      "A:     Do preset  ",
      "Up:    Move up    ",
      "Down:  Move down  ",
      "Right: Decrease   ",
      "Left:  Increase   ",
      "Start: Exit       "
   };

   int i;
   for (i = 0; i < 6; i++)
   {
      write_str_as_pattern_name_data(0, 17 + i, instructions[i], 3, 0x000000, vdp2_tile_address[0]);
   }

   ra_do_preset(&s, presets[preset]);

   //display the dot data bits
   volatile u32 *vram_ptr = (volatile u32 *)(VDP2_RAM + vdp2_tile_address[0]);
   int pos = 8;
   int unchanged_data = vram_ptr[pos];

   vram_ptr = (volatile u32 *)(VDP2_RAM + vdp2_tile_address[1]);
   int changed_data = vram_ptr[pos];
   char output[64] = { 0 };
   sprintf(output, "0x%08x", unchanged_data);
   write_str_as_pattern_name_data(0, 24, output, 3, 0x000000, vdp2_tile_address[0]);
   sprintf(output, "0x%08x", changed_data);
   write_str_as_pattern_name_data(0, 25, output, 3, 0x000000, vdp2_tile_address[0]);

#ifdef BUILD_AUTOMATED_TESTING
   for (i = 0; i < 4; i++)
   {
      ra_do_preset(&s, presets[i]);
      ra_update_vars(&s);
      ra_do_menu(&s, 17, 0, 0);
      vdp2_special_priority_write_regs(v, nbg_ratio);
      auto_test_take_screenshot(2);
   }
#else

   for (;;)
   {
      vdp_vsync();

      ra_update_vars(&s);

      ra_do_menu(&s, 17,0,0);

      vdp2_special_priority_write_regs(v,nbg_ratio);

      char ratio_status[64] = { 0 };

      write_str_as_pattern_name_data(0, 13, "Ratios", 3, 0x000000, vdp2_tile_address[0]);

      sprintf(ratio_status, "NBG0=%02x NBG1=%02x", nbg_ratio[0], nbg_ratio[1]);
      write_str_as_pattern_name_data(0, 14, ratio_status, 3, 0x000000, vdp2_tile_address[0]);

      sprintf(ratio_status, "NBG2=%02x NBG3=%02x", nbg_ratio[2], nbg_ratio[3]);
      write_str_as_pattern_name_data(0, 15, ratio_status, 3, 0x000000, vdp2_tile_address[0]);

      if (per[0].but_push_once & PAD_A)
      {
         preset++;

         if (preset > 4)
            preset = 0;

         ra_do_preset(&s, presets[preset]);

      }

      if (per[0].but_push_once & PAD_START)
         break;

      if (per[0].but_push_once & PAD_X)
         reset_system();
   }

#endif

   vdp2_basic_tile_scroll_deinit();
}

//////////////////////////////////////////////////////////////////////////////

void vdp2_set_line_window_tables(u32 * line_window_table_address)
{
   u16 ellipse[] = {
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 290, 348, 268, 370, 253, 385,
      242, 396, 231, 407, 222, 416, 214, 424, 207, 431, 200, 438, 193, 445, 187, 451, 181, 457, 175, 463,
      170, 468, 165, 473, 160, 478, 156, 482, 151, 487, 147, 491, 143, 495, 139, 499, 135, 503, 131, 507,
      128, 510, 124, 514, 121, 517, 117, 521, 114, 524, 111, 527, 108, 530, 105, 533, 102, 536, 99, 539,
      97, 541, 94, 544, 92, 546, 89, 549, 87, 551, 84, 554, 82, 556, 80, 558, 77, 561, 75, 563,
      73, 565, 71, 567, 69, 569, 67, 571, 65, 573, 63, 575, 61, 577, 60, 578, 58, 580, 56, 582,
      55, 583, 53, 585, 51, 587, 50, 588, 48, 590, 47, 591, 46, 592, 44, 594, 43, 595, 42, 596,
      40, 598, 39, 599, 38, 600, 37, 601, 36, 602, 35, 603, 34, 604, 33, 605, 32, 606, 31, 607,
      30, 608, 29, 609, 28, 610, 27, 611, 26, 612, 26, 612, 25, 613, 24, 614, 24, 614, 23, 615,
      22, 616, 22, 616, 21, 617, 21, 617, 20, 618, 20, 618, 19, 619, 19, 619, 18, 620, 18, 620,
      18, 620, 17, 621, 17, 621, 17, 621, 17, 621, 17, 621, 16, 622, 16, 622, 16, 622, 16, 622,
      16, 622, 16, 622, 16, 622, 16, 622, 16, 622, 16, 622, 16, 622, 17, 621, 17, 621, 17, 621,
      17, 621, 17, 621, 18, 620, 18, 620, 18, 620, 19, 619, 19, 619, 20, 618, 20, 618, 21, 617,
      21, 617, 22, 616, 22, 616, 23, 615, 24, 614, 24, 614, 25, 613, 26, 612, 26, 612, 27, 611,
      28, 610, 29, 609, 30, 608, 31, 607, 32, 606, 33, 605, 34, 604, 35, 603, 36, 602, 37, 601,
      38, 600, 39, 599, 40, 598, 42, 596, 43, 595, 44, 594, 46, 592, 47, 591, 48, 590, 50, 588,
      51, 587, 53, 585, 55, 583, 56, 582, 58, 580, 60, 578, 61, 577, 63, 575, 65, 573, 67, 571,
      69, 569, 71, 567, 73, 565, 75, 563, 77, 561, 80, 558, 82, 556, 84, 554, 87, 551, 89, 549,
      92, 546, 94, 544, 97, 541, 99, 539, 102, 536, 105, 533, 108, 530, 111, 527, 114, 524, 117, 521,
      121, 517, 124, 514, 128, 510, 131, 507, 135, 503, 139, 499, 143, 495, 147, 491, 151, 487, 156, 482,
      160, 478, 165, 473, 170, 468, 175, 463, 181, 457, 187, 451, 193, 445, 200, 438, 207, 431, 214, 424,
      222, 416, 231, 407, 242, 396, 253, 385, 268, 370, 290, 348, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   };

   u16 ellipse2[] = {
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 290, 348, 269, 369, 254, 384, 243, 395, 233, 405,
      224, 414, 216, 422, 208, 430, 201, 437, 195, 443, 189, 449, 183, 455, 178, 460, 173, 465, 168, 470,
      163, 475, 159, 479, 154, 484, 150, 488, 146, 492, 142, 496, 139, 499, 135, 503, 131, 507, 128, 510,
      125, 513, 122, 516, 118, 520, 115, 523, 113, 525, 110, 528, 107, 531, 104, 534, 102, 536, 99, 539,
      97, 541, 94, 544, 92, 546, 90, 548, 87, 551, 85, 553, 83, 555, 81, 557, 79, 559, 77, 561,
      75, 563, 74, 564, 72, 566, 70, 568, 68, 570, 67, 571, 65, 573, 64, 574, 62, 576, 61, 577,
      59, 579, 58, 580, 57, 581, 55, 583, 54, 584, 53, 585, 52, 586, 51, 587, 49, 589, 48, 590,
      47, 591, 46, 592, 45, 593, 44, 594, 44, 594, 43, 595, 42, 596, 41, 597, 40, 598, 40, 598,
      39, 599, 38, 600, 38, 600, 37, 601, 37, 601, 36, 602, 36, 602, 35, 603, 35, 603, 34, 604,
      34, 604, 34, 604, 33, 605, 33, 605, 33, 605, 33, 605, 32, 606, 32, 606, 32, 606, 32, 606,
      32, 606, 32, 606, 32, 606, 32, 606, 32, 606, 32, 606, 32, 606, 33, 605, 33, 605, 33, 605,
      33, 605, 34, 604, 34, 604, 34, 604, 35, 603, 35, 603, 36, 602, 36, 602, 37, 601, 37, 601,
      38, 600, 38, 600, 39, 599, 40, 598, 40, 598, 41, 597, 42, 596, 43, 595, 44, 594, 44, 594,
      45, 593, 46, 592, 47, 591, 48, 590, 49, 589, 51, 587, 52, 586, 53, 585, 54, 584, 55, 583,
      57, 581, 58, 580, 59, 579, 61, 577, 62, 576, 64, 574, 65, 573, 67, 571, 68, 570, 70, 568,
      72, 566, 74, 564, 75, 563, 77, 561, 79, 559, 81, 557, 83, 555, 85, 553, 87, 551, 90, 548,
      92, 546, 94, 544, 97, 541, 99, 539, 102, 536, 104, 534, 107, 531, 110, 528, 113, 525, 115, 523,
      118, 520, 122, 516, 125, 513, 128, 510, 131, 507, 135, 503, 139, 499, 142, 496, 146, 492, 150, 488,
      154, 484, 159, 479, 163, 475, 168, 470, 173, 465, 178, 460, 183, 455, 189, 449, 195, 443, 201, 437,
      208, 430, 216, 422, 224, 414, 233, 405, 243, 395, 254, 384, 269, 369, 290, 348, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   };

   volatile u16 *line_window_table_table_ptr = (volatile u16 *)(VDP2_RAM + line_window_table_address[0]);
   volatile u16 *line_window_table_table_ptr2 = (volatile u16 *)(VDP2_RAM + line_window_table_address[1]);

   int i;
   for (i = 0; i < 224 * 2; i++)
   {
      line_window_table_table_ptr[i] = ellipse[i];
      line_window_table_table_ptr2[i] = ellipse2[i];
   }
}

//////////////////////////////////////////////////////////////////////////////


//vars for reg adjuster
struct LineWindowRegs {
   int line_window_enable[2];
   struct {
      int window_logic;
      int window_enable[2];
      int window_area[2];
   }nbg[4];
};

void vdp2_line_window_write_regs(struct LineWindowRegs v, u32 *line_window_table_address)
{
   *(volatile u32 *)0x25F800D8 = (v.line_window_enable[0] << 31) | (line_window_table_address[0] / 2);
   *(volatile u32 *)0x25F800DC = (v.line_window_enable[1] << 31) | (line_window_table_address[1] / 2);

   VDP2_REG_WCTLA = (v.nbg[0].window_enable[0] << 1) | (v.nbg[1].window_enable[0] << 9) |
      (v.nbg[0].window_logic << 7) | (v.nbg[1].window_logic << 15) |
      (v.nbg[0].window_area[0] << 0) | (v.nbg[1].window_area[0] << 8) |
      (v.nbg[0].window_enable[1] << 3) | (v.nbg[1].window_enable[1] << 11) |
      (v.nbg[0].window_area[1] << 2) | (v.nbg[1].window_area[1] << 10);

   VDP2_REG_WCTLB = (v.nbg[2].window_enable[0] << 1) | (v.nbg[3].window_enable[0] << 9) |
      (v.nbg[2].window_logic << 7) | (v.nbg[3].window_logic << 15) |
      (v.nbg[2].window_area[0] << 0) | (v.nbg[3].window_area[0] << 8) |
      (v.nbg[2].window_enable[1] << 3) | (v.nbg[3].window_enable[1] << 11) |
      (v.nbg[2].window_area[1] << 2) | (v.nbg[3].window_area[1] << 10);

   VDP2_REG_WPSX0 = (1 * 8) * 2;
   VDP2_REG_WPSY0 = 1 * 8;
   VDP2_REG_WPEX0 = ((39 * 8) * 2) - 2;
   VDP2_REG_WPEY0 = (27 * 8) - 1;

   VDP2_REG_WPSX1 = (2 * 8) * 2;
   VDP2_REG_WPSY1 = 2 * 8;
   VDP2_REG_WPEX1 = ((38 * 8) * 2) - 2;
   VDP2_REG_WPEY1 = (26 * 8) - 1;
}

//////////////////////////////////////////////////////////////////////////////

void vdp2_line_window_test()
{
   const u32 vdp2_tile_address = 0x40000;

   auto_test_sub_test_start("Line window test");

   vdp2_basic_tile_scroll_setup(vdp2_tile_address);

   int i;
   for (i = 0; i < 32; i += 4)
   {
      write_str_as_pattern_name_data_special(0, 0 + i, "\n\n\n\nNBG0                        NBG0\n\n\n\n", 3, 0, vdp2_tile_address, 0, 0);
      write_str_as_pattern_name_data_special(0, 1 + i, "\n\n\n\nNBG1                        NBG1\n\n\n\n", 4, 0x004000, vdp2_tile_address, 0, 0);
      write_str_as_pattern_name_data_special(0, 2 + i, "\n\n\n\nNBG2                        NBG2\n\n\n\n", 5, 0x008000, vdp2_tile_address, 0, 0);
      write_str_as_pattern_name_data_special(0, 3 + i, "\n\n\n\nNBG3                        NBG3\n\n\n\n", 6, 0x00C000, vdp2_tile_address, 0, 0);
   }

   write_str_as_pattern_name_data_special(0, 0,  "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n", 3, 0x000000, vdp2_tile_address, 0, 0);
   write_str_as_pattern_name_data_special(0, 1, "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n", 4, 0x004000, vdp2_tile_address, 0, 0);
   write_str_as_pattern_name_data_special(0, 2, "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n", 5, 0x008000, vdp2_tile_address, 0, 0);

   write_str_as_pattern_name_data_special(0, 25, "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n", 4, 0x004000, vdp2_tile_address, 0, 0);
   write_str_as_pattern_name_data_special(0, 26, "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n", 5, 0x008000, vdp2_tile_address, 0, 0);
   write_str_as_pattern_name_data_special(0, 27, "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n", 6, 0x00C000, vdp2_tile_address, 0, 0);

   struct LineWindowRegs v = { { 0 } };

   struct RegAdjusterState s = { 0 };

   ra_add_array(&s, (int(*)[])v.line_window_enable, 2, "Line window enab #", 1);

   for (i = 0; i < 4; i++)
   {
      char str[64] = { 0 };
      sprintf(str, "NBG%d window logic  ", i);
      ra_add_var(&s, &v.nbg[i].window_logic,              str, 1);
      sprintf(str, "NBG%d window enabl ", i);
      ra_add_array(&s, (int(*)[])v.nbg[i].window_enable, 2, str, 1);
      sprintf(str, "NBG%d window area  ", i);
      ra_add_array(&s, (int(*)[])v.nbg[i].window_area, 2, str, 1);
   }

   int presets[][22] =
   {
      //preset 0
      {
         //line window enable
         1, 1,
         //nbg0
         0, 0, 0, 0, 0,
         //nbg1
         0, 0, 1, 1, 1,
         //nbg2
         0, 1, 1, 1, 0,
         //nbg3
         1, 1, 1, 0, 1
      },
      //preset 1
      {
         //line window enable
         0,0,
         //nbg0
         0, 0, 0, 0, 0,
         //nbg1
         0, 0, 1, 1, 1,
         //nbg2
         0, 1, 1, 1, 0,
         //nbg3
         1, 1, 1, 0, 1
      },
      //preset 1
      {
         //line window enable
         0, 0,
         //nbg0
         0, 0, 0, 0, 0,
         //nbg1
         0, 0, 0, 0, 0,
         //nbg2
         0, 0, 0, 0, 0,
         //nbg3
         0, 0, 0, 0, 0
      }
   };

   int preset = 0;
   int lsmd = 0;

   ra_do_preset(&s, presets[preset]);

   u32 line_window_table_address[2] = { 0x50000, 0x52000};

   vdp2_set_line_window_tables(line_window_table_address);

#ifdef BUILD_AUTOMATED_TESTING
   for (i = 0; i < 3; i++)
   {
      ra_do_preset(&s, presets[i]);
      ra_update_vars(&s);
      ra_do_menu(&s, 8, 3, 0);
      vdp2_line_window_write_regs(v, line_window_table_address);
      auto_test_take_screenshot(3);
   }
#else

   int hreso = 0;

   for (;;)
   {
      vdp_vsync();

      VDP2_REG_TVMD = (1 << 15) | (lsmd << 6) | hreso;

      vdp2_line_window_write_regs(v, line_window_table_address);

      ra_update_vars(&s);

      ra_do_menu(&s, 8,3,0);

      if (per[0].but_push_once & PAD_A)
      {
         preset++;

         if (preset > 2)
            preset = 0;

         ra_do_preset(&s, presets[preset]);
      }

      if (per[0].but_push_once & PAD_START)
      {
         break;
      }

      if (per[0].but_push_once & PAD_X)
      {
         if (hreso == 2)
            hreso = 0;
         else
            hreso = 2;
      }

      if (per[0].but_push_once & PAD_Y)
      {
         reset_system();
      }

      if (per[0].but_push_once & PAD_DOWN)
      {
         if (lsmd == 3)
            lsmd = 0;
         else
            lsmd = 3;
      }
   }

#endif

   vdp2_basic_tile_scroll_deinit();
}

//////////////////////////////////////////////////////////////////////////////

u8 sine_tbl[] = {
   0x80, 0x83, 0x86, 0x89, 0x8c, 0x8f, 0x92, 0x95,
   0x98, 0x9b, 0x9e, 0xa2, 0xa5, 0xa7, 0xaa, 0xad,
   0xb0, 0xb3, 0xb6, 0xb9, 0xbc, 0xbe, 0xc1, 0xc4,
   0xc6, 0xc9, 0xcb, 0xce, 0xd0, 0xd3, 0xd5, 0xd7,
   0xda, 0xdc, 0xde, 0xe0, 0xe2, 0xe4, 0xe6, 0xe8,
   0xea, 0xeb, 0xed, 0xee, 0xf0, 0xf1, 0xf3, 0xf4,
   0xf5, 0xf6, 0xf8, 0xf9, 0xfa, 0xfa, 0xfb, 0xfc,
   0xfd, 0xfd, 0xfe, 0xfe, 0xfe, 0xff, 0xff, 0xff,
   0xff, 0xff, 0xff, 0xff, 0xfe, 0xfe, 0xfe, 0xfd,
   0xfd, 0xfc, 0xfb, 0xfa, 0xfa, 0xf9, 0xf8, 0xf6,
   0xf5, 0xf4, 0xf3, 0xf1, 0xf0, 0xee, 0xed, 0xeb,
   0xea, 0xe8, 0xe6, 0xe4, 0xe2, 0xe0, 0xde, 0xdc,
   0xda, 0xd7, 0xd5, 0xd3, 0xd0, 0xce, 0xcb, 0xc9,
   0xc6, 0xc4, 0xc1, 0xbe, 0xbc, 0xb9, 0xb6, 0xb3,
   0xb0, 0xad, 0xaa, 0xa7, 0xa5, 0xa2, 0x9e, 0x9b,
   0x98, 0x95, 0x92, 0x8f, 0x8c, 0x89, 0x86, 0x83,
   0x80, 0x7c, 0x79, 0x76, 0x73, 0x70, 0x6d, 0x6a,
   0x67, 0x64, 0x61, 0x5d, 0x5a, 0x58, 0x55, 0x52,
   0x4f, 0x4c, 0x49, 0x46, 0x43, 0x41, 0x3e, 0x3b,
   0x39, 0x36, 0x34, 0x31, 0x2f, 0x2c, 0x2a, 0x28,
   0x25, 0x23, 0x21, 0x1f, 0x1d, 0x1b, 0x19, 0x17,
   0x15, 0x14, 0x12, 0x11, 0xf, 0xe, 0xc, 0xb,
   0xa, 0x9, 0x7, 0x6, 0x5, 0x5, 0x4, 0x3,
   0x2, 0x2, 0x1, 0x1, 0x1, 0x0, 0x0, 0x0,
   0x0, 0x0, 0x0, 0x0, 0x1, 0x1, 0x1, 0x2,
   0x2, 0x3, 0x4, 0x5, 0x5, 0x6, 0x7, 0x9,
   0xa, 0xb, 0xc, 0xe, 0xf, 0x11, 0x12, 0x14,
   0x15, 0x17, 0x19, 0x1b, 0x1d, 0x1f, 0x21, 0x23,
   0x25, 0x28, 0x2a, 0x2c, 0x2f, 0x31, 0x34, 0x36,
   0x39, 0x3b, 0x3e, 0x41, 0x43, 0x46, 0x49, 0x4c,
   0x4f, 0x52, 0x55, 0x58, 0x5a, 0x5d, 0x61, 0x64,
   0x67, 0x6a, 0x6d, 0x70, 0x73, 0x76, 0x79, 0x7c
};

void write_line_scroll_table(u32 address, int counter, int h_scroll, int v_scroll, int h_coord)
{
   int i = 0;

   if (!h_scroll && !v_scroll && !h_coord)
      return;

   volatile u32 *ptr = (volatile u32 *)(VDP2_RAM + address);

   for (;;)
   {
      if (h_scroll)
      {
         ptr[i] = sine_tbl[(counter + i) & 0xff] << 15;
         i++;
      }
      if (v_scroll)
      {
         ptr[i] = sine_tbl[(counter + i) & 0xff] << 14;
         i++;
      }
      if (h_coord)
      {
         ptr[i] = (sine_tbl[(counter + i) & 0x7f]) << 8;
         i++;
      }
      if (i > 224*3)
         break;
   }
}

//////////////////////////////////////////////////////////////////////////////

void write_vertical_cell_scroll_table(u32 address, int counter)
{
   volatile u32 *ptr = (volatile u32 *)(VDP2_RAM + address);

   int i;
   for (i = 0; i < 224; i++)
   {
      ptr[i] = sine_tbl[(counter + i) & 0xff] << 14;
   }
}

//////////////////////////////////////////////////////////////////////////////

   //vars for reg adjuster
   struct LineScrollRegs {
      int line_scroll_interval;
      int line_zoom_enable;
      int vertical_line_scroll_enable;
      int horizontal_line_scroll_enable;
      int vertical_cell_scroll_enable;
   };

   void vdp2_line_scroll_write_regs(struct LineScrollRegs v, int counter, u32 line_scroll_table_address, u32 vertical_cell_scroll_table_address)
   {
      VDP2_REG_SCRCTL = v.vertical_cell_scroll_enable |
         (v.horizontal_line_scroll_enable << 1) |
         (v.vertical_line_scroll_enable << 2) |
         (v.line_zoom_enable << 3) |
         (v.line_scroll_interval << 4);

      write_line_scroll_table(line_scroll_table_address, counter,
         v.horizontal_line_scroll_enable,
         v.vertical_line_scroll_enable,
         v.line_zoom_enable);

      write_vertical_cell_scroll_table(vertical_cell_scroll_table_address, counter);
   }

void vdp2_line_scroll_test()
{
   const u32 vdp2_tile_address = 0x40000;
   const u32 line_scroll_table_address =  0x42000;
   const u32 vertical_cell_scroll_table_address =  0x43000;

   auto_test_sub_test_start("Line scroll test");

   vdp2_basic_tile_scroll_setup(vdp2_tile_address);

   VDP2_REG_CYCA0L = 0x01FF;
   VDP2_REG_CYCA0U = 0xFFFF;
   VDP2_REG_CYCB0L = 0xC4C5;
   VDP2_REG_CYCB0U = 0xCCCC;

   int i;
   for (i = 0; i < 32; i += 2)
   {
      write_str_as_pattern_name_data_special(0, 0 + i, "\n\n\n\nNBG0\n\n\n\n\n\n\n\n", 4, 0x000000, vdp2_tile_address, 0, 0);
   }

   VDP2_REG_PRINA = 1 | 7 << 8;

   struct LineScrollRegs v = { 0 };

   struct RegAdjusterState s = { 0 };

   ra_add_var(&s, &v.line_scroll_interval,           "Line scrll intrvl ", 3);
   ra_add_var(&s, &v.line_zoom_enable,  "Line zoom enable  ", 1);
   ra_add_var(&s, &v.vertical_line_scroll_enable,  "Vert lin scrl enab", 1);
   ra_add_var(&s, &v.horizontal_line_scroll_enable,  "Horiz ln scrl enab", 1);
   ra_add_var(&s, &v.vertical_cell_scroll_enable,  "Vert cll scrl enab", 1);

   *(volatile u32 *)0x25F800A0 =  (line_scroll_table_address / 2);
   *(volatile u32 *)0x25F8009C = (vertical_cell_scroll_table_address / 2);

   int presets[][5] =
   {
      { 0, 0, 0, 1, 0 },
      { 0, 0, 0, 0, 1 },
      { 0, 1, 0, 0, 0 },
      { 3, 0, 1, 0, 0 },
      { 3, 0, 0, 1, 1 },
      { 0, 0, 1, 0, 1 },
      { 1, 0, 1, 0, 1 },
      { 3, 1, 0, 1, 1 },
      { 3, 1, 0, 1, 0 }
   };

   int preset = 0;

   int counter = 0;

   ra_do_preset(&s, presets[preset]);

#ifdef BUILD_AUTOMATED_TESTING
   for (i = 0; i < 9; i++)
   {
      ra_do_preset(&s, presets[i]);
      ra_update_vars(&s);
      ra_do_menu(&s, 17, 0, 0x004000);
      vdp2_line_scroll_write_regs(v, counter, line_scroll_table_address, vertical_cell_scroll_table_address);
      auto_test_take_screenshot(3);
   }
#else

   int hreso = 0;
   int lsmd = 0;

   for (;;)
   {
      vdp_vsync();

      VDP2_REG_TVMD = (1 << 15) | (lsmd << 6) | hreso;

      counter++;

      vdp2_line_scroll_write_regs(v, counter, line_scroll_table_address, vertical_cell_scroll_table_address);

      ra_update_vars(&s);

      ra_do_menu(&s, 17, 0, 0x004000);

      if (per[0].but_push_once & PAD_A)
      {
         preset++;

         if (preset > 8)
            preset = 0;

         ra_do_preset(&s, presets[preset]);
      }

      if (per[0].but_push_once & PAD_START)
      {
         break;
      }

      if (per[0].but_push_once & PAD_X)
      {
         if (hreso == 2)
            hreso = 0;
         else
            hreso = 2;
      }

      if (per[0].but_push_once & PAD_Y)
      {
         reset_system();
      }

      if (per[0].but_push_once & PAD_C)
      {
         if (lsmd == 3)
            lsmd = 0;
         else
            lsmd = 3;
      }
   }
#endif

   vdp2_basic_tile_scroll_deinit();
}

//////////////////////////////////////////////////////////////////////////////

void vdp2_nbg0_test ()
{
   screen_settings_struct settings;

   // Draw a box on our default screen
   draw_box(120, 180, 80, 40, 15);

   // Setup NBG0 for drawing
   settings.is_bitmap = TRUE;
   settings.bitmap_size = BG_BITMAP512x256;
   settings.transparent_bit = 0;
   settings.color = BG_256COLOR;
   settings.special_priority = 0;
   settings.special_color_calc = 0;
   settings.extra_palette_num = 0;
//   settings.map_offset = 0;
//   settings.parameteraddr = 0x25E60000;
   vdp_nbg0_init(&settings);

   // Draw some stuff on the screen

   working_query("Is the above graphics displayed?");

   // Disable NBG0
   vdp_nbg0_deinit();
}

//////////////////////////////////////////////////////////////////////////////

void vdp2_nbg1_test ()
{
}

//////////////////////////////////////////////////////////////////////////////

void vdp2_nbg2_test ()
{
}

//////////////////////////////////////////////////////////////////////////////

void vdp2_nbg3_test ()
{
}

//////////////////////////////////////////////////////////////////////////////

void vdp2_rbg0_test ()
{
   // Draw a box on our default screen
   draw_box(120, 180, 80, 40, 15);

   // Draw some graphics on the RBG0 layer

   working_query("Is the above graphics displayed?");
}

//////////////////////////////////////////////////////////////////////////////

void vdp2_rbg1_test ()
{
}

//////////////////////////////////////////////////////////////////////////////

void vdp2_resolution_test ()
{
/*
   vdp_printf(&test_disp_font, 0 * 8, 2 * 8, 0xF, "vidmode = %02X", vidmode);

   // Display Main Menu
   for(;;)
   {
      vdp_vsync();

      if (per[0].but_push_once & PAD_A)
      {
         if ((vidmode & 0x7) == 7)
            vidmode &= 0xF0;
         else
            vidmode++;
         vdp_init(vidmode);
         vdp_rbg0_init(&testdispsettings);
         vdp_set_default_palette();
         vdp_set_font(SCREEN_RBG0, &test_disp_font, 1);
         vdp_disp_on();
         vdp_printf(&test_disp_font, 0 * 8, 2 * 8, 0xF, "vidmode =   ", vidmode);
         vdp_printf(&test_disp_font, 0 * 8, 2 * 8, 0xF, "vidmode = %02X", vidmode);
      }
      else if (per[0].but_push_once & PAD_B)
      {
         if ((vidmode & 0x30) == 0x30)
            vidmode &= 0xCF;
         else
            vidmode += 0x10;
         vdp_init(vidmode);
         vdp_rbg0_init(&testdispsettings);
         vdp_set_default_palette();
         vdp_set_font(SCREEN_RBG0, &test_disp_font, 1);
         vdp_disp_on();
         vdp_printf(&test_disp_font, 0 * 8, 2 * 8, 0xF, "vidmode =   ", vidmode);
         vdp_printf(&test_disp_font, 0 * 8, 2 * 8, 0xF, "vidmode = %02X", vidmode);
      }
      else if (per[0].but_push_once & PAD_C)
      {
         if ((vidmode & 0xC0) == 0xC0)
            vidmode &= 0x3F;
         else
            vidmode += 0x40;
         vdp_init(vidmode);
         vdp_rbg0_init(&testdispsettings);
         vdp_set_default_palette();
         vdp_set_font(SCREEN_RBG0, &test_disp_font, 1);
         vdp_disp_on();
         vdp_printf(&test_disp_font, 0 * 8, 2 * 8, 0xF, "vidmode =   ", vidmode);
         vdp_printf(&test_disp_font, 0 * 8, 2 * 8, 0xF, "vidmode = %02X", vidmode);
      }
   }
*/
}

//////////////////////////////////////////////////////////////////////////////

void vdp2_window_test ()
{
   screen_settings_struct settings;
   int dir=-1;
   int counter=320-1, counter2=224-1;
   int i;
   int nbg0_wnd;
   int nbg1_wnd;

   // Draw a box on our default screen
//   DrawBox(120, 180, 80, 40, 15);

   // Setup NBG0 for drawing
   settings.is_bitmap = TRUE;
   settings.bitmap_size = BG_BITMAP512x256;
   settings.transparent_bit = 0;
   settings.color = BG_256COLOR;
   settings.special_priority = 0;
   settings.special_color_calc = 0;
   settings.extra_palette_num = 0;
   settings.map_offset = (0x20000 >> 17);
//   settings.parameteraddr = 0x25E60000;
   vdp_nbg0_init(&settings);

   // Setup NBG1 for drawing
   settings.is_bitmap = TRUE;
   settings.bitmap_size = BG_BITMAP512x256;
   settings.transparent_bit = 0;
   settings.color = BG_256COLOR;
   settings.special_priority = 0;
   settings.special_color_calc = 0;
   settings.extra_palette_num = 0;
   settings.map_offset = (0x40000 >> 17);
//   settings.parameteraddr = 0x25E60000;
   vdp_nbg1_init(&settings);

   // Draw some stuff on the screen

   vdp_set_font(SCREEN_NBG0, &test_disp_font, 1);
   test_disp_font.out = (u8 *)0x25E20000;
   for (i = 5; i < 24; i+=2)
      vdp_printf(&test_disp_font, 0 * 8, i * 8, 0xB, "NBG0 NBG0 NBG0 NBG0 NBG0 NBG0 NBG0");
   vdp_set_font(SCREEN_NBG1, &test_disp_font, 1);
   test_disp_font.out = (u8 *)0x25E40000;
   for (i = 6; i < 24; i+=2)
      vdp_printf(&test_disp_font, 0 * 8, i * 8, 0xC, "NBG1 NBG1 NBG1 NBG1 NBG1 NBG1 NBG1");
   vdp_set_font(SCREEN_RBG0, &test_disp_font, 0);
   test_disp_font.out = (u8 *)0x25E00000;

   vdp_set_priority(SCREEN_NBG0, 2);
   vdp_set_priority(SCREEN_NBG1, 3);

   VDP2_REG_WPSX0 = 0;
   VDP2_REG_WPSY0 = 0;
   VDP2_REG_WPEX0 = counter << 1;
   VDP2_REG_WPEY0 = counter2;
   VDP2_REG_WPSX1 = ((320 - 40) / 2) << 1;
   VDP2_REG_WPSY1 = (224 - 40) / 2;
   VDP2_REG_WPEX1 = ((320 + 40) / 2) << 1;
   VDP2_REG_WPEY1 = (224 + 40) / 2;
   nbg0_wnd = 0x83; // enable outside of window 0 for nbg0
   nbg1_wnd = 0x88; // enable inside of window 1 for nbg1
   VDP2_REG_WCTLA = (nbg1_wnd << 8) | nbg0_wnd;
   vdp_disp_on();

//   WorkingQuerry("Is the above graphics displayed?");
   for(;;)
   {
      vdp_vsync();

      if(dir > 0)
      {
         if (counter2 >= (224-1))
         {
            dir = -1;
            nbg0_wnd ^= 1;
         }
         else
         {
            counter2++;
            counter=counter2 * (320-1) / (224-1);
         }
      }
      else
      {
         if (counter2 <= 0)
         {
            dir = 1;
            nbg0_wnd ^= 1;
         }
         else
         {
            counter2--;
            counter=counter2 * (320-1) / (224-1);
         }
      }

      VDP2_REG_WPEX0 = counter << 1;
      VDP2_REG_WPEY0 = counter2;
      VDP2_REG_WCTLA = (nbg1_wnd << 8) | nbg0_wnd;

      vdp_printf(&test_disp_font, 0 * 8, 26 * 8, 0xC, "%03d %03d", counter, counter2);

      if (per[0].but_push_once & PAD_START || per[0].but_push_once & PAD_B)
         break;
   }

   // Disable NBG0/NBG1
   vdp_nbg0_deinit();
   vdp_nbg1_deinit();
   yabauseut_init();
}

//////////////////////////////////////////////////////////////////////////////

void draw_square_sprite(int x, int y, int size, int bank, int vdp1_tile_address, int offset, int msb)
{
   sprite_struct quad = { 0 };

   int top_right_x = x * 8;
   int top_right_y = y * 8;

   quad.x = top_right_x;
   quad.y = top_right_y;
   quad.x2 = top_right_x + size - 1;
   quad.y2 = top_right_y;
   quad.x3 = top_right_x + size - 1;
   quad.y3 = top_right_y + size - 1;
   quad.x4 = top_right_x;
   quad.y4 = top_right_y + size - 1;

   quad.addr = vdp1_tile_address + offset;
   quad.bank = bank << 4;
   quad.width = 8;
   quad.height = 8;
   quad.attr = (msb << 15);

   vdp_draw_distorted_sprite(&quad);
}

//////////////////////////////////////////////////////////////////////////////

struct Wctl {
   int logic;
   int w0_enable;
   int w1_enable;
   int sw_enable;
   int w0_area;
   int w1_area;
   int sw_area;
};

u8 make_wctl(struct Wctl bg)
{
   return
      (bg.w0_area << 0) |
      (bg.w0_enable << 1) |
      (bg.w1_area << 2)|
      (bg.w1_enable << 3) |
      (bg.sw_area << 4) |
      (bg.sw_enable << 5) |
      (bg.logic << 7);
}

void vdp2_sprite_window_test()
{
   const u32 vdp2_tile_address = 0x40000;
   vdp2_basic_tile_scroll_setup(vdp2_tile_address);

   const u32 vdp1_tile_address = 0x10000;
   load_font_8x8_to_vram_1bpp_to_4bpp(vdp1_tile_address, VDP1_RAM);

   VDP1_REG_PTMR = 0x02;//draw automatically with frame change

   vdp_start_draw_list();

   sprite_struct spr;
   spr.x = 0;
   spr.y = 0;
   vdp_local_coordinate(&spr);

   draw_square_sprite(2, 4, 8 * 12, 4, vdp1_tile_address, (2 * 32), 0);
   draw_square_sprite(2, 2, 8 * 12, 4, vdp1_tile_address, (2 * 32), 1);

   vdp_end_draw_list();

   volatile u16 * color_ram_ptr = (volatile u16 *)VDP2_CRAM;
   color_ram_ptr[0] = 0x3105;

   int i;
   for (i = 0; i < 32; i += 2)
   {
      write_str_as_pattern_name_data_special(0, 0 + i, "\n\n\n\nNBG2\n\n\n\n\n\n\n\n", 5, 0x008000, vdp2_tile_address, 0, 0);
      write_str_as_pattern_name_data_special(0, 1 + i, "\n\n\n\nNBG3\n\n\n\n\n\n\n\n", 6, 0x00C000, vdp2_tile_address, 0, 0);
   }

   //vars for reg adjuster
   struct {
      int sprite_window_enable;
      struct Wctl nbg[2];
      struct Wctl spr;
   }v = { 0 };

   struct RegAdjusterState s = { 0 };

   ra_add_var(&s, &v.sprite_window_enable, "Sprite window enabl", 1);

   for (i = 0; i < 2; i++)
   {
      char str[64] = { 0 };
      sprintf(str, "NBG%d spr win enabl ", i + 2);
      ra_add_var(&s, &v.nbg[i].sw_enable, str, 1);
      sprintf(str, "NBG%d spr win area  ", i + 2);
      ra_add_var(&s, &v.nbg[i].sw_area, str, 1);
      sprintf(str, "NBG%d transp logic  ", i + 2);
      ra_add_var(&s, &v.nbg[i].logic, str, 1);
      sprintf(str, "NBG%d w0 enable  ", i + 2);
      ra_add_var(&s, &v.nbg[i].w0_enable, str, 1);
      sprintf(str, "NBG%d w1 enable  ", i + 2);
      ra_add_var(&s, &v.nbg[i].w1_enable, str, 1);
      sprintf(str, "NBG%d w0 area  ", i + 2);
      ra_add_var(&s, &v.nbg[i].w0_area, str, 1);
      sprintf(str, "NBG%d w1 area  ", i + 2);
      ra_add_var(&s, &v.nbg[i].w1_area, str, 1);
   }

   ra_add_var(&s, &v.spr.logic, "sprite transp logic", 1);
   ra_add_var(&s, &v.spr.sw_enable, "spr use spr win", 1);
   ra_add_var(&s, &v.spr.sw_area, "spr sprite win area", 1);
   ra_add_var(&s, &v.spr.w1_enable, "sprite w1 enab", 1);
   ra_add_var(&s, &v.spr.w1_area, "sprite w1 area", 1);
   ra_add_var(&s, &v.spr.w0_enable, "sprite w0 enab", 1);
   ra_add_var(&s, &v.spr.w0_area, "sprite w0 area", 1);

   int presets[][22] =
   {
      //preset 0
      {
         //sprite window enable
         0,
         //nbg2
         0, 0, 0, 0, 0, 0, 0,
         //nbg3
         0, 0, 0, 0, 0, 0, 0,
         //sprite
         0, 0, 0, 0, 0, 0, 0
      },
      {
         //sprite window enable
         0,
         //nbg2
         0, 0, 0, 0, 0, 0, 0,
         //nbg3
         0, 0, 0, 0, 0, 0, 0,
         //sprite
         1, 0, 1, 0, 0, 0, 0
      }
   };

   int preset = 0;

   ra_do_preset(&s, presets[preset]);

   for (;;)
   {
      vdp_vsync();

      VDP2_REG_SPCTL = (v.sprite_window_enable << 4) | 7;

      VDP2_REG_WCTLB = (make_wctl(v.nbg[1]) << 8) | make_wctl(v.nbg[0]);

      VDP2_REG_WCTLC = make_wctl(v.spr) << 8;

      VDP2_REG_WPSX0 = (1*8)*2;
      VDP2_REG_WPSY0 = 1*8;
      VDP2_REG_WPEX0 = ((9 * 8) * 2)-1;
      VDP2_REG_WPEY0 = (8*9)-1;

      VDP2_REG_WPSX1 = (7 * 8) * 2;
      VDP2_REG_WPSY1 = 1*8;
      VDP2_REG_WPEX1 = ((14 * 8) * 2)-1;
      VDP2_REG_WPEY1 = (8*9)-1;

      ra_update_vars(&s);

      ra_do_menu(&s, 17, 0, 0);

      if (per[0].but_push_once & PAD_A)
      {
         preset++;

         if (preset > 1)
            preset = 0;

         ra_do_preset(&s, presets[preset]);
      }

      if (per[0].but_push_once & PAD_START)
      {
         reset_system();
      }
   }
}

//////////////////////////////////////////////////////////////////////////////

volatile int linecount_hlines_since_vblank_out = 0;
volatile int linecount_hlines_since_vblank_in = 0;
volatile int linecount_vblank_in_occurred = 0;

volatile int vblank_out_results[10] = { 0 };
volatile int vblank_out_results_pos = 0;
volatile int vblank_in_results[10] = { 0 };
volatile int vblank_in_results_pos = 0;

volatile int lines_between_vblank_out_and_vblank_in_results[10] = { 0 };
volatile int lines_between_vblank_out_and_vblank_in_results_pos = 0;

volatile int lines_between_vblank_in_and_vblank_out_results[10] = { 0 };
volatile int lines_between_vblank_in_and_vblank_out_results_pos = 0;

//////////////////////////////////////////////////////////////////////////////

void linecount_test_vblank_out_handler()
{
   vblank_out_results[vblank_out_results_pos++] = linecount_hlines_since_vblank_out;
   lines_between_vblank_in_and_vblank_out_results[lines_between_vblank_in_and_vblank_out_results_pos++] = linecount_hlines_since_vblank_in;
   linecount_hlines_since_vblank_out = 0;
}

//////////////////////////////////////////////////////////////////////////////

void linecount_test_vblank_in_handler()
{
   linecount_vblank_in_occurred = 1;
   vblank_in_results[vblank_in_results_pos++] = linecount_hlines_since_vblank_in;
   lines_between_vblank_out_and_vblank_in_results[lines_between_vblank_out_and_vblank_in_results_pos++] = linecount_hlines_since_vblank_out;
   linecount_hlines_since_vblank_in = 0;
}

//////////////////////////////////////////////////////////////////////////////

void linecount_test_hblank_in_handler()
{
   linecount_hlines_since_vblank_out++;
   linecount_hlines_since_vblank_in++;
}

//////////////////////////////////////////////////////////////////////////////

void linecount_test_set_interrupts()
{
   interrupt_set_level_mask(0xF);
   bios_change_scu_interrupt_mask(0xFFFFFFFF, MASK_VBLANKOUT | MASK_HBLANKIN | MASK_VBLANKIN);
   bios_set_scu_interrupt(0x40, linecount_test_vblank_in_handler);
   bios_set_scu_interrupt(0x41, linecount_test_vblank_out_handler);
   bios_set_scu_interrupt(0x42, linecount_test_hblank_in_handler);
   bios_change_scu_interrupt_mask(~(MASK_VBLANKOUT | MASK_HBLANKIN | MASK_VBLANKIN), 0);
   interrupt_set_level_mask(0x1);
}

//////////////////////////////////////////////////////////////////////////////

void linecount_wait()
{
   while (!linecount_vblank_in_occurred){}
   linecount_vblank_in_occurred = 0;
}

//////////////////////////////////////////////////////////////////////////////

void linecount_run_test(int * current_line)
{
   int i;

   vblank_out_results_pos = 0;
   vblank_in_results_pos = 0;
   lines_between_vblank_out_and_vblank_in_results_pos = 0;
   lines_between_vblank_in_and_vblank_out_results_pos = 0;

   disable_iapetus_handler();
   test_disp_font.transparent = 0;

   linecount_test_set_interrupts();

   int count = 0;

   for (;;)
   {
      linecount_wait();

      count++;

      if (count > 8)
         break;
   }

   //the counters take a couple of frames to get inititalized fully so we start from 2
   for (i = 2; i < 7; i++)
   {
      vdp_printf(&test_disp_font, 0 * 8, *current_line * 8, 15, "%04d %04d %04d %04d",
         vblank_out_results[i],
         vblank_in_results[i],
         lines_between_vblank_in_and_vblank_out_results[i],
         lines_between_vblank_out_and_vblank_in_results[i]);

      *current_line = *current_line + 1;
   }
}

//////////////////////////////////////////////////////////////////////////////

void linecount_test()
{
   int current_line = 0;

   //test 224 line mode
   vdp_printf(&test_disp_font, 0 * 8, current_line * 8, 15, "TVMD = 224 Lines");
   current_line++;
   VDP2_REG_TVMD = 0x8000 | (0 << 4);
   linecount_run_test(&current_line);

   //test 240 line mode
   vdp_printf(&test_disp_font, 0 * 8, current_line * 8, 15, "TVMD = 240 Lines");
   current_line++;
   VDP2_REG_TVMD = 0x8000 | (1 << 4);
   linecount_run_test(&current_line);

   VDP2_REG_TVMD = 0x8000 | (0 << 4);

   current_line++;
   vdp_printf(&test_disp_font, 0 * 8, current_line * 8, 15, "column 3: lines between vblank in/out");
   current_line++;
   vdp_printf(&test_disp_font, 0 * 8, current_line * 8, 15, "column 4: lines between vblank out/in");

   per_init();

   for (;;)
   {
      vdp_vsync();

      if (per[0].but_push_once & PAD_START)
      {
         reset_system();
      }
   }
}

//////////////////////////////////////////////////////////////////////////////

u32 coef[] = { 0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80008000,0x80001c20,0x0e100960,0x070805a0,0x04b00404,0x03840320,0x02d0028e,0x02580229,0x020201e0,0x01c201a7,0x0190017a,0x01680156,0x01470139,0x012c0120,0x0114010a,0x010100f8,0x00f000e8,0x00e100da,0x00d300cd,0x00c800c2,0x00bd00b8,0x00b400af,0x00ab00a7,0x00a300a0,0x00a0009c,0x00990096,0x00920090,0x008d008a,0x00870085,0x00820080,0x007e007c,0x007a0078,0x00760074,0x00720070,0x006e006d,0x006b0069,0x00680066,0x00650064,0x00620061,0x0060005e,0x005d005c,0x005b005a,0x00580057,0x00560055,0x00540053,0x00520051,0x00500050,0x004f004e,0x004d004c,0x004b004b,0x004a0049,0x00480048,0x00470046,0x00450045,0x00440043,0x00430042,0x00420041,0x00400040,0x003f003f,0x003e003e,0x003d003d,0x003c003c,0x003b003b,0x003a003a,0x00390039,0x00380038,0x00370037,0x00360036,0x00360035,0x00350034,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x000001b2,0x01ce01c3,0x01ba01b3,0x01b201b7,0x01bb01be,0x01c101c4,0x01c701c9,0x01cb01cd,0x01cf01ce,0x01cd01cb,0x01ca01c8,0x01c701c6,0x01c401c3,0x01c201c1,0x01c001bf,0x01be01bd,0x01bc01bb,0x01ba01ba,0x01b901b8,0x01b701b6,0x01b601b5,0x01b401b4,0x01b301b2,0x01b201b1,0x01b101b0,0x01b001b0,0x01b101b1,0x01b201b2,0x01b301b3 };

u32 table[] =
{
   0x0000,0x0000,//xst
   0x0000,0x0000,//yst
   0x0000,0x0000,//zst
   0x0000,0x0000,//dxst
   0x0001,0x0000,//dyst
   0x0001,0x0000,//dx
   0x0000,0x0000,//dy
   0x0002,0xe939,//a
   0x0000,0x06da,//b
   0x0000,0x4599,//c
   0xffff,0xba0f,//d
   0x0000,0x490c,//e
   0x0002,0xe5a0,//f
   0x00b0,//px
   0x0070,//py
   0x0100,//pz
   0x0000,
   0x00b0,//cx
   0x0070,//cy
   0x0100,//cz
   0x0000,
   0x065d,0xd9f8,//mx
   0x0a6f,0x1988,//my
   0x0002,0xec84,//kx
   0x0002,0xec84,//ky
   0xf000,0x0000,//kast (coef table addr)
   0x0001,0x0000,//dkast
   0xfef9,0x43c0,//dkax
   0x8000,0x8000,0x8000,0x8000,0x8000,0x8000,0x8000,0x8000,0x8000,0x8000,0x8000,0x8000,0x8000,0x8000,0x8000,0x8000
};

void init_rbg0(u32 map_offset, u32 param_offset, u32 ktaof, u32 coef_data_size, u32 deltakax)
{
   int i;

   volatile u32 * vram_ptr = (volatile u32 *)(0x25E00000);
   u32 param_addr = 0x25E00000 + (param_offset * 0x20000) + 0xE000;

   for (i = 0; i < 0x20000; i++)
      vram_ptr[i] = 0;

   // Setup a screen for us draw on
   test_disp_settings.is_bitmap = TRUE;
   test_disp_settings.bitmap_size = BG_BITMAP512x256;
   test_disp_settings.transparent_bit = 0;
   test_disp_settings.color = BG_256COLOR;
   test_disp_settings.special_priority = 0;
   test_disp_settings.special_color_calc = 0;
   test_disp_settings.extra_palette_num = 0;
   test_disp_settings.map_offset = map_offset;
   test_disp_settings.rotation_mode = 0;
   test_disp_settings.parameter_addr = param_addr;
   vdp_rbg0_init(&test_disp_settings);

   // Use the default palette
   vdp_set_default_palette();

   // Setup an 8x8 1BPP font
   test_disp_font.data = font_8x8;
   test_disp_font.width = 8;
   test_disp_font.height = 8;
   test_disp_font.bpp = 1;
   vdp_set_font(SCREEN_RBG0, &test_disp_font, 1);
   test_disp_font.out = (u8 *)(0x25E00000 + (map_offset * 0x20000));//vdp_set_font bug workaround

   vdp_rbg0_init(&test_disp_settings);
   vdp_set_default_palette();

   for (i = 0; i < 16; i++)
      vdp_printf(&test_disp_font, 0 * 8, i * 16, 15, "RBG0 RBG0 RBG0 RBG0 RBG0 RBG0 RBG0 RBG0 RBG0 RBG0 RBG0 RBG0");

   VDP2_REG_CYCB0L = 0xffff;
   VDP2_REG_CYCB0U = 0xffff;
   VDP2_REG_CYCB1L = 0xffff;
   VDP2_REG_CYCB1U = 0xffff;

   VDP2_REG_RAMCTL = 0x1300 | (3 << (map_offset * 2)) | (1 << (ktaof * 2));

   VDP2_REG_KTAOF = ktaof;
   VDP2_REG_KTCTL = 0x0003;

   VDP2_REG_RPRCTL = 0x0000;
   VDP2_REG_RPMD = 0x0000;
   volatile u16 * rot_table_ptr = (volatile u16 *)param_addr;

   for (i = 0; i < 64; i++)
   {
      rot_table_ptr[i] = table[i];
   }

   u32 addr = (ktaof * 0x10000 + deltakax) * coef_data_size;
   volatile u32 * coef_ptr = (volatile u32 *)(0x25E00000 | addr);

   //write coef
   for (i = 0; i < 224; i++)
   {
      coef_ptr[i] = coef[i];
   }
}

//////////////////////////////////////////////////////////////////////////////

void vdp1_print_char(int x, int y, int palette, u32 vdp1_tile_address, char c)
{
   sprite_struct quad = { 0 };

   quad.x = x;
   quad.y = y;
   quad.height = 8;
   quad.width = 8;
   quad.bank = (palette << 4);
   quad.addr = vdp1_tile_address + (c * 32);

   vdp_draw_normal_sprite(&quad);
}

//////////////////////////////////////////////////////////////////////////////

void vdp1_print_str(int x, int y, int palette, u32 vdp1_tile_address, char* str)
{
   int i;
   int len = strlen(str);

   for (i = 0; i < len; i++)
   {
      vdp1_print_char(x + (i * 8), y, palette, vdp1_tile_address, str[i]);
   }
}

//////////////////////////////////////////////////////////////////////////////

void rbg0_delta_kax_test()
{
   //vdp1 setup
   const u32 vdp1_tile_address = 0x10000;
   load_font_8x8_to_vram_1bpp_to_4bpp(vdp1_tile_address, VDP1_RAM);
   VDP1_REG_PTMR = 0x02;//draw automatically with frame change
   VDP2_REG_PRISA = 7 | (6 << 8);
   VDP2_REG_PRISB = 5 | (4 << 8);
   VDP2_REG_PRISC = 3 | (2 << 8);
   VDP2_REG_PRISD = 1 | (0 << 8);
   VDP2_REG_SPCTL = (0 << 12) | (0 << 8) | (0 << 5) | 7;

   u32 map_offset = 0;
   u32 param_offset = 0;
   u32 param_addr = 0x25E00000 + (param_offset * 0x20000) + 0xE000;
   u32 ktaof = 0;
   u32 coef_data_size = 2;
   u32 deltakax = 0xf000;

   init_rbg0(map_offset, param_offset, ktaof, coef_data_size, deltakax);

   int q = 0;
   volatile u32 * dkax = (volatile u32 *)(param_addr + 0x5c);
   char str[128] = { 0 };

   for (;;)
   {
      vdp_vsync();

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

      sprintf(str, "map offset %01X, param offset %01X, ktaof %01X", map_offset, param_offset, ktaof);

      vdp1_print_str(0, 0, 4, vdp1_tile_address, str);

      vdp_end_draw_list();

      dkax[0] = q;
      q += 10000;

      if (per[0].but_push_once & PAD_A)
      {
         map_offset++;

         if (map_offset > 3)
            map_offset = 0;
      }

      if (per[0].but_push_once & PAD_B)
      {
         ktaof++;

         if (ktaof > 3)
            ktaof = 0;
      }

      if (per[0].but_push_once & PAD_C)
      {
         param_offset++;

         if (param_offset > 3)
            param_offset = 0;
      }

      if (per[0].but_push_once & PAD_Z)
      {
         q = 0;
         init_rbg0(map_offset, param_offset, ktaof, coef_data_size, deltakax);
      }

      if (per[0].but_push_once & PAD_START)
      {
         reset_system();
      }
   }
}

//////////////////////////////////////////////////////////////////////////////

void vdp2_auto_tests()
{
   auto_test_section_start("Vdp2 screenshot tests");

   vdp2_all_scroll_test();
   vdp2_line_color_screen_test();
   vdp2_extended_color_calculation_test();
   vdp2_special_priority_test();
   vdp2_line_window_test();
   vdp2_line_scroll_test();

   auto_test_section_end();
}