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

#ifndef CDBH
#define CDBH

enum IAPETUS_ERR init_cdb_tests();
void cdb_test();
void cd_cmd_test();
void cd_rw_test();
void misc_cd_test();

void test_cmd_cd_status();
void test_cmd_get_hw_info();
void test_cmd_get_toc();
void test_cmd_get_session_info();

void test_cmd_set_cddev_con();
void test_cmd_get_cd_dev_con();
void test_cmd_get_last_buffer();
void test_cmd_set_filter_range();
void test_cmd_get_filter_range();
void test_cmd_set_filter_sh_cond();
void test_cmd_get_filter_sh_cond();
void test_cmd_set_filter_mode();
void test_cmd_get_filter_mode();
void test_cmd_set_filter_con();
void test_cmd_get_filter_con();

void test_cmd_set_sector_length();
#endif
