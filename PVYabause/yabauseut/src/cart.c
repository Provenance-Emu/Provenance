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
#include "cart.h"

//////////////////////////////////////////////////////////////////////////////

void cart_test()
{
   int choice;

   menu_item_struct cart_menu[] = {
   { "Action Replay" , &ar_test, },
   { "1 Mbit DRAM Cart", &dram_1mbit_test, },
   { "4 Mbit DRAM Cart", &dram_4mbit_test, },
   { "Backup RAM Cart" , &bup_test, },
   { "Netlink Cart" , &netlink_test, },
   { "ROM Cart" , &rom_test, },
   { "Misc" , &misc_cart_test, },
   { "\0", NULL }
   };

   for (;;)
   {
      choice = gui_do_menu(cart_menu, &test_disp_font, 0, 0, "Cart Tests", MTYPE_CENTER, -1);
      if (choice == -1)
         break;
   }   
}

//////////////////////////////////////////////////////////////////////////////

void ar_test ()
{
}

//////////////////////////////////////////////////////////////////////////////

void dram_1mbit_test ()
{
}

//////////////////////////////////////////////////////////////////////////////

void dram_4mbit_test ()
{
}

//////////////////////////////////////////////////////////////////////////////

void bup_test ()
{
}

//////////////////////////////////////////////////////////////////////////////

void netlink_test ()
{
}

//////////////////////////////////////////////////////////////////////////////

void rom_test ()
{
}

//////////////////////////////////////////////////////////////////////////////

void misc_cart_test ()
{
}

//////////////////////////////////////////////////////////////////////////////
